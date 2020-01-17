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
    fncheck    = function (self, mod, _) --> boolean, err
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
    fncheck    = function (_, ratio, tpardef) --> boolean, err
        local mils = 0.0254 * 186467
        local mod = tpardef.module
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
    fncheck = function (_self, h, _opt) --> boolean, err
        local mils = 0.0254 * 186467
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
    fncheck    = function (self, qz, _opt) --> boolean, err
        local mils = 0.0254 * 186467
        local mod = self.module
        local min = math.max(10*mod, 250*mils)
        if qz >= min then
            return true, nil
        else
            return false, "[OutOfRange] quietzone too small"
        end
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
    fncheck    = function (self, e, _) --> boolean, err
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
    fncheck       = function (self, e, _) --> boolean, err
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
    fncheck    = function (_, flag, _) --> boolean, err
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
    fncheck = function (_self, thick, tpardef) --> boolean, err
        local module = tpardef.module
        if thick >= 2*module then
            return true, nil
        end
        return false, "[OutOfRange] thickness too small"
    end,
}

pardef.bearer_bars_layout = { -- enumeration
    -- determine the algorithm for the check digit calculation
    default       = "hbar",
    isReserved    = false,
    method_enum = {
        frame = true, -- a rectangle around the symbol
        hbar = true, -- top and bottom horizontal bars
    },
    fncheck       = function (self, e, _) --> boolean, err
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


local function check_mod10(t, last)
    local sum = 0
    local w = true
    for i = last, 1, -1 do
        if w then
            sum = sum + 3*t[i]
        else
            sum = sum + t[i]
        end
        w = not w
    end
    local m = sum % 10
    if m == 0 then return 0 else return 10 - m end
end

local function checkdigit(t, last, method)
    if method == "mod_10" then
        return check_mod10(t, last)
    else
        assert(false, "[InternalErr] unknow method")
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
    return true, nil
end

-- public functions

function ITF:get_checkdigit(n, method)
    if type(n) ~= "number" then return nil, "[ArgErr] 'n' is not a number" end
    if n < 0 then return nil, "[ArgErr] found a negative number" end
    if n - math.floor(n) ~= 0 then return nil, "[ArgErr] found a float number" end
    method = method or self.check_digit_method
    local last, t = n_to_arr(n)
    return checkdigit(t, last, method)
end

-- internal methods for constructors

function ITF:_finalize() --> ok, err
    -- check digit action
    local policy = self.check_digit_policy
    local slen = self._code_len
    local is_even = (slen % 2 == 0)
    local digits = self._code_data
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
        local c = checkdigit(digits, slen, self.check_digit_method)
        digits[#digits + 1] = c
    elseif policy == "verify" then
        if not is_even then
            rshift(digits)
            slen = slen + 1
        end
        local c = checkdigit(digits, slen - 1, self.check_digit_method)
        if c ~= digits[slen] then
            return false, "[DataErr] wrong check digit"
        end
    else
        return false, "[InternalError] wrong enum value"
    end
    self._code_len = slen
    return true, nil
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
