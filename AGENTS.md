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

## Water shader system (animated pixel water)
- `shaders/water1.glsl` replaces the water texture with a world‑space stationary pixel shader. Uniforms:
  - `u_resolution`, `u_camera` (vec2) – screen size & camera offset.
  - `u_pixelCount` (float) – number of pixels in the grid (10–60).
  - `u_waterSpeed` (float) – animation speed (0.05–2.0).
  - `u_distortion` (float) – wave distortion intensity (0.01–0.50).
  - `u_waterScale` (float) – pattern zoom scale (0.2–3.0).
- `shaders/splash1.glsl` is an additive overlay with two phases:
  1. **Splash explosion** – expanding white foam at the entry point (uses `u_splashProgress`, `u_splashWorld`, `u_splashPixelCount`, `u_splashCenterRadius`, `u_splashScale`).
  2. **Ring** – pulsating ring + 5 orbiting particles around the player, gated by the water mask (`u_inWater`, `u_ringBaseRadius`, `u_ringPulseSpeed`, `u_ringScale`, `u_waterMask`).
- **Render order**: ① water mask canvas built → ② maze water + ring shader pass in sceneCanvas → ③ player on top → ④ flashlight → ⑤ splash explosion pass.
- **Water mask** (`waterMaskCanvas`): white rectangles over visible water tiles, sampled by splash shader at `pixcoord / u_resolution` to gate the ring.

## F1 panel water/splash/ring parameters
| Section  | Parameter            | Default | Range     | Step |
|----------|----------------------|---------|-----------|------|
| WATER    | Water PixelCount     | 20      | 10–60     | 1    |
| WATER    | Water Speed          | 0.25    | 0.05–2.0  | 0.05 |
| WATER    | Water Distortion     | 0.09    | 0.01–0.50 | 0.01 |
| WATER    | Water Scale          | 1.0x    | 0.2–3.0   | 0.1  |
| SPLASH   | Splash PixelCount    | 30      | 10–80     | 1    |
| SPLASH   | Splash CenterSize    | 0.04    | 0.01–0.20 | 0.01 |
| SPLASH   | Splash Duration      | 1.0s    | 0.2–2.0   | 0.05 |
| SPLASH   | Splash Scale         | 1.0x    | 0.2–3.0   | 0.1  |
| RING     | Ring Radius          | 0.01    | 0.01–0.20 | 0.01 |
| RING     | Ring Speed           | 3.0     | 0.5–10.0  | 0.5  |
| RING     | Ring Scale           | 1.0x    | 0.2–3.0   | 0.1  |

- All parameters are persisted to `ui_config.json`.

## Adding/Modifying shaders
1. Place the `.glsl` file in the `shaders/` directory.
2. If you replace the default, edit `loadShaders()` in `main.lua` to load the new file and update `shaderNames`.
3. Ensure the shader defines all required uniforms (see sections above); otherwise `shader:send` calls will error.

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
