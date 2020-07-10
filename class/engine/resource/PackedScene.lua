-- An interface to a scene file.

local binser = require("enginelib.binser")
local Resource = require("class.engine.resource.Resource")
local PackedScene = Resource:subclass("PackedScene")
PackedScene:export_var("data", "data")

function PackedScene:instance()
    
    -- Reconstruct tree
    local scene = binser.deserialize(self.data)[1]
    
    -- First node is always the root
    local root = scene.nodes[1].data
    
    for i = 2, #scene.nodes do        
        local n = scene.nodes[i]
        local parent = scene.nodes[n.parent_index].data
        
        parent:add_child(n.data)
    end
    
    return root
end

local function preorder_traverse(node, list)
    table.insert(list, node)
    for _,c in ipairs(node:get_children()) do
        preorder_traverse(c, list)
    end
end

-- Packs the given root node into scene data
function PackedScene:pack(root)
    -- TODO: Save signals/slots
    -- Idea: Keep a list of all resources referenced for preloading purposes?
    
    -- Nodes are listed in preorder to make reconstruction of 
    -- the tree easier
    
    local node_list = {}
    preorder_traverse(root, node_list)
    
    local index_map = {}
    
    for i,n in ipairs(node_list) do
        index_map[n] = i
    end
    
    local packed_nodes = {}
    
    for _,n in ipairs(node_list) do
        local d = {
            data = n
        }
        
        if n:get_parent() then
            d.parent_index = index_map[n:get_parent()]
        end
        
        
        table.insert(packed_nodes, d)
    end
    
    local scene = {
        nodes = packed_nodes
    }
    
    self.data = binser.serialize(scene)
end

return PackedScene