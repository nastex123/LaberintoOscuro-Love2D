# AGENTS.md – Quick guide for OpenCode agents

## How to run the game
- **Windows**: double‑click `run_game.bat` or run `C:\Program Files\LOVE\love.exe .` from the repository root (`.../Love2D/perlin`).
- **Any platform** with Love2D installed: execute `love .` inside the repository folder.
- The project has **no build step** – Love2D loads the Lua files directly.

## Project entry point
- `main.lua` is the Love2D entry point. All other modules (`maze.lua`, `player.lua`, `criker.lua`, `debugInfo.lua`) are required from there.

## Light system (important for editors)
- The shader used by default is `shaders/light_falloff.glsl`. It expects the following uniforms:
  - `lightPos` (vec2) – screen coordinates of the light source.
  - `radius`   (float) – radius of the light.
  - `lightColor` (vec3) – RGB color of the light.
  - `falloff` (float) – exponent controlling attenuation (default = 2).
- Static lights are stored in the global table `lights` (declared in `main.lua`). Add a new static light with:
  ```lua
  addLight(x, y, radius, {r,g,b}, falloff)
  ```
  where `x` and `y` are world coordinates (in pixels).
- The player's flashlight is added automatically each frame (white color).

## Adding/Modifying shaders
1. Place the `.glsl` file in the `shaders/` directory.
2. If you replace the default, edit `loadShaders()` in `main.lua` to load the new file and update `shaderNames`.
3. Ensure the shader defines the same uniforms as above; otherwise `shader:send` calls will error.

## Debug overlay
- `debugInfo.lua` draws a top‑right overlay with maze state, player distance, lives, etc.
- To disable it, comment out (or delete) the line `Debug:draw(maze, player, criker, lives, camera)` in `love.draw`.

## Common pitfalls
- **Do not** run `lua main.lua`; Love2D must be the runtime (`love .`).
- The batch file assumes Love2D is installed at `C:\Program Files\LOVE\love.exe`. Adjust the path if installed elsewhere.
- Changing shaders or light parameters requires restarting the game (or re‑loading the scene) to see updates.
- The `lights` table must be populated **after** the maze is created (i.e., after `player:setPos`). Adding lights before that results in `nil` coordinates.

## Quick commands for agents
- **Run the game**: `run_game.bat` or `love .`
- **Refresh after code change**: just restart the process; Love2D reloads all modules.
- **Add a static green safe‑room light** (already present):
  ```lua
  addLight(maze.safeRoom.cx * TILE_SIZE, maze.safeRoom.cy * TILE_SIZE,
           180, {0,1,0}, 2)
  ```
- **Add a static yellow exit light** (already present):
  ```lua
  addLight(maze.exitCell.x * TILE_SIZE, maze.exitCell.y * TILE_SIZE,
           120, {1,0.9,0}, 2)
  ```

---
*This file is intentionally concise; any deeper workflow (e.g., CI, packaging) is not present in this repository.*
