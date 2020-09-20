--[[

MIT License

Copyright (c) 2020 DekuJuice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

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