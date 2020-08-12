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

Object.static.get_signals = function(class)
    local signals = {}
    while class do
    
        if rawget(class.static, "signals") then
            for _,name in ipairs(class.static.signals) do
                signals[name] = true
            end
        end
    
        class = class.super
    end
    return signals
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

local weak_mt = {__mode = "k"}
function Object:initialize()

    self.connections = {}
    self.signals = self.class:get_signals()
    for name in pairs(self.signals) do
        self.signals[name] = setmetatable({}, weak_mt)
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
    assert(type(target[method]) == "function", ("Invalid method %s"):format(tostring(method)))
    
    
    self.signals[signal][target] = self.signals[signal][target] or {}
    self.signals[signal][target][method] = true
    
    -- Give connected object a reference to the connection
    target.connections[method] = target.connections[method] or setmetatable({}, weak_mt)
    target.connections[method][self] = target.connections[method][self] or {}
    target.connections[method][self][signal] = true
    
    table.insert( target.connections, {subject = self, signal = signal, method = method} )
end

-- Disconnect a signal
-- signal (string) is the name of the signal
-- target (Object) is the object connected
-- method (string) is the name of the method in the target object
function Object:disconnect(signal, target, method)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))
    assert(type(target[method]) == "function", ("Invalid method %s"):format(tostring(method)))    
    assert(self:is_connected(signal, target, method), "Signal is not connected" )

    self.signals[signal][target][method] = nil
    target:_remove_connection(signal, self, method)
end

-- Signals should be disconnected when an object is to be destroyed
function Object:disconnect_all()
    for name, signals in pairs(self.signals) do
        for target, methods in pairs(signals) do
            for method in pairs(signals) do
                target:_remove_connection(name, self, method)
            end
            signals[target] = nil
        end
    end
    
end

function Object:is_connected(signal, target, method)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))    
    return self.signals[signal][target] and self.signals[signal][target][method]
end

-- No gurantees are made about the order signals are called in
function Object:emit_signal(signal, ...)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))

    for target, methods in pairs(self.signals[signal]) do
        for method in pairs(methods) do
            target[method](target, ...)
        end
    end
end

-- Internal helper for disconnecting signals
function Object:_remove_connection(signal, subject, method)
    local s = self.connections[method][subject]
    s[signal] = nil    
end

return Object