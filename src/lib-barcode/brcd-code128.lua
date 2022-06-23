-- Code128 barcode generator module
-- Copyright (C) 2019-2022 Roberto Giacomelli
--
-- All dimension must be in scaled point (sp)
-- every fields that starts with an undercore sign are intended as private

local Code128 = {
    _VERSION     = "code128 v0.0.6",
    _NAME        = "Code128",
    _DESCRIPTION = "Code128 barcode encoder",
}

Code128._int_def_bar = {-- code bar definitions
    [0] = 212222,   222122, 222221, 121223, 121322, 131222, 122213, 122312,
    132212, 221213, 221312, 231212, 112232, 122132, 122231, 113222, 123122,
    123221, 223211, 221132, 221231, 213212, 223112, 312131, 311222, 321122,
    321221, 312212, 322112, 322211, 212123, 212321, 232121, 111323, 131123,
    131321, 112313, 132113, 132311, 211313, 231113, 231311, 112133, 112331,
    132131, 113123, 113321, 133121, 313121, 211331, 231131, 213113, 213311,
    213131, 311123, 311321, 331121, 312113, 312311, 332111, 314111, 221411,
    431111, 111224, 111422, 121124, 121421, 141122, 141221, 112214, 112412,
    122114, 122411, 142112, 142211, 241211, 221114, 413111, 241112, 134111,
    111242, 121142, 121241, 114212, 124112, 124211, 411212, 421112, 421211,
    212141, 214121, 412121, 111143, 111341, 131141, 114113, 114311, 411113,
    411311, 113141, 114131, 311141, 411131, 211412, 211214, 211232,
    2331112, -- the last number is the stop char at index 106
}

Code128._codeset = {
    A        = 103, -- Start char for Codeset A
    B        = 104, -- Start char for Codeset B
    C        = 105, -- Start char for Codeset C
    stopChar = 106, -- Stop char
    shift    =  98, -- A to B or B to A
}

Code128._switch = { -- codes for switching from a codeset to another one
    [103] = {[104] = 100, [105] =  99}, -- from A to B or C
    [104] = {[103] = 101, [105] =  99}, -- from B to A or C
    [105] = {[103] = 101, [104] = 100}, -- from C to A or B
}

-- parameters definition
Code128._par_order = {
    "xdim",
    "ydim",
    "quietzone_factor",
}
Code128._par_def = {}
local pardef = Code128._par_def

-- module main parameter
pardef.xdim = {
    default    = 0.21 * 186467, -- X dimension
    unit       = "sp", -- scaled point
    isReserved = true,
    fncheck    = function (self, x, _) --> boolean, err
        if x >= self.default then
            return true, nil
        else
            return false, "[OutOfRange] too small value for xdim"
        end
    end,
}

pardef.ydim = {
    default    = 10 * 186467, -- Y dimension
    unit       = "sp",
    isReserved = false,
    fncheck    = function (self, y, tpar) --> boolean, err
        local xdim = tpar.xdim
        if y >= 10*xdim then
            return true, nil
        else
            return false, "[OutOfRange] too small value for ydim"
        end
    end,
}

pardef.quietzone_factor = {
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, z, _) --> boolean, err
        if z >= 10 then
            return true, nil
        else
            return false, "[OutOfRange] too small value for quietzone_factor"
        end
    end,
}

-- create vbar objects
function Code128:_config() --> ok, err
    -- build Vbar object for the start/stop symbol
    local mod = self.xdim
    local sc = self._codeset.stopChar -- build the stop char
    local n = self._int_def_bar[sc]
    local repo = self._libgeo.Archive:new()
    self._vbar_archive = repo
    local Vbar = self._libgeo.Vbar
    repo:insert(Vbar:from_int(n, mod, true), 106)
    return true, nil
end

-- utility functions

-- evaluate the check digit of encoded data
local function check_digit(code)
    local sum = code[1] -- this is the start character
    for i = 2, #code do
        sum = sum + code[i]*(i-1)
    end
    code[#code + 1] = sum % 103
end

local function isdigit(char) --> true/false
    assert(char)
    return (char > 47) and (char < 58)
end

local function iscontrol(char) --> true/false
    assert(char)
    -- [0,31] control chars interval
    return char < 32
end

local function islower(char)
    assert(char)
    -- [96, 127] lower case chars
    return (char > 95) and (char < 128)
end

-- count digits
local function digits_group(data, len) --> counting digits
    local res = {}
    local last = false
    for i = len, 1, -1 do
        local digit = isdigit(data[i])
        if last then
            if digit then
                res[i] = res[i+1] + 1
            else
                res[i] = 0
                last = false
            end
        else
            if digit then
                res[i] = 1
                last = true
            else
                res[i] = 0
            end
        end
    end
    return res
end

-- find the first char in the codeset that adhere
-- with the function argument 'filter'
local function indexof_char_by(filter, arr, counter) --> index or nil
    counter = counter or 1
    local char = arr[counter]
    while char do
        if filter(char) then
            return counter
        end
        counter = counter + 1
        char = arr[counter]
    end
end

-- determine the Start character
local function start_codeset_char(codeset, arr, len)
    assert(len>0)
    local ctrl = indexof_char_by(iscontrol, arr)
    local lowc = indexof_char_by(islower, arr)
    local t_digits = digits_group(arr, len)
    local first_digits = t_digits[1]
    -- case 1
    if (len == 2) and (first_digits == 2) then
        return lowc, ctrl, codeset.C, t_digits
    end
    -- case 2
    if first_digits >= 4 then
        return lowc, ctrl, codeset.C, t_digits
    end
    -- case 3
    local cs = codeset.B
    if (ctrl and lowc) and (ctrl < lowc) then
        cs = codeset.A
    end
    -- case 4
    return lowc, ctrl, cs, t_digits
end

-- codeset A char
local function encode_char_A(res, char)
    local code
    if char < 32 then
        code = char + 64
    elseif char > 31 and char < 96 then
        code = char - 32
    else
        error("[InternalErr] Not implemented or wrong code" )
    end
    res[#res + 1] = code
end
-- codeset B char
local function encode_char_B(res, char)
    local code
    if char > 31 and char < 128 then
        code = char - 32
    else
        error("[InternalErr] Not implemented or wrong code")
    end
    res[#res + 1] = code
end

-- every function encodes a group of chars
-- A = 103, -- Start char for Codeset A
-- B = 104, -- Start char for Codeset B
-- C = 105, -- Start char for Codeset C
local encode_codeset = {
    -- A
    [103] = function (codeset, res, data, index, t_digits, i_low, _ctrl)
        assert(t_digits[index] < 4, "[InternalErr] in codeset A digits must be less than 4")
        while data[index] do
            local char = data[index]
            if i_low and islower(char) then -- ops a lower case char
                local next = data[index + 1]
                local next_next = data[index + 2]
                if next and next_next then
                    -- case 5a
                    if iscontrol(char) and islower(next_next) then
                        res[#res+1] = codeset.shift
                        encode_char_B(res, char)
                        index = index + 1
                    end
                else
                    -- case 5b
                    return codeset.B, index
                end
            else
                local digits = t_digits[index]
                if digits > 3 then -- go to codeset C
                    if (digits % 2) == 1 then -- odd number of a group of digits
                        encode_char_A(res, char)
                        digits = digits - 1
                        index = index + 1
                    end
                    return codeset.C, index
                end
                encode_char_A(res, char)
                index = index + 1
            end
        end
        return nil, index
    end,
    -- B
    [104] = function (codeset, res, data, index, t_digits, _low, i_ctrl)
        assert(t_digits[index] < 4, "[InternalErr] in codeset B digits must be less than 4")
        while data[index] do
            local char = data[index]
            if i_ctrl and iscontrol(char) then -- ops a control char
                local next = data[index + 1]
                local next_next = data[index + 2]
                if next and next_next then
                    -- case 4a
                    if islower(next) and iscontrol(next_next) then
                        res[#res+1] = codeset.shift
                        encode_char_A(res, char)
                        index = index + 1
                    end
                else
                    -- case 4b
                    return codeset.A, index
                end
            else
                local digits = t_digits[index]
                if digits > 3 then -- go to codeset C
                    if (digits % 2) == 1 then -- odd number of a group of digits
                        encode_char_B(res, char)
                        digits = digits - 1
                        index = index + 1
                    end
                    return codeset.C, index
                end
                encode_char_B(res, char)
                index = index + 1
            end
        end
        return nil, index
    end,
    -- C
    [105] = function (codeset, res, data, index, t_digits, i_low, i_ctrl)
        local digits = t_digits[index]
        assert(digits > 1, "[InternalErr] at least a pair of digit is required")
        while digits > 1 do
            local d1, d2 = data[index], data[index + 1]
            res[#res + 1] = (d1 - 48)*10 + d2 - 48
            digits = digits - 2
            index = index + 2
        end
        local res_codeset
        if i_ctrl and i_low then
            local ctrl = indexof_char_by(iscontrol, data, index)
            local low = indexof_char_by(islower, data, index)
            if low and (ctrl < low) then
                res_codeset = codeset.A
            end
        else
            res_codeset = codeset.B
        end
        return res_codeset, index
    end,
}

-- encode the message in a sequence of Code128 symbol minimizing the symbol width
local function encode128(arr, codeset, switch) --> data, err
    local len = #arr
    local i_low, i_ctrl, cur_codeset, t_digits = start_codeset_char(codeset, arr, len)
    local res = {cur_codeset} -- the result array (the check character will be appended later)
    local switch_codeset
    local cur_index = 1
    while cur_index <= len do
        if switch_codeset then
            res[#res+1] = switch[cur_codeset][switch_codeset]
            cur_codeset = switch_codeset
        end
        local fn = assert(encode_codeset[cur_codeset], "[InternalErr] cur_codeset is "..(cur_codeset or "nil"))
        switch_codeset, cur_index = fn(codeset, res, arr, cur_index, t_digits, i_low, i_ctrl)
    end
    check_digit(res)
    return res, nil
end

-- Code 128 internal functions used by Barcode costructors

function Code128:_process_char(c) --> char_code, char_text, err
    local b = string.byte(c)
    if b > 127 then
        local fmt = "[unimplemented] the '%d' is an ASCII extented char"
        return nil, string.format(fmt, c)
    end
    return b, c, nil
end

function Code128:_process_digit(n) --> digit_code, char_text, err
    local res = n + 48
    return res, string.char(res), nil
end

function Code128:_finalize() --> ok, err
    local chr = assert(self._code_data, "[InternalErr] '_code_data' field is nil")
    local data, err = encode128(chr, self._codeset, self._switch)
    if err then return false, err end
    self._enc_data = data
    -- dynamically load the required Vbar objects
    local Repo = self._vbar_archive
    local Vbar = self._libgeo.Vbar
    for _, c in ipairs(data) do
        if not Repo:contains_key(c) then
            local n = self._int_def_bar[c]
            local mod = self.xdim
            assert(Repo:insert(Vbar:from_int(n, mod, true), c))
        end
    end
    return true, nil
end

-- Drawing into the provided channel the geometrical barcode data
-- tx, ty is the optional translator vector
-- the function return the canvas reference to allow call chaining
function Code128:_append_ga(canvas, tx, ty) --> bbox
    local data = self._enc_data
    local Repo = self._vbar_archive
    local queue = self._libgeo.Vbar_queue:new()
    for _, c in ipairs(data) do
        queue = queue + Repo:get(c)
    end
    local stop = self._codeset.stopChar
    queue = queue + Repo:get(stop)
    local xdim, h = self.xdim, self.ydim
    local ns = #data + 1
    local w = (11*ns + 2) * xdim -- total symbol width
    local ax, ay = self.ax, self.ay
    local x0 = tx - ax * w
    local y0 = ty - ay * h
    local x1 = x0 + w
    local y1 = y0 + h
    -- drawing the symbol
    assert(canvas:encode_disable_bbox())
    assert(canvas:encode_vbar_queue(queue, x0, y0, y1))
    -- bounding box setting
    local qz = self.quietzone_factor * xdim
    -- { xmin, ymin, xmax, ymax }
    assert(canvas:encode_set_bbox(x0 - qz, y0, x1 + qz, y1))
    assert(canvas:encode_enable_bbox())
    return {x0, y0, x1, y1, qz, nil, qz, nil,}
end

return Code128
