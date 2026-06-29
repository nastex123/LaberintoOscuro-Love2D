-- chest_animation.lua – Horizontal wheel fortune animation

local Items = require "items"

local ChestAnim = {
    state = "idle",
    scrollPos = 0,
    speed = 0,
    displayItems = {},
    targetItem = nil,
    lastItemId = nil,
    timer = 0,
    itemWidth = 90,
    centerX = 0,
    centerY = 0,
}

function ChestAnim:start(tier)
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
    for rep = 1, 12 do
        for _, id in ipairs(pool) do
            local def = Items.defs[id]
            table.insert(self.displayItems, { id = id, nombre = def.nombre, color = def.color })
        end
    end

    self.targetItem = pool[love.math.random(1, #pool)]
    self.scrollPos = 0
    self.speed = 3000
    self.state = "spinning"
    self.lastItemId = nil
    self.tierName = ({ common="Común", epic="Épico", legendary="Legendario", random="Aleatorio" })[tier] or tier

    local sw, sh = love.graphics.getDimensions()
    self.centerX = sw / 2
    self.centerY = sh / 2
end

function ChestAnim:update(dt)
    if self.state == "idle" or self.state == "done" then return end

    if self.state == "spinning" then
        self.speed = self.speed * (1 - dt * 2.2)
        if self.speed < 0 then self.speed = 0 end
        self.scrollPos = self.scrollPos + self.speed * dt

        if self.speed < 30 then
            local targetIdx
            for i, item in ipairs(self.displayItems) do
                if item.id == self.targetItem then
                    targetIdx = i
                    break
                end
            end
            if targetIdx then
                local targetPos = (targetIdx - 1) * self.itemWidth + self.itemWidth / 2
                self.scrollPos = targetPos - self.centerX
            end
            self.state = "result"
            self.timer = 1.8
        end
    elseif self.state == "result" then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self.state = "done"
        end
    end
end

function ChestAnim:draw()
    if self.state == "idle" then return end
    local sw, sh = love.graphics.getDimensions()

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    local tierName = self.tierName or ""
    local title = (self.state == "result" or self.state == "done")
        and ("¡Has encontrado!  [" .. tierName .. "]")
        or "Abriendo cofre..."
    love.graphics.printf(title, 0, self.centerY - 130, sw, "center")

    local trackY = self.centerY - 40
    local trackH = 100

    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", 0, trackY, sw, trackH)
    love.graphics.setColor(0.3, 0.3, 0.4, 0.8)
    love.graphics.rectangle("line", 0, trackY, sw, trackH)

    love.graphics.setFont(love.graphics.newFont(12))
    for idx, item in ipairs(self.displayItems) do
        local ix = (idx - 1) * self.itemWidth - self.scrollPos
        local iy = trackY + trackH / 2

        if ix > -self.itemWidth and ix < sw + self.itemWidth then
            local sqSize = 50
            local sqX = ix - sqSize / 2
            local sqY = iy - sqSize / 2 - 8
            local isResult = (self.state == "result" or self.state == "done") and item.id == self.targetItem

            if isResult then
                love.graphics.setColor(1, 0.8, 0)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", sqX - 4, sqY - 4, sqSize + 8, sqSize + 8)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 0, 0.25)
                love.graphics.rectangle("fill", sqX - 4, sqY - 4, sqSize + 8, sqSize + 8)
            end

            love.graphics.setColor(item.color)
            love.graphics.rectangle("fill", sqX, sqY, sqSize, sqSize)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("line", sqX, sqY, sqSize, sqSize)

            if isResult then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            love.graphics.printf(item.nombre, ix - self.itemWidth / 2, sqY + sqSize + 4, self.itemWidth, "center")
        end
    end

    -- Centre indicator arrow
    love.graphics.setColor(1, 0.5, 0)
    love.graphics.setLineWidth(3)
    love.graphics.line(self.centerX, trackY, self.centerX, trackY + trackH)
    love.graphics.setLineWidth(1)

    if self.state == "result" or self.state == "done" then
        local def = Items.defs[self.targetItem]
        if def then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(love.graphics.newFont(18))
            love.graphics.printf(def.nombre .. " — " .. def.desc, 0, self.centerY + 70, sw, "center")
        end
    end

    if self.state == "done" then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.printf("Presiona E para cerrar", 0, self.centerY + 100, sw, "center")
    end
end

return ChestAnim
