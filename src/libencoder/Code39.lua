-- Code39 barcode encoder implementation
--
-- All dimensions must be in scaled point (sp)
-- every fields that starts with an undercore sign are intended as private

-- Code39_factory is an "encoder builder". It can build a concrete
-- Code39 encoder. Read the documentation for more info about the code
-- implementation.

local Code39_factory = {
    _VERSION     = "code39 v0.0.1",
    _NAME        = "Code39",
    _DESCRIPTION = "Code39 barcode encoder",
}

Code39_factory._enc_instance = {} -- encoder reference archive
Code39_factory._symb_def = {-- symbol definition
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
Code39_factory._star_def  = 112121121 -- '*' start/stop character

-- parameters definition
Code39_factory._par_def = {
    module = {
        -- Narrow element X-dimension is the width of the smallest element in a
        -- barcode symbol.
        -- The X-dimension impacts scan-ability. Within the allowed range, it is
        -- recommended to use the largest possible X-dimension that is consistent
        -- with label or form design.
        -- The module width (width of narrow element) should be at least 7.5 mils
        -- or 0.1905mm (a mil is 1/1000 inch).
        default = 7.5 * 0.0254 * 186467, -- 7.5 mils (sp) unit misure,
        unit = "sp", -- scaled point
        isReserved = true,
        order = 1, -- the the first to be modified
        fncheck = function (mod, _) --> boolean, err
            local mils = 0.0254 * 186467
            if mod >= 7.5*mils then return true, nil end
            return nil, "[OutOfRange] too small value for module"
        end,
    },
    ratio = {
        -- The "wide" element is a multiple of the "narrow" element and this
        -- multiple must remain the same throughout the symbol. This multiple can
        -- range between 2.0 and 3.0. Preferred value is 3.0.
        -- The multiple for the wide element should be between 2.0 and 3.0 if the
        -- narrow element is greater than 20 mils. If the narrow element is less
        -- than 20 mils (0.508mm), the multiple can only range between 2.0 and 2.2.
        default = 2.0, -- the minimum
        unit = "absolute-number",
        isReserved = true,
        order = 2,
        fncheck = function (ratio, tparcheck) --> boolean, err
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
    },
    quietzone = {
        -- It is recommended to use the largest possible quiet zone, that is
        -- consistent with label or form design.
        -- Quiet zones must be at least 10 times the module width or 0.10 inches,
        -- whichever is larger. Default value (100 mils)
        default = 0.254 * 186467, -- 0.1 inches equal to 100*mils
        unit = "sp", -- scaled point
        isReserved = false,
        order = 3,
        fncheck = function (qz, tparcheck) --> boolean, err
            local mils = 0.0254 * 186467
            local mod = tparcheck.module
            local min = math.max(10*mod, 100*mils)
            if qz >= min then
                return true, nil
            end
            return false, "[OutOfRange] quietzone too small"
        end,
    },
    interspace = { -- Intercharacter gap
        -- The intercharacter gap width (igw) is 5.3 times the module width (mw) if
        -- mw is less than 10 mils. If mw is 10 mils or greater, the value for igw
        -- is 3mw or 53 mils, whichever is greater. However, for quality printers,
        -- igw often equals mw.
        default = 7.5 * 0.0254 * 186467, -- 1 module, for quality printer
        unit = "sp", -- scaled point
        isReserved = false,
        order = 4,
        fncheck = function (igw, tparcheck)
            local mod = tparcheck.module
            if igw >= mod then return true, nil end
            return false, "[OutOfRange] interspace too small"
        end,
    },
    height = {
        -- To enhance readability, it is recommended that the barcode be designed
        -- to be as tall as possible, taking into consideration the aspects of label
        -- and forms design.
        -- The height should be at least 0.15 times the barcode's length or 0.25 inch.
        default = 8 * 186467, -- 8 mm -- TODO: better assessment for symbol length
        unit = "sp", -- scaled point
        isReserved = false,
        order = 5,
        fncheck = function (h, _)
            local mils = 0.0254 * 186467
            if h >= 250*mils then return true, nil end
            return false, "[OutOfRange] height too small"
        end,
    },
}

-- other possible parameter
-- text-compact
-- text-up
-- text-down

-- text yes or not
-- param.text_enabled = true
-- check.text_enabled = BoolCheck:new(param.text_enabled)

-- decide if the start/stop char will be printed
-- param.text_startstop = false
-- check.text_startstop = BoolCheck:new(param.text_startstop)

-- param.text_placement = "bottom"
-- check.text_placement = EnumCheck:new(param.text_placement, {"top","bottom"})


-- parameter identifier array _par_id
Code39_factory._par_id = {}
local parid = Code39_factory._par_id
for id, tpar in pairs(Code39_factory._par_def) do
    parid[tpar.order] = id
end

-- init function
function Code39_factory:init(libgeo, bc_class)
    self._libgeo  = assert(libgeo, "[InternalErr] libgeo is nil")
    self._barcode = assert(bc_class, "[InternalErr] bc_class is nil")
    -- append the superclass parameter identifier
    local super_parid = bc_class._par_id
    local parid = self._par_id
    for _, id in ipairs(super_parid) do
        parid[#parid + 1] = id
    end
end


-- main factory function for Code39 encoders
-- enc_name  : encoder identifier in the Code39 namespace
-- user_param: a table with the user defined parameters for Code39 encoder class
function Code39_factory:new_encoder(enc_name, user_param) --> <encoder object>, <err>
    if type(enc_name) ~= "string" then
        return nil, "[ArgErr] enc_name, is not a string"
    end
    if enc_name == "" then
        return nil, "[ArgErr] empty string is not allowed for enc_name"
    end
    if string.match(enc_name, " ") then
        return nil, "[ArgErr] space char not allowed for enc_name"
    end
    if self._enc_instance[enc_name] then
        return nil, "[Err] enc_name also declared"
    end
    
    local enc = { -- the new encoder
        _NAME        = self._NAME,
        _VERSION     = self._VERSION,
        _DESCRIPTION = self._DESCRIPTION,
        _libgeo      = self._libgeo,   -- a reference to the geometric library
        _symb_def    = self._symb_def, -- reference to symbol definition table
        _par_id      = self._par_id,   -- array of parameter identifier
        _vbar        = {},             -- where we dynamically place vbar symbol
        _get_param_for_checking = function (o) return {module = o.module} end,
        
        -- symbol costructors
        -- return the symbol object or an error message
        from_string = function (o, s, opt) --> symbol, err
            if type(s) ~= "string" then return nil, "[ArgErr] not a string" end
            if #s == 0 then return nil, "[ArgErr] Empty string" end
            local chars = {}
            for c in string.gmatch(s, ".") do
                chars[#chars+1] = c
            end
            return o:from_chars(chars, opt)
        end,

        -- symbol costructor: from an array of chars
        -- return the symbol object or an error message
        from_chars = function (o, symb, opt)
            if type(symb) ~= "table" then
                return nil, "[ArgErr] symb is not a table"
            end
            if #symb == 0 then
                return nil, "[ArgErr] symb is an empty array"
            end
            -- loading the Vbar definitions on the fly (dynamic loading)
            local g_Vbar     = o._libgeo.Vbar
            local vbar       = o._vbar
            local symb_def   = o._symb_def
            local mod, ratio = o.module, o.ratio
            -- create every vbar object needed for symbol if not already present
            for _, s in ipairs(symb) do
                if not vbar[s] then
                    local n = symb_def[s]
                    if not n then
                        local fmt = "[Err] '%s' is not a valid Code 39 symbol"
                        return nil, string.format(fmt, s)
                    end
                    vbar[s] = g_Vbar:from_int_revpair(n, mod, mod*ratio)
                end
            end
            -- build the Code39 symbol object
            local obj = {
                code = symb, -- array of code chars
            }
            setmetatable(obj, o)
            return obj, nil
        end,
        -- 
        -- tx, ty is an optional translator vector
        append_graphic = function (o, canvas, tx, ty)
            local code = o.code
            local ns = #code -- number of chars inside the symbol
            local mod        = o.module
            local ratio      = o.ratio
            local interspace = o.interspace
            local h          = o.height
            local xs = mod*(6 + 3*ratio)
            local xgap = xs + interspace
            local w = xgap*(ns + 1) + xs -- (ns + 2) * xgap - interspace
            local ax, ay = o.ax, o.ay
            local x0 = (tx or 0) - ax * w
            local y0 = (ty or 0) - ay * h
            local x1 = x0 + w
            local y1 = y0 + h
            local xpos = x0
            canvas:start_bbox_group()
            -- start/stop symbol
            local term_vbar = o._vbar['*']
            -- draw start symbol
            term_vbar:append_graphic(canvas, y0, y1, xpos)

            -- draw code symbol
            for _, c in ipairs(code) do
                xpos = xpos + xgap
                local vb = o._vbar[c]
                vb:append_graphic(canvas, y0, y1, xpos)
            end
            -- draw stop symbol
            term_vbar:append_graphic(canvas, y0, y1, xpos + xgap)

            -- bounding box setting
            local qz = o.quietzone
            canvas:stop_bbox_group(x0 - qz, y0, x1 + qz, y1)

            -- check height as the minimum of 15% of length
            -- TODO: message function warning the user
            -- if 0.15 * w > h then
                -- message("The height of the barcode is to small")
            -- end
            -- TODO: text human readable
            return canvas
        end,
    }
    local pardef = self._par_def
    local p_ord = {}
    local i = 0
    for pk, tdef in pairs(pardef) do
        enc[pk.."_def"] = tdef -- copy a reference to the param definition table
        p_ord[tdef.order] = pk
        i = i + 1
    end
    assert(#p_ord == i)
    -- generate parameters value
    user_param = user_param or {}
    if type(user_param) ~= "table" then
        return nil, "[ArgErr] 'user_param' must be a table"
    end
    -- check and eventually set every parameter within user_param
    local cktab = { module = true }
    for _, par in ipairs(p_ord) do
        if user_param[par] then
            local val = user_param[par]
            local ok, err = pardef[par].fncheck(val, cktab)
            if ok then
                enc[par] = val
                if cktab[par] then cktab[par] = val end
            else
                return nil, err
            end
        else
            enc[par] = pardef[par].default
        end
        cktab[par] = enc[par]
    end
    -- build Vbar object for the start/stop symbol
    local mod, ratio = enc.module, enc.ratio
    local n_star = self._star_def
    local Vbar = self._libgeo.Vbar -- Vbar class
    enc._vbar = {['*'] = Vbar:from_int_revpair(n_star, mod, mod*ratio)}
    --save locally the encoder reference
    self._enc_instance[enc_name] = enc
    enc.__index = enc
    setmetatable(enc, self._barcode)
    return enc, nil
end



return Code39_factory

--
