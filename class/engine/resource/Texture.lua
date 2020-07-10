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

function Texture:initialize()
    ImportedResource.initialize(self)
    
    self.filter_min = "nearest"
    self.filter_mag = "nearest"
    self.hor_wrap = "clamp"
    self.ver_wrap = "clamp"
end

function Texture:initialize_from_filedata(fd)
    self.image = love.graphics.newImage(fd)
    self.image:setFilter(self.filter_min, self.filter_mag)
    self.image:setWrap(self.hor_wrap, self.ver_wrap)
end

function Texture:get_love_image()
    return self.image
end

return Texture