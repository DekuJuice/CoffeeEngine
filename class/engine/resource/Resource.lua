-- Superclass for all Resource objects
local binser = require("enginelib.binser")

local Object = require("class.engine.Object")
local Resource = Object:subclass("Resource")
Resource.static.noinstance = true
Resource.static.extensions = {}
Resource:define_get_set("filepath")
Resource:define_get_set("has_unsaved_changes")

local _gc_debug_info = function(proxy)
    local mt = getmetatable(proxy)
    log.info(("Garbage collected %s, path %s"):format(tostring(mt._res), mt._res:get_filepath()))
end

function Resource:initialize()
    Object.initialize(self)
    self.has_unsaved_changes = true
    
    if settings.get_setting("is_debug") and _VERSION == "Lua 5.1" then
        self.proxy = newproxy(true)
        local mt = getmetatable(self.proxy)
        mt.__gc = _gc_debug_info
        mt._res = self
    end
    
end

function Resource:_serialize()
    return self.filepath
end

function Resource.static._deserialize(filepath)
    return resource.get_resource(filepath)
end

function Resource.static.subclassed(self, class)
    binser.register(class.__instanceDict, class.name, class._serialize, class._deserialize)
end

return Resource