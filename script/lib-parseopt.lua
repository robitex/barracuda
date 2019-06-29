-- a small library parsing option in LuaTeX

local parseopt = {
    _option = {}
}

-- parse a key
local function parseKey(t, i) --> new position, key
    local k = {}
    local isInnerChar = false
    local isLastChar = true
    while true do
        if i > #t then
            break
        end
        local c = t[i]
        if c == "," or c == "=" then
            break
        end
        if c == " " then
            if isInnerChar and isLastChar then
                 isLastChar = false
                 k[#k + 1] = c
            end
        else
            isLastChar = true
            isInnerChar = true
            k[#k + 1] = c
        end
        i = i + 1
    end
    local key
    local len = #k
    if len > 0 then
        if not isLastChar then
            k[len] = nil
        end
        key = table.concat(k)
    end
    return i, key
end

-- parse a boolean option value
local function parseBool(ot, i) --> index, boolean
    local c = ot[i]
    local len = #ot
    if i > len or c == "," then
        return i, true
    end
    if c == "=" then
        i = i + 1
        while i<= len do
            local b = ot[i]
            if b ~= " " then
                break
            end
            i = i + 1
        end
        local res
        if i + 4 <= len and table.concat(ot, "", i, i+4) == "false" then
            i = i + 5
            res = false
        elseif i + 3 <= len and table.concat(ot, "", i, i+3) == "true" then
            i = i + 4
            res = true
        end
        while i <= len do
            local c = ot[i]
            if c == "," then
                return i + 1,  res
            end
            if c ~= " " then
                return i, nil
            end
            i = i + 1
        end
        return i, res
    end
    return i, nil
end

-- parse a dimension value
local function parseDim(t, i) --> index, sp
    local c = t[i]
    local len = #t
    if i > len or c ~= "=" then
        return i, nil
    end
    i = i + 1
    local k = i
    while k <= len and t[k] ~= "," do
        k = k + 1
    end
    if t[k] == "," then
        k = k - 1
    end
    local dim = table.concat(t, "", i, k)
    return k, tex.sp(dim)
end

-- verify the format of an option definition

-- basic option definition format:
-- {
--      opt_name = "<name>",     -- mandatory string
--      opt_type = "<typeName>", -- mandatory string
--      default  = <val>,        -- this is optional
--      checkfn  = function (<optdef>, <val>, <optval>) --> ok, err
--          -- ...
--      end, -- this is optional
-- }
--
local function checkOptDef(opt) -- ok, err
    if type(opt) ~= "table" then false, "[ArgErr] table expected" end
    --
end

-- public funtion

-- define an option of some type
--
-- inner option definition table:
-- self._option = {
--     pkgName = {
--          famName = {
--                [1] = {...}, -- option definition 1
--                [2] = {...}, -- option definition 2
--          },
--     },
-- }

function parseopt:define_namespace(ns) -- ok, err
    if type(ns) ~= "string" then
        return false, "[ArgErr] string expected as namespace name"
    end
    if ns == "" then
        return false, "[Err] empty string is not a valid namespace name"
    end
    local gopt = self._option
    if gopt[ns] then return false, "[Err] name '"..ns.."' already exists" end
    gopt[ns] = {}
    return true, nil -- namespace created
end

function parseopt:define_family(ns, famName) -- ok, err
    if type(ns) ~= "string" then
        return false, "[ArgErr] string expected as namespace name"
    end
    if ns == "" then
        return false, "[Err] empty string is not a valid namespace name"
    end
    if type(famName) ~= "string" then
        return false, "[ArgErr] string expected as family name"
    end
    if famName == "" then
        return false, "[Err] empty string is not a valid family name"
    end
    local gopt = self._option
    if not gopt[ns] then
        return false, "[Err] namespace '"..ns.."' not found"
    end
    local nsopt = gopt[ns]
    if nsopt[famName] then
        return false, "[Err] family name '"..famName.."' already exists"
    end
    nsopt[famName] = {}
    return true, nil -- family created
end

function parseopt:append_option(namespace, famName, opt) --> ok, err
    if type(namespace) ~= "string" then
        return false, "[ArgErr] string expected as namespace name"
    end
    if namespace == "" then
        return false, "[Err] empty string is not a valid namespace name"
    end
    if type(famName) ~= "string" then
        return false, "[ArgErr] string expected as family name"
    end
    if famName == "" then
        return false, "[Err] empty string is not a valid family name"
    end
    if type(opt) ~= "table" then
        return false, "[ArgErr] table expected for option definition argument"
    end
    local gopt = self._option -- global option container
    if not gopt[namespace] then
        return false, "[Err] namespace '"..namespace.."' not found"
    end
    local nsopt = gopt[namespace]
    if not nsopt[famName] then 
        return false, "[Err] family '"..famName.."' not found"
    end
    local famopt = nsopt[famName]
    local ok, err = checkOptDef(opt)
    if ok then
        famopt[#famopt + 1] = opt
        return true, nil
    end
    return false, err
end

-- parse a user string and return the option value
function parseopt:parse_options(namespace, famName, s) --> opt_table, err
    if type(namespace) ~= "string" then
        return false, "[ArgErr] string expected as namespace name"
    end
    if namespace == "" then
        return false, "[Err] empty string is not a valid namespace name"
    end
    if type(famName) ~= "string" then
        return false, "[ArgErr] string expected as family name"
    end
    if famName == "" then
        return false, "[Err] empty string is not a valid family name"
    end
    if type(s) ~= "string" then
        return false, "[ArgErr] string expected as key/value list"
    end
    local gopt = self._option








    
    local opt = assert(self[pkgName][famName])
    local isKeyParse = true -- state: key reading
    for c in s:gmatch(".") do
        if isKeyParse then -- read a key
            if c == " " then
            end
        else
        end
    end
    return opt, nil
end


local function parseOption(s) --> topt, err
    local t = {} -- option table
    for c in s:gmatch(".") do
        t[#t + 1] = c
    end
    local i = 1
    local len = #t
    local opt = {}
    local defopt = self.defopt
    while i <= len do
        local key
        i, key = parseKey(t, i)

        if not key then
            error("Error at index " .. i)
        end
        if not defopt[key] then
            error("Key not found " .. key)
        end
        local def = defopt[key]
        local optype = def.optype
        local fnparse = fnparselib[optype]
        local val
        i, val = fnparse(t, i)
        if not val then
            error("Invalid value for ".. key)
        end
        local fncheck = def.fncheck
        if fncheck then
            local ok = fncheck(val)
            if not ok then
                error("Invalid value for "..key)
            end
        end
        opt[key] = val
    end
    return opt
end


return parseopt

