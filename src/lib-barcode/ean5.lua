-- Ean5 barcode generator
-- Copyright (C) 2018 Roberto Giacomelli

local Ean5 = {}

-- standard module is 0.33 mm but it can vary from 0.264 to 0.66mm
Ean5.mod =  0.33 * 186467 -- (mm to sp) X dimension
Ean5.height = 11 * 186467 -- (mm to sp)
Ean5.quite_zone_factor = 10
Ean5.text_ygap_factor  = 1.8

-- L-code == 1
-- G-code == 2
Ean5.structure = { -- check digit => structure
[0]={2, 2, 1, 1, 1}, -- GGLLL
    {2, 1, 2, 1, 1}, -- GLGLL
    {2, 1, 1, 2, 1}, -- GLLGL
    {2, 1, 1, 1, 2}, -- GLLLG
    {1, 2, 2, 1, 1}, -- LGGLL
    {1, 1, 2, 2, 1}, -- LLGGL
    {1, 1, 1, 2, 2}, -- LLLGG
    {1, 2, 1, 2, 1}, -- LGLGL
    {1, 2, 1, 1, 2}, -- LGLLG
    {1, 1, 2, 1, 2}, -- LLGLG
}

-- L-code == 1
-- G-code == 2
Ean5.symbol = {
{[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112},
{[0] = 1123, 1222 ,2212 ,1141, 2311, 1321, 4111, 2131, 3121, 2113},
}

Ean5.is_first_bar = false

-- utility function

-- return the flat array {xcenter, width, ...} of the bars
-- from the integer representation
local function yline(n, isbar, digits, mod)
    local yl = {} -- {(xcenter, width)}
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

-- return the check digit that selects the symbol's structure
local function checksum(t)
    local ck = (t[1] + t[3] + t[5]) * 3 + (t[2] + t[4]) * 9
    return ck % 10
end

-- costructors section
-- the returned values are object, err_message pair


-- costructor: from an array of digits
-- -> object, err_message
function Ean5:from_intarray(array)
    if not array then
        return nil, "Mandatory arg"
    end
    if #array ~= 5 then
        return nil, "Wrong number of digits in the array (5 expected)"
    end
    for _, n in ipairs(array) do
        if not type(n) == "number" then
            return nil, "An element of the array is not a number"
        end
    end

    local o = { -- build the Ean5 object
        code = array, -- array of 5 digits
    }
    setmetatable(o, self)
    return o, nil
end

-- costructor
function Ean5:from_int(n)
    if not n then
        return nil, "Mandatory arg"
    end
    if n < 0 then return nil, "Negative number" end
    if (n - math.floor(n)) > 0 then
        return nil, "Not an integer number"
    end
    if n > 99999 then
        return nil, "Out of range for a 5 digits number: " .. n
    end
    local arr = {}
    for i = 5, 1, -1 do
        if n > 0 then
            local d = n % 10
            arr[i] = d
            n = (n - d)/10
        else
            arr[i] = 0
        end
    end

    local o = { -- build the Ean5 object
        code = arr, -- array of 5 digits
    }
    setmetatable(o, self)
    return o, nil
end

-- costructor: from a string
-- no error checking
-- string.bytes() is a LuaTeX only function
function Ean5:from_string(s)
    local symb = {}
    for cp in string.utfvalues(s) do
        if cp < 48 or cp > 57 then -- only digit
            local fmt = "The char '%d' is not a digits (from 0 to 9 char)"
            return nil, string.format(fmt, cp)
        end
        symb[#symb+1] = cp - 48
    end
    local o = { -- build the Ean5 object
        code = symb, -- array of 5 digits
    }
    setmetatable(o, self)
    return o, nil
end

-- methods

function Ean5:configure(register_param)
end

-- init all the vbars needed to the Ean5 barcode symbology
-- this function will be called by the loading process
function Ean5:initialize()
    local Ean5 = self
    local mod = Ean5.mod
    local Vbar = self.libgeo.Vbar
    Ean5.start_vbar = Vbar:from_array(yline(112,  true, 3, mod))
    Ean5.sep_vbar   = Vbar:from_array(yline( 11, false, 2, mod))
    Ean5.codeset_vbar = {}
    for codeset, codetab in ipairs(Ean5.symbol) do
        Ean5.codeset_vbar[codeset] = {}
        local tdest = Ean5.codeset_vbar[codeset]
        local isbar = Ean5.is_first_bar
        for i = 0, 9 do
            tdest[i] = Vbar:from_array(yline(codetab[i], isbar, 4, mod))
        end
    end
end

-- Drawing in the provided channel the geometrical
-- data of the barcode
-- tx, ty is the optional traslation vector
-- the function return the canvas reference to accomplish chaining
function Ean5:draw_to_canvas(canvas, tx, ty)
    local mod = self.mod
    local ax, ay = self.ax or 0, self.ay or 0
    local w, h = 47*mod, self.height
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local y1 = y0 + h
    local xpos = x0 -- current insertion x-coord
    local sym_width = 7*mod
    local sep_width = 2*mod
    local data = self.code

    -- draw the start symbol
    local start = self.start_vbar
    start:draw_to_canvas(canvas, y0, y1, xpos)
    xpos = xpos + 4*mod

    -- reference to the codeset L or G on the checksum's value
    local ck = checksum(data)
    local codeset = self.structure[ck]
    local sep = self.sep_vbar
    -- draw the dataset
    for i, d in ipairs(data)  do
        local cs = codeset[i] -- 1 or 2
        local vbar = self.codeset_vbar[cs][d]
        vbar:draw_to_canvas(canvas, y0, y1, xpos)
        xpos = xpos + sym_width
        if i < 5 then
            sep:draw_to_canvas(canvas, y0, y1, xpos)
            xpos = xpos + sep_width
        end
    end

    -- bounding box setting
    local qz = self.quite_zone_factor * mod
    canvas:bounding_box(x0 - qz, y0, x1 + qz, y1) -- {xmin, ymin, xmax, ymax}

    -- human readable text
    local Text = self.libgeo.Text
    local ygap = self.text_ygap_factor * mod
    local txt = Text:from_intarray(data, x1, y1 + ygap, 1, 0)
    canvas:add_text(txt)
end

return Ean5
--

