-- 3 types of physics bodies
-- Actors - Anything that moves, must be AABBs. Only collide with obstacles
-- Obstacles - Things actors can collide with, such as tilemaps, moving platforms, etc
--             Obstacles can move, but do not interact with each other. Must be AABB, but
--             can use heightmaps to create things such as slopes
-- Areas - Can be any convex polygon shape - Detects when actors or obstacles overlap them
--         but does not perform any sort of collision resolution

-- Collision
-- For collision between actors and obstacles, only collision for actors and obstacles that 
-- are NOT intersecting are checked. This means that if an actor and obstacle somehow overlap,
-- no further collision checks between them will be made.  This is for the sake of crush resolution

local shash = require("enginelib.shash")
local intersect = require("enginelib.intersect")

local Object = require("class.engine.Object")
local Actor = require("class.engine.Actor")
local Obstacle = require("class.engine.Obstacle")
local Area = require("class.engine.Area")
local TileMap = require("class.engine.TileMap")

local PhysicsWorld = Object:subclass("PhysicsWorld")

local CELL_SIZE = 16 * 6

local function overlap_interval(a, b, c, d)
    return math.max(a, c), math.min(b, d)
end

function PhysicsWorld:initialize()
    Object.initialize(self)
    
    self.collidables = {}    
    self.actor_shash = shash.new(CELL_SIZE)
    self.obstacle_shash = shash.new(CELL_SIZE)
    self.area_shash = shash.new(CELL_SIZE)
    -- Tilemaps are a special case, since there likely won't be more than
    -- 2 or 3 collidable layers, we'll just check all of them instead of bothering with spatial hashing it
    self.tilemaps = {}
    
end

function PhysicsWorld:has_collidable(collidable)
    return self.collidables[collidable] ~= nil
end

function PhysicsWorld:add_collidable(collidable)
    self.collidables[collidable] = true
    
    if collidable:isInstanceOf(Actor) then
        local rmin, rmax = collidable:get_bounding_box()
        local dim = rmax - rmin
        
        self.actor_shash:add_object(collidable, rmin.x, rmin.y, dim.x, dim.y)
    elseif collidable:isInstanceOf(Obstacle) then
        local rmin, rmax = collidable:get_bounding_box()
        local dim = rmax - rmin
        
        self.obstacle_shash:add_object(collidable, rmin.x, rmin.y, dim.x, dim.y)
    elseif collidable:isInstanceOf(Area) then
        local rmin, rmax = collidable:get_bounding_box()
        local dim = rmax - rmin
        
        self.area_shash:add_object(collidable, rmin.x, rmin.y, dim.x, dim.y)
    elseif collidable:isInstanceOf(TileMap) then
        table.insert(self.tilemaps, collidable)
    else
        error("Base collidable should not be instantiated")
    end 
end

function PhysicsWorld:remove_collidable(collidable)
    self.collidables[collidable] = nil
    if collidable:isInstanceOf(Actor) then
        self.actor_shash:remove_object(collidable)
    elseif collidable:isInstanceOf(Obstacle) then
        self.obstacle_shash:remove_object(collidable)
    elseif collidable:isInstanceOf(Area) then
        self.area_shash:remove_object(collidable)
    elseif collidable:isInstanceOf(TileMap) then
        local n = #self.tilemaps
        if n == 1 then
            self.tilemaps[n] = nil
        else
            for i,v in ipairs(self.tilemaps) do
                if v == collidable then
                    self.tilemaps[i] = self.tilemaps[n]
                    self.tilemaps[n] = nil
                    break
                end
            end
        end
    else
        error("Base collidable should not be instantiated")
    end 
end



function PhysicsWorld:_step_actor_x(actor, sign)
    local p = actor:get_position()
    local step = vec2(sign, 0)
    local rmin, rmax = actor:get_bounding_box()
    
    local nmin, nmax = rmin + step, rmax + step
    local nearby = self.obstacle_shash:get_nearby_in_rect( nmin.x, nmin.y, (nmax - nmin):unpack() ) 
    local nearby_tiles = {}
    
    for _, tilemap in ipairs(self.tilemaps) do
        if tilemap:get_collision_enabled() then
            local t = tilemap:get_obstacles_in_rect(
                tilemap:transform_to_map(nmin),
                tilemap:transform_to_map(nmax),
                true
            )
            
            for _,o in ipairs(t) do
                table.insert(nearby, o)
                table.insert(nearby_tiles, o)
            end
        end
    end
    
    local obstacle_hit = false
    
    for _, obstacle in ipairs(nearby) do
        local omin, omax = obstacle:get_bounding_box()
        
        if not intersect.aabb_aabb(nmin, nmax, omin, omax) then
            goto CONTINUE
        end
        
        local hm = obstacle:get_heightmap()
        if #hm == 0 and not intersect.aabb_aabb(rmin, rmax, omin, omax) then
            obstacle_hit = true
            break
        else
           
            local x1, x2 = overlap_interval(nmin.x, nmax.x, omin.x, omax.x)
            
            local max_height = 0
            for x = x1, x2 - 1 do
                max_height = math.max(max_height, obstacle:get_height(x - omin.x))
            end
                        
            if obstacle:get_flip_v() then                
                local b_edge = omin.y + max_height
                if nmin.y < omin.y then
                    obstacle_hit = true
                elseif nmin.y < b_edge then
                    for i = 1, b_edge - nmin.y do
                        if self:_step_actor_y(actor, 1) then
                            obstacle_hit = true
                            actor:translate(vec2(0, -(i - 1)))
                            break
                        end
                    end
                end
                
            else
                local t_edge = omax.y - max_height
                        
                if nmax.y > omax.y then
                    obstacle_hit = true
                elseif nmax.y > t_edge then
                    for i = 1, nmax.y - t_edge do
                        if self:_step_actor_y(actor, -1) then
                            obstacle_hit = true
                            actor:translate(vec2(0, i - 1))
                            break
                        end
                    end
                end
            end
        end
        
        ::CONTINUE::
    end
    
    if not obstacle_hit then
        actor:translate(step)
    end
    
    for _, o in ipairs(nearby_tiles) do
        TileMap:pool_push_obstacle(o)
    end
    
    
    return obstacle_hit
end

function PhysicsWorld:_step_actor_y(actor, sign)
    local p = actor:get_position()
    local step = vec2(0, sign)
    local rmin, rmax = actor:get_bounding_box()
    
    local nmin, nmax = rmin + step, rmax + step
    local nearby = self.obstacle_shash:get_nearby_in_rect( nmin.x, nmin.y, (nmax - nmin):unpack() ) 
    local nearby_tiles = {}
    
    for _, tilemap in ipairs(self.tilemaps) do
        if tilemap:get_collision_enabled() then
            local t = tilemap:get_obstacles_in_rect(
                tilemap:transform_to_map(nmin),
                tilemap:transform_to_map(nmax),
                true
            )
            
            for _,o in ipairs(t) do
                table.insert(nearby, o)
                table.insert(nearby_tiles, o)
            end
        end
    end
    
    local obstacle_hit = false
    
    for _, obstacle in ipairs(nearby) do
        local omin, omax = obstacle:get_bounding_box()
        
        if not intersect.aabb_aabb(nmin, nmax, omin, omax) then
            goto CONTINUE
        end
        
        local hm = obstacle:get_heightmap()
        if #hm == 0 and not intersect.aabb_aabb(rmin, rmax, omin, omax) then
            obstacle_hit = true
            break
        else
            local x1, x2 = overlap_interval(nmin.x, nmax.x, omin.x, omax.x)
            local max_height = 0
            for x = x1, x2 - 1 do
                max_height = math.max(max_height, obstacle:get_height(x - omin.x))
            end
            
            if obstacle:get_flip_v() then
                local b_edge = omin.y + max_height
                if nmin.y < b_edge then
                    obstacle_hit = true
                    break
                end
            else
                local t_edge = omax.y - max_height
                
                if nmax.y > t_edge then
                    obstacle_hit = true
                    break
                end
            end
            
        end
        
        ::CONTINUE::
    end
    
    if not obstacle_hit then
        actor:translate(step)
    end    
    
    for _, o in ipairs(nearby_tiles) do
        TileMap:pool_push_obstacle(o)
    end
    
    return obstacle_hit
end

-- Delta must not be 0
-- Returns absolute step 
-- Assumed x step taken first
local function get_step_size(delta)

    local ax = math.abs(delta.x)
    local ay = math.abs(delta.y)
    
    if ax == 0 or ay == 0 then
        return ax, ay
    end
        
    return math.ceil(ax / ay), math.ceil(ay / ax)
end

function PhysicsWorld:move_actor(actor, delta, cling_dist)
    assert(self:has_collidable(actor), "Actor is not in physics world")
    assert(actor:isInstanceOf(Actor), "move_actor expects an anctor")
    
    if delta == vec2.zero then return end
    
    cling_dist = cling_dist or 0
    
    local x_remainder = delta.x
    local y_remainder = delta.y
    
    local xsign = math.sign(delta.x)
    local ysign = math.sign(delta.y)
    
    local step_x, step_y = get_step_size(delta)
    
    local next_step_x = x_remainder ~= 0
    while math.abs(x_remainder) + math.abs(y_remainder) > 0 do
        
        if next_step_x then
            local capped_step = math.min(step_x, math.abs(x_remainder))
            local hit = false
            for i = 1, capped_step do
                if self:_step_actor_x(actor, xsign) then
                    hit = true
                    actor.on_wall = true
                    break
                end
                
                if actor.on_ground or actor.on_ground_prev and cling_dist > 0 then
                    local clung = false
                    
                    for j = 1, cling_dist + 1 do
                        if self:_step_actor_y(actor, 1) then
                            clung = true
                            break
                        end
                    end
                    
                    if clung then
                        actor.on_ground = true
                    else
                        actor:translate(vec2(0, -(cling_dist + 1)))
                    end
                end
                
            end
            
            if hit then
                x_remainder = 0
            else
                x_remainder = x_remainder - capped_step * xsign
            end
            
        else
            local capped_step = math.min(step_y, math.abs(y_remainder))
            local hit = false
            for i = 1, capped_step do
                if self:_step_actor_y(actor, ysign) then
                    hit = true
                    break
                end
            end
            if hit then
                y_remainder = 0
                if ysign == 1 then
                    actor.on_ground = true
                elseif ysign == -1 then
                    actor.on_ceil = true
                end
                
            else
                y_remainder = y_remainder - capped_step * ysign
            end
        end
        
        next_step_x = not next_step_x
    end

end

function PhysicsWorld:move_obstacle(obstacle, delta)
    assert(self:has_collidable(obstacle), "Obstacle is not in physics world")
    assert(obstacle:isInstanceOf(Obstacle), "move_obstacle expects an obstacle")
    
    
    
    
end

-- Updates cached positions without checking for any intersections
function PhysicsWorld:set_collidable_position(collidable, x, y) 
    
end

function PhysicsWorld:debug_draw()
    -- Draw cells
    --self.obstacle_shash:debug_draw()
    
    -- Draw collision boxes
    for collidable in pairs(self.collidables) do
        if collidable.draw_collision then collidable:draw_collision() end
    end
end

return PhysicsWorld