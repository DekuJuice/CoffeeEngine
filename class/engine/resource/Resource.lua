-- Superclass for all Resource objects
local binser = require("enginelib.binser")

local Object = require("class.engine.Object")
local Resource = Object:subclass("Resource")
Resource.static.noinstance = true
Resource.static.extensions = {}
Resource:define_get_set("filepath")
Resource:define_get_set("has_unsaved_changes")
Resource:define_get_set("serialize_full")

local _gc_debug_info = function(proxy)
    local mt = getmetatable(proxy)
    log.info(("Garbage collected %s, path %s"):format(tostring(mt._res), mt._res:get_filepath()))
end

function Resource:initialize()
    Object.initialize(self)
    self.has_unsaved_changes = true
    self.serialize_full = false
    
    if settings.get_setting("is_debug") and _VERSION == "Lua 5.1" then
        self.proxy = newproxy(true)
        local mt = getmetatable(self.proxy)
        mt.__gc = _gc_debug_info
        mt._res = self
    end
    
end

function Resource:_serialize()
    if self.serialize_full or not self.filepath then
        return Object._serialize(self)
    end

    return self.filepath
end

Resource.static.binser_register = function(class)
    if not class._deserialize then
        class.static._deserialize = function(filepath_or_data)
            if type(filepath_or_data) == "string" then
                return resource.get_resource(filepath_or_data)        
            else
                local instance = class()
                for _,v in ipairs(filepath_or_data) do
                    local key = v[1]
                    local val = v[2]
                    local setter = ("set_%s"):format(key)
                    instance[setter](instance, val)
                end
                return instance
            end
        end
    end
    
    binser.register(class.__instanceDict, class.name, class._serialize, class._deserialize)
end

return Resource