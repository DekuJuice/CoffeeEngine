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

function CollidablePlugin:update(dt)
    local editor = self:get_parent()
    
    local model = editor:get_active_scene_model()
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
        
        local merge_mode = "merge_ends"
        if not love.mouse.isDown(1) then            
            self.dragging = false
            merge_mode = nil
        end
        
        local cmd = model:create_command("Edit Extents", merge_mode)
        cmd:add_do_var(selected, "aabb_extents", aabb_extents)
        cmd:add_undo_var(selected, "aabb_extents", selected:get_aabb_extents())
        
        model:commit_command(cmd)
        
    end
end

function CollidablePlugin:draw()
    local editor = self:get_parent()
    
    local model = editor:get_active_scene_model()
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
    local model = editor:get_active_scene_model()
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