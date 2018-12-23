-- Welcome to the 'barracuda' barcode library
--
-- Encode a message into a barcode symbol, in Lua or within a LuaTeX source file
--
-- Copyright (C) 2018 Roberto Giacomelli
-- 
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

-- fields that start with an undercore are private
-- class name follows the snake case naming convention
-- the barracuda table is the only global object to access every package
-- functionality. It plays the loader role.

local Barracuda = {
    _VERSION     = "barracuda v0.0.3",
    _NAME        = "Barracuda",
    _DESCRIPTION = "Library for barcode typesetting",
    _URL         = "https://github.com/robitex/barracuda",
    _LICENSE     = [[GNU GENERAL PUBLIC LICENSE, Version 2, June 1991]],
}

-- basic sub-module loading 
Barracuda._libgeo   = require "lib-geo.libgeo"      -- basic vestor object
Barracuda._barcode  = require "lib-barcode.barcode" -- barcode abstract class
Barracuda._gacanvas = require "lib-geo.gacanvas"    -- ga stream library

local Barcode = Barracuda._barcode
Barcode._libgeo = Barracuda._libgeo

Barracuda._drv_instance = {} -- driver instances repository

-- driver_type/submodule name
Barracuda._drv_available_drv = { -- keys must be lowercase
    native  = "lib-driver.driver-pdfliteral",
    -- svg  = "lib-driver.driver-svg",
    -- tikz = "lib-driver.driver-tikz",
}

-- encoder builder loader
-- barcode_type: is the encoder type in lowercase chars
function Barracuda:new_encoder(bc_class, id_enc, opt) --> enc, err
    local barcode = self._barcode
    return barcode:new_encoder(bc_class, id_enc, opt)
end

-- return a specific already build barcode encoder
function Barracuda:enc_by_name(bc_class, id_enc)
    local barcode = self._barcode
    return barcode:enc_by_name(bc_class, id_enc)
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
