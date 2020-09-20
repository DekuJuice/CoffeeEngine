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

-- Resource manager module
local lily = require("enginelib.lily")
local binser = require("enginelib.binser")

local ImportedResource = require("class.engine.resource.ImportedResource")

local resource_cache = setmetatable({}, {__mode="v"})
local ext_associations = {}

local function get_extension(path)
    return path:match("[^.]+$")
end

local function get_filename(path)
    return path:match("[^/]+$")
end

local function trim_extension(filename)
    return filename:match("^[^%.]+")
end

-- Returns the resource class associated with a given extension
local function get_associated_resource_class(extension)
    return ext_associations[extension]
end

-- Right now we just use the path string as a key to the resource cache table
-- We may or may not need to change how this is implemented.
-- Returns nil if resource is not cached
local function get_cached_resource(path)
    return resource_cache[path]
end

local function cache_resource(path, res)
    res:set_filepath(path)
    resource_cache[path] = res
end

do
    -- Preload resource classes so we can traverse Resource for subclasses
    local function preload_class(dir)
        for _,v in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local path = dir .. "/" .. v
            local info = love.filesystem.getInfo(path)
            if info.type == "directory" then
                preload_class(path)
            else
                require(path:match("^[^%.]+"):gsub("/", "."))
            end
        end
    end

    preload_class("class/engine/resource")

    local Resource = require("class.engine.resource.Resource")
    
    -- Create extension associations
    local stack = {Resource}
    while (#stack > 0) do
        local rclass = table.remove(stack)
        for _,ext in ipairs(rclass.static.extensions) do
            ext_associations[ext] = rclass
        end
        
        for c in pairs(rclass.subclasses) do
            table.insert(stack, c)
        end
    end
end

local module = {}

local function finalize_resource(res, properties, fd)

    if properties then
        for k,v in pairs(properties) do
            local setter = ("set_%s"):format(k)
            if res[setter] then
                local ok, err = pcall(res[setter], res, v)
                if not ok then
                    log.error(err)
                end
            else
                log.error(("Invalid property %s, corrupted file?"):format(k))
            end
        end
    end
        
    if res.class:isSubclassOf(ImportedResource) then -- Need to finish initialization with the imported asset
        res:initialize_from_filedata(fd)
    end
end

-- Get the specified resource
-- Loads the resource in the current thread if it is not loaded
function module.get_resource(path)
    if not love.filesystem.getInfo(path, "file") then
        log.error(("File %s does not exist"):format(path))
        return
    end

    -- Check if resource is already loaded
    local cached = get_cached_resource(path)
    if cached then
        return cached
    end
    
    local rclass = get_associated_resource_class(get_extension(path))
    if not rclass then
        log.error(("No associated resource type for %s"):format(path))
        return
    end
    
    -- For imported resources, the filedata will be the original file
    -- For native resources, it will just be the serialized properties
    local fd = love.filesystem.newFileData(path)
    local res = rclass()
    local properties
    
    if res.class:isSubclassOf(ImportedResource) then
        local import_path = path .. "." .. settings.get_setting("import_ext")
        -- Attempt to load .import file if it exists
        if (love.filesystem.getInfo(import_path, "file")) then
            local err            
            local imp, read_err = love.filesystem.read(import_path)
            if imp then
                local ok, result = pcall(binser.deserialize, imp)
                if ok then
                    properties = result[1]
                    log.info(("Loaded import data for %s"):format(path))
                else
                    err = result
                end
            else
                err = read_err
            end
            
            if err then log.error(err) end
        else
            log.info(("No import data for %s found, using defaults"):format(path))        
        end
    else
        local ok, result = pcall(binser.deserialize, fd:getString())
        if ok then
            properties = result[1]
        else
            log.error(result)
            return 
        end        
    end    
        
    finalize_resource(res, properties, fd)
    
    cache_resource(path, res)
    res:set_has_unsaved_changes(false)
    log.info(("Loaded resource %s"):format(path))
    
    return res
end

function module.is_resource_loaded(path)
    return get_cached_resource(path) ~= nil
end

-- Load one or more resources in the background
function module.load_background(paths, on_complete, on_error, on_loaded)    
    local lily_args = {} -- Args to pass to lily.loadMultiple
    local load_info = {} -- Information on the resource being loaded
    local lily_index_map = {} -- Map lilyIndex to load_info, since imported resources may require more than 1 file
    
    -- Array of loaded resources, corresponding to paths
    -- Entries can be nil if the resource failed to load for whatever reason
    local loaded_resources = {}
    
    -- Create load infos for resources that aren't already loaded
    for _,p in ipairs(paths) do
        if module.is_resource_loaded(p) then
            goto CONTINUE
        end
        
        local rclass = get_associated_resource_class(get_extension(p))
        
        if not rclass then
            log.error(("No associated resource type for %s"):format(p))
            goto CONTINUE
        end
        
        local is_imported = rclass:isSubclassOf(ImportedResource)
        local info = {
            imported = is_imported,
            resource = rclass(),
            path = path
        }
        
        table.insert(load_info, info)
        local info_index = #load_info
        
        -- Request filedata
        table.insert(lily_args, {"newFileData", p})
        table.insert(lily_index_map, info_index)
        
        if is_imported then
            local import_path = p .. "." .. settings.get_setting("import_ext")
            -- Request import data
            table.insert(lily_args, {"read", import_path})
            table.insert(lily_index_map, info_index)
        end                

        ::CONTINUE::
    end

    local lobj = lily.loadMulti(lily_args)

    lobj:onLoaded(function(_, lily_index, data)
        local index = lily_index_map[lily_index]
        local info = load_info[index]
        -- Import data
        if type(data) == "string" then
            info.import_data = data        
        -- Filedata
        else
            info.filedata = data
        end
    end)

    lobj:onComplete(function()
    
        for _, info in ipairs(load_info) do
        
            if not info.filedata then goto CONTINUE end
            
            local properties
            local data_str
            if info.imported then            
                data_str = info.import_data       
            else
                data_str = info.filedata:getString()
            end
            
            local ok, res = pcall(binser.deserialize, data_str)
            if ok then
                properties = res[1]
            else
                log.error(res)
            end
            
            finalize_resource(info.resource, properties, info.filedata)
            cache_resource(info.path, info.resource)
            info.resource:set_has_unsaved_changes(false)
            
            ::CONTINUE::
        end
    
        if on_complete then on_complete(loaded_resources) end
    end)
    
    lobj:onError(function(_, lily_index, msg)
        local index = lily_index_map[lily_index]
        local info = load_info[index]
        log.error(msg)
        if on_error then on_error(index, msg) end
    end)
    
end

function module.uncache_resource(res)
    resource_cache[res:get_filepath()] = nil
end

-- These functions write to real directories rather than just appdata,
-- these should only be exposed in editor mode

if settings.get_setting("is_editor") then

function module.write_file(path, data, on_complete, on_error)
    local tname
    local rand = {}
    -- Generate random filename
    for i = 1, 16 do
        rand[i] = love.math.random(16) - 1
    end
    
    tname = ("/%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"):format(unpack(rand))
    
    local lobj = lily.write(tname, data)
    lobj:onComplete(function()
        local real_tmp = love.filesystem.getSaveDirectory() .. tname
        local real_path = love.filesystem.getWorkingDirectory() .. "/" .. path
        local backup_path = real_path .. "." .. settings.get_setting("backup_ext")
        
        -- Remove old backup
        os.remove(backup_path)
        
        -- Backup current
        os.rename(real_path, backup_path)
        
        -- Move new file
        os.rename(real_tmp, real_path)
                
        if on_complete then on_complete() end
    end)

    lobj:onError(function(_, msg)
        log.error(msg)
        if on_error then on_error() end
    end)
end

function module.save_resource(resource)
    assert(resource:get_filepath(), "Resource needs a path to be saved")
    
    local filepath = resource:get_filepath()
    local target_path = filepath
    
    if resource:isInstanceOf(ImportedResource) then
        target_path = ("%s.%s"):format(target_path, settings.get_setting("import_ext"))
    end
    
    local properties = {}
    for name, ep in pairs(resource.class:get_exported_vars()) do
        local getter = ("get_%s"):format(name)
        local val = resource[getter](resource)
        
        if val ~= ep.default then
            properties[name] = val 
        end
    end
    
    local data = binser.serialize(properties)
    
    module.write_file(target_path, data, function() 
        log.info(("Saved resource %s"):format(filepath))
        resource:set_has_unsaved_changes(false)
    end)
    
    cache_resource(filepath, resource)
end

end

return module