-- Interleaved 2 of 5 (ITF) barcode generator
--
-- Copyright (C) 2019 Roberto Giacomelli
-- see LICENSE.txt file

local ITF = { -- main container
    _VERSION     = "ITF v0.0.1",
    _NAME        = "ITF",
    _DESCRIPTION = "Interleaved 2 of 5 barcode encoder",
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
    order      = 1, -- the one first to be modified
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
    order      = 2,
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
    order      = 3,
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
    order      = 4,
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

-- auxiliary function
local function check_mod10(t)
    local sum = 0
    local l = #t
    for i = 1,l,2 do
        sum = sum + 3*t[i]
    end
    for i = 2,l,2 do
        sum = sum + t[i]
    end
    local m = sum % 10
    if m == 0 then return 0 else return 10 - m end
end

-- t: array of digits
-- len: array position where data ends
function ITF:checkdigit_mod10(t, len)
    return 0
end

-- configuration function
function ITF:config() --> ok, err
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


-- constructors
-- return the symbol object or an error message
function ITF:from_int(n, opt) --> symbol, err
    if type(n) ~= "number" then return nil, "[ArgErr] 'n' is not a number" end
    assert(n > 0, "unsupported negative integer")
    assert( n - math.floor(n) == 0, "unsupported float number")
    local digits = {}
    while n > 0 do
        local d = n % 10
        digits[#digits + 1] = d
        n = (n - d) / 10
    end
    local slen = #digits
    assert((slen % 2) == 0, "unsupported odd integer")
    for k = 1, slen/2  do -- array reversing
        local h = slen - k + 1
        local d = digits[k]
        digits[k] = digits[h]
        digits[h] = d
    end
    local o = {} -- create an ITF barcode object
    o._data = digits
    setmetatable(o, self)
    if opt ~= nil then
        if type(opt) ~= "table" then
            return nil, "[ArgErr] opt is not a table"
        else
           local ok, err = o:set_param(opt)
           if not ok then
               return nil, err
           end
        end
    end

    return o, nil
end

-- drawing function
-- tx, ty is an optional translator vector
function ITF:append_ga(canvas, tx, ty) --> canvas
    local err = canvas:start_bbox_group(); assert(not err, err)

    -- draw start symbols
    local xdim = self.module
    local ratio = self.ratio
    local symb_len = 2 * xdim * (3 + 2*ratio)
    local x0 = tx or 0
    local xpos = x0
    local y0 = ty or 0
    local y1 = y0 + self.height
    local start = self._vbar_start
    local _, e1 = start:append_ga(canvas, y0, y1, xpos); assert(not e1, e1)
    xpos = xpos + 4 * xdim
    -- draw code symbol
    local digits = self._data
    local vbars = self._vbar_data
    for i = 1, #digits, 2 do
        local index = 10 * digits[i] + digits[i+1]
        local b = vbars[index]
        local _, e = b:append_ga(canvas, y0, y1, xpos); assert(not e, e)
        xpos = xpos + symb_len
    end
    -- draw the stop symbol
    local stop = self._vbar_stop
    local _, e2 = stop:append_ga(canvas, y0, y1, xpos); assert(not e2, e2)
    -- bounding box setting
    local x1 = xpos + (2 + ratio)*xdim
    local qz = self.quietzone
    local err = canvas:stop_bbox_group(x0 - qz, y0, x1 + qz, y1)
    assert(not err, err)
    return canvas
end

return ITF
