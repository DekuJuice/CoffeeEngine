local log = require("enginelib.log")
local lily = require("enginelib.lily")
local vec2 = require("enginelib.vec2")
local resource = require("resource")
local scaledraw = require("enginelib.scaledraw")

local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")

local SceneModel = require("class.editor.SceneModel")
local PackedScene = require("class.engine.resource.PackedScene")

local Editor = Node:subclass("Editor")
Editor.static.dontlist = true

local MIN_ZOOM = 0.5
local MAX_ZOOM = 8.0
local LOG_MIN_ZOOM = math.log(MIN_ZOOM)
local LOG_MAX_ZOOM = math.log(MAX_ZOOM)

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

local function draw_grid(ox, oy, w, h, cellw, cellh)
    for x = 0, w, cellw do
        love.graphics.line(x + ox, 0, x + ox, h)
    end
    
    for y = 0, h, cellh do
        love.graphics.line(0, y + oy, w, y + oy)
    end
end

function Editor:initialize()
    
    Node.initialize(self, "Editor")
    
    self.scene_models = {}
    self.scene_views = {}
    
    self.active_scene = 1
    
    self.dragging = false
    self.view_y = 0
    self.actions_to_do = {}
    
    self.show_window = {
        node_tree = true,
        inspector = true,
        signals = true
    }
    
    self.resource_preview_canvas = love.graphics.newCanvas(128, 128)
    
    self:add_child(require("class.editor.Node2dPlugin")())
    
    
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
    
    local tname = os.tmpname()
    if not tname then
        log.error("Failed to generate tmp filename, could not save the scene")
        return
    end

    local data = model:pack()
    
    local lobj = lily.write(tname, data)
    lobj:onComplete(function()
        local real_save = love.filesystem.getSaveDirectory()
        local real_tmp = real_save .. tname
        
        local real_path = love.filesystem.getWorkingDirectory() .. "/" .. path
        -- Remove old file first
        os.remove(real_path)
        os.rename(real_tmp, real_path)
        
        model:set_modified(false)
    end)
    
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

    -- Menu Bar --
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
    
    self:do_actions()
    
    -- Tabbar
    
    imgui.SetNextWindowPos(0, menu_bar_height)
    imgui.SetNextWindowSize(love.graphics.getWidth(), 40)
    imgui.PushStyleVar("WindowBorderSize", 0)
    imgui.Begin("Scenes", true, 
        {
        "ImGuiWindowFlags_NoTitleBar", 
        "ImGuiWindowFlags_NoMove", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoBringToFrontOnFocus",
        "ImGuiWindowFlags_NoDocking"
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
    
    do -- Draw nodes
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


    -- Other editor components
    self:draw_node_tree()
    self:draw_node_inspector()
    -- Modal Windows
    self:draw_alert_modal()
    self:draw_save_as_modal()
    self:draw_open_scene_modal() 

end

-- Modals

local function get_scene_list()
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

local function get_resource_list()
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

-- Open scene prompt
function Editor:open_open_scene_modal()
    imgui.OpenPopup("Open Scene")
end

function Editor:draw_open_scene_modal()
    local flags = {
        "ImGuiWindowFlags_AlwaysAutoResize", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoMove"
    }
    if imgui.BeginPopupModal("Open Scene", nil, flags) then
        
        local scenes = get_scene_list()
        imgui.BeginChild("Scene List", 400, 400)
        for _,s in ipairs(scenes) do
            if (imgui.Selectable(s, false, {"ImGuiSelectableFlags_AllowDoubleClick"})) then
                if (imgui.IsMouseDoubleClicked(0)) then
                    self:add_new_scene(s)
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

-- Add node prompt
function Editor:open_node_list_modal()
    imgui.OpenPopup("Add a new node")
end

function Editor:draw_node_list_modal()
    local popup_flags = {
        "ImGuiWindowFlags_AlwaysAutoResize", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoMove"
    }
    
    if imgui.BeginPopupModal("Add a new node", nil, popup_flags) then
        imgui.BeginChild("Scene List", 400, 400)
    
        -- Iterative Preorder Traversal
        local stack = {}
        local current_class = Node
        repeat
            -- Add subclasses to stack
            local subclasses = {}
            local has_subclasses = false
            for c in pairs(current_class.subclasses) do
                if not c.static.dontlist then
                    table.insert(subclasses, c)
                    has_subclasses = true
                end
            end
            
            
            local flags = {
                "ImGuiTreeNodeFlags_DefaultOpen",
                "ImGuiTreeNodeFlags_OpenOnArrow", 
                "ImGuiTreeNodeFlags_SpanAvailWidth",
                "ImGuiTreeNodeFlags_SpanFullWidth"
            }
            
            if not has_subclasses then
                table.insert(flags, "ImGuiTreeNodeFlags_Leaf")
            end
            
            local open = imgui.TreeNodeEx(current_class.name, flags)
            
            if imgui.IsItemHovered() then
                local x, y = imgui.GetItemRectMin()
                local mx, my = imgui.GetMousePos()
                local spacing = imgui.GetTreeNodeToLabelSpacing()
                    
                local m1 = imgui.IsMouseDoubleClicked(0)
                local m2 = imgui.IsMouseReleased(1)
                    
                if (m1 or m2) 
                and (not has_subclasses or (mx - x > spacing)) then
                    local scene = self:get_active_scene()
                    local instance = current_class()
                    
                    scene:start_command("AddNode", false)
                    local selection = scene:get_selected_nodes()
                    local path = "/"
                    if selection[1] then
                        path = selection[1]:get_absolute_path()
                    elseif scene:get_tree():get_root() then
                        path = scene:get_tree():get_root():get_absolute_path()
                    end
                    
                    scene:add_do_function(function()
                        scene:add_node(path, instance)
                    end)
                    
                    scene:add_undo_function(function()
                        scene:remove_node(instance)
                        scene:set_selected_nodes(selection)
                    end)
                    
                    scene:end_command()
                    
                    imgui.CloseCurrentPopup()
                end
            end
            
            if open then
                table.sort(subclasses,
                    function(a, b) return a.name < b.name end)
                
                table.insert(stack, "pop")
                for i = #subclasses, 1, -1 do
                    table.insert(stack, subclasses[i])
                end
            end

            current_class = table.remove(stack)
            while current_class == "pop" do
                current_class = table.remove(stack)
                imgui.TreePop()
            end
                
        until not current_class
        imgui.EndChild()
        
        
        
        imgui.Separator()
        
        if imgui.Button("Cancel", 120, 0) then
            imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
    end
end

-- Instance node prompt
function Editor:open_instance_modal()
    imgui.OpenPopup("Instance a scene")
end

function Editor:draw_instance_modal()
    local popup_flags = {
        "ImGuiWindowFlags_AlwaysAutoResize", 
        "ImGuiWindowFlags_NoResize",
        "ImGuiWindowFlags_NoMove"
    }
    if imgui.BeginPopupModal("Instance a scene", nil, popup_flags) then
                
        local scenes = get_scene_list()
        imgui.BeginChild("Scene List", 400, 400)
        for _,s in ipairs(scenes) do
            if (imgui.Selectable(s, false, {"ImGuiSelectableFlags_AllowDoubleClick"})) then
                if (imgui.IsMouseDoubleClicked(0)) then
                
                    
                
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

-- Tree View
function Editor:draw_node_tree()
    
    local tree_flags = {"ImGuiWindowFlags_MenuBar"}
    
    if not self.show_window.node_tree then return end

    local open_context = false
    local open_node_list = false
    local open_scene_list = false
    
    local open, window_open = imgui.Begin("Node Tree View", true, tree_flags)

    self.show_window.node_tree = window_open
    if open then
    
        if imgui.BeginMenuBar() then
            if imgui.Button("Add Node") then
                open_node_list = true
            end
            
            if imgui.Button("Instance Scene") then
                open_scene_list = true
            end
            
            -- TODO: Move up/Move down/Delete buttons
            imgui.EndMenuBar()            
        end
        
        local model = self:get_active_scene()
        local root = model:get_tree():get_root()
        
        if root then
        
            local selected_nodes = model:get_selected_nodes()
            
            -- Iterative Preorder Traversal
            local stack = {}
            local current_node = root
            
            repeat
                local has_children = false
                local children = current_node:get_children()
                
                for _,c in ipairs(children) do
                    has_children = true
                end
                
                -- Draw the tree node
                local node_flags = 
                    {"ImGuiTreeNodeFlags_OpenOnArrow", 
                    "ImGuiTreeNodeFlags_SpanFullWidth",
                    "ImGuiTreeNodeFlags_DefaultOpen"}
                    
                local is_selected = false
                local should_open = false
                for _,v in ipairs(selected_nodes) do
                    if v == current_node then
                        is_selected = true
                    elseif current_node:is_parent_of(v) then
                        should_open = true
                    end
                end
                
                if should_open then
                    imgui.SetNextItemOpen(true)
                end
                
                if is_selected then
                    table.insert(node_flags, "ImGuiTreeNodeFlags_Selected")
                end
                
                if not has_children then
                    table.insert(node_flags, "ImGuiTreeNodeFlags_Leaf")
                end
                
                local open = 
                    imgui.TreeNodeEx(current_node:get_full_name(), node_flags)
                
                if imgui.IsItemHovered() then
                
                    -- Check that we're not clicking on the arrow
                    local x, y = imgui.GetItemRectMin()
                    local mx, my = imgui.GetMousePos()
                    local spacing = imgui.GetTreeNodeToLabelSpacing()
                    
                    local m1 = imgui.IsMouseReleased(0)
                    local m2 = imgui.IsMouseReleased(1)
                    
                    if (m1 or m2) 
                        and (not has_children or (mx - x > spacing)) then
                        
                        model:set_selected_nodes({current_node})
                        
                    end
                    
                    if m2 then
                        open_context = true
                    end

                end
                
                if open then
                    table.insert(stack, "pop")
                    for i = #children, 1, -1 do
                        table.insert(stack, children[i])
                    end
                    
                end
                
                current_node = table.remove(stack)
                
                while current_node == "pop" do
                    current_node = table.remove(stack)
                    imgui.TreePop()
                end
                
            until not current_node
        
        else
            imgui.Text("No Root Node")
        end
        
    end
    
    if open_context then
        imgui.OpenPopup("ContextMenu")
    end
    
    if imgui.BeginPopup("ContextMenu") then
        imgui.EndPopup()
    end
    
    if open_node_list then
        self:open_node_list_modal()
    end
    
    if open_scene_list then
        self:open_instance_modal()
    end
    
    self:draw_node_list_modal()
    self:draw_instance_modal()
    
    imgui.End()

end

-- Node Inspector
function Editor:_draw_property_widget(node, ep)
    local ptype = ep.type
    local name = ep.name
    local filter = ep.filter
    local editor_hints = ep.editor_hints
    local display_name = editor_hints.display_name or name
    
    local getter = ("get_%s"):format(name)
    local setter = ("set_%s"):format(name)
        
    local val = node[getter](node)
    local new_val
    local changed = false
    
    imgui.AlignTextToFramePadding()
    imgui.Text(display_name)
    imgui.NextColumn()
    imgui.PushID(name)
    
    if ptype == "string" then
        changed, new_val = imgui.InputText("##StringInput", val, 64)
    elseif ptype == "float" then
        local velo, smin, smax = 
            editor_hints.speed, editor_hints.min, editor_hints.max
        velo = velo or 0.01
        smin = smin or 0
        smax = smax or 100
        
        changed, new_val = imgui.DragFloat("##FloatSlider", val, velo, smin, smax)
    
    elseif ptype == "vec2" then
        local velo, smin, smax = 
            editor_hints.speed, editor_hints.min, editor_hints.max
        velo = velo or 1
        smin = smin or 0
        smax = smax or 100
            
        local c, nx, ny = imgui.DragInt2("##Vec2Slider", val.x, val.y, velo, smin, smax)
        new_val = vec2(nx, ny)            
        changed = c
    elseif ptype == "bool" then
        changed, new_val = imgui.Checkbox("##Checkbox", val)
    elseif ptype == "resource" then
        if imgui.Button("Select") then
            imgui.OpenPopup("Resource Selector")
        end
        
        imgui.SameLine()
        imgui.Text("Path:")
        imgui.SameLine()
        
        if val then
            imgui.Text(val:get_filepath())
        else
            imgui.Text("No Resource")
        end

        if editor_hints.resource_type == "Texture" then
            if val then
                love.graphics.push("all")
                love.graphics.setCanvas(self.resource_preview_canvas)
                love.graphics.clear(0,0,0,0)                
                scaledraw.draw( val:get_data(), "aspect", 0, 0, self.resource_preview_canvas:getDimensions() )
                love.graphics.setCanvas()
                
                imgui.Image(self.resource_preview_canvas, 128, 128) 
                
                love.graphics.pop()
            end
        end
        
        local popup_flags = {
            "ImGuiWindowFlags_AlwaysAutoResize", 
            "ImGuiWindowFlags_NoResize",
            "ImGuiWindowFlags_NoMove"
        }
        
        if imgui.BeginPopupModal("Resource Selector", nil, popup_flags) then
            
            local resources = get_resource_list()
            imgui.BeginChild("Resource List", 400, 400)
            for _,s in ipairs(resources) do
                if (imgui.Selectable(s, false, {"ImGuiSelectableFlags_AllowDoubleClick"})) then
                    if (imgui.IsMouseDoubleClicked(0)) then
                        
                        local res = resource.get_resource(s)
                        
                        if res then
                        
                            new_val = res
                            changed = true
                        
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
        
    imgui.PopID()
    imgui.NextColumn()
    
    if changed and filter(new_val) then
        local scene = self:get_active_scene()
        scene:start_command(("Edit%s"):format(name), false)
        scene:add_do_function(function() 
            node[setter](node, new_val)
        end)
        
        scene:add_undo_function(function()
            node[setter](node, val)
        end)

        scene:end_command()
    end
end

function Editor:draw_node_inspector()
    local inspector_flags = {}
    
    if not self.show_window.inspector then return end
    
    local open, window_open = imgui.Begin("Node Inspector", true, inspector_flags)
    self.show_window.inspector = window_open
    
    if open then
        local model = self:get_active_scene()
        local target = model:get_selected_nodes()[1]
        if target then
            imgui.Text("Path:")
            imgui.SameLine()
            imgui.Text(target:get_absolute_path())
            
            imgui.Columns(2)
            
            local class = target.class
            while class do
                local static = rawget(class, "static")
                if static then
                    local exported = rawget(static, "exported_vars")
                    if exported then
                        imgui.Separator()
                        for _, ep in ipairs(exported) do
                            self:_draw_property_widget(target, ep)
                        end
                    end
                end
                class = class.super
            end
            
            imgui.Columns(1)
            
        else
            imgui.Text("No Node Selected")
        end
    end
    
    imgui.End()
    
end


-- Signal Inspector

function Editor:do_actions()
    -- Handle shortcut/menubar actions
    if self.actions_to_do.undo then
        self:get_active_scene():undo()
    end
    
    if self.actions_to_do.redo then
        self:get_active_scene():redo()
    end

    if self.actions_to_do.new then
        self:add_new_scene()
    end
    
    if self.actions_to_do.save then
        self:save_scene()
    end
    
    if self.actions_to_do.saveas then
        self:open_save_as_modal()
    end
    
    if self.actions_to_do.open then
        self:open_open_scene_modal()
    end
    
    if self.actions_to_do.close then
        self:close_scene(self.active_scene)
    end

    if self.actions_to_do.show_node_tree then
        self.show_window.node_tree = not self.show_window.node_tree
    end
    
    if self.actions_to_do.show_inspector then
        self.show_window.inspector = not self.show_window.inspector
    end
    

    self.actions_to_do = {}
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