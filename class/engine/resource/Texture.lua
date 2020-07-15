local binser = require("enginelib.binser")

local ImportedResource = require("class.engine.resource.ImportedResource")
local Texture = ImportedResource:subclass("Texture")
Texture:export_var(
    "filter_min", 
    "enum", 
    { 
        enum = {
            "nearest",
            "linear"
        }
    }
)

Texture:export_var(
    "filter_mag", 
    "enum", 
    { 
        enum = {
            "nearest",
            "linear"
        }
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
        }
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
        }
    }
)

Texture.static.extensions = {"png", "jpg"}
Texture:binser_register()

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