-- Module loosely based off https://github.com/rxi/shash/blob/master/shash.lua
-- MIT License

local module = {}
module.__index = module

local function get_key(x, y)
    return x + y * 1e7
end

function module.new(cellsize)
    local self = setmetatable({}, module)
    
    self.cellsize = cellsize or 64
    self.cells = {}
    self.objects = {}
    
    return self
end

function module:get_cell_position(x, y)
    return math.floor(x / self.cellsize), math.floor(y / self.cellsize)
end

function module:_add_to_cells(obj, x, y, w, h)
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

function module:_remove_from_cells(obj)
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
                        break
                    end
                end
            end
        end
    end
end

function module:add_object(obj, x, y, w, h)
    assert(not self:has_object(obj), "Object is already in hash")
    self.objects[obj] = {x, y, w, h}
    self:_add_to_cells(obj, x, y, w, h)
end

function module:update_object(obj, x, y, w, h)
    assert(self:has_object(obj), "Object is not in hash")
    
    self:_remove_from_cells(obj)
    self:_add_to_cells(obj, x, y, w, h)

    local e = self.objects[obj]
    e[1] = x
    e[2] = y
    e[3] = w
    e[4] = h
end

function module:has_object(obj)
    return self.objects[obj] ~= nil
end

function module:remove_object(obj)
    
    assert(self:has_object(obj), "Object is not in hash")
    self:_remove_from_cells(obj)
    self.objects[obj] = nil

end

function module:get_nearby_in_rect(x, y, w, h)
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

function module:get_nearby_objects(obj)
    assert(self:has_object(obj), "Object is not in hash")
    
    local e = self.objects[obj]
    local x, y, w, h = e[1], e[2], e[3], e[4]
    
    return self:get_in_rect(x, y, w, h)
end

return module