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
    
    local obstacle_hit = false
    
    for _, obstacle in ipairs(nearby) do
        local omin, omax = obstacle:get_bounding_box()
        
        if not intersect.aabb_aabb(rmin, rmax, omin, omax)
        and intersect.aabb_aabb(nmin, nmax, omin, omax) then
            obstacle_hit = true
            break
        end
    end
    
    if not obstacle_hit then
        actor:translate(step)
    end    
end

function PhysicsWorld:_step_actor_y(actor, sign)
    local p = actor:get_position()
    local step = vec2(0, sign)
    local rmin, rmax = actor:get_bounding_box()
    
    local nmin, nmax = rmin + step, rmax + step
    local nearby = self.obstacle_shash:get_nearby_in_rect( nmin.x, nmin.y, (nmax - nmin):unpack() ) 
    
    local obstacle_hit = false
    
    for _, obstacle in ipairs(nearby) do
        local omin, omax = obstacle:get_bounding_box()
        if not intersect.aabb_aabb(rmin, rmax, omin, omax) 
        and intersect.aabb_aabb(nmin, nmax, omin, omax) then
            obstacle_hit = true
            break
        end
    end
    
    if not obstacle_hit then
        actor:translate(step)
    end    
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
    assert(actor:isInstanceOf(Actor), "move_actor expects an Actor")
    
    if delta == vec2.zero then return end
    
    local x_remainder = delta.x
    local y_remainder = delta.y
    
    local xsign = math.sign(delta.x)
    local ysign = math.sign(delta.y)
    
    local step_x, step_y = get_step_size(delta)
    
    local next_step_x = x_remainder ~= 0
    while math.abs(x_remainder) + math.abs(y_remainder) > 0 do
        
        if next_step_x then
            local capped_step = math.min(step_x, math.abs(x_remainder))
            for i = 1, capped_step do
                self:_step_actor_x(actor, xsign)
            end
            x_remainder = x_remainder - capped_step * xsign
        
        else
            local capped_step = math.min(step_y, math.abs(y_remainder))
            for i = 1, capped_step do
                self:_step_actor_y(actor, ysign)
            end
            y_remainder = y_remainder - capped_step * ysign
        end
        
        next_step_x = not next_step_x
    end
    
    
    
    
    
   
   
   
end

function PhysicsWorld:move_obstacle(obstacle, delta)
    assert(self:has_collidable(obstacle), "Obstacle is not in physics world")
    assert(obstacle:isInstanceOf(Obstacle), "move_obstacle expects an obstacle")
    
    
    
    
end

function PhysicsWorld:clear()

    self.collidables = {}
end

-- Updates cached positions without checking for any intersections
function PhysicsWorld:set_collidable_position(collidable, x, y) 
    
end

function PhysicsWorld:debug_draw()
    -- Draw cells
    
    -- Draw collision boxes
    for collidable in pairs(self.collidables) do
        if collidable:isInstanceOf(Actor) then
            local rectmin, rectmax = collidable:get_bounding_box()
            local dim = rectmax - rectmin
            
            love.graphics.push("all")
            love.graphics.setColor(160/255, 201/255, 115/255, 0.3)
            love.graphics.rectangle("fill", rectmin.x, rectmin.y, dim.x, dim.y)
            love.graphics.pop()
        elseif collidable:isInstanceOf(Obstacle) then
        
            -- TODO: Draw heightmap
            local rectmin, rectmax = collidable:get_bounding_box()
            local dim = rectmax - rectmin
            
            love.graphics.push("all")
            love.graphics.setColor(210/255, 165/255, 242/255, 0.3)
            love.graphics.rectangle("fill", rectmin.x, rectmin.y, dim.x, dim.y)
            love.graphics.pop()
        
        
        end
    end
    
    
end

return PhysicsWorld