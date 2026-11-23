# Especificación Técnica — Live Banner 2.5D & Banner Lab (`Valentina v2`)

> **Ámbito:** Splash Art vivo 2.5D para Selección de Personajes + Icono `1:1` (`512×512`) bajo `sandbox/pilot_rig_lab/banner_lab/`.
> **Estado:** Base Activa (I+D) · **Regla de aislamiento:** No enlazar directo a producción hasta la promoción controlada.
> **Prompts IA (Master HQ / ILM / Ink / Normal):** [`VALENTINA_LIVE_BANNER_PROMPTS.md`](VALENTINA_LIVE_BANNER_PROMPTS.md)
> **Verificación rápida:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_banner_lab"`

---

## 1. Mapa de Archivos del Subsistema

| Rol | Archivo | Responsabilidad |
|---|---|---|
| **Configuración `.tres`** | `sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_live_banner.tres` | Balance numérico, rutas de texturas/máscaras, pivotes UV, tiempos de parpadeo, alas e Impact Frames (`PilotLiveBannerConfig`) |
| **Esquema de datos** | `sandbox/pilot_rig_lab/data/pilot_live_banner_config.gd` | Recurso tipado `PilotLiveBannerConfig` + `ensure_defaults()` |
| **Controlador runtime** | `sandbox/pilot_rig_lab/banner_lab/pilot_live_banner_controller.gd` | Árbol de nodos (`UnifiedBannerGroup`), física de resorte 2D, parpadeo, secuencia *Elegir Piloto* (Impact Frames 1→2→0 + despliegue de 12 cuchillas) |
| **Shader Pasada 1** | `sandbox/pilot_rig_lab/banner_lab/pilot_live_banner.gdshader` | Respiración, cabello Zero-G, Ojo Amatista + parpadeo, Monóculo HUD, Cel 2.5D ArcSys, contra-luz simétrica de alas, tinta Ink SDF, modo debug `0..5` |
| **Shader Pasada 2** | `sandbox/pilot_rig_lab/pilot_rig_pass2.gdshader` | Contorno caligráfico exterior, soldador de costuras (`seam_weld`), CAS Sharpen, rim de silueta e Impact Frames sobre `UnifiedBannerGroup` |
| **Escena de Lab + HUD** | `sandbox/pilot_rig_lab/banner_lab/valentina_banner_lab.{tscn,gd}` + `valentina_banner_lab_hud.gd` | Laboratorio interactivo con zoom, skins, debug de máscaras y guardado/recarga `.tres` |
| **Compilador Offline** | `sandbox/pilot_rig_lab/tools/build_valentina_live_banner.py` | Toma arte master + 4 máscaras IA y hornea los 9 PNGs + `*_banner_meta.json` |
| **Suite de Tests** | `tests/sandbox/test_valentina_banner_lab.{tscn,gd}` | Valida carga, parpadeo, resorte jiggle, Idle 2.5D, invariante `CanvasGroup` y secuencia de alas + Impact Frames |

---

## 2. Jerarquía de Nodos e Invariantes Críticos

`PilotLiveBannerController` (`Node2D`) construye esta jerarquía exacta en `_build_nodes()`:

```text
PilotLiveBannerController (Node2D)
├── BannerBackdropFX (_BackdropFX, z_index = 1)           # Atmósfera / shockwave / backlight
├── PsychicWingsRoot (Node2D, z_index = 3)                # 12 cuchillas reales (wing_0deg_l/r de wings_metadata.json)
├── UnifiedBannerGroup (CanvasGroup, z_index = 5)         # Material: pilot_rig_pass2.gdshader (fit/clear_margin = 24px)
│   └── BannerCharacterRoot (Node2D, z_index = 0)         # Flotación Zero-G, tilt, punch_scale y shake
│       ├── FreeArmPivot (Node2D, z_index = 0)            # Pivote FIJO en right_shoulder_uv (escala/rotación 2.5D)
│       │   └── FreeArmSprite (Sprite2D, z_index = 0)     # pilot_live_banner.gdshader (is_arm_layer = true)
│       └── LiveBannerSprite (Sprite2D, z_index = 0)      # pilot_live_banner.gdshader (is_arm_layer = false)
└── BannerForegroundFX (_BackdropFX, z_index = 8)         # Partículas / frente
```

### Invariantes que NO se pueden romper
1. **Regla `CanvasGroup`:** Todos los descendientes de `UnifiedBannerGroup` (`BannerCharacterRoot`, `FreeArmPivot`, `FreeArmSprite`, `LiveBannerSprite`) DEBEN mantener `z_index = 0`. El brazo libre queda debajo de la hombrera estática exclusivamente por orden de hijos (`FreeArmPivot` antes de `LiveBannerSprite`).
2. **Soldadura Hombrera–Brazo Libre:** `LiveBannerSprite` no aplica desplazamiento UV horizontal en el cuerpo y `FreeArmPivot.position` permanece anclado en `_arm_pivot_local` (`right_shoulder_uv`), evitando cualquier grieta en la bisagra.
3. **Protección HSV en Ojo Amatista (Invariante #7):** El shader evalúa `max(r, max(g, b))` para conservar pupila `#100816` y delineado sin ennegrecer el violeta `#421D70` superior, y excluye la almendra del ojo del `ink_sdf` (salvo la pestaña activa durante el parpadeo).
4. **Ink SDF sin mipmaps:** `ink_sdf` se carga con `use_mipmaps = false` (`_load_tex(..., true)`) y se muestrea con `textureLod(ink_sdf, final_uv, 0.0)`.
5. **Escalado normalizado:** `TARGET_BANNER_HEIGHT_PX = 640.0`; `_base_scale = 640.0 / base_tex.get_size().y`.

---

## 3. Contrato de Máscaras y Pipeline de Compilación Python

### Entradas del compilador (`banner_lab/refs/`)
| Flag CLI | Archivo Ref (Valentina v2) | Contrato de Colores (Entrada IA) |
|---|---|---|
| `--src` | `valentina_v2_splash_raw_master.jpg` | Arte completo sobre fondo blanco puro (removido por flood-fill + anti-fringe) |
| `--mask-parts` | `mask1_parts_raw.png` | `R`=torso/busto, `G`=cabello, `B`=brazo libre, `Y`=brazo cadera, `C`=rostro, `M`=piernas |
| `--mask-mat` | `mask2_materials_raw.png` | `B`=ojo, `G`=monóculo, `Y`=trim carmesí, `R`=traje, `C`=piel, `M`=cabello |
| `--mask-depth` | `mask3_depth_raw.png` | Depth Map 2.5D en escala de grises (blanco = más cerca) |
| `--mask-ink` | `mask4_ink_raw.png` | Trazos internos negros sobre fondo `#FFFFFF` puro (sin rellenos sólidos) |
| `--mask-ilm` | `mask5_ilm_raw.png` | Zonas ILM ortogonales (`#FF0000` Metal, `#00FFFF` Angel Ring/Satín, `#0000FF` AO permanente, `#FFFF00` Piel protegida, `#00FF00` Mate, `#FF00FF` Emisivo) |
| `--mask-normal` | `mask6_normal_raw.png` | Normal Map tangente OpenGL sobre `#8080FF` (prioritario sobre el Sobel de `depth`) |

### Comando de compilación
```powershell
python sandbox/pilot_rig_lab/tools/build_valentina_live_banner.py `
  --src sandbox/pilot_rig_lab/banner_lab/refs/valentina_v2_splash_raw_master.jpg `
  --mask-parts sandbox/pilot_rig_lab/banner_lab/refs/mask1_parts_raw.png `
  --mask-mat sandbox/pilot_rig_lab/banner_lab/refs/mask2_materials_raw.png `
  --mask-depth sandbox/pilot_rig_lab/banner_lab/refs/mask3_depth_raw.png `
  --mask-ink sandbox/pilot_rig_lab/banner_lab/refs/mask4_ink_raw.png `
  --mask-ilm sandbox/pilot_rig_lab/banner_lab/refs/mask5_ilm_raw.png `
  --mask-normal sandbox/pilot_rig_lab/banner_lab/refs/mask6_normal_raw.png `
  --out-dir sandbox/pilot_rig_lab/banner_lab/assets/valentina_v2 `
  --prefix valentina_v2
```

### Salidas compiladas y contrato de canales RGBA (`banner_lab/assets/<pilot>/`)
| Archivo Generado | Contenido / Canales (RGB leído en Shader) | Notas Técnicas |
|---|---|---|
| `<pilot>_splash_base.png` | RGBA completo recortado sin fondo | Referencia completa |
| `<pilot>_body_layer.png` | RGBA cuerpo sin brazo libre (hombrera intacta) | Textura de `LiveBannerSprite` |
| `<pilot>_free_arm_layer.png` | RGBA solo brazo libre derecho | Textura de `FreeArmSprite` |
| `<pilot>_splash_motion_mask.png` | **R** = peso respiración busto · **G** = cabello Zero-G · **B** = `0` | Canal `G` dilatado `24px` hacia afuera con máscara de protección facial (`face/monocle/eye`) para cero fantasmas en bordes |
| `<pilot>_splash_fx_mask.png` | **R** = traje/armadura · **G** = monóculo + trims carmesí · **B** = almendra del ojo | Piel se deduce como `1 - max(suit, hair, emissive, eye)` |
| `<pilot>_splash_depth.png` | Grises `[0..255]` | Dilatado `28px` hacia afuera para cero halos |
| `<pilot>_splash_normal.png` | Normal tangente RGB (desde `--mask-normal` o fallback Sobel de `depth`) | Neutralizado a `(0, 0, 1)` fuera de la silueta |
| `<pilot>_splash_ilm.png` | **R** = Metal Spec · **G** = AO/Shadow Bias · **B** = Angel Ring / Satín | Compilado desde `mask5_ilm_raw.png` con limpieza intra-silueta |
| `<pilot>_splash_ink_sdf.png` | Distancia con signo `±8px` nativos horneada a **`2×`** (`2212×3072`) | Muestreado en LOD 0 con `ink_color_tint_mix = 0.82` |
| `<pilot>_icon_1x1.png` | Retrato `512×512` (rostro + monóculo) | Icono de tarjeta/roster |
| `<pilot>_banner_meta.json` | `size`, `chest_center_uv`, `eye_center_uv`, `iris_center_uv`, `right_shoulder_uv` | Coordenadas UV calibradas para copiar al `.tres` |

---

## 4. Pipeline del Shader (`pilot_live_banner.gdshader`)

El fragment shader ejecuta 8 etapas en orden (respetando `is_arm_layer`, que desactiva respiración, cabello, ojo y monóculo en el brazo libre):
1. **Respiración & Jiggle 2D:** Expansión radial + lift vertical sobre `chest_center_uv` modulados por `motion_mask.r` + desplazamiento por resorte `jiggle_offset`.
2. **Cabello Zero-G + Viento de Alas:** Doble onda sinusoidal + ráfaga ascendente (`hair_burst_lift`) al desplegar alas, modulado por `motion_mask.g`.
3. **Recolor por Skin Preset:** Cuando `skin_recolor_enabled = true`, recolorea `emissive_w` con `skin_accent_color` y `hair_mat_w` con `skin_hair_color` (mismo contrato que `PilotSkinPreset`).
4. **Ojo Amatista Profundo + Parpadeo Anatómico:** Realce hacia `#421D70 → #8B5CF6 → #DFC4FF` con protección HSV, 2 catchlights y barrido arqueado del párpado superior (`blink_amount`, piel `#E3B2A6` + pestaña `#160D1A`).
5. **Monóculo HUD Vivo:** Scanlines, barrido vertical y retícula dentro de `monocle_bounds_uv` reactivos a `wings_light_intensity`.
6. **Cel-Shading 2.5D ArcSys:** Usa `rig_stylized_lighting.gdshaderinc` (`compute_arcsys_shadow_srgb`), protección facial (`0.90`), SSS en piel, especular en traje y halo ángel en cabello superior + `arm_depth_shade` en brazo libre.
7. **Contra-Luz Direccional Simétrica de Alas:** Iluminación rasante (`n_vec.xy` vs `wing_dir`) que protege el núcleo central (`abs(uv.x - 0.50)`) para evitar manchas rojas en rostro/pecho.
8. **Tinta Interna Ink SDF + Grading:** Tinta vectorial nítida (`ink_sdf_enabled`) con protección ocular + `apply_cinematic_grade_srgb` preservando exceso HDR `> 1.0`.

### Modos de Depuración (`debug_view_mode`)
`0` = Final (con Pass 2 activo) · `1` = Motion Mask · `2` = FX Mask · `3` = Depth Map · `4` = Normal Map · `5` = Ink SDF · `6` = ILM Map.
*(En modos `1..5`, `PilotLiveBannerController` apaga automáticamente contorno, rim e Impact Frames en Pass 2 para inspección pura.)*

---

## 5. Secuencia Lock-In "Full Anime Overdrive" y Pulso Escáner de Alas

### Flujo de `trigger_select_sequence()`
1. **Cascada Mecánica (`0 .. wings_cascade_duration_sec`):** Dispara parpadeo rápido de anticipación (`1.65×`), despliega secuencialmente las 12 cuchillas de alas (`0..5` de adentro hacia afuera) con destello `ignition_flash` en las vetas rojas (`wing_red_glow.gdshader`) y tensión creciente.
2. **Golpe de Trabado (`wings_cascade_duration_sec`):** Abre el ojo instantáneamente con brillo amatista intenso (`_lock_eye_flare`), contracción táctica de iris (`0.86×`) y destello en cruz; abre el brazo libre hacia afuera (`lock_arm_flare_deg`), dispara ráfaga ascendente de cabello, micro-zoom + camera shake, onda expansiva doble y líneas radiales anime sobre los **2 Impact Frames (`phase 1 → 2 → 0`)**.
3. **Sostenido + Pulso Cibernético:** Las 12 cuchillas mantienen un pulso escáner HDR continuo de raíz a punta en sus máscaras rojas (`*_ilm_mask.png`, compartido con Combat Rig y VFX Lab) junto a chispas carmesí flotantes detrás del personaje.
4. **Reinicio:** `reset_select_sequence()` pliega las alas y limpia chispas, onda y flare.

### Atajos en `valentina_banner_lab.tscn`
| Entrada | Acción |
|---|---|
| `Enter` / `E` | Disparar secuencia *Elegir Piloto* (Impact Frames + Alas) |
| `R` | Reiniciar / plegar alas |
| `B` | Disparar parpadeo manual |
| `Space` / Click Izquierdo | Impulso de hover/jiggle |
| Rueda del Mouse | Zoom (`0.55×` a `2.4×`, sincronizado con `zoom_scale` de Pass 2) |

---

## 6. Guía Rápida para Escalar a Otros Pilotos
1. Crear `sandbox/pilot_rig_lab/banner_lab/refs/<pilot>/` con el arte master sobre blanco y las 4 máscaras siguiendo el contrato de la Sección 3.
2. Ejecutar `build_valentina_live_banner.py --prefix <pilot> --out-dir sandbox/pilot_rig_lab/banner_lab/assets/<pilot>`.
3. Duplicar `valentina_v2_live_banner.tres` → `<pilot>_live_banner.tres`, actualizar las 7 rutas de texturas, `wings_assets_dir` y copiar `chest_center_uv`, `eye_center_uv` y `right_shoulder_uv` desde `<pilot>_banner_meta.json`.
4. Si el nuevo piloto tiene ojos/monóculo en otra región o sin monóculo, parametrizar `eye_almond_bounds_uv` y `monocle_bounds_uv` en `PilotLiveBannerConfig` (hoy tienen defaults calibrados a Valentina v2 en `pilot_live_banner.gdshader`).
