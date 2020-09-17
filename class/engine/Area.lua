local intersect = require("enginelib.intersect")

local Collidable = require("class.engine.Collidable")
local Area = Collidable:subclass("Area")

Area:define_signal("actor_entered")
Area:define_signal("actor_exited")
Area:define_signal("obstacle_entered")
Area:define_signal("obstacle_exited")
Area:define_signal("area_entered")
Area:define_signal("area_exited")

Area:export_var("aabb_extents", "vec2_int", {speed = 0.2, min = 0, max = math.huge} )
Area:export_var("aabb_offset", "vec2_int", {speed = 0.2, min = -math.huge, max = math.huge})

Area:define_get_set("collide_current")

local _weak_mt = {__mode = "k"}

function Area:initialize()
    Collidable.initialize(self)
    self.aabb_extents = vec2(16, 16)
    self.aabb_offset = vec2(0, 0)
    
    self.collide_current = setmetatable({}, _weak_mt)
end

function Area:get_aabb_extents()
    return self.aabb_extents:clone()
end

function Area:set_aabb_extents(ext)
    self.aabb_extents = ext:clone()
end

function Area:get_aabb_offset()
    return self.aabb_offset:clone()
end

function Area:set_aabb_offset(offset)
    self.aabb_offset = offset:clone()
end

function Area:get_bounding_box()
    local gpos = self:get_global_position() + self.aabb_offset
    local rmin = gpos - self.aabb_extents
    local rmax = gpos + self.aabb_extents
    return rmin, rmax
end

function Area:hit_point(point)
    local rmin, rmax = self:get_bounding_box()
    return intersect.point_aabb(point, rmin, rmax)
end

function Area:update_physics_position()
    local world = self:get_physics_world()
    assert(world, "Area must be in a tree")
    world:update_collidable_position(self)
end

function Area:hit_rect(rmin, rmax)
    local bmin, bmax = self:get_bounding_box()
    return intersect.aabb_aabb(rmin, rmax, bmin, bmax)
end

function Area:draw_collision()
    local rectmin, rectmax = self:get_bounding_box()
    local dim = rectmax - rectmin

    love.graphics.push("all")
    love.graphics.setColor(255/255,92/255,92/255, 0.3)
    love.graphics.rectangle("fill", rectmin.x, rectmin.y, dim.x, dim.y)
    love.graphics.pop()
end


return Area