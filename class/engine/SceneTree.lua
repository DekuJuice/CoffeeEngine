local scaledraw = require("enginelib.scaledraw")

local Object = require("class.engine.Object")
local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")
local Viewport = require("class.engine.Viewport")
local PhysicsWorld = require("class.engine.PhysicsWorld")

local SceneTree = Object:subclass("SceneTree")
SceneTree:define_get_set("scale_mode")
SceneTree:define_get_set("debug_draw_physics")
SceneTree:define_get_set("is_editor")

function SceneTree:initialize()
    Object.initialize(self)
    -- Scenetree can only have 1 root node
    self.root = nil
    self.viewport = Viewport(800, 600)
    self.scale_mode = "aspect"
    self.physics_world = PhysicsWorld()
    self.debug_draw_physics = false
    self.is_editor = false
end

function SceneTree:destroy()
    Object.destroy(self)
    self.viewport:destroy()
    self.physics_world:destroy()
    if self.root then
        self.root:destroy()
        self.root = nil
    end
end

function SceneTree:get_physics_world()
    return self.physics_world
end

function SceneTree:set_root(root)
    -- Remove reference to self from existing root and children
    if self.root then
        self.root:_set_tree(nil)
    end
    self.root = root
    -- Give reference to self to children
    if self.root then
        self.root:_set_tree(self)
    end
end

function SceneTree:get_root()
    return self.root
end

-- Sets how canvas contents are upscaled to the screen.
-- Uses the same options as enginelib.scaledraw.
function SceneTree:set_scale_mode(mode)
    self.scale_mode = mode
end

function SceneTree:get_viewport()
    return self.viewport
end

function SceneTree:update(dt)
    for _, node in ipairs(self:_traverse()) do
        node:event("update", dt)
    end
    
    for _, node in ipairs(self:_traverse()) do
        node:event("physics_update", dt)
    end
end

-- Iterates over root node in preorder
-- Ex
--[[
-- 1
--  2
--   3
--    4
--    5
--  6
--   7
--  8
]]--
function SceneTree:_traverse()
    
    local stack = {self.root}
    local nodes = {}
    
    while (#stack > 0) do
        local top = table.remove(stack)
        
        table.insert(nodes, top)
        local children = top:get_children()
        for i = #children, 1, -1 do
            table.insert(stack, children[i])
        end
    end
    
    return nodes
end

-- Iterates in reverse preorder
--[[
-- 8
--  7
--   6
--    5
--    4
--  3
--   2
--  1
]]--
function SceneTree:_traverse_reverse()
    local nodes = self:_traverse()
    local n = #nodes
    
    for i = 1, n / 2 do
        local tmp = nodes[i]
        nodes[i] = nodes[n - i + 1]
        nodes[n - i + 1] = tmp
    end
    
    return nodes
end

function SceneTree:render()
    self.viewport:set()
    self.viewport:clear()
        
    local stack = {self.root}
    
    while (#stack > 0) do
        local top = table.remove(stack)
        if top:get_visible() and top:get_tree() == self then
            top:event("draw")
            local children = top:get_children()
            for i = #children, 1, -1 do
                table.insert(stack, children[i])
            end
        end
    end
    
    if self.debug_draw_physics then
        self.physics_world:debug_draw()
    end
        
    self.viewport:unset()
end

function SceneTree:draw(x, y, w, h)

    self:render()
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    
    scaledraw.draw(
        self.viewport:get_canvas(), 
        self.scale_mode, x, y, w, h
    )
    
    love.graphics.pop()
end

-- Event callbacks are all passed in reverse preorder

for _, callback in ipairs({
    "mousepressed",
    "mousereleased",
    "mousemoved",
    "textinput",
    "keypressed",
    "keyreleased",
    "joystickpressed",
    "joystickreleased",
    "joystickaxis",
    "joystickhat",
    "wheelmoved"
}) do
    SceneTree[callback] = function(self, ...)
        for _,node in ipairs(self:_traverse_reverse()) do
            if node:event(callback, ...) then
                return
            end
        end
    end
end

return SceneTree