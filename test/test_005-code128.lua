local barracuda = require "barracuda"

local c128, err = barracuda:load_builder("code128")
assert(not err, err)

print(c128._NAME)
print(c128._VERSION)

local c128_default, err = c128:new_encoder("default")
assert(not err, err)
local info = c128_default:info()
print("name", info.name)
print("description", info.description)
for k, tp in ipairs(info.param) do
    print(k, tp.name, tp.value)
end

local symb = c128_default:from_chars({"1", "2", "3"})

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



