local ObjectInspector = require("class.editor.ObjectInspector")

local NodeInspector = ObjectInspector:subclass("NodeInspector")

function NodeInspector:display(node)
    
    if node then
        imgui.Text( ("%s: %s"):format(node.class.name, node:get_name()))
        imgui.Text( ("Path: %s"):format(node:get_absolute_path()))
    else
        imgui.Text( ("No Node Selected"))
    end
    


    ObjectInspector.display(self, node)
    
end


return NodeInspector