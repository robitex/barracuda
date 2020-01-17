-- Copyright (C) 2020 Roberto Giacomelli
-- test Code 39 encoder

local barracuda = require "barracuda"

for k, v in pairs(barracuda) do
    print(k,v)
end

local barcode = barracuda:barcode()

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

local symb = c39:from_string("123")

print("print internal representation of chars")
for _, c in ipairs(symb._code_data) do
    print(c)
end
print()

local canvas = barracuda:new_canvas()
symb:append_ga(canvas)

-- native driver
local drv = barracuda:get_driver()

for _, code in ipairs(canvas._data) do print(code) end
