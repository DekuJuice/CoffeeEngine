local Resource = require("class.engine.resource.Resource")
local Animation = Resource:subclass("Animation")
Animation.static.extensions = {"anim"}
Animation.static.dontlist = true

Animation:export_var("name", "string")
Animation:export_var("loop", "boolean")
Animation:export_var("length", "float")
Animation:export_var("tracks", "data")


Animation:binser_register()

function Animation:initialize()
    Resource.initialize(self)
    
    self.name = ""
    self.loop = false
    self.length = 1.0
    self.tracks = {}
    
    
end

function Animation:duplicate()
end

function Animation:add_function_track(name, node_path)
    local func_track = { 
        name = name,
        type = "func", 
        node_path = node_path,
        keyframes = {}
    }
    
    table.insert(self.tracks, func_track)
end

function Animation:add_variable_track(name, node_path, property, update_mode)
    assert(property ~= nil, "A property must be specified")
    
    local var_track = {
        name = name,
        type = "var",
        node_path = node_path,
        property = property,
        update_mode = update_mode or "continuous",
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

function Animation:remove_track(index)
    table.remove(self.tracks, index)
end

function Animation:function_track_add_key(index, time, func_name, args)
    assert(self:track_get_type(index) == "func", "Track must be a function track")
    
    local keyframes = self.tracks[index].keyframes

    local kf = {
        time = time,
        func_name = func_name,
        args = args
    }
    
    for j, kf in ipairs(keyframes) do
        if kf.time == time then
            keyframes[j] = kf
            return
        elseif kf.time > time then
            table.insert(keyframes, j, kf)
            return
        end
    end
    
end

function Animation:function_track_get_key_indices(track_index, time_start, delta)
    assert(self:track_get_type(track_index) == "func", "Track must be a function track")
    
    local keyframes = self.tracks[track_index].keyframes
    local indices = {}
    local time_end = (time_start + delta) % self.length
    
    if time_end >= time_start then
        for i,kf in ipairs(keyframes) do
            if kf.time >= time_start then
                table.insert(indices, i)
            end
        end
        
        for i,kf in ipairs(keyframes) do
            if kf.time < time_end then
                table.insert(indices, i)
            end
        end
    else
        for i,kf in ipairs(keyframes) do
            if kf.time >= time_start and kf.time < time_end then
                table.insert(indices, i)
            end
        end
    end
    
    return indices
end

function Animation:function_track_get_function_name(track_index, key_index)
    
end

function Animation:function_track_get_function_arguments()
end

function Animation:variable_track_add_key(index, time, value, lerp)
    assert(self:track_get_type(index) == "var", "Track must be a variable track")
    
    local keyframes = self.tracks[index].keyframes
    local kf = {
        time = time,
        value = value,
        lerp = lerp
    }
    
    for j, kf in ipairs(keyframes) do
        if kf.time == time then
            keyframes[j] = kf
            return
        elseif kf.time > time then
            table.insert(keyframes, j, kf)
            return
        end
    end
    
end


return Animation



