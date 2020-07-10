local ImguiNodeBrowser = require("class.editor.ImguiNodeBrowser")

local ImguiTreeSelector = require("class.editor.ImguiTreeSelector")
local ImguiNodeSelector = ImguiTreeSelector:subclass("ImguiNodeSelector")

function ImguiNodeSelector:initialize()
    ImguiTreeSelector.initialize(self)
    
    self:set_select_leaf_only(false)
    
    self.node_browser = ImguiNodeBrowser()
    self.node_browser:set_window_name("Select a node")
    self.node_browser:close()
    
    self.node_browser_selection = {}
end

function ImguiNodeSelector:set_scene_model(sm)
    self.scene_model = sm
end

function ImguiNodeSelector:get_root()
    return self.scene_model:get_tree():get_root()
end

function ImguiNodeSelector:get_children(node)
    return node:get_children()
end

function ImguiNodeSelector:is_leaf(node)
    return node:get_child_count() == 0
end

function ImguiNodeSelector:parent_has_child(parent, child)
    return parent:is_parent_of(child)
end

function ImguiNodeSelector:get_node_name(node)
    return node:get_full_name()
end

function ImguiNodeSelector:display(selected)

    if imgui.Button(IconFont.PLUS_CIRCLE) then
        self.node_browser:open()
    end
    
    imgui.SameLine()
    
    if imgui.Button(IconFont.LINK) then
    
    end

    local changed, new_selection = ImguiTreeSelector.display(self, selected) 
    
    return changed, new_selection
end

function ImguiNodeSelector:end_window()
    ImguiTreeSelector.end_window(self)

    if self.node_browser:begin_window() then
        local changed, new_selection = self.node_browser:display(self.node_browser_selection)
        self.node_browser_selection = new_selection
        
    end
    self.node_browser:end_window()
end


return ImguiNodeSelector