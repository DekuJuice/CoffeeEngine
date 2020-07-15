local ResourceTreeView = require("class.editor.ResourceTreeView")
local SceneSelector = ResourceTreeView:subclass("SceneSelector")

function SceneSelector:initialize()
    ResourceTreeView.initialize(self)
    self:set_ext_filter({"scene"})
    self:set_modal(true)
    self:set_open(false)
end

function SceneSelector:get_root()
    return "scene"
end

return SceneSelector