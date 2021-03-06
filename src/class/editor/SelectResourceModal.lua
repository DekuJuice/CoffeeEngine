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
local SelectResourceModal = Node:subclass("SelectResourceModal")
SelectResourceModal.static.dontlist = true
SelectResourceModal:define_signal("resource_selected")

local _pop_sentinel = {}

function SelectResourceModal:initialize()
    Node.initialize(self)
    self.is_open = false
    self.selection = ""
end

function SelectResourceModal:open(ext_filter)
    self.is_open = true
    self.ext_filter = ext_filter or {}
end

function SelectResourceModal:draw()
    if not self.is_open then
        return
    end
    
    if self.is_open then
        imgui.OpenPopup("Select Resource", "ImGuiPopupFlags_NoOpenOverExistingPopup")
    end

    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})

    local flags = {}
    local should_draw, open = imgui.BeginPopupModal("Select Resource", self.is_open, flags)
    self.is_open = open
    
    local res
    local finalized = false

    if should_draw then
        
        imgui.BeginChild("##Tree Area", -1, -32, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )
        
        if imgui.BeginTable("##Table", 1, {"ImGuiTableFlags_RowBg"}) then

            local stack = {  settings.get_setting("asset_dir") }
            while #stack > 0 do
                local top = table.remove(stack)
                if top == _pop_sentinel then
                    imgui.TreePop()
                else
                    imgui.TableNextRow()
                    
                    local is_leaf = love.filesystem.getInfo(top, "file") ~= nil
                    
                    local tree_node_flags = {
                        "ImGuiTreeNodeFlags_SpanFullWidth",
                        "ImGuiTreeNodeFlags_DefaultOpen",
                    }
                    
                    if is_leaf then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Leaf")
                    end
                    
                    if top == self.selection then
                        table.insert(tree_node_flags, "ImGuiTreeNodeFlags_Selected")
                    end
                        
                    if self.selection and top:find(self.selection) == 0 then 
                        imgui.SetNextItemOpen(true)
                    end
                        
                    local open = imgui.TreeNodeEx(top:match("[^/]+$"), tree_node_flags)
                    
                    if imgui.IsItemClicked(0) and not imgui.IsItemToggledOpen() and is_leaf then
                        self.selection = top
                        if imgui.IsMouseDoubleClicked(0) then
                            res = resource.get_resource(self.selection)
                            finalized = true
                        end
                    end
                    
                    if open then
                        table.insert(stack, _pop_sentinel)
                        
                        local di = love.filesystem.getDirectoryItems(top)
                        for i = #di, 1, -1 do
                        
                            local cp = ("%s/%s"):format(top, di[i])
                            if love.filesystem.getInfo(cp, "directory") then
                                table.insert(stack, cp)
                            else
                                local ext = di[i]:match("[^.]+$")
                                if ext ~= settings.get_setting("backup_ext") and ext ~= settings.get_setting("import_ext") 
                                and table.find(self.ext_filter, ext) then
                                
                                    table.insert(stack, cp)
                                end
                                
                            end
                        end
                    end
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()
        
        if (imgui.Button("Confirm", 120, 0) or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Enter")))
        and self.selection then            
            res = resource.get_resource(self.selection)
            finalized = true
        end
        
        imgui.SameLine()
        
        if imgui.Button("Cancel", 120, 0) 
        or imgui.IsKeyPressed(imgui.GetKeyIndex("ImGuiKey_Escape")) then
            imgui.CloseCurrentPopup()
            self.is_open = false
        end
        
        if finalized then
            self.is_open = false
            imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
    end
    
    return res, finalized
end


return SelectResourceModal