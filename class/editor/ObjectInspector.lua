local ResourceTreeView = require("class.editor.ResourceTreeView")

local Object = require("class.engine.Object")
local ObjectInspector = Object:subclass("ObjectInspector")
ObjectInspector:define_get_set("window_name")
ObjectInspector:define_get_set("bottom_height")
ObjectInspector:define_get_set("open")

function ObjectInspector:initialize()
    Object.initialize(self)
    self.open = true
    self.resource_preview_canvas = love.graphics.newCanvas(128, 128)
    self.resource_selector = ResourceTreeView()
    self.resource_selector:set_window_name("Choose a resource")
    self.resource_selector:set_modal(true)
    self.resource_selector:set_open(false)
    self.resource_selector_selection = {}
    
    self.bottom_height = 0
end

function ObjectInspector:_draw_property_widget(obj, ep)
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
    elseif ptype == "array" then
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
            self.resource_selector:set_open(true)
            if editor_hints.resource_type then
                self.resource_selector:set_ext_filter(editor_hints.resource_type.extensions) 
            end
        end
        
        imgui.SameLine()
        imgui.Text("Path:")
        imgui.SameLine()
        
        if val then
            imgui.Text(val:get_filepath())
        else
            imgui.Text("No Resource")
        end
        
        if self.resource_selector:begin_window() then
            self.resource_selector:display(self.resource_selector_selection)            
            self.resource_selector_selection = self.resource_selector:get_selection()
            
            if self.resource_selector:is_selection_changed() then
                local path = self.resource_selector_selection[1]
                new_val = get_resource(path)
                finalized = true         
                
                self.resource_selector:set_ext_filter(nil)
            end
        end
        self.resource_selector:end_window()
        
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
        self.changed_var = name
        self.new_val = new_val
        self.finalized = finalized
    end
end

function ObjectInspector:begin_window(flags)
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

function ObjectInspector:end_window()
    self.changed_var = nil
    self.new_val = nil
    self.finalized = nil
    imgui.End()
end

function ObjectInspector:display(object)

    if object then
        local flags = {
            "ImGuiTableFlags_Resizable",
            "ImGuiTableFlags_RowBg",
        }
        
        if imgui.BeginTable("##Properties", 2, flags, 0, -self.bottom_height - 1)then
            local class = object.class
            while class do
                local static = rawget(class, "static")
                if static then
                    local exported = rawget(static, "exported_vars")
                    if exported then
                        for _,ep in ipairs(exported) do
                            imgui.TableNextRow()
                            self:_draw_property_widget(object, ep)
                        end
                    end
                end
                class = class.super
            end
            
            imgui.EndTable()
        end
    end    
end

function ObjectInspector:is_var_changed()
    return self.changed_var ~= nil
end

function ObjectInspector:is_change_finalized()
    return self.finalized
end

function ObjectInspector:get_changed_var_name()
    return self.changed_var
end

function ObjectInspector:get_changed_var_value()
    return self.new_val
end


return ObjectInspector