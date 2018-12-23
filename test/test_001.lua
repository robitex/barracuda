-- Copyright (C) 2018 Roberto Giacomelli

local barracuda = require "barracuda"

local c39builder, err = barracuda:new_encoder("code39")
assert(not err, err)

print(c39builder._NAME)
print(c39builder._VERSION)

local info = c39_default:info()

print("name", info.name)
print("description", info.description)
for k, tp in ipairs(info.param) do
    print(k, tp.name, tp.value)
end

local symb = c39_default:from_chars({"1", "2", "3"})

print()
for _, c in ipairs(symb.code) do
    print(c)
end

local canvas = barracuda:new_canvas()

symb:append_graphic(canvas)

-- native driver
local drv, err = barracuda:load_driver("native")
assert(not err, err)

for _, code in ipairs(canvas._data) do print(code) end


