-- chest_animation.lua – Horizontal wheel fortune animation (MODO COMPLETO)

local Items = require "items"

local function easeOutCubic(t) return 1 - (1 - t)^3 end
local function easeInQuad(t) return t * t end

local shineShader = love.graphics.newShader("shaders/shine.glsl")

local ChestAnim = {
    state = "idle",
    scrollPos = 0, speed = 0, displayItems = {}, targetItem = nil,
    timer = 0, itemWidth = 90, centerX = 0, centerY = 0,
    offsetX = 0, poolSize = 0,
    stopProgress = 0, stopStartPos = 0, stopTargetPos = 0,
    particles = {}, confetti = {},
    flashAlpha = 0, flashColor = {1,1,1},
    shineTime = 0,
    closeStartY = 0, closeEndY = 0, closeProgress = 1,
}

function ChestAnim:start(tier, forcedItemId, offsetX)
    local pool
    if tier == "random" then
        pool = {}
        for _, ids in pairs(Items.pools) do
            for _, id in ipairs(ids) do table.insert(pool, id) end
        end
    else
        pool = Items.pools[tier] or {}
    end
    if #pool == 0 then return end

    self.displayItems = {}
    for _, id in ipairs(pool) do
        local def = Items.defs[id]
        table.insert(self.displayItems, { id = id, nombre = def.nombre, color = def.color })
    end
    self.poolSize = #self.displayItems

    self.targetItem = forcedItemId or pool[love.math.random(1, self.poolSize)]
    self.scrollPos = 0
    self.speed = 3000
    self.state = "spinning"
    self.tierName = ({ common="Común", epic="Épico", legendary="Legendario", random="Aleatorio" })[tier] or tier

    local sw, sh = love.graphics.getDimensions()
    self.offsetX = offsetX or 0
    self.centerX = sw / 2
    self.centerY = sh / 2

    self.particles = {}
    self.confetti = {}
    self.stopProgress = 0
    self.flashAlpha = 0
    self.shineTime = 0
end

function ChestAnim:close()
    if self.state == "done" or self.state == "result" then
        self.state = "closing"
        self.closeStartY = self.centerY
        self.closeEndY = self.centerY + 500
        self.closeProgress = 0
    end
end

function ChestAnim:update(dt)
    if self.state == "idle" then return end

    if self.state == "spinning" then
        local speedFactor = 1 - dt * 1.8
        if speedFactor < 0 then speedFactor = 0 end
        self.speed = self.speed * speedFactor

        if self.speed < 30 then
            local targetIdx
            for i, item in ipairs(self.displayItems) do
                if item.id == self.targetItem then
                    targetIdx = i
                    break
                end
            end
            if targetIdx then
                local targetScrollPos = (targetIdx - 0.5) * self.itemWidth - (self.centerX - self.offsetX)
                local totalWidth = self.itemWidth * self.poolSize
                local cycles = math.floor((self.scrollPos - targetScrollPos) / totalWidth) + 1
                targetScrollPos = targetScrollPos + cycles * totalWidth

                self.stopStartPos = self.scrollPos
                self.stopTargetPos = targetScrollPos
                self.stopProgress = 0
                self.state = "stopping"
            end
        else
            self.scrollPos = self.scrollPos + self.speed * dt
        end

    elseif self.state == "stopping" then
        self.stopProgress = self.stopProgress + dt * 2.5
        if self.stopProgress >= 1 then
            self.stopProgress = 1
            self.scrollPos = self.stopTargetPos
            self.state = "result"
            self.timer = 1.8
            self.shineTime = 0

            self:spawnParticles()
            self:spawnConfetti()

            local tierColors = { common={0.6,0.6,0.6}, epic={0.6,0.3,0.8}, legendary={1,0.6,0}, random={1,1,1} }
            self.flashColor = tierColors[self.tierName] or {1,1,1}
            self.flashAlpha = 0.8
        else
            local t = easeOutCubic(self.stopProgress)
            self.scrollPos = self.stopStartPos + (self.stopTargetPos - self.stopStartPos) * t
        end

    elseif self.state == "result" then
        self.timer = self.timer - dt
        self.shineTime = self.shineTime + dt
        self:updateParticles(dt)
        self:updateConfetti(dt)

        if self.flashAlpha > 0 then
            self.flashAlpha = self.flashAlpha - dt * 0.8
            if self.flashAlpha < 0 then self.flashAlpha = 0 end
        end
        if self.timer <= 0 then
            self.state = "done"
        end

    elseif self.state == "closing" then
        self.closeProgress = self.closeProgress + dt * 2.5
        if self.closeProgress >= 1 then
            self.centerY = self.closeEndY
            self.state = "idle"
        else
            local t = easeInQuad(self.closeProgress)
            self.centerY = self.closeStartY + (self.closeEndY - self.closeStartY) * t
        end
    end
end

function ChestAnim:spawnParticles()
    local def = Items.defs[self.targetItem]
    local color = def and def.color or {1,1,1}
    for i = 1, 30 do
        local angle = love.math.random() * 2 * math.pi
        local speed = love.math.random(100, 300)
        table.insert(self.particles, {
            x = self.centerX + self.offsetX, y = self.centerY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            radius = love.math.random(4, 8),
            life = love.math.random(0.5, 1.2), maxLife = love.math.random(0.5, 1.2),
            color = {color[1], color[2], color[3], 1},
        })
    end
end

function ChestAnim:spawnConfetti()
    local sw, sh = love.graphics.getDimensions()
    local colors = {{1,0,0},{0,1,0},{0,0,1},{1,1,0},{1,0,1},{0,1,1},{1,1,1}}
    for i = 1, 80 do
        table.insert(self.confetti, {
            x = love.math.random(0, sw),
            y = love.math.random(-sh, -50),
            w = love.math.random(6, 12),
            h = love.math.random(6, 12),
            vx = love.math.random(-200, 200),
            vy = love.math.random(200, 800),
            rot = love.math.random() * 2 * math.pi,
            rot_speed = love.math.random(-5, 5),
            life = love.math.random(0.8, 2.0), maxLife = love.math.random(0.8, 2.0),
            color = colors[love.math.random(1, #colors)]
        })
    end
end

function ChestAnim:updateParticles(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 100 * dt
        p.life = p.life - dt
        p.radius = p.radius * (1 + dt * 2)
        if p.life <= 0 then table.remove(self.particles, i) end
    end
end

function ChestAnim:updateConfetti(dt)
    for i = #self.confetti, 1, -1 do
        local c = self.confetti[i]
        c.x = c.x + c.vx * dt
        c.y = c.y + c.vy * dt
        c.vy = c.vy + 300 * dt
        c.rot = c.rot + c.rot_speed * dt
        c.life = c.life - dt
        if c.life <= 0 then table.remove(self.confetti, i) end
    end
end

function ChestAnim:draw()
    if self.state == "idle" then return end
    local sw, sh = love.graphics.getDimensions()

    if self.flashAlpha > 0 then
        love.graphics.setColor(self.flashColor[1], self.flashColor[2], self.flashColor[3], self.flashAlpha)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    local alpha = (self.state == "spinning" or self.state == "stopping") and 0.75 or 0.85
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    for _, c in ipairs(self.confetti) do
        local alpha = math.max(0, c.life / c.maxLife)
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], alpha)
        love.graphics.push()
        love.graphics.translate(c.x, c.y)
        love.graphics.rotate(c.rot)
        love.graphics.rectangle("fill", -c.w/2, -c.h/2, c.w, c.h)
        love.graphics.pop()
    end

    for _, p in ipairs(self.particles) do
        local alpha = math.max(0, p.life / p.maxLife)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.line(p.x, p.y, p.x - p.vx * 0.08, p.y - p.vy * 0.08)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f24)
    local tierName = self.tierName or ""
    local title = (self.state == "result" or self.state == "done" or self.state == "closing")
        and ("¡Has encontrado!  [" .. tierName .. "]")
        or "Abriendo cofre..."
    love.graphics.printf(title, 0, self.centerY - 130, sw, "center")

    local trackY = self.centerY - 40
    local trackH = 100

    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", 0, trackY, sw, trackH)
    love.graphics.setColor(0.3, 0.3, 0.4, 0.8)
    love.graphics.rectangle("line", 0, trackY, sw, trackH)

    love.graphics.setFont(fonts.f12)

    local startX = -self.itemWidth * 2
    local endX = sw + self.itemWidth * 2
    local x = startX
    while x < endX do
        local idx = math.floor((x + self.scrollPos) / self.itemWidth) % self.poolSize + 1
        local item = self.displayItems[idx]

        local ix = x + self.offsetX
        local iy = trackY + trackH / 2

        local sqSize = 50
        local sqX = ix - sqSize / 2
        local sqY = iy - sqSize / 2 - 8
        local isResult = (self.state == "result" or self.state == "done" or self.state == "closing") and item.id == self.targetItem

        if isResult then
            love.graphics.setColor(1, 0.8, 0, 0.5)
            love.graphics.rectangle("fill", sqX - 8, sqY - 8, sqSize + 16, sqSize + 16)
            love.graphics.setColor(1, 1, 0, 0.25)
            love.graphics.rectangle("fill", sqX - 4, sqY - 4, sqSize + 8, sqSize + 8)

            if Items.defs[item.id] then
                local tierColor = { common={0.6,0.6,0.6}, epic={0.6,0.3,0.8}, legendary={1,0.6,0} }
                local tc = tierColor[Items.defs[item.id].tier] or {1,1,1}
                love.graphics.setColor(tc[1], tc[2], tc[3], 0.3)
                love.graphics.rectangle("fill", sqX, sqY, sqSize, sqSize)
            end

            local pulse = 1 + 0.15 * math.abs(math.sin(self.shineTime * 10))
            local cx, cy = sqX + sqSize/2, sqY + sqSize/2

            love.graphics.setShader(shineShader)
            shineShader:send("u_time", self.shineTime)
            shineShader:send("u_width", sqSize)

            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(pulse, pulse)
            love.graphics.setColor(item.color)
            love.graphics.rectangle("fill", -sqSize/2, -sqSize/2, sqSize, sqSize)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("line", -sqSize/2, -sqSize/2, sqSize, sqSize)
            love.graphics.pop()

            love.graphics.setShader()

            love.graphics.setColor(1, 0.8, 0)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", sqX - 4, sqY - 4, sqSize + 8, sqSize + 8)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(item.color)
            love.graphics.rectangle("fill", sqX, sqY, sqSize, sqSize)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("line", sqX, sqY, sqSize, sqSize)
        end

        if isResult then love.graphics.setColor(1, 1, 1) else love.graphics.setColor(0.8, 0.8, 0.8) end
        love.graphics.printf(item.nombre, ix - self.itemWidth / 2, sqY + sqSize + 4, self.itemWidth, "center")

        x = x + self.itemWidth
    end

    local arrowAlpha = (self.state == "result" or self.state == "done" or self.state == "closing") and (0.6 + 0.4 * math.sin(love.timer.getTime()*4)) or 1
    love.graphics.setColor(1, 0.5, 0, arrowAlpha)
    love.graphics.setLineWidth(3)
    love.graphics.line(self.centerX, trackY, self.centerX, trackY + trackH)
    love.graphics.setLineWidth(1)

    if self.state == "result" or self.state == "done" or self.state == "closing" then
        local def = Items.defs[self.targetItem]
        if def then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f18)
            love.graphics.printf(def.nombre .. " — " .. def.desc, 0, self.centerY + 70, sw, "center")
        end
    end

    if self.state == "done" or self.state == "closing" then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(fonts.f14)
        love.graphics.printf("Presiona E para cerrar", 0, self.centerY + 100, sw, "center")
    end
end

return ChestAnim
