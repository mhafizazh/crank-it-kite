import "CoreLibs/sprites"
import "CoreLibs/graphics"

local pd  = playdate
local gfx = pd.graphics

-- Screen bounds (Playdate is 400x240)
local SCREEN_W, SCREEN_H = 400, 240

local score = 0

-- Player / Ship
local ship = {}
ship.x, ship.y = 200, 120
ship.speed = 2.0                  -- forward speed
ship.angle = 0                    -- current ship facing angle (degrees)
ship.turnBase = 8.0               -- base turn speed (deg per frame, before wind)
ship.turnVelocity = 0.0           -- current angular velocity (deg/frame)
ship.turnAccel = 0.25             -- steering acceleration strength
ship.turnFriction = 0.85          -- damping (0..1), higher = smoother

-- Collectable Item
local item = {}
item.x, item.y = math.random(20, 350), math.random(20, 110)


-- Wind (optional)
local wind = {}
wind.angle = 0                    -- wind direction (degrees)
wind.changeTimer = 0
wind.changeInterval = 240         -- frames between changes (~4 seconds at 60fps)

-- Sprite setup
local shipImage = gfx.image.new("images/kite")
local shipSprite = gfx.sprite.new(shipImage)
shipSprite:setCollideRect(4, 4, 20, 30)
shipSprite:moveTo(ship.x, ship.y)
shipSprite:add()

-- collectable item setup
local itemImage = gfx.image.new("images/baloon")
local itemSprite = gfx.sprite.new(itemImage)
itemSprite.collisionResponse = gfx.sprite.KcollisionTypeOverlap
itemW, itemH = itemSprite:getSize()
itemSprite:setCollideRect(4, -1, itemW-4, itemH)
itemSprite:moveTo(item.x, item.y)
itemSprite:add()

-- Obstacle 
local obstacleSpeed = 5
local obstacleImage = gfx.image.new("images/bird")
local obstacleSprite = gfx.sprite.new(obstacleImage)
obstacleSprite:setCollideRect(2, 0, 32, 32)
obstacleSprite:moveTo(450, 240)
obstacleSprite:add()

-- game state
local gameOver = false


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
        if pd.buttonJustPressed(pd.kButtonA) then
            gameOver = false
            score = 0
            ship.x, ship.y = 200, 120
            ship.angle = 0
            ship.turnVelocity = 0
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
    local align = math.cos(deg2rad(ship.angle - wind.angle))
    -- Turn multiplier: faster when aligned, slower when opposing
    -- Tune these numbers to taste.
    local turnMultiplier = 0.4 + 0.6 * ((align + 1) * 0.5)  -- maps [-1..1] -> [0.4..1.0]

    local maxTurn = ship.turnBase * turnMultiplier

    -- 4) Smoothly rotate ship toward crank angle (heavy-ship feel)
    local diff = shortestAngleDiffDeg(ship.angle, targetAngle)
    local accel = clamp(diff * ship.turnAccel, -maxTurn, maxTurn)
    ship.turnVelocity = clamp(ship.turnVelocity + accel, -maxTurn, maxTurn)
    ship.turnVelocity = ship.turnVelocity * ship.turnFriction
    ship.angle = (ship.angle + ship.turnVelocity) % 360

    -- 5) Move forward in ship’s facing direction
    local r = deg2rad(ship.angle)
    ship.x = ship.x + math.cos(r) * ship.speed
    ship.y = ship.y + math.sin(r) * ship.speed

    -- 6) Keep ship on screen (simple clamp; you can replace with wrap/bounce)
    ship.x = clamp(ship.x, 0, SCREEN_W)
    ship.y = clamp(ship.y, 40, SCREEN_H)  -- you used 40 as a top HUD area

    shipSprite:moveTo(ship.x, ship.y)

    local collisions = shipSprite:overlappingSprites()
    for i = 1, #collisions do
        if collisions[i] == itemSprite then
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
        ship.x, ship.y = 200, 120
        ship.angle = 0
        ship.turnVelocity = 0
        respawnObstacle()
    end

    -- 7) Optional debug display
    gfx.drawText("*Score: *" .. tostring(score), 10, 10)
    gfx.drawText("*Wind: *" .. tostring(wind.angle), 10, 30)
    gfx.drawText("*Ship: *" .. tostring(math.floor(ship.angle)), 10, 50)
end
