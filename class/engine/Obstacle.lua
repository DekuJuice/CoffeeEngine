local intersect = require("enginelib.intersect")

local Collidable = require("class.engine.Collidable")
local Obstacle = Collidable:subclass("Obstacle")

Obstacle:export_var("aabb_extents", "vec2", {speed = 0.2, merge_mode = "merge_ends", min = 0, max = math.huge} )
Obstacle:export_var("one_way", "bool")
Obstacle:export_var("heightmap", "array", {merge_mode = "merge_ends"})
Obstacle:export_var("flip_h", "bool")
Obstacle:export_var("flip_v", "bool")

Obstacle:binser_register()

function Obstacle:initialize()
    Collidable.initialize(self)
    
    self.aabb_extents = vec2(32, 8)
    self.one_way = false
    self.heightmap = {}    
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

function Obstacle:get_height(xoffset)
    local w = self.aabb_extents.x * 2
    local n = #self.heightmap
    
    if n == 0 then return self.aabb_extents.y * 2 end
    
    local nearest = math.floor(xoffset / w * n) + 1
    nearest = math.clamp(nearest, 1, n)
    
    if self.flip_h then
        nearest = n - nearest + 1
    end
    
    return self.heightmap[nearest]    
end

function Obstacle:draw_collision()
    local rectmin, rectmax = self:get_bounding_box()
    local dim = rectmax - rectmin
            
    love.graphics.push("all")
    love.graphics.setColor(210/255, 165/255, 242/255, 0.3)
    love.graphics.setLineStyle("rough")
    local hm = self:get_heightmap()
    local count = #hm
    if count > 0 then
        for x = 0, dim.x - 1 do
            local h = self:get_height(x)
            
            if self.flip_v then
                love.graphics.line(rectmin.x + x + 0.5, rectmin.y, rectmin.x + x + 0.5, rectmin.y + h)
            else
                love.graphics.line(rectmin.x + x + 0.5, rectmax.y - h, rectmin.x + x + 0.5, rectmax.y)
            end
        end
    else
        love.graphics.rectangle("fill", rectmin.x, rectmin.y, dim.x, dim.y)
    end
    love.graphics.pop()
end

return Obstacle