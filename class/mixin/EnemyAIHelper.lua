local intersect = require("enginelib.intersect")

local AiHelper = {}

function AiHelper:find_player()

end

function AiHelper:is_on_screen(extents)

    local tree = self:get_tree()
    if not tree then return end
    
    extents = extents or vec2.zero
    
    local view = tree:get_viewport()    
    local vmin, vmax = view:get_bounds()
        
    local gp = self:get_global_position()
    
    local on_screen = intersect.aabb_aabb(vmin, vmax, gp - extents / 2, gp + extents / 2)

    return on_screen    
end

return AiHelper