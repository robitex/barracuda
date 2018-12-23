-- EAN-2 add-on barcode encoder
-- Copyright (C) 2018 Roberto Giacomelli
-- see https://en.wikipedia.org/wiki/EAN_2

-- TODO: add human readable
-- TODO: test suite

local Ean2 = {
    symb_Start = 211, -- 1011 (in reverse orders)
    symb_Sep   =  11, -- 01
    symb_Def   = {
        [0] = 1123, -- 0001101
        1222, 2212, 1141, 2311, 1321, 4111, 2131, 3121, 2113,      --  0 ->  9 L
        3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112 -- 10 -> 19 G
    },
}

-- utility local function

-- high level encoding
local function encode_symbol(enc)
    local n1, n2 = enc.code_n1, enc.code_n2
    local r = (10*n1 + n2) % 4
    local s1, s2 = n1, n2 -- LL scheme
    if r == 1 then        -- LG scheme
        s2 = s2 + 10
    elseif r == 2 then    -- GL scheme
        s1 = s1 + 10
    else -- r == 3        -- GG scheme
        s1, s2 = s1+10, s2+10
    end
    enc.code_s1 = s1
    enc.code_s2 = s2
    -- Vbar dynamic loading
    local vbardef = enc.vbar_symbol
    local Vbar    = enc.libgeo.Vbar
    local mod     = enc.parameter_value.module
    if not vbardef[s1] then
        local n = enc.symb_Def[s1]
        vbardef[s1] = Vbar:from_int_revstep(n, mod, false)
    end
    if not vbardef[s2] then
        local n = enc.symb_Def[s2]
        vbardef[s2] = Vbar:from_int_revstep(n, mod, false)
    end
end



-- factory method: create an encoder object and set up the parameters
function Ean2:configure(enc)
    -- encoding data with an integer reverse format
    enc.symb_Start      = self.symb_Start
    enc.symb_Sep        = self.symb_Sep
    enc.symb_Def        = self.symb_Def
    -- contructors
    enc.from_intarray   = self.from_intarray
    enc.from_int        = self.from_int
    enc.from_string     = self.from_string
    -- methods
    enc.set_parameter   = self.set_parameter
    enc.draw_to_canvas  = self.draw_to_canvas

    local lib       = enc.libctrl
    local Values    = lib.Values
    local BoolCheck = lib.BoolCheck
    local NumCheck  = lib.NumCheck
    local EnumCheck = lib.EnumCheck

    local param = Values:insert_into(enc) -- main barcode parameter
    local check = self.parameter_control  -- main parameter controls data

    local mm = 186467 -- 1 mm in scaled point (sp)
    -- module width
    -- standard module is 0.33 mm but it can vary from 0.264 to 0.66mm
    param.module = 0.33*mm -- (mm to sp) X dimension
    check.module = NumCheck:new(0.33*mm, {min = 0.264*mm, max = 0.660*mm})
    -- barcode height
    param.height = 11*mm -- (mm to sp)
    check.height = NumCheck:new(11*mm, {min = 5*mm})
    -- quite zone
    param.quite_zone_factor_left = 7 -- module width
    check.quite_zone_factor_left = NumCheck:new(7, {min = 7, max = 12})
    param.quite_zone_factor_right = 5
    check.quite_zone_factor_right = NumCheck:new(5, {min = 5})

    -- text_vertical_gap_factor
    param.text_vertical_gap_factor = 1.5 -- module width
    check.text_vertical_gap_factor = NumCheck:new(1.5, {min = 0, isopen=true})
    -- text yes or not
    param.text_enabled = true
    check.text_enabled = BoolCheck:new(param.text_enabled)

    param.text_placement = "top"
    check.text_placement = EnumCheck:new(param.text_placement, {"top","bottom"})
end

-- factory method, work with an encoder object to
-- process parameters eventually passed by the user
-- and initialize the start/stop Vbar object
-- return <error message> or nil if all is OK
function Ean2.initialize(_, enc, t_option)
    local vl = enc.parameter_value
    if t_option then
        if type(t_option) ~= "table" then
            return "Table expected, got other data type"
        end
        local ck = enc.parameter_control
        -- the parameter update must be ordered as follows
        -- for first check the module with:
        if t_option.module then
            local mod = t_option.module
            if ck:isOk("module", mod) then
                vl.module = mod
            else
                return "Incorrect module value"
            end
            t_option.module = nil
        end
        -- then the others
        for p, v in pairs(t_option) do
            if ck:isOk(p, v, vl) then
                assert(vl[p], "Parameter name not found")
                vl[p] = v
            else
                return "Incorrect parameter value"
            end
        end
    end
    -- symbol's representation
    local mod  = vl.module
    local Vbar = enc.libgeo.Vbar
    -- build Vbar object for the start/stop symbol
    enc.vbar_start  = Vbar:from_int_revstep(enc.symb_Start, mod)
    enc.vbar_sep    = Vbar:from_int_revstep(enc.symb_Sep, mod, false)
    enc.vbar_symbol = {} -- dynamic loading
end


-- constructor

-- costructor: from an array of digits
-- -> object, err_message
function Ean2:from_intarray(array)
    if not array then
        return nil, "Mandatory arg"
    end
    if #array ~= 2 then
        return nil, "Wrong number of digits in the array (2 expected)"
    end
    for i = 1,2 do
        local n = array[i]
        if not type(n) == "number" then
            return nil, "An element of the array is not a number"
        end
        if n < 0 or n > 9 then
            return nil, "Array of one-digit numbers is required"
        end
        if (n - math.floor(n)) ~= 0 then
            return nil, "Not an integer number"
        end
    end

    local o = { -- build the Ean2 object
        code_n1 = array[1], -- array of 2 digits
        code_n2 = array[2],
    }
    setmetatable(o, self)
    encode_symbol(o)
    return o, nil
end

-- costructor
function Ean2:from_int(n)
    if not n then
        return nil, "Mandatory arg"
    end
    if n < 0 or n > 99 then return nil, "Out of range number" end
    if (n - math.floor(n)) ~= 0 then
        return nil, "Not an integer number"
    end
    local n2 = n % 10
    local n1 = (n - n2)/10
    local o = { -- build the Ean2 object
        code_n1 = n1,
        code_n2 = n2,
    }
    setmetatable(o, self)
    encode_symbol(o)
    return o, nil
end



-- costructor: from a string
-- string.utfvalues() is a LuaTeX only function
function Ean2:from_string(s)
    if s == "" then return nil, "Empty string (for zero type '0' or '00')" end
    local symb = {}
    for cp in string.utfvalues(s) do
        if cp < 48 or cp > 57 then -- only digit
            local fmt = "The char '%d' is not a digits (from 0 to 9 char)"
            return nil, string.format(fmt, cp)
        end
        symb[#symb+1] = cp - 48
    end
    if #symb > 2 then return nil, "Too many digits" end
    if #symb == 1 then
        symb[2] = symb[1]
        symb[1] = 0
    end
    local o = { -- build the Ean2 object
        code_n1 = symb[1],
        code_n2 = symb[2],
    }
    setmetatable(o, self)
    encode_symbol(o)
    return o, nil
end

-- override the superclass method set_parameter()
-- because parameters are not an indipendent set
-- syntax:
-- :set_parameter{key = value, key = value, ...}
-- :set_parameter(key, value)
function Ean2:set_parameter(arg1, arg2)
    -- process the args
    local targ
    if type(arg1) == "table" then
        if type(arg2) ~=nil then
            return nil, "Further argument not allowed"
        end
        targ = arg1
    elseif type(arg1) == "string" then
        if type(arg2) == nil then
            return nil, "Second argument expected as a value"
        end
        targ = {}
        targ[arg1] = arg2
    end
    -- check all the parameters' name
    local param = self.parameter_value
    for p, _ in pairs(targ) do
        if not param[p] then
            return nil, "Invalid parameter name"
        end
    end
    -- get the reference to the param value local table
    local pv = rawget(self, "parameter_value")
    if not pv then
        local Values = self.libctrl.Values
        pv = Values:insert_into(self)
    end
    local ck = self.parameter_control
    local rebuild_vbar = false -- set to true if the module/ratio change
    -- the parameter update must be ordered as follows:
    -- for first, check the module with
    if targ.module then
        local mod = targ.module
        if ck:isOk("module", mod) then
            pv.module = mod -- access to parameter value local table
        end
        targ.module = nil
        rebuild_vbar = true
    end
    -- then the others
    for p, v in pairs(targ) do
        if ck:isOk(p, v, pv) then
            pv[p] = v
        end
    end
    if rebuild_vbar then -- rebuild vbars if necessary
        local pval = self.parameter_value
        local mod = pval.module

        local vb = rawget(self, "vbar_symbol")
        if vb then -- rebuild encoder's vbar
            for c, ovbars in pairs(vb) do
                ovbars:regen(mod)
            end
        else
            local Values = self.libctrl.Values
            vb = Values:insert_into(self, "vbar_symbol")
            local Vbar = self.libgeo.Vbar
            -- create start/sep symbol
            vb.vbar_start = Vbar:from_int_revstep(self.symb_Start, mod)
            vb.vbar_sep   = Vbar:from_int_revstep(self.symb_Sep, mod, false)
            -- build Vbar locally
            local s1, s2 = self.code_s1, self.code_s2
            local n1 = self.symb_Def[s1]
            vb[s1] = Vbar:from_int_revstep(n, mod, false)
            local n2 = self.symb_Def[s2]
            vb[s2] = Vbar:from_int_revstep(n, mod, false)
        end
    end
    return self
end


-- Drawing in the provided driver channel the barcode elements
-- tx, ty is the optional traslating vector
-- the function return the canvas reference to accomplish chaining
function Ean2:draw_to_canvas(canvas, tx, ty)
    local param = self.parameter_value
    local mod = param.module
    local ax, ay = param.ax, param.ay
    local w, h = 20*mod, param.height
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local y1 = y0 + h

    local xpos = x0 -- current insertion x-coord
    -- draw the start symbol
    local start = self.vbar_start
    start:draw_to_canvas(canvas, y0, y1, xpos)
    xpos = xpos + 4*mod

    -- draw the first digit
    local symb = self.vbar_symbol
    local vbs1 = symb[self.code_s1]
    vbs1:draw_to_canvas(canvas, y0, y1, xpos)
    xpos = xpos + 7*mod

    -- draw the separation symbol
    local sep = self.vbar_sep
    sep:draw_to_canvas(canvas, y0, y1, xpos)
    xpos = xpos + 2*mod

    -- draw the second digit
    local vbs2 = symb[self.code_s2]
    vbs2:draw_to_canvas(canvas, y0, y1, xpos)

    -- bounding box setting
    local qzleft = param.quite_zone_factor_left * mod
    local qzright = param.quite_zone_factor_right * mod
    --                 (       xmin, ymin,         xmax, ymax)
    canvas:bounding_box(x0 - qzleft,   y0, x1 + qzright,   y1)

    -- human readable text TODO:
    local Text = self.libgeo.Text
    -- local ygap = self.text_ygap_factor * mod
    -- local txt = Text:from_intarray(data, x1, y1 + ygap, 1, 0)
    -- canvas:add_text(txt)
end

return Ean2

--
