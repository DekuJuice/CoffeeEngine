local intersect = require("enginelib.intersect")

local Collidable = require("class.engine.Collidable")
local Actor = Collidable:subclass("Actor")
Actor.static.noinstance = true

Actor:export_var("aabb_extents", "vec2_int", {speed = 0.2, min = 0, max = math.huge} )
Actor:export_var("aabb_offset", "vec2_int", {speed = 0.2, min = -math.huge, max = math.huge})
Actor:export_var("cling_dist", "int", {speed = 0.05, min = 0, max = 16})
Actor:export_var("climb_dist", "int", {speed = 0.05, min = 0, max = 16})

Actor:define_get_set("on_ground")
Actor:define_get_set("on_ceil")
Actor:define_get_set("on_wall")
Actor:define_get_set("on_slope")
Actor:define_get_set("jump_down_one_way")

Actor:define_get_set("stick_moving_ground")
Actor:define_get_set("stick_moving_wall_left")
Actor:define_get_set("stick_moving_wall_right")
Actor:define_get_set("stick_moving_ceil")

Actor:binser_register()

function Actor:initialize()
    Collidable.initialize(self)
    self.aabb_extents = vec2(8, 16)
    self.aabb_offset = vec2(0, 0)
    self.cling_dist = 1
    self.climb_dist = 1

    self.on_ground = false
    self.on_ceil = false
    self.on_wall = false
    self.on_wall_left = false
    self.on_wall_right = false
    
    self.on_ground_prev = false
    
    self.jump_down_one_way = false
    self.stick_moving_ground = true
    self.stick_moving_wall_left = false
    self.stick_moving_wall_right = false
    self.stick_moving_ceil = false

end

function Actor:move_and_collide(delta)
    local world = self:get_physics_world()
    assert(world, "Actor must be in a tree")

    self.on_ground_prev = self.on_ground

    self.on_ground = false
    self.on_ceil = false
    self.on_wall = false
    self.on_wall_left = false
    self.on_wall_right = false

    world:move_actor(self, delta)
    
    self.jump_down_one_way = false
end

function Actor:get_aabb_extents()
    return self.aabb_extents:clone()
end

function Actor:set_aabb_extents(ext)
    self.aabb_extents = ext:clone()
end

function Actor:get_aabb_offset()
    return self.aabb_offset:clone()
end

function Actor:set_aabb_offset(offset)
    self.aabb_offset = offset:clone()
end

function Actor:get_bounding_box()
    local gpos = self:get_global_position() + self.aabb_offset
    local rmin = gpos - self.aabb_extents
    local rmax = gpos + self.aabb_extents
    return rmin, rmax
end

function Actor:hit_point(point)
    local rmin, rmax = self:get_bounding_box()
    return intersect.point_aabb(point, rmin, rmax)
end

function Actor:update_physics_position()
    local world = self:get_physics_world()
    assert(world, "Actor must be in a tree")
    world:update_collidable_position(self)
end

function Actor:hit_rect(rmin, rmax)
    local bmin, bmax = self:get_bounding_box()
    return intersect.aabb_aabb(rmin, rmax, bmin, bmax)
end

function Actor:draw_collision()
    local rectmin, rectmax = self:get_bounding_box()
    local dim = rectmax - rectmin

    love.graphics.push("all")
    love.graphics.setColor(160/255, 201/255, 115/255, 0.3)
    love.graphics.rectangle("fill", rectmin.x, rectmin.y, dim.x, dim.y)
    love.graphics.pop()
end

function Actor:crushed() 
    log.info(tostring(self) .. " was crushed")
end

return Actor