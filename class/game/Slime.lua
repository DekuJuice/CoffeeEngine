
local GRAVITY = settings.get_setting("physics_gravity")
local JUMP_WINDUP = 0.35
local JUMP_FORCE_X = 120
local JUMP_FORCE_Y = 240

local class = require("enginelib.middleclass")

local Actor = require("class.engine.Actor")
local Slime = Actor:subclass("Slime")
Slime:include(require("class.mixin.VelocityHelper"))
Slime:include(require("class.mixin.EnemyAIHelper"))

Slime:export_var("start_hanging", "bool")

-- Slime states: 
-- Ground
-- Air
-- Hanging

local GroundState = class("SlimeGroundState")
function GroundState:initialize()
    self.windup = 0
    self.cooldown = 0
end

local AirState = class("SlimeAirState")
local HangingState = class("SlimeHangingState")

function Slime:initialize()
    
    Actor.initialize(self)
    
    self.start_hanging = false
    self.state = GroundState()
    self.velocity = vec2(0, 0)
    self.velocity_remainder = vec2(0, 0)
    self.direction = 1
end

function Slime:enter_tree()
    Actor.enter_tree(self)
    if self.start_hanging then
        self.state = HangingState()
    else
        self.state = GroundState()
    end
end

function Slime:physics_update(dt)
    if self.state.update then
        local new = self.state:update(self, dt)
        if new then
            if self.state.exit then
                self.state:exit(self)
            end
            self.state = new
        end
    end
end

function Slime:draw()
    local gp = self:get_global_position()
    love.graphics.print(self.state.class.name, gp:unpack())
end


function GroundState:update(slime, dt)

    -- TODO: check player presence and whether slime is onscreen

    slime.velocity.x = 0
    if not slime:is_on_screen() then
        self.windup = 0
    end
    
    self.windup = self.windup + dt
    if self.windup > JUMP_WINDUP then
        self.windup = 0
        slime.velocity.x = -JUMP_FORCE_X
        slime.velocity.y = -JUMP_FORCE_Y
        slime.on_ground = false
    end

    
    
    -- Always move at least 1 pixel down so that we can check if we're still on the ground
    local delta = slime:get_velocity_delta(dt)
    if delta.y == 0 then
        delta.y = 1
    end
    
    slime:move_and_collide( delta )
    
    if not slime.on_ground then
        return AirState()
    end
end

function AirState:update(slime, dt)
    slime.velocity.y = slime.velocity.y + GRAVITY * dt
    slime:move_and_collide(slime:get_velocity_delta(dt))
    
    if slime.on_ground then
        return GroundState()
    end
end


return Slime