local PackedScene = require("class.engine.resource.PackedScene")
local Node = require("class.engine.Node")
local OpenSceneModal = Node:subclass("OpenSceneModal")

local _pop_sentinel = {}

OpenSceneModal.static.dontlist = true

function OpenSceneModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.selection = settings.get_setting("scene_dir")
    self.window_name = "Open Scene"
end

function OpenSceneModal:open()
    self.is_open = true
end

function OpenSceneModal:confirm_selection()
    local editor = self:get_parent()
    if love.filesystem.getInfo(self.selection, "file") then
        
        local ok, err = pcall(editor.add_new_scene, editor, self.selection)
        if err then
            log.error(err)
        end
        self.is_open = false
    end
end

function OpenSceneModal:draw()
    if not self.is_open then return end
    
    if self.is_open then
        imgui.OpenPopup(self.window_name, "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})
    local should_draw, window_open = imgui.BeginPopupModal(self.window_name, self.is_open, window_flags)
    self.is_open = window_open
    
    if should_draw then
        imgui.PushItemWidth(-1)
        imgui.BeginChild("##Tree view", 0, -28, {"ImGuiWindowFlags_HorizontalScrollbar"})
        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg"}) then
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
                        "ImGuiTreeNodeFlags_DefaultOpen",
                        "ImGuiTreeNodeFlags_OpenOnDoubleClick"
                    }
                    
                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end
                    
                    if top == self.selection then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                    end
                    
                    local open = imgui.TreeNodeEx(top:match("[^/]+$"), tree_node_flags)
                    
                    if imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                        self.selection = top
                        
                        if imgui.IsMouseDoubleClicked(0) then
                            self:confirm_selection()
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

return OpenSceneModal