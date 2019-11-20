-- test SVG driver output

local barracuda = require "barracuda"
local driver = barracuda:get_driver()

local mm = 186467.9811 -- 1 mm in sp
local ga1 = { _data = { 1, 1*mm,
  34, 10*mm, 100*mm, 0*mm, -- vline, y1, y2, x
  34, 20*mm, 90*mm, 10*mm,
  34, 30*mm, 80*mm, 20*mm,
  34, 40*mm, 70*mm, 30*mm,
  34, 50*mm, 60*mm, 40*mm,
}}

driver:save("svg", ga1, "test-01")

local ga2 = { _data = {
    1, 5*mm,
  34, 0*mm, 50*mm, 2.5*mm,
  33, 0*mm, 50*mm, 40*mm,
}}

driver:save("svg", ga2, "test-02")





