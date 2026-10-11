# Guía Maestra de Ajustes Visuales — Parallax y Cosmos Engine

> **Objetivo:** Guía práctica y directa para la fase de diseño estético. Explica exactamente dónde reemplazar o ajustar los **shaders de todas las capas**, sustituir y agregar **assets de planetas, lunas, estaciones y soles**, y usar las herramientas de depuración en caliente para iterar con máxima velocidad y cero fricción.

---

## 🗺️ 1. Mapa de Estratos, Shaders y Recursos de Datos

| Nivel | Estrato Visual | Nodo en Escena (`cosmos_root.tscn`) | Shader (`.gdshader`) | Recurso de Balance / Datos (`.tres`) |
|---|---|---|---|---|
| **Capa 1** | **Nebulosa Cósmica Profunda** | `ParallaxNebulaDeep/NebulaBackdrop` | [`universe_nebula.gdshader`](../../sandbox/shaders/universe_nebula.gdshader) | [`default_cosmic_biome.tres`](../../sandbox/resources/data/default_cosmic_biome.tres) |
| **Capa 2** | **Starfield 8K Óptico** | `ParallaxStarfield8K/StarfieldSprite` | [`deep_starfield.gdshader`](../../sandbox/shaders/deep_starfield.gdshader) | Configurado en `ShaderMaterial_starfield` |
| **Capa 3** | **Macro-Galaxias Ultra-Lentas** | `ParallaxMacroGalaxies/GalaxyStreamer2D` | Material estándar / CanvasItem | [`default_galaxy_landmark.tres`](../../sandbox/resources/data/default_galaxy_landmark.tres) |
| **Capa 4** | **Sistemas Solares y Soles** | `ParallaxSolarSystems/SolarSystemStreamer` | [`star_corona.gdshader`](../../sandbox/shaders/star_corona.gdshader)<br>[`star_light_field.gdshader`](../../sandbox/shaders/star_light_field.gdshader)<br>[`space_station_beacon.gdshader`](../../scenes/combat/environment/space_station_beacon.gdshader) | [`default_celestial_system.tres`](../../sandbox/resources/data/default_celestial_system.tres)<br>Carpeta: [`sandbox/resources/data/star_archetypes/`](../../sandbox/resources/data/star_archetypes) |
| **Capa 5** | **Cinturón de Escombros GPU** | `ParallaxDebrisBelt/DebrisStreamer2D` | [`debris_cutout.gdshader`](../../sandbox/shaders/debris_cutout.gdshader) | [`default_debris_layer.tres`](../../sandbox/resources/data/default_debris_layer.tres) |
| **Capa 6** | **Nave y Entidades (Gameplay)** | `GameplayWorld/PlayerVessel` | Shaders de Sandevistan y toberas | [`nova.tres`](../../data/characters/roster/nova.tres) |

---

## 🎨 2. Ajuste y Modificación de Shaders por Capa

### Capa 1: Nebulosa y Micro-Estrellas de Fondo ([`universe_nebula.gdshader`](../../sandbox/shaders/universe_nebula.gdshader))
* **Qué hace:** Dibuja el gas estelar procedural con FBM Simplex en GPU mezclado con texturas seamless de azulejo, más un lecho estelar ultra-lejano.
* **Uniforms clave que puedes ajustar:**
  * `biome_a_color_gas_primary` / `biome_a_color_gas_secondary`: Colores principales y de choque del gas nebular.
  * `biome_a_color_deep`: Tinte del vacío interestelar más oscuro.
  * `biome_a_density`: Opacidad general del gas estelar ($0.1 \to 3.0$, default `2.00` para garantizar visibilidad óptima en todos los biomas).
  * `biome_a_contrast`: Contraste de transiciones de densidad de gas ($0.5 \to 4.0$).
  * `biome_a_star_tint`: Tinte espectral de las micro-estrellas profundas asociado al bioma.
  * `flow_drift_speed`: Velocidad de corriente y deriva del gas con `TIME`.
  * `deep_stars_intensity` y `deep_stars_scale`: Brillo y escala de las micro-estrellas de 1-2px fijas al lecho profundo.
* **Catálogo de 6 Biomas Cósmicos Data-Driven:** Ubicados en [`sandbox/resources/data/biomes/`](../../sandbox/resources/data/biomes):
  1. [`biome_01_perseus_rift.tres`](../../sandbox/resources/data/biomes/biome_01_perseus_rift.tres) — **Grieta de Perseo** (Púrpura y turquesa cósmico).
  2. [`biome_02_hyperion_forge.tres`](../../sandbox/resources/data/biomes/biome_02_hyperion_forge.tres) — **Forja de Hiperión** (Ámbar incandescente, magma y oro solar).
  3. [`biome_03_carina_abyss.tres`](../../sandbox/resources/data/biomes/biome_03_carina_abyss.tres) — **Abismo de Carina** (Verde esmeralda y aguamarina cuántica).
  4. [`biome_04_crimson_veil.tres`](../../sandbox/resources/data/biomes/biome_04_crimson_veil.tres) — **Velo Carmesí** (Rubí sincrotrón, magenta y borravino).
  5. [`biome_05_silica_corona.tres`](../../sandbox/resources/data/biomes/biome_05_silica_corona.tres) — **Corona Silícea** (Zafiro glacial y plata perlada).
  6. [`biome_06_bootes_void.tres`](../../sandbox/resources/data/biomes/biome_06_bootes_void.tres) — **Vacío de Boötes** (Índigo sombrío sutil y alto contraste estelar).
* **Dónde editar los valores de diseño:** En cualquiera de los 6 recursos `.tres` o en los parámetros de shader de `ShaderMaterial_nebula` en [`cosmos_root.tscn`](../../sandbox/cosmos_root.tscn#L18).

---

### Capa 2: Starfield 8K Óptico en Paralaje ([`deep_starfield.gdshader`](../../sandbox/shaders/deep_starfield.gdshader))
* **Qué hace:** Muestrea la máscara estelar 8K pura descartando el fondo negro (`discard`) para que la nebulosa se vea perfectamente detrás, proyectando halos circulares suaves y espículas ópticas teñidas por canal espectral (R=cálidas, G=doradas, B=azules).
* **Uniforms clave:**
  * `threshold_cutoff`: Umbral de descarte de fragmentos negros (típico `0.02` a `0.05`).
  * `star_intensity`: Ganancia lumínica general (típico `2.0` a `3.0`).
  * `tint_red_star`, `tint_yellow_star`, `tint_blue_star`: Colores exactos para cada clase de estrella en la máscara 8K.
  * `twinkle_amount` y `twinkle_speed`: Intensidad y frecuencia del centelleo procedural.

---

### Capa 4: Shaders del Sistema Solar y Soles

#### A. Corona Solar y Plasma Convectivo ([`star_corona.gdshader`](../../sandbox/shaders/star_corona.gdshader))
* **Qué hace:** Se aplica a cada estrella central. Elimina el fondo negro cuadrado de los JPG mediante recorte radial suave (`smoothstep`), añade turbulencia de calor en tiempo real que hace hervir el disco estático, proyecta la corona respiratoria exterior e ilumina el núcleo central al blanco térmico.
* **Uniforms clave:**
  * `star_tint`: Color base de la estrella (proviene del recurso `StarArchetype`).
  * `heat_distortion_strength`: Intensidad de la ondulación térmica (ej. `0.035` a `0.065`).
  * `pulse_speed`: Velocidad de respiración y pulsación del plasma (ej. `1.0` a `2.2`).
  * `corona_intensity`: Brillo del halo exterior perimetral (ej. `0.8` a `1.2`).
  * `core_brightness`: Resplandor blanco térmico en el corazón del sol.
  * `black_threshold`: Corte de negros de la textura base (`0.04` a `0.08`).

#### B. Campo de Luz Orbital ([`star_light_field.gdshader`](../../sandbox/shaders/star_light_field.gdshader))
* **Qué hace:** Plano con mezcla aditiva (`blend_add`) que baña todo el sistema solar en el color de su estrella, atenuándose suavemente hacia el espacio interestelar.
* **Uniforms clave:**
  * `light_color`: Tinte lumínico (proyectado desde el sol).
  * `intensity`: Intensidad de luz difusa ambiental (ej. `0.25` a `0.40`).
  * `falloff_exponent`: Curva de caída de luz ($1.5$ a $2.2$).

#### C. Balizas de Estaciones Espaciales ([`space_station_beacon.gdshader`](../../scenes/combat/environment/space_station_beacon.gdshader))
* **Qué hace:** Luces estroboscópicas de advertencia aeronáutica que titilan en las puntas de las estaciones espaciales.
* **Uniforms clave:**
  * `beacon_intensity`: Intensidad lumínica de la baliza parpadeante.

---

### Capa 5: Restos y Escombros Espaciales ([`debris_cutout.gdshader`](../../sandbox/shaders/debris_cutout.gdshader))
* **Qué hace:** Gestiona 2000 fragmentos en 1 solo draw call de GPU (`MultiMeshInstance2D`).
* **Uniforms clave:**
  * `alpha_cutoff`: Descarte de bordes del atlas (típico `0.08`).
  * `drift_speed`: Velocidad de deriva espacial.
  * `spin_speed_mult`: Multiplicador de rotación angular aleatoria en GPU.

---

## 🪐 3. Cómo Agregar y Sustituir Assets

### A. Planetas Primarios
* **Archivo de configuración:** [`default_celestial_system.tres`](../../sandbox/resources/data/default_celestial_system.tres)
* **Propiedad a editar:** `planet_textures` (Array de `Texture2D`).
* **Formato recomendado:**
  * Archivos **PNG con canal alfa transparente**.
  * Resolución óptima: **256x256** o **512x512** píxeles.
  * La escala en pantalla se autocalibra al **75%** del rango (`0.375` a `0.825`) y el generador selecciona texturas determinísticamente con el hasher cósmico sin repeticiones inmediatas.
* **Para agregar más texturas:**
  1. Colocar las imágenes en `assets/environments/parallax_space/` (o subcarpeta designada).
  2. Abrir `default_celestial_system.tres` y agregar la referencia `ExtResource` al array `planet_textures`.

---

### B. Lunas (Reactivación y Nuevos Assets)
* **Archivo de configuración:** [`default_celestial_system.tres`](../../sandbox/resources/data/default_celestial_system.tres)
* **Para reactivar las lunas:**
  * Cambiar `moon_spawn_probability = 0.0` a un valor entre `0.5` y `0.85`.
* **Propiedad para texturas:** `moon_textures` (Array de `Texture2D`).
* **Propiedades de órbita:**
  * `moon_orbit_radius_range = Vector2(160.0, 280.0)` (distancia orbital respecto al planeta).
* **Formato recomendado:**
  * Texturas PNG transparentes de **64x64** a **128x128** píxeles (se escalan automáticamente con ratio compacto respecto a su planeta progenitor).

---

### C. Soles y Arquetipos Estelares
* **Carpeta de arquetipos:** [`sandbox/resources/data/star_archetypes/`](../../sandbox/resources/data/star_archetypes)
  * [`yellow_dwarf.tres`](../../sandbox/resources/data/star_archetypes/yellow_dwarf.tres) (Enana Amarilla)
  * [`blue_giant.tres`](../../sandbox/resources/data/star_archetypes/blue_giant.tres) (Gigante Azul)
  * [`red_dwarf.tres`](../../sandbox/resources/data/star_archetypes/red_dwarf.tres) (Enana Roja)
* **Variables editables por arquetipo:**
  * `star_textures`: Texturas de la estrella (admite JPG con fondo negro; el shader `star_corona` lo recorta automáticamente).
  * `star_core_radius`: Radio del disco interior (700px amarilla, 1000px azul, 520px roja).
  * `star_color`: Tinte espectral de emisión y luz ambiental.
  * `orbit_radius_min` / `orbit_radius_max`: Dominio orbital de los planetas para este sol.
  * `heat_distortion_strength` / `pulse_speed`: Parámetros del shader térmico.
  * `spawn_weight`: Probabilidad de selección en la ruleta ponderada.

---

### D. Estaciones Espaciales
* **Archivo de configuración:** [`default_celestial_system.tres`](../../sandbox/resources/data/default_celestial_system.tres)
* **Propiedad:** `space_station_textures` (Array de `Texture2D`).
* **Comportamiento automático:**
  * Mínimo 1 por planeta (`station_spawn_probability = 1.0`).
  * Escala automática calculada en código para medir **exactamente el 15% del diámetro del planeta**.
  * Órbita adaptativa a una distancia de **1.8x a 2.5x del radio del planeta** para que nunca se toquen.

---

## 🎛️ 4. Herramientas de Inspección y Live Debug en Runtime

Al ejecutar la escena demo de sandbox ([`sandbox/scenes/cosmos_engine_demo.tscn`](../../sandbox/scenes/cosmos_engine_demo.tscn)):

| Tecla / Control | Función en Runtime | Utilidad para el Ajuste Visual |
|---|---|---|
| **Tecla `F1`** | Abre/cierra el panel interactivo de telemetría y controles. | Permite ver coordenadas, FPS, memoria y origen flotante. |
| **Teclas `1`, `2`, `3`, `4`, `5`** | **Alterna (Toggle) cada estrato individualmente.** | **¡Clave!** Permite apagar todas las demás capas y dejar solo la que estés ajustando (ej. solo nebulosa o solo sistemas solares). |
| **Tecla `B`** | **Conmuta en caliente entre los 6 biomas espaciales.** | **¡Clave!** Cicla instantáneamente entre Perseo, Hiperión, Carina, Carmesí, Corona Silícea y Vacío de Boötes sin reiniciar la escena. |
| **Tecla `F2`** | Activa el Visual Debugger vectorial (Gizmos 2D). | Muestra los rectángulos del macro-grid, el frustum de cámara y las zonas de delimitación orbital. |
| **Rueda del Ratón** | Zoom elástico de cámara ($0.2\times$ a $2.0\times$). | Permite alejar la vista para apreciar la composición macro o acercarse a los detalles de los planetas. |
| **`W`, `A`, `S`, `D`** | Pilotaje inercial de la nave de prueba. | Navegar libremente entre cuadrantes para inspeccionar la transición entre sistemas estelares. |
| **`Shift`** | Sandevistan / Impulso temporal. | Desplazamiento ultra-rápido entre cuadrantes distantes. |

---

## 🧪 5. Comandos de Verificación Rápida (Sin gastar tokens)

Cada vez que modifiques un shader, textura o recurso `.tres`, ejecuta en terminal el comando específico correspondiente (tarda apenas 2-3 segundos):

| Si tocaste... | Ejecuta en terminal: |
|---|---|
| **Planetas, Soles, Lunas o Estaciones** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_solar_system.tscn"` |
| **Nebulosa o Biomas** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_environment_profile.tscn"` |
| **Galaxias de fondo** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_galaxy_streaming.tscn"` |
| **Verificación Integral de Todo el Cosmos** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/sandbox/test_cosmos_engine_integration.tscn"` |
