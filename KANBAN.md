# 📋 Kanban — Tareas Pendientes

---

## 🔴 CRÍTICOS (Bloquean ejecución / crashean)

| ID | Tarea | Archivo | Est. |
|----|-------|---------|------|
| P1 | `rand()` rango invertido en mazes pequeños — crashea si `cols < 23` | `maze.lua:99-100` | 30m |
| P2 | `rand(1, 0)` cuando no hay habitaciones colocadas | `maze.lua:184` | 20m |
| P3 | `maze:fillGrid()` no existe — debug steps "grid"/"lights" crashean | `maze.lua` | 30m |

---

## 🟠 ALTOS (Comportamiento roto)

| ID | Tarea | Archivo | Est. |
|----|-------|---------|------|
| P4 | CLI args (`--rooms`, `--branches`, etc.) mapean a claves equivocadas, se ignoran | `main.lua:163-175` | 20m |
| P5 | `tierColors` en inglés pero `tierName` en español — flash siempre blanco | `chest_animation.lua:111-112` | 15m |
| P6 | Animación trabada en `"spinning"` si `targetItem` no está en la rueda | `chest_animation.lua:76-94` | 30m |
| P7 | `treasureRoom` sobrescrito por cada F/G/H — solo la última se trackea | `maze.lua:113` | 20m |
| P8 | Template 'L' sobrescribe `self.safeRoom` silenciosamente | `maze.lua:475` | 15m |
| P9 | Inicio y salida pueden ser la misma habitación (`#rooms == 1`) | `maze.lua:135-136` | 15m |
| P10 | `io.open` en vez de `love.filesystem.write` — falla en Android/HTML5 | `main.lua:114` | 20m |

---

## 🟡 MEDIOS (Lógica, edge cases)

| ID | Tarea | Archivo | Est. |
|----|-------|---------|------|
| P11 | `uiState` variable global no declarada con `local` | `main.lua:326+` | 5m |
| P12 | 11+ variables globales implícitas (`configRef`, `maze`, `player`...) | `main.lua:187+` | 30m |
| P13 | UI puede crear rangos invertidos (`roomCount = {18, 6}`) | `main.lua:498-507` | 20m |
| P14 | Cámara sin clamping — muestra espacio vacío en bordes | `main.lua:634-635` | 20m |
| P15 | `stretchX`/`stretchY` calculados pero nunca usados en `draw()` | `player.lua:67-79` | 15m |
| P16 | Safe room repulsion sin `* dt` (frame-rate dependent) | `criker.lua:115-116` | 10m |
| P17 | `spawnValidated` accede global `player` sin parámetro | `criker.lua:44` | 10m |
| P18 | Shader shine cargado sin `pcall` en require-time | `chest_animation.lua:8` | 15m |
| P19 | LOS no verifica paredes diagonales | `maze.lua:658-674` | 45m |
| P20 | Sin nil guard en `Debug:draw` para criker | `debugInfo.lua:7` | 5m |

---

## 🟢 BAJOS / COSMÉTICOS (Limpieza)

| ID | Tarea | Archivo | Est. |
|----|-------|---------|------|
| P21 | Campo muerto `self.spinePath` | `maze.lua:31` | 2m |
| P22 | `carveRelicario` es un stub (tipo F = tipo A) | `maze.lua:411-413` | 30m |
| P23 | Borde doble de 2 celdas (degradeEdges salta filas 1/rows-2) | `maze.lua:480-481` | 20m |
| P24 | `sal` y `pegamento` son ítems duplicados | `items.lua:22,24` | 10m |
| P25 | ID `bculo` rompe convención de nombres | `items.lua:56` | 5m |
| P26 | Confeti se congela en estado "done" | `chest_animation.lua:119-131` | 20m |
| P27 | Variable `d` sombrea a `d` externa en patrol | `criker.lua:185` | 5m |
| P28 | Código muerto `canSee` en search/patrol | `criker.lua:156-157,175-179` | 10m |
| P29 | `debug.lua` duplicado sin usar | — | 2m |
| P30 | Sin validación de forma rectangular en templates | `room_templates.lua` | 20m |
| P31 | `math.random()` en vez de `love.math.random()` en flicker | `main.lua:693` | 5m |
| P32 | Cámara no arranca centrada (slide desde 0,0) | `main.lua:634-635` | 10m |
| P33 | Perlin: solo 4 gradientes (bandas visibles) | `perlin.lua` | 45m |
| P34 | JSON parser acepta strings inválidos (`1.2.3`) | `json.lua` | 30m |
| P35 | Uniform `u_color` no usado en shine.glsl | `shaders/shine.glsl` | 5m |

---

## 🎯 Sprint Recomendado (5-6 horas)

### Bloque 1: Críticos + Altos rápidos (~2h)

```
P1 → P2 → P3 → P5 → P10 → P4
```

**Por qué este orden:** P1-P3 son los que crashean el juego. P5 y P10 son fixes de 1 línea que tocan archivos que ya modificamos. P4 es importante para testing automatizado.

### Bloque 2: Medios de alto impacto (~1h 45m)

```
P12 → P14 → P16 → P18 → P19
```

**Por qué:** P12 limpia la arquitectura (reduce bugs futuros). P14 y P16 mejoran la experiencia visual y la consistencia del Criker. P18 evita que un shader roto impida arrancar. P19 mejora la fairness de la IA.

### Bloque 3: Quick wins + 1 medio (~1h 15m)

```
P11 → P20 → P21 → P25 → P27 → P28 → P29 → P31 → P32 → P35 → P23 → P30
```

**Por qué:** Todos son fixes de <10 min. Agrupados para maximizar throughput. P23 y P30 quedan al final porque requieren un poco más de testing.

### Bloque 4: Dejar para otro día

| ID | Razón |
|----|-------|
| P6 | Requiere testing visual de la animación completa |
| P7, P8, P9 | Tocan lógica de generación de habitaciones — alto riesgo de romper algo |
| P13, P15 | Testing visual de UI/player |
| P22, P24, P26 | Testing de juego completo |
| P33, P34 | Refactors mayores (Perlin, JSON) |

---

## 📊 Resumen Estimado

| Bloque | Tiempo | Items |
|--------|--------|-------|
| Críticos + Altos rápidos | 2h 00m | 6 |
| Medios alto impacto | 1h 45m | 5 |
| Quick wins | 1h 15m | 12 |
| **Total Sprint** | **5h 00m** | **23** |
| Pendiente para otro día | — | 12 |

---

## ✅ Completados

| ID | Tarea | Commit |
|----|-------|--------|
| G1 | TILE_SIZE → maze.tile | `e24d836` |
| G2 | Criker respeta paredes | `f42b1e2` |
| G3 | Sistema de efectos + Q + rango/stun | `cee6812` |
| G4 | Font cache (newFont por frame) | `78982fb` |
| G5 | Reinicio, diagonal, HUD sort, guards | `2fbfbfd` |
| P1 | rand() rango invertido en mazes pequenos | `663e934` |
| P2 | rand(1,0) cuando rooms vacio | `663e934` |
| P3 | maze:fillGrid() inexistente | `663e934` |
| P4 | CLI args mapean a claves equivocadas | `64a2769` |
| P5 | tierColors ingles vs espanol en flash | `64a2769` |
| P10 | io.open vs love.filesystem.write | `64a2769` |
