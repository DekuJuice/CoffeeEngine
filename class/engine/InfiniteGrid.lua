local CHUNK_LENGTH = 16
local CHUNK_TOTAL = CHUNK_LENGTH ^ 2
local CHUNK_COUNTER = CHUNK_TOTAL + 1

local Object = require("class.engine.Object")
local InfiniteGrid = Object:subclass("InfiniteGrid")

InfiniteGrid:export_var("chunks", "data")
InfiniteGrid:export_var("chunk_index_map", "data")

InfiniteGrid:define_get_set("autoremove_chunks")

-- Map data is stored in 16x16 chunks,
-- centered around the TileMap.
-- CHUNK_LENGTH^2 + 1'th index is used to store a counter
-- so we can determine quickly if a chunk is empty
local function chunk_init()
    local chunk = {}
    for i = 1, CHUNK_TOTAL + 1 do
        chunk[i] = 0
    end
    return chunk
end

function InfiniteGrid:initialize()
    Object.initialize(self)
    
    self.chunks = {}
    self.chunk_index_map = {}
    self.autoremove_chunks = true
end

InfiniteGrid:binser_register()

function InfiniteGrid:get_chunk_length()
    return CHUNK_LENGTH
end

-- Return the key for the given chunk position
function InfiniteGrid:get_chunk_key(x, y)
    return ("%d_%d"):format(x, y)
end

function InfiniteGrid:get_chunk_index(key)
    return self.chunk_index_map[key]
end

function InfiniteGrid:set_cell(x, y, v)
    assert(type(v) == "number", "Cell value must be a number")

    -- Determine which chunk the coordinates fall in
    local cx = math.floor(x / CHUNK_LENGTH)
    local cy = math.floor(y / CHUNK_LENGTH)
    
    local chunk
    local key = self:get_chunk_key(cx, cy)
    local chunk_index = self:get_chunk_index(key)
    if chunk_index then
        chunk = self.chunks[chunk_index]
    end
    
    if not chunk then -- No chunk at position, create a new one
        chunk = chunk_init()
        table.insert(self.chunks, chunk)
        chunk_index = #self.chunks
        self.chunk_index_map[ key ] = chunk_index
    end
    
    local tx = x - cx * CHUNK_LENGTH
    local ty = y - cy * CHUNK_LENGTH
    local i = tx + ty * CHUNK_LENGTH + 1
    local old = chunk[i]
    chunk[i] = v
    
    if v ~= 0 and old == 0 then
        chunk[CHUNK_COUNTER] = chunk[CHUNK_COUNTER] + 1
    elseif v == 0 and old ~= 0 then
        chunk[CHUNK_COUNTER] = chunk[CHUNK_COUNTER] - 1
    end
    
    -- Clean up empty chunks
    if chunk[CHUNK_COUNTER] == 0 and self.autoremove_chunks then
        self:_remove_chunk(chunk_index)
    end
end

function InfiniteGrid:get_cell(x, y)
    -- Determine which chunk the coordinates fall in
    local cx = math.floor(x / CHUNK_LENGTH)
    local cy = math.floor(y / CHUNK_LENGTH)
    
    local key = self:get_chunk_key(cx, cy)
    local chunk_index = self:get_chunk_index(key)
    if not chunk_index then return nil end
    
    local chunk = self:get_chunk(chunk_index)
    
    local tx = x - cx * CHUNK_LENGTH
    local ty = y - cy * CHUNK_LENGTH
    local i = tx + ty * CHUNK_LENGTH + 1
    return chunk[i]    
end

function InfiniteGrid:get_chunk(index)
    return self.chunks[index]
end

function InfiniteGrid:clear()
    self.chunks = {}
    self.chunk_index_map = {}
end

function InfiniteGrid:_remove_chunk(chunk_index)
    table.remove(self.chunks, chunk_index)
    -- Update key map
    for k, i in pairs(self.chunk_index_map) do
        if i == chunk_index then
            self.chunk_index_map[k] = nil
        elseif i > chunk_index then
            self.chunk_index_map[k] = i - 1
        end
    end
end

function InfiniteGrid:remove_empty_chunks()
    for i,chunk in ipairs(self.chunks) do
        if chunk[CHUNK_COUNTER] == 0 then
            self:_remove_chunk(i)
        end
    end
end

-- Returns all non-0 cells
function InfiniteGrid:get_occupied_cells()
    local cells = {}
    for key, index in pairs(self.chunk_index_map) do
        local s = key:split("_")
        local x = tonumber(s[1]) * CHUNK_LENGTH
        local y = tonumber(s[2]) * CHUNK_LENGTH
        
        local chunk = self:get_chunk(index)
        
        for cx = 1, CHUNK_LENGTH do
            for cy = 1, CHUNK_LENGTH do
                local i = (cx - 1) % CHUNK_LENGTH + (cy - 1) * CHUNK_LENGTH + 1
                if chunk[i] ~= 0 then
                    table.insert(cells, vec2(x + cx - 1, y + cy - 1))
                end
            end
        end
    end

    return cells
end

return InfiniteGrid