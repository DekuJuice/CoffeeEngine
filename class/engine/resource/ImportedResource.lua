local Resource = require("class.engine.resource.Resource")
local ImportedResource = Resource:subclass("ImportedResource")
ImportedResource.static.dontlist = true
ImportedResource.static.noinstance = true
function ImportedResource:initialize_from_filedata(fd) end

function ImportedResource:_serialize()
    if not self.filepath then
        error("Imported Resources cannot be embedded")
    end
    
    return Resource._serialize(self)
end

return ImportedResource