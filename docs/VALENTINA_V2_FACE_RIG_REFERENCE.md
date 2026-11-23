# Referencia Técnica — Rig Facial Vivo Independiente (Valentina v2 `face_lab/`)

> **Escena del Laboratorio:** [`valentina_face_lab.tscn`](../sandbox/pilot_rig_lab/face_lab/valentina_face_lab.tscn)
> **Fuente de Verdad del Rig de Cuerpo:** [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md)
> **Suite de Verificación:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_face_lab"`

---

## 1. Propósito y Aislamiento Arquitectónico

`face_lab/` implementa un **rig facial autónomo** para calibrar, animar y depurar todas las capas vivas de las 8 cabezas de Valentina v2 sin acoplar ni alterar el estado purgado de `PlanarCombatRig` (`planar_combat_rig_proto.tscn` / `planar_anim_test.tscn`).

| Módulo | Responsabilidad | Archivo |
|---|---|---|
| **Escena + Orquestador Lab** | Modos `Hero Close-Up` vs `Galería 8-Dir`, cámara zoom/paneo, atajos, `WorldEnvironment` (AgX) | [`valentina_face_lab.tscn`](../sandbox/pilot_rig_lab/face_lab/valentina_face_lab.tscn) + [`valentina_face_lab.gd`](../sandbox/pilot_rig_lab/face_lab/valentina_face_lab.gd) |
| **Rig Facial Runtime** | Monta `UnifiedCharacterGroup` (`HeadUnderMount` Pass 1 + `TorsoRefMount` + `HeadOverMount` Pass 2), enlaza máscaras vivas y aplica uniformes | [`valentina_face_rig.gd`](../sandbox/pilot_rig_lab/face_lab/valentina_face_rig.gd) |
| **Evaluador Procedural** | Parpadeo orgánico, eye-tracking/sacadas, 6 presets + lip-sync, cabeceo cervical, parallax 2.5D, 3 resortes de cabello y monóculo | [`valentina_face_animator.gd`](../sandbox/pilot_rig_lab/face_lab/valentina_face_animator.gd) |
| **HUD del Laboratorio** | Panel lateral en 4 pestañas (`1. Ojos`, `2. 2.5D`, `3. Pelo`, `4. Vista`) con guardado directo a `.tres` | [`valentina_face_lab_hud.gd`](../sandbox/pilot_rig_lab/face_lab/valentina_face_lab_hud.gd) |
| **Configuración Data-Driven** | Esquema `@export` y recurso calibrado de parámetros faciales | [`pilot_face_anim_config.gd`](../sandbox/pilot_rig_lab/data/pilot_face_anim_config.gd) → [`valentina_v2_face_anim.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_face_anim.tres) |
| **Shader Modular Opt-In** | Funciones GLSL puras para soldadura cervical, ojos/párpados/boca, monóculo HUD y rayos-X `7..8` | [`rig_face_live.gdshaderinc`](../sandbox/pilot_rig_lab/shaders/rig_face_live.gdshaderinc) + [`pilot_rig_stylizer.gdshader`](../sandbox/pilot_rig_lab/pilot_rig_stylizer.gdshader) |

---

## 2. Topología del SceneTree (`ValentinaFaceRig`)

```text
ValentinaFaceRig (Node2D)
└── UnifiedCharacterGroup (CanvasGroup, z_index = 0, use_mipmaps = true, fit/clear_margin = 64.0) [Pasada 2]
    ├── HeadUnderMount (Node2D, z_index = 0)  [8/9 Sprite2D, head_layer_pass = 1 (cuello detrás del torso)]
    ├── TorsoRefMount (Node2D, z_index = 0)   [8 Sprite2D body_core alineados por parts_5_meta.json, toggle T]
    └── HeadOverMount (Node2D, z_index = 0)   [8/9 Sprite2D, head_layer_pass = 2 (rostro + pelo + monóculo)]
```

> **Invariante `CanvasGroup`:** Todos los hijos bajo `UnifiedCharacterGroup` mantienen `z_index = 0`. El orden de render se determina estrictamente por el orden de nodos en el árbol (`HeadUnderMount < TorsoRefMount < HeadOverMount`).

---

## 3. Pipeline de Máscaras y Contratos de Canales (`heads/`)

### 3.1 Herramientas Offline (`08_head_live_rig/` y `09_eye_live2d_assets/`)
1. [`export_head_live_mask_sheet.py`](../sandbox/pilot_rig_lab/tools/export_head_live_mask_sheet.py): exporta la lámina `16:9` (`2560×1440`, grilla `2×4` a escala `1.70x`), pre-máscara plana, base con tinta y `head_live_sheet_manifest.json`.
2. [`fuse_head_live_mask_sheet.py`](../sandbox/pilot_rig_lab/tools/fuse_head_live_mask_sheet.py): fusiona silueta/cuello/monóculo canónicos (`IoU = 1.0000`) + facciones faciales + 4 zonas de cabello en `outputs/heads_8dir_live_mask_16x9.png`.
3. [`ingest_head_live_rig_assets.py`](../sandbox/pilot_rig_lab/tools/ingest_head_live_rig_assets.py): compila la máscara semántica y el mapa de profundidad 2.5D en las texturas runtime de `assets/pilots/valentina_v2/planar/heads/`.
4. [`export_eye_live2d_sheets.py`](../sandbox/pilot_rig_lab/tools/export_eye_live2d_sheets.py): exporta la lámina estándar `1:1` (`2048×2048`, grilla `2×2`, zoom `12x` = `960×960 px`) para las 4 cabezas con ojo descubierto (`head_front`, `head_front_r`, `head_front_l`, `head_side_r`).
5. [`ingest_eye_live2d_assets.py`](../sandbox/pilot_rig_lab/tools/ingest_eye_live2d_assets.py): compila los iris 360° **Amatista Profundo** desde `outputs/eyes_4dir_iris_360_1x1.png` (`eyes_4dir_iris_360_1x1_amethyst.png`, con respaldo original `eyes_4dir_iris_360_1x1_silver_lavender_backup.png`) usando extracción *chroma-safe* (`max_ch < 62`, `median_chroma >= 28.0`), genera el parche de ojo cerrado, refina `G` (respetando la pestaña negra superior), hornea de forma idempotente (respaldo nativo inmutable `_heads_native_backup/`) la mirada neutra **Amatista Profundo** `4× SSAA` sin catchlights sobre `heads/head_{front,front_r,front_l,side_r,side}.png` y registra `"eye_palette": "deep_amethyst"` en `eye_live2d_meta.json`.

### 3.2 Contrato Exacto de Texturas por Cabeza (8 Cabezas + Alias `head_side`)

| Archivo | Formato / Mipmaps | Canales | Uso en Runtime (`rig_face_live.gdshaderinc`) |
|---|---|---|---|
| `<head>.png` *(5 vistas con ojo descubierto)* | RGBA 8-bit (`use_mipmaps = true`, alfa preservado) | Albedo base estandarizado con ojo neutro **Amatista Profundo** `4× SSAA` horneado sin catchlights + sombra fija de párpado | Fuente directa en modos estáticos/A-B y rigs con `enable_face_live = false` (`PlanarShaderLab`, `RigCalibrator`, `PlanarCombatRig` independiente); en vivo queda cubierto por las capas Live2D. |
| `<head>_face_live_mask.png` | RGBA 8-bit (`use_mipmaps = false`) | `R` = Párpado superior + envolvente superior sobre iris<br>`G` = Ventana de almendra ocular recortada bajo la pestaña negra superior<br>`B` = Cejas<br>`A` = Boca (en rostro) / **Gradiente Soldadura Cervical `0→1`** (en `is_collar_blue`) | `G` recorta la esclerótica limpia, la sombra fija del párpado superior y el iris 360°; `R/G` impulsan el barrido intermedio del párpado; `B/A` deforman cejas/labios y fijan el cuello al torso. |
| `<head>_eye_iris.png` *(4 vistas + alias `head_side`)* | RGBA `128×128` (`use_mipmaps = true`, muestreado en `LOD 0` + RGSS, borde oscuro sin halo) | Paleta canónica **Amatista Profundo** (`#421D70` sombra sup. → `#8B5CF6` núcleo → `#DFC4FF` media luna inf.) + anillo negro + pupila gatuna `#100816` (`87.5%` centrado) | Capa 2 desplazada por `face_eye_look_px` y escalada dinámicamente por `face_iris_scale` dentro de `G`, con brillo especular reactivo (`face_eye_highlight_strength`) y micro-glow táctico (`face_eye_combat_glow`). |
| `<head>_eye_closed.png` *(4 vistas con ojo descubierto)* | RGBA `256×256` (`use_mipmaps = true`, alineado a `eye_patch_rect_uv`) | Parche dibujado de párpado cerrado + pestaña anime curva con piel igualada y protección de cejas/pelo/monóculo | Entra suavemente en la fase final del parpadeo y *squint* alto (`close_amt → 1.0`), sustituyendo al iris/esclerótica abiertos. |
| `<head>_hair_jiggle_mask.png` | RGB 8-bit (`use_mipmaps = false`) | `R` = Flequillo frontal<br>`G` = Mechones laterales<br>`B` = Puntas traseras / nuca<br>*(Coronilla `#606878` y rostro/cuello = `0`)* | Impulsado independientemente por 3 resortes subamortiguados (`secondary_jiggle_l_px`, `secondary_jiggle_r_px`, `secondary_jiggle_b_px`) + micro-normal 2.5D. |
| `<head>_normal_depth.png` | RGBA 8-bit (`use_mipmaps = true`) | `RGB` = `70%` domo craneal + `30%` relieve Sobel (nariz, pómulos, monóculo, mechones)<br>`A` = Profundidad normalizada `[80..245]` (`monóculo >= 235`, `flequillo >= 215`, `cuello [80..135]`, relleno Voronoi) | Sombreado 2.5D esculpido del rostro y parallax Live2D (`banking_tilt_2d`, `depth_parallax_px`, pivote `face_parallax_pivot`). |

---

## 4. Uniformes Opt-In del Shader (`pilot_rig_stylizer.gdshader`)

Todos los cambios en `pilot_rig_stylizer.gdshader` están protegidos detrás de `enable_face_live = false`, `has_eye_live2d_assets = false` y `secondary_jiggle_b_px = vec2(0.0)`, manteniendo compatibilidad binaria 100% con `PlanarCombatRig`:

- **Soldadura Cervical:** `face_live_mask_tex`, `neck_pivot_uv`, `face_neck_weld_strength`, `face_neck_rot_rad`, `face_neck_shift_px`, `face_chin_shadow_strength`.
- **Ojo Live2D 3 Capas + Expresiones:** `has_eye_live2d_assets`, `eye_iris_tex`, `eye_closed_tex`, `eye_center_uv`, `eye_iris_size_uv`, `eye_patch_rect_uv`, `face_iris_scale` (dilatación/contracción dinámica), `face_eye_highlight_strength` (brillo especular reactivo), `face_eye_lid_shadow_strength` (sombra fija del párpado superior sobre el iris), `face_eye_look_px`, `face_blink`, `face_squint`, `face_brow_offset_px`, `face_brow_tilt`, `face_mouth_open`, `face_mouth_smile`.
- **Parallax 2.5D & Cabello 3 Zonas:** `face_parallax_pivot`, `banking_tilt_2d`, `depth_parallax_px`, `secondary_jiggle_l_px` (Flequillo `R`), `secondary_jiggle_r_px` (Laterales `G`), `secondary_jiggle_b_px` (Nuca `B`), `secondary_jiggle_normal_strength`.
- **Monóculo Táctico & Rayos-X:** `face_monocle_hud_strength`, `face_monocle_activity`, `debug_view_mode = 7` (`Face Live Mask R/G/B/A`) y `debug_view_mode = 8` (`Hair 3-Zone R/G/B`).

---

## 5. Controles y Atajos del Laboratorio (`valentina_face_lab.tscn`)

| Atajo / Control | Acción |
|---|---|
| **Mover ratón** | Mirada en tiempo real (en modo `Seguir Cursor`) + Parallax 2.5D Live2D + inclinación cervical suave |
| **Rueda del ratón / Arrastrar Der. o Central** | Zoom (`0.50x..10.0x`) y paneo libre sin interferir con el cursor de mirada |
| **`B`** | Disparar parpadeo inmediato |
| **`W`** | Disparar impulso *Whip* sobre los 3 resortes de cabello + actividad del monóculo |
| **`1..8`** | Cambiar cabeza activa (`S, SE, E, NE, N, NW, W, SW`) |
| **`V`** | Alternar vista **Hero Close-Up** ↔ **Galería 8-Dir (2×4)** |
| **`T`** | Mostrar/ocultar **Torso de Referencia** (`TorsoRefMount`) para validar soldadura cervical |
| **`Tab`** | Comparativa instantánea **A/B** (`Rig Facial Vivo` vs `Estático Original`) |
| **`M`** | Ciclar velocidad Slow-Mo (`1.00x / 0.50x / 0.25x / 0.12x`) |
| **`R`** | Centrar y restaurar cámara |

---

## 6. Integración Activa en `PlanarCombatRig`, Arena de Combate y Brújula 8-Dir

El rig facial vivo y el ojo Live2D en 3 capas ya operan integrados sobre el rig completo de combate mediante el controlador modular [`PlanarRigFaceController`](../sandbox/pilot_rig_lab/proto/planar_rig_face_controller.gd):

1. **Enlace Único en [`PlanarRigMeshBuilder.build_decoupled_heads`](../sandbox/pilot_rig_lab/proto/planar_rig_mesh_builder.gd):**
   - Carga automática de `<head>_face_live_mask.png` (`use_mipmaps = false`), `neck_pivot_uv`, `eye_live2d_meta.json`, `<head>_eye_iris.png` y `<head>_eye_closed.png` (y expone `tex_per_du`).
   - En `PlanarCombatRig` independiente permanece opt-in (`enable_face_live = false` por defecto) para preservar intactos los invariantes del rig purgado.
2. **Personalidad Calibrada en [`valentina_v2_face_anim.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_face_anim.tres):**
   - Perfil por defecto: **`STOIC_TACTICAL` (`0: Táctica Fría / Estoica`)**, con soporte data-driven de `CONFIDENT_ACE (1)` y `EXPRESSIVE_ANIME (2)` en `COMBAT_MOOD_TABLES`.
   - Prioridad emocional en combate: **`HIT_WINCE > FIRE > BRAKE_DASH > BACKPEDAL > FOCUS > COMMS > IDLE`**. En el impacto inicial de `HIT_WINCE`, `blink_floor = 1.0` cierra al parche dibujado `_eye_closed.png` antes de reabrir con ceño tenso.
3. **Mecánicas de Vida y "Juice" Integradas:**
   - **Aim-Lead + Parallax 2.5D:** los ojos y el relieve facial se adelantan hacia `_smooth_aim_dir` respecto al frente anatómico de la cabeza activa, y el catchlight sigue dinámicamente a `light_dir_2d` (la estrella luminosa en la Arena).
   - **Blink-on-Turn:** parpadeo rápido (`combat_turn_blink_dur_sec = 0.115 s`) disparado al iniciar un giro o cambio de vista 8-dir para ocultar el corte discreto.
   - **Cabello 3-Zonas con Física Real:** arrastre aerodinámico (`-vel_norm`), *overshoot* frontal al clavar Air-Brake y *whip* escalonado por zona (`R/G/B`) en giros y retrocesos. Cuando `rig.is_face_live_enabled()` es `true`, `PlanarRigBasePoseEvaluator._apply_secondary_jiggle_layer` cede el cabello de la cabeza al controlador facial manteniendo el jiggle corporal en `body_core`.
   - **Comms Tácticos (`C` / `trigger_comms_talk`):** superpone lip-sync silábico y pulso en el monóculo sin bloquear el eye-tracking ni sobrescribir el foco de combate.
4. **Escenas Conectadas por Defecto (`enable_face_live = true`):**
   - **Arena de Combate ([`planar_combat_rig_proto.gd`](../sandbox/pilot_rig_lab/proto/planar_rig_face_controller.gd)):** toggle en Menú 3, selector de Personalidad, botón `Comms Táctico (C)` / tecla `C`, Rayos-X `7..8` en Menú 4 y telemetría `Face=<MOOD>` en la barra de estado.
   - **Brújula 8-Dir ([`planar_anim_test.gd`](../sandbox/pilot_rig_lab/proto/planar_anim_test.gd)):** checkbox `Rig Facial Vivo & Personalidad (.tres)` y actualización sincronizada de las 8 cabezas en Idle, Vuelo, Freno, Reversa, Giros y Jiggle.
5. **Claridad de Pupila a Distancia de Combate, Estándar Amatista Profundo y Micro-Glow Táctico:**
   - **Asset [`_eye_iris.png`](../sandbox/pilot_rig_lab/tools/ingest_eye_live2d_assets.py) y Albedo Horneado:** paleta estandarizada **Amatista Profundo** (`#421D70` → `#8B5CF6` → `#DFC4FF`, pupila felina `#100816`), con detección *chroma-safe*, respaldo original en `_heads_native_backup/`, horneado `4× SSAA` neutro en `<head>.png` (`head_front`, `head_front_r`, `head_front_l`, `head_side_r`, `head_side`) y columna 7 (`7. Combat Zoom 1.15x`) en `audit_eye_live2d_compiled.png`.
   - **Muestreo `LOD 0` + RGSS Nuclear-Scoped ([`pilot_rig_stylizer.gdshader`](../sandbox/pilot_rig_lab/pilot_rig_stylizer.gdshader)):** reemplaza `texture()` con mipmaps por `textureLod(..., 0.0)` y supermuestreo RGSS acotado (`±0.26` texels) con preservación HSV mínima (`dark_hit * 0.58 * pupil_core_zone`) restringida al núcleo vertical de la pupila (sin dilatar el anillo exterior) y presencia óptica `+5%` a distancia (`screen_px_in_texels`, `face_eye_far_clarity = 0.90`), más máscara `face_eye_open_mask` (en vivo y estático) que aísla esclerótica e iris de `skin_shadow_tint`, `ao_tint`, SSS coral y `ink_skin_tint` pardo-rojizo dejando el párpado móvil sombreado normalmente. Además, `above_uv` muestrea en `LOD 0` el delineado real dibujado (`above_lid_rgb`/`above_lid_sdf` con preservación vertical de pestañas en distancia) y `eye_closed_tex` usa `LOD 0` + RGSS de 4 taps para evitar borrado de pestañas en `squint` o parpadeo.
   - **Óptica, Catchlights y Downsample SSAA ([`rig_face_live.gdshaderinc`](../sandbox/pilot_rig_lab/shaders/rig_face_live.gdshaderinc), [`ssaa_downsample.gdshader`](../sandbox/pilot_rig_lab/shader_lab/ssaa_downsample.gdshader)):** Capa 3 desliza suavemente el delineado superior dibujado real (`above_flm.r`) sin sobrescribirlo con piel al entrecerrar los ojos ni recortar el rabillo del parpadeo cerrado; realce tonal limpio a distancia (`1.12x`), umbrales HSV (`io_dark_luma`, `new_iris_ink`, `iris_interior`, `fill_only`), catchlight gemelo estabilizado frente a luz rotatoria y reforzado a distancia (`mix(1.0, 1.08, far_eye_clarity)`), moods de combate con ojo abierto (`FOCUS squint = 0.12 / iris_scale = 0.93`, `BACKPEDAL squint = 0.14 / iris_scale = 0.94`), micro-glow amatista calmo (`0.38`, `eye_combat_glow_strength = 0.52`, `eye_highlight_strength = 0.92`) y filtro SSAA más nítido (`0.21 * ss_scale`, pesos `0.44 / 0.14`). Estandarizado transversalmente en `ValentinaFaceLab`, `PlanarCombatRigProto`, `PlanarAnimTest`, `PlanarShaderLab` y `RigCalibrator`.
