local Object = require("class.engine.Object")

local ImguiObjectInspector = Object:subclass("ImguiObjectInspector")
ImguiObjectInspector:define_get_set("window_name")
ImguiObjectInspector:define_get_set("bottom_height")

function ImguiObjectInspector:initialize()
    Object.initialize(self)
    self.open = true
    self.resource_preview_canvas = love.graphics.newCanvas(128, 128)
    self.bottom_height = 0
end

function ImguiObjectInspector:open()
    self.open = true
end

function ImguiObjectInspector:close()
    self.open = false
end

function ImguiObjectInspector:_draw_resource_preview(resource)
    
end

function ImguiObjectInspector:_draw_property_widget(obj, ep)
    local ptype = ep.type
    
    -- "data" type is any type that needs its own specialized editor, so we don't show it here
    if ptype == "data" then
        return
    end
    
    local name = ep.name
    local editor_hints = ep.editor_hints
    local display_name = editor_hints.display_name or name
    
    local getter = ("get_%s"):format(name)
    local setter = ("set_%s"):format(name)
        
    local val = obj[getter](obj)
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
        smin = smin or -math.huge
        smax = smax or math.huge
        
        changed, new_val = imgui.DragFloat("##FloatSlider", val, velo, smin, smax)
    elseif ptype == "int" then
        local velo, smin, smax =
            editor_hints.speed, editor_hints.min, editor_hints.max
        
        velo = velo or 0.1
        smin = smin or -math.huge
        smax = smax or math.huge
        
        changed, new_val = imgui.DragInt("##IntSlider", val, velo, smin, smax)
            
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
        
        --new_val = self:imgui_resource_selector_modal("Resource Selector")
        --changed = new_val ~= nil
    elseif ptype == "enum" then
        if imgui.BeginCombo("##", val) then
            
            for _,enum in ipairs(editor_hints.enum) do
                local is_selected = enum == val
                
                if imgui.Selectable(enum, is_selected) then
                    new_val = val
                    changed = true
                end
                
                imgui.SetItemDefaultFocus()
                
            end
        
        
            imgui.EndCombo()
        end
    end 
    
    imgui.PopID()
    imgui.NextColumn()
end

function ImguiObjectInspector:begin_window(flags)
    if not self.open then return end
    
    local window_flags = {}
    if flags then
        for _,f in ipairs(flags) do
            table.insert(window_flags, v)
        end
    end
    
    imgui.SetNextWindowSize(400, 400, {"ImGuiCond_FirstUseEver"})
    
    local should_draw, window_open = imgui.Begin(self.window_name, self.open, window_flags)
    self.open = window_open
    
    return should_draw
end

function ImguiObjectInspector:end_window()
    imgui.End()
end

function ImguiObjectInspector:display(object)

    imgui.BeginChild("Selection Area", 0, -self.bottom_height, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )

    if object then
        
        imgui.Columns(2)
        
        local class = object.class
        while class do
            local static = rawget(class, "static")
            if static then
                local exported = rawget(static, "exported_vars")
                if exported then
                    imgui.Separator()
                    for _,ep in ipairs(exported) do
                        self:_draw_property_widget(object, ep)
                    end
                end
            end
            class = class.super
        end
        
        imgui.Columns(1)
        imgui.Separator()
        
    else
        imgui.Text("Nothing Selected")
    end
end

return ImguiObjectInspector