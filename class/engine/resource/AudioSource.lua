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