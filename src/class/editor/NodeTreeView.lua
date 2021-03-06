--[[

MIT License

Copyright (c) 2020 DekuJuice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

local Node = require("class.engine.Node")
local NodeTreeView = Node:subclass("NodeTreeView")
NodeTreeView.static.dontlist = true
NodeTreeView:define_signal("node_selected")

local _pop_sentinel = {}

function NodeTreeView:initialize()
    Node.initialize(self)
    self.is_open = true
end

function NodeTreeView:parented(parent)
    parent:add_action("Show Node Tree", function()
        self.is_open = not self.is_open
    end)
end

function NodeTreeView:draw()
    local editor = self:get_parent()

    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("View") then
            editor:_menu_item("Show Node Tree", self.is_open)
            imgui.EndMenu()
        end
        imgui.EndMainMenuBar()
    end

    if not self.is_open then
        return
    end

    local model = editor:get_active_scene_model()
    
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})

    local flags = {}
    local should_draw, open = imgui.Begin("Node Tree", self.is_open, flags)
    self.is_open = open
    
    if should_draw then
    
        if imgui.Button(("%s Add Node"):format(IconFont.PLUS)) then
            editor:do_action("Add Node")
        end
        
        imgui.SameLine()
        
        if imgui.Button(("%s Instance Scene"):format(IconFont.LINK)) then
            editor:do_action("Instance Scene")
        end
                
        imgui.BeginChild("##Tree Area", -1, -1, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )
        
        if imgui.BeginTable("##Table", 2, {"ImGuiTableFlags_RowBg", "ImGuiTableFlags_BordersVInner"}) then
            local cw, ch = imgui.GetContentRegionAvail()
            
            imgui.TableSetupColumn("", nil, cw - 30);
            imgui.TableSetupColumn("", nil, 30);
            local root = model:get_tree():get_current_scene()
            
            local stack = { root }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == _pop_sentinel then
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
                    
                    for _, s in ipairs(model:get_selected_nodes()) do
                        if top == s then
                            table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                        end
                        
                        if top:is_parent_of(s) then 
                            imgui.SetNextItemOpen(true)
                        end
                    end
                    imgui.TableSetColumnIndex(0)
                    
                    local dname = top:get_name()
                    if top.class.icon then
                        dname = ("%s %s"):format(top.class.icon, dname)
                    end
                    
                    local open = imgui.TreeNodeEx(dname, tree_node_flags)
                                        
                    if imgui.BeginPopupContextItem("NodeContextMenu") then
                        model:set_selected_nodes({top})
                        
                        if top ~= root then
                        
                            editor:_menu_item("Move Node Up")
                            editor:_menu_item("Move Node Down")
                            editor:_menu_item("Duplicate Node")
                            editor:_menu_item("Reparent Node")
                        
                        end
                        
                        editor:_menu_item("Delete Node")
                        
                        imgui.EndPopup()
                    end
                    
                    
                    if imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() then
                        model:set_selected_nodes({top})
                        self:emit_signal("node_selected", top)
                    end
                    
                    if top:get_filepath() then
                        imgui.SameLine()
                        imgui.Text(("%s"):format(IconFont.LINK))
                    end
                    
                    --[[if top:get_owner() then
                        imgui.SameLine()
                        imgui.Text(top:get_owner():get_name())
                    end]]--
                    
                    if open then
                        table.insert(stack, _pop_sentinel)
                        
                        local children = top:get_children()
                        for i = #children, 1, -1 do
                            local c = children[i]
                            if c:get_owner() == root then     
                                table.insert(stack, c)
                            end
                        end
                    end
                    
                    imgui.TableSetColumnIndex(1)
                    
                    local visible = top:get_visible()
                    local visible_in_tree = top:is_visible_in_tree()
                    local b
                    if visible then 
                        b = IconFont.EYE 
                    else
                        b = IconFont.EYE_OFF
                    end
                    
                    if not visible_in_tree then
                        imgui.PushStyleColor("ImGuiCol_Button", 0.260, 0.590, 0.980, 0.200)
                        imgui.PushStyleColor("ImGuiCol_ButtonHovered", 0.260, 0.590, 0.980, 0.400)
                        imgui.PushStyleColor("ImGuiCol_ButtonActive", 0.060, 0.530, 0.980, 0.200)
                    end
                    
                    if imgui.Button(b) then
                        local cmd = model:create_command("Toggle Visibility")
                        local func = function()
                            top:set_visible(not top:get_visible())
                        end
                        cmd:add_do_func(func)
                        cmd:add_undo_func(func)
                        model:commit_command(cmd)
                        
                    end
                    
                    if not visible_in_tree then
                        imgui.PopStyleColor(3)
                    end
                    
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()
        if imgui.IsWindowFocused("ImGuiFocusedFlags_RootAndChildWindows") then
            editor:get_node("Inspector"):set_auto_inspect_nodes(true)
        end

    end
    imgui.End()
end



return NodeTreeView