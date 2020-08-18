local Node = require("class.engine.Node")
local AnimationPlayer = Node:subclass("AnimationPlayer")

AnimationPlayer.static.icon = IconFont and IconFont.FILM

AnimationPlayer:export_var("root_node", "node_path")
AnimationPlayer:export_var("animations", "data")
AnimationPlayer:export_var("autoplay", "bool")
AnimationPlayer:export_var("current_anim", "string")




AnimationPlayer:binser_register()

function AnimationPlayer:initialize()
    Node.initialize(self)
    
    self.root_node = nil
    self.animations = {}
    self.autoplay = false
    self.current_anim = ""
    
end




return AnimationPlayer