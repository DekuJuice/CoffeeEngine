local Texture = require("class.engine.resource.Texture")
local Resource = require("class.engine.resource.Resource")
local Tileset = Resource:subclass("Tileset")

Tileset.static.extensions = {"tset"}

Tileset:export_var("texture", "resource", {resource_type=Texture})
Tileset:export_var("tile_size", "int")

Tileset:binser_register()

function Tileset:initialize()
    Resource.initialize(self)
    self.tile_size = 16
    self.tiles = {}
end

function Tileset:add_property(tile_index, type, key)

end

function Tileset:remove_property(tile_index, key)

end

function Tileset:set_property(tile_index, key, value)

end

function Tileset:get_tile_properties(index)

end

function Tileset:get_quad(tile_index)
    assert(self.texture, "Texture needed to create quad transform")
    local tw, th = self.texture:get_love_image():getDimensions()
    local xt = math.ceil(tw / self.tile_size)
    local yt = math.ceil(th / self.tile_size)
    
    local tile_x = (tile_index - 1) % xt
    local tile_y = math.floor((tile_index - 1) / xt)
    
    return love.graphics.newQuad(
        tile_x * self.tile_size,
        tile_y * self.tile_size, 
        self.tile_size,
        self.tile_size,
        tw, th
    )
end

function Tileset:get_count()
    assert(self.texture, "Texture needed to calculate count")
    
    local tw, th = self.texture:get_love_image():getDimensions()
    
    local xt = math.ceil(tw / self.tile_size)
    local yt = math.ceil(th / self.tile_size)
    
    return xt * yt
end

function Tileset:get_count_x()
    local tw, _ = self.texture:get_love_image():getDimensions()
    return math.ceil(tw / self.tile_size)
end

function Tileset:get_count_y()
    local _, th = self.texture:get_love_image():getDimensions()
    return math.ceil(th / self.tile_size)
end

return Tileset