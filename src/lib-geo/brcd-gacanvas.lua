-- class gaCanvas
-- Copyright (C) 2020 Roberto Giacomelli

-- ga -- basic function

local gaCanvas = {
    _VERSION     = "gacanvas v0.0.4",
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
function gaCanvas:encode_linethick(w) --> err
    if type(w) ~= "number" then return "[ArgErr] 'w' number expected" end
    if w < 0 then return "[ArgErr] negative value for 'w'" end
    local data = self._data
    data[#data + 1] = 1 -- opcode for line thickness
    data[#data + 1] = w
end

-- line cap style: opcode <2> <cap: u8>
-- 0 Butt cap
-- 1 Round cap
-- 2 Projecting square cap
function gaCanvas:encode_linecap(cap) --> err
    if type(cap) ~= "number" then return "[ArgErr] 'cap' arg number expected" end
    if cap == 0 or cap == 1 or cap == 2 then
        local data = self._data
        data[#data + 1] = 2 -- opcode for line cap style
        data[#data + 1] = cap
    else
        return "[ArgErr] invalid value for 'cap'"
    end
end

-- line cap style: opcode <3> <join: u8>
-- 0 Miter join
-- 1 Round join
-- 2 Bevel join
function gaCanvas:encode_linejoin(join) --> err
    if type(join) ~= "number" then return "[ArgErr] 'join' arg number expected" end
    if join == 0 or join == 1 or join == 2 then
        local data = self._data
        data[#data + 1] = 3 -- opcode for line join style
        data[#data + 1] = join
    else
        return "[ArgErr] invalid value for 'join'"
    end
end

-- Stop checking the bounding box
-- opcode: <30>
function gaCanvas:start_bbox_group() --> err
    local data = self._data
    data[#data + 1] = 30
end

-- restart checking the bounding box
-- and insert the specified bb for the entire object group
-- code: <31> x1 y1 x2 y2
function gaCanvas:stop_bbox_group(x1, y1, x2, y2) --> err
    if type(x1) ~= "number" then return "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return "[ArgErr] 'y2' number expected" end
    if x1 > x2 then x1, x2 = x2, x1 end -- reorder coordinates
    if y1 > y2 then y1, y2 = y2, y1 end
    local data = self._data
    data[#data + 1] = 31 -- bounding box of the object group
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
end

-- insert a line from point (x1, y1) to the point (x2, y2)
-- <32> x1 y1 x2 y2
function gaCanvas:encode_line(x1, y1, x2, y2) --> err
    if type(x1) ~= "number" then return "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return "[ArgErr] 'y2' number expected" end
    local data = self._data
    data[#data + 1] = 32 -- append line data
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
end

-- insert an horizontal line from point (x1, y) to point (x2, y)
-- <33> x1 x2 y
function gaCanvas:encode_hline(x1, x2, y) --> err
    if type(x1) ~= "number" then return "[ArgErr] 'x1' number expected" end
    if type(x2) ~= "number" then return "[ArgErr] 'x2' number expected" end
    if type(y) ~= "number" then return "[ArgErr] 'y2' number expected" end
    local data = self._data
    data[#data + 1] = 33 -- append hline data
    data[#data + 1] = x1
    data[#data + 1] = x2
    data[#data + 1] = y
end

-- insert a rectangle from point (x1, x2) to (x2, y2)
-- <48> <x1: DIM> <y1: DIM> <x2: DIM> <y2: DIM>
function gaCanvas:encode_rectangle(x1, y1, x2, y2) --> err
    if type(x1) ~= "number" then return "[ArgErr] 'x1' number expected" end
    if type(y1) ~= "number" then return "[ArgErr] 'y1' number expected" end
    if type(x2) ~= "number" then return "[ArgErr] 'x2' number expected" end
    if type(y2) ~= "number" then return "[ArgErr] 'y2' number expected" end
    local d = self._data
    d[#d + 1] = 48 -- append rectangle data
    d[#d + 1] = x1
    d[#d + 1] = y1
    d[#d + 1] = x2
    d[#d + 1] = y2
end

-- Vbar object: opcode <36>
-- x0, y1, y2 ordinates
function gaCanvas:encode_Vbar(vbar, x0, y1, y2) --> err
    if type(vbar) ~= "table" then
        return "[ArgErr] table expected for 'vbar'"
    end
    if x0 == nil then
        x0 = 0
    elseif type(x0) ~= "number" then
        return "[ArgErr] 'x0' number expected"
    end
    if type(y1) ~= "number" then return "[ArgErr] 'y1' number expected" end
    if type(y2) ~= "number" then return "[ArgErr] 'y2' number expected" end
    -- ordinates
    if y1 == y2 then return "[ArgErr] 'y1' 'y2' are the same value" end
    if y1 > y2 then y1, y2 = y2, y1 end
    local bars = assert(vbar._yline, "[InternalErr] no '_yline' field")
    local bdim = #bars
    if bdim == 0 then return "[InternalErr] number of bars is zero" end
    if bdim % 2 ~= 0 then
        return "[InternalErr] '_yline' does not have an even number of elements"
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
            return "[Err] a coordinates is not a number"
        end
        if type(width) ~= "number" then
            return "[Err] a width is not a number"
        end
        data[#data + 1] = coord + x0
        data[#data + 1] = width
    end
end

-- [text] <130> ax ay x y chars
function gaCanvas:encode_Text(txt, xpos, ypos, ax, ay) --> err
    if type(txt) ~= "table" then
        return "[ArgErr] 'txt' object table expected"
    end
    if type(xpos) ~= "number" then
        return "[ArgErr] 'xpos' number expected"
    end
    if type(ypos) ~= "number" then
        return "[ArgErr] 'ypos' number expected"
    end
    if ax == nil then
        ax = 0
    elseif type(ax) ~= "number" then
        return "[ArgErr] 'ax' number expected"
    end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return "[ArgErr] 'ay' number expected"
    end
    local data = self._data
    data[#data + 1] = 130
    data[#data + 1] = ax -- relative anchor x-coordinate
    data[#data + 1] = ay -- relative anchor y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    local chars = assert(txt.codepoint, "[InternalErr] no 'codepoint' field in txt")
    if #chars == 0 then return "[InternalErr] 'txt' has no chars" end
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
end

-- glyphs equally spaced along the baseline
-- [text_xspaced] <131> x1 xgap ay ypos chars
function gaCanvas:encode_Text_xspaced(txt, x1, xgap, ypos, ay) --> err
    if type(txt)~= "table" then return "[ArgErr] 'txt' object table expected" end
    local chars = assert(txt.codepoint, "[InternalErr] no 'codepoint' field in txt")
    if #chars == 0 then return "[InternalErr] 'txt' has no chars" end
    if type(x1) ~= "number" then return "[ArgErr] 'x1' number expected" end
    if type(xgap) ~= "number" then return "[ArgErr] 'xgap' number expected" end
    if xgap < 0 then
        local n = #chars
        x1 = x1 + (n - 1) * xgap
        xgap = -xgap
    end
    if type(ypos) ~= "number" then return "[ArgErr] 'ypos' number expected" end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return "[ArgErr] 'ay' number expected"
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
end

-- text_xwidth
-- text equally spaced but within [x1, x2] coordinate interval
-- <132> <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
function gaCanvas:encode_Text_xwidth(txt, x1, x2, ypos, ay) --> err
    if type(txt)~= "table" then return "[ArgErr] 'txt' object table expected" end
    if type(x1) ~= "number" then return "[ArgErr] 'x1' number expected" end
    if type(x2) ~= "number" then return "[ArgErr] 'x2' number expected" end
    if type(ypos) ~= "number" then return "[ArgErr] 'ypos' number expected" end
    if ay == nil then
        ay = 0
    elseif type(ay) ~= "number" then
        return "[ArgErr] 'ay' number expected"
    end
    local chars = assert(txt.codepoint, "[InternalErr] no 'codepoint' field in txt")
    if #chars == 0 then return "[InternalErr] 'txt' has no chars" end
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
end

-- experimental code section
-- new opcodes under assessment

-- [start_text_group] 140
function gaCanvas:start_text_group() --> err
    local data = self._data
    data[#data + 1] = 140
end

-- [gtext] 141
function gaCanvas:gtext(chars) --> err
    if type(chars) ~= "table" then return "[ArgErr] 'chars' table expected" end
    local data = self._data
    data[#data + 1] = 141
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
end

-- [gtext_spaced] 142 gap string
function gaCanvas:gtext_spaced(gap, chars) --> err
    if type(gap) ~= "number" then return "[ArgErr] 'gap' number expected" end
    if type(chars) ~= "table" then return "[ArgErr] 'chars' table expected" end
    local data = self._data
    data[#data + 1] = 142
    data[#data + 1] = gap
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
end

-- [gtext_space] 143 gap 
function gaCanvas:gtext_gap(gap) --> err
    if type(gap) ~= "number" then return "[ArgErr] 'gap' number expected" end
    local data = self._data
    data[#data + 1] = 143
    data[#data + 1] = gap
end


-- [end_text_group] 149 ax ay x y
function gaCanvas:end_text_group(xpos, ypos, ax, ay) --> err
    if type(xpos) ~= "number" then return "[ArgErr] 'xpos' number expected" end
    if type(ypos) ~= "number" then return "[ArgErr] 'ypos' number expected" end
    if type(ax) ~= "number" then return "[ArgErr] 'ax' number expected" end
    if type(ay) ~= "number" then return "[ArgErr] 'ay' number expected" end
    local data = self._data
    data[#data + 1] = 149
    data[#data + 1] = ax   -- anchor relative x-coordinate
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
end

-- amazing...
function gaCanvas:to_string() --> string

end

function gaCanvas:get_bbox()

end

function gaCanvas:check() --> boolean, err
    
end

return gaCanvas
