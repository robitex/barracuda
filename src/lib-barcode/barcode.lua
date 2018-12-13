
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
-- _par_def table
barcode._par_def = {}
local pardef = barcode._par_def
pardef.__index = pardef

-- set an Anchor point (ax, ay) relatively to the barcode bounding box
-- without considering any text object
-- ax = 0, ay = 0 is the origin of the local axis system
-- ax = 1, ay = 1 is the upper right corner of the symbol
barcode.ax = 0.0
pardef.ax = {
    default = 0.0,
    unit = "sp", -- scaled point
    isReserved = false,
    order = 1,
    fncheck = function (self, ax, _) --> boolean, err
        if ax >= 0.0 and ax <= 1.0 then return true, nil end
        return false, "[OutOfRange] 'ax' out of [0, 1]"
    end,
}

barcode.ay = 0.0
pardef.ay = {
    default = 0.0,
    unit = "sp", -- scaled point
    isReserved = false,
    order = 2,
    fncheck = function (self, ay, _) --> boolean, err
        if ay >= 0.0 and ay <= 1.0 then return true, nil end
        return false, "[OutOfRange] 'ay' out of [0, 1]"
    end,
}

-- barcode.bbox_to_quietzone -- under assessment

-- barcode methods

-- check a parameter before set it up
-- syntax:
-- :set_parameter{key = value, key = value, ...} --> boolean, check_table
-- :set_parameter(key, value)                    --> boolean, err_descr
-- this method check also reserved parameter
function barcode:check_param(arg1, arg2) --> boolean, check report | err_descr
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
    -- preparing to checking process
    local parid  = self._par_id
    local pardef = self._par_def
    local cktab  = {}
    local isOk   = true
    local check_rpt; if not isPair then check_rpt = {} end
    
    -- checking process
    for _, par in ipairs(parid) do
        assert(self[par] ~= nil, "[InternalErr] parameter value unreachable")
        assert(pardef[par], "[InternalErr] parameter definition unreachable")
        local val = targ[par] -- par = val
        local pdef = pardef[par]
        local def_val; if pdef.fndefault then
            def_val = pdef:fndefault(cktab)
        else
            def_val = pdef.default
        end
        if val ~= nil then
            local ok, err = pdef:fncheck(val, cktab)
            if isPair then
                check_rpt = err
            else
                check_rpt[#check_rpt + 1] = {
                    param       = par,
                    checked_val = val,
                    default_val = def_val,
                    isOk        = ok,
                    err         = err,
                }
            end
            if ok then
                cktab[par] = val
            else -- error!
                isOk = false
                cktab[par] = def_val
            end
        else
            cktab[par] = def_val
        end
    end
    return isOk, check_rpt
end

-- restore to the default values all the parameter
-- (reserved one won't be changed so no need to restore it)
-- this need further investigation about the conseguence of a restore
-- that reset the parameter but "locally"
-- so this method must be considered experimental
function barcode:restore_param() --> self :FIXME:
    for _, par in ipairs(self._par_id) do
        local pdef = self[par.."_def"]
        if not pdef.isReserved then
            self[par] = pdef.default
        end
    end
    return self
end

-- create a table with the information of the current barcode encoder
function barcode:info() --> table
    local info = {
        name        = self._NAME,
        version     = self._VERSION,
        description = self._DESCRIPTION,
        param       = {},
    }
    local par_id = self._par_id
    local pardef = self._par_def
    local tpar   = info.param
    for _, id in ipairs(par_id) do
        tpar[#tpar + 1] = {
            name       = id,
            descr      = nil, -- TODO:
            value      = self[id],
            isReserved = pardef.isReserved,
            unit       = pardef.unit,
        }
    end
    return info
end

-- make accessible by name parameter values
-- id: parameter identifier
function barcode:get_param(id) --> value, err
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
function barcode:set_param(arg1, arg2) --> boolean, err_rpt
    local isOk, chk = self:check_param(arg1, arg2)
    if isOk then
        local targ; if type(arg1) == "table" then  -- processing arguments
            targ = arg1
        else -- key/value
            targ = {}
            targ[arg1] = arg2
        end
        local parid  = self._par_id
        for _, par in ipairs(parid) do -- par = val
            local val = targ[par]
            if val ~= nil then self[par] = val end -- set the value
        end
        return true, chk
    else
        return false, chk
    end
end

return barcode

--
