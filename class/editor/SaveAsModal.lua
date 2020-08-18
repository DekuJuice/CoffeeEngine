local Node = require("class.engine.Node")
local AlertModal = require("class.editor.AlertModal")
local SaveAsModal = Node:subclass("SaveAsModal")
local PackedScene = require("class.engine.resource.PackedScene")

SaveAsModal.static.dontlist = true

local _pop_sentinel = {}

function SaveAsModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.alert_modal = AlertModal()
end

function SaveAsModal:open(path)
    self.is_open = true
    self.path = path or ""
end

function SaveAsModal:do_save()
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    scene:set_filepath(self.path)
    local packed_scene = scene:pack()
    
    resource.save_resource(packed_scene, function() 
        scene:set_modified(false)
    end)
    self.is_open = false
end

function SaveAsModal:validate_path()
    local ext = PackedScene.static.extensions[1]
    
    local root_dir = settings.get_setting("scene_dir")
    if self.path:find(root_dir) ~= 1 then
        self.path = ("%s/%s"):format(root_dir, self.path)
    end
    
    if self.path:match("[^.]+$") ~= ext then
        self.path = ("%s.%s"):format( self.path, ext)
    end
end

function SaveAsModal:_on_overwrite_modal_button_pressed(index, button)
    self.alert_modal:disconnect("button_pressed", self, "_on_overwrite_modal_button_pressed")
    if button == "Confirm" then
        self:do_save()
    end
end

function SaveAsModal:check_path()
    self:validate_path()
    
    local info = love.filesystem.getInfo(self.path)
    
    if info then
        if info.type == "file" then
            self.alert_modal:show("Alert!", ("%s already exists. Overwrite?"):format(self.path), {"Confirm", "Cancel"})
            self.alert_modal:connect("button_pressed", self, "_on_overwrite_modal_button_pressed")
        else
            self.alert_modal:show("Error!", "Cannot save to this path", {"Ok"})
        end
    else
        self:do_save()
    end
    
end

function SaveAsModal:draw()
    if not self.is_open then return end
    
    if self.is_open then
        imgui.OpenPopup("Save As", "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})
    local should_draw, window_open = imgui.BeginPopupModal("Save As", self.is_open, window_flags)
    self.is_open = window_open
    
    if should_draw then
        imgui.PushItemWidth(-1)
        local changed
        changed, self.path = imgui.InputText("##Filename", self.path, 128, {"ImGuiInputTextFlags_EnterReturnsTrue"})
        
        if imgui.IsItemDeactivatedAfterEdit() then
            self:validate_path()
        end
        
        
        imgui.BeginChild("Tree view", 0, -28, {"ImGuiWindowFlags_HorizontalScrollbar"})
        -- Tree view of scenes
        if imgui.BeginTable("Table", 1, {"ImGuiTableFlags_RowBg"}) then
            local stack = { settings.get_setting("scene_dir") }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == _pop_sentinel then
                    imgui.TreePop()
                else
                    imgui.TableNextRow()
                    local is_leaf = love.filesystem.getInfo(top, "file") ~= nil
                    local tree_node_flags = {
                        "ImGuiTreeNodeFlags_OpenOnArrow", 
                        "ImGuiTreeNodeFlags_SpanFullWidth",
                        "ImGuiTreeNodeFlags_DefaultOpen"
                    }
                    
                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end
                    
                    local open = imgui.TreeNodeEx(top:match("[^/]+$"), tree_node_flags)
                    
                    if imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                        if is_leaf then
                            self.path = top
                        else
                            self.path = top .. "/"
                        end
                        
                        if imgui.IsMouseDoubleClicked(0) then
                            self:check_path()
                        end
                    end
                    
                    if open then
                        table.insert(stack, _pop_sentinel)
                        
                        local di = love.filesystem.getDirectoryItems(top)
                        for i = #di, 1, -1 do
                            local cp = ("%s/%s"):format(top, di[i])
                            if love.filesystem.getInfo(cp, "directory") or di[i]:match("[^.]+$") == PackedScene.static.extensions[1] then
                                table.insert(stack, cp)
                            end
                        end
                    end
                end
            end
        imgui.EndTable()
        end
        
        imgui.EndChild()

        if (imgui.Button("Confirm", 120, 0) or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Enter"))) then            
            self:check_path()
        end
        
        imgui.SameLine()
        
        if imgui.Button("Cancel", 120, 0) 
        or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Escape")) then
            imgui.CloseCurrentPopup()
            self.is_open = false
        end
        
        self.alert_modal:draw()
        
        imgui.EndPopup()
    end
    
end


return SaveAsModal

