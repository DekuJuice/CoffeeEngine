--[[

MIT License

Copyright (c) 2020 DekuJuice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

-- An interface to a scene file.

local binser = require("enginelib.binser")
local Resource = require("class.engine.resource.Resource")
local PackedScene = Resource:subclass("PackedScene")
PackedScene.static.extensions = {"scene"}
PackedScene.static.dontlist = true
PackedScene:export_var("data", "data")

function PackedScene:instance()
    
    local node_list = binser.deserialize(self.data)[1]
    
    local root
    if node_list[1].filepath then
        root = resource.get_resource(node_list[1].filepath):instance()
    else
        root = node_list[1].class()        
    end
    
    for k,v in pairs(node_list[1].properties) do
        local setter = ("set_%s"):format(k)
        root[setter](root, v)
    end
    
    for i = 2, #node_list do
        local info = node_list[i]
        if info.class then
            info.node = info.class()
        elseif info.filepath then
            info.node = resource.get_resource(info.filepath):instance()
        else
            info.node = root:get_node(info.path)            
        end
        
        local node = info.node
        if not node then
            log.warn("Missing node, inherited scene was changed?")
            goto CONTINUE
        end
        
        for k,v in pairs(info.properties) do
            local setter = ("set_%s"):format(k)
            node[setter](node, v)
        end
        
        if not info.path then
            root:get_node(info.parent):add_child(node)
        end 
        node:set_owner(root)
        
        ::CONTINUE::
    end
    
    -- Do second pass to connect signals
    for _, info in ipairs(node_list) do
        local node = info.node
        for _,connection in ipairs(info.signals) do
            node:connect(connection.signal, root:get_node(connection.target_path), connection.method)
        end
        
    end
    
    root:set_filepath( self:get_filepath() )
    
    return root
end

-- Packs the given root node into scene data
-- Only nodes owned by the root (+ the root itself) are saved
-- Only signals between children of root or to autoload nodes are preserved
function PackedScene:pack(root)
    -- Idea: Keep a list of all resources referenced for preloading purposes?
    
    -- Nodes are listed in preorder to make reconstruction of 
    -- the tree easier
    
    local instance_defaults = {}
    local node_list = {}
    
    -- Serialize nodes
    local stack = { root }
    while #stack > 0 do
        local top = table.remove(stack)
        
        -- Ignore children of instanced nodes that aren't part of an inherited scene
        if top ~= root and top:get_owner() ~= root then goto CONTINUE end
        
        local instanced = top:get_filepath() ~= nil
        local inherited = top:get_is_inherited_scene()
        
        -- Node was instanced from a file, load the default values for comparison
        if instanced then
            instance_defaults[top:get_filepath()] = resource.get_resource( top:get_filepath() ):instance()
        end
        
        local exported_vars = top.class:get_exported_vars()
        
        local node_info = {
            properties = {},
            signals = {}
        }
        
        -- Create list of outgoing signals
        -- Signals pointing to things outside the tree are discarded
        for signal in pairs(top.class:get_signals()) do
            for _, connection in ipairs(top:get_connections(signal)) do
            
                if connection.target:get_tree() == top:get_tree() then
                    
                    table.insert(node_info.signals, {
                        signal = signal,
                        target_path = connection.target:get_relative_path(root),
                        method = connection.method
                    })

                end

            end
        end

        -- Non root nodes are given the path of their parent
        -- Since we're traversing in preorder if we add children back
        -- when instancing the children will still be in the same order
        if top ~= root then
            node_info.parent = top:get_parent():get_relative_path(root)
        end
        
        -- Cases:
        --   Node is root node of instanced scene
        --   Node is part of inherited scene
        --   Normal node
        
        if instanced then
            node_info.filepath = top:get_filepath()
        elseif not inherited then
            node_info.class = top.class
        else
            node_info.path = top:get_relative_path(root)
        end
    
        --   If node is instanced or inherited, only save properties that were modified from the default
        if instanced or inherited then
        
            local base
            if instanced then
                base = instance_defaults[top:get_filepath()]
            else
                local owner = top:get_owner()        
                base = instance_defaults[owner:get_filepath()]:get_node( top:get_relative_path(owner) )                 
            end
            
            for name in pairs(exported_vars) do
                local getter = ("get_%s"):format(name)
                local v = top[getter](top)
                local bv = base[getter](base)
                
                if v ~= bv then
                    node_info.properties[name] = v
                end
            end
        else -- Otherwise save properties that differ from class defaults
            for name, ep in pairs(exported_vars) do
                local getter = ("get_%s"):format(name)
                local v = top[getter](top)
                if v ~= ep.default then
                    node_info.properties[name] = v
                end
            end
        end
        
        table.insert(node_list, node_info)
        
        -- Include children only if owner is root node
        for _,c in ipairs(top:get_children()) do
            if c:get_owner() == root then
                table.insert(stack, c)
            end
        end
        
        ::CONTINUE::
    end
    
    -- Do second pass for 
    
    
    self.data = binser.serialize(node_list)
end

return PackedScene