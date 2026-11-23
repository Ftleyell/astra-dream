# Guía Maestra de Creación y Estandarización — Alas 3D Cel-Shaded (*ArcSys*) para Futuros Pilotos

> **Estado:** **Estándar oficial Multi-Piloto en `PilotRigLab`** (`PlanarCombatRig.enable_3d_wings`, `PilotRigProfile.wings_3d_config`, `planar_combat_rig_proto.tscn`, `valentina_guns_lab.tscn`, `valentina_3d_lab.tscn`).
> **Implementación de Referencia:** **Valentina v2 — *Astral Seraph 3D*** (`astral_wings_3d_mesh_builder.gd` + `astral_wings_3d_controller.gd` + `valentina_v2_wings_3d.tres`).
> **Documentos relacionados:** [`docs/VALENTINA_3D_LAB_SPEC.md`](VALENTINA_3D_LAB_SPEC.md) · [`docs/VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md) · [`docs/PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md)

---

## 1. Filosofía Visual: Por qué el 3D y el 2D se Potencian Mutuamente

El objetivo de este estándar no es que las alas parezcan "objetos 3D pegados" detrás de un dibujo 2D, sino lograr la sinergia *Guilty Gear Strive / Arc System Works*:
1. **Misma resolución percibida:** `SubViewport` a **`768×768` + `MSAA_4X` + `use_hdr_2d`** escalado a `512/768` + **`CAS Sharpen`** en 2D → cero bordes blandos al hacer zoom.
2. **Misma tinta caligráfica que `PlanarCombatRig`:** contorno 3D *inverted-hull* + contorno 2D *pixel-perfect* modulados por dirección de luz (más grueso en sombra `#0C0A18`, más fino y cálido en luz `#1C0912`), replicando exactamente `pilot_rig_pass2.gdshader`.
3. **Tinta interna y canales tallados:** cada canal emisivo lleva una **cuna de tinta oscura** (`SURFACE_CHASSIS`) debajo + **tinta de aristas en facetas** (`fwidth(NORMAL)` en `astral_wing_toon_3d.gdshader`), imitando el `Ink SDF 2×` de Valentina 2D.
4. **Iluminación viva HDR + Rebote:** los canales emisivos superan el umbral `1.08` de `AgX` Bloom con una onda energética raíz→punta (`UV2.y`) y proyectan un rebote suave del color acento sobre las placas adyacentes.

---

## 2. Paso 1 — Blueprint 2D y Extracción de Medidas Exactas

Antes de tocar código 3D o Blender, define la silueta exacta de las alas en **vista frontal (`0°`, lado derecho `+X`)**:

1. **Si ya existe un arte 2D / `wings_metadata.json`:**
   - Para cada cuchilla/pluma `s0..sN`, calcula su vector raíz→punta `(dx, -dy)` (invirtiendo `Y` porque en 3D `+Y` apunta hacia arriba):
     - **Longitud normalizada (`L`):** asigna `~2.00–2.20` unidades 3D a la cuchilla hero principal (`s0`) y escala el resto proporcionalmente (`length_i / length_0`).
     - **Ángulo en reposo (`SLOT_REST_ANGLES_DEG`):** `rad_to_deg(atan2(-dy, dx))`.
     - **Desfase de raíz (`SLOT_REST_OFFSETS`):** convierte `rest_offset_px` a unidades 3D con el factor `~0.0034 units/px` (para `tex_scale = 3`, `display_scale = 0.378`).
2. **Si diseñas el ala desde cero:**
   - Mantén el alcance máximo horizontal + vertical dentro de **`≤ 3.6` unidades 3D** desde el origen `(0, 0, 0)` para que nunca recorte los bordes del `SubViewport` (`FOV = 32°`, `CAMERA_DIST_Z = 14.5`, semialtura visible `4.16` unidades).
   - Reserva el rol de **Shard 0 (`s0`)** para el marco/brazo dominante superior y distribuye `s1..s5` en un arco curvo limpio debajo, sin amontonar piezas sobre la columna vertebral del piloto (`root_spread_x ≈ 0.38–0.52`).

---

## 3. Paso 2 — Contrato Obligatorio de Geometría 3D

Toda malla de ala (sea **Camino A: Procedural GDScript** o **Camino B: Modelo `.glb` de Blender**) **DEBE** cumplir estas 6 reglas invariantes:

### Regla 1 — Convención de Ejes Locales
- **`+X`**: eje de la cuchilla desde la raíz (`x = 0.0`) hasta la punta (`x = length`).
- **`+Y`**: borde de ataque / filo superior de la cuchilla.
- **`-Y`**: borde posterior / bisel de punta emisiva.
- **`±Z`**: espesor de la cuchilla.

### Regla 2 — Simetría en `Z = 0` y Prohibición de Escala Negativa
- **NUNCA** uses `scale.x = -1` para espejar el ala izquierda: una matriz con determinante `-1` invierte el *winding* de los triángulos y rompe `cull_back` y el contorno `cull_front`.
- Construye secciones transversales simétricas respecto al plano `Z = 0`. Así el ala izquierda rota con `Basis(Vector3.UP, PI - sweep_rad)`, preservando determinante **`+1.0`** y exactamente la misma polaridad (`+Y` filo superior, `-Y` punta emisiva).

### Regla 3 — *Winding* Horario Godot 4 (`cull_back`)
- En Godot 4, la normal saliente de `SurfaceTool` es `(c - a).cross(b - a)`.
- En generadores procedurales, pasa siempre cada triángulo por `_push_tri_outward(tris, a, b, c, volume_center)` y verifica contra `BoxMesh` en el test unitario.

### Regla 4 — Doble Normal *ArcSys* + Progreso de Cuchilla en `UV`/`UV2`
Cada vértice empaqueta 3 datos críticos sin texturas extra:
- `NORMAL`: **normal plana del triángulo** → cortes cel-shading nítidos estilo anime y detección automática de aristas (`fwidth(NORMAL)`).
- `UV = Vector2(sn.x, sn.y)` y `UV2.x = sn.z`: **normal suave promediada** por posición soldada (`roundi(v * 1000.0)`) → extrusión del contorno *inverted-hull* 100% cerrada sin grietas en aristas duras.
- `UV2.y = clampf(v.x / blade_length, 0.0, 1.0)`: **progreso normalizado raíz→punta** → alimenta la onda de flujo energético y el realce HDR en la punta.

### Regla 5 — Contrato de 3 Superficies (Sync Automático de 10 Skins)
| Índice | Constante | Rol Visual | Mapeo con `PilotSkinPreset` |
|---|---|---|---|
| `0` | `SURFACE_ARMOR` | Placas principales (cristal, metal, plumas blindadas) | `panel_color.lerp(Color(0.92, 0.94, 0.98), 0.25)` |
| `1` | `SURFACE_CHASSIS` | Cunas de tinta oscura alrededor de canales, costuras y nervios internos | `suit_dark_color` |
| `2` | `SURFACE_CRYSTAL` | Venas luminosas, núcleos, puntas cristalinas HDR | `accent_color` (+ pulso `fire_glow_color`) |

### Regla 6 — Técnica de Canales Iluminados Enmarcados (`_add_framed_vein`)
Para que venas, runas o circuitos rojos/cian se lean con claridad cristalina sin *Z-fighting*:
1. Coloca primero una tira oscura en `SURFACE_CHASSIS` con `half_w * 1.46` y `half_z * 0.92` (la **cuna de tinta**).
2. Superpón encima la tira emisiva en `SURFACE_CRYSTAL` con `half_w` y `half_z` (`~1.15–1.24 ×` el espesor de la placa base).
3. En cortes diagonales entre placa y punta emisiva (ej. plata ↔ rubí), añade una tira fina (`0.040 * W`) en `SURFACE_CHASSIS` para replicar el entintado interno 2D.

---

## 4. Paso 3 — Dos Caminos para Crear un Nuevo Set de Alas 3D

### Camino A — Procedural GDScript (Recomendado para cristal, energía, espadas, mecha)
1. Duplica [`sandbox/pilot_rig_lab/3d_lab/astral_wings_3d_mesh_builder.gd`](../sandbox/pilot_rig_lab/3d_lab/astral_wings_3d_mesh_builder.gd) como `<pilot>_wings_3d_mesh_builder.gd`.
2. Reutiliza íntegros `_crystal_ring`, `_add_loft`, `_push_tri_outward`, `_add_vein_strip`, `_add_framed_vein` y `_commit_surface`.
3. Rediseña solo `_build_hero_shard_s0` y `_build_crystal_dagger_shard` (o añade los tiers que necesite el piloto) y ajusta `TIER_LENGTHS`, `TIER_WIDTHS`, `TIER_THICKNESSES`.
4. Ventajas: cero binarios externos, peso mínimo en repo, *watertight* y simetría `±Z` garantizadas.

### Camino B — Modelado en Blender (`.glb`) para siluetas curvas o complejas
1. Modela cada tier de cuchilla alineado en `+X` (raíz en `(0, 0, 0)`, punta en `(+L, 0, 0)`), simétrico en `Z = 0` y con longitud `~1.0–2.2` unidades.
2. Asigna exactamente **3 slots de material** en orden `0: Armor`, `1: Chassis/InkFrame`, `2: Crystal/HDR`.
3. Triangula la malla, guarda caras planas en `NORMAL` y ejecuta un pequeño script de exportación en Blender que hornee:
   - `UV0 = (smooth_normal.x, smooth_normal.y)`
   - `UV1 = (smooth_normal.z, clamp(v.x / L, 0.0, 1.0))`
4. Importa el `.glb` en Godot y asigna los 3 `ShaderMaterial` (`astral_wing_toon_3d.gdshader` + `next_pass = astral_wing_outline_3d.gdshader`) exactamente igual que en `AstralWings3DController._build_blades()`.

---

## 5. Paso 4 — Stack de Shaders y Post-Pass 2D Unificado

Reutiliza sin duplicar los 3 shaders estándar de `sandbox/pilot_rig_lab/3d_lab/`:
1. **[`astral_wing_toon_3d.gdshader`](../sandbox/pilot_rig_lab/3d_lab/astral_wing_toon_3d.gdshader):** cel-shading 3 bandas, *crease ink* en facetas (`fwidth(NORMAL)`), canales HDR con onda raíz→punta (`UV2.y`), rebote cromático en placas plata e iluminación dinámica `Cosmos`.
2. **[`astral_wing_outline_3d.gdshader`](../sandbox/pilot_rig_lab/3d_lab/astral_wing_outline_3d.gdshader):** contorno *inverted-hull* caligráfico modulando grosor y color (`#0C0A18` sombra ↔ `#1C0912` luz).
3. **[`astral_wing_post_2d.gdshader`](../sandbox/pilot_rig_lab/3d_lab/astral_wing_post_2d.gdshader):** aplicado a `_back_sprite` y `_front_sprite`; ejecuta `CAS Sharpen` con protección HDR, contorno exterior *pixel-perfect* y Micro-Rim dual.

---

## 6. Paso 5 — Calibración `.tres` e Integración Automática en `PlanarCombatRig`

1. **Crea el preset `.tres` del piloto:** duplica [`valentina_v2_wings_3d.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_wings_3d.tres) en `sandbox/pilot_rig_lab/pilots/<pilot_id>/<pilot_id>_wings_3d.tres`.
2. **Enlaza el recurso en `PilotRigProfile`:** abre `<pilot_id>_profile.tres` y asigna:
   - `wings_3d_config = <pilot_id>_wings_3d.tres`
   - `prefer_3d_wings = true`
3. **Activa en cualquier instancia de `PlanarCombatRig`:**
   ```gdscript
   rig.pilot_profile = profile
   rig.enable_3d_wings = true
   ```
   `PlanarCombatRig` se encarga automáticamente de:
   - Montar `AstralWings3DController` compensando `scale = 1.0 / display_scale`.
   - Configurar Z-layering relativo `(-2, -1, 1, 2)` alrededor de `UnifiedCharacterGroup` (`z_index = 0`), respetando la invariante del `CanvasGroup`.
   - Sincronizar orientación 8-dir → yaw 3D continuo, velocidad de vuelo (`IDLE_ZERO_G` ↔ `CRUISE_BOOST`), estelas compensadas en mundo, **10 skins**, **iluminación cósmica `Cosmos`**, y pulsos HDR en `trigger_dash_burst()` / `trigger_air_brake()`.
4. **Calibra visualmente en el `3D Lab`:** abre [`valentina_3d_lab.tscn`](../sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.tscn), ajusta sliders en tiempo real (escala, barrido, contorno 3D, caligrafía, *crease ink*, glow HDR, Post-Pass 2D), compara con **`B`** y guarda directo con **`Guardar .tres`**.

---

## 7. Reglas de Rendimiento GPU y Checklist de Verificación

### Regla de Presupuesto `SubViewport`
- Cada rig con alas 3D usa **2 `SubViewport` (`768×768`)** (`Back` y `Front`).
- **Permitido:** piloto jugador, jefes/rivales héroe, arena principal (`planar_combat_rig_proto`), Guns Lab y 3D Lab (`≤ 10 SubViewport` simultáneos).
- **Prohibido:** activar `enable_3d_wings = true` en escenas con 8+ rigs simultáneos (como la brújula de `planar_anim_test.tscn`) o en enjambres masivos de enemigos.

### Checklist Obligatorio antes de Cerrar un Nuevo Set de Alas 3D
- [ ] **3 superficies** (`0, 1, 2`) presentes en cada tier y validadas en test.
- [ ] ***Winding* horario** validado contra `BoxMesh` y determinante `+1.0` en ambos lados.
- [ ] **Z-sorting real** verificado: Sur `0/12`, Norte `12/0`, Este `6/6`, Aegis `12/0`.
- [ ] **Sync de skins e iluminación `Cosmos`** funcionando sin errores en `PlanarCombatRig`.
- [ ] **Verificación con el arnés oficial:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_3d_lab"
  powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"
  powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_guns_lab"
  powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"
  ```
