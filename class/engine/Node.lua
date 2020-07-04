-- Base class for all Nodes

local binser = require("enginelib.binser")
local tableutil = require("enginelib.tableutil")

local Object = require("class.engine.Object")
local Node = Object:subclass("Node")

-- Only used in editor, indicates that the current node was instanced from a scene file,
-- and therefore should not expose any built in subnodes
Node:define_get_set("editor_hint_is_instance") 

-- If node was instanced, the scene root will have its filename set to the file it was instanced from
Node:define_get_set("filename")

local function validate_node_name(name)
    if name:len() == 0 then return false end
    for _, char in ipairs({ -- Invalid characters
        "/",
        "%."
    }) do
        if name:find(char) then
            return false
        end
    end
    return true
end

local function _no_filter(var)
    return true
end

-- Exports a member of the class, including it in a list of variables to show in the editor,
-- and defining standard setget functions for it
-- filter specifies a filter function on entered data to validate it
-- Editor hints are hints to how the editing widget should be displayed, ie names of fields in vectors, 
-- min/max ranges, etc
-- These vary depending on the datatype, check NodeInspector for more details
Node.static.export_var = function(class, name, datatype, filter, editor_hints)
    
    assert(name ~= nil, "A name must be given!")
    assert(datatype ~= nil, "A datatype must be specified!")
    
    class.static.exported_vars = rawget(class.static, "exported_vars") or {} -- Create export table if it does not exist

    -- Make sure getsets exist for this var, even if none are manually defined
    class:define_get_set(name)
    
    table.insert(class.static.exported_vars, 
        {type = datatype, 
        name = name, 
        filter = filter or _no_filter,
        editor_hints = editor_hints or {}})
end

Node:export_var("name", "string", validate_node_name)

-- serialization saves all exported variables into a key-value table
function Node:_serialize()
    local res = {}
    local cur_class = self.class
    while (cur_class) do
        local static = rawget(cur_class, "static")
        if static then
            local exported = rawget(static, "exported_vars")
            
            if exported then
                for _, ep in ipairs(exported) do
                    local getter = ("get_%s"):format(ep.name)
                    res[ep.name] = self[getter](self)
                end
            end
        end        
        
        if cur_class == Node then
            break
        end
        
        cur_class = cur_class.super
    end
    return res
end

-- Since each class has its own metatable, so we need to define deserialize for each class
local function binser_register(class)
    class._deserialize = function(data) 
        local instance = class()
        for k,v in pairs(data) do
            local setter = ("set_%s"):format(k)
            instance[setter](instance, v)
        end
        return instance
    end

    binser.registerClass(class)
end

binser_register(Node)

Node.static.subclassed = function(class, other)
    binser_register(other)
end

function Node:initialize()
    Object.initialize(self)
    
    self.name = self.class.name
    self.name_num = 1
    self.editor_hint_is_instance = false
    
    self.children = {} -- Array of children
end

-- If child already has a parent, will reparent it to the current node
function Node:add_child(child)

    if child.parent == self then 
        return 
    elseif child.parent then
        child.parent:remove_child(child)
    end

    table.insert(self.children, child)
    
    child.parent = self
    self:_validate_child_name(child)
    
    child:set_tree(self:get_tree())
end

-- Checks child nodes for any duplicate names, and generate and assign a new one
-- if needed.
function Node:_validate_child_name(child)
    while true do
        local attempt = child:get_full_name()
        local exists = false
        
        for _,c in ipairs(self.children) do
            if c ~= child and c:get_full_name() == attempt then
                exists = true
                break
            end
        end
        
        if not exists then 
            break
        end
        
        -- If we're in editor, we'll make the new name sequential,
        -- that is, if Child (1) and Child (2) already exist, the new child will be renamed
        -- Child (3)
        -- This is slow as we will end up iterating self.children n times, where n is the number
        -- of children with the same name.
        
        -- If we're not in editor mode, we'll just generate some random integer instead.
        if _G.EDITOR_MODE then
            child.name_num = child.name_num + 1            
        else
            child.name_num = love.math.random(2^32)
        end
    end
end

function Node:remove_child(child)
    for i,c in ipairs(self.children) do
        if c == child then
            c.parent = nil
            c.name_num = 1
            table.remove(self.children, i)
            return true
        end
    end
    return false
end

function Node:get_parent()
    return self.parent
end

function Node:set_name(name)
    self.name = name
    self.name_num = 1
    
    if self.parent then self.parent:_validate_child_name(self) end
end

function Node:get_full_name()
    if self.name_num > 1 then
        return ("%s (%d)"):format(self.name, self.name_num)
    else
        return self.name
    end
end

function Node:get_child_count()
    -- Small optimization here if needed, keep track of child count instead of recounting each time
    return #self.children
end

function Node:get_children()
    return tableutil.copy(self.children)
end

function Node:get_child(i)
    return self.children[i]
end

function Node:get_node(path)
    local next_path = path:match("/(.*)")
    local first = path:match("([^/]+)")
    local sloc = path:find("/")
    if sloc == 1 then
        -- Absolute path
        assert(self:get_tree(), "Node must be in a tree to get by absolute path")
        local root = self:get_tree():get_root()
        
        local rootname = next_path:match("([^/]+)")
        local next_next_path = next_path:match("/(.*)")
        local next_sloc = next_path:find("/")
        
        if rootname ~= root:get_full_name() then 
            return
        end
        
        if next_sloc then
            return root:get_node(next_next_path)
        else
            return root
        end
    else
    
        if first == ".." then
            if sloc then
                return self:get_parent():get_node(next_path)
            else
                return self:get_parent()
            end
        elseif first == "." then
            if sloc then
                return self:get_node(next_path)
            else
                return self
            end
        else
            for _,c in ipairs(self.children) do
                if c:get_full_name() == first then
                    if sloc then
                        return c:get_node(next_path)
                    else
                        return c
                    end
                end
            end
        end
    end
end

--[[function Node:get_relative_path(other)
    assert(other:get_tree() and self:get_tree(), "Nodes must be in trees to get relative path")
    assert(other:get_tree() == self:get_tree(), "Nodes must be in the same tree to get relative path")
    
end]]

function Node:get_absolute_path()
    assert(self:get_tree(), "Node must be in a tree to get absolute path")
    local path = ("/%s"):format(self:get_full_name())
    
    if self.parent then 
        return ("%s%s"):format(self.parent:get_absolute_path(), path)
    else
        return path
    end
end

function Node:is_parent_of(other)
    if other:get_parent() == self then return true end
    
    for _,c in ipairs(self.children) do
        if c:is_parent_of(other) then
            return true
        end
    end
    
    return false
end

-- This is used internally, you should probably not call this
function Node:set_tree(tree)

    if tree == self.tree then return end

    self.tree = tree
    for _,child in ipairs(self:get_children()) do
        child:set_tree(tree)
    end
end

function Node:get_tree()
    return self.tree
end

return Node