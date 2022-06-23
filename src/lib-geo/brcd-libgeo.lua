-- this file is part of barracuda project
-- Copyright (C) 2019-2022 Roberto Giacomelli
-- see https://github.com/robitex/barracuda
--
-- libgeo simple Geometric Library

-- All dimension must be in scaled point (sp) a TeX unit equal to 1/65536pt
local libgeo = {
    _VERSION     = "libgeo v0.0.6",
    _NAME        = "libgeo",
    _DESCRIPTION = "simple geometric library",
}

-- a simple tree structured Archive class
libgeo.Archive = {_classname = "Archive"}
local Archive = libgeo.Archive
Archive.__index = Archive

function Archive:new() --> object
    local o = {
        _archive = {}
    }
    setmetatable(o, self)
    return o
end

function Archive:insert(o, ...) --> ok, err
    if type(o) ~= "table" then
        return false, "[Err] "
    end
    local a = self._archive
    local keys = {...}
    for i = 1, (#keys - 1) do -- dive into the tree
        local k = keys[i]
        local leaf = a[k]
        if not leaf then
            a[k] = {}
            leaf = a[k]
        end
        a = leaf
    end
    local k = keys[#keys]
    if a[k] ~= nil then
        return false, "[Err] an object "
    end
    a[k] = o
    return true, nil
end

function Archive:contains_key(...) --> boolean
    local a = self._archive
    for _, k in ipairs{...} do
        local leaf = a[k]
        if leaf == nil then
            return false
        end
        a = leaf
    end
    return true
end

function Archive:get(...) --> object, err
    local a = self._archive
    for _, k in ipairs{...} do
        local leaf = a[k]
        if leaf == nil then
            return nil, "[Err] key '"..k.."' not found"
        end
        a = leaf
    end
    return a, nil
end

-- Queue Class
local VbarQueue = {_classname = "VbarQueue"}
libgeo.Vbar_queue = VbarQueue
VbarQueue.__index = VbarQueue

function VbarQueue:new()
   local o = { 0 }
   setmetatable(o, self)
   return o
end

VbarQueue.__add = function (lhs, rhs)
    if type(lhs) == "number" then -- dist + queue
        local i = 1
        while rhs[i] do
            rhs[i] = rhs[i] + lhs
            i = i + 2
        end
        return rhs
    else -- queue + object
        if type(rhs) == "number" then
           lhs[#lhs] = lhs[#lhs] + rhs
           return lhs
        elseif type(rhs) == "table" then
            if rhs._classname == "VbarQueue" then -- queue + queue
                local q = {}
                for _, v in ipairs(lhs) do
                    q[#q + 1] = v
                end
                local w = lhs[#lhs]
                for i = 1, #rhs/2 do
                    q[#q + 1] = rhs[i] + w
                    q[#q + 1] = rhs[i + 1]
                end
                return q
            elseif rhs._classname == "Vbar" then -- queue + vbar
                local w = lhs[#lhs]
                lhs[#lhs + 1] = rhs
                lhs[#lhs + 1] = w + rhs._x_lim
                return lhs
            else
                error("[Err] unsupported object type for queue operation")
            end
        else
            error("[Err] unsupported type for queue operation")
        end
    end
end

function VbarQueue:width()
    return self[#self] - self[1]
end

-- Vbar class
-- a pure geometric entity of several infinite vertical lines
libgeo.Vbar = {_classname = "Vbar"}
local Vbar = libgeo.Vbar
Vbar.__index = Vbar
Vbar.__add = function (lhs, rhs)
    return VbarQueue:new() + lhs + rhs
end

-- Vbar costructors

-- VBar costructor from an array [xcenter1, width1, xcenter2, width2, ...]
function Vbar:from_array(yl_arr) --> <vbar object>
    assert(type(yl_arr) == "table", "'yline_array' is a mandatory arg")
    -- stream scanning
    local i = 1
    local nbars = 0
    local xlim = 0.0
    while yl_arr[i] do
        local x = yl_arr[i]; i = i + 1
        local w = yl_arr[i]; i = i + 1
        assert(type(x) == "number", "[InternalErr] not a number")
        assert(type(w) == "number", "[InternalErr] not a number")
        xlim = x + w/2
        nbars = nbars + 1
    end
    assert(i % 2 == 0, "[InternalErr] the index is not even")
    assert(nbars > 0, "[InternalErr] empty array")
    local o = {
        _yline = yl_arr, -- [<xcenter>, <width>, ...] flat array
        _x_lim = xlim,   -- right external bounding box coordinates
        _nbars = nbars,  -- number of bars
    }
    setmetatable(o, self)
    return o
end

-- costructor useful for Code128 encoder
-- from an integer: 21231 -> binary 11 0 11 000 1 -> symbol 110110001
-- is_bar :: boolean :: bar or space as first element, default true
function Vbar:from_int(ngen, mod, is_bar) --> <vbar object>
    assert(type(ngen) == "number", "Invalid argument for n")
    assert(type(mod) == "number", "Invalid argument for module width")
    if is_bar == nil then is_bar = true else
        assert(type(is_bar) == "boolean", "Invalid argument for is_bar")
    end
    -- scan ngen for digits
    local digits = {}
    while ngen > 0 do
        local d = ngen % 10
        digits[#digits + 1] = d
        ngen = (ngen - d)/10
    end
    local nbars = 0
    local x0 = 0.0 -- axis reference
    local yl = {}
    for k = #digits, 1, -1 do
        local d = digits[k]
        local w = d*mod   -- bar width
        if is_bar then    -- bar
            yl[#yl + 1] = x0 + w/2
            yl[#yl + 1] = w
            nbars = nbars + 1
        end
        x0 = x0 + w
        is_bar = not is_bar
    end
    assert(nbars > 0, "[InternalErr] no bars")
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- right external coordinate
        _nbars = nbars,  -- number of bars
    }
    setmetatable(o, self)
    return o
end

-- from an integer to read from right to left
-- 13212 ->rev 21231 ->binary 11 0 11 000 1 -> symbol 110110001
-- is_bar :: boolean :: bar or space for first, default true
function Vbar:from_int_revstep(ngen, mod, is_bar) --> <vbar object>
    assert(type(ngen) == "number", "Invalid argument for n")
    assert(type(mod) == "number", "Invalid argument for module width")
    if is_bar == nil then is_bar = true else
        assert(type(is_bar) == "boolean", "Invalid argument for is_bar")
    end
    --
    local nbars = 0
    local x0 = 0.0 -- axis reference
    local i = 0
    local yl = {}
    while ngen > 0 do
        local d = ngen % 10 -- first digit
        local w = d*mod     -- bar width
        if is_bar then -- bar
            i = i + 1; yl[i] = x0 + w/2
            i = i + 1; yl[i] = w
            nbars = nbars + 1
        end
        x0 = x0 + w
        is_bar = not is_bar
        ngen = (ngen - d)/10
    end
    assert(not is_bar, "[InternalErr] the last element in not a bar")
    assert(nbars > 0, "[InternalErr] no bars")
    local o = {
        _yline = yl,   -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- right external coordinate
        _nbars = nbars,  -- number of bars
    }
    setmetatable(o, self)
    return o
end

-- costructor useful for Code39 encoder
-- i.e. 11212 -> rev -> 2 1 2 1 1 -> decodes to -> B w B w b
-- build a yline array from the integer definition. Digit decoding rule:
-- mod: b or w => 1 -- narrow bar/space
-- MOD: B or W => 2 -- wide bar/space
-- is_bar: the first element is a bar not a space, default to true
function Vbar:from_int_revpair(ngen, mod, MOD, is_bar) --> <vbar object>
    assert(type(ngen) == "number", "Invalid argument for n")
    assert(type(mod) == "number", "Invalid argument for narrow module width")
    assert(type(MOD) == "number", "Invalid argument for wide module width")
    assert(mod < MOD, "Not ordered narrow/Wide values")
    if is_bar == nil then
        is_bar = true
    else
        assert(type(is_bar) == "boolean", "Invalid argument for 'is_bar'")
    end
    local nbars = 0
    local yl = {}
    local x0 = 0.0
    local k = 0
    while ngen > 0 do
        local d = ngen % 10 -- digit
        ngen = (ngen - d)/10
        local w; if d == 1 then
            w = mod
        elseif d == 2 then
            w = MOD
        end; assert(w, "[InternalErr] Allowed digits are only 1 or 2")
        if is_bar then -- bars
            k = k + 1; yl[k] = x0 + w/2 -- xcenter
            k = k + 1; yl[k] = w        -- width
            nbars = nbars + 1
        end
        is_bar = not is_bar
        x0 = x0 + w
    end
    assert(nbars > 0, "[InternalErr] no bars")
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- external x coordinate
        _nbars = nbars, -- number of bars
    }
    setmetatable(o, self)
    return o
end

-- return a Vbar interleaving narrow/Wide sequences
-- tbar, tspace = {boolean sequence}, true -> narrow, false -> Wide
function Vbar:from_two_tab(tbar, tspace, mod, MOD) --> <vbar object>
    assert(type(tbar) == "table", "tbar must be a table")
    assert(type(tspace) == "table", "tspace must be a table")
    assert(#tbar == #tspace, "tbar and tspace must be longer the same")
    assert(type(mod) == "number", "Invalid argument for narrow module width")
    assert(type(MOD) == "number", "Invalid argument for wide module width")
    assert(mod < MOD, "Not ordered narrow/Wide values")
    local nbars = 0
    local x0 = 0.0 -- x-coordinate
    local yl = {}
    for i = 1, #tbar do
        local is_narrow = tbar[i]
        assert(type(is_narrow) == "boolean", "[InternalErr] found a not boolean value")
        if is_narrow then
            yl[#yl + 1] = x0 + mod/2 -- bar x-coordinate
            yl[#yl + 1] = mod -- bar width
            x0 = x0 + mod
        else
            yl[#yl + 1] = x0 + MOD/2 -- bar x-coordinate
            yl[#yl + 1] = MOD -- bar width
            x0 = x0 + MOD
        end
        nbars = nbars + 1
        local is_narrow_space = tspace[i]
        assert(type(is_narrow_space) == "boolean", "[InternalErr] found a not boolean value")
        if is_narrow_space then
            x0 = x0 + mod
        else
            x0 = x0 + MOD
        end
    end
    assert(nbars > 0, "[InternalErr] no bars")
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- external x coordinate
        _nbars = nbars, -- number of bars
    }
    setmetatable(o, self)
    return o
end

function Vbar:get_bars() --> nbars, <coordinates flat array>
    return self._nbars, self._yline
end

-- Polyline class
local Polyline = {_classname = "Polyline"}
Polyline.__index = Polyline
libgeo.Polyline = Polyline

-- optional argument a first point (x, y)
function Polyline:new(x, y) --> <Polyline>
    local o = {
        _point = {},
        _n = 0,
    }
    setmetatable(o, self)
    if x ~= nil then
        assert(type(x) == "number", "[Polyline:new()] Invalid type for x-coordinate")
        assert(type(y) == "number", "[Polyline:new()] Invalid type for y-coordinate")
        self:add_point(x, y)
    end
    return o
end

-- get a clone of points' coordinates
function Polyline:get_points()
    local res = {}
    local p = self._point
    for i, c in ipairs(p) do
        res[i] = c
    end
    return self._n, res
end

-- append a new point with absolute coordinates
function Polyline:add_point(x, y)
    assert(type(x) == "number", "[Polyline:add_point()] Invalid type for x-coordinate")
    assert(type(y) == "number", "[Polyline:add_point()] Invalid type for y-coordinate")
    local point = self._point
    point[#point + 1] = x
    point[#point + 1] = y
    self._n = self._n + 1
end

-- append a new point with relative coordinates respect to the last one
function Polyline:add_relpoint(x, y)
    assert(type(x) == "number", "Invalid type for x-coordinate")
    assert(type(y) == "number", "Invalid type for y-coordinate")
    local point = self._point
    local n = self._n
    assert(n > 0, "Attempt to add a relative point to an empty polyline")
    local i = 2 * n
    point[#point + 1] = point[i - 1] + x
    point[#point + 1] = point[i] + y
    self._n = n + 1
end

-- Text class

libgeo.Text = {_classname="Text"}
local Text = libgeo.Text
Text.__index = Text

-- costructors
-- internally it keeps text as a sequence of codepoint
function Text:from_string(s) --> object
    assert(type(s) == "string", "[ArgErr] 's' not a valid string")
    assert(#s > 0, "[Err] 's' empty string not allowed")

    local cp = {} -- codepoint array
    for b in string.gmatch(s, ".") do
        cp[#cp + 1] = string.byte(b)
    end
    local o = {
        codepoint = cp,
    }
    setmetatable(o, self)
    return o
end

-- arr, array of single digit number
-- i start index
-- j stop index
function Text:from_digit_array(arr, i, j) --> object
    assert(type(arr) == "table", "[ArgErr] 'arr' not a table")
    assert(#arr > 0, "[ArgErr] 'arr' is an empty array")
    local cp = {} -- codepoint array
    if i ~= nil then
        assert(type(i) == "number", "[ArgErr] 'i' is not a number")
    else
        i = 1
    end
    if j ~= nil then
        assert(type(j) == "number", "[ArgErr] 'j' is not a number")
        assert(i <= j, "[ArgErr] not suitable pair of array index")
    else
        j = #arr
    end
    for k = i, j do
        local d = arr[k]
        assert(type(d) == "number", "[ArgErr] array contains a not number element")
        assert(d == math.floor(d), "[ArgErr] array contains a not integer number")
        assert(d >= 0 or d < 10, "[ArgErr] array contains a not single digit number")
        cp[#cp + 1] = d + 48
    end
    local o = {
        codepoint = cp,
    }
    setmetatable(o, self)
    return o
end


-- from an array of chars
function Text:from_chars(chars) --> object
    assert(type(chars) == "table", "[ArgErr] 'chars' must be a table")
    local arr = {}
    for _, c in ipairs(chars) do
        arr[#arr + 1] = string.byte(c)
    end
    local o = {
        codepoint = arr,
    }
    setmetatable(o, self)
    return o
end

-- provide an integer to build a Text object
function Text:from_int(n) --> object
    assert(type(n) == "number", "[ArgErr] 'n' must be a number")
    assert( n > 0, "[Err] 'n' must be positive")
    assert( n == math.floor(n), "[Err] 'n' must be an integer")
    local cp = {}
    while n > 0 do
        local d = n % 10
        cp[#cp + 1] = d + 48
        n = (n - d)/10
    end
    local digits = #cp
    for i = 1, digits/2 do -- reverse the array
        local d = cp[digits - i + 1]
        cp[digits - i + 1] = cp[i]
        cp[i] = d
    end
    local o = {
        codepoint = cp,
    }
    setmetatable(o, self)
    return o
end

return libgeo
