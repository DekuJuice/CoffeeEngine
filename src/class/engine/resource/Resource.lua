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

-- Superclass for all Resource objects
local binser = require("enginelib.binser")

local Object = require("class.engine.Object")
local Resource = Object:subclass("Resource")
Resource.static.noinstance = true
Resource.static.extensions = {}
Resource:define_get_set("filepath")
Resource:define_get_set("has_unsaved_changes")

local _gc_debug_info = function(proxy)
    local mt = getmetatable(proxy)
    log.info(("Garbage collected %s, path %s"):format(tostring(mt._res), mt._res:get_filepath()))
end

function Resource:initialize()
    Object.initialize(self)
    self.has_unsaved_changes = true
    
    if settings.get_setting("is_debug") and _VERSION == "Lua 5.1" then
        self.proxy = newproxy(true)
        local mt = getmetatable(self.proxy)
        mt.__gc = _gc_debug_info
        mt._res = self
    end
    
end

function Resource:_serialize()
    return self.filepath
end

function Resource.static._deserialize(filepath)
    return resource.get_resource(filepath)
end

function Resource.static.subclassed(self, class)
    binser.register(class.__instanceDict, class.name, class._serialize, class._deserialize)
end

return Resource