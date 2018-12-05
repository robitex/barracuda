
-- barcode abstract class

local barcode = {
    _VERSION     = "Barcode v0.0.1",
    _NAME        = "Barcode",
    _DESCRIPTION = "Barcode abstract class",
}
barcode.__index = barcode

-- common fields

-- we need to know the ordered list of parameter identifier
-- primarly for :check_par() and :info() methods
barcode._par_id = {"ax", "ay",}

-- set an Anchor point (ax, ay) relatively to the barcode bounding box
-- without considering any text object
-- ax = 0, ay = 0 is the origin of the local axis system
-- ax = 1, ay = 1 is the upper right corner of the symbol
barcode.ax = 0.0
barcode.ax_def = {
    default = 0.0,
    unit = "sp", -- scaled point
    isReserved = false,
    order = 1,
    fncheck = function (ax, _) --> boolean, err
        if ax >= 0.0 and ax <= 1.0 then return true, nil end
        return false, "[OutOfRange] 'ax' out of [0, 1]"
    end,
}
barcode.ay = 0.0
barcode.ay_def = {
    default = 0.0,
    unit = "sp", -- scaled point
    isReserved = false,
    order = 2,
    fncheck = function (ay, _) --> boolean, err
        if ay >= 0.0 and ay <= 1.0 then return true, nil end
        return false, "[OutOfRange] 'ay' out of [0, 1]"
    end,
}

-- refers anchor to the bounding box that includes quietzone ???
-- barcode.bbox_to_quietzone



-- barcode methods

-- check a parameter before set it up
-- syntax:
-- :set_parameter{key = value, key = value, ...} --> boolean, check_table
-- :set_parameter(key, value)                    --> boolean, err_descr
-- this method check also reserved parameter
function barcode:check_param(arg1, arg2) --> boolean, checkresult|err_descr
    -- processing arguments
    local targ
    local isPair = true
    if type(arg1) == "table" then
        if type(arg2) ~= nil then
            return nil, "[ArgErr] Further arguments not allowed"
        end
        targ = arg1
        isPair = false
    elseif type(arg1) == "string" then -- key/value
        if type(arg2) == nil then
            return nil, "[ArgErr] 'value' as the second argument expected"
        end
        targ = {}
        targ[arg1] = arg2
    end
    
    local parid = self._par_id
    local cktab = self._get_param_checking_table()
    local isOk  = true
    local check_result; if not isPair then check_result = {} end
    
    -- checking cycle
    for _, par in ipairs(parid) do
        local val = targ[par]
        if val then
            local pdef = self[par.."_def"]
            local ok, err = pdef.fncheck(val, cktab)
            if ok then
                if not isPair then
                    check_result[#check_result + 1] = {param = par, isOk = true,  err = nil,}
                end
                if cktab[par] then cktab[par] = val end
            else
                isOk = false
                if isPair then
                    check_result = err
                else
                    check_result[#check_result + 1] = {param = par, isOk = false, err = err,}
                end
            end
            
        end
    end
    return isOk, check_result
end

-- restore to the default values all the parameter
-- (reserved one won't be changed so no need to restore it)
-- this need further investigation about the conseguence of a restore
-- that reset the parameter but "locally"
-- so this method must be considered experimental
function barcode:restore_param() --> self
    for _, par in ipairs(self._par_id) do
        local pdef = self[par.."_def"]
        if not pdef.isReserved then
            self[par] = pdef.default
        end
    end
    return self
end

-- create a table with the information of the current barcode encoder
function barcode:info_tab() --> table
    local _info = {
        name        = self._NAME,
        version     = self._VERSION,
        description = self._DESCRIPTION,
        param       = {},
    }
    local par_id = self._par_id
    local ipar = _info.param
    for _, id in ipairs(par_id) do
        ipar[#ipar + 1] = {
            name       = id,
            value      = self[id],
            isReserved = self[id.."_def"].isReserved,
            unit       = self[id.."_def"].unit,
        }
    end
    return _info
end

-- make accessible by name parameter values
-- id: parameter identifier
function barcode:get_param(id) --> value, err
    if type(id) ~= "string" then
        return nil, "[ArgErr] 'id' must be a string"
    end
    if string.sub(id, 1, 1) == "_" then
        return nil, "[Err] 'id' starts with an underscore that is for private fields"
    end
    local idpar = self._par_id
    local parkey = {}
    for i, kid in ipairs(idpar) do
        parkey[kid] = true
    end
    if not parkey[id] then
        return nil, "[Err] Parameter '"..id.."' doesn't exist"
    end
    assert(self[id.."_def"], "[InternalErr] '"..id.."_def' not defined")
    return self[id], nil
end

-- set parameters only if it is not reserved
-- syntax:
-- :set_param{key = value, key = value, ...}
-- :set_param(key, value)
function barcode:set_param(arg1, arg2) --> self, err
    -- processing arguments
    local targ; if type(arg1) == "table" then
        if type(arg2) ~= nil then
            return nil, "[ArgErr] Further arguments not allowed"
        end
        targ = arg1
    elseif type(arg1) == "string" then -- key/value
        if type(arg2) == nil then
            return nil, "[ArgErr] second argument expected as a not nil value"
        end
        targ = {}
        targ[arg1] = arg2
    end

    -- check, and eventually set, every parameter within targ in order
    local parid = self._par_id
    local check_val = self:_get_param_for_checking()
    for _, id_par in ipairs(parid) do
        if targ[id_par] ~= nil then
            local pdef = self[id_par.."_def"]
            -- is parameter reserved?
            if pdef.isReserved then
                return nil, "[Err] '"..id_par.."' is reserved, create a further encoder with the builder"
            end
            local new_val = targ[id_par]
            local ok, err = pdef.fncheck(new_val, check_val)
            if err then return nil, err end
            assert(ok, "[InternalErr] ok, err disarmony")
            self[id_par] = new_val -- OK, set a new parameter value
            -- update checking value
            if check_val[id_par] then check_val[id_par] = new_val end
        end
    end
    return self, nil
end


return barcode

--
