-- yes it *IS* manual memory management, if you don't push unused objects back 
-- into the pool they get garbage collected

-- since generic tables' metatable is nil, Pool with nil generator 
-- produces generic tables

-- MIT license, knock yourselves out

local ffiloaded, ffi = pcall ( require, "ffi" )

local Pool = setmetatable ( { }, { __call = function ( class, ... ) return class.new ( ... ) end } )
Pool.__index = Pool

-- accepts custom generator function, nil, lua table, 
-- ffi cdecl, ffi ctype for object generator
function Pool.new ( generator )
    local self = setmetatable ( { }, Pool )
    if type ( generator ) == "function" then
        self.generator = generator
    elseif ffiloaded and ( type ( generator ) == "string" or type ( generator ) == "cdata" ) then
        self.generator = ffi.typeof ( generator )
    elseif generator == nil or type ( generator ) == "table" then
        self.generator = function ( ) return setmetatable ( { }, generator ) end
    end
    self.pool = { } 
    return self
end

-- retreive object if available
function Pool:pop2 ( )
    return table.remove ( self.pool )
end

if settings.get_setting("debug") then
function Pool:pop ( )
    local r = table.remove(self.pool)
    if not r then
        r = self.generator()
        log.info(("Pool Miss! (%s)"):format(tostring(r)))
    end
    
    return r

end

else
-- allocate new object if none available, always returns an object
function Pool:pop ( )
    return table.remove ( self.pool ) or self.generator ( )
end

end

-- discard used object for later reuse
function Pool:push ( obj )
    table.insert ( self.pool, obj )
end

-- preallocate objects
function Pool:generate ( num )
    for i = 1, num do table.insert ( self.pool, self.generator ( ) ) end
end

-- clear references
function Pool:clear ( )
    while #self.pool > 1 do table.remove ( self.pool ) end
end

return Pool