--[[

MIT License

Copyright (c) 2020 DekuJuice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

local ImportedResource = require("class.engine.resource.ImportedResource")
local Texture = ImportedResource:subclass("Texture")
Texture:export_var(
    "filter_min", 
    "enum", 
    { 
        enum = {
            "nearest",
            "linear"
        },
        default = "nearest"
    }
)

Texture:export_var(
    "filter_mag", 
    "enum", 
    { 
        enum = {
            "nearest",
            "linear"
        },
        default = "nearest"
    }
)

Texture:export_var(
    "hor_wrap",
    "enum", 
    { 
        enum = {
            "clamp",
            "clampzero",
            "repeat",
            "mirroredrepeat"
        },
        default = "clamp"
    }
)

Texture:export_var(
    "ver_wrap",
    "enum", 
    { 
        enum = {
            "clamp",
            "clampzero",
            "repeat",
            "mirroredrepeat"
        },
        default = "clamp"
    }
)

Texture.static.extensions = {"png", "jpg"}

function Texture:initialize()
    ImportedResource.initialize(self)
    
    self.filter_min = "nearest"
    self.filter_mag = "nearest"
    self.hor_wrap = "clamp"
    self.ver_wrap = "clamp"
end

function Texture:initialize_from_filedata(fd)
    self.image = love.graphics.newImage(fd)
    self:_update_filter()
    self:_update_wrap()
end

function Texture:_update_filter()
    if self.image then
        self.image:setFilter(self.filter_min, self.filter_mag)
    end
end

function Texture:_update_wrap()
    if self.image then
        self.image:setWrap(self.hor_wrap, self.ver_wrap)
    end
end

function Texture:set_filter_min(mode)
    self.filter_min = mode
    self:_update_filter()
end

function Texture:set_filter_mag(mode)
    self.filter_mag = mode
    self:_update_filter()
end

function Texture:set_hor_wrap(wrap)
    self.hor_wrap = wrap
    self:_update_wrap()
end

function Texture:set_ver_wrap(wrap)
    self.ver_wrap = wrap
    self:_update_wrap()
end

function Texture:get_love_image()
    return self.image
end

return Texture