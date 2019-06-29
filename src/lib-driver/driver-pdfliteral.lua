--
-- ga Intermediate Graphic Language for barcode drawing
-- Copyright (C) 2018 Roberto Giacomelli
--
-- All dimension must be in scaled point (sp)
-- ga Driver LuaTeX native implementation (node+pdfliteral)

-- class for drawing elementary geometric elements
local PDFnative = {
    _VERSION     = "PDFnative v0.0.3",
    _NAME        = "PDFnative",
    _DESCRIPTION = "a LuaTeX native pdfliteral driver for ga graphic stream",
}

local node = assert(node)
local tex = assert(tex)
local font = assert(font)

-- text utility functions with node

local function newglue(w) --> node
    local n = node.new("glue")
    n.width = w
    return n
end

local function newglyph(c) --> node -- ? U+2423 ␣ for whitespace?
    if c == 32 then
        return newglue(tex.sp "3.5pt")
    end
    local n = node.new("glyph")
    n.char = c
    n.font = font.current()
    return n
end

local function newpdfliteral(buf) --> node
    local npdf = node.new("whatsit", "pdf_literal")
    npdf.mode = 0
    npdf.data = table.concat(buf, "\n")
    return npdf
end

local function append_glyph(head, last, c) --> head, last, xdim
    if c == 32 then -- space
        local space = tex.sp "3.5pt"
        head, last = node.insert_after(head, last, newglue(space))
        return head, last, space
    else
        local g = newglyph(c)
        local xdim = g.width
        head, last = node.insert_after(head, last, g)
        return head, last, xdim
    end
end

-- operation functions
-- operation_v001 corresponds to the version 1 of ga graphic assembler spec
-- this table indexed every opcode to a function that takes these arguments:
-- st: state
-- pc: program counter
-- ga: ga stream
-- bf: the output pdfliteral buffer
-- xt: the output text object buffer
-- return the updated program counter pointed to the next operation
PDFnative.operation_v001 = {
    -- set a pen line width
    -- 1 <W: dim>
    [1] = function (st, pc, ga, bf, xt)
        local w = ga[pc]; pc = pc + 1
        st.line_width = w
        local bp = 65781.76 -- conversion ratio sp -> bp
        bf[#bf + 1] = string.format("%0.6f w", w/bp)
        return pc
    end,

    [30] = function (st, pc, ga, bf, xt) -- start_bbox_group
        assert(st.bb_on)
        st.bb_on = false
        return pc
    end,
    [31] = function (st, pc, ga, bf, xt) -- end_bbox_group
        assert(st.bb_on == false)
        st.bb_on = true
        local x1 = ga[pc]; pc = pc + 1
        local y1 = ga[pc]; pc = pc + 1
        local x2 = ga[pc]; pc = pc + 1
        local y2 = ga[pc]; pc = pc + 1
        if st.bb_x1 == nil then
            st.bb_x1 = x1
            st.bb_y1 = y1
            st.bb_x2 = x2
            st.bb_y2 = y2
        else
            if x1 < st.bb_x1 then st.bb_x1 = x1 end
            if x2 > st.bb_x2 then st.bb_x2 = x2 end
            if y1 < st.bb_y1 then st.bb_y1 = y1 end
            if y2 > st.bb_y2 then st.bb_y2 = y2 end
        end
        return pc
    end,

    -- draw an horizontal single line
    -- 33 <x1: DIM> <x2: DIM> <y: DIM>
    [33] = function (st, pc, ga, bf, xt)
        local x1 = ga[pc]; pc = pc + 1
        local x2 = ga[pc]; pc = pc + 1
        local  y = ga[pc]; pc = pc + 1
        local bp = 65781.76 -- conversion ratio sp -> bp
        bf[#bf + 1] = string.format("% 0.6f %0.6f m", x1/bp, y/bp)
        bf[#bf + 1] = string.format("% 0.6f %0.6f l", x2/bp, y/bp)
        bf[#bf + 1] = "S" -- stroke
        if st.bb_on then -- eventually update bbox
            local hw  = st.line_width/2
            local by1 = y - hw
            local by2 = y + hw
            if st.bb_x1 == nil then
                st.bb_x1 = x1
                st.bb_x2 = x2
                st.bb_y1 = by1
                st.bb_y2 = by2
            else
                if  x1 < st.bb_x1 then st.bb_x1 =  x1 end
                if  x2 > st.bb_x2 then st.bb_x2 =  x2 end
                if by1 < st.bb_y1 then st.bb_y1 = by1 end
                if by2 > st.bb_y2 then st.bb_y2 = by2 end
            end
        end
        return pc
    end,

    -- draw a vertical single line
    -- 34 <y1: DIM> <y2: DIM> <x: DIM>
    [34] = function (st, pc, ga, bf, xt)
        local y1 = ga[pc]; pc = pc + 1
        local y2 = ga[pc]; pc = pc + 1
        local x  = ga[pc]; pc = pc + 1
        local bp = 65781.76 -- conversion ratio sp -> bp
        bf[#bf + 1] = string.format("% 0.6f %0.6f m", x/bp, y1/bp)
        bf[#bf + 1] = string.format("% 0.6f %0.6f l", x/bp, y2/bp)
        bf[#bf + 1] = "S" -- stroke
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

    -- draw a group of vertical lines
    -- 36 <y1: DIM> <y2: DIM> <b: UINT> <x1: DIM> <t1: DIM>
    [36] = function(st, pc, ga, bf, xt) -- vbar
        -- we have less memory consumption if we insert a bar as a rectangle
        -- rather than as a vertical line
        local y1   = ga[pc]; pc = pc + 1
        local y2   = ga[pc]; pc = pc + 1
        local nbar = ga[pc]; pc = pc + 1
        assert(nbar > 0)
        local h = y2 - y1 -- height common to every rectangles
        assert(h > 0)
        local bp = 65781.76 -- conversion ratio sp -> bp
        local fmt = "%0.6f %0.6f %0.6f" .. string.format(" %0.6f re", h/bp)
        local pc_next = pc + 2 * nbar
        local bx1, bx2
        for i = pc, pc_next - 1, 2 do -- reading coordinates <x axis> <width>
            local x = assert(ga[i], "[InternalErr] prematurely reached the end")
            local w = assert(ga[i+1], "[InternalErr] prematurely reached the end")
            local x1 = x - w/2
            -- pdf literal insertion <x y w h re>
            bf[#bf + 1] = string.format(fmt, x1/bp, y1/bp, w/bp)
            -- check the bounding box only if the corresponding flag is true
            if st.bb_on then
                if bx1 == nil then
                    bx1 = x1
                    bx2 = x1 + w
                else
                    if x1 < bx1 then bx1 = x1 end
                    local x2 = x1 + w
                    if x2 > bx2 then bx2 = x2 end
                end
            end
        end
        bf[#bf + 1] = "f" -- fill
        bf[#bf + 1] = "S" -- stroke
        if st.bb_on then -- eventually update bbox
            if st.bb_x1 == nil then
                st.bb_x1 = bx1
                st.bb_x2 = bx2
                st.bb_y1 = y1
                st.bb_y2 = y2
            else
                if bx1 < st.bb_x1 then st.bb_x1 = bx1 end
                if bx2 > st.bb_x2 then st.bb_x2 = bx2 end
                if  y1 < st.bb_y1 then st.bb_y1 = y1 end
                if  y2 > st.bb_y2 then st.bb_y2 = y2 end
            end
        end
        return pc_next
    end,

    -- draw a rectangle
    -- 48 <x1: DIM> <y1: DIM> <x2: DIM> <y2: DIM>
    [48] = function(st, pc, ga, bf, xt)
        local x1   = ga[pc]; pc = pc + 1
        local y1   = ga[pc]; pc = pc + 1
        local x2   = ga[pc]; pc = pc + 1
        local y2   = ga[pc]; pc = pc + 1
        local w = x2 - x1 -- rectangle width
        assert(w > 0)
        local h = y2 - y1 -- rectangle height
        assert(h > 0)
        local bp = 65781.76 -- conversion ratio sp -> bp
        local fmt = "%0.6f %0.6f %0.6f %0.6f re S"
        -- pdf literal insertion <x y w h re>
        bf[#bf + 1] = string.format(fmt, x1/bp, y1/bp, w/bp, h/bp)
        
        -- check the bounding box only if the corresponding flag is true
        if st.bb_on then
            local hw  = st.line_width/2
            local bx1, bx2 = x1 - hw, x2 + hw
            local by1, by2 = y1 - hw, y2 + hw
            if st.bb_x1 == nil then
                st.bb_x1 = bx1
                st.bb_x2 = bx2
                st.bb_y1 = by1
                st.bb_y2 = by2
            else
                if bx1 < st.bb_x1 then st.bb_x1 = bx1 end
                if bx2 > st.bb_x2 then st.bb_x2 = bx2 end
                if by1 < st.bb_y1 then st.bb_y1 = by1 end
                if by2 > st.bb_y2 then st.bb_y2 = by2 end
            end
        end
        return pc
    end,

    [130] = function(st, pc, ga, bf, xt) -- text: ax ay xpos ypos string
        local ax   = ga[pc]; pc = pc + 1
        local ay   = ga[pc]; pc = pc + 1
        local xpos = ga[pc]; pc = pc + 1
        local ypos = ga[pc]; pc = pc + 1
        assert(ga[pc] ~= 0, "[InternalErr] No char")
        local head, last
        while ga[pc] ~= 0 do
            local c = ga[pc]; pc = pc + 1
            head, last = append_glyph(head, last, c)
        end
        local hbox = node.hpack(head)
        local w, h, d = node.dimensions(hbox)
        local x = xpos - ax*w -- text x, y position
        local y
        if ay > 0 then
            y = ypos - h*ay
        else
            y = ypos - d*ay
        end
        -- bounding box checking
        if st.bb_on then -- eventually update bbox
            if st.bb_x1 == nil then
                st.bb_x1 = x
                st.bb_x2 = x + w
                st.bb_y1 = y
                st.bb_y2 = y + h
            else
                if     x < st.bb_x1 then st.bb_x1 = x end
                if x + w > st.bb_x2 then st.bb_x2 = x + w end
                if     y < st.bb_y1 then st.bb_y1 = y end
                if y + h > st.bb_y2 then st.bb_y2 = y + h end
            end
        end
        xt[#xt + 1] = {hbox, x, y - d, w, h}
        return pc + 1
    end,

    [131] = function(st, pc, ga, bf, xt) -- text_xspaced x1 xgap ay ypos chars
        local x1   = ga[pc]; pc = pc + 1
        local xgap = ga[pc]; pc = pc + 1
        local ay   = ga[pc]; pc = pc + 1
        local ypos = ga[pc]; pc = pc + 1
        assert(ga[pc] ~= 0, "[InternalErr] No char")
        local head, last -- node list
        local c1 = ga[pc]; pc = pc + 1 -- first char
        head, last, xc = append_glyph(head, last, c1)
        local x = x1 - xc/2 -- x hbox coordinate
        while ga[pc] ~= 0 do
            local g = newglyph(ga[pc]); pc = pc + 1
            local xdim = g.width
            local isp = xgap - (xc + xdim)/2
            --assert(isp >= 0, "[InternalErr] have you decided what to do?")
            local s = newglue(isp)
            head, last = node.insert_after(head, last, s)
            head, last = node.insert_after(head, last, g)
            xc = xdim
        end
        local hbox = node.hpack(head)
        local w, h, d = node.dimensions(hbox)
        local y -- y hbox coordinate
        if ay > 0 then
            y = ypos - h*ay
        else
            y = ypos - d*ay
        end
        -- bounding box checking
        if st.bb_on then -- eventually update bbox
            if st.bb_x1 == nil then
                st.bb_x1 = x
                st.bb_x2 = x + w
                st.bb_y1 = y      -- no depth
                st.bb_y2 = y + h
            else
                if     x < st.bb_x1 then st.bb_x1 = x end
                if x + w > st.bb_x2 then st.bb_x2 = x + w end
                if     y < st.bb_y1 then st.bb_y1 = y end
                if y + h > st.bb_y2 then st.bb_y2 = y + h end
            end
        end
        xt[#xt + 1] = {hbox, x, y - d, w, h}
        return pc + 1
    end,
    
    -- text_xwidth
    -- <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
    [132] = function (st, pc, ga, bf, xt)
        local ay = ga[pc]; pc = pc + 1 -- y anchor
        local x1 = ga[pc]; pc = pc + 1 -- left limit
        local x2 = ga[pc]; pc = pc + 1 -- right limit
        assert (x1 ~= x2, "[InternalErr] x coordinate are equal")
        assert (x1 < x2, "[InternalErr] not order limit")
        local ypos = ga[pc]; pc = pc + 1 -- y coordinate of anchor point
        local c1 = ga[pc]; pc = pc + 1 -- first char
        assert(c1 ~= 0, "[InternalErr] empty char sequence")
        assert(ga[pc] ~= 0, "[InternalErr] we need almost two char in the sequence")
        local i = 1
        local head, last -- node list
        local w_1 -- width of the first char
        head, last, w_1 = append_glyph(head, last, c1)
        while ga[pc] ~= 0 do
            local s = newglue(0) -- unknow dim at moment
            head, last = node.insert_after(head, last, s)
            local g = newglyph(ga[pc]); pc = pc + 1
            head, last = node.insert_after(head, last, g)
            i = i + 1
        end
        local w_n = last.width
        local xgap = ( x2 - x1 - (w_1 + w_n)/2 )/(i - 1)
        local c_curr = head
        for _ = 1, i - 1 do
            local g = c_curr.next
            local c_next = g.next
            w_1, w_2 = c_curr.width, c_next.width
            g.width = xgap - (w_1 + w_2)/2
            c_curr = c_next
        end
        local hbox = node.hpack(head)
        local _, h, d = node.dimensions(hbox)
        local y -- y hbox coordinate
        if ay > 0 then
            y = ypos - h*ay
        else
            y = ypos - d*ay
        end
        -- bounding box checking
        if st.bb_on then -- eventually update bbox
            if st.bb_x1 == nil then
                st.bb_x1 = x1
                st.bb_x2 = x2
                st.bb_y1 = y      -- no depth
                st.bb_y2 = y + h
            else
                if    x1 < st.bb_x1 then st.bb_x1 = x1 end
                if    x2 > st.bb_x2 then st.bb_x2 = x2 end
                if     y < st.bb_y1 then st.bb_y1 = y end
                if y + h > st.bb_y2 then st.bb_y2 = y + h end
            end
        end
        xt[#xt + 1] = {hbox, x1, y - d, x2 - x1, h}
        return pc + 1
    end,
}

-- drawing function
local function hboxcreate(hboxname, buf, txt, bb_x1, bb_y1, bb_x2, bb_y2)
    assert(
        tex.isbox(hboxname),
        string.format("Box register [%s] doesn’t exist", hboxname)
    )
    local npdf = newpdfliteral(buf) -- node whatsit pdfliteral
    -- vboxing, vertical correction
    local vpdf = node.vpack(npdf)
    vpdf.height = -bb_y1
    -- glue, for horizontal correction
    local ng = newglue(-bb_x1)
    local head, last = node.insert_after(ng, ng, vpdf)
    local xprev = 0.0
    for _, t in ipairs(txt) do -- text processing
        local gy = newglue(t[3] - bb_y1) -- n, x, y, w, h -- t[3] -t[5] - bb_y1
        local nvtxt = node.insert_after(t[1], t[1], gy)
        local vtxt = node.vpack(nvtxt)
        local gx = newglue(t[2]-xprev)
        head, last = node.insert_after(head, last, gx)
        head, last = node.insert_after(head, last, vtxt)
        xprev = t[2] + t[4]
    end
    -- hboxing
    local hbox = node.hpack(head)
    hbox.width  = bb_x2 - bb_x1
    hbox.height = bb_y2 - bb_y1
    tex.box[hboxname] = hbox
end

-- stream processing and hbox node building
function PDFnative:ga_to_hbox(ga, hboxname)
    local op_fn = self.operation_v001
    local bf = {"q 1 1"} -- new stack and line width equal to 1bp
    local xt = {} -- text buffer
    local st = { -- state of the process
        line_width = 65781.76, -- line width like 1bp
        gtext = false, -- text group off
        bb_on = true, -- bounding box checking activation
        bb_x1 = nil, -- bounding box coordinates in scaled point
        bb_y1 = nil, -- nil means no data
        bb_x2 = nil,
        bb_y2 = nil,
    }
    local pc = 1 -- program counter
    local data = ga._data
    while data[pc] do -- stream processing
        local opcode = data[pc]
        local fn = assert(op_fn[opcode], "[InternalErr] Opcode ".. opcode.." not found")
        pc = fn(st, pc + 1, data, bf, xt)
    end
    bf[#bf + 1] = "Q" -- stack restoring
    hboxcreate(hboxname, bf, xt, st.bb_x1, st.bb_y1, st.bb_x2, st.bb_y2)
end

return PDFnative

