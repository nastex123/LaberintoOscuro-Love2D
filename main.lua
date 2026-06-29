-- main.lua – Love2D entry point, full-feature implementation

local Maze   = require "maze"
local Player = require "player"
local Criker = require "criker"
local Debug  = require "debugInfo"

local TILE_SIZE = 28
local MAZE_COLS = 140
local MAZE_ROWS = 140

-- globals will be created in love.load
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

local function addLight(x, y, radius, color, falloff)
    lights[#lights+1] = {x=x, y=y, radius=radius, color=color, falloff=falloff or 2}
end

local currentTemplates = {}

local editor = {
    active = false, currentIdx = 1, grid = {},
    cursorX = 1, cursorY = 1, brush = 0,
    width = 10, height = 10, name = "Nueva sala",
}
local brushChars = {[0]='.', [1]='#', [2]='X', [3]='L', [4]='R'}
local brushNames = {[0]="Suelo", [1]="Pared", [2]="Salida", [3]="Luz", [4]="Relicario"}

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
    local f, err = io.open("room_templates.lua", "w")
    if f then
        f:write(content)
        f:close()
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

    --=== 1. Cargar configuración por defecto (JSON) ===
    local json = require "json"
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
        elseif key == "rooms" or key == "branches" or key == "branchlen" then
            local a,b = value:match("(%d+)%-(%d+)")
            if a and b then config[key] = {tonumber(a), tonumber(b)} end
        elseif key == "loopchance" or key == "perlin" then
            config[key] = tonumber(value)
        elseif key == "seed" then
            config[key] = tonumber(value)
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
            maze:fillGrid()
        elseif step == "lights" then
            maze:createRooms()
            maze:buildSpine()
            maze:buildBranches()
            maze:buildLoops()
            maze:degradeEdges()
            maze:fillGrid()
        else
            maze:generate()
        end
    else
        maze:generate()
    end

    player = Player:new()
    criker = Criker:new()
    if maze.startRoom then
        player:setPos(maze.startRoom, maze)
    end

    initCanvases()
    loadShaders()

    -- Cargar plantillas de salas personalizadas
    currentTemplates = require "room_templates"

    --=== 5. UI de depuración en tiempo real ===
    ui = {
        active = false,
        selection = 1,
        params = {"cols","rows","tile","roomCount","branchCount","branchLen","loopChance","perlinThresh"}
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
        perlinThresh = "Umbral (0‑1) de ruido Perlin para degradar paredes"
    }
    configRef = config   -- referencia global para la UI

    --=== 6. Luz estática de salida (amarilla) ===
    if maze.exitCell then
        addLight(maze.exitCell.x * TILE_SIZE, maze.exitCell.y * TILE_SIZE,
                 120, {1,0.9,0}, 2)  -- amarillo
    end
end
    -- exit light and init handled earlier

-- Input handling – keyboard only
local function getInput()
    local x, y = 0, 0
    if love.keyboard.isDown("left", "a") then x = -1 end
    if love.keyboard.isDown("right", "d") then x = 1 end
    if love.keyboard.isDown("up", "w") then y = -1 end
    if love.keyboard.isDown("down", "s") then y = 1 end
    return {x = x, y = y}
end

-- No shader switching: solo se usa el shader Falloff
function love.keypressed(key)
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
    -- UI toggle
    if key == "f1" then
        ui.active = not ui.active
        return
    end
    if not ui.active then return end

    local sel = ui.selection
    local param = ui.params[sel]
    if key == "up" then
        ui.selection = (sel - 2) % #ui.params + 1
    elseif key == "down" then
        ui.selection = sel % #ui.params + 1
        elseif key == "right" then
            -- increment
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
            -- decrement max
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
        elseif key == "home" then
            -- increment min
            if param == "roomCount" or param == "branchCount" or param == "branchLen" then
                if type(configRef[param]) ~= "table" then
                    local cur = configRef[param] or 1
                    configRef[param] = {cur, cur}
                end
                local minVal = configRef[param][1] or configRef[param][2] or 1
                local maxVal = configRef[param][2] or minVal
                if minVal + 1 <= maxVal then
                    configRef[param][1] = minVal + 1
                end
            end
        elseif key == "end" then
            -- decrement min
            if param == "roomCount" or param == "branchCount" or param == "branchLen" then
                if type(configRef[param]) ~= "table" then
                    local cur = configRef[param] or 1
                    configRef[param] = {cur, cur}
                end
                local minVal = configRef[param][1] or configRef[param][2] or 1
                if minVal - 1 >= 1 then
                    configRef[param][1] = minVal - 1
                end
            end
        elseif key == "r" then
        -- Regenerar el laberinto con la configuración actual
        -- Reset static lights
        lights = {}
        maze = Maze:new(configRef)
        maze:generate()
        player = Player:new()
        criker = Criker:new()
        player:setPos(maze.startRoom, maze)
        if maze.exitCell then
            addLight(maze.exitCell.x * TILE_SIZE, maze.exitCell.y * TILE_SIZE,
                     120, {1,0.9,0}, 2)
        end
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
    if state ~= "play" then return end
    time = time + dt
    if not criker.active then
        crikerSpawnTimer = crikerSpawnTimer + dt
        if crikerSpawnTimer >= 1.5 then
            criker:spawnValidated(maze)
        end
    end
    local input = getInput()
    player:update(input, maze, dt)
    if criker.active then criker:update(player, maze, dt) end
    -- collision
    if criker.active and math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2) < 15 then
        lives = lives - 1
        criker:spawnValidated(maze)
        if lives <= 0 then state = "dead" end
    end
    if maze:isExit(player.x, player.y) then state = "win" end
    -- camera follows player
    camera.x = camera.x + (player.x - love.graphics.getWidth()/2 - camera.x) * 0.1
    camera.y = camera.y + (player.y - love.graphics.getHeight()/2 - camera.y) * 0.1
end

local function drawUI()
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.print("\226\156\165 x "..lives, 20, 30)
    local d = math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2)
    if d < 220 then
        local a = 1 - (d / 220)
        love.graphics.setColor(1,0,0, a*0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 12)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight()-12, love.graphics.getWidth(), 12)
        love.graphics.rectangle("fill", 0, 0, 12, love.graphics.getHeight())
        love.graphics.rectangle("fill", love.graphics.getWidth()-12, 0, 12, love.graphics.getHeight())
    end
    -- UI panel drawn later (see section near line 401)
end

local function drawFlashlight()
    local sw, sh = love.graphics.getDimensions()
    local shader = shaders[currentShader]
    if not shader then return end

    -- Flicker
    local flicker = math.sin(time*12)*8 + math.sin(time*23)*5 + (math.random()-0.5)*6
    local radius  = 200 + flicker

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
            elseif ch == 'R' then color = {0.533,0.4,0.267}
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
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.print(editor.name .. " (" .. editor.width .. "x" .. editor.height .. ")", 20, 20)

    -- Brush indicator
    love.graphics.print("Brocha: " .. (brushNames[editor.brush] or "?"), sw - 200, 20)

    -- Template navigation
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("Sala " .. editor.currentIdx .. " de " .. #currentTemplates, sw - 200, 40)

    -- Controls help
    local helpY = sh - 130
    local help = {
        "Flechas: mover cursor  Click izq: pintar  Der: borrar",
        "1=Suelo  2=Pared  3=Luz  4=Salida  5=Reliquia",
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

-- UI panel (runtime editing)
if ui.active then
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0,0,0,0.6)
    love.graphics.rectangle("fill", 10, 10, 250, (#ui.params+4)*18)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.print("Seed: "..tostring(currentSeed), 20, 20)
    for i, p in ipairs(ui.params) do
        local val = configRef[p]
        local txt = p..": "
        if type(val) == "table" then
            txt = txt .. "["..val[1]..","..val[2].."]"
        else
            txt = txt .. tostring(val)
        end
        if i == ui.selection then love.graphics.setColor(1,1,0) else love.graphics.setColor(1,1,1) end
        love.graphics.print(txt, 20, 20 + i*18)
        if i == ui.selection then
            local desc = paramDescriptions[p] or ""
            love.graphics.setColor(0.8,0.8,0.8)
            love.graphics.print(desc, 150, 20 + i*18 + 20)
        end
    end
    love.graphics.setColor(1,1,1)
end

    if editor.active then drawEditor() end

    if state == "dead" then
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(36))
        love.graphics.print("GAME OVER", love.graphics.getWidth()/2 - 100, love.graphics.getHeight()/2)
    elseif state == "win" then
        love.graphics.setColor(1,1,0)
        love.graphics.setFont(love.graphics.newFont(36))
        love.graphics.print("\194\161ESCAPASTE!", love.graphics.getWidth()/2 - 110, love.graphics.getHeight()/2)
    end
end
