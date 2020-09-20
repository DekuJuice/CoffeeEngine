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

local class = require("enginelib.middleclass")
local CircularBuffer = class("CircularBuffer")

function CircularBuffer:initialize(length)
    self.items = {}
    self.oldest = 1
    self.length = length or 500
end

function CircularBuffer:get_length()
    return self.length
end

function CircularBuffer:get_count()
    return #self.items
end

function CircularBuffer:is_full()
    return #self.items == self.length
end

function CircularBuffer:push(v)
    if self:is_full() then
        self.items[self.oldest] = v
        self.oldest = (self.oldest % self.length) + 1    
    else
        table.insert(self.items, v)    
    end
end

-- negative indices are oldest items
-- positive indices are newest items
function CircularBuffer:at(i)
    local n = #self.items
    if i == 0 or math.abs(i) > n then
        return nil
    end
    
    if i >= 1 then
        return self.items[ (self.oldest - i - 1) % n + 1 ]
    elseif i <= -1 then
        return self.items[ (self.oldest - i - 2) % n + 1 ]
    end
end

return CircularBuffer