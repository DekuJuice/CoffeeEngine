--[[

MIT License

Copyright (c) 2020 DekuJuice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

local Node2d = require("class.engine.Node2d")
local Collidable = Node2d:subclass("Collidable")
Collidable.static.noinstance = true
Collidable.static.icon = IconFont and IconFont.SQUARE
Collidable:export_var("collision_layer", "bitmask", {default = 1, bits = 16})
Collidable:export_var("collision_mask", "bitmask", {default = 1, bits = 16})

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