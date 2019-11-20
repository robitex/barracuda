-- Welcome to the 'barracuda' barcode library
--
-- Encode a message into a barcode symbol, in Lua or within a LuaTeX source file
--
-- Copyright (C) 2019 Roberto Giacomelli
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

-- Basic Conventions:
-- fields that start with an undercore are private
-- class name follows the snake case naming convention
-- the 'barracuda' table is the only global object to access every package
-- modules.

local Barracuda = {
    _VERSION     = "barracuda v0.0.9",
    _NAME        = "Barracuda",
    _DESCRIPTION = "Lua library for barcode printing",
    _URL         = "https://github.com/robitex/barracuda",
    _LICENSE     = "GNU GENERAL PUBLIC LICENSE, Version 2, June 1991",
}

-- essential sub-module loading
Barracuda._libgeo   = require "lib-geo.libgeo"      -- basic vestor object
Barracuda._gacanvas = require "lib-geo.gacanvas"    -- ga stream library
Barracuda._barcode  = require "lib-barcode.barcode" -- barcode abstract class

local Barcode = Barracuda._barcode
Barcode._libgeo = Barracuda._libgeo

-- encoder builder
function Barracuda:get_barcode_class() --> Barcode class object
    return self._barcode
end

-- where we place output driver library
function Barracuda:get_driver() --> Driver object, err
    if not self._lib_driver then
        self._lib_driver = require "lib-driver.driver"
    end
    return self._lib_driver
end

function Barracuda:new_canvas() --> driver
    local gacanvas = self._gacanvas
    return gacanvas:new()
end

return Barracuda
