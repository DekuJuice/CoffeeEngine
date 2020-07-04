

--[[
local round = math.round
local floor = math.floor
local clamp = math.clamp

local easing = require("lib.easing")
local Camera = require("lib.middleclass")("Camera")

local function new_shake(amp, freq, attack, sustain, release, axis)
    
    local shake = {
        t = 0,
        samples = {},
        amp = amp, -- How far the shake goes
        freq = freq, -- How often the shake "shakes"
        attack = attack, -- How long the shake takes to reach max amp, increasing linearly
        sustain = sustain, -- How long the shake is sustained at max amp
        release = release, -- How long the shake takes to stop, fades out linearly
        axis = axis, -- Axes to shake along
        finished = false
    }
   
    for i = 1, floor( (attack + sustain + release) * freq) do
        shake.samples[i] = love.math.random() * 2 - 1
    end
    
    return shake
end

local function update_shake(shake, dt)
    shake.t = shake.t + dt
    shake.finished = shake.t > shake.attack + shake.sustain + shake.release
end

local function get_shake_displace(shake)
    local i = floor(shake.t * shake.freq)
    local j = i + 1
    
    local t1 = i / shake.freq
    local t2 = j / shake.freq
    
    local s1 = shake.samples[i] or 0
    local s2 = shake.samples[j] or 0
    
    local d = (shake.t - t1) / (t2 - t1) * (s2 - s1) + s1
    
    if shake.attack > 0 and shake.t <= shake.attack then
        local amp = shake.t / shake.attack * shake.amp
        
        return d * amp
    end
    
    if shake.sustain > 0 and shake.t <= shake.attack + shake.sustain then
        return d * shake.amp
    end
    
    if shake.release > 0 and shake.t <= shake.attack + shake.sustain + shake.release then 
        local amp = (1 - (shake.t - shake.sustain - shake.attack) / shake.release) * shake.amp
        return d * amp    
    end
end

local function new_interpolate(ox, oy, ozoom, time, method)
    return {
        x = ox,
        y = oy,
        zoom = ozoom,
        time = 0,
        maxTime = time,
        method = method
    }
end

function Camera:initialize(w, h)
    -- The actual position/zoom of the camera
    self.x = 0
    self.y = 0
    self.zoom = 1
    
    -- Position with camera shakes applied
    self.trueX = 0
    self.trueY = 0

    -- Intended position/zoom of the camera
    self.targetX = 0
    self.targetY = 0
    self.targetZoom = 1
    
    -- 
    self.interp = nil

    self.w = w or love.graphics.getWidth()
    self.h = h or love.graphics.getHeight()
    
    -- Deadzones
    -- Only applied when using :follow(x,y)
    self.deadzone = {
        xmin = self.w/2-16,
        xmax = self.w/2+16,
        ymin = self.h/2-24,
        ymax = self.h/2+24
    }
    
    -- Camera bounds
    self.bounds = {
        xmin = -math.huge,
        xmax = math.huge,
        ymin = -math.huge,
        ymax = math.huge
    }
    
    -- Active shakes
    self.shakes = {}
    
end

function Camera:shake(amp, freq, sustain, release, axes)
    amp = amp or 4
    freq = freq or 60
    sustain = sustain or 0.5
    release = release or 0.2
    axes = axes or "XY"
    
    if axes:find("X") then table.insert(self.shakes, new_shake(amp, freq, sustain, release, "X") ) end
    if axes:find("Y") then table.insert(self.shakes, new_shake(amp, freq, sustain, release, "Y") ) end
end

function Camera:interpolate(time, method)
    time = time or 40/60
    if time > 0 then
        self.interp = new_interpolate(self.x, self.y, self.zoom, time, method or "outQuad")
    end
end

function Camera:cancelInterpolation()
    self.interp = nil
end

function Camera:setDeadzone(xmin, xmax, ymin, ymax)
    self.deadzone.xmin = xmin or self.w/2
    self.deadzone.xmax = xmax or self.w/2
    self.deadzone.ymin = ymin or self.h/2
    self.deadzone.ymax = ymax or self.h/2
end

function Camera:setBounds(xmin, xmax, ymin, ymax)
    self.bounds.xmin = xmin or -math.huge
    self.bounds.xmax = xmax or math.huge
    self.bounds.ymin = ymin or -math.huge
    self.bounds.ymax = ymax or math.huge
end

function Camera:follow(x, y)
    local xmin, ymin = self:cameraToWorld(self.deadzone.xmin, self.deadzone.ymin)
    local xmax, ymax = self:cameraToWorld(self.deadzone.xmax, self.deadzone.ymax)
    
    if x < xmin then
        self.targetX = self.trueX - (xmin - x)
    elseif x > xmax then
        self.targetX = self.trueX - (xmax - x)
    end
    
    if y < ymin then
        self.targetY = self.trueY - (ymin - y)
    elseif y > ymax then
        self.targetY = self.trueY - (ymax - y)
    end    
end

function Camera:setX(x)
    self.targetX = x
end

function Camera:setY(y)
    self.targetY = y
end

function Camera:setPosition(x, y)
    self:setX(x); self:setY(y)
end

function Camera:setZoom(zoom)
    assert(zoom > 0, "Zoom must be greater than 0")
    assert(zoom < math.huge, "Zoom must be finite")
    self.targetZoom = zoom
end

function Camera:zoomTowards(zoom, x, y)
    local oz = self.targetZoom

    local cx = (x * oz) - self.targetX
    local cy = (y * oz) - self.targetY
    
    self:setZoom(zoom)
    
    local nx = (x * self.targetZoom) - self.targetX
    local ny = (y * self.targetZoom) - self.targetY
        
    local ox = (nx - cx)
    local oy = (ny - cy)
    
    self.targetX = self.targetX + ox
    self.targetY = self.targetY + oy
end


function Camera:update(dt)
    
    if self.interp then
        local i = self.interp
        i.time = i.time + dt
        local tx = clamp(self.targetX, self.bounds.xmin, self.bounds.xmax - self.w / self.zoom)
        local ty = clamp(self.targetY, self.bounds.ymin, self.bounds.ymax - self.h / self.zoom)
        self.x = easing[i.method](i.time, i.x, tx - i.x, i.maxTime)
        self.y = easing[i.method](i.time, i.y, ty - i.y, i.maxTime)
        self.zoom = easing[i.method](i.time, i.zoom, self.targetZoom - i.zoom, i.maxTime)
        
        self.x = round(self.x)
        self.y = round(self.y)
        
        if i.time >= i.maxTime then
            self.interp = nil
        end
    else
        self.x = clamp(self.targetX, self.bounds.xmin, self.bounds.xmax - self.w / self.zoom)
        self.y = clamp(self.targetY, self.bounds.ymin, self.bounds.ymax - self.h / self.zoom)
        self.zoom = self.targetZoom
        self.x = floor(self.x)
        self.y = floor(self.y)
    end
    self.trueX = self.x
    self.trueY = self.y
    --camera shakes
    for i = #self.shakes, 1, -1 do
        local s = self.shakes[i]
        update_shake(s, dt)
        
        local d = get_shake_displace(s)
        if s.axis == "X" then
            self.trueX = self.trueX + d
        elseif s.axis == "Y" then
            self.trueY = self.trueY + d
        end
        
        if s.finished then
            table.remove(self.shakes, i)
        end
    end
end


function Camera:set()
    love.graphics.push("all")
    love.graphics.translate(self:getTranslation())
    love.graphics.scale(self.zoom, self.zoom)
end

function Camera:getTranslation()
    return floor(-self.trueX ), floor(-self.trueY)
end

function Camera:unset()
    love.graphics.pop()
end

function Camera:draw()
    love.graphics.push("all")
    local xmin, ymin = self.deadzone.xmin, self.deadzone.ymin
    local xmax, ymax = self.deadzone.xmax, self.deadzone.ymax
    love.graphics.rectangle("line", xmin+.5, ymin+.5, xmax-xmin, ymax-ymin)
    --love.graphics.rectangle("line", self.trueX, self.trueY, self.w / self.targetZoom, self.h / self.targetZoom)
    love.graphics.translate(self.w / 2, self.h / 2)
    love.graphics.print(("Real: %f %f %f"):format(self.x, self.y, self.zoom), 10, 15)
    love.graphics.print(("Target: %f %f %f"):format(self.targetX, self.targetY, self.targetZoom), 10, 30)
    --love.graphics.print(("True: %f %f %f"):format(self.trueX, self.trueY, self.zoom), 10, 45)
    love.graphics.pop()
end

-- Camera Space to World Space
function Camera:cameraXToWorld(x)
    return (self.trueX + x) / self.zoom
end

function Camera:cameraYToWorld(y)
    return (self.trueY + y) / self.zoom
end

function Camera:cameraToWorld(x, y)
    return self:cameraXToWorld(x), self:cameraYToWorld(y)
end

-- World Space to Camera Space

function Camera:worldXToCamera(x)
    return self.zoom * x - self.trueX
end

function Camera:worldYToCamera(y)
    return self.zoom * y - self.trueY  
end

function Camera:worldToCamera(x, y)
    return self:worldXToCamera(x), self:worldYToCamera(y)
end


return Camera]]--