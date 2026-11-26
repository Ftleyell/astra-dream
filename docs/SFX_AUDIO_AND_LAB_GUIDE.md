# Sistema de Audio v2, SfxLab & Librería Compartida — Stela Galactica

> **Guía unificada para colaboradores y agentes IA.**
> Explica cómo explorar, elegir, combinar, reemplazar y exportar efectos de sonido en **`SfxLab`**, qué hace cada uno de los **32 slots**, y dónde debe editar un agente IA para ajustar balance, buses o presets sin tocar código de juego innecesariamente.

---

## 1. Quickstart para Colaboradores (Elegir, Probar y Cambiar SFX en 3 Minutos)

No necesitás descargar packs externos: la librería curada (**699 audios** en OGG alta calidad) ya viene versionada dentro del repo en `sandbox/workbenches/sfx_lab/packs/` (aislada del build final mediante `.gdignore`).

### Cómo abrir `SfxLab`
1. Abrí el proyecto en **Godot 4.7.2**.
2. Ejecutá `sandbox/workbenches/sfx_lab/sfx_lab.tscn` directamente (`F6`), o abrí el Hub de Workbenches (`sandbox/workbenches/workbench_hub.tscn`) y hacé clic en **`[0] SFX Lab`**.
3. Al abrirse, `SfxLab` carga automáticamente `sandbox/workbenches/sfx_lab/packs/` y aplica por defecto el preset **`1. Stela Signature`** (con los 32 slots listos para probar, **sin sobrescribir producción** hasta que exportes).

### Controles y flujo paso a paso
1. **Elegir Preset base (barra superior):**
   * **`1. Stela Signature`**: híbrido equilibrado anime + cósmico (disparos cristalinos, UI holográfica, cortes energía, Ults/Bosses con Capa 2).
   * **`2. Anime Sakuga`**: transientes ultra rápidos y agudos estilo combate *sakuga*.
   * **`3. Cyberpunk`**: UI mecánica/glitch + railguns metálicos y sintetizados.
   * **`4. Cosmos`**: peso cinematográfico espacial, bajos profundos y atmósferas largas.
   * **`5. Zen`**: anti-fatiga para sesiones largas (picos suaves, clicks orgánicos, mínimo desgaste auditivo).
   * **`☆ Custom`**: tu propio preset guardado localmente con **`★ Guardar Custom`**.
2. **Escuchar todo el preset rápidamente:**
   * Pulsá **`▶ Tour (9 clave)`** para recorrer automáticamente los 9 sonidos representativos (UI, armas, explosión, EXP, nivel, bomb, pasos). **`■ Stop [S]`** corta en cualquier momento.
   * O movete directamente con **`↓` / `↑`** en la **Columna 1 (`1. SLOTS DEL PRESET`)**: cada slot reproduce al instante su sonido asignado (`[Main]` + `Capa 2`).
3. **Comparar Nuevo vs Producción Actual (A/B):**
   * **`[Space]` (`▶ Nuevo`)**: repite el sonido del preset o archivo seleccionado con su `Pitch Preview` y `Gain Offset`.
   * **`[A]` (`▶ Prod Actual`)**: reproduce lo que suena actualmente en el juego (`AudioManager`).
   * **`[R]` (`▶ Ráfaga`)** y **`▶ Combo EXP`**: simulan disparos continuos a la cadencia real del arma (con pitch jitter) o el arpegio ascendente de EXP.
4. **Reemplazar un sonido puntual:**
   * Seleccioná el slot en **Columna 1** (ej. `weapon_blade`).
   * En **Columna 2 (`2. REEMPLAZAR SONIDO DE [slot]`)**, usá los chips de palabras clave o el buscador, o filtrá por pack (`Shapeforms`, `SCI-FI_UI_SFX_PACK`, `kenney_sci-fi-sounds`, `Sonniss_Curated`).
   * Hacé **doble clic** o apretá **`[Enter]`** (`Reemplazar Main [Enter]`) para cambiar el sonido principal `[Main]` de ese slot, **`+ Variante`** para sumar variación aleatoria `_v2`..`_v5`, o **`+Capa 2`** para añadir una capa de peso/brillo simultánea.
5. **Aplicar al juego real y probar in-game:**
   * En **Columna 3**, pulsá **`Exportar Slot`** (solo el slot actual) o **`Exportar Todos Staged → assets/audio/sfx/`** (normaliza todos los slots con FFmpeg a WAV PCM 16-bit `-1 dBFS`, respaldando los anteriores en `user://`).
   * **Nota de exportación:** Requiere tener `ffmpeg` y `python` disponibles en `PATH` (o instalados por WinGet) para ejecutar `tools/normalize_sfx.py`. Al terminar la exportación en `SfxLab`, el juego lee automáticamente los nuevos archivos en `assets/audio/sfx/` y `assets/audio/ambience/`.
   * Pulsá **`Combat Gym`** en la barra superior para probar las armas y combates reales con los sonidos recién exportados.

---

## 2. Arquitectura de AudioManager v2 (Producción)

El servicio global `AudioManager` (`core/autoloads/audio_manager.gd`) usa una arquitectura data-driven modularizada:

| Módulo / Recurso | Ruta | Responsabilidad |
|---|---|---|
| **Orquestador Global** | `core/autoloads/audio_manager.gd` | Pools de reproducción (`24` voces 2D + `12` voces paneables `AudioStreamPlayer2D`), anti-fatiga, combo pentatónico EXP y despacho por `SfxCueBank`. |
| **DTO por Cue** | `core/audio/sfx_cue_data.gd` | Resource `SfxCueData`: `bus_name`, `priority`, `streams`, `secondary_layer_*`, `base_volume_db`, `pitch_min/max`, `min_interval_ms`, `max_polyphony`, `density_attenuation_db`, `duck_combat_db`, `allow_panning`. |
| **Banco Maestro** | `data/audio/default_sfx_cue_bank.tres` | `SfxCueBank` con los cues cargados, aliases retrocompatibles (`exp_pickup → exp`, `laser_fire → laser`, `bomb_explode → bomb`) y pistas `ambience_tracks`. |
| **Director DSP** | `core/audio/audio_mix_director.gd` | LowPass suave al pausar (`Music` / `Ambience`), enfoque táctico en modales (`set_tactical_focus`), slow-motion y ducking reactivo sobre `SFX_Combat`. |
| **Control de Densidad** | `core/audio/sfx_density_tracker.gd` | Ventana temporal anti-fatiga que atenúa progresivamente cues repetidos en ráfaga. |
| **Crossfade Ambiental** | `core/audio/ambience_crossfade_controller.gd` | Doble reproductor en `Ambience` con crossfade suave (`set_ambience(&"cosmos" | &"hub" | &"title" | &"off")`). |
| **Layout de Buses** | `default_bus_layout.tres` | 7 buses jerárquicos: `Master`, `Music`, `SFX` → (`SFX_Combat`, `SFX_Heroic`, `SFX_UI`), `Ambience`. |
| **Familias de Armas** | `data/weapons/**/*.tres` | Cada `WeaponData` declara su `sfx_key` hacia una de las 7 familias sonoras de armas. |

---

## 3. Guía para Agentes IA ("Qué cambiar → Archivo exacto")

Si un colaborador le pide a su agente IA ajustar cómo suena un efecto, cambiar la intensidad en combate, mover un arma de familia o reemplazar un archivo, el agente **debe ir directo al archivo indicado aquí**:

| Pedido del colaborador | Dónde actuar | Detalles clave |
|---|---|---|
| *"Quiero probar otro sonido en el slot X o armar un mix distinto"* | `sandbox/workbenches/sfx_lab/curated_presets.json` o `SfxLab` UI | Editar JSON (rutas relativas a `sandbox/workbenches/sfx_lab/packs/`) o exportar WAVs con `tools/normalize_sfx.py`. |
| *"El disparo láser está muy fuerte / repetitivo / agudo"* | `data/audio/default_sfx_cue_bank.tres` | Ajustar `base_volume_db`, `pitch_min`/`pitch_max`, `min_interval_ms`, `max_polyphony` o `density_attenuation_db` en el `SfxCueData` de `laser` o `weapon_laser` **(nunca hardcodear en `.gd`)**. |
| *"Esta arma debería sonar como escopeta / vacío / espada"* | `data/weapons/<categoria>/<arma>.tres` | Cambiar `sfx_key` a una de las 7 familias: `weapon_laser`, `weapon_railgun`, `weapon_shotgun`, `weapon_missile`, `weapon_blade`, `weapon_tesla`, `weapon_void`. |
| *"El menú o la bomba no apagan lo suficiente el ruido de fondo"* | `core/audio/audio_mix_director.gd` o `default_sfx_cue_bank.tres` (`duck_combat_db`) | Ajustar constantes `FOCUS_COMBAT_*` o el ducking por cue crítico (`bomb`, `player_hit`, `level_up`, `warning`). |
| *"Agregué un WAV `_v3` o `_layer2` en `assets/audio/sfx/`"* | `core/audio/sfx_cue_bank.gd` + `data/audio/default_sfx_cue_bank.tres` | Ejecutar `SfxCueBank.rebuild_and_save_default_bank()` o asignar el nuevo `AudioStream` en `default_sfx_cue_bank.tres`. |
| *"Reemplazar un slot desde consola sin abrir Godot"* | `tools/normalize_sfx.py` | Ver sección **Pipeline CLI** abajo. |

### Contratos de código obligatorios
1. **Firma de reproducción:**
   ```gdscript
   AudioManager.play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0)
   AudioManager.play_sfx_at(sfx_name: String, world_pos: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0)
   ```
   **¡Crítico!** `pitch_scale` siempre es el **2.º parámetro** y `volume_db` el **3.º** (nunca invertirlos).
2. **Enfriamiento en UI:** Llamar `AudioManager.set_tactical_focus(true/false)` al abrir/cerrar overlays de combate para bajar `SFX_Combat` sin atenuar `SFX_UI`.
3. **Cero BOM UTF-8:** Si un agente modifica `.tres` o `.gd` desde PowerShell 5.1, jamás usar `Set-Content -Encoding UTF8` (escribe BOM UTF-8 y rompe el parser de Godot); usar edición directa o Python con `encoding="utf-8"`.
4. **Cero `.import` en librería fuente:** `sandbox/workbenches/sfx_lab/packs/.gdignore` debe existir siempre.

---

## 4. Catálogo Completo de los 32 Slots SFX (`SfxLabCatalog`)

### 4.1. Cues Base Activos en `AudioManager` (11)
| Slot Key | Archivo Destino (`assets/audio/sfx/`) | Categoría | Bus / Notas |
|---|---|---|---|
| `laser` | `laser_fire.wav` | Combat | `SFX_Combat` · Disparo láser estándar / fallback |
| `missile` | `missile_fire.wav` | Combat | `SFX_Combat` · Lanzamiento de cohetes/misiles |
| `explosion` | `explosion.wav` | Combat | `SFX_Combat` · Muerte de enemigos (`CROWD`, variantes `_v2.._v3`) |
| `bomb` | `bomb.wav` (+ `_layer2.wav`) | Combat | `SFX_Heroic` · Ultimate `[Q]`, detonación masiva, ducking alto |
| `player_hit` | `player_hit.wav` | Combat | `SFX_Heroic` · Daño al piloto (`CRITICAL`, ducking) |
| `dash` | `dash.wav` | Combat | `SFX_Heroic` · Blink / Sandevistan |
| `exp` | `exp_pickup.wav` | Pickups | `SFX_UI` · `use_exp_combo = true` (escala pentatónica ascendente) |
| `heal` | `heal.wav` | Pickups | `SFX_Heroic` · Curación y escudo |
| `magnet` | `magnet.wav` | Pickups | `SFX_Heroic` · Imán de campo |
| `ui_click` | `ui_click.wav` | UI | `SFX_UI` · Confirmación estándar de botones |
| `hub_footstep` | `hub_footstep.wav` | Hub | `SFX_Combat` · Pasos sobre Estación Astral 3D |

### 4.2. Cues Extendidos Invocados en Código (12)
| Slot Key | Archivo Destino (`assets/audio/sfx/`) | Categoría | Uso |
|---|---|---|---|
| `ui_hover` | `ui_hover.wav` | UI | Micro-tick al pasar cursor / foco |
| `ui_error` | `ui_error.wav` | UI | Bloqueo / recursos insuficientes |
| `menu_open` | `menu_open.wav` | UI | Apertura de modales y hangar |
| `level_up` | `level_up.wav` (+ `_layer2.wav`) | Pickups | Subida de nivel y Arcana / Dark Matter |
| `upgrade_obtained` | `upgrade_obtained.wav` | Pickups | Recompensa / mejora adquirida |
| `item_pickup` | `item_pickup.wav` | Pickups | Loot e ítems en arena |
| `warning` | `warning.wav` (+ `_layer2.wav`) | Combat | Alerta de Boss / Rival |
| `laser_heavy` | `laser_heavy.wav` (+ `_layer2.wav`) | Combat | Láser pesado / desgarro |
| `impact` | `impact.wav` | Combat | Colisiones físicas / monolitos |
| `hit_bullet` | `hit_bullet.wav` | Combat | Impacto rápido / ricochet |
| `satellite_plant` | `satellite_plant.wav` | Hub | Despliegue/anclaje de satélite |
| `satellite_activate` | `satellite_activate.wav` | Hub | Activación de baliza / Gacha modal |

### 4.3. Las 7 Familias Sonoras de Armas (`WeaponData.sfx_key`)
| Slot Key | Archivo Destino (`assets/audio/sfx/`) | Armas Asociadas |
|---|---|---|
| `weapon_laser` | `weapon_laser.wav` | Scatter Laser, Tachyon Beam, Solar Beam |
| `weapon_railgun` | `weapon_railgun.wav` (+ `_layer2.wav`) | Rail Launcher, Sniper Rifle |
| `weapon_shotgun` | `weapon_shotgun.wav` | Titan Shotgun, Plasma Flak, Nova Flak |
| `weapon_missile` | `weapon_missile.wav` | Swarm Missiles, Hive Cannon, Cluster |
| `weapon_blade` | `weapon_blade.wav` | Crescent Blade, Dimensional Blade |
| `weapon_tesla` | `weapon_tesla.wav` | Tesla Arc |
| `weapon_void` | `weapon_void.wav` (+ `_layer2.wav`) | Singularity Cannon/Pulsar, Void Siphon, Solar Flare |

### 4.4. Camas Atmosféricas (`assets/audio/ambience/`)
| Slot Key | Archivo Destino | Uso |
|---|---|---|
| `ambience_cosmos` | `ambience_cosmos.wav` (o `.ogg`) | Fondo etéreo continuo en Combate y Título |
| `ambience_hub` | `ambience_hub.wav` (o `.ogg`) | Room tone limpio de hangar/estación en Hub 3D |

---

## 5. Pipeline CLI (`tools/normalize_sfx.py`)

Cualquier colaborador o agente IA puede normalizar un archivo de `sandbox/workbenches/sfx_lab/packs/` directo a producción sin distorsión ni silencio inicial:

```powershell
python tools/normalize_sfx.py `
  --input "sandbox/workbenches/sfx_lab/packs/Shapeforms/Sci-Fi Weapons/LASRGun_Classic Blaster A Fire_03.ogg" `
  --output "assets/audio/sfx/weapon_laser.wav" `
  --gain-db 0.0 `
  --target-peak-db -1.0 `
  --trim-silence `
  --mono `
  --sample-rate 44100
```

* Usar `--stereo` en lugar de `--mono` para slots atmosféricos o heroicos (`bomb`, `ambience_*`, `weapon_void`, `level_up`).
* Convención de variantes: archivo principal `<file_base>.wav`, variantes aleatorias `<file_base>_v2.wav`..`_v5.wav` y capa 2 simultánea `<file_base>_layer2.wav`.

---

## 6. Verificación Automatizada

Ejecutar después de cualquier cambio de SFX, `.tres` o scripts de audio:

```powershell
# 1. Laboratorio SfxLab, decodificador nativo WAV y presets
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_sfx_lab" -TimeoutSeconds 35

# 2. AudioManager v2 (7 buses, anti-fatiga, layering, Ambience crossfade)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_audio_manager_v2" -TimeoutSeconds 30

# 3. Anti-fatiga EXP y polifonía
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_audio_anti_fatigue" -TimeoutSeconds 30

# 4. Slider Ambiente y configuración de audio en Pausa
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_pause_audio" -TimeoutSeconds 30
```
