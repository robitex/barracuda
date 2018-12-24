
-- Barcode abstract class
-- Copyright (C) 2018 Roberto Giacomelli

local Barcode = {
    _VERSION     = "Barcode v0.0.3",
    _NAME        = "Barcode",
    _DESCRIPTION = "Barcode abstract class",
}
Barcode.__index = Barcode

-- barcode_type/submodule name
Barcode._available_enc = {-- keys must be lowercase
    code39  = "lib-barcode.code39",
    code128 = "lib-barcode.code128",
    ean13   = "lib-barcode.ean13",
    ean5    = "lib-barcode.ean5",
    ean2    = "lib-barcode.ean2",
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

-- a fast and useful ordered stateless iterator troughtout parameter collection
local function p_iter(state, i)
    i = i + 1
    local t = state[i]
    if t then
        return i, t.pname, t.pdef
    end
end
-- main iterator function
function Barcode:param_ord_iter()
    local p1, p2 = self._super_par_def, self._par_def
    local p2len = 0
    local state = {}
    for pname, pdef in pairs(p2) do
        state[pdef.order] = {
            pname = pname,
            pdef  = pdef,
        }
        p2len = p2len + 1
    end
    assert(p2len == #state)
    -- append the super class parameter to the iterator state
    local p1len = 0
    for pname, pdef in pairs(p1) do
        if state[pname] then
            error("[InternalError] overriding paramenter '"..pname.."'")
        end
        state[p2len + pdef.order] = {
            pname = pname,
            pdef  = pdef,
        }
        p1len = p1len + 1
    end
    return p_iter, state, 0
end

-- encoder costructor
function Barcode:new_encoder(bc_type, id_enc, opt) --> object, err
    -- argument checking
    if type(bc_type) ~= "string" then
        return nil, "[ArgErr] 'bc_type' is not a string"
    end
    local av_enc = self._available_enc
    if not av_enc[bc_type] then -- is the barcode type a real module?
        return nil, "[Err] barcode type '"..bc_type.."' not found"
    end
    if type(id_enc) == "string" or id_enc == nil then
        id_enc = id_enc or "_noname"
    else
        return nil, "[ArgErr] provided 'id_enc' is wrong"
    end
    if type(opt) == "table" or opt == nil then
        opt = opt or {}
    else
        return nil, "[ArgErr] provided 'opt' is wrong"
    end
    local tenc = self._builder_instances
    local builder;
    if tenc[bc_type] then -- is the encoder builder already loaded?
        builder = tenc[bc_type]
    else -- loading the encoder builder
        local mod_path = av_enc[bc_type]
        builder = require(mod_path)
        tenc[bc_type] = assert(builder, "[InternalErr] module not found!")
        builder._enc_instances = {}
    end
    if builder._enc_instances[id_enc] then
        return nil, "[Err] 'id_enc' already present"
    end
    local enc = {} -- the new encoder
    enc.__index = enc
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
    for _, pname, pdef in enc:param_ord_iter() do
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
            enc[pname] = def_val
        end
    end
    if enc.config then -- this must be called after the parameter defintion
        enc:config()
    end
    return enc, nil
end

-- retrive encoder object already created
function Barcode:enc_by_name(bc_type, name) --> <encoder object>, <err>
    if type(bc_type) ~= "string" then
        return nil, "[ArgErr] 'bc_type' must be a string"
    end
    local av_enc = self._available_enc
    if not av_enc[bc_type] then -- is the barcode type a real module?
        return nil, "[Err] barcode type '"..bc_type.."' not found"
    end
    local builder = self._builder_instances[bc_type]
    if builder == nil then
        return nil, "[Err] enc builder '"..bc_type.."' not loaded, use 'new_encoder()'"
    end
    if name == nil then
        name = "_noname"
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
-- syntax:
-- :set_param{key = value, key = value, ...}
-- :set_param({k=v, ...}, "default"|"current")
-- if ref is "default" parameters are checked with defualkt values
-- if ref is "current" parameters are checked with the current values
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
    -- preparing to the checking process
    local cktab  = {}
    local isOk   = true
    local check_rpt
    -- checking process
    for _, pname, pdef in self:param_ord_iter() do
        -- load the default value of <pname>
        local def_val; if pdef.fndefault then
            def_val = pdef:fndefault(cktab)
        else
            def_val = pdef.default
        end
        local val = targ[pname] -- par = val
        if val ~= nil then
            local ok, err = pdef:fncheck(val, cktab)
            if ok then
                cktab[pname] = val
            else -- error!
                isOk = false
                if check_rpt == nil then check_rpt = {} end
                check_rpt[#check_rpt + 1] = {
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
    return isOk, check_rpt
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
    for _, id, pdef in self:param_ord_iter() do
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

-- set parameters only if it is not reserved
-- syntax:
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
    for _, pname, pdef in self:param_ord_iter() do
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
