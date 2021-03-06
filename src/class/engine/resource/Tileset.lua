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

local DEFAULT_TILE_SIZE = 16

local Texture = require("class.engine.resource.Texture")
local Resource = require("class.engine.resource.Resource")
local Tileset = Resource:subclass("Tileset")

Tileset.static.extensions = {"tset"}

Tileset:export_var("texture", "resource", {resource_type=Texture})
Tileset:export_var("tile_size", "int", {default = DEFAULT_TILE_SIZE} )
Tileset:export_var("tiles", "data")

function Tileset:initialize()
    Resource.initialize(self)
    self.tile_size = DEFAULT_TILE_SIZE
    self.tiles = {}
    self.quads = {}
end

function Tileset:_reset_data()

    self.tiles = {}
    self.quads = {}

    local tc = self:get_count()
    
    for i = 1, tc do
        self.tiles[i] = {
            collision_enabled = true,
            heightmap_enabled = false,
            heightmap = {},
            tags = {}
        }
        
        for j = 1, self.tile_size do
            self.tiles[i].heightmap[j] = self.tile_size
        end
    end
    
    for i = 1, tc do
        local tw, th = self.texture:get_love_image():getDimensions()
        local xt = math.ceil(tw / self.tile_size)
        local yt = math.ceil(th / self.tile_size)
        
        local tile_x = (i - 1) % xt
        local tile_y = math.floor((i - 1) / xt)
        
        self.quads[i] = love.graphics.newQuad(
            tile_x * self.tile_size,
            tile_y * self.tile_size, 
            self.tile_size,
            self.tile_size,
            tw, th
        )
    end
end

function Tileset:set_texture(texture)
    self.texture = texture
    self:_reset_data()
end

function Tileset:set_tile_size(tile_size)
    self.tile_size = tile_size
    self:_reset_data()
end

function Tileset:get_tile(tile_index)
    return self.tiles[tile_index]
end

function Tileset:get_quad(tile_index)
    return self.quads[tile_index]
end

function Tileset:get_count()
    if not self.texture then
        return 0
    end
    
    local tw, th = self.texture:get_love_image():getDimensions()
    
    local xt = math.ceil(tw / self.tile_size)
    local yt = math.ceil(th / self.tile_size)
    
    return xt * yt
end

function Tileset:get_count_x()
    if not self.texture then return 0 end

    local tw, _ = self.texture:get_love_image():getDimensions()
    return math.ceil(tw / self.tile_size)
end

function Tileset:get_count_y()
    if not self.texture then return 0 end

    local _, th = self.texture:get_love_image():getDimensions()
    return math.ceil(th / self.tile_size)
end

return Tileset