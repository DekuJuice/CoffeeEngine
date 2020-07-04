-- Superclass for all Resource objects
-- Assets are wrapped in a Resource class so that references to the 
-- asset can be correctly serialized.
-- In addition, this also lets us store arbitrary metadata related to the asset files,
-- such as loop points for audio files and glyphs for bitmap fonts

local binser = require("enginelib.binser")
local resource = require("resource")

local Object = require("class.engine.Object")

local Resource = Object:subclass("Resource")
Resource:define_get_set("data")
Resource:define_get_set("filepath")
Resource:define_get_set("metadata")

-- Serialization just returns the path of the associated asset file, loading the asset data
-- and metadata is handled by resource
function Resource:_serialize()
    return self.filepath
end

local function deserialize(path)
    local instance = resource.get_resource(path)
    return instance
end

-- Deserialize needs to be defined for each subclass as they have different metatables
local function binser_register(class)
    class._deserialize = deserialize
    binser.registerClass(class)
end

Resource.static.subclassed = function(class, other)
    binser_register(other)
end

binser_register(Resource)

return Resource