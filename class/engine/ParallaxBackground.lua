local Sprite = require("class.engine.Sprite")

local ParallaxBackground = Sprite:subclass("ParallaxBackground")
ParallaxBackground:export_var("scroll_factor", "vec2_float", {min=-2, max=2, speed=0.01} )
ParallaxBackground:binser_register()

function ParallaxBackground:initialize()
    Sprite.initialize(self)
    self.scroll_factor = vec2(1, 1)
end

function ParallaxBackground:get_scroll_factor() return self.scroll_factor:clone() end
function ParallaxBackground:set_scroll_factor(f) self.scroll_factor = f:clone() end

function ParallaxBackground:draw()

    if self.texture then
        local viewport = self:get_tree():get_viewport()
        
        local image = self.texture:get_love_image()
        local pos = self:get_global_position()
        local scale = self.scale:clone()
        local offset = self.offset:clone()
        
        if self.flip_h then scale.x = scale.x * -1 end
        if self.flip_v then scale.y = scale.y * -1 end
        
        offset = offset + self.viewport_dimensions / 2

        offset.x = math.floor(offset.x)
        offset.y = math.floor(offset.y)
        
        local scroll_base = (pos - viewport:get_position() / viewport:get_scale())
        local scroll_offset = (scroll_base - scroll_base * self.scroll_factor)
        scroll_offset.x = math.floor(scroll_offset.x)
        scroll_offset.y = math.floor(scroll_offset.y)
        
        self.quad:setViewport(
            self.viewport_pos.x + scroll_offset.x, self.viewport_pos.y + scroll_offset.y, 
            self.viewport_dimensions.x, self.viewport_dimensions.y,
            image:getDimensions()
        )
        
        love.graphics.push("all")
        love.graphics.setColor(self.color)
        love.graphics.draw(image, self.quad, pos.x, pos.y, self.rotation, scale.x, scale.y, offset.x, offset.y)
        love.graphics.pop()
    end
end



return ParallaxBackground