local Actor = require("class.engine.Actor")
local TestActor = Actor:subclass("TestActor")

TestActor:binser_register()

function TestActor:physics_update(dt)
    local u = love.keyboard.isDown("up")
    local d = love.keyboard.isDown("down")
    local l = love.keyboard.isDown("left")
    local r = love.keyboard.isDown("right")

    local vel = vec2(0, 0)

    if u and not d then
        vel.y = -200
    elseif d and not u then
        vel.y = 200
    end
    
    if l and not r then
        vel.x = -60
    elseif r and not l then
        vel.x = 60
    end
    
    vel = vel * dt
    vel.x = math.floor(math.abs(vel.x)) * math.sign(vel.x)
    vel.y = math.floor(math.abs(vel.y)) * math.sign(vel.y)
    
    self:move_and_collide(vel, 0)
end

return TestActor