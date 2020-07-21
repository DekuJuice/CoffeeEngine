

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
    local scene = self:get_parent():get_active_scene()
    
    local node = require("class.engine.Node")()
    scene:add_node(nil, node)
    
    local actor = require("class.game.TestActor")()
    actor:set_position(vec2(136, 64))
    scene:add_node("/Node", actor)
    scene:set_selected_nodes({actor})
    
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
end


return CollidablePlugin