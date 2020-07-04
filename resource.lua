-- Resource manager module
local lily = require("enginelib.lily")
local log = require("enginelib.log")

local module = {}
local data_cache = {}

local function get_extension(path)
    return path:match("[^.]+$")
end

local function get_filename(path)
    return path:match("[^/]+$")
end

local function trim_extension(filename)
    return filename:match("^[^%.]+")
end

-- Map extensions to loader names
local ext_map = {
    -- Images
    png = "newImage",
    jpg = "newImage",
    jpeg ="newImage",
    
    -- Text
    lua = "read",
    txt = "read",
    glsl = "read",
    scene = "read",
    
    -- Audio
    wav = "newSource",
    ogg = "newSource",

    -- Misc
    ttf = "newFont"
}

-- Map extensions to resource classes
local ext_res = {
    png = "Texture",
    jpg = "Texture",
    jpeg = "Texture",
    scene = "PackedScene"
}

-- Love functions for when loading in the same thread
local loaders = {
    newSource = love.audio.newSource,
    newImage = love.graphics.newImage,
    read = love.filesystem.read,
    newFont = love.graphics.newFont
}

-- Helpers to generate arguments
local res_args = {
    ogg = function(path)
        local info = love.filesystem.getInfo(path)
        if not info.size or info.size > 1024 * 512 then
            return "stream"
        else
            return "static"
        end
    end
}
res_args.wav = res_args.ogg

-- Returns data at path, loads it in thread if it is not already
local function get_data(path, reload)
    if data_cache[path] then 
        if reload then
            log.info(("Reloading %s"):format(path))
        else 
            return data_cache[path]
        end
    end
    
    local ext = get_extension(path)
    local loader = loaders[ext_map[ext]]
    
    if loader then
        local arg_gen = res_args[ext]
        local data = loader(path, arg_gen and arg_gen(path))
        local info = love.filesystem.getInfo(path)
        local modtime = info.modtime or -1
        data_cache[path] = { data = data, modtime = modtime } 
        
        log.info(("Loaded in sync %s"):format(path))
    else
        
        log.warn(("No loader found for %s"):format(path))
    end
    
    return data_cache[path]
end

-- Recursively loads all assets in the given path and caches them
function module.load(path)
    local info = love.filesystem.getInfo(path)
    if info.type == "directory" then
        for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
            module.load(path .. "/" .. item)
        end
    elseif info.type == "file" then
        get_data(path, true)
    end

end

function module.is_loaded(path)
    return data_cache[path] ~= nil
end

function module.get_resource(path)
    local ext = get_extension(path)
    
    if not ext_res[ext] then
        log.error(("No associated resource type for %s"):format(path))
        return
    end
    
    local ok, rclass = pcall(require, ("class.engine.resource.%s"):format(ext_res[ext]))
    if ok then
        local instance = rclass()
        instance:set_data(get_data(path, false).data)
        instance:set_filepath(path)
        local info = love.filesystem.getInfo(path)
        local modtime = info.modtime or -1
        return instance
    end
end

local function get_file_paths(path, t)
    local info = love.filesystem.getInfo(path)
    if info.type == "directory" then
        for _,item in ipairs(love.filesystem.getDirectoryItems(path)) do
            get_file_paths(path .. "/" .. item, t)
        end
    elseif info.type == "file" then
        table.insert(t, path)
    end
end

-- Asynchronously loads all assets in the given path
function module.preload(path)
    local paths_to_load = {}
    get_file_paths(path, paths_to_load)
    
    local lily_list = {}
    
    for _, p in ipairs(paths_to_load) do
        local ext = get_extension(p)
        local lname = ext_map[ext]
    
        if lname then
            local arg_gen = res_args[ext]
            table.insert(lily_list, {
                lname, p, arg_gen and arg_gen(p)
            })
        end
        log.info(("Started preloading %s"):format(p))
    end
    
    local ml = lily.loadMulti(lily_list)
    ml:onLoaded(function(userdata, index, data)
        local original_path = paths_to_load[index]
        local info = love.filesystem.getInfo(path)
        local modtime = info.modtime or -1
        data_cache[original_path] = {data = data, modtime = modtime}
        
        log.info(("Loaded async %s"):format(original_path))
    end)
    
    ml:onError(function(userdata, index, message) 
        log.error(("Failed to load asset, %s"):format(message))
    end)
end

function module.has_new_version(path)
    if not module.is_loaded(path) then return true end

    local info = love.filesystem.getInfo(path)
    if info then
        local modtime = data_cache[path].modtime
        return (info.modtime or -1) > modtime
    end
    
    return false
end

return module