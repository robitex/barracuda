-- EAN family barcode generator
--
-- Copyright (C) 2020 Roberto Giacomelli
-- see LICENSE.txt file

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
    ["issn"] = true, -- ISSN 13 digits
    ["issn+2"] = true, -- ISSN 13 digits with an EAN2 add-on
    ["issn+5"] = true, -- ISSN 13 digits with an EAN2 add-on
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

-- common family parameters
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
    fncheck    = function (_self, x, _) --> boolean, err
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
    fncheck    = function (_self, qzf, _) --> boolean, err
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
    fncheck    = function (_self, qzf, _) --> boolean, err
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
    fncheck    = function (_self, b, _) --> boolean, err
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
    fncheck    = function (_self, flag, _) --> boolean, err
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
    fncheck    = function (_self, t, _) --> boolean, err
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
    fncheck    = function (_self, t, _) --> boolean, err
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
    ["issn"] = { -- ISSN 13 digits, International Standard Serial Number
        "text_issn_enabled",
        "text_issn_ygap_factor",
    },
    ["issn+2"] = { -- ISSN 13 digits with an EAN2 add-on
        "text_issn_enabled",
        "text_issn_ygap_factor",
        "addon_xgap_factor",
    },
    ["issn+5"] = { -- ISSN 13 digits with an EAN2 add-on
        "text_issn_enabled",
        "text_issn_ygap_factor",
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
    -- ISBN
    ["isbn"] = {}, -- ISBN 13 digits
    ["isbn+2"] = {}, -- ISBN 13 digits with an EAN2 add-on
    ["isbn+5"] = {}, -- ISBN 13 digits with an EAN2 add-on
    -- ISSN
    ["issn"] = {}, -- ISBN 13 digits
    ["issn+2"] = {}, -- ISBN 13 digits with an EAN2 add-on
    ["issn+5"] = {}, -- ISBN 13 digits with an EAN2 add-on
}
local par_def_var = EAN._par_def_variant

-- EAN ISBN/ISSN/13/8 + add-on parameters
local addon_xgap_factor = {-- distance between main and add-on symbol
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (_self, t, _) --> boolean, err
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
-- ISBN
par_def_var["isbn+5"].addon_xgap_factor = addon_xgap_factor
par_def_var["isbn+2"].addon_xgap_factor = addon_xgap_factor
-- ISSN
par_def_var["issn+5"].addon_xgap_factor = addon_xgap_factor
par_def_var["issn+2"].addon_xgap_factor = addon_xgap_factor

-- text_ISBN_* parameter
-- enable/disable a text ISBN label upon the barcode symbol
-- if it is "auto" the isbn text appears or not and depends by input code
local isbn_text_enabled = { -- boolean type
    default    = "auto",
    isReserved = false,
    fncheck    = function (_self, flag, _) --> boolean, err
        if type(flag) == "boolean" or
            (type(flag) == "string" and flag == "auto") then
            return true, nil
        else
            return false, "[TypeErr] not a boolean or 'auto' for text_isbn_enabled"
        end
    end,
}
-- ISBN
par_def_var["isbn+5"].text_isbn_enabled = isbn_text_enabled
par_def_var["isbn+2"].text_isbn_enabled = isbn_text_enabled
par_def_var["isbn"].text_isbn_enabled = isbn_text_enabled

-- text_ISSN_* parameter
-- enable/disable a text ISBN label upon the barcode symbol
-- if it is "auto" the isbn/issn text appears or not and depends by input code
local issn_text_enabled = { -- boolean type
    default    = true,
    isReserved = false,
    fncheck    = function (_self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value for text_issn_enabled"
        end
    end,
}

-- ISSN
par_def_var["issn+5"].text_issn_enabled = issn_text_enabled
par_def_var["issn+2"].text_issn_enabled = issn_text_enabled
par_def_var["issn"].text_issn_enabled = issn_text_enabled

-- ISBN text vertical distance
local text_ygap_factor = {
    default    = 2.0,
    unit       = "absolute-number",
    isReserved = false,
    fncheck    = function (_self, t, _) --> boolean, err
        if t >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for text_isbn_ygap_factor"
        end
    end,
}
-- ISBN
par_def_var["isbn+5"].text_isbn_ygap_factor = text_ygap_factor
par_def_var["isbn+2"].text_isbn_ygap_factor = text_ygap_factor
par_def_var["isbn"].text_isbn_ygap_factor = text_ygap_factor
-- ISSN
par_def_var["issn+5"].text_issn_ygap_factor = text_ygap_factor
par_def_var["issn+2"].text_issn_ygap_factor = text_ygap_factor
par_def_var["issn"].text_issn_ygap_factor = text_ygap_factor

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
-- ISBN
config_variant["isbn"] = config_variant["13"]
config_variant["isbn+2"] = config_variant["13+2"]
config_variant["isbn+5"] = config_variant["13+5"]
-- ISSN
config_variant["issn"] = config_variant["13"]
config_variant["issn+2"] = config_variant["13+2"]
config_variant["issn+5"] = config_variant["13+5"]
EAN._config_variant = config_variant

-- utility function

-- the checksum of EAN8 or EAN13 code
-- 'data' is an array of digits
local function checksum_8_13(data, stop_index) --> checksum
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

-- ISBN utility function

-- return the ISBN 10 digits checksum
local function isbn_checksum(isbn)
    local sum = 0
    for w = 1, 9 do
        sum = sum + w * isbn[w]
    end
    return sum % 11
end

-- group char for readibility '-' or ' '
-- char won't be inserted in the top isbn code
local function isbn_check_char(_, c, parse_state) --> elem, err
    if type(c) ~= "string" or #c ~= 1 then
        return nil, "[InternalErr] invalid char"
    end
    if parse_state.isbncode == nil then parse_state.isbncode = {} end
    local code = parse_state.isbncode
    if parse_state.isspace == nil then parse_state.isspace = false end
    if parse_state.isdash == nil then parse_state.isdash = false end
    if parse_state.isbn_len == nil then parse_state.isbn_len = 0 end
    local isbn_len = parse_state.isbn_len
    if c == "-" then
        if isbn_len == 0 then
            return nil, "[ArgErr] an initial dash is not allowed"
        end
        if parse_state.isdash then
            return nil, "[ArgErr] two consecutive dash char found"
        end
        parse_state.isdash = true
        return nil, nil
    elseif c == " " then
        if isbn_len == 0 then
            return nil, "[ArgErr] an initial space is not allowed"
        end
        parse_state.isspace = true
        return nil, nil
    elseif c == "X" then -- ISBN-10 checksum for 10
        code[#code + 1] = c
        isbn_len = isbn_len + 1
        parse_state.isbn_len = isbn_len
        if isbn_len ~= 10 then
            return nil, "[ArgErr] found a checksum 'X' in a wrong position"
        end
        return 10, nil
    else -- c is at this point eventually a digit
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
        code[#code + 1] = c
        isbn_len = isbn_len + 1
        parse_state.isbn_len = isbn_len
        return n, nil
    end
end

-- overriding function called every time an input ISBN code has been completely
-- parsed
local function isbn_finalize(enc, parse_state) --> ok, err
    local var = enc._variant
    local code_len = enc._code_len
    local isbn_len = parse_state.isbn_len
    local l1, l2
    if var == "isbn" then
        if isbn_len == 10 then
            l1 = 10
        elseif isbn_len == 13 then
            l1 = 13
        else
            return false, "[ArgErr] unsuitable ISBN code length"
        end
        assert(l1 == code_len)
    elseif var == "isbn+5" then
        assert(enc._addon_len == 5)
        if isbn_len == 15 then
            l1, l2 = 10, 5
        elseif isbn_len == 18 then
            l1, l2 = 13, 5
        else
            return false, "[ArgErr] unsuitable ISBN+5 code length"
        end
        assert(l1 + l2 == code_len)
    elseif var == "isbn+2" then
        assert(enc._addon_len == 2)
        if isbn_len == 12 then
            l1, l2 = 10, 2
        elseif isbn_len == 15 then
            l1, l2 = 13, 2
        else
            return false, "[ArgErr] unsuitable ISBN+2 code length"
        end
        assert(l1 + l2 == code_len)
    else
        error("[InternalErr] unexpected ISBN variant code")
    end
    local code_data = enc._code_data
    local isbn_auto = false
    if l1 == 10 then -- isbn 10 to 13 conversion
        local ck = isbn_checksum(code_data)
        if ck ~= code_data[10] then
            return false, "[ArgErr] unmatched ISBN 10 checksum"
        end
        for i = l1 + (l2 or 0), 1, -1 do -- code_data sliding
            code_data[i + 3] = code_data[i]
        end
        code_data[1] = 9
        code_data[2] = 7
        code_data[3] = 8
        code_data[13] = checksum_8_13(code_data, 12)
        isbn_auto = true
    else
        local ck = checksum_8_13(code_data, 12)
        if code_data[13] ~= ck then
            return false, "[ArgErr] unmatched ISBN 13 checksum"
        end
    end
    local isbncode = parse_state.isbncode
    if l2 then -- nils the add-on digits
        local i = #isbncode
        while l2 > 0 do
            local c = isbncode[i]
            isbncode[i] = nil
            i = i - 1
            if not (c == " " or c == "-") then
                l2 = l2 - 1
            end
        end
        local c = isbncode[i]
        if c == " " or c == "-" then isbncode[i] = nil end
    end
    -- check group number
    local g = 0
    for _, c in ipairs(isbncode) do
        if c == "-" or c == " " then
            g = g + 1
        end
    end
    if g > 4 then
        return false, "[ArgErr] too many groups found in the ISBN code"
    end
    if g > 0 then isbn_auto = true end
    enc._isbncode = isbncode
    enc._isbntxt_on = isbn_auto
    return true, nil
end

-- ISSN utility fucntion

-- return the ISSN checksum
local function issn_checksum(issn)
    local sum = 0
    for i = 1, 7 do
        sum = sum + (9 - i) * issn[i]
    end
    local r = sum % 11
    if r == 0 then
        return 0
    else
        return 11 - r
    end
end

local function to_n(c) --> n, err
    local n = string.byte(c) - 48
    if n < 0 or n > 9 then
        return nil, true
    end
    return n, false
end

-- ISSN dddd-dddx[dd] or 13-long array
-- spaces is always ignored
local function issn_check_char(enc, c, parse_state) --> elem, err
    if (type(c) ~= "string") or (#c ~= 1) then
        return nil, "[InternalErr] invalid char"
    end
    if parse_state.is_dash == nil then parse_state.is_dash = false end
    if parse_state.is_group_open == nil then parse_state.is_group_open = false end
    if parse_state.is_group_close == nil then parse_state.is_group_close = false end
    if parse_state.ed_var_len == nil then parse_state.ed_var_len = 0 end
    if parse_state.ed_var_arr == nil then parse_state.ed_var_arr = {} end
    if parse_state.code_len == nil then parse_state.code_len = 0 end
    if parse_state.addon_len == nil then parse_state.addon_len = 0 end
    local addon_len = enc._addon_len
    -- edition variant part
    if c == " " then
        return nil, nil -- ignore all spaces
    end
    if parse_state.is_group_close then
        if addon_len then
            if parse_state.addon_len == enc._addon_len then
                return nil, "[ArgErr] too many chars in the ISSN input code"
            end
            local n, e = to_n(c)
            if e then
                return nil, "[ArgErr] non digit char after a edition variant group"
            end
            parse_state.addon_len = parse_state.addon_len + 1
            return n, nil
        else
            return nil, "[ArgErr] too many chars in the ISSN input code"
        end
    end
    -- code part
    if c == "-" then
        if parse_state.is_dash then
            return nil, "[ArgErr] two or more dash char in the input code"
        end
        if parse_state.code_len ~= 4 then
            return nil, "[ArgErr] incorrect position for a dash sign"
        end
        parse_state.is_dash = true
        return nil, nil
    elseif c == "[" then -- two digits edition variant group opening
        if parse_state.code_len ~= 8 then
            return nil, "[ArgErr] not a 8 digits long code for the ISSN input"
        end
        parse_state.is_group_open = true
        return nil, nil
    elseif c == "]" then -- two digits edition variant closing
        if not parse_state.is_group_open then
            return nil, "[ArgErr] found a ']' without a '['"
        end
        if parse_state.ed_var_len ~= 2 then
            return nil, "[ArgErr] edition variant group must be two digits long"
        end
        parse_state.is_group_open = false
        parse_state.is_group_close = true
        return nil, nil
    elseif c == "X" then -- 8th ISSN checksum digit
        if parse_state.code_len ~= 7 then
            return nil, "[ArgErr] incorrect position for checksum digit 'X'"
        end
        parse_state.code_len = 8
        return 10, nil
    else -- at this point 'c' can be only a digit
        local n, e = to_n(c)
        if e then
            return nil, "[ArgErr] found a non digit in code part"
        end
        if parse_state.is_group_open then
            if parse_state.ed_var_len == 2 then
                return nil, "[ArgErr] group digits are more than two"
            end
            parse_state.ed_var_len = parse_state.ed_var_len + 1
            local t = parse_state.ed_var_arr
            t[#t + 1] = n
            return nil, nil
        end
        if parse_state.is_dash then
            if addon_len then
                if parse_state.code_len < 8 then
                    parse_state.code_len = parse_state.code_len + 1
                else
                    if parse_state.addon_len == addon_len then
                        return nil, "[ArgErr] too many digits for a 8 + "..addon_len.." ISSN input code"
                    end
                    parse_state.addon_len = parse_state.addon_len + 1
                end
            else
                if parse_state.code_len == 8 then
                    return nil, "[ArgErr] too many digits found for a 8 digits long ISSN input code"
                end
                parse_state.code_len = parse_state.code_len + 1
            end
        else
            if addon_len then
                if parse_state.code_len == (13 + addon_len) then
                    return nil, "[ArgErr] too many digits in ISSN input code"
                end
            else
                if parse_state.code_len == 13 then
                    return nil, "[ArgErr] too many digits in a 13 digits long ISSN input code"
                end
            end
            parse_state.code_len = parse_state.code_len + 1
        end
        return n, nil
    end
end

-- translate an ISSN 8 in an EAN 13
local function issn8_to_13(issn, ed_var_1, ed_var_2) --> i13, i8, err
    local r13, r8 = {9, 7, 7}, {}
    for i = 1, 7 do
        r8[i]  = issn[i]
        r13[i + 3] = issn[i]
    end
    local issn_cs = issn_checksum(r8)
    if issn_cs ~= issn[8] then
        return nil, nil, "[Err] unmatch ISSN 8 checksum"
    end
    for i = 1, 7 do
        r8[i] = string.char(r8[i] + 48)
    end
    if issn_cs == 10 then
        r8[8] = "X"
    else
        r8[8] = string.char(issn_cs + 48)
    end
    r13[11] = ed_var_1
    r13[12] = ed_var_2
    r13[13] = checksum_8_13(r13, 12)
    return r13, r8, nil
end

-- translate an EAN 13 to an ISSN 8 input code
local function ean13_to_issn8(ean)
    local res = {}
    for i = 4, 10 do
        res[i - 3] = ean[i]
    end
    local issn_cs = issn_checksum(res)
    for i = 1, 7 do
        res[i] = string.char(res[i] + 48)
    end
    if issn_cs == 10 then
        res[8] = "X"
    else
        res[8] = string.char(issn_cs + 48)
    end
    return res
end

-- finalize the ISSN input code
-- new field 'enc._issn_is_short_input' -- the input code was 8 digits long
-- new filed 'enc._issn_is_dash'        -- the 8 digits long input code contained a dash
local function issn_finalize(enc, parse_state) --> ok, err
    if parse_state.is_group_open then
        return false, "[ArgErr] unclosed edition variant group in ISSN input code"
    end
    local data = enc._code_data
    local code_len = enc._code_len
    local addon_len = enc._addon_len
    local main_len = code_len - (addon_len or 0)
    if main_len == 8 then
        -- make the 8 long array for human readable text
        local ev1, ev2 = 0, 0
        if parse_state.ed_var_len > 0 then
            local edvar = parse_state.ed_var_arr
            ev1, ev2 = edvar[1], edvar[2]
        end
        local issn13, issn8, err = issn8_to_13(data, ev1, ev2)
        if err then return false, err end
        if addon_len then
            for i = 9, 9 + addon_len do
                issn13[i + 5] = data[i] -- save addon digits
            end
        end
        enc._code_data = issn13
        enc._code_text = issn8
        enc._issn_is_short_input = true
        enc._issn_is_dash = parse_state.is_dash
    elseif main_len == 13 then
        local ck = checksum_8_13(data, 12) -- check EAN checksum
        if ck ~= data[13] then
            return false, "[Err] wrong checksum digit"
        end
        -- make 8 long array for human readable text
        enc._code_text = ean13_to_issn8(data)
        enc._issn_is_short_input = false
    else
        return nil, "[ArgErr] incorrect digits number of "..main_len.." in input ISSN code"
    end
    return true, nil
end

-- finalize for basic encoder
local function basic_finalize(enc) --> ok, err
    local l1 = enc._main_len
    local l2 = enc._addon_len
    local ok_len = l1 + (l2 or 0)
    local symb_len = enc._code_len
    if symb_len ~= ok_len then
        return false, "[ArgErr] not a "..ok_len.."-digit long array"
    end
    if enc._is_last_checksum then -- is the last digit ok?
        local data = enc._code_data
        local ck = checksum_8_13(data, l1 - 1)
        if ck ~= data[l1] then
            return false, "[Err] wrong checksum digit"
        end
    end
    return true, nil
end

-- config function called at the moment of encoder construction
-- create all the possible VBar object
function EAN:_config() --> ok, err
    local variant = self._variant
    if not variant then
        return false, "[Err] variant is mandatory for EAN family"
    end
    local plus = variant:find("+")
    local v1
    if plus then
        v1 = variant:sub(1, plus - 1)
        self._sub_variant_1 = v1
        self._sub_variant_2 = variant:sub(plus + 1)
    else
        v1 = variant
        self._sub_variant_1 = v1
    end
    local fnconfig = self._config_variant[variant]
    local VbarClass = self._libgeo.Vbar -- Vbar class
    local mod = self.mod
    fnconfig(self, VbarClass, mod)
    if v1 == "isbn" then
        self._check_char = isbn_check_char
    elseif v1 == "issn" then
        self._check_char = issn_check_char
    end
    return true, nil
end

-- internal methods for Barcode costructors

-- function called every time an input EAN code has been completely parsed
function EAN:_finalize(parse_state) --> ok, err
    local v1 = self._sub_variant_1
    if v1 == "isbn" then
        return isbn_finalize(self, parse_state) --> ok, err
    elseif v1 == "issn" then
        return issn_finalize(self, parse_state) --> ok, err
    else
        return basic_finalize(self) --> ok, err
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
            return nil, "[ArgErr] 'n' argument is not an integer"
        end
        arr = {}
        local i = 0
        while n > 0 do
            i = i + 1
            arr[i] = n % 10
            n = math.floor((n - arr[i]) / 10)
        end
        -- array reversing
        local len = #arr + 1
        for k = 1, #arr/2 do
            local dt = arr[k]
            arr[k] = arr[len - k]
            arr[len - k] = dt
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
    err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
    assert(not err, err)
    if ean.text_enabled then -- human readable text
        local Text  = ean._libgeo.Text
        local txt_1 = Text:from_digit_array(code, 1,  1)
        local txt_2 = Text:from_digit_array(code, 2,  7)
        local txt_3 = Text:from_digit_array(code, 8, 13)
        local y_bl = ys - ean.text_ygap_factor * mod
        local mx = ean.text_xgap_factor
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
        local istxt = false
        if ean.text_isbn_enabled then
            if ean.text_isbn_enabled == "auto" then
                if ean._isbntxt_on == true then
                    istxt = true
                end
            else
                istxt = true
            end
        end
        if istxt then
            local isbn = assert(ean._isbncode, "[InternalErr] ISBN text not found")
            local descr = {"I", "S", "B", "N", " ",}
            for _, d in ipairs(isbn) do
                descr[#descr + 1] = d
            end
            local isbn_txt = Text:from_chars(descr)
            local x_isbn = x0 + 47.5 * mod
            local y_isbn = y1 + ean.text_isbn_ygap_factor * mod
            err = canvas:encode_Text(isbn_txt, x_isbn, y_isbn, 0.5, 0)
            assert(not err, err)
        end
        -- issn text
        if ean.text_issn_enabled then
            local hri = {"I", "S", "S", "N", " "}
            local txt = assert(ean._code_text, "[IternalErr] _code_text not found")
            for i = 1, 4 do
                hri[i + 5] = txt[i]
            end
            hri[10] = "-"
            for i = 5, 8 do
                hri[i + 6] = txt[i]
            end
            local issn_txt = Text:from_chars(hri)
            local x_issn = x0 + 47.5 * mod
            local y_issn = y1 + ean.text_issn_ygap_factor * mod
            err = canvas:encode_Text(issn_txt, x_issn, y_issn, 0.5, 0)
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
    err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
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
    err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
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
    err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
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

-- ISBN
fn_append_ga_variant["isbn"] = fn_append_ga_variant["13"]
fn_append_ga_variant["isbn+5"] = fn_append_ga_variant["13+5"]
fn_append_ga_variant["isbn+2"] = fn_append_ga_variant["13+2"]
-- ISSN
fn_append_ga_variant["issn"] = fn_append_ga_variant["13"]
fn_append_ga_variant["issn+5"] = fn_append_ga_variant["13+5"]
fn_append_ga_variant["issn+2"] = fn_append_ga_variant["13+2"]

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
