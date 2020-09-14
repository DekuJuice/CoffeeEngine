local Resource = require("class.engine.resource.Resource")
local Node = require("class.engine.Node")
local CreateResourceModal = Node:subclass("CreateResourceModal")
CreateResourceModal.static.dontlist = true
CreateResourceModal:define_signal("resource_created")
local _pop_sentinel = {}

function CreateResourceModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.filepath = ""
end

function CreateResourceModal:open()
    self.is_open = true
    self.filepath = ""
end

function CreateResourceModal:confirm_selection()
    if self.filepath ~= "" then
        local res = self.selection()
        res:set_filepath(self.filepath)
        
        self:emit_signal("resource_created", res)
        self.is_open = false
    end
end

function CreateResourceModal:draw()
    local editor = self:get_parent()

    if not self.is_open then return end
    
    if self.is_open then
        imgui.OpenPopup("Create Resource", "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end
    
    local model = editor:get_active_scene_model()
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})

    local flags = {}
    local should_draw, open = imgui.BeginPopupModal("Create Resource", self.is_open, flags)
    self.is_open = open
    
    if should_draw then
        
        local changed, fp = imgui.InputTextWithHint("##PathInput", "Enter Resource Path", self.filepath, 128) 
        local finalized = imgui.IsItemDeactivatedAfterEdit()
        if finalized and self.selection then
            
            if fp:find(settings.get_setting("asset_dir")) ~= 0 then
                fp = ("%s/%s"):format(settings.get_setting("asset_dir"), fp)
            end
            
            local ext = fp:match("[^.]+$")
            if not table.find(self.selection.static.extensions, ext) then
                fp = ("%s.%s"):format(fp, self.selection.static.extensions[1])
            end
            
            local bname = fp:match("^[^%.]+")
            if bname ~= "" then
                self.filepath = fp
            end            
        end
        
        imgui.BeginChild("##Tree Area", -1, -32, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )
        
        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg"}) then

            local stack = {  Resource }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == _pop_sentinel then
                    imgui.TreePop()
                else
                    imgui.TableNextRow()
                    
                    local is_leaf = next(top.subclasses, nil) == nil
                    local noinstance = rawget(top.static, "noinstance")
                    local tree_node_flags = {
                        "ImGuiTreeNodeFlags_SpanFullWidth",
                        "ImGuiTreeNodeFlags_DefaultOpen",
                    }
                    
                    if noinstance then
                        imgui.PushStyleColor("ImGuiCol_Text", 1, 1, 1, 0.5)
                    else                    
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_OpenOnArrow")
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_OpenOnDoubleClick")
                    end
                    
                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end
                    
                    if top == self.selection then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                    end
                    
                    local open = imgui.TreeNodeEx(top.name, tree_node_flags)
                    
                    if noinstance then
                        imgui.PopStyleColor(1)
                    end
                    
                    if imgui.IsItemClicked(0) and not noinstance then
                        self.selection = top
                        if imgui.IsMouseDoubleClicked(0) then
                            self:confirm_selection()
                        end
                    end
                    
                    if open then
                        table.insert(stack, _pop_sentinel)
                        
                        local subclasses = {}
                        for s in pairs(top.subclasses) do
                            if not s.static.dontlist then
                                table.insert(subclasses, s)
                            end
                        end
                        
                        table.sort(subclasses, function(a, b)
                            return a.name > b.name
                        end)
                        
                        for _,s in ipairs(subclasses) do
                            table.insert(stack, s)
                        end
                    end
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()
        
        if (imgui.Button("Confirm", 120, 0) or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Enter")))
        and self.selection then            
            self:confirm_selection()
        end
        
        imgui.SameLine()
        
        if imgui.Button("Cancel", 120, 0) 
        or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Escape")) then
            imgui.CloseCurrentPopup()
            self.is_open = false
        end
        
        imgui.EndPopup()
    end
end


return CreateResourceModal