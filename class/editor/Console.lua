local Object = require("class.engine.Object")
local Console = Object:subclass("Console")

function Console:initialize()
    Object.initialize(self)
    self.open = true
    
    self.show_timestamps = true
    
end

function Console:display()

    if not self.open then return end

    local flags = {}
    
    local should_draw, open = imgui.Begin("Console", self.open, flags)
    self.open = open
    
    
    if should_draw then
        imgui.BeginChild("Output", -1, -1, true, {})
        
        
        for i = 1, _G.CONSOLE_OUTPUT:get_count() do
            local o = _G.CONSOLE_OUTPUT:at(-i)
            imgui.TextWrapped( ("%f : %s"):format(o[2], o[1]))
        end
        
        if  imgui.GetScrollY() >= imgui.GetScrollMaxY() then
            imgui.SetScrollHere(1);
        end
        
        imgui.EndChild()
    end
    imgui.End()
end

return Console