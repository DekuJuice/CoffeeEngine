local Object = require("class.engine.Object")
local ActionDispatcher = Object:subclass("ActionDispatcher")

function ActionDispatcher:initialize()
    Object.initialize(self)
    self.actions = {}
end

function ActionDispatcher:add_action(name, func, shortcut)
    table.insert(self.actions, {
        name = name,
        func = func,
        shortcut = shortcut
    })
end

function ActionDispatcher:get_shortcut(action_name)
    for _,action in pairs(self.actions) do
        if action.name == action_name then
            return action.shortcut
        end
    end
end

function ActionDispatcher:do_action(name)
    for _,action in pairs(self.actions) do
        if action.name == name then
            action.func()
            break
        end
    end
end

function ActionDispatcher:keypressed(key)
    local shortcut = ""
    if love.keyboard.isDown("lctrl") then
        shortcut = shortcut .. "Ctrl+"
    end
    if love.keyboard.isDown("lalt") then
        shortcut = shortcut .. "Alt+"
    end
    if love.keyboard.isDown("lshift") then
        shortcut = shortcut .. "Shift+"
    end
        
    shortcut = (shortcut .. key):upper()
    
    for _,action in ipairs(self.actions) do
        if action.shortcut and action.shortcut:upper() == shortcut then
            action.func()
            return true
        end
    end
end

return ActionDispatcher