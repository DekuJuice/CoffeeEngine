local vec2 = require("enginelib.vec2")

local Node2d = require("class.engine.Node2d")
local Sprite = Node2d:subclass("Sprite")
local Texture = require("class.engine.resource.Texture")

Sprite:export_var("texture", "resource", {
    resource_type="Texture",
    filter = function(val)
        return val:isInstanceOf(Texture)
    end
})

Sprite:export_var("offset", "vec2" )
Sprite:export_var("scale", "vec2", {speed = 0.01, min = 0, max=8} )
Sprite:export_var("rotation", "float", {speed = 0.01, min=-math.pi * 2, max=math.pi * 2} )
Sprite:export_var("flip_h", "bool")
Sprite:export_var("flip_v", "bool")

function Sprite:initialize()
    Node2d.initialize(self)
    self.offset = vec2(0, 0)
    self.scale = vec2(1, 1)
    self.flip_h = false
    self.flip_v = false
    self.rotation = 0
end

function Sprite:draw()
    if self.texture then
        local data = self.texture:get_data()
        if data then
            local w, h = data:getDimensions()
            local pos = self:get_global_position()
            local scale = self.scale:clone()
            local offset = self.offset:clone()
            
            if self.flip_h then scale.x = scale.x * -1 end
            if self.flip_v then scale.y = scale.y * -1 end
            offset.x = offset.x + w/2
            offset.y = offset.y + h/2
                        
            love.graphics.draw(data, pos.x, pos.y, self.rotation, scale.x, scale.y, offset.x, offset.y)
        end
    end
end

return Sprite
