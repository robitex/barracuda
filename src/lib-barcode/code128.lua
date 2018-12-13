--
-- Code128 barcode generator module
--
-- All dimension must be in scaled point (sp)
-- every fields that starts with an undercore sign are intended as private

local Code128._factory = {
    _VERSION     = "code128 v0.0.3",
    _NAME        = "Code128",
    _DESCRIPTION = "Code128 barcode encoder",
}

Code128_factory._int_def_bar = {-- code bar definitions
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
    2331112, -- stop char [106]
}

Code128_factory._codeset = {
    A        = 103, -- Start char for Codeset A
    B        = 104, -- Start char for Codeset B
    C        = 105, -- Start char for Codeset C
    stopChar = 106, -- Stop char
    shift    =  98, -- A to B or B to A
}

Code128_factory._switch = { -- codes for to switch from a codeset to another one
    [103] = {[104] = 100, [105] =  99}, -- from A to B or C
    [104] = {[103] = 101, [105] =  99}, -- from B to A or C
    [105] = {[103] = 101, [104] = 100}, -- from C to A or B
}

Code128_factory._enc_instance = {}

-- parameters definition
Code128_factory._par_def = {}
local pardef = Code128_factory._par_def

-- module main parameter
pardef.xdim = {
    default    = 0.21 * 186467, -- X dimension
    unit       = "sp", -- scaled point
    isReserved = true,
    order      = 1, -- the one first to be modified
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
    order      = 2,
    fncheck    = function (self, y, tpar) --> boolean, err
        local xdim = tpar.xdim
        if y >= 10*xdim then
            return true, nil
        else
            return false, "[OutOfRange] too small value for ydim"
        end
    end,
}

pardef.quite_zone_factor = {
    default    = 10,
    unit       = "absolute-number",
    isReserved = false,
    order      = 3,
    fncheck    = function (self, z, _) --> boolean, err
        if z >= 10 then
            return true, nil
        else
            return false, "[OutOfRange] too small value for quite_zone_factor"
        end
    end,
}

-- parameter identifier array _par_id: { [order] = par_identifier, }
Code128_factory._par_id = {}
local parid = Code128_factory._par_id
for id, tpar in pairs(pardef) do
    parid[tpar.order] = id
end

-- init function
function Code128_factory:init(libgeo, bc_class)
    self._libgeo  = assert(libgeo, "[InternalErr] libgeo is nil")
    self._barcode = assert(bc_class, "[InternalErr] bc_class is nil")
    -- append the superclass parameter identifier
    local super_parid = bc_class._par_id
    local parid = self._par_id
    for _, id in ipairs(super_parid) do
        parid[#parid + 1] = id
    end
end












-- costructors section


-- symbol costructors
-- return the symbol object or an error message
local from_string = function (o, s, opt) --> symbol, err
    if type(s) ~= "string" then return nil, "[ArgErr] not a string" end
    if #s == 0 then return nil, "[ArgErr] Empty string" end
    local symb_def = o._symb_def
    local chars = {}
    for c in string.gmatch(s, ".") do
        local n = symb_def[c]
        if not n then
            local fmt = "[Err] '%s' is not a valid Code 39 symbol"
            return nil, string.format(fmt, c)
        end
        chars[#chars+1] = c
    end
    return o:from_chars(chars, opt)
end



-- costructor: from an array of chars
-- no error checking
function Code128:from_array(arr)
    -- build the Code128 object
    local o = {
        code = arr, -- array of code chars
        data = encode128(arr,
            self.codesetA, self.codesetB, self.codesetC,
            self.stopChar, self.switch
        ),
    }
    -- load dynamically the geometric bar definition
    for _, char in ipairs(o.data) do
        if not self.vbar[char] then
            local n   = self.integer_def_bar[char]
            local mod = self.xdim
            local yline = build_vbar(n, mod, 6)
            local Vbar = self.libgeo.Vbar
            self.vbar[char] = Vbar:from_array(yline)
        end
    end
    setmetatable(o, self)
    return o
end

-- costructor: from an ASCII string
-- no error checking
-- string.utfvalues() is a LuaTeX only function
function Code128:from_string(s)
    if not s then return nil, "Mandatory arg" end
    if not type(s) == "string" then return nil, "Not a string" end
    if #s == 0 then return nil, "Empty string" end

    local symb = {}
    for codepoint in string.utfvalues(s) do
        if codepoint > 255 then
            local fmt = "The codepoint '%d' is not representable in Code128"
            return nil, string.format(fmt, codepoint)
        end
        if codepoint > 127 then
            local fmt = "The '%d' char is ASCII extented not yet implemented"
            return nil, string.format(fmt, codepoint)
        end
        symb[#symb + 1] = codepoint
    end

    local o = {
        code = symb, -- array of code chars
        data = encode128(symb,
            self.codesetA, self.codesetB, self.codesetC,
            self.stopChar, self.switch
        ),
    }
    -- load dynamically the geometric bar definition
    for _, char in ipairs(o.data) do
        if not self.vbar[char] then
            local n   = self.integer_def_bar[char]
            local mod = self.xdim
            local yline =  build_vbar(n, mod, 6)
            local Vbar = self.libgeo.Vbar
            self.vbar[char] = Vbar:from_array(yline)
        end
    end
    setmetatable(o, self)
    return o, nil
end













-- symbol costructor: from an array of chars
-- return the symbol object or an error message
local from_chars = function (o, symb, opt)
    if type(symb) ~= "table" then
        return nil, "[ArgErr] symb is not a table"
    end
    if #symb == 0 then
        return nil, "[ArgErr] symb is an empty array"
    end
    -- loading the Vbar definitions on the fly (dynamic loading)
    local g_Vbar     = o._libgeo.Vbar
    local vbar       = o._vbar
    local symb_def   = o._symb_def
    local mod, ratio = o.module, o.ratio
    -- create every vbar object needed for symbol if not already present
    for _, s in ipairs(symb) do
        local n = symb_def[s]
        if not n then
            local fmt = "[Err] '%s' is not a valid Code 39 symbol"
            return nil, string.format(fmt, s)
        end
        if not vbar[s] then
            vbar[s] = g_Vbar:from_int_revpair(n, mod, mod*ratio)
        end
    end
    -- build the Code39 symbol object
    local obj = {
        code = symb, -- array of chars
    }
    setmetatable(obj, o)
    return obj, nil
end




-- Drawing into the provided channel the geometrical barcode data
-- tx, ty is the optional translation vector
-- the function return the canvas reference to allow call chaining
local function append_graphic(o, canvas, tx, ty)
    local xdim, h = o.xdim, o.ydim
    local sw = 11*xdim -- the width of a symbol
    local data = o.data
    local w = #data*sw + 2*xdim -- with the stop char correction
    local ax, ay = o.ax or 0, o.ay or 0
    local x0 = (tx or 0) - ax * w
    local y0 = (ty or 0) - ay * h
    local x1 = x0 + w
    local y1 = y0 + h

    local xpos = x0
    canvas:start_bbox_group()
    -- drawing the symbols
    for _, char in ipairs(data) do
        local ref = o._vbar[char]
        ref:draw_to_canvas(canvas, y0, y1, xpos)
        xpos = xpos + sw
    end

    -- bounding box setting
    local qz = o.quite_zone_factor * xdim
    canvas:bounding_box(x0 - qz, y0, x1 + qz, y1) -- {xmin, ymin, xmax, ymax}

    -- check height as the minimum of 15% of length
    if 0.15 * w > h then
        -- TODO: message function for warning the user
        -- message("The height of the barcode is to small")
    end
    return canvas
end








-- tx, ty is an optional translator vector
local append_graphic = function (o, canvas, tx, ty)
    local code       = o.code
    local ns         = #code -- number of chars inside the symbol
    local mod        = o.module
    local ratio      = o.ratio
    local interspace = o.interspace
    local h          = o.height
    local xs         = mod*(6 + 3*ratio)
    local xgap       = xs + interspace
    local w          = xgap*(ns + 1) + xs -- (ns + 2) * xgap - interspace
    local ax, ay     = o.ax, o.ay
    local x0         = (tx or 0) - ax * w
    local y0         = (ty or 0) - ay * h
    local x1         = x0 + w
    local y1         = y0 + h
    local xpos       = x0
    canvas:start_bbox_group()
    -- start/stop symbol
    local term_vbar = o._vbar['*']
    -- draw start symbol
    term_vbar:append_graphic(canvas, y0, y1, xpos)

    -- draw code symbol
    for _, c in ipairs(code) do
        xpos = xpos + xgap
        local vb = o._vbar[c]
        vb:append_graphic(canvas, y0, y1, xpos)
    end
    -- draw stop symbol
    term_vbar:append_graphic(canvas, y0, y1, xpos + xgap)

    -- bounding box setting
    local qz = o.quietzone
    canvas:stop_bbox_group(x0 - qz, y0, x1 + qz, y1)

    -- check height as the minimum of 15% of length
    -- TODO: message could warn the user
    -- if 0.15 * w > h then
        -- message("The height of the barcode is to small")
    -- end
    if o.text_enabled then -- human readable text
        local chars; if o.text_star then
            chars = {"*"}
            for _, c in ipairs(code) do
                chars[#chars + 1] = c
            end
            chars[#chars + 1] = "*"
        else
            chars = {}
            for _, c in ipairs(code) do
                chars[#chars + 1] = c
            end
        end
        local Text = o._libgeo.Text
        local txt  = Text:from_chars(chars)
        -- setup text position
        local pdef = o.text_pos_def
        local default = pdef.default
        local vopt_d, hopt_d = pdef:fnparse(default)
        local vo, ho = pdef:fnparse(o.text_pos, vopt_d, hopt_d)
        local txtgap = o.text_gap
        local ypos, tay; if vo == "top" then  -- vertical setup
            ypos = y1 + txtgap
            tay = 0.0
        else
            ypos = y0 - txtgap
            tay = 1.0
        end
        if ho == "spaced" then -- horizontal setup
            local xaxis = x0
            if not o.text_star then
                xaxis = xaxis + xgap
            end
            xaxis = xaxis + xs/2
            txt:append_graphic_xspaced(canvas, xaxis, xgap, ypos, ay)
        else
            local xpos, tax
            if ho == "left" then
                xpos = x0
                tax = 0.0
            elseif ho == "center" then
                xpos = (x1 - x0)/2
                tax = 0.5
            elseif ho == "right" then
                xpos = x1
                tax = 1.0
            else
                error("[InternalErr] wrong option for text_pos")
            end
            txt:append_graphic(canvas, xpos, ypos, tax, tay)
        end
    end
    return canvas
end


-- main factory function for Code128 encoders
-- enc_name  : encoder identifier in the Code128 namespace
-- user_param: a table with the user defined parameters for Code128 encoder class
function Code128_factory:new_encoder(enc_name, user_param) --> <encoder object>, <err>
    if type(enc_name) ~= "string" then
        return nil, "[ArgErr] enc_name, is not a string"
    end
    if enc_name == "" then
        return nil, "[ArgErr] empty string is not allowed for enc_name"
    end
    if string.match(enc_name, " ") then
        return nil, "[ArgErr] space char not allowed for enc_name"
    end
    if self._enc_instance[enc_name] then
        return nil, "[Err] enc_name also declared"
    end
    local codeset = self._codeset
    local int_def = self._int_def_bar
    local enc = { -- the new encoder
        _NAME          = self._NAME,
        _VERSION       = self._VERSION,
        _DESCRIPTION   = self._DESCRIPTION,
        _libgeo        = self._libgeo, -- a ref to the geometric library
        _int_def_bar   = int_def,      -- ref to symbol definition table
        _codeset       = codeset,      -- codeset and other codes
        _switch        = self._switch, -- switch code table
        _par_id        = self._par_id, -- array of parameter identifier
        _vbar          = {},           -- where we dynamically place vbars
        from_string    = from_string,  -- copying methods
        from_chars     = from_chars,
        append_graphic = append_graphic,
        _get_param_for_checking = function (o) return {xdim = o.xdim} end,
    }

    local pardef = self._par_def
    local p_ord = {}
    local i = 0
    for pk, tdef in pairs(pardef) do
        enc[pk.."_def"] = tdef -- copy a reference to the param definition table
        p_ord[tdef.order] = pk
        i = i + 1
    end
    assert(#p_ord == i)

    -- generate parameters value
    user_param = user_param or {}
    if type(user_param) ~= "table" then
        return nil, "[ArgErr] 'user_param' must be a table"
    end
    -- check and eventually set every parameter within user_param
    local cktab = { xdim = true }
    for _, par in ipairs(p_ord) do
        if user_param[par] then
            local val = user_param[par]
            local ok, err = pardef[par]:fncheck(val, cktab)
            if ok then
                enc[par] = val
                if cktab[par] then cktab[par] = val end
            else
                return nil, err
            end
        else
            enc[par] = pardef[par].default
        end
        cktab[par] = enc[par]
    end
    -- build Vbar object for the start/stop symbol
    local mod = enc.xdim
    local sc = codeset.stopChar-- build the stop char
    local n = int_def[sc]
    local Vbar = self._libgeo.Vbar -- Vbar class
    local b = enc._vbar
    b[sc] = Vbar:from_int(n, mod, true)
    --save locally the encoder reference
    self._enc_instance[enc_name] = enc
    enc.__index = enc
    setmetatable(enc, self._barcode)
    return enc, nil
end











-- utility functions

-- the number of consecutive digits from the index 'i'
-- in the code array
local function count_digits_from(arr, i)
    local start = i
    while i <= #arr and (arr[i] > 47 and arr[i] < 58) do
        i = i + 1
    end
    return i - start
end

-- evaluate the check digit of the data representation
local function check_digit(code)
    local sum = code[1] -- start char
    for i = 2, #code do
        sum = sum + code[i]*(i-1)
    end
    return sum % 103
end

-- return a pair of boolean the first one is true
-- if a control char and a lower case char occurs in the data
-- and the second one is true if the control char occurs before
-- the lower case char
local function ctrl_or_lowercase(pos, data)
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

-- encode the provided char respect to the codeset
-- in the future this function may treats FN data
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

-- encode the message in a sequence of Code128 symbol
-- minimizing its lenght
local function encode128(arr, codesetA, codesetB, codesetC, stopChar, switch)
    local res = {} -- the result array (the check character will be tail added)

    -- find the Start Character A, B, or C
    local cur_codeset
    local ndigit = count_digits_from(arr, 1)
    local len = #arr
    --local no_ctrl_lower_char
    if (ndigit == 2 and len == 2) or ndigit > 3 then -- start char code C
        cur_codeset = codesetC
    else
        local ok, ctrl_first = ctrl_or_lowercase(1, arr)
        if ok and ctrl_first then
            cur_codeset = codesetA
        else
            cur_codeset = codesetB
        end
    end
    res[#res + 1] = cur_codeset

    local pos = 1 -- symbol's index to encode
    while pos <= len do
        if cur_codeset == codesetC then
            if arr[pos] < 48 or arr[pos] > 57 then -- not numeric char
                local ok, ctrl_first = ctrl_or_lowercase(pos, arr)
                if ok and ctrl_first then
                    cur_codeset = codesetA
                else
                    cur_codeset = codesetB
                end
                res[#res + 1] = switch[codesetC][cur_codeset]
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
                        cur_codeset = codesetA
                    else
                        cur_codeset = codesetB
                    end
                    res[#res + 1] = switch[codesetC][cur_codeset]
                end
            end
        else --- current codeset is A or B
            if ndigit > 3 then
                if ndigit % 2 > 1 then -- odd number of digits
                    encode_char(res, cur_codeset, arr[pos], codesetA)
                    pos = pos + 1
                    ndigit = ndigit - 1
                end
                res[#res + 1] = switch[cur_codeset][codesetC]
                cur_codeset = codesetC
            elseif (cur_codeset == codesetB) and
                (arr[pos] >= 0 and arr[pos] < 32) then -- ops a control char
                local ok, ctrl_first = ctrl_or_lowercase(pos + 1, arr)
                if ok and (not ctrl_first) then -- shift to codeset A
                    res[#res + 1] = shift
                    encode_char(res, codesetA, arr[pos], codesetA)
                    pos = pos + 1
                    ndigit = count_digits_from(pos, arr)
                else -- switch to code set A
                    res[#res + 1] = switch[cur_codeset][codesetA]
                    cur_codeset = codesetA
                end
            elseif (cur_codeset == codesetA) and
                (arr[pos] > 95 and arr[pos] < 128) then -- ops a lower case char
                local ok, ctrl_first = ctrl_or_lowercase(pos+1, arr)
                if ok and ctrl_first then -- shift to codeset B
                    res[#res + 1] = shift
                    encode_char(res, codesetB, arr[pos], codesetA)
                    pos = pos + 1
                    ndigit = count_digits_from(arr, pos)
                else -- switch to code set B
                    res[#res + 1] = switch[cur_codeset][codesetB]
                    cur_codeset = codesetB
                end
            else
                -- insert char
                encode_char(res, cur_codeset, arr[pos], codesetA)
                pos = pos + 1
                ndigit = count_digits_from(arr, pos)
            end
        end
    end

    res[#res + 1] = check_digit(res)
    res[#res + 1] = stopChar
    return res
end











return Code128

--
