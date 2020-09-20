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

function table.copy(t, do_recurse)
    
    local c = {}
    
    for k,v in pairs(t) do
        if do_recurse and type(v) == "table" then
            c[k] = table.copy(v, true)
        else
            c[k] = v
        end
    end
    
    return c
end

function table.pack(...)
    return { n = select("#", ...), ... }
end

function table.find(t, v)
    for _,v2 in pairs(t) do
        if v2 == v then
            return true
        end
    end

    return false
end

function table.compare_array(t1, t2)
    if #t1 ~= #t2 then
        return false
    end
    
    for i = 1, #t1 do
        if t1[i] ~= t2[2] then
            return false
        end
    end
        
    return true
end

