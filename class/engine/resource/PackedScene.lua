-- An interface to a scene file.

local binser = require("enginelib.binser")
local Resource = require("class.engine.resource.Resource")
local PackedScene = Resource:subclass("PackedScene")
PackedScene.static.extensions = {"scene"}
PackedScene.static.dontlist = true
PackedScene:export_var("data", "data")
PackedScene:binser_register()

function PackedScene:instance()
    
    -- Reconstruct tree
    local node_list = binser.deserialize(self.data)[1]
        
    -- First node is always the root
    local root = node_list[1].node
    root:set_filepath(self.filepath)
    
    for i = 2, #node_list do
        local n = node_list[i]
        
        if type(n.node) == "string" then
            n.node = resource.get_resource(n.node):instance()
        end
        
        -- We can assume the parent is already created since the parent
        -- index will always be less than the current
        local parent = node_list[n.parent_index].node
        parent:add_child(n.node)
        n.node:set_owner(root)
    end    
    
    return root
end

-- Packs the given root node into scene data
-- Only nodes owned by the root (+ the root itself) are saved
function PackedScene:pack(root)
    -- TODO: Save signals/slots
    -- Idea: Keep a list of all resources referenced for preloading purposes?
    
    -- Nodes are listed in preorder to make reconstruction of 
    -- the tree easier
    
    local node_list = {}
    local index_map = {}
    
    local stack = {root}
    while #stack > 0 do
        local top = table.remove(stack)
        local node
        
        if top ~= root and top:get_filepath() then
            node = top:get_filepath()
        else
            node = top
        end
        
        local d = {
            node = node,
            parent_index = index_map[top:get_parent()],
        }
        
        table.insert(node_list, d)
        index_map[top] = #node_list
        
        local children = top:get_children()
        for i = #children, 1, -1 do
            local c = children[i]
            if c:get_owner() == root then
                table.insert(stack, c)
            end
        end            
    end
    
    self.data = binser.serialize(node_list)
end

return PackedScene