-- Copyright (C) 2018 Roberto Giacomelli

local barracuda = require "barracuda"
local barcode = barracuda:get_barcode_class()
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

local symb = c128:from_chars({"1", "2", "3"})
print("Symbol char list:")
for _, c in ipairs(symb.code) do
    print(c)
end

local canvas = barracuda:new_canvas()

local _, err = symb:append_ga(canvas)
assert(not err, err)

-- native driver loading
local drv, err = barracuda:load_driver("native")
assert(not err, err)

for _, code in ipairs(canvas._data) do print(code) end

