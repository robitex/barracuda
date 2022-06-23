-- Universal Product Code
-- UPC family barcode generator
--
-- Copyright (C) 2019-2022 Roberto Giacomelli
-- see LICENSE.txt file

local UPC = {
    _VERSION     = "upc v0.0.2",
    _NAME        = "upc",
    _DESCRIPTION = "UPC barcode encoder",
}

UPC._pattern = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,}
UPC._sepbar = 111

UPC._id_variant = {
    A = true, -- UPC-A
}

-- common family parameters
UPC._par_order = {
    "mod",
    "height",
    "bars_depth_factor",
    "quietzone_factor",
    "text_enabled",
    "text_ygap_factor",
    "text_xgap_factor",
}
UPC._par_def = {}
local pardef = UPC._par_def

-- from Wikipedia https://en.wikipedia.org/wiki/Universal_Product_Code
-- The x-dimension for the UPC-A at the nominal size is 0.33 mm (0.013").
-- UPC-A can be reduced or magnified anywhere from 80% to 200%.
-- standard module is 0.33 mm but it may vary from 0.264 to 0.66mm
pardef.mod = {
    default    = 0.33 * 186467, -- (mm to sp) X dimension (original value 0.33)
    unit       = "sp", -- scaled point
    isReserved = true,
    fncheck    = function (_self, x, _) --> boolean, err
        local mm = 186467
        local min, max = 0.264*mm, 0.660*mm
        if x < min then
            return false, "[OutOfRange] too small value for mod"
        elseif x > max then
            return false, "[OutOfRange] too big value for mod"
        end
        return true, nil
    end,
}

-- Nominal symbol height for UPC-A is 25.9 mm (1.02")
pardef.height = {
    default    = 25.9 * 186467,
    unit       = "sp",
    isReserved = false,
    fncheck    = function (self, h, _enc) --> boolean, err
        if h > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for height"
        end
    end,
}

-- The bars forming the S (start), M (middle), and E (end) guard patterns, are
-- extended downwards by 5 times x-dimension, with a resulting nominal symbol
-- height of 27.55 mm (1.08")
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

-- A quiet zone, with a width of at least 9 times the x-dimension, must be
-- present on each side of the scannable area of the UPC-A barcode.
pardef.quietzone_factor = {
    default    = 9,
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

-- enable/disable human readble text
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

-- vertical gap from text and symbol baseline
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

-- horizontal gap from text and symbol bars
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

-- utility function

-- the checksum of UPC-A
-- 'data' is an array of digits
local function checkdigit_A(data) --> checksum, ok
    local s = 0
    for i = 1, 11, 2 do
        s = s + data[i]
    end
    s = 3*s
    for i = 2, 10, 2 do
        s = s + data[i]
    end
    local res = s % 10
    if res > 0  then
        res = 10 - res
    end
    return res, data[12] == res
end

-- internal methods for Barcode costructors

-- config function called at the moment of encoder construction
function UPC:_config() --> ok, err
    local variant = self._variant
    if not variant then
        return false, "[Err] variant is mandatory for the UPC family"
    end
    local Vbar = self._libgeo.Vbar -- Vbar class
    local Vbar_archive = self._libgeo.Archive -- Archive class
    local Codeset = Vbar_archive:new()
    self._upca_codeset = Codeset
    local mod = self.mod
    local sepbar = self._sepbar
    Codeset:insert(Vbar:from_int(sepbar, mod), "sepbar")
    local symb = self._pattern
    for i = 0, 9 do
        Codeset:insert(Vbar:from_int(symb[i], mod, false), 0, i)
        Codeset:insert(Vbar:from_int(symb[i], mod, true), 1, i)
    end
    return true, nil
end

-- function called every time an input UPC-A code has been completely parsed
function UPC:_finalize() --> ok, err
    local data = self._code_data
    local symb_len = #data
    if symb_len ~= 12 then
        return false, "[ArgErr] not a 12-digit long array"
    end
    local ck, ok = checkdigit_A(data)
    if not ok then -- is the last digit ok?
        return false,
        "[Err] incorrect last digit "..data[12]..", the checksum is "..ck
    end
    return true, nil
end

-- Drawing into the provided channel geometrical data
-- tx, ty is the optional translation vector
-- the function return the canvas reference to allow call chaining
function UPC:_append_ga(canvas, tx, ty) --> bbox
    local Codeset = self._upca_codeset
    local code = self._code_data
    local mod = self.mod
    local sepbar = assert(Codeset:get("sepbar"))
    local queue_0 = sepbar + assert(Codeset:get(0, code[1])) +
        36*mod + sepbar + 36*mod +
        assert(Codeset:get(1, code[12])) + sepbar
    local queue_1 = 10*mod
    for i = 2, 6 do
        queue_1 = queue_1 + assert(Codeset:get(0, code[i]))
    end
    queue_1 = queue_1 + 5*mod
    for i = 7, 11 do
        queue_1 = queue_1 + assert(Codeset:get(1, code[i]))
    end
    local bars_depth = mod * self.bars_depth_factor
    local w, h = 95*mod, self.height + bars_depth
    local x0 = tx - self.ax * w
    local y0 = ty - self.ay * h
    local x1 = x0 + w
    local y1 = y0 + h
    local ys = y0 + bars_depth
    -- draw the symbol
    assert(canvas:encode_disable_bbox())
    assert(canvas:encode_vbar_queue(queue_0, x0, y0, y1))
    assert(canvas:encode_vbar_queue(queue_1, x0, ys, y1))
    -- bounding box set up
    local qz = self.quietzone_factor * mod
    assert(canvas:encode_set_bbox(x0 - qz, y0, x1 + qz, y1))
    assert(canvas:encode_enable_bbox())
    if self.text_enabled then -- human readable text
        local Text  = self._libgeo.Text
        local txt_1 = Text:from_digit_array(code, 1,  1)
        local txt_2 = Text:from_digit_array(code, 2,  6)
        local txt_3 = Text:from_digit_array(code, 7, 11)
        local txt_4 = Text:from_digit_array(code, 12, 12)
        local y_bl = ys - self.text_ygap_factor * mod
        assert(canvas:encode_Text(txt_1, x0 - qz, y_bl, 0, 1))
        local mx = self.text_xgap_factor
        local x2_1 = x0 + (10+mx)*mod
        local x2_2 = x0 + (46-mx)*mod
        assert(canvas:encode_Text_xwidth(txt_2, x2_1, x2_2, y_bl, 1))
        local x3_1 = x0 + (49+mx)*mod
        local x3_2 = x0 + (85-mx)*mod
        assert(canvas:encode_Text_xwidth(txt_3, x3_1, x3_2, y_bl, 1))
        assert(canvas:encode_Text(txt_4, x1 + qz, y_bl, 1, 1))
    end
    return {x0, y0, x1, y1, qz, nil, qz, nil,}
end

return UPC
