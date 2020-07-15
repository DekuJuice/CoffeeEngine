local ObjectInspector = require("class.editor.ObjectInspector")

local NodeInspector = ObjectInspector:subclass("NodeInspector")

function NodeInspector:initialize()
    ObjectInspector.initialize(self)
end

function NodeInspector:display(node)
    local name = "N/A"
    local path = "N/A"
    
    if node then
        name = node:get_full_name()
        path = node:get_absolute_path()
    end
    
    imgui.Text( ("Node: %s"):format(name))
    imgui.Text( ("Path: %s"):format(path))

    ObjectInspector.display(self, node)
    
end


return NodeInspector