local Node = require("class.engine.Node")
local AnimationPlayer = Node:subclass("AnimationPlayer")

AnimationPlayer.static.icon = IconFont and IconFont.FILM

AnimationPlayer:define_signal("animation_finished")

function AnimationPlayer:initialize()
    Node.initialize(self)
    
    self.animations = {}
    self.autoplay = false
    self.playing = false
    self.current_animation = nil
    self.initial_animation = nil
    
    self.playback_position = 0
end

function AnimationPlayer:ready()
    if self.autoplay then        
        self:play()
    end
    self.current_animation = self.initial_animation
end

function AnimationPlayer:_update_var_track(anim, t_index)
    local node_path = anim:track_get_node_path(t_index)
    local target_node = self:get_node(node_path)
    
    if not target_node then
        log.error(("Node path %q does not point to any node"):format(node_path))
        return
    end
    
    local property = anim:variable_track_get_property(t_index)
    
    local setter = ("set_%s"):format(property)
    if not target_node[setter] then
        log.error(("The node at the specified path does not have the property %q"):format(property))
        return
    end
    
    local pi = anim:variable_track_get_previous_index(t_index, self.playback_position)
    local ni = anim:variable_track_get_next_index(t_index, self.playback_position)
    
    if not pi and not ni then -- no keyframes
        return 
    end
    
    local final_val
    
    if anim:variable_track_get_update_discrete(t_index) then
        
        if pi then
            final_val = anim:variable_track_get_value(t_index, pi)
        else
            return
        end
        
    else
    
        if not pi then
            final_val = anim:variable_track_get_value(t_index, ni)
        elseif not ni then
            final_val = anim:variable_track_get_value(t_index, pi)
        else
        
            local ptime = anim:track_get_key_time(t_index, pi)
            local ntime = anim:track_get_key_time(t_index, ni)
            
            local pval = anim:variable_track_get_value(t_index, pi)
            local nval = anim:variable_track_get_value(t_index, ni)
            
            local t_dist = ntime - ptime
            if ntime < ptime then
                t_dist = t_dist + anim:get_length()
            end
            
            local rt = self.playback_position - ptime
            if self.playback_position < ptime then
                rt = rt + anim:get_length()
            end
            
            -- TODO: lerp the values according to key lerp value
            local t = rt / t_dist
            
            final_val = pval + (nval - pval) * t
            
            
        end
        
    end
    
    target_node[setter](target_node, final_val)
    
    
end

function AnimationPlayer:_update_func_track(anim, t_index, time_start, dt)
    local node_path = anim:track_get_node_path(t_index)
    local target_node = self:get_node(node_path)
    if not target_node then
        log.error(("Node path %q does not point to any node"):format(node_path))
        return
    end
    
    local indices = anim:function_track_get_key_indices(t_index, time_start, dt)
    
    for _, i in ipairs(indices) do
        local func_name = anim:function_track_get_function_name(t_index, i)
        local func_args = anim:function_track_get_function_arguments(t_index, i)
        
        if type(target_node[func_name]) == "function" then
            target_node[func_name](unpack(func_args))
        else
            log.error(("Node at %q does not have function %q"):format(node_path, func_name))

        end
    end
end

function AnimationPlayer:update(dt)
    if not self.playing then return end
    local anim = self:get_animation(self.current_animation)
    if not anim then return end
    local prev = self.playback_position
    self.playback_position = self.playback_position + dt        
    if self.playback_position > anim:get_length() then
        if anim:get_loop() then
            self.playback_position = self.playback_position % anim:get_length()                
        else
            self.playback_position = anim:get_length()
            self.playing = false
        end            
    end 
        
    for i = 1, anim:get_track_count() do
        local ttype = anim:track_get_type(i)
        if ttype == "var" then                
            self:_update_var_track(anim, i)
        elseif ttype == "func" then
            self:_update_func_track(anim, i, prev, dt)
        end
    end       
end

function AnimationPlayer:editor_update(dt)
    if not self.playing then return end
    local anim = self:get_animation(self.current_animation)
    if not anim then return end

    self.playback_position = self.playback_position + dt        
    if self.playback_position > anim:get_length() then
        if anim:get_loop() then
            self.playback_position = self.playback_position % anim:get_length()                
        else
            self.playback_position = anim:get_length()
            self.playing = false
        end            
    end 
        
    for i = 1, anim:get_track_count() do
        local ttype = anim:track_get_type(i)
        if ttype == "var" then                
            self:_update_var_track(anim, i)
        end
    end        
end

function AnimationPlayer:editor_exit_tree()
    self:stop()
end

function AnimationPlayer:play()
    self.playing = true
end

function AnimationPlayer:stop()
    self.playing = false
end

function AnimationPlayer:get_playing()
    return self.playing
end

function AnimationPlayer:set_playback_position(pos, update)
    pos = math.max(pos, 0)
    
    local cur = self:get_animation(self.current_animation)
    if cur then
        pos = math.min(pos, cur:get_length())
    end
        
    self.playback_position = pos

    if update and cur then
        for i = 1, cur:get_track_count() do
            local ttype = cur:track_get_type(i)
            if ttype == "var" then
                self:_update_var_track(cur, i)
            end
        end
    end
end

function AnimationPlayer:add_animation(anim)
    local oname = anim:get_name()
    if self.animations[oname] then
        local num = (tonumber(oname:match("%d+$")) or 1) + 1
        oname = oname:gsub("%d+$", "")
        oname = ("%s%d"):format(oname, num)
        anim:set_name(oname)
    end
    
    self.animations[oname] = anim 
end

function AnimationPlayer:remove_animation(name)
    self.animations[name] = nil
end

function AnimationPlayer:get_animation(name)
    return self.animations[name]
end

function AnimationPlayer:get_animation_list()
    local list = {}
    
    for name in pairs(self.animations) do
        table.insert(list, name)
    end
    
    table.sort(list)
    
    return list
end

AnimationPlayer:define_get_set("playback_position")
AnimationPlayer:define_get_set("current_animation")

AnimationPlayer:export_var("animations", "data")
AnimationPlayer:export_var("autoplay", "bool")
AnimationPlayer:export_var("initial_animation", "enum", {enum = AnimationPlayer.get_animation_list, include_nil = true})
AnimationPlayer:binser_register()

return AnimationPlayer