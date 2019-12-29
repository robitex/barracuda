-- EAN family barcode generator
--
-- Copyright (C) 2019 Roberto Giacomelli
-- see LICENSE.txt file
--
-- variant identifiers of the EAN family barcodes:
-- "13"   EAN13
-- "8"    EAN8
-- "5"    EAN5 add-on
-- "2"    EAN2 add-on
-- "13+5" EAN13 with EAN5 add-on
-- "13+2" EAN13 with EAN2 add-on
-- "8+5"  EAN8 with EAN5 add-on
-- "8+2"  EAN8 with EAN2 add-on

local EAN = {
    _VERSION     = "ean v0.0.6",
    _NAME        = "ean",
    _DESCRIPTION = "EAN barcode encoder",
}

EAN._id_variant = {
    ["13"]   = true, -- EAN13
    ["8"]    = true, -- EAN8
    ["5"]    = true, -- EAN5 add-on
    ["2"]    = true, -- EAN2 add-on
    ["13+5"] = true, -- EAN13 with EAN5 add-on
    ["13+2"] = true, -- EAN13 with EAN2 add-on
    ["8+5"]  = true, -- EAN8 with EAN5 add-on
    ["8+2"]  = true, -- EAN8 with EAN2 add-on
    ["isbn"] = true, -- ISBN 13 digits
    ["isbn+2"] = true, -- ISBN 13 digits with an EAN2 add-on
    ["isbn+5"] = true, -- ISBN 13 digits with an EAN2 add-on
}

EAN._codeset_seq = {-- 1 -> A, 2 -> B, 3 -> C
[0]={1, 1, 1, 1, 1, 1, 3, 3, 3, 3, 3, 3},
    {1, 1, 2, 1, 2, 2, 3, 3, 3, 3, 3, 3},
    {1, 1, 2, 2, 1, 2, 3, 3, 3, 3, 3, 3},
    {1, 1, 2, 2, 2, 1, 3, 3, 3, 3, 3, 3},
    {1, 2, 1, 1, 2, 2, 3, 3, 3, 3, 3, 3},
    {1, 2, 2, 1, 1, 2, 3, 3, 3, 3, 3, 3},
    {1, 2, 2, 2, 1, 1, 3, 3, 3, 3, 3, 3},
    {1, 2, 1, 2, 1, 2, 3, 3, 3, 3, 3, 3},
    {1, 2, 1, 2, 2, 1, 3, 3, 3, 3, 3, 3},
    {1, 2, 2, 1, 2, 1, 3, 3, 3, 3, 3, 3},
}

EAN._codeset14_8 = 1
EAN._codeset58_8 = 3

EAN._codeset_5 = { -- check digit => structure
[0]={2, 2, 1, 1, 1}, -- 0 GGLLL
    {2, 1, 2, 1, 1}, -- 1 GLGLL
    {2, 1, 1, 2, 1}, -- 2 GLLGL
    {2, 1, 1, 1, 2}, -- 3 GLLLG
    {1, 2, 2, 1, 1}, -- 4 LGGLL
    {1, 1, 2, 2, 1}, -- 5 LLGGL
    {1, 1, 1, 2, 2}, -- 6 LLLGG
    {1, 2, 1, 2, 1}, -- 7 LGLGL
    {1, 2, 1, 1, 2}, -- 8 LGLLG
    {1, 1, 2, 1, 2}, -- 9 LLGLG
}

EAN._symbol = { -- codesets A, B, and C
    [1] = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,},
    [2] = {[0] = 1123, 1222, 2212, 1141, 2311, 1321, 4111, 2131, 3121, 2113,},
    [3] = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,},
}

EAN._is_first_bar = {false, false, true}
EAN._start = {111, true}
EAN._stop  = {11111, false}

-- family common parameters
EAN._par_order = {
    "mod",
    "height",
    "quietzone_left_factor",
    "quietzone_right_factor",
    "bars_depth_factor",
    "text_enabled",
    "text_ygap_factor",
    "text_xgap_factor",
}
EAN._par_def = {}
local pardef = EAN._par_def

-- standard module is 0.33 mm but it can vary from 0.264 to 0.66mm
pardef.mod = {
    default    = 0.33 * 186467, -- (mm to sp) X dimension (original value 0.33)
    unit       = "sp", -- scaled point
    isReserved = true,
    fncheck    = function (self, x, _) --> boolean, err
        local mm = 186467
        local min, max = 0.264 * mm, 0.660 * mm
        if x < min then
            return false, "[OutOfRange] too small value for mod"
        elseif x > max then
            return false, "[OutOfRange] too big value for mod"
        end
        return true, nil
    end,
}

pardef.height = {
    default    = 22.85 * 186467, -- 22.85 mm
    unit       = "sp",
    isReserved = false,
    fncheck    = function (self, h, _) --> boolean, err
        if h > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for height"
        end
    end,
}

pardef.quietzone_left_factor = {
    default    = 11,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, qzf, _) --> boolean, err
        if qzf > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_left_factor"
        end
    end,
}

pardef.quietzone_right_factor = {
    default    = 7,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, qzf, _) --> boolean, err
        if qzf > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_right_factor"
        end
    end,
}

pardef.bars_depth_factor = {
    default    = 5,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, b, _) --> boolean, err
        if b >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for bars_depth_factor"
        end
    end,
}

-- enable/disable a text label upon the barcode symbol
pardef.text_enabled = { -- boolean type
    default    = true,
    isReserved = false,
    fncheck    = function (self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value for text_enabled"
        end
    end,
}

pardef.text_ygap_factor = {
    default    = 1.0,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, t, _) --> boolean, err
        if t >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for text_ygap_factor"
        end
    end,
}

pardef.text_xgap_factor = {
    default    = 0.75,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, t, _) --> boolean, err
        if t >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for text_xgap_factor"
        end
    end,
}

-- variant parameters
EAN._par_variant_order = {
    ["13"]   = {}, -- EAN13
    ["8"]    = {}, -- EAN8
    ["5"]    = {}, -- add-on EAN5
    ["2"]    = {}, -- add-on EAN2
    ["isbn"] = { -- ISBN 13 digits
        "text_isbn_enabled",
        "text_isbn_ygap_factor",
    },
    ["13+5"] = {"addon_xgap_factor",}, -- EAN13 with EAN5 add-on
    ["13+2"] = {"addon_xgap_factor",}, -- EAN13 with EAN2 add-on
    ["8+5"]  = {"addon_xgap_factor",}, -- EAN8 with EAN5 add-on
    ["8+2"]  = {"addon_xgap_factor",}, -- EAN8 with EAN2 add-on
    ["isbn+2"] = { -- ISBN 13 digits with an EAN2 add-on
        "text_isbn_enabled",
        "text_isbn_ygap_factor",
        "addon_xgap_factor",
    },
    ["isbn+5"] = { -- ISBN 13 digits with an EAN2 add-on
        "text_isbn_enabled",
        "text_isbn_ygap_factor",
        "addon_xgap_factor",
    },
}
EAN._par_def_variant = {
    ["13"]   = {}, -- EAN13
    ["8"]    = {}, -- EAN8
    ["5"]    = {}, -- add-on EAN5
    ["2"]    = {}, -- add-on EAN2
    ["13+5"] = {}, -- EAN13 with EAN5 add-on
    ["13+2"] = {}, -- EAN13 with EAN2 add-on
    ["8+5"]  = {}, -- EAN8 with EAN5 add-on
    ["8+2"]  = {}, -- EAN8 with EAN2 add-on
    ["isbn"] = {}, -- ISBN 13 digits
    ["isbn+2"] = {}, -- ISBN 13 digits with an EAN2 add-on
    ["isbn+5"] = {}, -- ISBN 13 digits with an EAN2 add-on
}
local par_def_var = EAN._par_def_variant

-- EAN ISBN/13/8 + add-on parameters
local addon_xgap_factor = {-- distance between main and add-on symbol
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, t, _) --> boolean, err
        if t >= 7 then
            return true, nil
        else
            return false, "[OutOfRange] not positive value for xgap_factor"
        end
    end,
}
par_def_var["13+5"].addon_xgap_factor = addon_xgap_factor
par_def_var["13+2"].addon_xgap_factor = addon_xgap_factor
par_def_var["8+5"].addon_xgap_factor = addon_xgap_factor
par_def_var["8+2"].addon_xgap_factor = addon_xgap_factor
par_def_var["isbn+5"].addon_xgap_factor = addon_xgap_factor
par_def_var["isbn+2"].addon_xgap_factor = addon_xgap_factor

-- text_ISBN parameter
-- enable/disable a text ISBN label upon the barcode symbol
local text_isbn_enabled = { -- boolean type
    default    = true,
    isReserved = false,
    fncheck    = function (self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value for text_isbn_enabled"
        end
    end,
}
par_def_var["isbn+5"].text_isbn_enabled = text_isbn_enabled
par_def_var["isbn+2"].text_isbn_enabled = text_isbn_enabled
par_def_var["isbn"].text_isbn_enabled = text_isbn_enabled

-- ISBN text vertical distance
local text_isbn_ygap_factor = {
    default    = 2.0,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (self, t, _) --> boolean, err
        if t >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for text_isbn_ygap_factor"
        end
    end,
}

par_def_var["isbn+5"].text_isbn_ygap_factor = text_isbn_ygap_factor
par_def_var["isbn+2"].text_isbn_ygap_factor = text_isbn_ygap_factor
par_def_var["isbn"].text_isbn_ygap_factor = text_isbn_ygap_factor

-- configuration functions

-- utility for generic configuration of full symbol, add-on included
-- n1 length of main symbol, 8 or 13
-- n2 length of add-on symbol, 2 or 5
local function config_full(ean, Vbar, mod, n1, n2)
    local i1 = tostring(n1)
    local fn_1 = assert(ean._config_variant[i1])
    fn_1(ean, Vbar, mod)
    local i2 = tostring(n2)
    local fn_2 = assert(ean._config_variant[i2])
    fn_2(ean, Vbar, mod)
    ean._main_len = n1
    ean._addon_len = n2
    ean._is_last_checksum = true
end

local config_variant = {
    ["13"] = function (ean13, Vbar, mod)
        ean13._main_len = 13
        ean13._is_last_checksum = true
        local start = ean13._start
        local stop  = ean13._stop
        ean13._13_start_stop_vbar  = Vbar:from_int(start[1], mod, start[2])
        ean13._13_ctrl_center_vbar = Vbar:from_int(stop[1], mod, stop[2])
        ean13._13_codeset_vbar = {}
        local tvbar = ean13._13_codeset_vbar
        for i_cs, codetab in ipairs(ean13._symbol) do
            tvbar[i_cs] = {}
            local tv = tvbar[i_cs]
            local isbar = ean13._is_first_bar[i_cs]
            for i = 0, 9 do
                tv[i] = Vbar:from_int(codetab[i], mod, isbar)
            end
        end
    end,
    ["8"] = function (ean8, Vbar, mod)
        ean8._main_len = 8
        ean8._is_last_checksum = true
        local start = ean8._start
        local stop  = ean8._stop
        ean8._8_start_stop_vbar = Vbar:from_int(start[1], mod, start[2])
        ean8._8_ctrl_center_vbar = Vbar:from_int(stop[1], mod, stop[2])
        ean8._8_codeset_vbar = {}
        local tvbar = ean8._8_codeset_vbar
        for k = 1, 3, 2 do -- only codeset A and C (k == 1, 3)
            tvbar[k] = {}
            local codetab = ean8._symbol[k]
            local isbar = ean8._is_first_bar[k]
            local tv = tvbar[k]
            for i = 0, 9 do
                tv[i] = Vbar:from_int(codetab[i], mod, isbar)
            end
        end
    end,
    ["5"] = function (ean5, Vbar, mod) -- add-on EAN5
        ean5._main_len = 5
        ean5._is_last_checksum = false
        ean5._5_start_vbar = Vbar:from_int(112, mod, true)
        ean5._5_sep_vbar   = Vbar:from_int(11, mod, false)
        ean5._5_codeset_vbar = {}
        local tvbar = ean5._5_codeset_vbar
        local symbols = ean5._symbol
        for c = 1, 2 do
            tvbar[c] = {}
            local tcs = tvbar[c]
            local isbar = false
            local sb = symbols[c]
            for i = 0, 9 do
                tcs[i] = Vbar:from_int(sb[i], mod, false)
            end
        end
    end,
    ["2"] = function (ean2, Vbar, mod) -- add-on EAN2
        ean2._main_len = 2
        ean2._is_last_checksum = false
        ean2._2_start_vbar = Vbar:from_int(112, mod, true)
        ean2._2_sep_vbar   = Vbar:from_int(11, mod, false)
        ean2._2_codeset_vbar = {}
        local tvbar = ean2._2_codeset_vbar
        local symbols = ean2._symbol
        for c = 1, 2 do
            tvbar[c] = {}
            local tcs = tvbar[c]
            local isbar = false
            local sb = symbols[c]
            for i = 0, 9 do
                tcs[i] = Vbar:from_int(sb[i], mod, false)
            end
        end
    end,
    ["13+5"] = function (ean, Vbar, mod) -- EAN13 with EAN5 add-on
        config_full(ean, Vbar, mod, 13, 5)
    end,
    ["13+2"] = function(ean, Vbar, mod) -- EAN13 with EAN2 add-on
        config_full(ean, Vbar, mod, 13, 2)
    end,
    ["8+5"]  = function(ean, Vbar, mod) -- EAN8 with EAN5 add-on
        config_full(ean, Vbar, mod, 8, 5)
    end,
    ["8+2"]  = function(ean, Vbar, mod) -- EAN8 with EAN2 add-on
        config_full(ean, Vbar, mod, 8, 2)
    end,
}

config_variant["isbn"] = config_variant["13"]
config_variant["isbn+2"] = config_variant["13+2"]
config_variant["isbn+5"] = config_variant["13+5"]
EAN._config_variant = config_variant

local function isbn_check_char(isbn, c, parse_state) --> elem, err
    if type(c) ~= "string" or #c ~= 1 then
        return nil, "[InternalErr] invalid char"
    end
    parse_state.isbncode = parse_state.isbncode or {}
    local code = parse_state.isbncode
    if parse_state.isspace == nil then parse_state.isspace = false end
    if parse_state.isdash == nil then parse_state.isdash = false end
    parse_state.i = parse_state.i or 0
    if c == "-" then
        if parse_state.isdash then
            return nil, "[ArgErr] two consecutive dash char found"
        end
        parse_state.isdash = true
        return nil, nil
    elseif c == " " then
        parse_state.isspace = true
        return nil, nil
    else
        local n = string.byte(c) - 48
        if n < 0 or n > 9 then
            return nil, "[ArgErr] found a not digit or a not grouping char"
        end
        if parse_state.isdash then -- close a group
            code[#code + 1] = "-"
            parse_state.isdash = false
            parse_state.isspace = false
        elseif parse_state.isspace then
            code[#code + 1] = " "
            parse_state.isspace = false
        end
        if parse_state.i < 13 then
            code[#code + 1] = c
            parse_state.i = parse_state.i + 1
        end
        return n, nil
    end
end

-- config function called at the moment of encoder construction
-- create all the possible VBar object
function EAN:config() --> ok, err
    local variant = self._variant
    local fnconfig = self._config_variant[variant]
    local VbarClass = self._libgeo.Vbar -- Vbar class
    local mod = self.mod
    fnconfig(self, VbarClass, mod)
    if variant == "isbn" or variant == "isbn+5" or variant == "isbn+2" then
        self._check_char = isbn_check_char
    end
    return true, nil
end

-- utility function

-- the checksum of EAN8 or EAN13 code
-- 'data' is an array of digits
local function checksum_8_13(data, stop_index)
    local s1 = 0; for i = 2, stop_index, 2 do
        s1 = s1 + data[i]
    end
    local s2 = 0; for i = 1, stop_index, 2 do
        s2 = s2 + data[i]
    end
    local sum; if stop_index % 2 == 0 then
        sum = 3 * s1 + s2
    else
        sum = s1 + 3 * s2
    end
    return (10 - (sum % 10)) % 10
end

-- return the checksum digit of an EAN 5 or EAN 2 add-on
-- this digits will not be part of the code
-- 'data' is an array of digits
-- i is the index where the code starts
-- len is the length of the code
local function checksum_5_2(data, i, len) --> checksum digit or nil
    if len == 5 then -- EAN 5 add-on
        local c1 = data[i] + data[i + 2] + data[i + 4]
        local c2 = data[i + 1] + data[i + 3]
        local ck = 3 * c1 + 9 * c2
        return ck % 10
    elseif len == 2 then -- EAN 2 add-on
        local ck = 10 * data[i] + data[i + 1]
        return ck % 4
    end
end

-- public methods

-- return the checksum digit of the argument or an error
-- respect to the encoder variant EAN8 or EAN13
-- 'n' can be an integer, a string of digits or an array of digits
function EAN:checksum(n) --> n, err
    local arr;
    if type(n) == "number" then
        if n <= 0 then
            return nil, "[ArgErr] number must be a positive integer"
        end
        if n - math.floor(n) > 0 then
            return nil, "[ArgErr] 'n' is not an integer"
        end
        arr = {}
        local i = 0
        while n > 0 do
            i = i + 1
            arr[i] = n % 10
            n = (n - arr[i]) / 10
        end
        -- array reversing
        local len = #arr + 1
        for i = 1, #arr/2 do
            local dt = arr[i]
            arr[i] = arr[len - i]
            arr[len - i] = dt
        end
    elseif type(n) == "table" then
        if not #n > 0 then return nil, "[ArgErr] empty array" end
        for _, d in ipairs(n) do
            if type(d) ~= "number" then
                return nil, "[ArgErr] array 'n' contains a not digit element"
            end
            if d < 0 or d > 9 then
                return nil, "[ArgErr] array contains a not digit number"
            end
        end
        arr = n
    elseif type(n) == "string" then
        arr = {}
        for c in string.gmatch(n, ".") do
            local d = tonumber(c)
            if (not d) or d > 9 then
                return nil, "[ArgErr] 's' contains a not digit char"
            end
            arr[#arr + 1] = d
        end
    else
        return nil, "[ArgErr] not a number, a string or an array of digits"
    end
    local i = #arr
    if i == 7 or i == 8 then
        return checksum_8_13(arr, 7)
    elseif i == 12 or i == 13 then
        return checksum_8_13(arr, 12)
    else
        return nil, "[Err] unsuitable data length for EAN8 or EAN13 checksum"
    end
end

-- internal methods for Barcode costructors

function EAN:_finalize(parse_state) --> ok, err
    local l1 = self._main_len
    local l2 = self._addon_len
    local ok_len = l1 + (l2 or 0)
    local symb_len = self._code_len
    if symb_len ~= ok_len then
        return false, "[ArgErr] not a "..ok_len.."-digits long array"
    end
    if self._is_last_checksum then -- is the last digit ok?
        local data = self._code_data
        local ck = checksum_8_13(data, l1 - 1)
        if ck ~= data[l1] then
            return false, "[Err] wrong checksum digit"
        end
    end
    local var = self._variant
    if var == "isbn" or var == "isbn+5" or var == "isbn+2" then
        -- check group number
        local code = parse_state.isbncode
        local g = 0
        for _, c in ipairs(code) do
            if c == "-" or c == " " then
                g = g + 1
            end
        end
        if g > 4 then
            return false, "[ArgErr] to many group in ISBN code"
        end
        self._isbncode = code
    end
    return true, nil
end

-- drawing functions

EAN._append_ga_variant = {}
local fn_append_ga_variant = EAN._append_ga_variant

-- draw EAN13 symbol
fn_append_ga_variant["13"] = function (ean, canvas, tx, ty, ax, ay)
    local code       = ean._code_data
    local mod        = ean.mod
    local bars_depth = mod * ean.bars_depth_factor
    local w, h       = 95*mod, ean.height + bars_depth
    local x0         = (tx or 0) - ax * w
    local y0         = (ty or 0) - ay * h
    local x1         = x0 + w
    local y1         = y0 + h
    local xpos       = x0 -- current insertion x-coord
    local ys         = y0 + bars_depth
    local s_width    = 7*mod
    local code_seq   = ean._codeset_seq[code[1]]
    -- draw the start symbol
    local err
    err = canvas:start_bbox_group(); assert(not err, err)
    local be = ean._13_start_stop_vbar
    err = canvas:encode_Vbar(be, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 3*mod
    -- draw the first 6 numbers
    for i = 2, 7 do
        local codeset = code_seq[i-1]
        local n = code[i]
        local vbar = ean._13_codeset_vbar[codeset][n]
        err = canvas:encode_Vbar(vbar, xpos, ys, y1); assert(not err, err)
        xpos = xpos + s_width
    end
    -- draw the control symbol
    local ctrl = ean._13_ctrl_center_vbar
    err = canvas:encode_Vbar(ctrl, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 5*mod
    -- draw the last 6 numbers
    for i = 8, 13 do
        local codeset = code_seq[i-1]
        local n = code[i]
        local vbar = ean._13_codeset_vbar[codeset][n]
        err = canvas:encode_Vbar(vbar, xpos, ys, y1); assert(not err, err)
        xpos = xpos + s_width
    end
    -- draw the stop char
    err = canvas:encode_Vbar(be, xpos, y0, y1); assert(not err, err)
    -- bounding box set up
    local qzl = ean.quietzone_left_factor * mod
    local qzr = ean.quietzone_right_factor * mod
    local err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
    assert(not err, err)
    if ean.text_enabled then -- human readable text
        local Text  = ean._libgeo.Text
        local txt_1 = Text:from_digit_array(code, 1,  1)
        local txt_2 = Text:from_digit_array(code, 2,  7)
        local txt_3 = Text:from_digit_array(code, 8, 13)
        local y_bl = ys - ean.text_ygap_factor * mod
        local mx = ean.text_xgap_factor
        local err
        err = canvas:encode_Text(txt_1, x0 - qzl, y_bl, 0, 1)
        assert(not err, err)
        local x2_1 = x0 + (3+mx)*mod
        local x2_2 = x0 + (46-mx)*mod
        err = canvas:encode_Text_xwidth(txt_2, x2_1, x2_2, y_bl, 1)
        assert(not err, err)
        local x3_1 = x0 + (49+mx)*mod
        local x3_2 = x0 + (92-mx)*mod
        err = canvas:encode_Text_xwidth(txt_3, x3_1, x3_2, y_bl, 1)
        assert(not err, err)
        if ean.text_isbn_enabled then
            local isbn = assert(ean._isbncode, "[InternalErr] ISBN text not found")
            local descr = {"I", "S", "B", "N", " ",}
            for _, d in ipairs(isbn) do
                descr[#descr + 1] = d
            end
            local isbn_txt = Text:from_chars(descr)
            local x_isbn = x0 + 47.5 * mod
            local y_isbn = y1 + ean.text_isbn_ygap_factor * mod
            local err
            err = canvas:encode_Text(isbn_txt, x_isbn, y_isbn, 0.5, 0)
            assert(not err, err)
        end
    end
end

-- draw EAN8 symbol
fn_append_ga_variant["8"] = function (ean, canvas, tx, ty, ax, ay)
    local code       = ean._code_data
    local mod        = ean.mod
    local bars_depth = mod * ean.bars_depth_factor
    local w, h       = 67*mod, ean.height + bars_depth
    local x0         = (tx or 0) - ax * w
    local y0         = (ty or 0) - ay * h
    local x1         = x0 + w
    local y1         = y0 + h
    local xpos       = x0 -- current insertion x-coord
    local ys         = y0 + bars_depth
    local s_width    = 7*mod
    -- draw the start symbol
    local err
    err = canvas:start_bbox_group(); assert(not err, err)
    local be = ean._8_start_stop_vbar
    err = canvas:encode_Vbar(be, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 3*mod
    -- draw the first 4 numbers
    local t_vbar = ean._8_codeset_vbar
    local cs14 = ean._codeset14_8
    for i = 1, 4 do
        local n = code[i]
        local vbar = t_vbar[cs14][n]
        err = canvas:encode_Vbar(vbar, xpos, ys, y1); assert(not err, err)
        xpos = xpos + s_width
    end
    -- draw the control symbol
    local ctrl = ean._8_ctrl_center_vbar
    err = canvas:encode_Vbar(ctrl, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 5*mod
    -- draw the product code
    local cs58 = ean._codeset58_8
    for i = 5, 8 do
        local n    = code[i]
        local vbar = t_vbar[cs58][n]
        err = canvas:encode_Vbar(vbar, xpos, ys, y1); assert(not err, err)
        xpos = xpos + s_width
    end
    -- draw the stop char
    err = canvas:encode_Vbar(be, xpos, y0, y1); assert(not err, err)
    -- bounding box set up
    local qzl = ean.quietzone_left_factor * mod
    local qzr = ean.quietzone_right_factor * mod
    local err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
    assert(not err, err)
    if ean.text_enabled then -- human readable text
        local Text  = ean._libgeo.Text
        local t_1 = Text:from_digit_array(code, 1, 4)
        local t_2 = Text:from_digit_array(code, 5, 8)
        local y_bl  = ys - ean.text_ygap_factor * mod
        local mx    = ean.text_xgap_factor
        local x1_1 = x0 + ( 3 + mx)*mod
        local x1_2 = x0 + (32 - mx)*mod
        err = canvas:encode_Text_xwidth(t_1, x1_1, x1_2, y_bl, 1)
        assert(not err, err)
        local x2_1 = x0 + (35+mx)*mod
        local x2_2 = x0 + (64-mx)*mod
        err = canvas:encode_Text_xwidth(t_2, x2_1, x2_2, y_bl, 1)
        assert(not err, err)
    end
end

-- draw EAN5 add-on symbol
fn_append_ga_variant["5"] = function (ean, canvas, tx, ty, ax, ay, h)
    local code = ean._code_data
    local l1 = ean._main_len
    local i1; if l1 == 5 then
        i1 = 1
    else
        i1 = l1 + 1
    end
    local i2 = i1 + 4
    local mod    = ean.mod
    local w      = 47*mod
    h = h or ean.height
    local x0     = (tx or 0) - ax * w
    local y0     = (ty or 0) - ay * h
    local x1     = x0 + w
    local y1     = y0 + h
    local xpos   = x0 -- current insertion x-coord
    local sym_w  = 7*mod
    local sep_w  = 2*mod
    -- draw the start symbol
    local err
    err = canvas:start_bbox_group(); assert(not err, err)
    local start = ean._5_start_vbar
    err = canvas:encode_Vbar(start, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 4*mod
    local ck = checksum_5_2(code, i1, 5)
    local codeset = ean._codeset_5[ck]
    local sep    = ean._5_sep_vbar
    local t_vbar = ean._5_codeset_vbar
    -- draw the five digits
    local k = 0
    for i = i1, i2 do
        k = k + 1
        local cs = codeset[k] -- 1 or 2
        local d = code[i]
        local vbar = t_vbar[cs][d]
        err = canvas:encode_Vbar(vbar, xpos, y0, y1); assert(not err, err)
        xpos = xpos + sym_w
        if k < 5 then
            err = canvas:encode_Vbar(sep, xpos, y0, y1); assert(not err, err)
            xpos = xpos + sep_w
        end
    end
    -- bounding box set up
    local qzl = ean.quietzone_left_factor * mod
    local qzr = ean.quietzone_right_factor * mod
    local err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
    assert(not err, err)
    if ean.text_enabled then -- human readable text
        local Text = ean._libgeo.Text
        local txt  = Text:from_digit_array(code, i1, i2)
        local y_bl = y1 + ean.text_ygap_factor * mod
        local x1_1 = x0 + 3*mod
        local x1_2 = x1 - 3*mod
        err = canvas:encode_Text_xwidth(txt, x1_1, x1_2, y_bl, 0)
        assert(not err, err)
    end
end

-- draw EAN2 symbol
fn_append_ga_variant["2"] = function (ean, canvas, tx, ty, ax, ay, h)
    local code = ean._code_data
    local l1 = ean._main_len
    local i1; if l1 == 2 then
        i1 = 1
    else
        i1 = l1 + 1
    end
    local mod = ean.mod
    local w = 20*mod
    h = h or ean.height
    local x0 = (tx or 0.0) - ax * w
    local y0 = (ty or 0.0) - ay * h
    local x1 = x0 + w
    local y1 = y0 + h
    local xpos = x0 -- current insertion x-coord
    local sym_w = 7*mod
    local sep_w = 2*mod
    -- draw the start symbol
    local err
    err = canvas:start_bbox_group(); assert(not err, err)
    local start = ean._2_start_vbar
    err = canvas:encode_Vbar(start, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 4*mod
    local r = checksum_5_2(code, i1, 2)
    local s1, s2
    if r == 0 then     -- LL scheme
        s1, s2 = 1, 1
    elseif r == 1 then -- LG scheme
        s1, s2 = 1, 2
    elseif r == 2 then -- GL scheme
        s1, s2 = 2, 1
    else -- r == 3     -- GG scheme
        s1, s2 = 2, 2
    end
    local t_vbar = ean._2_codeset_vbar
    local d1 = code[i1] -- render the first digit
    local vb1 = t_vbar[s1][d1]
    err = canvas:encode_Vbar(vb1, xpos, y0, y1); assert(not err, err)
    xpos = xpos + sym_w
    local sep  = ean._2_sep_vbar
    err = canvas:encode_Vbar(sep, xpos, y0, y1); assert(not err, err)
    xpos = xpos + sep_w
    local d2 = code[i1 + 1] -- render the second digit
    local vb2 = t_vbar[s2][d2]
    err = canvas:encode_Vbar(vb2, xpos, y0, y1); assert(not err, err)
    -- bounding box set up
    local qzl = ean.quietzone_left_factor * mod
    local qzr = ean.quietzone_right_factor * mod
    local err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
    assert(not err, err)
    if ean.text_enabled then -- human readable text
        local Text  = ean._libgeo.Text
        local txt = Text:from_digit_array(code, i1, i1 + 1)
        local y_bl = y1 + ean.text_ygap_factor * mod
        local x1_1 = x0 + 3*mod
        local x1_2 = x1 - 3*mod
        err = canvas:encode_Text_xwidth(txt, x1_1, x1_2, y_bl, 0)
        assert(not err, err)
    end
end

fn_append_ga_variant["13+5"] = function (ean, canvas, tx, ty, ax, ay)
    local mod = ean.mod
    local bars_depth = mod * ean.bars_depth_factor
    local h = ean.height + bars_depth
    local w = (142 + ean.addon_xgap_factor) * mod
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local fn_ga = ean._append_ga_variant
    local fn_1 = fn_ga["13"]
    local fn_2 = fn_ga["5"]
    fn_1(ean, canvas, x0, y0, 0, 0)
    fn_2(ean, canvas, x1, y0, 1, 0, 0.85 * h)
end

fn_append_ga_variant["13+2"] = function (ean, canvas, tx, ty, ax, ay)
    local mod = ean.mod
    local bars_depth = mod * ean.bars_depth_factor
    local h = ean.height + bars_depth
    local w = (115 + ean.addon_xgap_factor) * mod
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local fn_ga = ean._append_ga_variant
    local fn_1 = fn_ga["13"]
    local fn_2 = fn_ga["2"]
    fn_1(ean, canvas, x0, y0, 0, 0)
    fn_2(ean, canvas, x1, y0, 1, 0, 0.85 * h)
end

fn_append_ga_variant["8+5"] = function (ean, canvas, tx, ty, ax, ay)
    local mod = ean.mod
    local bars_depth = mod * ean.bars_depth_factor
    local h = ean.height + bars_depth
    local w = (114 + ean.addon_xgap_factor) * mod
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local fn_ga = ean._append_ga_variant
    local fn_1 = fn_ga["8"]
    local fn_2 = fn_ga["5"]
    fn_1(ean, canvas, x0, y0, 0, 0)
    fn_2(ean, canvas, x1, y0, 1, 0, 0.85 * h)
end

fn_append_ga_variant["8+2"] = function (ean, canvas, tx, ty, ax, ay)
    local mod = ean.mod
    local bars_depth = mod * ean.bars_depth_factor
    local h = ean.height + bars_depth
    local w = (87 + ean.addon_xgap_factor) * mod
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local fn_ga = ean._append_ga_variant
    local fn_1 = fn_ga["8"]
    local fn_2 = fn_ga["2"]
    fn_1(ean, canvas, x0, y0, 0, 0)
    fn_2(ean, canvas, x1, y0, 1, 0, 0.85 * h)
end

fn_append_ga_variant["isbn"] = fn_append_ga_variant["13"]
fn_append_ga_variant["isbn+5"] = fn_append_ga_variant["13+5"]
fn_append_ga_variant["isbn+2"] = fn_append_ga_variant["13+2"]

-- Drawing into the provided channel geometrical data
-- tx, ty is the optional translation vector
-- the function return the canvas reference to allow call chaining
function EAN:append_ga(canvas, tx, ty) --> canvas
    local var = self._variant
    local fn_append_ga = assert(self._append_ga_variant[var])
    local ax, ay = self.ax, self.ay
    fn_append_ga(self, canvas, tx, ty, ax, ay)
    return canvas
end

return EAN
