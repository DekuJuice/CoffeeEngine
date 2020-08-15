local OpenSceneModal = require("class.editor.OpenSceneModal")
local InstanceSceneModal = OpenSceneModal:subclass("InstanceSceneModal")

function InstanceSceneModal:initialize()
    OpenSceneModal.initialize(self)
    self.window_name = "Instance Scene"
end

function InstanceSceneModal:confirm_selection()
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    local sel = scene:get_selected_nodes()
    local path
    if sel[1] then path = sel[1]:get_absolute_path() end
    
    local ps = resource.get_resource(self.selection)
    local ok, res = pcall(ps.instance, ps)
    
    if ok then
        res:set_is_instance(true)
        res:propagate_event_preorder("set_is_instance", false, true)
        res:propagate_event_preorder("set_filepath", false, self.selection)
        
        local cmd = scene:create_command("Instanced Scene")
        cmd:add_do_func(function()
            scene:add_node(path, res)
            scene:set_selected_nodes({res})
        end)
        
        cmd:add_undo_func(function()
            scene:remove_node(res)
            scene:set_selected_nodes(sel)
        end)
        
        scene:commit_command(cmd)
        
        
    else
        log.error(res)
    end
    


    self.is_open = false
end


return InstanceSceneModal