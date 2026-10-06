# Plan de Generación y Procesado de Iconos de Kits de Pilotos (Fase 1)

> **Objetivo:** Generar los 28 iconos correspondientes a los kits de las 7 heroínas de *Astra Dream* (Arma Base, Click Táctico, Dash Shift y Pasiva de Conversión de Tomos) gastando únicamente **2 imágenes en Gemini** mediante grillas 4x4 sobre fondo Chroma Key Magenta (`#FF00FF`), procesándolas con un script Python con *autocrop* y *despill*. Además, se deja trazado el mapa para las fases futuras (Items, Tomos y Arcanas).

---

## 1. Arquitectura de Distribución (Fase 1: Pilotos)

Cada imagen contendrá una grilla **4x4 (16 celdas cuadradas 1:1)** con marcos HUD oscuros tecnológicos sci-fi, fondo magenta `#FF00FF` entre celdas y en márgenes, y perspectiva diagonal dinámica.

### Resumen de las 7 Pilotos y sus Habilidades

| Piloto | Color Temático | Arma Base | Click Táctico | Dash (Shift) | Pasiva / Tomo Favorecido |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Nova** | Naranja Neón (`#FF660D`) | Riel Magnético Dual | Láser Focalizado de Vanguardia | Omega Spin (Giro 360°) | Sobrecarga de Vanguardia (`tome_move_speed`) |
| **Valentina** | Azul Cobalto (`#2E73E6`) | Cañón Francotirador Perforante | Matriz de Puntería Óptica | Repliegue Táctico | Balística de Alta Celeridad (`tome_projectile_speed`) |
| **Roxy** | Rojo Carmesí (`#E62438`) | Escopeta de Dispersión Titánica | Barrera de Choque Térmico | Embestida Blindada | Coraza Balística Pesada (`tome_armor`) |
| **Selene** | Índigo/Púrpura (`#5940BF`) | Sifón Gravitatorio de Vacío | Micro-Horizonte de Sucesos | Pliegue Espacial (Teleport) | Atracción Singular (`tome_pickup_radius`) |
| **Nyx** | Violeta Oscuro (`#9933E0`) | Hojas de Fractura Dimensional | Desfase Abisal (Intangible) | Paso de Sombras (Corte Dash) | Pacto de Sangre y Cenizas (`tome_curse`) |
| **Echo** | Cian Eléctrico (`#1FD9F2`) | Bobina Tesla Voltaica | Pulso EMP Sistémico | Destello Cibernético | Bucle de Frecuencia Acelerada (`tome_cooldown_reduction`) |
| **Kira** | Amarillo (`#F2C71F`) | Enjambre Biomórfico | Colmena de Nanobots | Desprendimiento Celular | Replicación Azarosa (`tome_luck`) |

---

## 2. Grilla 1: Armas Base & Clicks Tácticos (16 Celdas)

* **Fondo exterior y separadores:** Magenta puro `#FF00FF`.
* **Marco interior:** Marco cuadrado HUD futurista oscuro con esquinas reforzadas y micro-circuitos que complementan el color de cada habilidad.
* **Orientación:** Diagonal dinámica 3/4 (de abajo-izquierda hacia arriba-derecha).

### Prompt Maestro para Gemini (Grilla 1)

```text
A 4x4 grid of exactly 16 perfectly square sci-fi weapon and tactical ability icons for a video game, displayed on a solid, pure magenta chromakey background (hex #FF00FF) visible between and around the squares. The entire image has a square (1:1) aspect ratio. NO TEXT, no letters, no numbers, no labels, no watermark anywhere.
Each of the 16 squares has its own distinct, high-quality dark futuristic frame with tech borders, glowing sci-fi interface elements, and cybernetic HUD patterns, highly contrasting with the bright magenta chromakey background that separates them.
Inside each of the 16 squares is a highly detailed, 2D futuristic sci-fi game icon with dynamic glowing energy, particle effects, and sparks. Crucially, EVERY icon element is positioned DIAGONALLY (oriented from bottom-left to top-right) to fully fill and showcase its square. Rich hand-drawn digital game art style with vibrant colors and cinematic lighting.

THE 16 CELLS CONTAIN (from top-left to bottom-right):
[Row 1: Primary Weapons 1-4]
1. Nova's Dual Magnetic Rail: A twin-barrel heavy electromagnetic railgun firing parallel high-speed glowing orange kinetic slugs and plasma sparks.
2. Valentina's Armor-Piercing Sniper: An ultra-long sleek futuristic anti-materiel sniper rifle with a glowing cobalt blue barrel and supersonic muzzle wave.
3. Roxy's Titan Spread Shotgun: A heavy industrial quadrupled-barrel combat shotgun discharging a wide cone of fiery crimson buckshot and incendiary embers.
4. Selene's Void Gravity Siphon: A dark cosmic void cannon channeling a swirling deep purple and indigo gravitational micro-singularity vortex at the tip.

[Row 2: Primary Weapons 5-7 + Tactical Ability 1]
5. Nyx's Dimensional Fracture Blades: A pair of ethereal dual vibro-blades crackling with sharp dark violet dimensional rift energy and spatial tears.
6. Echo's Voltaic Tesla Coil: An advanced high-voltage directed energy projector releasing crackling bright cyan electric lightning arcs and plasma sparks.
7. Kira's Biomorphic Swarm Launcher: An organic-cybernetic bio-missile pod firing a cluster of self-guided amber and golden bio-chemical micro-missiles.
8. Nova's Vanguard Focused Laser: A high-intensity concentrated orange-yellow prismatic laser beam charging up and burning through atmospheric dust.

[Row 3: Tactical Abilities 2-5]
9. Valentina's Optical Targeting Matrix: A holographic cobalt blue crosshair reticle projecting a laser trajectory lock with telemetry HUD brackets.
10. Roxy's Thermal Shock Barrier: A reinforced heavy hexagonal thermal energy riot shield glowing vibrant crimson and reflecting incoming bullet sparks.
11. Selene's Micro Event Horizon: A localized gravitational distortion sphere trapping purple celestial starlight and warping surrounding space.
12. Nyx's Abyssal Phase: A phantom silhouette fading into an ethereal violet void smoke, leaving ripples of invulnerable dark matter.

[Row 4: Tactical Abilities 6-7 + 2 Bonus Wildcards]
13. Echo's Systemic EMP Pulse: An expanding shockwave ring of bright cyan electromagnetic pulse disruption with shattered digital interference nodes.
14. Kira's Nanobot Hive: A deployed swarm canister releasing a dense cloud of microscopic golden predatory nanobots devouring energy.
15. Bonus Wildcard - Overdrive Matrix: A radiant golden and prismatic energy core discharging emergency boost particles.
16. Bonus Wildcard - Void Beacon: An ominous dark cosmic monolith pulsating with ultraviolet tachyon radiation.

Consistent viewpoint, game UI/UX ability icon style, vibrant sci-fi visual effects, no perspective distortions, no merging between cells. All 16 icons are unique and perfectly aligned in a 4x4 square matrix. Keep all icon UI completely free of text overlay, labels, or numbering.
```

---

## 3. Grilla 2: Dashes (Shift) & Pasivas de Conversión de Tomos (16 Celdas)

### Prompt Maestro para Gemini (Grilla 2)

```text
A 4x4 grid of exactly 16 perfectly square sci-fi mobility dash and passive synergy ability icons for a video game, displayed on a solid, pure magenta chromakey background (hex #FF00FF) visible between and around the squares. The entire image has a square (1:1) aspect ratio. NO TEXT, no letters, no numbers, no labels, no watermark anywhere.
Each of the 16 squares has its own distinct, high-quality dark futuristic frame with tech borders, glowing sci-fi interface elements, and cybernetic HUD patterns, highly contrasting with the bright magenta chromakey background that separates them.
Inside each of the 16 squares is a highly detailed, 2D futuristic sci-fi game icon with dynamic glowing energy, particle effects, motion trails, and sparks. Crucially, EVERY icon element is positioned DIAGONALLY (oriented from bottom-left to top-right) to convey speed, kinetic thrust, and cosmic power. Rich hand-drawn digital game art style with vibrant colors and cinematic lighting.

THE 16 CELLS CONTAIN (from top-left to bottom-right):
[Row 1: Dash & Mobility 1-4]
1. Nova's Omega Spin: A circular 360-degree kinetic slash vortex trail with brilliant glowing orange afterimages cutting through air.
2. Valentina's Tactical Evasion: A swift backward vector thruster booster with aerodynamic cobalt blue speed trails and recoil sparks.
3. Roxy's Armored Bull-Rush: A heavy juggernaut forward ramming shield cone surrounded by explosive crimson shockwave rings and cracked air.
4. Selene's Space Fold: A quantum wormhole portal folding space, leaving twin spiral rings of indigo cosmic stardust and dark energy ripples.

[Row 2: Dash & Mobility 5-7 + Passive Synergy 1]
5. Nyx's Shadowstep: A razor-sharp linear dash cut through space leaving a trailing blade wake of dark violet rift cuts and afterimages.
6. Echo's Cybernetic Flash: A lightning-fast zigzag electrostatic teleport streak with cyan circuit sparks and lingering voltaic terminals.
7. Kira's Cellular Decoy: An organic speed boost leaving behind a glowing amber bio-matter cellular decoy husk.
8. Nova's Vanguard Overload (Speed Synergy): An overheating orange thruster core overflowing with raw kinetic energy and flaming acceleration arrows.

[Row 3: Passive Synergies 2-5]
9. Valentina's High-Velocity Ballistics (Proj Speed Synergy): A supersonic bullet accelerating through multiple concentric cobalt blue acceleration rings.
10. Roxy's Heavy Ballistic Plating (Armor Synergy): A layered ultra-dense tungsten armor plate deflecting fiery crimson sparks and converting kinetic impact.
11. Selene's Singular Attraction (Magnet Synergy): A miniature black hole gravity magnet pulling dense indigo star-fragments and floating astral matter.
12. Nyx's Blood and Ash Pact (Curse Synergy): A menacing occult dark violet rune skull inscribed with forbidden crimson-violet sacrificial sigils.

[Row 4: Passive Synergies 6-7 + 2 Bonus Wildcards]
13. Echo's Accelerated Frequency Loop (Cooldown Synergy): A digital infinity symbol made of pulsating bright cyan frequency waves and clockwork circuitry.
14. Kira's Random Replication (Luck Synergy): A cybernetic golden bio-die roll splitting into twin golden clone cells surrounded by four-leaf quantum clovers.
15. Bonus Wildcard - Chrono Acceleration: A warped holographic sci-fi stopwatch surrounded by turquoise speed lines and temporal sparks.
16. Bonus Wildcard - Core Synthesis: An intricate multi-layered hexagonal tech matrix fusing elemental energy cores into a single nexus.

Consistent viewpoint, game UI/UX ability icon style, vibrant sci-fi visual effects, no perspective distortions, no merging between cells. All 16 icons are unique and perfectly aligned in a 4x4 square matrix. Keep all icon UI completely free of text overlay, labels, or numbering.
```

---

## 4. Estructura de Exportación de Archivos

Los iconos procesados se organizarán de forma limpia en [`assets/characters/skills/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/assets/characters/skills/):

```text
assets/characters/skills/
├── weapons/
│   ├── icon_weapon_nova.png
│   ├── icon_weapon_valentina.png
│   ├── icon_weapon_roxy.png
│   ├── icon_weapon_selene.png
│   ├── icon_weapon_nyx.png
│   ├── icon_weapon_echo.png
│   └── icon_weapon_kira.png
├── tacticals/
│   ├── icon_tactical_nova.png
│   ├── icon_tactical_valentina.png
│   ├── icon_tactical_roxy.png
│   ├── icon_tactical_selene.png
│   ├── icon_tactical_nyx.png
│   ├── icon_tactical_echo.png
│   └── icon_tactical_kira.png
├── dashes/
│   ├── icon_dash_nova.png
│   ├── icon_dash_valentina.png
│   ├── icon_dash_roxy.png
│   ├── icon_dash_selene.png
│   ├── icon_dash_nyx.png
│   ├── icon_dash_echo.png
│   └── icon_dash_kira.png
└── passives/
    ├── icon_passive_nova.png
    ├── icon_passive_valentina.png
    ├── icon_passive_roxy.png
    ├── icon_passive_selene.png
    ├── icon_passive_nyx.png
    ├── icon_passive_echo.png
    └── icon_passive_kira.png
```

*(Los comodines 15 y 16 de cada grilla se exportarán a `assets/icons/misc/` para uso general).*

---

## 5. Script Python Automatizado (`tools/process_pilot_skill_grids.py`)

Se creará una herramienta específica basada en `Pillow`:
1. Toma las 2 imágenes generadas (ej. `grid_pilot_skills_1.png` y `grid_pilot_skills_2.png`).
2. Divide la matriz en 16 celdas exactas según coordenadas relativas.
3. Realiza la máscara croma para descartar el fondo `#FF00FF` sobrante alrededor del marco.
4. Aplica *despill* y recorte ajustado (*autocrop* al marco HUD).
5. Normaliza y redimensiona a 256x256 (y miniatura 128x128 para HUD).
6. Renombra y guarda cada archivo según el mapa de celdas configurado.

---

## 6. Planificación de Fases Futuras (Ahorro de Cuota Gemini)

* **Fase 2: Tomos del Códice (18 Tomos):**
  * Se generarán con **1 o 2 Grillas 4x4** (o 1 Grilla 4x5) con diseño de orbes / pergaminos holográficos tecnológicos.
* **Fase 3: Items de Tienda y Cofres (40-50 Items):**
  * Divididos en **3 Grillas 4x4 temáticas** (Ofensivos / Defensivos / Utilitarios y Pasivos).
* **Fase 4: Arcanas y Pactos (24 Arcanas):**
  * Agrupadas en **2 Grillas 4x4 (16 + 8 con 8 comodines de élite)** con estética de cartas del tarot cósmico oscuro / runas abisales.
