--
-- ga Intermediate Graphic Language for barcode drawing
-- Copyright (C) 2020 Roberto Giacomelli
--
-- Basic driver interface
-- drawing elementary vector shape
-- All dimensions are in scaled point (sp)

local Driver = {
    _VERSION     = "Driver v0.0.9",
    _NAME        = "Driver",
    _DESCRIPTION = "Driver for ga graphic assembler stream",
}

Driver.__index = Driver
Driver._drv_instance = {} -- driver instances repository

-- driver_type/submodule name
Driver._drv_available_drv = { -- lowercase keys please
    native  = "lib-driver.brcd-drv-pdfliteral", -- only LuaTeX driver
    svg  = "lib-driver.brcd-drv-svg",
}

function Driver:_get_driver(id_drv) --> object, err
    if type(id_drv) ~= "string" then
        return nil, "[ArgErr] 'id_drv' is not a string"
    end
    if not self._drv_available_drv[id_drv] then
        return nil, "[ArgErr] driver '"..id_drv.."' not found"
    end
    local t_drv = self._drv_instance
    if t_drv[id_drv] then -- is the repo already loaded?
        return t_drv[id_drv], nil
    else -- loading driver
        local module = self._drv_available_drv[id_drv]
        local channel = require(module)
        t_drv[id_drv] = channel
        return channel, nil
    end
end

function Driver:_new_state() --> a new state
    return {
        line_width = 65781.76, -- line width 1bp (in scaled point sp)
        line_cap = 0, -- line cap style
        line_join = 0, -- line join style
        gtext = false, -- text group off
        bb_on = true, -- bounding box checking activation
        bb_x1 = nil, -- bounding box coordinates in sp (nil means no data)
        bb_y1 = nil,
        bb_x2 = nil,
        bb_y2 = nil,
        mm = 186467.98110236, -- conversion factor sp -> mm (millimeter)
        bp = 65781.76, -- conversion factor sp -> bp (big point)
    }
end

function Driver:_ga_process(drv, ga, st, bf, xt)
    local op_fn = self._opcode_v001
    local pc = 1 -- program counter
    local data = ga._data
    while data[pc] do -- stream processing
        local opcode = data[pc]
        local fn = assert(op_fn[opcode], "[InternalErr] unimpl opcode ".. opcode)
        pc = fn(drv, st, pc + 1, data, bf, xt)
    end
end

-- save graphic data in an external file with the 'id_drv' format
-- id_drv: specific driver output
-- ga: ga object
-- filename: file name
-- ext: file extension (optional)
function Driver:save(id_drv, ga, filename, ext) --> ok, err
    -- retrive the output library
    local drv, err = self:_get_driver(id_drv)
    if err then return false, err end
    -- init
    local state = self:_new_state()
    local buf, txt_buf = drv.init_buffer(state) -- a new buffer and text_buffer
    -- processing
    self:_ga_process(drv, ga, state, buf, txt_buf)
    -- buffer finalizing
    drv.close_buffer(state, buf, txt_buf) -- finalize the istruction
    -- file saving
    local sep = drv.buf_sep
    ext = ext or drv.ext
    local fn = io.open(filename.."."..ext, "w") -- output the file
    fn:write(table.concat(buf, sep))  -- concat the buffer
    fn:close()
    return true, nil
end

-- insert a ga drawing in a TeX box
-- PDFnative only function
function Driver:ga_to_hbox(ga, boxname) --> ok, err
    -- retrive the output library
    local id_drv = "native"
    local drv, err = self:_get_driver(id_drv)
    if err then return false, err end
    -- init process
    local state = self:_new_state()
    local buf, txt_buf = drv.init_buffer(state) -- a new buffer and text_buffer
    -- processing
    self:_ga_process(drv, ga, state, buf, txt_buf)
    -- finalizing
    drv.close_buffer(state, buf, txt_buf) -- finalize the istruction sequence
    -- build hbox
    local ok, err = drv.hboxcreate(boxname, state, buf, txt_buf)
    return ok, err
end


-- operational functions
-- _op_v001 corresponds to the version 1 of ga graphic assembler specification.
-- The table indexes every opcode to a function that takes these arguments and
-- return the updated program counter pointed to the next operation:
-- fn: format specific driver library
-- st: state
-- pc: program counter
-- ga: read only ga stream
-- bf: the output buffer
-- xt: the output text object buffer
Driver._opcode_v001 = {
    [1] = function (drv, st, pc, ga, bf, xt) -- 1 <W: dim>; set line width
        local w = ga[pc]
        st.line_width = w
        if not drv.append_001 then
            error("[InternalErr] unimplemented opcode 1 for "..drv._NAME)
        end
        drv.append_001(st, bf, xt, w)
        return pc + 1
    end,
    [2] = function (drv, st, pc, ga, bf, xt) -- 2 <e: u8>; set line cap style
        local style = ga[pc]
        st.line_cap = style
        if not drv.append_002 then
            error("[InternalErr] unimplemented opcode 2 for "..drv._NAME)
        end
        drv.append_002(st, bf, xt, style)
        return pc + 1
    end,
    [3] = function (drv, st, pc, ga, bf, xt) -- 3 <e: u8>; set line join style
        local join = ga[pc]
        if not drv.append_003 then
            error("[InternalErr] unimplemented opcode 3 for "..drv._NAME)
        end
        drv.append_003(st, bf, xt, join)
        return pc + 1
    end,
    [30] = function (drv, st, pc, ga, bf, xt) -- start_bbox_group
        assert(st.bb_on)
        st.bb_on = false
        return pc
    end,
    [31] = function (drv, st, pc, ga, bf, xt) -- end_bbox_group
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
    -- draw an horizontal line
    -- 33 <x1: DIM> <x2: DIM> <y: DIM>
    [33] = function (drv, st, pc, ga, bf, xt)
        local x1 = ga[pc]; pc = pc + 1
        local x2 = ga[pc]; pc = pc + 1
        local  y = ga[pc]; pc = pc + 1
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
        if not drv.append_033 then
            error("[InternalErr] unimplemented opcode 33 for "..drv._NAME)
        end
        drv.append_033(st, bf, xt, x1, x2, y)
        return pc
    end,
    -- draw a vertical line
    [34] = function (drv, st, pc, ga, bf, xt) -- 34 <y1: DIM> <y2: DIM> <x: DIM>
        local y1 = ga[pc]; pc = pc + 1
        local y2 = ga[pc]; pc = pc + 1
        local x  = ga[pc]; pc = pc + 1
        if st.bb_on then -- eventually update the figure bounding box
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
        if not drv.append_034 then
            error("[InternalErr] unimplemented opcode 34 for "..drv._NAME)
        end
        drv.append_034(st, bf, xt, y1, y2, x)
        return pc
    end,
    -- draw a group of vertical lines (vbar)
    -- 36 <y1: DIM> <y2: DIM> <b: UINT> <x1: DIM> <t1: DIM>
    [36] = function(drv, st, pc, ga, bf, xt) -- vbar
        local y1   = ga[pc]; pc = pc + 1
        local y2   = ga[pc]; pc = pc + 1
        local nbar = ga[pc]; pc = pc + 1
        assert(nbar > 0)
        local h = y2 - y1 -- height common to every rectangle
        assert(h > 0)
        local pc_next = pc + 2 * nbar
        if drv.append_036_start then
            drv.append_036_start(st, bf, xt, nbar, y1, y2)
        end
        local bx1, bx2
        for i = pc, pc_next - 1, 2 do -- reading coordinates <x axis> <width>
            local x = assert(ga[i], "[InternalErr] ga prematurely reached the end")
            local w = assert(ga[i+1], "[InternalErr] ga prematurely reached the end")
            drv.append_036_bar(st, bf, xt, x, w, y1, y2)
            -- check the bounding box only if the corresponding flag is true
            local x1 = x - w/2
            local x2 = x + w/2
            if st.bb_on then
                if bx1 == nil then
                    bx1 = x1
                    bx2 = x2
                else
                    if x1 < bx1 then bx1 = x1 end
                    if x2 > bx2 then bx2 = x2 end
                end
            end
        end
        if drv.append_036_stop then
            drv.append_036_stop(st, bf, xt, nbar, y1, y2)
        end
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
    [48] = function(drv, st, pc, ga, bf, xt)
        local x1   = ga[pc]; pc = pc + 1
        local y1   = ga[pc]; pc = pc + 1
        local x2   = ga[pc]; pc = pc + 1
        local y2   = ga[pc]; pc = pc + 1
        -- check the bounding box only if the flag is true
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
        if not drv.append_048 then
            error("[InternalErr] unimplemented opcode 48 for "..drv._NAME)
        end
        drv.append_048(st, bf, xt, x1, y1, x2, y2)
        return pc
    end,
    -- text
    [130] = function(drv, st, pc, ga, bf, xt) -- text: ax ay xpos ypos string
        local ax   = ga[pc]; pc = pc + 1
        local ay   = ga[pc]; pc = pc + 1
        local xpos = ga[pc]; pc = pc + 1
        local ypos = ga[pc]; pc = pc + 1
        assert(ga[pc] ~= 0, "[InternalErr] empty chars sequence")
        while ga[pc] ~= 0 do
            local c = ga[pc]; pc = pc + 1
            drv.append_130_char(st, bf, xt, c)
        end
        local x1, y1, x2, y2 = drv.append_130_stop(st, bf, xt, xpos, ypos, ax, ay)
        -- bounding box checking
        if st.bb_on then
            if st.bb_x1 == nil then
                st.bb_x1 = x1
                st.bb_x2 = x2
                st.bb_y1 = y1
                st.bb_y2 = y2
            else
                if x1 < st.bb_x1 then st.bb_x1 = x1 end
                if x2 > st.bb_x2 then st.bb_x2 = x2 end
                if y1 < st.bb_y1 then st.bb_y1 = y1 end
                if y2 > st.bb_y2 then st.bb_y2 = y2 end
            end
        end
        return pc + 1
    end,
    [131] = function(drv, st, pc, ga, bf, xt) -- text_xspaced x1 xgap ay ypos chars
        local x1   = ga[pc]; pc = pc + 1
        local xgap = ga[pc]; pc = pc + 1
        local ay   = ga[pc]; pc = pc + 1
        local ypos = ga[pc]; pc = pc + 1
        assert(ga[pc] ~= 0, "[InternalErr] empty chars sequence")
        while ga[pc] ~= 0 do
            local c = ga[pc]; pc = pc + 1
            drv.append_131_char(st, bf, xt, c, xgap)
        end
        local bx1, by1, bx2, by2 = drv.append_131_stop(st, bf, xt, x1, xgap, ypos, ay)
        -- bounding box checking
        if st.bb_on then -- eventually update bbox
            if st.bb_x1 == nil then
                st.bb_x1 = bx1
                st.bb_x2 = bx2
                st.bb_y1 = by1 -- no depth
                st.bb_y2 = by2
            else
                if bx1 < st.bb_x1 then st.bb_x1 = bx1 end
                if bx2 > st.bb_x2 then st.bb_x2 = bx2 end
                if by1 < st.bb_y1 then st.bb_y1 = by1 end
                if by2 > st.bb_y2 then st.bb_y2 = by2 end
            end
        end
        return pc + 1
    end,
    -- text_xwidth
    -- <ay: FLOAT> <x1: DIM> <x2: DIM> <y: DIM> <c: CHARS>
    [132] = function (drv, st, pc, ga, bf, xt)
        local ay = ga[pc]; pc = pc + 1 -- y anchor
        local x1 = ga[pc]; pc = pc + 1 -- left limit
        local x2 = ga[pc]; pc = pc + 1 -- right limit
        assert (x1 ~= x2, "[InternalErr] x coordinate are equal")
        assert (x1 < x2, "[InternalErr] not ordered x1, x2 limits")
        local ypos = ga[pc]; pc = pc + 1 -- y coordinate of anchor point
        assert(ga[pc] ~= 0, "[InternalErr] empty chars sequence")
        while ga[pc] ~= 0 do
            local c = ga[pc]; pc = pc + 1
            drv.append_132_char(st, bf, xt, c)
        end
        local bx1, by1, bx2, by2 = drv.append_132_stop(st, bf, xt, x1, x2, ypos, ay)
        -- bounding box checking
        if st.bb_on then -- eventually update bbox
            if st.bb_x1 == nil then
                st.bb_x1 = bx1
                st.bb_x2 = bx2
                st.bb_y1 = by1 -- no depth
                st.bb_y2 = by2
            else
                if bx1 < st.bb_x1 then st.bb_x1 = bx1 end
                if bx2 > st.bb_x2 then st.bb_x2 = bx2 end
                if by1 < st.bb_y1 then st.bb_y1 = by1 end
                if by2 > st.bb_y2 then st.bb_y2 = by2 end
            end
        end
        return pc + 1
    end,
}

return Driver

