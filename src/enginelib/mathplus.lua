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

function math.truncate(n)
    if n > 0 then 
        return math.floor(n)
    else
        return math.ceil(n)
    end
end
