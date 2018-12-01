-- Welcome to the barracuda barcode library

-- fields that start with an undercore are private
-- class name follows the snake case naming convention
-- the barracuda table is the only global object to access every package
-- functionality. It plays the role of loader.

local Barracuda = {
    _VERSION     = 'barracuda v0.0.1',
    _NAME        = "Barracuda",
    _DESCRIPTION = 'Library for barcode typesetting',
    _URL         = 'http://repo.com',
    _LICENSE     = [[
        GNU GENERAL PUBLIC LICENSE
        Version 2, June 1991
    ]],
}

-- basic sub-module loading
Barracuda._libgeo   = require "lib-geo.libgeo"      -- basic vestor object
Barracuda._barcode  = require "lib-barcode.barcode" -- barcode abstract class
Barracuda._gacanvas = require "lib-geo.gacanvas"    -- ga stream library

Barracuda._brc_instance = {} -- encoder builder instances repository
Barracuda._drv_instance = {} -- driver instances repository

-- barcode_type/submodule name
Barracuda._brc_available_enc = {-- keys must be lowercase
    code39  = "lib-barcode.code39",
    -- code128 = "Code128.lua",
    -- ean13   = "Ean13.lua",
    -- ean5    = "Ean5.lua",
    -- ean2    = "Ean2.lua",
}

-- driver_type/submodule name
Barracuda._drv_available_drv = {-- keys must be lowercase
    native  = "lib-driver.driver-pdfliteral",
}

-- encoder builder loader
-- barcode_type: is the encoder type in lowercase chars
function Barracuda:load_builder(brc) --> enc_builder, err
    if type(brc) ~= "string" then
        return nil, "[ArgErr] 'brc' is not a string"
    end
    -- is the barcode type a real module?
    if not self._brc_available_enc[brc] then
        return nil, "[Err] barcode type '"..brc.."' not found"
    end
    local tenc = self._brc_instance
    if tenc[brc] then -- is the encoder builder already loaded?
        return tenc[brc], nil --> enc_builder, no error
    else -- loading the encoder builder
        local mod = self._brc_available_enc[brc]
        local builder = require(mod)
        builder:init(self._libgeo, self._barcode)
        tenc[brc] = builder
        return builder, nil --> enc_builder, no error
    end
end

--
function Barracuda:load_driver(drv)
    if type(drv) ~= "string" then
        return nil, "[ArgErr] 'drv' is not a string"
    end
    if not self._drv_available_drv[drv] then
        return nil, "[Err] driver '"..drv.."' not found"
    end
    local tdrv = self._drv_instance
    if tdrv[drv] then -- is the encoder builder already loaded?
        return tdrv[drv], nil --> driver, no error
    else -- loading driver
        local mod = self._drv_available_drv[drv]
        local driver = require(mod)
        tdrv[drv] = driver
        return driver, nil --> driver, no error
    end
end

function Barracuda:new_canvas()
    local gacanvas = self._gacanvas
    return gacanvas:new()
end

return Barracuda

