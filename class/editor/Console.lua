local Object = require("class.engine.Object")
local Console = Object:subclass("Console")

function Console:initialize()
    Object.initialize(self)
    self.open = true
end

function Console:display(console_output)

    if not self.open then return end

    local flags = {}
    
    local should_draw, open = imgui.Begin("Console", self.open, flags)
    
    self.open = open
    
    if should_draw then
        imgui.BeginChild("Output", -1, -1, true, {})
        for _,v in ipairs(console_output) do
            imgui.TextWrapped(v)
        end
        imgui.SetScrollHere(1)
        imgui.EndChild()
    end
    imgui.End()
end

return Console