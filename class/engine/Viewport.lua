local Object = require("class.engine.Object")
local Viewport = Object:subclass("Viewport")

local MIN_ZOOM = 0.5
local MAX_ZOOM = 8.0

Viewport:define_get_set("scale")
Viewport:define_get_set("position")
Viewport:define_get_set("background_color")

function Viewport:initialize(w, h)
    Object.initialize(self)
    self.canvas = love.graphics.newCanvas(w, h)
    self.position = vec2(0, 0)
    self.scale = 1
    self.background_color = {0,0,0,0}
end

function Viewport:set_resolution(w, h)
    local cw, ch = self.canvas:getDimensions()
    if w ~= cw or h ~= ch then
        self.canvas = love.graphics.newCanvas(w, h)
    end
end

function Viewport:get_resolution()
    return self.canvas:getDimensions()
end

function Viewport:set_scale(scale)
    self.scale = math.min(math.max(scale, MIN_ZOOM), MAX_ZOOM)
end

function Viewport:set()
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.translate(-self.position.x, -self.position.y)
    love.graphics.scale(self.scale)
end

function Viewport:clear()
    love.graphics.clear(self.background_color)
end

function Viewport:unset()
    love.graphics.pop()
end

function Viewport:get_canvas()
    return self.canvas
end

-- Converts a point from being relative to the viewport to relative to the world
function Viewport:transform_to_world(point)
    return (point + self.position) / self.scale
end

-- Converts a point from being relative to the world to relative to the viewport
function Viewport:transform_to_viewport(point)
    return (point * self.scale) - self.position
end

-- Returns bounds in world coordinates
function Viewport:get_bounds()
    return self:transform_to_world(vec2.zero), self:transform_to_world(vec2( self.canvas:getDimensions() ) )
end

return Viewport