
local AudioSource = require("class.engine.resource.AudioSource")

local Node2d = require("class.engine.Node2d")
local AudioPlayer = Node2d:subclass("AudioPlayer")
AudioPlayer.static.icon = IconFont and IconFont.MUSIC

AudioPlayer:export_var("source", "resource", {resource_type=AudioSource})
AudioPlayer:export_var("autoplay", "bool")
AudioPlayer:export_var("volume", "float")
AudioPlayer:export_var("loop", "bool")

AudioPlayer:binser_register()

function AudioPlayer:initialize()
    Node2d.initialize(self)
    self.source = nil
    self.autoplay = false
    self.volume = 0.5
end

function AudioPlayer:set_source(src)
    if src == self.source then return end
    
    self.source = src
    
    if self.love_source_clone then
        self.love_source_clone:stop()
        self.love_source_clone = nil
    end
end

function AudioPlayer:set_volume(vol)
    self.volume = math.clamp(vol, 0, 1)
    
    if self.love_source_clone then
        self.love_source_clone:setVolume(self.volume)
    end
end

function AudioPlayer:set_loop(loop)
    self.loop = loop
    if self.love_source_clone then
        self.love_source_clone:setLooping(self.loop)
    end
end

function AudioPlayer:play()
    if not self.source then return end
    
    if not self.love_source_clone then
        self.love_source_clone = self.source:get_love_source():clone()
    end
    
    self.love_source_clone:setLooping(self.loop)
    self.love_source_clone:setVolume(self.volume)
    self.love_source_clone:play()
end

function AudioPlayer:enter_tree()
    if self.autoplay then
        self:play()
    end
end

function AudioPlayer:exit_tree()
    if self.love_source_clone then
        self.love_source_clone:stop()
    end
end




return AudioPlayer
