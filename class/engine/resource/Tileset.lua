local binser = require("enginelib.binser")

local Resource = require("class.engine.resource.Resource")
local Tileset = Resource:subclass("Tileset")
Tileset.static.extensions = {"tset"}

Tileset:export_var("texture", "string")
Tileset:export_var("tile_size", "int")

function Tileset:initialize()
    Resource.initialize(self)
    self.tile_size = 16
    self.tiles = {}
end

function Tileset:add_property()
end

function Tileset:remove_property()
end

function Tileset:set_property()
end

function Tileset:get_quad(index)
    if not self.texture then return end
    
    
    
end

function Tileset:get_tile(index)
    return self.tiles[index]
end


return Tileset