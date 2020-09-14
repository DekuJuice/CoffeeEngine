local intersect = require("enginelib.intersect")

local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")

local Node2dPlugin = Node:subclass("Node2dPlugin")
Node2dPlugin.static.dontlist = true

local function traverse_nodes(root)
    local n = {}
    local stack = {root}
    while #stack > 0 do
        local top = table.remove(stack)
        table.insert(n, top)
        
        local children = top:get_children()
        for i = #children, 1, -1 do
            local c = children[i]
            table.insert(stack, c)
        end
        
    end
    
    return n
end

function Node2dPlugin:initialize()
    Node.initialize(self)
    
    self.dragging = false
    self.selecting = false
    
    self.select_anchor = vec2()
    self.select_cursor = vec2()

    self.drag_anchor = vec2()
    self.prev_drag_anchor = vec2()
end

-- Selection rect is in world coordinates
function Node2dPlugin:get_selection_rect()
    local ax, ay =  self.select_anchor:unpack()
    local cx, cy = self.select_cursor:unpack()
        
    local xmin = math.min(ax, cx)
    local ymin = math.min(ay, cy)
    local xmax = math.max(ax, cx)
    local ymax = math.max(ay, cy)
    
    
    return vec2(xmin, ymin), vec2(xmax, ymax)
end

-- Selected nodes are guranteed to be ordered such that
-- the index of any children are hiegher than their parents
function Node2dPlugin:update_selection()
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    
    local rmin, rmax = self:get_selection_rect()
    
    local selected = {}
    
    for _,c in ipairs( traverse_nodes(model:get_tree():get_root())) do
        if c:is_visible_in_tree() 
        and c:isInstanceOf(Node2d)
        and c:hit_rect(rmin, rmax) then
            table.insert(selected, c)
        end
    end

    model:set_selected_nodes(selected)    
end

function Node2dPlugin:drag_nodes() 
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    local cmd = model:create_command("Move Node2d", "merge_ends")
    
    local delta = self.drag_anchor - self.prev_drag_anchor
    self.prev_drag_anchor = self.drag_anchor:clone()
    
    local selection = model:get_selected_nodes()
    local new_positions = {}
    local old_positions = {}

    -- Selected nodes may be parents or children of each other,
    -- so we calculate their final positions before moving any.
    
    -- We know that parents will always have a lower index than their
    -- children, so we can don't need to worry about their global position
    -- causing children whose positions were already set to be updated
    for _,c in ipairs(selection) do
        if c:isInstanceOf(Node2d) then
            table.insert(old_positions, {c, c:get_global_position() })
            table.insert(new_positions, {c, c:get_global_position() + delta})
        end
    end
    
    cmd:add_do_func(function() 
        for _,np in ipairs(new_positions) do
            np[1]:set_global_position(np[2])
        end
    end)
    
    cmd:add_undo_func(function()
        for _,op in ipairs(old_positions) do
            op[1]:set_global_position(op[2])
        end
    end)
    
    model:commit_command(cmd)

end

function Node2dPlugin:update(dt)

    if self.selecting then
        if not love.mouse.isDown(1) then
            self:update_selection()
            self.selecting = false
        end
    elseif self.dragging then
        local editor = self:get_parent()
        local model = editor:get_active_scene_model()
        if not love.mouse.isDown(1) then
            local cmd = model:create_command("Move Node2d")
            local global_pos = {}
            for _,obj in ipairs(model:get_selected_nodes()) do
                if obj:isInstanceOf(Node2d) then
                    table.insert(global_pos, {obj, obj:get_global_position()})
                end
            end
            
            cmd:add_do_func(function()
                for _, gp in pairs(global_pos) do
                    gp[1]:set_global_position(gp[2])
                end
            end)
            
            model:commit_command(cmd)
            self.dragging = false
        end

    end
end

function Node2dPlugin:draw()
    local editor = self:get_parent()
    
    -- Draw selection rect
    if self.selecting then
        local rmin, rmax = self:get_selection_rect()
        
        rmin = editor:transform_to_screen(rmin)
        rmax = editor:transform_to_screen(rmax)

        local dim = rmax - rmin
        
        love.graphics.push("all")
        
        love.graphics.setColor(118/255, 207/255, 255/255, 0.18)
        love.graphics.rectangle("fill", rmin.x, rmin.y, dim:unpack())
        love.graphics.setColor(118/255, 207/255, 255/255, 1)
        love.graphics.rectangle("line", rmin.x + 0.5, rmin.y + 0.5, dim:unpack())
        
        love.graphics.pop()
    end
    
    -- Draw gizmos for node2ds
    local model = editor:get_active_scene_model()    
    
    for _,c in ipairs(traverse_nodes(model:get_tree():get_root())) do
        if c:is_visible_in_tree()
        and c:isInstanceOf(Node2d)  then
            local sp = editor:transform_to_screen(c:get_global_position())
            local sw, sh = self:get_tree():get_viewport():get_resolution()
            
            if sp.x > 0 and sp.x < sw and sp.y > 0 and sp.y < sh then
               
                love.graphics.push("all")
                
                if model:is_selected(c) then
                    love.graphics.setColor(1,1,1,1)
                else      
                    love.graphics.setColor(0, 0, 0, 1)
                end
                
                love.graphics.circle("line", sp.x, sp.y, 5)                
                love.graphics.rectangle("line", sp.x-2, sp.y-9, 4, 18)
                love.graphics.rectangle("line", sp.x-9, sp.y-2, 18, 4)
                love.graphics.setBlendMode("replace")
                
                if model:is_selected(c) then
                    love.graphics.setColor(255/255, 119/255, 119/255, 0.7)
                else
                    love.graphics.setColor(220/255, 220/255, 220/255, 0.3)
                end
                
                love.graphics.rectangle("fill", sp.x-1, sp.y-8, 2, 16)
                love.graphics.rectangle("fill", sp.x-8, sp.y-1, 16, 2)
                love.graphics.circle("fill", sp.x, sp.y, 3)
                
                love.graphics.pop()
               
            end
        end
    end
end

function Node2dPlugin:mousemoved(x, y, dx, dy)
    local editor = self:get_parent()
    
    local wpoint = editor:transform_to_world(vec2(x, y))
    
    if self.selecting then
        self.select_cursor = wpoint
    elseif self.dragging then
        wpoint.x = math.floor(wpoint.x)
        wpoint.y = math.floor(wpoint.y)
        self.drag_anchor = wpoint        
        
        self:drag_nodes()
    end
end

function Node2dPlugin:mousepressed(x, y, button)
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    
    if button == 1 then

        local node_hit = false
        local wpoint = editor:transform_to_world(vec2(x, y))
        
        -- check if we hit any already selected nodes
        for _,c in ipairs(model:get_selected_nodes()) do
            if c:is_visible_in_tree() and c:isInstanceOf(Node2d) and c:hit_point(wpoint) then
                node_hit = true
                break
            end
        end
        
        -- Otherwise see if we hit any others
        if not node_hit then
            local nodes = traverse_nodes(model:get_tree():get_root())
            for i = #nodes, 1, -1 do
                local c = nodes[i]
                if c:is_visible_in_tree() 
                and c:isInstanceOf(Node2d) 
                and c:hit_point( wpoint ) then
                    model:set_selected_nodes({c})
                    node_hit = true
                    break
                end
            end
        end

        if node_hit then
            self.dragging = true
            wpoint.x = math.floor(wpoint.x)
            wpoint.y = math.floor(wpoint.y)
            self.drag_anchor = wpoint
            self.prev_drag_anchor = wpoint:clone() 
        else
            self.selecting = true
            self.select_anchor = wpoint
            self.select_cursor = wpoint:clone()
            model:set_selected_nodes({})
        end
    end
end

return Node2dPlugin