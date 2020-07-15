-- Module for drawing textures with different scaling methods
-- scale_mode can be either

-- aspect -- preserves aspect ratio
-- free -- stretches to fill
-- perfect -- only allow integer values. Falls back to free scaling if 
--            given rect is smaller than the texture

local module = {}

--Aspect ratio: (original height / original width) x new width = new height
local function calculate_scaled_dimensions(w1,h1,w2,h2)
    local ratio = math.min(w2 / w1, h2 / h1)
    return w1 * ratio, h1 * ratio
end

function module.get_transform(scale_mode, tw, th, x, y, w, h)

    local scale_x
    local scale_y
    local offset_x
    local offset_y
    if scale_mode == "free" then
        scale_x = w / tw
        scale_y = h / th
        offset_x = 0
        offset_y = 0
    elseif scale_mode == "aspect" then
        
        local nw, nh = calculate_scaled_dimensions(tw, th, w, h)
        scale_x = nw / tw
        scale_y = nh / th
        
        offset_x = math.floor( (w - nw) / 2 + 0.5)
        offset_y = math.floor( (h - nh) / 2 + 0.5)
        
    elseif scale_mode == "perfect" then
    
        local nw, nh = calculate_scaled_dimensions(tw, th, w, h)
        
        if nw > tw and nh > th then
            nw = math.floor( nw / tw) * tw
            nh = math.floor( nh / th) * th
        end
        
        scale_x = nw / tw
        scale_y = nh / th
        
        offset_x = math.floor( (w - nw) / 2 + 0.5)
        offset_y = math.floor( (h - nh) / 2 + 0.5)
        
    end
    
    return scale_x, scale_y, offset_x, offset_y
end

function module.draw(texture, scale_mode, x, y, w, h )
    local tw, th = texture:getDimensions()
    local scale_x, scale_y, offset_x, offset_y =
        module.get_transform(scale_mode, tw, th, x, y, w, h)

    love.graphics.draw(texture, x + offset_x, y + offset_y, 0, scale_x, scale_y)
    --love.graphics.rectangle("line", x, y, w, h)

end

function module.transform_point(x, y, scale_mode, tw, th, dx, dy, w, h)
    local scale_x, scale_y, offset_x, offset_y =
        module.get_transform(scale_mode, tw, th, dx, dy, w, h)
    
    local tx = (x - dx - offset_x) / scale_x
    local ty = (y - dy - offset_y) / scale_y
        
    return tx, ty
end

function module.untransform_point(x, y, scale_mode, tw, th, dx, dy, w, h)
    local scale_x, scale_y, offset_x, offset_y =
        module.get_transform(scale_mode, tw, th, dx, dy, w, h)
        
    local ux = x * scale_x + dx + offset_x
    local uy = y * scale_y + dy + offset_y
    
    return tx, ty
end

return module
