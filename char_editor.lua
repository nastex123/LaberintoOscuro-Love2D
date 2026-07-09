-- char_editor.lua – F3 Character Editor Module

local json = require "json"
local Character = require "character"

local PRESET_COLORS = {
    {1,1,1}, {0,1,1}, {1,1,0}, {1,0,0},
    {0,1,0}, {0,0,1}, {1,0,1}, {1,0.8,0},
}

local charEditorModule = {
    active = false,
    tab = "PARTES",
    tabNames = {"PARTES", "POSES", "ANIM"},
    partSel = 1,
    paramSel = 1,
    poses = {[1]={}, [2]={}, [3]={}, [4]={}, [5]={}, [6]={}, [7]={}, [8]={}, [9]={}},
    animPoseA = 1,
    animPoseB = 2,
    animBlend = 0,
    animAuto = false,
    animSpeed = 0.5,
    animTimer = 0,
    charConfigPath = "char_config.json",
    sliders = {},
    dragging = false,
}

function charEditorModule:toggle()
    self.active = not self.active
    if self.active then
        self.poses = self.poses or {}
    end
end

function charEditorModule:keypressed(key, player)
    if key == "s" then
        self:saveConfig(player)
    elseif key == "escape" then
        self.active = false
    elseif key == "tab" then
        local idx = 1
        for i, tn in ipairs(self.tabNames) do
            if tn == self.tab then
                idx = i % #self.tabNames + 1
                break
            end
        end
        self.tab = self.tabNames[idx]
        self.paramSel = 1
    elseif key == "left" or key == "right" then
        local part = player and player.character and player.character.parts[self.partSel]
        if self.tab == "PARTES" and part then
            local params = Character.getParamMeta(part)
            local pm = params[self.paramSel]
            if pm then
                local delta = (key == "right" and 1 or -1) * pm.step
                part[pm.key] = math.max(pm.min, math.min(pm.max, part[pm.key] + delta))
            end
        end
    end
end

function charEditorModule:saveConfig(player)
    local data = {
        parts = {},
        poses = self.poses,
    }
    for i, part in ipairs(player.character.parts) do
        local pd = {}
        for k, v in pairs(part) do
            pd[k] = v
        end
        table.insert(data.parts, pd)
    end
    local content = json.encode(data)
    love.filesystem.write(self.charConfigPath, content)
end

function charEditorModule:loadConfig(player)
    local charData = love.filesystem.read(self.charConfigPath)
    if charData and charData ~= "" then
        local ok, parsed = pcall(json.decode, charData)
        if ok then
            if parsed.parts then
                for i, pd in ipairs(parsed.parts) do
                    if player.character.parts[i] then
                        for k, v in pairs(pd) do
                            player.character.parts[i][k] = v
                        end
                    end
                end
            end
            if parsed.poses then
                for i, pose in ipairs(parsed.poses) do
                    if i <= 9 and pose then
                        self.poses[i] = pose
                    end
                end
            end
        end
    end
end

function charEditorModule:mousepressed(mx, my, button, player)
    if not self.active or not player or not player.character then return end
    local sw, sh = love.graphics.getDimensions()
    local PANEL_W = 620
    local PANEL_H = 520
    local PANEL_X = math.floor((sw - PANEL_W) / 2)
    local PANEL_Y = math.floor((sh - PANEL_H) / 2)
    local char = player.character

    if mx >= PANEL_X + PANEL_W - 26 and mx <= PANEL_X + PANEL_W - 6 and
       my >= PANEL_Y + 6 and my <= PANEL_Y + 26 then
        self.active = false
        return
    end

    local TAB_Y = PANEL_Y + 32
    local TAB_H = 24
    local TAB_W = 80
    for i, tn in ipairs(self.tabNames) do
        local tx = PANEL_X + (PANEL_W / #self.tabNames) * (i - 1) + 20
        if mx >= tx and mx <= tx + TAB_W and my >= TAB_Y and my <= TAB_Y + TAB_H then
            self.tab = tn
            self.paramSel = 1
            return
        end
    end

    local CONTENT_Y = TAB_Y + TAB_H + 10

    if self.tab == "PARTES" then
        local SIDEBAR_X = PANEL_X + 10
        local SIDEBAR_W = 110
        local CANVAS_X = PANEL_X + 135
        local CANVAS_Y = CONTENT_Y
        local CANVAS_S = 200
        local PROP_X = CANVAS_X + CANVAS_S + 15

        local spy = CONTENT_Y
        for i, p in ipairs(char.parts) do
            if mx >= SIDEBAR_X and mx <= SIDEBAR_X + SIDEBAR_W and
               my >= spy and my <= spy + 20 then
                self.partSel = i
                self.paramSel = 1
                return
            end
            spy = spy + 22
        end

        local btnY = spy + 6
        for bi = 1, 4 do
            local bx = SIDEBAR_X + (bi - 1) * 28
            if mx >= bx and mx <= bx + 25 and my >= btnY and my <= btnY + 20 then
                if bi == 1 then
                    table.insert(char.parts, self.partSel + 1, Character.defaultPart())
                elseif bi == 2 and #char.parts > 1 then
                    table.remove(char.parts, self.partSel)
                    self.partSel = math.min(self.partSel, #char.parts)
                elseif bi == 3 and self.partSel > 1 then
                    local idx = self.partSel
                    char.parts[idx], char.parts[idx - 1] = char.parts[idx - 1], char.parts[idx]
                    self.partSel = idx - 1
                elseif bi == 4 and self.partSel < #char.parts then
                    local idx = self.partSel
                    char.parts[idx], char.parts[idx + 1] = char.parts[idx + 1], char.parts[idx]
                    self.partSel = idx + 1
                end
                return
            end
        end

        local scale = 3
        local cx = CANVAS_X + CANVAS_S/2
        local cy = CANVAS_Y + CANVAS_S/2
        local relX = (mx - cx) / scale
        local relY = (my - cy) / scale
        if mx >= CANVAS_X and mx <= CANVAS_X + CANVAS_S and
           my >= CANVAS_Y and my <= CANVAS_Y + CANVAS_S then
            for i = #char.parts, 1, -1 do
                if Character.hitTestPart(char.parts[i], relX, relY) then
                    self.partSel = i
                    return
                end
            end
        end

        if button == 1 and mx >= CANVAS_X and mx <= CANVAS_X + CANVAS_S and
           my >= CANVAS_Y and my <= CANVAS_Y + CANVAS_S then
            self.dragging = true
            self.dragStartX = relX
            self.dragStartY = relY
            self.dragPartSel = self.partSel
            return
        end

        local part = char.parts[self.partSel]
        if part and mx >= PROP_X + 40 and mx <= PROP_X + 130 and my >= CONTENT_Y and my <= CONTENT_Y + 20 then
            local types = {"circle", "rect", "line"}
            for ti, tname in ipairs(types) do
                if tname ~= part.type then
                    Character.changePartType(part, tname)
                    break
                end
            end
            return
        end

        if part then
            local params = Character.getParamMeta(part)
            local py2 = CONTENT_Y + 26
            local PROP_W = PANEL_W - PROP_X - PANEL_X - 10
            for pi, pm in ipairs(params) do
                local SLIDER_X = PROP_X + 90
                local SLIDER_W = 80
                local sliderY = py2 + 2
                if my >= py2 and my <= py2 + 18 and mx >= PROP_X and mx <= PROP_X + PROP_W then
                    self.paramSel = pi
                    if mx >= SLIDER_X and mx <= SLIDER_X + SLIDER_W and
                       my >= sliderY and my <= sliderY + 14 then
                        local t = math.max(0, math.min(1, (mx - SLIDER_X) / SLIDER_W))
                        part[pm.key] = pm.min + t * (pm.max - pm.min)
                    end
                    return
                end
                py2 = py2 + 22
            end
            for ci = 1, 8 do
                local sx = PROP_X + 50 + (ci - 1) * 22
                if mx >= sx and mx <= sx + 18 and my >= py2 and my <= py2 + 18 then
                    part.colorR, part.colorG, part.colorB = PRESET_COLORS[ci][1], PRESET_COLORS[ci][2], PRESET_COLORS[ci][3]
                    return
                end
            end
        end
    elseif self.tab == "POSES" then
        local py = CONTENT_Y
        for i = 1, 9 do
            if mx >= PANEL_X + 180 and mx <= PANEL_X + 260 and my >= py + 4 and my <= py + 24 then
                self.poses[i] = Character.snapshot(char)
                return
            end
            if mx >= PANEL_X + 270 and mx <= PANEL_X + 350 and my >= py + 4 and my <= py + 24 then
                if self.poses[i] and #self.poses[i] > 0 then
                    Character.applyPose(char, self.poses[i])
                end
                return
            end
            py = py + 32
        end
    elseif self.tab == "ANIM" then
        local py = CONTENT_Y
        if mx >= PANEL_X + 120 and mx <= PANEL_X + 160 and my >= py and my <= py + 20 then
            self.animPoseA = self.animPoseA % 9 + 1
            return
        end
        if mx >= PANEL_X + 270 and mx <= PANEL_X + 310 and my >= py and my <= py + 20 then
            self.animPoseB = self.animPoseB % 9 + 1
            return
        end
        py = py + 30

        local bsx = PANEL_X + 110
        local bsy = py + 4
        if mx >= bsx and mx <= bsx + 300 and my >= bsy and my <= bsy + 8 then
            self.animBlend = math.max(0, math.min(1, (mx - bsx) / 300))
            return
        end
        py = py + 30

        local actx = PANEL_X + 90
        local acty = py
        if mx >= actx and mx <= actx + 90 and my >= acty and my <= acty + 22 then
            self.animAuto = not self.animAuto
            self.animTimer = 0
            return
        end
        py = py + 30

        local vsx = PANEL_X + 80
        local vsy = py + 4
        if mx >= vsx and mx <= vsx + 200 and my >= vsy and my <= vsy + 8 then
            self.animSpeed = math.max(0.1, math.min(3.0, (mx - vsx) / 200 * 3.0))
            return
        end
    end
end

function charEditorModule:mousemoved(mx, my, player)
    if not (self.active and self.dragging) then return end
    local sw, sh = love.graphics.getDimensions()
    local PANEL_W = 620
    local PANEL_X = math.floor((sw - PANEL_W) / 2)
    local PANEL_Y = math.floor((sh - 520) / 2)
    local CANVAS_X = PANEL_X + 135
    local CANVAS_Y = PANEL_Y + 32 + 24 + 10
    local CANVAS_S = 200
    local scale = 3
    local cx = CANVAS_X + CANVAS_S/2
    local cy = CANVAS_Y + CANVAS_S/2
    local relX = (mx - cx) / scale
    local relY = (my - cy) / scale
    local part = player.character.parts[self.dragPartSel]
    if part then
        part.offsetX = relX
        part.offsetY = relY
    end
end

function charEditorModule:mousereleased(mx, my, button)
    if button == 1 then
        self.dragging = false
    end
end

function charEditorModule:wheelmoved(x, y, player)
    if not (self.active and self.tab == "PARTES" and player and player.character) then return end
    local part = player.character.parts[self.partSel]
    if part then
        local params = Character.getParamMeta(part)
        local pm = params[self.paramSel]
        if pm then
            part[pm.key] = math.max(pm.min, math.min(pm.max, part[pm.key] + pm.step * y))
        end
    end
end

function charEditorModule:update(player, dt)
    if not (self.active and self.tab == "ANIM" and player and player.character) then return end
    local poseA = self.poses[self.animPoseA]
    local poseB = self.poses[self.animPoseB]
    if poseA and #poseA > 0 and poseB and #poseB > 0 then
        if self.animAuto then
            self.animTimer = self.animTimer + dt * self.animSpeed
            self.animBlend = (math.sin(self.animTimer) + 1) / 2
        end
        local blended = Character.lerpPose(poseA, poseB, self.animBlend)
        Character.applyPose(player.character, blended)
    end
end

function charEditorModule:draw(player)
    if not (self.active and player and player.character) then return end
    local sw, sh = love.graphics.getDimensions()
    local PANEL_W = 620
    local PANEL_H = 520
    local PANEL_X = math.floor((sw - PANEL_W) / 2)
    local PANEL_Y = math.floor((sh - PANEL_H) / 2)
    local char = player.character
    local part = char.parts[self.partSel]

    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f16)
    love.graphics.print("F3 - Editor de Personaje", PANEL_X + 10, PANEL_Y + 8)

    local closeBtn = {x = PANEL_X + PANEL_W - 26, y = PANEL_Y + 6, w = 20, h = 20}
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("fill", closeBtn.x, closeBtn.y, closeBtn.w, closeBtn.h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f14)
    love.graphics.print("X", closeBtn.x + 5, closeBtn.y + 2)

    local TAB_Y = PANEL_Y + 32
    local TAB_H = 24
    local TAB_W = 80
    for i, tn in ipairs(self.tabNames) do
        local tx = PANEL_X + (PANEL_W / #self.tabNames) * (i - 1) + 20
        if tn == self.tab then
            love.graphics.setColor(0.3, 0.6, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.3)
        end
        love.graphics.rectangle("fill", tx, TAB_Y, TAB_W, TAB_H)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.f12)
        love.graphics.print(tn, tx + (TAB_W - fonts.f12:getWidth(tn))/2, TAB_Y + 5)
    end

    local CONTENT_Y = TAB_Y + TAB_H + 10

    if self.tab == "PARTES" then
        local SIDEBAR_X = PANEL_X + 10
        local SIDEBAR_W = 110
        local CANVAS_X = PANEL_X + 135
        local CANVAS_Y = CONTENT_Y
        local CANVAS_S = 200
        local PROP_X = CANVAS_X + CANVAS_S + 15
        local PROP_W = PANEL_W - PROP_X - PANEL_X - 10

        local spy = CONTENT_Y
        for i, p in ipairs(char.parts) do
            local col = i == self.partSel and {0.3, 0.6, 0.9} or {0.15, 0.15, 0.2}
            love.graphics.setColor(col)
            love.graphics.rectangle("fill", SIDEBAR_X, spy, SIDEBAR_W, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f12)
            love.graphics.print(p.name, SIDEBAR_X + 4, spy + 3)
            spy = spy + 22
        end

        local btnY = spy + 6
        local btnColors = {{0.3,0.5,0.3}, {0.5,0.3,0.3}, {0.3,0.3,0.5}, {0.3,0.3,0.5}}
        local btnLabels = {"+","-","▲","▼"}
        for bi = 1, 4 do
            love.graphics.setColor(btnColors[bi])
            love.graphics.rectangle("fill", SIDEBAR_X + (bi - 1) * 28, btnY, 25, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f14)
            love.graphics.print(btnLabels[bi], SIDEBAR_X + (bi - 1) * 28 + 7, btnY + 2)
        end

        love.graphics.setColor(0.08, 0.08, 0.1)
        love.graphics.rectangle("fill", CANVAS_X, CANVAS_Y, CANVAS_S, CANVAS_S)
        love.graphics.setColor(0.15, 0.15, 0.2)
        love.graphics.rectangle("line", CANVAS_X, CANVAS_Y, CANVAS_S, CANVAS_S)
        love.graphics.setColor(0.12, 0.12, 0.15)
        for g = 0, 10 do
            love.graphics.line(CANVAS_X + g*20, CANVAS_Y, CANVAS_X + g*20, CANVAS_Y + CANVAS_S)
            love.graphics.line(CANVAS_X, CANVAS_Y + g*20, CANVAS_X + CANVAS_S, CANVAS_Y + g*20)
        end
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.line(CANVAS_X + CANVAS_S/2, CANVAS_Y, CANVAS_X + CANVAS_S/2, CANVAS_Y + CANVAS_S)
        love.graphics.line(CANVAS_X, CANVAS_Y + CANVAS_S/2, CANVAS_X + CANVAS_S, CANVAS_Y + CANVAS_S/2)

        local scale = 3
        local cx = CANVAS_X + CANVAS_S/2
        local cy = CANVAS_Y + CANVAS_S/2

        for i, p in ipairs(char.parts) do
            if p.type == "circle" then
                local px = cx + p.offsetX * scale
                local py = cy + p.offsetY * scale
                love.graphics.setColor(p.colorR, p.colorG, p.colorB)
                love.graphics.circle("fill", px, py, p.radius * scale)
            elseif p.type == "rect" then
                local px = cx + p.offsetX * scale
                local py = cy + p.offsetY * scale
                love.graphics.setColor(p.colorR, p.colorG, p.colorB)
                love.graphics.rectangle("fill", px - p.width/2 * scale, py - p.height/2 * scale, p.width * scale, p.height * scale)
            elseif p.type == "line" then
                local rad = math.rad(p.angleDeg)
                love.graphics.setColor(p.colorR, p.colorG, p.colorB)
                love.graphics.setLineWidth(2 * scale)
                love.graphics.line(cx + p.offsetX * scale, cy + p.offsetY * scale,
                                    cx + (p.offsetX + math.cos(rad) * p.length) * scale,
                                    cy + (p.offsetY + math.sin(rad) * p.length) * scale)
                love.graphics.setLineWidth(1)
            end
            if i == self.partSel then
                local px = cx + p.offsetX * scale
                local py = cy + p.offsetY * scale
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle("line", px, py, (p.radius or 6) * scale + 3)
            end
        end

        if part then
            local py2 = CONTENT_Y
            love.graphics.setFont(fonts.f12)
            love.graphics.setColor(1, 1, 1)

            love.graphics.print("Tipo:", PROP_X, py2)
            love.graphics.setColor(0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", PROP_X + 40, py2, 90, 20)
            love.graphics.setColor(1, 1, 1)
            local ttxt = part.type == "circle" and "Circulo" or part.type == "rect" and "Rectangulo" or "Linea"
            love.graphics.print(ttxt, PROP_X + 45, py2 + 3)

            love.graphics.print("Nombre:", PROP_X + 140, py2)
            love.graphics.setColor(0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", PROP_X + 200, py2, 90, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(part.name, PROP_X + 205, py2 + 3)

            py2 = py2 + 26

            local params = Character.getParamMeta(part)
            for pi, pm in ipairs(params) do
                local val = part[pm.key]
                local txt = pm.name .. ": " .. string.format(pm.fmt, val)
                love.graphics.setFont(fonts.f12)
                love.graphics.setColor(pi == self.paramSel and 1 or 0.8, pi == self.paramSel and 1 or 0.8, pi == self.paramSel and 0 or 0.8)
                love.graphics.print(txt, PROP_X, py2)

                local SLIDER_X = PROP_X + 90
                local SLIDER_W = 80
                local sliderY = py2 + 2
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W, 14)
                local t = (val - pm.min) / (pm.max - pm.min)
                love.graphics.setColor(0.6, 0.8, 1.0)
                love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W * t, 14)
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.rectangle("line", SLIDER_X, sliderY, SLIDER_W, 14)
                py2 = py2 + 22
            end

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f12)
            love.graphics.print("Color:", PROP_X, py2)

            local swSize = 18
            for ci, c in ipairs(PRESET_COLORS) do
                love.graphics.setColor(c)
                love.graphics.rectangle("fill", PROP_X + 50 + (ci - 1) * (swSize + 4), py2, swSize, swSize)
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.rectangle("line", PROP_X + 50 + (ci - 1) * (swSize + 4), py2, swSize, swSize)
            end
        end
    elseif self.tab == "POSES" then
        local py = CONTENT_Y
        for i = 1, 9 do
            local hasPose = self.poses[i] and #self.poses[i] > 0
            love.graphics.setColor(0.2, 0.2, 0.25)
            love.graphics.rectangle("fill", PANEL_X + 30, py, 560, 28)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f12)
            love.graphics.print("Pose " .. i .. (hasPose and " (guardada)" or " (vacia)"), PANEL_X + 36, py + 6)
            local sbx = PANEL_X + 180
            love.graphics.setColor(0.3, 0.5, 0.3)
            love.graphics.rectangle("fill", sbx, py + 4, 80, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Guardar", sbx + 12, py + 5)
            local lbx = sbx + 90
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", lbx, py + 4, 80, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Cargar", lbx + 14, py + 5)
            py = py + 32
        end
    elseif self.tab == "ANIM" then
        local py = CONTENT_Y
        love.graphics.setFont(fonts.f12)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Pose A:", PANEL_X + 40, py)
        love.graphics.setColor(1, 1, 1)
        local atxt = tostring(self.animPoseA)
        love.graphics.rectangle("line", PANEL_X + 120, py, 40, 20)
        love.graphics.print(atxt, PANEL_X + 125, py + 3)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Pose B:", PANEL_X + 200, py)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", PANEL_X + 270, py, 40, 20)
        love.graphics.print(tostring(self.animPoseB), PANEL_X + 275, py + 3)
        py = py + 30

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Mezcla:", PANEL_X + 40, py)
        local bsx = PANEL_X + 110
        local bsy = py + 4
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", bsx, bsy, 300, 8)
        love.graphics.setColor(0.6, 0.8, 1.0)
        love.graphics.rectangle("fill", bsx, bsy, 300 * self.animBlend, 8)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", bsx, bsy, 300, 8)
        love.graphics.setFont(fonts.f12)
        love.graphics.print(string.format("%.2f", self.animBlend), bsx + 285, bsy + 10)
        py = py + 30

        love.graphics.setFont(fonts.f12)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Auto:", PANEL_X + 40, py)
        local actx = PANEL_X + 90
        local acty = py
        local actCol = self.animAuto and {0.3, 0.6, 0.3} or {0.3, 0.3, 0.3}
        love.graphics.setColor(actCol)
        love.graphics.rectangle("fill", actx, acty, 90, 22)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(self.animAuto and "ACTIVO" or "INACTIVO", actx + 12, acty + 4)
        py = py + 30

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Vel:", PANEL_X + 40, py)
        local vsx = PANEL_X + 80
        local vsy = py + 4
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", vsx, vsy, 200, 8)
        local vt = self.animSpeed / 3.0
        love.graphics.setColor(0.6, 0.8, 1.0)
        love.graphics.rectangle("fill", vsx, vsy, 200 * vt, 8)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", vsx, vsy, 200, 8)
        love.graphics.print(string.format("%.1f", self.animSpeed), vsx + 205, vsy + 10)
    end

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(fonts.f12)
    love.graphics.print("S: guardar | ESC: cerrar | Tab: pestaña", PANEL_X + 10, PANEL_Y + PANEL_H - 20)
end

return charEditorModule