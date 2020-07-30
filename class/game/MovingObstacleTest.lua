local Obstacle = require("class.engine.Obstacle")
local MovingObstacleTest = Obstacle:subclass("MovingObstacleTest")
MovingObstacleTest:binser_register()

function MovingObstacleTest:initialize()
    Obstacle.initialize(self)
end

function MovingObstacleTest:physics_update(dt)

    local hor = 0
    hor = 
        (love.keyboard.isDown("a") == love.keyboard.isDown("d")) and 0
        or love.keyboard.isDown("a") and -1 
        or love.keyboard.isDown("d") and 1

    local ver = 0
    ver = 
        (love.keyboard.isDown("w") == love.keyboard.isDown("s")) and 0
        or love.keyboard.isDown("w") and -1
        or love.keyboard.isDown("s") and 1
        
    local velocity = vec2(
        hor * 120 * dt,
        ver * 120 * dt
    ) 
    
    velocity.x = math.ceil(math.abs(velocity.x)) * math.sign(velocity.x)
    velocity.y = math.ceil(math.abs(velocity.y)) * math.sign(velocity.y)
    
    self:move_and_collide(velocity)

end


return MovingObstacleTest