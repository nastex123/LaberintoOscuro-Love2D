-- debug.lua – Simple top‑right overlay for development

local Debug = {}

function Debug:draw(maze, player, criker, lives, camera)
    local loc = maze:getLocationInfo(player.x, player.y)
    local d = math.sqrt((player.x - criker.x)^2 + (player.y - criker.y)^2)
    local inSafe = maze:isSafe(player.x, player.y) and "SI" or "NO"
    local lines = {
        "Sala: " .. (loc.sala or "--"),
        "Pasillo: " .. (loc.pasillo or "--"),
        "Safe: " .. inSafe,
        "Criker: " .. (criker.state or "--"),
        string.format("Dist: %dpx", math.floor(d + 0.5)),
        "Vidas: " .. tostring(lives),
        string.format("Salida: (%d,%d)", maze.exitCell and maze.exitCell.x or -1, maze.exitCell and maze.exitCell.y or -1),
        "Tesoro: " .. (maze.treasureRoom and maze.treasureRoom.name or "--"),
        string.format("SafeRoom: (%d,%d)", maze.safeRoom and maze.safeRoom.cx or -1, maze.safeRoom and maze.safeRoom.cy or -1),
        "Rooms: " .. tostring(#maze.rooms),
        "Branches: " .. tostring(#maze.branches),
        "Loops: " .. tostring(#maze.loops),
    }
    love.graphics.setColor(0,1,0)
    love.graphics.setFont(love.graphics.newFont(12))
    local x = love.graphics.getWidth() - 150
    local y = 10
    for i, line in ipairs(lines) do
        love.graphics.print(line, x, y + (i-1)*14)
    end
end

return Debug
