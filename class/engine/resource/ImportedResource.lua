local Resource = require("class.engine.resource.Resource")
local ImportedResource = Resource:subclass("ImportedResource")
ImportedResource.static.dontlist = true
ImportedResource.static.noinstance = true
function ImportedResource:initialize_from_filedata(fd) end

return ImportedResource