local NodeSelector = require("class.editor.NodeSelector")
local Resource = require("class.engine.resource.Resource")
local ImportedResource = require("class.engine.resource.ImportedResource")

local ResourceSelector = NodeSelector:subclass("ResourceSelector")

local function filter_class(class)
    return class ~= ImportedResource
    and not class.static.dontlist
    and not class:isSubclassOf(ImportedResource)
end

function ResourceSelector:get_root()
    local subc = {}
    for subclass in pairs(Resource.subclasses) do
        if filter_class(subclass) then
            table.insert(subc, subclass)
        end
    end
    
    table.sort(subc, function(a, b)
        return a.name < b.name
    end)

    return unpack(subc)
end

function ResourceSelector:get_children(class)
    local children = {}
    
    for subclass in pairs(class.subclasses) do
        if filter_class(subclass) then
            table.insert(children, subclass)
        end
    end
    
    table.sort(children, function(a, b)
        return a.name < b.name
    end)
    
    return children
end

return ResourceSelector