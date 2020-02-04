-- Code39 barcode encoder implementation
-- Copyright (C) 2020 Roberto Giacomelli
--
-- All dimensions must be in scaled point (sp)
-- every fields that starts with an undercore sign are intended as private

local Code39 = {
    _VERSION     = "code39 v0.0.5",
    _NAME        = "Code39",
    _DESCRIPTION = "Code39 barcode encoder",
}

Code39._symb_def = {-- symbol definition
    ["0"] = 112122111, ["1"] = 211112112, ["2"] = 211112211,
    ["3"] = 111112212, ["4"] = 211122111, ["5"] = 111122112,
    ["6"] = 111122211, ["7"] = 212112111, ["8"] = 112112112,
    ["9"] = 112112211, ["A"] = 211211112, ["B"] = 211211211,
    ["C"] = 111211212, ["D"] = 211221111, ["E"] = 111221112,
    ["F"] = 111221211, ["G"] = 212211111, ["H"] = 112211112,
    ["I"] = 112211211, ["J"] = 112221111, ["K"] = 221111112,
    ["L"] = 221111211, ["M"] = 121111212, ["N"] = 221121111,
    ["O"] = 121121112, ["P"] = 121121211, ["Q"] = 222111111,
    ["R"] = 122111112, ["S"] = 122111211, ["T"] = 122121111,
    ["U"] = 211111122, ["V"] = 211111221, ["W"] = 111111222,
    ["X"] = 211121121, ["Y"] = 111121122, ["Z"] = 111121221,
    ["-"] = 212111121, ["."] = 112111122, [" "] = 112111221,
    ["$"] = 111212121, ["/"] = 121112121, ["+"] = 121211121,
    ["%"] = 121212111,
}
Code39._star_def  = 112121121 -- '*' start/stop character

-- parameters definition
Code39._par_order = {
    "module",
    "ratio",
    "quietzone",
    "interspace",
    "height",
    "text_enabled",
    "text_vpos",
    "text_hpos",
    "text_gap",
    "text_star",
}
Code39._par_def = {}
local pardef = Code39._par_def

-- module main parameter
pardef.module = {
    -- Narrow element X-dimension is the width of the smallest element in a
    -- barcode symbol.
    -- The X-dimension impacts scan-ability. Within the allowed range, it is
    -- recommended to use the largest possible X-dimension that is consistent
    -- with label or form design.
    -- The module width (width of narrow element) should be at least 7.5 mils
    -- or 0.1905mm (a mil is 1/1000 inch).
    default    = 7.5 * 0.0254 * 186467, -- 7.5 mils (sp) unit misure,
    unit       = "sp", -- scaled point
    isReserved = true,
    fncheck    = function (self, mod, _) --> boolean, err
        if mod >= self.default then return true, nil end
        return false, "[OutOfRange] too small value for module"
    end,
}

pardef.ratio = {
    -- The "wide" element is a multiple of the "narrow" element and this
    -- multiple must remain the same throughout the symbol. This multiple can
    -- range between 2.0 and 3.0. Preferred value is 3.0.
    -- The multiple for the wide element should be between 2.0 and 3.0 if the
    -- narrow element is greater than 20 mils. If the narrow element is less
    -- than 20 mils (0.508mm), the multiple can only range between 2.0 and 2.2.
    default    = 2.0, -- the minimum
    unit       = "absolute-number",
    isReserved = true,
    fncheck    = function (self, ratio, tparcheck) --> boolean, err
        local mils = 0.0254 * 186467
        local mod = tparcheck.module
        local maxr; if mod < 20*mils then maxr = 2.2 else maxr = 3.0 end
        if ratio < 2.0 then
            return false, "[OutOfRange] too small ratio (min 2.0)"
        end
        if ratio > maxr then
            return false, "[OutOfRange] too big ratio (max "..maxr..")"
        end
        return true, nil
    end,
}

pardef.quietzone = {
    -- It is recommended to use the largest possible quiet zone, that is
    -- consistent with label or form design.
    -- Quiet zones must be at least 10 times the module width or 0.10 inches,
    -- whichever is larger. Default value (100 mils)
    default    = 2.54 * 186467, -- 0.1 inches equal to 100*mils
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck    = function (self, qz, tparcheck) --> boolean, err
        local mils = 0.0254 * 186467
        local mod = tparcheck.module
        local min = math.max(10*mod, 100*mils)
        if qz >= min then
            return true, nil
        end
        return false, "[OutOfRange] quietzone too small"
    end,
    fndefault = function(self, tck) --> default value respect to a set of param
        local mod = tck.module
        return math.max(10*mod, self.default)
    end,
}

pardef.interspace = { -- Intercharacter gap
    -- The intercharacter gap width (igw) is 5.3 times the module width (mw) if
    -- mw is less than 10 mils. If mw is 10 mils or greater, the value for igw
    -- is 3mw or 53 mils, whichever is greater. However, for quality printers,
    -- igw often equals mw.
    default    = 7.5 * 0.0254 * 186467, -- 1 module, for quality printer
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck    = function (self, igw, tparcheck) --> boolean, err
        local mod = tparcheck.module
        if igw >= mod then return true, nil end
        return false, "[OutOfRange] interspace too small"
    end,
    fndefault = function(self, tck) --> default value respect to a set of param
        return tck.module
    end,
}

pardef.height = {
    -- To enhance readability, it is recommended that the barcode be designed
    -- to be as tall as possible, taking into consideration the aspects of label
    -- and forms design.
    -- The height should be at least 0.15 times the barcode's length or 0.25 inch.
    default    = 8 * 186467, -- 8 mm -- TODO: better assessment for symbol length
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck = function (self, h, _) --> boolean, err
        local mils = 0.0254 * 186467
        if h >= 250*mils then return true, nil end
        return false, "[OutOfRange] height too small"
    end,
}

-- text yes or not
pardef.text_enabled = { -- boolean type
    -- enable/disable a text label upon the barcode symbol
    default    = true,
    isReserved = false,
    fncheck    = function (self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value"
        end
    end,
}

-- define the text label vertical position
pardef.text_vpos = { -- enumeration
    default    = "bottom",
    isReserved = false,
    policy_enum = {
        top    = true, -- place text at the top of symbol
        bottom = true, -- place text under the symbol
    },
    fncheck    = function (self, e, _) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.policy_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enumeration value '"..e.."' not found"
        end
    end,
}

-- define the text label horizontal position
pardef.text_hpos = { -- enumeration
    default    = "left",
    isReserved = false,
    policy_enum = {
        left = true,
        center = true,
        right = true,
        spaced = true,
    },
    fncheck    = function (self, e, _) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.policy_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enumeration value '"..e.."' not found"
        end
    end,
}

-- vertical dimension between symbol and text
pardef.text_gap = {
    default    = 2.2 * 65536, -- 2.2 pt
    isReserved = false,
    unit       = "em", --> TODO: please put this under further analisys asap
    fncheck    = function(self, g, _) --> boolean, err
        if type(g) == "number" then
            if g > 0 then
                return true, nil
            else
                return false, "[OptErr] negative number"
            end
        else
            return false, "[TypeErr] not valid type for gap opt"
        end
    end,
}

-- star character appearing
pardef.text_star = {
    default    = false,
    isReserved = false,
    fncheck    = function(_self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value"
        end
    end,
}

-- configuration function
function Code39:_config() --> ok, err
    -- build Vbar object for the start/stop symbol
    local mod, ratio = self.module, self.ratio
    local n_star = self._star_def
    local Vbar = self._libgeo.Vbar -- Vbar class
    self._vbar = {['*'] = Vbar:from_int_revpair(n_star, mod, mod*ratio)}
    return true, nil
end

-- overriding Barcode method
function Code39:_check_char(c) --> elem, err
    if type(c) ~= "string" or #c ~= 1 then
        return nil, "[ArgErr] invalid char"
    end
    local symb_def = self._symb_def
    local n = symb_def[c]
    if not n then
        local fmt = "[ArgErr] '%s' is not a valid Code 39 symbol"
        return nil, string.format(fmt, c)
    end
    return c, nil
end

-- overriding Barcode method
function Code39:_check_digit(n) --> elem, err
    if type(n) ~= "number" then
        return nil, "[ArgErr] not a number"
    end
    if n < 0 or n > 9 then
        return nil, "[ArgErr] not a digit"
    end
    return string.char(n + 48), nil
end

function Code39:_finalize() --> ok, err
    local v = assert(self._code_data, "[InternalErr] '_code_data' field is nil")
    local vbar = self._vbar
    local g_Vbar = self._libgeo.Vbar
    local mod, ratio = self.module, self.ratio
    local symb_def = self._symb_def
    for _, c in ipairs(v) do
        if not vbar[c] then
            local n1 = symb_def[c]
            vbar[c] = g_Vbar:from_int_revpair(n1, mod, mod*ratio)
        end
    end
    return true, nil
end

-- tx, ty is an optional translator vector
function Code39:append_ga(canvas, tx, ty) --> canvas
    local code       = self._code_data
    local ns         = self._code_len -- number of chars inside the symbol
    local mod        = self.module
    local ratio      = self.ratio
    local interspace = self.interspace
    local h          = self.height
    local xs         = mod*(6 + 3*ratio)
    local xgap       = xs + interspace
    local w          = xgap*(ns + 1) + xs -- (ns + 2)*xgap - interspace
    local ax, ay     = self.ax, self.ay
    local x0         = (tx or 0) - ax * w
    local y0         = (ty or 0) - ay * h
    local x1         = x0 + w
    local y1         = y0 + h
    local xpos       = x0
    local err
    err = canvas:start_bbox_group()
    assert(not err, err)
    local vbar = self._vbar
    -- start/stop symbol
    local term_vbar = vbar['*']
    -- draw start symbol
    err = canvas:encode_Vbar(term_vbar, xpos, y0, y1)
    assert(not err, err)
    for _, c in ipairs(code) do -- draw code symbols
        xpos = xpos + xgap
        local vb = vbar[c]
        err = canvas:encode_Vbar(vb, xpos, y0, y1)
        assert(not err, err)
    end
    -- draw stop symbol
    err = canvas:encode_Vbar(term_vbar, xpos + xgap, y0, y1)
    assert(not err, err)
    -- bounding box setting
    local qz = self.quietzone
    err = canvas:stop_bbox_group(x0 - qz, y0, x1 + qz, y1)
    assert(not err, err)
    -- check height as the minimum of 15% of length
    -- TODO: message could warn the user
    -- if 0.15 * w > h then
        -- message("The height of the barcode is to small")
    -- end
    if self.text_enabled then -- human readable text
        local chars; if self.text_star then
            chars = {"*"}
            for _, c in ipairs(code) do
                chars[#chars + 1] = c
            end
            chars[#chars + 1] = "*"
        else
            chars = {}
            for _, c in ipairs(code) do
                chars[#chars + 1] = c
            end
        end
        local Text = self._libgeo.Text
        local txt  = Text:from_chars(chars)
        -- setup text position
        local txt_vpos = self.text_vpos
        local txt_gap = self.text_gap
        local ypos, tay; if txt_vpos == "top" then  -- vertical setup
            ypos = y1 + txt_gap
            tay = 0.0
        elseif txt_vpos == "bottom" then
            ypos = y0 - txt_gap
            tay = 1.0
        else
            error("[IntenalErr] text vertical placement option is wrong")
        end
        local txt_hpos = self.text_hpos
        if txt_hpos == "spaced" then -- horizontal setup
            local xaxis = x0
            if not self.text_star then
                xaxis = xaxis + xgap
            end
            xaxis = xaxis + xs/2
            err = canvas:encode_Text_xspaced(txt, xaxis, xgap, ypos, tay)
            assert(not err, err)
        else
            local xpos, tax
            if txt_hpos == "left" then
                xpos = x0
                tax = 0.0
            elseif txt_hpos == "center" then
                xpos = (x1 + x0)/2
                tax = 0.5
            elseif txt_hpos == "right" then
                xpos = x1
                tax = 1.0
            else
                error("[InternalErr] wrong option for text_pos")
            end
            err = canvas:encode_Text(txt, xpos, ypos, tax, tay)
            assert(not err, err)
        end
    end
    return canvas
end

return Code39
--