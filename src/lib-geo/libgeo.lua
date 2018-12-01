
-- libgeo simple Geometric Library
-- All dimension must be in scaled point (sp)

local libgeo = {
    _VERSION     = "libgeo v0.0.1",
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

-- internally gets text as a byte codepoint sequence

function Text:new(xpos, ypos, ax, ay)
    assert(type(xpos) == "number", "Number required")
    assert(type(ypos) == "number", "Number required")
    ax = ax or 0
    ay = ay or 0
    local o = {
        text_list = {},
        xpos = xpos,
        ypos = ypos,
        ax = ax,
        ay = ay,
    }
    setmetatable(o, self)
    return o, nil
end

function Text:from_string(s, xpos, ypos, ax, ay)
    assert(type(s) == "string", "Not a valid string")
    if #s == 0  then return nil, "Empty string"  end
    local txt = self:new(xpos, ypos, ax, ay)

    local arr = {}
    for b in string.bytes(s) do
        arr[#arr+1] = b
    end
    local ta = txt.text_list
    ta[1] = {arr}
    return txt, nil
end

function Text:from_int(n, digits, xpos, ypos, ax, ay)
    if not n then return nil, "Mandatory arg"   end
    if n < 0 then return nil, "Negative number" end
    if (n - math.floor(n)) > 0 then
        return nil, "Not an integer number"
    end
    local txt = self:new(xpos, ypos, ax, ay)
    local p = n
    local d = 0
    while p > 0 do
        d = d + 1
        p = math.floor(p / 10)
    end
    digits = digits or d
    if d > digits then
        return nil, "The number has more digits than the requested argument"
    end
    local arr = {}
    for i = digits, 1, -1 do
        if n > 0 then
            local dg = n % 10
            arr[i] = dg + 48
            n = (n - dg)/10
        else
            arr[i] = 48
        end
    end
    local ta = txt.text_list
    ta[1] = arr
    return txt, nil
end

function Text:from_chars(c_arr, xpos, ypos, ax, ay)
    if not c_arr then return nil, "Mandatory arg" end
    local txt = self:new(xpos, ypos, ax, ay)
    local arr = {}
    for i, c in ipairs(c_arr) do
        arr[i] = string.byte(c)
    end
    local ta = txt.text_list
    ta[1] = arr
    return txt, nil
end

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


return libgeo

