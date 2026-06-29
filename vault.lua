-- vault.lua – Vault/chest system

local Items = require "items"

local Vault = {}
Vault.data = {}

Vault.spawnRates = {
    common    = { min=5, max=8 },
    epic      = { min=2, max=3 },
    legendary = { min=1, max=1 },
    random    = { min=3, max=5 },
}

Vault.randomTierChances = {
    common    = 0.55,
    epic      = 0.30,
    legendary = 0.15,
}

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = love.math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function isVaultAt(tx, ty)
    return Vault.data[ty] and Vault.data[ty][tx] ~= nil
end

function Vault:setVault(maze, tx, ty, tier)
    if not Vault.data[ty] then Vault.data[ty] = {} end
    Vault.data[ty][tx] = { tier = tier, opened = false, tx = tx, ty = ty }
    local val = ({ common=4, epic=5, legendary=6, random=7 })[tier] or 4
    maze.grid[ty][tx] = val
end

function Vault:placeAll(maze)
    Vault.data = {}

    -- 1. Scan grid for existing vault tiles (from templates)
    for y = 0, maze.rows - 1 do
        for x = 0, maze.cols - 1 do
            local v = maze.grid[y][x]
            if v >= 4 and v <= 7 then
                local tier = ({ [4]="common", [5]="epic", [6]="legendary", [7]="random" })[v] or "common"
                if not Vault.data[y] then Vault.data[y] = {} end
                Vault.data[y][x] = { tier = tier, opened = false, tx = x, ty = y }
            end
        end
    end

    -- 2. Legendary vault at treasure room centre
    if maze.treasureRoom then
        local cx, cy = maze.treasureRoom.cx, maze.treasureRoom.cy
        if not isVaultAt(cx, cy) then
            self:setVault(maze, cx, cy, "legendary")
        end
    end

    -- 3. Collect room centres (excluding safe & treasure)
    local roomCandidates = {}
    for _, r in ipairs(maze.rooms) do
        if r ~= maze.safeRoom and r ~= maze.treasureRoom
            and maze.grid[r.cy] and maze.grid[r.cy][r.cx] == 0
            and not isVaultAt(r.cx, r.cy) then
            table.insert(roomCandidates, { tx = r.cx, ty = r.cy })
        end
    end
    shuffle(roomCandidates)

    -- Epic vaults in room centres
    local epicCount = love.math.random(self.spawnRates.epic[1], self.spawnRates.epic[2])
    for i = 1, math.min(epicCount, #roomCandidates) do
        self:setVault(maze, roomCandidates[i].tx, roomCandidates[i].ty, "epic")
    end

    -- 4. Collect corridor tiles
    local corridorTiles = {}
    for y = 3, maze.rows - 4 do
        for x = 3, maze.cols - 4 do
            if maze.grid[y][x] == 0
                and (maze.gridType[y][x] == "spine" or maze.gridType[y][x] == "branch" or maze.gridType[y][x] == "loop")
                and not isVaultAt(x, y) then
                local tooClose = false
                for dy = -3, 3 do
                    for dx = -3, 3 do
                        if dy ~= 0 or dx ~= 0 then
                            if isVaultAt(x+dx, y+dy) then tooClose = true; break end
                        end
                    end
                    if tooClose then break end
                end
                if not tooClose then
                    table.insert(corridorTiles, { tx = x, ty = y })
                end
            end
        end
    end
    shuffle(corridorTiles)

    local idx = 1

    -- Common vaults
    local commonCount = love.math.random(self.spawnRates.common[1], self.spawnRates.common[2])
    for i = 1, math.min(commonCount, #corridorTiles) do
        while idx <= #corridorTiles and isVaultAt(corridorTiles[idx].tx, corridorTiles[idx].ty) do idx = idx + 1 end
        if idx > #corridorTiles then break end
        self:setVault(maze, corridorTiles[idx].tx, corridorTiles[idx].ty, "common")
        idx = idx + 1
    end

    -- Random vaults
    local randomCount = love.math.random(self.spawnRates.random[1], self.spawnRates.random[2])
    for i = 1, math.min(randomCount, #corridorTiles - idx + 1) do
        while idx <= #corridorTiles and isVaultAt(corridorTiles[idx].tx, corridorTiles[idx].ty) do idx = idx + 1 end
        if idx > #corridorTiles then break end
        self:setVault(maze, corridorTiles[idx].tx, corridorTiles[idx].ty, "random")
        idx = idx + 1
    end
end

function Vault:getVaultAt(tx, ty)
    if not Vault.data[ty] then return nil end
    return Vault.data[ty][tx]
end

function Vault:resolveTier()
    local r = love.math.random()
    local cumulative = 0
    for tier, chance in pairs(self.randomTierChances) do
        cumulative = cumulative + chance
        if r <= cumulative then return tier end
    end
    return "common"
end

function Vault:openVault(maze, tx, ty)
    local vault = self:getVaultAt(tx, ty)
    if not vault or vault.opened then return nil end
    vault.opened = true
    local tier = vault.tier == "random" and self:resolveTier() or vault.tier
    local itemId = Items.randomFromTier(tier)
    if maze.grid[ty] then maze.grid[ty][tx] = 0 end
    return itemId, tier
end

function Vault:playerOnVault(player, maze)
    local tx = math.floor(player.x / maze.tile)
    local ty = math.floor(player.y / maze.tile)
    local vault = self:getVaultAt(tx, ty)
    if vault and not vault.opened then return vault, tx, ty end
    return nil
end

return Vault
