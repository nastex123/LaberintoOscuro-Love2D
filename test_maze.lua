-- Test script for Maze generation without Love2D GUI
local love = {}
love.math = {}
function love.math.random(a,b)
    if a and b then
        return math.random(a,b)
    else
        return math.random()
    end
end
function love.math.setRandomSeed(seed)
    math.randomseed(seed)
end
-- Dummy placeholders for required love functions (no-op)
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
local config = {
    cols = 30,
    rows = 30,
    tile = 28,
    roomCount = {8,12},
    branchCount = {4,8},
    branchLen = {8,20},
    loopChance = 0.7,
    perlinThresh = 0.25,
    seed = 12345
}
local maze = Maze:new(config)
maze:generate()
print('Maze generated successfully with rows='..maze.rows..' cols='..maze.cols)
