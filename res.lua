-- Resource manager module
local lily = require("enginelib.lily")
local binser = require("enginelib.binser")

local ImportedResource = require("class.engine.resource.ImportedResource")

local IMPORT_EXT = ".import"
local BACKUP_EXT = ".bak"

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

    -- Otherwise, load it from disk and cache it
    local rclass = get_associated_resource_class(get_extension(path))
    if not rclass then
        log.error(("No associated resource type for %s"):format(path))
        return
    end
    
    local fd = love.filesystem.newFileData(path)
    local res

    if rclass:isSubclassOf(ImportedResource) then
        local import_path = path .. IMPORT_EXT
        -- Attempt to load .import file if it exists
        -- Deserializing the import file creates an instance of the resource
        if (love.filesystem.getInfo(import_path, "file")) then
            local err
            
            local imp, read_err = love.filesystem.read(import_path)
            if imp then
                local ok, result = pcall(binser.deserialize, imp)
                if ok then
                    res = result[1]
                    log.info(("Loaded import data for %s"):format(path))
                else
                    err = result
                end
            else
                err = read_err
            end
            
            if err then log.error(err) end
        end
        
        if not res then
            log.info(("No import data for %s found, using defaults"):format(path))
            res = rclass()
        end
        
        -- Need to finish initialization with the imported asset
        res:initialize_from_filedata(fd)
        
    else  -- Native resources can be directly deserialized with binser
        local ok, result = pcall(binser.deserialize, fd:getString())
        if ok then
            res = result[1]
        else
            log.error(result)
            return 
        end        
    end
    
    local valid = true
    
    if res then
        local ok, result = pcall(res.isInstanceOf, res, rclass)
        if not ok then
            valid = false
            log.error(result)
        end
    else
        valid = false
    end
    
    if valid then                
        cache_resource(path, res)
        res:set_has_unsaved_changes(false)
        log.info(("Loaded resource %s"):format(path))
        return res
    else
        log.error(("Resource %s is corrupted or invalid"):format(path))
    end
end

function module.is_resource_loaded(path)
    return get_cached_resource(path) ~= nil
end

-- Load one or more resources in the background
function module.load_background(paths, on_complete, on_error, on_loaded)
    local ImportedResource = require("class.engine.resource.ImportedResource")
    
    local lily_args = {} -- Args to pass to lily.loadMultiple
    local load_info = {} -- Information on the resource being loaded
    local lily_index_map = {} -- Map lilyIndex to load_info, since imported resources may require more than 1 file
    
    -- Array of loaded resources, corresponding to paths
    -- Entries can be nil if the resource failed to load for whatever reason
    local loaded_resources = {}
    
    -- Create load infos for resources that aren't already loaded
    for _,p in ipairs(paths) do
        if not module.is_resource_loaded(p) then
            local rclass = get_associated_resource_class(get_extension(p))
            if rclass then
                local is_imported = rclass:isSubclassOf(ImportedResource)
                local info = {
                    imported = is_imported,
                    path = p,
                    class = rclass
                }
                local info_index = #load_info + 1
                
                if is_imported then
                    local import_path = p .. IMPORT_EXT                    
                    table.insert(lily_args, {"newFileData", p})
                    table.insert(lily_index_map, info_index)
                    
                    -- Load import data if one exists
                    if love.filesystem.getInfo(import_path, "file") then                    
                        table.insert(lily_args, {"read", import_path})
                        table.insert(lily_index_map, info_index)
                    else
                        log.info(("No import data for %s found, using defaults"):format(p))
                        info.resource = rclass()
                    end
                else
                    table.insert(lily_args, {"read", p})
                    table.insert(lily_index_map, info_index)
                end
                
                table.insert(load_info, info)
            else
                log.error(("No associated resource type for %s"):format(p))
            end
        end
    end

    local lobj = lily.loadMulti(lily_args)

    lobj:onLoaded(function(_, lily_index, data)
        local index = lily_index_map[lily_index]
        local info = load_info[index]
        
        local case
        if type(data) == "string" then
            if info.imported then   
                case = "ImportSettings"
            else
                case = "NativeResource"
            end
        else
            case = "ImportFileData"
        end
        
        if case == "NativeResource" then
            local ok, result = pcall(binser.deserialize, data)
            if ok then
                loaded_resources[index] = result[1]
                cache_resource(info.path, result[1])
                result[1]:set_has_unsaved_changes(false)
                log.info(("Loaded in background %s"):format(info.path))
            else
                log.error(result)
                if on_error then on_error(index, result) end
            end
        else
            if case == "ImportSettings" then
                local ok, result = pcall(binser.deserialize, data)
                if ok then
                    info.resource = result[1]
                else
                    log.error(result)
                    info.resource = info.class()
                    if on_error then on_error(index, result) end
                end                
            elseif case == "ImportFileData" then
                info.filedata = data
            end
            
            -- Finalize import
            if info.resource and info.filedata then
                local ok, err = pcall(info.resource.initialize_from_filedata, info.resource, info.filedata)
                if ok then
                    loaded_resources[index] = info.resource
                    cache_resource(info.path, info.resource)
                    info.resource:set_has_unsaved_changes(false)
                    log.info(("Loaded in background %s"):format(info.path))
                else
                    log.error(err)
                    if on_error then on_error(index, err) end
                end
            end
        end
    end)

    lobj:onComplete(function()
        if on_complete then on_complete(loaded_resources) end
    end)
    
    lobj:onError(function(_, lily_index, msg)
        local index = lily_index_map[lily_index]
        local info = load_info[index]
        
        log.error(msg)
        
        if info.imported and lily_args[lily_index][1] == "read" then
            info.resource = info.class()
        end
        
        if on_error then on_error(index, msg) end
    end)
    
end

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
        local backup_path = real_path .. BACKUP_EXT
        
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
        target_path = target_path .. IMPORT_EXT    
    end
    
    -- Resource only serialize to a reference by default

    resource:set_serialize_full(true)
    local data = binser.serialize(resource)
    resource:set_serialize_full(false)
    
    module.write_file(target_path, data, function() 
        log.info(("Saved resource %s"):format(filepath))
        resource:set_has_unsaved_changes(false)
    end)
    
    cache_resource(filepath, resource)
end

end

return module