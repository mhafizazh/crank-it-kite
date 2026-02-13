import "CoreLibs/sprites"
import "CoreLibs/graphics"

local pd  = playdate
local gfx = pd.graphics

-- Screen bounds (Playdate is 400x240)
local SCREEN_W, SCREEN_H = 400, 240

local score = 0

-- Player / kite
local kite = {}
kite.x, kite.y = 200, 120
kite.speed = 2.0                  -- forward speed
kite.angle = 0                    -- current kite facing angle (degrees)
kite.turnBase = 8.0               -- base turn speed (deg per frame, before wind)
kite.turnVelocity = 0.0           -- current angular velocity (deg/frame)
kite.turnAccel = 0.25             -- steering acceleration strength
kite.turnFriction = 0.85          -- damping (0..1), higher = smoother

-- Collectable Item
local item = {}
item.x, item.y = math.random(20, 350), math.random(20, 110)


-- Wind (optional)
local wind = {}
wind.angle = 0                    -- wind direction (degrees)
wind.changeTimer = 0
wind.changeInterval = 240         -- frames between changes (~4 seconds at 60fps)

-- Sprite setup
local kiteImage = gfx.image.new("images/kite")
local kiteSprite = gfx.sprite.new(kiteImage)
kiteSprite:setCollideRect(4, 4, 20, 30)
kiteSprite:moveTo(kite.x, kite.y)
kiteSprite:add()

-- collectable item setup
local itemImage = gfx.image.new("images/baloon")
local itemSprite = gfx.sprite.new(itemImage)
itemSprite.collisionResponse = gfx.sprite.KcollisionTypeOverlap
itemW, itemH = itemSprite:getSize()
itemSprite:setCollideRect(4, -1, itemW-4, itemH)
itemSprite:moveTo(item.x, item.y)
itemSprite:add()

-- Obstacle1
local obstacleSpeed = 5
local obstacleImage = gfx.image.new("images/bird")
local obstacleSprite = gfx.sprite.new(obstacleImage)
obstacleSprite:setCollideRect(0, 0, 14, 14)
obstacleSprite:moveTo(450, 240)
obstacleSprite:add()


-- add sound pop effect
local popSound = pd.sound.fileplayer.new( "sounds/pop" )


-- add lose sounds effect
local loseSound = pd.sound.fileplayer.new("sounds/lose")
-- bird definition
-- local Bird ={}
-- Bird._index = Bird


-- function Bird.new(x, y, speed, isLeft)
--     local self = setmetatable({}, Bird)
--     self.x = x
--     self.y = y
--     self.speed = speed
--     self.isLeft = isLeft
--     return self
-- end

-- function Bird:move(dx, dy)
--     self.x = self.x + dx
--     self.y = self.y + dy
-- end

-- function Bird:getPosition()
--     return self.x, self.y
-- end

-- game state
local gameOver = false

local function accelerateControlY(currSpeed)
    if pd.buttonIsPressed(pd.kButtonUp) then
        return currSpeed - 2
    end
    if pd.buttonIsPressed(pd.kButtonDown) then
        return currSpeed + 2
    end
    return currSpeed
    
end

local function accelerateControlX(currSpeed)
    if pd.buttonIsPressed(pd.kButtonLeft) then
        return currSpeed - 2
    end
    if pd.buttonIsPressed(pd.kButtonRight) then
        return currSpeed + 2
    end
    return currSpeed
    
end

local function respawnObstacle()
    obstacleSprite:moveTo(-50, math.random(50, 220))
end

-- --- Helpers ---
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Returns shortest signed angle difference (target - current) in degrees, range [-180, 180]
local function shortestAngleDiffDeg(current, target)
    local diff = (target - current + 180) % 360 - 180
    return diff
end

-- Convert degrees to radians
local function deg2rad(d) return d * math.pi / 180 end

-- --- Update loop ---
function pd.update()
    if gameOver then
        gfx.drawText("*Game Over*", 140, 100)
        gfx.drawText("*Press A to restart", 110, 120)
        loseSound:play()
        if pd.buttonJustPressed(pd.kButtonA) then
            gameOver = false
            score = 0
            kite.x, kite.y = 200, 120
            kite.angle = 0
            kite.turnVelocity = 0
            respawnObstacle()
        end
        return
    end

    gfx.sprite.update()
    -- 1) Read crank as "steering wheel" target direction
    local targetAngle = pd.getCrankPosition() -- 0..360

    -- 2) (Optional) wind changes over time
    -- wind.changeTimer += 1
    if wind.changeTimer >= wind.changeInterval then
        wind.changeTimer = 0
        wind.angle = math.random(0, 359)
    end

    -- 3) Compute turn resistance/speed based on wind alignment
    -- Alignment: 1 = same direction, -1 = opposite
    local align = math.cos(deg2rad(kite.angle - wind.angle))
    -- Turn multiplier: faster when aligned, slower when opposing
    -- Tune these numbers to taste.
    local turnMultiplier = 0.4 + 0.6 * ((align + 1) * 0.5)  -- maps [-1..1] -> [0.4..1.0]

    local maxTurn = kite.turnBase * turnMultiplier

    -- 4) Smoothly rotate kite toward crank angle (heavy-kite feel)
    local diff = shortestAngleDiffDeg(kite.angle, targetAngle)
    local accel = clamp(diff * kite.turnAccel, -maxTurn, maxTurn)
    kite.turnVelocity = clamp(kite.turnVelocity + accel, -maxTurn, maxTurn)
    kite.turnVelocity = kite.turnVelocity * kite.turnFriction
    kite.angle = (kite.angle + kite.turnVelocity) % 360

    -- 5) Move forward in kite’s facing direction
    local r = deg2rad(kite.angle)
    kite.x = accelerateControlX(kite.x + math.cos(r) * kite.speed)
    kite.y = accelerateControlY(kite.y + math.sin(r) * kite.speed)

    -- 6) Keep kite on screen (simple clamp; you can replace with wrap/bounce)
    kite.x = clamp(kite.x, 0, SCREEN_W)
    kite.y = clamp(kite.y, 40, SCREEN_H)  -- you used 40 as a top HUD area

    kiteSprite:moveTo(kite.x, kite.y)

    local collisions = kiteSprite:overlappingSprites()
    for i = 1, #collisions do
        if collisions[i] == itemSprite then
            popSound:play()
            score = score + 1
            -- Respawn item at random position
            item.x = math.random(20, 350)
            item.y = math.random(50, 200)
            itemSprite:moveTo(item.x, item.y)
        end
    end
    
    local obstacleX, obstacleY = obstacleSprite:getPosition()
    obstacleX = obstacleX + obstacleSpeed

    -- Respawn when off-screen right
    if obstacleX > 450 then
        respawnObstacle()
    else
        obstacleSprite:moveTo(obstacleX, obstacleY)
    end

    -- Check collision with obstacle
    for i = 1, #collisions do
        if collisions[i] == obstacleSprite then
            gameOver = true
        end
    end

    if pd.buttonJustPressed(pd.kButtonB) then
        gameOver = false
        score = 0
        kite.x, kite.y = 200, 120
        kite.angle = 0
        kite.turnVelocity = 0
        respawnObstacle()
    end

    -- 7) Optional debug display
    gfx.drawText("*Score: *" .. tostring(score), 10, 10)
    gfx.drawText("*Wind: *" .. tostring(wind.angle), 10, 30)
    -- gfx.drawText("*kite: *" .. tostring(math.floor(kite.angle)), 10, 50)
end
