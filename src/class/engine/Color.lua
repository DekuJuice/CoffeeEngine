local binser = require("enginelib.binser")
local class = require("enginelib.middleclass")

local Color = class("Color")

function Color:initialize(r, g, b, a)
    self[1] = r or 1
    self[2] = b or 1
    self[3] = g or 1
    self[4] = a or 1
end

function Color:_serialize()
    return self[1], self[2], self[3], self[4]
end

function Color.static._deserialize(r,g,b,a)
    local col = Color:allocate()
    col[1] = r
    col[2] = g
    col[3] = b
    col[4] = a
    
    return col
end

binser.registerClass(Color, "Color" )

function Color:__add(other)
    return Color(
        self[1] + other[1],
        self[2] + other[2],
        self[3] + other[3],
        self[4] + other[4]
    )
end

function Color:__sub(other)
    return self + (other * -1)
end

function Color:__mul(m)
    return Color(
        self[1] * m,
        self[2] * m,
        self[3] * m,
        self[4] * m
    )
end

return Color

