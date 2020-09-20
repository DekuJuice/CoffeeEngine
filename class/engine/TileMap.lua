-- TODO: Rewrite drawing to use a single spritebatch
-- while still reading from chunks directly

local FLIP_H_BIT = bit.lshift(1, 14)
local FLIP_V_BIT = bit.lshift(1, 15)

local pool = require("enginelib.pool")

local Tileset = require("class.engine.resource.Tileset")
local InfiniteGrid = require("class.engine.InfiniteGrid")
local Collidable = require("class.engine.Collidable")
local Obstacle = require("class.engine.Obstacle")

local TilePlaceholder = Obstacle:subclass("TilePlaceholder")
TilePlaceholder.static.dontlist = true
TilePlaceholder.static.empty_heightmap = {}

local tile_placehold_pool = pool.new(function() return TilePlaceholder() end)
tile_placehold_pool:generate(100)

local TileMap = Collidable:subclass("TileMap")
TileMap.static.icon = IconFont and IconFont.GRID

TileMap:export_var("tile_data", "data")
TileMap:export_var("tileset", "resource", {resource_type = Tileset})
TileMap:export_var("collision_enabled", "bool")
TileMap:export_var("tile_size", "int", {min = 4, max = 1024})

function TileMap:initialize()
    Collidable.initialize(self)

    self.tile_data = InfiniteGrid()
    
    self.sprite_batch = nil
    self.quad_cache = {}
    
    self.collision_enabled = false
    self.tile_size = 16
    
    self.changed_chunks = {}
end

function TileMap:set_tileset(tileset)
    self.tileset = tileset
    self.sprite_batch = nil
    self.quad_cache = {}
    
    if tileset then
        for i = 1, self.tileset:get_count() do
            self.quad_cache[i] = self.tileset:get_quad(i)
        end
    end
end

function TileMap:bitmask_tile(t, flip_h, flip_v)
    if t ~= 0 then
        if flip_h then
            t = bit.bxor(t, FLIP_H_BIT)
        end
        
        if flip_v then
            t = bit.bxor(t, FLIP_V_BIT)
        end
    end
    return t
end

function TileMap:unbitmask_tile(t)
    local flip_h = bit.band(t, FLIP_H_BIT) ~= 0
    local flip_v = bit.band(t, FLIP_V_BIT) ~= 0
    
    t = bit.band(t, bit.bnot(FLIP_H_BIT), bit.bnot(FLIP_V_BIT))

    return t, flip_h, flip_v
end

function TileMap:set_cell(x, y, t)
    self.tile_data:set_cell(x, y, t)
end

function TileMap:get_cell(x, y)
    return self.tile_data:get_cell(x, y)
end

-- IMPORTANT: For optimization purposes, the obstacles returned by these methods
-- are pooled. Don't forget to return them with pool_push_obstacle when you're done
-- with them (although they don't strictly need to be, it just wastes memory and gc time if they aren't)

function TileMap:get_obstacle(x, y)
    local c = self:get_cell(x, y)
    if c == 0 or not c then return nil end
        
    local flip_h, flip_v
    
    c, flip_h, flip_v = self:unbitmask_tile(c)
    
    local tile = self.tileset:get_tile(c)
    if not tile.collision_enabled then return nil end

    local hdim = vec2(self.tile_size / 2, self.tile_size / 2)
    local placehold = tile_placehold_pool:pop()

    placehold:set_aabb_extents(hdim)   
    placehold:set_position(self:transform_to_world(vec2(x, y)) + hdim) 
    placehold:set_heightmap(TilePlaceholder.static.empty_heightmap)
    placehold:set_flip_h(flip_h)
    placehold:set_flip_v(flip_v)
    placehold:set_collision_layer(self.collision_layer)
    if tile.heightmap_enabled then
        placehold:set_heightmap(tile.heightmap)
    end
    
    return placehold
end

function TileMap:get_obstacles_in_rect(rectmin, rectmax)
    local result = {}
    if not self.tileset then return result end

    for x = rectmin.x, rectmax.x do
        for y = rectmin.y, rectmax.y do
            local placehold = self:get_obstacle(x, y)
            if placehold then
                table.insert(result, placehold)
            end            
        end
    end

    return result
end

TileMap.static.pool_push_obstacle = function(class, ob)
    tile_placehold_pool:push(ob)
end

function TileMap:get_chunk_size()
    return self.tile_size * self.tile_data:get_chunk_length()
end

function TileMap:draw()
    local tree = self:get_tree()
    if not tree then return end -- Need to be in tree to calculate visible chunks
    if not self.tileset then return end -- No tileset, nothing to render
    local texture = self.tileset:get_texture() 
    if not texture then return end -- No texture, nothing to render
    local image = texture:get_love_image()
    
    if self.sprite_batch then
        self.sprite_batch:clear()
    else
        self.sprite_batch = love.graphics.newSpriteBatch(image, 500)    
    end
    
    local view = tree:get_viewport()
    local vp = view:get_position()
    local dim = vec2( view:get_resolution() )
    local gp = self:get_global_position()
    local rmin = view:transform_to_world( vec2.zero ) - gp
    local rmax = view:transform_to_world( vec2.zero + dim ) - gp

    local gmin = self:transform_to_map(rmin)
    local gmax = self:transform_to_map(rmax)

    local chunk_length = self.tile_data:get_chunk_length()
    local chunk_size = self:get_chunk_size()
    local cmin = rmin / chunk_size
    local cmax = rmax / chunk_size    
    
    -- Iterate through visible chunks
    for x = math.floor(cmin.x), math.floor(cmax.x) do
        for y = math.floor(cmin.y), math.floor(cmax.y) do
            local key = self.tile_data:get_chunk_key(x, y)
            local index = self.tile_data:get_chunk_index(key)
            local chunk = self.tile_data:get_chunk(index)
            if chunk then
                local xc = x * chunk_length
                local yc = y * chunk_length
                local xc2 = xc + chunk_length - 1
                local yc2 = yc + chunk_length - 1
                
                local x_min = math.max(xc, gmin.x) - xc
                local y_min = math.max(yc, gmin.y) - yc
                local x_max = math.min(xc2, gmax.x) - xc
                local y_max = math.min(yc2, gmax.y) - yc
                for ty = y_min, y_max do
                    for tx = x_min, x_max do
                        local t = chunk[ tx % chunk_length + ty * chunk_length + 1]
                        if t > 0 then
                            local flip_h, flip_v
                            t, flip_h, flip_v = self:unbitmask_tile(t)
                            
                            local hs = self.tile_size / 2
                            self.sprite_batch:add(
                                self.quad_cache[t],
                                (tx + xc) * self.tile_size + hs, 
                                (ty + yc) * self.tile_size + hs,
                                0,
                                flip_h and -1 or 1,
                                flip_v and -1 or 1,
                                hs,
                                hs
                            )
                        end
                    end
                end
            end
        end
    end
    
    love.graphics.draw(self.sprite_batch, gp.x, gp.y)

end

-- World coords to map coords
function TileMap:transform_to_map(point)
    local gp = self:get_global_position()
    local p = (point - gp) / self.tile_size
    p.x = math.floor(p.x)
    p.y = math.floor(p.y)
    
    return p
end

function TileMap:transform_to_world(cell)
    local gpos = self:get_global_position()
    return cell * self.tile_size + gpos    
end

function TileMap:draw_collision()
    if not self.collision_enabled then return end
    if not self.tileset then return end
    
    local tree = self:get_tree()
    if not tree then return end
    
    local view = tree:get_viewport()
    local vp = view:get_position()
    local dim = vec2( view:get_resolution() )
    local gp = self:get_global_position()
    local rmin = view:transform_to_world( vec2.zero ) - gp
    local rmax = view:transform_to_world( vec2.zero + dim ) - gp
    
    rmin = self:transform_to_map(rmin)
    rmax = self:transform_to_map(rmax)
    local obs = self:get_obstacles_in_rect(rmin, rmax)
    for _,o in ipairs(obs) do
        o:draw_collision()
        TileMap:pool_push_obstacle(o)
    end

end

return TileMap