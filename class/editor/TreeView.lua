local Object = require("class.engine.Node")
local TreeView = Object:subclass("TreeView")
TreeView.static.dontlist = true

TreeView:define_signal("selection_made")
TreeView:define_get_set("modal")
TreeView:define_get_set("window_name")
TreeView:define_get_set("select_leaf_only")
TreeView:define_get_set("bottom_height")
TreeView:define_get_set("display_extra_width")
TreeView:define_get_set("open")

function TreeView:initialize()
    Object.initialize(self)
    self.modal = false
    self.open = true
    self.bottom_height = 0
    self.display_extra_width = 0
    
    self.window_name = "Tree Selector"
end

-- Return root node of the tree, needs to be overridden
function TreeView:get_root()
    return nil
end

-- Return children of a given node, needs to be overridden
function TreeView:get_children(node)
    return {}
end

-- Returns if the given node is a leaf, when select_leaf_only is enabled,
-- for example, to only allow selecting files and disallow directories
function TreeView:is_leaf(node)
    return false
end

-- Return if the given node is a child of parent, needed to auto
-- open tree nodes when selection is changed programatically
function TreeView:parent_has_child(parent, child)
    return false
end

function TreeView:get_selected_nodes()
    return {}
end

function TreeView:get_node_name(node)
    return ""
end

function TreeView:begin_window(flags)

end

function TreeView:display(old_selection)
     
    if not old_selection then return end
     
    local selection_changed = false
    local selected_nodes = table.copy(old_selection)
    
    local b_height = self.bottom_height
    if self.modal then b_height = b_height + 32 end
     
    imgui.BeginChild("Selection Area", 0, -b_height, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )
        
    if self.display_node_extra then
        local w = imgui.GetContentRegionAvailWidth()
        imgui.Columns(2)
        imgui.SetColumnWidth(-1, w - self.display_extra_width)
        
    end
    local root = self:get_root()
    local stack = { root }
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
            
            if node == root then
                table.insert(tree_node_flags, "ImGuiTreeNodeFlags_DefaultOpen")
            end
                
            if old_selection then
                for _,n in ipairs(old_selection) do
                    if n == node then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                        break
                    end
                        
                    if self:parent_has_child(node, n) then
                        imgui.SetNextTreeNodeOpen(true)
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
                            self.open = false
                        end
                    else
                        selection_changed = true
                    end
                
                end
            end
                
            if self.display_node_extra then
                imgui.NextColumn()

                self:display_node_extra(node)
                imgui.NextColumn()
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
        
        
    if self.display_node_extra then
        imgui.Columns(1)
    end
        
    imgui.EndChild()
    
    if self.modal then
        imgui.Separator()
        
        if imgui.Button("Select", 120, 0) and selected_nodes[1] then
            if not self.select_leaf_only or self:is_leaf(selected_nodes[1]) then
                selection_changed = true
                self.open = false
            end
        end
        imgui.SameLine()
        if imgui.Button("Cancel", 120, 0) then
            self.open = false
        end

        if not self.open then
            imgui.CloseCurrentPopup()
        end 
    end
    
    self.new_selection = selected_nodes
    self.selection_changed = selection_changed
end

function TreeView:end_window()

end

-- Querying functions, must be called between display() and end_window()
function TreeView:is_selection_changed()
end

function TreeView:get_selection()
end

return TreeView