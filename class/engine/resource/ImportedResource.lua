local Resource = require("class.engine.resource.Resource")
local ImportedResource = Resource:subclass("ImportedResource")

function ImportedResource:initialize_from_filedata(fd) end

return ImportedResource