-- main.lua – Love2D entry point, full-feature implementation

local Maze   = require "maze"
local Player = require "player"
local Criker = require "criker"
local Debug  = require "debugInfo"
local Items  = require "items"
local Vault  = require "vault"
local ChestAnim = require "chest_animation"

local lives = 3
local state = "play" -- "play", "win", "dead"
local time = 0
local camera = {x = 0, y = 0}

-- Canvases and shaders for lighting
local sceneCanvas, lightCanvas
local shaders = {}
local currentShader = 1
local shaderNames = {}

-- Table de luces estáticas
local lights = {}
local json = require "json"
local UI_CONFIG_PATH = "ui_config.json"

local function addLight(x, y, radius, color, falloff)
    lights[#lights+1] = {x=x, y=y, radius=radius, color=color, falloff=falloff or 2}
end

local currentTemplates = {}

local editor = {
    active = false, currentIdx = 1, grid = {},
    cursorX = 1, cursorY = 1, brush = 0,
    width = 10, height = 10, name = "Nueva sala",
}
local brushChars = {[0]='.', [1]='#', [2]='X', [3]='L', [4]='R', [5]='C', [6]='G', [7]='?'}
local brushNames = {[0]="Suelo", [1]="Pared", [2]="Salida", [3]="Luz", [4]="Cofre épico", [5]="Cofre común", [6]="Cofre legendario", [7]="Cofre aleatorio"}

local function setGridChar(grid, x, y, ch)
    local row = grid[y]
    if not row or x < 1 or x > #row then return end
    grid[y] = row:sub(1, x-1) .. ch .. row:sub(x+1)
end

local function initEditor()
    if #currentTemplates > 0 then
        editor.currentIdx = math.min(editor.currentIdx, #currentTemplates)
        editor.currentIdx = math.max(editor.currentIdx, 1)
        local tmpl = currentTemplates[editor.currentIdx]
        editor.grid = {}
        for _, row in ipairs(tmpl.grid) do
            table.insert(editor.grid, row)
        end
        if #editor.grid > 0 and #editor.grid[1] > 0 then
            editor.width = #editor.grid[1]
            editor.height = #editor.grid
        else
            editor.grid = {}
            for y = 1, 10 do
                editor.grid[y] = string.rep(".", 10)
            end
            editor.width = 10
            editor.height = 10
        end
        editor.name = tmpl.name
    else
        editor.grid = {}
        for y = 1, 10 do
            editor.grid[y] = string.rep(".", 10)
        end
        editor.width = 10
        editor.height = 10
        editor.name = "Nueva sala"
    end
    editor.cursorX = 1
    editor.cursorY = 1
end

local function saveEditorData()
    local tmpl = currentTemplates[editor.currentIdx]
    if tmpl then
        tmpl.grid = {}
        for _, row in ipairs(editor.grid) do
            table.insert(tmpl.grid, row)
        end
        tmpl.name = editor.name
    end
    local lines = {
        "-- room_templates.lua – Plantillas de salas personalizadas",
        "-- Editado desde el editor in-game (F2)",
        "",
        "local templates = {",
    }
    for _, t in ipairs(currentTemplates) do
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
    else
        print("Error al guardar:", err)
    end
end

local function loadShaders()
    -- Cargamos únicamente el shader de caída cuadrática (falloff)
    local ok, shader = pcall(love.graphics.newShader, "shaders/light_falloff.glsl")
    if ok then
        shaders[1] = shader
        shaderNames[1] = "Falloff Cuadratico"
    else
        error("Error cargando shader light_falloff.glsl: " .. tostring(shader))
    end
    currentShader = 1
end

local function initCanvases()
    local w, h = love.graphics.getDimensions()
    sceneCanvas = love.graphics.newCanvas(w, h)
    lightCanvas = love.graphics.newCanvas(w, h)
end

function love.load()
    love.window.setTitle("Luz en la Oscuridad — Exploracion")

    -- Precargar todas las fuentes (evita newFont en cada frame = memory leak)
    fonts = {
        f12 = love.graphics.newFont(12),
        f14 = love.graphics.newFont(14),
        f16 = love.graphics.newFont(16),
        f18 = love.graphics.newFont(18),
        f22 = love.graphics.newFont(22),
        f24 = love.graphics.newFont(24),
        f36 = love.graphics.newFont(36),
    }

    --=== 1. Cargar configuración por defecto (JSON) ===
    local configPath = "maze_config.json"
    local configData = love.filesystem.read(configPath) or ""
    local config = {
        cols = 145, rows = 145, tile = 75,
        roomCount = {16, 20}, branchCount = {6, 12},
        branchLen = {30, 30}, loopChance = 0.8,
        perlinThresh = 0.25, seed = nil,
    }
    if configData ~= "" then
        local ok, parsed = pcall(json.decode, configData)
        if ok then
            for k, v in pairs(parsed) do config[k] = v end
        else
            print("Error al leer maze_config.json:", parsed)
        end
    end
    --=== 2. Sobrescribir con argumentos de línea de comandos ===
    local function applyArg(key, value)
        if key == "cols" or key == "rows" or key == "tile" then
            config[key] = tonumber(value)
        elseif key == "rooms" then
            local a,b = value:match("(%d+)%-(%d+)")
            if a and b then config.roomCount = {tonumber(a), tonumber(b)} end
        elseif key == "branches" then
            local a,b = value:match("(%d+)%-(%d+)")
            if a and b then config.branchCount = {tonumber(a), tonumber(b)} end
        elseif key == "branchlen" then
            local a,b = value:match("(%d+)%-(%d+)")
            if a and b then config.branchLen = {tonumber(a), tonumber(b)} end
        elseif key == "loopchance" then
            config.loopChance = tonumber(value)
        elseif key == "perlin" then
            config.perlinThresh = tonumber(value)
        elseif key == "seed" then
            config.seed = tonumber(value)
        elseif key == "debugstep" then
            config.debugStep = value
        end
    end
    if arg then
        for _, a in ipairs(arg) do
            local k,v = a:match("%-%-(%w+)=(.+)")
            if k and v then applyArg(k:lower(), v) end
        end
    end

    --=== 3. Semilla (determinista si se indica) ===
    local seed = config.seed or os.time()
    love.math.setRandomSeed(seed)
    currentSeed = seed

    --=== 4. Crear laberinto con la configuración ===
    maze = Maze:new(config)
    -- Generar laberinto según paso de depuración opcional
    if config.debugStep then
        local step = config.debugStep:lower()
        if step == "rooms" then
            maze:createRooms()
        elseif step == "spine" then
            maze:createRooms()
            maze:buildSpine()
        elseif step == "branches" then
            maze:createRooms()
            maze:buildSpine()
            maze:buildBranches()
        elseif step == "loops" then
            maze:createRooms()
            maze:buildSpine()
            maze:buildBranches()
            maze:buildLoops()
        elseif step == "degrade" then
            maze:createRooms()
            maze:buildSpine()
            maze:buildBranches()
            maze:buildLoops()
            maze:degradeEdges()
        elseif step == "grid" then
            maze:createRooms()
            maze:buildSpine()
            maze:buildBranches()
            maze:buildLoops()
            maze:degradeEdges()
        elseif step == "lights" then
            maze:createRooms()
            maze:buildSpine()
            maze:buildBranches()
            maze:buildLoops()
            maze:degradeEdges()
        else
            maze:generate()
        end
    else
        maze:generate()
    end

    player = Player:new()
    player.inventory = {}
    player.effects = {}
    criker = Criker:new()
    if maze.startRoom then
        player:setPos(maze.startRoom, maze)
    end

    -- Place vaults
    Vault:placeAll(maze)

    initCanvases()
    loadShaders()

    -- Cargar plantillas de salas personalizadas
    currentTemplates = require "room_templates"

    --=== 5. UI de depuración en tiempo real ===
    ui = {
        active = false,
        selection = 1,
        -- Añadimos las nuevas opciones de cofres y un separador visual
        params = {"cols","rows","tile","roomCount","branchCount","branchLen","loopChance","perlinThresh", "- CHEST -", "Open Comun", "Open Epic", "Open Legend", "Offset X"}
    }
    -- Descripciones breves de cada parámetro del menú UI (F1)
    paramDescriptions = {
        cols = "Número de columnas del laberinto",
        rows = "Número de filas del laberinto",
        tile = "Tamaño de cada celda en píxeles",
        roomCount = "Rango [mín‑máx] de habitaciones a crear",
        branchCount = "Rango [mín‑máx] de ramas (pasillos) a crear",
        branchLen = "Rango [mín‑máx] de longitud de cada rama",
        loopChance = "Probabilidad (0‑1) de crear lazos entre ramas",
        perlinThresh = "Umbral (0‑1) de ruido Perlin para degradar paredes",
        -- Nuevas descripciones para los cofres
        ["Open Comun"] = "Presiona Enter para abrir un cofre Común (sin animación)",
        ["Open Epic"] = "Presiona Enter para abrir un cofre Épico (sin animación)",
        ["Open Legend"] = "Presiona Enter para abrir un cofre Legendario (sin animación)",
        ["Offset X"] = "Desplazamiento manual de la rueda (-/+ 5px)",
    }
    configRef = config   -- referencia global para la UI
    chestOffsetX = 0    -- ajuste manual para centrar la animación

    -- Variables para el sistema de reemplazo de inventario
    pendingItem = nil
    pendingTier = nil
    waitingForDecision = false

    -- Cargar configuración de UI (offset del cofre)
    local uiData = love.filesystem.read(UI_CONFIG_PATH)
    if uiData and uiData ~= "" then
        local ok, parsed = pcall(json.decode, uiData)
        if ok and parsed.chestOffsetX ~= nil then
            chestOffsetX = parsed.chestOffsetX
        end
    end

    --=== 6. Luz estática de salida (amarilla) ===
    if maze.exitCell then
        addLight(maze.exitCell.x * maze.tile, maze.exitCell.y * maze.tile,
                 120, {1,0.9,0}, 2)  -- amarillo
    end
end

-- Input handling – keyboard only
local function getInput()
    local x, y = 0, 0
    if love.keyboard.isDown("left", "a") then x = -1 end
    if love.keyboard.isDown("right", "d") then x = 1 end
    if love.keyboard.isDown("up", "w") then y = -1 end
    if love.keyboard.isDown("down", "s") then y = 1 end
    return {x = x, y = y}
end

local function getInventorySlots(player)
    local slots = {}
    for id, data in pairs(player.inventory) do
        table.insert(slots, {id = id, data = data, def = Items.defs[id]})
    end
    table.sort(slots, function(a, b) return a.def.nombre < b.def.nombre end)
    return slots
end

local function saveUIConfig()
    local data = { chestOffsetX = chestOffsetX }
    local content = json.encode(data)
    love.filesystem.write(UI_CONFIG_PATH, content)
end

-- Resetea una partida completa conservando la configuracion actual.
-- Usado por la tecla R y por el reinicio tras win/dead.
local function resetGameState()
    lights = {}
    maze = Maze:new(configRef)
    maze:generate()
    player = Player:new()
    player.inventory = {}
    player.effects = {}
    criker = Criker:new()
    crikerSpawnTimer = 0
    Vault:placeAll(maze)
    player:setPos(maze.startRoom, maze)
    if maze.exitCell then
        addLight(maze.exitCell.x * maze.tile, maze.exitCell.y * maze.tile, 120, {1,0.9,0}, 2)
    end
    -- Centrar la camara sobre el jugador para evitar el slide inicial.
    camera.x = player.x - love.graphics.getWidth() / 2
    camera.y = player.y - love.graphics.getHeight() / 2
    time = 0
    lives = 3
    state = "play"
    pendingItem = nil
    pendingTier = nil
    waitingForDecision = false
    uiState = nil
end

-- Construye el contexto que los consumibles necesitan para mutar el mundo.
local function buildConsumableContext()
    return {
        -- Curacion
        heal = function(amount)
            lives = math.min(lives + amount, 3)
        end,
        healFull = function()
            lives = 3
        end,
        -- Teletransporte a la sala segura
        tpSafe = function()
            if maze.safeRoom then
                player.x = (maze.safeRoom.cx + 0.5) * maze.tile
                player.y = (maze.safeRoom.cy + 0.5) * maze.tile
            end
        end,
        -- Teletransporte a la salida
        tpExit = function()
            if maze.exitCell then
                player.x = (maze.exitCell.x + 0.5) * maze.tile
                player.y = (maze.exitCell.y + 0.5) * maze.tile
            end
        end,
        -- Báculo de luz: deja una luz estática permanente en el tile del jugador
        dropLight = function()
            addLight(player.x, player.y, 90, {1, 1, 0.8}, 2)
        end,
        -- Tiza / Cinta / Lentes: marcan el tile actual
        markTile = function(id)
            local tx = math.floor(player.x / maze.tile)
            local ty = math.floor(player.y / maze.tile)
            markedTiles = markedTiles or {}
            markedTiles[ty] = markedTiles[ty] or {}
            markedTiles[ty][tx] = id or "marca"
        end,
    }
end

-- No shader switching: solo se usa el shader Falloff
function love.keypressed(key)
    -- Prioridad: Menú de reemplazo de inventario
    if waitingForDecision and uiState == "inventory_prompt" then
        if key == "escape" then
            pendingItem = nil
            pendingTier = nil
            waitingForDecision = false
            uiState = nil
            return
        elseif key == "1" or key == "2" or key == "3" then
            local idx = tonumber(key)
            local slots = getInventorySlots(player)
            if slots[idx] then
                player.inventory[slots[idx].id] = nil
                Items.give(player, pendingItem)
                pendingItem = nil
                pendingTier = nil
                waitingForDecision = false
                uiState = nil
            end
            return
        end
        return
    end

    -- Reinicio tras ganar o morir
    if (state == "dead" or state == "win") and (key == "r" or key == "return") then
        resetGameState()
        return
    end

    -- Editor toggle
    if key == "f2" then
        editor.active = not editor.active
        if editor.active then initEditor() end
        return
    end
    -- Editor keys
    if editor.active then
        if key == "escape" then
            editor.active = false
        elseif key == "up" then
            editor.cursorY = math.max(1, editor.cursorY - 1)
        elseif key == "down" then
            editor.cursorY = math.min(#editor.grid, editor.cursorY + 1)
        elseif key == "left" then
            editor.cursorX = math.max(1, editor.cursorX - 1)
        elseif key == "right" then
            editor.cursorX = math.min(#editor.grid[1], editor.cursorX + 1)
        elseif key == "space" then
            local ch = brushChars[editor.brush] or '.'
            setGridChar(editor.grid, editor.cursorX, editor.cursorY, ch)
            if editor.cursorX < #editor.grid[1] then
                editor.cursorX = editor.cursorX + 1
            elseif editor.cursorY < #editor.grid then
                editor.cursorX = 1
                editor.cursorY = editor.cursorY + 1
            end
        elseif key == "1" then editor.brush = 0
        elseif key == "2" then editor.brush = 1
        elseif key == "3" then editor.brush = 3
        elseif key == "4" then editor.brush = 2
        elseif key == "5" then editor.brush = 4
        elseif key == "6" then editor.brush = 5
        elseif key == "7" then editor.brush = 6
        elseif key == "8" then editor.brush = 7
        elseif key == "s" then
            saveEditorData()
            package.loaded["room_templates"] = nil
            currentTemplates = require "room_templates"
        elseif key == "tab" then
            local tmpl = currentTemplates[editor.currentIdx]
            if tmpl then
                tmpl.grid = {}
                for _, row in ipairs(editor.grid) do
                    table.insert(tmpl.grid, row)
                end
            end
            if #currentTemplates > 0 then
                editor.currentIdx = editor.currentIdx % #currentTemplates + 1
            end
            initEditor()
        elseif key == "n" then
            table.insert(currentTemplates, {name = "Nueva sala", grid = {}})
            editor.currentIdx = #currentTemplates
            initEditor()
            editor.grid = {}
            for y = 1, 10 do
                editor.grid[y] = string.rep(".", 10)
            end
            editor.width = 10
            editor.height = 10
            editor.name = "Nueva sala"
        elseif key == "r" then
            if love.keyboard.isDown("lshift", "rshift") then
                if editor.height > 3 then
                    table.remove(editor.grid)
                    editor.height = editor.height - 1
                    editor.cursorY = math.min(editor.cursorY, editor.height)
                end
            elseif editor.height < 30 then
                table.insert(editor.grid, string.rep(".", editor.width))
                editor.height = editor.height + 1
            end
        elseif key == "c" then
            if love.keyboard.isDown("lshift", "rshift") then
                if editor.width > 3 then
                    for y = 1, #editor.grid do
                        editor.grid[y] = editor.grid[y]:sub(1, -2)
                    end
                    editor.width = editor.width - 1
                    editor.cursorX = math.min(editor.cursorX, editor.width)
                end
            elseif editor.width < 30 then
                for y = 1, #editor.grid do
                    editor.grid[y] = editor.grid[y] .. "."
                end
                editor.width = editor.width + 1
            end
        end
        return
    end
    -- Chest animation close
    if key == "e" and ChestAnim.state == "done" then
        ChestAnim:close()
        return
    end

    -- Open vault
    if key == "e" and ChestAnim.state == "idle" and state == "play" then
        local vault, tx, ty = Vault:playerOnVault(player, maze)
        if vault then
            local itemId, tier = Vault:openVault(maze, tx, ty)
            if itemId then
                pendingItem = itemId
                pendingTier = tier
                waitingForDecision = false
                ChestAnim:start(tier, itemId, chestOffsetX)
            end
        end
        return
    end

    -- Attack with weapon
    if key == "space" and ChestAnim.state == "idle" and state == "play" then
        local weapon = Items.getWeapon(player)
        if weapon and criker.active then
            local d = math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2)
            -- Armas ranged (Honda, Arco de caza, Arco largo) atacan a distancia;
            -- el resto es cuerpo a cuerpo.
            local range = (weapon.range == "ranged") and 180 or 45
            if d < range then
                if weapon.range == "ranged" then
                    -- a distancia solo aplica si hay linea de vision
                    if maze:hasLineOfSight(player.x, player.y, criker.x, criker.y) then
                        Items.useWeapon(player)
                        criker:stun(weapon.stunDuration or 3)
                    end
                else
                    Items.useWeapon(player)
                    criker:stun(weapon.stunDuration or 3)
                end
            end
        end
        return
    end

    -- Use consumable (tecla Q): usa el primer consumible del inventario.
    if key == "q" and ChestAnim.state == "idle" and state == "play" then
        -- Buscamos el primer consumible con usos disponibles.
        local target = nil
        for id, data in pairs(player.inventory) do
            local def = Items.defs[id]
            if def and def.type == "consumable" then
                local uses = type(data) == "table" and data.uses or 1
                if uses and uses > 0 then
                    -- Preferimos curacion/TP si hace falta; si no, el primero.
                    if target == nil then target = id end
                end
            end
        end
        if target then
            local ctx = buildConsumableContext()
            Items.useConsumable(player, target, ctx)
        end
        return
    end

    -- UI toggle
    if key == "f1" then
        ui.active = not ui.active
        return
    end
    if not ui.active then return end

    -- Navegación y acciones del menú
    local sel = ui.selection
    local param = ui.params[sel]

    if key == "up" then
        ui.selection = (sel - 2) % #ui.params + 1
    elseif key == "down" then
        ui.selection = sel % #ui.params + 1
    elseif key == "right" then
        if param == "Offset X" then
            chestOffsetX = chestOffsetX + 5
            saveUIConfig()
            return
        end
        if param == "Open Comun" or param == "Open Epic" or param == "Open Legend" or param == "- CHEST -" then
            return
        end
        if param == "roomCount" or param == "branchCount" or param == "branchLen" then
            if type(configRef[param]) ~= "table" then
                local cur = configRef[param] or 1
                configRef[param] = {cur, cur}
            end
            configRef[param][2] = (configRef[param][2] or configRef[param][1]) + 1
        elseif param == "loopChance" or param == "perlinThresh" then
            configRef[param] = math.min(1, (configRef[param] or 0) + 0.05)
        else
            configRef[param] = (configRef[param] or 0) + 1
        end
    elseif key == "left" then
        if param == "Offset X" then
            chestOffsetX = chestOffsetX - 5
            saveUIConfig()
            return
        end
        if param == "Open Comun" or param == "Open Epic" or param == "Open Legend" or param == "- CHEST -" then
            return
        end
        if param == "roomCount" or param == "branchCount" or param == "branchLen" then
            if type(configRef[param]) ~= "table" then
                local cur = configRef[param] or 1
                configRef[param] = {cur, cur}
            end
            configRef[param][2] = math.max(1, (configRef[param][2] or configRef[param][1]) - 1)
        elseif param == "loopChance" or param == "perlinThresh" then
            configRef[param] = math.max(0, (configRef[param] or 0) - 0.05)
        else
            configRef[param] = math.max(1, (configRef[param] or 1) - 1)
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
        
        if tier and ChestAnim.state == "idle" and state == "play" then
            local itemId = Items.randomFromTier(tier)
            if itemId then
                pendingItem = itemId
                pendingTier = tier
                waitingForDecision = false
                ChestAnim:start(tier, itemId, chestOffsetX)
            end
        end
        return
    elseif key == "r" then
        -- Regenerar el laberinto con la configuración actual
        resetGameState()
    elseif key == "escape" then
        ui.active = false
    end
end

-- === Mouse support for the F2 editor ===
local function editorCellFromMouse(mx, my)
    local sw, sh = love.graphics.getDimensions()
    local ET = 32
    local gridW = editor.width * ET
    local gridH = editor.height * ET
    local gx = math.floor((mx - math.max(10, (sw - gridW) / 2)) / ET) + 1
    local gy = math.floor((my - math.max(10, (sh - gridH) / 2)) / ET) + 1
    if gx < 1 or gx > editor.width or gy < 1 or gy > editor.height then return end
    return gx, gy
end

local function editorPaintCell(gx, gy, brush)
    editor.cursorX, editor.cursorY = gx, gy
    setGridChar(editor.grid, gx, gy, brushChars[brush] or '.')
end

function love.mousepressed(mx, my, button)
    if editor.active then
        local gx, gy = editorCellFromMouse(mx, my)
        if gx then
            if button == 1 then
                editorPaintCell(gx, gy, editor.brush)
            elseif button == 2 then
                editorPaintCell(gx, gy, 0)
            end
        end
        return
    end
end

function love.mousemoved(mx, my)
    if editor.active then
        if love.mouse.isDown(1) or love.mouse.isDown(2) then
            local gx, gy = editorCellFromMouse(mx, my)
            if gx then
                editorPaintCell(gx, gy, love.mouse.isDown(1) and editor.brush or 0)
            end
        end
        return
    end
end

local crikerSpawnTimer = 0
function love.update(dt)
    if editor.active then return end
    if ChestAnim.state ~= "idle" then
        ChestAnim:update(dt)
    end
    if ChestAnim.state == "idle" then
        if state == "play" then
            time = time + dt
            -- Tick de efectos temporales (luces, velocidad, sigilo, etc.)
            Items.tickEffects(player, dt)

            if not criker.active then
                crikerSpawnTimer = crikerSpawnTimer + dt
                if crikerSpawnTimer >= 1.5 then
                    criker:spawnValidated(maze)
                end
            end
            local input = getInput()
            -- Velocidad efectiva segun items/efectos
            player.speed = 130 * Items.getSpeedMultiplier(player)
            player:update(input, maze, dt)
            if criker.active then criker:update(player, maze, dt) end

            -- Colision con el Criker: escudos/amuleto/armadura absorben primero;
            -- si no hay proteccion, se pierde una vida (salvo inmunidad temporal).
            if criker.active and math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2) < 15 then
                if Items.isImmune(player) then
                    -- salamandra / cristales de inmunidad: sin efecto
                elseif Items.absorbHit(player) then
                    -- absorbido por escudo/amuleto/armadura, re-spawnea Criker
                    criker:spawnValidated(maze)
                else
                    lives = lives - 1
                    criker:spawnValidated(maze)
                    if lives <= 0 then state = "dead" end
                end
            end
            if maze:isExit(player.x, player.y) then state = "win" end
            camera.x = camera.x + (player.x - love.graphics.getWidth()/2 - camera.x) * 0.1
            camera.y = camera.y + (player.y - love.graphics.getHeight()/2 - camera.y) * 0.1
        end
    end

    -- Lógica post-animación (solo durante gameplay)
    if pendingItem and not waitingForDecision and state == "play" then
        if ChestAnim.state == "done" then
            local count = 0
            for _ in pairs(player.inventory) do count = count + 1 end

            if count >= 3 then
                waitingForDecision = true
                uiState = "inventory_prompt"
            else
                Items.give(player, pendingItem)
                pendingItem = nil
                pendingTier = nil
            end
        end
    end
end

local function drawUI()
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fonts.f18)
    love.graphics.print("\226\156\165 x "..lives, 20, 30)
    local d = math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2)
    if criker.active and d < 220 then
        local a = 1 - (d / 220)
        love.graphics.setColor(1,0,0, a*0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 12)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight()-12, love.graphics.getWidth(), 12)
        love.graphics.rectangle("fill", 0, 0, 12, love.graphics.getHeight())
        love.graphics.rectangle("fill", love.graphics.getWidth()-12, 0, 12, love.graphics.getHeight())
    end
    -- Compass (brújula)
    if Items.has(player, "brujula") and maze.exitCell then
        local ed = math.floor(math.sqrt((player.x - maze.exitCell.x*maze.tile)^2 + (player.y - maze.exitCell.y*maze.tile)^2))
        love.graphics.setColor(0.3,0.3,1)
        love.graphics.setFont(fonts.f14)
        love.graphics.print("Salida: "..ed.."px", 20, 55)
    end
    -- Weapon durability (left side)
    local weapon = Items.getWeapon(player)
    if weapon then
        local wy = Items.has(player, "brujula") and 75 or 55
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(fonts.f14)
        love.graphics.print(Items.defs[weapon.id].nombre.." ["..weapon.uses.."/"..weapon.maxUses.."]", 20, wy)
    end
end

local function drawFlashlight()
    local sw, sh = love.graphics.getDimensions()
    local shader = shaders[currentShader]
    if not shader then return end

    -- Flicker
    local flicker = math.sin(time*12)*8 + math.sin(time*23)*5 + (math.random()-0.5)*6
    local baseRadius = Items.getLightRadius(player, 200)
    local radius  = baseRadius + flicker

    -- Player screen position
    local px = player.x - camera.x
    local py = player.y - camera.y

    -- Player direction for cone shader
    local dirX = player.lastDirX or 1
    local dirY = player.lastDirY or 0

    -- Draw light mask
    love.graphics.setCanvas(lightCanvas)
    love.graphics.clear(0,0,0,1)
    love.graphics.setBlendMode("add")
    love.graphics.setShader(shader)

    -- Player light (white)
    shader:send("lightPos", {px, py})
    shader:send("radius", radius)
    shader:send("lightColor", {1,1,1})
    shader:send("falloff", 2)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Static lights (safe room y salida)
    for _, l in ipairs(lights) do
        shader:send("lightPos", {l.x - camera.x, l.y - camera.y})
        shader:send("radius", l.radius)
        shader:send("lightColor", l.color)
        shader:send("falloff", l.falloff)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    -- Safe room lights (additive on top of darkness)
    if maze.safeRoom then
        local sr = maze.safeRoom
        local safeLights = {
            {sr.x + 1,      sr.y + 1},
            {sr.x + sr.w-2, sr.y + sr.h-2},
            {sr.cx,         sr.cy},
        }
        love.graphics.setBlendMode("add")
        for _, sl in ipairs(safeLights) do
            local lx = sl[1] * maze.tile - camera.x
            local ly = sl[2] * maze.tile - camera.y
            for r = 50, 10, -5 do
                love.graphics.setColor(0.15, 0.3, 0.4, 0.05)
                love.graphics.circle("fill", lx, ly, r)
            end
        end
        if maze.exitCell then
            local ex = maze.exitCell.x * maze.tile - camera.x
            local ey = maze.exitCell.y * maze.tile - camera.y
            for r = 35, 8, -4 do
                love.graphics.setColor(0.6, 0.5, 0.0, 0.06)
                love.graphics.circle("fill", ex, ey, r)
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.setCanvas()

    -- Multiply light mask over scene
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1,1,1)
    love.graphics.draw(lightCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")
end

local function drawEditor()
    local sw, sh = love.graphics.getDimensions()
    local EDITOR_TILE = 32
    local gridW = editor.width * EDITOR_TILE
    local gridH = editor.height * EDITOR_TILE
    local gridX = math.max(10, (sw - gridW) / 2)
    local gridY = math.max(10, (sh - gridH) / 2)

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Grid
    for y = 1, editor.height do
        for x = 1, editor.width do
            local ch = editor.grid[y]:sub(x, x)
            local px = gridX + (x-1) * EDITOR_TILE
            local py = gridY + (y-1) * EDITOR_TILE
            local color
            if ch == '#' then color = {0.176,0.176,0.227}
            elseif ch == 'X' then color = {1,0.867,0}
            elseif ch == 'L' then color = {0.267,0.533,0.667}
            elseif ch == 'R' then color = {0.533,0.267,0.667}
            elseif ch == 'C' then color = {0.533,0.4,0.267}
            elseif ch == 'G' then color = {0.867,0.667,0}
            elseif ch == '?' then color = {0.4,0.8,1}
            else color = {0.039,0.039,0.039}
            end
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", px, py, EDITOR_TILE, EDITOR_TILE)
            love.graphics.setColor(0.2, 0.2, 0.3, 0.4)
            love.graphics.rectangle("line", px, py, EDITOR_TILE, EDITOR_TILE)
        end
    end

    -- Cursor
    local cx = gridX + (editor.cursorX-1) * EDITOR_TILE
    local cy = gridY + (editor.cursorY-1) * EDITOR_TILE
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("line", cx-1, cy-1, EDITOR_TILE+2, EDITOR_TILE+2)

    -- Top info
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fonts.f16)
    love.graphics.print(editor.name .. " (" .. editor.width .. "x" .. editor.height .. ")", 20, 20)

    -- Brush indicator
    love.graphics.print("Brocha: " .. (brushNames[editor.brush] or "?"), sw - 200, 20)

    -- Template navigation
    love.graphics.setFont(fonts.f12)
    love.graphics.print("Sala " .. editor.currentIdx .. " de " .. #currentTemplates, sw - 200, 40)

    -- Controls help
    local helpY = sh - 130
    local help = {
        "Flechas: mover cursor  Click izq: pintar  Der: borrar",
        "1=Suelo  2=Pared  3=Luz  4=Salida  5=Épico  6=Común  7=Legendario  8=Aleatorio",
        "R: +fila  Shift+R: -fila",
        "C: +col  Shift+C: -col",
        "Tab: siguiente sala  N: nueva  S: guardar  Esc: salir",
        "Arrastrar con mouse para pintar/borrar",
    }
    for _, line in ipairs(help) do
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(line, 20, helpY)
        helpY = helpY + 16
    end
end

function love.draw()
    love.graphics.clear(0,0,0)

    -- Draw scene to canvas
    love.graphics.setCanvas(sceneCanvas)
    love.graphics.clear(0,0,0)
    maze:draw(camera)
    player:draw(camera)
    criker:draw(camera)
    love.graphics.setCanvas()

    -- Draw scene
    love.graphics.setColor(1,1,1)
    love.graphics.draw(sceneCanvas, 0, 0)

    -- Apply flashlight
    drawFlashlight()

    -- UI always on top
    love.graphics.setColor(1,1,1)
    drawUI()
    Debug:draw(maze, player, criker, lives, camera)

    -- Inventory HUD (bottom-right, orden determinístico)
    do
        local sw, sh = love.graphics.getDimensions()
        local invX = sw - 155
        local slots = getInventorySlots(player)
        local invY = sh - 16 * math.max(1, #slots) - 10
        love.graphics.setFont(fonts.f12)
        for _, slot in ipairs(slots) do
            local def = slot.def
            local data = slot.data
            local txt = def.nombre
            if type(data) == "table" and data.uses then
                txt = txt .. " ["..data.uses.."/"..def.maxUses.."]"
            end
            love.graphics.setColor(def.color)
            love.graphics.rectangle("fill", invX, invY, 12, 12)
            love.graphics.setColor(1,1,1)
            love.graphics.print(txt, invX + 15, invY - 2)
            invY = invY + 16
        end
    end

    -- Chest animation overlay
    if ChestAnim.state ~= "idle" then
        ChestAnim:draw()
    end

    -- Menú de reemplazo de inventario
    if waitingForDecision and uiState == "inventory_prompt" and pendingItem then
        local sw, sh = love.graphics.getDimensions()

        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.f22)
        love.graphics.printf("¡Inventario lleno! Elige qué reemplazar", 0, sh/2 - 120, sw, "center")

        local slots = getInventorySlots(player)
        local startX = sw/2 - 130
        local startY = sh/2 - 20

        for i, slot in ipairs(slots) do
            local x = startX + (i-1) * 130
            local y = startY
            local def = slot.def

            love.graphics.setColor(def.color)
            love.graphics.rectangle("fill", x, y, 80, 80)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x, y, 80, 80)

            love.graphics.setFont(fonts.f18)
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.printf("["..i.."]", x, y - 25, 80, "center")

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f14)
            local txt = def.nombre
            if type(slot.data) == "table" and slot.data.uses then
                txt = txt .. " ["..slot.data.uses.."/"..def.maxUses.."]"
            end
            love.graphics.printf(txt, x, y + 85, 80, "center")
        end

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setFont(fonts.f14)
        love.graphics.printf("Presiona 1, 2 o 3 para soltar ese objeto (Esc = descartar el nuevo)", 0, sh/2 + 130, sw, "center")
    end

    -- UI panel (runtime editing)
    if ui.active then
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill", 10, 10, 350, (#ui.params+4)*18)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(fonts.f14)
        love.graphics.print("Seed: "..tostring(currentSeed), 20, 20)
        for i, p in ipairs(ui.params) do
            -- Construir el texto de la línea
            local txt
            if p == "- CHEST -" then
                txt = "=== " .. p .. " ==="
            elseif p == "Open Comun" or p == "Open Epic" or p == "Open Legend" then
                txt = p
            elseif p == "Offset X" then
                txt = p .. ": " .. chestOffsetX
            else
                local val = configRef[p]
                if type(val) == "table" then
                    txt = p..": ["..val[1]..","..val[2].."]"
                else
                    txt = p..": "..tostring(val)
                end
            end

            -- Color del texto
            if p == "- CHEST -" then
                love.graphics.setColor(0.8, 0.8, 0.8) -- Gris para el separador
            elseif i == ui.selection then
                love.graphics.setColor(1, 1, 0) -- Amarillo para el seleccionado
            else
                love.graphics.setColor(1, 1, 1) -- Blanco para el resto
            end
            love.graphics.print(txt, 20, 20 + i*18)

            -- Mostrar descripción si está seleccionado
            if i == ui.selection then
                local desc = paramDescriptions[p] or ""
                love.graphics.setColor(0.8,0.8,0.8)
                love.graphics.print(desc, 160, 20 + i*18 + 20)
            end
        end
    end

    -- Editor overlay
    if editor.active then
        drawEditor()
    end

    -- Game over / Win states
    if state == "dead" then
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(fonts.f36)
        love.graphics.print("GAME OVER", love.graphics.getWidth()/2 - 100, love.graphics.getHeight()/2)
    elseif state == "win" then
        love.graphics.setColor(1,1,0)
        love.graphics.setFont(fonts.f36)
        love.graphics.print("\194\161ESCAPASTE!", love.graphics.getWidth()/2 - 110, love.graphics.getHeight()/2)
    end
end