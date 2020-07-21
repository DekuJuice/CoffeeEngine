local intersect = require("enginelib.intersect")

local Collidable = require("class.engine.Collidable")
local Actor = Collidable:subclass("Actor")
Actor:export_var("aabb_extents", "vec2", {speed = 0.2, merge_mode = "merge_ends", min = 0, max = math.huge} )
Actor:export_var("aabb_offset", "vec2", {speed = 0.2, merge_mode = "merge_ends", min = -math.huge, max = math.huge})

Actor:define_get_set("on_ground")
Actor:define_get_set("on_ceil")
Actor:define_get_set("on_wall")
Actor:define_get_set("on_slope")

Actor:binser_register()

function Actor:initialize()
    Collidable.initialize(self)
    self.aabb_extents = vec2(8, 16)
    self.aabb_offset = vec2(0, 0)
    
    self.on_ground = false
    self.on_ceil = false
    self.on_wall = false
    self.on_slope = false
end

function Actor:move_and_collide(delta, cling_dist)
    local world = self:get_physics_world()
    assert(world, "Actor must be in a tree")
    
    world:move_actor(self, delta, cling_dist)
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

function Actor:hit_rect(rmin, rmax)
    local bmin, bmax = self:get_bounding_box()
    return intersect.aabb_aabb(rmin, rmax, bmin, bmax)
end

return Actor