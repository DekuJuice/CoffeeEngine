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
local AABB_OFFSET = vec2(0, 0)

local MOVE_SPEED = 120 -- 7.5 tiles / second
local GRAVITY = 900 -- 0.9375 tiles / second^2
local MAX_FALL = 420 -- 26.25 tiles / second

local DASH_SPEED = 210 --13.125 tiles / second
local DASH_FRAMES = 28 / 60
--Dimensions during dash
local DASH_AABB_EXTENTS = vec2(7, 10)
local DASH_AABB_OFFSETS = vec2(0, 0)

--Initial velocity when wall slide begins
local WALL_SLIDE_START_SPEED = 30 -- 0.03125 tiles / second
local WALL_SLIDE_ACCEL = GRAVITY * 2 -- 1.875 tiles / second^2
local WALL_SLIDE_FALL_MAX = 90 -- 0.09375 tiles / second
local WALL_SLIDE_SENSOR_LEFT = vec2( -AABB_EXTENTS.x - 1, 0)
local WALL_SLIDE_SENSOR_RIGHT = vec2( AABB_EXTENTS.x + 1, 0)

--Duration that the player can't move during walljump
local WALL_JUMP_FRAMES = 8 / 60
local JUMP_FORCE = 300 -- 0.3125 tiles / second
local WALL_JUMP_SENSOR_LEFT = vec2(-AABB_EXTENTS.x - 4, 0)
local WALL_JUMP_SENSOR_RIGHT = vec2(AABB_EXTENTS.x + 4, 0)

local input = require("input")
local class = require("enginelib.middleclass")
local StateMachine = require("class.engine.StateMachine")
local Obstacle = require("class.engine.Obstacle")
local Actor = require("class.engine.Actor")
local Player = Actor:subclass("Player")
Player:binser_register()

-- Player movement states:
-- standing
-- air
-- wallslide
-- dash
-- death

local StandingState = class("PlayerStandingState")
local AirState = class("PlayerAirState")
local WallSlideState = class("PlayerWallSlideState")
local DashState = class("PlayerDashState")
local DeathState = class("PlayerDeathState")

local function move_behaviour(state, player)

    if player.control_locks.all ~= 0 and player.control_locks.move ~= 0 then
        return
    end

    local hor = 0
    hor = 
        (input.action_is_down("left") == input.action_is_down("right")) and 0
        or input.action_is_down("left") and -1 
        or input.action_is_down("right") and 1
        
    player.velocity.x = hor * MOVE_SPEED
end

local function jump_behaviour(state, player)
    if input.action_is_pressed("jump") then
        if input.action_is_down("down") then
            player.jump_down_one_way = true
        elseif state.jump_count > 0 then
            player.velocity.y = -JUMP_FORCE
            player.on_ground = false
            player.is_jumping = true
            state.jump_count = state.jump_count - 1
        end
    end
end

local function wall_jump_behaviour(state, player)
    
end

local function get_delta(player, dt)
    local delta = player.velocity * dt
    delta.x = math.ceil(math.abs(delta.x)) * math.sign(delta.x)
    delta.y = math.ceil(math.abs(delta.y)) * math.sign(delta.y)
    return delta
end

function StandingState:initialize()
    self.jump_count = 1
end

function StandingState:update(player, dt)
    player.velocity.y = 0
    player.is_jumping = false
    
    move_behaviour(self, player)
    jump_behaviour(self, player)
    
    player.velocity.y = math.min( player.velocity.y + GRAVITY * dt, MAX_FALL)
    player:move_and_collide(get_delta(player, dt))
    
    if not player.on_ground then
        return AirState(player, COYOTE_TIME)
    end
end

function AirState:initialize(player, coyote_time, walljump_lock)
    walljump_lock = walljump_lock or 0
    self.walljump_lock_timer = walljump_lock
    self.has_move_lock = walljump_lock > 0
    self.coyote_time = coyote_time or 0
end

function AirState:update(player, dt)   
    local world = player:get_physics_world()
    local gp = player:get_global_position()

    -- Allow early jump ends
    if player.velocity.y < -30 
    and player.is_jumping 
    and not input.action_is_down("jump") then
        player.velocity.y = -30
        player.is_jumping = false
        if self.has_move_lock then
            self.walljump_lock_timer = 0
            self.has_move_lock = false
            player:release_control("move")
        end
    end

    move_behaviour(self, player)
    
    -- Wall jumps
    if self.has_move_lock then
        self.walljump_lock_timer = self.walljump_lock_timer - dt
        if self.walljump_lock_timer <= 0 then
            self.walljump_lock_timer = 0
            player:release_control("move")
            self.has_move_lock = false
        end
    end
    
    if input.action_is_pressed("jump") then
    
        local wall_jump = 0
        local left_p = world:query_point(gp + WALL_JUMP_SENSOR_LEFT, player.collision_mask, player)
        
        for _,o in ipairs(left_p) do
            if o:isInstanceOf(Obstacle) and not o:has_tag("no_wall_slide") then
                wall_jump = 1
                break
            end
        end
        
        world:pool_push_query(left_p)
        
        local right_p = world:query_point(gp + WALL_JUMP_SENSOR_RIGHT, player.collision_mask, player)
        
        for _,o in ipairs(right_p) do
            if o:isInstanceOf(Obstacle) and not o:has_tag("no_wall_slide") then
                wall_jump = -1
                break
            end
        end
        
        world:pool_push_query(right_p)
        
        if wall_jump ~= 0 then
            player.velocity.y = -JUMP_FORCE
            player.velocity.x = MOVE_SPEED * wall_jump
            player:lock_control("move")
            self.walljump_lock_timer = WALL_JUMP_FRAMES
            self.has_move_lock = true
            player.is_jumping = true
        else -- can't walljump, check for coyote time and allow normal jump
            if self.coyote_time > 0 then
                player.is_jumping = true     
                player.velocity.y = -JUMP_FORCE
                self.coyote_time = 0
            end
        end
    end
    
    self.coyote_time = self.coyote_time - dt
    
    player.velocity.y = player.velocity.y + GRAVITY * dt
    player:move_and_collide(get_delta(player, dt))
    
    if player.on_ceil then
        player.velocity.y = 0
        if self.has_move_lock then
            self.walljump_lock_timer = 0
            self.has_move_lock = false
            player:release_control("move")
        end
    end
    
    if player.on_ground then
        return StandingState(player)
    end
    
    -- TODO: Point query before entering wallslide state
    if player.on_wall and player.velocity.y >= 0 then

        local can_wallslide = false
        local dir
        local query
        
        if player.on_wall_left then
            dir = -1
            query = world:query_point(gp + WALL_SLIDE_SENSOR_LEFT, player.collision_mask, player)
            
            
        elseif player.on_wall_right then
            dir = 1
            query = world:query_point(gp + WALL_SLIDE_SENSOR_RIGHT, player.collision_mask, player)
        end
        
        for _, o in ipairs(query) do
            if not o:has_tag("no_wall_slide") then
                can_wallslide = true
                break
            end
        end
        
        world:pool_push_query(query)
        
        if can_wallslide then
            return WallSlideState(player, dir)
        end
    end
end

function AirState:exit(player)
    if self.has_move_lock then
        player:release_control("move")
    end
end

function WallSlideState:initialize(player, dir)
    player.velocity.y = 0
    self.dir = dir
end

function WallSlideState:update(player, dt)
    
    if self.dir == 1 then
        player.stick_moving_wall_right = true
    elseif self.dir == -1 then
        player.stick_moving_wall_left = true
    end
    
    player.is_jumping = false
    
    local wall_jumped = false
    if input.action_is_pressed("jump") then
        player.velocity.y = -JUMP_FORCE
        player.velocity.x = -self.dir * MOVE_SPEED
        player:lock_control("move")
        wall_jumped = true
        player.is_jumping = true
    end
    
    move_behaviour(self, player)
    
    player.velocity.y = math.min(player.velocity.y + WALL_SLIDE_ACCEL * dt, WALL_SLIDE_FALL_MAX)
    player:move_and_collide(get_delta(player, dt))
    
    if player.on_ceil then
        player.velocity.y = 0
    end
    
    if player.on_ground then
        return StandingState(player)
    end
    
    if not player.on_wall 
    or (self.dir == 1 and not player.on_wall_right)
    or (self.dir == -1 and not player.on_wall_left) then
        
        return AirState(player, 0, wall_jumped and WALL_JUMP_FRAMES or 0)
    end
end

function WallSlideState:exit(player)
    player.stick_moving_wall_left = false
    player.stick_moving_wall_right = false
end

function Player:initialize()
    Actor.initialize(self)
    
    self:set_aabb_extents(AABB_EXTENTS:clone())
    self:set_aabb_offset(AABB_OFFSET:clone())
    
    self.jump_count = 1
    self.is_jumping = false
    
    self.control_locks = {
        all = 0,
        move = 0,
        attack = 0
    }
    
    self.movement_state = StandingState(self)

    self.velocity = vec2(0, 0)
end

function Player:lock_control(which)
    assert(self.control_locks[which] ~= nil, ("Invalid control lock %s"):format(tostring(which)))
    if which ~= "all" then
        self.control_locks.all = self.control_locks.all + 1
    end
    self.control_locks[which] = self.control_locks[which] + 1
end

function Player:release_control(which)
    assert(self.control_locks[which] ~= nil, ("Invalid control lock %s"):format(tostring(which)))
    
    if which ~= "all" then
        self.control_locks.all = self.control_locks.all - 1
    end
    self.control_locks[which] = self.control_locks[which] - 1
    
end

function Player:physics_update(dt)
    if self.movement_state.update then
        local new = self.movement_state:update(self, dt)
        if new then
            if self.movement_state.exit then
                self.movement_state:exit(self)
            end
            self.movement_state = new
        end
    end
end

function Player:draw()
    local gp = self:get_global_position()
    love.graphics.print(self.movement_state.class.name, gp:unpack())
end

return Player