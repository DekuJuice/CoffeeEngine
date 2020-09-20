local VelocityHelper = {}

function VelocityHelper:get_velocity_delta(dt)
    local delta = self.velocity * dt + self.velocity_remainder
    local rounded = delta:clone()
    
    rounded.x = math.floor(math.abs(rounded.x)) * math.sign(rounded.x)
    rounded.y = math.floor(math.abs(rounded.y)) * math.sign(rounded.y)
    
    self.velocity_remainder = delta - rounded
        
    return rounded
end

return VelocityHelper