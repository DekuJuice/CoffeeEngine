local Object = require("class.engine.Object")

local ImguiTreeSelector = Object:subclass("ImguiTreeSelector")

ImguiTreeSelector:define_signal("menu_button_pressed")

ImguiTreeSelector:define_get_set("modal")
ImguiTreeSelector:define_get_set("window_name")
ImguiTreeSelector:define_get_set("select_leaf_only")
ImguiTreeSelector:define_get_set("bottom_height")

function ImguiTreeSelector:initialize()
    Object.initialize(self)
    self.modal = false
    self.is_open = true
    self.bottom_height = 0
    
    self.window_name = "Tree Selector"
    self.select_leaf_only = true
end

function ImguiTreeSelector:open()
    self.is_open = true
end

function ImguiTreeSelector:close()
    self.is_open = false
    if self.modal then
        imgui.CloseCurrentPopup()
    end
end

-- Return root node of the tree, needs to be overridden
function ImguiTreeSelector:get_root()
    return nil
end

-- Return children of a given node, needs to be overridden
function ImguiTreeSelector:get_children(node)
    return {}
end

-- Returns if the given node is a leaf, when select_leaf_only is enabled,
-- for example, to only allow selecting files and disallow directories
function ImguiTreeSelector:is_leaf(node)
    return false
end

-- Return if the given node is a child of parent, needed to auto
-- open tree nodes when selection is changed programatically
function ImguiTreeSelector:parent_has_child(parent, child)
    return false
end

function ImguiTreeSelector:get_selected_nodes()
    return {}
end

function ImguiTreeSelector:get_node_name(node)
    return ""
end

function ImguiTreeSelector:begin_window(flags)
    local window_flags = {}
    if flags then
        for _,f in ipairs(flags) do
            table.insert(window_flags, v)
        end
    end
    
    imgui.SetNextWindowSize(400, 400, {"ImGuiCond_FirstUseEver"})
    
    local should_draw, window_open
    if self.modal then
        if self.is_open then
            imgui.OpenPopup(self.window_name)
        end
        
        should_draw, window_open = imgui.BeginPopupModal(self.window_name, self.is_open, window_flags)
    else
        
        if not self.is_open then
            return false
        end
        
        should_draw, window_open = imgui.Begin(self.window_name, self.is_open, window_flags)
    end
    
    self.is_open = window_open
    
    return should_draw
end

function ImguiTreeSelector:end_window()
    if self.is_open then
        if self.modal then
            imgui.EndPopup()
        else
            imgui.End()
        end
    end
end

function ImguiTreeSelector:display(old_selection)
     
    if not old_selection then return end
     
    local selection_changed = false
    local selected_nodes = table.copy(old_selection)
    
    local b_height = self.bottom_height
    if self.modal then b_height = b_height + 32 end
     
    imgui.BeginChild("Selection Area", 0, -b_height, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )
        
    local stack = { self:get_root() }
    while #stack > 0 do
        local node = table.remove(stack)
        if node == "pop" then
            imgui.TreePop()
        else
                
            local is_leaf = self:is_leaf(node)
            
            local tree_node_flags = {
                "ImGuiTreeNodeFlags_OpenOnArrow", 
                "ImGuiTreeNodeFlags_SpanFullWidth",
            }
                
            if is_leaf then
                table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
            end
                
            if old_selection then
                for _,n in ipairs(old_selection) do
                    if n == node then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                        break
                    end
                        
                    if self:parent_has_child(n, node) then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_DefaultOpen")
                        break
                    end
                end
            end
                
            local open = imgui.TreeNodeEx(self:get_node_name(node), tree_node_flags)
            
            if imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                -- TODO: Maybe implement multi selection?
                selected_nodes = {node}
                if not self.select_leaf_only or is_leaf then
                    
                    if self.modal then
                        if imgui.IsMouseDoubleClicked(0) then
                            selection_changed = true
                            self:close()
                        end
                    else
                        selection_changed = true
                    end
                
                end
            end
                
            if open then
                table.insert(stack, "pop")
                local children = self:get_children(node)
                for i = 1, #children do
                    table.insert(stack, children[#children - i + 1])
                end
            end
        end
    end
        
    imgui.EndChild()
    
    if self.modal then
        imgui.Separator()
        
        if imgui.Button("Select", 120, 0) and selected_nodes[1] then
            selection_changed = true
            self:close()
        end
        imgui.SameLine()
        if imgui.Button("Cancel", 120, 0) then
            self:close()
        end
    end
    return selection_changed, selected_nodes
end



return ImguiTreeSelector