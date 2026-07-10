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
local UIDebug = require "ui_debug"
local EditorF2 = require "editor_f2"
local CharEditor = require "char_editor"

local lives = 3
local state = "play" -- "play", "win", "dead"
local time = 0
local camera = {x = 0, y = 0}

-- Canvases and shaders for lighting
local sceneCanvas, lightCanvas, waterMaskCanvas
local shaders = {}
local currentShader = 1
local shaderNames = {}

-- Table de luces estáticas
local lights = {}
local json = require "json"

local function addLight(x, y, radius, color, falloff)
    lights[#lights+1] = {x=x, y=y, radius=radius, color=color, falloff=falloff or 2}
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
    player.attackDuration = UIDebug.attackDuration
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
    EditorF2.currentTemplates = require "room_templates"

    --=== 5. UI de depuración en tiempo real (F1) ===
    UIDebug.currentSeed = currentSeed
    UIDebug.configRef = config
    UIDebug.loadConfig()

    player.attackDuration = UIDebug.attackDuration

    -- Variables para el sistema de reemplazo de inventario
    pendingItem = nil
    pendingTier = nil
    waitingForDecision = false

    -- Cargar configuración de personaje (F3)
    CharEditor:loadConfig(player)

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

-- Resetea una partida completa conservando la configuracion actual.
-- Usado por la tecla R y por el reinicio tras win/dead.
local function resetGameState()
    lights = {}
    maze = Maze:new(UIDebug.configRef)
    maze:generate()
    player = Player:new()
    player.attackDuration = UIDebug.attackDuration
    player.inventory = {}
    player.effects = {}
    criker = Criker:new()
    crikerSpawnTimer = 0
    Vault:placeAll(maze)
    player:setPos(maze.startRoom, maze)
    if maze.exitCell then
        addLight(maze.exitCell.x * maze.tile, maze.exitCell.y * maze.tile, 120, {1,0.9,0}, 2)
    end
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

-- Editor toggle (F2)
    if key == "f2" then
        EditorF2.active = not EditorF2.active
        if EditorF2.active then EditorF2:initEditor() end
        return
    end
    if EditorF2.active then
        EditorF2:keypressed(key)
        return
    end
    -- Chest animation close
    if key == "e" and ChestAnim.state == "done" then
        ChestAnim:close()
        return
    end

    -- UI (F1) / Character Editor (F3) toggle
    if key == "f1" then
        if CharEditor.active then CharEditor.active = false end
        UIDebug:toggle()
        return
    end
    if key == "f3" then
        if UIDebug.ui.active then UIDebug.ui.active = false end
        CharEditor.active = not CharEditor.active
        if CharEditor.active and player.character then

        end
        return
    end
    if UIDebug.ui.active then
        UIDebug:keypressed(key, state, resetGameState, {pendingItem}, {pendingTier}, {waitingForDecision}, ChestAnim, Items)
        return
    end
    if CharEditor.active then
        CharEditor:keypressed(key, player)
        return
    end
end

function love.mousepressed(mx, my, button)
    if EditorF2.active then
        EditorF2:mousepressed(mx, my, button, Tiles.order)
        return
    end
    if CharEditor.active then
        CharEditor:mousepressed(mx, my, button, player)
        return
    end
end

function love.mousemoved(mx, my)
    if EditorF2.active then
        EditorF2:mousemoved(mx, my)
        return
    end
    if CharEditor.active and CharEditor.dragging then
        CharEditor:mousemoved(mx, my, player)
    end
end

function love.wheelmoved(x, y)
    CharEditor:wheelmoved(x, y, player)
end

function love.mousereleased(mx, my, button)
    if button == 1 then
        CharEditor:mousereleased(mx, my, button, player)
    end
end

function love.textinput(text)
    if EditorF2.active then
        EditorF2:textinput(text)
    elseif CharEditor.active then
        CharEditor:textinput(text)
    end
end

local crikerSpawnTimer = 0
function love.update(dt)
    if EditorF2.active then return end
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

            -- Water splash / ring state (delegado a UI debug)
            UIDebug:update(dt, maze, player, Tiles)

            -- Character animation (pose blend)
            CharEditor:update(player, dt)
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
                    ChestAnim:start(tier, itemId, UIDebug.chestOffsetX)
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
            UIDebug:toggle()
        end
        -- Editor toggle (F2)
        if touchUI:wasPressed("editor") then
            EditorF2.active = not EditorF2.active
            if EditorF2.active then EditorF2:initEditor() end
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

    -- Right arm follows mouse cursor (gameplay only, not in editors)
    if state == "play" and player and player.character and not CharEditor.active then
        local arm
        for _, p in ipairs(player.character.parts) do
            if p.name == "Brazo Der" then arm = p; break end
        end
        if arm then
            local mx, my = love.mouse.getPosition()
            local angle = math.deg(math.atan2(
                my + camera.y - (player.y + arm.offsetY),
                mx + camera.x - (player.x + arm.offsetX)))
            arm.angleDeg = angle
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
    local dist = UIDebug.handRadius * tile
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
    if splashShader and (UIDebug.inWaterFade > 0.01) then
        splashShader:send("u_time", love.timer.getTime())
        splashShader:send("u_resolution", {sw, sh})
        splashShader:send("u_camera", {camera.x, camera.y})
        splashShader:send("u_playerWorld", {player.x, player.y})
        splashShader:send("u_inWater", UIDebug.inWaterFade)
        splashShader:send("u_splashProgress", -1.0) -- no splash
        splashShader:send("u_splashWorld", {UIDebug.splashWorldPos.x, UIDebug.splashWorldPos.y})
        splashShader:send("u_splashPixelCount", UIDebug.splashPixelCount)
        splashShader:send("u_splashCenterRadius", UIDebug.splashCenterSize)
        splashShader:send("u_ringBaseRadius", UIDebug.ringBaseRadius)
        splashShader:send("u_ringPulseSpeed", UIDebug.ringPulseSpeed)
        splashShader:send("u_splashScale", UIDebug.splashScale)
        splashShader:send("u_ringScale", UIDebug.ringScale)
        splashShader:send("u_waterMask", waterMaskCanvas)
        love.graphics.setShader(splashShader)
        love.graphics.setBlendMode("add")
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setBlendMode("alpha")
        love.graphics.setShader()
    end

    player:draw(camera, maze)
    player:drawHand(maze, camera, UIDebug.handRadius, axeSheet, axeQuads)
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
    if splashShader and UIDebug.splashPhase >= 0 then
        splashShader:send("u_time", love.timer.getTime())
        splashShader:send("u_resolution", {sw, sh})
        splashShader:send("u_camera", {camera.x, camera.y})
        splashShader:send("u_playerWorld", {player.x, player.y})
        splashShader:send("u_inWater", 0.0) -- no ring
        splashShader:send("u_splashProgress", UIDebug.splashPhase)
        splashShader:send("u_splashWorld", {UIDebug.splashWorldPos.x, UIDebug.splashWorldPos.y})
        splashShader:send("u_splashPixelCount", UIDebug.splashPixelCount)
        splashShader:send("u_splashCenterRadius", UIDebug.splashCenterSize)
        splashShader:send("u_ringBaseRadius", UIDebug.ringBaseRadius)
        splashShader:send("u_ringPulseSpeed", UIDebug.ringPulseSpeed)
        splashShader:send("u_splashScale", UIDebug.splashScale)
        splashShader:send("u_ringScale", UIDebug.ringScale)
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
    UIDebug.draw()

    -- Editor overlay
    if EditorF2.active then
        EditorF2:draw(Tiles.order, tileSheets, tileQuads, Tiles)
    end

    -- Character editor overlay
    if CharEditor.active then
        CharEditor:draw(player)
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