local NodeSelector = require("class.editor.NodeSelector")
local SceneSelector = require("class.editor.SceneSelector")

local TreeView = require("class.editor.TreeView")
local NodeTreeView = TreeView:subclass("NodeTreeView")

function NodeTreeView:initialize()
    TreeView.initialize(self)
    
    self:set_select_leaf_only(false)
    
    self.node_selector = NodeSelector()
    self.node_selector:set_window_name("Select a node to add")
    self.node_selector_selection = {}
    
    self.scene_selector = SceneSelector()
    self.scene_selector:set_window_name("Select a scene to instance")
    self.scene_selector_selection = {}
    
    self:set_display_extra_width(24)
end

function NodeTreeView:set_scene_model(sm)
    self.scene_model = sm
end

function NodeTreeView:get_root()
    return self.scene_model:get_tree():get_root()
end

function NodeTreeView:get_children(node)
    return node:get_children()
end

function NodeTreeView:is_leaf(node)
    return node:get_child_count() == 0
end

function NodeTreeView:parent_has_child(parent, child)
    return parent:is_parent_of(child)
end

function NodeTreeView:get_node_name(node)
    return node:get_name()
end

function NodeTreeView:display(selected)

    if imgui.Button( ("%s Add Node"):format(IconFont.PLUS_CIRCLE)) then
        self.node_selector:set_open(true)
    end
    
    imgui.SameLine()
    
    if imgui.Button( ("%s Instance Scene"):format( IconFont.LINK)) then
        self.scene_selector:set_open(true)
    end

    TreeView.display(self, selected)     
    
    if self.node_selector:begin_window() then
        self.node_selector:display(self.node_selector_selection)
        self.node_selector_selection = self.node_selector:get_selection()
        if self.node_selector:is_selection_changed() then
            self.new_node_selected = true
        end
    end
    self.node_selector:end_window()
    
    
    if self.scene_selector:begin_window() then
        self.scene_selector:display(self.scene_selector_selection)
        self.scene_selector_selection = self.scene_selector:get_selection()
        if self.scene_selector:is_selection_changed() then
            self.new_scene_selected = true
        end
    end
    self.scene_selector:end_window()

end

function NodeTreeView:is_new_node_selected()
    return self.new_node_selected
end

function NodeTreeView:get_new_node()
    return self.node_selector_selection[1]
end

function NodeTreeView:is_new_scene_selected()
    return self.new_scene_selected
end

function NodeTreeView:get_new_scene()
    return self.scene_selector_selection[1]
end

function NodeTreeView:end_window()

    self.new_node_selected = nil
    self.new_scene_selected = nil
    
    TreeView.end_window(self)
end

function NodeTreeView:display_node_extra(node)
    imgui.SetCursorPosY(imgui.GetCursorPosY() - 3)

    imgui.Button(IconFont.EYE)
end

return NodeTreeView