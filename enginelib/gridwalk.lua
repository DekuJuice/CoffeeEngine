-- bresenham.lua - v1.0 (2012-05)
-- Copyright (c) 2011 Enrique García Cota
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local function los(x0,y0,x1,y1, callback)

  local sx,sy,dx,dy

  if x0 < x1 then
    sx = 1
    dx = x1 - x0
  else
    sx = -1
    dx = x0 - x1
  end

  if y0 < y1 then
    sy = 1
    dy = y1 - y0
  else
    sy = -1
    dy = y0 - y1
  end

  local err, e2 = dx-dy, nil

  if not callback(x0, y0) then return false end

  while not(x0 == x1 and y0 == y1) do
    e2 = err + err
    if e2 > -dy then
      err = err - dy
      x0  = x0 + sx
    end
    if e2 < dx then
      err = err + dx
      y0  = y0 + sy
    end
    if not callback(x0, y0) then return false end
  end

  return true
end

local function line(x0,y0,x1,y1,callback)
  local points = {}
  local count = 0
  local result = los(x0,y0,x1,y1, function(x,y)
    if callback and not callback(x,y) then return false end
    count = count + 1
    points[count] = {x,y}
    return true
  end)
  return points, result
end

--[[
    Supercover taken and modifed from
    https://github.com/kikito/bump.lua

    Copyright (c) 2014 Enrique García Cota
    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local function grid_toCell(cellSize, x, y)
  return math.floor(x / cellSize) + 1, math.floor(y / cellSize) + 1
end

-- grid_traverse* functions are based on "A Fast Voxel Traversal Algorithm for Ray Tracing",
-- by John Amanides and Andrew Woo - http://www.cse.yorku.ca/~amana/research/grid.pdf
-- It has been modified to include both cells when the ray "touches a grid corner",
-- and with a different exit condition

local function grid_traverse_initStep(cellSize, ct, t1, t2)
  local v = t2 - t1
  if     v > 0 then
    return  1,  cellSize / v, ((ct + v) * cellSize - t1) / v
  elseif v < 0 then
    return -1, -cellSize / v, ((ct + v - 1) * cellSize - t1) / v
  else
    return 0, math.huge, math.huge
  end
end

local function grid_traverse(cellSize, x1,y1,x2,y2, f)
  local cx1,cy1        = grid_toCell(cellSize, x1,y1)
  local cx2,cy2        = grid_toCell(cellSize, x2,y2)
  local stepX, dx, tx  = grid_traverse_initStep(cellSize, cx1, x1, x2)
  local stepY, dy, ty  = grid_traverse_initStep(cellSize, cy1, y1, y2)
  local cx,cy          = cx1,cy1

  f(cx, cy)

  -- The default implementation had an infinite loop problem when
  -- approaching the last cell in some occassions. We finish iterating
  -- when we are *next* to the last cell
  while abs(cx - cx2) + abs(cy - cy2) > 1 do
    if tx < ty then
      tx, cx = tx + dx, cx + stepX
      f(cx, cy)
    else
      -- Addition: include both cells when going through corners
      if tx == ty then f(cx + stepX, cy) end
      ty, cy = ty + dy, cy + stepY
      f(cx, cy)
    end
  end

  -- If we have not arrived to the last cell, use it
  if cx ~= cx2 or cy ~= cy2 then f(cx2, cy2) end

end

local module = {}
module.bresenham = line
module.bresenham_los = los
module.supercover = grid_traverse

return module