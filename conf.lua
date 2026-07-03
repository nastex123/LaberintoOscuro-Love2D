-- conf.lua – Love2D configuration (mobile + desktop)

function love.conf(t)
    t.identity = "luz_en_la_oscuridad"
    t.version = "11.5"

    t.window.title = "Luz en la Oscuridad"
    t.window.width = 0              -- auto-detect from device
    t.window.height = 0
    t.window.fullscreen = true
    t.window.borderless = true
    t.window.resizable = false
    t.window.usedpiscale = true
    t.window.vsync = 1

    -- Modules
    t.modules.touch = true
    t.modules.joystick = false
    t.modules.mouse = true
    t.modules.keyboard = true
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.math = true
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.window = true
end
