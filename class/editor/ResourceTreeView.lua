local TreeView = require("class.editor.TreeView")
local ResourceTreeView = TreeView:subclass("ResourceTreeView")
ResourceTreeView:define_get_set("ext_filter")

function ResourceTreeView:initialize()
    TreeView.initialize(self)
    self:set_select_leaf_only(true)
end

function ResourceTreeView:get_root()
    return "assets"
end

function ResourceTreeView:get_children(path)
    local children = {}
    
    for _,item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local info = love.filesystem.getInfo( ("%s/%s"):format(path, item ) )
        if info.type == "directory" then
            table.insert(children, ("%s/%s"):format(path, item))
        elseif info.type == "file" then
            local ext = item:match("[^.]+$")
            local ext_ok = true
            if ext == "import" or ext == "bak" then
                ext_ok = false
            end
            
            if self.ext_filter then
                ext_ok = false
                for _,v in ipairs(self.ext_filter) do
                    if ext == v then
                        ext_ok = true
                        break
                    end
                end
            end
            
            if ext_ok then
                table.insert(children, ("%s/%s"):format(path, item))
            end
        end
    end
    
    return children
end

function ResourceTreeView:is_leaf(path)
    local info = love.filesystem.getInfo(path)
    if info and info.type == "file" then return true end
    return false
end

function ResourceTreeView:parent_has_child(p1, p2)
    return p2:find(p1) == 1
end

function ResourceTreeView:get_node_name(path)
    return path:match("[^/]+$")
end

return ResourceTreeView