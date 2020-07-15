local module = {}

function module.point_aabb(point, rmin, rmax)
    return point.x >= rmin.x
    and point.x <= rmax.x
    and point.y >= rmin.y
    and point.y <= rmax.y
end

return module