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

local scaledraw = require("enginelib.scaledraw")

local SceneTree = require("class.engine.SceneTree")
local Node = require("class.engine.Node")
local ScenePlayer = Node:subclass("ScenePlayer")
ScenePlayer.static.dontlist = true

function ScenePlayer:initialize()
    Node.initialize(self)
    
    self.open = false
    self.player_tree = nil
end

function ScenePlayer:parented(parent)
    parent:add_action("Play Scene", function()
        local scene = parent:get_active_scene_model()
        self:play(scene)    
    end, "f5")
end

function ScenePlayer:_cleanup()
    self.open = false
    self.player_tree = nil
    -- an error may have occured, and nodes can't be safely notified,
    -- need to make sure playing audio sources are stopped
    love.audio.stop()
end

function ScenePlayer:play(scene)

    if not scene:get_tree():get_current_scene() then return end
    
    local packed = scene:pack()
    local instance = packed:instance()
    
    self.open = true
    
    self.player_tree = SceneTree()
    self.player_tree:set_scale_mode( settings.get_setting("upscale_mode") )
    self.player_tree:get_viewport():set_background_color({0,0,0,1})
    self.player_tree:get_viewport():set_resolution(settings.get_setting("game_width"), settings.get_setting("game_height"))
    self.player_tree:set_debug_draw_physics( scene:get_tree():get_debug_draw_physics() )
    
    local ok, msg = pcall(self.player_tree.create_autoload_scenes, self.player_tree)
    if not ok then
        log.error(msg)
        self:_cleanup()
        return
    end
    
    ok, msg  = pcall(self.player_tree.set_current_scene, self.player_tree, instance)
    if not ok then
        log.error(msg)
        self:_cleanup()
    end
    
end

function ScenePlayer:update(dt)
    if self.open then
        local ok,err = pcall(self.player_tree.update, self.player_tree, dt)
        if not ok then
            log.error(err)
            self:_cleanup()
        end
    end
end

function ScenePlayer:draw_toolbar()
    if imgui.Button(("%s Play Scene"):format(IconFont.PLAY) ) then
        self:get_parent():do_action("Play Scene")
    end
end

function ScenePlayer:draw()
    
    if not self.open then return end
        
    if self.open then
        imgui.OpenPopup("Game", "ImGuiPopupFlags_NoOpenOverExistingPopup")
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
        
        local ok, err = pcall( self.player_tree.render, self.player_tree)
        if not ok then
            log.error(err)
            imgui.EndPopup()
            self:_cleanup()
            return
        end
        
        local sx, sy, ox, oy = scaledraw.get_transform(  self.player_tree:get_scale_mode() , iw, ih, 0, 0, rw, rh)
        
        imgui.SetCursorPos(cx + ox, cy + oy)
        imgui.Image(self.player_tree:get_viewport():get_canvas(), iw * sx, ih * sy)
        
        imgui.EndPopup()
    end

    self.open = window_open
    if not self.open then   
        self:_cleanup()
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