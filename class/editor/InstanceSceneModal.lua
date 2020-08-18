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
    local tree = scene:get_tree()
    
    local ps = resource.get_resource(self.selection)
    local ok, res = pcall(ps.instance, ps)
    
    if not ok then
        log.error(res)
        self.is_open = false
        return
    end
    
    local cmd = scene:create_command("Instance Node")
    
    local root = tree:get_root()
    if root then
        local par = root
        if sel[1] then par = sel[1] end
        
        cmd:add_do_func(function()
            par:add_child(res)
            res:set_owner(root)
            scene:set_selected_nodes({res})            
        end)
        cmd:add_undo_func(function()
            par:remove_child(res)
            scene:set_selected_nodes(sel)
        end)

    else
        cmd:add_do_var(tree, "root", res)
        cmd:add_do_func(function()
            scene:set_selected_nodes({res})
        end)
        cmd:add_undo_var(tree, "root", nil)
        cmd:add_undo_func(function()
            scene:set_selected_nodes({})
        end)
    end
    
    scene:commit_command(cmd)

    self.is_open = false
end


return InstanceSceneModal