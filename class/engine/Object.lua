-- Base class for all objects
-- Includes a signal/slot system
local binser = require("enginelib.binser")
local middleclass = require("enginelib.middleclass")
local Object = middleclass("Object")

--- Create generic getters/setters for the given property.
-- Don't forget to actually initialize these properties when creating the object
-- @param class
-- @param name
Object.static.define_get_set = function(class, name)
    class[("set_%s"):format(name)] = function(self, v) self[name] = v end
    class[("get_%s"):format(name)] = function(self) return self[name] end
end

--- Define a signal for the signal/slot system.
-- If we try to emit or connect to an undefined signal, an error will be thrown.
-- @param class
-- @param name The signal name
Object.static.define_signal = function(class, name)
    class.static.signals = rawget(class.static, "signals") or {} -- Create signals table it does not exist
    table.insert(class.static.signals, name)
end

--- Exports a member of the class, marking it for serialization, and allowing it to be displayed in the editor if desired.
-- Also defines standard getset functions for it
-- @param class
-- @param name The property name
-- @param datatype Datatypes can be anything, see ObjectInspector to see how different types are handled.
-- In particular, data indicates a custom editor is needed and the property will not be shown in 
-- the object inspector
-- @param editor_hints A table containing various hints to how the editing widget should be displayed.
-- These vary depending on the datatype, check _draw_property_widget in class/editor/Editor.lua for more details 
Object.static.export_var = function(class, name, datatype, editor_hints)
    
    assert(name ~= nil, "A name must be given!")
    assert(datatype ~= nil, "A datatype must be specified!")
    
    class.static.exported_vars = rawget(class.static, "exported_vars") or {} -- Create export table if it does not exist

    -- Make sure getsets exist for this var, even if none are manually defined
    class:define_get_set(name)
    
    table.insert(class.static.exported_vars, 
        {type = datatype, 
        name = name, 
        editor_hints = editor_hints or {}})
end

Object.static.get_exported_vars = function(class)
    local evars = {}
    while class do
        local static = rawget(class, "static")
        if static then
            local exported = rawget(static, "exported_vars")
            if exported then
                for _,ep in ipairs(exported) do
                    evars[ep.name] = ep
                end             
            end
        end
        class = class.super
    end
    return evars
end

Object.static.binser_register = function(class)
    if not rawget(class.static, "_deserialize") then
        class.static._deserialize = function(data)
            local instance = class()
            for _,v in ipairs(data) do
                local key = v[1]
                local val = v[2]
                
                local setter = ("set_%s"):format(key)
                instance[setter](instance, val)
            end
            return instance
        end
    end
    
    binser.register(class.__instanceDict, class.name, class._serialize, class._deserialize)
end

-- serialization saves all exported variables into a key-value table
function Object:_serialize()
    local res = {}
    local cur_class = self.class
    while (cur_class) do
        local static = rawget(cur_class, "static")
        if static then
            local exported = rawget(static, "exported_vars")
            
            if exported then
                for _, ep in ipairs(exported) do
                    local getter = ("get_%s"):format(ep.name)
                    table.insert(res, {ep.name, self[getter](self)})
                end
            end
        end        
        
        cur_class = cur_class.super
    end
    return res
end

local _destroy_guard_func = function(guard)
    local mt = getmetatable(guard)
    local obj = mt._obj
    if not settings.get_setting("suppress_destroy_guard_nag") 
    and not obj.suppress_destroy_guard_nag
    and not obj.destroyed then
        log.info(
            ("%s was not properly destroyed before being garbage collected!"):format(tostring(obj))
        )
    end
end

function Object:initialize()

    self.destroyed = false
    if _VERSION == "Lua 5.1" then
        -- If possible, use undocumented newproxy() function to make gc nag if 
        -- we let an Object get garbage collected without first calling destroy on it
        self.destroy_guard = newproxy(true)
        local mt = getmetatable(self.destroy_guard)
        mt.__gc = _destroy_guard_func
        mt._obj = self
    end

    self.connections = {}
    self.signals = {}
    
    -- Recursively find every exposed signal and create a table for it
    local c = self.class
    while c do
        if c.static.signals then
            for _,name in ipairs(c.static.signals) do
                self.signals[name] = {}
            end
        end
        c = c.super
    end
end

--- Connect a signal to a slot (method)
-- signal (string) is the name of the signal
-- target (Object) is the object to connect to
-- method (string) is the name of the method in the target object
-- returns: nothing
function Object:connect(signal, target, method)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))
    assert(not self:is_connected(signal, target, method), "Signal is already connected")
    table.insert( self.signals[signal], {target = target, method = method, connected = true} )
    -- Give connected object a reference to the connection
    table.insert( target.connections, {subject = self, signal = signal, method = method} )
end

-- Disconnect a signal
-- signal (string) is the name of the signal
-- target (Object) is the object connected
-- method (string) is the name of the method in the target object
function Object:disconnect(signal, target, method)
    for i,c in ipairs(self.signals[signal]) do
        if c.target == target and c.method == method then
            c.connected = false
            c.target:_remove_connection(self, signal, c.method)
            table.remove(self.signals[signal], i)
            return
        end
    end
    
    error("Signal is not connected")
end

-- Signals should be disconnected when an object is to be destroyed
function Object:disconnect_all()
    for name, signals in pairs(self.signals) do
        for _, c in ipairs(signals) do
            c.connected = false
            c.target:_remove_connection(self, name, c.method)
        end
        self.signals[name] = {}
    end
    
end

function Object:is_connected(signal, target, method)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))
    for _,c in ipairs(self.signals[signal]) do
        if c.target == target and c.method == method then
            return true
        end
    end

    return false
end

function Object:emit_signal(signal, ...)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))

    -- Create local table containing connections, they might be 
    -- disconnected or have their objects destroyed during signal propagation
    local connections = {}
    for _,c in ipairs(self.signals[signal]) do
        table.insert( connections, c)
    end
    
    for _,c in ipairs(connections) do
        if c.connected and not c.target.destroyed then
            c.target[c.method](c.target, ...)
        end
    end
end

-- Once you're done with an object, you should destroy it to ensure signals are properly removed
function Object:destroy()
    if self.destroyed then return end
    
    -- Disconnect all signals
    self:disconnect_all()
    
    self.destroyed = true
end

function Object:is_destroyed()
    return self.destroyed
end

-- Internal helper for disconnecting signals
function Object:_remove_connection(subject, signal, method)
    for i,c in ipairs(self.connections) do
        if c.subject == subject and c.signal == signal and c.method == method then
            table.remove(self.connections, i)
            return
        end
    end
end

return Object