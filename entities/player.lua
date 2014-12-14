--[[
-- Player Class
-- This entity collides "sliding" over walls and floors.
--]]
local class  = require 'lib.middleclass'
local util   = require 'util'

local Entity = require 'entities.entity'

local Player = class('Player', Entity)
Player.static.updateOrder = 1

local runAccel      = 500 -- the player acceleration while going left/right
local brakeAccel    = 2000
local jumpVelocity  = 400 -- the initial upwards velocity when jumping
local width         = 32
local height        = 64

local abs = math.abs

function Player:initialize(world, x,y)
  Entity.initialize(self, world, x, y, width, height)

  self.filter = function(other)
    local kind = other.class.name
    if kind == 'Block'
    or (kind == 'Platform' and self.y + self.h <= other.prevY)
    then
      return 'slide'
    end
  end
end

function Player:changeVelocityByKeys(dt)
  local vx = self.vx
  if love.keyboard.isDown("left") then
    vx = vx - dt * (vx > 0 and brakeAccel or runAccel)
  elseif love.keyboard.isDown("right") then
    vx = vx + dt * (vx < 0 and brakeAccel or runAccel)
  else
    local brake = dt * (vx < 0 and brakeAccel or -brakeAccel)
    if math.abs(brake) > math.abs(vx) then
      vx = 0
    else
      vx = vx + brake
    end
  end

  self.vx = vx

  if love.keyboard.isDown("up") and self.ground then -- jump
    self.vy = -jumpVelocity
    self.ground = nil
  end
end

function Player:alignWithGround(dt)
  if self.ground then
    self.world:update(self, self.x, self.ground.y - self.h)
  end
end

function Player:setGround(other, dt)
  self.ground = other
  self:alignWithGround(dt)
end

function Player:checkIfOnGround(ny, other)
  if ny < 0 then
    self.ground = other
  end
end

function Player:moveColliding(dt)
  self.ground = nil
  local world = self.world

  local goalX = self.x + self.vx * dt
  local goalY = self.y + self.vy * dt

  local actualX, actualY, cols, len = world:check(self, goalX, goalY, self.filter)

  for i=1, len do
    local col = cols[i]
    self:changeVelocityByCollisionNormal(col.normal.x, col.normal.y, bounciness)
    self:checkIfOnGround(col.normal.y, col.other)
  end

  self.x, self.y = actualX, actualY
  world:update(self, actualX, actualY)
end

function Player:update(dt)
  self:alignWithGround()

  self:changeVelocityByKeys(dt)
  self:changeVelocityByGravity(dt)

  self:moveColliding(dt)
end

function Player:draw(drawDebug)
  util.drawFilledRectangle(self.x, self.y, self.w, self.h, 0,255,0)

  if drawDebug then
    if self.ground then
      util.drawFilledRectangle(self.x, self.y + self.h - 4, self.w, 4, 255,255,255)
    end
  end
end

return Player