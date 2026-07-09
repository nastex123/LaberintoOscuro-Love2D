-- player.lua – Player character implementation

local Character = require "character"

local Player = {}
Player.__index = Player

function Player:new()
    local self = setmetatable({}, Player)
    self.x = 0
    self.y = 0
    self.r = 6
    self.speed = 130
    self.bob = 0
    self.stretchX = 1
    self.stretchY = 1
    self.lastDirX = 1
    self.lastDirY = 0
    self.lastFlipX = 1
    self.attackTimer = 0
    self.attackDuration = 0.25
    self.character = Character.create()
    return self
end

-- Pick a safe floor tile near a room's centre
function Player:setPos(room, maze)
    local candidates = {}
    for dy = -1,1 do
        for dx = -1,1 do
            local tx = room.cx + dx
            local ty = room.cy + dy
            if tx > 0 and ty > 0 and tx < maze.cols-1 and ty < maze.rows-1 and maze.grid[ty][tx] == 0 then
                table.insert(candidates, {x = tx, y = ty})
            end
        end
    end
    if #candidates == 0 then
        for y = room.y, room.y + room.h - 1 do
            for x = room.x, room.x + room.w - 1 do
                if x > 0 and y > 0 and x < maze.cols-1 and y < maze.rows-1 and maze.grid[y][x] == 0 then
                    table.insert(candidates, {x = x, y = y})
                end
            end
        end
    end
    if #candidates > 0 then
        local c = candidates[math.floor(#candidates/2) + 1]
        self.x = (c.x + 0.5) * maze.tile
        self.y = (c.y + 0.5) * maze.tile
    else
        self.x = (room.cx + 0.5) * maze.tile
        self.y = (room.cy + 0.5) * maze.tile
    end
end

function Player:startAttack()
    if self.attackTimer <= 0 then
        self.attackTimer = self.attackDuration
    end
end

function Player:update(input, maze, dt)
    -- Normalizar input diagonal para evitar velocidad √2
    local len = math.sqrt(input.x^2 + input.y^2)
    if len > 1 then input.x = input.x / len; input.y = input.y / len end
    local nx = self.x + input.x * self.speed * dt
    local ny = self.y + input.y * self.speed * dt
    local moved = false
    if not maze:isWall(nx, self.y) then self.x = nx; moved = true end
    if not maze:isWall(self.x, ny) then self.y = ny; moved = true end
    if math.abs(input.x) > 0.1 or math.abs(input.y) > 0.1 then
        self.lastDirX = input.x
        self.lastDirY = input.y
    end
    if math.abs(input.x) > 0.1 then
        self.lastFlipX = input.x
    end
    local spd = math.sqrt((input.x * self.speed)^2 + (input.y * self.speed)^2)
    if moved and spd > 10 then
        self.bob = self.bob + dt * 14
    else
        self.bob = self.bob + dt * 3
    end
    local tx, ty = 1, 1
    if math.abs(input.x) > 0.1 or math.abs(input.y) > 0.1 then
        local a = math.atan2(input.y, input.x)
        local c = math.cos(a)
        local s = math.sin(a)
        local stretch = 1.28
        local squash = 0.80
        tx = 1 + (stretch - 1) * math.abs(c) - (1 - squash) * math.abs(s)
        ty = 1 + (stretch - 1) * math.abs(s) - (1 - squash) * math.abs(c)
    end
    local ls = 8 * dt
    self.stretchX = self.stretchX + (tx - self.stretchX) * ls
    self.stretchY = self.stretchY + (ty - self.stretchY) * ls
    if self.attackTimer > 0 then
        self.attackTimer = math.max(0, self.attackTimer - dt)
    end
end

function Player:draw(camera, maze)
    local sx = self.x - camera.x
    local sy = self.y - camera.y
    local bobOffset = math.sin(self.bob) * 3

    local sinkOffset = 0
    if maze then
        local tx = math.floor(self.x / maze.tile)
        local ty = math.floor(self.y / maze.tile)
        if maze.grid[ty] and maze.grid[ty][tx] == 8 then
            sinkOffset = 3
        end
    end

    self.character:draw(sx, sy, bobOffset, sinkOffset)
end

function Player:drawHand(maze, camera, radius, sheet, quads)
    local tile = maze.tile
    local dist = radius * tile
    local len = math.sqrt(self.lastDirX^2 + self.lastDirY^2)
    if len < 0.01 then return end
    local dx = self.lastDirX / len
    local dy = self.lastDirY / len
    local facingAngle = math.atan2(dy, dx)

    local drawAngle = 0
    local sx = self.lastFlipX < 0 and -1 or 1
    local hx, hy

    if self.attackTimer > 0 then
        local progress = 1 - self.attackTimer / self.attackDuration
        local swingDir = self.lastFlipX < 0 and -1 or 1
        local swingAngle = math.sin(progress * math.pi) * math.rad(90) * swingDir
        local a = facingAngle + swingAngle
        hx = self.x + math.cos(a) * dist - camera.x
        hy = self.y + math.sin(a) * dist - camera.y
        drawAngle = swingAngle
    else
        hx = self.x + dx * dist - camera.x
        hy = self.y + dy * dist - camera.y
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(sheet, quads[1][1], hx, hy, drawAngle, sx, 1, 16, 16)
end

return Player
