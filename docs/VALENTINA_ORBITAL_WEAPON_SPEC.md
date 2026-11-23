# Guía Maestra y Estándar Replicable — Anillo Orbital 2.5D & Armamento 3D Cel-Shaded (*Guns Lab*)

> **Estado:** **Cerrado y verificado en `PilotRigLab`** (`test_valentina_guns_lab.tscn`, `test_pilot_rig_lab.tscn`).
> **Implementación de Referencia:** **Valentina v2 — *Rail-Lance Autónomo* (3D Cel-Shaded)** + **Anillo *Retícula Táctica Mecha* (Textura IA + Encastre *Over-Hug*)**.
> **Documentos relacionados:** [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md) · [`docs/VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) · [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md)

---

## 1. Arquitectura del Sistema (Anillo 2.5D + Dual Renderer 3D / 2.5D)

El sistema mantiene al piloto intacto dentro de su `CanvasGroup` 2D y orbita de 1 a 4 armas alrededor de una elipse 3D nivelada (`ring_tilt_deg = 0.0`, `128 × 72 px` en perspectiva 3/4 de combate) partida en pasadas Z-ordenadas:

1. **Modo 3D Cel-Shaded (`SubViewport` transparente — Estándar Principal):** rotación real 360° en 3 ejes sin *flip* brusco ni aplastamiento tipo acordeón, con cel-shading *ArcSys* de 3 bandas, contorno *inverted-hull* cerrado y proyección exacta de boca `3D → 2D`.
2. **Modo 2.5D Multi-Mapa (`Sprite2D` + `orbital_weapon_25d.gdshader` — Respaldo / Comparativa A/B):** sprite plano compilado en 4 mapas (`albedo`, `id_mask`, `ilm_mask`, `ink_sdf 2×`) con deformación trapezoidal, extrusión multi-tap de 6 pasos y soporte retrocompatible para sprites simples de 1 textura.

```text
PilotOrbitalWeaponConfig (.tres) ──► OrbitalWeaponRingController (Node2D)
                                      ├── OrbitalRingTexBack / OrbitalRingBack   (z_index = 2, mitad trasera)
                                      ├── OrbitalWeaponSlot_0..3 atrás           (z_index = 3)
                                      ├── OrbitalRingTexBackOver                 (z_index = 4, Over-Hug detrás del rig)
                                      ├── [PlanarCombatRig externo:               z_index = 5]
                                      ├── OrbitalRingTexFront / OrbitalRingFront (z_index = 10, mitad delantera)
                                      ├── OrbitalWeaponSlot_0..3 adelante        (z_index = 11)
                                      │    ├── [3D] Weapon3DRenderer (SubViewport 256×256, MSAA_4X)
                                      │    │     └── Camera3D + RailLanceMesh3D (3 superficies Toon + Outline)
                                      │    └── WeaponSprite (Sprite2D: textura del SubViewport o Multi-Mapa 2.5D)
                                      ├── OrbitalRingTexFrontOver                (z_index = 12, Over-Hug sobre mitad inferior del arma)
                                      └── OrbitalWeaponFX                        (z_index = 13, muzzle flashes & trazadores HDR)
```

### Inventario de Archivos del Sistema

| Componente | Archivo | Rol |
|---|---|---|
| **Esquema Data-Driven** | [`sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd`](../sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd) | Recurso `PilotOrbitalWeaponConfig` (elipse 3D, textura IA, contrarrotación, perspectiva 2.5D, shader, órbita y recoil). |
| **Preset Calibrado** | [`sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_orbital_weapon.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_orbital_weapon.tres) | Preset aprobado para Valentina v2 (`ring_center_offset = (0, 10)`, `ring_radius_x = 128.0`, `ring_radius_y = 72.0`, `ring_tilt_deg = 0.0`, `weapon_radial_offset_px = 0.0`, `weapon_base_scale = 0.135`, `weapon_pivot_u = 0.355`, `weapon_muzzle_u = 0.966`). |
| **Orquestador Orbital** | [`sandbox/pilot_rig_lab/guns_lab/orbital_weapon_ring_controller.gd`](../sandbox/pilot_rig_lab/guns_lab/orbital_weapon_ring_controller.gd) | `OrbitalWeaponRingController`: modos `AUTO_RADIAL`, `MOUSE_AIM`, `AUTO_TANGENT`, Z-sorting (`2/3/4` y `10/11/12/13`), acoplamiento 3D, `MAIN_RAIL_UV_RADIUS = 0.3827` y VFX de disparo. |
| **Malla 3D Procedural** | [`sandbox/pilot_rig_lab/guns_lab/rail_lance_3d_mesh_builder.gd`](../sandbox/pilot_rig_lab/guns_lab/rail_lance_3d_mesh_builder.gd) | `RailLance3DMeshBuilder`: construye el `ArrayMesh` cacheado de 3 superficies con normales planas (`NORMAL`) y suaves soldadas (`UV`/`UV2`). |
| **Renderizador `SubViewport` 3D** | [`sandbox/pilot_rig_lab/guns_lab/orbital_weapon_3d_renderer.gd`](../sandbox/pilot_rig_lab/guns_lab/orbital_weapon_3d_renderer.gd) | `OrbitalWeapon3DRenderer`: `SubViewport` (`256×256`, `transparent_bg`, `use_hdr_2d`, `MSAA_4X`), cámara 3D, sync de skins y `get_muzzle_uv_offset()`. |
| **Shader Toon 3D** | [`sandbox/pilot_rig_lab/guns_lab/rail_lance_toon_3d.gdshader`](../sandbox/pilot_rig_lab/guns_lab/rail_lance_toon_3d.gdshader) | Cel-shading 3 bandas *ArcSys*, Blinn-Phong nítido, rim-light, glow HDR en cristal/conductos y atenuación trasera. |
| **Shader Contorno 3D** | [`sandbox/pilot_rig_lab/guns_lab/rail_lance_outline_3d.gdshader`](../sandbox/pilot_rig_lab/guns_lab/rail_lance_outline_3d.gdshader) | Pasada `cull_front` (`next_pass`) extruyendo por la normal suave almacenada en `UV`/`UV2` sin grietas en aristas duras. |
| **Shader Anillo IA 2.5D** | [`sandbox/pilot_rig_lab/guns_lab/orbital_ring_25d.gdshader`](../sandbox/pilot_rig_lab/guns_lab/orbital_ring_25d.gdshader) | Proyección elíptica, corte atrás/delante (`UV.y < 0.5`), contrarrotación exterior/interior, pulso HDR por `slot_angles` y pasada `over_hug_pass` de encastre vertical. |
| **Shader Arma 2.5D Multi-Mapa** | [`sandbox/pilot_rig_lab/guns_lab/orbital_weapon_25d.gdshader`](../sandbox/pilot_rig_lab/guns_lab/orbital_weapon_25d.gdshader) | Trapezoide proyectivo, extrusión 3D multi-tap, Ink SDF `2×` en LOD 0, recoloreo por skin vía `id_mask_tex` y fallback legacy. |
| **Compilador Offline Arma 2D** | [`sandbox/pilot_rig_lab/tools/build_valentina_weapon.py`](../sandbox/pilot_rig_lab/tools/build_valentina_weapon.py) | Compila un sprite maestro `#808080` en 4 mapas (`albedo`, `id_mask`, `ilm_mask`, `ink_sdf 2×`) + `*_meta.json`. |
| **Compilador Offline Anillo IA** | [`sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py`](../sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py) | Compila una textura cenital `1:1` sobre `#000000` en PNG RGBA empaquetado (`R/G/B/A`) + `*_meta.json` (`split_uv_radius`, `main_rail_uv_radius`). |
| **Escena & HUD de Lab** | [`valentina_guns_lab.tscn`](../sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab.tscn) · [`valentina_guns_lab.gd`](../sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab.gd) · [`valentina_guns_lab_hud.gd`](../sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab_hud.gd) | Escena aislada, `WEAPON_CATALOG` A/B, carga de `valentina_mecha_ring_packed.png`, selector de 10 skins sincronizadas y guardado directo en `.tres`. |
| **Suite de Verificación** | [`tests/sandbox/test_valentina_guns_lab.gd`](../tests/sandbox/test_valentina_guns_lab.gd) | Valida modo 3D por defecto, `has_ring_texture()`, *winding* compatible con `BoxMesh`, Z-sorting, `barrel_z`, recoil, 4 slots, skins, modo 2.5D y fallback legacy. |

---

## 2. Estándar 3D Cel-Shaded *ArcSys* en `SubViewport` (Giro 360° Real)

Para que cualquier arma futura gire en perspectiva 3D auténtica sin romper la estética anime 2D de Valentina v2, toda malla 3D debe cumplir este **Contrato Geométrico y de Materiales**:

### 2.1 Convención Espacial y Cámara (`OrbitalWeapon3DRenderer`)
- **Centro / Pivote `(0, 0, 0)`:** debe coincidir con el centro de masa o cámara del núcleo energético donde el arma pivota sobre el anillo orbital.
- **Orientación canónica:** cañón apuntando hacia **`-Z`** (`MUZZLE_LOCAL_POS = Vector3(0.0, 0.0, -2.18)`), arriba del arma en **`+Y`**, y espesor lateral en **`±X`**.
- **Envolvente segura del viewport:** la cámara usa `CAMERA_FOV_DEG = 30.0` y `CAMERA_DIST_Z = 9.8` en un `SubViewport` cuadrado de `256×256` (`span ≈ 5.25` unidades en `z = 0`). Mantén el radio máximo de la malla en **`≤ 2.2` unidades** desde el origen para evitar recortes en los bordes al apuntar a `45°` hacia la cámara.
- **Escala en pantalla:** `OrbitalWeaponRingController` escala el `Sprite2D` con `vp_scale = (_config.weapon_base_scale / 0.135) * 0.76 * persp_scale`, igualando `1:1` el tamaño del sprite `1024 px` con `weapon_base_scale = 0.135`.

### 2.2 Contrato de 3 Superficies para Sync Automático de Skins
Las superficies del `ArrayMesh` (o *material slots* de un `.glb`) deben seguir estrictamente este orden para que `apply_skin_palette(...)` sincronice las **10 skins** sin código extra:

| Índice | Constante | Rol Visual | Color en Skin Base (`is_base_skin`) | Mapeo con Skins (`PilotSkinPreset`) |
|---|---|---|---|---|
| `0` | `SURFACE_ARMOR` | Placas principales, rieles, aletas | `Color(0.88, 0.92, 0.97)` | `panel_color.lerp(Color(0.92, 0.94, 0.98), 0.25)` |
| `1` | `SURFACE_CHASSIS` | Cuna mecánica interna, soportes | `Color(0.12, 0.16, 0.25)` | `suit_dark_color` |
| `2` | `SURFACE_CRYSTAL` | Núcleo cristalino, conductos, puntas HDR | `Color(0.92, 0.14, 0.32)` | `accent_color` (+ pulso `fire_glow_color`) |

### 2.3 El Truco *ArcSys* de Doble Normal y *Winding*
1. **Iluminación facetada (`NORMAL`):** cada triángulo almacena su normal plana exacta (`fn = (c - a).cross(b - a).normalized()`), haciendo que `rail_lance_toon_3d.gdshader` corte sombras y brillos especulares en facetas nítidas tipo anime.
2. **Contorno sin grietas (`UV` / `UV2`):** extruir un contorno `cull_front` usando normales planas abre huecos en las esquinas. Por eso `RailLance3DMeshBuilder._commit_surface` suelda los vértices por posición (`roundi(v * 1000.0)`), promedia sus normales y guarda la normal suave directamente como flotantes crudos sin conversión sRGB en `UV = Vector2(sn.x, sn.y)` y `UV2 = Vector2(sn.z, 0.0)`. `rail_lance_outline_3d.gdshader` extruye `VERTEX += normalize(vec3(UV.x, UV.y, UV2.x)) * outline_width`.
3. **Regla de *Winding* Godot 4 (`cull_back`):** los triángulos frontales en Godot 4 deben ser **horarios (*clockwise*)** vistos desde afuera, de modo que `(c - a).cross(b - a)` apunte hacia el exterior (verificado contra `BoxMesh` en `test_valentina_guns_lab.gd`).

### 2.4 Acoplamiento Matemático Anillo 2D ↔ Cámara 3D
`OrbitalWeaponRingController` deriva la inclinación 3D real directamente desde la elipse configurada en `.tres`:

```gdscript
var ellipse_ratio: float = clampf(_config.ring_radius_y / maxf(_config.ring_radius_x, 1.0), 0.15, 1.0)
var elev_rad: float = asin(clampf(ellipse_ratio, 0.15, 0.98))
var view_basis: Basis = Basis(Vector3.BACK, -tilt_rad) * Basis(Vector3.RIGHT, elev_rad)
var ring_up_3d: Vector3 = (view_basis * Vector3.UP).normalized()
```

- Al rotar con `Basis.looking_at(aim_dir_3d, ring_up_3d)`, el lomo superior del arma siempre apunta hacia el "arriba" del plano orbital: cruza izquierda ↔ derecha suavemente en 3D sin *flip* repentino.
- El retroceso se ejecuta sobre la boca real en 3D (`_weapon_body.position.z = recoil * 0.38`, `rotation.x = recoil_pitch_rad`).
- La posición 2D de *muzzle flashes* y trazadores se obtiene proyectando `MUZZLE_LOCAL_POS` con `_camera.unproject_position(world_muzzle) - Vector2(size) * 0.5`.

### 2.5 Dos Caminos para Crear Futuras Armas 3D
- **Camino A — Malla Procedural (`ArrayMesh` GDScript):** duplica `rail_lance_3d_mesh_builder.gd`, reutiliza `_add_loft`, `_push_tri_outward` y `_commit_surface`, y define nuevas secciones transversales (`_hex_ring`, `_oct_ring`, `_box_ring`) repartidas en las 3 superficies. Ventaja: cero archivos binarios externos, peso mínimo y contorno *watertight* garantizado.
- **Camino B — Modelo `.glb` Externo (Blender):**
  1. Modela el arma con centro en `(0, 0, 0)`, apuntando en `-Z` y longitud total `~3.5–4.0` unidades (`r <= 2.2`).
  2. Separa exactamente **3 slots de material** (`0` armadura, `1` chasis, `2` emisivo/cristal) y triangula la malla.
  3. Para el contorno `rail_lance_outline_3d.gdshader`: hornea la normal suave promediada en `UV`/`UV2` vía script de exportación Blender (o modifica el outline para leer `COLOR` si se codifica como normal lineal), y aplica los 3 `ShaderMaterial` + `next_pass` sobre el `MeshInstance3D` cargado dentro de `OrbitalWeapon3DRenderer`.

---

## 3. Estándar del Asset Base 2D Óptimo & Pipeline Multi-Mapa

Antes de modelar una nueva arma en 3D (o para usarla directamente en modo **2.5D Multi-Mapa**), conviene generar primero una **vista maestra 2D limpia** que sirva tanto de *blueprint* de proporciones para el 3D como de entrada directa al compilador [`build_valentina_weapon.py`](../sandbox/pilot_rig_lab/tools/build_valentina_weapon.py).

### 3.1 Las 5 Reglas de Producción del Asset Base Óptimo
1. **Fondo gris medio uniforme `#808080`:** sin degradados, viñetas ni sombras proyectadas (permite extracción limpia de alfa por *flood-fill* desde bordes).
2. **Cero glow/bloom externo ni halos semitransparentes:** incluso el núcleo energético debe renderizarse con facetas 100% opacas y cerradas por tinta oscura; el bloom real lo añade Godot por shader (`ilm_mask.A` + `AgX`).
3. **Perfil horizontal puro apuntando a la derecha (`+X`):** sin manos, empuñaduras humanas innecesarias ni ángulos en escorzo; deja margen gris `#808080` alrededor.
4. **Tinta cerrada *ArcSys*:** contorno exterior e interior nítido en tinta oscura (`#121622`) para generar un `ink_sdf 2×` vectorial limpio.
5. **Separación estricta de 3 materiales cel-shaded (para `id_mask` automático):**
   - **Placas principales (`id_mask.G`):** plata/blanco frío `#E4ECF5..#FFFFFF` con facetas de sombra `#9FB0C8`.
   - **Chasis mecánico interno (`id_mask.B`):** azul marino pizarra `#1D273B..#2E3C56` (debe mantener `B >= R + 4` y valor `< 135` para separarse limpiamente de placas y tinta).
   - **Núcleo, conductos y acentos emisivos (`id_mask.R` + `ilm_mask.A`):** rojo carmesí-rubí saturado `#D91E48..#FF335C` (faceta especular `#FF8FA8`).

### 3.2 Plantilla de Prompt Maestro (Adaptable a cualquier arma)

```text
Generate a single clean 2D game-rig production asset sprite (16:9 landscape) of [WEAPON ARCHETYPE AND NAME] for anime space pilot [PILOT NAME] ([THEME]), strictly on a completely flat, uniform neutral medium-grey (#808080) background.

DESIGN:
- Pure horizontal side profile pointing straight RIGHT, centered nicely with comfortable grey padding on all sides (weapon occupies ~78% of width, centered vertically).
- Autonomous floating sci-fi weapon with NO human hands, NO stand, [NO pistol grip if autonomous].
- [DESCRIBE SILHOUETTE: rails/barrels, central crystal/energy chamber, rear stabilizer fins/thrusters].

CRITICAL PRODUCTION PIPELINE CONSTRAINTS (for automated alpha/ID/ILM/Ink SDF extraction):
- Background MUST be 100% flat uniform medium grey (#808080) with ZERO gradients, ZERO vignette, ZERO drop shadow, ZERO text, ZERO labels, ZERO grid lines, ZERO floating dust dots or sparkles.
- ZERO outer glow, ZERO bloom, ZERO soft fog, ZERO translucent halo bleeding into #808080. Energy cores must have crisp, solid, 100% opaque cel-shaded facets.
- Art style: Arc System Works / Guilty Gear Strive 2D anime cel-shaded game sprite, ultra-crisp closed dark ink outlines (#121622) and razor-sharp internal panel/facet lineart.
- STRICT 3-MATERIAL HARD CEL-SHADED COLOR SEPARATION:
  1) Base armor plates & fins: cool faceted silver-white (#E4ECF5 to #FFFFFF, shadow facets #9FB0C8).
  2) Inner mechanical chassis: deep dark navy-slate (#1D273B to #2E3C56).
  3) Accent energy core, conduits & tips: saturated vivid crimson-ruby (#D91E48 to #FF335C, bright facet #FF8FA8).
```

### 3.3 Compilación Offline Python (`build_valentina_weapon.py`)
Guarda el arte maestro en `sandbox/pilot_rig_lab/source_refs/<pilot>_weapons/<weapon_id>_master.jpg` y ejecuta:

```powershell
python sandbox/pilot_rig_lab/tools/build_valentina_weapon.py `
  --src sandbox/pilot_rig_lab/source_refs/<pilot>_weapons/<weapon_id>_master.jpg `
  --out-dir sandbox/pilot_rig_lab/combat_assets/<pilot>_planar/weapons `
  --name <weapon_id> `
  --target-width 1024 `
  --no-upscayl
```
*(Si Upscayl está instalado en `C:\Program Files\Upscayl\resources\bin\upscayl-bin.exe`, omite `--no-upscayl` para super-resolución `digital-art-4x` previa a la extracción).*

**Salidas generadas y contrato de carga:**
- `<weapon_id>.png`: Albedo recortado a `target_width` con *Voronoi RGB bleed*.
- `<weapon_id>_id_mask.png`: `R` acento/energía, `G` placas armadura, `B` chasis marino.
- `<weapon_id>_ilm_mask.png`: `R` especular, `G` AO/cel bias, `B` rim, `A` emisivo HDR.
- `<weapon_id>_ink_sdf.png`: SDF a **`2×`** (`±8.0` texels nativos). **Invariante:** cargar siempre sin mipmaps (`ImageTexture.create_from_image`) y muestrear con `textureLod(..., 0.0)` para mantener líneas nítidas a cualquier zoom.
- `<weapon_id>_meta.json`: dimensiones `size_px`, `pivot_u` (centroide automático de la cámara del núcleo) y `muzzle_u` (punta frontal).

---

## 4. Anillo Orbital IA Texturizado, Encastre *Over-Hug* y Fallback Procedural

### 4.1 Las 5 Reglas para Generar el Asset Maestro del Anillo (`1:1` sobre `#000000`)
1. **Relación `1:1` cenital ortográfica perfecta:** círculo matemático exacto centrado en `(50%, 50%)` ocupando `~84–90%` del lienzo para que nunca recorte bordes al rotar.
2. **Fondo negro puro `#000000` sin ruido ni texto:** cero etiquetas, rejillas ni viñetas (`build_orbital_ring_texture.py` recorta el negro automáticamente en alfa `0`).
3. **Centro completamente hueco (`~55–60%` de diámetro interior):** todo el detalle debe vivir en la banda anular exterior para dejar limpio al piloto en el centro.
4. **Separación estricta de 2 colores (para empaquetado de canales y 10 skins):**
   - **Estructura (`R`):** blanco-plata frío `#E6F0FF..#FFFFFF` (arcos blindados, líneas técnicas, micro-marcas).
   - **Acentos energéticos (`G`):** rojo carmesí-rubí saturado `#FF1F4B..#FF4068` (cheurones de fijación y sectores luminosos).
5. **Brecha radial limpia entre aro interior y exterior:** dejar una franja negra vacía entre el aro interior (ej. micro-marcas) y el aro exterior blindado permite al compilador separarlos en `B = 0 / 255` para contrarrotarlos en shader.

### 4.2 Plantilla de Prompt Maestro para Anillos Orbitales IA

```text
Generate a single clean 1:1 square 2D game-VFX production texture of a top-down orthographic circular orbital weapon ring matching [THEME / DESIGN STYLE], strictly on a completely pure pitch-black (#000000) background.

CRITICAL PRODUCTION CONSTRAINTS:
- Strictly 1:1 square aspect ratio, perfectly centered at exact image center (50%, 50%), outer ring diameter occupying ~84% of image width/height.
- COMPLETELY EMPTY PITCH-BLACK HOLLOW CENTER (inner open diameter ~58% of image width — ZERO elements inside the center).
- Pure flat 2D top-down orthographic view (perfect mathematical circle, NOT tilted or oval).
- ZERO text, ZERO letters, ZERO numbers, ZERO labels, ZERO grid lines, ZERO vignette. Background must be 100% pure #000000 black.
- Clean empty black radial gap separating an inner precision ring (fine micro-ticks) from an outer armored ring (allowing independent counter-rotation).
- STRICT 2-COLOR HIGH-CONTRAST SEPARATION:
  1) Structural tactical ring: razor-sharp crisp white-silver (#E6F0FF to #FFFFFF).
  2) Energy / lock-on accents: vivid saturated crimson-ruby (#FF1F4B to #FF4068).
```

### 4.3 Compilación Offline (`build_orbital_ring_texture.py`) y Shader `orbital_ring_25d.gdshader`
Guarda el arte maestro en `sandbox/pilot_rig_lab/source_refs/<pilot>_weapons/<ring_id>_master.jpg` y ejecuta:

```powershell
python sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py `
  --src sandbox/pilot_rig_lab/source_refs/<pilot>_weapons/<ring_id>_master.jpg `
  --out-dir sandbox/pilot_rig_lab/combat_assets/<pilot>_planar/weapons `
  --name <ring_id> `
  --size 1024
```

**Empaquetado RGBA resultante (`<ring_id>_packed.png` + `<ring_id>_meta.json`):**
- `R`: luminancia estructural plata (`0..255`).
- `G`: energía/cheurones carmesí (`0..255`).
- `B`: máscara de zona radial (`255` aro exterior donde `rr_uv >= split_uv_radius`, `0` aro interior).
- `A`: alfa limpio `max(R, G)` recortando `#000000`.
- `*_meta.json`: registra `outer_uv_radius` (`0.445`), `split_uv_radius` (`0.3171` en `valentina_mecha_ring`) y `main_rail_uv_radius` (`0.3827`, igualado en `OrbitalWeaponRingController.MAIN_RAIL_UV_RADIUS`).

**Cómo proyecta `orbital_ring_25d.gdshader` en tiempo real:**
1. **Corte atrás/delante + contrarrotación:** recorta `UV.y < 0.5` (`is_front_half = false`) vs `UV.y >= 0.5` (`is_front_half = true`) y rota `p = UV - 0.5` por `outer_rot_rad` (`B > 0.5`) e `inner_rot_rad` (`B <= 0.5`) antes de la escala elíptica del `Sprite2D`.
2. **Encastre *Over-Hug* por profundidad real (`over_hug_pass`):** cerca del ángulo de cada arma (`slot_angles`), compara `p.y` contra `sin(slot_angle) * main_rail_uv_radius`:
   - La pasada base (`z = 2 / 10`) atenúa esa zona con `(1.0 - over_w)`.
   - La pasada `over_hug_pass = true` (`z = 4` detrás del rig `z = 5`, y `z = 12` sobre el arma delantera `z = 11`) dibuja con `over_w` el labio cercano del anillo abrazando la mitad inferior del arma mientras la mitad superior sobresale limpia por arriba (cero doble alfa).
3. **Pulso HDR, Anclajes y Sync de Skins:** `slot_pulses` enciende el sector bajo cada arma al disparar; con `ring_use_texture = true` se dibujan halos energéticos suaves (`_draw_soft_anchor_halos`) + polvo estelar discreto (`_draw_ring_stardust`). Si `ring_use_texture = false`, vuelve al modo procedural (*Híbrido Astrolabio-Minimalista* con cristales romboidales). Con `ring_follow_skin = true`, tanto la estructura del anillo como los acentos HDR y trazadores *lance-beam* adoptan la skin activa.

---

## 5. Checklist Rápido para Agregar una Nueva Arma o Anillo

1. **Nueva Arma (Arte y/o 3D):**
   - Genera el maestro `#808080` siguiendo la Sección 3.1 y compílalo con `build_valentina_weapon.py`.
   - Para soporte 3D completo (recomendado), crea `<weapon_id>_3d_mesh_builder.gd` siguiendo el contrato de 3 superficies y doble normal (`UV`/`UV2`) de la Sección 2.
2. **Nuevo Anillo IA (Opcional):**
   - Genera la textura cenital `1:1` sobre `#000000` siguiendo la Sección 4.1 y compílala con `build_orbital_ring_texture.py`.
   - Verifica `main_rail_uv_radius` en `*_meta.json` y enlaza la textura vía `RING_TEXTURE_PATH` o `ctrl.set_ring_texture(tex)`.
3. **Registro en Guns Lab:**
   - Añade la entrada a `WEAPON_CATALOG` en [`valentina_guns_lab.gd`](../sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab.gd) (modo `"3d_<weapon_id>"` o entrada multi-mapa con `path`, `id_mask`, `ilm_mask`, `ink_sdf`).
   - Calibra `ring_radius_x`, `ring_radius_y`, `weapon_base_scale` y `weapon_radial_offset_px` (`0.0` para montar sobre el riel) desde el HUD interactivo y pulsa **Guardar `.tres`**.
4. **Verificación obligatoria:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_guns_lab" -VerboseOutput
   powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"
   ```
