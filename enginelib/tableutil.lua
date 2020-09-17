
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

