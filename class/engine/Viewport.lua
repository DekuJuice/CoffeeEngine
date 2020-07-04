local Object = require("class.engine.Object")
local Viewport = Object:subclass("Viewport")

local MIN_ZOOM = 0.5
local MAX_ZOOM = 8.0

local vec2 = require("enginelib.vec2")

Viewport:define_get_set("scale")
Viewport:define_get_set("position")

function Viewport:initialize(w, h)
    self.canvas = love.graphics.newCanvas(w, h)
    self.position = vec2(0, 0)
    self.scale = 1
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
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(-self.position.x, -self.position.y)
    love.graphics.scale(self.scale)
end

function Viewport:unset()
    love.graphics.pop()
end

function Viewport:get_canvas()
    return self.canvas
end

-- Converts a point from being relative to the viewport to relative to the world
function Viewport:transform_to_world(x, y)
    return (x + self.position.x) / self.scale, (y + self.position.y) / self.scale
end

-- Converts a point from being relative to the world to relative to the viewport
function Viewport:transform_to_viewport(x, y)
    return (x * self.scale) - self.position.x, (y * self.scale) - self.position.y
end

return Viewport