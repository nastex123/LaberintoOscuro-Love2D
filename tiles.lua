-- tiles.lua – Sistema central de tipos de tile
-- Tabla compartida para editor, generacion de maze y renderizado

local Tiles = {}

-- defs[id] = { char, name, color, walkable, solid, texture }
-- texture = nil (color solido) o string key en tileTextureQuads
Tiles.defs = {
    [0] = { id=0, char='.', name="Suelo",           color={0.039,0.039,0.039}, walkable=true,  solid=false, texture=nil },
    [1] = { id=1, char='#', name="Pared",           color={0.176,0.176,0.227}, walkable=false, solid=true,  texture=nil },
    [2] = { id=2, char='X', name="Salida",          color={1,0.867,0},          walkable=true,  solid=false, texture=nil },
    [3] = { id=3, char='L', name="Luz",             color={0.267,0.533,0.667}, walkable=true,  solid=false, texture=nil },
    [4] = { id=4, char='C', name="Cofre común",    color={0.533,0.4,0.267},   walkable=true,  solid=false, texture=nil },
    [5] = { id=5, char='R', name="Cofre épico",     color={0.533,0.267,0.667}, walkable=true,  solid=false, texture=nil },
    [6] = { id=6, char='G', name="Cofre legendario",color={0.867,0.667,0},    walkable=true,  solid=false, texture=nil },
    [7] = { id=7, char='?', name="Cofre aleatorio", color={0.4,0.8,1},         walkable=true,  solid=false, texture=nil },
    [8] = { id=8, char='W', name="Agua",            color={0.2,0.4,0.8},       walkable=true,  solid=false, texture="water" },
}

-- Orden para iterar (barra lateral del editor)
Tiles.order = {0, 1, 2, 3, 4, 5, 6, 7, 8}

-- Lookup por char (para carveTemplate)
local charMap = {}
for _, def in pairs(Tiles.defs) do
    charMap[def.char] = def.id
end
Tiles.charToId = charMap

-- IDs especiales
Tiles.WATER = 8
Tiles.WALL  = 1
Tiles.FLOOR = 0

return Tiles
