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

local Color = require("class.engine.Color")
local intersect = require("enginelib.intersect")
local Node2d = require("class.engine.Node2d")
local Sprite = Node2d:subclass("Sprite")
Sprite.static.icon = IconFont and IconFont.IMAGE

local Texture = require("class.engine.resource.Texture")

Sprite:export_var("texture", "resource", {resource_type=Texture})
Sprite:export_var("offset", "vec2_int", {default = vec2(0, 0)} )
Sprite:export_var("scale", "vec2", {default = vec2(1, 1), speed = 0.01, min = 0, max=8} )
Sprite:export_var("rotation", "float", {default = 0, speed = 0.01, min=-math.pi * 2, max=math.pi * 2} )
Sprite:export_var("flip_h", "bool", {default = false})
Sprite:export_var("flip_v", "bool", {default = false})
Sprite:export_var("color", "color")
Sprite:export_var("viewport_pos", "vec2_int", {default = vec2(0, 0), min = -math.huge, max = math.huge} )
Sprite:export_var("viewport_dimensions", "vec2_int", {default = vec2(16, 16), min = 0, max = math.huge} )

function Sprite:initialize()
    Node2d.initialize(self)
    self.offset = vec2(0, 0)
    self.scale = vec2(1, 1)
    self.flip_h = false
    self.flip_v = false
    self.rotation = 0
    self.color = Color()
    self.viewport_pos = vec2(0, 0)
    self.viewport_dimensions = vec2(16, 16)
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

function Sprite:set_offset(offset)
    self.offset = offset:clone()
end

function Sprite:get_offset()
    return self.offset:clone()
end

function Sprite:set_scale(scale)
    self.scale = scale:clone()
end

function Sprite:get_scale()
    return self.scale:clone()
end

function Sprite:set_viewport_pos(pos)
    self.viewport_pos = pos:clone()
    self:_update_quad()
end

function Sprite:get_viewport_pos()
    return self.viewport_pos:clone()
end

function Sprite:set_viewport_dimensions(dim)
    self.viewport_dimensions = dim:clone()
    self:_update_quad()
end

function Sprite:get_viewport_dimensions()
    return self.viewport_dimensions:clone()
end

function Sprite:set_texture(texture)
    self.texture = texture
    if texture then
        self:_update_quad()
    end
end

function Sprite:set_color(col)
    self.color = col
end

function Sprite:get_color(col)
    return self.color
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
        offset.x = math.floor(offset.x)
        offset.y = math.floor(offset.y)
        
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
