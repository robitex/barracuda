
-- Barcode abstract class
-- Copyright (C) 2019 Roberto Giacomelli
-- Please see LICENSE.TXT for any legal information about present software

local Barcode = {
    _VERSION     = "Barcode v0.0.9",
    _NAME        = "Barcode",
    _DESCRIPTION = "Barcode abstract class",
}
Barcode.__index = Barcode

-- barcode_type/submodule name
Barcode._available_enc = {-- keys must be lowercase
    code39  = "lib-barcode.brcd-code39",  -- Code 39
    code128 = "lib-barcode.brcd-code128", -- Code128
    ean     = "lib-barcode.brcd-ean",     -- EAN family (ISBN, EAN8, etc)
    i2of5   = "lib-barcode.brcd-i2of5",   -- Interleaved 2 of 5
}
Barcode._builder_instances = {} -- encoder builder instances repository
Barcode._encoder_instances = {} -- encoder instances repository

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

-- Barcode.bbox_to_quietzone -- under assessment

-- Barcode methods

-- extract id from an encoder 'tree name'
local function ck_enc_name(treename) --> fam, var, name, err
    if not type(treename) == "string" then
        return nil, nil, nil, "[ArgErr] 'treename' must be a string"
    end
    if treename:find(" ") then
        return nil, nil, nil,
            "[ArgErr] spaces are not allowed in an encoder identifier"
    end
    local fam, var, name
    -- fam extraction
    local idash = treename:find("-")
    local icolon = treename:find(":")
    if idash then
        fam = treename:sub(1, idash - 1)
    else
        if icolon then
            fam = treename:sub(1, icolon - 1)
        else
            fam = treename
        end
    end
    if fam == "" then
        return nil, nil, nil, "[ArgErr] empty encoder id"
    end
    if idash then
        if icolon then
            var = treename:sub(idash + 1, icolon - 1)
        else
            var = treename:sub(idash + 1)
        end
        if var == "" then
            return nil, nil, nil, "[ArgErr] empty 'variant' encoder id"
        end
    end
    if icolon then
        name = treename:sub(icolon + 1)
        if name == "" then
            return nil, nil, nil, "[ArgErr] empty 'name' after colon"
        end
        if name:find("-") then
            return nil, nil, nil, "[ArgErr] the name mustn't contain a dash"
        end
        if name:find(":") then
            return nil, nil, nil, "[ArgErr] the name mustn't contain a colon"
        end
    end
    return fam, var, name
end

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
-- Symbology can be a family with many variants. This is represented by the
-- first argument 'tree_name' formatted as <family>-<variant>:<id>.
-- i.e. when 'tree_name' is the string "ean-13", "ean" is the barcode family and
-- "13" is its variant name.
-- For whose barcodes that do not have variants, 'treename' is simply the
-- encoder id such as in the case of "code128".
-- <id> is an optional identifier useful if there are more than one encoders of
-- the same type
-- 'opt' is an optional table with the user-defined parameters setting up
-- encoders
function Barcode:new_encoder(treename, opt) --> object, err
    -- argument checking
    local family, variant, enc_name, err = ck_enc_name(treename)
    if err then
        return err
    end
    local av_enc = self._available_enc
    local mod_path = av_enc[family]
    -- check family identifier
    if not mod_path then
        return nil, "[Err] barcode type '"..family.."' not found"
    end
    -- retrive/load the builder
    local builder
    local tenc = self._builder_instances
    if tenc[family] then -- is the encoder builder already loaded?
        builder = tenc[family]
    else -- loading the encoder builder
        builder = require(mod_path)
        tenc[family] = builder
    end
    -- check the variant identifier
    local av_var = builder._id_variant
    if av_var then
        if variant then
            if not av_var[variant] then
                local fmt = "[Err] family '%s' does not have '%s' variant"
                return nil, string.format(fmt, family, variant)
            end
        else
            return nil, "[Err] mandatory variant identifier in treename"
        end
    else
        if variant then
            return nil, "[Err] family '"..family.."' doesn't admit variant"
        end
    end
    -- check unique encoder identifier
    local enc_archive = self._encoder_instances
    if enc_archive[treename] then
        return nil, "[Err] duplicated encoder name"
    end
    if type(opt) == "table" or opt == nil then
        opt = opt or {}
    else
        return nil, "[ArgErr] provided 'opt' is not a table"
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
    enc_archive[treename] = enc
    -- parameters definition
    for _, tpar in enc:param_ord_iter() do
        local pname   = tpar.pname
        local pdef    = tpar.pdef
        local isSuper = tpar.isSuper
        local val = opt[pname] -- param = val
        if val ~= nil then
            local ok, perr = pdef:fncheck(val, enc)
            if ok then
                enc[pname] = val
            else -- parameter error!
                return nil, perr
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
        enc:config()
    end
    return enc, nil
end

-- retrive an encoder object already created
-- 'trename' is the special identifier of the encoder
function Barcode:enc_by_name(treename) --> <encoder object>, <err>
    -- argument checking
    local family, variant, enc_name, err = ck_enc_name(treename)
    if err then
        return nil, err
    end
    local enc = self._encoder_instances[treename]
    if enc then
        return enc, nil
    else
        return nil, "[Err] encoder '"..treename.."' not found"
    end
end

-- base methods common to all the encoders

-- for numeric only simbology
function Barcode:_check_char(c) --> elem, err
    if type(c) ~= "string" or #c ~= 1 then
        return nil, "[InternalErr] invalid char"
    end
    local n = string.byte(c) - 48
    if n < 0 or n > 9 then
        return nil, "[ArgErr] found a not digit char"
    end
    return n, nil
end
--
function Barcode:_check_digit(n) --> elem, err
    if type(n) ~= "number" then
        return nil, "[InternalErr] not a number"
    end
    if n < 0 or n > 9 then
        return nil, "[InternalErr] not a digit"
    end
    return n, nil
end

-- not empty string --> Barcode object
function Barcode:from_string(symb, opt) --> object, err
    assert(self._check_char, "[InternalErr] undefined _check_char() method")
    if type(symb) ~= "string" then
        return nil, "[ArgErr] 'symb' is not a string"
    end
    if #symb == 0 then
        return nil, "[ArgErr] 'symb' is an empty string"
    end
    local chars = {}
    local len = 0
    for c in string.gmatch(symb, ".") do
        local elem, err = self:_check_char(c)
        if err then
            return nil, err
        else
            chars[#chars+1] = elem
            len = len + 1
        end
    end
    -- build the barcode object
    local o = {
        _code_data = chars, -- array of chars
        _code_len = len, -- symbol lenght
    }
    setmetatable(o, self)
    if opt ~= nil then
        if type(opt) ~= "table" then
            return nil, "[ArgErr] 'opt' is not a table"
        else
            local ok, err = o:set_param(opt)
            if not ok then
                return nil, err
            end
        end
    end
    if o._finalize then
        local ok, e = o:_finalize()
        if not ok then return nil, e end
    end
    return o, nil
end

-- positive integer --> Barcode object
function Barcode:from_uint(n, opt) --> object, err
    assert(self._check_digit, "[InternalErr] undefined _check_digit() method")
    if type(n) ~= "number" then return nil, "[ArgErr] 'n' is not a number" end
    if n < 0 then return nil, "[ArgErr] 'n' must be a positive integer" end
    if n - math.floor(n) ~= 0 then
        return nil, "[ArgErr] 'n' is not an integer"
    end
    if opt ~= nil and type(opt) ~= "table" then
        return nil, "[ArgErr] 'opt' is not a table"
    end
    local digits = {}
    local i = 0
    if n == 0 then
        local elem, err = self:_check_digit(0)
        if err then
            return nil, err
        end
        digits[1] = elem
        i = 1
    else
        while n > 0 do
            local d = n % 10
            i = i + 1
            local elem, err = self:_check_digit(d)
            if err then
                return nil, err
            end
            digits[i] = elem
            n = (n - d) / 10
        end
        for k = 1, i/2  do -- reverse the array
            local d = digits[k]
            local h = i - k + 1
            digits[k] = digits[h]
            digits[h] = d
        end
    end
    -- build the barcode object
    local o = {
        _code_data = digits, -- array of digits
        _code_len = i, -- symbol lenght
    }
    setmetatable(o, self)
    if opt ~= nil then
        if type(opt) ~= "table" then
            return nil, "[ArgErr] 'opt' is not a table"
        else
            local ok, err = o:set_param(opt)
            if not ok then
                return nil, err
            end
        end
    end
    if o._finalize then
        local ok, e = o:_finalize()
        if not ok then return nil, e end
    end
    return o, nil
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
