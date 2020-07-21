local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local abs = math.abs
local sign

function math.sign(n)
    if n > 0 then
        return 1
    elseif n < 0 then 
        return -1
    else 
        return 0
    end
end

sign = math.sign

function math.clamp(n, lo, hi)
    return min(hi, max(lo, n))
end

function math.movetowards(c, t, d)
    if abs(t - c) <= d then
        return t    
    end
    
    return c + sign(t - c) * d
end

function math.round(n, step)
    step = step or 1
    return floor(n / step + 0.5 ) * step
end
