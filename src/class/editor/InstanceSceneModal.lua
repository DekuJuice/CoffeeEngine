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
    
    -- Check for cyclical instancing
    local stack = {res}
    if model:get_filepath() then
        while #stack > 0 do
        
            local top = table.remove(stack)
            for _,v in ipairs(top.children) do
                table.insert(stack, v)
            end
        
            if top:get_filepath() == model:get_filepath() then
                log.error("Cycle found while instancing")
                self.is_open = false
                return
            end
        end
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