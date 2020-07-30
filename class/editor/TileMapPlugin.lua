local gridwalk = require("enginelib.gridwalk")
local scaledraw = require("enginelib.scaledraw")
local intersect = require("enginelib.intersect")

local InfiniteGrid = require("class.engine.InfiniteGrid")

local Tileset = require("class.engine.resource.Tileset")
local TileMap = require("class.engine.TileMap")
local Node = require("class.engine.Node")

local TileMapPlugin = Node:subclass("TileMapPlugin")
TileMapPlugin.static.dontlist = true

local BRUSH_TOOL = 1
local ERASE_TOOL = 2
local FILL_TOOL = 3

local ERASE_BRUSH = {
    width = 1,
    height = 1,
    tiles = {0}
}

function TileMapPlugin:initialize()
    Node.initialize(self)
    self.drawing = false
    self.tool = BRUSH_TOOL
    self.paint_new_cells = nil
    self.paint_old_cells = nil

    self.brush = {
        width = 1,
        height = 1,
        tiles = {1}
    }
    self.flip_brush_h = false
    self.flip_brush_v = false

    self.sampling_tiles = false
    self.sample_tile_anchor = vec2(0, 0)
    self.sample_tile_pos = vec2(0, 0)

    self.selecting_tiles = false
    self.select_tile_anchor = vec2(0,0)
    self.select_tile_pos = vec2(0,0)
    self.tile_selector_canvas = love.graphics.newCanvas(400, 400)

    self.tileset_editor_canvas = love.graphics.newCanvas(400, 400)
    self.tileset_selected_tile = 1

end

function TileMapPlugin:update()
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    if self.selecting_tiles then
        if not love.mouse.isDown(1) then
            self.selecting_tiles = false
        end
    elseif self.sampling_tiles then
        if not love.mouse.isDown(2) then
            self.sampling_tiles = false
            local rectmin, rectmax = self:get_sample_tile_rect()
            local brush_data = {}
            for y = rectmin.y, rectmax.y do
                for x = rectmin.x, rectmax.x do
                    local d = tilemap:get_cell(x, y)
                    if not d or d == 0 then d = -1 end
                    table.insert(brush_data, d)
                end
            end

            self.brush.width = rectmax.x - rectmin.x + 1
            self.brush.height = rectmax.y - rectmin.y + 1
            self.brush.tiles = brush_data            
        end
    elseif self.drawing then
        if not love.mouse.isDown(1) then
            self.drawing = false

            -- Upvalue references to cells we want to change
            local old_cells = self.paint_old_cells
            local new_cells = self.paint_new_cells 

            -- Doesn't matter which one we get it from, both should be the same
            local changed = old_cells:get_occupied_cells() 

            local cmd = model:create_command("Paint Tiles")
            cmd:add_do_func(function()
                    for _, cpos in ipairs(changed) do
                        tilemap:set_cell(cpos.x, cpos.y, new_cells:get_cell(cpos.x, cpos.y) - 1)
                    end
                end)

            cmd:add_undo_func(function()
                    for _, cpos in ipairs(changed) do
                        tilemap:set_cell(cpos.x, cpos.y, old_cells:get_cell(cpos.x, cpos.y) - 1)
                    end
                end)

            model:commit_command(cmd)


            self.paint_command = nil
            self.paint_new_cells = nil
            self.paint_old_cells = nil
        end
    end
end

function TileMapPlugin:enter_tree()
    --[[local tmap = TileMap()
    tmap:set_tileset(get_resource("assets/tilesets/Forest1.tset"))
    self:get_parent():get_active_scene():add_node(nil, tmap)]]--
end

function TileMapPlugin:place_tiles()
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    local start_point = tilemap:transform_to_map( editor:transform_to_world( self.prev_draw_pos ) )
    local end_point = tilemap:transform_to_map( editor:transform_to_world( self.draw_pos ) )

    local bres = gridwalk.bresenham(start_point.x, start_point.y, end_point.x, end_point.y)
    local cells = {}
    local brush

    if self.tool == BRUSH_TOOL then

        brush = self.brush
    elseif self.tool == ERASE_TOOL then
        brush = ERASE_BRUSH
    end

    local hw = math.floor(brush.width / 2)
    local hh = math.floor(brush.height / 2)

    for _,c in ipairs(bres) do
        local cx, cy = c[1], c[2]
        for by = 1, brush.height do
            for bx = 1, brush.width do
                local x = cx + bx - hw - 1
                local y = cy + by - hh - 1
                local i = brush.tiles[(bx - 1) + (by - 1) * brush.width + 1]
                if i ~= -1 then
                    local t = tilemap:bitmask_tile(i, self.flip_brush_h, self.flip_brush_v)
                
                    self.paint_new_cells:set_cell(x, y, t + 1)
                    
                    local co = self.paint_old_cells:get_cell(x, y)
                    if not co or co == 0 then
                        local old = tilemap:get_cell(x, y) or 0
                        self.paint_old_cells:set_cell(x, y, old + 1)
                    end
                    
                    tilemap:set_cell(x, y, t)
                end
            end
        end
    end
end

function TileMapPlugin:draw_toolbar()
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    local clicked, e
    e = self.tool
    clicked, e = imgui.RadioButton("Brush (B)", e, BRUSH_TOOL); imgui.SameLine()    
    if clicked then self.tool = e end

    clicked, e = imgui.RadioButton("Erase (E)", e, ERASE_TOOL); imgui.SameLine()
    if clicked then self.tool = e end

    clicked, e = imgui.RadioButton("Bucket (F)", e, FILL_TOOL); imgui.SameLine()
    if clicked then self.tool = e end
    self.tool = e
    
    if imgui.Checkbox("Flip H (H)", self.flip_brush_h) then
        self.flip_brush_h = not self.flip_brush_h
    end
    
    imgui.SameLine()
    
    if imgui.Checkbox("Flip V (V)", self.flip_brush_v) then
        self.flip_brush_v = not self.flip_brush_v
    end
    

end

function TileMapPlugin:get_sample_tile_rect()
    local minx = math.min(self.sample_tile_anchor.x, self.sample_tile_pos.x)
    local miny = math.min(self.sample_tile_anchor.y, self.sample_tile_pos.y)
    local maxx = math.max(self.sample_tile_anchor.x, self.sample_tile_pos.x)
    local maxy = math.max(self.sample_tile_anchor.y, self.sample_tile_pos.y)

    return vec2(minx, miny), vec2(maxx, maxy)
end

function TileMapPlugin:get_tile_selection_rect()
    local minx = math.min(self.select_tile_anchor.x, self.select_tile_pos.x)
    local miny = math.min(self.select_tile_anchor.y, self.select_tile_pos.y)
    local maxx = math.max(self.select_tile_anchor.x, self.select_tile_pos.x)
    local maxy = math.max(self.select_tile_anchor.y, self.select_tile_pos.y)

    return vec2(minx, miny), vec2(maxx, maxy)
end

function TileMapPlugin:draw_tile_selector()

    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    local tileset = tilemap:get_tileset()
    if not tileset then return end

    local texture = tileset:get_texture()
    if not texture then return end

    local image = texture:get_love_image()
    local iw, ih = image:getDimensions()

    imgui.SetNextWindowSize(400, 400, "ImGuiCond_FirstUseEver")

    local flags = {}

    if imgui.Begin("Tiles", nil, flags) then

        local rw, rh = imgui.GetContentRegionAvail()

        if rw > 0 and rh > 0 then

            -- Recreate canvas if dimensions have changed
            local cw, ch = self.tile_selector_canvas:getDimensions()
            if cw ~= rw or ch ~= rh then
                self.tile_selector_canvas = love.graphics.newCanvas(rw, rh)
            end

            local cx, cy = imgui.GetCursorPos()            
            -- Calculate relative position to tileset image
            local mx, my = imgui.GetMousePos()
            local scx, scy = imgui.GetCursorScreenPos()
            local rmx, rmy = scaledraw.transform_point( (mx - scx), (my - scy), "aspect", iw, ih, 0, 0, rw, rh )
            local sx, sy, ox, oy = scaledraw.get_transform("aspect",iw, ih, 0, 0, rw, rh)

            -- Place invisible button to intercept mouse events
            imgui.SetCursorPos(cx + ox, cy + oy)
            imgui.InvisibleButton("Selection Area", iw * sx, ih * sy)

            local tile_size = tileset:get_tile_size()                

            if imgui.IsItemHovered() and imgui.IsMouseClicked(0) then

                local anchor = vec2(rmx, rmy)
                anchor.x = math.floor(anchor.x / tile_size)
                anchor.y = math.floor(anchor.y / tile_size)
                anchor.x = math.max(anchor.x, 0)
                anchor.y = math.max(anchor.y, 0)
                anchor.x = math.min(anchor.x, tileset:get_count_x() - 1)
                anchor.y = math.min(anchor.y, tileset:get_count_y() - 1)            

                self.select_tile_anchor = anchor
                self.selecting_tiles = true
            end

            if self.selecting_tiles then

                local select_pos = vec2(rmx, rmy)
                select_pos.x = math.floor(select_pos.x / tile_size)
                select_pos.y = math.floor(select_pos.y / tile_size)
                select_pos.x = math.max(select_pos.x, 0)
                select_pos.y = math.max(select_pos.y, 0)
                select_pos.x = math.min(select_pos.x, tileset:get_count_x() - 1)
                select_pos.y = math.min(select_pos.y, tileset:get_count_y() - 1)     

                self.select_tile_pos = select_pos

                local rectmin, rectmax = self:get_tile_selection_rect()

                local brush_data = {}

                for y = rectmin.y, rectmax.y do
                    for x = rectmin.x, rectmax.x do
                        local i = x + y * tileset:get_count_x() + 1
                        table.insert(brush_data, i)
                    end
                end

                self.brush.width = rectmax.x - rectmin.x + 1
                self.brush.height = rectmax.y - rectmin.y + 1
                self.brush.tiles = brush_data                
            end

            imgui.SetItemAllowOverlap()
            imgui.SetCursorPos(cx, cy)
            love.graphics.push("all")
            love.graphics.setCanvas(self.tile_selector_canvas)
            love.graphics.clear(0,0,0,0)
            scaledraw.draw(image, "aspect", 0, 0, rw, rh)

            local rectmin, rectmax = self:get_tile_selection_rect()
            rectmin = rectmin * tile_size
            rectmax = rectmax * tile_size

            love.graphics.translate(ox, oy)
            love.graphics.scale(sx, sy)
            
            -- Draw collision boxes
            love.graphics.setColor(210/255, 165/255, 242/255, 0.3)
            love.graphics.setLineStyle("rough")
            for i = 1, tileset:get_count() do
                local quad = tileset:get_quad(i)
                local tile = tileset:get_tile(i)
                if tile.collision_enabled then
                    local tx, ty, tw, th = quad:getViewport()
                    
                    if tile.heightmap_enabled then
                        for j = 1, tile_size do
                            local hs = tile.heightmap[j]
                            love.graphics.line(tx + j - 0.5, ty + th - hs, tx + j - 0.5, ty + th)
                        end
                    else
                        love.graphics.rectangle("fill", tx, ty, tw, th)
                    end
                end
            end
            
            love.graphics.setColor(118/255, 207/255, 255/255, 0.18)
            love.graphics.rectangle("fill", 
                rectmin.x, rectmin.y,
                (rectmax.x - rectmin.x + tile_size), 
                (rectmax.y - rectmin.y + tile_size)
            )
            love.graphics.setColor(118/255, 207/255, 255/255, 1)
            love.graphics.rectangle("line", 
                rectmin.x, rectmin.y,
                (rectmax.x - rectmin.x + tile_size), 
                (rectmax.y - rectmin.y + tile_size)
            )

            love.graphics.pop()

            imgui.Image(self.tile_selector_canvas, rw, rh)
        end
    end

    imgui.End()
end

function TileMapPlugin:draw_tileset_editor()
    local editor = self:get_parent()
    if not editor.show_resource_inspector then return end
    
    local tileset = editor:get_inspected_resource()
    if not tileset or not tileset:isInstanceOf(Tileset) then return end

    local x_count = tileset:get_count_x()
    local y_count = tileset:get_count_y()
    local tile_size = tileset:get_tile_size()  

    local texture = tileset:get_texture()
    if not texture then return end

    local image = texture:get_love_image()
    local iw, ih = image:getDimensions()

    local flags = {}

    if imgui.Begin("Tileset", nil, flags) then

        local rw, rh = imgui.GetContentRegionAvail()

        if rw > 0 and rh > 0 then

            -- Recreate canvas if dimensions have changed
            local cw, ch = self.tileset_editor_canvas:getDimensions()
            if cw ~= rw or ch ~= rh then
                self.tileset_editor_canvas = love.graphics.newCanvas(rw, rh)
            end

            local cx, cy = imgui.GetCursorPos()            
            -- Calculate relative position to tileset image
            local mx, my = imgui.GetMousePos()
            local scx, scy = imgui.GetCursorScreenPos()
            local rmx, rmy = scaledraw.transform_point( (mx - scx), (my - scy), "aspect", iw, ih, 0, 0, rw, rh )
            local sx, sy, ox, oy = scaledraw.get_transform("aspect",iw, ih, 0, 0, rw, rh)

            -- Place invisible button to intercept mouse events
            imgui.SetCursorPos(cx + ox, cy + oy)
            imgui.InvisibleButton("Selection Area", iw * sx, ih * sy)

            if imgui.IsItemHovered() and imgui.IsMouseClicked(0) then

                local cell = vec2(rmx, rmy)
                cell.x = math.floor(cell.x / tile_size)
                cell.y = math.floor(cell.y / tile_size)
                cell.x = math.max(cell.x, 0)
                cell.y = math.max(cell.y, 0)
                cell.x = math.min(cell.x, x_count - 1)
                cell.y = math.min(cell.y, y_count - 1)
                self.tileset_selected_tile = cell.x + cell.y * x_count + 1
            end

            imgui.SetItemAllowOverlap()
            imgui.SetCursorPos(cx, cy)
            love.graphics.push("all")
            love.graphics.setCanvas(self.tileset_editor_canvas)
            love.graphics.clear(0,0,0,0)
            scaledraw.draw(image, "aspect", 0, 0, rw, rh)

            love.graphics.translate(ox, oy)
            love.graphics.scale(sx, sy)

            -- Draw collision boxes
            love.graphics.setColor(210/255, 165/255, 242/255, 0.3)
            love.graphics.setLineStyle("rough")
            for i = 1, tileset:get_count() do
                local quad = tileset:get_quad(i)
                local tile = tileset:get_tile(i)
                if tile.collision_enabled then
                    local tx, ty, tw, th = quad:getViewport()
                    
                    if tile.heightmap_enabled then
                        for j = 1, tile_size do
                            local hs = tile.heightmap[j]
                            love.graphics.line(tx + j - 0.5, ty + th - hs, tx + j - 0.5, ty + th)
                        end
                    else
                        love.graphics.rectangle("fill", tx, ty, tw, th)
                    end
                end
            end
            local quad = tileset:get_quad(self.tileset_selected_tile)
            if quad then
                local tx, ty, tw, th = quad:getViewport()
                love.graphics.setColor(118/255, 207/255, 255/255, 0.18)
                love.graphics.rectangle("fill", tx, ty, tw, th)
                love.graphics.setColor(118/255, 207/255, 255/255, 1)
                love.graphics.rectangle("line", tx, ty, tw, th)
            end
            love.graphics.pop()
            imgui.Image(self.tileset_editor_canvas, rw, rh)
        end
        
        local tile = tileset:get_tile(self.tileset_selected_tile)
        if tile then
            imgui.Text(("Tile: %d"):format(self.tileset_selected_tile))
            if imgui.Checkbox("collision_enabled", tile.collision_enabled) then
                tile.collision_enabled = not tile.collision_enabled
                tileset:set_has_unsaved_changes(true)
            end
            if imgui.Checkbox("heightmap_enabled", tile.heightmap_enabled) then
                tile.heightmap_enabled = not tile.heightmap_enabled
                tileset:set_has_unsaved_changes(true)

            end
            if imgui.CollapsingHeader("heightmap") then
                for i = 1, tile_size do
                    local changed, new_v = imgui.DragInt(("%d"):format(i), tile.heightmap[i], 0.05, 1, tile_size)
                    tile.heightmap[i] = new_v
                    if changed then
                        tileset:set_has_unsaved_changes(true)
                    end
                end
            end
            if imgui.CollapsingHeader("tags") then
                if imgui.Button(IconFont.PLUS) then
                    tileset:set_has_unsaved_changes(true)
                end
                imgui.SameLine()
                if imgui.Button(IconFont.MINUS) then
                    tileset:set_has_unsaved_changes(true)
                end
            end
        end 

    end
    imgui.End()

end

function TileMapPlugin:draw()

    self:draw_tileset_editor()

    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    self:draw_tile_selector()

    -- Draw Tilemap Grid
    local view = editor:get_active_view()
    local position = view:get_position()
    local scale = view:get_scale()

    local tile_size = tilemap:get_tile_size()
    local tilemap_position = tilemap:get_global_position()

    local offset = vec2( tilemap_position.x % tile_size, tilemap_position.y % tile_size ) * scale

    love.graphics.push("all")
    love.graphics.setColor(0.5, 0.3, 0.25, 0.3)
    editor:draw_grid(position - offset, scale, vec2(tile_size) )
    love.graphics.pop()

    -- Draw selection rect when sampling tiles
    if self.sampling_tiles then
        local rectmin, rectmax = self:get_sample_tile_rect()
        rectmin = tilemap:transform_to_world(rectmin)
        rectmax = tilemap:transform_to_world(rectmax + vec2(1, 1))

        rectmin = editor:transform_to_screen(rectmin)
        rectmax = editor:transform_to_screen(rectmax)
        love.graphics.push("all")
        love.graphics.setColor(118/255, 207/255, 255/255, 0.18)
        love.graphics.rectangle("fill", rectmin.x, rectmin.y, rectmax.x - rectmin.x, rectmax.y - rectmin.y)
        love.graphics.setColor(118/255, 207/255, 255/255, 1)
        love.graphics.rectangle("line", rectmin.x, rectmin.y, rectmax.x - rectmin.x, rectmax.y - rectmin.y)
        love.graphics.pop()
    end
    -- Highlight rect 
    local mp = vec2(love.mouse.getPosition())
    local wp = editor:transform_to_world(mp)
    local center_cell = tilemap:transform_to_map(wp)

    if (self.tool == BRUSH_TOOL or self.tool == ERASE_TOOL) and not self.sampling_tiles then
        local brush
        if self.tool == BRUSH_TOOL then 
            brush = self.brush
        elseif self.tool == ERASE_TOOL then
            brush = ERASE_BRUSH
        end

        local half_d = vec2(math.floor(brush.width / 2), math.floor(brush.height / 2))
        local rectmin = center_cell
        local rectmax = center_cell + vec2(brush.width, brush.height)
        rectmin = rectmin - half_d
        rectmax = rectmax - half_d

        rectmin = tilemap:transform_to_world(rectmin)
        rectmax = tilemap:transform_to_world(rectmax)

        rectmin = editor:transform_to_screen(rectmin)
        rectmax = editor:transform_to_screen(rectmax)
        love.graphics.push("all")
        love.graphics.setColor(118/255, 207/255, 255/255, 0.18)
        love.graphics.rectangle("fill", rectmin.x, rectmin.y, rectmax.x - rectmin.x, rectmax.y - rectmin.y)
        love.graphics.setColor(118/255, 207/255, 255/255, 1)
        love.graphics.rectangle("line", rectmin.x, rectmin.y, rectmax.x - rectmin.x, rectmax.y - rectmin.y)
        love.graphics.pop()
    end
end

function TileMapPlugin:keypressed(key, scan, isRepeat)
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    -- Block keypresses when drawing, to avoid issues with undo/redo orders
    if self.drawing then return true end

    if key == "e" then
        self.tool = ERASE_TOOL
        return true
    elseif key == "b" then
        self.tool = BRUSH_TOOL
        return true
    elseif key == "f" then
        self.tool = FILL_TOOL
        return true
    elseif key == "h" then
        self.flip_brush_h = not self.flip_brush_h
        return true
    elseif key == "v" then
        self.flip_brush_v = not self.flip_brush_v
        return true
    end

end

function TileMapPlugin:mousemoved(x, y, dx, dy)
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if not tilemap or not tilemap:isInstanceOf(TileMap) then return end

    if self.drawing then
        self.prev_draw_pos = self.draw_pos:clone()
        self.draw_pos = vec2(x, y)
        self:place_tiles()
    elseif self.sampling_tiles then
        self.sample_tile_pos = tilemap:transform_to_map(  editor:transform_to_world(vec2(x, y)) )
    end

end

function TileMapPlugin:mousepressed(x, y, button)
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local tilemap = model:get_selected_nodes()[1]
    if tilemap and tilemap:isInstanceOf(TileMap) then

        if button == 1 then
            if self.tool == FILL_TOOL then


            else
                self.drawing = true
                self.draw_pos = vec2(x, y)
                self.prev_draw_pos = self.draw_pos:clone()
                self.paint_new_cells = InfiniteGrid()
                self.paint_new_cells:set_autoremove_chunks(false)
                self.paint_old_cells = InfiniteGrid()
                self.paint_old_cells:set_autoremove_chunks(false)

                self:place_tiles()
            end

            return true
        elseif button == 2 then

            if self.tool == BRUSH_TOOL then
                self.sample_tile_anchor = tilemap:transform_to_map(  editor:transform_to_world(vec2(x, y)) )
                self.sample_tile_pos = self.sample_tile_anchor:clone()
                self.sampling_tiles = true
                return true
            end
        end
    end
end


return TileMapPlugin