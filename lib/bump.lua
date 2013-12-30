local bump = {
  _VERSION     = 'bump v2.0.0',
  _URL         = 'https://github.com/kikito/bump.lua',
  _DESCRIPTION = 'A collision detection library for Lua',
  _LICENSE     = [[
    MIT LICENSE

    Copyright (c) 2013 Enrique García Cota

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
  ]]
}

local abs, floor, ceil, min, max = math.abs, math.floor, math.ceil, math.min, math.max

local function assertType(desiredType, value, name)
  if type(value) ~= desiredType then
    error(name .. ' must be a ' .. desiredType .. ', but was ' .. tostring(value) .. '(a ' .. type(value) .. ')')
  end
end

local function assertIsPositiveNumber(value, name)
  if type(value) ~= 'number' or value <= 0 then
    error(name .. ' must be a positive integer, but was ' .. tostring(value) .. '(' .. type(value) .. ')')
  end
end

local function assertIsBox(l,t,w,h)
  assertType('number', l, 'l')
  assertType('number', t, 'w')
  assertIsPositiveNumber(w, 'w')
  assertIsPositiveNumber(h, 'h')
end

local function getLiangBarskyIndices(l,t,w,h, x1,y1,x2,y2, t0,t1)
  t0, t1 = t0 or 0, t1 or 1
  local dx, dy = x2-x1, y2-y1
  local p, q, r

  for side = 1,4 do
    if     side == 1 then p,q = -dx, x1 - l
    elseif side == 2 then p,q =  dx, l + w - x1
    elseif side == 3 then p,q = -dy, y1 - t
    else                  p,q =  dy, t + h - y1
    end

    if p == 0 then
      if q < 0 then return nil end
    else
      r = q / p
      if p < 0 then
        if     r > t1 then return nil
        elseif r > t0 then t0 = r
        end
      else -- p > 0
        if     r < t0 then return nil
        elseif r < t1 then t1 = r
        end
      end
    end
  end
  return t0, t1
end

local function getMinkowskyDiff(l1,t1,w1,h1, l2,t2,w2,h2)
  return l2 - l1 - w1,
         t2 - t1 - h1,
         w1 + w2,
         h1 + h2
end

local function containsPoint(l,t,w,h, x,y)
  return x > l and y > t and x < l + w and y < t + h
end

local function minAbs(a,b)
  if abs(a) < abs(b) then return a else return b end
end

local function areColliding(l1,t1,w1,h1, l2,t2,w2,h2)
  return l1 < l2+w2 and l2 < l1+w1 and
         t1 < t2+h2 and t2 < t1+h1
end

function toCellBox(world, l,t,w,h)
  local cellSize = world.cellSize
  local cl,ct    = world:toCell(l, t)
  local cr,cb    = ceil((l+w) / cellSize), ceil((t+h) / cellSize)
  return cl, ct, cr-cl+1, cb-ct+1
end

local function sortByTi(a,b) return a.ti < b.ti end

local function collideBoxes(item, b1, b2, next_l, next_t, axis)
  local l1,t1,w1,h1  = b1.l, b1.t, b1.w, b1.h
  local l2,t2,w2,h2  = b2.l, b2.t, b2.w, b2.h
  local l,t,w,h      = getMinkowskyDiff(next_l,next_t,w1,h1, l2,t2,w2,h2)

  if containsPoint(l,t,w,h, 0,0) then -- b1 was intersecting b2
    local dx,dy = 0,0
    if     axis == 'x' then dx = minAbs(l,l+w)
    elseif axis == 'y' then dy = minAbs(t,t+h)
    else
      dx, dy = minAbs(l,l+w), minAbs(t,t+h)
      if abs(dx) < abs(dy) then dy=0 else dx=0 end
    end
    return {item = item, dx = dx, dy = dy, ti = 0, kind = 'intersection'}
  else
    local vx, vy  = next_l - l1, next_t - t1
    l,t,w,h = getMinkowskyDiff(l1,t1,w1,h1, l2,t2,w2,h2)
    local ti,_ = getLiangBarskyIndices(l,t,w,h, 0,0,vx,vy)
    -- b1 tunnels into b2 while it travels
    if ti and ti > 0 then
      local dx, dy = vx*ti-vx, vy*ti-vy
      if     axis == 'x' then dy = 0
      elseif axis == 'y' then dx = 0
      end
      return {item = item, dx = dx, dy = dy, ti = ti, kind = 'tunnel'}
    end
  end
end

local function addItemToCell(self, item, cx, cy)
  self.rows[cy] = self.rows[cy] or setmetatable({}, {__mode = 'v'})
  local row = self.rows[cy]
  row[cx] = row[cx] or {itemCount = 0, x = cx, y = cy, items = setmetatable({}, {__mode = 'k'})}
  local cell = row[cx]
  self.nonEmptyCells[cell] = true
  if not cell.items[item] then
    cell.items[item] = true
    cell.itemCount = cell.itemCount + 1
  end
end

local function removeItemFromCell(self, item, cx, cy)
  local row = self.rows[cy]
  if not row or not row[cx] or not row[cx].items[item] then return false end

  local cell = row[cx]
  cell.items[item] = nil
  cell.itemCount = cell.itemCount - 1
  if cell.itemCount == 0 then
    self.nonEmptyCells[cell] = nil
  end
  return true
end

local function getDictItemsInCellBox(self, cl,ct,cw,ch)
  local items_dict = {}
  for cy=ct,ct+ch-1 do
    local row = self.rows[cy]
    if row then
      for cx=cl,cl+cw-1 do
        local cell = row[cx]
        if cell and cell.itemCount > 0 then -- no cell.itemCount > 1 because tunneling
          for item,_ in pairs(cell.items) do
            items_dict[item] = true
          end
        end
      end
    end
  end

  return items_dict
end

local function getSegmentStep(cellSize, ct, t1, t2)
  local v = t2 - t1
  if     v > 0 then
    return  1,  cellSize / v, ((ct + v) * cellSize - t1) / v
  elseif v < 0 then
    return -1, -cellSize / v, ((ct + v - 1) * cellSize - t1) / v
  else
    return 0, math.huge, math.huge
  end
end

local function getCellsTouchedBySegment(self, x1,y1,x2,y2)

  local cx1,cy1        = self:toCell(x1,y1)
  local cx2,cy2        = self:toCell(x2,y2)
  local stepX, dx, tx  = getSegmentStep(self.cellSize, cx1, x1, x2)
  local stepY, dy, ty  = getSegmentStep(self.cellSize, cy1, y1, y2)
  local maxLen         = 2*(abs(cx2-cx1) + abs(cy2-cy1))
  local cx,cy          = cx1,cy1
  local coords, len = {{cx=cx,cy=cy}}, 1

  -- maxLen is a safety guard. In some cases this algorithm loops inf on the last step without it
  while len <= maxLen and (cx~=cx2 or y~=cy2) do
    if tx < ty then
      tx, cx, len = tx + dx, cx + stepX, len + 1
      coords[len] = {cx=cx,cy=cy}
    elseif ty < tx then
      ty, cy, len = ty + dy, cy + stepY, len + 1
      coords[len] = {cx=cx,cy=cy}
    else -- tx == ty
      local ntx,nty = tx+dx, dy+dy
      local ncx,ncy = cx+stepX, cy+stepY

      len = len + 1
      coords[len] = {cx=ncx,cy=cy}
      len = len + 1
      coords[len] = {cx=cx,cy=ncy}

      tx,ty = ntx,nty
      cx,cy = ncx,ncy
    end
  end

  local coord, row, cell
  local visited = {}
  local cells, cellsLen = {}, 0
  for i=1,len do
    coord = coords[i]
    row   = self.rows[coord.cy]
    if row then
      cell = row[coord.cx]
      if cell then
        if not visited[cell] then
          visited[cell] = true
          cellsLen = cellsLen + 1
          cells[cellsLen] = cell
        end
      end
    end
  end

  return cells, cellsLen
end

------------------------------------------------------------

local World = {}
local World_mt = {__index = World}

function World:add(item, l,t,w,h, options)
  local box = self.boxes[item]
  if box then
    error('Item ' .. tostring(item) .. ' added to the world twice.')
  end
  assertIsBox(l,t,w,h)

  self.boxes[item] = {l=l,t=t,w=w,h=h}

  local cl,ct,cw,ch = toCellBox(self, l,t,w,h)
  for cy = ct, ct+ch-1 do
    for cx = cl, cl+cw-1 do
      addItemToCell(self, item, cx, cy)
    end
  end

  return self:check(item, options)
end

function World:move(item, l,t,w,h, options)
  local box = self.boxes[item]
  if not box then
    error('Item ' .. tostring(item) .. ' must be added to the world before being moved. Use world:add(item, l,t,w,h) to add it first.')
  end
  w,h = w or box.w, h or box.h

  assertIsBox(l,t,w,h)

  options        = options or {}
  options.next_l = l
  options.next_t = t

  if box.w ~= w or box.h ~= h then
    self:remove(item)
    self:add(item, box.l, box.t, w,h, {skip_collisions = true})
  end

  local collisions, len = self:check(item, options)

  if box.l ~= l or box.t ~= t then
    self:remove(item)
    self:add(item, l,t,w,h, {skip_collisions = true})
  end

  return collisions, len
end

function World:getBox(item)
  local box = self.boxes[item]
  if not box then
    error('Item ' .. tostring(item) .. ' must be added to the world before getting its box. Use world:add(item, l,t,w,h) to add it first.')
  end
  return box.l, box.t, box.w, box.h
end

function World:check(item, options)
  local next_l, next_t, filter, skip_collisions, opt_visited, axis
  if options then
    next_l, next_t, filter, skip_collisions, opt_visited, axis =
      options.next_l, options.next_t, options.filter, options.skip_collisions, options.visited, options.axis
  end
  local box = self.boxes[item]
  if not box then
    error('Item ' .. tostring(item) .. ' must be added to the world before being checked for collisions. Use world:add(item, l,t,w,h) to add it first.')
  end

  local collisions, len = {}, 0

  if not skip_collisions then
    local visited = {[item] = true}
    if opt_visited then
      for _,v in pairs(opt_visited) do visited[v] = true end
    end
    local l,t,w,h = box.l, box.t, box.w, box.h
    next_l, next_t = next_l or l, next_t or t


    -- TODO this could probably be done with less cells using a polygon raster over the cells instead of a
    -- bounding box of the whole movement. Conditional to building a queryPolygon method
    local tl, tt = min(next_l, l),       min(next_t, t)
    local tr, tb = max(next_l + w, l+w), max(next_t + h, t+h)
    local tw, th = tr-tl, tb-tt

    local cl,ct,cw,ch = toCellBox(self, tl,tt,tw,th)

    local dictItemsInCellBox = getDictItemsInCellBox(self, cl,ct,cw,ch)

    for other,_ in pairs(dictItemsInCellBox) do
      if not visited[other] then
        visited[other] = true
        if not (filter and filter(other)) then
          local oBox = self.boxes[other]
          local col  = collideBoxes(other, box, oBox, next_l, next_t, axis)
          if col then
            len = len + 1
            collisions[len] = col
          end
        end
      end
    end

    table.sort(collisions, sortByTi)
  end

  return collisions, len
end

function World:remove(item)
  local box = self.boxes[item]
  if not box then
    error('Item ' .. tostring(item) .. ' must be added to the world before being removed. Use world:add(item, l,t,w,h) to add it first.')
  end
  self.boxes[item] = nil
  local cl,ct,cw,ch = toCellBox(self, box.l,box.t,box.w,box.h)
  for cy = ct, ct+ch-1 do
    for cx = cl, cl+cw-1 do
      removeItemFromCell(self, item, cx, cy)
    end
  end
end

function World:countCells()
  local count = 0
  for _,row in pairs(self.rows) do
    for _,_ in pairs(row) do
      count = count + 1
    end
  end
  return count
end

function World:toWorld(cx, cy)
  local cellSize = self.cellSize
  return (cx - 1)*cellSize, (cy-1)*cellSize
end

function World:toCell(x,y)
  local cellSize = self.cellSize
  return floor(x / cellSize) + 1, floor(y / cellSize) + 1
end

function World:queryBox(l,t,w,h)

  local cl,ct,cw,ch = toCellBox(self, l,t,w,h)
  local dictItemsInCellBox = getDictItemsInCellBox(self, cl,ct,cw,ch)

  local items, len = {}, 0

  local box
  for item,_ in pairs(dictItemsInCellBox) do
    box = self.boxes[item]
    if areColliding(l,t,w,h, box.l, box.t, box.w, box.h) then
      len = len + 1
      items[len] = item
    end
  end

  return items, len
end

function World:queryPoint(x,y)
  local cx,cy = self:toCell(x,y)
  local dictItemsInCellBox = getDictItemsInCellBox(self, cx,cy,1,1)

  local items, len = {}, 0

  local box
  for item,_ in pairs(dictItemsInCellBox) do
    box = self.boxes[item]
    if containsPoint(box.l, box.t, box.w, box.h, x, y) then
      len = len + 1
      items[len] = item
    end
  end

  return items, len
end

function World:querySegment(x1,y1,x2,y2)
  local cells, len = getCellsTouchedBySegment(self, x1,y1,x2,y2)
  local cell, box, l,t,w,h, t0, t1
  local visited, items, itemsLen = {},{},0
  for i=1,len do
    cell = cells[i]
    for item in pairs(cell.items) do
      if not visited[item] then
        visited[item] = true
        box = self.boxes[item]
        l,t,w,h = box.l,box.t,box.w,box.h

        t0,t1 = getLiangBarskyIndices(l,t,w,h, x1,y1, x2,y2, 0, 1)
        if t0 and ((0 < t0 and t0 < 1) or (0 < t1 and t1 < 1)) then
          -- the sorting is according to the t of an infinite line, not the segment
          t0,t1 = getLiangBarskyIndices(l,t,w,h, x1,y1, x2,y2, -math.huge, math.huge)
          itemsLen = itemsLen + 1
          items[itemsLen] = {item=item, ti=min(t0,t1)}
        end
      end
    end
  end
  table.sort(items, sortByTi)
  for i=1,itemsLen do
    items[i] = items[i].item
  end
  return items, itemsLen
end

bump.newWorld = function(cellSize)
  cellSize = cellSize or 64
  assertIsPositiveNumber(cellSize, 'cellSize')
  return setmetatable(
    { cellSize       = cellSize,
      boxes          = {},
      rows           = {},
      nonEmptyCells  = {}
    },
    World_mt
  )
end

return bump