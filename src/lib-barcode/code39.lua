-- Code39 barcode encoder implementation
-- Copyright (C) 2019 Roberto Giacomelli
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
    order      = 1, -- the one first to be modified
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
    order      = 2,
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
    order      = 3,
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
    order      = 4,
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
    order      = 5,
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
    order      = 6,
    fncheck    = function (self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value"
        end
    end,
}

-- define a text label layout
pardef.text_pos = { -- enumeration
    default       = "bottom-left",
    isReserved    = false,
    order         = 7,
    text_pos_enum = { -- i.e. "center-top" or even "top-center" or simply "top"
        vpos = {"top", "bottom"},
        hpos = {"left", "center", "right", "spaced"},
    },
    fncheck       = function (self, e, _) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeErr] not a string" end
        local enum_vpos = self.text_pos_enum.vpos
        local enum_hpos = self.text_pos_enum.hpos
        local vkey = {}; for _, k in ipairs(enum_vpos) do vkey[k] = true end
        local hkey = {}; for _, k in ipairs(enum_hpos) do hkey[k] = true end
        -- parsing
        local p1 = e:find("-")
        if p1 then
            local s1 = e:sub(1, p1 - 1)
            local s2 = e:sub(p1 + 1)
            if vkey[s1] then
                if hkey[s2] then
                    return true, nil
                else
                    return false, "[Err] incorrect option"
                end
            elseif hkey[s1] then
                if vkey[s2] then
                    return true, nil
                else
                    return false, "[Err] incorrect option"
                end
            else
                return false, "[Err] option not found"
            end
        else -- single option
            if vkey[e] or hkey[e] then
                return true, nil
            else
                return false, "[Err] option not found"
            end
        end
    end,
    fnparse = function (self, e, v, h) --> vopt, hopt
        local enum_vpos = self.text_pos_enum.vpos
        local enum_hpos = self.text_pos_enum.hpos
        local vkey = {}; for _, k in ipairs(enum_vpos) do vkey[k] = true end
        local hkey = {}; for _, k in ipairs(enum_hpos) do hkey[k] = true end
        -- parsing
        local p1 = e:find("-")
        if p1 then
            local s1 = e:sub(1, p1 - 1)
            local s2 = e:sub(p1 + 1)
            if vkey[s1] and hkey[s2] then
                v = s1
                h = s2
            elseif hkey[s1] and vkey[s2] then
                v = s2
                h = s1
            end
        else -- single option
            if vkey[e] then
                v = e
            elseif hkey[e] then
                h = e
            end
        end
        return v, h
    end
}

-- vertical dimension between symbol and text
pardef.text_gap = {
    default    = 2.2 * 65536, -- 2.2 pt
    isReserved = false,
    order      = 8,
    unit       = "em", --> TODO: please analyzing this asap
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
    order      = 9,
    fncheck    = function(self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value"
        end
    end,
}

-- configuration function
function Code39:config() --> ok, err
    -- build Vbar object for the start/stop symbol
    local mod, ratio = self.module, self.ratio
    local n_star = self._star_def
    local Vbar = self._libgeo.Vbar -- Vbar class
    self._vbar = {['*'] = Vbar:from_int_revpair(n_star, mod, mod*ratio)}
    return true, nil
end

function Code39:from_chars(symb, opt) --> symbol, err
    if type(symb) ~= "table" then return nil, "[ArgErr] symb is not a table" end
    if #symb == 0 then return nil, "[ArgErr] symb is an empty array" end
    -- loading the Vbar definitions on the fly (dynamic loading)
    local g_Vbar     = self._libgeo.Vbar
    local vbar       = self._vbar
    local symb_def   = self._symb_def
    local mod, ratio = self.module, self.ratio
    -- create every vbar object needed for the symbol if not already loaded
    for _, s in ipairs(symb) do
        local n = symb_def[s]
        if not n then
            local fmt = "[Err] '%s' is not a valid Code 39 symbol"
            return nil, string.format(fmt, s)
        end
        if not vbar[s] then
            vbar[s] = g_Vbar:from_int_revpair(n, mod, mod*ratio)
        end
    end
    -- build the Code39 symbol object
    local obj = {
        code = symb, -- array of chars
    }
    setmetatable(obj, self)
    if opt ~= nil then
        if type(opt) ~= "table" then
            return nil, "[ArgErr] opt is not a table"
        else
           local ok, err = obj:set_param(opt)
           if not ok then
               return nil, err
           end
        end
    end
    return obj, nil
end

-- symbol costructors
-- return the symbol object or an error message
function Code39:from_string(s, opt) --> symbol, err
    if type(s) ~= "string" then return nil, "[ArgErr] not a string" end
    if #s == 0 then return nil, "[ArgErr] Empty string" end
    local symb_def = self._symb_def
    local chars = {}
    for c in string.gmatch(s, ".") do
        local n = symb_def[c]
        if not n then
            local fmt = "[Err] '%s' is not a valid Code 39 symbol"
            return nil, string.format(fmt, c)
        end
        chars[#chars+1] = c
    end
    return self:from_chars(chars, opt)
end

-- tx, ty is an optional translator vector
function Code39:append_ga(canvas, tx, ty) --> canvas
    local code       = self.code
    local ns         = #code -- number of chars inside the symbol
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
    local err = canvas:start_bbox_group(); assert(not err, err)
    local vbar = self._vbar
    -- start/stop symbol
    local term_vbar = vbar['*']
    -- draw start symbol
    local _, err = term_vbar:append_ga(canvas, y0, y1, xpos)
    assert(not err, err)
    -- draw code symbol
    for _, c in ipairs(code) do
        xpos = xpos + xgap
        local vb = vbar[c]
        local _, err = vb:append_ga(canvas, y0, y1, xpos)
        assert(not err, err)
    end
    -- draw stop symbol
    local _, err = term_vbar:append_ga(canvas, y0, y1, xpos + xgap)
    assert(not err, err)
    -- bounding box setting
    local qz = self.quietzone
    local err = canvas:stop_bbox_group(x0 - qz, y0, x1 + qz, y1)
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
        local pardef = self._par_def
        local pdef = pardef.text_pos
        local default = pdef.default
        local vopt_d, hopt_d = pdef:fnparse(default)
        local vo, ho = pdef:fnparse(self.text_pos, vopt_d, hopt_d)
        local txtgap = self.text_gap
        local ypos, tay; if vo == "top" then  -- vertical setup
            ypos = y1 + txtgap
            tay = 0.0
        elseif vo == "bottom" then
            ypos = y0 - txtgap
            tay = 1.0
        else
            error("[IntenalErr] text vertical placement option is wrong")
        end
        if ho == "spaced" then -- horizontal setup
            local xaxis = x0
            if not self.text_star then
                xaxis = xaxis + xgap
            end
            xaxis = xaxis + xs/2
            local _, err = txt:append_ga_xspaced(canvas, xaxis, xgap, tay, ypos)
            assert(not err, err)
        else
            local xpos, tax
            if ho == "left" then
                xpos = x0
                tax = 0.0
            elseif ho == "center" then
                xpos = (x1 - x0)/2
                tax = 0.5
            elseif ho == "right" then
                xpos = x1
                tax = 1.0
            else
                error("[InternalErr] wrong option for text_pos")
            end
            local _, err = txt:append_ga(canvas, xpos, ypos, tax, tay)
            assert(not err, err)
        end
    end
    return canvas
end

return Code39

--