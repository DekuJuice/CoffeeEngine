local ImguiTreeSelector = require("class.editor.ImguiTreeSelector")
local ImguiResourceSelector = ImguiTreeSelector:subclass("ImguiResourceSelector")

function ImguiResourceSelector:initialize()
    ImguiTreeSelector.initialize(self)
    
    self:set_select_leaf_only(true)
end

function ImguiResourceSelector:get_root()
    return "assets"
end

function ImguiResourceSelector:get_children(path)
    local children = {}
    
    for _,item in ipairs(love.filesystem.getDirectoryItems(path)) do
        table.insert(children, ("%s/%s"):format(path, item))
    end
    
    return children
end

function ImguiResourceSelector:is_leaf(path)
    local info = love.filesystem.getInfo(path)
    if info and info.type == "file" then return true end
    return false
end

function ImguiResourceSelector:parent_has_child(p1, p2)
    return p1:find(p2) == 1
end

function ImguiResourceSelector:get_node_name(path)
    return path:match("[^/]+$")
end

return ImguiResourceSelector