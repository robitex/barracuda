--
-- ga Intermediate Graphic Language for barcode drawing
-- Copyright (C) 2019 Roberto Giacomelli
--
-- All dimension in the ga stream are scaled point (sp)
-- 1 sp = 65536pt
-- ga SVG Driver

-- class for drawing elementary geometric elements
local SVG = {
    _VERSION     = "SVGdriver v0.0.1",
    _NAME        = "SVGdriver",
    _DESCRIPTION = "A SVG driver for ga graphic stream",
}

-- operation functions
-- operation_v001 corresponds to the version 1 of ga graphic assembler spec
-- this table indexes every opcode to a function that takes these arguments:
-- st: state
-- pc: program counter
-- ga: ga stream
-- bf: the output pdfliteral buffer
-- xt: the output text object buffer
-- and return the updated program counter pointing to the next operation
SVG.operation_v001 = {
    [1] = function (st, pc, ga, bf, xt) -- 1 <W: dim>; set line width
        local w = ga[pc]
        local mm = st.mm -- conversion ratio sp -> mm
        st.line_width = w/mm
        return pc + 1
    end,
    -- draw a vertical line
    -- 34 <y1: DIM> <y2: DIM> <x: DIM>
    [34] = function (st, pc, ga, bf, xt)
        local y1 = ga[pc]; pc = pc + 1
        local y2 = ga[pc]; pc = pc + 1
        local x  = ga[pc]; pc = pc + 1
        local mm = st.mm -- conversion ratio sp -> bp
        local w = st.line_width -- sp
        local lvl = st.ident_lvl
        local ident = string.rep(" ", 2*lvl)
        bf[#bf + 1] = string.format('%s<path d="M%0.6f %0.6fV%0.6f"', ident, x/mm, -y1/mm, -y2/mm)
        bf[#bf + 1] = string.format('%s  style="stroke:#000000;stroke-width:%0.6fmm"', ident, w/mm)
        bf[#bf + 1] = ident..'/>'
        if st.bb_on then -- eventually update bbox
            local hw  = st.line_width/2
            local bx1 = x - hw
            local bx2 = x + hw
            if st.bb_x1 == nil then
                st.bb_x1 = bx1
                st.bb_x2 = bx2
                st.bb_y1 = y1
                st.bb_y2 = y2
            else
                if bx1 < st.bb_x1 then st.bb_x1 = bx1 end
                if bx2 > st.bb_x2 then st.bb_x2 = bx2 end
                if y1 < st.bb_y1 then st.bb_y1 = y1 end
                if y2 > st.bb_y2 then st.bb_y2 = y2 end
            end
        end
        return pc
    end,
}

-- it fills bounding box data and creates the svg external file
local function create_svg_file(filename, buf, txt, bb_x1, bb_y1, bb_x2, bb_y2)
    local mm = 186467.9811 -- sp
    local w = (bb_x2 - bb_x1)/mm
    local h = (bb_y2 - bb_y1)/mm
    local fmt_wh = buf[7]
    buf[7] = string.format(fmt_wh, w, h) -- line 7
    local x = bb_x1/mm
    local y = -bb_y2/mm
    local fmt_vw = buf[8]
    buf[8] = string.format(fmt_vw, x, y, w, h)
    local fn = io.open(filename..".svg", "w")
    fn:write(table.concat(buf, "\n"))
    fn:close()
end

-- stream processing and hbox node building
function SVG:ga_to_file(ga, filename)
    local bf = {
        '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
        '<!-- Created with Barracuda package (https://github.com/robitex/barracuda) -->',
        '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"',
        '  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">',
        '<svg xmlns="http://www.w3.org/2000/svg"',
        '  version="1.1"',
        '  width="%0.6fmm" height="%0.6fmm"', -- line 7
        '  viewBox="%0.6f %0.6f %0.6f %0.6f"', -- line 8
        '>',
    } -- a new buffer
    local xt = {} -- text buffer
    local st = { -- state of the process
        ident_lvl = 1, -- identation level
        mm = 186467.9811, -- conversion ratio mm/sp
        line_width = 65882.135, -- line width like 1bp (sp)
        gtext = false, -- text group off
        bb_on = true, -- bounding box checking activation
        bb_x1 = nil, -- bounding box coordinates in sp
        bb_y1 = nil, -- nil means no data
        bb_x2 = nil,
        bb_y2 = nil,
    }
    local pc = 1 -- program counter
    local data = ga._data
    local op_fn = self.operation_v001
    while data[pc] do -- stream processing
        local opcode = data[pc]
        local fn = assert(op_fn[opcode], "[InternalErr] Opcode ".. opcode.." not found")
        pc = fn(st, pc + 1, data, bf, xt)
    end
    bf[#bf + 1] = '</svg>' -- close svg xml element
    bf[#bf + 1] = '' -- last empty line
    create_svg_file(filename, bf, xt, st.bb_x1, st.bb_y1, st.bb_x2, st.bb_y2)
end

return SVG


--<?xml version="1.0" standalone="no"?>
--<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" 
--  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
--<svg xmlns="http://www.w3.org/2000/svg"
--     version="1.1" width="5cm" height="5cm">
--  <desc>Two groups, each of two rectangles</desc>
--  <g id="group1" fill="red">
--    <rect x="1cm" y="1cm" width="1cm" height="1cm"/>
--    <rect x="3cm" y="1cm" width="1cm" height="1cm"/>
--  </g>
--  <g id="group2" fill="blue">
--    <rect x="1cm" y="3cm" width="1cm" height="1cm"/>
--    <rect x="3cm" y="3cm" width="1cm" height="1cm"/>
--  </g>
--
--  <!-- Show outline of canvas using 'rect' element -->
--  <rect x=".01cm" y=".01cm" width="4.98cm" height="4.98cm"
--        fill="none" stroke="blue" stroke-width=".02cm"/>
--</svg>

