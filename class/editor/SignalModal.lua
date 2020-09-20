local Node = require("class.engine.Node")
local SignalModal = Node:subclass("SignalModal")
local _pop_sentinel = {}

SignalModal.static.dontlist = true

function SignalModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.selected_node = nil
    self.selected_method = nil
    self.target = nil
end

function SignalModal:open(signal)
    local editor = self:get_parent()
    local scene = editor:get_active_scene_model()
    local sel = scene:get_selected_nodes()[1]
    local cur_scene = scene:get_tree():get_current_scene()
    
    self.signal = signal
    self.emitter = scene:get_selected_nodes()[1]
    self.is_open = true
    self.selected_node = nil
    self.selected_method = nil    
end

function SignalModal:confirm_selection()
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    local cur_scene = model:get_tree():get_current_scene()
    
    local method = self.selected_method
    local emitter = self.emitter
    local target = self.selected_node
    local signal = self.signal
    
    if not method or not target then return end
    
    if emitter:is_connected(signal, target, method) then
        self.is_open = false
        return
    end
    
    local cmd = model:create_command("Connect signal")
    cmd:add_do_func(function()
        emitter:connect(signal, target, method)
    end)
    
    cmd:add_undo_func(function()
        emitter:disconnect(signal, target, method)
    end)
    
    model:commit_command(cmd)
    
    self.is_open = false
end

function SignalModal:draw()
    if not self.is_open then return end
    
    if self.is_open then
        imgui.OpenPopup("Connect Signal", "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end
    
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})
    local should_draw, window_open = imgui.BeginPopupModal("Connect Signal", self.is_open, window_flags)
    self.is_open = window_open
    
    if should_draw then
        if imgui.BeginCombo("Method", tostring(self.selected_method)) then
         
            if self.selected_node then
                local method_arr = {}
                local class = self.selected_node.class
                while class do
                    for k,v in pairs(rawget(class, "__declaredMethods")) do
                        if k[1] ~= "_" then
                            table.insert(method_arr, k)
                        end
                    end
                    class = class.super
                end
                table.sort(method_arr)
                
                for _, method in ipairs(method_arr) do
                    if imgui.Selectable(method) then
                        self.selected_method = method
                    end
                end
            end
            imgui.EndCombo()
        
        end
    
    
        imgui.PushItemWidth(-1)
        imgui.BeginChild("##Tree view", 0, -28, {"ImGuiWindowFlags_HorizontalScrollbar"})
        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg"}) then
            
            local root = model:get_tree():get_current_scene()
            
            local stack = {  root }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == _pop_sentinel then
                    imgui.TreePop()
                else
                    imgui.TableNextRow()
                    local is_leaf = true
                    for _,c in ipairs(top:get_children()) do
                        if c:get_owner() == root then
                            is_leaf = false
                            break
                        end
                    end
                    
                    
                    local tree_node_flags = {
                        "ImGuiTreeNodeFlags_SpanFullWidth",
                        "ImGuiTreeNodeFlags_DefaultOpen",
                        "ImGuiTreeNodeFlags_OpenOnArrow"
                    }
                    
                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end
                    
                    if top == self.selected_node then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                    elseif self.selected_node and top:is_parent_of(self.selected_node) then
                        imgui.SetNextItemOpen(true)
                    end
                    
                    local col_pop = 0
                    local no_select = false
                    
                    if top == self.emitter then
                        imgui.PushStyleColor("ImGuiCol_Text", 1.000, 0.424, 0.424, 1.000)
                        col_pop = 1
                        no_select = true
                    end
                    
                    local dname = top:get_name()
                    if top.class.icon then
                        dname = ("%s %s"):format(top.class.icon, dname)
                    end
                    
                    local open = imgui.TreeNodeEx(dname, tree_node_flags)
                    
                    imgui.PopStyleColor(col_pop)
                    
                    if not no_select and imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                        self.selected_node = top
                        if imgui.IsMouseDoubleClicked(0) then
                            self:confirm_selection()
                        end
                    end
                    
                    if top:get_filepath() then
                        imgui.SameLine()
                        imgui.Text(("%s"):format(IconFont.LINK))
                    end
                    
                    if open then
                        table.insert(stack, _pop_sentinel)
                        
                        local children = top:get_children()
                        for i = #children, 1, -1 do
                            local c = children[i]
                            if c:get_owner() == root then
                                table.insert(stack, children[i])
                            end
                        end
                    end
                    
                end
            end
            
            
            imgui.EndTable()
        end
        
        imgui.EndChild()
        
        if (imgui.Button("Confirm", 120, 0) or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Enter"))) then            
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

return SignalModal