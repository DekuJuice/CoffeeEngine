-- Superclass for all Resource objects

local Object = require("class.engine.Object")
local Resource = Object:subclass("Resource")

Resource.static.extensions = {}
Resource:define_get_set("filepath")

--function Resource:clone() end

return Resource