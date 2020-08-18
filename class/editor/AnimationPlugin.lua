local AnimationPlayer = require("class.engine.AnimationPlayer")
local Animation = require("class.engine.resource.Animation")

local Node = require("class.engine.Node")
local AnimationPlugin = Node:subclass("AnimationPlugin")
AnimationPlugin.static.dontlist = true

function AnimationPlugin:initialize()
    Node.initialize(self)
end

function AnimationPlugin:enter_tree()
    local scene = self:get_parent():get_active_scene()
    local ap = AnimationPlayer()
    
    local n2 = require("class.engine.Node2d")()
    
end

function AnimationPlugin:draw()
   
    local editor = self:get_parent()
    local model = editor:get_active_scene()
    local animp = model:get_selected_nodes()[1]
    if not animp or not animp:isInstanceOf(AnimationPlayer) then return end
    
    
    imgui.SetNextWindowSize(800, 800, "ImGuiCond_FirstUseEver")
    local flags = {}
    
    if imgui.Begin("Animation", nil, flags) then
    
        imgui.Button("New Animation")
        imgui.SameLine()
        imgui.Button("Export Animation")
        imgui.SameLine()
        imgui.Button("Import Animation")
        
        imgui.Separator()
        
        if imgui.Button("Add Track") then
            imgui.OpenPopup("Add Track Popup", "ImGuiPopupFlags_NoOpenOverExistingPopup")
        end
        
        imgui.SameLine()
        imgui.Button("Insert Keyframe")
        
        if imgui.BeginPopup("Add Track Popup") then
            if imgui.Selectable("Variable Track") then
                
            end
            
            if imgui.Selectable("Function Track") then
            
            end
            
            imgui.EndPopup()
        end
        
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
            
            if imgui.BeginTable("TimelineTable", 2, table_flags) then
                imgui.TableSetupColumn("Tracks", {"ImGuiTableColumnFlags_WidthFixed"})
                imgui.TableSetupColumn("Keyframes")
                imgui.TableAutoHeaders()
                
                for i = 1, 10 do
                    local min_height = imgui.GetFontSize() * 2
                    imgui.TableNextRow(0, min_height)
                    imgui.TableSetColumnIndex(0)
                    imgui.Selectable("Foo")
                    imgui.TableSetColumnIndex(1)
                    imgui.Selectable("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
                end
                
                imgui.EndTable()
            end
            
        
            imgui.EndChild()
        end
        
    
    end
    
    imgui.End()
end



return AnimationPlugin