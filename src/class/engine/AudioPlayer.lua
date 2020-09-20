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

local AudioSource = require("class.engine.resource.AudioSource")

local Node2d = require("class.engine.Node2d")
local AudioPlayer = Node2d:subclass("AudioPlayer")
AudioPlayer.static.icon = IconFont and IconFont.MUSIC

AudioPlayer:export_var("source", "resource", {resource_type=AudioSource})
AudioPlayer:export_var("autoplay", "bool", {default = false} )
AudioPlayer:export_var("volume", "float", {default = 0.5} )
AudioPlayer:export_var("loop", "bool", {default = false})

function AudioPlayer:initialize()
    Node2d.initialize(self)
    self.source = nil
    self.autoplay = false
    self.loop = false
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
