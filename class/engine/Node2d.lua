-- Base class for all 2d objects

local HIT_POINT_RADIUS = 12

local intersect = require("enginelib.intersect")
local Node = require("class.engine.Node")
local Node2d = Node:subclass("Node2d")

Node2d:export_var("position", "vec2_int", {speed = 0.2, min = -math.huge, max = math.huge})

Node2d:binser_register()

function Node2d:initialize()
    Node.initialize(self)
    
    self.position = vec2(0, 0)
    self.global_position = vec2(0, 0)
    
    self.position_dirty = true
end

function Node2d:_update_global_position()
    local parent = self:get_parent()
    while parent and not parent:isInstanceOf(Node2d) do
        parent = parent:get_parent()
    end
    
    self.position_dirty = false

    if not parent then
        self.global_position = self.position:clone()
        return
    end
    
    local par_pos = parent:get_global_position()
    self.global_position = self.position + par_pos
end

function Node2d:flag_position_dirty()
    if self.position_dirty then return end
    self.position_dirty = true
    
    -- Need to traverse all children since they may not be node2ds
    
    local stack = {}
    local children = {}
    
    for _,c in ipairs(self.children) do
        if c:isInstanceOf(Node2d) then
            c:flag_position_dirty()
        else
            table.insert(stack, c)
        end
    end
    
    while #stack > 0 do
        local top = table.remove(stack)
        for _,c in ipairs(top.children) do
            if c:isInstanceOf(Node2d) then
                c:flag_position_dirty()
            else
                table.insert(stack, c)
            end
        end
    end
end

function Node2d:translate(delta)
    self:flag_position_dirty()
    self.position = self.position + delta
end

function Node2d:set_position(pos)
    self.position = pos:clone()
    self.position.x = math.round(self.position.x)
    self.position.y = math.round(self.position.y)
    self:flag_position_dirty()
end

function Node2d:get_position()
    return self.position:clone()
end

function Node2d:get_global_position()

    if self.position_dirty or not self:get_parent() then
        self:_update_global_position()
    end

    return self.global_position:clone()
end

function Node2d:set_global_position(pos)
    local cur = self:get_global_position()
    self:set_position(self.position + (pos - cur))
end



-- Returns true if the given point has intersected with the node2d
-- Used for the editor selecting the node
function Node2d:hit_point(point)
    local gp = self:get_global_position()
    
    -- Scale the hit radius according to the zoom so it always
    -- remains the same in screen space
    local scale = 1
    if self:get_tree() then
        scale = self:get_tree():get_viewport():get_scale()
    end
    
    return (point - gp):len() < HIT_POINT_RADIUS / scale
end

function Node2d:hit_rect(rmin, rmax)    
    return intersect.point_aabb(self:get_global_position(), rmin, rmax)
end

return Node2d