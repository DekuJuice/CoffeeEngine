local Node2d = require("class.engine.Node2d")

local TileMap = Node2d:subclass("TileMap")

TileMap:export_var("tile_data", "data")
TileMap:export_var("tileset_data", "data")
TileMap:export_var("collision_enabled", "bool")
TileMap:export_var("tile_size", "int", {min = 1, max = 1024})


function TileMap:initialize()
    Node2d.initialize(self)
    
    self.tile_data = {}
    self.tileset_data = {}
    
    self.collision_enabled = false
    self.tile_size = 16
end

function TileMap:remove_invalid_tiles()
end

function TileMap:add_tileset(tileset)
end

function TileMap:remove_tileset()
end







return TileMap