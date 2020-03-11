-- test SVG driver output

local barracuda = require "barracuda"
local barcode = barracuda:barcode()
local driver = barracuda:get_driver()

local opt = {module = 15 * 0.0254 * 186467, height = 12 * 186467}

local c39, err = barcode:new_encoder("code39", nil, opt)
assert(not err, err)

local symbol, err = c39:from_string("ABC000Z")
assert(not err, err)

local canvas = barracuda:new_canvas()
symbol:draw(canvas)

driver:save("svg", canvas, "test-code39")