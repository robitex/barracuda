-- class gaCanvas


-- ga -- basic function

local gaCanvas = {
    _VERSION     = "gacanvas v0.0.1",
    _GA_ID       = 1,
    _NAME        = "gaCanvas",
    _DESCRIPTION = "a library for dealing with ga stream",
}
gaCanvas.__index = gaCanvas

-- ga specification: see the file ga-grammar.pdf in the doc directory

-- constructor
function gaCanvas:new() --> object
    local o = {
        _data = {},
    }
    setmetatable(o, self)
    return o
end

-- ipothetical constructor
function gaCanvas:from_tcp_server() --> self, err
end

-- insert a line from point (x1, y1) to (x2, y2)
-- 32 x1 y1 x2 y2
function gaCanvas:line(x1, y1, x2, y2) --> self, err
    if not type(x1) == "number" then return nil, "[ArgErr] x1 number expected" end
    if not type(y1) == "number" then return nil, "[ArgErr] y1 number expected" end
    if not type(x2) == "number" then return nil, "[ArgErr] x2 number expected" end
    if not type(y2) == "number" then return nil, "[ArgErr] y2 number expected" end
    -- append
    local data = self._data
    data[#data + 1] = 32 -- line
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
    return self, nil
end

-- vbar
-- y1, y2 ordinates
-- encoding: 36 
function gaCanvas:vbar(x0, y1, y2, bars) --> self, err
    if not type(x0) == "number" then return nil, "[ArgErr] x0 number expected" end
    if not type(y1) == "number" then return nil, "[ArgErr] y1 number expected" end
    if not type(y2) == "number" then return nil, "[ArgErr] y2 number expected" end
    if not type(bars) == "table" then
        return nil, "[ArgErr] 'bars' table expected"
    end
    local bdim = #bars
    if bdim % 2 ~= 0 then
        return nil, "[Err] bars does not have an even number of numbers"
    end
    -- ordinates
    if y1 == y2 then return nil, "[Err] y1 y2 have the same value" end
    if y1 > y2 then y1, y2 = y2, y1 end
    local data = self._data
    data[#data + 1] = 36 -- vbar
    data[#data + 1] = y1
    data[#data + 1] = y2
    data[#data + 1] = bdim / 2 -- the number of bars <x_i t_i>
    for i = 1, bdim, 2 do
        local coord = bars[i]
        local width = bars[i + 1]
        if type(coord) ~= "number" then
            return nil, "[Err] a coordinates is not a number"
        end
        if type(width) ~= "number" then
            return nil, "[Err] a width is not a number"
        end
        data[#data + 1] = coord + x0
        data[#data + 1] = width
    end
    return self, nil
end

-- Stop to check the bounding box
-- code: 30
function gaCanvas:start_bbox_group() --> self, err
    local data = self._data
    data[#data + 1] = 30
    return self, nil
end

-- restart to check the bounding box
-- and insert one for the entire object group
-- code: 31 x1 y1 x2 y2
function gaCanvas:stop_bbox_group(x1, y1, x2, y2) --> self, err
    if not type(x1) == "number" then return nil, "[ArgErr] x1 number expected" end
    if not type(y1) == "number" then return nil, "[ArgErr] y1 number expected" end
    if not type(x2) == "number" then return nil, "[ArgErr] x2 number expected" end
    if not type(y2) == "number" then return nil, "[ArgErr] y2 number expected" end
    if x1 > x2 then x1, x2 = x2, x1 end -- reorder coordinates
    if y1 > y2 then y1, y2 = y2, y1 end
    local data = self._data
    data[#data + 1] = 31 -- bounding box of the object group
    data[#data + 1] = x1
    data[#data + 1] = y1
    data[#data + 1] = x2
    data[#data + 1] = y2
    return self, nil
end


-- [text] 130 ax ay x y string
function gaCanvas:text(xpos, ypos, ax, ay, chars)
    if not type(xpos) == "number" then return nil, "[ArgErr] 'xpos' number expected" end
    if not type(ypos) == "number" then return nil, "[ArgErr] 'ypos' number expected" end
    if not type(ax) == "number" then return nil, "[ArgErr] 'ax' number expected" end
    if not type(ay) == "number" then return nil, "[ArgErr] 'ay' number expected" end
    if not type(chars) == "table" then return nil, "[ArgErr] 'chars' table expected" end
    local data = self._data
    data[#data + 1] = 130
    data[#data + 1] = ax -- anchor relative x-coordinate
    data[#data + 1] = ay -- anchor relative y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return self, nil
end

-- [text_xspaced] 131 x1 xgap ay ypos chars
function gaCanvas:text_xspaced(x1, xgap, ay, ypos, chars)
    if not type(x1)   == "number" then return nil, "[ArgErr] 'x1' number expected" end
    if not type(xgap) == "number" then return nil, "[ArgErr] 'xgap' number expected" end
    if not type(ay)   == "number" then return nil, "[ArgErr] 'ay' number expected" end
    if not type(ypos) == "number" then return nil, "[ArgErr] 'ypos' number expected" end
    if not type(chars) == "table" then return nil, "[ArgErr] 'chars' table expected" end
    local data = self._data
    data[#data + 1] = 131
    data[#data + 1] = x1   -- x-coordinate of the first axis from left to right
    data[#data + 1] = xgap  -- axial distance among gliphs
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0    -- end string signal
    return self, nil
end

-- [start_text_group] 140
function gaCanvas:start_text_group()
    local data = self._data
    data[#data + 1] = 140
    return self, nil
end

-- [gtext] 141
function gaCanvas:gtext(chars)
    if not type(chars) == "table" then return nil, "[ArgErr] 'chars' table expected" end
    local data = self._data
    data[#data + 1] = 141
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return self, nil
end

-- [gtext_spaced] 142 gap string
function gaCanvas:gtext_spaced(gap, chars)
    if not type(gap) == "number" then return nil, "[ArgErr] 'gap' number expected" end
    if not type(chars) == "table" then return nil, "[ArgErr] 'chars' table expected" end
    local data = self._data
    data[#data + 1] = 142
    data[#data + 1] = gap
    for _, c in ipairs(chars) do
        data[#data + 1] = c
    end
    data[#data + 1] = 0 -- end string signal
    return self, nil
end

-- [gtext_space] 143 gap 
function gaCanvas:gtext_gap(gap)
    if not type(gap) == "number" then return nil, "[ArgErr] 'gap' number expected" end
    local data = self._data
    data[#data + 1] = 143
    data[#data + 1] = gap
    return self, nil
end


-- [end_text_group] 149 ax ay x y
function gaCanvas:end_text_group(xpos, ypos, ax, ay)
    if not type(xpos) == "number" then return nil, "[ArgErr] 'xpos' number expected" end
    if not type(ypos) == "number" then return nil, "[ArgErr] 'ypos' number expected" end
    if not type(ax) == "number" then return nil, "[ArgErr] 'ax' number expected" end
    if not type(ay) == "number" then return nil, "[ArgErr] 'ay' number expected" end
    local data = self._data
    data[#data + 1] = 149
    data[#data + 1] = ax   -- anchor relative x-coordinate
    data[#data + 1] = ay   -- anchor relative y-coordinate
    data[#data + 1] = xpos -- text x-coordinate
    data[#data + 1] = ypos -- text y-coordinate
    return self, nil
end


-- amazing...
function gaCanvas:to_string()

end

function gaCanvas:get_bbox()

end

function gaCanvas:check_stream()
    -- body
end




return gaCanvas

