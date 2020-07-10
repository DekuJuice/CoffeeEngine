local log = require("enginelib.log")
local lily = require("enginelib.lily")
local vec2 = require("enginelib.vec2")
local scaledraw = require("enginelib.scaledraw")

local Texture = require("class.engine.resource.Texture")
local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")

local SceneModel = require("class.editor.SceneModel")

local ImguiResourceSelector = require("class.editor.ImguiResourceSelector")
local ImguiNodeSelector = require("class.editor.ImguiNodeSelector")
local ImguiResourceInspector = require("class.editor.ImguiResourceInspector")

local Editor = Node:subclass("Editor")
Editor.static.dontlist = true

local MIN_ZOOM = 0.5
local MAX_ZOOM = 8.0
local LOG_MIN_ZOOM = math.log(MIN_ZOOM)
local LOG_MAX_ZOOM = math.log(MAX_ZOOM)

local MENU_DEF = {
    {name = "File", items = {
        {name = "New", action = "new"},
        {name = "Save", action = "save"},
        {name = "Save As", action = "saveas"},
        {name = "Open", action = "open"},
        {name = "Close", action = "close"},
    }},
    {name = "Edit", items = {
        {name = "Undo", action ="undo"},
        {name = "Redo", action ="redo"},
        {name = "Copy", action ="copy"},
        {name = "Paste", action ="paste"},
    }},
    {name = "View", items = {
        {name = "Node Tree", action="show_node_tree"},
        {name = "Inspector", action="show_inspector"},
        {name = "Signals", action="show_signals"}
    }}
}

local SHORTCUTS = {
    ["Ctrl+z"]="undo",
    ["Ctrl+y"]="redo",
    ["Ctrl+s"]="save",
    ["Ctrl+Shift+s"]="saveas",
    ["Ctrl+w"]="close",
    ["Ctrl+o"]="open",
    ["Ctrl+n"]="new"
}

-- f(x) = e^(a + bx)
-- a = log_min_zoom
-- b = log_max_zoom - log_min_zoom
local function get_exp_scale(scale)
    return math.exp( LOG_MIN_ZOOM + (LOG_MAX_ZOOM - LOG_MIN_ZOOM) * scale ) 
end

-- f-1(x) = (log(x) - a) / b
local function get_log_scale(scale)
    return (math.log(scale) - LOG_MIN_ZOOM) / (LOG_MAX_ZOOM - LOG_MIN_ZOOM)
end

local function draw_grid(ox, oy, w, h, cellw, cellh)
    for x = 0, w, cellw do
        love.graphics.line(x + ox, 0, x + ox, h)
    end
    
    for y = 0, h, cellh do
        love.graphics.line(0, y + oy, w, y + oy)
    end
end

local function create_file_tree(path)
    local root = TreeData(path)
    local stack = {path}
    local data_stack = {root}
    
    while (#stack > 0) do
        local top = table.remove(stack)
        local node = table.remove(data_stack)
        for _,v in ipairs(love.filesystem.getDirectoryItems(top)) do
            local p = top .. "/" .. v
            local info = love.filesystem.getInfo(p) 
            if info.type == "directory" then                
                table.insert(stack, p)
                local child = TreeData(v)
                node:add_child(child)
                table.insert(data_stack, child)
            elseif info.type == "file" then
                node:add_child(TreeData(v, p))
            end
        end
    end
    
    return root
end


-- The first time the editor is loaded, we require every class, so that we can
-- traverse the parent classes to find subclasses. This is useful for listing them in
-- the editor
do

local function preload_class(dir)
    for _,v in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. v
        local info = love.filesystem.getInfo(path)
        if info.type == "directory" then
            preload_class(path)
        else
            require(path:match("^[^%.]+"):gsub("/", "."))
        end
    end
end

preload_class("class/engine")

end

function Editor:initialize()
    
    Node.initialize(self, "Editor")
    
    self.scene_models = {}
    self.scene_views = {}
    
    self.active_scene = 1
    
    self.dragging = false
    self.view_y = 0
    self.actions_to_do = {}
    
    self.selected_resources = {}
    self.inspected_resource = nil
    
    -- Add other components of the editor
    self.resource_browser = ImguiResourceSelector()
    self.resource_browser:set_window_name("Resources")
    self.resource_browser:set_modal(false)    
    
    self.node_browser = ImguiNodeSelector()
    self.node_browser:set_window_name("Nodes")
    self.node_browser:set_modal(false)
    
    self.resource_inspector = ImguiResourceInspector()
    self.resource_inspector:set_window_name("Inspector")
    
    
    self.show_resource_inspector = true -- whether to show resource inspector or node inspector
    
    
    --self:add_child(require("class.editor.Node2dPlugin")())
    --self:add_child(require("class.editor.TileMapPlugin")())

    self:add_new_scene() -- Make sure there is always at least one scene open
end

function Editor:_get_shortcut_for(action)
    for s,a in pairs(SHORTCUTS) do
        if a == action then return s end
    end
end

function Editor:get_active_scene()
    return self.scene_models[self.active_scene]
end

function Editor:get_active_view()
    return self:get_active_scene():get_tree():get_viewport()
end

function Editor:add_new_scene(filepath)
    local model = SceneModel(filepath)
        
    table.insert(self.scene_models, model)

    self.active_scene = #self.scene_models
end

function Editor:close_scene(index)
    if self.active_scene > index or self.active_scene == #self.scene_models then
        self.active_scene = self.active_scene - 1
    end

    table.remove(self.scene_models, index)
    table.remove(self.scene_views, index)
    
    if (#self.scene_models == 0) then
        self:add_new_scene()
        self.active_scene = 1
    end
end

function Editor:save_scene()
    local model = self:get_active_scene()
    
    if not model:get_tree():get_root() then
        self:open_alert_modal("The scene must have a root node to be saved.")
        return
    end

    local path = model:get_filepath()

    if not path then
        self:open_save_as_modal()
        return 
    end
    
end

function Editor:transform_to_world(x, y)
    return self:get_active_view():transform_to_world(x, y - self.view_y)
end

function Editor:transform_to_screen(x, y)
    local nx, ny = self:get_active_view():transform_to_viewport(x, y)
    return nx, ny + self.view_y
end


-- IMGUI stuff

function Editor:draw()

    -- Demo window --
    imgui.ShowDemoWindow() 
    
    -- Main Menu Bar --
    local menu_bar_height = 0 

    if imgui.BeginMainMenuBar() then
    
        for _, menu in ipairs(MENU_DEF) do
            if imgui.BeginMenu(menu.name) then
                for _, item in ipairs(menu.items) do
                    local shortcut = self:_get_shortcut_for(item.action)
                    local pressed
                    if shortcut then
                        pressed = imgui.MenuItem(item.name, shortcut)
                    else
                        pressed = imgui.MenuItem(item.name)
                    end
                    
                    if pressed then
                        self.actions_to_do[item.action] = true
                    end
                    
                end
                imgui.EndMenu()
            end
        end

        local mw, mh = imgui.GetWindowSize()
        menu_bar_height = mh
        imgui.EndMainMenuBar()
    end

    
    -- Tabbar --
    imgui.SetNextWindowPos(0, menu_bar_height)
    imgui.SetNextWindowSize(love.graphics.getWidth(), 40)
    imgui.PushStyleVar("ImGuiStyleVar_WindowBorderSize", 0)
    imgui.Begin("Scenes", true, 
        {
        "ImGuiWindowFlags_NoTitleBar", 
        "ImGuiWindowFlags_NoMove", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoBringToFrontOnFocus",
        "ImGuiWindowFlags_NoDocking",
        }
    )
    imgui.PopStyleVar(1)
    
    if imgui.BeginTabBar("SceneTabs", {
        "ImGuiTabBarFlags_Reorderable",
        "ImGuiTabBarFlags_TabListPopupButton",
        "ImGuiTabBarFlags_FittingPolicyResizeDown",
        "ImGuiTabBarFlags_AutoSelectNewTabs"
    }) then
    
        for i,model in ipairs(self.scene_models) do
            local tabname = ("%d. %s"):format(i, model:get_name())        
            local tabflags = {}
            
            if model.modified then
                table.insert(tabflags, "ImGuiTabItemFlags_UnsavedDocument")
            end
                        
            local selected, open = imgui.BeginTabItem(tabname, true, tabflags)
            if selected then
                self.active_scene = i
                imgui.EndTabItem()            
            end
            
            if not open then
                self:close_scene(i)
            end
            
        end

        imgui.EndTabBar()
    end
    
    local _, lh = imgui.GetWindowSize()
    self.view_y = lh + menu_bar_height

    imgui.End()

    do -- Scene Nodes
        local vx = 0
        local vy = self.view_y
        local vx2, vy2 = love.graphics.getDimensions()
        
        local vw = vx2 - vx
        local vh = vy2 - vy
        
        local curmodel = self:get_active_scene()
        local view = self:get_active_view()
                
        if (vw > 0 and vh > 0) then
            
            local pw, ph = view:get_resolution()
            if (pw ~= vw or ph ~= vh) then
                view:set_resolution(vw, vh)
            end
            
            
            local position = view:get_position()
            local scale = view:get_scale()
            -- Scaling for the grid is done manually so that lines are always at full resolution
            if curmodel:get_draw_grid() then
                local minor_w = curmodel:get_grid_minor_w()
                local minor_h = curmodel:get_grid_minor_h()
                local major_w = curmodel:get_grid_major_w()
                local major_h = curmodel:get_grid_major_h()
                
                love.graphics.push("all")
                love.graphics.translate(0, vy)
                love.graphics.setLineStyle("rough")
                
                minor_w = minor_w * scale
                minor_h = minor_h * scale
                major_w = major_w * scale
                major_h = major_h * scale
                love.graphics.translate(0.5,0.5)
                love.graphics.setColor(0.4, 0.4, 0.4, 0.3)
                -- Minor Lines
                draw_grid(
                    -position.x % minor_w,  -position.y % minor_h, 
                    vw, vh,
                    minor_w, minor_h
                )
                
                love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
                -- Major Lines
                draw_grid(
                    -position.x % major_w,  -position.y % major_h, 
                    vw, vh,
                    major_w, major_h
                )
                
                -- Origin Lines
                local cx, cy = -position.x, -position.y
                love.graphics.setColor(1,0,0,0.5)
                love.graphics.line(0, cy, vw, cy)
                
                love.graphics.setColor(0,1,0,0.5)
                love.graphics.line(cx, 0, cx, vh)
                
                love.graphics.pop()
            end
        
            curmodel:get_tree():draw(0, vy, vw, vh)            
        end
    end
    
    -- Resource Browser --
    if self.resource_browser:begin_window() then
        local changed, new_selection = self.resource_browser:display(self.selected_resources)
        self.selected_resources = new_selection
        if changed then
            self.inspected_resource = get_resource(self.selected_resources[1])
        end
        
    end
    self.resource_browser:end_window()
    
    -- Node Browser
    if self.node_browser:begin_window() then
        
        local model = self:get_active_scene()
        self.node_browser:set_scene_model(model)
        local changed, new_selection = self.node_browser:display( model:get_selected_nodes() )
        
        if changed then
            model:set_selected_nodes(new_selection)
        end
        
    end
    self.node_browser:end_window()
    
    if self.show_resource_inspector then
        if self.resource_inspector:begin_window() then
            self.resource_inspector:display(self.inspected_resource)
        end
        self.resource_inspector:end_window()
    end
    
end

-- Modals
function Editor:get_scene_list()
    local stack = {}
    local scenes = {}
    table.insert(stack, "scene")
    while (#stack > 0) do
        local top = table.remove(stack)
        for _,v in ipairs(love.filesystem.getDirectoryItems(top)) do
            local p = top .. "/" .. v
            local info = love.filesystem.getInfo(p) 
            if info.type == "directory" then
                table.insert(stack, p)
            else
                table.insert(scenes, p)
            end
        end
    end
    
    table.sort(scenes)
    
    return scenes
end

function Editor:get_resource_list()
    local stack = {}
    local resources = {}
    table.insert(stack, "assets")
    while (#stack > 0) do
        local top = table.remove(stack)
        for _,v in ipairs(love.filesystem.getDirectoryItems(top)) do
            local p = top .. "/" .. v
            local info = love.filesystem.getInfo(p) 
            if info.type == "directory" then
                table.insert(stack, p)
            else
                table.insert(resources, p)
            end
        end
    end
    
    table.sort(resources)
    
    return resources
end

-- Alert Modal
function Editor:open_alert_modal(text)
    self.alert_text = text
    imgui.OpenPopup("Alert")
end

function Editor:draw_alert_modal()
    local flags = {
        "ImGuiWindowFlags_AlwaysAutoResize", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoMove"
    }
    if imgui.BeginPopupModal("Alert", nil, flags) then
        imgui.Text(self.alert_text)
        imgui.Separator()
        
        if imgui.Button("OK", 120, 0) then
            imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
    end
end

-- Save as prompt
function Editor:open_save_as_modal()
    local model = self:get_active_scene()
    
    if not model:get_tree():get_root() then
        self:open_alert_modal("The scene must have a root node to be saved.")
        return
    end
    
    imgui.OpenPopup("Save As")
end

function Editor:draw_save_as_modal()

    local flags = {
        "ImGuiWindowFlags_AlwaysAutoResize", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoMove"
    }

    if imgui.BeginPopupModal("Save As", nil, flags) then
        local model = self:get_active_scene()
        imgui.Text("Enter the filename to save as:")
        
        local path = model:get_filepath() or ""
        imgui.PushItemWidth(-1)
        local changed, new = imgui.InputText("##Filename", path, 128, {"ImGuiInputTextFlags_EnterReturnsTrue"})
        
        imgui.Separator()
        if changed then
            if new == "" then 
                imgui.CloseCurrentPopup()
            end
            
            -- Add extension and scene dir
            new = ("scene/%s.scene"):format(new)
            
            model:set_filepath(new)
            self:save_scene()
            imgui.CloseCurrentPopup()
            
        end
        
        imgui.SameLine()
        if imgui.Button("Cancel", 120, 0) then
            imgui.CloseCurrentPopup()
        end
    
    
        imgui.EndPopup()
    end
end

-- Callbacks --

function Editor:keypressed(key)

    local shortcut = ""
    if love.keyboard.isDown("lctrl") then
        shortcut = shortcut .. "Ctrl+"
    end
    if love.keyboard.isDown("lalt") then
        shortcut = shortcut .. "Alt+"
    end
    if love.keyboard.isDown("lshift") then
        shortcut = shortcut .. "Shift+"
    end
        
    shortcut = shortcut .. key
    local action = SHORTCUTS[shortcut]
    if action then
        self.actions_to_do[action] = true
    end
        
        

end

function Editor:mousemoved(x, y, dx, dy)

    if not love.mouse.isDown(3) then
        self.dragging = false
    end
        
    if self.dragging then
        local view = self:get_active_view()
        view:set_position(view:get_position() - vec2(dx, dy))
    end
end

function Editor:mousepressed(x, y, button)
    if button == 3 then
        self.dragging = true
    end
end

function Editor:wheelmoved(x, y, dx, dy)

    local view = self:get_active_view()
    
    -- First frame, remaining space underneath main menu bar
    -- has not been calculated yet, so return early
    if self.view_y == 0 then return end
    
    local old_scale = view:get_scale()
    view:set_scale( get_exp_scale(get_log_scale(view:get_scale()) + dy * 0.05))
    local new_scale = view:get_scale()
        
    local rx, ry = x, y - self.view_y
        
    local old_wx = (rx + view:get_position().x ) / old_scale
    local old_wy = (ry + view:get_position().y ) / old_scale
        
    local new_wx = (rx + view:get_position().x ) / new_scale
    local new_wy = (ry + view:get_position().y ) / new_scale
        
    local ox = (new_wx - old_wx) * new_scale
    local oy = (new_wy - old_wy) * new_scale
        
    view:set_position( view:get_position() - vec2(ox, oy) )
end

return Editor