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
| F1          | Menú de configuración en tiempo real      |
| F2          | Editor de plantillas de salas             |
| R           | Regenerar el laberinto (menú F1)          |
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
- Cada arma tiene usos limitados y duración de aturdimiento distinta.
- Armas ranged (Honda, Arco de caza, Arco largo) pueden aturdir a distancia.
- Las armas se priorizan por rareza (legendaria > épica > común).
- Escudos absorben golpes del Criker antes de perder vidas.

---

## Inventario

- Máximo **3 ítems** simultáneos.
- Se muestra en la esquina inferior derecha con color y usos restantes.
- Al abrir un cofre con el inventario lleno, aparece un menú para reemplazar o descartar.
- Los pasivos (Antorcha, Brújula, etc.) ocupan un slot pero dan efecto permanente.

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
| `shaders/`            | Shaders GLSL (light_falloff, shine)          |

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
- `Offset X`: Ajuste de centrado de la animación del cofre (persistente)
