local PackedScene = require("class.engine.resource.PackedScene")
local SceneTree = require("class.engine.SceneTree")
local Object = require("class.engine.Object")

local SceneModel = Object:subclass("SceneModel")
SceneModel:define_get_set("modified")
SceneModel:define_get_set("grid_minor_w")
SceneModel:define_get_set("grid_minor_h")
SceneModel:define_get_set("grid_major_w")
SceneModel:define_get_set("grid_major_h")
SceneModel:define_get_set("draw_grid")

local function get_filename(path)
    return path:match("[^/]+$")
end

local function trim_extension(filename)
    return filename:match("^[^%.]+")
end

function SceneModel:initialize(loadpath)
    Object.initialize(self)
    
    -- Undo/redo
    self.in_command = false
    self.undo_stack = {}
    self.redo_stack = {}

    self.selected_nodes = {}
    
    -- Grid config
    self.draw_grid = true
    self.grid_minor_w = 16
    self.grid_minor_h = 16
    self.grid_major_w = 416
    self.grid_major_h = 240
    
    self.tree = SceneTree()
    
    if loadpath then
        self.modified = false
        self.packed_scene = get_resource(loadpath)
        self.tree:set_root(self.packed_scene:instance())
    else
        self.modified = true
        self.packed_scene = PackedScene()
    end
    
end

function SceneModel:get_name()
    local path = self.packed_scene:get_filepath()
    if path then 
        return trim_extension(get_filename(path))
    else
        return "Untitled"
    end
end

function SceneModel:set_filepath(path)
    self.packed_scene:set_filepath(path)
end

function SceneModel:get_filepath(path)
    return self.packed_scene:get_filepath()
end

function SceneModel:pack()
    self.packed_scene:pack(self:get_tree():get_root())
    return self.packed_scene:get_data()
end

function SceneModel:get_tree()
    return self.tree
end

function SceneModel:set_selected_nodes(nodes)
    self.selected_nodes = table.copy(nodes)
end

function SceneModel:get_selected_nodes()
    return table.copy(self.selected_nodes)
end

function SceneModel:is_selected(node)
    for _,n in ipairs(self.selected_nodes) do
        if n == node then return true end
    end
    
    return false
end

function SceneModel:add_node(path, node)
    local root = self:get_tree():get_root()
    if root then
        local parent = root:get_node(path)
        assert(parent, "Invalid path " .. path)
        
        parent:add_child(node)
        
    else
        assert(path == "/", "Invalid path " .. path)
        self:get_tree():set_root(node)        
    end
end

function SceneModel:remove_node(instance)
    assert(instance:get_tree() == self:get_tree(), "Invalid instance")
    if instance:get_parent() then
        instance:get_parent():remove_child(instance)
        
    else
        -- No parent, must be root node
        self:get_tree():set_root(nil)
    end

end

function SceneModel:undo()
    local command = self.undo_stack[#self.undo_stack]
    if not command then return end
    
    table.remove(self.undo_stack)
    
    for _,f in ipairs(command.undo_funcs) do
        f()
    end
    
    table.insert(self.redo_stack, command)
    
end

function SceneModel:redo()

    local command = self.redo_stack[#self.redo_stack]
    if not command then return end
    
    table.remove(self.redo_stack)
    
    for _,f in ipairs(command.do_funcs) do
        f()
    end
    
    table.insert(self.undo_stack, command)
    
end

function SceneModel:start_command(name, merge)
    assert(not self.in_command, "Finish the command before starting another")
    self.in_command = true
    self.do_merge = merge
    self.command = {
        name = name,
        do_funcs = {},
        undo_funcs = {}
    }
end

function SceneModel:add_do_function(func)
    assert(self.in_command, "Call start_command before adding functions")
    table.insert(self.command.do_funcs, func)
    
end

function SceneModel:add_undo_function(func)
    assert(self.in_command, "Call start_command before adding functions")
    table.insert(self.command.undo_funcs, func)
end

function SceneModel:end_command()
    self.in_command = false
    -- Execute functions
    for _,f in ipairs(self.command.do_funcs) do
        f()
    end

    -- Merge if applicable
    if self.do_merge then
        local prev = self.undo_stack[#self.undo_stack]
        if prev then
            if prev.name == self.command.name then
                for _,f in ipairs(self.command.do_funcs) do
                    table.insert(prev.do_funcs, f)
                end
                
                for _,f in ipairs(self.command.undo_funcs) do
                    table.insert(prev.undo_funcs, f)
                end
                                
                self.redo_stack = {}
                
                return
            end
        end
    end
    
    -- Update undo/redo stack
    table.insert(self.undo_stack, self.command)
    self.command = nil
    self.redo_stack = {}
    
end

return SceneModel