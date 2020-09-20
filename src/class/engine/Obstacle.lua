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

local intersect = require("enginelib.intersect")

local Collidable = require("class.engine.Collidable")
local Obstacle = Collidable:subclass("Obstacle")

Obstacle:export_var("aabb_extents", "vec2_int", {speed = 0.2, min = 0, max = math.huge} )
Obstacle:export_var("heightmap", "array", {array_type = "int", init_value = 0})
Obstacle:export_var("flip_h", "bool")
Obstacle:export_var("flip_v", "bool")

function Obstacle:initialize()
    Collidable.initialize(self)
    
    self.aabb_extents = vec2(32, 8)
    self.heightmap = {}
    self.flip_h = false
    self.flip_v = false
end

function Obstacle:move_and_collide(delta)
    local world = self:get_physics_world()
    assert(world, "Obstacle must be in a tree")

    world:move_obstacle(self, delta)
end

function Obstacle:get_aabb_extents()
    return self.aabb_extents:clone()
end

function Obstacle:set_aabb_extents(ext)
    self.aabb_extents = ext:clone()
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

function Obstacle:get_heightmap()
    return table.copy(self.heightmap)
end

function Obstacle:set_heightmap(heightmap)
    self.heightmap = table.copy(heightmap)
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
        if self:has_tag("one_way") then
            for x = 0, dim.x - 1 do
                local h = self:get_height(x)
                if self.flip_v then
                    
                    love.graphics.rectangle("fill", rectmin.x + x , rectmin.y + h, 1, 1)
                else
                    love.graphics.rectangle("fill", rectmin.x + x , rectmax.y - h, 1, 1)
                end
            end
        else
        
            for x = 0, dim.x - 1 do
                local h = self:get_height(x)
                if self.flip_v then
                    love.graphics.line(rectmin.x + x + 0.5, rectmin.y, rectmin.x + x + 0.5, rectmin.y + h)
                else
                    love.graphics.line(rectmin.x + x + 0.5, rectmax.y - h, rectmin.x + x + 0.5, rectmax.y)
                end
            end
            
        end
    else
        if self:has_tag("one_way") then
            love.graphics.line(rectmin.x, rectmin.y, rectmax.x, rectmin.y)
        else
            love.graphics.rectangle("fill", rectmin.x, rectmin.y, dim.x, dim.y)
        end
    end
    love.graphics.pop()
end

return Obstacle