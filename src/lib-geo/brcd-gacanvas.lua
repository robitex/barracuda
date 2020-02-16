-- class gaCanvas
-- Copyright (C) 2020 Roberto Giacomelli

-- ga -- basic function

local gaCanvas = {
    _VERSION     = "gacanvas v0.0.5",
    _NAME        = "gaCanvas",
    _DESCRIPTION = "A library for dealing with ga stream",
}
gaCanvas.__index = gaCanvas

-- ga specification: see the file ga-grammar.pdf in the doc directory

-- gaCanvas constructor
function gaCanvas:new() --> object
    local o = {
        _data = {},
        _v    = 100, -- version of the ga format
    }
    setmetatable(o, self)
    return o
end

-- Ipothetical another constructor
-- function gaCanvas:from_tcp_server() --> err
-- end

-- line width: opcode <1> <w: DIM>
function gaCanvas:encode_linethick(w) --> ok, err
    if type(w) ~= "number" then
        return false, "[ArgErr] 'w' number expected"
    end
    if w < 0 then return false, "[ArgErr] negative value for 'w'" end
    local data = self._data
    data[#data + 1] = 1 -- opcode for line thickness
    data[#data + 1] = w
    return true, nil
end

-- line cap style: opcode <2> <cap: u8>
-- 0 Butt cap
-- 1 Round cap
-- 2 Projecting square cap
function gaCanvas:encode_linecap(cap) --> ok, err
    if type(cap) ~= "number" then
        return false, "[ArgErr] 'cap' arg number expected"
    end
    if cap == 0 or cap == 1 or cap == 2 then
        local data = self._data
        data[#data + 1] = 2 -- opcode for line cap style
        data[#data + 1] = cap
    else
        return false, "[ArgErr] invalid value for 'cap'"
    end
    return true, nil
end

-- line cap style: opcode <3> <join: u8>
-- 0 Miter join
-- 1 Round join
-- 2 Bevel join
function gaCanvas:encode_linejoin(join) --> ok, err
    if type(join) ~= "number" then
        return false, "[ArgErr] 'join' arg number expected"
    end
    if join == 0 or join == 1 or join == 2 then
        local data = self._data
        data[#data + 1] = 3 -- opcode for line join style
        data[#data + 1] = join
    else
        return false, "[ArgErr] invalid value for 'join'"
    end
    return true, nil
end

-- Stop checking the bounding box
-- opcode: <30>
function gaCanvas:start_bbox_group() --> ok, err
    local data = self._data
    data[#data + 1] = 30
    return true, nil
end

-- restart checking the bounding box
-- and insert the specified bb for the entire object group
-- code: <31> x1 y1 x2 y2
function gaCanvas:stop_bbox_group(x1, y1, x2, y2) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return false, "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
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
-- <32> x1 y1 x2 y2
function gaCanvas:encode_line(x1, y1, x2, y2) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return false, "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
    local data = self._data
    data[#data + 1] = 32 -- append line data
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
    return true, nil
end

-- insert an horizontal line from point (x1, y) to point (x2, y)
-- <33> x1 x2 y
function gaCanvas:encode_hline(x1, x2, y) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr] 'x2' number expected" end
    if type(y) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
    local data = self._data
    data[#data + 1] = 33 -- append hline data
    data[#data + 1] = x1
    data[#data + 1] = x2
    data[#data + 1] = y
    return true, nil
end

-- insert a rectangle from point (x1, x2) to (x2, y2)
-- <48> <x1: DIM> <y1: DIM> <x2: DIM> <y2: DIM>
function gaCanvas:encode_rectangle(x1, y1, x2, y2) --> ok, err
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return false, "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
    local d = self._data
    d[#d + 1] = 48 -- append rectangle data
    d[#d + 1] = x1
    d[#d + 1] = y1
    d[#d + 1] = x2
    d[#d + 1] = y2
    return true, nil
end

-- Vbar object: opcode <36>
-- x0, y1, y2 ordinates
function gaCanvas:encode_Vbar(vbar, x0, y1, y2) --> ok, err
    if type(vbar) ~= "table" then
        return false, "[ArgErr] table expected for 'vbar'"
    end
    if x0 == nil then
        x0 = 0
    elseif type(x0) ~= "number" then
        return false, "[ArgErr] 'x0' number expected"
    end
    if type(y1) ~= "number" then return false, "[ArgErr] 'y1' number expected" end
    if type(y2) ~= "number" then return false, "[ArgErr] 'y2' number expected" end
    -- ordinates
    if y1 == y2 then return false, "[ArgErr] 'y1' 'y2' are the same value" end
    if y1 > y2 then y1, y2 = y2, y1 end
    local bars = assert(vbar._yline, "[InternalErr] no '_yline' field")
    local bdim = #bars
    if bdim == 0 then return false, "[InternalErr] number of bars is zero" end
    if bdim % 2 ~= 0 then
        return false, "[InternalErr] '_yline' does not have an even number of elements"
    end
    local data = self._data
    data[#data + 1] = 36 -- vbar sequence start
    data[#data + 1] = y1
    data[#data + 1] = y2
    data[#data + 1] = bdim / 2 -- the number of bars <x_i t_i>
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
-- at y0 and y1 y-coordinates
function gaCanvas:encode_Vbar_Queue(queue, xpos, y0, y1) --> ok, err
    -- check arg
    if type(queue) ~= "table" then
        return false, "[Err] 'queue' arg must be a table"
    end
    if type(xpos) ~= "number" then
        return false, "[Err] 'xpos' arg must be a number"
    end
    if type(y0) ~= "number" then
        return false, "[Err] 'y0' arg must be a number"
    end
    if type(y1) ~= "number" then
        return false, "[Err] 'y1' arg must be a number"
    end
    local i = 2
    while queue[i] do
        local x = queue[i - 1] + xpos
        local vbar = queue[i]
        local _, err = self:encode_Vbar(vbar, x, y0, y1)
        if err then return false, err end
        i = i + 2
    end
    return true, nil
end

-- [text] <130> ax ay x y chars
function gaCanvas:encode_Text(txt, xpos, ypos, ax, ay) --> ok, err
    if type(txt) ~= "table" then
        return false, "[ArgErr] 'txt' object table expected"
    end
    if type(xpos) ~= "number" then
        return false, "[ArgErr] 'xpos' number expected"
    end
    if type(ypos) ~= "number" then
        return false, "[ArgErr] 'ypos' number expected"
    end
    if ax == nil then
        ax = 0
    elseif type(ax) ~= "number" then
        return false, "[ArgErr] 'ax' number expected"
    end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return false, "[ArgErr] 'ay' number expected"
    end
    local data = self._data
    data[#data + 1] = 130
    data[#data + 1] = ax -- relative anchor x-coordinate
    data[#data + 1] = ay -- relative anchor y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    local chars = assert(txt.codepoint, "[InternalErr] no 'codepoint' field in txt")
    if #chars == 0 then return false, "[InternalErr] 'txt' has no chars" end
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- glyphs equally spaced along the baseline
-- [text_xspaced] <131> x1 xgap ay ypos chars
function gaCanvas:encode_Text_xspaced(txt, x1, xgap, ypos, ay) --> ok, err
    if type(txt)~= "table" then return false, "[ArgErr] 'txt' object table expected" end
    local chars = assert(txt.codepoint, "[InternalErr] no 'codepoint' field in txt")
    if #chars == 0 then return false, "[InternalErr] 'txt' has no chars" end
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(xgap) ~= "number" then return false, "[ArgErr] 'xgap' number expected" end
    if xgap < 0 then
        local n = #chars
        x1 = x1 + (n - 1) * xgap
        xgap = -xgap
    end
    if type(ypos) ~= "number" then return false, "[ArgErr] 'ypos' number expected" end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return false, "[ArgErr] 'ay' number expected"
    end
    local data = self._data
    data[#data + 1] = 131
    data[#data + 1] = x1   -- x-coordinate of the first axis from left to right
    data[#data + 1] = xgap -- axial distance among gliphs
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return true, nil
end

-- text_xwidth
-- text equally spaced but within [x1, x2] coordinate interval
-- <132> <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
function gaCanvas:encode_Text_xwidth(txt, x1, x2, ypos, ay) --> ok, err
    if type(txt)~= "table" then return false, "[ArgErr] 'txt' object table expected" end
    if type(x1) ~= "number" then return false, "[ArgErr] 'x1' number expected" end
    if type(x2) ~= "number" then return false, "[ArgErr] 'x2' number expected" end
    if type(ypos) ~= "number" then return false, "[ArgErr] 'ypos' number expected" end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return false, "[ArgErr] 'ay' number expected"
    end
    local chars = assert(txt.codepoint, "[InternalErr] no 'codepoint' field in txt")
    if #chars == 0 then return false, "[InternalErr] 'txt' has no chars" end
    if x1 > x2 then x1, x2 = x2, x1 end -- reorder coordinates
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
    if type(chars) ~= "table" then return false, "[ArgErr] 'chars' table expected" end
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
    if type(gap) ~= "number" then return false, "[ArgErr] 'gap' number expected" end
    if type(chars) ~= "table" then return false, "[ArgErr] 'chars' table expected" end
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
    if type(gap) ~= "number" then return false, "[ArgErr] 'gap' number expected" end
    local data = self._data
    data[#data + 1] = 143
    data[#data + 1] = gap
    return true, nil
end


-- [end_text_group] 149 ax ay x y
function gaCanvas:end_text_group(xpos, ypos, ax, ay) --> ok, err
    if type(xpos) ~= "number" then return false, "[ArgErr] 'xpos' number expected" end
    if type(ypos) ~= "number" then return false, "[ArgErr] 'ypos' number expected" end
    if type(ax) ~= "number" then return false, "[ArgErr] 'ax' number expected" end
    if type(ay) ~= "number" then return false, "[ArgErr] 'ay' number expected" end
    local data = self._data
    data[#data + 1] = 149
    data[#data + 1] = ax   -- anchor relative x-coordinate
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    return true, nil
end

-- amazing...
function gaCanvas:to_string() --> string

end

function gaCanvas:get_bbox()

end

function gaCanvas:check() --> boolean, err
    
end

return gaCanvas
