
-- Barcode abstract class
-- Copyright (C) 2019 Roberto Giacomelli
-- Please see LICENSE.TXT

local Barcode = {
    _VERSION     = "Barcode v0.0.5",
    _NAME        = "Barcode",
    _DESCRIPTION = "Barcode abstract class",
}
Barcode.__index = Barcode

-- barcode_type/submodule name
Barcode._available_enc = {-- keys must be lowercase
    code39  = "lib-barcode.code39",
    code128 = "lib-barcode.code128",
    ean     = "lib-barcode.ean",
    i2of5   = "lib-barcode.i2of5", -- Interleaved 2 of 5
}
Barcode._builder_instances = {} -- encoder builder instances repository

-- common parameters to all the barcode objects
Barcode._super_par_def = {}
local pardef = Barcode._super_par_def

-- set an Anchor point (ax, ay) relatively to the barcode bounding box
-- without considering any text object
-- ax = 0, ay = 0 is the lower left corner of the symbol
-- ax = 1, ay = 1 is the upper right corner of the symbol
Barcode.ax = 0.0
pardef.ax = {
    default = 0.0,
    unit = "sp", -- scaled point
    isReserved = false,
    order = 1,
    fncheck = function (self, ax, _) --> boolean, err
        if ax >= 0.0 and ax <= 1.0 then return true, nil end
        return false, "[OutOfRange] 'ax' out of [0, 1] interval"
    end,
}
Barcode.ay = 0.0
pardef.ay = {
    default = 0.0,
    unit = "sp", -- scaled point
    isReserved = false,
    order = 2,
    fncheck = function (self, ay, _) --> boolean, err
        if ay >= 0.0 and ay <= 1.0 then return true, nil end
        return false, "[OutOfRange] 'ay' out of [0, 1] interval"
    end,
}

-- Barcode.bbox_to_quietzone -- under evaluation

-- Barcode methods

-- stateless iterator troughtout the ordered parameters collection
local function p_iter(state, i)
    i = i + 1
    local t = state[i]
    if t then
        return i, t
    end
end

-- main iterator on parameter definitions
function Barcode:param_ord_iter()
    local state = {}
    -- append family parameter
    local p2_family  = self._par_def -- base family parameters
    local fam_len = 0
    if p2_family then
        for pname, pdef in pairs(p2_family) do
            state[pdef.order] = {
                pname   = pname,
                pdef    = pdef,
                isSuper = false,
            }
            fam_len = fam_len + 1
        end
        assert(fam_len == #state)
    end
    -- append the variant parameters
    local var_len = 0
    local var = self._variant
    if var then -- specific variant parameters
        local p2_variant = assert(self._par_def_variant[var])
        for pname, pdef in pairs(p2_variant) do
            if state[pname] then
                error("[InternalErr] overriding paramenter '"..pname.."'")
            end
            state[pdef.order + fam_len] = {
                pname   = pname,
                pdef    = pdef,
                isSuper = false,
            }
            var_len = var_len + 1
        end
        assert(fam_len + var_len == #state)
    end
    -- append the super class parameter to the iterator state
    local p1 = self._super_par_def
    local super_len = 0
    for pname, pdef in pairs(p1) do
        if state[pname] then
            error("[InternalError] overriding paramenter name '"..pname.."'")
        end
        state[fam_len + var_len + pdef.order] = {
            pname = pname,
            pdef  = pdef,
            isSuper = true,
        }
        super_len = super_len + 1
    end
    assert(super_len + fam_len + var_len == #state)
    return p_iter, state, 0
end

-- encoder costructor
-- Symbology can be a family with many variants. This is represented
-- in the first argument with a <family>-<variant> syntax.
-- i.e. when bc_type is the string "ean-13", "ean" is the barcode
-- family and "13" is the variant.
-- For whose barcodes that do not have variants, bc_type is simple <encoder>
-- such as for "code128" encoder
-- id_enc is an optional identifier useful to retrive an encoder reference later
-- opt    is an optional table with the user-defined parameters
--
function Barcode:new_encoder(bc_type, id_enc, opt) --> object, err
    -- argument checking
    if type(bc_type) ~= "string" then
        return nil, "[ArgErr] 'bc_type' is not a string"
    end
    local pdash = string.find(bc_type, "-")
    local family, variant
    if pdash then
        family  = string.sub(bc_type, 1, pdash - 1)
        variant = string.sub(bc_type, pdash + 1)
    else
        family = bc_type
    end
    local av_enc = self._available_enc
    if not av_enc[family] then -- is the barcode type a real module?
        return nil, "[Err] barcode type '"..family.."' not found"
    end
    if id_enc == nil then
        id_enc = (variant or "") .. "_noname"
    elseif type(id_enc) ~= "string" then
        return nil, "[ArgErr] provided 'id_enc' is not a string"
    end
    if type(opt) == "table" or opt == nil then
        opt = opt or {}
    else
        return nil, "[ArgErr] provided 'opt' is wrong"
    end
    local tenc = self._builder_instances
    local builder;
    if tenc[family] then -- is the encoder builder already loaded?
        builder = tenc[family]
    else -- loading the encoder builder
        local mod_path = av_enc[family]
        builder = require(mod_path)
        tenc[family] = assert(builder, "[InternalErr] module not found!")
        builder._enc_instances = {}
    end
    if builder._enc_instances[id_enc] then
        return nil, "[Err] 'id_enc' already present"
    end
    local enc = {} -- the new encoder
    enc.__index = enc
    enc._variant = variant
    setmetatable(enc, {
        __index = function(_, k)
            if builder[k] ~= nil then
                return builder[k]
            end
            return self[k]
        end
    })
    builder._enc_instances[id_enc] = enc
    -- param defition
    for _, tpar in enc:param_ord_iter() do
        local pname   = tpar.pname
        local pdef    = tpar.pdef
        local isSuper = tpar.isSuper
        local val = opt[pname] -- param = val
        if val ~= nil then
            local ok, err = pdef:fncheck(val, enc)
            if ok then
                enc[pname] = val
            else -- error!
                return nil, err
            end
        else
            -- load the default value of <pname>
            local def_val; if pdef.fndefault then
                def_val = pdef:fndefault(enc)
            else
                def_val = pdef.default
            end
            if not isSuper then
                enc[pname] = def_val
            end
        end
    end
    if enc.config then -- this must be called after the parameter definition
        enc:config(variant)
    end
    return enc, nil
end

-- retrive encoder object already created
-- 'name' is optional in case you didn't assign one to the encoder
function Barcode:enc_by_name(bc_type, name) --> <encoder object>, <err>
    if type(bc_type) ~= "string" then
        return nil, "[ArgErr] 'bc_type' must be a string"
    end
    local pdash = string.find(bc_type, "-")
    local family, variant
    if pdash then
        family  = string.sub(bc_type, 1, pdash - 1)
        variant = string.sub(bc_type, pdash + 1)
    else
        family = bc_type
    end
    local av_enc = self._available_enc
    if not av_enc[family] then -- is the barcode type a real module?
        return nil, "[Err] barcode type '"..family.."' not found"
    end
    local builder = self._builder_instances[family]
    if builder == nil then
        return nil, "[Err] enc builder '"..family.."' not loaded, use 'new_encoder()' method"
    end
    if name == nil then
        name = (variant or "") .. "_noname"
    elseif type(name) ~= "string" then
        return nil, "[ArgErr] 'name' must be a string"
    end
    local repo = builder._enc_instances
    local enc = repo[name]
    if enc == nil then
        return nil, "[Err] encoder '"..name.."' not found"
    else
        return enc, nil
    end
end

-- check a parameter set
-- this method check also reserved parameter
-- argments: {k=v, ...}, "default" | "current"
-- if ref is "default" parameters are checked with default values
-- if ref is "current" parameters are checked with current values
function Barcode:check_param(opt, ref) --> boolean, check report
    if type(opt) ~= "table" then
        return nil, "[ArgErr] opt is not a table"
    end
    if ref == nil then
        ref = "current"
    else
        if type(ref) ~= "string" then
            return nil, "[ArgErr] ref is not a string"
        end
        if (ref ~= "current") or (ref ~= "default") then
            return nil, "[ArgErr] ref can only be 'default' or 'current'"
        end
    end
    -- checking process
    local cktab  = {}
    local isOk   = true
    local err_rpt -- nil if no error
    for _, tpar in self:param_ord_iter() do
        local pname = tpar.pname
        local pdef  = tpar.pdef
        -- load the default value of <pname>
        local def_val; if pdef.fndefault then
            def_val = pdef:fndefault(cktab)
        else
            def_val = pdef.default
        end
        local val = opt[pname]
        if val ~= nil then
            local ok, err = pdef:fncheck(val, cktab)
            if ok then
                cktab[pname] = val
            else -- error!
                isOk = false
                if err_rpt == nil then err_rpt = {} end
                err_rpt[#err_rpt + 1] = {
                    param       = pname,
                    checked_val = val,
                    default_val = def_val,
                    isOk        = ok,
                    err         = err,
                }
            end
        end
        local v
        if ref == "current" then
            v = self[pname]
        else
            v = def_val
        end
        cktab[pname] = v
    end
    return isOk, err_rpt
end

-- restore to the default values all the parameter
-- (reserved parameters are unmodified so no need to restore it)
-- this need further investigation about the conseguence of a restore
-- that reset the parameter but "locally"
-- so this method must be considered experimental
function Barcode:restore_param() --> self :FIXME:
    for _, par in ipairs(self._par_id) do
        local pdef = self[par.."_def"]
        if not pdef.isReserved then
            self[par] = pdef.default
        end
    end
    return self
end

-- create a table with the information of the current barcode encoder
function Barcode:info() --> table
    local info = {
        name        = self._NAME,
        version     = self._VERSION,
        description = self._DESCRIPTION,
        param       = {},
    }
    local tpar   = info.param
    for _, pardef in self:param_ord_iter() do
        local id   = pardef.pname
        local pdef = pardef.pdef
        tpar[#tpar + 1] = {
            name       = id,
            descr      = nil, -- TODO:
            value      = self[id],
            isReserved = pdef.isReserved,
            unit       = pdef.unit,
        }
    end
    return info
end

-- make accessible by name parameter values
-- id: parameter identifier
function Barcode:get_param(id) --> value, err
    if type(id) ~= "string" then
        return nil, "[ArgErr] 'id' must be a string"
    end
    local pardef = self._par_def
    if not pardef[id] then
        return nil, "[Err] Parameter '"..id.."' doesn't exist"
    end
    local res = assert(self[id], "[InternalErr] parameter value unreachable")
    return res, nil
end

-- set a barcode parameter only if it is not reserved
-- arguments:
-- :set_param{key = value, key = value, ...}
-- :set_param(key, value)
function Barcode:set_param(arg1, arg2) --> boolean, err
    -- processing arguments
    local targ
    local isPair = true
    if type(arg1) == "table" then
        if arg2 ~= nil then
            return false, "[ArgErr] Further arguments not allowed"
        end
        targ = arg1
        isPair = false
    elseif type(arg1) == "string" then -- key/value
        if arg2 == nil then
            return false, "[ArgErr] 'value' as the second argument expected"
        end
        targ = {}
        targ[arg1] = arg2
    else
        return false, "[ArgErr] param name must be a string"
    end
    -- preparing to the checking process
    local cktab  = {}
    local ckparam = {}
    -- checking process
    for _, tpar in self:param_ord_iter() do
        local pname = tpar.pname
        local pdef  = tpar.pdef
        local val = targ[pname] -- par = val
        if val ~= nil then
            if pdef.isReserved then
                return false, "[Err] parameter '" .. pname ..
                    "' is reserved, create another encoder"
            end
            local ok, err = pdef:fncheck(val, cktab)
            if ok then
                cktab[pname] = val
                ckparam[pname] = val
            else -- error!
                return false, err
            end
        else -- no val in user option
            cktab[pname] = self[pname]
        end
    end
    for p, v in pairs(ckparam) do
        self[p] = v
    end
    return true, nil
end

return Barcode

--
