local intersect = require("enginelib.intersect")

local Collidable = require("class.engine.Collidable")
local Obstacle = Collidable:subclass("Obstacle")

Obstacle:export_var("aabb_extents", "vec2", {speed = 0.2, merge_mode = "merge_ends", min = 0, max = math.huge} )
Obstacle:export_var("one_way", "bool")


Obstacle:binser_register()

function Obstacle:initialize()
    Collidable.initialize(self)
    
    self.aabb_extents = vec2(32, 8)
    self.one_way = false
    
end

function Obstacle:get_bounding_box()
    local gpos = self:get_global_position()
    local rmin = gpos - self.aabb_extents
    local rmax = gpos + self.aabb_extents
    return rmin, rmax
end

function Obstacle:hit_point(point)
    local rmin, rmax = self:get_bounding_box()
    return intersect.point_aabb(point, rmin, rmax)
end

function Obstacle:hit_rect(rmin, rmax)
    local bmin, bmax = self:get_bounding_box()
    return intersect.aabb_aabb(rmin, rmax, bmin, bmax)
end


return Obstacle