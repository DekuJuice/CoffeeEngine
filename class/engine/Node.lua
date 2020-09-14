-- Base class for all Nodes
local binser = require("enginelib.binser")
local Object = require("class.engine.Object")
local Node = Object:subclass("Node")
Node.static.icon = IconFont and IconFont.CIRCLE

local function validate_node_name(name)
    if name:len() == 0 then return false end
    for _, char in ipairs({ -- Invalid characters
        "/",
        ".",
        ":",
        "%"
    }) do
        if name:find(char, nil, true) then
            return false
        end
    end
    return true
end

-- Only used in editor
Node:define_get_set("owner") 
Node:define_get_set("filepath") -- If node was instanced, the scene root will have its filename set to the file it was instanced from

Node:export_var("name", "string", 
    {filter = function(_, name) return validate_node_name(name) end, 
})
    
Node:export_var("tags", "data")
Node:export_var("visible", "data")
--[[
function Node:_serialize()
    return Object._serialize(self)
end

Node.static.binser_register = function(class)
    if not rawget(class.static, "_deserialize") then
        class.static._deserialize = function(data, filepath)
            local instance
            
            if filepath then
                local ps = resource.get_resource(filepath)
                local ok, res = pcall(ps.instance, ps)
                if ok then
                    instance = res
                    instance.is_instance = true
                    instance:set_filepath(filepath)
                else
                    instance = class()
                    instance.invalid = true
                    return instance
                end
            else
                instance = class()
            end
            
            for _,v in ipairs(data) do
                local key = v[1]
                local val = v[2]
                
                local setter = ("set_%s"):format(key)
                instance[setter](instance, val)
            end
            
            return instance
        end
    end
    
    binser.register(class.__instanceDict, class.name, class._serialize, class._deserialize)
end
]]--

Node:binser_register()

function Node:initialize()
    Object.initialize(self)
    
    self.visible = true
    self.visible_in_tree = true
    self.visible_dirty = false
    
    self.name = self.class.name
    self.tags = {}
    
    self.is_instance = false
    
    self.children = {} -- Array of children
end

-- Checks child nodes for any duplicate names, and generate and assign a new one
-- if needed.
function Node:_validate_child_name(child)

    -- Check if there are any nodes with the same name
    local exists = false
    for _,c in ipairs(self.children) do
        if c ~= child and c.name == child.name then
            exists = true
            break
        end
    end
    
    if not exists then return end
    
    local cur_num = tonumber(child.name:match("%d+$")) or 1
    local base_name = child.name:sub(1, -(math.ceil(math.log10(cur_num)) + 1))
    if cur_num == 1 then cur_num = 2 end
    
    local attempt
    
    while exists do
            
        if settings.get_setting("is_editor") then
            attempt = ("%s%d"):format(base_name, cur_num)
            cur_num = cur_num + 1
        else
            attempt = ("%s%d"):format(base_name, love.math.random(2^32))
        end
            
        exists = false
        for _,c in ipairs(self.children) do
            if c ~= child and c.name == attempt then
                exists = true
                break
            end
        end
    end
    
    child.name = attempt

end

function Node:_set_tree(tree)

    if tree == self.tree then return end
    
    -- Don't call enter/exit tree events when we're in the editor, so that
    -- if we make any signal connections in there it won't show up in editor
    
    if tree then
        self.tree = tree
        
        if tree:get_is_editor() then
            self:event("editor_enter_tree")
        else
            self:event("enter_tree")
        end        
    else
        if self.tree:get_is_editor() then
            self:event("editor_exit_tree")
        else
            self:event("exit_tree")
        end
        
        self.tree = nil
    end
    
    if self.tree ~= tree then
        return
    end
    
    for _,child in ipairs(self.children) do
        child:_set_tree(tree)
    end
        
    if tree then
        if tree:get_is_editor() then
            self:event("editor_ready")
        else
            self:event("ready")
        end
    end
        
end

function Node:_validate_owner()
    local owner = self:get_owner()
    if not owner then return end
    
    if not owner:is_parent_of(self) then
        self.owner = nil
    end        
end

function Node:flag_visibility_dirty()
    self.visible_dirty = true
    local stack = {}
    local children = {}
    
    for _,c in ipairs(self.children) do
        table.insert(stack, c)
    end
    
    while #stack > 0 do
        local top = table.remove(stack)
        top.visible_dirty = true
        for _,c in ipairs(top.children) do
            table.insert(stack, c)
        end
    end
end

function Node:set_visible(visible)
    self.visible = visible
    self:flag_visibility_dirty()
end

function Node:is_visible_in_tree()
    if self.visible_dirty then
        if self.parent then
            self.visible_in_tree = self.parent:is_visible_in_tree()
        else
            self.visible_in_tree = true
        end
        self.visible_dirty = false
    end

    return self.visible and self.visible_in_tree
end

function Node:duplicate()
    -- TODO: Duplicate signals?
    
    local root = binser.deserialize(binser.serialize(self))[1]
    for _,c in ipairs(self.children) do
        self:add_child( c:duplicate() )
    end
    
    return root
end

function Node:set_owner(owner)
    if owner then
        assert(owner:is_parent_of(self), "Owner must be a parent of the node" )
    end
    
    self.owner = owner
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
    child:_set_tree(self:get_tree())
    child:flag_visibility_dirty()
    child:event("parented", self)
end

function Node:remove_child(child)
    for i,c in ipairs(self.children) do
        if c == child then
            c.parent = nil
            c.name_num = 1
            table.remove(self.children, i)
            
            child:flag_visibility_dirty()
            child:event("unparented", self)
            child:_set_tree(nil)
            child:propagate_event_preorder("_validate_owner", false)
            
            return true
        end
    end
    return false
end

function Node:get_child_index(child)
    for i,c in ipairs(self.children) do
        if c == child then
            return i
        end
    end
end

-- Callback order is dependant on child order, so this may be useful
function Node:move_child(child, new_index)
    assert(new_index >= 1 and new_index <= #self.children, "Index must be between 1 and the number of children")
    
    for j, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, j)
            table.insert(self.children, new_index, child)
            return
        end
    end
    
    error("The given node is not a child of this node")    
end

function Node:get_parent()
    return self.parent
end

-- If there are multiple child nodes that have the same "base" name, the node
-- will be renamed to ensure its path is unique
function Node:set_name(name)
    assert(validate_node_name(name), ("Invalid node name %s"):format(name))
    self.name = name
    
    if self.parent then self.parent:_validate_child_name(self) end
end

function Node:get_child_count()
    -- Small optimization here if needed, keep track of child count instead of recounting each time
    return #self.children
end

function Node:get_children()
    return table.copy(self.children)
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
        
        if rootname ~= root:get_name() then 
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
                if c:get_name() == first then
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

-- Get path of the node relative to other
function Node:get_relative_path(other)
    assert(other:get_tree() and self:get_tree(), "Nodes must be in trees to get relative path")
    assert(other:get_tree() == self:get_tree(), "Nodes must be in the same tree to get relative path")
    
    if self == other then
        return "."
    end
    
    
    local p1 = self:get_absolute_path() .. "/"
    local p2 = other:get_absolute_path() .. "/"
    
    local i = 1
    local j = 1
    
    while (p1:sub(i, i) == p2:sub(i, i)) do
        if p1:sub(i, i) == "/" then
            j = i
        end
        i = i + 1
    end
    
    local common = p1:sub(1, j)
    
    local root = p1:sub(j, -2)
    local rel = p2:sub(j + 1, -2):gsub("[^/]+", "..")
    
    local path = rel .. root
    
    return path
end
--[[
local function test_get_relative_path(p1, p2)
    local i = 1
    local j = 1
    
    while (p1:sub(i, i) == p2:sub(i, i)) do
        if p1:sub(i, i) == "/" then
            j = i
        end
        i = i + 1
    end
    
    local common = p1:sub(1, j)
    
    local root = p1:sub(j, -2)
    local rel = p2:sub(j + 1, -2):gsub("[^/]+", "..")
    
    local path = rel .. root
    
    
end

test_get_relative_path("/foo/bar/baz/", "/foo/")
test_get_relative_path("/foo/", "/foo/bar/baz/")
test_get_relative_path("/foo/bar/baz/", "/foo/qux/")

-- node  /foo/bar/baz
-- other /foo/
-- res bar/baz

-- node /foo
-- other /foo/bar/baz/
-- res ../..

-- node /foo/bar/baz
-- other /foo/qux
-- res ../bar/baz
]]--

function Node:get_absolute_path()
    assert(self:get_tree(), "Node must be in a tree to get absolute path")
    local path = ("/%s"):format(self:get_name())
    
    if self.parent then 
        return ("%s%s"):format(self.parent:get_absolute_path(), path)
    else
        return path
    end
end

function Node:is_parent_of(other)

    local par = other:get_parent()
    while par do
        if par == self then return true end
        par = par:get_parent()
    end

    return false
end

function Node:get_tree()
    return self.tree
end

function Node:add_tag(tag)
    self.tags[tag] = true
end

function Node:has_tag(tag)
    return self.tags[tag] == true
end

function Node:remove_tag(tag)
    self.tags[tag] = nil
end


function Node:propagate_event_preorder(name, allow_interrupt, ...)
    if self:event(name, ...) and allow_interrupt then
        return true
    end

    for _,child in ipairs(self.children) do
        if child:propagate_event_preorder(name, allow_interrupt, ...) and allow_interrupt then
            return true
        end
    end
    
    return false
end

function Node:propagate_event_postorder(name, allow_interrupt, ...)
    
    for i = #self.children, 1, -1 do
        local child = self.children[i]
        if child:propagate_event_postorder(name, allow_interrupt, ...) and allow_interrupt then
            return true
        end
    end
    
    if self:event(name, ...) and allow_interrupt then
        return true
    end
    
    return false
end

function Node:event(name, ...)
    if self[name] then return self[name](self, ...) end
end

function Node:_print_tree(indent_level)
    print(string.rep("\t", indent_level) .. self:get_name())

    for _,c in ipairs(self.children) do
        c:_print_tree(indent_level + 1)    
    end
end

function Node:print_tree()
    self:_print_tree(0) 
end

return Node