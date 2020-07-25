

local Node = require("class.engine.Node")
local Actor = require("class.engine.Actor")
local Area = require("class.engine.Area")
local Obstacle = require("class.engine.Obstacle")

local CollidablePlugin = Node:subclass("CollidablePlugin")
CollidablePlugin.static.dontlist = true

function CollidablePlugin:initialize()
    Node.initialize(self)
    
    
end

function CollidablePlugin:enter_tree()
    --[[local scene = self:get_parent():get_active_scene()
    
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
    scene:add_node("/Node", o6)]]--
end


return CollidablePlugin