local ImguiTreeSelector = require("class.editor.ImguiTreeSelector")

local ImguiNodeBrowser = ImguiTreeSelector:subclass("ImguiNodeBrowser")

function ImguiNodeBrowser:initialize()
    ImguiTreeSelector.initialize(self)
    
    self:set_select_leaf_only(false)
    self:set_modal(true)
end

function ImguiNodeBrowser:get_root()
    return require("class.engine.Node")
end

function ImguiNodeBrowser:get_children(class)
    local children = {}
    
    for subclass in pairs(class.subclasses) do
        if not subclass.static.dontlist then
            table.insert(children, subclass)
        end
    end
    
    table.sort(children, function(a, b)
        return a.name < b.name
    end)
    
    return children
end

function ImguiNodeBrowser:is_leaf(class)
    
    -- Will return false if there are any subclasses
    for _ in pairs(class.subclasses) do 
        return false
    end

    return true
end

function ImguiNodeBrowser:parent_has_child(c1, c2)
    return c2:isSubclassOf(c1)
end

function ImguiNodeBrowser:get_node_name(class)
    return class.name
end

return ImguiNodeBrowser