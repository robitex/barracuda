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
    _VERSION     = "barracuda v0.0.9.1",
    _NAME        = "barracuda",
    _DESCRIPTION = "Lua library for barcode printing",
    _URL         = "https://github.com/robitex/barracuda",
    _LICENSE     = "GNU GENERAL PUBLIC LICENSE, Version 2, June 1991",
}

-- essential sub-module loading
Barracuda._libgeo   = require "lib-geo.brcd-libgeo"      -- basic vectorial objects
Barracuda._gacanvas = require "lib-geo.brcd-gacanvas"    -- ga stream library
Barracuda._barcode  = require "lib-barcode.brcd-barcode" -- barcode abstract class

local Barcode = Barracuda._barcode
Barcode._libgeo = Barracuda._libgeo

-- encoder builder
function Barracuda:get_barcode_class() --> Barcode class object
    return self._barcode
end

-- where we place output driver library
function Barracuda:get_driver() --> Driver object, err
    if not self._lib_driver then
        self._lib_driver = require "lib-driver.brcd-driver"
    end
    return self._lib_driver
end

function Barracuda:new_canvas() --> driver
    local gacanvas = self._gacanvas
    return gacanvas:new()
end

-- high level barcode functions
-- only default options
-- panic on error

-- save barcode as a graphic external file
function Barracuda:save(bc_type, data, filename, id_drv)
    local barcode = self:get_barcode_class()
    local enc, err = barcode:new_encoder(bc_type)
    assert(enc, err)
    local arg_data = type(data)
    local symb
    if arg_data == "number" then
        local err_data
        symb, err_data = enc:from_uint(data)
        asser(symb, err_data)
    elseif arg_data == "string" then
        local err_data
        symb, err_data = enc:from_string(data)
        assert(symb, err_data)
    else
        error("[argErr] unsupported 'data' type")
    end
    local canvas = self:new_canvas()
    symb:append_ga(canvas)
    local driver = self:get_driver()
    id_drv = id_drv or "svg"
    local ok, out_err = driver:save(id_drv, canvas, filename)
    assert(ok, out_err)
end

-- this is a only LuaTeX method
function Barracuda:hbox(bc_type, data, box_name)
    local barcode = self:get_barcode_class()
    local enc, err = barcode:new_encoder(bc_type)
    assert(enc, err)
    local arg_data = type(data)
    local symb
    if arg_data == "number" then
        local err_data
        symb, err_data = enc:from_uint(data)
        asser(symb, err_data)
    elseif arg_data == "string" then
        local err_data
        symb, err_data = enc:from_string(data)
        assert(symb, err_data)
    else
        error("[argErr] unsupported 'data' type")
    end
    local canvas = self:new_canvas()
    symb:append_ga(canvas)
    local driver = self:get_driver()
    local ok, err_hbox = driver:ga_to_hbox(canvas, box_name)
    assert(ok, err_hbox)
end

return Barracuda
