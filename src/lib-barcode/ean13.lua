-- Ean13 barcode generator
-- Copyright (C) 2018 Roberto Giacomelli

local Ean13 = {
    _VERSION     = "ean13 v0.0.3",
    _NAME        = "ean13",
    _DESCRIPTION = "EAN13 barcode encoder",
}

Ean13._codeset_sequence = {
[0]={1, 1, 1, 1, 1, 1, 3, 3, 3, 3, 3, 3},
    {1, 1, 2, 1, 2, 2, 3, 3, 3, 3, 3, 3},
    {1, 1, 2, 2, 1, 2, 3, 3, 3, 3, 3, 3},
    {1, 1, 2, 2, 2, 1, 3, 3, 3, 3, 3, 3},
    {1, 2, 1, 1, 2, 2, 3, 3, 3, 3, 3, 3},
    {1, 2, 2, 1, 1, 2, 3, 3, 3, 3, 3, 3},
    {1, 2, 2, 2, 1, 1, 3, 3, 3, 3, 3, 3},
    {1, 2, 1, 2, 1, 2, 3, 3, 3, 3, 3, 3},
    {1, 2, 1, 2, 2, 1, 3, 3, 3, 3, 3, 3},
    {1, 2, 2, 1, 2, 1, 3, 3, 3, 3, 3, 3},
}

Ean13._symbol = {
    -- codeset A
    [1] = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,},
    -- codeset B
    [2] = {[0] = 1123, 1222, 2212, 1141, 2311, 1321, 4111, 2131, 3121, 2113,},
    -- codeset C
    [3] = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,},
}

Ean13._is_first_bar = {false, false, true}
Ean13._start_stop = {
    {  111, true , 3},
    {11111, false, 5},
}

Ean13._par_def = {}
local pardef = Ean13._par_def

-- standard module is 0.33 mm but it can vary from 0.264 to 0.66mm
pardef.mod = {
    default    = 0.33 * 186467, -- (mm to sp) X dimension (original value 0.33)
    unit       = "sp", -- scaled point
    isReserved = true,
    order      = 1, -- the one first to be modified
    fncheck    = function (self, x, _) --> boolean, err
        local mm = 186467
        local min, max = 0.264 * mm, 0.660 * mm
        if x < min then
            return false, "[OutOfRange] too small value for mod"
        elseif x > max then
            return false, "[OutOfRange] too big value for mod"
        end
        return true, nil
    end,
}

pardef.height = {
    default    = 15 * 186467, -- (mm to sp)
    unit       = "sp",
    isReserved = false,
    order      = 2,
    fncheck    = function (self, h, _) --> boolean, err
        if h > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for height"
        end
    end,
}

pardef.quietzone_left_factor = {
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    order      = 3,
    fncheck    = function (self, qzf, _) --> boolean, err
        if qzf > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_left_factor"
        end
    end,
}

pardef.quietzone_right_factor = {
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    order      = 4,
    fncheck    = function (self, qzf, _) --> boolean, err
        if qzf > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_right_factor"
        end
    end,
}

pardef.bars_depth_factor = {
    default    = 5,
    unit       = "absolute-number",
    isReserved = false,
    order      = 5,
    fncheck    = function (self, b, _) --> boolean, err
        if b >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_right_factor"
        end
    end,
}

pardef.text_ygap_factor = {
    default    = 1.5,
    unit       = "absolute-number",
    isReserved = false,
    order      = 6,
    fncheck    = function (self, t, _) --> boolean, err
        if t >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_right_factor"
        end
    end,
}

-- utility function

-- return the flat array [xcenter, width, ...] of the bars
-- from the integer representation
local function yline(n, isbar, digits, mod)
    local yl = {} -- [xcenter, width, ...]
    local x0 = 0
    local div = 10^digits
    for i = 1, digits do
        div = div / 10
        local d = math.floor(n/div) % 10
        local w = d*mod
        if isbar then
            local xc = x0 + w/2
            yl[#yl + 1] = xc
            yl[#yl + 1] = w
        end
        x0 = x0 + w
        isbar = not isbar
    end
    return yl
end

-- return the check digit no matter if the symbol
-- is 12 or 13 digits length
local function check_digit(data)
    local sum = 0
    local flag = true
    for i = 1, 12 do
        if flag then
            sum = sum + data[i]
        else
            sum = sum + 3*data[i]
        end
        flag = not flag
    end
    local ck = 10 - (sum % 10)
    if ck == 10 then ck = 0 end
    return ck
end

-- costructors section

-- costructor: from an array of digits
-- no error checking, not yet !!!
function Ean13:from_intarray(array)
    local o = { -- build the Ean13 object
        code = array, -- array of 13 digits
    }
    setmetatable(o, self)
    return o, nil
end

-- costructor: from a string
-- no error checking!!! not yet
-- string.utfvalues() is a LuaTeX only function
function Ean13:from_string(s)
    if not s then return nil, "Mandatory arg" end
    if not type(s) == "string" then
        return nil, "The provided arg is not a string"
    end
    if #s == 0 then
        return nil, "Empty string"
    end
    local symb = {}
    for codepoint in string.utfvalues(s) do
        if codepoint < 48 or codepoint > 57 then -- only digit
            local fmt = "The char '%d' is not a digits (from 0 to 9)"
            return nil, string.format(fmt, codepoint)
        end
        symb[#symb + 1] = codepoint - 48
    end
    if #symb == 12 then
        symb[#symb + 1] = check_digit(symb)
    elseif #symb == 13 then
        if symb[13] ~= check_digit(symb) then
            return nil, "Wrong check digit in the code"
        end
    else
        return nil, "Wrong number of digits in the code"
    end
    local o = {
        code = symb, -- array of 13 digits
    }
    setmetatable(o, self)
    return o, nil
end

-- methods functions

function Ean13:config()
    local ean = self
    local libgeo = assert(ean.libgeo)
    local Vbar = libgeo.Vbar
    local mod = ean.mod
    --
    local str = ean.start_stop[1]
    local yl_start = yline(str[1], str[2], str[3], mod)
    ean.start_stop_vbar = Vbar:from_array(yl_start)
    --
    local stp = ean.start_stop[2]
    local yl_stop  = yline(stp[1], stp[2], stp[3], mod)
    ean.ctrl_center_vbar = Vbar:from_array(yl_stop)
    --
    ean.codeset_vbar = {}
    for i_cs, codetab in ipairs(ean.symbol) do
        ean.codeset_vbar[i_cs] = {}
        local tdest = ean.codeset_vbar[i_cs]
        local isbar = ean.is_first_bar[i_cs]
        for i = 0, 9 do
            tdest[i] = Vbar:from_array(yline(codetab[i], isbar, 4, mod))
        end
    end
end

-- Drawing in the provided channel the geometrical
-- data of the barcode
-- tx, ty is the optional translation vector
-- the function return the canvas reference to accomplish chaining
function Ean13:append_graphic(canvas, tx, ty)
    local code = self.code
    local mod = self.mod
    local ax, ay = self.ax or 0, self.ay or 0
    local bars_depth = mod * self.bars_depth_factor
    local w ,  h = 95*mod, self.height + bars_depth
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local y1 = y0 + h
    local xpos = x0 -- current insertion x-coord
    local ys   = y0 + bars_depth
    local s_width = 7*mod

    -- reference to the codeset
    local first_code = code[1]
    local code_seq = self.codeset_sequence[first_code]

    -- draw the start symbol
    local be = self.start_stop_vbar
    be:draw_to_canvas(canvas, y0, y1, xpos)
    xpos = xpos + 3*mod
    -- draw the first 6 number
    for i = 2, 7 do
        local codeset = code_seq[i-1]
        local n = code[i]
        local vbar = self.codeset_vbar[codeset][n]
        vbar:draw_to_canvas(canvas, ys, y1, xpos)
        xpos = xpos + s_width
    end
    -- draw the control symbol
    local ctrl = self.ctrl_center_vbar
    ctrl:draw_to_canvas(canvas, y0, y1, xpos)
    xpos = xpos + 5*mod
    -- draw the product code
    for i = 8, 13 do
        local codeset = code_seq[i-1]
        local n = code[i]
        local vbar = self.codeset_vbar[codeset][n]
        vbar:draw_to_canvas(canvas, ys, y1, xpos)
        xpos = xpos + s_width
    end
    -- draw the stop char
    be:draw_to_canvas(canvas, y0, y1, xpos)

    -- bounding box check
    local qzl  = self.quite_zone_left_factor * mod
    local qzr  = self.quite_zone_right_factor * mod
    canvas:bounding_box(x0 - qzl, y0, x1 + qzr, y1) -- {xmin, ymin, xmax, ymax}

    -- text human readable
    local Text = self.libgeo.Text
    local txt = Text
        :from_intarray(
            code,                             -- array of integers
            x0 - qzl,                         -- xpos
            ys - self.text_ygap_factor * mod, -- ypos
            0, 1,                             -- ax, ay
            1, 1                              -- slice index
        )
        :append_intarray(code, 24.5*mod + qzl,   0, 0.5, 2, 7)
        :append_intarray(code,         46*mod, 0.5, 0.5, 8, 13)

    canvas:add_text(txt)
end

return Ean13
--
