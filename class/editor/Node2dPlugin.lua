local vec2 = require("enginelib.vec2")
local tableutil = require("enginelib.tableutil")

local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")

local Node2dPlugin = Node:subclass("Node2dPlugin")
Node2dPlugin.static.dontlist = true

function Node2dPlugin:initialize()
    Node.initialize(self)
    
    self.dragging = false
    self.selecting = false
    
    self.select_anchor = vec2()
    self.select_cursor = vec2()

    self.drag_anchor = vec2()
    self.prev_drag_anchor = vec2()
    
    self.position_cache = {}
end

-- Selection rect is in world coordinates
function Node2dPlugin:get_selection_rect()
    local ax, ay =  self.select_anchor:unpack()
    local cx, cy = self.select_cursor:unpack()
        
    local w = math.abs(ax - cx)
    local h = math.abs(ay - cy)
    
    local x = math.min(ax, cx)
    local y = math.min(ay, cy)
    
    return x, y, w, h
end

function Node2dPlugin:update_selection()
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    
    local x,y,w,h = self:get_selection_rect()
    
    local selected = {}
    
    for _,c in ipairs(model:get_tree():_traverse()) do
        if c:isInstanceOf(Node2d) then
            local cx, cy = c:get_global_position():unpack()
            
            if c:hit_rect(x, y, w, h) then
                table.insert(selected, c)
            end
        end
    end

    model:set_selected_nodes(selected)    
end

function Node2dPlugin:drag_nodes() 
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    
    local delta = self.drag_anchor - self.prev_drag_anchor
    self.prev_drag_anchor = vec2(self.drag_anchor)
    
    local selection = model:get_selected_nodes()
    local new_positions = {}

    -- Selected nodes may be parents or children of each other,
    -- so we calculate their final positions before moving any
    for _,c in ipairs(selection) do
        if c:isInstanceOf(Node2d) then
            table.insert(new_positions, {c, c:get_global_position() + delta})
        end
    end
    
    for _,np in ipairs(new_positions) do
        np[1]:set_global_position(np[2])
    end
end

function Node2dPlugin:update(dt)

    if self.selecting then
        if not love.mouse.isDown(1) then
            self:update_selection()

            self.selecting = false
        end
    elseif self.dragging then
        if not love.mouse.isDown(1) then
            -- Commit action
            local editor = self:get_parent()
            local model = editor:get_active_scene()
            
            local current_positions = {}
            for _,c in ipairs(model:get_selected_nodes()) do
                if c:isInstanceOf(Node2d) then
                    table.insert(current_positions, {c, c:get_global_position()})
                end
            end
            local old_positions = tableutil.copy(self.position_cache)
            
            model:start_command("Move Nodes", false)
            
            model:add_do_function(function()
            
                for _,cp in ipairs(current_positions) do
                    cp[1]:set_global_position(cp[2])
                end
            end)
            
            model:add_undo_function(function()
                for _,cp in ipairs(old_positions) do
                    cp[1]:set_global_position(cp[2])
                end
            end)
            
            
            
            model:end_command()
            
            
            self.dragging = false
        end
    end
end

function Node2dPlugin:draw()
    local editor = self:get_parent()
    
    -- Draw selection rect
    if self.selecting then
        local x, y, w, h = self:get_selection_rect()
        
        x, y = editor:transform_to_screen(x, y)
        w, h = editor:transform_to_screen(w, h)
        
        local wo, ho = editor:transform_to_screen(0, 0)
        
        w = w - wo
        h = h - ho
        
        love.graphics.push("all")
        
        love.graphics.setColor(118/255, 207/255, 255/255, 0.18)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(118/255, 207/255, 255/255, 1)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w, h)
        
        love.graphics.pop()
    end
    
    -- Draw gizmos for node2ds
    local model = editor:get_active_scene()    
    
    for _,c in ipairs(model:get_tree():_traverse()) do
        if c:isInstanceOf(Node2d) then
            local sx, sy = editor:transform_to_screen(c:get_global_position():unpack())
            
            local sw, sh = self:get_tree():get_viewport():get_resolution()
            
            if sx > 0 and sx < sw and sy > 0 and sy < sh then
               
                love.graphics.push("all")
                
                if model:is_selected(c) then
                    love.graphics.setColor(1,1,1,1)
                else      
                    love.graphics.setColor(0, 0, 0, 1)
                end
                
                
                love.graphics.circle("line", sx, sy, 5)                
                love.graphics.rectangle("line", sx-2, sy-9, 4, 18)
                love.graphics.rectangle("line", sx-9, sy-2, 18, 4)

                love.graphics.setBlendMode("replace")
                
                
                if model:is_selected(c) then
                    love.graphics.setColor(255/255, 119/255, 119/255, 0.7)
                else
                    love.graphics.setColor(220/255, 220/255, 220/255, 0.3)
                end
                
                love.graphics.rectangle("fill", sx-1, sy-8, 2, 16)
                love.graphics.rectangle("fill", sx-8, sy-1, 16, 2)

                love.graphics.circle("fill", sx, sy, 3)
                
                love.graphics.pop()
               
            end
            
        end
    end
end

function Node2dPlugin:mousemoved(x, y, dx, dy)
    local editor = self:get_parent()
    local wx, wy = editor:transform_to_world(x, y)
    if self.selecting then
        self.select_cursor = vec2( wx, wy)
    elseif self.dragging then
        self.drag_anchor = vec2(math.floor(wx), math.floor(wy))
        self:drag_nodes()
    end
end

function Node2dPlugin:mousepressed(x, y, button)
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    
    if button == 1 then

        local node_hit = false
        local wx, wy = editor:transform_to_world(x, y)
        
        -- check if we hit any already selected nodes
        for _,c in ipairs(model:get_selected_nodes()) do
            if c:isInstanceOf(Node2d) and c:hit_point(wx, wy) then
                node_hit = true
                break
            end
        end
        
        -- Otherwise see if we hit any others
        if not node_hit then
            for _,c in ipairs(model:get_tree():_traverse_reverse()) do
                if c:isInstanceOf(Node2d) and c:hit_point( wx, wy ) then
                    model:set_selected_nodes({c})
                    node_hit = true
                    break
                end
            end
        end

        if node_hit then
            self.dragging = true
            self.drag_anchor = vec2(math.floor(wx), math.floor(wy))
            self.prev_drag_anchor = vec2(math.floor(wx), math.floor(wy))
            
            -- Save positions of selected nodes
            self.position_cache = {}
            
            for _,n in ipairs(model:get_selected_nodes()) do
                if n:isInstanceOf(Node2d) then
                    table.insert(self.position_cache, {n, n:get_global_position()})
                end
            end
            
        else
            self.selecting = true
            self.select_anchor = vec2( wx, wy )
            self.select_cursor = vec2( wx, wy )
            model:set_selected_nodes({})
        end
    end
end

return Node2dPlugin