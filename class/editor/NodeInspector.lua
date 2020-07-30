local ObjectInspector = require("class.editor.ObjectInspector")

local NodeInspector = ObjectInspector:subclass("NodeInspector")

function NodeInspector:display(node)
    if node then
        imgui.Text( ("%s: %s"):format(node.class.name, node:get_name()))
        imgui.Text( ("Path: %s"):format(node:get_absolute_path()))
        
        if imgui.CollapsingHeader("Tags") then
            
            local changed, nv = imgui.InputText("Add New Tag", "", 128)
            local finalized = imgui.IsItemDeactivatedAfterEdit()
            
            if finalized and nv ~= "" then
                self.tag_added = true
                self.tag_arg = nv
            end
            
            local tags = {}
            for k,v in pairs(node:get_tags()) do
                table.insert(tags, k)
            end
            table.sort(tags)
            
            for _,t in ipairs(tags) do
                imgui.Text(t)
                imgui.SameLine()
                if imgui.Button(IconFont.MINUS) then
                    self.tag_removed = true
                    self.tag_arg = t
                end
            end                  
        end
        imgui.Separator()
    else
        imgui.Text( ("No Node Selected"))
    end
    ObjectInspector.display(self, node)
end

function NodeInspector:is_tag_added()
    return self.tag_added == true
end

function NodeInspector:is_tag_removed()
    return self.tag_removed == true
end

function NodeInspector:get_tag_arg()
    return self.tag_arg
end

function NodeInspector:end_window()
    ObjectInspector.end_window(self)
    self.tag_added = nil
    self.tag_removed = nil
    self.tag_arg = nil
end


return NodeInspector