
function table.copy(t, do_recurse)
    
    local c = {}
    
    for k,v in pairs(t) do
        if do_recurse and type(v) == "table" then
            c[k] = module.copy(v, true)
        else
            c[k] = v
        end
    end
    
    return c
end

function table.pack(...)
  return { n = select("#", ...), ... }
end
