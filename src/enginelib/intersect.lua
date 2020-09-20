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

-- This module contains helpers for various geometric intersection tests
local module = {}

local function line_1d_overlap(min1, max1, min2, max2)
    return math.min(max1, max2) - math.max(min1, min2)
end 

function module.point_aabb(point, rmin, rmax)
    return point.x >= rmin.x
    and point.x <= rmax.x
    and point.y >= rmin.y
    and point.y <= rmax.y
end

function module.aabb_aabb(rmin1, rmax1, rmin2, rmax2)
    return line_1d_overlap( rmin1.x, rmax1.x, rmin2.x, rmax2.x) >= 0
    and line_1d_overlap(rmin1.y, rmax1.y, rmin2.y, rmax2.y) >= 0
end

function module.aabb_aabb_no_touch(rmin1, rmax1, rmin2, rmax2)
    return line_1d_overlap( rmin1.x, rmax1.x, rmin2.x, rmax2.x) > 0
    and line_1d_overlap(rmin1.y, rmax1.y, rmin2.y, rmax2.y) > 0
end

function module.polygon_polygon(p1, p2)
    
    -- Calculate projection axes
    local axes = {}
    
    local p1c = #p1
    local p2c = #p2
    
    for i = 1, p1c do
        local j = i % p1c + 1
        table.insert(axes, (p1[j] - p1[i]):perpendicular())
    end
    
    for i = 1, p2c do
        local j = i % p2c + 1
        table.insert(axes, (p2[j] - p2[i]):perpendicular())
    end

    -- SAT check
    for i,axis in ipairs(axes) do
        local min1 = math.huge
        local min2 = math.huge
        local max1 = -math.huge
        local max2 = -math.huge
        
        for j,p in ipairs(p1) do
            local proj = axis:dot(p)
            
            min1 = math.min(min1, proj)
            max1 = math.max(max1, proj)
        end
        
        for j,p in ipairs(p2) do
            local proj = axis:dot(p)
            min2 = math.min(min2, proj)
            max2 = math.max(max2, proj)
        end
        
        local overlaps = line_1d_overlap(min1, max1, min2, max2) >= 0
        if not overlaps then
            return false
        end
    end
    
    return true
end

function module.point_circle(point, origin, radius)
    return (point - origin):len2() <= (radius ^ 2)
end

return module