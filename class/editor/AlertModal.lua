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