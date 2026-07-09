-- character.lua – Partes del cuerpo dibujables con primitivas
local Character = {}

local PART_PARAM_META = {
    circle = {
        { key = "offsetX", name = "Offset X", min = -30, max = 30, step = 1, fmt = "%.0f" },
        { key = "offsetY", name = "Offset Y", min = -30, max = 30, step = 1, fmt = "%.0f" },
        { key = "radius",  name = "Radio",    min = 1,  max = 20, step = 1, fmt = "%.0f" },
        { key = "colorR",  name = "Rojo",     min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
        { key = "colorG",  name = "Verde",    min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
        { key = "colorB",  name = "Azul",     min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
    },
    rect = {
        { key = "offsetX", name = "Offset X", min = -30, max = 30, step = 1, fmt = "%.0f" },
        { key = "offsetY", name = "Offset Y", min = -30, max = 30, step = 1, fmt = "%.0f" },
        { key = "width",   name = "Ancho",    min = 1,  max = 20, step = 1, fmt = "%.0f" },
        { key = "height",  name = "Alto",     min = 1,  max = 20, step = 1, fmt = "%.0f" },
        { key = "colorR",  name = "Rojo",     min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
        { key = "colorG",  name = "Verde",    min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
        { key = "colorB",  name = "Azul",     min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
    },
    line = {
        { key = "offsetX", name = "Offset X", min = -30, max = 30, step = 1, fmt = "%.0f" },
        { key = "offsetY", name = "Offset Y", min = -30, max = 30, step = 1, fmt = "%.0f" },
        { key = "length",  name = "Largo",    min = 1,  max = 30, step = 1, fmt = "%.0f" },
        { key = "angleDeg",name = "Angulo",   min = -180, max = 180, step = 5, fmt = "%.0f" },
        { key = "colorR",  name = "Rojo",     min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
        { key = "colorG",  name = "Verde",    min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
        { key = "colorB",  name = "Azul",     min = 0,  max = 1,  step = 0.05, fmt = "%.2f" },
    },
}

local DEFAULT_PARTS = {
    { name = "Cuerpo",    type = "circle", offsetX = 0,    offsetY = 0,  radius=6, colorR=0,   colorG=1,   colorB=1 },
    { name = "Ojo Izq",   type = "rect",   offsetX = -4.5, offsetY=-3.5, width=3, height=3, colorR=1, colorG=1, colorB=1 },
    { name = "Ojo Der",   type = "rect",   offsetX = 2.5,  offsetY=-3.5, width=3, height=3, colorR=1, colorG=1, colorB=1 },
    { name = "Brazo Izq", type = "line",   offsetX = -6,   offsetY=-1,  length=6, angleDeg=-25, colorR=0, colorG=0.8, colorB=0.8 },
    { name = "Brazo Der", type = "line",   offsetX = 6,    offsetY=-1,  length=6, angleDeg=25,  colorR=0, colorG=0.8, colorB=0.8 },
    { name = "Pierna Izq",type = "line",   offsetX = -3,   offsetY=5,   length=5, angleDeg=15,  colorR=0, colorG=0.8, colorB=0.8 },
    { name = "Pierna Der",type = "line",   offsetX = 3,    offsetY=5,   length=5, angleDeg=-15, colorR=0, colorG=0.8, colorB=0.8 },
}

local CharInstance = {}
CharInstance.__index = CharInstance

function CharInstance:draw(sx, sy, bobOffset, sinkOffset)
    for _, part in ipairs(self.parts) do
        local px = sx + part.offsetX
        local py = sy + part.offsetY + bobOffset + sinkOffset
        love.graphics.setColor(part.colorR, part.colorG, part.colorB)
        if part.type == "circle" then
            love.graphics.circle("fill", px, py, part.radius)
        elseif part.type == "rect" then
            love.graphics.rectangle("fill", px - part.width/2, py - part.height/2, part.width, part.height)
        elseif part.type == "line" then
            local rad = math.rad(part.angleDeg)
            local ex = px + math.cos(rad) * part.length
            local ey = py + math.sin(rad) * part.length
            love.graphics.setLineWidth(2)
            love.graphics.line(px, py, ex, ey)
            love.graphics.setLineWidth(1)
        end
    end
end

function Character.create()
    local self = setmetatable({}, CharInstance)
    self.parts = {}
    for _, dp in ipairs(DEFAULT_PARTS) do
        local p = {}
        for k, v in pairs(dp) do p[k] = v end
        table.insert(self.parts, p)
    end
    return self
end

function Character.getParamMeta(part)
    return PART_PARAM_META[part.type] or {}
end

function Character.snapshot(char)
    local pose = {}
    for i, part in ipairs(char.parts) do
        pose[i] = {}
        for k, v in pairs(part) do
            if k ~= "name" and k ~= "type" then
                pose[i][k] = v
            end
        end
    end
    return pose
end

function Character.applyPose(char, pose)
    for i, p in ipairs(pose) do
        if char.parts[i] then
            for k, v in pairs(p) do
                char.parts[i][k] = v
            end
        end
    end
end

function Character.defaultPart()
    return { name = "Nueva", type = "circle", offsetX = 0, offsetY = 0, radius = 3, colorR = 1, colorG = 1, colorB = 1 }
end

function Character.hitTestPart(part, mx, my)
    if part.type == "circle" then
        return (mx - part.offsetX)^2 + (my - part.offsetY)^2 <= part.radius^2
    elseif part.type == "rect" then
        return mx >= part.offsetX - part.width/2 and mx <= part.offsetX + part.width/2 and
               my >= part.offsetY - part.height/2 and my <= part.offsetY + part.height/2
    elseif part.type == "line" then
        local rad = math.rad(part.angleDeg)
        local ex = part.offsetX + math.cos(rad) * part.length
        local ey = part.offsetY + math.sin(rad) * part.length
        local dx, dy = ex - part.offsetX, ey - part.offsetY
        local len = math.sqrt(dx^2 + dy^2)
        if len < 0.01 then return false end
        local t = ((mx - part.offsetX) * dx + (my - part.offsetY) * dy) / (len^2)
        t = math.max(0, math.min(1, t))
        local px, py = part.offsetX + t * dx, part.offsetY + t * dy
        return math.sqrt((mx - px)^2 + (my - py)^2) < 4
    end
    return false
end

local function defaultForType(t)
    if t == "circle" then return {radius = 3}
    elseif t == "rect" then return {width = 3, height = 3}
    else return {length = 5, angleDeg = 0}
    end
end

function Character.changePartType(part, newType)
    local leftovers = defaultForType(newType)
    for k, v in pairs(leftovers) do
        part[k] = v
    end
    part.type = newType
end
    local result = {}
    for i = 1, #poseA do
        result[i] = {}
        for k, v in pairs(poseA[i]) do
            local b = (poseB[i] and poseB[i][k]) or v
            result[i][k] = v + (b - v) * t
        end
    end
    return result
end

return Character