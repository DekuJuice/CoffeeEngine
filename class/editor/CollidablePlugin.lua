local ANCHOR_RADIUS = 5

local intersect = require("enginelib.intersect")

local Node = require("class.engine.Node")
local Actor = require("class.engine.Actor")
local Area = require("class.engine.Area")
local Obstacle = require("class.engine.Obstacle")

local CollidablePlugin = Node:subclass("CollidablePlugin")
CollidablePlugin.static.dontlist = true

function CollidablePlugin:initialize()
    Node.initialize(self)
    
    self.drag_anchor = vec2()
    self.drag_pos = vec2()
    self.drag_aabb_corner = 0
    self.dragging = false
    
end

function CollidablePlugin:enter_tree()
    local scene = self:get_parent():get_active_scene()
    
    local node = require("class.engine.Node")()
    scene:add_node(nil, node)
    
    local player = require("class.game.Player")()
    player:set_position(vec2(136, 64))
    scene:add_node("/Node", player)
    scene:set_selected_nodes({player})
    
    local o1 = Obstacle()
    o1:set_aabb_extents(vec2(208, 8))
    o1:set_position(vec2(208, 232))
    scene:add_node("/Node", o1)
    
    local o2 = Obstacle()
    o2:set_aabb_extents(vec2(8, 104))
    o2:set_position(vec2(8, 120))
    scene:add_node("/Node", o2)
    
    local o3 = Obstacle()
    o3:set_aabb_extents(vec2(8, 104))
    o3:set_position(vec2(408, 120))
    scene:add_node("/Node", o3)
    
    local o4 = Obstacle()
    o4:set_aabb_extents(vec2(208, 8))
    o4:set_position(vec2(208, 8))
    scene:add_node("/Node", o4)
    
    local o5 = Obstacle()
    o5:set_aabb_extents(vec2(8, 8))
    o5:set_position(vec2(216, 216))
    o5:set_heightmap({1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16})
    scene:add_node("/Node", o5)
    
    local o6 = Obstacle()
    o6:set_aabb_extents(vec2(8, 8))
    o6:set_position(vec2(48, 216))
    o6:set_heightmap({16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1})
    scene:add_node("/Node", o6)
end

function CollidablePlugin:update(dt)
    local editor = self:get_parent()
    
    local model = editor:get_active_scene()
    local selected = model:get_selected_nodes()[1]
    
    if not selected then return end
    
    if not selected:isInstanceOf(Actor) and not selected:isInstanceOf(Obstacle) then
        return
    end
    
    if self.dragging then
        
        local aabb_extents
        local gp = selected:get_global_position()
        
        if self.drag_aabb_corner == 1 then
            aabb_extents = gp - self.drag_pos
        elseif self.drag_aabb_corner == 2 then
            aabb_extents = vec2(self.drag_pos.x - gp.x, gp.y - self.drag_pos.y)
        elseif self.drag_aabb_corner == 3 then
            aabb_extents = self.drag_pos - gp
        elseif self.drag_aabb_corner == 4 then
            aabb_extents = vec2(gp.x - self.drag_pos.x, self.drag_pos.y - gp.y)
        end
        
        aabb_extents.x = math.floor(aabb_extents.x)
        aabb_extents.y = math.floor(aabb_extents.y)
        
        selected:set_aabb_extents(aabb_extents)
        
        
        if not love.mouse.isDown(1) then
            self.dragging = false
        end
        
    end
end

function CollidablePlugin:draw()
    local editor = self:get_parent()
    
    local model = editor:get_active_scene()
    local selected = model:get_selected_nodes()[1]
    
    if not selected then return end
    
    if not selected:isInstanceOf(Actor) and not selected:isInstanceOf(Obstacle) then
        return
    end
    
    local rmin, rmax = selected:get_bounding_box()
    rmin = editor:transform_to_screen(rmin)
    rmax = editor:transform_to_screen(rmax)
    
    love.graphics.push("all")
    
    love.graphics.circle("line", rmin.x, rmin.y, ANCHOR_RADIUS)
    love.graphics.circle("line", rmax.x, rmin.y, ANCHOR_RADIUS)
    love.graphics.circle("line", rmax.x, rmax.y, ANCHOR_RADIUS)
    love.graphics.circle("line", rmin.x, rmax.y, ANCHOR_RADIUS)
    
    love.graphics.pop()
end

function CollidablePlugin:mousemoved(x, y, dx, dy)
    if self.dragging then
        
        local editor = self:get_parent()
        self.drag_pos =  editor:transform_to_world( vec2(x, y) )
        
        return true
    end
end

function CollidablePlugin:mousepressed(x, y, button, isTouch)
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    if button == 1 then
        local selected = model:get_selected_nodes()[1]
    
        if not selected then return end
        
        if not selected:isInstanceOf(Actor) and not selected:isInstanceOf(Obstacle) then
            return
        end

        local scale = editor:get_active_view():get_scale()
        local wpoint = editor:transform_to_world(vec2(x, y))
        local rmin, rmax = selected:get_bounding_box()
        local hit = false
        
        local points = {
            rmin,
            vec2(rmax.x, rmin.y),
            rmax,
            vec2(rmin.x, rmax.y)
        }
        
        for i,p in ipairs(points) do
            if intersect.point_circle(wpoint, p, ANCHOR_RADIUS / scale) then
                self.dragging = true
                self.drag_aabb_corner = i
                self.drag_anchor = p
                self.drag_pos = wpoint:clone()
                return true
            end
        end
        
    end
end

return CollidablePlugin