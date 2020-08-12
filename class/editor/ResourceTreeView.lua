local Node = require("class.engine.Node")
local ResourceTreeView = Node:subclass("ResourceTreeView")
ResourceTreeView.static.dontlist = true
ResourceTreeView:define_signal("resource_selected")

local _pop_sentinel = {}

function ResourceTreeView:initialize()
    Node.initialize(self)
    self.is_open = true
    self.has_focus = false
    self.selection = ""
end

function ResourceTreeView:parented(parent)
    parent:add_action("Show Resource Tree", function()
        self.is_open = not self.is_open
    end)
end

function ResourceTreeView:draw()
    local editor = self:get_parent()

    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("View") then
            editor:_menu_item("Show Resource Tree", self.is_open)
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
    local should_draw, open = imgui.Begin("Resource Tree", self.is_open, flags)
    self.is_open = open
    
    if should_draw then
        
        if imgui.Button(("%s Create Resource"):format(IconFont.FILE)) then
        end
        
        imgui.BeginChild("##Tree Area", -1, -1, true, {"ImGuiWindowFlags_HorizontalScrollbar"} )
        
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
                        self:emit_signal("resource_selected", resource.get_resource(self.selection))
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
                                if ext ~= settings.get_setting("backup_ext") and ext ~= settings.get_setting("import_ext") then
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
        
        if imgui.IsWindowFocused({"ImGuiFocusedFlags_RootAndChildWindows"}) then
            editor:get_node("Inspector"):set_auto_inspect_nodes(false)        
        end
    end
    imgui.End()
end





return ResourceTreeView