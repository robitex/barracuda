--
-- ga Intermediate Graphic Language for barcode drawing
-- SVG driver for the ga graphic stream
-- Copyright (C) 2019-2022 Roberto Giacomelli
--
-- All dimension in the ga stream are scaled point (sp)
-- 1 pt = 65536 sp

-- class for drawing elementary geometric elements
local SVG = {_drvname = "SVG"}
SVG.ext = "svg" -- file extension
SVG.buf_sep = nil -- separation string for buffer concat

function SVG.init_buffer(st) --> buffer, text buffer
    local bf = {
        '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n',
        '<!-- Created with Barracuda package (https://github.com/robitex/barracuda) -->\n',
        '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"\n',
        '  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n',
        '<svg xmlns="http://www.w3.org/2000/svg"\n',
        '  version="1.1"\n',
        '  width="%0.6fmm" height="%0.6fmm"\n', -- line 7
        '  viewBox="%0.6f %0.6f %0.6f %0.6f"\n', -- line 8
        '>\n',
    }
    -- additions for SVG driver to 'state'
    st.ident_lvl = 1 -- identation level
    st.char_buf = nil -- character buffer
    local mm = st.mm
    st.h_char = 2.1 * mm -- char height (mm)
    st.w_char = st.h_char / 1.303 -- average char width (mm)
    st.d_char = st.h_char / 3.7 -- char deep (mm)
    return bf, {}
end

function SVG.close_buffer(st, bf, xt)
    bf[#bf + 1] = '</svg>\n' -- close svg xml element
    bf[#bf + 1] = '\n' -- a last empty line
    local mm = st.mm
    local x1, y1, x2, y2 = st.bb_x1 or 0, st.bb_y1 or 0, st.bb_x2 or 0, st.bb_y2 or 0
    local w = (x2 - x1)/mm
    local h = (y2 - y1)/mm
    local fmt_wh = bf[7]
    bf[7] = string.format(fmt_wh, w, h) -- line 7
    local x, y = x1/mm, -y2/mm
    local fmt_vw = bf[8]
    bf[8] = string.format(fmt_vw, x, y, w, h)
end

-- SVG encoding functions

-- 1 <W: dim>; set line width
function SVG.append_001(st, bf, xt, w) -- nothing to do
end

-- 2 <enum: u8>; set line cap style
function SVG.append_002(st, bf, xt, cap) -- nothing to do
end

-- 3 <enum: u8>; set line join style
function SVG.append_003(st, bf, xt, j) -- nothing to do
end

-- 5 <dash_pattern>
function SVG.append_005(st, bf, xt) -- nothing to do
end

-- 6 <reset_pattern>
function SVG.append_006(st, bf, xt) -- nothing to do
end

-- draw an horizontal line <hline> opcode
-- 33 <x1: DIM> <x2: DIM> <y: DIM>
function SVG.append_033(st, bf, xt, x1, x2, y)
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl) -- a couple of spaces as indentation
    local mm = st.mm -- conversion ratio sp -> bp
    bf[#bf + 1] = string.format( -- <path> element
        '%s<path d="M%0.6f %0.6fH %0.6f"\n', ident, x1/mm, -y/mm, x2/mm
    )
    local lw = st.linewidth
    bf[#bf + 1] = string.format(
        '%s  stroke="black" stroke-width="%0.6f"\n', ident, lw/mm
    )
    local dash = st.dashpattern
    if dash then
        local t = {}
        for _, d in ipairs(dash) do
            t[#t + 1] = string.format("%0.6f", d/mm)
        end
        bf[#bf + 1] = string.format(
            '%s  stroke-dasharray="%s"\n', ident, table.concat(t, " ")
        )
        local phase = st.dashphase
        assert(phase >= 0)
        if phase > 0 then
            bf[#bf + 1] = string.format(
                '%s  stroke-dashoffset="%0.6f"\n', ident, phase/mm
            )
        end
    end
    bf[#bf + 1] = ident..'/>\n'
end

-- Vertical line: 34 <y1: DIM> <y2: DIM> <x: DIM>
function SVG.append_034(st, bf, xt, y1, y2, x)
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl) -- a couple of spaces as indentation
    local mm = st.mm -- conversion ratio sp -> mm
    bf[#bf + 1] = string.format( -- <path> element
        '%s<path d="M%0.6f %0.6f V%0.6f"\n', ident, x/mm, -y2/mm, -y1/mm
    )
    local lw = st.linewidth
    bf[#bf + 1] = string.format(
        '%s  stroke="black" stroke-width="%0.6f"\n', ident, lw/mm
    )
    local dash = st.dashpattern
    if dash then
        local t = {}
        for _, d in ipairs(dash) do
            t[#t + 1] = string.format("%0.6f", d/mm)
        end
        bf[#bf + 1] = string.format(
            '%s  stroke-dasharray="%s"\n', ident, table.concat(t, " ")
        )
        local phase = st.dashphase
        assert(phase >= 0)
        if phase > 0 then
            bf[#bf + 1] = string.format(
                '%s  stroke-dashoffset="%0.6f"\n', ident, phase/mm
            )
        end
    end
    bf[#bf + 1] = ident..'/>\n'
end

-- Vbar
-- draw a group of vertical lines
-- 36 <y1: DIM> <y2: DIM> <b: UINT> <x1: DIM> <t1: DIM> ...
function SVG.append_036_start(st, bf, xt, nbar, y1, y2)
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    bf[#bf + 1] = ident..'<g stroke="black">\n' -- open a group
    st.ident_lvl = lvl + 1
end
function SVG.append_036_bar(st, bf, xt, x, w, y1, y2)
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local mm = st.mm -- conversion factor mm -> sp
    bf[#bf + 1] = string.format(
        '%s<path d="M%0.6f %0.6fV%0.6f" style="stroke-width:%0.6f"/>\n',
        ident, x/mm, -y2/mm, -y1/mm, w/mm
    )
end
function SVG.append_036_stop(st, bf, xt, nbar, y1, y2)
    st.ident_lvl = st.ident_lvl - 1
    local ident = string.rep("  ", st.ident_lvl)
    bf[#bf + 1] = ident..'</g>\n' -- end group
end

-- Polyline
-- draw a polyline
-- 38 <n> <x1: DIM> <y1: DIM> ... <xn: DIM> <yn: DIM>
function SVG.append_038_start(st, bf, xt, n, x1, y1)
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local mm = st.mm -- conversion factor mm -> sp
    local style = string.format(
        '%s<g stroke="black" stroke-width="%0.6f" fill="none"',
        ident, st.linewidth/mm
    )
    local dash = st.dashpattern
    if dash then
        local t = {}
        for _, d in ipairs(dash) do
            t[#t + 1] = string.format("%0.6f", d/mm)
        end
        style = string.format(
            '%s stroke-dasharray="%s"', style, table.concat(t, " ")
        )
        local phase = st.dashphase
        assert(phase >= 0)
        if phase > 0 then
            style = string.format(
                '%s stroke-dashoffset="%0.6f"', style, phase/mm
            )
        end
    end
    bf[#bf + 1] = style..'>\n'
    ident = ident .. "  "
    bf[#bf + 1] = string.format('%s<polyline points="%0.6f,%0.6f',
        ident, x1/mm, -y1/mm
    )
    st.ident_lvl = lvl + 1
end
function SVG.append_038_point(st, bf, xt, x, y)
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local mm = st.mm -- conversion factor mm -> sp
    bf[#bf + 1] = string.format('\n%s%0.6f,%0.6f', ident, x/mm, -y/mm)
end
function SVG.append_038_stop(st, bf, xt)
    bf[#bf + 1] = '"/>\n' -- closing tag
    local lvl = st.ident_lvl - 1
    local ident = string.rep("  ", lvl)
    st.ident_lvl = lvl
    bf[#bf + 1] = ident..'</g>\n' -- close the group
end

-- draw a rectangle
-- 48 <x1: DIM> <y1: DIM> <x2: DIM> <y2: DIM>
function SVG.append_048(st, bf, xt, x1, y1, x2, y2)
    local w = x2 - x1 -- rectangle width
    assert(w > 0)
    local h = y2 - y1 -- rectangle height
    assert(h > 0)
    local mm = st.mm -- conversion factor mm -> sp
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local fmt = '%s<rect x="%0.6f" y="%0.6f" width="%0.6f" height="%0.6f"'
    bf[#bf + 1] = string.format(fmt, ident, x1/mm, -y2/mm, w/mm, h/mm)
    local lw = st.linewidth
    bf[#bf + 1] = string.format(
        '%s  fill="none" stroke="black" stroke-width="%0.6f"\n', ident, lw/mm
    )
    local dash = st.dashpattern
    if dash then
        local t = {}
        for _, d in ipairs(dash) do
            t[#t + 1] = string.format("%0.6f", d/mm)
        end
        bf[#bf + 1] = string.format(
            '%s  stroke-dasharray="%s"\n', ident, table.concat(t, " ")
        )
        local phase = st.dashphase
        assert(phase >= 0)
        if phase > 0 then
            bf[#bf + 1] = string.format(
                '%s  stroke-dashoffset="%0.6f"\n', ident, phase/mm
            )
        end
    end
    bf[#bf + 1] = ident..'/>\n'
end

-- Text
-- 130 <text> Text with several glyphs
-- 130 <ax: FLOAT> <ay: FLOAT> <xpos: DIM> <ypos: DIM> <c: CHARS>
function SVG.append_130_char(st, bf, xt, c)
    local ch = string.char(c)
    if not st.char_buf then
        st.char_buf = {ch}
    else
        local chars = st.char_buf
        chars[#chars + 1] = ch
    end
end
function SVG.append_130_stop(st, bf, xt, xpos, ypos, ax, ay) --> p1, p2
    local c = st.char_buf
    st.char_buf = nil
    local txt = table.concat(c)
    local w = st.w_char * #c -- approx dim
    local h = st.h_char
    local d = st.d_char
    local anchor = ""
    local x1 = xpos
    local bx1 = xpos
    if ax == 0 then -- start (default)
    elseif ax == 0.5 then -- middle
        anchor = ' text-anchor="middle"'
        bx1 = bx1 - w/2
    elseif ax == 1 then -- end
        anchor = ' text-anchor="end"'
        bx1 = bx1 - w
    else
        x1 = x1 - ax*w
        bx1 = x1
    end
    local y1 = ypos
    if ay > 0 then
        y1 = y1 - h*ay
    else
        y1 = y1 - d*ay
    end
    local fs = st.h_char * 1.37 -- sp
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local mm = st.mm
    bf[#bf + 1] = string.format(
        '%s<text x="%0.6f" y="%0.6f" font-family="Verdana" font-size="%0.6f"%s>\n',
        ident, x1/mm, -y1/mm, fs/mm, anchor
    )
    bf[#bf + 1] = ident..txt
    bf[#bf + 1] = ident..'</text>\n'
    return bx1, y1, bx1 + w, y1 + h
end

-- 131 <text_xspaced>, Text with glyphs equally spaced on its vertical axis
-- 131 <x1: DIM> <xgap: DIM> <ay: FLOAT> <ypos: DIM> <c: CHARS>
function SVG.append_131_char(st, bf, xt, c, xgap)
    local ch = string.char(c)
    if not st.char_buf then
        st.char_buf = {ch}
    else
        local chars = st.char_buf
        chars[#chars + 1] = ch
    end
end
function SVG.append_131_stop(st, bf, xt, x1, xgap, ypos, ay) --> p1, p2
    local chars = st.char_buf
    st.char_buf = nil
    local n = #chars
    local h = st.h_char -- height
    local d = st.d_char -- deep
    local hw = st.w_char/2 -- sp half width
    local y1 = ypos
    if ay > 0 then
        y1 = y1 - h*ay
    else
        y1 = y1 - d*ay
    end
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local fs = st.h_char * 1.37 -- (sp) font-size -> inter baselines distance
    local mm = st.mm
    bf[#bf + 1] = string.format(
        '%s<text y="%0.6f" font-family="Verdana" font-size="%0.6f" text-anchor="middle">\n',
        ident, -y1/mm, fs/mm
    )
    local x = x1
    for _, c in ipairs(chars) do
        bf[#bf + 1] = string.format('%s<tspan x="%0.6f">%s</tspan>\n',
            ident, x/mm, c
        )
        x = x + xgap
    end
    bf[#bf + 1] = ident..'</text>\n'
    local x2 = x1 + (n - 1)*xgap -- sp
    return x1 - hw, y1, x2 + hw, y1 + h -- text group bounding box
end

-- 132 <text_xwidth> Glyphs equally spaced on vertical axis between two x coordinates
-- 132 <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
function SVG.append_132_char(st, bf, xt, c, xgap)
    local ch = string.char(c)
    if not st.char_buf then
        st.char_buf = {ch}
    else
        local chars = st.char_buf
        chars[#chars + 1] = ch
    end
end
function SVG.append_132_stop(st, bf, xt, x1, x2, ypos, ay) --> p1, p2
    local chars = st.char_buf; st.char_buf = nil
    local n = #chars
    local h = st.h_char -- height (approx)
    local d = st.d_char -- deep (approx)
    local cw = st.w_char -- (sp) char width (approx)
    local xgap = (x2 - x1 - cw)/(n - 1)
    local y1 = ypos
    if ay > 0 then
        y1 = y1 - h*ay
    else
        y1 = y1 - d*ay
    end
    local lvl = st.ident_lvl
    local ident = string.rep("  ", lvl)
    local fs = st.h_char * 1.37 -- font-size -> inter baselines distance
    local mm = st.mm
    bf[#bf + 1] = string.format(
        '%s<text y="%0.6f" font-family="Verdana" font-size="%0.6f" text-anchor="middle">\n',
        ident, -y1/mm, fs/mm
    )
    local x = x1 + cw/2
    for _, c in ipairs(chars) do
        bf[#bf + 1] = string.format('%s<tspan x="%0.6f">%s</tspan>\n',
            ident, x/mm, c
        )
        x = x + xgap
    end
    bf[#bf + 1] = ident..'</text>\n'
    return x1, y1, x2, y1 + h -- text group bounding box
end

return SVG
