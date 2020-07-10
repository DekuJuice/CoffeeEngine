local resource = require("resource")
local Node = require("class.engine.Node")
local TileMap = require("class.engine.TileMap")

local TileMapPlugin = Node:subclass("TileMapPlugin")
TileMapPlugin.static.dontlist = true

function TileMapPlugin:initialize()
    Node.initialize(self)
end

function TileMapPlugin:open_add_tileset_modal()
    imgui.OpenPopup("Add Tileset")
end

function TileMapPlugin:draw_add_tileset_modal()

    local editor = self:get_parent()

    local popup_flags = {
        "ImGuiWindowFlags_AlwaysAutoResize", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoMove"
    }

    if imgui.BeginPopupModal("Add Tileset", nil, popup_flags) then

        local resources = editor:get_resource_list()
        imgui.BeginChild("Resource List", 400, 400)
        for _,s in ipairs(resources) do
            if (imgui.Selectable(s, false, {"ImGuiSelectableFlags_AllowDoubleClick"})) then
                if (imgui.IsMouseDoubleClicked(0)) then
                    local res = resource.get_resource(s)
                    if res then
                    
                        
                    
                    end
                    imgui.CloseCurrentPopup()
                end
            end
        end
        imgui.EndChild()

        imgui.Separator()
        if imgui.Button("Cancel", 120, 0) then
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end

end

function TileMapPlugin:draw_load_tileset_modal()
end

function TileMapPlugin:draw_tileset_selector()
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    local selection = scene:get_selected_nodes()
    local tilemap = selection[1]

    local window_flags = {"ImGuiWindowFlags_MenuBar"}

    local add_tileset = false
    local load_tileset = false

    if imgui.Begin("Tilesets", true, window_flags) then
        if imgui.BeginMenuBar() then

            if imgui.Button("Add Tileset") then
                add_tileset = true
            end

            if imgui.Button("Load Tileset") then
                load_tileset = true
            end

            if imgui.Button("Remove Tileset") then

            end

            imgui.EndMenuBar()            
        end
    end

    imgui.End()

    if add_tileset then
        self:open_add_tileset_modal()
    end

    self:draw_add_tileset_modal()


end


function TileMapPlugin:draw_tile_property_editor()
end


function TileMapPlugin:draw()
    local editor = self:get_parent()
    local scene = editor:get_active_scene()
    local selection = scene:get_selected_nodes()

    if #selection == 1 and selection[1]:isInstanceOf(TileMap) then




        self:draw_tileset_selector()
    end





end

return TileMapPlugin