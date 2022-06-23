--
-- ga graphic assembler or
-- Intermediate Graphic Language for barcode drawing
-- Copyright (C) 2019-2022 Roberto Giacomelli
--
-- All dimensions are in scaled point (sp)
-- ga LuaTeX Driver (native implementation node+pdfliteral)

local tex = assert(tex, "This require a Lua powered TeX engine")
local node = assert(node, "This require a Lua powered TeX engine")
local font = assert(font, "This require a Lua powered TeX engine")

-- class for drawing elementary geometric elements
local PDFnative = {_drvname = "PDFnative"}
PDFnative.ext = "txt" -- file extension
PDFnative.buf_sep = "\n" -- separation string for buffer concat

function PDFnative.init_buffer(st) --> buffer, text buffer
    st.head = nil -- addition for text processing (to remember purpose)
    st.last = nil
    st.hbox = nil
    st.dash_array = nil
    st.cw = nil
    st.x_hbox = nil
    st.char_counter = nil
    local bf = {"q"} -- create a new graphic stack
    local xt = {} -- text buffer
    return bf, xt
end

function PDFnative.close_buffer(st, bf, xt)
    bf[#bf + 1] = "Q" -- stack restoring
end

-- text utility special functions

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

-- special drawing function
function PDFnative.hboxcreate(hboxname, st, buf, txt) --> ok, err
    local node = assert(node, "This is not LuaTeX!")
    local tex = assert(tex)
    local font = assert(font)
    if not tex.isbox(hboxname) then
        return nil, string.format("Box register [%s] doesn’t exist", hboxname)
    end
    local bb_x1, bb_y1, bb_x2, bb_y2 = st.bb_x1, st.bb_y1, st.bb_x2, st.bb_y2
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
    return true, nil
end

-- PDF literal encoding functions

-- 1 <W: dim>; set line width
function PDFnative.append_001(st, bf, xt, w)
    local bp = st.bp -- 1bp (sp)
    bf[#bf + 1] = string.format("%0.6f w", w/bp)
end

-- 2 <enum: u8>; set line cap style
function PDFnative.append_002(st, bf, xt, cap)
    bf[#bf + 1] = string.format("%d J", cap)
end

-- 3 <enum: u8>; set line join style
function PDFnative.append_003(st, bf, xt, j)
    bf[#bf + 1] = string.format("%d j", j)
end

-- 5 dash_pattern
function PDFnative.append_005(st, bf, xt, phase, dash_array)
    local bp = st.bp -- conversion factor bp -> sp
    local t = {}
    for _, d in ipairs(dash_array) do
        t[#t + 1] = string.format("%0.6f", d/bp)
    end
    bf[#bf + 1] = string.format("[%s] %0.6f d",table.concat(t, " "), phase/bp)
end

-- 6 reset_pattern
function PDFnative.append_006(st, bf, xt)
    bf[#bf + 1] = string.format("[] 0 d")
end

-- draw an horizontal line
-- 33 <x1: DIM> <x2: DIM> <y: DIM>
function PDFnative.append_033(st, bf, xt, x1, x2, y)
    local bp = st.bp -- conversion factor bp -> sp
    bf[#bf + 1] = string.format("%0.6f %0.6f m", x1/bp, y/bp)
    bf[#bf + 1] = string.format("%0.6f %0.6f l", x2/bp, y/bp)
    bf[#bf + 1] = "S" -- stroke
end

-- vline
-- draw a vertical line
-- 34 <y1: DIM> <y2: DIM> <x: DIM>
function PDFnative.append_034(st, bf, xt, y1, y2, x)
    local bp = st.bp -- conversion factor bp -> sp
    bf[#bf + 1] = string.format("%0.6f %0.6f m", x/bp, y1/bp)
    bf[#bf + 1] = string.format("%0.6f %0.6f l", x/bp, y2/bp)
    bf[#bf + 1] = "S" -- stroke
end

-- Vbar
-- draw a group of vertical lines
-- 36 <y1: DIM> <y2: DIM> <b: UINT> <x1: DIM> <t1: DIM> ...
function PDFnative.append_036_bar(st, bf, xt, x, w, y1, y2)
    local bp = st.bp -- conversion factor bp -> sp
    local fmt = "%0.6f %0.6f %0.6f %0.6f re"
    local x1 = x - w/2
    local h = y2 - y1
    -- pdf literal insertion <x y w h re>
    bf[#bf + 1] = string.format(fmt, x1/bp, y1/bp, w/bp, h/bp)
end
function PDFnative.append_036_stop(st, bf, xt, nbar, y1, y2)
    bf[#bf + 1] = "f" -- fill
    bf[#bf + 1] = "S" -- stroke
end

-- Polyline
-- draw a polyline
-- 38 <n> <x1: DIM> <y1: DIM> ... <xn: DIM> <yn: DIM>
function PDFnative.append_038_start(st, bf, xt, n, x1, y1)
    local bp = st.bp -- conversion factor bp -> sp
    bf[#bf + 1] = string.format("%0.6f %0.6f m", x1/bp, y1/bp)
end
function PDFnative.append_038_point(st, bf, xt, x, y)
    local bp = st.bp -- conversion factor bp -> sp
    bf[#bf + 1] = string.format("%0.6f %0.6f l", x/bp, y/bp)
end
function PDFnative.append_038_stop(st, bf, xt)
    bf[#bf + 1] = "S" -- stroke
end

-- draw a rectangle
-- 48 <x1: DIM> <y1: DIM> <x2: DIM> <y2: DIM>
function PDFnative.append_048(st, bf, xt, x1, y1, x2, y2)
    local w = x2 - x1 -- rectangle width
    assert(w > 0)
    local h = y2 - y1 -- rectangle height
    assert(h > 0)
    local bp = st.bp -- conversion factor
    local fmt = "%0.6f %0.6f %0.6f %0.6f re S"
    -- pdf literal string <x y w h re>
    bf[#bf + 1] = string.format(fmt, x1/bp, y1/bp, w/bp, h/bp)
end

-- 130 <text> Text with several glyphs
-- 130 <ax: FLOAT> <ay: FLOAT> <xpos: DIM> <ypos: DIM> <c: CHARS>
function PDFnative.append_130_char(st, bf, xt, c)
    local head, last = st.head, st.last
    head, last = append_glyph(head, last, c)
    st.head = head
    st.last = last
end
-- return bounding box of the text object without deep
function PDFnative.append_130_stop(st, bf, xt, xpos, ypos, ax, ay)
    local head = assert(st.head)
    st.head = nil -- reset temporary reference
    st.last = nil
    local hbox = node.hpack(head)
    local w, h, d = node.dimensions(hbox)
    local x1 = xpos - ax*w -- text position
    local y1; if ay > 0 then
        y1 = ypos - h*ay
    else
        y1 = ypos - d*ay
    end
    xt[#xt + 1] = {hbox, x1, y1 - d, w, h}
    return x1, y1, x1 + w, y1 + h
end

-- 131 <text_xspaced>, Text with glyphs equally spaced on its vertical axis
-- 131 <x1: DIM> <xgap: DIM> <ay: FLOAT> <ypos: DIM> <c: CHARS>
function PDFnative.append_131_char(st, bf, xt, c, xgap)
    local head, last, prec_cw = st.head, st.last, st.cw
    local cw
    if prec_cw then
        local g = newglyph(c)
        cw = g.width
        local isp = xgap - (cw + prec_cw)/2
        local s = newglue(isp)
        head, last = node.insert_after(head, last, s)
        head, last = node.insert_after(head, last, g)
    else -- first char
        head, last, cw = append_glyph(head, last, c)
        st.x_hbox = cw/2
    end
    st.cw = cw
    st.head = head
    st.last = last
end
function PDFnative.append_131_stop(st, bf, xt, x1, xgap, ypos, ay) --> bb
    local head = assert(st.head)
    st.head = nil -- reset temporary reference
    st.last = nil
    st.cw = nil
    local hbox = node.hpack(head)
    local w, h, d = node.dimensions(hbox)
    local bx1 = x1 - st.x_hbox
    st.x_hbox = nil -- reset temporary references
    local y1; if ay > 0 then
        y1 = ypos - h*ay
    else
        y1 = ypos - d*ay
    end
    xt[#xt + 1] = {hbox, bx1, y1 - d, w, h}
    return bx1, y1, bx1 + w, y1 + h
end

-- 132 <text_xwidth> Glyphs equally spaced on vertical axis between two x coordinates
-- 132 <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
function PDFnative.append_132_char(st, bf, xt, c)
    local head, last = st.head, st.last
    if head then
        local g = newglyph(c)
        local s = newglue(1)
        head, last = node.insert_after(head, last, s)
        head, last = node.insert_after(head, last, g)
        st.char_counter = st.char_counter + 1
    else -- first char
        head, last, cw = append_glyph(head, last, c)
        st.cw = cw
        st.char_counter = 1
    end
    st.head = head
    st.last = last
end
function PDFnative.append_132_stop(st, bf, xt, x1, x2, ypos, ay) --> p1, p2
    local head, last = st.head, st.last
    st.head = nil -- reset temporary registry
    st.last = nil
    local w_1 = st.cw
    st.cw = nil
    local i = st.char_counter
    st.char_counter = nil
    local w_n = last.width
    local xgap = (x2 - x1 - (w_1 + w_n)/2)/(i - 1)
    local c_curr = head
    for _ = 1, i - 1 do
        local g = c_curr.next
        local c_next = g.next
        local w_2
        w_1, w_2 = c_curr.width, c_next.width
        g.width = xgap - (w_1 + w_2)/2
        c_curr = c_next
    end
    local hbox = node.hpack(head)
    local w, h, d = node.dimensions(hbox)
    local y; if ay > 0 then
        y = ypos - h*ay
    else
        y = ypos - d*ay
    end
    xt[#xt + 1] = {hbox, x1, y - d, w, h}
    return x1, y, x2, y + h
end

return PDFnative
