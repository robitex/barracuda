-- Ean13 barcode generator
-- Copyright (C) 2018 Roberto Giacomelli

local Ean13 = {
    _VERSION     = "ean13 v0.0.3",
    _NAME        = "ean13",
    _DESCRIPTION = "EAN13 barcode encoder",
}

Ean13._codeset_seq = {-- 1 -> A, 2 -> B, 3 -> C
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

Ean13._symbol = {
    -- codeset A
    [1] = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,},
    -- codeset B
    [2] = {[0] = 1123, 1222, 2212, 1141, 2311, 1321, 4111, 2131, 3121, 2113,},
    -- codeset C
    [3] = {[0] = 3211, 2221, 2122, 1411, 1132, 1231, 1114, 1312, 1213, 3112,},
}

Ean13._is_first_bar = {false, false, true}
Ean13._start = {111, true}
Ean13._stop  = {11111, false}

Ean13._par_def = {}
local pardef = Ean13._par_def

-- standard module is 0.33 mm but it can vary from 0.264 to 0.66mm
pardef.mod = {
    default    = 0.33 * 186467, -- (mm to sp) X dimension (original value 0.33)
    unit       = "sp", -- scaled point
    isReserved = true,
    order      = 1, -- the one first to be modified
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
    default    = 15 * 186467, -- 15mm (mm to sp)
    unit       = "sp",
    isReserved = false,
    order      = 2,
    fncheck    = function (self, h, _) --> boolean, err
        if h > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for height"
        end
    end,
}

pardef.quietzone_left_factor = {
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    order      = 3,
    fncheck    = function (self, qzf, _) --> boolean, err
        if qzf > 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for quietzone_left_factor"
        end
    end,
}

pardef.quietzone_right_factor = {
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    order      = 4,
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
    order      = 5,
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
    order      = 6,
    fncheck    = function (self, flag, _) --> boolean, err
        if type(flag) == "boolean" then
            return true, nil
        else
            return false, "[TypeErr] not a boolean value for text_enabled"
        end
    end,
}

pardef.text_ygap_factor = {
    default    = 1.5,
    unit       = "absolute-number",
    isReserved = false,
    order      = 7,
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
    order      = 8,
    fncheck    = function (self, t, _) --> boolean, err
        if t >= 0 then
            return true, nil
        else
            return false, "[OutOfRange] non positive value for text_xgap_factor"
        end
    end,
}


-- utility function

-- return the check digit no matter if the symbol
-- is 12 or 13 digits long
local function check_digit_of_array(data)
    local sum = 0
    local flag = true
    for i = 1, 12 do
        if flag then
            sum = sum + data[i]
        else
            sum = sum + 3*data[i]
        end
        flag = not flag
    end
    local ck = 10 - (sum % 10)
    if ck == 10 then
        return 0
    else
        return ck
    end
end

-- return the check digit of 12-digits long code
-- as the first output position or an error as
-- the second one
function Ean13:check_of_12(n) --> n, err
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
        if i ~= 12 then return nil, "[Err] no 12-digits long number" end
        -- array reversing
        local len = #arr + 1
        for i = 1, #arr/2 do
            local dt = arr[i]
            arr[i] = arr[len - i]
            arr[len - i] = dt
        end
    elseif type(n) == "table" then
        if #n ~= 12 then return nil, "[Err] no 12-digits long array" end
        arr = n
    elseif type(n) == "string" then
        if #n == 0 then return nil, "[ArgErr] Empty string" end
        if #n ~= 12 then return nil, "[ArgErr] 's' must be 12-digits long" end
        arr = {}
        for c in string.gmatch(n, ".") do
            local d = tonumber(c)
            if not d then return nil, "[ArgErr] 's' contains no digit char" end
            if d > 9 then return nil, "[ArgErr] 's' contains no-digit char" end
            arr[#arr + 1] = d
        end
    else
        return nil, "[ArgErr] unsuitable type"
    end
    return check_digit_of_array(arr)
end

-- costructors section

-- costructor: from an array of digits
--
-- {1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3,}
--
function Ean13:from_array(array) --> symbol, err
    if type(array) ~= "table" then
        return nil, "[ArgErr] array is not a table"
    end
    local len = #array
    if len ~= 13 then return nil, "[Err] not a 13-digits long array" end
    for _, d in ipairs(array) do
        if type(d) ~= "number" then
            return nil, "[Err] array contains a not digit number"
        end
        if d - math.floor(d) > 0 then
            return nil, "[Err] array contains a not integer number"
        end
        if d < 0 or d > 9 then
            return nil, "[Err] array contains a not single digit number"
        end
    end
    local ck = check_digit_of_array(array)
    if ck ~= array[13] then
        return nil, "[Err] wrong check digit"
    end
    local o = { -- create an Ean13 object
        code = array, -- array of 13 digits
    }
    setmetatable(o, self)
    return o, nil
end

-- 1234567890123
--
function Ean13:from_int(n) --> symbol, err
    if type(n) ~= "number" then return nil, "[ArgErr] n is not a number" end
    if n <= 0 then return nil, "[ArgErr] number must be a positive integer" end
    if n - math.floor(n) > 0 then return nil, "[ArgErr] 'n' is not an integer" end
    local arr = {}
    local i = 0
    while n > 0 do
        i = i + 1
        local d = n % 10
        arr[i] = d
        n = (n - d) / 10
    end
    if #arr ~= 13 then
        return nil, "[Err] not a 13-digits long integer"
    end
    local len = #arr + 1
    for i = 1, #arr/2 do -- reverse array
        local d = arr[i]
        arr[i]       = arr[len - i]
        arr[len - i] = d
    end
    return self:from_array(arr)
end

-- costructor: from a string
--
-- "1234567890123"
--
function Ean13:from_string(s) --> symbol, err
    if type(s) ~= "string" then return nil, "[ArgErr] 's' is not a string" end
    if #s == 0 then return nil, "[ArgErr] Empty string" end
    if #s ~= 13 then return nil, "[ArgErr] 's' must be 13-digits long" end
    local symb = {}
    for c in string.gmatch(s, ".") do
        local d = tonumber(c)
        if not d then return nil, "[ArgErr] 's' contains a not digit char" end
        symb[#symb + 1] = d
    end
    return self:from_array(symb)
end

-- methods functions

-- create all the possible VBar object
function Ean13:config()
    local Vbar = self._libgeo.Vbar -- Vbar class
    local mod = self.mod
    local start = self._start
    self._start_stop_vbar = Vbar:from_int(start[1], mod, start[2])
    local stop = self._stop
    self._ctrl_center_vbar = Vbar:from_int(stop[1], mod, stop[2])
    self._codeset_vbar = {}
    local tvbar = self._codeset_vbar
    for i_cs, codetab in ipairs(self._symbol) do
        tvbar[i_cs] = {}
        local tv = tvbar[i_cs]
        local isbar = self._is_first_bar[i_cs]
        for i = 0, 9 do
            tv[i] = Vbar:from_int(codetab[i], mod, isbar)
        end
    end
end

-- Drawing into the provided channel geometrical data
-- tx, ty is the optional translation vector
-- the function return the canvas reference to allow call chaining
function Ean13:append_graphic(canvas, tx, ty) --> canvas
    local code       = self.code
    local mod        = self.mod
    local ax, ay     = self.ax, self.ay
    local bars_depth = mod * self.bars_depth_factor
    local w, h       = 95*mod, self.height + bars_depth
    local x0         = (tx or 0) - ax * w
    local y0         = (ty or 0) - ay * h
    local x1         = x0 + w
    local y1         = y0 + h
    local xpos       = x0 -- current insertion x-coord
    local ys         = y0 + bars_depth
    local s_width    = 7*mod
    local code_seq = self._codeset_seq[code[1]]
    -- draw the start symbol
    local err = canvas:start_bbox_group(); assert(not err, err)
    local be = self._start_stop_vbar
    local _, err = be:append_graphic(canvas, y0, y1, xpos)
    assert(not err, err)
    xpos = xpos + 3*mod
    -- draw the first 6 number
    for i = 2, 7 do
        local codeset = code_seq[i-1]
        local n = code[i]
        local vbar = self._codeset_vbar[codeset][n]
        local _, err = vbar:append_graphic(canvas, ys, y1, xpos)
        assert(not err, err)
        xpos = xpos + s_width
    end
    -- draw the control symbol
    local ctrl = self._ctrl_center_vbar
    local _, err = ctrl:append_graphic(canvas, y0, y1, xpos)
    assert(not err, err)
    xpos = xpos + 5*mod
    -- draw the product code
    for i = 8, 13 do
        local codeset = code_seq[i-1]
        local n = code[i]
        local vbar = self._codeset_vbar[codeset][n]
        local _, err = vbar:append_graphic(canvas, ys, y1, xpos)
        assert(not err, err)
        xpos = xpos + s_width
    end
    -- draw the stop char
    local _, err = be:append_graphic(canvas, y0, y1, xpos)
    -- bounding box set up
    local qzl = self.quietzone_left_factor * mod
    local qzr = self.quietzone_right_factor * mod
    local err = canvas:stop_bbox_group(x0 - qzl, y0, x1 + qzr, y1)
    assert(not err, err)
    if self.text_enabled then -- human readable text
        local Text = self._libgeo.Text
        local txt_1 = Text:from_digit_array(code, 1,  1)
        local txt_2 = Text:from_digit_array(code, 2,  7)
        local txt_3 = Text:from_digit_array(code, 8, 13)
        local y_bl = ys - self.text_ygap_factor * mod
        local mx   = self.text_xgap_factor
        local _, err = txt_1:append_graphic(canvas, x0 - qzl, y_bl, 0, 1)
        assert(not err, err)
        local _, err = txt_2:append_graphic_xwidth(canvas, (3+mx)*mod, (46-mx)*mod, 1, y_bl)
        assert(not err, err)
        local _, err = txt_3:append_graphic_xwidth(canvas, (49+mx)*mod, (92-mx)*mod, 1, y_bl)
        assert(not err, err)
    end
    return canvas
end

return Ean13
