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
| Espacio     | Atacar al Criker (si tienes palo/espada)  |
| F1          | Menú de configuración en tiempo real      |
| F2          | Editor de plantillas de salas             |
| R           | Regenerar el laberinto (menú F1)          |

---

## Sistema de cofres

### Tipos de cofre

| Tipo       | Color grid | Cantidad por mundo | Contenido                     |
|------------|------------|-------------------|-------------------------------|
| Común      | Café       | 5–8               | Antorcha (50%), Palo (50%)    |
| Épico      | Púrpura    | 2–3               | Brújula (50%), Mapa (50%)     |
| Legendario | Dorado     | 1                 | Espada (100%)                 |
| Aleatorio  | Celeste    | 3–5               | Cualquier ítem de cualquier tier |

### Probabilidades del cofre aleatorio

Al abrir un cofre aleatorio, se tira primero el tier:

| Tier       | Probabilidad |
|------------|-------------|
| Común      | 55%         |
| Épico      | 30%         |
| Legendario | 15%         |

Luego se escoge un ítem dentro de ese tier según los pesos del pool.

### Apertura

- El jugador debe pararse sobre el cofre y presionar **E**.
- Aparece una animación de rueda horizontal.
- Los ítems giran horizontalmente y deceleran hasta detenerse en uno.
- Presiona **E** nuevamente para cerrar la animación.
- Una vez abierto, el cofre desaparece del mapa.

---

## Ítems

| Ítem      | Tier       | Efecto                                    |
|-----------|------------|-------------------------------------------|
| Antorcha  | Común      | Aumenta el radio de la linterna a 280px   |
| Palo      | Común      | 3 golpes, aturde al Criker 3s             |
| Brújula   | Épico      | Muestra la distancia a la salida en el HUD |
| Mapa      | Épico      | (efecto visual pendiente)                  |
| Espada    | Legendario | 5 golpes, aturde al Criker 3s             |

### Combate

- Si tienes **Palo** o **Espada**, presiona **Espacio** cuando el Criker esté cerca.
- El Criker queda aturdido 3 segundos (color azul).
- El arma pierde un uso; al llegar a 0 se rompe y desaparece del inventario.

---

## Enemigo: Criker

- Aparece cerca de la sala del tesoro (cofre legendario).
- Estados: patrulla → alerta → caza → búsqueda.
- Si te ve, te persigue. Si pierde el rastro, busca y vuelve a patrullar.
- No entra en zonas seguras (tiles con luz, valor 3 en grid).

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

## Tareas realizadas

- [x] Generación procedural de laberintos (Perlin + rooms + spine + branches + loops)
- [x] Editor de plantillas de salas (F2) con soporte de ratón
- [x] Sistema de iluminación con shader GLSL (linterna + luces estáticas)
- [x] Enemigo Criker con IA (patrulla, alerta, caza, búsqueda)
- [x] Importación de salas procedurales A–H a `room_templates.lua`
- [x] Reconocimiento de salas segura/salida/tesoro en templates
- [x] Soporte de ratón en el editor (click, arrastrar)
- [x] Sistema de ítems (5 tipos con pools y pesos)
- [x] Sistema de cofres (4 tiers: común, épico, legendario, aleatorio)
- [x] Animación de rueda horizontal al abrir cofres
- [x] Combate cuerpo a cuerpo (aturde al Criker con armas)
- [x] Efecto de antorcha (aumenta radio de luz)
- [x] Brújula (distancia a salida en HUD)
- [x] Inventario visible en HUD (esquina superior derecha)

## Tareas pendientes / por pulir

- [ ] **Mapa**: Implementar efecto visual (minimapa o tile reveal)
- [ ] **Sonido**: Efectos de paso, apertura de cofre, ataque, etc.
- [ ] **Múltiples cofres legendarios**: Permitir más de 1 por mundo en salas grandes
- [ ] **Mejorar la detección de "zona segura"**: Que el Criker no pueda entrar en salas con cofres abiertos
- [ ] **Persistencia**: Guardar progreso (ítems recogidos, cofres abiertos)
- [ ] **UI/UX pulido**: Tooltips en ítems, feedback visual al golpear
- [ ] **Optimización**: El escaneo de tiles para cofres en pasillos podría ser más eficiente
- [ ] **Más variedad de ítems**: Pociones, llaves, trampas
- [ ] **Música ambiental** y efectos de sonido

---

## Archivos del proyecto

| Archivo               | Propósito                                    |
|-----------------------|----------------------------------------------|
| `main.lua`            | Punto de entrada, input, renderizado, UI     |
| `maze.lua`            | Generación procedural del laberinto          |
| `player.lua`          | Jugador: movimiento, animación, dibujo       |
| `criker.lua`          | Enemigo: IA, estados, dibujo                |
| `items.lua`           | Definiciones de ítems e inventario           |
| `vault.lua`           | Sistema de cofres (colocación, apertura)     |
| `chest_animation.lua` | Animación de rueda horizontal                |
| `debugInfo.lua`       | Overlay de depuración                        |
| `room_templates.lua`  | Plantillas de salas personalizadas           |
| `perlin.lua`          | Ruido Perlin para degradar paredes           |
| `json.lua`            | Decodificador JSON para configuración        |
| `shaders/`            | Shaders GLSL para iluminación               |
| `maze_config.json`    | Configuración por defecto del laberinto      |

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
