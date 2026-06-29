-- maze.lua – Maze generator ported from the original HTML/JS version

local Perlin = require "perlin"

local Maze = {}
Maze.__index = Maze

-- Utility random helpers (inclusive integer, float)
local function rand(a, b) return love.math.random(a, b) end
local function randf(a, b) return a + love.math.random() * (b - a) end
local function hypot(x, y) return math.sqrt(x * x + y * y) end

function Maze:new(config)
    config = config or {}
    local self = setmetatable({}, Maze)
    self.config = config
    self.cols = config.cols or 140
    self.rows = config.rows or 140
    self.tile = config.tile or 28
    self.roomCount = config.roomCount or {8, 12}
    self.branchCount = config.branchCount or {4, 8}
    self.branchLen = config.branchLen or {8, 20}
    self.loopChance = config.loopChance or 0.7
    self.perlinThresh = config.perlinThresh or 0.25
    self.grid = {}
    self.gridType = {}
    self.gridHall = {}
    self.gridSpawnSafe = {}
    self.rooms = {}
    self.spinePath = {}
    self.branches = {}
    self.loops = {}
    self.safeRoom = nil
    self.treasureRoom = nil
    self.exitRoom = nil
    self.startRoom = nil
    self.exitCell = nil
    return self
end

function Maze:generate()
    -- initialise empty grids
    for y = 0, self.rows - 1 do
        self.grid[y] = {}
        self.gridType[y] = {}
        self.gridHall[y] = {}
        self.gridSpawnSafe[y] = {}
        for x = 0, self.cols - 1 do
            self.grid[y][x] = 1                -- wall
            self.gridType[y][x] = ""
            self.gridHall[y][x] = ""
            self.gridSpawnSafe[y][x] = false
        end
    end
    self:createRooms()
    self:buildSpine()
    self:buildBranches()
    self:buildLoops()
    self:carveRooms()
    self:degradeEdges()
    self:forceBorderRing()
    self:setExitCell()
end

function Maze:createRooms()
    local names = {A="Vacia", B="Pilares", C="MiniLab", D="Pozo", E="Safe", F="Relicario", G="Boveda", H="Condenados"}
    local count = rand(self.roomCount[1], self.roomCount[2])
    local margin = 6
    for i = 0, count - 1 do
        local w, h, type
        if i == 0 then
            type = 'E'
        elseif i == 1 then
            type = ({'F','G','H'})[rand(1,3)]
        else
            type = ({'A','A','B','B','C','D'})[rand(1,6)]
        end
        if type == 'A' then w, h = rand(5,8), rand(5,8)
        elseif type == 'B' then w, h = rand(6,9), rand(6,9)
        elseif type == 'C' then w, h = 7, 7
        elseif type == 'D' then w, h = rand(5,7), rand(5,7)
        elseif type == 'E' then w, h = rand(4,6), rand(5,7)
        elseif type == 'F' then w, h = 4, 4
        elseif type == 'G' then w, h = 6, 6
        elseif type == 'H' then w, h = 5, 5
        end
        local placed = false
        for attempt = 1, 15 do
            local x = rand(margin, self.cols - margin - w - 1)
            local y = rand(margin, self.rows - margin - h - 1)
            local overlap = false
            for _, r in ipairs(self.rooms) do
                if x < r.x + r.w + 3 and x + w + 3 > r.x and y < r.y + r.h + 3 and y + h + 3 > r.y then
                    overlap = true
                    break
                end
            end
            if not overlap then
                local room = {x = x, y = y, w = w, h = h, cx = math.floor(x + w / 2), cy = math.floor(y + h / 2), type = type, name = names[type]}
                table.insert(self.rooms, room)
                if type == 'E' then self.safeRoom = room end
                if type == 'F' or type == 'G' or type == 'H' then self.treasureRoom = room end
                placed = true
                break
            end
        end
        if not placed then break end
    end
    -- Determine start and exit rooms
    local candidates = {}
    for _, r in ipairs(self.rooms) do
        if r.type ~= 'E' and not (r.type == 'F' or r.type == 'G' or r.type == 'H') then
            table.insert(candidates, r)
        end
    end
    if #candidates >= 2 then
        self.startRoom = candidates[rand(1, #candidates)]
        local exitCandidates = {}
        for _, r in ipairs(candidates) do
            if r ~= self.startRoom then table.insert(exitCandidates, r) end
        end
        self.exitRoom = exitCandidates[rand(1, #exitCandidates)]
    else
        self.startRoom = self.rooms[1]
        self.exitRoom = self.rooms[#self.rooms]
    end
end

function Maze:buildSpine()
    local ordered = {self.startRoom}
    local remaining = {}
    for _, r in ipairs(self.rooms) do
        if r ~= self.startRoom and r ~= self.exitRoom then table.insert(remaining, r) end
    end
    local exitPos = rand(2, math.max(2, #remaining))
    while #remaining > 0 do
        local last = ordered[#ordered]
        local nearest = nil
        local nearDist = math.huge
        local nearIdx = nil
        for i, r in ipairs(remaining) do
            local d = hypot(r.cx - last.cx, r.cy - last.cy)
            if d < nearDist then
                nearDist = d
                nearest = r
                nearIdx = i
            end
        end
        table.insert(ordered, nearest)
        table.remove(remaining, nearIdx)
        if #ordered == exitPos and not self:contains(ordered, self.exitRoom) then
            table.insert(ordered, self.exitRoom)
            -- remove exitRoom from remaining if present
            for i = #remaining, 1, -1 do
                if remaining[i] == self.exitRoom then table.remove(remaining, i) break end
            end
        end
    end
    if not self:contains(ordered, self.exitRoom) then table.insert(ordered, self.exitRoom) end
    for i = 1, #ordered - 1 do
        self:carvePath(ordered[i].cx, ordered[i].cy, ordered[i+1].cx, ordered[i+1].cy, "spine")
    end
end

function Maze:contains(arr, val)
    for _, v in ipairs(arr) do if v == val then return true end end
    return false
end

function Maze:buildBranches()
    local branchCount = rand(self.branchCount[1], self.branchCount[2])
    for b = 1, branchCount do
        local startRoom = self.rooms[rand(1, #self.rooms)]
        local dirs = {{0,1},{0,-1},{1,0},{-1,0}}
        local dir = dirs[rand(1,4)]
        local len = rand(self.branchLen[1], self.branchLen[2])
        local path = {}
        local x, y = startRoom.cx, startRoom.cy
        local walked = 0
        for i = 1, len do
            x = x + dir[1]
            y = y + dir[2]
            if x < 2 or y < 2 or x >= self.cols-2 or y >= self.rows-2 then break end
            if walked > 3 and self.grid[y][x] == 0 and self.gridType[y][x] == "spine" then break end
            if love.math.random() < 0.3 then
                local nd = {}
                for _, d in ipairs(dirs) do
                    if d[1] ~= -dir[1] or d[2] ~= -dir[2] then table.insert(nd, d) end
                end
                dir = nd[rand(1, #nd)]
            end
            table.insert(path, {x=x, y=y})
            self.grid[y][x] = 0
            self.gridType[y][x] = "branch"
            local hallType = love.math.random() < 0.7 and "estrecho" or (love.math.random() < 0.67 and "doble" or "zigzag")
            self.gridHall[y][x] = hallType
            if hallType == "doble" then
                for dy2 = -1,1 do
                    for dx2 = -1,1 do
                        if math.abs(dx2) + math.abs(dy2) <= 1 then
                            local ny = y + dy2
                            local nx = x + dx2
                            if ny > 0 and nx > 0 and ny < self.rows-1 and nx < self.cols-1 then
                                self.grid[ny][nx] = 0
                                self.gridType[ny][nx] = "branch"
                                self.gridHall[ny][nx] = hallType
                            end
                        end
                    end
                end
            end
            walked = walked + 1
        end
        local deadEnd = love.math.random() < 0.5
        if #path > 0 then
            local last = path[#path]
            if not deadEnd then
                for dy = -1,1 do
                    for dx = -1,1 do
                        local ny = last.y + dy
                        local nx = last.x + dx
                        if ny > 0 and nx > 0 and ny < self.rows-1 and nx < self.cols-1 then
                            self.grid[ny][nx] = 0
                            self.gridType[ny][nx] = "branch"
                        end
                    end
                end
            end
            table.insert(self.branches, {path = path, deadEnd = deadEnd})
        end
    end
end

function Maze:buildLoops()
    if #self.branches < 2 then return end
    -- Máximo número de lazos basado en la cantidad de ramas
    local maxLoops = math.floor(#self.branches / 2)
    local created = 0
    while created < maxLoops and #self.branches >= 2 do
        if math.random() > self.loopChance then break end
        local b1 = self.branches[rand(1, #self.branches)]
        local b2 = self.branches[rand(1, #self.branches)]
        if b1 == b2 then
            -- intentar con otro par en la siguiente iteración
        else
            if #b1.path > 3 and #b2.path > 3 then
                local p1 = b1.path[math.floor(#b1.path/2)]
                local p2 = b2.path[math.floor(#b2.path/2)]
                self:carvePath(p1.x, p1.y, p2.x, p2.y, "loop")
                table.insert(self.loops, {path = {p1, p2}})
                created = created + 1
            end
        end
    end
end

function Maze:carvePath(x0, y0, x1, y1, typ)
    local x, y = x0, y0
    local hallType = love.math.random() < 0.7 and "estrecho" or (love.math.random() < 0.67 and "doble" or "zigzag")
    while x ~= x1 or y ~= y1 do
        for oy = -1,1 do
            for ox = -1,1 do
                local nx, ny = x+ox, y+oy
                if nx > 0 and ny > 0 and nx < self.cols-1 and ny < self.rows-1 and math.abs(ox)+math.abs(oy) <= 1 then
                    self.grid[ny][nx] = 0
                    if self.gridType[ny][nx] == "" then self.gridType[ny][nx] = typ end
                    if self.gridHall[ny][nx] == "" then self.gridHall[ny][nx] = hallType end
                end
            end
        end
        if love.math.random() < 0.15 then
            hallType = love.math.random() < 0.7 and "estrecho" or (love.math.random() < 0.67 and "doble" or "zigzag")
        end
        local dx = x1 - x
        local dy = y1 - y
        local moves = {}
        if dx > 0 then table.insert(moves, {1,0}) elseif dx < 0 then table.insert(moves, {-1,0}) end
        if dy > 0 then table.insert(moves, {0,1}) elseif dy < 0 then table.insert(moves, {0,-1}) end
        if love.math.random() < 0.25 then
            local dirs = {{0,1},{0,-1},{1,0},{-1,0}}
            local extra = dirs[rand(1,4)]
            if x+extra[1] > 1 and y+extra[2] > 1 and x+extra[1] < self.cols-2 and y+extra[2] < self.rows-2 then
                table.insert(moves, extra)
            end
        end
        local m = moves[rand(1, #moves)]
        x = x + m[1]
        y = y + m[2]
    end
end

function Maze:carveRooms()
    for _, r in ipairs(self.rooms) do
        for dy = -1,1 do
            for dx = -1,1 do
                local sy = r.cy + dy
                local sx = r.cx + dx
                if sy > 0 and sx > 0 and sy < self.rows-1 and sx < self.cols-1 then
                    self.gridSpawnSafe[sy][sx] = true
                end
            end
        end
    end
    for _, r in ipairs(self.rooms) do
        if r.type == 'A' then self:carveEmpty(r)
        elseif r.type == 'B' then self:carvePillars(r)
        elseif r.type == 'C' then self:carveMiniLab(r)
        elseif r.type == 'D' then self:carvePit(r)
        elseif r.type == 'E' then self:carveSafe(r)
        elseif r.type == 'F' then self:carveRelicario(r)
        elseif r.type == 'G' then self:carveBoveda(r)
        elseif r.type == 'H' then self:carveCondenados(r)
        end
    end
end

function Maze:carveEmpty(r)
    for y = r.y, r.y + r.h - 1 do
        for x = r.x, r.x + r.w - 1 do
            if y > 0 and x > 0 and y < self.rows-1 and x < self.cols-1 then
                self.grid[y][x] = 0
                self.gridType[y][x] = "room"
            end
        end
    end
end

function Maze:carvePillars(r)
    self:carveEmpty(r)
    for py = r.y + 2, r.y + r.h - 2, 3 do
        for px = r.x + 2, r.x + r.w - 2, 3 do
            if py > 0 and py+1 < self.rows-1 and px > 0 and px+1 < self.cols-1 then
                if not self.gridSpawnSafe[py][px] and not self.gridSpawnSafe[py][px+1]
                   and not self.gridSpawnSafe[py+1][px] and not self.gridSpawnSafe[py+1][px+1] then
                    self.grid[py][px] = 1
                    self.grid[py][px+1] = 1
                    self.grid[py+1][px] = 1
                    self.grid[py+1][px+1] = 1
                end
            end
        end
    end
end

function Maze:carveMiniLab(r)
    self:carveEmpty(r)
    local cx, cy = r.cx, r.cy
    local mode = rand(0,1)
    if mode == 0 then
        for y = r.y + 1, r.y + r.h - 2 do
            if y > 0 and y < self.rows-1 and cx > 0 and cx < self.cols-1 then
                if not self.gridSpawnSafe[y][cx] then self.grid[y][cx] = 1 end
            end
        end
        for x = r.x + 1, r.x + r.w - 2 do
            if cy > 0 and cy < self.rows-1 and x > 0 and x < self.cols-1 then
                if not self.gridSpawnSafe[cy][x] then self.grid[cy][x] = 1 end
            end
        end
    else
        for i = -2,2 do
            local yy = cy + i
            local xx = cx + i
            if yy > 0 and yy < self.rows-1 and xx > 0 and xx < self.cols-1 and not self.gridSpawnSafe[yy][xx] then
                self.grid[yy][xx] = 1
            end
            local xx2 = cx - i
            if yy > 0 and yy < self.rows-1 and xx2 > 0 and xx2 < self.cols-1 and not self.gridSpawnSafe[yy][xx2] then
                self.grid[yy][xx2] = 1
            end
        end
    end
end

function Maze:carvePit(r)
    self:carveEmpty(r)
    local px = math.floor(r.x + r.w/2) - 1
    local py = math.floor(r.y + r.h/2) - 1
    for y = py, py + 2 do
        for x = px, px + 2 do
            if y > 0 and x > 0 and y < self.rows-1 and x < self.cols-1 and not self.gridSpawnSafe[y][x] then
                self.grid[y][x] = 1
            end
        end
    end
end

function Maze:carveSafe(r)
    self:carveEmpty(r)
    local lights = {{x=r.x+1, y=r.y+1}, {x=r.x+r.w-2, y=r.y+r.h-2}, {x=r.cx, y=r.cy}}
    for _, l in ipairs(lights) do
        if l.y > 0 and l.x > 0 and l.y < self.rows-1 and l.x < self.cols-1 then
            self.grid[l.y][l.x] = 3
        end
    end
end

function Maze:carveRelicario(r)
    self:carveEmpty(r)
    if r.cy > 0 and r.cx > 0 and r.cy < self.rows-1 and r.cx < self.cols-1 and not self.gridSpawnSafe[r.cy][r.cx] then
        self.grid[r.cy][r.cx] = 4
    end
end

function Maze:carveBoveda(r)
    self:carveEmpty(r)
    local corners = {{x=r.x+1, y=r.y+1}, {x=r.x+r.w-2, y=r.y+1}, {x=r.x+1, y=r.y+r.h-2}, {x=r.x+r.w-2, y=r.y+r.h-2}}
    for _, c in ipairs(corners) do
        if c.y > 0 and c.x > 0 and c.y < self.rows-1 and c.x < self.cols-1 then
            if not self.gridSpawnSafe[c.y][c.x] then self.grid[c.y][c.x] = 1 end
        end
    end
end

function Maze:carveCondenados(r)
    self:carveEmpty(r)
    local px = math.floor(r.x + r.w/2) - 1
    local py = math.floor(r.y + r.h/2) - 1
    for y = py, py + 1 do
        for x = px, px + 1 do
            if y > 0 and x > 0 and y < self.rows-1 and x < self.cols-1 and not self.gridSpawnSafe[y][x] then
                self.grid[y][x] = 1
            end
        end
    end
end

function Maze:degradeEdges()
    local P = Perlin:new(love.math.random())
    for y = 2, self.rows - 3 do
        for x = 2, self.cols - 3 do
            if self.grid[y][x] == 1 and self.gridType[y][x] == "" then
                if P:noise2d(x * 0.14, y * 0.14) < self.perlinThresh then
                    self.grid[y][x] = 0
                end
            end
        end
    end
end

function Maze:forceBorderRing()
    for x = 0, self.cols - 1 do
        self.grid[0][x] = 0
        self.grid[self.rows-1][x] = 0
        self.gridType[0][x] = "corridor"
        self.gridType[self.rows-1][x] = "corridor"
    end
    for y = 0, self.rows - 1 do
        self.grid[y][0] = 0
        self.grid[y][self.cols-1] = 0
        self.gridType[y][0] = "corridor"
        self.gridType[y][self.cols-1] = "corridor"
    end
end

function Maze:setExitCell()
    if not self.exitRoom then return end
    -- Ensure exit coordinates are inside the grid bounds
    local ex = math.max(0, math.min(self.exitRoom.cx, self.cols - 1))
    local ey = math.max(0, math.min(self.exitRoom.cy, self.rows - 1))
    self.exitCell = {x = ex, y = ey}
    if self.grid[ey] then
        self.grid[ey][ex] = 2
    end
end

function Maze:getLocationInfo(px, py)
    local tx = math.floor(px / self.tile)
    local ty = math.floor(py / self.tile)
    if tx < 0 or ty < 0 or tx >= self.cols or ty >= self.rows then
        return {sala = "--", pasillo = "--", type = ""}
    end
    for _, r in ipairs(self.rooms) do
        if tx >= r.x and tx < r.x + r.w and ty >= r.y and ty < r.y + r.h then
            return {sala = r.name, pasillo = "--", type = "room"}
        end
    end
    local hall = self.gridHall[ty][tx] or "estrecho"
    local hallName = hall == "estrecho" and "Estrecho" or (hall == "doble" and "Doble" or "Zigzag")
    return {sala = "--", pasillo = hallName, type = self.gridType[ty][tx] or "desconocido"}
end

function Maze:isWall(px, py)
    local tx = math.floor(px / self.tile)
    local ty = math.floor(py / self.tile)
    if tx < 0 or ty < 0 or tx >= self.cols or ty >= self.rows then return true end
    return self.grid[ty][tx] == 1
end

function Maze:isExit(px, py)
    if not self.exitCell then return false end
    local tx = math.floor(px / self.tile)
    local ty = math.floor(py / self.tile)
    return tx == self.exitCell.x and ty == self.exitCell.y
end

function Maze:isSafe(px, py)
    local tx = math.floor(px / self.tile)
    local ty = math.floor(py / self.tile)
    if not self.safeRoom then return false end
    return tx >= self.safeRoom.x and tx < self.safeRoom.x + self.safeRoom.w and ty >= self.safeRoom.y and ty < self.safeRoom.y + self.safeRoom.h
end

function Maze:hasLineOfSight(x0, y0, x1, y1)
    local t = self.tile
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    while true do
        local tx = math.floor(x0 / t)
        local ty = math.floor(y0 / t)
        if tx < 0 or ty < 0 or tx >= self.cols or ty >= self.rows or self.grid[ty][tx] == 1 then return false end
        if math.abs(x0 - x1) < t and math.abs(y0 - y1) < t then return true end
        local e2 = err * 2
        if e2 > -dy then err = err - dy; x0 = x0 + sx * t * 0.5 end
        if e2 < dx then err = err + dx; y0 = y0 + sy * t * 0.5 end
    end
end

function Maze:draw(camera)
    local t = self.tile
    for y = 0, self.rows - 1 do
        for x = 0, self.cols - 1 do
            local px = x * t - camera.x
            local py = y * t - camera.y
            if px < -t or py < -t or px > love.graphics.getWidth() or py > love.graphics.getHeight() then
                -- skip off‑screen tiles
            else
                local col
                local val = self.grid[y][x]
                if val == 1 then col = {0.176,0.176,0.227}          -- #2d2d3a wall
                elseif val == 2 then col = {1,0.867,0}                -- #ffdd00 exit
                elseif val == 3 then col = {0.267,0.533,0.667}        -- #4488aa safe light
                elseif val == 4 then col = {0.533,0.4,0.267}          -- #886644 relic
                else col = {0.039,0.039,0.039}                       -- #0a0a0a floor
                end
                love.graphics.setColor(col)
                love.graphics.rectangle("fill", px, py, t, t)
            end
        end
    end
end

return Maze
