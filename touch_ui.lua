-- touch_ui.lua – Virtual joystick + action buttons for mobile

local TouchUI = {}
TouchUI.__index = TouchUI

-- ============================================================================
-- Joystick virtual dinámico
-- ============================================================================
local Joystick = {}
Joystick.__index = Joystick

function Joystick.new()
    return setmetatable({
        x = 0, y = 0,           -- center (se establece al primer toque)
        radius = 80,
        thumbRadius = 32,
        dx = 0, dy = 0,         -- output: -1 a 1
        active = false,
        touchId = nil,
        baseAlpha = 0.25,
        thumbAlpha = 0.6,
    }, Joystick)
end

function Joystick:touchPressed(id, tx, ty)
    if self.active then return end  -- ya tiene un dedo
    -- Solo activar en la mitad izquierda de la pantalla
    local sw = love.graphics.getWidth()
    if tx > sw * 0.45 then return end
    self.active = true
    self.touchId = id
    self.x = tx
    self.y = ty
    self:clamp(tx, ty)
end

function Joystick:touchMoved(id, tx, ty)
    if self.active and self.touchId == id then
        self:clamp(tx, ty)
    end
end

function Joystick:touchReleased(id)
    if self.active and self.touchId == id then
        self.active = false
        self.touchId = nil
        self.dx = 0
        self.dy = 0
    end
end

function Joystick:clamp(tx, ty)
    local dx = tx - self.x
    local dy = ty - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    -- Deadzone
    if dist < self.radius * 0.05 then
        self.dx = 0
        self.dy = 0
        return
    end
    if dist > self.radius then
        dx = dx / dist * self.radius
        dy = dy / dist * self.radius
        dist = self.radius
    end
    self.dx = dx / self.radius
    self.dy = dy / self.radius
end

function Joystick:draw()
    if not self.active then return end
    -- Base circle
    love.graphics.setColor(1, 1, 1, self.baseAlpha)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(1, 1, 1, self.baseAlpha + 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius)
    -- Thumb
    local tx = self.x + self.dx * self.radius
    local ty = self.y + self.dy * self.radius
    love.graphics.setColor(1, 1, 1, self.thumbAlpha)
    love.graphics.circle("fill", tx, ty, self.thumbRadius)
    love.graphics.setColor(1, 1, 1, self.thumbAlpha + 0.2)
    love.graphics.circle("line", tx, ty, self.thumbRadius)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- Botón de acción
-- ============================================================================
local Button = {}
Button.__index = Button

function Button.new(label, x, y, radius)
    return setmetatable({
        label = label,
        x = x, y = y,
        radius = radius or 38,
        pressed = false,
        wasPressed = false,   -- true solo en el frame que se presionó
        touchId = nil,
        color = {1, 1, 1},
        pressColor = {0.4, 0.8, 1},
    }, Button)
end

function Button:touchPressed(id, tx, ty)
    if self.pressed then return end
    local dx = tx - self.x
    local dy = ty - self.y
    if math.sqrt(dx * dx + dy * dy) <= self.radius * 1.3 then
        self.pressed = true
        self.wasPressed = true
        self.touchId = id
        return true
    end
    return false
end

function Button:touchReleased(id)
    if self.pressed and self.touchId == id then
        self.pressed = false
        self.touchId = nil
        return true
    end
    return false
end

function Button:consumePress()
    local v = self.wasPressed
    self.wasPressed = false
    return v
end

function Button:draw()
    local col = self.pressed and self.pressColor or self.color
    love.graphics.setColor(col[1], col[2], col[3], 0.35)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(col[1], col[2], col[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius)
    love.graphics.setLineWidth(1)
    -- Label
    love.graphics.setColor(1, 1, 1, self.pressed and 1 or 0.85)
    love.graphics.setFont(fonts.f14)
    local fw = fonts.f14:getWidth(self.label)
    love.graphics.print(self.label, self.x - fw / 2, self.y - 7)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- TouchUI — módulo principal
-- ============================================================================
function TouchUI.new()
    local self = setmetatable({}, TouchUI)
    self.joystick = Joystick.new()
    self.buttons = {}
    self._layoutDone = false
    return self
end

-- Reposicionar botones según tamaño de pantalla (llamar en love.load y love.resize)
function TouchUI:layout()
    local sw, sh = love.graphics.getDimensions()
    local margin = 20
    local btnR = math.min(38, sw * 0.05)
    local bigR = math.min(44, sw * 0.06)

    -- Botones de acción (zona derecha, parte inferior)
    local actionX = sw - margin - btnR
    local actionY = sh - margin - btnR * 2.5

    self.buttons = {
        -- Acciones principales
        interact = Button.new("E", actionX, actionY, btnR),             -- Abrir/cerrar cofre
        attack   = Button.new("ATK", actionX - btnR * 2.5, actionY, bigR), -- Atacar
        use      = Button.new("Q", actionX - btnR * 2.5, actionY + btnR * 2.8, btnR), -- Usar ítem
        restart  = Button.new("R", actionX, actionY + btnR * 2.8, btnR),  -- Reiniciar (solo dead/win)
        -- Botones pequeños arriba
        debug    = Button.new("F1", sw - margin - btnR, margin + btnR, btnR * 0.7),
        editor   = Button.new("F2", sw - margin - btnR * 3, margin + btnR, btnR * 0.7),
    }

    -- Slots del inventario (centro-abajo, para prompt de reemplazo)
    self.invSlots = {}
    local slotW = 80
    local slotGap = 10
    local slotY = sh / 2 - 20
    local startX = sw / 2 - (slotW * 3 + slotGap * 2) / 2
    for i = 1, 3 do
        self.invSlots[i] = {
            x = startX + (i - 1) * (slotW + slotGap),
            y = slotY,
            w = slotW,
            h = 80,
            pressed = false,
            wasPressed = false,
            touchId = nil,
        }
    end

    self._layoutDone = true
end

-- ============================================================================
-- Touch callbacks — reenviar desde love.touchpressed/moved/released
-- ============================================================================
function TouchUI:touchPressed(id, tx, ty)
    if not self._layoutDone then return end

    -- Intentar joystick primero
    self.joystick:touchPressed(id, tx, ty)
    if self.joystick.active and self.joystick.touchId == id then return end

    -- Intentar botones de acción
    for _, btn in pairs(self.buttons) do
        if btn:touchPressed(id, tx, ty) then return end
    end

    -- Intentar slots de inventario
    for i, slot in ipairs(self.invSlots) do
        if tx >= slot.x and tx <= slot.x + slot.w
           and ty >= slot.y and ty <= slot.y + slot.h then
            slot.pressed = true
            slot.wasPressed = true
            slot.touchId = id
            return
        end
    end
end

function TouchUI:touchMoved(id, tx, ty)
    self.joystick:touchMoved(id, tx, ty)
end

function TouchUI:touchReleased(id)
    self.joystick:touchReleased(id)
    for _, btn in pairs(self.buttons) do
        btn:touchReleased(id)
    end
    for _, slot in ipairs(self.invSlots) do
        if slot.pressed and slot.touchId == id then
            slot.pressed = false
            slot.touchId = nil
        end
    end
end

-- ============================================================================
-- Consultas de estado
-- ============================================================================

-- ¿Se presionó un botón en este frame? (consume la señal)
function TouchUI:wasPressed(name)
    local btn = self.buttons[name]
    if btn then return btn:consumePress() end
    return false
end

-- ¿El botón está presionado ahora mismo?
function TouchUI:isDown(name)
    local btn = self.buttons[name]
    if btn then return btn.pressed end
    return false
end

-- ¿Se tocó un slot de inventario en este frame? Devuelve el índice (1-3) o nil
function TouchUI:consumeSlotTap()
    for i, slot in ipairs(self.invSlots) do
        if slot.wasPressed then
            slot.wasPressed = false
            return i
        end
    end
    return nil
end

-- Resetear slots (llamar al cerrar el prompt de reemplazo)
function TouchUI:resetSlots()
    for _, slot in ipairs(self.invSlots) do
        slot.pressed = false
        slot.wasPressed = false
        slot.touchId = nil
    end
end

-- ============================================================================
-- Draw
-- ============================================================================
function TouchUI:draw()
    if not self._layoutDone then return end
    self.joystick:draw()
    for _, btn in pairs(self.buttons) do
        btn:draw()
    end
end

-- Dibujar slots de inventario (solo cuando el prompt está activo)
function TouchUI:drawInventorySlots(slots, pendingItem)
    if not self._layoutDone or not slots then return end
    local sw, sh = love.graphics.getDimensions()

    -- Overlay oscuro
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Título
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f22)
    love.graphics.printf("!Inventario lleno! Elige que reemplazar", 0, sh / 2 - 120, sw, "center")

    -- Dibujar cada slot
    for i, slot in ipairs(self.invSlots) do
        if i <= #slots then
            local s = slots[i]
            local def = s.def
            local col = slot.pressed and {0.4, 0.8, 1} or {1, 1, 1}

            -- Fondo del slot
            love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.7)
            love.graphics.rectangle("fill", slot.x, slot.y, slot.w, slot.h)

            -- Borde
            love.graphics.setColor(col[1], col[2], col[3], 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slot.x, slot.y, slot.w, slot.h)
            love.graphics.setLineWidth(1)

            -- Número
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.setFont(fonts.f18)
            love.graphics.printf("[" .. i .. "]", slot.x, slot.y - 25, slot.w, "center")

            -- Nombre
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f14)
            local txt = def.nombre
            if type(s.data) == "table" and s.data.uses then
                txt = txt .. " [" .. s.data.uses .. "/" .. def.maxUses .. "]"
            end
            love.graphics.printf(txt, slot.x, slot.y + slot.h + 5, slot.w, "center")
        end
    end

    -- Instrucción
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(fonts.f14)
    love.graphics.printf("Toca un slot para soltar ese objeto (Esc = descartar el nuevo)", 0, sh / 2 + 130, sw, "center")
    love.graphics.setColor(1, 1, 1)
end

return TouchUI
