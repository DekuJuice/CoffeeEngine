local ImguiObjectInspector = require("class.editor.ImguiObjectInspector")

local ImguiResourceInspector = ImguiObjectInspector:subclass("ImguiResourceInspector")

function ImguiResourceInspector:initialize()
    ImguiObjectInspector.initialize(self)
    
    
end

function ImguiResourceInspector:display(resource)
    if resource then
        self:set_bottom_height(32)
        local path = resource:get_filepath() or ""

        imgui.Text( ("Resource: %s"):format(path)   )
    else
        self:set_bottom_height(0)
    end


    ImguiObjectInspector.display(self, resource)
end






return ImguiResourceInspector