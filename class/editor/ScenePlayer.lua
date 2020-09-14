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
    
    -- Create autoloads
    for _, path in ipairs(settings.get_setting("autoload_scenes")) do
        local as = resource.get_resource( path )
        if not as then
            log.error(("Failed to get autoload %s"):format(path))
            
            
            self:_cleanup()
            return
        end
        
        local ok, res = pcall(as.instance, as)
        if not ok then
            log.error(res)
            self:_cleanup()
            return
        end
        
        self.player_tree:get_root():add_child( res )        
    end
    
    
    local ok, msg  = pcall(self.player_tree.set_current_scene, self.player_tree, instance)
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