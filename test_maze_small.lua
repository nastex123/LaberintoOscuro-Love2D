-- Test script for very small Maze (rows=10, cols=10)
local love = {}
love.math = {}
function love.math.random(a,b)
    if a and b then return math.random(a,b) else return math.random() end
end
function love.math.setRandomSeed(seed) math.randomseed(seed) end
love.graphics = {}
function love.graphics.newCanvas(...) end
function love.graphics.setShader(...) end
function love.graphics.setBlendMode(...) end
function love.graphics.setColor(...) end
function love.graphics.rectangle(...) end
function love.graphics.print(...) end
function love.graphics.setFont(...) end
function love.graphics.newFont(...) end

local Maze = require "maze"
local config = {cols = 10, rows = 10, tile = 28, roomCount = {2,3}, branchCount = {1,2}, branchLen = {2,4}, loopChance = 0.5, perlinThresh = 0.25, seed = 123}
local maze = Maze:new(config)
maze:generate()
print('Small maze generated: rows='..maze.rows..' cols='..maze.cols)
