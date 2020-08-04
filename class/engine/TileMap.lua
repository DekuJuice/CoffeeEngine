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

TileMap:export_var("tile_data", "data")
TileMap:export_var("tileset", "resource", {resource_type = Tileset})
TileMap:export_var("collision_enabled", "bool")
TileMap:export_var("tile_size", "int", {min = 4, max = 1024, merge_mode = "merge_ends"})

TileMap:binser_register()

function TileMap:initialize()
    Collidable.initialize(self)

    self.tile_data = InfiniteGrid()
    self.sprite_batches = {}
    self.quad_cache = {}
    
    self.collision_enabled = false
    self.tile_size = 16
end

function TileMap:set_tileset(tileset)
    self.tileset = tileset
    self.sprite_batches = {}
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
            t = bit.bor(t, FLIP_H_BIT)
        end
        
        if flip_v then
            t = bit.bor(t, FLIP_V_BIT)
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

function TileMap:set_cell(x, y, t, flip_h, flip_v)
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

function TileMap:calculate_visible_chunks()
    local tree = self:get_tree()
    local view = tree:get_viewport()
    
    local vp = view:get_position()
    local scale = view:get_scale()
    local dim = vec2( view:get_resolution() )
    
    local gp = self:get_global_position()
    
    local rmin = view:transform_to_world( vec2.zero ) - gp
    local rmax = view:transform_to_world( vec2.zero + dim ) - gp

    local chunk_size = self:get_chunk_size()
    rmin = rmin / chunk_size
    rmax = rmax / chunk_size    

    local visible_chunks = {}
    for x = math.floor(rmin.x), math.floor(rmax.x) do
        for y = math.floor(rmin.y), math.floor(rmax.y) do
            
            local key = self.tile_data:get_chunk_key(x, y)
            local index = self.tile_data:get_chunk_index(key)
            if self.tile_data:get_chunk(index) then
                table.insert(visible_chunks, vec2(x, y))
            end
        end
    end
    
    return visible_chunks
end

function TileMap:draw()
    local tree = self:get_tree()
    if not tree then return end -- Need to be in tree to calculate visible chunks
    if not self.tileset then return end -- No tileset, nothing to render
    local texture = self.tileset:get_texture() 
    if not texture then return end -- No texture, nothing to render
    local image = texture:get_love_image()
    
    
    local visible_chunks = self:calculate_visible_chunks()
    
    local visible_indices = {} -- Set of visible chunk indices
    for _, cpos in ipairs(visible_chunks) do
        local key = self.tile_data:get_chunk_key(cpos:unpack())
        local index = self.tile_data:get_chunk_index(key)
        visible_indices[index] = true
    end
    
    -- Clean up spritebatches pointing to no longer existing or visible cells
    for _,binfo in ipairs(self.sprite_batches) do
        if not visible_indices[binfo.index] then
            binfo.index = nil
        end
    end
    
    local gpos = self:get_global_position()
    local chunk_size = self:get_chunk_size()
    local chunk_length = self.tile_data:get_chunk_length()
    
    for _, cpos in ipairs(visible_chunks) do
        local key = self.tile_data:get_chunk_key(cpos:unpack())
        local index = self.tile_data:get_chunk_index(key)
        local chunk = self.tile_data:get_chunk(index)
        local sprite_batch
            
        -- Get a free spritebatch
        for _,binfo in ipairs(self.sprite_batches) do
            -- Batch no longer used or already cached for this chunk
            if binfo.index == index or binfo.index == nil then
                sprite_batch = binfo.batch
                binfo.index = index
                break
            end
        end
            
        if not sprite_batch then -- Create new spritebatch since no free ones
            sprite_batch = love.graphics.newSpriteBatch(
                image, chunk_length ^ 2, "dynamic")
                
            table.insert(self.sprite_batches, {
                batch = sprite_batch,
                index = index
            })
        end
            
        sprite_batch:clear()
            
        -- Populate batch
        for y = 1, chunk_length do
            for x = 1, chunk_length do
                local t = chunk[ (x - 1) % chunk_length + (y - 1) * chunk_length + 1]
                if t and t > 0 then
                    
                    local flip_h, flip_v
                    t, flip_h, flip_v = self:unbitmask_tile(t)
                    
                    local hs = self.tile_size / 2
                    
                    sprite_batch:add(
                        self.quad_cache[t],
                        (x - 1) * self.tile_size + hs, 
                        (y - 1) * self.tile_size + hs,
                        0,
                        flip_h and -1 or 1,
                        flip_v and -1 or 1,
                        hs,
                        hs
                    )
                end
            end
        end
            
        -- Draw batch
        love.graphics.draw(
            sprite_batch,
            cpos.x * chunk_size + gpos.x, 
            cpos.y * chunk_size + gpos.y
        )
            
        -- Debug rect for chunks
        --[[love.graphics.rectangle("line", 
            cpos.x * chunk_size + gpos.x, 
            cpos.y * chunk_size + gpos.y,
            chunk_size,
            chunk_size
        )]]--
    end
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

    local visible_chunks = self:calculate_visible_chunks()
    local gpos = self:get_global_position()
    local chunk_size = self:get_chunk_size()
    local chunk_length = self.tile_data:get_chunk_length()

    love.graphics.push("all")
    love.graphics.setColor(210/255, 165/255, 242/255, 0.3)
    love.graphics.setLineStyle("rough")
    
    for _, cpos in ipairs(visible_chunks) do
        local key = self.tile_data:get_chunk_key(cpos:unpack())
        local index = self.tile_data:get_chunk_index(key)
        local chunk = self.tile_data:get_chunk(index)
        
        local tmin = cpos * chunk_length
        local tmax = tmin + vec2(chunk_length - 1, chunk_length - 1)
        
        local obs = self:get_obstacles_in_rect(tmin, tmax)
        for _,o in ipairs(obs) do
           o:draw_collision() 
           TileMap:pool_push_obstacle(o)
        end
        
    end
    
    love.graphics.pop()
end

return TileMap