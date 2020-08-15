local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")
local ReparentNodeModal = Node:subclass("ReparentNodeModal")
local _pop_sentinel = {}

ReparentNodeModal.static.dontlist = true

function ReparentNodeModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.selection = {}
end

function ReparentNodeModal:open()
    self.is_open = true
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    self.target = scene:get_selected_nodes()[1]
    self.selection = nil
end

function ReparentNodeModal:confirm_selection()
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    
    local old_par = self.target:get_parent()
    local old_i = old_par:get_child_index(self.target)
    
    local new_par = self.selection
    local target = self.target
    
    local cmd = scene:create_command("Reparent Node")
    cmd:add_do_func(function()
        old_par:remove_child(target)
        new_par:add_child(target)
        target:flag_visibility_dirty()
        
        if target:isInstanceOf(Node2d) then
            target:flag_position_dirty()
        end
        
    end)
    cmd:add_undo_func(function()
        new_par:remove_child(target)
        old_par:add_child(target)
        old_par:move_child(target, old_i)
        target:flag_visibility_dirty()
        
        if target:isInstanceOf(Node2d) then
            target:flag_position_dirty()
        end
    end)
    
    scene:commit_command(cmd)
    
    self.is_open = false
end

function ReparentNodeModal:draw()
    if not self.is_open then return end
    
    if self.is_open then
        imgui.OpenPopup("Reparent Node")
    end
    
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})
    local should_draw, window_open = imgui.BeginPopupModal("Reparent Node", self.is_open, window_flags)
    self.is_open = window_open
    
    if should_draw then
        imgui.PushItemWidth(-1)
        imgui.BeginChild("##Tree view", 0, -28, {"ImGuiWindowFlags_HorizontalScrollbar"})
        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg"}) then
                    
            local stack = {  model:get_tree():get_root() }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == _pop_sentinel then
                    imgui.TreePop()
                else
                    imgui.TableNextRow()
                    local is_leaf = #top:get_children() == 0
                    local tree_node_flags = {
                        "ImGuiTreeNodeFlags_SpanFullWidth",
                        "ImGuiTreeNodeFlags_DefaultOpen",
                    }
                    
                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end
                    
                    if top == self.selection then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                    elseif self.selection and top:is_parent_of(self.selection) then
                        imgui.SetNextItemOpen(true)
                    end
                    
                    local col_pop = 0
                    local no_select = false
                    
                    if top == self.target then
                        imgui.PushStyleColor("ImGuiCol_Text", 0.446, 0.763, 1.000, 1.000)
                        col_pop = 1
                        no_select = true
                    elseif self.target:is_parent_of(top) then
                        imgui.PushStyleColor("ImGuiCol_Text", 1.000, 0.424, 0.424, 1.000)
                        col_pop = 1
                        no_select = true
                    else
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_OpenOnArrow")
                    end
                    
                    local open = imgui.TreeNodeEx(top:get_name(), tree_node_flags)
                    
                    imgui.PopStyleColor(col_pop)
                    
                    if not no_select and imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                        self.selection = top
                        if imgui.IsMouseDoubleClicked(0) then
                            self:confirm_selection()
                        end
                    end
                    
                    if open then
                        table.insert(stack, _pop_sentinel)
                        
                        local children = top:get_children()
                        for i = #children, 1, -1 do
                            table.insert(stack, children[i])
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

return ReparentNodeModal