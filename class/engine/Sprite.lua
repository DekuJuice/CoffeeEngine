local intersect = require("enginelib.intersect")

local Node2d = require("class.engine.Node2d")
local Sprite = Node2d:subclass("Sprite")
local Texture = require("class.engine.resource.Texture")

Sprite:export_var("texture", "resource", {resource_type=Texture})
Sprite:export_var("offset", "vec2" )
Sprite:export_var("scale", "vec2", {speed = 0.01, min = 0, max=8, merge_mode = "merge_ends"} )
Sprite:export_var("rotation", "float", {speed = 0.01, min=-math.pi * 2, max=math.pi * 2, merge_mode = "merge_ends"} )
Sprite:export_var("flip_h", "bool")
Sprite:export_var("flip_v", "bool")
Sprite:export_var("color", "color")
Sprite:export_var("viewport_pos", "vec2", {min = -math.huge, max = math.huge, merge_mode = "merge_ends"} )
Sprite:export_var("viewport_dimensions", "vec2", {min = 0, max = math.huge, merge_mode = "merge_ends"} )

Sprite:binser_register()

function Sprite:initialize()
    Node2d.initialize(self)
    self.offset = vec2(0, 0)
    self.scale = vec2(1, 1)
    self.flip_h = false
    self.flip_v = false
    self.rotation = 0
    self.color = {1,1,1,1}
    self.viewport_pos = vec2(0, 0)
    self.viewport_dimensions = vec2(0, 0)
    self.quad = love.graphics.newQuad(0, 0, 0, 0, 0, 0)
end

function Sprite:_update_quad()
    if self.texture then
        local sw, sh = self.texture:get_love_image():getDimensions()
        self.quad:setViewport(
            self.viewport_pos.x, self.viewport_pos.y, 
            self.viewport_dimensions.x, self.viewport_dimensions.y,
            sw, sh
        )
    end
end

function Sprite:set_viewport_pos(pos)
    self.viewport_pos = pos
    self:_update_quad()
end

function Sprite:set_viewport_dimensions(dim)
    self.viewport_dimensions = dim
    self:_update_quad()
end

function Sprite:set_texture(texture)
    self.texture = texture
    if texture then
        self.viewport_pos = vec2(0, 0)
        self.viewport_dimensions = vec2( texture:get_love_image():getDimensions())
        self:_update_quad()
    end
end

function Sprite:draw()
    if self.texture then
        local image = self.texture:get_love_image()
        local pos = self:get_global_position()
        local scale = self.scale:clone()
        local offset = self.offset:clone()

        if self.flip_h then scale.x = scale.x * -1 end
        if self.flip_v then scale.y = scale.y * -1 end
        
        offset = offset + self.viewport_dimensions / 2
        
        love.graphics.push("all")
        love.graphics.setColor(self.color)
        love.graphics.draw(image, self.quad, pos.x, pos.y, self.rotation, scale.x, scale.y, offset.x, offset.y)
        love.graphics.pop()
    end
end

function Sprite:hit_point(point)
    if self.texture then
        local image = self.texture:get_love_image()
        local dim = self.viewport_dimensions * self.scale
        local origin = self:get_global_position() + self.offset
        
        -- Rotate point about origin to account for sprite rotation
        point = point - origin
        point = point:rotate(self.rotation)
        point = point + origin
        
        return intersect.point_aabb(point, origin - dim / 2, origin + dim / 2)
    else
        return Node2d.hit_point(self, point)
    end
end

function Sprite:hit_rect(rmin, rmax)
    if self.texture then
        local image = self.texture:get_love_image()
        local dim = self.viewport_dimensions * self.scale
        local origin = self:get_global_position() + self.offset
        
        local poly = {
            vec2(-dim.x / 2, -dim.y / 2),
            vec2(dim.x / 2, -dim.y / 2),
            vec2(dim.x / 2, dim.y / 2),
            vec2(-dim.x / 2, dim.y / 2)
        }
        
        for i, p in ipairs(poly) do
            poly[i] = poly[i]:rotate(self.rotation) + origin
        end
        
        local rpoly = {
            vec2(rmin.x, rmin.y),
            vec2(rmax.x, rmin.y),
            vec2(rmax.x, rmax.y),
            vec2(rmin.x, rmax.y)
        }
        
        return intersect.polygon_polygon( rpoly, poly)
    else
        return Node2d.hit_rect(self, rmin, rmax)
    end
end

return Sprite
