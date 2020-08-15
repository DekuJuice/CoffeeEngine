local Node2d = require("class.engine.Node2d")
local Collidable = Node2d:subclass("Collidable")
Collidable.static.noinstance = true

Collidable:export_var("collision_layer", "bitmask", {bits = 16})
Collidable:export_var("collision_mask", "bitmask", {bits = 16})

function Collidable:initialize()
    Node2d.initialize(self)
    self.collision_layer = 1
    self.collision_mask = 1
end

function Collidable:get_physics_world()
    local tree = self:get_tree()
    if tree then
        return tree:get_physics_world()
    end
end

function Collidable:enter_tree()
    local tree = self:get_tree()
    local world = tree:get_physics_world()
    world:add_collidable(self)
end

function Collidable:exit_tree()
    local tree = self:get_tree()
    local world = tree:get_physics_world()
    world:remove_collidable(self)
end

function Collidable:editor_enter_tree()
    local tree = self:get_tree()
    local world = tree:get_physics_world()
    world:add_collidable(self)
end

function Collidable:editor_exit_tree() 
    local tree = self:get_tree()
    local world = tree:get_physics_world()
    world:remove_collidable(self)
end

function Collidable:get_bounding_box()
    error("Unimplemented function")
end

return Collidable