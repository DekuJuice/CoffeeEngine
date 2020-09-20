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

local TRACK_TYPE_INDEX = 1
local TRACK_NODE_PATH_INDEX = 2
local TRACK_KEYFRAME_INDEX = 3
local TRACK_PROPERTY_OFFSET = 3

local KEYFRAME_TIME_INDEX = 1
local KEYFRAME_DATA_OFFSET = 1

local VAR_PROPERTY_INDEX = 1
local VAR_UPDATE_DISCRETE_INDEX = 2
local VAR_WRAP_CLAMP_INDEX = 3

local VAR_KEY_VALUE_INDEX = 1
local VAR_KEY_LERP_INDEX = 1

local FUNC_KEY_NAME_INDEX = 1
local FUNC_KEY_ARG_INDEX = 2

local class = require("enginelib.middleclass")
local binser = require("enginelib.binser")
local Animation = class("Animation")

function Animation:initialize()
    self.name = "Unnamed"
    self.loop = false
    self.length = 1.0
    self.tracks = {}
end

function Animation:_serialize()
    return self.name, self.loop, self.length, self.tracks
end

function Animation.static.deserialize(name, loop, length, tracks)
    local anim = Animation:allocate()
    anim.name = name
    anim.loop = loop
    anim.length = length
    anim.tracks = tracks
    return anim
end

binser.registerClass(Animation)

function Animation:set_name(name)
    self.name = name
end

function Animation:get_name()
    return self.name
end

function Animation:set_loop(loop)
    self.loop = loop
end

function Animation:get_loop()
    return self.loop
end

function Animation:set_length(length)
    self.length = length
end

function Animation:get_length()
    return self.length
end

function Animation:set_length(length)
    self.length = math.max(length, 0)
end

function Animation:add_track(type, node_path, ...)
    type = type or ""
    table.insert(self.tracks,
        {
            type,
            node_path,
            {},
            ... -- additional properties
        }
    )
end

function Animation:remove_track(track_index)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    table.remove(self.tracks, track_index)
end

function Animation:get_track_count()
    return #self.tracks
end

function Animation:get_track_property(track_index, prop_index)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    assert(prop_index <= #track - TRACK_PROPERTY_OFFSET, prop_index > 0, "Property index out of bounds")
    
    return track[prop_index + TRACK_PROPERTY_OFFSET]
end

function Animation:set_track_property(track_index, prop_index, val)
    assert(val ~= nil, "Value cannot be nil")    
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    assert(prop_index <= #track - TRACK_PROPERTY_OFFSET, prop_index > 0, "Property index out of bounds")
    
    track[prop_index + TRACK_PROPERTY_OFFSET] = val
end

function Animation:get_track_type(track_index)    
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    return track[TRACK_TYPE_INDEX]
end

function Animation:get_track_node_path(track_index)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    return track[TRACK_NODE_PATH_INDEX]
end

function Animation:set_track_node_path(track_index, node_path)
    assert(node_path ~= nil, "Node path must not be nil")
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    track[TRACK_NODE_PATH_INDEX] = node_path
end

function Animation:add_keyframe(track_index, keyframe_time, ...)    
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    local new_kf = {
        keyframe_time,
        ... -- additional data
    }
    
    if #keyframes == 0 then
        table.insert(keyframes, new_kf)
        return
    end
    
    for i, kf in ipairs(keyframes) do
        local time = kf[KEYFRAME_TIME_INDEX]
        if time == keyframe_time then
            keyframes[i] = new_kf
            return
        elseif time < keyframe_time then
            table.insert(keyframes, i + 1, new_kf)
            return
        end
    end

    table.insert(keyframes, 1, new_kf)
end

function Animation:remove_keyframe(track_index, keyframe_index)    
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    assert(keyframe_index <= #keyframes and keyframe_index > 0, "Keyframe index out of bounds")
    
    table.remove(keyframes, keyframe_index)
end

function Animation:set_keyframe_time(track_index, keyframe_index, new_time)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    assert(keyframe_index <= #keyframes and keyframe_index > 0, "Keyframe index out of bounds")
    
    local old = table.remove(keyframes, keyframe_index)
    
    self:add_keyframe(track_index, new_time, unpack(old, KEYFRAME_DATA_OFFSET + 1))
end

function Animation:set_keyframe_data(track_index, keyframe_index, data_index, val)    
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    assert(keyframe_index <= #keyframes and keyframe_index > 0, "Keyframe index out of bounds")
    
    local kf = keyframes[keyframe_index]    
    assert(data_index <= #kf - KEYFRAME_DATA_OFFSET, data_index > 0, "Data index out of range")
    
    kf[data_index + KEYFRAME_DATA_OFFSET] = val    
end

function Animation:get_keyframe_data(track_index, keyframe_index, data_index)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    assert(keyframe_index <= #keyframes and keyframe_index > 0, "Keyframe index out of bounds")
    
    local kf = keyframes[keyframe_index]
    assert(data_index <= #kf - KEYFRAME_DATA_OFFSET, data_index > 0, "Data index out of range")    
    
    return kf[data_index + KEYFRAME_DATA_OFFSET]
end

function Animation:get_keyframe_time(track_index, keyframe_index)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    assert(keyframe_index <= #keyframes and keyframe_index > 0, "Keyframe index out of bounds")
    
    return keyframes[keyframe_index][KEYFRAME_TIME_INDEX]
end

function Animation:get_keyframe_index(track_index, keyframe_time)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    for i, kf in ipairs(keyframes) do
        local time = kf[KEYFRAME_TIME_INDEX]
        if time == keyframe_time then
            return i
        end
    end
end

function Animation:get_keyframe_count(track_index)
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    return #keyframes
end

function Animation:add_function_track(path)
    assert(path ~= nil, "A path must be specified")
    self:add_track("func", path)
end

function Animation:add_variable_track(path, property, update_discrete, wrap_clamp)
    assert(path ~= nil, "A path must be specified")
    assert(property ~= nil, "A property must be specified")
    
    if update_discrete == nil then update_discrete = false end
    if wrap_clamp == nil then wrap_clamp = false end
    
    self:add_track("var", path, property, update_discrete, wrap_clamp)
end

function Animation:function_track_add_key(track_index, time, func_name, args)
    assert(self:get_track_type(track_index) == "func", "Track must be a function track")

    args = args or {}
    
    self:add_keyframe(track_index, time, func_name, args)
end

function Animation:function_track_get_key_indices(track_index, time_start, delta)
    assert(self:get_track_type(track_index) == "func", "Track must be a function track")
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    local indices = {}
    local time_end = (time_start + delta) % self.length
    
    if time_end >= time_start then
        for i,kf in ipairs(keyframes) do
            local time = kf[KEYFRAME_TIME_INDEX]
            
            if time >= time_start 
            and time <= self.length
            and time < time_end then
                table.insert(indices, i)
            end
        end
    else
        for i,kf in ipairs(keyframes) do
            local time = kf[KEYFRAME_TIME_INDEX]
            if (time >= time_start 
            and time <= self.length)
            or time < time_end then
                table.insert(indices, i)
            end
        end
    end
    
    return indices
end

function Animation:function_track_set_key_func_name(track_index, keyframe_index, func_name)
    assert(self:get_track_type(track_index) == "func", "Track must be a function track")
    self:set_keyframe_data(track_index, keyframe_index, FUNC_KEY_NAME_INDEX, func_name)
end

function Animation:function_track_get_key_func_name(track_index, keyframe_index)
    assert(self:get_track_type(track_index) == "func", "Track must be a function track")
    return self:get_keyframe_data(track_index, keyframe_index, FUNC_KEY_NAME_INDEX)
end

function Animation:function_track_set_key_args(track_index, keyframe_index, args)
    assert(self:get_track_type(track_index) == "func", "Track must be a function track")
    self:set_keyframe_data(track_index, keyframe_index, FUNC_KEY_ARG_INDEX, args)
end

function Animation:function_track_get_key_args(track_index, keyframe_index)
    assert(self:get_track_type(track_index) == "func", "Track must be a function track")
    return self:get_keyframe_data(track_index, keyframe_index, FUNC_KEY_ARG_INDEX)
end

function Animation:variable_track_add_key(track_index, time, value, lerp)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    self:add_keyframe(track_index, time, value, lerp)
end

function Animation:variable_track_get_property(track_index)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")    
    return self:get_track_property(track_index, VAR_PROPERTY_INDEX)
end

function Animation:variable_track_set_property(track_index, property)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    self:set_track_property(track_index, VAR_PROPERTY_INDEX, property)
end

function Animation:variable_track_get_update_discrete(track_index)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")    
    return self:get_track_property(track_index, VAR_UPDATE_DISCRETE_INDEX)
end

function Animation:variable_track_set_update_discrete(track_index, update_discrete)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    self:set_track_property(track_index, VAR_UPDATE_DISCRETE_INDEX, update_discrete)
end

function Animation:variable_track_get_wrap_clamp(track_index)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    return self:get_track_property(track_index, VAR_WRAP_CLAMP_INDEX)

end

function Animation:variable_track_set_wrap_clamp(track_index, wrap_clamp)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    self:set_track_property(track_index, VAR_WRAP_CLAMP_INDEX, wrap_clamp)
end

function Animation:variable_track_get_previous_index(track_index, time)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]
    
    for i = #keyframes, 1, -1 do
        if time >= keyframes[i][KEYFRAME_TIME_INDEX] then
            return i
        end
    end
    
    local wrap_clamp = track[TRACK_PROPERTY_OFFSET + VAR_WRAP_CLAMP_INDEX]
    
    if not wrap_clamp and #keyframes > 0 then
        for i = #keyframes, 1, -1 do
            if keyframes[i][KEYFRAME_TIME_INDEX] <= self.length then
                return i
            end
        end    
    end
    
    return nil
end

function Animation:variable_track_get_next_index(track_index, time)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")
    assert(track_index <= self:get_track_count() and track_index > 0, "Track index out of bounds")    
    local track = self.tracks[track_index]
    local keyframes = track[TRACK_KEYFRAME_INDEX]

    for i, keyframe in ipairs(keyframes) do
        if keyframe[KEYFRAME_TIME_INDEX] > time then
            return i
        end
    end
    
    local wrap_clamp = track[TRACK_PROPERTY_OFFSET + VAR_WRAP_CLAMP_INDEX]
    
    if not wrap_clamp and #keyframes > 0 then
        return 1
    end
end

function Animation:variable_track_get_key_value(track_index, keyframe_index)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")    
    return self:get_keyframe_data(track_index, keyframe_index, VAR_KEY_VALUE_INDEX)
end

function Animation:variable_track_set_key_value(track_index, keyframe_index, value)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")    
    self:set_keyframe_data(track_index, keyframe_index, VAR_KEY_VALUE_INDEX, value)
end

function Animation:variable_track_get_key_lerp(track_index, keyframe_index)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")    
    return self:get_keyframe_data(track_index, keyframe_index, VAR_KEY_LERP_INDEX)
end

function Animation:variable_track_set_key_lerp(track_index, keyframe_index, lerp)
    assert(self:get_track_type(track_index) == "var", "Track must be a variable track")    
    self:set_keyframe_data(track_index, keyframe_index, VAR_KEY_LERP_INDEX, lerp)
end

return Animation