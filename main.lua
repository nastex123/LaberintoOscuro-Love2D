-- main.lua – Love2D entry point, full-feature implementation

local Maze   = require "maze"
local Player = require "player"
local Criker = require "criker"
local Debug  = require "debugInfo"
local Items  = require "items"
local Vault  = require "vault"
local ChestAnim = require "chest_animation"
local TouchUI = require "touch_ui"
local Tiles = require "tiles"
local Character = require "character"

local lives = 3
local state = "play" -- "play", "win", "dead"
local time = 0
local camera = {x = 0, y = 0}

-- Splash / water ring state
local splashPhase = -1
local splashWorldPos = {x = 0, y = 0}
local wasInWater = false
local inWaterFade = 0
-- Configurables desde F1
local splashDuration = 0.8
local splashPixelCount = 40
local splashCenterSize = 0.05
local ringBaseRadius = 0.01
ringPulseSpeed = 3.0
waterScale = 1.0
splashScale = 1.0
ringScale = 1.0
waterPixelCount = 20
waterSpeed = 0.25
waterDistortion = 0.09

-- Canvases and shaders for lighting
local sceneCanvas, lightCanvas, waterMaskCanvas
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
    editingName = false, nameBuffer = "",
    buttonRects = {},
}

local charEditor = {
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
}
-- Brochas generadas desde tiles.lua (single source of truth)
local brushChars = {}
local brushNames = {}
for _, id in ipairs(Tiles.order) do
    brushChars[id] = Tiles.defs[id].char
    brushNames[id] = Tiles.defs[id].name
end

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
    -- Save current editor data
    local tmpl = currentTemplates[editor.currentIdx]
    if tmpl then
        tmpl.grid = {}
        for _, row in ipairs(editor.grid) do
            table.insert(tmpl.grid, row)
        end
        tmpl.name = editor.name
    end
    -- Deduplicate names
    local usedNames = {}
    for _, t in ipairs(currentTemplates) do
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
    -- Update editor name if current template was renamed
    if tmpl then
        editor.name = tmpl.name
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
        -- Copiar también a la carpeta del proyecto usando ruta relativa
        local projectPath = "room_templates.lua"
        local f, ferr = io.open(projectPath, "w")
        if f then
            f:write(content)
            f:close()
            print("Copiado a carpeta del proyecto (ruta relativa)")
            -- Log a archivo para ver después
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

local function loadShaders()
    -- Shader de luz
    local ok, shader = pcall(love.graphics.newShader, "shaders/light_falloff.glsl")
    if ok then
        shaders[1] = shader
        shaderNames[1] = "Falloff Cuadratico"
    else
        error("Error cargando shader light_falloff.glsl: " .. tostring(shader))
    end
    -- Shader de barrido de ataque
    local ok2, sweep = pcall(love.graphics.newShader, "shaders/sweep.glsl")
    if ok2 then
        shaders[2] = sweep
        shaderNames[2] = "Sweep Ataque"
    else
        error("Error cargando shader sweep.glsl: " .. tostring(sweep))
    end
    currentShader = 1
end

local function initCanvases()
    local w, h = love.graphics.getDimensions()
    sceneCanvas = love.graphics.newCanvas(w, h)
    lightCanvas = love.graphics.newCanvas(w, h)
    waterMaskCanvas = love.graphics.newCanvas(w, h)
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

    -- Detectar plataforma móvil
    isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
    touchUI = TouchUI.new()
    if isMobile then touchUI:layout() end

    -- Cargar spritesheet de hachas
    axeSheet = love.graphics.newImage("assets/AXES.png")
    axeQuads = {}
    for row = 0, 9 do
        axeQuads[row+1] = {}
        for col = 0, 5 do
            axeQuads[row+1][col+1] = love.graphics.newQuad(col*32, row*32, 32, 32, 512, 320)
        end
    end

    -- Cargar spritesheet de efecto de ataque (64x64, 13 cols, 9 rows)
    attackSheet = love.graphics.newImage("assets/attack_effect.png")
    attackQuads = {}
    for col = 0, 12 do
        attackQuads[col+1] = love.graphics.newQuad(col*64, 320, 64, 64, attackSheet:getDimensions())
    end

    -- Cargar texturas de tiles (water: 12 cols × 14 rows × 16px)
    waterSheet = love.graphics.newImage("assets/Water+.png")
    -- col 6, fila 3 (1-indexed) = pixel (80, 32)
    waterQuad = love.graphics.newQuad(80, 32, 16, 16, waterSheet:getDimensions())
    -- Tabla de texturas para maze:draw (fallback si shader no disponible)
    tileSheets = { water = waterSheet }
    tileQuads  = { water = waterQuad }
    -- Cargar shader de agua (reemplaza la textura cuando está disponible)
    local wok, wshader = pcall(love.graphics.newShader, "shaders/water1.glsl")
    if wok then
        waterShader = wshader
    else
        waterShader = nil
        print("Error cargando water1.glsl:", wshader)
    end
    -- Cargar shader de splash
    local sok, sshader = pcall(love.graphics.newShader, "shaders/splash1.glsl")
    if sok then
        splashShader = sshader
    else
        splashShader = nil
        print("Error cargando splash1.glsl:", sshader)
    end

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
    player.attackDuration = attackDuration
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
        params = {"cols","rows","tile","roomCount","branchCount","branchLen","loopChance","perlinThresh", "- CHEST -", "Open Comun", "Open Epic", "Open Legend", "Offset X", "- HAND -", "Hand Radius", "Attack Duration", "- WATER -", "Water PixelCount", "Water Speed", "Water Distortion", "Water Scale", "- SPLASH -", "Splash PixelCount", "Splash CenterSize", "Splash Duration", "Splash Scale", "- RING -", "Ring Radius", "Ring Speed", "Ring Scale"}
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
    configRef = config   -- referencia global para la UI
    chestOffsetX = 0    -- ajuste manual para centrar la animación
    handRadius = 1.5    -- radio de la mano respecto al jugador (en tiles)
    attackDuration = 0.25  -- duración de la animación de ataque (segundos)

    -- Sincronizar duración de ataque con el player (ya existe si se creó antes de cargar la UI)
    player.attackDuration = attackDuration

    -- Variables para el sistema de reemplazo de inventario
    pendingItem = nil
    pendingTier = nil
    waitingForDecision = false

    -- Cargar configuración de UI (offset del cofre + radio de mano)
    local uiData = love.filesystem.read(UI_CONFIG_PATH)
    if uiData and uiData ~= "" then
        local ok, parsed = pcall(json.decode, uiData)
        if ok then
            if parsed.chestOffsetX ~= nil then chestOffsetX = parsed.chestOffsetX end
            if parsed.handRadius ~= nil then handRadius = parsed.handRadius end
            if parsed.attackDuration ~= nil then attackDuration = parsed.attackDuration end
            if parsed.splashDuration ~= nil then splashDuration = parsed.splashDuration end
            if parsed.splashPixelCount ~= nil then splashPixelCount = parsed.splashPixelCount end
            if parsed.splashCenterSize ~= nil then splashCenterSize = parsed.splashCenterSize end
            if parsed.ringBaseRadius ~= nil then ringBaseRadius = parsed.ringBaseRadius end
            if parsed.ringPulseSpeed ~= nil then ringPulseSpeed = parsed.ringPulseSpeed end
            if parsed.waterScale ~= nil then waterScale = parsed.waterScale end
            if parsed.splashScale ~= nil then splashScale = parsed.splashScale end
            if parsed.ringScale ~= nil then ringScale = parsed.ringScale end
            if parsed.waterPixelCount ~= nil then waterPixelCount = parsed.waterPixelCount end
            if parsed.waterSpeed ~= nil then waterSpeed = parsed.waterSpeed end
            if parsed.waterDistortion ~= nil then waterDistortion = parsed.waterDistortion end
        end
    end

    -- Sincronizar duración de ataque con el player (se crea más abajo en resetGameState, pero ya existe para cuando se usa en reset)

    -- Cargar configuración de personaje (partes y poses)
    local charData = love.filesystem.read(charEditor.charConfigPath)
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
                        charEditor.poses[i] = pose
                    end
                end
            end
        end
    end

    --=== 6. Luz estática de salida (amarilla) ===
    if maze.exitCell then
        addLight(maze.exitCell.x * maze.tile, maze.exitCell.y * maze.tile,
                 120, {1,0.9,0}, 2)  -- amarillo
    end
end

-- Resize: recrear canvases cuando cambia el tamaño de ventana
function love.resize(w, h)
    sceneCanvas = love.graphics.newCanvas(w, h)
    lightCanvas = love.graphics.newCanvas(w, h)
    waterMaskCanvas = love.graphics.newCanvas(w, h)
    if isMobile then touchUI:layout() end
end

-- Touch callbacks (mobile)
function love.touchpressed(id, x, y, dx, dy, pressure)
    if isMobile then touchUI:touchPressed(id, x, y) end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if isMobile then touchUI:touchMoved(id, x, y) end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    if isMobile then touchUI:touchReleased(id) end
end

-- Input handling – keyboard + touch
local function getInput()
    local x, y = 0, 0
    -- Keyboard
    if love.keyboard.isDown("left", "a") then x = -1 end
    if love.keyboard.isDown("right", "d") then x = 1 end
    if love.keyboard.isDown("up", "w") then y = -1 end
    if love.keyboard.isDown("down", "s") then y = 1 end
    -- Touch joystick (merge: touch overrides keyboard if active)
    if isMobile and touchUI and touchUI.joystick.active then
        x = touchUI.joystick.dx
        y = touchUI.joystick.dy
    end
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
    local data = { chestOffsetX = chestOffsetX, handRadius = handRadius, attackDuration = attackDuration, splashDuration = splashDuration, splashPixelCount = splashPixelCount, splashCenterSize = splashCenterSize, ringBaseRadius = ringBaseRadius, ringPulseSpeed = ringPulseSpeed, waterScale = waterScale, splashScale = splashScale, ringScale = ringScale, waterPixelCount = waterPixelCount, waterSpeed = waterSpeed, waterDistortion = waterDistortion }
    local content = json.encode(data)
    love.filesystem.write(UI_CONFIG_PATH, content)
end

local function saveCharConfig()
    local data = {
        parts = {},
        poses = charEditor.poses,
    }
    for i, part in ipairs(player.character.parts) do
        local pd = {}
        for k, v in pairs(part) do
            pd[k] = v
        end
        table.insert(data.parts, pd)
    end
    local content = json.encode(data)
    love.filesystem.write(charEditor.charConfigPath, content)
end

-- Resetea una partida completa conservando la configuracion actual.
-- Usado por la tecla R y por el reinicio tras win/dead.
local function resetGameState()
    lights = {}
    maze = Maze:new(configRef)
    maze:generate()
    player = Player:new()
    player.attackDuration = attackDuration
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
        if editor.editingName then
            if key == "return" or key == "kpenter" then
                editor.name = editor.nameBuffer
                editor.editingName = false
            elseif key == "escape" then
                editor.editingName = false
            elseif key == "backspace" then
                editor.nameBuffer = editor.nameBuffer:sub(1, -2)
            end
            return
        end
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
        print("S presionado - guardando...")
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
        player:startAttack()
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

    -- UI / Character Editor toggle
    if key == "f1" then
        if charEditor.active then charEditor.active = false end
        ui.active = not ui.active
        return
    end
    if key == "f3" then
        if ui.active then ui.active = false end
        charEditor.active = not charEditor.active
        if charEditor.active and player.character then
            charEditor.poses = charEditor.poses or {}
        end
        return
    end
    if not ui.active and not charEditor.active then
        -- Continue to normal key handling
    elseif charEditor.active then
        if key == "s" then
            saveCharConfig()
        elseif key == "escape" then
            charEditor.active = false
        elseif key == "tab" then
            local idx = 1
            for i, tn in ipairs(charEditor.tabNames) do
                if tn == charEditor.tab then
                    idx = i % #charEditor.tabNames + 1
                    break
                end
            end
            charEditor.tab = charEditor.tabNames[idx]
            charEditor.paramSel = 1
        end
        return
    end

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
        if param == "Hand Radius" then
            handRadius = handRadius + 0.1
            saveUIConfig()
            return
        end
        if param == "Attack Duration" then
            attackDuration = attackDuration + 0.05
            player.attackDuration = attackDuration
            saveUIConfig()
            return
        end
        if param == "Open Comun" or param == "Open Epic" or param == "Open Legend" or param == "- CHEST -" or param == "- HAND -" or param == "- WATER -" or param == "- SPLASH -" or param == "- RING -" then
            return
        end
        if param == "Splash PixelCount" then
            splashPixelCount = math.min(80, splashPixelCount + 1)
            return
        end
        if param == "Splash CenterSize" then
            splashCenterSize = math.min(0.20, splashCenterSize + 0.01)
            return
        end
        if param == "Splash Duration" then
            splashDuration = math.min(2.0, splashDuration + 0.05)
            return
        end
        if param == "Ring Radius" then
            ringBaseRadius = math.min(0.20, ringBaseRadius + 0.01)
            return
        end
        if param == "Ring Speed" then
            ringPulseSpeed = math.min(10.0, ringPulseSpeed + 0.5)
            return
        end
        if param == "Water PixelCount" then
            waterPixelCount = math.min(60, waterPixelCount + 1)
            return
        end
        if param == "Water Speed" then
            waterSpeed = math.min(2.0, waterSpeed + 0.05)
            return
        end
        if param == "Water Distortion" then
            waterDistortion = math.min(0.50, waterDistortion + 0.01)
            return
        end
        if param == "Water Scale" then
            waterScale = math.min(3.0, waterScale + 0.1)
            return
        end
        if param == "Splash Scale" then
            splashScale = math.min(3.0, splashScale + 0.1)
            return
        end
        if param == "Ring Scale" then
            ringScale = math.min(3.0, ringScale + 0.1)
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
        if param == "Hand Radius" then
            handRadius = math.max(0.1, handRadius - 0.1)
            saveUIConfig()
            return
        end
        if param == "Attack Duration" then
            attackDuration = math.max(0.1, attackDuration - 0.05)
            player.attackDuration = attackDuration
            saveUIConfig()
            return
        end
        if param == "Open Comun" or param == "Open Epic" or param == "Open Legend" or param == "- CHEST -" or param == "- HAND -" or param == "- WATER -" or param == "- SPLASH -" or param == "- RING -" then
            return
        end
        if param == "Splash PixelCount" then
            splashPixelCount = math.max(10, splashPixelCount - 1)
            return
        end
        if param == "Splash CenterSize" then
            splashCenterSize = math.max(0.01, splashCenterSize - 0.01)
            return
        end
        if param == "Splash Duration" then
            splashDuration = math.max(0.2, splashDuration - 0.05)
            return
        end
        if param == "Ring Radius" then
            ringBaseRadius = math.max(0.01, ringBaseRadius - 0.01)
            return
        end
        if param == "Ring Speed" then
            ringPulseSpeed = math.max(0.5, ringPulseSpeed - 0.5)
            return
        end
        if param == "Water PixelCount" then
            waterPixelCount = math.max(10, waterPixelCount - 1)
            return
        end
        if param == "Water Speed" then
            waterSpeed = math.max(0.05, waterSpeed - 0.05)
            return
        end
        if param == "Water Distortion" then
            waterDistortion = math.max(0.01, waterDistortion - 0.01)
            return
        end
        if param == "Water Scale" then
            waterScale = math.max(0.2, waterScale - 0.1)
            return
        end
        if param == "Splash Scale" then
            splashScale = math.max(0.2, splashScale - 0.1)
            return
        end
        if param == "Ring Scale" then
            ringScale = math.max(0.2, ringScale - 0.1)
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

-- Detectar click en la barra lateral de tiles
local function editorTileFromMouse(mx, my)
    local sw, sh = love.graphics.getDimensions()
    local sidebarX = sw - 140
    local sidebarY = 20
    local tilePreviewSize = 28
    local spacing = 35

    for i, id in ipairs(Tiles.order) do
        local y = sidebarY + (i - 1) * spacing + 15
        if mx >= sidebarX and mx <= sidebarX + tilePreviewSize and
           my >= y - 2 and my <= y + tilePreviewSize + 2 then
            return id
        end
    end
    return nil
end

function love.mousepressed(mx, my, button)
    if editor.active then
        if button == 1 then
            -- Check button rects
            for _, rect in ipairs(editor.buttonRects) do
                if mx >= rect.x and mx <= rect.x + rect.w and
                   my >= rect.y and my <= rect.y + rect.h then
                    local k = rect.name
                    if k == "save" then
                        saveEditorData()
                        package.loaded["room_templates"] = nil
                        currentTemplates = require "room_templates"
                    elseif k == "new" then
                        local tmpl = currentTemplates[editor.currentIdx]
                        if tmpl then
                            tmpl.grid = {}
                            for _, row in ipairs(editor.grid) do
                                table.insert(tmpl.grid, row)
                            end
                        end
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
                    elseif k == "next" then
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
                    elseif k == "close" then
                        editor.active = false
                    elseif k == "row+" then
                        if editor.height < 30 then
                            table.insert(editor.grid, string.rep(".", editor.width))
                            editor.height = editor.height + 1
                        end
                    elseif k == "row-" then
                        if editor.height > 3 then
                            table.remove(editor.grid)
                            editor.height = editor.height - 1
                            editor.cursorY = math.min(editor.cursorY, editor.height)
                        end
                    elseif k == "col+" then
                        if editor.width < 30 then
                            for y = 1, #editor.grid do
                                editor.grid[y] = editor.grid[y] .. "."
                            end
                            editor.width = editor.width + 1
                        end
                    elseif k == "col-" then
                        if editor.width > 3 then
                            for y = 1, #editor.grid do
                                editor.grid[y] = editor.grid[y]:sub(1, -2)
                            end
                            editor.width = editor.width - 1
                            editor.cursorX = math.min(editor.cursorX, editor.width)
                        end
                    elseif k == "name" then
                        editor.editingName = true
                        editor.nameBuffer = editor.name
                    end
return
    end

    -- F3 Character editor mouse
    if charEditor.active then
        local PANEL_X = 20
        local PANEL_Y = 55
        local PANEL_W = 400
        local TAB_Y = PANEL_Y + 32
        local TAB_W = 120
        local TAB_H = 28
        local LINE_H = 24

        -- Close button
        if mx >= PANEL_X + PANEL_W - 28 and mx <= PANEL_X + PANEL_W - 6 and
           my >= PANEL_Y + 6 and my <= PANEL_Y + 28 then
            charEditor.active = false
            return
        end

        -- Tabs
        for i, tn in ipairs(charEditor.tabNames) do
            local tx = PANEL_X + 10 + (i - 1) * (TAB_W + 6)
            if mx >= tx and mx <= tx + TAB_W and my >= TAB_Y and my <= TAB_Y + TAB_H then
                charEditor.tab = tn
                charEditor.paramSel = 1
                return
            end
        end

        local char = player.character
        local CONTENT_Y = TAB_Y + TAB_H + 12

        if charEditor.tab == "PARTES" then
            -- Parts sidebar click
            local SIDEBAR_X = PANEL_X + 10
            local SIDEBAR_W = 110
            local spy = CONTENT_Y
            for i, part in ipairs(char.parts) do
                if mx >= SIDEBAR_X and mx <= SIDEBAR_X + SIDEBAR_W and
                   my >= spy and my <= spy + 22 then
                    charEditor.partSel = i
                    charEditor.paramSel = 1
                    return
                end
                spy = spy + 24
            end

            -- Param sliders click
            local part = char.parts[charEditor.partSel]
            if part then
                local params = Character.getParamMeta(part)
                local px = SIDEBAR_X + SIDEBAR_W + 15
                local ppy = CONTENT_Y + 22
                for pi, pm in ipairs(params) do
                    local SLIDER_X = px + 170
                    local SLIDER_W = 100
                    local SLIDER_H = 6
                    local sliderY = ppy + 6
                    if mx >= SLIDER_X and mx <= SLIDER_X + SLIDER_W and
                       my >= sliderY and my <= sliderY + SLIDER_H then
                        local t = math.max(0, math.min(1, (mx - SLIDER_X) / SLIDER_W))
                        part[pm.key] = pm.min + t * (pm.max - pm.min)
                        charEditor.paramSel = pi
                        return
                    end
                    ppy = ppy + 22
                end
            end
        elseif charEditor.tab == "POSES" then
            local py = CONTENT_Y
            for i = 1, 9 do
                -- Save button
                local sbx = PANEL_X + 150
                if mx >= sbx and mx <= sbx + 70 and my >= py + 4 and my <= py + 24 then
                    if char.parts then
                        charEditor.poses[i] = Character.snapshot(char)
                    end
                    return
                end
                -- Load button
                local lbx = sbx + 80
                if mx >= lbx and mx <= lbx + 70 and my >= py + 4 and my <= py + 24 then
                    if charEditor.poses[i] and #charEditor.poses[i] > 0 then
                        Character.applyPose(char, charEditor.poses[i])
                    end
                    return
                end
                py = py + 32
            end
        elseif charEditor.tab == "ANIM" then
            -- Pose A / B click
            local py = CONTENT_Y
            if mx >= PANEL_X + 100 and mx <= PANEL_X + 130 and my >= py and my <= py + 20 then
                charEditor.animPoseA = charEditor.animPoseA % 9 + 1
                return
            end
            if mx >= PANEL_X + 220 and mx <= PANEL_X + 250 and my >= py and my <= py + 20 then
                charEditor.animPoseB = charEditor.animPoseB % 9 + 1
                return
            end
            py = py + 30

            -- Blend slider click
            local bsx = PANEL_X + 80
            local bsy = py + 4
            if mx >= bsx and mx <= bsx + 260 and my >= bsy and my <= bsy + 8 then
                charEditor.animBlend = math.max(0, math.min(1, (mx - bsx) / 260))
                return
            end
            py = py + 30

            -- Auto toggle click
            local actx = PANEL_X + 60
            local acty = py
            if mx >= actx and mx <= actx + 80 and my >= acty and my <= acty + 22 then
                charEditor.animAuto = not charEditor.animAuto
                charEditor.animTimer = 0
                return
            end
            py = py + 28

            -- Speed slider click
            local vsx = PANEL_X + 60
            local vsy = py + 4
            if mx >= vsx and mx <= vsx + 180 and my >= vsy and my <= vsy + 8 then
                charEditor.animSpeed = math.max(0.1, math.min(3.0, (mx - vsx) / 180 * 3.0))
                return
            end
        end
        return
    end
end
        end

        -- Verificar click en la barra lateral de tiles
        local tileId = editorTileFromMouse(mx, my)
        if tileId then
            editor.brush = tileId
            return
        end

        -- Pintar en la grilla
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

function love.wheelmoved(x, y)
    if charEditor.active and charEditor.tab == "PARTES" and player.character then
        local part = player.character.parts[charEditor.partSel]
        if part then
            local params = Character.getParamMeta(part)
            local pm = params[charEditor.paramSel]
            if pm then
                part[pm.key] = math.max(pm.min, math.min(pm.max, part[pm.key] + pm.step * y))
            end
        end
    end
end

function love.textinput(text)
    if editor.active and editor.editingName then
        editor.nameBuffer = editor.nameBuffer .. text
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

            -- Water splash / ring state
            if splashPhase >= 0 then
                splashPhase = splashPhase + dt / splashDuration
                if splashPhase >= 1.0 then splashPhase = -1 end
            end
            local inWater = maze:getTileAt(player.x, player.y) == Tiles.WATER
            if inWater and not wasInWater then
                splashPhase = 0
                splashWorldPos = {x = player.x, y = player.y}
            end
            if inWater then
                inWaterFade = math.min(1, inWaterFade + dt / 0.2)
            else
                inWaterFade = math.max(0, inWaterFade - dt / 0.5)
            end
            wasInWater = inWater

            -- Character animation (pose blend)
            if charEditor.active and charEditor.tab == "ANIM" and player.character then
                local poseA = charEditor.poses[charEditor.animPoseA]
                local poseB = charEditor.poses[charEditor.animPoseB]
                if poseA and #poseA > 0 and poseB and #poseB > 0 then
                    if charEditor.animAuto then
                        charEditor.animTimer = charEditor.animTimer + dt * charEditor.animSpeed
                        charEditor.animBlend = (math.sin(charEditor.animTimer) + 1) / 2
                    end
                    local blended = Character.lerpPose(poseA, poseB, charEditor.animBlend)
                    Character.applyPose(player.character, blended)
                end
            end
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

    -- Touch action buttons (mobile)
    if isMobile and touchUI then
        -- Reinicio tras win/dead
        if (state == "dead" or state == "win") and touchUI:wasPressed("restart") then
            resetGameState()
        end
        -- Cerrar animación de cofre
        if touchUI:wasPressed("interact") and ChestAnim.state == "done" then
            ChestAnim:close()
        end
        -- Abrir cofre
        if touchUI:wasPressed("interact") and ChestAnim.state == "idle" and state == "play" then
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
        end
        -- Atacar
        if touchUI:wasPressed("attack") and ChestAnim.state == "idle" and state == "play" then
            player:startAttack()
            local weapon = Items.getWeapon(player)
            if weapon and criker.active then
                local d = math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2)
                local range = (weapon.range == "ranged") and 180 or 45
                if d < range then
                    if weapon.range == "ranged" then
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
        end
        -- Usar consumible
        if touchUI:wasPressed("use") and ChestAnim.state == "idle" and state == "play" then
            local target = nil
            for id, data in pairs(player.inventory) do
                local def = Items.defs[id]
                if def and def.type == "consumable" then
                    local uses = type(data) == "table" and data.uses or 1
                    if uses and uses > 0 then
                        if target == nil then target = id end
                    end
                end
            end
            if target then
                local ctx = buildConsumableContext()
                Items.useConsumable(player, target, ctx)
            end
        end
        -- Debug toggle (F1)
        if touchUI:wasPressed("debug") then
            ui.active = not ui.active
        end
        -- Editor toggle (F2)
        if touchUI:wasPressed("editor") then
            editor.active = not editor.active
            if editor.active then initEditor() end
        end
        -- Inventory slot taps (reemplazo de ítems)
        if waitingForDecision and uiState == "inventory_prompt" then
            local tapIdx = touchUI:consumeSlotTap()
            if tapIdx then
                local slots = getInventorySlots(player)
                if slots[tapIdx] then
                    player.inventory[slots[tapIdx].id] = nil
                    Items.give(player, pendingItem)
                    pendingItem = nil
                    pendingTier = nil
                    waitingForDecision = false
                    uiState = nil
                    touchUI:resetSlots()
                end
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

local function drawSweep()
    if player.attackTimer <= 0 then return end

    local progress = 1 - player.attackTimer / player.attackDuration
    local tile = maze.tile
    local dist = handRadius * tile
    local len = math.sqrt(player.lastDirX^2 + player.lastDirY^2)
    if len < 0.01 then return end
    local dx = player.lastDirX / len
    local dy = player.lastDirY / len
    local facingAngle = math.atan2(dy, dx)
    local hx = player.x + dx * dist - camera.x
    local hy = player.y + dy * dist - camera.y

    local frameCol = 13 - math.floor(progress * 13)
    if frameCol < 1 then frameCol = 1 end

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(attackSheet, attackQuads[frameCol], hx, hy, facingAngle, 1, 1, 32, 32)
    love.graphics.setBlendMode("alpha")
end

local function drawEditor()
    local sw, sh = love.graphics.getDimensions()
    local EDITOR_TILE = 32
    local gridW = editor.width * EDITOR_TILE
    local gridH = editor.height * EDITOR_TILE
    local gridX = math.max(175, (sw - gridW) / 2)
    local gridY = math.max(10, (sh - gridH) / 2)

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Left sidebar buttons
    local LEFT_X = 15
    local LEFT_W = 150
    local BTN_H = 26
    local BTN_GAP = 4
    local y = 15

    editor.buttonRects = {}
    local function addRect(name, x, y, w, h)
        table.insert(editor.buttonRects, {name=name, x=x, y=y, w=w, h=h})
    end

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f16)
    love.graphics.print("Editor de salas", LEFT_X, y)
    y = y + 22

    -- Name field
    love.graphics.setFont(fonts.f12)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Nombre:", LEFT_X, y)
    local nameFieldX = LEFT_X + 52
    local nameFieldY = y - 2
    local nameFieldW = LEFT_W - 52
    local nameFieldH = 20

    if editor.editingName then
        love.graphics.setColor(0.2, 0.4, 0.6, 0.5)
        love.graphics.rectangle("fill", nameFieldX, nameFieldY, nameFieldW, nameFieldH)
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("line", nameFieldX, nameFieldY, nameFieldW, nameFieldH)
        love.graphics.setColor(1, 1, 1)
        local displayText = editor.nameBuffer
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
        love.graphics.print(editor.name, nameFieldX + 3, nameFieldY + 3)
    end
    addRect("name", nameFieldX, nameFieldY, nameFieldW, nameFieldH)

    y = nameFieldY + nameFieldH + 8

    -- Action buttons
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

    -- Row/Col buttons
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

    -- Right sidebar: tile palette
    local sidebarX = sw - 140
    local sidebarY = 20
    local tilePreviewSize = 28
    local spacing = 35

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", sidebarX - 10, sidebarY - 10, 160, #Tiles.order * spacing + 20)
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("line", sidebarX - 10, sidebarY - 10, 160, #Tiles.order * spacing + 20)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f14)
    love.graphics.print("Tiles:", sidebarX, sidebarY - 5)

    for i, id in ipairs(Tiles.order) do
        local def = Tiles.defs[id]
        local ty = sidebarY + (i - 1) * spacing + 15
        local isSelected = (editor.brush == id)
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

    -- Grid
    for gy = 1, editor.height do
        for gx = 1, editor.width do
            local ch = editor.grid[gy]:sub(gx, gx)
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

    -- Cursor
    local cx = gridX + (editor.cursorX - 1) * EDITOR_TILE
    local cy = gridY + (editor.cursorY - 1) * EDITOR_TILE
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("line", cx - 1, cy - 1, EDITOR_TILE + 2, EDITOR_TILE + 2)

    -- Info
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f16)
    love.graphics.printf("Sala " .. editor.currentIdx .. " de " .. #currentTemplates, 0, gridY + gridH + 15, sw, "center")

    -- Help text
    local helpY = sh - 30
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(fonts.f12)
    love.graphics.printf("Click izq: pintar | Der: borrar | Flechas: mover cursor | 1-8: tile | S: guardar", 0, helpY, sw, "center")
end

local function drawCharEditor()
    if not charEditor.active or not player or not player.character then return end
    local sw, sh = love.graphics.getDimensions()
    local PANEL_X = 20
    local PANEL_Y = 55
    local PANEL_W = 400
    local LINE_H = 24
    local char = player.character

    -- Overlay semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, 430)

    -- Title bar
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f16)
    love.graphics.print("F3 — Editor de Personaje", PANEL_X + 10, PANEL_Y + 8)

    -- Close button
    local closeBtn = {x = PANEL_X + PANEL_W - 28, y = PANEL_Y + 6, w = 22, h = 22}
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("fill", closeBtn.x, closeBtn.y, closeBtn.w, closeBtn.h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.f14)
    love.graphics.print("X", closeBtn.x + 6, closeBtn.y + 4)

    -- Tabs
    local TAB_Y = PANEL_Y + 32
    local TAB_W = 120
    local TAB_H = 28
    for i, tn in ipairs(charEditor.tabNames) do
        local tx = PANEL_X + 10 + (i - 1) * (TAB_W + 6)
        if tn == charEditor.tab then
            love.graphics.setColor(0.3, 0.6, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.3)
        end
        love.graphics.rectangle("fill", tx, TAB_Y, TAB_W, TAB_H)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.f12)
        local tw = fonts.f12:getWidth(tn)
        love.graphics.print(tn, tx + (TAB_W - tw) / 2, TAB_Y + 7)
    end

    local CONTENT_Y = TAB_Y + TAB_H + 12
    local CONTENT_H = 340

    if charEditor.tab == "PARTES" then
        -- Left sidebar: parts list
        local SIDEBAR_X = PANEL_X + 10
        local SIDEBAR_W = 110
        local py = CONTENT_Y
        for i, part in ipairs(char.parts) do
            local hover = false
            local col
            if i == charEditor.partSel then
                col = {0.3, 0.6, 0.9}
            else
                col = {0.15, 0.15, 0.2}
            end
            love.graphics.setColor(col)
            love.graphics.rectangle("fill", SIDEBAR_X, py, SIDEBAR_W, 22)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f12)
            love.graphics.print(part.name, SIDEBAR_X + 6, py + 4)
            py = py + 24
        end

        -- Right panel: part parameters
        local part = char.parts[charEditor.partSel]
        if part then
            local params = Character.getParamMeta(part)
            local px = SIDEBAR_X + SIDEBAR_W + 15
            local ppy = CONTENT_Y
            love.graphics.setFont(fonts.f12)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Parte: " .. part.name, px, ppy - 2)
            ppy = ppy + 22

            for pi, pm in ipairs(params) do
                local val = part[pm.key]
                if val ~= nil then
                    local txt = pm.name .. ": " .. string.format(pm.fmt, val)
                    love.graphics.setFont(fonts.f12)
                    if pi == charEditor.paramSel then
                        love.graphics.setColor(1, 1, 0)
                    else
                        love.graphics.setColor(0.8, 0.8, 0.8)
                    end
                    love.graphics.print(txt, px, ppy)

                    -- Slider bar
                    local SLIDER_X = px + 170
                    local SLIDER_W = 100
                    local SLIDER_H = 6
                    local sliderY = ppy + 6
                    love.graphics.setColor(0.3, 0.3, 0.3)
                    love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W, SLIDER_H)
                    local t = (val - pm.min) / (pm.max - pm.min)
                    love.graphics.setColor(0.6, 0.8, 1.0)
                    love.graphics.rectangle("fill", SLIDER_X, sliderY, SLIDER_W * t, SLIDER_H)
                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.rectangle("line", SLIDER_X, sliderY, SLIDER_W, SLIDER_H)

                    if charEditor.sliders then
                        charEditor.sliders[pi] = {x = SLIDER_X, y = sliderY, w = SLIDER_W, h = SLIDER_H, paramIdx = pi, partIdx = charEditor.partSel, meta = pm}
                    end
                end
                ppy = ppy + 22
            end
        end
    elseif charEditor.tab == "POSES" then
        local py = CONTENT_Y
        for i = 1, 9 do
            local hasPose = charEditor.poses[i] and #charEditor.poses[i] > 0
            love.graphics.setColor(0.2, 0.2, 0.25)
            love.graphics.rectangle("fill", PANEL_X + 10, py, 370, 28)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fonts.f12)
            local label = "Pose " .. i .. (hasPose and " (guardada)" or " (vacia)")
            love.graphics.print(label, PANEL_X + 16, py + 6)

            -- Save button
            local sbx = PANEL_X + 150
            love.graphics.setColor(0.3, 0.5, 0.3)
            love.graphics.rectangle("fill", sbx, py + 4, 70, 20)
            love.graphics.setColor(1, 1, 1)
            local tw = fonts.f12:getWidth("Guardar")
            love.graphics.print("Guardar", sbx + (70 - tw) / 2, py + 6)

            -- Load button
            local lbx = sbx + 80
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", lbx, py + 4, 70, 20)
            love.graphics.setColor(1, 1, 1)
            tw = fonts.f12:getWidth("Cargar")
            love.graphics.print("Cargar", lbx + (70 - tw) / 2, py + 6)

            py = py + 32
        end
    elseif charEditor.tab == "ANIM" then
        local py = CONTENT_Y
        love.graphics.setFont(fonts.f12)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Pose A:", PANEL_X + 10, py)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(charEditor.animPoseA), PANEL_X + 110, py)
        love.graphics.print("Pose B:", PANEL_X + 180, py)
        love.graphics.print(tostring(charEditor.animPoseB), PANEL_X + 230, py)
        py = py + 30

        -- Blend slider
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Mezcla:", PANEL_X + 16, py)
        local bsx = PANEL_X + 80
        local bsy = py + 4
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", bsx, bsy, 260, 8)
        love.graphics.setColor(0.6, 0.8, 1.0)
        love.graphics.rectangle("fill", bsx, bsy, 260 * charEditor.animBlend, 8)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", bsx, bsy, 260, 8)
        love.graphics.setFont(fonts.f12)
        love.graphics.print(string.format("%.2f", charEditor.animBlend), bsx + 205, bsy + 10)
        py = py + 30

        -- Auto toggle
        love.graphics.setFont(fonts.f12)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Auto:", PANEL_X + 16, py)
        local actx = PANEL_X + 60
        local acty = py
        local actCol = charEditor.animAuto and {0.3, 0.6, 0.3} or {0.3, 0.3, 0.3}
        love.graphics.setColor(actCol)
        love.graphics.rectangle("fill", actx, acty, 80, 22)
        love.graphics.setColor(1, 1, 1)
        local atxt = charEditor.animAuto and "ACTIVO" or "INACTIVO"
        love.graphics.print(atxt, actx + 10, acty + 5)
        py = py + 28

        -- Speed slider
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Vel:", PANEL_X + 16, py)
        local vsx = PANEL_X + 60
        local vsy = py + 4
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", vsx, vsy, 180, 8)
        local vt = charEditor.animSpeed / 3.0
        love.graphics.setColor(0.6, 0.8, 1.0)
        love.graphics.rectangle("fill", vsx, vsy, 180 * vt, 8)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", vsx, vsy, 180, 8)
        love.graphics.print(string.format("%.1f", charEditor.animSpeed), vsx + 185, vsy + 10)
    end

    -- Save hint at bottom
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(fonts.f12)
    love.graphics.print("S: guardar  |  ESC: cerrar  |  Tab: pestaña", PANEL_X + 10, PANEL_Y + 400)
end

function love.draw()
    love.graphics.clear(0,0,0)
    local sw, sh = love.graphics.getDimensions()

    -- Build water mask BEFORE sceneCanvas (needed for ring shader in sceneCanvas)
    love.graphics.setCanvas(waterMaskCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    local mt = maze.tile
    local msw, msh = love.graphics.getDimensions()
    for my = 0, maze.rows - 1 do
        for mx = 0, maze.cols - 1 do
            if maze.grid[my][mx] == Tiles.WATER then
                local mpx = mx * mt - camera.x
                local mpy = my * mt - camera.y
                if mpx + mt >= 0 and mpy + mt >= 0 and mpx <= msw and mpy <= msh then
                    love.graphics.rectangle("fill", mpx, mpy, mt, mt)
                end
            end
        end
    end
    love.graphics.setCanvas()

    -- Draw scene to canvas (ring goes here, below player)
    love.graphics.setCanvas(sceneCanvas)
    love.graphics.clear(0,0,0)
    maze:draw(camera)

    -- Ring shader pass (inside sceneCanvas, above water but below player)
    if splashShader and (inWaterFade > 0.01) then
        splashShader:send("u_time", love.timer.getTime())
        splashShader:send("u_resolution", {sw, sh})
        splashShader:send("u_camera", {camera.x, camera.y})
        splashShader:send("u_playerWorld", {player.x, player.y})
        splashShader:send("u_inWater", inWaterFade)
        splashShader:send("u_splashProgress", -1.0) -- no splash
        splashShader:send("u_splashWorld", {splashWorldPos.x, splashWorldPos.y})
        splashShader:send("u_splashPixelCount", splashPixelCount)
        splashShader:send("u_splashCenterRadius", splashCenterSize)
        splashShader:send("u_ringBaseRadius", ringBaseRadius)
        splashShader:send("u_ringPulseSpeed", ringPulseSpeed)
        splashShader:send("u_splashScale", splashScale)
        splashShader:send("u_ringScale", ringScale)
        splashShader:send("u_waterMask", waterMaskCanvas)
        love.graphics.setShader(splashShader)
        love.graphics.setBlendMode("add")
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setBlendMode("alpha")
        love.graphics.setShader()
    end

    player:draw(camera, maze)
    player:drawHand(maze, camera, handRadius, axeSheet, axeQuads)
    criker:draw(camera)
    love.graphics.setCanvas()

    -- Draw scene
    love.graphics.setColor(1,1,1)
    love.graphics.draw(sceneCanvas, 0, 0)

    -- Apply flashlight
    drawFlashlight()

    -- Sweep effect (ataque)
    drawSweep()

    -- Water splash overlay (blend add) — solo splash, sin ring
    if splashShader and splashPhase >= 0 then
        splashShader:send("u_time", love.timer.getTime())
        splashShader:send("u_resolution", {sw, sh})
        splashShader:send("u_camera", {camera.x, camera.y})
        splashShader:send("u_playerWorld", {player.x, player.y})
        splashShader:send("u_inWater", 0.0) -- no ring
        splashShader:send("u_splashProgress", splashPhase)
        splashShader:send("u_splashWorld", {splashWorldPos.x, splashWorldPos.y})
        splashShader:send("u_splashPixelCount", splashPixelCount)
        splashShader:send("u_splashCenterRadius", splashCenterSize)
        splashShader:send("u_ringBaseRadius", ringBaseRadius)
        splashShader:send("u_ringPulseSpeed", ringPulseSpeed)
        splashShader:send("u_splashScale", splashScale)
        splashShader:send("u_ringScale", ringScale)
        splashShader:send("u_waterMask", waterMaskCanvas)
        love.graphics.setShader(splashShader)
        love.graphics.setBlendMode("add")
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setBlendMode("alpha")
        love.graphics.setShader()
    end

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

    -- Room name HUD (only during gameplay, not editor)
    if state == "play" then
        local loc = maze:getLocationInfo(player.x, player.y)
        if loc and loc.sala and loc.sala ~= "--" then
            local sw, sh = love.graphics.getDimensions()
            love.graphics.setFont(fonts.f18)
            local tw = fonts.f18:getWidth(loc.sala)
            local bx = (sw - tw) / 2 - 10
            local by = 10
            local bw = tw + 20
            local bh = 28
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", bx, by, bw, bh)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(loc.sala, bx + 10, by + 5)
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
            elseif p == "- HAND -" then
                txt = "=== " .. p .. " ==="
            elseif p == "Open Comun" or p == "Open Epic" or p == "Open Legend" then
                txt = p
            elseif p == "Offset X" then
                txt = p .. ": " .. chestOffsetX
            elseif p == "Hand Radius" then
                txt = p .. ": " .. string.format("%.1f", handRadius)
            elseif p == "Attack Duration" then
                txt = p .. ": " .. string.format("%.2fs", attackDuration)
            elseif p == "- WATER -" then
                txt = "=== " .. p .. " ==="
            elseif p == "- SPLASH -" then
                txt = "=== " .. p .. " ==="
            elseif p == "- RING -" then
                txt = "=== " .. p .. " ==="
            elseif p == "Water PixelCount" then
                txt = p .. ": " .. waterPixelCount
            elseif p == "Water Speed" then
                txt = p .. ": " .. string.format("%.2f", waterSpeed)
            elseif p == "Water Distortion" then
                txt = p .. ": " .. string.format("%.2f", waterDistortion)
            elseif p == "Splash PixelCount" then
                txt = p .. ": " .. splashPixelCount
            elseif p == "Splash CenterSize" then
                txt = p .. ": " .. string.format("%.2f", splashCenterSize)
            elseif p == "Splash Duration" then
                txt = p .. ": " .. string.format("%.1fs", splashDuration)
            elseif p == "Ring Radius" then
                txt = p .. ": " .. string.format("%.2f", ringBaseRadius)
            elseif p == "Ring Speed" then
                txt = p .. ": " .. string.format("%.1f", ringPulseSpeed)
            elseif p == "Water Scale" then
                txt = p .. ": " .. string.format("%.1f", waterScale) .. "x"
            elseif p == "Splash Scale" then
                txt = p .. ": " .. string.format("%.1f", splashScale) .. "x"
            elseif p == "Ring Scale" then
                txt = p .. ": " .. string.format("%.1f", ringScale) .. "x"
            else
                local val = configRef[p]
                if type(val) == "table" then
                    txt = p..": ["..val[1]..","..val[2].."]"
                else
                    txt = p..": "..tostring(val)
                end
            end

            -- Color del texto
            if p == "- CHEST -" or p == "- HAND -" or p == "- WATER -" or p == "- SPLASH -" or p == "- RING -" then
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

    -- Character editor overlay
    if charEditor.active then
        drawCharEditor()
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

    -- Touch UI overlay (mobile only)
    if isMobile and touchUI then
        touchUI:draw(fonts, state)
    end
end