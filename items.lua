-- items.lua – Item definitions and inventory system

local Items = {}

Items.defs = {
    antorch = { id="antorch", nombre="Antorcha",   tier="common",    desc="Aumenta el radio de luz", color={1,0.6,0} },
    palo    = { id="palo",    nombre="Palo",       tier="common",    desc="3 golpes",                 color={0.6,0.4,0.2}, maxUses=3 },
    brujula = { id="brujula", nombre="Brújula",    tier="epic",      desc="Muestra distancia a salida", color={0.3,0.3,1} },
    mapa    = { id="mapa",    nombre="Mapa",       tier="epic",      desc="Revela el mapa",           color={0.2,0.8,0.2} },
    espada  = { id="espada",  nombre="Espada",     tier="legendary", desc="5 golpes",                 color={0.9,0.9,0.9}, maxUses=5 },
}

Items.pools = {
    common    = { "antorch", "palo" },
    epic      = { "brujula", "mapa" },
    legendary = { "espada" },
}

Items.poolWeights = {
    common    = { antorch=50, palo=50 },
    epic      = { brujula=50, mapa=50 },
    legendary = { espada=100 },
}

function Items.give(player, id)
    local def = Items.defs[id]
    if not def then return end
    player.inventory[id] = def.maxUses and { uses = def.maxUses } or true
end

function Items.has(player, id)
    return player.inventory[id] ~= nil
end

function Items.getWeapon(player)
    for _, id in ipairs({ "espada", "palo" }) do
        local inv = player.inventory[id]
        if inv and inv.uses and inv.uses > 0 then
            return { id = id, uses = inv.uses, maxUses = Items.defs[id].maxUses }
        end
    end
    return nil
end

function Items.useWeapon(player)
    for _, id in ipairs({ "espada", "palo" }) do
        local inv = player.inventory[id]
        if inv and inv.uses and inv.uses > 0 then
            inv.uses = inv.uses - 1
            if inv.uses <= 0 then player.inventory[id] = nil end
            return true
        end
    end
    return false
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

return Items
