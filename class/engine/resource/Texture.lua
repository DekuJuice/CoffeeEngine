-- For this resource, we don't need any additional methods,
-- but we define it anyways so we can differentiate it from
-- other resource types

local Resource = require("class.engine.resource.Resource")
local Texture = Resource:subclass("Texture")

return Texture