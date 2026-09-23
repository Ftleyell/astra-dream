# Guía de Especificaciones Técnicas: Stage 2 — Entornos, Parallax y Hangar 3D

**Proyecto:** Astra: Dream  
**Módulo:** Stage 2 (Espacio Exterior Parallax, Superficies del Hangar y Máquinas HUD 3D)  
**Destinatario:** Equipo de Arte 2D / Background & Environment Artists  
**Versión:** 2.0  

---

## 1. Visión General del Stage 2

El Stage 2 abarca todo el arte ambiental para el **Hangar Espacial 3D (Nuevo Menú Principal)** y la vista al espacio profundo a través del **Gran Ventanal Panorámico**.

El pipeline seleccionado es **Estilizado Psycho-Pop / Cyberpunk Anime**:
- **Texturas Albedo (Color Difuso):** Ilustración base con paleta contrastada sci-fi.
- **Mapas de Emisión (Emission Masks):** Texturas blanco/negro o coloreadas que definen exactamente qué partes brillan en la oscuridad con el post-procesado `WorldEnvironment Glow` (luces neón cian `#00F0FF`, rosa caliente `#FF1493`, ámbar dorado `#FFB703` y verde biomasa `#00FF9D`).

---

## 2. Especificación de Archivos a Pintar

### Grupo A: Parallax del Espacio Exterior (`space_parallax/`)
Situado detrás del ventanal panorámico a distintas profundidades en el eje Z.

| Archivo | Resolución | Canal Alfa | Descripción y Contenido |
| :--- | :--- | :--- | :--- |
| `space_parallax_layer0_deep.png` | `3840 x 2160` (4K) | No (Opaco) | **Capa Profunda (Z = -85m):** Vacío cósmico, nebulosas violeta/magenta envolventes y brillo tenue de galaxias lejanas. |
| `space_parallax_layer1_mid.png` | `2048 x 2048` | **SÍ (Transparente)** | **Capa Media (Z = -45m):** Planeta colosal o luna tecnológica visible en uno de los cuadrantes, anillos estelares y campo de estrellas nítidas (1 a 4 px). |
| `space_parallax_layer2_near.png` | `2048 x 1080` | **SÍ (Transparente)** | **Capa Cercana (Z = -22m):** Polvo cósmico, partículas brillantes, micro-meteoritos y baliza satelital parpadeante. |

---

### Grupo B: Superficies del Hangar 3D (`hub_surfaces/`)
Superficies interiores con repetición de textura (Tiling UV).

| Archivo | Resolución | Tipo | Reglas de Arte |
| :--- | :--- | :--- | :--- |
| `hangar_floor_albedo.png` | `1024 x 1024` | Albedo | Baldosas metálicas sci-fi, líneas de carril de aterrizaje, marcas de desgaste. **Debe ser seamless / repetible en X e Y**. |
| `hangar_floor_emission.png` | `1024 x 1024` | Emisión | Franjas neón cian (`#00F0FF`) y marcas de suelo bioluminiscentes verdes (`#00FF9D`). Fondo negro puro (`#000000`). |
| `hangar_wall_albedo.png` | `2048 x 1024` | Albedo | Paneles de hangar blindado, rejillas de ventilación, tuberías y compuertas. **Seamless horizontal (eje X)**. |
| `hangar_wall_emission.png` | `2048 x 1024` | Emisión | Tiras LED cian, luces de advertencia y circuitos de energía. Fondo negro puro. |
| `hangar_ceiling_albedo.png` | `1024 x 1024` | Albedo | Vigas estructurales, conductos de refrigeración y soportes metálicos oscuros. **Seamless en X e Y**. |
| `hangar_ceiling_emission.png` | `1024 x 1024` | Emisión | Barras de luz cenital blanca/azulada suave. |
| `hangar_railing_albedo.png` | `1024 x 512` | Albedo | Barandilla perimetral de seguridad frente al ventanal con franjas diagonales de advertencia (amarillo/negro o cian/negro). |
| `hangar_railing_emission.png` | `1024 x 512` | Emisión | Barra luminosa superior de advertencia en cian neón. |

---

### Grupo C: Máquinas y Consolas Interactivas (`hub_machines/`)

| Archivo | Resolución | Tipo | Contenido Visual |
| :--- | :--- | :--- | :--- |
| `terminal_mission_albedo.png` | `1024 x 1024` | Albedo | Consola de despacho táctico, botoneras, teclado táctil futurista y carcasa metálica. |
| `terminal_mission_emission.png` | `1024 x 1024` | Emisión | Gráficos de mapa de radar, texto holográfico y luces de estado en magenta neón (`#FF1493`) y cian. |
| `arcade_cabinet_albedo.png` | `1024 x 1024` | Albedo | Chasis de máquina recreativa estilo arcade retro-futurista, arte lateral (side art con naves/estrellas) y marquesina. |
| `arcade_cabinet_emission.png` | `1024 x 1024` | Emisión | Marquesina iluminada ("ASTRA // TOP 10"), neones dorados/ámbar (`#FFB703`) y botones brillantes. |
| `arcade_screen_albedo.png` | `512 x 512` | Albedo | Vidrio de monitor CRT retro con líneas de barrido sutiles y marco de alta puntuación. |
| `arcade_screen_emission.png` | `512 x 512` | Emisión | Tablero de récord con texto fosforescente ámbar y destellos en amarillo/oro. |

---

## 3. Paleta Cromática Guía (Psycho-Pop)

| Tono | Hexadecimal | Uso Recomendado |
| :--- | :--- | :--- |
| **Deep Void** | `#080A12` / `#0E121E` | Metal base de paredes, suelo y chasis |
| **Neon Cyan** | `#00F0FF` | Luces de hangar, suelo táctico, terminal de misiones |
| **Hot Pink** | `#FF1493` | Acentos de hologramas, radares y contraste |
| **Gold Amber** | `#FFB703` | Arcade de Récords, marquesina y estrellas |
| **Biomass Green** | `#00FF9D` | Circuitos orgánicos, marcas de energía |

---

## 4. Instrucciones de Entrega
1. No alterar las resoluciones ni los nombres de archivo para garantizar que el motor los cargue automáticamente sin requerir reprogramación.
2. Guardar en formato **PNG de 24 bits (o 32 bits con canal Alfa en las capas transparentes)**.
3. Asegurarse de que en los mapas `_emission.png` las partes que NO deben brillar sean **negro absoluto (`#000000`)**.
