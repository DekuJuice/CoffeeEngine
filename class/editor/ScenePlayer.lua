local scaledraw = require("enginelib.scaledraw")

local SceneTree = require("class.engine.SceneTree")
local Node = require("class.engine.Node")
local ScenePlayer = Node:subclass("ScenePlayer")
ScenePlayer.static.dontlist = true

function ScenePlayer:initialize()
    Node.initialize(self)
    
    self.open = false
    self.player_tree = SceneTree()
    self.player_tree:get_viewport():set_background_color({0,0,0,1})
end

function ScenePlayer:play(packed_scene)

    self.open = true
    local root = packed_scene:instance()
    
    self.player_tree:get_viewport():set_resolution(416, 240)
    self.player_tree:set_root(root)
    self.player_tree:set_debug_draw_physics(true)
end

function ScenePlayer:update(dt)
    if self.open then
        self.player_tree:update(dt)
    end
end

function ScenePlayer:draw()
    
    if not self.open then return end
        
    if self.open then
        imgui.OpenPopup("Game")
    end
        
    local window_flags = {}
    imgui.SetNextWindowSize(800, 600, {"ImGuiCond_FirstUseEver"})
    local should_draw, window_open = imgui.BeginPopupModal("Game", self.open, window_flags)

    if should_draw then
        imgui.CaptureKeyboardFromApp(false)
        imgui.CaptureMouseFromApp(false)
        local rw, rh = imgui.GetContentRegionAvail()
        local cx, cy = imgui.GetCursorPos()
        local viewport = self.player_tree:get_viewport()
        local iw, ih = viewport:get_resolution()
        
        
        self.player_tree:render()
        
        local sx, sy, ox, oy = scaledraw.get_transform("perfect", iw, ih, 0, 0, rw, rh)
        
        imgui.SetCursorPos(cx + ox, cy + oy)
        imgui.Image(self.player_tree:get_viewport():get_canvas(), iw * sx, ih * sy)
        
        imgui.EndPopup()
    end

    self.open = window_open
    if not self.open then   
        self.player_tree:set_root(nil)
    end


end

for _,callback in ipairs({
    "mousepressed",
    "mousereleased",
    "mousemoved",
    "textinput",
    "keypressed",
    "keyreleased",
    "joystickpressed",
    "joystickreleased",
    "joystickaxis",
    "joystickhat",
    "wheelmoved"
}) do

    ScenePlayer[callback] = function(self, ...)
        if self.open then
            self.player_tree[callback](self.player_tree, ...)            
            return true
        end
        return false
    end

end


return ScenePlayer