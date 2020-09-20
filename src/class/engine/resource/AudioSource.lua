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

local MAX_STATIC_SIZE = 512 * 1024 -- Size in bytes, any audio files bigger than this should be streamed in instead of loaded statically

local ImportedResource = require("class.engine.resource.ImportedResource")
local AudioSource = ImportedResource:subclass("AudioSource")
AudioSource.static.extensions = {"ogg", "wav", "mp3"}

function AudioSource:initialize()
    ImportedResource.initialize(self)
end

function AudioSource:initialize_from_filedata(fd)
    local size = fd:getSize()
    self.source = love.audio.newSource(fd, size > MAX_STATIC_SIZE and "stream" or "static")
end

function AudioSource:get_love_source()
    return self.source
end


return AudioSource