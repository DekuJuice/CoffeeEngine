local scaledraw = require("enginelib.scaledraw")

local Object = require("class.engine.Object")
local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")
local Viewport = require("class.engine.Viewport")
local PhysicsWorld = require("class.engine.PhysicsWorld")
local PackedScene = require("class.engine.resource.PackedScene")

local SceneTree = Object:subclass("SceneTree")
SceneTree:define_get_set("scale_mode")
SceneTree:define_get_set("debug_draw_physics")
SceneTree:define_get_set("is_editor")

function SceneTree:initialize()
    Object.initialize(self)
    -- Scenetree can only have 1 root node
    self.root = Node()
    self.root:set_name("root")
    self.current_scene = nil
    
    self.viewport = Viewport(800, 600)
    self.scale_mode = "aspect"
    self.physics_world = PhysicsWorld()
    self.debug_draw_physics = false
    self.is_editor = false

    self.root:_set_tree(self)
end

function SceneTree:create_autoload_scenes()
    -- Create autoloads
    for _, path in ipairs(settings.get_setting("autoload_scenes")) do
        local as = resource.get_resource( path )
        assert(as, ("Failed to get autoload %s"):format(path))
        assert(as:isInstanceOf(PackedScene), ("Invalid autoload %s"):format(path) )
        
        local instance = as:instance()
        
        self.root:add_child( instance )
    end
end

function SceneTree:get_physics_world()
    return self.physics_world
end

function SceneTree:set_current_scene(scene)
    if self.current_scene then
        self.root:remove_child(self.current_scene)
    end
    
    self.current_scene = scene
    
    if self.current_scene then
        self.root:add_child(self.current_scene)
    end    
end

function SceneTree:get_current_scene()
    return self.current_scene
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
        if node:get_tree() == self then
            node:event("update", dt)
        end
    end
    
    for _, node in ipairs(self:_traverse()) do
        if node:get_tree() == self then
            node:event("physics_update", dt)
        end
    end
    
    self.physics_world:physics_update(dt)
end

function SceneTree:editor_update(dt)
    for _,node in ipairs(self:_traverse()) do
        node:event("editor_update", dt)
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
    
    for _,node in ipairs(self:_traverse()) do
        if node:get_visible() and node:get_tree() == self then
            node:event("draw")
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