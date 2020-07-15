-- Superclass for all Resource objects
local binser = require("enginelib.binser")

local Object = require("class.engine.Object")
local Resource = Object:subclass("Resource")

Resource.static.extensions = {}
Resource:define_get_set("filepath")
Resource:define_get_set("has_unsaved_changes")
Resource:define_get_set("serialize_full")

function Resource:initialize()
    Object.initialize(self)
    self.has_unsaved_changes = true
    self.serialize_full = false
end

function Resource:_serialize()
    if self.serialize_full then
        return Object._serialize(self)
    end

    return self.filepath
end

Resource.static.binser_register = function(class)
    if not class._deserialize then
        class.static._deserialize = function(filepath_or_data)
            if type(filepath_or_data) == "string" then
                return get_resource(filepath_or_data)        
            else
                local instance = class()
                for k,v in pairs(filepath_or_data) do
                    local setter = ("set_%s"):format(k)
                    instance[setter](instance, v)
                end
                return instance
            end
        end
    end
    
    binser.register(class.__instanceDict, class.name, class._serialize, class._deserialize)
end

return Resource