local OpenSceneModal = require("class.editor.OpenSceneModal")
local InstanceSceneModal = OpenSceneModal:subclass("InstanceSceneModal")

function InstanceSceneModal:initialize()
    OpenSceneModal.initialize(self)
    self.window_name = "Instance Scene"
end

function InstanceSceneModal:confirm_selection()
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    local sel = model:get_selected_nodes()
    local tree = model:get_tree()
    
    local ps = resource.get_resource(self.selection)
    local ok, res = pcall(ps.instance, ps)
    
    if not ok then
        log.error(res)
        self.is_open = false
        return
    end
    
    local root = tree:get_root()
    
    
    
    local cmd = model:create_command("Instance Node")
    local cur_scene = tree:get_current_scene()
    
    if cur_scene then
        local par = cur_scene
        if sel[1] then par = sel[1] end
        
        cmd:add_do_func(function()
                par:add_child(res)
                res:set_owner(cur_scene)
                model:set_selected_nodes({res})            
            end)
        cmd:add_undo_func(function()
                par:remove_child(res)
                model:set_selected_nodes(sel)
            end)
        
    else
        
        cmd:add_do_func(function()
                tree:set_current_scene(res)
                model:set_selected_nodes({res})
            end)
            
        cmd:add_undo_func(function()
                tree:set_current_scene(nil)
                model:set_selected_nodes(sel)
            end)
    end

    model:commit_command(cmd)

    self.is_open = false
end


return InstanceSceneModal