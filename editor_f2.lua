-- editor_f2.lua – F2 Room Template Editor

local editorF2 = {
    active = false,
    currentIdx = 1,
    grid = {},
    cursorX = 1,
    cursorY = 1,
    brush = 0,
    width = 10,
    height = 10,
    name = "Nueva sala",
    editingName = false,
    nameBuffer = "",
    buttonRects = {},
    currentTemplates = {},
}

local function setGridChar(grid, x, y, ch)
    local row = grid[y]
    if not row or x < 1 or x > #row then return end
    grid[y] = row:sub(1, x-1) .. ch .. row:sub(x+1)
end

function editorF2:initEditor()
    if #self.currentTemplates > 0 then
        self.currentIdx = math.min(self.currentIdx, #self.currentTemplates)
        self.currentIdx = math.max(self.currentIdx, 1)
        local tmpl = self.currentTemplates[self.currentIdx]
        self.grid = {}
        for _, row in ipairs(tmpl.grid) do
            table.insert(self.grid, row)
        end
        if #self.grid > 0 and #self.grid[1] > 0 then
            self.width = #self.grid[1]
            self.height = #self.grid
        else
            self.grid = {}
            for y = 1, 10 do
                self.grid[y] = string.rep(".", 10)
            end
            self.width = 10
            self.height = 10
        end
        self.name = tmpl.name
    else
        self.grid = {}
        for y = 1, 10 do
            self.grid[y] = string.rep(".", 10)
        end
        self.width = 10
        self.height = 10
        self.name = "Nueva sala"
    end
    self.cursorX = 1
    self.cursorY = 1
end

function editorF2:saveEditorData()
    local tmpl = self.currentTemplates[self.currentIdx]
    if tmpl then
        tmpl.grid = {}
        for _, row in ipairs(self.grid) do
            table.insert(tmpl.grid, row)
        end
        tmpl.name = self.name
    end
    local usedNames = {}
    for _, t in ipairs(self.currentTemplates) do
        local base = t.name
        local finalName = base
        local counter = 2
        while usedNames[finalName] do
            finalName = base .. " (" .. counter .. ")"
            counter = counter + 1
        end
        t.name = finalName
        usedNames[finalName] = true
    end
    if tmpl then
        self.name = tmpl.name
    end
    local lines = {
        "-- room_templates.lua – Plantillas de salas personalizadas",
        "-- Editado desde el editor in-game (F2)",
        "",
        "local templates = {",
    }
    for _, t in ipairs(self.currentTemplates) do
        lines[#lines+1] = "    {"
        lines[#lines+1] = "        name = " .. string.format("%q", t.name) .. ","
        lines[#lines+1] = "        grid = {"
        for _, row in ipairs(t.grid) do
            lines[#lines+1] = "            " .. string.format("%q", row) .. ","
        end
        lines[#lines+1] = "        },"
        lines[#lines+1] = "    },"
    end
    lines[#lines+1] = "}"
    lines[#lines+1] = "return templates"
    local content = table.concat(lines, "\n")
    local ok, err = love.filesystem.write("room_templates.lua", content)
    if ok then
        print("Templates guardados (room_templates.lua)")
        local projectPath = "room_templates.lua"
        local f, ferr = io.open(projectPath, "w")
        if f then
            f:write(content)
            f:close()
            print("Copiado a carpeta del proyecto (ruta relativa)")
            love.filesystem.write("save_debug.log", "OK: " .. os.date() .. "\n")
        else
            print("ERROR copiando a proyecto:", ferr)
            love.filesystem.write("save_debug.log", "ERR: " .. ferr .. " " .. os.date() .. "\n")
        end
    else
        print("Error al guardar:", err)
        love.filesystem.write("save_debug.log", "ERR save: " .. err .. " " .. os.date() .. "\n")
    end
end

function editorF2:cellFromMouse(mx, my)
    local sw, sh = love.graphics.getDimensions()
    local ET = 32
    local gridW = self.width * ET
    local gridH = self.height * ET
    local gx = math.floor((mx - math.max(10, (sw - gridW) / 2)) / ET) + 1
    local gy = math.floor((my - math.max(10, (sh - gridH) / 2)) / ET) + 1
    if gx < 1 or gx > self.width or gy < 1 or gy > self.height then return end
    return gx, gy
end

function editorF2:paintCell(gx, gy, brush, brushChars)
    self.cursorX, self.cursorY = gx, gy
    setGridChar(self.grid, gx, gy, brushChars[brush] or '.')
end

function editorF2:tileFromMouse(mx, my, tileOrder)
    local sw, sh = love.graphics.getDimensions()
    local sidebarX = sw - 140
    local sidebarY = 20
    local tilePreviewSize = 28
    local spacing = 35
    for i, id in ipairs(tileOrder) do
        local y = sidebarY + (i - 1) * spacing + 15
        if mx >= sidebarX and mx <= sidebarX + tilePreviewSize and
           my >= y - 2 and my <= y + tilePreviewSize + 2 then
            return id
        end
    end
    return nil
end

function editorF2:keypressed(key, brushChars)
    if self.editingName then
        if key == "return" or key == "kpenter" then
            self.name = self.nameBuffer
            self.editingName = false
        elseif key == "escape" then
            self.editingName = false
        elseif key == "backspace" then
            self.nameBuffer = self.nameBuffer:sub(1, -2)
        end
        return
    end
    if key == "escape" then
        self.active = false
    elseif key == "up" then
        self.cursorY = math.max(1, self.cursorY - 1)
    elseif key == "down" then
        self.cursorY = math.min(#self.grid, self.cursorY + 1)
    elseif key == "left" then
        self.cursorX = math.max(1, self.cursorX - 1)
    elseif key == "right" then
        self.cursorX = math.min(#self.grid[1], self.cursorX + 1)
    elseif key == "space" then
        local ch = brushChars[self.brush] or '.'
        setGridChar(self.grid, self.cursorX, self.cursorY, ch)
        if self.cursorX < #self.grid[1] then
            self.cursorX = self.cursorX + 1
        elseif self.cursorY < #self.grid then
            self.cursorX = 1
            self.cursorY = self.cursorY + 1
        end
    elseif key == "1" then self.brush = 0
    elseif key == "2" then self.brush = 1
    elseif key == "3" then self.brush = 3
    elseif key == "4" then self.brush = 2
    elseif key == "5" then self.brush = 4
    elseif key == "6" then self.brush = 5
    elseif key == "7" then self.brush = 6
    elseif key == "8" then self.brush = 7
    elseif key == "s" then
        print("S presionado - guardando...")
        self:saveEditorData()
        package.loaded["room_templates"] = nil
        self.currentTemplates = require "room_templates"
    elseif key == "tab" then
        local tmpl = self.currentTemplates[self.currentIdx]
        if tmpl then
            tmpl.grid = {}
            for _, row in ipairs(self.grid) do
                table.insert(tmpl.grid, row)
            end
        end
        if #self.currentTemplates > 0 then
            self.currentIdx = self.currentIdx % #self.currentTemplates + 1
        end
        self:initEditor()
    elseif key == "n" then
        table.insert(self.currentTemplates, {name = "Nueva sala", grid = {}})
        self.currentIdx = #self.currentTemplates
        self:initEditor()
        self.grid = {}
        for y = 1, 10 do
            self.grid[y] = string.rep(".", 10)
        end
        self.width = 10
        self.height = 10
        self.name = "Nueva sala"
    elseif key == "r" then
        if love.keyboard.isDown("lshift", "rshift") then
            if self.height > 3 then
                table.remove(self.grid)
                self.height = self.height - 1
                self.cursorY = math.min(self.cursorY, self.height)
            end
        elseif self.height < 30 then
            table.insert(self.grid, string.rep(".", self.width))
            self.height = self.height + 1
        end
    elseif key == "c" then
        if love.keyboard.isDown("lshift", "rshift") then
            if self.width > 3 then
                for y = 1, #self.grid do
                    self.grid[y] = self.grid[y]:sub(1, -2)
                end
                self.width = self.width - 1
                self.cursorX = math.min(self.cursorX, self.width)
            end
        elseif self.width < 30 then
            for y = 1, #self.grid do
                self.grid[y] = self.grid[y] .. "."
            end
            self.width = self.width + 1
        end
    end
end

function editorF2:textinput(text)
    if self.active and self.editingName then
        self.nameBuffer = self.nameBuffer .. text
    end
end

function editorF2:mousepressed(mx, my, button, tileOrder, brushChars, brushNames)
    if button == 1 then
        for _, rect in ipairs(self.buttonRects) do
            if mx >= rect.x and mx <= rect.x + rect.w and
               my >= rect.y and my <= rect.y + rect.h then
                local k = rect.name
                if k == "save" then
                    self:saveEditorData()
                    package.loaded["room_templates"] = nil
                    self.currentTemplates = require "room_templates"
                elseif k == "new" then
                    local tmpl = self.currentTemplates[self.currentIdx]
                    if tmpl then
                        tmpl.grid = {}
                        for _, row in ipairs(self.grid) do
                            table.insert(tmpl.grid, row)
                        end
                    end
                    table.insert(self.currentTemplates, {name = "Nueva sala", grid = {}})
                    self.currentIdx = #self.currentTemplates
                    self:initEditor()
                    self.grid = {}
                    for y = 1, 10 do
                        self.grid[y] = string.rep(".", 10)
                    end
                    self.width = 10
                    self.height = 10
                    self.name = "Nueva sala"
                elseif k == "next" then
                    local tmpl = self.currentTemplates[self.currentIdx]
                    if tmpl then
                        tmpl.grid = {}
                        for _, row in ipairs(self.grid) do
                            table.insert(tmpl.grid, row)
                        end
                    end
                    if #self.currentTemplates > 0 then
                        self.currentIdx = self.currentIdx % #self.currentTemplates + 1
                    end
                    self:initEditor()
                elseif k == "close" then
                    self.active = false
                elseif k == "row+" then
                    if self.height < 30 then
                        table.insert(self.grid, string.rep(".", self.width))
                        self.height = self.height + 1
                    end
                elseif k == "row-" then
                    if self.height > 3 then
                        table.remove(self.grid)
                        self.height = self.height - 1
                        self.cursorY = math.min(self.cursorY, self.height)
                    end
                elseif k == "col+" then
                    if self.width < 30 then
                        for y = 1, #self.grid do
                            self.grid[y] = self.grid[y] .. "."
                        end
                        self.width = self.width + 1
                    end
                elseif k == "col-" then
                    if self.width > 3 then
                        for y = 1, #self.grid do
                            self.grid[y] = self.grid[y]:sub(1, -2)
                        end
                        self.width = self.width - 1
                        self.cursorX = math.min(self.cursorX, self.width)
                    end
                elseif k == "name" then
                    self.editingName = true
                    self.nameBuffer = self.name
                end
                return
            end
        end
    end

    local tileId = self:tileFromMouse(mx, my, tileOrder)
    if tileId then
        self.brush = tileId
        return
    end

    local gx, gy = self:cellFromMouse(mx, my)
    if gx then
        if button == 1 then
            self:paintCell(gx, gy, self.brush, brushChars)
        elseif button == 2 then
            self:paintCell(gx, gy, 0, brushChars)
        end
    end
end

function editorF2:mousemoved(mx, my, brushChars)
    if love.mouse.isDown(1) or love.mouse.isDown(2) then
        local gx, gy = self:cellFromMouse(mx, my)
        if gx then
            self:paintCell(gx, gy, love.mouse.isDown(1) and self.brush or 0, brushChars)
        end
    end
end

function editorF2:draw(tileOrder, tileSheets, tileQuads, Tiles)
    local sw, sh = love.graphics.getDimensions()
    local EDITOR_TILE = 32
    local gridW = self.width * EDITOR_TILE
    local gridH = self.height * EDITOR_TILE
    local gridX = math.max(175, (sw - gridW) / 2)
    local gridY = math.max(10, (sh - gridH) / 2)

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local LEFT_X = 15
    local LEFT_W = 150
    local BTN_H = 26
    local BTN_GAP = 4
    local y = 15

    self.buttonRects = {}
    local function addRect(name, x, y, w, h)
        table.insert(self.buttonRects, {name=name, x=x, y=y, w=w, h=h})
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f16)
    love.graphics.print("Editor de salas", LEFT_X, y)
    y = y + 22

    love.graphics.setFont(fonts.f12)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Nombre:", LEFT_X, y)
    local nameFieldX = LEFT_X + 52
    local nameFieldY = y - 2
    local nameFieldW = LEFT_W - 52
    local nameFieldH = 20

    if self.editingName then
        love.graphics.setColor(0.2, 0.4, 0.6, 0.5)
        love.graphics.rectangle("fill", nameFieldX, nameFieldY, nameFieldW, nameFieldH)
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("line", nameFieldX, nameFieldY, nameFieldW, nameFieldH)
        love.graphics.setColor(1, 1, 1)
        local displayText = self.nameBuffer
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            displayText = displayText .. "|"
        end
        love.graphics.print(displayText, nameFieldX + 3, nameFieldY + 3)
    else
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", nameFieldX, nameFieldY, nameFieldW, nameFieldH)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("line", nameFieldX, nameFieldY, nameFieldW, nameFieldH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(self.name, nameFieldX + 3, nameFieldY + 3)
    end
    addRect("name", nameFieldX, nameFieldY, nameFieldW, nameFieldH)

    y = nameFieldY + nameFieldH + 8

    local actions = {
        {name = "Guardar", key = "save"},
        {name = "Nueva",   key = "new"},
        {name = "Siguiente", key = "next"},
        {name = "Cerrar",  key = "close"},
    }
    for _, btn in ipairs(actions) do
        love.graphics.setColor(0.3, 0.5, 0.7)
        love.graphics.rectangle("fill", LEFT_X, y, LEFT_W, BTN_H)
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.rectangle("line", LEFT_X, y, LEFT_W, BTN_H)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.f14)
        local tw = fonts.f14:getWidth(btn.name)
        love.graphics.print(btn.name, LEFT_X + (LEFT_W - tw) / 2, y + 5)
        addRect(btn.key, LEFT_X, y, LEFT_W, BTN_H)
        y = y + BTN_H + BTN_GAP
    end

    y = y + 4

    local halfW = (LEFT_W - BTN_GAP) / 2

    love.graphics.setFont(fonts.f12)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Filas:", LEFT_X, y)
    y = y + 16

    love.graphics.setColor(0.3, 0.5, 0.3)
    love.graphics.rectangle("fill", LEFT_X, y, halfW, BTN_H)
    love.graphics.setColor(0.5, 0.7, 0.5)
    love.graphics.rectangle("line", LEFT_X, y, halfW, BTN_H)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f14)
    local fw = fonts.f14:getWidth("+Fila")
    love.graphics.print("+Fila", LEFT_X + (halfW - fw) / 2, y + 5)
    addRect("row+", LEFT_X, y, halfW, BTN_H)

    love.graphics.setColor(0.5, 0.3, 0.3)
    love.graphics.rectangle("fill", LEFT_X + halfW + BTN_GAP, y, halfW, BTN_H)
    love.graphics.setColor(0.7, 0.5, 0.5)
    love.graphics.rectangle("line", LEFT_X + halfW + BTN_GAP, y, halfW, BTN_H)
    love.graphics.setColor(1, 1, 1)
    fw = fonts.f14:getWidth("-Fila")
    love.graphics.print("-Fila", LEFT_X + halfW + BTN_GAP + (halfW - fw) / 2, y + 5)
    addRect("row-", LEFT_X + halfW + BTN_GAP, y, halfW, BTN_H)

    y = y + BTN_H + BTN_GAP + 4

    love.graphics.setFont(fonts.f12)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Columnas:", LEFT_X, y)
    y = y + 16

    love.graphics.setColor(0.3, 0.5, 0.3)
    love.graphics.rectangle("fill", LEFT_X, y, halfW, BTN_H)
    love.graphics.setColor(0.5, 0.7, 0.5)
    love.graphics.rectangle("line", LEFT_X, y, halfW, BTN_H)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f14)
    fw = fonts.f14:getWidth("+Col")
    love.graphics.print("+Col", LEFT_X + (halfW - fw) / 2, y + 5)
    addRect("col+", LEFT_X, y, halfW, BTN_H)

    love.graphics.setColor(0.5, 0.3, 0.3)
    love.graphics.rectangle("fill", LEFT_X + halfW + BTN_GAP, y, halfW, BTN_H)
    love.graphics.setColor(0.7, 0.5, 0.5)
    love.graphics.rectangle("line", LEFT_X + halfW + BTN_GAP, y, halfW, BTN_H)
    love.graphics.setColor(1, 1, 1)
    fw = fonts.f14:getWidth("-Col")
    love.graphics.print("-Col", LEFT_X + halfW + BTN_GAP + (halfW - fw) / 2, y + 5)
    addRect("col-", LEFT_X + halfW + BTN_GAP, y, halfW, BTN_H)

    local sidebarX = sw - 140
    local sidebarY = 20
    local tilePreviewSize = 28
    local spacing = 35

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", sidebarX - 10, sidebarY - 10, 160, #tileOrder * spacing + 20)
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("line", sidebarX - 10, sidebarY - 10, 160, #tileOrder * spacing + 20)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f14)
    love.graphics.print("Tiles:", sidebarX, sidebarY - 5)

    for i, id in ipairs(tileOrder) do
        local def = Tiles.defs[id]
        local ty = sidebarY + (i - 1) * spacing + 15
        local isSelected = (self.brush == id)
        if isSelected then
            love.graphics.setColor(0.2, 0.4, 0.6, 0.5)
            love.graphics.rectangle("fill", sidebarX - 8, ty - 2, 156, tilePreviewSize + 4)
        end
        local previewX = sidebarX
        local previewY = ty
        if def.texture and tileSheets and tileQuads then
            love.graphics.setColor(1, 1, 1)
            local sheet = tileSheets[def.texture]
            local quad = tileQuads[def.texture]
            if sheet and quad then
                love.graphics.draw(sheet, quad, previewX, previewY, 0, tilePreviewSize / 16, tilePreviewSize / 16)
            else
                love.graphics.setColor(def.color)
                love.graphics.rectangle("fill", previewX, previewY, tilePreviewSize, tilePreviewSize)
            end
        else
            love.graphics.setColor(def.color)
            love.graphics.rectangle("fill", previewX, previewY, tilePreviewSize, tilePreviewSize)
        end
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.rectangle("line", previewX, previewY, tilePreviewSize, tilePreviewSize)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.f12)
        love.graphics.print(def.name, previewX + tilePreviewSize + 8, previewY + 8)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("(" .. def.char .. ")", previewX + tilePreviewSize + 70, previewY + 8)
    end

    for gy = 1, self.height do
        for gx = 1, self.width do
            local ch = self.grid[gy]:sub(gx, gx)
            local px = gridX + (gx - 1) * EDITOR_TILE
            local py = gridY + (gy - 1) * EDITOR_TILE
            local def = Tiles.charToId[ch] and Tiles.defs[Tiles.charToId[ch]]
            local color = def and def.color or {0.039, 0.039, 0.039}
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", px, py, EDITOR_TILE, EDITOR_TILE)
            love.graphics.setColor(0.2, 0.2, 0.3, 0.4)
            love.graphics.rectangle("line", px, py, EDITOR_TILE, EDITOR_TILE)
        end
    end

    local cx = gridX + (self.cursorX - 1) * EDITOR_TILE
    local cy = gridY + (self.cursorY - 1) * EDITOR_TILE
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("line", cx - 1, cy - 1, EDITOR_TILE + 2, EDITOR_TILE + 2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f16)
    love.graphics.printf("Sala " .. self.currentIdx .. " de " .. #self.currentTemplates, 0, gridY + gridH + 15, sw, "center")

    local helpY = sh - 30
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(fonts.f12)
    love.graphics.printf("Click izq: pintar | Der: borrar | Flechas: mover cursor | 1-8: tile | S: guardar", 0, helpY, sw, "center")
end

return editorF2
