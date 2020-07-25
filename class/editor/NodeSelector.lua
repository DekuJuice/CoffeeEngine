local TreeView = require("class.editor.TreeView")

local NodeSelector = TreeView:subclass("NodeSelector")

function NodeSelector:initialize()
    TreeView.initialize(self)
    self:set_select_leaf_only(false)
    self:set_modal(true)
    self:set_open(false)
end

function NodeSelector:get_root()
    return require("class.engine.Node")
end

function NodeSelector:get_children(class)
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

function NodeSelector:is_leaf(class)
    
    for class in pairs(class.subclasses) do 
        if not class.static.dontlist then
            return false
        end
    end

    return true
end

function NodeSelector:parent_has_child(c1, c2)
    return c2:isSubclassOf(c1)
end

function NodeSelector:get_node_name(class)
    return class.name
end

return NodeSelector