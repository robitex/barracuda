-- Copyright (C) 2020 Roberto Giacomelli

local barracuda = require "barracuda"
local barcode = barracuda:barcode()
local c128, err = barcode:new_encoder("code128")
assert(not err, err)

print(c128._NAME)
print(c128._VERSION)

local info = c128:info()
print("encoder name = ", info.name)
print("description = ", info.description)
for k, tp in ipairs(info.param) do
    print(k, tp.name, tp.value)
end

local symb = c128:from_string("123")
print("Symbol char list:")
for _, c in ipairs(symb._code_data) do
    print(c)
end

local canvas = barracuda:new_canvas()

symb:append_ga(canvas)

-- driver library
local drv = barracuda:get_driver()
drv:save("svg", canvas, "c128-123")


