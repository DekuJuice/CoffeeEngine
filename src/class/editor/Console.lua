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

local Node = require("class.engine.Node")
local Console = Node:subclass("Console")
Console.static.dontlist = true

function Console:initialize()
    Node.initialize(self)
    self.is_open = true
    self.show_timestamps = true
end

function Console:parented(parent)
    parent:add_action("Show Console", function() 
        self.is_open = not self.is_open
    end, "ctrl+shift+o")
end

function Console:draw()

    local editor = self:get_parent()

    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("View") then
            editor:_menu_item("Show Console", self.is_open)
            imgui.EndMenu()
        end
        imgui.EndMainMenuBar()
    end

    if not self.is_open then return end

    local flags = {}
    local should_draw, open = imgui.Begin("Console", self.is_open, flags)
    self.is_open = open
    
    if should_draw then
        imgui.BeginChild("Output", -1, -1, true)
        
        for i = 1, _G.CONSOLE_OUTPUT:get_count() do
            local o = _G.CONSOLE_OUTPUT:at(-i)
            imgui.TextWrapped( ("%f : %s"):format(o[2], o[1]))
        end
        
        if  imgui.GetScrollY() >= imgui.GetScrollMaxY() then
            imgui.SetScrollHereY(1);
        end
        
        local wx, wy = imgui.GetWindowPos()
        
        
        imgui.EndChild()
    end
    imgui.End()
end

return Console