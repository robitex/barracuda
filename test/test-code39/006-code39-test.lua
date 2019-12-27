
local cm = 1864679.8110236 -- sp

local barracuda = require "barracuda"
local c39, err = barracuda:barcode()
                          :new_encoder("code39")
assert(not err, err)
local err
local symbol
symbol, err = c39:from_string("ABCDEF12QJ31+")
assert(not err, err)

local ok, err = c39:set_param("text_vpos", "top")
assert(ok, err)

local canvas = barracuda:new_canvas()
symbol:append_ga(canvas)

local ok, err = symbol:set_param("text_hpos", "center")
assert(ok, err)
symbol:append_ga(canvas, 4.5*cm)

local ok, err = symbol:set_param("text_hpos", "right")
assert(ok, err)
symbol:append_ga(canvas, 9.0*cm)

local ok, err = c39:set_param("text_vpos", "bottom")
assert(ok, err)

local ok, err = symbol:set_param("text_hpos", "left")
symbol:append_ga(canvas, 0, -2.0*cm)

local ok, err = symbol:set_param("text_hpos", "center")
assert(ok, err)
symbol:append_ga(canvas, 4.5*cm, -2.0*cm)

local ok, err = symbol:set_param("text_hpos", "right")
assert(ok, err)
symbol:append_ga(canvas, 9.0*cm, -2.0*cm)

local drv = barracuda:get_driver()
drv:save("svg", canvas, "006-six")



