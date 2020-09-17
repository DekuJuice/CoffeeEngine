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