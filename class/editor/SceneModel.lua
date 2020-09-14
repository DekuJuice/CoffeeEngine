local middleclass = require("enginelib.middleclass")

local PackedScene = require("class.engine.resource.PackedScene")
local SceneTree = require("class.engine.SceneTree")

local Object = require("class.engine.Object")

local Command = middleclass("UndoRedoCommand")
local _nil_placehold = {}

function Command:initialize(name, merge_mode)
    self.name = name or ""
    self.do_funcs = {}
    self.undo_funcs = {}
    
    self.do_vars = {}
    self.undo_vars = {}
    self.references = {}
    self.merge_mode = merge_mode
end

function Command:merge_with(other)

    if self.merge_mode == "merge_all" then
        -- Combine functions and values
        for _,f in ipairs(other.do_funcs) do
            table.insert(self.do_funcs, f)
        end
        
        for _,f in ipairs(other.undo_funcs) do
            table.insert(self.undo_funcs, f)
        end
        
        for obj, vals in pairs(other.do_vars) do
            if self.do_vals[obj] then
                for k,v in pairs(vals) do
                    self.do_vals[obj][k] = v
                end
            else
                self.do_vals[obj] = vals
            end
        end
        
        for obj, vals in pairs(other.undo_vars) do
            if self.do_vals[obj] then
                for k,v in pairs(vals) do
                    self.undo_vals[obj][k] = v
                end
            else
                self.undo_vals[obj] = vals
            end
        end
    -- Use the oldest command's undo, and the newest's redo. Useful for things like merging incremental changes
    elseif self.merge_mode == "merge_ends" then  
        self.do_funcs = other.do_funcs
        self.do_vars = other.do_vars  
    end
    
    self.merge_mode = other.merge_mode
end

function Command:add_do_func(func)
    table.insert(self.do_funcs, func)
end

function Command:add_undo_func(func)
    table.insert(self.undo_funcs, func)
end

function Command:add_do_var(object, var, value)
    if not self.do_vars[object] then
        self.do_vars[object] = {}
    end
    
    if value == nil then value = _nil_placehold end
    self.do_vars[object][var] = value
end

function Command:add_undo_var(object, var, value)
    if not self.undo_vars[object] then
        self.undo_vars[object] = {}
    end
    
    if value == nil then value = _nil_placehold end
    self.undo_vars[object][var] = value
end

function Command:do_command()
    for _,f in ipairs(self.do_funcs) do
        f()
    end
    
    for obj, vars in pairs(self.do_vars) do
        for k,v in pairs(vars) do
            local setter = ("set_%s"):format(k)
            if v == _nil_placehold then v = nil end
            obj[setter](obj, v)
        end
    end
end

function Command:undo_command()
    for _,f in ipairs(self.undo_funcs) do
        f()
    end
    
    for obj, vars in pairs(self.undo_vars) do
        for k,v in pairs(vars) do
            local setter = ("set_%s"):format(k)
            if v == _nil_placehold then v = nil end
            obj[setter](obj, v)
        end
    end
    
end

local SceneModel = Object:subclass("SceneModel")
SceneModel:define_get_set("grid_minor")
SceneModel:define_get_set("grid_major")
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
    self.undo_stack = {}
    self.redo_stack = {}

    self.selected_nodes = {}
    
    -- Grid config
    self.draw_grid = true
    self.grid_minor = vec2(16, 16)
    self.grid_major = vec2(416, 240)
    
    if loadpath then
        self.packed_scene = resource.get_resource(loadpath)
        if not self.packed_scene then
            error("Failed to load scene")
        end
        
        self.packed_scene:set_has_unsaved_changes(false)
    else
        self.packed_scene = PackedScene()
    end
    
    self.tree = SceneTree()
    self.tree:set_is_editor(true)
    
    if loadpath then
        local scene = self.packed_scene:instance()

        -- Clear filepath, as we're loading the scene directly for editing,
        -- not instancing it
        scene:set_filepath(nil)        
        self.tree:get_root():set_current_scene(scene)
        
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
    local cur_scene = self:get_tree():get_current_scene()
    assert(cur_scene, "Model needs a root node to be packed")
    self.packed_scene:pack(cur_scene)
    return self.packed_scene
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

function SceneModel:set_modified(modified)
    self.packed_scene:set_has_unsaved_changes(modified)
end

function SceneModel:get_modified()
    return self.packed_scene:get_has_unsaved_changes()
end

function SceneModel:undo()    
    local command = table.remove(self.undo_stack)
    if not command then return end
    
    command:undo_command()

    table.insert(self.redo_stack, command)
    self:set_modified(true)
    
end

function SceneModel:redo()

    local command = table.remove(self.redo_stack)
    if not command then return end

    command:do_command()
    
    table.insert(self.undo_stack, command)
    self:set_modified(true)
end

function SceneModel:create_command(name, merge_mode)
    return Command(name, merge_mode)
end

function SceneModel:commit_command(cmd)
    self.redo_stack = {}

    local top = self.undo_stack[#self.undo_stack]
    
    cmd:do_command()
    if top and top.merge_mode then

        if top.name == cmd.name then
            top:merge_with(cmd)
            return
        end
    end
    
    self:set_modified(true)
    table.insert(self.undo_stack, cmd)
end


return SceneModel