--
-- ga Intermediate Graphic Language for barcode drawing
-- All dimension must be in scaled point (sp)
--
-- ga Driver LuaTeX native implementation (node+pdfliteral)

-- class for drawing elementary geometric elements
local PDFnative = {
    _VERSION     = "PDFnative v0.0.1",
    _NAME        = "PDFnative",
    _DESCRIPTION = "a LuaTeX native pdfliteral driver for ga graphic stream",
}

-- operation functions
-- operation_v001 corresponds to the version 1 of ga graphic assembler spec
-- this table indexed every opcode to a function that takes these arguments:
-- st: state
-- pc: program counter
-- ga: ga stream
-- bf: the output buffer
-- and return the updated program counter pointed to the next operation
PDFnative.operation_v001 = {

    [30] = function (st, pc, ga, bf) -- start_bbox_group
        assert(st.bb_on)
        st.bb_on = false
        return pc
    end,
    [31] = function (st, pc, ga, bf) -- end_bbox_group
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

    [36] = function(st, pc, ga, bf) -- vbar
        -- we have less memory consumption if inserting a bar as a rectangle
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
            local w  = ga[i+1]
            local x1 = ga[i] - w/2
            -- pdf literal insertion <x y w h re>
            bf[#bf + 1] = string.format(fmt, x1/bp, y1/bp, w/bp)
            -- check the bounding box limit only if the state flag is true
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
}


-- drawing function
local function hboxcreate(hboxname, buf, bb_x1, bb_y1, bb_x2, bb_y2)
    assert(
        tex.isbox(hboxname),
        string.format("Box register [%s] doesn’t exist", hboxname)
    )
    -- node whatsit pdfliteral
    local npdf = node.new("whatsit", "pdf_literal")
    npdf.mode = 0
    npdf.data = table.concat(buf, "\n")
    -- vboxing, vertical correction
    local vpdf = node.vpack(npdf)
    vpdf.height = -bb_y1
    -- glue, for horizontal correction
    local ng = node.new("glue")
    ng.width = -bb_x1

    local head = node.insert_after(ng, ng, vpdf)
    -- hboxing
    local hbox = node.hpack(head)
    hbox.width  = bb_x2 - bb_x1
    hbox.height = bb_y2 - bb_y1
    tex.box[hboxname] = hbox
end

-- validate a stream
function PDFnative.ga_check(ga) --> bool, err
end

-- stream processing and hbox node building
function PDFnative:ga_to_hbox(ga, hboxname) --> nil
    local op_fn = self.operation_v001
    local bf = {"q"} -- stack saving
    local st = { -- process state
        bb_on = true, -- bounding box checking activation
        bb_x1 = nil,  -- bounding box coordinates in scaled point
        bb_y1 = nil,
        bb_x2 = nil,
        bb_y2 = nil,
    }
    local pc = 1 -- program counter
    local data = ga._data
    while data[pc] do -- stream processing
        local opcode = data[pc]
        local fn = op_fn[opcode]
        pc = fn(st, pc + 1, data, bf)
    end
    bf[#bf + 1] = "Q" -- stack restoring
    hboxcreate(hboxname, bf, st.bb_x1, st.bb_y1, st.bb_x2, st.bb_y2)
end


return PDFnative

--[[


    -- node whatsit pdfliteral
    local npdf = node.new("whatsit", "pdf_literal")
    npdf.mode = 0
    npdf.data = table.concat(self.buffer, "\n")
    local nvpdf = node.vpack(npdf)
    nvpdf.height = -self.bbox[2]
    local gx = newglue(-self.bbox[1])
    local head, last = node.insert_after(gx, gx, nvpdf)
    -- text processing
    local xprev = 0.0
    for _, txt in ipairs(txtnodes) do
        local gy = newglue(txt[3] -txt[5] - self.bbox[2])
        local nvtxt = node.insert_after(txt[1], txt[1], gy)
        local vtxt = node.vpack(nvtxt)
        local gx = newglue(txt[2]-xprev)
        head, last = node.insert_after(head, last, gx)
        head, last = node.insert_after(head, last, vtxt)
        xprev = txt[2] + txt[4]
    end
    local hbox = node.hpack(head)
    hbox.width  = self.bbox[3] - self.bbox[1]
    hbox.height = self.bbox[4] - self.bbox[2]
    node.write(hbox)

    --
    --
    --
    --
    --
    --
    --
    --
    --
    --
    --
    
    -- insert in the buffer a hard copy information about the istruction
    -- to draw a text. All lenghts are in sp
    -- bounding boxing must be re-adjusted at the moment of drawing
    function PDFliteralDriver:add_text(geotext)
        local t = self.text
        t[#t+1] = geotext
    end
    
    -- text utility functions
    
    local function newglyph(c)
        local n = node.new("glyph")
        n.char = c
        n.font = font.current()
        return n
    end
    
    local function newglue(w)
        local n = node.new("glue")
        n.width = w
        return n
    end
    
    local function hpack_text(char_array)
        local h, l
        for _, c in ipairs(char_array) do
            if c == " " then
                h, l = node.insert_after(h, l, newglue(tex.sp "3.5pt"))
            else
                h, l = node.insert_after(h, l, newglyph(c))
            end
        end
        return node.hpack(h)
    end
    
    local function hpack_text_list( tlist )
        local h, l
        local w
        local x, xp, xs
        local isglue = false
        for _, elem in ipairs(tlist) do
            if elem.glue then
                isglue = true
                x  = elem.glue
                xp = elem.axprec
                xs = elem.axsucc
            else
                if isglue then
                    local hbox = hpack_text(elem)
                    local ws = hbox.width
                    local g = x - w*(1 - xp) - ws*xs
                    h, l = node.insert_after(h, l, newglue(g))
                    h, l = node.insert_after(h, l, hbox)
                    isglue = false
                    w = ws
                else
                    local hbox = hpack_text(elem)
                    w = hbox.width
                    h, l = node.insert_after(h, l, hbox)
                end
            end
        end
        return node.hpack(h)
    end
    
    -- it builds the node text object and checks the bounding box
    -- process_text() return the array {{nt, tx, ty, w, d}}
    function PDFliteralDriver:process_text()
        local tt = self.text
        local res = {}
        for _, txt in ipairs(tt) do
            local ntext = hpack_text_list(txt.text_list)
            local xpos, ax = txt.xpos, txt.ax
            local w, d, h = ntext.width, ntext.depth, ntext.height
            local tx = xpos - ax*w -- text x, y position
            local ty, ay = txt.ypos, txt.ay
            if ay > 0 then
                ty = ty - ntext.height*ay
            else
                ty = ty - d*ay
            end
            
            -- bb check
            self:bounding_box(tx, ty - d, tx + w, ty + h)
            res[#res+1] = {ntext, tx, ty, w, d}
        end
        return res
    end
    
    
    
    --]]
    
