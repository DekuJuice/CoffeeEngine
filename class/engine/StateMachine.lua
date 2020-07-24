local Object = require("class.engine.Object")
local StateMachine = Object:subclass("StateMachine")

function StateMachine:initialize()
    Object.initialize(self)
    
    self.current = nil
    self.events = {}
end

function StateMachine:set_state(state)
    self.current = state
end

function StateMachine:get_state()
    return self.current
end

function StateMachine:define_event(name, from, to)
    
    if type(from) == "string" then
        from = {from}
    end
    
    local event = {from, to} 
    
    self.events[name] = event
end

function StateMachine:event(name, ...)
    assert(self.current, "A default state must be set")
    
    local e = self.events[name]
    for _,fr in ipairs(e[1]) do
        if fr == "*" or self.current == fr then
            
            self.current = fr
        end
    end
end

return StateMachine