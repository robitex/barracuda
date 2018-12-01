-- barracuda barcode libray
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
        LaTeX Project Public License LPPL Version 1.3c 2008-05-04
        https://www.latex-project.org/lppl.txt
    ]],
}

-- sub path to the local modules
Barracuda._enc_libdir = "/libencoder/"
Barracuda._drv_libdir = "/libdriver/"

-- barcode_type/submodule filename
Barracuda._enc_module = {-- keys must be lowercase
    code39  = "Code39.lua",
    -- code128 = "Code128.lua",
    -- ean13   = "Ean13.lua",
    -- ean5    = "Ean5.lua",
    -- ean2    = "Ean2.lua",
}

Barracuda._drv_module = {-- keys must be lowercase
    native  = "driver-pdfliteral.lua",
}


Barracuda._enc_instance = {} -- encoder instances repository
Barracuda._drv_instance = {} -- driver instances repository

-- init method
-- path is the home directory of the project usually provided by LuaTeX
-- from within the main level package. This function must be called for
-- first in order to keep the code self-contained
function Barracuda:init(path)
    assert(type(path) == "string")
    self._homedir = path
    -- load libgeo
    local libgeo = assert(dofile(path.."/libgeo.lua"))
    self._libgeo = libgeo
    local barcode = assert(dofile(path.."/Barcode-abstract-class.lua"))
    self._barcode = barcode
    local gacanvas = assert(dofile(path.."/gaCanvas.lua"))
    self._gacanvas = gacanvas
end

-- encoder builder loader
-- barcode_type: is the encoder type in lowercase chars
function Barracuda:load_builder(barcode_type) --> (enc_builder, err)
    if type(barcode_type) ~= "string" then
        return nil, "[ArgErr] barcode_type is not a string"
    end
    -- is the barcode type recognized?
    if not self._enc_module[barcode_type] then
        return nil, "[Err] barcode type '"..barcode_type.."' not found"
    end
    local tenc = self._enc_instance
    if tenc[barcode_type] then -- is the encoder builder already loaded?
        return tenc[barcode_type], nil --> (ok, no error)
    else -- loading the encoder builder
        local filename = self._enc_module[barcode_type]
        local builder = dofile(self._homedir .. self._enc_libdir .. filename)
        builder:init(self._libgeo, self._barcode)
        tenc[barcode_type] = builder
        return builder, nil --> (ok, no error)
    end
end


function Barracuda:load_driver(drv)
    if type(drv) ~= "string" then
        return nil, "[ArgErr] 'drv' is not a string"
    end
    if not self._drv_module[drv] then
        return nil, "[Err] driver '"..drv.."' not found"
    end
    local tdrv = self._drv_instance
    if tdrv[drv] then -- is the encoder builder already loaded?
        return tdrv[drv], nil --> (ok, no error)
    else -- loading driver
        local filename = self._drv_module[drv]
        local driver = dofile(self._homedir .. self._drv_libdir .. filename)
        tdrv[drv] = driver
        return driver, nil --> (ok, no error)
    end
end

function Barracuda:new_canvas()
    local gacanvas = self._gacanvas
    return gacanvas:new()
end

return Barracuda

