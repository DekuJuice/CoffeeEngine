-- Base class for all 2d objects

local HIT_POINT_RADIUS = 7

local vec2 = require("enginelib.vec2")

local Node = require("class.engine.Node")
local Node2d = Node:subclass("Node2d")

Node2d:export_var("position", "vec2", nil, {speed = 1, min = -math.huge, max = math.huge} )

function Node2d:initialize()
    Node.initialize(self)
    
    self.position = vec2(0, 0)
    self.global_position = vec2(0, 0)
    
    self.position_dirty = false
end

function Node2d:_update_global_position()
    local parent = self:get_parent()
    self.position_dirty = false

    if not parent then
        self.global_position = vec2(self.position)
        return
    end
    
    local par_pos = parent:get_global_position()
    self.global_position = self.position + par_pos
end

function Node2d:flag_as_dirty()
    if self.position_dirty then return end
    self.position_dirty = true
    for _,c in ipairs(self.children) do
        c:flag_as_dirty()
    end
end

function Node2d:set_position(pos)
    self:flag_as_dirty()
    self.position = pos
end

function Node2d:get_position()
    return vec2(self.position)
end

function Node2d:get_global_position()

    if self.position_dirty then
        self:_update_global_position()
    end
    
    return vec2(self.global_position)
end

function Node2d:set_global_position(pos)
    local cur = self:get_global_position()
    self:set_position(self.position + (pos - cur))
end


-- Returns true if the given point has intersected with the node2d
-- Used for the editor selecting the node
function Node2d:hit_point(x, y)
    local gp = self:get_global_position()
    
    -- Scale the hit radius according to the zoom so it always
    -- remains the same in screen space
    local scale = 1
    if self:get_tree() then
        scale = self:get_tree():get_viewport():get_scale()
    end
    
    
    return (vec2(x, y) - gp):len() < HIT_POINT_RADIUS / scale
end

function Node2d:hit_rect(x, y, w, h)

    local cx, cy = self:get_global_position():unpack()
    
    return cx > x and cx < x + w and cy > y and cy < y + h
end

return Node2d