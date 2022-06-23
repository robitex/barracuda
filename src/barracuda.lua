-- Welcome to the 'barracuda' barcode library
--
-- Encode a message into a barcode symbol, in Lua or within a LuaTeX source file
--
-- Copyright (C) 2019-2022 Roberto Giacomelli
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
-- fields that start with an undercore must be considered as private
-- class name follows the snake case naming convention
-- the 'barracuda' table is the only global object to access every package
-- modules.

local Barracuda = {
    _NAME        = "barracuda",
    _VERSION     = "barracuda v0.0.12",
    _DATE        = "2022-06-23",
    _DESCRIPTION = "Lua library for barcode printing",
    _URL         = "https://github.com/robitex/barracuda",
    _LICENSE     = "GNU GENERAL PUBLIC LICENSE, Version 2, June 1991",
}

-- essential sub-module loading
Barracuda._libgeo   = require "lib-geo.brcd-libgeo"      -- basic vector objects
Barracuda._gacanvas = require "lib-geo.brcd-gacanvas"    -- ga stream library
Barracuda._barcode  = require "lib-barcode.brcd-barcode" -- barcode abstract class
Barracuda._lib_driver = require "lib-driver.brcd-driver" -- abstract driver class

local Barcode = Barracuda._barcode
Barcode._libgeo = Barracuda._libgeo

-- a reference to Driver class for gaCancas class
local canvas = Barracuda._gacanvas
canvas._driver_class = Barracuda._lib_driver

-- return a reference of Barcode abstract class
function Barracuda:barcode() --> <Barcode class>
    return self._barcode
end

-- return a reference to the libgeo library
function Barracuda:libgeo() --> <libgeo library>
    return self._libgeo
end

-- encoder costructor (a bridge to Barcode class method)
function Barracuda:new_encoder(treename, opt) --> object, err
    local barcode = self._barcode
    local enc, err = barcode:new_encoder(treename, opt) --> object, err
    return enc, err
end

-- where we place the output driver library
function Barracuda:get_driver() --> Driver object
    return self._lib_driver
end

function Barracuda:new_canvas() --> canvas
    local gacanvas = self._gacanvas
    return gacanvas:new()
end

-- high level barcode functions
-- panic on error

-- save barcode as a graphic external file
-- 'treename' mandatory encoder identifier <family>-<variant>:<name>
-- 'data' mandatory the object string or integer being encoded
-- 'filename' mandatory output filename
-- 'id_drv' optional driver identifier, defualt 'svg'
-- 'opt' optional table for symbol parameters
function Barracuda:save(treename, data, filename, id_drv, opt)
    local barcode = self._barcode
    local enc_archive = barcode._encoder_instances
    local enc = enc_archive[treename]
    if not enc then
        local err
        enc, err = barcode:new_encoder(treename)
        assert(enc, err)
    end
    -- make symbol
    local symb
    local arg_data = type(data)
    if arg_data == "number" then
        local err_data
        symb, err_data = enc:from_uint(data)
        assert(symb, err_data)
    elseif arg_data == "string" then
        local err_data
        symb, err_data = enc:from_string(data)
        assert(symb, err_data)
    else
        error("[ArgErr] unsupported type for 'data'")
    end
    if opt then
        local ok, err = symb:set_param(opt)
        assert(ok, err)
    end
    local canvas = self:new_canvas()
    symb:draw(canvas)
    local driver = self:get_driver()
    id_drv = id_drv or "svg"
    local ok, err = driver:save(id_drv, canvas, filename)
    assert(ok, err)
end

-- this is a only LuaTeX method
-- 'treename' mandatory encoder identifier <family>-<variant>:<name>
-- 'data' mandatory the object string or integer being encoded
-- 'box_name' mandatory TeX hbox name
-- 'opt' optional table for symbol parameters
function Barracuda:hbox(treename, data, box_name, opt)
    local barcode = self._barcode
    local enc_archive = barcode._encoder_instances
    local enc = enc_archive[treename]
    if not enc then
        local err
        enc, err = barcode:new_encoder(treename)
        assert(enc, err)
    end
    -- make symbol
    local symb
    local arg_data = type(data)
    if arg_data == "number" then
        local err_data
        symb, err_data = enc:from_uint(data)
        assert(symb, err_data)
    elseif arg_data == "string" then
        local err_data
        symb, err_data = enc:from_string(data)
        assert(symb, err_data)
    else
        error("[ArgErr] unsupported type for 'data'")
    end
    if opt then
        local ok, err = symb:set_param(opt)
        assert(ok, err)
    end
    local canvas = self:new_canvas()
    symb:draw(canvas)
    local driver = self:get_driver()
    local ok, err = driver:ga_to_hbox(canvas, box_name)
    assert(ok, err)
end

return Barracuda
