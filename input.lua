local module = {}
local actions = {}
local state = {}

function module.action_add_bind(action, device, input)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    table.insert(actions[action].events, {device = device, input = input} )
end

function module.action_erase_bind(action, device, input)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    for i,b in ipairs(actions[action].events) do
        if b.device == device and b.input == input then
            table.remove(actions[action].events, i)
            break
        end
    end
end

function module.action_has_bind(action, device, input)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    for i,b in ipairs(actions[action].events) do
        if b.device == device and b.input == input then
            return true
        end
    end
    return false
end

function module.action_set_deadzone(action, deadzone)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    actions[action].deadzone = deadzone
end

function module.add_action(action, deadzone)
    assert(not module.has_action(action), ("Action %s already exists"):format(action) ) 
    actions[action] = {
        deadzone = deadzone or 0.2,
        strength = 0,
        pressed = false,
        released = false,
        events = {}
    }
end

function module.erase_action(action)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    actions[action] = nil
end

function module.has_action(name)
    return actions[name] ~= nil
end

function module.get_binds(action)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    return actions[action].events
end

function module.reset_state()
    for _,action in pairs(actions) do
        action.pressed = false
        action.released = false
    end
end

function module.action_is_down(action)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    local a = actions[action]
    return a.strength > a.deadzone
end

function module.action_is_pressed(action)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    local a = actions[action]
    return a.pressed
end

function module.action_is_released(action)
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    local a = actions[action]
    return a.released
end

function module.action_get_strength()
    assert(module.has_action(action), ("Action %s does not exist"):format(action) )
    local a = actions[action]
    return a.strength
end

function module.get_actions(device, input)
    local a = {}
    for name,action in pairs(actions) do
        for _,bind in ipairs(action.events) do
            if bind.device == device and bind.input == input then
                table.insert(a, name)
                break
            end
        end
    end
    
    return a
end

function module.get_action_list()
    local l = {}
    for name in pairs(actions) do
        table.insert(l, name)
    end
    return l
end

function module.keypressed(key, scan, isrepeat)
    if not isrepeat then
        for _,name in ipairs( module.get_actions( "keyboard", key ) ) do
            local a = actions[name]
            if not module.action_is_down(name) then
                a.pressed = true
                module.actionpressed(name)
            end
            a.strength = 1.0
        end
        
        for _,name in ipairs( module.get_actions( "scancode", scan ) ) do
            local a = actions[name]
            if not module.action_is_down(name) then
                a.pressed = true
                module.actionpressed(name)
            end
            a.strength = 1.0
        end
    end
end

function module.keyreleased(key, scan)
    for _,name in ipairs( module.get_actions( "keyboard", key ) ) do
        local a = actions[name]
        if module.action_is_down(name) then
            a.released = true
            module.actionreleased(name)
        end
        a.strength = 0.0
    end
        
    for _,name in ipairs( module.get_actions( "scancode", scan ) ) do
        local a = actions[name]
        if module.action_is_down(name) then
            a.released = true
            module.actionreleased(name)
        end
        a.strength = 0.0
    end
end

function module.joystickpressed(stick, button)
    for _,name in ipairs(module.get_actions("joystick", button)) do
        local a = actions[name]
        if not module.action_is_down(name) then
            a.pressed = true
            module.actionpressed(name)
        end
        a.strength = 1.0
    end
end

function module.joystickreleased(stick, button)
    for _,name in ipairs(module.get_actions("joystick", button)) do
        local a = actions[name]
        if module.action_is_down(name) then
            a.released = true
            module.actionreleased(name)
        end
        a.strength = 0.0
    end
end

function module.joystickaxis(stick, axis, value)

    local axis_name = ("axis%i"):format(axis)
    
    local pb = axis_name .. "+"
    local nb = axis_name .. "-"
    
    -- Positive Axis
    for _,name in ipairs(module.get_actions("joystick", pb)) do
        local a = actions[name]
        
        if value > a.deadzone then
            if not module.action_is_down(name) then 
                a.pressed = true 
                module.actionpressed(name)
            end
            a.strength = value
        elseif module.action_is_down(name) then
            a.released = true
            a.strength = 0.0
            module.actionreleased(name)
        end
    end

    -- Negative Axis
    for _,name in ipairs(module.get_actions("joystick", nb)) do
        local a = actions[name]
        
        if value < -a.deadzone then
            if not module.action_is_down(name) then 
                a.pressed = true
                module.actionpressed(name)
            end
            a.strength = -value
        elseif module.action_is_down(name) then
            a.released = true
            a.strength = 0.0
            module.actionreleased(name)
        end
    end
end

function module.joystickhat(stick, hat, direction)
    local dirs = {
        l = direction:find("l") ~= nil ,
        r = direction:find("r") ~= nil ,
        u = direction:find("u") ~= nil ,
        d = direction:find("d") ~= nil 
    }
    
    for d, down in pairs(dirs) do
        for _, name in ipairs(module.get_actions("joystick", ("%s%i"):format(d, hat))) do
            local a = actions[name]
            
            if down then
                if not module.action_is_down(name) then
                    a.pressed = true
                    module.actionpressed(name)
                end
                a.strength = 1.0
            else
                if module.action_is_down(name) then
                    a.released = false
                    module.actionreleased(name)
                end
                a.strength = 0.0
            end
        end
    end
end

function module.actionpressed(action) end
function module.actionreleased(action) end

return module