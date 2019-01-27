-- Copyright (C) 2018 Roberto Giacomelli
-- test Code 39 encoder

local barracuda = require "barracuda"
local barcode = barracuda:get_barcode_class()

local c39, err = barcode:new_encoder("code39")
assert(not err, err)

print(c39._NAME)
print(c39._VERSION)

local info = c39:info()

print("encoder name = ", info.name)
print("description = ", info.description)

for k, tp in ipairs(info.param) do
    print(k, tp.name, tp.value)
end

local symb = c39:from_chars({"1", "2", "3"})

print("print internal representation of chars")
for _, c in ipairs(symb.code) do
    print(c)
end
print()

local canvas = barracuda:new_canvas()
symb:append_ga(canvas)

-- native driver
local drv, err = barracuda:load_driver("native")
assert(not err, err)

for _, code in ipairs(canvas._data) do print(code) end

