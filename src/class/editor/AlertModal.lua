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
local AlertModal = Node:subclass("AlertModal")
AlertModal.static.dontlist = true
AlertModal:define_signal("button_pressed")

function AlertModal:initialize()
    Node.initialize(self)
    self.open = false
end

function AlertModal:show(title, message, buttons)
    self.open = true
    self.title = title or ""
    self.message = message or ""
    self.buttons = buttons or {}
end

function AlertModal:draw()
    if not self.open then return end
    
    if self.open then
        imgui.OpenPopup(self.title, "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end

    local window_flags = {"ImGuiWindowFlags_AlwaysAutoResize"}
    local should_draw, window_open = imgui.BeginPopupModal(self.title, self.open, window_flags)
    self.open = window_open
    
    
    if should_draw then
        imgui.Text(self.message)
        imgui.Separator()
        for i, button in ipairs(self.buttons) do
            if imgui.Button(button) then
                self.open = false
                self:emit_signal("button_pressed", i, button)
                imgui.CloseCurrentPopup()
                break
            end
            imgui.SameLine()
        end
    
        imgui.EndPopup()
    end
    
    if not self.open then
        self.title = nil
        self.message = nil
        self.buttons = nil
    end
    
end

return AlertModal