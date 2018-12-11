
-- libgeo simple Geometric Library
-- All dimension must be in scaled point (sp)

local libgeo = {
    _VERSION     = "libgeo v0.0.2",
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
function Vbar:from_array(yl_arr)
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
    assert(i % 2 == 0, "[InternalErr] not an even index")
    assert(i > 0, "[InternalErr] empty array")
    local o = {
        _yline = yl_arr, -- [<xcenter>, <width>, ...] flat array
        _x_lim = xlim,   -- right external bounding box coordinates
    }
    setmetatable(o, self)
    return o
end

-- costructor useful for EAN encoder
-- from an integer to read from right to left
-- 13212 ->rev 21231 ->binary 11 0 11 000 1 -> symbol 110110001
-- is_bar :: boolean :: bar or space for first, default true
function Vbar:from_int_revstep(ngen, mod, is_bar)
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
-- 1212 -> rev 2121 -> bar 1 2 2 2 -> b W B W
-- build a yline array from the integer definition. Digit decoding rule:
-- mod: b or w => 1 -- narrow bar/space
-- MOD: B or W => 2 -- wide bar/space
function Vbar:from_int_revpair(ngen, mod, MOD, is_bar)
    assert(type(ngen) == "number", "Invalid argument for n")
    assert(type(mod) == "number", "Invalid argument for narrow module width")
    assert(type(MOD) == "number", "Invalid argument for wide module width")
    assert(mod < MOD, "Not ordered module value")
    if is_bar == nil then is_bar = true else
        assert(type(is_bar) == "boolean", "Invalid argument for is_bar")
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
        end; assert(w, "[InternalErr] Allowed digits 1, 2")
        if is_bar then -- bars
            k = k + 1; yl[k] = x0 + w/2 -- xcenter
            k = k + 1; yl[k] = w        -- width
        end
        is_bar = not is_bar
        x0 = x0 + w
    end
    assert(not is_bar, "[InternalErr] the last element in not a bar")
    local o = {
        _yline = yl, -- [<xcenter>, <width>, ...] flat array
        _x_lim = x0, -- external x coordinate
    }
    setmetatable(o, self)
    return o
end


-- Vbar methods

-- draw the lines in the xy plane towards a driver's canvas
-- tx is the absolute coordinate of the local origin
-- y0, y1 are the y-coordinates of the vertical bound
function Vbar:append_graphic(canvas, y1, y2, tx) --> canvas, err
    assert(canvas, "'canvas' object must be provided")
    assert(y1, "y1 must be provided")
    assert(y2, "y2 must be provided")
    tx = tx or 0
    if y1 > y2 then -- re-ordering y-coordinates
        y1, y2 = y2, y1
    end
    local yl = self._yline
    local c, err = canvas:vbar(tx, y1, y2, yl)
    return c, err
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
    for b in string.bytes(s) do
        cp[#cp + 1] = b
    end
    local o = {
        codepoint = cp,
    }
    setmetatable(o, self)
    return o
end

-- from an array of chars
function Text:from_chars(chars)
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
function Text:from_int(n)
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

function Text:append_graphic(canvas, xpos, ypos, ax, ay) --> canvas, err
    assert(type(canvas) == "table", "[ArgErr] 'canvas' object must be provided")
    assert(type(xpos) == "number", "[ArgErr] 'xpos' number required")
    assert(type(ypos) == "number", "[ArgErr] 'ypos' number required")
    ax = ax or 0; assert(type(ax) == "number", "[ArgErr] 'ax' is not a number")
    ay = ay or 0; assert(type(ay) == "number", "[ArgErr] 'ay' is not a number")
    
    local chars = self.codepoint
    local c, err = canvas:text(xpos, ypos, ax, ay, chars)
    return c, err
end

-- glyph equally spaced along the baseline
function Text:append_graphic_xspaced(canvas, x1, xgap, ypos, ay) --> canvas, err
    assert(type(canvas) == "table", "[ArgErr] 'canvas' object must be provided")
    assert(type(x1) == "number", "[ArgErr] 'x1' number required")
    assert(type(xgap) == "number", "[ArgErr] 'xgap' is not a number")
    assert(type(ypos) == "number", "[ArgErr] 'ypos' number required")
    ay = ay or 0; assert(type(ay) == "number", "[ArgErr] 'ay' is not a number")
    local chars = self.codepoint
    local c, err
    if xgap > 0 then
        c, err = canvas:text_xspaced(x1, xgap, ay, ypos, chars)
    elseif xgap < 0 then
        local n = #chars
        x1 = x1 + (n - 1) * xgap
        xgap = -xgap
        c, err = canvas:text_xspaced(x1, xgap, ay, ypos, chars)
    else -- xgap == 0
        error("xgap is zero")
    end
    return c, err
end

return libgeo



--[=[

function Text:from_intarray(n_arr, xpos, ypos, ax, ay, i, j)
    if not n_arr then return nil, "Mandatory arg" end
    i = i or 1
    j = j or #n_arr
    assert(j >= i, "No ordered index")
    local txt = self:new(xpos, ypos, ax, ay)
    local arr = {}
    for k = i, j do
        arr[#arr + 1] = n_arr[k] + 48
    end
    local ta = txt.text_list
    ta[1] = arr
    return txt, nil
end


function Text:append_string(s, xspace, axprec, axsucc)
    if not s    then return nil, "Mandatory arg" end
    if #s == 0  then return nil, "Empty string"  end
    local tl = self.text_list
    if #tl > 0 and xspace then
        axprec = axprec or 0
        axsucc = axsucc or 0
        tl[#tl+1] = {glue = xspace, axprec = axprec, axsucc = axsucc,}
    end
    local arr = {}
    for b in string.bytes(s) do
        arr[#arr+1] = b
    end
    tl[#tl + 1] = arr
    return self
end

function Text:append_listof_string(slist, xspace, axprec, axsucc, i, j)
    i = i or 1
    j = j or #slist
    assert(j >= i, "No ordered index")
    for k = i, j do
        self:append_string(slist[k], xspace, axprec, axsucc)
    end
    return self
end

function Text:append_intarray(n_arr, xspace, axprec, axsucc, i, j)
    assert(n_arr, "Mandatory arg")
    i = i or 1
    j = j or #n_arr
    assert(j >= i, "No ordered index")

    local tl = self.text_list
    if #tl > 0 and xspace then
        axprec = axprec or 0
        axsucc = axsucc or 0
        tl[#tl+1] = {glue = xspace, axprec = axprec, axsucc = axsucc,}
    end

    local arr = {}
    for k = i, j do
        arr[#arr + 1] = n_arr[k] + 48
    end
    tl[#tl+1] = arr
    return self
end

--]=]