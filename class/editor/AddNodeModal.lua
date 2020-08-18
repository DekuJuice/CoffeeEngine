local Node = require("class.engine.Node")
local AddNodeModal = Node:subclass("AddNodeModal")
local _pop_sentinel = {}

AddNodeModal.static.dontlist = true

function AddNodeModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.selection = Node
end

function AddNodeModal:open()
    self.is_open = true
end

function AddNodeModal:confirm_selection()
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    local sel = scene:get_selected_nodes()
    local tree = scene:get_tree()
    
    local instance = self.selection()
    local cmd = scene:create_command("Add Node")
    
    local root = tree:get_root()
    if root then
        local par = root
        if sel[1] then par = sel[1] end
        
        cmd:add_do_func(function()
            par:add_child(instance)
            instance:set_owner(root)
            scene:set_selected_nodes({instance})            
        end)
        cmd:add_undo_func(function()
            par:remove_child(instance)
            scene:set_selected_nodes(sel)
        end)

    else
        cmd:add_do_var(tree, "root", instance)
        cmd:add_do_func(function()
            scene:set_selected_nodes({instance})
        end)
        cmd:add_undo_var(tree, "root", nil)
        cmd:add_undo_func(function()
            scene:set_selected_nodes({})
        end)
    end
    
    scene:commit_command(cmd)
    
    self.is_open = false
end

function AddNodeModal:draw()
    if not self.is_open then return end
    
    if self.is_open then
        imgui.OpenPopup("Add Node", "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})
    local should_draw, window_open = imgui.BeginPopupModal("Add Node", self.is_open, window_flags)
    self.is_open = window_open
    
    if should_draw then
        imgui.PushItemWidth(-1)
        imgui.BeginChild("##Tree view", 0, -28, {"ImGuiWindowFlags_HorizontalScrollbar"})
        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg"}) then
            local stack = { Node }
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
                    local dname = top:get_name()
                    if top.icon then
                        dname = ("%s %s"):format(top.icon, dname)
                    end
                    
                    local open = imgui.TreeNodeEx(dname, tree_node_flags)
                    
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
        and not rawget(self.selection.static, "noinstance") then            
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

return AddNodeModal