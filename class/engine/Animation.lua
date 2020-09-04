-- TODO: Asserts and error checking on everything

local Object = require("class.engine.Object")
local Animation = Object:subclass("Animation")

Animation:export_var("name", "string")
Animation:export_var("loop", "boolean")
Animation:export_var("length", "float")
Animation:export_var("tracks", "data")

Animation:binser_register()

function Animation:initialize()
    Object.initialize(self)
    
    self.name = "Unnamed"
    self.loop = false
    self.length = 1.0
    self.tracks = {}
    
end

function Animation:set_length(length)
    self.length = math.max(length, 0)
end

function Animation:add_function_track(path)
    assert(path ~= nil, "A path must be specified")

    local func_track = { 
        type = "func", 
        node_path = path,
        keyframes = {}
    }
    
    table.insert(self.tracks, func_track)
end

function Animation:add_variable_track(path, property, update_discrete, wrap_clamp)
    assert(path ~= nil, "A path must be specified")
    assert(property ~= nil, "A property must be specified")
    
    if update_discrete == nil then update_discrete = false end
    if wrap_clamp == nil then wrap_clamp = false end
    
    local var_track = {
        type = "var",
        node_path = path,
        property = property,
        update_discrete = update_discrete,
        wrap_clamp = wrap_clamp,
        keyframes = {}
    }
    
    table.insert(self.tracks, var_track)
end

function Animation:get_track_count()
    return #self.tracks
end

function Animation:track_get_type(index)
    return self.tracks[index].type
end

function Animation:track_get_key_count(index)
    return #self.tracks[index].keyframes
end

function Animation:track_get_key_time(track_index, key_index)
    return self.tracks[track_index].keyframes[key_index].time
end

-- return index of key if one exists, cannot have multiple keys at the same time
function Animation:track_get_key_index(track_index, key_time)
    for i , kf in ipairs(self.tracks[track_index].keyframes) do
        if kf.time == key_time then
            return i
        end
    end
end

-- Will replace keys if they have the same time
function Animation:track_set_key_time(track_index, key_index, new_time)
    local old = table.remove(self.tracks[track_index].keyframes, key_index)
    if self.tracks[track_index].type == "var" then
        self:variable_track_add_key(track_index, new_time, old.value, old.lerp)
    elseif self.tracks[track_index].type == "func" then
        self:function_track_add_key(track_index, new_time, old.func_name, old.args)
    end
end

function Animation:track_remove_key(track_index, key_index)
    table.remove(self.tracks[track_index].keyframes, key_index)
end

function Animation:track_get_node_path(track_index)
    return self.tracks[track_index].node_path
end

function Animation:remove_track(index)
    table.remove(self.tracks, index)
end

function Animation:function_track_add_key(index, time, func_name, args)
    assert(self:track_get_type(index) == "func", "Track must be a function track")
    
    local keyframes = self.tracks[index].keyframes

    local new_kf = {
        time = time,
        func_name = func_name,
        args = args or {}
    }
    
    if #keyframes == 0 then
        table.insert(keyframes, new_kf)
        return
    end
    
    for j, kf in ipairs(keyframes) do
        if kf.time == time then
            keyframes[j] = new_kf
            return
        elseif kf.time < time then
            table.insert(keyframes, j + 1, new_kf)
            return
        end
    end

    table.insert(keyframes, 1, new_kf)
end

function Animation:function_track_set_key_function_name(track_index, key_index, func_name)
end

function Animation:function_track_set_key_function_arguments(track_index, key_index, arguments)

end

function Animation:function_track_get_key_indices(track_index, time_start, delta)
    assert(self:track_get_type(track_index) == "func", "Track must be a function track")
    
    local keyframes = self.tracks[track_index].keyframes
    local indices = {}
    local time_end = (time_start + delta) % self.length
    
    if time_end >= time_start then
        for i,kf in ipairs(keyframes) do
            if kf.time >= time_start 
            and kf.time <= self.length
            and kf.time < time_end then
                table.insert(indices, i)
            end
        end
    else
        for i,kf in ipairs(keyframes) do
            if (kf.time >= time_start 
            and kf.time <= self.length)
            or kf.time < time_end then
                table.insert(indices, i)
            end
        end
    end
    
    return indices
end

function Animation:function_track_get_function_name(track_index, key_index)
    return self.tracks[track_index].keyframes[key_index].func_name 
end

function Animation:function_track_get_function_arguments(track_index, key_index) 
    return self.tracks[track_index].keyframes[key_index].args
end

function Animation:variable_track_get_update_discrete(track_index)
    return self.tracks[track_index].update_discrete
end

function Animation:variable_track_set_update_discrete(track_index, update_mode)
    self.tracks[track_index].update_discrete = update_mode
end

function Animation:variable_track_get_wrap_clamp(track_index)
    return self.tracks[track_index].wrap_clamp
end

function Animation:variable_track_set_wrap_clamp(track_index, wrap_mode)
    self.tracks[track_index].wrap_clamp = wrap_mode
end

function Animation:variable_track_add_key(index, time, value, lerp)
    assert(self:track_get_type(index) == "var", "Track must be a variable track")
    
    local keyframes = self.tracks[index].keyframes
    local new_kf = {
        time = time,
        value = value,
        lerp = lerp
    }
    
    if #keyframes == 0 then
        table.insert(keyframes, new_kf)
        return
    end
    
    for j, kf in ipairs(keyframes) do
        if kf.time == time then
            keyframes[j] = new_kf
            return
        elseif time < kf.time then
            table.insert(keyframes, j, new_kf)
            return
        end
    end
    
    table.insert(keyframes, new_kf)
    
end

function Animation:variable_track_get_value(track_index, key_index)
    return self.tracks[track_index].keyframes[key_index].value
end

function Animation:variable_track_get_property(track_index)
    return self.tracks[track_index].property
end

function Animation:variable_track_get_lerp(track_index, key_index)
    
end

function Animation:variable_track_get_previous_index(track_index, time)
    local keyframes = self.tracks[track_index].keyframes
    
    for i = #keyframes, 1, -1 do
        if time >= keyframes[i].time then
            return i
        end
    end
    
    if not self.tracks[track_index].wrap_clamp and #keyframes > 0 then
        for i = #keyframes, 1, -1 do
            if keyframes[i].time <= self.length then
                return i
            end
        end    
    end
    
    return nil
end

function Animation:variable_track_get_next_index(track_index, time)
    local keyframes = self.tracks[track_index].keyframes

    for i, keyframe in ipairs(keyframes) do
        if keyframe.time > time then
            return i
        end
    end
    
    if not self.tracks[track_index].wrap_clamp and #keyframes > 0 then
        return 1
    end
end

return Animation