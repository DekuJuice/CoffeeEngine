local lily = require("enginelib.lily")

local scaledraw = require("enginelib.scaledraw")

local Texture = require("class.engine.resource.Texture")
local Node = require("class.engine.Node")
local Node2d = require("class.engine.Node2d")

local SceneModel = require("class.editor.SceneModel")
local ActionDispatcher = require("class.editor.ActionDispatcher")

local ResourceInspector = require("class.editor.ResourceInspector")
local ResourceTreeView = require("class.editor.ResourceTreeView")
local ResourceSelector = require("class.editor.ResourceSelector")
local NodeTreeView = require("class.editor.NodeTreeView")
local NodeInspector = require("class.editor.NodeInspector")
local SceneSelector = require("class.editor.SceneSelector")

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

local function draw_grid(origin, rect, grid_size)
    local w, h = rect:unpack()
    local ox, oy = origin:unpack()
    local cellw, cellh = grid_size:unpack()

    for x = 0, w, cellw do
        love.graphics.line(x + ox, 0, x + ox, h)
    end

    for y = 0, h, cellh do
        love.graphics.line(0, y + oy, w, y + oy)
    end
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
    preload_class("class/game")
end

function Editor:initialize()

    Node.initialize(self, "Editor")

    self.scene_models = {}
    self.active_scene = 1
    self:add_new_scene() -- Make sure there is always at least one scene open

    self.dragging = false
    self.view_pos = vec2()
    self.action_dispatcher = ActionDispatcher()

    self.show_resource_inspector = true -- whether to show resource inspector or node inspector
    self.show_inspector = true

    -- Add actions
    self.action_dispatcher:add_action("Save", function() 
            local model = self:get_active_scene()
            if not model:get_tree():get_root() then
                self:get_node("AlertModal"):show("Alert!", "The scene must have a root node to be saved.", {"Ok"})
                return
            end
            local path = model:get_filepath()
            if not path then
                self.action_dispatcher:do_action("Save As")
                return 
            end
            
            resource.save_resource(model:pack())
            
        end, "ctrl+s")

    self.action_dispatcher:add_action("Save As", function()
            local model = self:get_active_scene()
            if not model:get_tree():get_root() then
                self:get_node("AlertModal"):show("Alert!", "The scene must have a root node to be saved.", {"Ok"})
                return
            end
    
            self:get_node("SaveAsModal"):open( 
                self:get_active_scene():get_filepath()
            )
        end, "ctrl+shift+s")

    self.action_dispatcher:add_action("New Scene", function()
            self:add_new_scene()
        end, "ctrl+n")

    self.action_dispatcher:add_action("Open Scene", function()
            self:get_node("OpenSceneModal"):open()
        end, "ctrl+o")

    self.action_dispatcher:add_action("Close Scene", function()
            self:close_scene(self.active_scene)
        end, "ctrl+w")

    self.action_dispatcher:add_action("Undo", function()
            self:get_active_scene():undo()
        end, "ctrl+z")

    self.action_dispatcher:add_action("Redo", function()
            self:get_active_scene():redo()
        end, "ctrl+y")

    self.action_dispatcher:add_action("Add Node", function()
        self:get_node("AddNodeModal"):open()
    end, "ctrl+a")
    
    self.action_dispatcher:add_action("Move Node Up", function()
        local scene = self:get_active_scene()
        local sel = scene:get_selected_nodes()[1]
        local par = sel:get_parent()
        if sel and par then
            local old_i = par:get_child_index(sel)
            if old_i > 1 then
                
                local cmd = scene:create_command("Move child up")
                cmd:add_do_func(function()
                    par:move_child(sel, old_i - 1)
                end)
                
                cmd:add_undo_func(function()
                    par:move_child(sel, old_i)
                end)
                
                scene:commit_command(cmd)
                
            end
        end
    end,"ctrl+up")
    
    self.action_dispatcher:add_action("Move Node Down", function()
        local scene = self:get_active_scene()
        local sel = scene:get_selected_nodes()[1]
        local par = sel:get_parent()
        if sel and par then
            local old_i = par:get_child_index(sel)
            if old_i < par:get_child_count() then
                
                local cmd = scene:create_command("Move child down")
                cmd:add_do_func(function()
                    par:move_child(sel, old_i + 1)
                end)
                
                cmd:add_undo_func(function()
                    par:move_child(sel, old_i)
                end)
                
                scene:commit_command(cmd)
                
            end
        end
    end,"ctrl+down")
    
    self.action_dispatcher:add_action("Reparent Node", function()
        self:get_node("ReparentNodeModal"):open()
        -- Open reparent modal
    end)
    
    self.action_dispatcher:add_action("Duplicate Node", function()
        local scene = self:get_active_scene()
        local sel = scene:get_selected_nodes()[1]
        local par = sel:get_parent()
        if sel and par then
            local dupe = sel:duplicate()
            local cmd = scene:create_command("Duplicate Node")
            cmd:add_do_func(function() 
                par:add_child(dupe)
            end)
            cmd:add_undo_func(function() 
                par:remove_child(dupe)
            end)
            
            scene:commit_command(cmd)
        
        end
    end, "ctrl+d")
    
    self.action_dispatcher:add_action("Delete Node", function()
    
        local scene = self:get_active_scene()
        local selection = scene:get_selected_nodes()
        local sel = selection[1]
        if not sel then return end
        
        local par = sel:get_parent()
                
        local cmd = scene:create_command("Delete Node")
        
        if par then
            local c_index = par:get_child_index(sel)
            cmd:add_do_func(function() 
                par:remove_child(sel)
                scene:set_selected_nodes({})
            end)
            
            cmd:add_undo_func(function()
                par:add_child(sel)
                par:move_child(sel, c_index)
                scene:set_selected_nodes(selection)
            end)
            
        else
            cmd:add_do_func(function()
                scene:get_tree():set_root(nil)
                scene:set_selected_nodes({})
            end)
            
            cmd:add_undo_func(function()
                scene:get_tree():set_root(sel)
                scene:set_selected_nodes(selection)
            end)
        end
        
        
        scene:commit_command(cmd)
        
    
    
    end, "delete")


    self.action_dispatcher:add_action("Toggle Grid", function()
            local scene = self:get_active_scene()
            scene:set_draw_grid( not scene:get_draw_grid() )
        end, "ctrl+g")

    self.action_dispatcher:add_action("Toggle Physics Debug", function()
            local scene = self:get_active_scene()
            local tree = scene:get_tree()
            tree:set_debug_draw_physics(not tree:get_debug_draw_physics())
        end, "ctrl+]")

    self.action_dispatcher:add_action("Recenter View", function()
            self:get_active_view():set_position(vec2(0, 0))
        end, "ctrl+shift+f")

    self.action_dispatcher:add_action("Show Inspector", function()
            self.show_inspector = not self.show_inspector
        end, "ctrl+shift+i")

    -- Add other components
    for _, p in ipairs({
        "class.editor.Console",
        "class.editor.NodeTreeView",
        "class.editor.Node2dPlugin",
        "class.editor.CollidablePlugin",
        "class.editor.TileMapPlugin",
        "class.editor.AddNodeModal",
        "class.editor.ReparentNodeModal",
        "class.editor.SaveAsModal",
        "class.editor.OpenSceneModal",
        "class.editor.AlertModal",
        "class.editor.ScenePlayer"
    }) do
        self:add_child(require(p)())
    end
    
    
    

end

function Editor:get_active_scene()
    return self.scene_models[self.active_scene]
end

function Editor:get_active_view()
    return self:get_active_scene():get_tree():get_viewport()
end

function Editor:add_action(name, func, shortcut)
    self.action_dispatcher:add_action(name, func, shortcut)
end

function Editor:do_action(name)
    self.action_dispatcher:do_action(name)
end

function Editor:add_new_scene(filepath)

    if filepath then
        for i,scene in ipairs(self.scene_models) do
            if scene:get_filepath() == filepath then
                self.active_scene = i
                return
            end
        end
    end

    local model = SceneModel(filepath)
    model:get_tree():set_debug_draw_physics(true)
    table.insert(self.scene_models, model)

    self.active_scene = #self.scene_models
end

function Editor:_close_scene(index)
    if self.active_scene > index or self.active_scene == #self.scene_models then
        self.active_scene = self.active_scene - 1
    end

    local scene = table.remove(self.scene_models, index)

    if (#self.scene_models == 0) then
        self:add_new_scene()
        self.active_scene = 1
    end
end

function Editor:_on_close_modal_button_pressed(index, button)
    if button == "Confirm" then
        self:_close_scene( self.active_scene )
    end
    local am = self:get_node("AlertModal")
    am:disconnect("button_pressed", self, "_on_close_modal_button_pressed")
end

function Editor:close_scene(index)
    local scene = self.scene_models[index]
    if scene:get_modified() then
        local am = self:get_node("AlertModal")
        am:show("Alert!", "Scene has unsaved changes. Close anyways?", {"Confirm", "Cancel"})
        am:connect("button_pressed", self, "_on_close_modal_button_pressed")
    else
        self:_close_scene(index)
    end
end

function Editor:transform_to_world(point)
    return self:get_active_view():transform_to_world(point - self.view_pos)
end

function Editor:transform_to_screen(point)
    return self:get_active_view():transform_to_viewport(point) + self.view_pos
end

function Editor:get_inspected_resource()
    return self.inspected_resource
end

function Editor:draw_grid(position, scale, cellsize)
    local vw, vh = self:get_active_view():get_resolution()
    if vw <= 0 or vh <= 0 then return end

    love.graphics.push("all")
    cellsize =  cellsize * scale

    love.graphics.translate(self.view_pos:unpack())
    love.graphics.translate(0.5, 0.5)
    love.graphics.setLineStyle("rough")

    local origin = -(cellsize + position)
    origin.x = origin.x % cellsize.x
    origin.y = origin.y % cellsize.y

    for x = 0, vw, cellsize.x do
        love.graphics.line(x + origin.x, 0, x + origin.x, vh)
    end

    for y = 0, vh, cellsize.y do
        love.graphics.line(0, y + origin.y, vw, y + origin.y)
    end

    love.graphics.pop()
end

function Editor:_menu_item(name, checked)
    local shortcut = self.action_dispatcher:get_shortcut(name) or ""

    if imgui.MenuItem(name, shortcut:upper(), checked) then
        self.action_dispatcher:do_action(name)
    end
end

-- manu menu bar, toolbar, and tabbar
function Editor:_draw_top_bars()
    -- Main Menu Bar --
    local menu_bar_height = 0 

    if imgui.BeginMainMenuBar() then

        if imgui.BeginMenu("File") then
            self:_menu_item("Save")
            self:_menu_item("Save As")
            imgui.Separator()
            self:_menu_item("New Scene")
            self:_menu_item("Open Scene")
            self:_menu_item("Close Scene")
            imgui.EndMenu()
        end

        if imgui.BeginMenu("Edit") then
            self:_menu_item("Undo")
            self:_menu_item("Redo")
            imgui.EndMenu()
        end

        if imgui.BeginMenu("View") then
            self:_menu_item("Recenter View")        
            imgui.Separator()
            self:_menu_item("Toggle Grid", self:get_active_scene():get_draw_grid() )
            imgui.Separator()
            self:_menu_item("Show Inspector", self.show_inspector)
            imgui.EndMenu()
        end

        local mw, mh = imgui.GetWindowSize()
        menu_bar_height = mh
        imgui.EndMainMenuBar()
    end

    -- Tabbar --
    local tab_bar_height = 0
    imgui.SetNextWindowPos(0, menu_bar_height)
    imgui.SetNextWindowSize(love.graphics.getWidth(), 0)
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

    imgui.PushStyleVar("ImGuiStyleVar_ItemSpacing", 8, 8)

    if imgui.BeginTabBar("SceneTabs", {
            "ImGuiTabBarFlags_Reorderable",
            "ImGuiTabBarFlags_TabListPopupButton",
            "ImGuiTabBarFlags_FittingPolicyResizeDown",
            "ImGuiTabBarFlags_AutoSelectNewTabs"
            }) then

        for i,model in ipairs(self.scene_models) do
            local tabname = ("%d. %s"):format(i, model:get_name())        
            local tabflags = {}

            if model:get_modified() then
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


        for i = #self.children, 1, -1 do
            local c = self.children[i]
            if c.draw_toolbar then
                c:draw_toolbar()
                imgui.SameLine()
            end
        end

    end

    imgui.PopStyleVar(1)

    tab_bar_height = select(2, imgui.GetWindowSize())
    imgui.End()
    imgui.PopStyleVar()

    self.view_pos.y = tab_bar_height + menu_bar_height
end

function Editor:_draw_scene_nodes()
    local gdim = vec2(love.graphics.getDimensions())
    local vdim = gdim - self.view_pos

    local curmodel = self:get_active_scene()
    local view = self:get_active_view()

    if (vdim.x > 0 and vdim.y > 0) then

        local pw, ph = view:get_resolution()
        if (pw ~= vdim.x or ph ~= vdim.y) then
            view:set_resolution(vdim.x, vdim.y)
        end

        local position = view:get_position()
        local scale = view:get_scale()
        -- Scaling for the grid is done manually so that lines are always at full resolution
        if curmodel:get_draw_grid() then
            love.graphics.push("all")
            local minor = curmodel:get_grid_minor()
            local major = curmodel:get_grid_major()
            love.graphics.setColor(0.4, 0.4, 0.4, 0.3)
            self:draw_grid(position, scale, minor)
            love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
            self:draw_grid(position, scale, major)
            love.graphics.pop()
        end

        love.graphics.push("all")
        love.graphics.translate(self.view_pos:unpack())            
        -- Always draw origin lines
        love.graphics.setLineStyle("rough")
        love.graphics.translate(0.5, 0.5)
        local cx, cy = -position.x, -position.y
        love.graphics.setColor(1,0,0,0.5)
        love.graphics.line(0, cy, vdim.x, cy)
        love.graphics.setColor(0,1,0,0.5)
        love.graphics.line(cx, 0, cx, vdim.y)
        love.graphics.pop()

        curmodel:get_tree():draw(self.view_pos.x, self.view_pos.y, vdim:unpack()) 
    end
end

function Editor:_draw_resource_tree_view()
    if self.resource_tree_view:begin_window() then
        if imgui.Button(("%s Create Resource"):format(IconFont.FILE_PLUS) ) then
            self.resource_selector:set_open(true)
        end

        self.resource_tree_view:display(self.resource_tree_view_selection)

        self.resource_tree_view_selection = self.resource_tree_view:get_selection()
        if self.resource_tree_view:is_selection_changed() then
            self.inspected_resource = resource.get_resource(self.resource_tree_view_selection[1])
        end
        local focus = imgui.IsWindowFocused({"ImGuiFocusedFlags_RootAndChildWindows"})   
        if focus or self.resource_tree_view:is_selection_changed() then
            self.show_resource_inspector = true
        end

    end
    self.resource_tree_view:end_window()
end

function Editor:_draw_node_tree_view()
    -- Node Tree View
    if self.node_tree_view:begin_window() then
        local model = self:get_active_scene()
        self.node_tree_view:set_scene_model(model)
        self.node_tree_view:display( model:get_selected_nodes() )
        model:set_selected_nodes( self.node_tree_view:get_selection() )
        local focus = imgui.IsWindowFocused({"ImGuiFocusedFlags_RootAndChildWindows"})
        if focus or self.node_tree_view:is_selection_changed() then
            self.show_resource_inspector = false
        end
        
        if self.node_tree_view:is_new_node_selected() then -- Add new node
            local nclass = self.node_tree_view:get_new_node()
            
            if not rawget(nclass.static, "noinstance") then
            
                local sel = model:get_selected_nodes()
                local path
                if sel[1] then path = sel[1]:get_absolute_path() end
                local instance = nclass()
                local cmd = model:create_command("Add Node")
                cmd:add_do_func(function()
                        model:add_node(path, instance)
                        model:set_selected_nodes({instance})            
                    end)
                cmd:add_undo_func(function()
                        model:remove_node(instance)
                        model:set_selected_nodes(sel)
                    end)
                model:commit_command(cmd)
            
            end
        end
        
        
        
        
    end
    self.node_tree_view:end_window() 
end

function Editor:_draw_resource_inspector()
    if self.resource_inspector:begin_window() then
        self.resource_inspector:display(self.inspected_resource)
        if self.inspected_resource then
            if self.resource_inspector:is_var_changed() then
                local k = self.resource_inspector:get_changed_var_name()
                local v = self.resource_inspector:get_changed_var_value()
                local setter = ("set_%s"):format(k)
                self.inspected_resource[setter](self.inspected_resource, v)
                self.inspected_resource:set_has_unsaved_changes(true)
            end
            if self.resource_inspector:is_filepath_changed() then
                local new_path = self.resource_inspector:get_new_filepath()
                local ext = self.inspected_resource.class.static.extensions[1]
                if new_path:match("[^.]+$") ~= ext then
                    new_path = ("%s.%s"):format(new_path, ext)
                end
                self.inspected_resource:set_filepath(new_path)            
            end
            if self.resource_inspector:save_pressed() then
                resource.save_resource(self.inspected_resource)
            end
        end
    end
    self.resource_inspector:end_window()
end

function Editor:_draw_node_inspector()
    if self.node_inspector:begin_window() then
        local model = self:get_active_scene()
        local selected = model:get_selected_nodes()[1]
        self.node_inspector:display(selected)
        if selected then
        
            if self.node_inspector:is_tag_added() then
                local tag = self.node_inspector:get_tag_arg()
                local cmd = model:create_command("Add Tag")
                cmd:add_do_func(function() 
                    selected:add_tag(tag)
                end)
                
                cmd:add_undo_func(function()
                    selected:remove_tag(tag)
                end)
                
                model:commit_command(cmd)
                
            elseif self.node_inspector:is_tag_removed() then
                local tag = self.node_inspector:get_tag_arg()
                local cmd = model:create_command("Remove Tag")
                cmd:add_do_func(function()
                    selected:remove_tag(tag)
                end)
                
                cmd:add_undo_func(function()
                    selected:add_tag(tag)
                end)
                
                model:commit_command(cmd)
            end        
        
            if self.node_inspector:is_var_changed() then
                local name = self.node_inspector:get_changed_var_name()
                local v = self.node_inspector:get_changed_var_value()
                local old_v = selected[("get_%s"):format(name)](selected)
                local ep = selected.class:get_exported_vars()[name]
                local merge_mode = ep.editor_hints.merge_mode
                if self.node_inspector:is_change_finalized() then
                    merge_mode = nil
                end
                local cmd = model:create_command(("Modify %s"):format(name), merge_mode)
                cmd:add_do_var(selected, name, v)
                cmd:add_undo_var(selected, name, old_v)
                model:commit_command(cmd)
            end
        end
    end
    self.node_inspector:end_window()


end

function Editor:_draw_resource_selector()
    if self.resource_selector:begin_window() then
        self.resource_selector:display(self.resource_selector_selection)
        self.resource_selector_selection = self.resource_selector:get_selection()
        if self.resource_selector:is_selection_changed() then
            local instance = self.resource_selector_selection[1]()
            self.inspected_resource = instance
            self.resource_tree_view_selection = {}
        end                
    end
    self.resource_selector:end_window()
end

function Editor:draw()

    imgui.ShowDemoWindow() 

    self:_draw_top_bars()
    self:_draw_scene_nodes()
    --self:_draw_resource_tree_view()
    --self:_draw_node_tree_view()
    
    --[[self.resource_inspector:set_open(self.show_inspector)
    self.node_inspector:set_open(self.show_inspector)

    if self.show_resource_inspector then
        self:_draw_resource_inspector()
    else
        self:_draw_node_inspector()
    end
    
    if not self.node_inspector:get_open() or not self.resource_inspector:get_open() then
        self.show_inspector = false
    end]]--

    --self:_draw_resource_selector()
    --self:_draw_scene_selector()

    -- undo/redo stack debug

    local scene = self:get_active_scene()
    for i,v in ipairs(scene.undo_stack) do
        love.graphics.print(v.name, 200, 200 + 15 * i)
    end
end

-- Callbacks --

function Editor:keypressed(key)
    if self.action_dispatcher:keypressed(key) then
        return true
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
    if self.view_pos.y == 0 then return end

    local old_scale = view:get_scale()
    view:set_scale( get_exp_scale(get_log_scale(view:get_scale()) + dy * 0.05))
    local new_scale = view:get_scale()

    local rx, ry = x, y - self.view_pos.y

    local old_wx = (rx + view:get_position().x ) / old_scale
    local old_wy = (ry + view:get_position().y ) / old_scale

    local new_wx = (rx + view:get_position().x ) / new_scale
    local new_wy = (ry + view:get_position().y ) / new_scale

    local ox = (new_wx - old_wx) * new_scale
    local oy = (new_wy - old_wy) * new_scale

    view:set_position( view:get_position() - vec2(ox, oy) )
end

return Editor