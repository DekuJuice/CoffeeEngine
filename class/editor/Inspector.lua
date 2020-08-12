local Node = require("class.engine.Node")
local ImportedResource = require("class.engine.resource.ImportedResource")

local Inspector = Node:subclass("Inspector")
Inspector.static.dontlist = true
Inspector:define_get_set("inspected_object")
Inspector:define_get_set("auto_inspect_nodes")

function Inspector:initialize()
    Node.initialize(self)
    self.is_open = true
    self.object = nil
    self.auto_inspect_nodes = true
end

function Inspector:parented(parent)
    parent:add_action("Show Inspector", function()
            self.is_open = not self.is_open
        end)
end

function Inspector:_draw_property_widget(obj, ep)
    local ptype = ep.type

    -- "data" type is any type that needs its own specialized editor, so we don't show it here
    if ptype == "data" then
        return
    end

    local name = ep.name
    local editor_hints = ep.editor_hints
    local display_name = editor_hints.display_name or name
    local filter = editor_hints.filter

    local getter = ("get_%s"):format(name)
    local setter = ("set_%s"):format(name)

    local val = obj[getter](obj)
    local new_val = val
    local changed = false
    local finalized = false

    imgui.PushID(name)
    imgui.TableSetColumnIndex(0)
    imgui.AlignTextToFramePadding()
    imgui.Text(display_name)
    imgui.TableSetColumnIndex(1)

    if ptype == "string" then
        imgui.PushItemWidth(-1)
        changed, new_val = imgui.InputText("##StringInput", val, 64)
        finalized = imgui.IsItemDeactivatedAfterEdit()

    elseif ptype == "float" then
        local velo, smin, smax = 
        editor_hints.speed, editor_hints.min, editor_hints.max
        velo = velo or 0.01
        smin = smin or -math.huge
        smax = smax or math.huge
        imgui.PushItemWidth(-1)

        changed, new_val = imgui.DragFloat("##FloatSlider", val, velo, smin, smax)
        finalized = imgui.IsItemDeactivatedAfterEdit()

    elseif ptype == "int" then
        local velo, smin, smax =
        editor_hints.speed, editor_hints.min, editor_hints.max

        velo = velo or 0.1
        smin = smin or -math.huge
        smax = smax or math.huge
        imgui.PushItemWidth(-1)
        changed, new_val = imgui.DragInt("##IntSlider", val, velo, smin, smax)
        finalized = imgui.IsItemDeactivatedAfterEdit()

    elseif ptype == "vec2" then
        local velo, smin, smax = 
        editor_hints.speed, editor_hints.min, editor_hints.max

        velo = velo or 1
        smin = smin or 0
        smax = smax or 100
        imgui.PushItemWidth(-1)
        local c, nx, ny = imgui.DragInt2("##Vec2Slider", val.x, val.y, velo, smin, smax)
        finalized = imgui.IsItemDeactivatedAfterEdit()
        new_val = vec2(nx, ny)            
        changed = c
    elseif ptype == "color" then
        local c, r, g, b, a = imgui.ColorEdit4("##ColorEdit4f", val[1], val[2], val[3], val[4], {"ImGuiColorEditFlags_Float"})
        finalized = imgui.IsItemDeactivatedAfterEdit()
        val[1] = r
        val[2] = g
        val[3] = b
        val[4] = a

        changed = c

    elseif ptype == "bool" then
        changed, new_val = imgui.Checkbox("##Checkbox", val)
        finalized = changed
    elseif ptype == "bitmask" then

        if imgui.CollapsingHeader("Bitmask") then
            local bits = editor_hints.bits or 31
            for i = 1, bits do
                local b = 2^(i - 1)
                local checked = bit.band(b, val) == b
                if imgui.Checkbox(("%d##bit%d"):format(i-1,i), checked) then

                    new_val = bit.bxor(val, b)

                    finalized = true
                end
            end

        end
    elseif ptype == "num_array" then
        if imgui.CollapsingHeader("Array") then

            local new = table.copy(val)

            if imgui.Button(IconFont.MINUS) then
                if table.remove(new) ~= nil then
                    changed = true
                    finalized = true
                end
            end

            imgui.SameLine()

            if imgui.Button(IconFont.PLUS) then
                table.insert(new, 0)
                changed = true
                finalized = true
            end

            imgui.SameLine()
            local n = #new
            imgui.Text(("Count: %d"):format(n))

            for i = 1, n do
                local v = new[i]

                local fc, nv = imgui.DragInt(("##%d"):format(i), v)

                new[i] = nv

                changed = fc or changed
                finalized = imgui.IsItemDeactivatedAfterEdit() or finalized

            end

            if finalized or changed then
                new_val = new
            end
        end

    elseif ptype == "resource" then
        if imgui.Button("Select") then

        end

        imgui.SameLine()
        imgui.Text("Path:")
        imgui.SameLine()

        if val then
            imgui.Text(val:get_filepath())
        else
            imgui.Text("No Resource")
        end

    elseif ptype == "enum" then
        imgui.PushItemWidth(-1)
        if imgui.BeginCombo("##", val) then

            for _,enum in ipairs(editor_hints.enum) do
                local is_selected = enum == val

                if imgui.Selectable(enum, is_selected) then
                    new_val = enum
                    finalized = true
                end

                imgui.SetItemDefaultFocus()

            end
            imgui.EndCombo()
        end
    end 

    imgui.PopID()

    if filter and not (filter(obj, new_val))  then
        new_val = val
    end

    if new_val ~= val or finalized then
    end
end

function Inspector:_draw_node_inspector()
    local node = self.inspected_object

    imgui.Text( ("%s: %s"):format(node.class.name, node:get_name()))
    imgui.Text( ("Path: %s"):format(node:get_absolute_path()))
    imgui.Separator()
    if imgui.CollapsingHeader("Tags") then

        local changed, nv = imgui.InputText("Add New Tag", "", 128)
        local finalized = imgui.IsItemDeactivatedAfterEdit()

        if finalized and nv ~= "" then
        end

        local tags = {}
        for k,v in pairs(node:get_tags()) do
            table.insert(tags, k)
        end
        table.sort(tags)

        for _,t in ipairs(tags) do
            imgui.Text(t)
            imgui.SameLine()
            if imgui.Button(IconFont.MINUS) then
            end
        end                  
    end
    imgui.Separator()
end

function Inspector:_draw_resource_inspector()
    local resource = self.inspected_object

    local rtype = resource.class.name
    local path = resource:get_filepath() or ("Unsaved Resource")

    imgui.Text( ("Resource: %s"):format(rtype))

    if resource:get_has_unsaved_changes() then
        imgui.SameLine()
        imgui.TextColored( 1, 1, 0, 1,  ("(%s Unsaved changes!)"):format(IconFont.ALERT_TRIANGLE))
    end

    if not resource:isInstanceOf(ImportedResource) then
        imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
        imgui.Text("Path: ")
        imgui.SameLine()
        imgui.SetCursorPosY(imgui.GetCursorPosY() - 3)
        local changed, fp = imgui.InputTextWithHint("##PathInput", "Enter Resource Path", resource:get_filepath() or "", 128) 
        local finalized = imgui.IsItemDeactivatedAfterEdit()
        if finalized then
        
        end

    else
        imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
        imgui.Text( ("Path: %s"):format(path) )
    end
    imgui.Separator()
    if imgui.Button(("%s Save changes"):format(IconFont.SAVE)) then 
        if resource:get_filepath() then
            
        end
    end
    imgui.Separator()

end

function Inspector:draw()
    local editor = self:get_parent()

    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("View") then
            editor:_menu_item("Show Inspector", self.is_open)
            imgui.EndMenu()
        end
        imgui.EndMainMenuBar()
    end

    if not self.is_open then
        return
    end

    local model = editor:get_active_scene()

    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})

    local flags = {}
    local should_draw, open = imgui.Begin("Inspector", self.is_open, flags)
    self.is_open = open

    if should_draw then
        if self.auto_inspect_nodes then
            self.inspected_object = editor:get_active_scene():get_selected_nodes()[1]
        end

        if self.inspected_object then

            if self.inspected_object:isInstanceOf(Node) then
                self:_draw_node_inspector()
            else
                self:_draw_resource_inspector()
            end

            local table_flags = {
                "ImGuiTableFlags_Resizable",
                "ImGuiTableFlags_RowBg",
            }

            if imgui.BeginTable("##Properties", 2, table_flags, 0, 0) then
                local class = self.inspected_object.class
                while class do
                    local static = rawget(class, "static")
                    if static then
                        local exported = rawget(static, "exported_vars")
                        if exported then
                            for _,ep in ipairs(exported) do
                                imgui.TableNextRow()
                                self:_draw_property_widget(self.inspected_object, ep)
                            end
                        end
                    end
                    class = class.super
                end
            end
            imgui.EndTable()
        else
            imgui.Text("Nothing selected")
        end

    end

    imgui.End()
end


return Inspector