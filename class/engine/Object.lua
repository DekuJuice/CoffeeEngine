-- Base class for all objects
-- Includes a signal/slot system
local binser = require("enginelib.binser")
local middleclass = require("enginelib.middleclass")
local Object = middleclass("Object")

binser.registerResource(Object, "Object")

function Object.static.subclassed(self, other)
    binser.registerResource(other, ("Class%s"):format(other.name))
end

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
-- @param [opt] export_hints A table containing various hints on the constraints of the property as well as 
-- how they should be displayed by editing widgets.
-- These vary depending on the datatype, check _draw_property_widget in class/editor/Editor.lua for more details 

-- @table export_hints
-- @field [opt] default The default value of the variable
Object.static.export_var = function(class, name, datatype, export_hints)
    
    assert(name ~= nil, "A name must be given!")
    assert(datatype ~= nil, "A datatype must be specified!")
    
    class.static.exported_vars = rawget(class.static, "exported_vars") or {} -- Create export table if it does not exist

    -- Make sure getsets exist for this var, even if none are manually defined
    class:define_get_set(name)
    
    table.insert(class.static.exported_vars, 
        {type = datatype, 
        name = name, 
        export_hints = export_hints or {}})
end

--- Returns a table of exported variables
-- @param class
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

--- Returns a set of signals defined for the class
-- @param class
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

local weak_mt = {__mode = "k"}
function Object:initialize()

    self.connections = {}
    self.signals = self.class:get_signals()
    for name in pairs(self.signals) do
        self.signals[name] = setmetatable({}, weak_mt)
    end

end

--- Connect a signal to a slot (method)
-- @param signal The name of the signal
-- @param target The object to notify when the signal is emitted
-- @method The name of the method in the target object to call
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

--- Disconnect a signal
-- @param signal The name of the signal
-- @param target The object to notify when the signal is emitted
-- @method The name of the method in the target object to call
function Object:disconnect(signal, target, method)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))
    assert(type(target[method]) == "function", ("Invalid method %s"):format(tostring(method)))    
    assert(self:is_connected(signal, target, method), "Signal is not connected" )

    self.signals[signal][target][method] = nil
    target:_remove_connection(signal, self, method)
end

-- Disconnects all signals
function Object:disconnect_all()
    for name, signals in pairs(self.signals) do
        for target, methods in pairs(signals) do
            for method in pairs(methods) do
                target:_remove_connection(name, self, method)
            end
            signals[target] = nil
        end
    end
    
end

--- Checks if a given signal is connected
-- @param signal The name of the signal
-- @param target The object to notify when the signal is emitted
-- @method The name of the method in the target object to call
function Object:is_connected(signal, target, method)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))    
    return self.signals[signal][target] and self.signals[signal][target][method]
end

--- Returns a list of outgoing connections for the given signal
-- @param signal the name of the signal
function Object:get_connections(signal)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))
    
    local list = {}
    for target, methods in pairs(self.signals[signal]) do
        for method in pairs(methods) do
            table.insert(list, { target = target, method = method })
        end
    end
    return list
end

--- Emits a signal
-- No gurantees are made about the order signals are called in
-- @param signal The name of the signal
-- @param ... Arguments to pass to the signaled methods
function Object:emit_signal(signal, ...)
    assert(self.signals[signal], ("Invalid signal %s"):format(signal))

    for target, methods in pairs(self.signals[signal]) do
        for method in pairs(methods) do
            target[method](target, ...)
        end
    end
end

--- Internal helper for disconnecting signals
function Object:_remove_connection(signal, subject, method)
    local s = self.connections[method][subject]
    s[signal] = nil    
end

return Object