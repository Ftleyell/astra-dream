# Guía Técnica y Hoja de Ruta — 3D Lab & Alas Psíquicas 3D Cel-Shaded (*Astral Seraph*)

> **Estado:** **Estandarizado y verificado en `PilotRigLab`** (`PlanarCombatRig.enable_3d_wings`, `PilotRigProfile.wings_3d_config`, `planar_combat_rig_proto.tscn`, `valentina_guns_lab.tscn`, `valentina_3d_lab.tscn`).
> **Guía Maestra de Creación Multi-Piloto:** [`docs/VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md)
> **Escena de Laboratorio:** [`sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.tscn`](../sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.tscn)
> **Suite de Verificación:** [`tests/sandbox/test_valentina_3d_lab.tscn`](../tests/sandbox/test_valentina_3d_lab.tscn) (`tools/run_tests.ps1 -Test "valentina_3d_lab"`)
> **Documentos relacionados:** [`docs/VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md) · [`docs/VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) · [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md)

---

## 1. Propósito y Arquitectura del `3D Lab`

El **`3D Lab`** extiende el método *ArcSys* 3D Cel-Shaded inaugurado con el *Rail-Lance* del *Guns Lab* hacia elementos *hard-surface* articulados que rodean al piloto 2D (`PlanarCombatRig`). Su primer prototipo funcional son las **Alas Psíquicas 3D *"Astral Seraph"*** (12 cuchillas cristalinas independientes con giro real 360°, Z-sorting dinámico atrás/delante del rig 2D y 6 animaciones 3D).

### Arquitectura Dual-Pass `SubViewport` (Oclusión Real 3D ↔ Rig 2D)

Para que cualquier cuchilla cruce suavemente por detrás o por delante de Valentina 2D (`z_index = 5`) tanto al girar en 360° como durante maniobras envolventes (*Escudo Aegis*, *Vórtice 360°*), el controlador utiliza **2 `SubViewport` sincronizados** (`768×768`, `transparent_bg`, `use_hdr_2d`, `MSAA_4X`) compartiendo cámara (`FOV = 32°`, `CAMERA_DIST_Z = 14.5`) con pasada 2D post-process unificada (`astral_wing_post_2d.gdshader`):

```text
PilotWings3DConfig (.tres) ──► AstralWings3DController (Node2D)
                                ├── Wings3DFXBack + Line2D atrás   (z_index = 2, estelas & polvo trasero)
                                ├── Wings3DBackSprite              (z_index = 3 ◄── SubViewport Back: cuchillas con world_z < 0)
                                ├── [PlanarCombatRig externo:       z_index = 5]
                                ├── Wings3DFrontSprite             (z_index = 7 ◄── SubViewport Front: cuchillas con world_z >= 0)
                                └── Wings3DFXFront + Line2D frente (z_index = 8, estelas, polvo & trazadores HDR)
```

- Cada una de las **12 cuchillas** evalúa su profundidad 3D (`mid_world.z`) frame a frame y conmuta visibilidad entre `Back` y `Front` sin recortes ni saltos de capa.
- Las puntas cristalinas 3D (`TIP_LOCAL_POS`) se proyectan a coordenadas 2D exactas mediante `Camera3D.unproject_position(...)` para anclar las **12 estelas `Line2D`**, el **polvo estelar 4-puntas** y los **trazadores láser HDR** de *Full Burst*.

### Inventario de Archivos del `3D Lab`

| Componente | Archivo | Rol |
|---|---|---|
| **Esquema Data-Driven** | [`sandbox/pilot_rig_lab/data/pilot_wings_3d_config.gd`](../sandbox/pilot_rig_lab/data/pilot_wings_3d_config.gd) | Recurso `PilotWings3DConfig` (escala, offsets, barrido, ondas, contorno, rim, HDR, estelas y polvo estelar). |
| **Preset Calibrado** | [`sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_wings_3d.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_wings_3d.tres) | Preset WIP para Valentina v2 calibrado 1:1 contra `wings_metadata.json`. |
| **Malla 3D Procedural** | [`sandbox/pilot_rig_lab/3d_lab/astral_wings_3d_mesh_builder.gd`](../sandbox/pilot_rig_lab/3d_lab/astral_wings_3d_mesh_builder.gd) | `AstralWings3DMeshBuilder`: construye 3 tiers de `ArrayMesh` cacheados con normales planas + suaves en `UV`/`UV2` y *winding* horario Godot 4. |
| **Controlador Dual-Pass** | [`sandbox/pilot_rig_lab/3d_lab/astral_wings_3d_controller.gd`](../sandbox/pilot_rig_lab/3d_lab/astral_wings_3d_controller.gd) | `AstralWings3DController`: 2 `SubViewport`, 12 cuchillas articuladas, 6 animaciones, sync de 10 skins y VFX 3D→2D. |
| **Shaders 3D + Post 2D** | [`3d_lab/astral_wing_toon_3d.gdshader`](../sandbox/pilot_rig_lab/3d_lab/astral_wing_toon_3d.gdshader) · [`3d_lab/astral_wing_outline_3d.gdshader`](../sandbox/pilot_rig_lab/3d_lab/astral_wing_outline_3d.gdshader) · [`3d_lab/astral_wing_post_2d.gdshader`](../sandbox/pilot_rig_lab/3d_lab/astral_wing_post_2d.gdshader) | Cel-shading 3 bandas + *crease ink* interno + canales HDR con flujo raíz→punta + rebote carmesí + contorno 3D caligráfico índigo↔ciruela + post-pass 2D (`CAS Sharpen`, borde *pixel-perfect* y Micro-Rim estilo `pilot_rig_pass2.gdshader`). |
| **Escena & HUD** | [`valentina_3d_lab.tscn`](../sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.tscn) · [`valentina_3d_lab.gd`](../sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.gd) · [`valentina_3d_lab_hud.gd`](../sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab_hud.gd) | Escena aislada con Valentina v2, 6 animaciones, Turntable 360°, vuelo WASD, comparativa A/B contra alas 2D, skins y guardado `.tres`. |
| **Suite Automatizada** | [`tests/sandbox/test_valentina_3d_lab.gd`](../tests/sandbox/test_valentina_3d_lab.gd) · [`test_valentina_3d_lab.tscn`](../tests/sandbox/test_valentina_3d_lab.tscn) | Valida 12 cuchillas, 3 superficies, *winding* vs `BoxMesh`, Z-sorting Sur/Norte/Este/Aegis, las 6 animaciones, recoil y sync de skins. |

---

## 2. Contrato Geométrico 3D y Fidelidad 1:1 (*Astral Seraph*)

1. **Proporciones y arco exacto de `wings_metadata.json`:**
   - **Shard 0 (`s0`, Tier 0):** brazo cristalino segmentado en 3 piezas (daga basal con chevron carmesí + antebrazo acodado con espuela superior + lanza principal con costura diagonal, vena en `Y` y punta rubí asimétrica) montado a **`+48.8°`** y longitud normalizada `1.00`.
   - **Shards 1–5 (`s1..s5`, Tiers 1–2):** 5 dagas cristalinas bipunta blanco-plata hielo (raíz afilada sin abrazaderas mecánicas gruesas), flotando en el arco curvo bajo `s0` (`+31.2°`, `+12.3°`, `-15.4°`, `-37.3°`, `-61.3°`), con **vena carmesí en `Y`** en micro-relieve (cero *Z-fighting*) y **punta rubí asimétrica** ocupando el bisel inferior (`-Y`) mientras el filo superior (`+Y`) permanece blanco-plata.
2. **Simetría `±Z` y espejado seguro (`det = +1.0`):**
   - Toda sección transversal de las cuchillas es simétrica respecto al plano `Z = 0`.
   - El ala izquierda nunca usa escala negativa (`scale.x = -1`), ya que invertiría el *winding* de `cull_back` y el contorno `cull_front`. En su lugar rota por `Basis(Vector3.UP, PI - sweep_rad)` manteniendo determinante `+1.0`.
3. **Contrato de 3 Superficies (Sync automático de 10 skins):**
   - `0` (`SURFACE_ARMOR`): placas cristalinas blanco-plata hielo (`panel_color`).
   - `1` (`SURFACE_CHASSIS`): nervio interno mínimo oscuro (`suit_dark_color`).
   - `2` (`SURFACE_CRYSTAL`): venas en `Y`, costuras y puntas rubí HDR (`accent_color` + pulso `fire_glow_color`).

---

## 3. Animaciones 3D y Controles del Laboratorio

| Tecla | Modo (`AnimState`) | Comportamiento 3D |
|---|---|---|
| **`1`** | `IDLE_ZERO_G` | Respiración orbital, `s0` regio y onda psíquica propagada en `s1..s5` con micro-torsión de facetas. |
| **`2`** | `CRUISE_BOOST` | Barrido aerodinámico hacia atrás, vibración de empuje, HDR elevado y reacción Newtoniana a `WASD`. |
| **`3`** | `SERAPH_BLOOM` | Ciclo dramático: anticipación de repliegue seguida de apertura serafín con *overshoot* elástico y pulso HDR. |
| **`4`** | `AEGIS_GUARD` | Las 12 cuchillas cruzan **adelante de Valentina** (`Back → Front`) y forman un escudo cristalino giratorio 3D. |
| **`5`** | `FULL_BURST` | Las 12 cuchillas suben en arco *funnel*, **apuntan en 3D real al mouse** y disparan ráfagas con recoil axial y trazadores láser HDR. |
| **`6`** | `VORTEX_SPIN` | Doble hélice 3D orbitando 360° alrededor del piloto cruzando continuamente detrás y delante. |

**Atajos adicionales:** `Space` / Click izquierdo (pulso o salva completa) · `WASD` / Flechas (simular vuelo) · `T` (Turntable 360° automático) · `B` (comparativa A/B directa contra las alas 2D) · Rueda del mouse (zoom).

---

## 4. Criterio de Escalabilidad para Futuros Experimentos en `3D Lab`

- **Candidatos ideales (éxito alto):** alas cristal/mecha, arsenal orbital/drones/*funnels*, escudos geométricos, satélites/estaciones y jefes o élites *hard-surface*.
- **Candidatos no recomendados en 3D procedural:** cuerpo/rostro orgánico del piloto (mantener `PlanarCombatRig` 2D/2.5D + Face Live) y telas/capas suaves (preferir mallas 2D deformables o cintas).
- **Regla GPU de `SubViewport`:** mantener `≤ 10` `SubViewport` simultáneos (piloto, armas, alas, jefe/satélite cercano). Nunca asignar un `SubViewport` propio por enemigo a enjambres ni a proyectiles danmaku (estos permanecen estrictamente en `BulletServer`).

---

## 5. Estado de Estandarización y Próximos Pasos (Producción)

- **Estandarizado en `PilotRigLab`:**
  - `PilotRigProfile` (`wings_3d_config`, `prefer_3d_wings`) y `PlanarCombatRig` (`enable_3d_wings`, `set_3d_wings_enabled`, `get_3d_wings_controller`, sync de skins, iluminación cósmica `Cosmos`, Z-layering relativo `(-2,-1,1,2)`, compensación `1/display_scale` y pulsos en dash/air-brake).
  - Activo por defecto en la Arena Principal (`planar_combat_rig_proto.tscn`), en el Cosmos Lighting Lab (`cosmos_lighting_lab/valentina_cosmos_lab.tscn`) y enlazado al toggle de alas en `valentina_guns_lab.tscn`.
  - La guía paso a paso para crear nuevos sets de alas 3D en futuros pilotos reside en [`docs/VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md).
- **Pendiente al promocionar a producción (`scenes/combat/player/`):**
  - [ ] Conectar modos de habilidad de combate (*Aegis Guard*, *Full Burst*, *Seraph Bloom*) al `WeaponController` / habilidades activas del jugador.
  - [ ] Respetar `SettingsManager` para conmutar resolución/LOD o fallback 2D en hardware de gama baja.
  - [ ] Reutilizar el `3D Lab` para futuros drones escudo, satélites o jefes mecha *ArcSys*.

---

## 6. Verificación

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_3d_lab"
```
