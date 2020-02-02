-- Interleaved 2 of 5 (ITF) barcode generator
--
-- Copyright (C) 2020 Roberto Giacomelli
-- see LICENSE.txt file

local ITF = { -- main container
    _VERSION     = "i2of5 v0.0.1",
    _NAME        = "i2of5",
    _DESCRIPTION = "Interleaved 2 of 5 barcode encoder",
}

ITF._id_variant = {
    ITF14 = true, -- ITF 14 GS1 specification
}

ITF._start = 111 -- nnnn
ITF._stop = 112 -- Wnn (integer must be in reverse order)

ITF._pattern = { -- true -> narrow, false -> Wide
    [0] = {true, true, false, false, true},
    [1] = {false, true, true, true, false},
    [2] = {true, false, true, true, false},
    [3] = {false, false, true, true, true},
    [4] = {true, true, false, true, false},
    [5] = {false, true, false, true, true},
    [6] = {true, false, false, true, true},
    [7] = {true, true, true, false, false},
    [8] = {false, true, true, false, true},
    [9] = {true, false, true, false, true},
}

-- define parameters
ITF._par_order = {
    "module",
    "ratio",
    "height",
    "quietzone",
    "check_digit_policy",
    "check_digit_method",
    "bearer_bars_enabled",
    "bearer_bars_thickness",
    "bearer_bars_layout",
}
ITF._par_def = {}
local pardef = ITF._par_def

-- module main parameter
pardef.module = {
    -- Narrow element X-dimension is the width of the smallest element.
    -- The module width (width of narrow element) should be at least 7.5 mils
    -- that is exactly 0.1905mm (1 mil is 1/1000 inch).
    default    = 7.5 * 0.0254 * 186467, -- 7.5 mils (sp) unit misure,
    unit       = "sp", -- scaled point
    isReserved = true,
    fncheck    = function (self, mod, _t_opt) --> boolean, err
        if mod >= self.default then return true, nil end
        return false, "[OutOfRange] too small lenght for X-dim"
    end,
}

pardef.ratio = {
    -- The "wide" element is a multiple of the "narrow" element that can
    -- range between 2.0 and 3.0. Preferred value is 3.0.
    -- The multiple for the wide element should be between 2.0 and 3.0 if the
    -- narrow element is greater than 20 mils. If the narrow element is less
    -- than 20 mils (0.508mm), the ratio must exceed 2.2.
    default    = 3.0,
    unit       = "absolute-number",
    isReserved = true,
    fncheck    = function (_self, ratio, t_opt) --> ok, err
        local mils = 0.0254 * 186467 -- sp
        local mod = t_opt.module
        local minr; if mod < 20*mils then minr = 2.2 else minr = 2.0 end
        if ratio < minr then
            return false, "[OutOfRange] too small ratio (the min is "..minr..")"
        end
        if ratio > 3.0 then
            return false, "[OutOfRange] too big ratio (the max is 3.0)"
        end
        return true, nil
    end,
}

pardef.height = {
    -- The height should be at least 0.15 times the barcode's length or 0.25 inch.
    default    = 15 * 186467, -- 15mm -- TODO: better assessment for symbol length
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck = function (_self, h, _t_opt) --> boolean, err
        local mils = 0.0254 * 186467 -- scaled point (sp)
        if h >= 250*mils then
            return true, nil
        end
        return false, "[OutOfRange] height too small"
    end,
}

pardef.quietzone = {
    -- Quiet zones must be at least 10 times the module width or 0.25 inches,
    -- whichever is larger
    default    = 250 * 0.0254 * 186467, -- 0.25 inch (250 mils)
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck    = function (self, qz, _t_opt) --> boolean, err
        local mils = 0.0254 * 186467
        local mod = self.module
        local min = math.max(10*mod, 250*mils)
        if qz < min then
            return false, "[OutOfRange] quietzone too small"
        end
        return true, nil
    end,
}

pardef.check_digit_policy = { -- enumeration
    default    = "none",
    isReserved = false,
    policy_enum = {
        add    = true, -- add a check digit to the symbol
        verify = true, -- check the last digit of the symbol as check digit
        none   = true, -- do nothing
    },
    fncheck    = function (self, e, _t_opt) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.policy_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enum value not found"
        end
    end,
}

pardef.check_digit_method = { -- enumeration
    -- determine the algorithm for the check digit calculation
    default       = "mod_10",
    isReserved    = false,
    method_enum = {
        mod_10 = true, -- MOD 10 check digits method
    },
    fncheck = function (self, e, _t_opt) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.method_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enum value not found"
        end
    end,
}

pardef.bearer_bars_enabled = { -- boolean type
    -- enable/disable Bearer bars around the barcode symbol
    default    = false,
    isReserved = false,
    fncheck    = function (_self, flag, _t_opt) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value"
        end
    end,
}

pardef.bearer_bars_thickness = { -- dimension
    default    = 37.5 * 0.0254 * 186467, -- 5 modules
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck = function (_self, thick, t_opt) --> boolean, err
        local module = t_opt.module
        if thick >= 2*module then
            return true, nil
        end
        return false, "[OutOfRange] too small bearer bar thickness"
    end,
}

pardef.bearer_bars_layout = { -- enumeration
    -- horizontal/frame bearer bars
    default       = "hbar",
    isReserved    = false,
    method_enum = {
        frame = true, -- a rectangle around the symbol
        hbar = true, -- only top and bottom horizontal bars
    },
    fncheck = function (self, e, _t_opt) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.method_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enum value not found"
        end
    end,
}

-- ITF14: variant based on GS1 specification, see
-- https://www.gs1.org/sites/default/files/docs/barcodes/GS1_General_Specifications.pdf
-- GS1 ITF14 parameters vary in range and preferred value on the specific
-- application. Default are chosen for better suite the majority of cases

-- ITF14 variant parameters as family parameters alternative
ITF._par_def_ITF14 = {}
local itf14_pdef = ITF._par_def_ITF14

itf14_pdef.module = { -- module main parameter
    -- Narrow element X-dimension is the width of the smallest element.
    -- The module width must follow GS1 specification
    default    = 0.495 * 186467, -- 0.495 mm
    unit       = "sp", -- scaled point
    isReserved = true,
    fncheck    = function (_self, mod, _t_opt) --> boolean, err
        local mod_mm = mod * 186467 -- mm
        if (mod_mm < 0.264) or (mod_mm > 0.660) then
            return false, "[OutOfRange] X-dim is out of [0.264mm, 0.660mm]"
        end
        return true, nil
    end,
}

itf14_pdef.ratio = {
    -- The "wide" element is a multiple of the "narrow" element that can
    -- range between 2.25 and 3.0.
    default    = 2.5,
    unit       = "absolute-number",
    isReserved = true,
    fncheck    = function (_self, ratio, _t_opt) --> boolean, err
        if (ratio < 2.25) or (ratio > 3.0) then
            return false, "[OutOfRange] wide-to-narrow ratio is out of [2.25, 3.0]"
        end
        return true, nil
    end,
}

itf14_pdef.height = {
    -- The height should be at least 5.08 mm. Target value is 12.70 mm
    -- except in retail pharmacy and general distribution or non-retail pharmacy
    -- and general distribution
    default    = 12.70 * 186467, -- mm
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck = function (_self, h, _t_opt) --> boolean, err
        if h < 5.08 * 186467 then
            return false, "[OutOfRange] height is too small"
        end
        return true, nil
    end,
}

itf14_pdef.quietzone = {
    -- Quiet zones must be at least 10 times the module width
    default    = 10,
    unit       = "absolute-number", -- scaled point
    isReserved = false,
    fncheck    = function (_self, qz, _t_opt) --> boolean, err
        if qz < 10 then
            return false, "[OutOfRange] quietzone factor is too small (min 10x)"
        else
            return true, nil
        end
    end,
}

itf14_pdef.check_digit_policy = { -- enumeration
    default    = "check_or_add",
    isReserved = false,
    policy_enum = {
        check_or_add = true,
        add    = true, -- add a check digit to the symbol
        verify = true, -- check the last digit of the symbol as check digit
    },
    fncheck    = function (self, e, _t_opt) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.policy_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enum value '"..e.."' not found"
        end
    end,
}

-- itf14_pdef.check_digit_method = {} the same as the basic parameter

itf14_pdef.bearer_bars_enabled = { -- boolean type
    -- enable/disable Bearer bars around the barcode symbol
    default    = true,
    isReserved = false,
    fncheck    = function (_self, flag, _t_opt) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value"
        end
    end,
}

-- from GS1 spec:
-- For printing methods that do not require printing plates, the bearer bar
-- SHALL be a minimum of twice the width of a narrow bar (dark bar) and need
-- only appear at the top and bottom of the symbol, butting directly against
-- the top and bottom of the symbol bars (dark bars).
pardef.bearer_bars_thickness = { -- dimension
    default    = 5 * 0.495 * 186467, -- 5 modules
    unit       = "sp", -- scaled point
    isReserved = false,
    fncheck = function (_self, thick, t_opt) --> boolean, err
        local module = t_opt.module
        if thick >= 2*module then
            return true, nil
        end
        return false, "[OutOfRange] too small bearer bar thickness"
    end,
}

itf14_pdef.bearer_bars_layout = { -- enumeration
    -- horizontal/frame bearer bars
    default       = "frame",
    isReserved    = false,
    method_enum = {
        frame = true, -- a rectangle around the symbol
        hbar = true, -- top and bottom horizontal bars
    },
    fncheck = function (self, e, _) --> boolean, err
        if type(e) ~= "string" then return false, "[TypeError] not a string" end
        local keys = self.method_enum
        if keys[e] == true then
            return true, nil
        else
            return false, "[Err] enum value not found"
        end
    end,
}

-- auxiliary functions

-- separate a non negative integer in its digits {d_n-1, ..., d_1, d_0}
local function n_to_arr(n) --> len, digits
    local digits = {}
    local slen
    if n == 0 then
        digits[#digits + 1] = 0
        slen = 1 
    else
        slen = 0
        while n > 0 do
            local d = n % 10
            digits[#digits + 1] = d
            n = (n - d) / 10
            slen = slen + 1
        end
    end
    for k = 1, slen/2  do -- array reversing
        local h = slen - k + 1
        local d = digits[k]
        digits[k] = digits[h]
        digits[h] = d
    end
    return slen, digits
end

local function rshift(t)
    local tlen = #t
    for i = tlen, 1, -1 do
        t[i + 1] = t[i]
    end
    t[1] = 0
end

-- for general i2of5 symbols
local function check_mod10(data, last)
    local s3 = 0; for i = last, 1, -2 do
        s3 = s3 + data[i]
    end
    local s1 = 0; for i = last - 1, 1, -2 do
        s1 = s1 + data[i]
    end
    local sum = s1 + 3 * s3
    local m = sum % 10
    if m == 0 then return 0 else return 10 - m end
end

local function checkdigit(t, last, method)
    if method == "mod_10" then
        return check_mod10(t, last)
    else
        error("[InternalErr] unknow checksum method '"..method.."'")
    end
end

-- group char for readibility '(' or ')' or ' '
local function itf14_check_char(enc, c, parse_state) --> elem, err
    if type(c) ~= "string" or #c ~= 1 then
        return nil, "[InternalErr] invalid char"
    end
    if parse_state.itf14_code == nil then parse_state.itf14_code = {} end
    local code = parse_state.itf14_code
    if parse_state.is_space == nil then parse_state.is_space = false end
    if parse_state.is_popen == nil then parse_state.is_popen = false end
    if parse_state.itf14_len == nil then parse_state.itf14_len = 0 end
    local itf14_len = parse_state.itf14_len
    -- parsing
    if c == " " then
        if itf14_len == 0 then -- ignore initial spaces
            return nil, nil
        end
        parse_state.is_space = true
        return nil, nil
    elseif c == "(" then
        if parse_state.is_popen then
            return nil, "[Err] a parenthesis group is already open"
        end
        parse_state.is_popen = true
        code[#code + 1] = c
        return nil, nil
    elseif c == ")" then
        if not parse_state.is_popen then
            return nil, "[Err] found a closing parenthesis without an opening one"
        end
        parse_state.is_popen = false
        code[#code + 1] = c
        return nil, nil
    else -- c is at this point eventually a digit
        local n = string.byte(c) - 48
        if n < 0 or n > 9 then
            return nil, "[ArgErr] found a not digit or a not grouping char"
        end
        if parse_state.is_space then
            code[#code + 1] = " "
            parse_state.is_space = false
        end
        code[#code + 1] = c
        itf14_len = itf14_len + 1
        parse_state.itf14_len = itf14_len
        return n, nil
    end
end

-- configuration function
function ITF:_config() --> ok, err
    -- init Vbar objects
    local narrow = self.module
    local wide = narrow * self.ratio
    -- start symbol
    local Vbar = self._libgeo.Vbar -- Vbar class
    self._vbar_start = Vbar:from_int_revpair(self._start, narrow, wide)
    self._vbar_stop = Vbar:from_int_revpair(self._stop, narrow, wide)
    -- build every possible pair of digits from 00 to 99
    self._vbar_data = {}
    local vbar = self._vbar_data
    local pattern = self._pattern
    for dec = 0, 9 do
        for unit = 0, 9 do
            local t1 = pattern[dec]
            local t2 = pattern[unit]
            local n = dec*10 + unit
            vbar[n] = Vbar:from_two_tab(t1, t2, narrow, wide)
        end
    end
    local variant = self._variant
    if variant == "ITF14" then
        self._check_char = itf14_check_char
    end
    return true, nil
end

-- internal methods for constructors

-- input code post processing for ITF14 variant
local function itf14_finalize(enc) --> ok, err
    -- check digit action
    local policy = enc.check_digit_policy
    local slen = enc._code_len
    local digits = enc._code_data
    local is_add
    if policy == "verify" then
        if slen ~= 14 then
            return nil, "[DataErr] incorrect input lenght of "..slen..
                " respect to 14 (checksum policy 'verify')" 
        end
        is_add = false
    elseif policy == "add" then
        if slen ~= 13 then
            return nil, "[DataErr] incorrect input lenght of "..slen..
                " respect to 13 (checksum policy 'add')" 
        end
        is_add = true
    elseif policy == "check_or_add" then
        if slen == 14 then
            is_add = false
        elseif slen == 13 then
            is_add = true
        else
            return nil, "[DataErr] incorrect input lenght of "..slen..
                " respect to the policy '"..policy.."'"
        end
    else
        return false, "[InternalErr] incorrect policy enum value '"..policy.."'"
    end
    assert(type(is_add) == "boolean")
    local cs = checkdigit(digits, 13, enc.check_digit_method)
    if is_add then
        digits[14] = cs
        enc._code_len = 14
    else
        if cs ~= digits[14] then
            return false, "[DataErr] last digit is not equal to checksum"
        end
    end
    return true, nil
end

-- input code post processing for basic i2of5
local function basic_finalize(enc) --> ok, err
    -- check digit action
    local policy = enc.check_digit_policy
    local slen = enc._code_len
    local is_even = (slen % 2 == 0)
    local digits = enc._code_data
    if policy == "none" then
        if not is_even then
            rshift(digits) -- add a heading zero for padding
            slen = slen + 1
        end
    elseif policy == "add" then
        if is_even then
            rshift(digits) -- add a heading zero for padding
            slen = slen + 1
        end
        local c = checkdigit(digits, slen, enc.check_digit_method)
        digits[#digits + 1] = c
    elseif policy == "verify" then
        if not is_even then
            rshift(digits)
            slen = slen + 1
        end
        local c = checkdigit(digits, slen - 1, enc.check_digit_method)
        if c ~= digits[slen] then
            return false, "[DataErr] wrong check digit"
        end
    else
        return false, "[InternalError] wrong enum value"
    end
    enc._code_len = slen
    return true, nil
end

-- input code post processing
function ITF:_finalize() --> ok, err
    local var = self._variant
    if var then
        assert(var == "ITF14")
        return itf14_finalize(self)
    else
        return basic_finalize(self)
    end
end

-- public functions

function ITF:get_checkdigit(n, method) --> checksum, err
    if type(n) ~= "number" then return nil, "[ArgErr] 'n' is not a number" end
    if n < 0 then return nil, "[ArgErr] found a negative number" end
    if math.floor(n) ~= n then return nil, "[ArgErr] found a not integer number" end
    method = method or self.check_digit_method
    local last, t = n_to_arr(n)
    return checkdigit(t, last, method)
end

-- drawing function
-- tx, ty is an optional translator vector
function ITF:append_ga(canvas, tx, ty) --> canvas
    local err = canvas:start_bbox_group(); assert(not err, err)
    -- draw the start symbol
    local xdim = self.module
    local ratio = self.ratio
    local symb_len = 2 * xdim * (3 + 2*ratio)
    local x0 = tx or 0
    local xpos = x0
    local y0 = ty or 0
    local y1 = y0 + self.height
    local start = self._vbar_start
    local err
    err = canvas:encode_Vbar(start, xpos, y0, y1); assert(not err, err)
    xpos = xpos + 4 * xdim
    -- draw the code symbol
    local digits = self._code_data
    local vbars = self._vbar_data
    for i = 1, #digits, 2 do
        local index = 10 * digits[i] + digits[i+1]
        local b = vbars[index]
        err = canvas:encode_Vbar(b, xpos, y0, y1); assert(not err, err)
        xpos = xpos + symb_len
    end
    -- draw the stop symbol
    local stop = self._vbar_stop
    err = canvas:encode_Vbar(stop, xpos, y0, y1); assert(not err, err)
    -- bounding box setting
    local x1 = xpos + (2 + ratio)*xdim
    local qz = self.quietzone
    if self._variant then
        qz = qz * xdim
    end
    local b1x,  b1y = x0 - qz, y0
    local b2x,  b2y = x1 + qz, y1
    if self.bearer_bars_enabled then
        local w = self.bearer_bars_thickness
        err = canvas:encode_linethick(w); assert(not err, err)
        b1y, b2y = b1y - w, b2y + w
        local layout = self.bearer_bars_layout
        if layout == "hbar" then
            err = canvas:encode_hline(b1x, b2x, y0 - w/2); assert(not err, err)
            err = canvas:encode_hline(b1x, b2x, y1 + w/2); assert(not err, err)
        elseif layout == "frame" then
            err = canvas:encode_rectangle(b1x - w/2, y0 - w/2, b2x + w/2, y1 + w/2)
            assert(not err, err)
            b1x, b2x = b1x - w, b2x + w
        else
            error("[IntenalErr] bearer bars layout option is wrong")
        end
    end
    local err = canvas:stop_bbox_group(b1x, b1y, b2x, b2y)
    assert(not err, err)
    return canvas
end

return ITF
