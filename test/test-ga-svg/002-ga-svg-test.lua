-- test SVG driver output

local barracuda = require "barracuda"
local barcode = barracuda:get_barcode_class()
local driver = barracuda:get_driver()

local c39, err = barcode:new_encoder("code39")
assert(not err, err)

local symbol, err = c39:from_string("ABC000Z", {text_enabled=false})
assert(not err, err)

local canvas = barracuda:new_canvas()
symbol:append_ga(canvas)
driver:save("svg", canvas, "test-code39")

