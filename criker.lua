-- criker.lua – Enemy (hunter) AI implementation

local Criker = {}
local function rand(a,b) return love.math.random(a,b) end
Criker.__index = Criker

function Criker:new()
    local self = setmetatable({}, Criker)
    self.x = 0
    self.y = 0
    self.r = 11
    self.speed = 65
    self.active = false
    self.state = "patrol"
    self.targetX = 0
    self.targetY = 0
    self.alertTimer = 0
    self.searchTimer = 0
    self.patrolDir = {x = 0, y = 0}
    self.patrolChangeTimer = 0
    self.bangTimer = 0
    self.bangScale = 0
    self.stunTimer = 0
    return self
end

-- Helper distance function
local function dist2(ax, ay, bx, by)
    return math.sqrt((ax - bx)^2 + (ay - by)^2)
end

function Criker:spawnValidated(maze)
    if not maze.treasureRoom then
        self:spawnRandom(maze)
        return
    end
    local t = maze.treasureRoom
    local candidates = {}
    for dy = -3, t.h + 2 do
        for dx = -3, t.w + 2 do
            local tx = t.x + dx
            local ty = t.y + dy
            if tx > 0 and ty > 0 and tx < maze.cols-1 and ty < maze.rows-1 and maze.grid[ty][tx] == 0 then
                local d = dist2(tx * maze.tile, ty * maze.tile, player.x, player.y)
                table.insert(candidates, {x = tx, y = ty, dist = d})
            end
        end
    end
    if #candidates > 0 then
        table.sort(candidates, function(a, b) return a.dist > b.dist end)
        local c = candidates[1]
        self.x = (c.x + 0.5) * maze.tile
        self.y = (c.y + 0.5) * maze.tile
    else
        self:spawnRandom(maze)
    end
    self.active = true
    self.state = "patrol"
    self.patrolChangeTimer = 0
    self.bangTimer = 0
end

function Criker:spawnRandom(maze)
    local attempts = 0
    while attempts < 50 do
        local x = rand(2, maze.cols-3)
        local y = rand(2, maze.rows-3)
        if maze.grid[y][x] == 0 then
            self.x = (x + 0.5) * maze.tile
            self.y = (y + 0.5) * maze.tile
            break
        end
        attempts = attempts + 1
    end
    if attempts >= 50 then
        self.x = 2 * maze.tile
        self.y = 2 * maze.tile
    end
    self.active = true
    self.state = "patrol"
end

function Criker:stun(duration)
    self.stunTimer = duration
    self.state = "patrol"
end

function Criker:update(player, maze, dt)
    if not self.active then return end
    if self.stunTimer > 0 then
        self.stunTimer = self.stunTimer - dt
        return
    end
    local DETECT_RADIUS = 145
    local LOSE_RADIUS = 200
    local CHASE_SPEED = 95
    local SEARCH_SPEED = 50
    local PATROL_SPEED = 35
    local SEARCH_TIME = 2.5

    local dx = player.x - self.x
    local dy = player.y - self.y
    local d = math.sqrt(dx*dx + dy*dy)
    local canSee = false
    if d < DETECT_RADIUS then
        canSee = maze:hasLineOfSight(self.x, self.y, player.x, player.y)
    end

    if maze:isSafe(self.x, self.y) then
        self.state = "patrol"
        local sx = (maze.safeRoom.cx + 0.5) * maze.tile
        local sy = (maze.safeRoom.cy + 0.5) * maze.tile
        local sd = dist2(self.x, self.y, sx, sy)
        if sd > 0 then
            self.x = self.x + (self.x - sx) / sd * 2
            self.y = self.y + (self.y - sy) / sd * 2
        end
        return
    end

    if canSee and self.state ~= "chase" and self.state ~= "alert" then
        self.state = "alert"
        self.alertTimer = 0.3
        self.bangTimer = 0.3
        self.bangScale = 1.5
        self.targetX = player.x
        self.targetY = player.y
    end

    if self.bangTimer > 0 then
        self.bangTimer = self.bangTimer - dt
        self.bangScale = math.max(0, self.bangScale - dt * 3)
    end

    if self.state == "alert" then
        self.alertTimer = self.alertTimer - dt
        if self.alertTimer <= 0 then self.state = "chase" end
    elseif self.state == "chase" then
        if not canSee or d > LOSE_RADIUS then
            self.state = "search"
            self.searchTimer = SEARCH_TIME
            self.targetX = player.x
            self.targetY = player.y
        else
            self.targetX = player.x
            self.targetY = player.y
            local spd = d < 120 and 110 or CHASE_SPEED
            local dirDist = dist2(self.targetX, self.targetY, self.x, self.y)
            if dirDist > 0 then
                self.x = self.x + (self.targetX - self.x) / dirDist * spd * dt
                self.y = self.y + (self.targetY - self.y) / dirDist * spd * dt
            end
        end
    elseif self.state == "search" then
        self.searchTimer = self.searchTimer - dt
        if canSee then
            self.state = "alert"
            self.alertTimer = 0.3
            self.bangTimer = 0.3
            self.bangScale = 1.5
        elseif self.searchTimer <= 0 then
            self.state = "patrol"
        else
            local dToTarget = dist2(self.targetX, self.targetY, self.x, self.y)
            if dToTarget > 10 then
                if dToTarget > 0 then
                    self.x = self.x + (self.targetX - self.x) / dToTarget * SEARCH_SPEED * dt
                    self.y = self.y + (self.targetY - self.y) / dToTarget * SEARCH_SPEED * dt
                end
            else
                self.patrolDir = {x = 0, y = 0}
            end
        end
    elseif self.state == "patrol" then
        if canSee then
            self.state = "alert"
            self.alertTimer = 0.3
            self.bangTimer = 0.3
            self.bangScale = 1.5
        else
            self.patrolChangeTimer = self.patrolChangeTimer - dt
            if self.patrolChangeTimer <= 0 then
                self.patrolChangeTimer = 1.5 + math.random() * 2
                local dirs = {{0,1},{0,-1},{1,0},{-1,0}}
                local d = dirs[rand(1,4)]
                self.patrolDir = {x = d[1], y = d[2]}
            end
            local nx = self.x + self.patrolDir.x * PATROL_SPEED * dt
            local ny = self.y + self.patrolDir.y * PATROL_SPEED * dt
            if not maze:isWall(nx, self.y) then self.x = nx end
            if not maze:isWall(self.x, ny) then self.y = ny end
        end
    end
end

function Criker:draw(camera)
    if not self.active then return end
    local sx = self.x - camera.x
    local sy = self.y - camera.y
    if self.stunTimer > 0 then love.graphics.setColor(0.5,0.5,0.8) -- stunned
    elseif self.state == "chase" then love.graphics.setColor(1,0,0) -- #ff3333 approximated
    elseif self.state == "alert" then love.graphics.setColor(1,0.53,0) -- #ff8800 approximated
    elseif self.state == "search" then love.graphics.setColor(1,0.4,0.4) -- #ff6666 approximated
    else love.graphics.setColor(0.67,0.27,0.27) -- #aa4444 approximated
    end
    love.graphics.circle("fill", sx, sy, self.r)
    if self.bangTimer > 0 then
        love.graphics.push()
        love.graphics.translate(sx, sy - 25)
        love.graphics.scale(self.bangScale, self.bangScale)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(22))
        love.graphics.printf("!", 0, 0, 100, "center")
        love.graphics.pop()
    end
end

return Criker
