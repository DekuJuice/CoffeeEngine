local ImportedResource = require("class.engine.resource.ImportedResource")
local ObjectInspector = require("class.editor.ObjectInspector")
local ResourceInspector = ObjectInspector:subclass("ResourceInspector")

function ResourceInspector:initialize()
    ObjectInspector.initialize(self)
end

function ResourceInspector:display(resource)
    local rtype = "No Resource Selected"
    local path = "N/A"
    
    if resource then
        self:set_bottom_height(32)
        rtype = resource.class.name
        path = resource:get_filepath() or ("Unsaved Resource")
    else
        self:set_bottom_height(0)
    end

    imgui.Text( ("Resource: %s"):format(rtype))
        
    if resource and resource:get_has_unsaved_changes() then
        imgui.SameLine()
        imgui.TextColored( 1, 1, 0, 1,  ("(%s Unsaved changes!)"):format(IconFont.ALERT_TRIANGLE))
    end

    if resource and not resource:isInstanceOf(ImportedResource) then
        imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
        imgui.Text("Path: ")
        imgui.SameLine()
        imgui.SetCursorPosY(imgui.GetCursorPosY() - 3)

        local changed, fp = imgui.InputTextWithHint("##PathInput", "Enter Resource Path", resource:get_filepath() or "", 128) 
        local finalized = imgui.IsItemDeactivatedAfterEdit()
        
        if finalized then
            self.new_filepath = fp
            self.filepath_changed = true
        end
        
    else
        imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
        imgui.Text( ("Path: %s"):format(path) )
    end
    
    ObjectInspector.display(self, resource)
        
    if resource then
        if imgui.Button(("%s Save changes"):format(IconFont.SAVE)) then 
            if resource:get_filepath() then
                self.save_resource = true
            end
        end
    end
end

function ResourceInspector:save_pressed()
    return self.save_resource
end

function ResourceInspector:is_filepath_changed()
    return self.filepath_changed
end

function ResourceInspector:get_new_filepath()
    return self.new_filepath
end

function ResourceInspector:end_window()
    self.save_resource = nil
    self.new_filepath = nil
    self.filepath_changed = nil
    ObjectInspector.end_window(self)
end

return ResourceInspector