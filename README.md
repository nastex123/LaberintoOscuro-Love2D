# Luz en la Oscuridad — Exploración

Juego de exploración en laberintos generados proceduralmente hecho con Love2D.

---

## Cómo ejecutar

```bash
love .
```

O en Windows, doble clic en `run_game.bat`.

---

## Controles

| Tecla       | Acción                                    |
|-------------|-------------------------------------------|
| WASD / Flechas | Moverse                               |
| E           | Abrir cofre / Cerrar animación            |
| Espacio     | Atacar al Criker (si tienes un arma)      |
| Q           | Usar primer consumible del inventario     |
| F1          | Menú de configuración en tiempo real      |
| F2          | Editor de plantillas de salas             |
| R           | Regenerar el laberinto                    |
| R / Enter   | Reiniciar tras ganar o morir              |
| 1 / 2 / 3   | Reemplazar ítem al tener inventario lleno |
| Esc         | Descartar ítem nuevo en menú de reemplazo |

---

## Sistema de cofres

### Tipos de cofre

| Tipo       | Color grid | Cantidad por mundo | Contenido                     |
|------------|------------|-------------------|-------------------------------|
| Común      | Café       | 5–8               | 20 ítems comunes (todos con igual peso) |
| Épico      | Púrpura    | 2–3               | 20 ítems épicos               |
| Legendario | Dorado     | 1                 | 20 ítems legendarios           |
| Aleatorio  | Celeste    | 3–5               | Cualquier ítem de cualquier tier |

### Probabilidades del cofre aleatorio

| Tier       | Probabilidad |
|------------|-------------|
| Común      | 55%         |
| Épico      | 30%         |
| Legendario | 15%         |

### Apertura

- El jugador debe pararse sobre el cofre y presionar **E**.
- Aparece una animación de rueda horizontal con todos los ítems posibles del tier.
- Los ítems giran, deceleran y se detienen en el premio con efectos visuales.
- Si el inventario tiene menos de 3 ítems, se añade automáticamente.
- Si ya tienes 3, aparece un menú para reemplazar uno (1/2/3) o descartar (Esc).
- Presiona **E** nuevamente para cerrar la animación (cierre deslizante).

---

## Ítems (60 totales)

### Tipos de ítem

| Tipo        | Al recogerlo                              |
|-------------|-------------------------------------------|
| **weapon**  | Se equipa automáticamente, tiene usos     |
| **passive** | Efecto permanente inmediato               |
| **consumable** | De un solo uso (usables con Q)        |
| **utility** | Herramientas de mapa / información        |

### Comunes (20)

Antorcha (pasiva, +80px luz), Palo (arma, 3 golpes, aturde 3s), Poción de vida, Venda, Bengala, Cuerda (TP a sala segura), Piedra ruidosa, Trampa de pinchos, Yesca, Botas de fieltro (+15% vel), Tiza, Daga, Ración, Lentes de cerca, Látigo, Sal marina, Lupa, Pegamento, Vela, Cinta de señal.

### Épicos (20)

Brújula, Mapa, Capa de sigilo, Botas de velocidad (+40%), Señuelo, Honda (ranged, aturde 3s), Martillo, Escudo de madera (absorbe 1 golpe), Poción vigorizante, Linterna de minero, Mapa de tesoros, Garrote, Espantapájaros, Poción de fuego, Luz de hielo, Silbato de caza, Capa de camuflaje, Arco de caza (ranged), Poción de prisa, Cofre falso.

### Legendarios (20)

Espada, Arco largo (ranged), Amuleto de protección (absorbe 2), Esencia de la antorcha, Poción de la eternidad (3 vidas), Báculo de luz, Esfera de teletransporte, Armadura de diamante (absorbe 3), Espada de fuego, Lámpara de Aladino, Capa de las sombras, Sello de la luz (+400px), Poción de la salamandra, Martillo de guerra, Talismán de escape, Garras de dragón, Cristal de tiempo, Guante de poder, Capa de la tormenta, Cristal del vacío.

---

## Animación de cofre

- Rueda horizontal infinita con todos los ítems del tier.
- Al detenerse: destello de color según rareza, partículas estrella, confeti, latido del ítem, shader shine (barrido de luz).
- Cierre deslizante suave hacia abajo.
- Offset X ajustable desde el menú F1 (persistente en `ui_config.json`).

---

## Combate

- Presiona **Espacio** cuando el Criker esté cerca con un arma equipada.
- Cada arma tiene usos limitados y duración de aturdimiento distinta:
  - Comunes: Daga (1s), Látigo (2s), Palo (3s)
  - Épicas: Honda (3s, ranged), Martillo (4s), Garrote (4s)
  - Legendarias: Espada (5s), Espada de fuego (5s), Arco largo (6s, ranged), Garras (6s), Martillo de guerra (7s)
- Armas ranged (Honda, Arco de caza, Arco largo) atacan a 180px con línea de visión.
- Armas cuerpo a cuerpo atacan a 45px.
- Escudos absorben golpes del Criker antes de perder vidas:
  - Escudo de madera: 1 golpe
  - Amuleto de protección: 2 golpes
  - Armadura de diamante: 3 golpes
- Inmunidad temporal (Salamandra: 15s) evita todo daño.

---

## Inventario

- Máximo **3 ítems** simultáneos.
- Se muestra en la esquina inferior derecha con color y usos restantes (ordenado por nombre).
- Al abrir un cofre con el inventario lleno, aparece un menú para reemplazar o descartar.
- Los pasivos (Antorcha, Brújula, etc.) ocupan un slot pero dan efecto permanente.
- Si repites un arma, se suman los usos en vez de recargar gratis.

---

## Consumibles (tecla Q)

Los consumibles se usan presionando **Q**. Se consume el primer consumible disponible del inventario:

| Ítem | Efecto |
|------|--------|
| Poción de vida / Venda / Ración | Recupera 1 vida |
| Poción de la eternidad | Recupera las 3 vidas |
| Cuerda | Teletransporta a la Sala Segura |
| Talismán de escape | TP a Sala Segura + cura total |
| Esfera de teletransporte | Teletransporta a la salida |
| Báculo de luz | Crea luz estática permanente en el suelo |
| Bengala | +200px luz por 5s |
| Vela | +100px luz por 5s |
| Yesca | +80px luz por 8s |
| Piedra ruidosa | Atrae al Criker 3s |
| Señuelo | Atrae al Criker 5s |
| Trampa de pinchos | Aturde al Criker 2s si pisa |
| Cofre falso | Aturde al Criker 6s al llegar |
| Sal marina / Pegamento | Ralentiza al Criker 4s |
| Espantapájaros | El Criker huye 4s |
| Poción de fuego | Quema al Criker 2s |
| Capa de sigilo | Invisible 6s |
| Poción de la salamandra | Inmune 15s |
| Cristal de tiempo | Ralentiza Criker 80% (10s) |
| Poción vigorizante | +1 vida y +20% velocidad 10s |
| Poción de prisa | +60% velocidad 5s |
| Guante de poder | +100% velocidad 5s (3 usos) |
| Tiza / Cinta / Lentes | Marca el tile actual en el mapa |

---

## Efectos pasivos permanentes

| Ítem | Efecto |
|------|--------|
| Antorcha | +80px radio de luz |
| Botas de fieltro | +15% velocidad |
| Botas de velocidad | +40% velocidad |
| Linterna de minero | +150px luz |
| Esencia de la antorcha | +150px luz |
| Sello de la luz | +400px luz |
| Brújula | Muestra distancia a la salida |
| Lupa | Muestra distancia al parar |
| Escudo de madera | Absorbe 1 golpe |
| Amuleto de protección | Absorbe 2 golpes |
| Armadura de diamante | Absorbe 3 golpes |
| Capa de camuflaje | Criker detecta 40% menos |
| Luz de hielo | Ralentiza Criker 20% cerca |
| Cristal del vacío | Invisible permanentemente |
| Capa de las sombras | Invisible al Criker sin moverte |
| Mapa / Lámpara | Revela el laberinto / cofres |

---

## Enemigo: Criker

- Aparece cerca de la sala del tesoro (cofre legendario).
- Estados: patrulla → alerta → caza → búsqueda.
- Si te ve, te persigue. Si pierde el rastro, busca y vuelve a patrullar.
- No entra en zonas seguras (tiles con luz, valor 3 en grid).
- Respeta paredes en todos los estados (no atraviesa muros).
- **Interacciones con ítems del jugador:**
  - Sigilo / Capa de las sombras / Vacío: invisible al Criker.
  - Camuflaje: reduce radio de detección 40%.
  - Hielo: ralentiza al Criker 20% cuando estás cerca.
  - Piedra ruidosa / Señuelo: atrae al Criker (3–5s).
  - Espantapájaros: el Criker huye de ti (4s).
  - Sal marina / Pegamento: ralentiza 30% (4s).
  - Cristal de tiempo: ralentiza 80% (10s).
  - Poción de fuego: aturde 2s.
  - Trampa de pinchos / Cofre falso: aturden si pisa (2–6s).

---

## Editor de salas (F2)

- Crea y edita plantillas que pueden aparecer durante la generación.
- Brochas: Suelo, Pared, Luz, Salida, Cofre épico/común/legendario/aleatorio.
- Los caracteres en templates:
  - `.` Suelo
  - `#` Pared
  - `L` Luz (zona segura)
  - `X` Salida
  - `R` Cofre épico
  - `C` Cofre común
  - `G` Cofre legendario
  - `?` Cofre aleatorio
- Guardar con **S** (sobrescribe `room_templates.lua`).

---

## Conectividad del laberinto

- Tras la generación, `ensureConnectivity()` ejecuta un flood fill desde la sala inicial.
- Si alguna sala, salida o cofre queda aislado, se cava automáticamente un pasillo de emergencia hasta la zona conectada más cercana.
- El proceso se repite hasta 6 intentos para garantizar que todo sea accesible.
- También se aplica tras colocar cofres en `vault.lua`.

---

## Valores del grid

| Valor | Significado               | Color                   |
|-------|---------------------------|-------------------------|
| 0     | Suelo                     | `#0a0a0a`              |
| 1     | Pared                     | `#2d2d3a`              |
| 2     | Salida                    | `#ffdd00`              |
| 3     | Luz (zona segura)         | `#4488aa`              |
| 4     | Cofre común               | `#886644`              |
| 5     | Cofre épico               | `#8844aa`              |
| 6     | Cofre legendario          | `#ddaa00`              |
| 7     | Cofre aleatorio           | `#66ccff`              |

---

## Archivos del proyecto

| Archivo               | Propósito                                    |
|-----------------------|----------------------------------------------|
| `main.lua`            | Punto de entrada, input, renderizado, UI     |
| `maze.lua`            | Generación procedural del laberinto          |
| `player.lua`          | Jugador: movimiento, animación, dibujo       |
| `criker.lua`          | Enemigo: IA, estados, dibujo                |
| `items.lua`           | 60 definiciones de ítems e inventario        |
| `vault.lua`           | Sistema de cofres (colocación, apertura)     |
| `chest_animation.lua` | Animación de rueda con efectos visuales      |
| `debugInfo.lua`       | Overlay de depuración                        |
| `room_templates.lua`  | Plantillas de salas personalizadas           |
| `perlin.lua`          | Ruido Perlin para degradar paredes           |
| `json.lua`            | Decodificador JSON para configuración        |
| `shaders/`            | Shaders GLSL (light_falloff, shine, water1, splash1) |

---

## Configuración

Edita `maze_config.json` o usa el menú **F1** en tiempo real para ajustar:

- `cols`, `rows`: Dimensiones del laberinto
- `tile`: Tamaño de cada celda en píxeles
- `roomCount`: Rango de habitaciones
- `branchCount`, `branchLen`: Ramas desde las habitaciones
- `loopChance`: Probabilidad de crear lazos
- `perlinThresh`: Umbral de ruido Perlin para degradar paredes
- `seed`: Semilla determinista (omite para aleatorio)

---

## Sistema de agua (shaders)

### water1.glsl
Reemplaza la textura del agua con un shader pixelado estacionario en espacio mundo. Uniformes:
- `u_pixelCount` — grilla de píxeles (10–60)
- `u_waterSpeed` — velocidad de animación (0.05–2.0)
- `u_distortion` — intensidad de ondas (0.01–0.50)
- `u_waterScale` — zoom del patrón (0.2–3.0)

### splash1.glsl
Overlay additive con dos fases:
1. **Splash**: espuma blanca expandiéndose al entrar al agua (usa `u_splashScale`).
2. **Anillo**: anillo pulsante + 5 partículas orbitales alrededor del jugador, enmascarado por tiles de agua (usa `u_ringScale`).

### Orden de render
① waterMaskCanvas → ② sceneCanvas: agua + anillo → ③ jugador → ④ linterna (flashlight) → ⑤ splash de entrada.

### Parámetros del panel F1
| Sección | Parámetro       | Defecto | Rango     |
|---------|-----------------|---------|-----------|
| WATER   | Water PixelCount| 20      | 10–60     |
| WATER   | Water Speed     | 0.25    | 0.05–2.0  |
| WATER   | Water Distortion| 0.09    | 0.01–0.50 |
| WATER   | Water Scale     | 1.0x    | 0.2–3.0   |
| SPLASH  | Splash PixelCount | 30    | 10–80     |
| SPLASH  | Splash CenterSize | 0.04  | 0.01–0.20 |
| SPLASH  | Splash Duration | 1.0s    | 0.2–2.0   |
| SPLASH  | Splash Scale    | 1.0x    | 0.2–3.0   |
| RING    | Ring Radius     | 0.01    | 0.01–0.20 |
| RING    | Ring Speed      | 3.0     | 0.5–10.0  |
| RING    | Ring Scale      | 1.0x    | 0.2–3.0   |

Todos los parámetros se persisten a `ui_config.json`.

---

## Bugs corregidos

### Críticos (rompían el juego)

| # | Archivo | Bug | Fix |
|---|---------|-----|-----|
| 1 | `main.lua:11,293,560` | **TILE_SIZE hardcodeado a 28** — las luces estáticas se dibujaban en coordenadas equivocadas (el maze usa `maze.tile=75`). La luz amarilla de salida iluminaba un punto incorrecto del mundo. | Sustituir `TILE_SIZE` por `maze.tile` en los llamadas a `addLight`. Eliminar la constante obsoleta. |
| 2 | `vault.lua:76,108,117` | **`spawnRates` accedido con `[1]`/`[2]` pero las claves son `.min`/`.max`** — `Vault:placeAll` siempre crasheaba con `"bad argument #1 to 'random'"`. No se colocaban cofres nunca. | Cambiar `self.spawnRates.epic[1]` → `self.spawnRates.epic.min`, idem para `.max`. |
| 3 | `criker.lua:147-152,164-169` | **Criker atraviesa paredes en chase y search** — se movía directamente hacia el jugador sin verificar `maze:isWall()`, volando a través de muros. | Aplicar movimiento eje a eje (slide-axis): mover X e Y por separado descartando el eje que colisiona con pared. |
| 4 | `criker.lua:109-118` | **Criker empujado DENTRO de pared desde safe room** — el repel de la sala segura no verificaba colisión con muros. | Verificar `maze:isWall()` antes de cada componente del empuje. |

### Altos (comportamiento incorrecto visible)

| # | Archivo | Bug | Fix |
|---|---------|-----|-----|
| 5 | `main.lua:468` | **Stun hardcoded a 3s** — todas las armas aturdían 3 segundos ignorando `stunDuration` por arma (daga=1s, espada=5s, guerra=7s). | Usar `weapon.stunDuration` en vez de literal `3`. |
| 6 | `main.lua:465` | **Armas ranged sin rango** — Honda, Arco de caza y Arco largo exigían la misma distancia cuerpo a cuerpo (45px) que un Palo. | Armas ranged ahora usan 180px de alcance con línea de visión requerida. |
| 7 | `items.lua` / `main.lua` | **~45 de 60 ítems no funcionaban** — velocidad, escudos, luz, invisibilidad, teletransporte, consumibles: nada de esto tenía implementación. | Sistema completo de efectos: `Items.getSpeedMultiplier`, `Items.getLightRadius`, `Items.absorbHit`, `Items.isStealthed`, `Items.isImmune`, `Items.useConsumable` con contexto (heal, TP, dropLight, markTile). |
| 8 | `main.lua` (keypressed) | **Consumibles no se podían usar** — el README decía "Q" pero no existía handler. Los consumibles ocupaban slot pero eran inútiles. | Handler `key == "q"` que busca el primer consumible y llama a `Items.useConsumable` con `buildConsumableContext`. |
| 9 | `main.lua:693-695` | **3 ítems de luz sin efecto** — `linterna` (+150px), `esencia` (+150px), `sello` (+400px) no modificaban el radio de la linterna. Solo `antorch` funcionaba. | `Items.getLightRadius` suma todos los pasivos y temporales de luz. |
| 10 | `main.lua` (fonts) | **`newFont()` llamado ~20 veces por frame** — memory leak continuo: cada frame se creaban objetos Font que se descartaban, causando lag y presión al GC. | Tabla global `fonts` precargada una sola vez en `love.load` con todos los tamaños (12–36). Todas las llamadas reemplazadas. |

### Medios (lógica, edge cases)

| # | Archivo | Bug | Fix |
|---|---------|-----|-----|
| 11 | `player.lua:52-53` | **Movimiento diagonal ~1.41× más rápido** — input no normalizado: al pulsar 2 teclas la velocidad real era √2 × speed. | Normalizar vector de input: `if len > 1 then x = x/len; y = y/len end`. |
| 12 | `main.lua` (win/dead) | **No hay forma de reiniciar tras ganar/morir** — state="win"/"dead" mostraba texto estático. Solo R dentro de F1 regeneraba. Jugador bloqueado. | `R` o `Enter` llama a `resetGameState()` cuando state ≠ "play". |
| 13 | `main.lua` (F1) | **Acciones F1 funcionan estando muerto** — se podían abrir cofres de prueba tras morir. | Añadir `and state == "play"` al check de tier en el menú F1. |
| 14 | `main.lua:740` | **pendingItem se procesa tras game over** — si el jugador moría durante una animación de cofre, el ítem se procesaba después de morir. | Añadir `and state == "play"` al check post-animación. |
| 15 | `main.lua:619-622` | **crikerSpawnTimer nunca se resetea** — solo el primer spawn tenía delay de 1.5s. Si el criker volvía a inactivo, reaparecía instantáneo. | `crikerSpawnTimer = 0` ya estaba en `resetGameState()` (verificado). |
| 16 | `main.lua:868-881` | **HUD de inventario con `pairs()`** — orden no determinístico: los ítems parpadeaban/saltaban entre frames. | Usar `getInventorySlots` (sort por nombre) en vez de `pairs()`. |
| 17 | `main.lua:761-762` | **Danger border sin checar `criker.active`** — calculaba distancia con coordenadas residuales del Criker (0,0) cuando inactivo, potencial falso positivo. | Añadir `criker.active and` al check de distancia. |
| 18 | `items.lua:107,117` | **`getWeapon` y `useWeapon` duplicaban la lista de armas** — el mismo array hardcoded en dos sitios. Añadir arma exige tocar dos sitios. | Extraer `Items.weaponOrder` como tabla única compartida. |
| 19 | `items.lua:149-158` | **`Items.give` reinicia usos si repites arma** — si dos cofres daban palo, los usos se reseteaban gratis. | Si el arma ya existe, sumar usos: `inv.uses = inv.uses + def.maxUses`. |

### Bajos (render, cosmetic)

| # | Archivo | Bug | Fix |
|---|---------|-----|-----|
| 20 | `debug.lua` | **Archivo duplicado sin usar** — `debug.lua` es idéntico a `debugInfo.lua` pero nunca se requiere. | No eliminado (pendiente de limpieza futura). |

---

## Bugs pendientes por corregir

### Críticos

| # | Archivo:Línea | Bug | Descripción |
|---|---------------|-----|-------------|
| P1 | `maze.lua:99-100` | **`rand()` con rango invertido en mazes pequeños** | `love.math.random(margin, cols-margin-w-1)` crashea cuando `cols < 13+w` (ej: tipo B con w=9 necesita cols≥23). Con configs pequeñas, el juego no arranca. |
| P2 | `maze.lua:184` | **`rand(1, #rooms)` cuando rooms está vacío** | Si todas las habitaciones fallan al colocar (15 intentos), `rooms` queda vacío y `rand(1,0)` crashea. |
| P3 | `maze.lua` (main.lua:215) | **`maze:fillGrid()` no existe** | Los debug steps "grid" y "lights" llaman a `maze:fillGrid()` que no está definida en ningún sitio. Crashea al usar `--debugstep=grid`. |

### Altos

| # | Archivo:Línea | Bug | Descripción |
|---|---------------|-----|-------------|
| P4 | `main.lua:163-175` | **Args CLI mapean a claves equivocadas** | `--rooms` setea `config["rooms"]` pero maze lee `config["roomCount"]`. Lo mismo para `--branches`, `--branchlen`, `--loopchance`, `--perlin`. Silenciosamente ignorados. |
| P5 | `chest_animation.lua:111-112` | **`tierColors` en inglés pero `tierName` en español** | `tierColors["common"]` no existe porque `self.tierName` es `"Comun"`. El flash siempre es blanco, nunca muestra color de tier (gris/púrpura/dorado). |
| P6 | `chest_animation.lua:76-94` | **Animación trabada en `"spinning"` si targetItem no está en la rueda** | Si `forcedItemId` no coincide con ningún ítem del pool, `targetIdx` es nil y el state nunca sale de "spinning". La animación loop para siempre. |
| P7 | `maze.lua:113` | **`treasureRoom` sobreescrito** | Cada habitación F/G/H sobrescribe `self.treasureRoom`. Solo la última se trackea; las anteriores no se excluyen de candidatas a vault. |
| P8 | `maze.lua:475` | **Template 'L' sobrescribe `safeRoom`** | Si un template con 'L' se procesa después de tipo 'E', `self.safeRoom` cambia a la habitación del template. |
| P9 | `maze.lua:135-136` | **Inicio y salida pueden ser la misma habitación** | Con 1 sola habitación, `rooms[1] == rooms[#rooms]`, el jugador empieza y debe salir en el mismo punto. |
| P10 | `main.lua:114` | **`io.open` en vez de `love.filesystem.write`** | El editor de templates usa `io.open` que falla en plataformas sandboxed (HTML5, Android). |

### Medios

| # | Archivo:Línea | Bug | Descripción |
|---|---------------|-----|-------------|
| P11 | `main.lua:326+` | **`uiState` variable global no declarada** | Nunca se declaró con `local`, se filtra al namespace global. Funciona por accidente. |
| P12 | `main.lua:187+` | **11+ variables globales sin declarar** | `configRef`, `chestOffsetX`, `pendingItem`, `pendingTier`, `waitingForDecision`, `currentSeed`, `maze`, `player`, `criker` son globales implícitos. |
| P13 | `main.lua:498-507` | **UI puede crear rangos invertidos** | Si ajustas `roomCount[2]` por debajo de `roomCount[1]`, el rango queda invertido (ej: `{18, 6}`), causando crash en `love.math.random(18,6)`. |
| P14 | `main.lua:634-635` | **Cámara sin clamping a bordes del maze** | La cámara puede mostrar espacio vacío/negro más allá de los límites del grid. |
| P15 | `player.lua:67-79` | **`stretchX`/`stretchY` calculados pero nunca usados** | El squash-and-stretch se computa cada frame pero `draw()` lo ignora. Código muerto. |
| P16 | `criker.lua:115-116` | **Safe room repulsion sin `* dt`** | Movimiento a 2px/frame (frame-rate dependent): 120px/s@60fps, 60px/s@30fps. |
| P17 | `criker.lua:44` | **Global `player` referenciada sin parámetro** | `spawnValidated(maze)` accede al global `player` en vez de recibirlo como argumento. |
| P18 | `chest_animation.lua:8` | **Shader cargado sin `pcall` en require-time** | Si `shine.glsl` falla, el módulo entero no carga y el juego no arranca. |
| P19 | `maze.lua:658-674` | **LOS no verifica paredes diagonales** | El Criker puede "ver" al jugador entre esquinas diagonales de pared. |
| P20 | `debugInfo.lua:7` | **Sin nil guard en `criker`** | `Debug:draw` crashea si `criker` es nil. |

### Bajos / Cosmetic

| # | Archivo:Línea | Bug | Descripción |
|---|---------------|-----|-------------|
| P21 | `maze.lua:31` | **Campo muerto `self.spinePath`** | Declarado, nunca escrito ni leído. |
| P22 | `maze.lua:411-413` | **`carveRelicario` es un stub** | Tipo 'F' (Relicario) es idéntico a tipo 'A' (vacía). |
| P23 | `maze.lua:480-481` | **Borde doble de 2 celdas** | `degradeEdges` salta filas/columnas 1 y rows-2/cols-2, creando muro sólido de 2 celdas que aísla el borde. |
| P24 | `items.lua:22,24` | **`sal` y `pegamento` son duplicados** | Ambos ralentizan Criker 4s, sin código que los distinga. |
| P25 | `items.lua:56` | **ID `bculo` rompe convención** | Abreviatura truncada vs palabras completas en español para todos los demás ítems. |
| P26 | `chest_animation.lua:119-131` | **Confeti se congela en estado "done"** | Deja de caer y queda con alpha fijo hasta que se cierra el cofre. |
| P27 | `criker.lua:185` | **Variable `d` sombrea a `d` externa** | Peligro de mantenimiento: la `d` de dirección (tabla) sombrea la `d` de distancia (número). |
| P28 | `criker.lua:156-157,175-179` | **Código muerto en search/patrol** | Los checks de `canSee` dentro de las ramas son inalcanzables (ya se manejan antes). |
| P29 | `debug.lua` | **Archivo duplicado sin usar** | Nunca se requiere desde ningún sitio. |
| P30 | `room_templates.lua` | **Sin validación de forma rectangular** | Templates con filas de distinta longitud se aceptan silenciosamente. |
| P31 | `main.lua:693` | **`math.random()` en vez de `love.math.random()`** | El flicker de la linterna usa RNG separado; no es reproducible con semilla fija. |
| P32 | `main.lua:634-635` | **Cámara no arranca centrada** | Primer frame con "slide" desde (0,0) hasta la posición del jugador. |
| P33 | `perlin.lua` | **Grad solo usa 4 direcciones** | Perlin canónico usa 8/12 gradientes. Ruido con bandas visibles. |
| P34 | `json.lua` | **`parseNumber` acepta strings inválidos** | Regex `[-+%d.eE]+` acepta `1.2.3`. Falta patrón JSON estricto. |
| P35 | `shaders/shine.glsl` | **Uniform `u_color` no se usa** | Declarado pero nunca enviado ni utilizado en el shader. |
- `Offset X`: Ajuste de centrado de la animación del cofre (persistente)
