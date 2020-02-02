
-- libgeo simple Geometric Library
-- Copyright (C) 2018 Roberto Giacomelli

-- All dimension must be in scaled point (sp)

local libgeo = {
    _VERSION     = "libgeo v0.0.3",
    _NAME        = "libgeo",
    _DESCRIPTION = "simple geometric library",
}

-- VBar class
-- a pure geometric entity of several infinite vertical lines
libgeo.Vbar = {}
local Vbar = libgeo.Vbar
Vbar.__index = Vbar

-- Vbar costructors

-- VBar costructor from an array [xcenter1, width1, xcenter2, width2, ...]
function Vbar:from_array(yl_arr) --> <vbar object>
    assert(type(yl_arr) == "table", "'yline_array' is a mandatory arg")
    -- stream scanning
    local i = 1
    local xlim = 0.0
    while yl_arr[i] do
        local x = yl_arr[i]; i = i + 1
        local w = yl_arr[i]; i = i + 1
        assert(type(x) == "number", "[InternalErr] not a number")
        assert(type(w) == "number", "[InternalErr] not a number")
        xlim = x + w/2
    end
    assert(i % 2 == 0, "[InternalErr] the index is not even")
    assert(i > 0, "[InternalErr] empty array")
    local o = {
        _yline = yl_arr, -- [<xcenter>, <width>, ...] flat array
        _x_lim = xlim,   -- right external bounding box coordinates
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
    local x0 = 0.0 -- axis reference
    local yl = {}
    for k = #digits, 1, -1 do
        local d = digits[k]
        local w = d*mod   -- bar width
        if is_bar then    -- bar
            yl[#yl + 1] = x0 + w/2
            yl[#yl + 1] = w
        end
        x0 = x0 + w
        is_bar = not is_bar
    end
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- right external coordinate
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
    local x0 = 0.0 -- axis reference
    local i = 0
    local yl = {}
    while ngen > 0 do
        local d = ngen % 10 -- first digit
        local w = d*mod     -- bar width
        if is_bar then -- bar
            i = i + 1; yl[i] = x0 + w/2
            i = i + 1; yl[i] = w
        end
        x0 = x0 + w
        is_bar = not is_bar
        ngen = (ngen - d)/10
    end
    assert(not is_bar, "[InternalErr] the last element in not a bar")
    local o = {
        _yline = yl,   -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- right external coordinate
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
        end
        is_bar = not is_bar
        x0 = x0 + w
    end
    assert(not is_bar, "[InternalErr] the last element is not a bar")
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- external x coordinate
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
        local is_narrow_space = tspace[i]
        assert(type(is_narrow_space) == "boolean", "[InternalErr] found a not boolean value")
        if is_narrow_space then
            x0 = x0 + mod
        else
            x0 = x0 + MOD
        end
    end
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- external x coordinate
    }
    setmetatable(o, self)
    return o
end

-- Text class

libgeo.Text = {}
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
