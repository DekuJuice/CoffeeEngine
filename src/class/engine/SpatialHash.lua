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

-- Module loosely based off https://github.com/rxi/shash/blob/master/shash.lua
-- MIT License

local class = require("enginelib.middleclass")
local SpatialHash = class("SpatialHash")

local function get_key(x, y)
    return x + y * 1e7
end

function SpatialHash:initialize(cellsize)
    self.cellsize = cellsize or 64
    self.cells = {}
    self.objects = {}
end

function SpatialHash:get_cell_position(x, y)
    return math.floor(x / self.cellsize), math.floor(y / self.cellsize)
end

function SpatialHash:_add_to_cells(obj, x, y, w, h)
    local x1, y1 = self:get_cell_position(x, y)
    local x2, y2 = self:get_cell_position(x + w, y + h)
    for x = x1, x2 do
        for y = y1, y2 do
            local key = get_key(x, y)
            self.cells[key] = self.cells[key] or {}
            table.insert(self.cells[key], obj)                        
        end
    end
end

function SpatialHash:_remove_from_cells(obj)
    local e = self.objects[obj]
    
    local x1, y1 = self:get_cell_position(e[1], e[2])
    local x2, y2 = self:get_cell_position(e[1] + e[3], e[2] + e[4])
    for x = x1, x2 do
        for y = y1, y2 do
            local key = get_key(x, y)
            local cell = self.cells[key]
            local n = #cell
            
            if n == 1 then
                cell[1] = nil
            else
                for i,v in ipairs(cell) do
                    if v == obj then
                        cell[i] = cell[n]       
                        cell[n] = nil
                        break
                    end
                end
            end
            
        end
    end
end

function SpatialHash:add_object(obj, x, y, w, h)
    assert(not self:has_object(obj), "Object is already in hash")
    self.objects[obj] = {x, y, w, h}
    self:_add_to_cells(obj, x, y, w, h)
end

function SpatialHash:update_object(obj, x, y, w, h)
    assert(self:has_object(obj), "Object is not in hash")
    
    self:_remove_from_cells(obj)
    self:_add_to_cells(obj, x, y, w, h)

    local e = self.objects[obj]
    e[1] = x
    e[2] = y
    e[3] = w
    e[4] = h
end

function SpatialHash:has_object(obj)
    return self.objects[obj] ~= nil
end

function SpatialHash:get_objects()
    return self.objects
end

function SpatialHash:remove_object(obj)
    
    assert(self:has_object(obj), "Object is not in hash")
    self:_remove_from_cells(obj)
    self.objects[obj] = nil

end

function SpatialHash:get_nearby_in_rect(x, y, w, h)
    local objs = {}
    local already = {}
    
    local x1, y1 = self:get_cell_position(x, y)
    local x2, y2 = self:get_cell_position(x + w, y + h)
    for x = x1, x2 do
        for y = y1, y2 do
            local key = get_key(x, y)
            local cell = self.cells[key]
            if cell then
                for _,o in ipairs(cell) do
                    if not already[o] then
                        already[o] = true
                        table.insert(objs, o)
                    end
                end
            end
        end
    end
    
    return objs
end

function SpatialHash:get_nearby_objects(obj)
    assert(self:has_object(obj), "Object is not in hash")
    
    local e = self.objects[obj]
    local x, y, w, h = e[1], e[2], e[3], e[4]
    
    return self:get_in_rect(x, y, w, h)
end

function SpatialHash:clear()
    self.cells = {}
    self.objects = {}
end

return SpatialHash