--How long after jumping that a dash can be started
local JUMP_DASH_BUFFER = 3 / 60
--How long after becoming airborne that the player is still allowed to jump
local COYOTE_TIME = 2 / 60
--How long to buffer jump inputs for
local JUMP_BUFFER = 3 / 60
--How long the player is invulnerable after being hit
local INVULN_TIME = 1
--How long the player is unable to move after being hit
local FLINCH_TIME = 24 / 60
--Knockback force of flinching
local FLINCH_KNOCKBACK = vec2(80, 120)
--Friction when sliding on the ground during a flinch
local FLINCH_FRICTION = vec2(800)

-- Max pixels to cling down to for every x pixel moved
local CLING_DIST = 2

-- Player Extents
local AABB_EXTENTS = vec2(7, 16) -- 14x32 pixels, or 0.875 x 2 tiles

local MOVE_SPEED = 120 -- 7.5 tiles / second
local GRAVITY = 900 -- 0.9375 tiles / second^2
local MAX_FALL = 420 -- 26.25 tiles / second

local DASH_SPEED = 210 --13.125 tiles / second
local DASH_FRAMES = 28 / 60
--Dimensions during dash
local DASH_AABB_EXTENTS = vec2(7, 10)

--Initial velocity when wall slide begins
local WALL_SLIDE_START_SPEED = 30 -- 0.03125 tiles / second
local WALL_SLIDE_ACCEL = GRAVITY * 2 -- 1.875 tiles / second^2
local WALL_SLIDE_FALL_MAX = 90 -- 0.09375 tiles / second

--Duration that the player can't move during walljump
local WALL_JUMP_FRAMES = 8
local JUMP_FORCE = 300 -- 0.3125 tiles / second

local input = require("input")

local StateMachine = require("class.engine.StateMachine")

local Actor = require("class.engine.Actor")
local Player = Actor:subclass("Player")

Player:binser_register()

function Player:initialize()
    Actor.initialize(self)
    
    self:set_aabb_extents(AABB_EXTENTS:clone())
    
    self.jump_count = 1
    
    -- Player states:
    -- standing
    -- air
    -- dash
    -- wallslide
    -- death
    self.movement_sm = StateMachine()
    self.movement_sm:set_state("standing")
    
    self.movement_sm:define_event("on_ground", {"air", "wallslide"}, "standing")
    self.movement_sm:define_event("off_ground", {"standing", "wallslide", "dash"}, "air")
    self.movement_sm:define_event("dash_start", "standing", "dash")
    self.movement_sm:define_event("killed", "*", "death")
    
    self.velocity = vec2(0, 0)
end

function Player:physics_update(dt)
    -- Update state
    if self.on_ground then
        self.movement_sm:event("on_ground")
    else
        self.movement_sm:event("off_ground")
    end
    
    if self.on_ground then
        self.jump_count = 1
        self.velocity.y = 0
    end
    
    if self.on_ceil then
        if self.velocity.y < 0 then
            self.velocity.y = 0
        end
    end



    local hor = 0
    hor = 
        (input.action_is_down("left") == input.action_is_down("right")) and 0
        or input.action_is_down("left") and -1 
        or input.action_is_down("right") and 1
    
    self.velocity.x = hor * MOVE_SPEED
    
    if input.action_is_pressed("jump") then
        if input.action_is_down("down") then
            self.jump_down_one_way = true
        elseif self.jump_count > 0 then
            self.velocity.y = -JUMP_FORCE
            self.jump_count = self.jump_count - 1
            self.on_ground = false
        end
    end
    
    
    self.velocity.y = self.velocity.y + GRAVITY * dt
    
    local delta = self.velocity * dt
    delta.x = math.ceil(math.abs(delta.x)) * math.sign(delta.x)
    delta.y = math.ceil(math.abs(delta.y)) * math.sign(delta.y)
    
    
    self:move_and_collide(delta)
    
end



return Player