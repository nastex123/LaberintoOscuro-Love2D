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
    tabNames = {"PARTES", "ANIM"},
    partSel = 1,
    paramSel = 1,
    animations = {},
    animSel = 0,
    animFrame = 1,
    animPlaying = false,
    animTimer = 0,
    editAnimName = false,
    animNameBuf = "",
    charConfigPath = nil, -- set lazily in persist/loadConfig
    sliders = {},
    dragging = false,
}

function charEditorModule:toggle()
    self.active = not self.active
end

local function persist(player)
    if not charEditorModule.charConfigPath then
        charEditorModule.charConfigPath = love.filesystem.getSource() .. "/char_config.json"
    end
    local data = {
        parts = {},
        animations = charEditorModule.animations,
    }
    for _, part in ipairs(player.character.parts) do
        local pd = {}
        for k, v in pairs(part) do pd[k] = v end
        table.insert(data.parts, pd)
    end
    local f = io.open(charEditorModule.charConfigPath, "w")
    if f then f:write(json.encode(data)); f:close() end
end

function charEditorModule:saveConfig(player) persist(player) end

local function updateFrameFromParts(char, partData, frames, frameIdx)
    if not frames or frameIdx < 1 or frameIdx > #frames then return end
    local f = frames[frameIdx]
    for i, p in ipairs(char.parts) do
        if f[i] then
            for k, v in pairs(p) do
                if k ~= "name" and k ~= "type" then
                    f[i][k] = v
                end
            end
        end
    end
end

function charEditorModule:loadConfig(player)
    if not self.charConfigPath then
        self.charConfigPath = love.filesystem.getSource() .. "/char_config.json"
    end
    local f = io.open(self.charConfigPath, "r")
    local txt = f and f:read("*a") or ""
    if f then f:close() end
    if txt and txt ~= "" then
        local ok, parsed = pcall(json.decode, txt)
        if ok then
            if parsed.parts then
                local char = player.character
                char.parts = {}
                for _, src in ipairs(parsed.parts) do
                    local p = {}
                    for k, v in pairs(src) do p[k] = v end
                    Character.normalizePart(p)
                    table.insert(char.parts, p)
                end
            end
            if parsed.animations then
                self.animations = parsed.animations
                if #self.animations > 0 then self.animSel = 1; self.animFrame = 1 end
            end
        end
    end
end

function charEditorModule:keypressed(key, player)
    if self.editAnimName then
        if key == "backspace" then
            self.animNameBuf = self.animNameBuf:sub(1, -2)
            local anim = self.animations[self.animSel]
            if anim then anim.name = self.animNameBuf; persist(player) end
        elseif key == "return" or key == "escape" then
            self.editAnimName = false
            persist(player)
        end
        return
    end
    if self.editingName then
        if key == "backspace" then
            self.nameBuffer = self.nameBuffer:sub(1, -2)
            if self.currentPart then self.currentPart.name = self.nameBuffer end
            persist(self.currentPlayer)
        elseif key == "return" or key == "escape" then
            self.editingName = false
        end
        return
    end
    if key == "escape" then
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
                persist(player)
            end
        elseif self.tab == "ANIM" and self.animSel > 0 and #self.animations >= self.animSel then
            local frames = self.animations[self.animSel].frames
            local nf = #frames
            if nf > 0 then
                if key == "right" then
                    self.animFrame = math.min(nf, self.animFrame + 1)
                else
                    self.animFrame = math.max(1, self.animFrame - 1)
                end
                Character.applyPose(player.character, frames[self.animFrame])
            end
        end
    end
end
function charEditorModule:textinput(t)
    if self.editAnimName then
        self.animNameBuf = self.animNameBuf .. t
        local anim = self.animations[self.animSel]
        if anim then anim.name = self.animNameBuf; persist(self.currentPlayer) end
        return
    end
    if self.editingName and self.currentPart then
        self.nameBuffer = self.nameBuffer .. t
        self.currentPart.name = self.nameBuffer
        persist(self.currentPlayer)
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
        self.editingName = false  -- any new click closes name editing (re-enabled below if on the field)
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
                persist(player)
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
        -- Name editing activation (must come before type button)
        if part and mx >= PROP_X + 200 and mx <= PROP_X + 290 and my >= CONTENT_Y and my <= CONTENT_Y + 20 then
            self.editingName = true
            self.nameBuffer = part.name
            self.currentPart = part
            self.currentPlayer = player
            return
        end
        -- Type change button
        if part and mx >= PROP_X + 40 and mx <= PROP_X + 130 and my >= CONTENT_Y and my <= CONTENT_Y + 20 then
            local types = {"circle", "rect", "line"}
            for _, tname in ipairs(types) do
                if tname ~= part.type then
                    Character.changePartType(part, tname)
                    persist(player)
                    break
                end
            end
            return
        end

        if part then
            local params = Character.getParamMeta(part)
            local py2 = CONTENT_Y + 26
            local PROP_W = PANEL_X + PANEL_W - PROP_X - 10
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
                        -- start slider drag
                        self.dragSlider = {
                            part = part, key = pm.key, min = pm.min, max = pm.max,
                            sliderX = SLIDER_X, sliderW = SLIDER_W, player = player,
                        }
                    end
                    -- arrow buttons (only for selected param)
                    if pi == self.paramSel then
                        -- left arrow
                        if mx >= SLIDER_X - 16 and mx <= SLIDER_X - 2 and my >= sliderY and my <= sliderY + 14 then
                            part[pm.key] = math.max(pm.min, part[pm.key] - pm.step)
                            persist(player); return
                        end
                        -- right arrow
                        if mx >= SLIDER_X + SLIDER_W + 2 and mx <= SLIDER_X + SLIDER_W + 18 and my >= sliderY and my <= sliderY + 14 then
                            part[pm.key] = math.min(pm.max, part[pm.key] + pm.step)
                            persist(player); return
                        end
                    end
                    return
                end
                py2 = py2 + 22
            end
            for ci = 1, 8 do
                local sx = PROP_X + 50 + (ci - 1) * 22
                if mx >= sx and mx <= sx + 18 and my >= py2 and my <= py2 + 18 then
                    part.colorR, part.colorG, part.colorB = PRESET_COLORS[ci][1], PRESET_COLORS[ci][2], PRESET_COLORS[ci][3]
                    persist(player)
                    return
                end
            end
        end
    elseif self.tab == "ANIM" then
        local SIDEBAR_X = PANEL_X + 10
        local SIDEBAR_W = 110
        local CANVAS_X = PANEL_X + 135
        local CANVAS_Y = CONTENT_Y
        local CANVAS_S = 200
        local LIST_X = CANVAS_X + CANVAS_S + 15
        local LIST_W = PANEL_X + PANEL_W - LIST_X - 10
        local PROP_X = SIDEBAR_X
        local PROP_W = CANVAS_X + CANVAS_S - SIDEBAR_X
        local scale = 3
        local cx = CANVAS_X + CANVAS_S/2
        local cy = CANVAS_Y + CANVAS_S/2
        local relX = (mx - cx) / scale
        local relY = (my - cy) / scale
        self.editingName = false

        -- Sidebar: click to select part
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

        -- Canvas: click part to select, or start drag
        if mx >= CANVAS_X and mx <= CANVAS_X + CANVAS_S and
           my >= CANVAS_Y and my <= CANVAS_Y + CANVAS_S then
            for i = #char.parts, 1, -1 do
                if Character.hitTestPart(char.parts[i], relX, relY) then
                    self.partSel = i
                    if button == 1 then
                        self.dragging = true
                        self.dragPartSel = i
                    end
                    return
                end
            end
            -- clicked empty canvas area → start drag anyway (move selected part)
            if button == 1 then
                self.dragging = true
                self.dragPartSel = self.partSel
                return
            end
        end

        -- Anim list: click animation name
        local alx = LIST_X; local aly = CONTENT_Y + 26
        for ai, anim in ipairs(self.animations) do
            if mx >= alx and mx <= alx + LIST_W and my >= aly and my <= aly + 20 then
                self.animSel = ai
                self.animFrame = 1
                self.animPlaying = false
                Character.applyPose(char, anim.frames[1])
                return
            end
            aly = aly + 22
        end

        -- [New] animation button
        local newBtnX = LIST_X; local newBtnY = CONTENT_Y
        if mx >= newBtnX and mx <= newBtnX + 60 and my >= newBtnY and my <= newBtnY + 20 then
            local n = #self.animations + 1
            local snap = Character.snapshot(char)
            table.insert(self.animations, {name="Anim"..n, fps=8, frames={snap}})
            self.animSel = n
            self.animFrame = 1
            persist(player)
            return
        end
        -- [Delete] animation button
        local delBtnX = LIST_X + 65
        if mx >= delBtnX and mx <= delBtnX + 60 and my >= newBtnY and my <= newBtnY + 20 then
            if self.animSel > 0 and #self.animations >= self.animSel then
                table.remove(self.animations, self.animSel)
                self.animSel = math.min(self.animSel, #self.animations)
                self.animFrame = 1
                if self.animSel > 0 then
                    Character.applyPose(char, self.animations[self.animSel].frames[1])
                end
                persist(player)
            end
            return
        end

        -- Property sliders for selected part (below canvas)
        local part = char.parts[self.partSel]
        local nrows = 0
        if part then
            local params = Character.getParamMeta(part)
            nrows = #params
            local slY = CONTENT_Y + CANVAS_S + 8
            for pi, pm in ipairs(params) do
                local SLIDER_X = PROP_X + 80
                local SLIDER_W = PROP_W - 80
                local sliderY = slY + 2
                if my >= slY and my <= slY + 18 and mx >= PROP_X and mx <= PROP_X + PROP_W then
                    self.paramSel = pi
                    if mx >= SLIDER_X and mx <= SLIDER_X + SLIDER_W and
                       my >= sliderY and my <= sliderY + 14 then
                        local t = math.max(0, math.min(1, (mx - SLIDER_X) / SLIDER_W))
                        part[pm.key] = pm.min + t * (pm.max - pm.min)
                        self.dragSlider = {
                            part = part, key = pm.key, min = pm.min, max = pm.max,
                            sliderX = SLIDER_X, sliderW = SLIDER_W, player = player,
                        }
                    end
                    -- arrow buttons
                    if pi == self.paramSel then
                        if mx >= SLIDER_X - 16 and mx <= SLIDER_X - 2 and my >= sliderY and my <= sliderY + 14 then
                            part[pm.key] = math.max(pm.min, part[pm.key] - pm.step)
                            if self.animSel > 0 and #self.animations >= self.animSel then
                                updateFrameFromParts(char, nil, self.animations[self.animSel].frames, self.animFrame)
                            end
                            persist(player); return
                        end
                        if mx >= SLIDER_X + SLIDER_W + 2 and mx <= SLIDER_X + SLIDER_W + 18 and my >= sliderY and my <= sliderY + 14 then
                            part[pm.key] = math.min(pm.max, part[pm.key] + pm.step)
                            if self.animSel > 0 and #self.animations >= self.animSel then
                                updateFrameFromParts(char, nil, self.animations[self.animSel].frames, self.animFrame)
                            end
                            persist(player); return
                        end
                    end
                    return
                end
                slY = slY + 22
            end
        end

        -- Timeline area
        local anim = nil
        if self.animSel > 0 and #self.animations >= self.animSel then
            anim = self.animations[self.animSel]
        end
        if anim then
            local frames = anim.frames
            local nf = #frames
            local tlY = CONTENT_Y + CANVAS_S + 8 + nrows * 22 + 6

            -- Prev frame button
            if mx >= CANVAS_X and mx <= CANVAS_X + 24 and my >= tlY and my <= tlY + 24 then
                if nf > 0 then
                    self.animFrame = math.max(1, self.animFrame - 1)
                    Character.applyPose(char, frames[self.animFrame])
                end
                return
            end
            -- Next frame button
            if mx >= CANVAS_X + CANVAS_S - 24 and mx <= CANVAS_X + CANVAS_S and my >= tlY and my <= tlY + 24 then
                if nf > 0 then
                    self.animFrame = math.min(nf, self.animFrame + 1)
                    Character.applyPose(char, frames[self.animFrame])
                end
                return
            end
            -- Frame number buttons
            local fbx = CANVAS_X + 28
            for fi = 1, math.min(nf, 8) do
                if mx >= fbx and mx <= fbx + 24 and my >= tlY and my <= tlY + 24 then
                    self.animFrame = fi
                    Character.applyPose(char, frames[fi])
                    return
                end
                fbx = fbx + 28
            end

            -- [+Frame] button
            local addFx = LIST_X
            if mx >= addFx and mx <= addFx + 60 and my >= tlY and my <= tlY + 24 then
                local snap = Character.snapshot(char)
                table.insert(frames, snap)
                self.animFrame = #frames
                persist(player)
                return
            end
            -- [-Frame] button
            local delFx = LIST_X + 65
            if mx >= delFx and mx <= delFx + 60 and my >= tlY and my <= tlY + 24 and nf > 1 then
                table.remove(frames, self.animFrame)
                self.animFrame = math.min(self.animFrame, #frames)
                if #frames > 0 then Character.applyPose(char, frames[self.animFrame]) end
                persist(player)
                return
            end

            -- Controls row
            local ctrlY = tlY + 30

            -- Anim name editing (width 100 at LIST_X+52)
            if mx >= LIST_X + 52 and mx <= LIST_X + 152 and my >= ctrlY and my <= ctrlY + 20 then
                self.editAnimName = true
                self.animNameBuf = anim.name
                self.currentPlayer = player
                return
            end

            -- FPS slider (LIST_X + 165, width 50)
            local fpsX = LIST_X + 165; local fpsY = ctrlY + 4; local fpsW = 50
            if mx >= fpsX and mx <= fpsX + fpsW and my >= fpsY and my <= fpsY + 10 then
                anim.fps = math.max(1, math.min(24, math.floor((mx - fpsX) / fpsW * 24) + 1))
                persist(player)
                return
            end

            -- Play / Stop button (LIST_X + 230, width 50)
            local psx = LIST_X + 230
            if mx >= psx and mx <= psx + 50 and my >= ctrlY and my <= ctrlY + 20 then
                self.animPlaying = not self.animPlaying
                self.animTimer = 0
                if not self.animPlaying then
                    Character.applyPose(char, frames[self.animFrame])
                end
                persist(player)
                return
            end
        end
    end
end

function charEditorModule:mousemoved(mx, my, player)
    -- slider drag
    if self.dragSlider then
        local ds = self.dragSlider
        local t = math.max(0, math.min(1, (mx - ds.sliderX) / ds.sliderW))
        ds.part[ds.key] = ds.min + t * (ds.max - ds.min)
        if self.tab == "ANIM" and self.animSel > 0 and #self.animations >= self.animSel then
            local anim = self.animations[self.animSel]
            updateFrameFromParts(player.character, nil, anim.frames, self.animFrame)
        end
        return
    end
    if not (self.active and self.dragging) then return end
    local sw, sh = love.graphics.getDimensions()
    local PANEL_W = 620
    local PANEL_X = math.floor((sw - PANEL_W) / 2)
    local PANEL_Y = math.floor((sh - 520) / 2)
    local TAB_Y = PANEL_Y + 32
    local TAB_H = 24
    local CONTENT_Y = TAB_Y + TAB_H + 10
    local CANVAS_X = PANEL_X + 135
    local CANVAS_Y = CONTENT_Y
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
        -- If in ANIM tab, update current frame data
        if self.tab == "ANIM" and self.animSel > 0 and #self.animations >= self.animSel then
            local anim = self.animations[self.animSel]
            updateFrameFromParts(player.character, nil, anim.frames, self.animFrame)
        end
    end
end

function charEditorModule:mousereleased(mx, my, button, player)
    if button == 1 and self.dragSlider then
        if self.tab == "ANIM" and self.animSel > 0 and #self.animations >= self.animSel then
            local anim = self.animations[self.animSel]
            updateFrameFromParts(player.character, nil, anim.frames, self.animFrame)
        end
        persist(self.dragSlider.player)
        self.dragSlider = nil
    end
    if button == 1 and self.dragging and player then
        self.dragging = false
        if self.tab == "ANIM" and self.animSel > 0 and #self.animations >= self.animSel then
            local anim = self.animations[self.animSel]
            updateFrameFromParts(player.character, nil, anim.frames, self.animFrame)
        end
        persist(player)
    end
end

function charEditorModule:wheelmoved(x, y, player)
    if not (self.active and player and player.character) then return end
    if self.tab == "PARTES" then
        local part = player.character.parts[self.partSel]
        if part then
            local params = Character.getParamMeta(part)
            local pm = params[self.paramSel]
            if pm then
                part[pm.key] = math.max(pm.min, math.min(pm.max, part[pm.key] + pm.step * y))
                persist(player)
            end
        end
    elseif self.tab == "ANIM" and self.animSel > 0 and #self.animations >= self.animSel then
        local frames = self.animations[self.animSel].frames
        local nf = #frames
        if nf > 0 then
            self.animFrame = math.max(1, math.min(nf, self.animFrame - y))
            Character.applyPose(player.character, frames[self.animFrame])
            persist(player)
        end
    end
end

function charEditorModule:update(player, dt)
    if not (self.active and self.tab == "ANIM" and player and player.character) then return end
    if not (self.animPlaying and self.animSel > 0 and #self.animations >= self.animSel) then return end
    local anim = self.animations[self.animSel]
    local frames = anim.frames
    local nf = #frames
    if nf < 2 then return end
    self.animTimer = self.animTimer + dt * anim.fps
    if self.animTimer >= 1 then
        self.animTimer = self.animTimer - 1
        self.animFrame = self.animFrame + 1
        if self.animFrame > nf then
            self.animFrame = 1
        end
        Character.applyPose(player.character, frames[self.animFrame])
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
        local PROP_W = PANEL_X + PANEL_W - PROP_X - 10

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
                local selected = (pi == self.paramSel)
                -- background track
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W, 14)
                local t = (val - pm.min) / (pm.max - pm.min)
                -- filled portion: red when selected, blue otherwise
                if selected then
                    love.graphics.setColor(1, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W * t, 14)
                    love.graphics.setColor(1, 0.5, 0.5)
                    love.graphics.rectangle("line", SLIDER_X, sliderY, SLIDER_W, 14)
                    -- left / right arrow buttons
                    love.graphics.setFont(fonts.f14)
                    love.graphics.setColor(0.8, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X - 16, sliderY, 14, 14)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print("<", SLIDER_X - 15, sliderY - 1)
                    love.graphics.setColor(0.8, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X + SLIDER_W + 2, sliderY, 14, 14)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(">", SLIDER_X + SLIDER_W + 4, sliderY - 1)
                else
                    love.graphics.setColor(0.6, 0.8, 1.0)
                    love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W * t, 14)
                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.rectangle("line", SLIDER_X, sliderY, SLIDER_W, 14)
                end
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
    elseif self.tab == "ANIM" then
        local SIDEBAR_X = PANEL_X + 10
        local SIDEBAR_W = 110
        local CANVAS_X = PANEL_X + 135
        local CANVAS_Y = CONTENT_Y
        local CANVAS_S = 200
        local LIST_X = CANVAS_X + CANVAS_S + 15
        local LIST_W = PANEL_X + PANEL_W - LIST_X - 10
        local PROP_X = SIDEBAR_X
        local PROP_W = CANVAS_X + CANVAS_S - SIDEBAR_X
        local scale = 3
        local cx = CANVAS_X + CANVAS_S/2
        local cy = CANVAS_Y + CANVAS_S/2

        -- Sidebar: part list
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

        -- Canvas
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

        for i, p in ipairs(char.parts) do
            if p.type == "circle" then
                love.graphics.setColor(p.colorR, p.colorG, p.colorB)
                love.graphics.circle("fill", cx + p.offsetX * scale, cy + p.offsetY * scale, p.radius * scale)
            elseif p.type == "rect" then
                love.graphics.setColor(p.colorR, p.colorG, p.colorB)
                love.graphics.rectangle("fill", cx + p.offsetX * scale - p.width/2 * scale, cy + p.offsetY * scale - p.height/2 * scale, p.width * scale, p.height * scale)
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
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle("line", cx + p.offsetX * scale, cy + p.offsetY * scale, (p.radius or 6) * scale + 3)
            end
        end

        -- Property sliders for selected part (below canvas)
        local nrows = 0
        if part then
            local params = Character.getParamMeta(part)
            nrows = #params
            local slY = CONTENT_Y + CANVAS_S + 8
            love.graphics.setFont(fonts.f12)
            for pi, pm in ipairs(params) do
                local val = part[pm.key]
                local txt = pm.name .. ": " .. string.format(pm.fmt, val)
                love.graphics.setColor(pi == self.paramSel and 1 or 0.8, pi == self.paramSel and 1 or 0.8, pi == self.paramSel and 0 or 0.8)
                love.graphics.print(txt, PROP_X, slY)

                local SLIDER_X = PROP_X + 80
                local SLIDER_W = PROP_W - 80
                local sliderY = slY + 2
                local selected = (pi == self.paramSel)
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W, 14)
                local t = (val - pm.min) / (pm.max - pm.min)
                if selected then
                    love.graphics.setColor(1, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W * t, 14)
                    love.graphics.setColor(1, 0.5, 0.5)
                    love.graphics.rectangle("line", SLIDER_X, sliderY, SLIDER_W, 14)
                    love.graphics.setFont(fonts.f14)
                    love.graphics.setColor(0.8, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X - 16, sliderY, 14, 14)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print("<", SLIDER_X - 15, sliderY - 1)
                    love.graphics.setColor(0.8, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X + SLIDER_W + 2, sliderY, 14, 14)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(">", SLIDER_X + SLIDER_W + 4, sliderY - 1)
                else
                    love.graphics.setColor(0.6, 0.8, 1.0)
                    love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W * t, 14)
                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.rectangle("line", SLIDER_X, sliderY, SLIDER_W, 14)
                end
                slY = slY + 22
            end
        end

        -- Animation list (right)
        love.graphics.setFont(fonts.f12)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Animaciones:", LIST_X, CONTENT_Y)

        -- [New] [Delete] buttons
        love.graphics.setColor(0.3, 0.5, 0.3)
        love.graphics.rectangle("fill", LIST_X, CONTENT_Y + 14, 60, 18)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("+Nueva", LIST_X + 4, CONTENT_Y + 15)
        love.graphics.setColor(0.5, 0.3, 0.3)
        love.graphics.rectangle("fill", LIST_X + 65, CONTENT_Y + 14, 60, 18)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("-Borrar", LIST_X + 69, CONTENT_Y + 15)

        local aly = CONTENT_Y + 38
        for ai, anim in ipairs(self.animations) do
            local col = ai == self.animSel and {0.3, 0.5, 0.7} or {0.15, 0.15, 0.2}
            love.graphics.setColor(col)
            love.graphics.rectangle("fill", LIST_X, aly, LIST_W, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(anim.name .. " (" .. #anim.frames .. "f)", LIST_X + 4, aly + 3)
            aly = aly + 22
        end

        -- Timeline + controls (only if animation selected)
        if self.animSel > 0 and #self.animations >= self.animSel then
            local anim = self.animations[self.animSel]
            local frames = anim.frames
            local nf = #frames
            local tlY = CONTENT_Y + CANVAS_S + 8 + nrows * 22 + 6

            -- Prev / Next buttons
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", CANVAS_X, tlY, 24, 24)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f14)
            love.graphics.print("<", CANVAS_X + 7, tlY + 3)
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", CANVAS_X + CANVAS_S - 24, tlY, 24, 24)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(">", CANVAS_X + CANVAS_S - 17, tlY + 3)

            -- Frame number buttons
            love.graphics.setFont(fonts.f12)
            local fbx = CANVAS_X + 28
            for fi = 1, math.min(nf, 8) do
                local col = fi == self.animFrame and {0.3, 0.6, 0.9} or {0.2, 0.2, 0.3}
                love.graphics.setColor(col)
                love.graphics.rectangle("fill", fbx, tlY, 24, 24)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(fi, fbx + 7, tlY + 5)
                fbx = fbx + 28
            end

            -- [+Frame] [-Frame] buttons
            love.graphics.setColor(0.3, 0.5, 0.3)
            love.graphics.rectangle("fill", LIST_X, tlY, 60, 24)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f12)
            love.graphics.print("+Frame", LIST_X + 6, tlY + 5)
            love.graphics.setColor(0.5, 0.3, 0.3)
            love.graphics.rectangle("fill", LIST_X + 65, tlY, 60, 24)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("-Frame", LIST_X + 71, tlY + 5)
            love.graphics.print("Frame " .. self.animFrame .. "/" .. nf, CANVAS_X, tlY + 28)

            -- Controls row
            local ctrlY = tlY + 46
            love.graphics.setFont(fonts.f12)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("Nombre:", LIST_X, ctrlY)
            local nameCol = self.editAnimName and {0.3, 0.5, 0.7} or {0.2, 0.2, 0.3}
            love.graphics.setColor(nameCol)
            love.graphics.rectangle("fill", LIST_X + 52, ctrlY, 100, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(self.editAnimName and self.animNameBuf or anim.name, LIST_X + 56, ctrlY + 3)

            -- FPS slider
            local fpsX = LIST_X + 165; local fpsY = ctrlY + 4; local fpsW = 50
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("FPS:", fpsX - 32, ctrlY)
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", fpsX, fpsY, fpsW, 10)
            local ft = (anim.fps - 1) / 23
            love.graphics.setColor(0.6, 0.8, 1.0)
            love.graphics.rectangle("fill", fpsX, fpsY, fpsW * ft, 10)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.rectangle("line", fpsX, fpsY, fpsW, 10)
            love.graphics.print(tostring(anim.fps), fpsX + fpsW + 4, ctrlY)

            -- Play / Stop button
            local psx = LIST_X + 230
            love.graphics.setColor(self.animPlaying and {0.5, 0.3, 0.3} or {0.3, 0.5, 0.3})
            love.graphics.rectangle("fill", psx, ctrlY, 50, 20)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(self.animPlaying and "■ Stop" or "▶ Play", psx + 5, ctrlY + 3)
        end
    end

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(fonts.f12)
    love.graphics.print("ESC: cerrar | Tab: pestaña" .. (self.editingName and " | Escribiendo nombre..." or ""), PANEL_X + 10, PANEL_Y + PANEL_H - 20)
end

return charEditorModule