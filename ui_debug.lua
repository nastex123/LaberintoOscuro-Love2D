local json = require "json"

local ui_debug = {}

ui_debug.UI_CONFIG_PATH = "ui_config.json"
ui_debug.currentSeed = nil
ui_debug.configRef = nil

ui_debug.ui = {
    active = false,
    selection = 1,
    params = {"cols","rows","tile","roomCount","branchCount","branchLen","loopChance","perlinThresh", "- CHEST -", "Open Comun", "Open Epic", "Open Legend", "Offset X", "- HAND -", "Hand Radius", "Attack Duration", "- WATER -", "Water PixelCount", "Water Speed", "Water Distortion", "Water Scale", "- SPLASH -", "Splash PixelCount", "Splash CenterSize", "Splash Duration", "Splash Scale", "- RING -", "Ring Radius", "Ring Speed", "Ring Scale"}
}

ui_debug.paramDescriptions = {
    cols = "Número de columnas del laberinto",
    rows = "Número de filas del laberinto",
    tile = "Tamaño de cada celda en píxeles",
    roomCount = "Rango [mín‑máx] de habitaciones a crear",
    branchCount = "Rango [mín‑máx] de ramas (pasillos) a crear",
    branchLen = "Rango [mín‑máx] de longitud de cada rama",
    loopChance = "Probabilidad (0‑1) de crear lazos entre ramas",
    perlinThresh = "Umbral (0‑1) de ruido Perlin para degradar paredes",
    ["Open Comun"] = "Presiona Enter para abrir un cofre Común (sin animación)",
    ["Open Epic"] = "Presiona Enter para abrir un cofre Épico (sin animación)",
    ["Open Legend"] = "Presiona Enter para abrir un cofre Legendario (sin animación)",
    ["Offset X"] = "Desplazamiento manual de la rueda (-/+ 5px)",
    ["Hand Radius"] = "Radio de la mano respecto al jugador (-/+ 0.1 tiles)",
    ["Attack Duration"] = "Duración de la animación de ataque (-/+ 0.05s)",
    ["- WATER -"] = "=== AJUSTES DEL AGUA ===",
    ["Water PixelCount"] = "Pixelado del agua (10-60, -/+ 1)",
    ["Water Speed"] = "Velocidad de animación del agua (0.05-2.0, -/+ 0.05)",
    ["Water Distortion"] = "Intensidad de distorsión de ondas (0.01-0.50, -/+ 0.01)",
    ["- SPLASH -"] = "=== AJUSTES DEL SPLASH ===",
    ["Splash PixelCount"] = "Nivel de pixelado (10-80, -/+ 1)",
    ["Splash CenterSize"] = "Radio de espuma central (0.01-0.20, -/+ 0.01)",
    ["Splash Duration"] = "Duración de la animación en segundos (0.2-2.0, -/+ 0.05)",
    ["- RING -"] = "=== AJUSTES DEL ANILLO ===",
    ["Ring Radius"] = "Radio base del anillo (0.01-0.20, -/+ 0.01)",
    ["Ring Speed"] = "Velocidad de pulso (0.5-10.0, -/+ 0.5)",
    ["Water Scale"] = "Escala del patrón de agua (0.2-3.0, -/+ 0.1)",
    ["Splash Scale"] = "Escala del splash de entrada (0.2-3.0, -/+ 0.1)",
    ["Ring Scale"] = "Escala del anillo y partículas (0.2-3.0, -/+ 0.1)",
}

ui_debug.chestOffsetX = 0
ui_debug.handRadius = 1.5
ui_debug.attackDuration = 0.25

ui_debug.splashPhase = -1
ui_debug.splashWorldPos = {x = 0, y = 0}
ui_debug.wasInWater = false
ui_debug.inWaterFade = 0

ui_debug.splashDuration = 0.8
ui_debug.splashPixelCount = 40
ui_debug.splashCenterSize = 0.05
ui_debug.ringBaseRadius = 0.01
ui_debug.ringPulseSpeed = 3.0
ui_debug.waterScale = 1.0
ui_debug.splashScale = 1.0
ui_debug.ringScale = 1.0
ui_debug.waterPixelCount = 20
ui_debug.waterSpeed = 0.25
ui_debug.waterDistortion = 0.09

function ui_debug.saveConfig()
    local data = {
        chestOffsetX = ui_debug.chestOffsetX,
        handRadius = ui_debug.handRadius,
        attackDuration = ui_debug.attackDuration,
        splashDuration = ui_debug.splashDuration,
        splashPixelCount = ui_debug.splashPixelCount,
        splashCenterSize = ui_debug.splashCenterSize,
        ringBaseRadius = ui_debug.ringBaseRadius,
        ringPulseSpeed = ui_debug.ringPulseSpeed,
        waterScale = ui_debug.waterScale,
        splashScale = ui_debug.splashScale,
        ringScale = ui_debug.ringScale,
        waterPixelCount = ui_debug.waterPixelCount,
        waterSpeed = ui_debug.waterSpeed,
        waterDistortion = ui_debug.waterDistortion,
    }
    love.filesystem.write(ui_debug.UI_CONFIG_PATH, json.encode(data))
end

function ui_debug.loadConfig()
    local uiData = love.filesystem.read(ui_debug.UI_CONFIG_PATH)
    if uiData and uiData ~= "" then
        local ok, parsed = pcall(json.decode, uiData)
        if ok then
            if parsed.chestOffsetX ~= nil then ui_debug.chestOffsetX = parsed.chestOffsetX end
            if parsed.handRadius ~= nil then ui_debug.handRadius = parsed.handRadius end
            if parsed.attackDuration ~= nil then ui_debug.attackDuration = parsed.attackDuration end
            if parsed.splashDuration ~= nil then ui_debug.splashDuration = parsed.splashDuration end
            if parsed.splashPixelCount ~= nil then ui_debug.splashPixelCount = parsed.splashPixelCount end
            if parsed.splashCenterSize ~= nil then ui_debug.splashCenterSize = parsed.splashCenterSize end
            if parsed.ringBaseRadius ~= nil then ui_debug.ringBaseRadius = parsed.ringBaseRadius end
            if parsed.ringPulseSpeed ~= nil then ui_debug.ringPulseSpeed = parsed.ringPulseSpeed end
            if parsed.waterScale ~= nil then ui_debug.waterScale = parsed.waterScale end
            if parsed.splashScale ~= nil then ui_debug.splashScale = parsed.splashScale end
            if parsed.ringScale ~= nil then ui_debug.ringScale = parsed.ringScale end
            if parsed.waterPixelCount ~= nil then ui_debug.waterPixelCount = parsed.waterPixelCount end
            if parsed.waterSpeed ~= nil then ui_debug.waterSpeed = parsed.waterSpeed end
            if parsed.waterDistortion ~= nil then ui_debug.waterDistortion = parsed.waterDistortion end
        end
    end
end

function ui_debug.toggle(self)
    ui_debug.ui.active = not ui_debug.ui.active
end

function ui_debug.update(self, dt, maze, player, Tiles)
    if ui_debug.splashPhase >= 0 then
        ui_debug.splashPhase = ui_debug.splashPhase + dt / ui_debug.splashDuration
        if ui_debug.splashPhase >= 1.0 then ui_debug.splashPhase = -1 end
    end
    local inWater = maze:getTileAt(player.x, player.y) == Tiles.WATER
    if inWater and not ui_debug.wasInWater then
        ui_debug.splashPhase = 0
        ui_debug.splashWorldPos = {x = player.x, y = player.y}
    end
    if inWater then
        ui_debug.inWaterFade = math.min(1, ui_debug.inWaterFade + dt / 0.2)
    else
        ui_debug.inWaterFade = math.max(0, ui_debug.inWaterFade - dt / 0.5)
    end
    ui_debug.wasInWater = inWater
end

function ui_debug.keypressed(self, key, gameState, resetGameState_fn, pendingItem_ref, pendingTier_ref, waitingForDecision_ref, ChestAnim, Items)
    local sel = ui_debug.ui.selection
    local param = ui_debug.ui.params[sel]

    if key == "up" then
        ui_debug.ui.selection = (sel - 2) % #ui_debug.ui.params + 1
    elseif key == "down" then
        ui_debug.ui.selection = sel % #ui_debug.ui.params + 1
    elseif key == "right" then
        if param == "Offset X" then
            ui_debug.chestOffsetX = ui_debug.chestOffsetX + 5
            ui_debug.saveConfig()
            return
        end
        if param == "Hand Radius" then
            ui_debug.handRadius = ui_debug.handRadius + 0.1
            ui_debug.saveConfig()
            return
        end
        if param == "Attack Duration" then
            ui_debug.attackDuration = ui_debug.attackDuration + 0.05
            player.attackDuration = ui_debug.attackDuration
            ui_debug.saveConfig()
            return
        end
        if param == "Open Comun" or param == "Open Epic" or param == "Open Legend" or param == "- CHEST -" or param == "- HAND -" or param == "- WATER -" or param == "- SPLASH -" or param == "- RING -" then
            return
        end
        if param == "Splash PixelCount" then
            ui_debug.splashPixelCount = math.min(80, ui_debug.splashPixelCount + 1)
            return
        end
        if param == "Splash CenterSize" then
            ui_debug.splashCenterSize = math.min(0.20, ui_debug.splashCenterSize + 0.01)
            return
        end
        if param == "Splash Duration" then
            ui_debug.splashDuration = math.min(2.0, ui_debug.splashDuration + 0.05)
            return
        end
        if param == "Ring Radius" then
            ui_debug.ringBaseRadius = math.min(0.20, ui_debug.ringBaseRadius + 0.01)
            return
        end
        if param == "Ring Speed" then
            ui_debug.ringPulseSpeed = math.min(10.0, ui_debug.ringPulseSpeed + 0.5)
            return
        end
        if param == "Water PixelCount" then
            ui_debug.waterPixelCount = math.min(60, ui_debug.waterPixelCount + 1)
            return
        end
        if param == "Water Speed" then
            ui_debug.waterSpeed = math.min(2.0, ui_debug.waterSpeed + 0.05)
            return
        end
        if param == "Water Distortion" then
            ui_debug.waterDistortion = math.min(0.50, ui_debug.waterDistortion + 0.01)
            return
        end
        if param == "Water Scale" then
            ui_debug.waterScale = math.min(3.0, ui_debug.waterScale + 0.1)
            return
        end
        if param == "Splash Scale" then
            ui_debug.splashScale = math.min(3.0, ui_debug.splashScale + 0.1)
            return
        end
        if param == "Ring Scale" then
            ui_debug.ringScale = math.min(3.0, ui_debug.ringScale + 0.1)
            return
        end
        if param == "roomCount" or param == "branchCount" or param == "branchLen" then
            if type(ui_debug.configRef[param]) ~= "table" then
                local cur = ui_debug.configRef[param] or 1
                ui_debug.configRef[param] = {cur, cur}
            end
            ui_debug.configRef[param][2] = (ui_debug.configRef[param][2] or ui_debug.configRef[param][1]) + 1
        elseif param == "loopChance" or param == "perlinThresh" then
            ui_debug.configRef[param] = math.min(1, (ui_debug.configRef[param] or 0) + 0.05)
        else
            ui_debug.configRef[param] = (ui_debug.configRef[param] or 0) + 1
        end
    elseif key == "left" then
        if param == "Offset X" then
            ui_debug.chestOffsetX = ui_debug.chestOffsetX - 5
            ui_debug.saveConfig()
            return
        end
        if param == "Hand Radius" then
            ui_debug.handRadius = math.max(0.1, ui_debug.handRadius - 0.1)
            ui_debug.saveConfig()
            return
        end
        if param == "Attack Duration" then
            ui_debug.attackDuration = math.max(0.1, ui_debug.attackDuration - 0.05)
            player.attackDuration = ui_debug.attackDuration
            ui_debug.saveConfig()
            return
        end
        if param == "Open Comun" or param == "Open Epic" or param == "Open Legend" or param == "- CHEST -" or param == "- HAND -" or param == "- WATER -" or param == "- SPLASH -" or param == "- RING -" then
            return
        end
        if param == "Splash PixelCount" then
            ui_debug.splashPixelCount = math.max(10, ui_debug.splashPixelCount - 1)
            return
        end
        if param == "Splash CenterSize" then
            ui_debug.splashCenterSize = math.max(0.01, ui_debug.splashCenterSize - 0.01)
            return
        end
        if param == "Splash Duration" then
            ui_debug.splashDuration = math.max(0.2, ui_debug.splashDuration - 0.05)
            return
        end
        if param == "Ring Radius" then
            ui_debug.ringBaseRadius = math.max(0.01, ui_debug.ringBaseRadius - 0.01)
            return
        end
        if param == "Ring Speed" then
            ui_debug.ringPulseSpeed = math.max(0.5, ui_debug.ringPulseSpeed - 0.5)
            return
        end
        if param == "Water PixelCount" then
            ui_debug.waterPixelCount = math.max(10, ui_debug.waterPixelCount - 1)
            return
        end
        if param == "Water Speed" then
            ui_debug.waterSpeed = math.max(0.05, ui_debug.waterSpeed - 0.05)
            return
        end
        if param == "Water Distortion" then
            ui_debug.waterDistortion = math.max(0.01, ui_debug.waterDistortion - 0.01)
            return
        end
        if param == "Water Scale" then
            ui_debug.waterScale = math.max(0.2, ui_debug.waterScale - 0.1)
            return
        end
        if param == "Splash Scale" then
            ui_debug.splashScale = math.max(0.2, ui_debug.splashScale - 0.1)
            return
        end
        if param == "Ring Scale" then
            ui_debug.ringScale = math.max(0.2, ui_debug.ringScale - 0.1)
            return
        end
        if param == "roomCount" or param == "branchCount" or param == "branchLen" then
            if type(ui_debug.configRef[param]) ~= "table" then
                local cur = ui_debug.configRef[param] or 1
                ui_debug.configRef[param] = {cur, cur}
            end
            ui_debug.configRef[param][2] = math.max(1, (ui_debug.configRef[param][2] or ui_debug.configRef[param][1]) - 1)
        elseif param == "loopChance" or param == "perlinThresh" then
            ui_debug.configRef[param] = math.max(0, (ui_debug.configRef[param] or 0) - 0.05)
        else
            ui_debug.configRef[param] = math.max(1, (ui_debug.configRef[param] or 1) - 1)
        end
    elseif key == "return" or key == "kpenter" then
        local tier = nil
        if param == "Open Comun" then
            tier = "common"
        elseif param == "Open Epic" then
            tier = "epic"
        elseif param == "Open Legend" then
            tier = "legendary"
        end
        if tier and ChestAnim.state == "idle" and gameState == "play" then
            local itemId = Items.randomFromTier(tier)
            if itemId then
                pendingItem_ref[1] = itemId
                pendingTier_ref[1] = tier
                waitingForDecision_ref[1] = false
                ChestAnim:start(tier, itemId, ui_debug.chestOffsetX)
            end
        end
        return
    elseif key == "r" then
        resetGameState_fn()
    elseif key == "escape" then
        ui_debug.ui.active = false
    end
end

function ui_debug.draw()
    if not ui_debug.ui.active then return end

    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0,0,0,0.6)
    love.graphics.rectangle("fill", 10, 10, 350, (#ui_debug.ui.params+4)*18)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fonts.f14)
    love.graphics.print("Seed: "..tostring(ui_debug.currentSeed), 20, 20)
    for i, p in ipairs(ui_debug.ui.params) do
        local txt
        if p == "- CHEST -" then
            txt = "=== " .. p .. " ==="
        elseif p == "- HAND -" then
            txt = "=== " .. p .. " ==="
        elseif p == "Open Comun" or p == "Open Epic" or p == "Open Legend" then
            txt = p
        elseif p == "Offset X" then
            txt = p .. ": " .. ui_debug.chestOffsetX
        elseif p == "Hand Radius" then
            txt = p .. ": " .. string.format("%.1f", ui_debug.handRadius)
        elseif p == "Attack Duration" then
            txt = p .. ": " .. string.format("%.2fs", ui_debug.attackDuration)
        elseif p == "- WATER -" then
            txt = "=== " .. p .. " ==="
        elseif p == "- SPLASH -" then
            txt = "=== " .. p .. " ==="
        elseif p == "- RING -" then
            txt = "=== " .. p .. " ==="
        elseif p == "Water PixelCount" then
            txt = p .. ": " .. ui_debug.waterPixelCount
        elseif p == "Water Speed" then
            txt = p .. ": " .. string.format("%.2f", ui_debug.waterSpeed)
        elseif p == "Water Distortion" then
            txt = p .. ": " .. string.format("%.2f", ui_debug.waterDistortion)
        elseif p == "Splash PixelCount" then
            txt = p .. ": " .. ui_debug.splashPixelCount
        elseif p == "Splash CenterSize" then
            txt = p .. ": " .. string.format("%.2f", ui_debug.splashCenterSize)
        elseif p == "Splash Duration" then
            txt = p .. ": " .. string.format("%.1fs", ui_debug.splashDuration)
        elseif p == "Ring Radius" then
            txt = p .. ": " .. string.format("%.2f", ui_debug.ringBaseRadius)
        elseif p == "Ring Speed" then
            txt = p .. ": " .. string.format("%.1f", ui_debug.ringPulseSpeed)
        elseif p == "Water Scale" then
            txt = p .. ": " .. string.format("%.1f", ui_debug.waterScale) .. "x"
        elseif p == "Splash Scale" then
            txt = p .. ": " .. string.format("%.1f", ui_debug.splashScale) .. "x"
        elseif p == "Ring Scale" then
            txt = p .. ": " .. string.format("%.1f", ui_debug.ringScale) .. "x"
        else
            local val = ui_debug.configRef[p]
            if type(val) == "table" then
                txt = p..": ["..val[1]..","..val[2].."]"
            else
                txt = p..": "..tostring(val)
            end
        end

        if p == "- CHEST -" or p == "- HAND -" or p == "- WATER -" or p == "- SPLASH -" or p == "- RING -" then
            love.graphics.setColor(0.8, 0.8, 0.8)
        elseif i == ui_debug.ui.selection then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.print(txt, 20, 20 + i*18)

        if i == ui_debug.ui.selection then
            local desc = ui_debug.paramDescriptions[p] or ""
            love.graphics.setColor(0.8,0.8,0.8)
            love.graphics.print(desc, 160, 20 + i*18 + 20)
        end
    end
end

return ui_debug