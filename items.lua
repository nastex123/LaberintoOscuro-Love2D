-- items.lua – Item definitions and inventory system (Expanded with 60 items)

local Items = {}

Items.defs = {
    -- ============ COMUNES (20) ============
    antorch = { id="antorch", nombre="Antorcha", tier="common", type="passive", desc="Aumenta el radio de luz +80px", color={1,0.6,0} },
    palo    = { id="palo", nombre="Palo", tier="common", type="weapon", desc="3 golpes (aturde 3s)", color={0.6,0.4,0.2}, maxUses=3, stunDuration=3 },
    vida    = { id="vida", nombre="Poción de vida", tier="common", type="consumable", desc="Recupera 1 vida", color={1,0.2,0.2}, maxUses=1 },
    venda   = { id="venda", nombre="Venda", tier="common", type="consumable", desc="Recupera 1 vida", color={0.9,0.9,0.9}, maxUses=1 },
    bengala = { id="bengala", nombre="Bengala", tier="common", type="consumable", desc="Aumenta la luz +200px por 5s", color={1,0.8,0.2}, maxUses=1 },
    cuerda  = { id="cuerda", nombre="Cuerda", tier="common", type="consumable", desc="Teletransporta a la Sala Segura", color={0.8,0.6,0.3}, maxUses=1 },
    ruido   = { id="ruido", nombre="Piedra ruidosa", tier="common", type="consumable", desc="Atrae al Criker 3s", color={0.5,0.5,0.5}, maxUses=1 },
    trampa  = { id="trampa", nombre="Trampa de pinchos", tier="common", type="consumable", desc="Aturde al Criker 2s si pisa", color={0.5,0.5,0.5}, maxUses=1 },
    yesca   = { id="yesca", nombre="Yesca", tier="common", type="consumable", desc="Crea luz estática 8s", color={0.9,0.6,0.1}, maxUses=1 },
    botasF  = { id="botasF", nombre="Botas de fieltro", tier="common", type="passive", desc="+15% velocidad permanente", color={0.4,0.3,0.2} },
    tiza    = { id="tiza", nombre="Tiza", tier="common", type="utility", desc="Marca el tile actual", color={0.9,0.9,1}, maxUses=1 },
    daga    = { id="daga", nombre="Daga", tier="common", type="weapon", desc="1 golpe (aturde 1s)", color={0.8,0.8,0.8}, maxUses=1, stunDuration=1 },
    racion  = { id="racion", nombre="Ración", tier="common", type="consumable", desc="Recupera 1 vida", color={0.6,0.4,0.2}, maxUses=1 },
    lentes  = { id="lentes", nombre="Lentes de cerca", tier="common", type="utility", desc="Muestra info del tile actual", color={0.6,0.8,1}, maxUses=1 },
    latigo  = { id="latigo", nombre="Látigo", tier="common", type="weapon", desc="1 golpe (aturde 2s)", color={0.6,0.4,0.2}, maxUses=1, stunDuration=2 },
    sal     = { id="sal", nombre="Sal marina", tier="common", type="consumable", desc="Ralentiza al Criker 30% (4s)", color={0.9,0.9,1}, maxUses=1 },
    lupa    = { id="lupa", nombre="Lupa", tier="common", type="passive", desc="Muestra distancia salida al parar", color={0.9,0.9,0.8} },
    pegamento = { id="pegamento", nombre="Pegamento", tier="common", type="consumable", desc="Ralentiza al Criker 4s", color={0.2,0.2,0.2}, maxUses=1 },
    vela    = { id="vela", nombre="Vela", tier="common", type="consumable", desc="+100px luz por 5s", color={1,1,0.8}, maxUses=1 },
    cinta   = { id="cinta", nombre="Cinta de señal", tier="common", type="utility", desc="Marca el tile en el minimapa", color={1,0,0}, maxUses=1 },

    -- ============ ÉPICOS / RAROS (20) ============
    brujula = { id="brujula", nombre="Brújula", tier="epic", type="passive", desc="Muestra distancia a la salida", color={0.3,0.3,1} },
    mapa    = { id="mapa", nombre="Mapa", tier="epic", type="passive", desc="Revela el laberinto", color={0.2,0.8,0.2} },
    sigilo  = { id="sigilo", nombre="Capa de sigilo", tier="epic", type="consumable", desc="Invisible al Criker 6s", color={0.2,0.2,0.3}, maxUses=1 },
    botasV  = { id="botasV", nombre="Botas de velocidad", tier="epic", type="passive", desc="+40% velocidad permanente", color={0.2,0.8,0.8} },
    senuelo = { id="senuelo", nombre="Señuelo", tier="epic", type="consumable", desc="Atrae al Criker 5s", color={1,0.5,0}, maxUses=1 },
    honda   = { id="honda", nombre="Honda", tier="epic", type="weapon", desc="2 golpes (aturde 3s a distancia)", color={0.6,0.4,0.2}, maxUses=2, stunDuration=3, range="ranged" },
    martillo = { id="martillo", nombre="Martillo", tier="epic", type="weapon", desc="3 golpes (aturde 4s)", color={0.5,0.5,0.5}, maxUses=3, stunDuration=4 },
    escudo  = { id="escudo", nombre="Escudo de madera", tier="epic", type="passive", desc="Absorbe 1 golpe del Criker", color={0.6,0.4,0.2} },
    vigor   = { id="vigor", nombre="Poción vigorizante", tier="epic", type="consumable", desc="+1 vida y +20% velocidad 10s", color={0.2,1,0.2}, maxUses=1 },
    linterna = { id="linterna", nombre="Linterna de minero", tier="epic", type="passive", desc="+150px luz permanente", color={1,0.8,0.2} },
    tesoro  = { id="tesoro", nombre="Mapa de tesoros", tier="epic", type="passive", desc="Resalta el cofre más cercano", color={1,0.6,0} },
    garrote = { id="garrote", nombre="Garrote", tier="epic", type="weapon", desc="5 golpes (aturde 4s)", color={0.6,0.4,0.2}, maxUses=5, stunDuration=4 },
    espanta = { id="espanta", nombre="Espantapájaros", tier="epic", type="consumable", desc="El Criker huye de él 4s", color={0.6,0.4,0.2}, maxUses=1 },
    fuego   = { id="fuego", nombre="Poción de fuego", tier="epic", type="consumable", desc="Quema al Criker (daño 2s)", color={1,0.2,0}, maxUses=1 },
    hielo   = { id="hielo", nombre="Luz de hielo", tier="epic", type="passive", desc="Ralentiza al Criker 20% cerca", color={0.6,0.8,1} },
    silbato = { id="silbato", nombre="Silbato de caza", tier="epic", type="passive", desc="Muestra la salida en el mapa", color={0.8,0.4,0} },
    camuflaje = { id="camuflaje", nombre="Capa de camuflaje", tier="epic", type="passive", desc="El Criker te detecta un 40% menos", color={0.4,0.6,0.4} },
    arcoC   = { id="arcoC", nombre="Arco de caza", tier="epic", type="weapon", desc="2 golpes (aturde 5s a distancia)", color={0.6,0.4,0.2}, maxUses=2, stunDuration=5, range="ranged" },
    prisa   = { id="prisa", nombre="Poción de prisa", tier="epic", type="consumable", desc="+60% velocidad 5s", color={1,1,0.2}, maxUses=1 },
    falso   = { id="falso", nombre="Cofre falso", tier="epic", type="consumable", desc="Aturde al Criker 6s al llegar", color={0.8,0.6,0.2}, maxUses=1 },

    -- ============ LEGENDARIOS (20) ============
    espada  = { id="espada", nombre="Espada", tier="legendary", type="weapon", desc="5 golpes (aturde 5s)", color={0.9,0.9,0.9}, maxUses=5, stunDuration=5 },
    arcoL   = { id="arcoL", nombre="Arco largo", tier="legendary", type="weapon", desc="3 golpes (aturde 6s a distancia)", color={0.8,0.6,0.2}, maxUses=3, stunDuration=6, range="ranged" },
    amuleto = { id="amuleto", nombre="Amuleto de protección", tier="legendary", type="passive", desc="Absorbe 2 golpes del Criker", color={1,0.8,0} },
    esencia = { id="esencia", nombre="Esencia de la antorcha", tier="legendary", type="passive", desc="+150px luz permanente", color={1,0.6,0} },
    eternidad = { id="eternidad", nombre="Poción de la eternidad", tier="legendary", type="consumable", desc="Recupera las 3 vidas", color={1,0.2,1}, maxUses=1 },
    bculo   = { id="bculo", nombre="Báculo de luz", tier="legendary", type="consumable", desc="Crea una luz permanente en el suelo", color={1,1,1}, maxUses=1 },
    esfera  = { id="esfera", nombre="Esfera de teletransporte", tier="legendary", type="consumable", desc="Teletransporta a la salida", color={0.2,0.2,1}, maxUses=1 },
    armadura= { id="armadura", nombre="Armadura de diamante", tier="legendary", type="passive", desc="Absorbe 3 golpes del Criker", color={0.6,0.8,1} },
    fuegEs  = { id="fuegEs", nombre="Espada de fuego", tier="legendary", type="weapon", desc="6 golpes (aturde 5s + ilumina)", color={1,0.2,0}, maxUses=6, stunDuration=5 },
    lampara = { id="lampara", nombre="Lámpara de Aladino", tier="legendary", type="passive", desc="Revela todo el mapa y cofres", color={1,0.9,0.2} },
    sombras = { id="sombras", nombre="Capa de las sombras", tier="legendary", type="passive", desc="Invisible al Criker sin moverte", color={0,0,0} },
    sello   = { id="sello", nombre="Sello de la luz", tier="legendary", type="passive", desc="+400px luz permanente", color={1,1,0.8} },
    salamandra= { id="salamandra", nombre="Poción de la salamandra", tier="legendary", type="consumable", desc="Inmune al Criker 15s", color={1,0.5,0}, maxUses=1 },
    guerra  = { id="guerra", nombre="Martillo de guerra", tier="legendary", type="weapon", desc="5 golpes (aturde 7s)", color={0.7,0.7,0.7}, maxUses=5, stunDuration=7 },
    talisman = { id="talisman", nombre="Talismán de escape", tier="legendary", type="consumable", desc="A la Sala Segura + cura total", color={0,1,0}, maxUses=1 },
    garras  = { id="garras", nombre="Garras de dragón", tier="legendary", type="weapon", desc="8 golpes (aturde 6s)", color={0.8,0.2,0.2}, maxUses=8, stunDuration=6 },
    cristalT= { id="cristalT", nombre="Cristal de tiempo", tier="legendary", type="consumable", desc="Ralentiza al Criker 80% (10s)", color={0.5,0.8,1}, maxUses=1 },
    guante  = { id="guante", nombre="Guante de poder", tier="legendary", type="consumable", desc="+100% velocidad 5s (3 usos)", color={1,0.2,0.2}, maxUses=3 },
    tormenta= { id="tormenta", nombre="Capa de la tormenta", tier="legendary", type="passive", desc="Empuja al Criker al acercarse (CD 15s)", color={0.2,0.2,1} },
    vacio   = { id="vacio", nombre="Cristal del vacío", tier="legendary", type="passive", desc="Invisible al Criker permanentemente", color={0.1,0.1,0.1} },
}

-- Los pools de objetos para la generación de cofres
Items.pools = {
    common    = { "antorch", "palo", "vida", "venda", "bengala", "cuerda", "ruido", "trampa", "yesca", "botasF", "tiza", "daga", "racion", "lentes", "latigo", "sal", "lupa", "pegamento", "vela", "cinta" },
    epic      = { "brujula", "mapa", "sigilo", "botasV", "senuelo", "honda", "martillo", "escudo", "vigor", "linterna", "tesoro", "garrote", "espanta", "fuego", "hielo", "silbato", "camuflaje", "arcoC", "prisa", "falso" },
    legendary = { "espada", "arcoL", "amuleto", "esencia", "eternidad", "bculo", "esfera", "armadura", "fuegEs", "lampara", "sombras", "sello", "salamandra", "guerra", "talisman", "garras", "cristalT", "guante", "tormenta", "vacio" },
}

-- Pesos (equilibrados para que todos tengan la misma probabilidad dentro de su tier)
Items.poolWeights = {
    common    = { antorch=50, palo=50, vida=50, venda=50, bengala=50, cuerda=50, ruido=50, trampa=50, yesca=50, botasF=50, tiza=50, daga=50, racion=50, lentes=50, latigo=50, sal=50, lupa=50, pegamento=50, vela=50, cinta=50 },
    epic      = { brujula=50, mapa=50, sigilo=50, botasV=50, senuelo=50, honda=50, martillo=50, escudo=50, vigor=50, linterna=50, tesoro=50, garrote=50, espanta=50, fuego=50, hielo=50, silbato=50, camuflaje=50, arcoC=50, prisa=50, falso=50 },
    legendary = { espada=50, arcoL=50, amuleto=50, esencia=50, eternidad=50, bculo=50, esfera=50, armadura=50, fuegEs=50, lampara=50, sombras=50, sello=50, salamandra=50, guerra=50, talisman=50, garras=50, cristalT=50, guante=50, tormenta=50, vacio=50 },
}

-- Funciones auxiliares
function Items.has(player, id)
    return player.inventory[id] ~= nil
end

function Items.randomFromTier(tier)
    local pool = Items.pools[tier]
    if not pool or #pool == 0 then return nil end
    local weights = Items.poolWeights[tier]
    local total = 0
    for _, id in ipairs(pool) do total = total + (weights[id] or 1) end
    local r = love.math.random() * total
    for _, id in ipairs(pool) do
        local w = weights[id] or 1
        if r <= w then return id end
        r = r - w
    end
    return pool[#pool]
end

-- =============================================================================
-- Sistema de efectos
-- =============================================================================
-- player.effects es una tabla { clave = tiempo_restante } gestionada por
-- Items.tickEffects cada frame. Los getters (getLightRadius, getSpeed, etc.)
-- consultan el inventario permanente + los efectos temporales activos.

-- Lista unica de armas en orden de prioridad (legendarias > épicas > comunes).
-- Antes estaba duplicada en getWeapon y useWeapon.
Items.weaponOrder = {
    "espada", "arcoL", "guerra", "garras", "fuegEs",        -- legendarias
    "honda", "arcoC", "martillo", "garrote",                -- épicas
    "palo", "daga", "latigo",                               -- comunes
}

function Items.getWeapon(player)
    for _, id in ipairs(Items.weaponOrder) do
        local inv = player.inventory[id]
        if inv and inv.uses and inv.uses > 0 then
            return { id = id, uses = inv.uses, maxUses = Items.defs[id].maxUses,
                     stunDuration = Items.defs[id].stunDuration, range = Items.defs[id].range }
        end
    end
    return nil
end

function Items.useWeapon(player)
    for _, id in ipairs(Items.weaponOrder) do
        local inv = player.inventory[id]
        if inv and inv.uses and inv.uses > 0 then
            inv.uses = inv.uses - 1
            if inv.uses <= 0 then player.inventory[id] = nil end
            return true
        end
    end
    return false
end

-- Aplica los efectos PASIVOS inmediatamente al recoger (solo lo que tiene
-- sentido aplicar una vez: curacion al instante, teletransporte, etc.).
-- Los pasivos con bonificador permanente (luz, velocidad, escudos) se
-- consultan via getters, no se aplican aqui.
function Items.give(player, id)
    local def = Items.defs[id]
    if not def then return end
    if def.type == "weapon" then
        -- Si ya tenias el arma, sumar usos en vez de recargarla gratis.
        if player.inventory[id] and player.inventory[id].uses then
            player.inventory[id].uses = player.inventory[id].uses + def.maxUses
        else
            player.inventory[id] = { uses = def.maxUses }
        end
    elseif def.type == "passive" or def.type == "utility" then
        player.inventory[id] = true
    else -- consumable
        player.inventory[id] = { uses = def.maxUses }
    end
end

-- Devuelve true si el item se aplico/false si no era usable o ya no quedan.
local function addTimed(player, key, seconds)
    player.effects = player.effects or {}
    player.effects[key] = math.max(player.effects[key] or 0, seconds)
end

-- Usa el consumible equipado (o el indicado). Devuelve el id usado o nil.
-- Aplica el efecto descrito en el campo 'desc' de cada item.
function Items.useConsumable(player, id, context)
    context = context or {}
    local inv = player.inventory[id]
    local def = Items.defs[id]
    if not inv or not def then return nil end
    if def.type ~= "consumable" then return nil end
    -- usos (algunos consumibles como guante tienen maxUses=3)
    if type(inv) == "table" and inv.uses and inv.uses <= 0 then return nil end

    -- === Aplicar efecto segun el id ===
    if id == "vida" or id == "venda" or id == "racion" then
        if context.heal then context.heal(1) end
    elseif id == "eternidad" then
        if context.healFull then context.healFull() end
    elseif id == "bengala" then addTimed(player, "lightBengala", 5)
    elseif id == "vela"   then addTimed(player, "lightVela", 5)
    elseif id == "yesca"  then addTimed(player, "lightYesca", 8)
    elseif id == "cuerda" then
        if context.tpSafe then context.tpSafe() end
    elseif id == "talisman" then
        if context.tpSafe then context.tpSafe() end
        if context.healFull then context.healFull() end
    elseif id == "esfera" then
        if context.tpExit then context.tpExit() end
    elseif id == "bculo" then
        if context.dropLight then context.dropLight() end
    elseif id == "ruido" or id == "senuelo" then
        addTimed(player, "lureCriker", id == "ruido" and 3 or 5)
    elseif id == "trampa" or id == "falso" then
        addTimed(player, "trapStun", id == "trampa" and 2 or 6)
    elseif id == "sal" or id == "pegamento" then
        addTimed(player, "slowCriker", 4)
    elseif id == "espanta" then
        addTimed(player, "fleeCriker", 4)
    elseif id == "fuego" then
        addTimed(player, "burnCriker", 2)
    elseif id == "sigilo" then
        addTimed(player, "stealth", 6)
    elseif id == "salamandra" then
        addTimed(player, "immune", 15)
    elseif id == "cristalT" then
        addTimed(player, "slowCrikerStrong", 10)
    elseif id == "vigor" then
        if context.heal then context.heal(1) end
        addTimed(player, "hasteVigor", 10)
    elseif id == "prisa" then addTimed(player, "hastePrisa", 5)
    elseif id == "guante" then addTimed(player, "hasteGuante", 5)
    elseif id == "tiza" or id == "cinta" or id == "lentes" then
        if context.markTile then context.markTile(id) end
    end

    -- descontar uso
    if type(inv) == "table" and inv.uses then
        inv.uses = inv.uses - 1
        if inv.uses <= 0 then player.inventory[id] = nil end
    else
        player.inventory[id] = nil
    end
    return id
end

-- Tick de efectos temporales. Llamar cada frame desde love.update.
function Items.tickEffects(player, dt)
    if not player.effects then return end
    for key, t in pairs(player.effects) do
        local nt = t - dt
        if nt <= 0 then
            player.effects[key] = nil
        else
            player.effects[key] = nt
        end
    end
end

function Items.hasEffect(player, key)
    return player.effects and player.effects[key] ~= nil
end

-- Radio de luz total del jugador (pasivos + temporales).
-- base es el radio sin items (200 normal, 280 con antorcha base antigua).
function Items.getLightRadius(player, base)
    local r = base or 200
    -- pasivos permanentes
    if Items.has(player, "antorch")  then r = r + 80 end
    if Items.has(player, "linterna") then r = r + 150 end
    if Items.has(player, "esencia")  then r = r + 150 end
    if Items.has(player, "sello")    then r = r + 400 end
    -- temporales
    if Items.hasEffect(player, "lightBengala") then r = r + 200 end
    if Items.hasEffect(player, "lightVela")    then r = r + 100 end
    if Items.hasEffect(player, "lightYesca")   then r = r + 80  end
    return r
end

-- Multiplicador de velocidad (pasivos + temporales). No se apilan: se toma
-- el maximo entre los activos.
function Items.getSpeedMultiplier(player)
    local m = 1.0
    if Items.has(player, "botasF") then m = math.max(m, 1.15) end
    if Items.has(player, "botasV") then m = math.max(m, 1.40) end
    if Items.hasEffect(player, "hasteVigor") then m = math.max(m, 1.20) end
    if Items.hasEffect(player, "hastePrisa") then m = math.max(m, 1.60) end
    if Items.hasEffect(player, "hasteGuante") then m = math.max(m, 2.00) end
    return m
end

-- ¿El jugador es invisible/no detectable para el Criker?
function Items.isStealthed(player)
    if Items.has(player, "vacio") then return true end           -- permanente
    if Items.hasEffect(player, "stealth") then return true end   -- sigilo 6s
    if Items.hasEffect(player, "immune") then return true end    -- salamandra
    return false
end

-- ¿Inmune al daño del Criker?
function Items.isImmune(player)
    return Items.hasEffect(player, "immune") ~= nil
end

-- Intenta absorber un golpe con escudos/amuleto/armadura.
-- Devuelve true si se absorbio (no se pierde vida), false si no habia escudo.
function Items.absorbHit(player)
    -- Prioridad: escudo (1) < amuleto (2) < armadura (3)
    if Items.has(player, "armadura") then
        -- La armadura absorbe 3 golpes: usamos un contador persistente.
        player.armorHits = (player.armorHits or 3) - 1
        if player.armorHits <= 0 then
            player.inventory["armadura"] = nil
            player.armorHits = nil
        end
        return true
    end
    if Items.has(player, "amuleto") then
        player.amuletHits = (player.amuletHits or 2) - 1
        if player.amuletHits <= 0 then
            player.inventory["amuleto"] = nil
            player.amuletHits = nil
        end
        return true
    end
    if Items.has(player, "escudo") then
        player.inventory["escudo"] = nil  -- 1 solo golpe
        return true
    end
    return false
end

return Items
