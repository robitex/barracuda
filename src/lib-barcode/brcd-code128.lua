-- Code128 barcode generator module
-- Copyright (C) 2020 Roberto Giacomelli
--
-- All dimension must be in scaled point (sp)
-- every fields that starts with an undercore sign are intended as private

local Code128 = {
    _VERSION     = "code128 v0.0.5",
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
    2331112, -- this is the stop char at index 106
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
    local Vbar = self._libgeo.Vbar -- Vbar class
    self._vbar = {}
    local b = self._vbar
    b[sc] = Vbar:from_int(n, mod, true)
    return true, nil
end

-- utility functions

-- the number of consecutive digits from the index 'i' in the code array
local function count_digits_from(arr, i)
    local start = i
    local dim = #arr 
    while i <= dim and (arr[i] > 47 and arr[i] < 58) do
        i = i + 1
    end
    return i - start
end

-- evaluate the check digit of the data representation
local function check_digit(code)
    local sum = code[1] -- this is the start character
    for i = 2, #code do
        sum = sum + code[i]*(i-1)
    end
    return sum % 103
end

-- return a pair of boolean the first one is true
-- if a control char and a lower case char occurs in the data
-- and the second one is true if the control char occurs before
-- the lower case char
local function ctrl_or_lowercase(pos, data) --> boolean, boolean|nil
    local len = #data
    local ctrl_occur, lower_occur = false, false
    for i = pos, len do
        local c = data[i]
        if (not ctrl_occur) and (c >= 0 and c < 32) then
            -- [0,31] control chars
            if lower_occur then
                return true, false -- lowercase char < ctrl char
            else
                ctrl_occur = true
            end
        elseif (not lower_occur) and (c > 95 and c < 128) then
            -- [96, 127] lower case chars
            if ctrl_occur then
                return true, true -- ctrl char < lowercase char
            else
                lower_occur = true
            end
        end
    end
    return false -- no such data
end

-- encode the provided char against a codeset
-- in the future this function will consider FN data
local function encode_char(t, codesetAorB, char_code, codesetA)
    local code
    if codesetAorB == codesetA then -- codesetA
        if char_code < 32 then
            code = char_code + 64
        elseif char_code > 31 and char_code < 96 then
            code = char_code - 32
        else
            error("Not implemented or wrong code")
        end
    else -- codesetB
        if char_code > 31 and char_code < 128 then
            code = char_code - 32
        else
            error("Not implemented or wrong code")
        end
    end
    t[#t + 1] = code
end

-- encode the message in a sequence of Code128 symbol minimizing its lenght
local function encode128(arr, codeset, switch) --> data, err :TODO:
    local res = {} -- the result array (the check character will be appended)
    -- find the Start Character A, B, or C
    local cur_codeset
    local ndigit = count_digits_from(arr, 1)
    local len = #arr
    --local no_ctrl_lower_char
    if (ndigit == 2 and len == 2) or ndigit > 3 then -- start char code C
        cur_codeset = codeset.C
    else
        local ok, ctrl_first = ctrl_or_lowercase(1, arr)
        if ok and ctrl_first then
            cur_codeset = codeset.A
        else
            cur_codeset = codeset.B
        end
    end
    res[#res + 1] = cur_codeset
    local pos = 1 -- symbol's index to encode
    while pos <= len do
        if cur_codeset == codeset.C then
            if arr[pos] < 48 or arr[pos] > 57 then -- not numeric char
                local ok, ctrl_first = ctrl_or_lowercase(pos, arr)
                if ok and ctrl_first then
                    cur_codeset = codeset.A
                else
                    cur_codeset = codeset.B
                end
                res[#res + 1] = switch[codeset.C][cur_codeset]
            else
                local imax = pos + 2*math.floor(ndigit/2) - 1
                for idx = pos, imax, 2 do
                    res[#res + 1] = (arr[idx] - 48)*10 + arr[idx+1] - 48
                end
                pos = pos + imax
                ndigit = ndigit - imax
                if ndigit == 1 then
                    -- cur_codeset setup
                    local ok, ctrl_first = ctrl_or_lowercase(pos + 1, arr)
                    if ok and ctrl_first then
                        cur_codeset = codeset.A
                    else
                        cur_codeset = codeset.B
                    end
                    res[#res + 1] = switch[codeset.C][cur_codeset]
                end
            end
        else --- current codeset is A or B
            if ndigit > 3 then
                if ndigit % 2 > 1 then -- odd number of digits
                    encode_char(res, cur_codeset, arr[pos], codeset.A)
                    pos = pos + 1
                    ndigit = ndigit - 1
                end
                res[#res + 1] = switch[cur_codeset][codeset.C]
                cur_codeset = codeset.C
            elseif (cur_codeset == codeset.B) and
                (arr[pos] >= 0 and arr[pos] < 32) then -- ops a control char
                local ok, ctrl_first = ctrl_or_lowercase(pos + 1, arr)
                if ok and (not ctrl_first) then -- shift to codeset A
                    res[#res + 1] = codeset.shift
                    encode_char(res, codeset.A, arr[pos], codeset.A)
                    pos = pos + 1
                    ndigit = count_digits_from(pos, arr)
                else -- switch to code set A
                    res[#res + 1] = switch[cur_codeset][codeset.A]
                    cur_codeset = codeset.A
                end
            elseif (cur_codeset == codeset.A) and
                (arr[pos] > 95 and arr[pos] < 128) then -- ops a lower case char
                local ok, ctrl_first = ctrl_or_lowercase(pos+1, arr)
                if ok and ctrl_first then -- shift to codeset B
                    res[#res + 1] = codeset.shift
                    encode_char(res, codeset.B, arr[pos], codeset.A)
                    pos = pos + 1
                    ndigit = count_digits_from(arr, pos)
                else -- switch to code set B
                    res[#res + 1] = switch[cur_codeset][codeset.B]
                    cur_codeset = codeset.B
                end
            else
                -- insert char
                encode_char(res, cur_codeset, arr[pos], codeset.A)
                pos = pos + 1
                ndigit = count_digits_from(arr, pos)
            end
        end
    end
    res[#res + 1] = check_digit(res)
    res[#res + 1] = codeset.stopChar
    return res
end

-- Code 128 internal functions used by Barcode costructors

function Code128:_check_char(c) --> elem, err
    if type(c) ~= "string" or #c ~= 1 then
        return nil, "[InternalErr] invalid char"
    end
    local b = string.byte(c)
    if b > 127 then
        local fmt = "[unimplemented] the '%d' is an ASCII extented char"
        return nil, string.format(fmt, c)
    end
    return b, nil
end

function Code128:_check_digit(n) --> elem, err
    if type(n) ~= "number" then
        return nil, "[InternalErr] invalid digit"
    end
    return n + 48, nil
end

function Code128:_finalize() --> ok, err
    local chr = assert(self._code_data, "[InternalErr] '_code_data' field is nil")
    local data, err = encode128(chr, self._codeset, self._switch)
    if err then return false, err end
    -- load dynamically required Vbar objects
    local vbar = self._vbar
    local oVbar = self._libgeo.Vbar
    for _, c in ipairs(data) do
        if not vbar[c] then
            local n = self._int_def_bar[c]
            local mod = self.xdim
            vbar[c] = oVbar:from_int(n, mod, true)
        end
    end
    self._enc_data = data
    return true, nil
end

-- Drawing into the provided channel the geometrical barcode data
-- tx, ty is the optional translator vector
-- the function return the canvas reference to allow call chaining
function Code128:append_ga(canvas, tx, ty) --> canvas
    local xdim, h = self.xdim, self.ydim
    local sw = 11*xdim -- the width of a symbol
    local data = self._enc_data
    local w = #data * sw + 2 * xdim -- total symbol width
    local ax, ay = self.ax, self.ay
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local y1 = y0 + h
    local xpos = x0
    -- drawing the symbol
    local err
    err = canvas:start_bbox_group()
    assert(not err, err)
    for _, c in ipairs(data) do
        local vb = self._vbar[c]
        err = canvas:encode_Vbar(vb, xpos, y0, y1)
        assert(not err, err)
        xpos = xpos + sw
    end
    -- bounding box setting
    local qz = self.quietzone_factor * xdim
    -- { xmin, ymin, xmax, ymax }
    err = canvas:stop_bbox_group(x0 - qz, y0, x1 + qz, y1)
    assert(not err, err)
    return canvas
end

return Code128
--