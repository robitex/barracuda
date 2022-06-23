-- class gaCanvas
-- Copyright (C) 2019-2022 Roberto Giacomelli
-- <ga> encoding functions (see barracuda-manual.pdf)

local gaCanvas = {_classname = "gaCanvas"}
gaCanvas.__index = gaCanvas
gaCanvas.mm = 186467.98110236 -- conversion factor sp -> mm (millimeter)
gaCanvas.bp = 65781.76 -- conversion factor sp -> bp (big point)
gaCanvas.pt = 65536 -- sp -> pt

-- ga specification: see the file ga-grammar.pdf in the doc directory

-- gaCanvas constructor
function gaCanvas:new() --> object
    local drv = assert(self._driver_class)
    -- graphic state fields returned by Driver:default_style() method
    -- linewidth
    -- linecap
    -- linejoin
    -- dashpattern
    -- dashphase
    local o = assert(drv:default_style()) -- initial graphic state
    o._version = 100  -- version of the ga format
    o._data = {} -- ga stream array
    o.bb_on = true
    setmetatable(o, self)
    return o
end

-- save graphic data in an external file with the 'id_drv' format
-- id_drv::= string, specific driver output identifier
-- filename ::= string, file name
-- ext ::= string, file extension (optional, default SVG)
function gaCanvas:save(id_drv, filename, ext) --> ok, err
    local driver = self._driver_class
    return driver:save(id_drv, self, filename, ext)
end

-- insert a ga drawing in a TeX hbox
-- PDFnative only function
-- boxname ::= string
function gaCanvas:ga_to_hbox(boxname) --> ok, err
    local driver = self._driver_class
    return driver:ga_to_hbox(self, boxname)
end

-- return a clone of the <ga> stream array
function gaCanvas:get_stream() --> table (as a flat array)
    local data = self._data
    local t = {}
    for _, v in ipairs(data) do
        t[#t + 1] = v
    end
    return t
end

-- Ipothetical further constructor
-- function gaCanvas:from_tcp_server() --> err
-- end

-- function gaCanvas:get_bbox()
-- end

-- function gaCanvas:check() --> ok, err 
-- end

-- line width: opcode <1> <w: DIM>
function gaCanvas:encode_linewidth(w) --> ok, err
    if type(w) ~= "number" then
        return false, "[ArgErr 'w'] number expected"
    end
    if w < 0 then return false, "[ArgErr: w] negative number not allowed" end
    self.linewidth = w
    local data = self._data
    data[#data + 1] = 1 -- opcode for line thickness
    data[#data + 1] = w
    return true, nil
end

-- line cap style: opcode <2> cap <u8>|<enum>
-- 0 | "butt": Butt cap
-- 1 | "round": Round cap
-- 2 | "proj": Projecting square cap
function gaCanvas:encode_linecap(cap) --> ok, err
    local tcap = type(cap)
    local cap_res
    if tcap == "number" then
        if cap == 0 or cap == 1 or cap == 2 then
            cap_res = cap
        else
            return false, "[ArgErr: cap] 0, 1 or 2 expected"
        end
    elseif tcap == "string" then
        if cap == "butt" then
            cap_res = 0
        elseif cap == "round" then
            cap_res = 1
        elseif cap == "proj" then
            cap_res = 2
        else
            return false, "[ArgErr: cap] 'butt', 'round' or 'proj' expected"
        end
    else
        return false, "[ArgErr: cap] number or string expected"
    end
    self.linecap = cap_res
    local data = self._data
    data[#data + 1] = 2 -- opcode for line cap style
    data[#data + 1] = cap_res
    return true, nil
end

-- line join style: opcode <3> join <u8>|<enum>
-- 0 | "miter" : Miter join
-- 1 | "round" : Round join
-- 2 | "bevel" : Bevel join
function gaCanvas:encode_linejoin(join) --> ok, err
    local tjoin = type(join)
    local join_res
    if tjoin == "number" then
        if join == 0 or join == 1 or join == 2 then
            join_res = join
        else
            return false, "[ArgErr: join] 0, 1 or 2 integer expected"
        end
    elseif tjoin == "string" then
        if join == "miter" then
            join_res = 0
        elseif join == "round" then
            join_res = 1
        elseif join == "bevel" then
            join_res = 2
        else
            return false, "[ArgErr: join] '"..join.."' join style not found"
        end
    else
        return false, "[ArgErr: join] number or string expected"
    end
    self.linejoin = join_res
    local data = self._data
    data[#data + 1] = 3 -- opcode for line join style
    data[#data + 1] = join_res
    return true, nil
end

-- 5 <dash_pattern>, Dash pattern line style, p <len> n <qty> bi <len>
-- p: phase lenght
-- n: number of array element
-- [bi]: dash array of dash and gap lenghts
function gaCanvas:encode_dash_pattern(p, ...) --> ok, err
    if type(p) ~= "number" then return false, "[ArgErr: phase] number expected" end
    local t = {...}
    for i, v in ipairs(t) do
        if type(v) ~= "number" then
            return false, "[ArgErr: array] found a not number value at index " .. i
        end
    end
    self.dash_pattern = t
    self.dash_phase = p
    local n = #t
    local d = self._data
    d[#d + 1] = 5
    d[#d + 1] = p
    d[#d + 1] = n
    for _, b in ipairs(t) do
        d[#d + 1] = b
    end
    return true, nil
end

-- 6 <reset_pattern>, set the continous line style
function gaCanvas:encode_reset_pattern() --> ok, err
    self.dash_pattern = nil
    self.dash_phase = nil
    local d = self._data
    d[#d + 1] = 6
    return true, nil
end

-- checking the bounding box from now on
-- opcode: <29>
function gaCanvas:encode_enable_bbox() --> ok, err
    self.bb_on = true
    local data = self._data
    data[#data + 1] = 29
    return true, nil
end

-- Stop checking the bounding box
-- opcode: <30>
function gaCanvas:encode_disable_bbox() --> ok, err
    self.bb_on = false
    local data = self._data
    data[#data + 1] = 30
    return true, nil
end

-- insert a figure bbox
-- code: <31> x1 y1 x2 y2
function gaCanvas:encode_set_bbox(x1, y1, x2, y2) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr: x1] number expected" end
    if type(y1) ~= "number" then return false, "[ArgErr: y1] number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr: x2] number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr: y2] number expected" end
    if x1 > x2 then x1, x2 = x2, x1 end -- re-order coordinates
    if y1 > y2 then y1, y2 = y2, y1 end
    local data = self._data
    data[#data + 1] = 31 -- bounding box of the object group
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
    return true, nil
end

-- insert a line from point (x1, y1) to the point (x2, y2)
-- tx optional translator x-vector
-- ty optional translator y-vector
-- <32> x1 y1 x2 y2
function gaCanvas:encode_line(x1, y1, x2, y2, tx, ty) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr: x1] number expected" end
    if type(y1) ~= "number" then return false, "[ArgErr: y1] number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr: x2] number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr: y2] number expected" end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x1 = x1 + tx
        x2 = x2 + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        y1 = y1 + ty
        y2 = y2 + ty
    end
    local data = self._data
    data[#data + 1] = 32 -- append line data
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
    return true, nil
end

-- insert an horizontal line from point (x1, y) to point (x2, y)
-- tx optional translator x-vector
-- ty optional translator y-vector
-- <33> x1 x2 y
function gaCanvas:encode_hline(x1, x2, y, tx, ty) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr: x1] number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr: x2] number expected" end
    if type(y) ~= "number" then return false, "[ArgErr: y] number expected" end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x1 = x1 + tx
        x2 = x2 + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        y = y + ty
    end
    local data = self._data
    data[#data + 1] = 33 -- append hline data
    data[#data + 1] = x1
    data[#data + 1] = x2
    data[#data + 1] = y
    return true, nil
end

-- vline, Vertical line, from point (x, y1) to point (x, y2)
-- tx optional translator x-vector
-- ty optional translator y-vector
-- <34> y1 y2 x
function gaCanvas:encode_vline(y1, y2, x, tx, ty) --> ok, err
    if type(y1) ~= "number" then return false, "[ArgErr] 'y1' number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
    if type(x) ~= "number" then return false, "[ArgErr] 'x' number expected" end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x = x + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        y1 = y1 + ty
        y2 = y2 + ty
    end
    local data = self._data
    data[#data + 1] = 34 -- append vline data
    data[#data + 1] = y1
    data[#data + 1] = y2
    data[#data + 1] = x
    return true, nil
end

-- insert an open polyline
-- tx optional translator x-vector
-- ty optional translator y-vector
-- <38> <n> x1 y1 x2, y2, ... , xn, yn
function gaCanvas:encode_polyline(point, tx, ty) --> ok, err
    if type(point) ~= "table" then
        return false, "[ArgErr: point] table expected"
    end
    local n, p
    if point._classname == "Polyline" then
        n, p = point:get_points()
    else
        local len = #point
        if len == 0 then return false, "[Err] 'point' is an empty table" end
        if (len % 2) ~= 0 then
            return false, "[Err] 'point' is not an even long array"
        end
        n = len/2
        for _, coord in ipairs(point) do
            if type(coord) ~= "number" then
                return false, "[Err] found a non-number in the 'point' array"
            end
        end
        p = point
    end
    if n < 2 then return
        false, "[Err] a polyline must have at least two points"
    end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
    else
        tx = 0
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
    else
        ty = 0
    end
    local data = self._data
    data[#data + 1] = 38
    data[#data + 1] = n
    for i = 1, 2*n, 2 do
        data[#data + 1] = p[i] + tx
        data[#data + 1] = p[i + 1] + ty
    end
    return true, nil
end

-- insert a rectangle from point (x1, x2) to (x2, y2)
-- tx optional translator x-vector
-- ty optional translator y-vector
-- <48> <x1: DIM> <y1: DIM> <x2: DIM> <y2: DIM>
function gaCanvas:encode_rect(x1, y1, x2, y2, tx, ty) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return false, "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x1 = x1 + tx
        x2 = x2 + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        y1 = y1 + ty
        y2 = y2 + ty
    end
    local d = self._data
    d[#d + 1] = 48 -- append rectangle data
    d[#d + 1] = x1
    d[#d + 1] = y1
    d[#d + 1] = x2
    d[#d + 1] = y2
    return true, nil
end

-- Vbar object: opcode <36>
-- tx optional translator x-vector
-- ty optional translator y-vector
-- x0, y1, y2 ordinates
function gaCanvas:encode_vbar(vbar, x0, y1, y2, tx, ty) --> ok, err
    if type(vbar) ~= "table" then
        return false, "[ArgErr: vbar] table expected"
    end
    if x0 == nil then
        x0 = 0
    elseif type(x0) ~= "number" then
        return false, "[ArgErr: x0] number expected"
    end
    if type(y1) ~= "number" then return false, "[ArgErr: y1] number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr: y2] number expected" end
    -- ordinates
    if y1 == y2 then return false, "[ArgErr: y1, y2] same value" end
    if y1 > y2 then y1, y2 = y2, y1 end
    local bdim, bars
    if vbar._classname == "Vbar" then
        bdim, bars = vbar:get_bars()
        bdim = 2*bdim
    else
        bdim = #vbar
        if bdim % 2 ~= 0 then -- bdim must be even
            return false, "[Err: vbar] found an odd array of elements"
        end
        bars = vbar
    end
    if bdim == 0 then return false, "[Err: vbar] the number of bars is zero" end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x0 = x0 + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        y1 = y1 + ty
        y2 = y2 + ty
    end
    local data = self._data
    data[#data + 1] = 36 -- vbar sequence start
    data[#data + 1] = y1
    data[#data + 1] = y2
    data[#data + 1] = bdim/2 -- the number of bars, pair <x_i, w_i>
    for i = 1, bdim, 2 do
        local coord = bars[i]
        local width = bars[i + 1]
        if type(coord) ~= "number" then
            return false, "[Err] a coordinates is not a number"
        end
        if type(width) ~= "number" then
            return false, "[Err] a width is not a number"
        end
        data[#data + 1] = coord + x0
        data[#data + 1] = width
    end
    return true, nil
end

-- print a Vbar queue starting at x position 'xpos', between the horizontal line
-- tx optional translator x-vector
-- ty optional translator y-vector
-- at y0 and y1 y-coordinates
function gaCanvas:encode_vbar_queue(queue, xpos, y0, y1, tx, ty) --> ok, err
    -- check arg
    if type(queue) ~= "table" then
        return false, "[ArgErr: queue] table expected"
    end
    if type(xpos) ~= "number" then
        return false, "[ArgErr: xpos] number expected"
    end
    if type(y0) ~= "number" then
        return false, "[ArgErr: y0] number expected"
    end
    if type(y1) ~= "number" then
        return false, "[ArgErr: y1] number expected"
    end
    local i = 2
    while queue[i] do
        local x = queue[i - 1] + xpos
        local vbar = queue[i]
        local _, err = self:encode_vbar(vbar, x, y0, y1, tx, ty)
        if err then return false, err end
        i = i + 2
    end
    return true, nil
end

-- tx optional translator x-vector
-- ty optional translator y-vector
-- [text] <130> ax ay xpos ypos chars
function gaCanvas:encode_Text(txt, xpos, ypos, ax, ay, tx, ty) --> ok, err
    if type(txt) ~= "table" then
        return false, "[ArgErr: txt] object table expected"
    end
    if type(xpos) ~= "number" then
        return false, "[ArgErr: xpos] number expected"
    end
    if type(ypos) ~= "number" then
        return false, "[ArgErr: ypos] number expected"
    end
    if ax == nil then
        ax = 0
    elseif type(ax) ~= "number" then
        return false, "[ArgErr: ax] number expected"
    end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return false, "[ArgErr: ay] number expected"
    end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        xpos = xpos + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        ypos = ypos + ty
    end
    local chars = assert(txt.codepoint, "[InternalErr: txt] no 'codepoint' found")
    if #chars == 0 then return false, "[InternalErr: txt] no chars found" end
    local data = self._data
    data[#data + 1] = 130
    data[#data + 1] = ax -- relative anchor x-coordinate
    data[#data + 1] = ay -- relative anchor y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- glyphs equally spaced along the baseline
-- tx optional translator x-vector
-- ty optional translator y-vector
-- [text_xspaced] <131> x1 xgap ay ypos chars
function gaCanvas:encode_Text_xspaced(txt, x1, xgap, ypos, ay, tx, ty) --> ok, err
    if type(txt)~= "table" then return false, "[ArgErr: txt] object table expected" end
    local chars = assert(txt.codepoint, "[InternalErr: txt] no 'codepoint' found")
    local n = #chars
    if n == 0 then return false, "[InternalErr: txt] no chars found" end
    if type(x1) ~= "number" then return false, "[ArgErr: x1] number expected" end
    if type(xgap) ~= "number" then return false, "[ArgErr: xgap] number expected" end
    if xgap < 0 then
        local n = #chars
        x1 = x1 + (n - 1) * xgap
        xgap = -xgap
    end
    if type(ypos) ~= "number" then return false, "[ArgErr: ypos] number expected" end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return false, "[ArgErr: ay] number expected"
    end
    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x1 = x1 + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        ypos = ypos + ty
    end
    local data = self._data
    data[#data + 1] = 131
    data[#data + 1] = x1   -- x-coordinate of the first axis from left to right
    data[#data + 1] = xgap -- axial distance between gliphs
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- text_xwidth
-- tx optional translator x-vector
-- ty optional translator y-vector
-- text equally spaced but within [x1, x2] coordinate interval
-- <132> <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
function gaCanvas:encode_Text_xwidth(txt, x1, x2, ypos, ay, tx, ty) --> ok, err
    if type(txt)~= "table" then return false, "[ArgErr: txt] object table expected" end
    if type(x1) ~= "number" then return false, "[ArgErr: x1] number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr: x2] number expected" end
    if type(ypos) ~= "number" then return false, "[ArgErr: ypos] number expected" end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return false, "[ArgErr: ay] number expected"
    end
    local chars = assert(txt.codepoint, "[InternalErr: txt] no 'codepoint' found")
    if #chars == 0 then return false, "[InternalErr: txt] no chars found" end
    if x1 > x2 then x1, x2 = x2, x1 end -- reorder coordinates

    if tx ~= nil then
        if type(tx) ~= "number" then return false, "[ArgErr: tx] number expected" end
        x1 = x1 + tx
        x2 = x2 + tx
    end
    if ty ~= nil then
        if type(ty) ~= "number" then return false, "[ArgErr: ty] number expected" end
        ypos = ypos + ty
    end
    local data = self._data
    data[#data + 1] = 132
    data[#data + 1] = ay -- anchor relative y-coordinate
    data[#data + 1] = x1 -- left limit of the text box
    data[#data + 1] = x2 -- right limit of the text box
    data[#data + 1] = ypos -- text y-coordinate
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- experimental code section
-- new opcodes under assessment

-- [start_text_group] 140
function gaCanvas:start_text_group() --> ok, err
    local data = self._data
    data[#data + 1] = 140
    return true, nil
end

-- [gtext] 141
function gaCanvas:gtext(chars) --> ok, err
    if type(chars) ~= "table" then return false, "[ArgErr: chars] table expected" end
    local data = self._data
    data[#data + 1] = 141
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- [gtext_spaced] 142 gap string
function gaCanvas:gtext_spaced(gap, chars) --> ok, err
    if type(gap) ~= "number" then return false, "[ArgErr: gap] number expected" end
    if type(chars) ~= "table" then return false, "[ArgErr: chars] table expected" end
    local data = self._data
    data[#data + 1] = 142
    data[#data + 1] = gap
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- [gtext_space] 143 gap 
function gaCanvas:gtext_gap(gap) --> ok, err
    if type(gap) ~= "number" then return false, "[ArgErr: gap] number expected" end
    local data = self._data
    data[#data + 1] = 143
    data[#data + 1] = gap
    return true, nil
end


-- [end_text_group] 149 ax ay x y
function gaCanvas:end_text_group(xpos, ypos, ax, ay) --> ok, err
    if type(xpos) ~= "number" then return false, "[ArgErr: xpos] '' number expected" end
    if type(ypos) ~= "number" then return false, "[ArgErr: ypos] number expected" end
    if type(ax) ~= "number" then return false, "[ArgErr: ax] number expected" end
    if type(ay) ~= "number" then return false, "[ArgErr: ay] number expected" end
    local data = self._data
    data[#data + 1] = 149
    data[#data + 1] = ax   -- anchor relative x-coordinate
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    return true, nil
end

return gaCanvas
