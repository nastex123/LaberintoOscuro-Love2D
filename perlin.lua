-- perlin.lua – Port of the JavaScript Perlin class

local Perlin = {}
Perlin.__index = Perlin

-- Utility: fade, lerp, grad are internal
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
    return a + t * (b - a)
end

local function grad(hash, x, y)
    local h = hash % 4
    local u = (h < 2) and x or -x
    local v = (h < 2) and ((h == 0) and y or -y) or ((h == 2) and y or -y)
    return u + v
end

function Perlin:new(seed)
    local self = setmetatable({}, Perlin)
    self.p = {}
    local t = {}
    for i = 0, 255 do t[i] = i end
    -- Generate a pseudo‑random shuffle using the seed (seed is a number)
    local h = math.abs(math.sin(seed * 127.1 + 311.7) * 43758.5453) % 1
    for i = 255, 1, -1 do
        h = (h * 16807) % 2147483647
        local j = math.floor(h) % (i + 1)
        t[i], t[j] = t[j], t[i]
    end
    for i = 0, 511 do self.p[i] = t[i % 256] end
    return self
end

function Perlin:fade(t)
    return fade(t)
end

function Perlin:lerp(t, a, b)
    return lerp(t, a, b)
end

function Perlin:grad(h, x, y)
    return grad(h, x, y)
end

function Perlin:noise(x, y)
    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    x = x - math.floor(x)
    y = y - math.floor(y)
    local u = self:fade(x)
    local v = self:fade(y)
    local A = self.p[X] + Y
    local AA = self.p[A]
    local AB = self.p[A + 1]
    local B = self.p[X + 1] + Y
    local BA = self.p[B]
    local BB = self.p[B + 1]
    return lerp(v,
        lerp(u, grad(AA, x, y), grad(BA, x - 1, y)),
        lerp(u, grad(AB, x, y - 1), grad(BB, x - 1, y - 1)))
end

function Perlin:noise2d(x, y)
    return (self:noise(x, y) + 1) / 2
end

return Perlin
