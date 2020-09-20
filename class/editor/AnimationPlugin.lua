local AnimationPlayer = require("class.engine.AnimationPlayer")
local Animation = require("class.engine.Animation")

local Node = require("class.engine.Node")
local AnimationPlugin = Node:subclass("AnimationPlugin")
AnimationPlugin.static.dontlist = true

local MIN_ZOOM = 0.5
local MAX_ZOOM = 8.0
local LOG_MIN_ZOOM = math.log(MIN_ZOOM)
local LOG_MAX_ZOOM = math.log(MAX_ZOOM)
local PIXELS_PER_SECOND = 400
local MINIMUM_STEP = 60

local ANIMATABLE_TYPES = {
    vec2_int = true,
    vec2 = true,
    float = true,
    int = true,
    color = true
}

-- f(x) = e^(a + bx)
-- a = log_min_zoom
-- b = log_max_zoom - log_min_zoom
local function get_exp_scale(scale)
    return math.exp( LOG_MIN_ZOOM + (LOG_MAX_ZOOM - LOG_MIN_ZOOM) * scale ) 
end

function AnimationPlugin:initialize()
    Node.initialize(self)
    self.timeline_zoom = 0.5

    self.is_open = true

    self.selected_animation_player = nil

    self.snap = true
    self.time_unit = "Frames"
    self.second_snap = 0.1
    self.framerate = 60

    self.selected_animation = nil
    self.selected_track = 1
    self.selected_keyframe = nil

    self.timeline_drag = false
    self.keyframe_drag = false
    self.keyframe_drag_time = 0
    
    self.rename_animation_modal_open = false
    
    self.new_track_modal_open = false
    self.new_track_modal_type = "Variable"
    self.new_track_modal_path = ""
    self.new_track_modal_selected_node = nil
    self.new_track_modal_selected_property = nil
    self.func_track_popup_open = false
end

function AnimationPlugin:enter_tree()
    local scene = self:get_parent():get_active_scene_model()

    local test_anim = Animation()
    test_anim:add_function_track("..")
    test_anim:add_variable_track("..", "position", false, false)
    test_anim:function_track_add_key(1, 0.25, "func_a")
    test_anim:function_track_add_key(1, 0.5, "func_b")

    test_anim:variable_track_add_key(2, 0.3, vec2(20, 20))
    test_anim:variable_track_add_key(2, 0.6, vec2(40, 60))
    test_anim:set_loop(true)

    local ap = AnimationPlayer()
    ap:add_animation(test_anim)

    local n2 = require("class.engine.Node2d")()
    scene:get_tree():set_current_scene(n2)
    
    local n3 = require("class.engine.Node2d")()
    
    n2:add_child(ap)
    ap:set_owner( n2 )
    ap:add_child(n3)
    n3:set_owner(n2)
    
    ap:connect("animation_looped", n3, "print_tree")

    scene:set_selected_nodes({ap})

    self.selected_animation = "Unnamed"
    
    local parent = self:get_parent()
    parent:add_action("Show Inspector", function()
        self.is_open = not self.is_open
    end)
    
end

function AnimationPlugin:update(dt)
    if not love.mouse.isDown(1) then
        self.timeline_drag = false
        if self.keyframe_drag then
            local animp = self.selected_animation_player
            local editor = self:get_parent()
            local model = editor:get_active_scene_model()
            
            if animp then
                local anim = animp:get_animation(self.selected_animation)
                local st = self.selected_track
                local kf = self.selected_keyframe
                local nt = self.keyframe_drag_time
                local old_t = anim:get_keyframe_time(st, kf)
                
                local cmd = model:create_command("Move keyframe")
                cmd:add_do_func(function()
                    self.selected_track = st
                    anim:set_keyframe_time(st, kf, nt)
                    self.selected_keyframe = anim:get_keyframe_index(st, nt)
                end)
                        
                local old_i = anim:get_keyframe_index(st, nt)
                if old_i then
                    
                else
                    cmd:add_undo_func(function()
                        local i = anim:get_keyframe_index(st, nt)
                        anim:set_keyframe_time(st, i, old_t)
                        self.selected_keyframe = anim:get_keyframe_index(st, old_t)
                    end)
                end
                        
                model:commit_command(cmd)

                self.keyframe_drag = false
            end
        end
    end
end

function AnimationPlugin:_open_new_track_modal()
    self.new_track_modal_open = true
    self.new_track_modal_path = ""
    self.new_track_modal_selected_node = nil
    self.new_track_modal_selected_property = nil    
end

function AnimationPlugin:_draw_new_track_modal()
    if not self.new_track_modal_open then
        return
    end

    imgui.OpenPopup("New Track")

    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    
    local animp = self.selected_animation_player
    if not animp then return end
    
    local animation = animp:get_animation(self.selected_animation)
    
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})

    local flags = {}

    local should_draw, window_open = imgui.BeginPopupModal("New Track", self.new_track_modal_open, flags)
    self.new_track_modal_open = window_open

    if should_draw then

        if imgui.BeginCombo("Track Type", self.new_track_modal_type) then
            if imgui.Selectable("Variable") then
                self.new_track_modal_type = "Variable"
            end

            if imgui.Selectable("Function") then
                self.new_track_modal_type = "Function"
            end

            imgui.EndCombo()
        end

        if self.new_track_modal_type == "Variable" then
            local ep_arr = {}
            if self.new_track_modal_selected_node then
                local class = self.new_track_modal_selected_node.class
                local ep_n = class:get_exported_vars()
                    
                for nm, p in pairs(ep_n) do
                    table.insert(ep_arr, p)
                end
                    
                table.sort(ep_arr, function(a, b) return a.name < b.name end)
                    
                if not ep_n[self.new_track_modal_selected_property] then
                    self.new_track_modal_selected_property = nil
                end
            
            end
            if imgui.BeginCombo("Property", tostring(self.new_track_modal_selected_property)) then
                for _,ep in ipairs(ep_arr) do
                    if ANIMATABLE_TYPES[ep.type] then
                        if imgui.Selectable(ep.name) then
                            self.new_track_modal_selected_property = ep.name
                        end
                    end
                end
                imgui.EndCombo()
            end
        end

        imgui.BeginChild("##Tree Area", -1, -28, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )

        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg", "ImGuiTableFlags_BordersVInner"}) then
            local root = model:get_tree():get_root()

            local stack = { root }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == 0 then
                    imgui.TreePop()
                else
                    imgui.TableNextRow()

                    local is_leaf = true

                    for _,child in ipairs(top:get_children()) do
                        if child:get_owner() == root then
                            is_leaf = false
                            break
                        end
                    end

                    local tree_node_flags = {
                        "ImGuiTreeNodeFlags_OpenOnArrow", 
                        "ImGuiTreeNodeFlags_SpanFullWidth",
                        "ImGuiTreeNodeFlags_DefaultOpen",
                    }

                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end

                    if top == self.new_track_modal_selected_node then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                    end

                    if self.new_track_modal_selected_node 
                    and top:is_parent_of(self.new_track_modal_selected_node) then 
                        imgui.SetNextItemOpen(true)
                    end

                    local dname = top:get_name()
                    if top.class.icon then
                        dname = ("%s %s"):format(top.class.icon, dname)
                    end

                    local open = imgui.TreeNodeEx(dname, tree_node_flags)

                    if imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                        self.new_track_modal_selected_node = top
                    end

                    if top:get_filepath() then
                        imgui.SameLine()
                        imgui.Text(("%s"):format(IconFont.LINK))
                    end

                    if open then
                        table.insert(stack, 0)

                        local children = top:get_children()
                        for i = #children, 1, -1 do
                            local c = children[i]
                            if c:get_owner() == root then     
                                table.insert(stack, c)
                            end
                        end
                    end
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()

        if imgui.Button("Confirm")
        or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Enter")) then
            imgui.CloseCurrentPopup()
            self.new_track_modal_open = false
            
            if self.new_track_modal_selected_node then
                local path = self.new_track_modal_selected_node:get_relative_path(animp)
                if self.new_track_modal_type == "Function" then
                    local cmd = model:create_command("Add Function Track")
                    cmd:add_do_func(function()
                        animation:add_function_track(path)
                    end)
                    
                    cmd:add_undo_func(function()
                        animation:remove_track(animation:get_track_count())
                    end)
                    
                    model:commit_command(cmd)
                elseif self.new_track_modal_type == "Variable" then
                
                    if self.new_track_modal_selected_property then
                        local cmd = model:create_command("Add Variable Track")
                        
                        cmd:add_do_func(function()
                            animation:add_variable_track(path, self.new_track_modal_selected_property)
                        end)
                        
                        cmd:add_undo_func(function()
                            animation:remove_track(animation:get_track_count())
                        end)
                        
                        model:commit_command(cmd)
                        
                    end
                
                end
            end
            
            
        end

        imgui.SameLine()
        if imgui.Button("Cancel") 
        or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Escape")) then
            imgui.CloseCurrentPopup()
            self.new_track_modal_open = false
        end

        imgui.EndPopup()
    end

    if not self.new_track_modal_open then
        self.new_track_modal_selected_node = nil
    end
end

function AnimationPlugin:_draw_rename_animation_modal()
    local animp = self.selected_animation_player
    local anim = animp:get_animation(self.selected_animation)
    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    
    if self.rename_animation_modal_open then
        imgui.OpenPopup("Rename Animation")
    end
    
    local window_flags = {"ImGuiWindowFlags_AlwaysAutoResize"}
    local should_draw, window_open = imgui.BeginPopupModal("Rename Animation", self.rename_animation_modal_open, window_flags)
    
    if should_draw then
        
        local changed, new_name = imgui.InputText("##Rename", anim:get_name(), 128, {"ImGuiInputTextFlags_EnterReturnsTrue"})
        if imgui.IsItemDeactivatedAfterEdit() then
            local cmd = model:create_command("Rename animation")
            local old_name = anim:get_name()
            cmd:add_do_func(function()
                animp:remove_animation(old_name)
                anim:set_name(new_name)
                animp:add_animation(anim)
                self.selected_animation = new_name
            end)
            
            cmd:add_undo_func(function()
                animp:remove_animation(new_name)
                anim:set_name(old_name)
                animp:add_animation(anim)
                self.selected_animation = old_name
            end)
            
            model:commit_command(cmd)
            imgui.CloseCurrentPopup()
            self.rename_animation_modal_open = false
        end
        
        if imgui.Button("Cancel", 120, 0) 
        or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Escape")) then
            imgui.CloseCurrentPopup()
            self.rename_animation_modal_open = false
        end
        imgui.EndPopup()
    end    
end

function AnimationPlugin:draw()

    local editor = self:get_parent()
    local model = editor:get_active_scene_model()
    
    if self.selected_animation_player then
        if self.selected_animation_player:get_tree() ~= model:get_tree() then
            self.selected_animation_player = nil
        end
    end
    
    local sel = model:get_selected_nodes()[1]
    if sel 
    and sel ~= self.selected_animation_player
    and sel:isInstanceOf(AnimationPlayer) then
        self.selected_animation_player = sel
    end
    
    local animp = self.selected_animation_player

    imgui.SetNextWindowSize(800, 800, "ImGuiCond_FirstUseEver")
    local flags = {"ImGuiWindowFlags_MenuBar"}

    local should_draw, open = imgui.Begin("Animation", self.is_open, flags)
    
    self.is_open = open

    if not animp then
        imgui.End()
        return
    end

    if should_draw then
        if imgui.BeginMenuBar() then

            if imgui.BeginMenu("Animation") then
                if imgui.MenuItem("New") then
                    local cmd = model:create_command("Add new animation")
                    local prev_selection = self.selected_animation
                    local new_anim = Animation()
                    cmd:add_do_func(function()
                            animp:add_animation(new_anim)
                            self.selected_animation = new_anim:get_name()
                        end)

                    cmd:add_undo_func(function()
                            -- Need to get name again as adding the animation
                            -- may have caused it to be renamed                        
                            animp:remove_animation(new_anim:get_name()) 
                            self.selected_animation = prev_selection
                        end)

                    model:commit_command(cmd)
                end

                if imgui.MenuItem("Rename") then
                    if animp:get_animation(self.selected_animation) then
                        self.rename_animation_modal_open = true
                    end
                end
                
                if imgui.MenuItem("Delete") then
                    local to_rem = animp:get_animation(self.selected_animation)
                    if to_rem then
                        local cmd = model:create_command("Delete Animation")
                        local new_selection
                        local anim_list = animp:get_animation_list()
                        for i, aname in ipairs(anim_list) do
                            if aname == to_rem:get_name() then
                                if i == #anim_list then
                                    new_selection = anim_list[i - 1]
                                else
                                    new_selection = anim_list[i + 1]
                                end
                                break
                            end
                        end

                        cmd:add_do_func(function()
                                animp:remove_animation(to_rem:get_name())
                                self.selected_animation = new_selection
                            end)

                        cmd:add_undo_func(function()
                                animp:add_animation(to_rem)
                                self.selected_animation = to_rem:get_name()
                            end)

                        model:commit_command(cmd)

                    end
                end

                imgui.EndMenu()
            end
            imgui.PushItemWidth(-144)            
            local anim_list = animp:get_animation_list()

            if imgui.BeginCombo("Current Animation", self.selected_animation and self.selected_animation or "[ None ]" ) then
                for _, name in ipairs(anim_list) do
                    if imgui.Selectable(name) then
                        self.selected_animation = name
                    end
                end
                imgui.EndCombo()
            end
            imgui.EndMenuBar()
        end

        self:_draw_rename_animation_modal()


        local animation = animp:get_animation(self.selected_animation)

        if not animation then
            self.selected_animation = "[ None ]"
            imgui.End()
            return
        end
        animp:set_current_animation(self.selected_animation)

        -- Playback control
        if imgui.Button(IconFont.SKIP_FORWARD) then
            animp:play()
            animp:set_playback_position(0)
        end
        imgui.SameLine()

        if animp:get_playing() then
            if imgui.Button(IconFont.PAUSE) then
                animp:stop()
            end

        else
            if imgui.Button(IconFont.PLAY) then
                animp:play()
            end
        end

        imgui.SameLine()
        if imgui.Button(IconFont.SQUARE) then
            animp:stop()
            animp:set_playback_position(0, true)
        end
        imgui.SameLine()
        imgui.PushItemWidth(-140)

        if self.time_unit == "Frames" then
            local fpos = math.floor(animp:get_playback_position() * self.framerate)
            local flen = math.floor(animation:get_length() * self.framerate)
            local changed, new = imgui.DragInt("Playback Position", fpos, 0.1, 0, flen, "Frame %d")
            
            if changed then
                animp:set_playback_position(new / self.framerate, true)
            end
        else

            local changed, new = imgui.DragFloat(
                "Playback Position",
                animp:get_playback_position(), 
                0.001, 
                0, 
                animation:get_length(),
                "%.3f seconds"
            )

            if changed then
                animp:set_playback_position(new, true)
            end
        end

        imgui.Separator()

        if imgui.Button("Add Track") then
            self:_open_new_track_modal()
        end

        imgui.SameLine()
        if imgui.Button("Insert Keyframe") then
            if self.selected_track <= animation:get_track_count() then
                local tt = animation:get_track_type(self.selected_track)
                if tt == "func" then
                    self.func_track_popup_open = true
                elseif tt == "var" then
                    
                    local ti = self.selected_track
                    local np = animation:get_track_node_path(ti)
                    local n = animp:get_node(np)
                    local prop = animation:variable_track_get_property(ti)
                    local getter = ("get_%s"):format(prop)
                    
                    if n and n[getter] then
                        local val = n[getter](n)
                        local cmd = model:create_command("Add variable keyframe")
                        local t = animp:get_playback_position()
                        
                        cmd:add_do_func(function()
                            animation:variable_track_add_key(ti, t, val)
                        end)
                        
                        local old_i = animation:get_keyframe_index(ti, t)
                        if old_i then
                            local old_v = animation:variable_track_get_key_value(ti, old_i)
                            local old_lerp = animation:variable_track_get_key_lerp(ti, old_i)
                            
                            cmd:add_undo_func(function()
                                animation:variable_track_add_key(ti, t, old_v, old_lerp)
                            end)
                            
                        else
                            
                            cmd:add_undo_func(function()
                                local i = animation:get_keyframe_index(ti, t)
                                animation:remove_keyframe(ti, i)                                
                            end)
                        end
                        
                        model:commit_command(cmd)
                    
                    end
                end
                
            end        
        end
        
        if self.func_track_popup_open then
            imgui.OpenPopup("funckeyframe")
            self.func_track_popup_open = false
        end
        
        if imgui.BeginPopup("funckeyframe") then
            imgui.CaptureKeyboardFromApp(true)
            local close_popup = false
            if imgui.BeginCombo("Method##Funckey", tostring(self.selected_method)) then
                local anim_target =  animp:get_node( animation:get_track_node_path(self.selected_track) )
                
                if anim_target then
                    local method_arr = {}
                    local class = anim_target.class
                    while class do
                        for k,v in pairs(rawget(class, "__declaredMethods")) do
                            if k[1] ~= "_" then
                                table.insert(method_arr, k)
                            end
                        end
                        class = class.super
                    end
                    table.sort(method_arr)
                    
                    for _, method in ipairs(method_arr) do
                        if imgui.Selectable(method) then
                        
                            local cmd = model:create_command("Add function keyframe")
                            local me = method
                            local ti = self.selected_track
                            local t = animp:get_playback_position()
                            local args = {}
                            
                            cmd:add_do_func(function()
                                animation:function_track_add_key(ti, t, me, args)
                            end)
                            
                            local old_i = animation:get_keyframe_index(ti, t)
                            if old_i then
                                local old_method = animation:variable_track_get_key_value(ti, old_i)
                                local old_args = animation:variable_track_get_key_lerp(ti, old_i)
                                
                                cmd:add_undo_func(function()
                                    animation:function_track_add_key(ti, t, old_method, old_args)
                                end)
                                
                            else
                                
                                cmd:add_undo_func(function()
                                    local i = animation:get_keyframe_index(ti, t)
                                    animation:remove_keyframe(ti, i)
                                end)
                            end
                            
                            model:commit_command(cmd)
                            
                            close_popup = false
                        end
                    end
                end
                imgui.EndCombo()            
            end
            if close_popup then
                imgui.CloseCurrentPopup()
            end
            
            imgui.EndPopup()
        end
        

        imgui.SameLine()
        imgui.PushItemWidth(-132)

        -- Animation length
        local anim_length = animation:get_length()

        if self.time_unit == "Frames" then
            local frames = math.floor(anim_length * self.framerate)
            local changed, new = imgui.DragInt("Length", frames, 0.05, 1, 2^31-1, "%d frames")
            local finalized = imgui.IsItemDeactivatedAfterEdit()

            local new_len = new / self.framerate

            if changed or finalized and new_len > 0 then
                local merge_mode
                if not finalized then merge_mode = "merge_ends" end
                local cmd = model:create_command("Change Animation Length", merge_mode)
                cmd:add_do_var(animation, "length", new_len)
                cmd:add_undo_var(animation, "length", anim_length)
                model:commit_command(cmd)
            end

        elseif self.time_unit == "Seconds" then
            local changed, new = imgui.DragFloat("Length", anim_length, 0.01, 0.01, math.huge, "%.3f seconds")
            local finalized = imgui.IsItemDeactivatedAfterEdit()

            if changed or finalized and new > 0 then
                local merge_mode
                if not finalized then merge_mode = "merge_ends" end
                local cmd = model:create_command("Change Animation Length", merge_mode)
                cmd:add_do_var(animation, "length", new)
                cmd:add_undo_var(animation, "length", anim_length)
                model:commit_command(cmd)
            end
        end
        imgui.SameLine()

        anim_length = animation:get_length()        

        -- Loop
        if imgui.Checkbox("Loop", animation:get_loop()) then
            local cmd = model:create_command("Change Animation Loop")
            cmd:add_do_var(animation, "loop", not animation:get_loop())
            cmd:add_undo_var(animation, "loop", animation:get_loop())
            model:commit_command(cmd)
        end
        imgui.Separator()

        -- Snap and snap quantile
        if imgui.Checkbox("Snap", self.snap) then self.snap = not self.snap end
        imgui.SameLine()
        imgui.PushItemWidth(100)

        if self.time_unit == "Frames" then
            local changed, new = imgui.DragInt("##SnapTime", self.framerate, 0.1, 1, 2^31 - 1)
            if changed then
                self.framerate = new
            end
        else
            local changed, new = imgui.DragFloat("##SnapTime", self.second_snap, 0.001, 0.01, math.huge, "%.2f")
            if changed then
                self.second_snap = new
            end
        end
        imgui.SameLine()

        -- Time display mode
        if imgui.BeginCombo("##Time Mode", self.time_unit) then
            if imgui.Selectable("Frames") then
                self.time_unit = "Frames"
            end
            if imgui.Selectable("Seconds") then
                self.time_unit = "Seconds"
            end

            imgui.EndCombo()
        end
        imgui.SameLine()
        imgui.PushItemWidth(-1)

        -- Zoom
        local changed,new = imgui.SliderFloat("##Zoom", self.timeline_zoom, 0, 1, IconFont.ZOOM_IN )
        self.timeline_zoom = new
        imgui.Separator()
        local zoom = get_exp_scale(self.timeline_zoom) -- Non-linear zoom scale

        if imgui.BeginChild("Timeline", -1,-1) then
            local table_flags = {   
                "ImGuiTableFlags_ScrollX",
                "ImGuiTableFlags_ScrollY",
                "ImGuiTableFlags_ScrollFreezeTopRow",
                "ImGuiTableFlags_ScrollFreezeLeftColumn",
                "ImGuiTableFlags_RowBg",
                "ImGuiTableFlags_Resizable",
                "ImGuiTableFlags_BordersV",
                "ImGuiTableFlags_BordersOuter"
            }

            imgui.PushStyleVar("ImGuiStyleVar_CellPadding", 0, 0)
            imgui.PushStyleVar("ImGuiStyleVar_FramePadding", 0, 0)

            if imgui.BeginTable("TimelineTable", 2, table_flags) then

                imgui.TableSetupColumn("Tracks", {"ImGuiTableColumnFlags_WidthFixed"}, 120)
                imgui.TableSetupColumn("Keyframes", {"ImGuiTableColumnFlags_WidthAlwaysAutoResize", "ImGuiTableColumnFlags_NoClipX"})
                imgui.TableNextRow(0, 40)
                imgui.TableSetColumnIndex(0)
                imgui.AlignTextToFramePadding()
                imgui.Text("Tracks")
                imgui.TableSetColumnIndex(1)
                -- Draw Timeline
                local wx, wy = imgui.GetWindowPos()
                local cx, cy = imgui.GetCursorPos()
                cx = cx - 4
                cy = cy - 2

                local dw, dh = imgui.GetContentRegionAvail()
                dw = dw + 4
                dh = dh + 2

                local tw = animation:get_length() * PIXELS_PER_SECOND * zoom
                local step

                if self.time_unit == "Frames" then
                    step = 1 / self.framerate * PIXELS_PER_SECOND * zoom 
                elseif self.time_unit == "Seconds" then
                    step = self.second_snap * PIXELS_PER_SECOND * zoom
                end

                if step < MINIMUM_STEP then
                    step = math.ceil(MINIMUM_STEP / step) * step
                end
                
                -- Timeline control
                imgui.InvisibleButton("##TimelineInv", tw + step * 2.5, 40) 
                
                local mx_time -- playback position at mouse cursor
                do
                    local ix = imgui.GetItemRectMin()
                    local mx = imgui.GetMousePos()
                    mx_time = (mx - ix) / PIXELS_PER_SECOND / zoom
                    if self.snap then
                        local snaptime
                        if self.time_unit == "Frames" then
                            snaptime = 1 / self.framerate
                        else
                            snaptime = self.second_snap
                        end
                        mx_time = math.round(mx_time, snaptime)
                    end
                end

                if imgui.IsItemClicked(0) then
                    self.timeline_drag = true
                end

                if self.timeline_drag then
                    animp:set_playback_position(mx_time, true)
                end

                local offset = imgui.GetScrollX() % step
                -- Snap lines
                for x = 0, dw, step do

                    imgui.AddLine("window",
                        wx + cx + x - offset, wy + cy - imgui.GetScrollY(),
                        wx + cx + x - offset, wy + cy + dh,
                        0xff553333)

                    imgui.SetCursorPos(cx + x + 4, cy + 2)
                    imgui.Text(("%.3f"):format(x / PIXELS_PER_SECOND / zoom))
                end

                -- Area indicating anim length
                imgui.AddRectFilled(
                    "window",
                    wx + cx - offset, wy + cy - imgui.GetScrollY(), 
                    wx + cx + anim_length * PIXELS_PER_SECOND * zoom - imgui.GetScrollX(), wy + cy + dh,
                    0x11ffaaff
                )

                -- Playback position
                local playback_x = animp:get_playback_position() * PIXELS_PER_SECOND * zoom
                imgui.AddLine("window",
                    wx + cx - imgui.GetScrollX() + playback_x, wy + cy - imgui.GetScrollY(),
                    wx + cx - imgui.GetScrollX() + playback_x, wy + cy + dh,
                    0x77ffffff
                )

                -- Table rows
                local col_pop = 0
                local i = 1 
                while i <= animation:get_track_count() do
                    local min_height = imgui.GetFontSize() * 4
                    imgui.TableNextRow(0, min_height)

                    -- Row color is not applied until the next TableNextRow call, so
                    -- we need to wait to pop the style colors

                    if i == self.selected_track then
                        imgui.PushStyleColor("ImGuiCol_TableRowBg", 0,159/255,255/255,30/255)
                        imgui.PushStyleColor("ImGuiCol_TableRowBgAlt", 0,159/255,255/255,30/255)
                        col_pop = col_pop + 2
                    else
                        imgui.PushStyleColor("ImGuiCol_TableRowBg", 0)
                        imgui.PushStyleColor("ImGuiCol_TableRowBgAlt", 1, 1, 1, 12/255)
                        col_pop = col_pop + 2
                    end

                    local np = animation:get_track_node_path(i)
                    local target_node = animp:get_node(np)
                    local track_type = animation:get_track_type(i)                    

                    imgui.TableSetColumnIndex(0)
                    if imgui.SmallButton(("%s##DelTrack%d"):format(IconFont.TRASH, i)) then
                        local track = animation.tracks[i]
                        local cmd = model:create_command("Delete animation track")
                        local ps = self.selected_track
                        local index = i
                        cmd:add_do_func(function()
                                table.remove(animation.tracks, index)
                                if self.selected_track == index and index > 1 then
                                    self.selected_track = self.selected_track - 1
                                end
                            end)

                        cmd:add_undo_func(function()
                                table.insert(animation.tracks, index, track)
                                self.selected_track = ps
                            end)

                        model:commit_command(cmd)

                        i = i - 1

                        goto CONTINUE
                    end

                    imgui.SameLine()
                    imgui.AlignTextToFramePadding()

                    if target_node then

                        if track_type == "func" then
                            imgui.Text(("%s %s"):format(target_node.class.static.icon, target_node:get_name()))

                        elseif track_type == "var" then
                            imgui.Text(("%s %s:%s"):format(
                                    target_node.class.static.icon, 
                                    target_node:get_name(),
                                    animation:variable_track_get_property(i)))
                        end

                        if imgui.IsItemHovered() then
                            imgui.BeginTooltip()
                            imgui.Text(np)
                            imgui.EndTooltip()
                        end
                    else

                        if track_type == "func" then
                            imgui.TextDisabled(np)
                        elseif track_type == "var" then
                            imgui.TextDisabled(("%s:%s"):format(np, animation:variable_track_get_property(i)))
                        end
                    end
                    
                    if track_type == "var" then
                        imgui.Indent()
                        if imgui.Checkbox("Clamp", animation:variable_track_get_wrap_clamp(i) ) then
                            local index = i
                            local cmd = model:create_command("Change track wrap mode")
                            local f = function()
                                animation:variable_track_set_wrap_clamp(index, 
                                    not animation:variable_track_get_wrap_clamp(index)
                                )
                            end
                            cmd:add_do_func(f)
                            cmd:add_undo_func(f)
                            
                            model:commit_command(cmd)
                        end
                        
                        if imgui.Checkbox("Discrete", animation:variable_track_get_update_discrete(i) ) then
                            local index = i
                            local cmd = model:create_command("Change track update mode")
                            local f = function()
                                animation:variable_track_set_update_discrete(index, 
                                    not animation:variable_track_get_update_discrete(index)
                                )
                            end
                            cmd:add_do_func(f)
                            cmd:add_undo_func(f)
                            
                            model:commit_command(cmd)
                        end
                    end

                    imgui.TableSetColumnIndex(1)
                    do
                        -- invisible item the width of timeline to select track
                        local cx, cy = imgui.GetCursorPos()
                        imgui.InvisibleButton(("##inv%d"):format(i), tw + step*2.5, min_height)
                        imgui.SetItemAllowOverlap()
                        if imgui.IsItemClicked(0) then
                            self.selected_track = i
                            self.selected_keyframe = nil
                        end
                        -- Keyframes
                        local j = 1
                        while j <= animation:get_keyframe_count(i) do
                            local ktime = animation:get_keyframe_time(i, j)
                            local kx = ktime * PIXELS_PER_SECOND * zoom
                            imgui.SetCursorPos(cx + kx - 14, cy + min_height/2 - 8)                            
                            imgui.InvisibleButton(("##Keyframe%d_%d"):format(i,j), 20, 16)
                            local kf_selected = self.selected_track == i and self.selected_keyframe == j

                            local circx = wx + cx + kx - imgui.GetScrollX() - 4
                            local circy = wy + cy + min_height / 2 - imgui.GetScrollY()                            
                            
                            if imgui.IsItemClicked(0) then
                                self.selected_keyframe = j
                                self.keyframe_drag = true
                                kf_selected = true
                            elseif imgui.IsItemClicked("ImGuiMouseButton_Right") then
                                -- delete keyframe
                                local cmd = model:create_command("Delete keyframe")
                                local kf = j
                                local index = i
                                
                                cmd:add_do_func(function()
                                    animation:remove_keyframe(index, kf)
                                    if self.selected_keyframe == kf then
                                        self.selected_keyframe = nil    
                                    end
                                end)
                                
                                local old_t = animation:get_keyframe_time(index, kf)
                                
                                if track_type == "func" then
                                    local ofunc = animation:function_track_get_key_func_name(index, kf)
                                    local oarg = animation:function_track_get_key_args(index, kf)
                                    
                                    
                                    cmd:add_undo_func(function()
                                        animation:function_track_add_key(index, old_t, ofunc, oarg)                                    
                                    end)
                                    
                                elseif track_type == "var" then
                                    local old_v = animation:variable_track_get_key_value(index, kf)
                                    local old_l = animation:variable_track_get_key_lerp(index, kf)
                                    cmd:add_undo_func(function()
                                        animation:variable_track_add_key(index, old_t, old_v, old_l)
                                    end)
                                end
                                
                                model:commit_command(cmd)
                                j = j - 1
                                goto KEY_CONTINUE
                                
                            end

                            if imgui.IsItemHovered() and not self.keyframe_drag then
                                imgui.BeginTooltip()
                                if track_type == "func" then
                                    local func_name = animation:function_track_get_key_func_name(i, j)
                                    imgui.Text(("%s(...)"):format(func_name))
                                elseif track_type == "var" then
                                    local val = animation:variable_track_get_key_value(i, j)
                                    imgui.Text(tostring(val))
                                end
                                imgui.EndTooltip()
                            end
                            

                           
                            if kf_selected and self.keyframe_drag then
                                
                                self.keyframe_drag_time = math.max(mx_time, 0)   
                                circx = wx + cx + self.keyframe_drag_time * PIXELS_PER_SECOND * zoom - imgui.GetScrollX() - 4
                            end
                            
                            imgui.AddCircleFilled("window", circx, circy, 7, 0x66FA9642)
                                
                            if kf_selected then
                                imgui.AddCircleFilled("window", circx, circy, 5, 0xFFFA9642)
                            end
                            
                            ::KEY_CONTINUE::
                            
                            j = j + 1
                        end
                    end

                    ::CONTINUE::

                    i = i + 1
                end

                imgui.EndTable()
                imgui.PopStyleColor(col_pop)
            end

            imgui.PopStyleVar(2)

            imgui.EndChild()
        end


    end

    imgui.End()

    self:_draw_new_track_modal()
end

return AnimationPlugin