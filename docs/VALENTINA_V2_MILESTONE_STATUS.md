# Valentina v2 — Estado de Milestone y Hoja de Ruta (`PilotRigLab`)

> **Propósito:** Índice ejecutivo liviano del milestone alcanzado en **Valentina v2 (8-Dir Nativo)** bajo `sandbox/pilot_rig_lab/`.
> Permite retomar el desarrollo en sesiones futuras con cero exploración ciega y saber qué está cerrado, qué labs/tests existen y cuáles son los siguientes pasos hacia producción.
> **Reglas de edición y tabla contractual:** [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md)

---

## 1. Resumen del Milestone Alcanzado (Cerrado y Verificado)

| Área | Estado | Artefactos Clave | Especificación Técnica |
|---|---|---|---|
| **Rig 8-Dir Nativo + Mallas + 18 Huesos** | **Cerrado** | `planar_combat_rig.gd`, `planar_rig_mesh_builder.gd`, `planar_rig_view_router.gd` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Máscaras HQ + Ink SDF 2× (65 mapas)** | **Cerrado** | `combat_assets/valentina_v2_planar/**`, `tools/ink_hq_pipeline.py` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Shaders Cel 2.5D + 3 Estilos + 10 Skins + 10 Pelos** | **Cerrado** | `pilot_rig_stylizer.gdshader`, `pilot_rig_pass2.gdshader`, `data/styles/*.tres` (`00_original`, `01_valentina_definitive`, `02_valentina_razor_sharp`) | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Animación Data-Driven (6 sistemas `.tres`)** | **Cerrado** | Pose Base Zero-G, Idle 3-Capas, Locomoción/Freno, Kiting 360° Hover-Slide, Giros Snappy 2.5D + Whip Cervical, Jiggle Busto/Glúteos | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Rig Facial Vivo + Cabello 3-Zonas + Ojos Amatista** | **Cerrado** | `planar_rig_face_controller.gd`, `face_lab/`, `valentina_v2_face_anim.tres`, `rig_face_live.gdshaderinc` | [`VALENTINA_V2_FACE_RIG_REFERENCE.md`](VALENTINA_V2_FACE_RIG_REFERENCE.md) |
| **Alas Psíquicas & Propulsión Base Multi-Piloto** | **Cerrado** | `valentina_base_propulsion_controller.gd`, `wing_red_glow.gdshader`, `valentina_v2_base_propulsion.tres`, `tools/build_valentina_v2_wings.py` | [`VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) |
| **VFX Power-Up Sandevistan (Estela Ping-Pong)** | **Cerrado (I+D)** | `vfx_lab/sandevistan_trail_controller.gd`, `sandevistan_*.gdshader`, `valentina_v2_propulsion_vfx.tres` | [`VALENTINA_PROPULSION_VFX_SPEC.md`](VALENTINA_PROPULSION_VFX_SPEC.md) |
| **Backup Inmutable de Baseline** | **Cerrado** | `sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/` + tag Git `valentina-v2-clean-baseline` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |

---

## 2. Mapa de Laboratorios Interactivos y Suites de Prueba

### Escenas de Laboratorio (`sandbox/pilot_rig_lab/`)
1. **Arena Principal del Rig:** `proto/planar_combat_rig_proto.tscn` — Rig completo (8-Dir, animación data-driven, rostro vivo, alas psíquicas base, skins/pelos/estilos).
2. **Laboratorio de Animación (6 pestañas):** `proto/planar_anim_test.tscn` — Calibración y guardado `.tres` de Pose Base, Idle, Vuelo/Freno, Giros, Jiggle y Kiting 360°.
3. **Laboratorio Facial Aislado:** `face_lab/valentina_face_lab.tscn` — Hero Close-Up, Galería 8-Dir, expresiones, cabello 3-zonas y guardado `.tres`.
4. **Laboratorio A/B de Shaders:** `shader_lab/planar_shader_lab.tscn` — Comparativa A/B, luz rotatoria, Rayos-X `0..6` y guardado `.tres`.
5. **Laboratorio VFX Alas + Sandevistan:** `vfx_lab/valentina_vfx_lab.tscn` — Calibración de alas base, estela Sandevistan, danmaku simulado y guardado `.tres`.

### Comandos Rápidos de Verificación (`tests/sandbox/`)
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_face_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"
```

---

## 3. Próximos Pasos (Backlog Ordenado)

### Fase A — Animaciones de Combate (Aditivas en `.tres`)
1. **Etapa 4 — Maniobras de Impulso (`DASH_BOOST`, `AIR_BRAKE` explosivo, `LAUNCH`):** overlays aditivos temporizados con curva *anticipation-overshoot*, refuerzo 2.5D (`torso_trap`), compresión distal y disparo de whiplash/afterimage.
2. **Etapa 5 — Reacción de Combate (`ATTACK_RECOIL`, `HIT_REACT`):** micro-retroceso direccional hacia `aim_dir` / `-hit_dir` acoplado a `trigger_impact_frame()`, `hit_flash` y micro-gestos faciales (`planar_rig_face_controller.gd`).

### Fase B — Promoción Controlada de Sandbox a Producción (`scenes/combat/player/`)
> **Regla vigente:** `sandbox/pilot_rig_lab/` sigue estrictamente aislado hasta ejecutar esta promoción.

Checklist previo a enlazar el rig en `scenes/combat/player/`:
- [ ] **Empaquetado de producción:** definir ubicación destino (p. ej. `scenes/combat/player/rig/` + `resources/pilots/valentina_v2/`) copiando únicamente runtime + assets compilados (nunca `source_refs/`, `tools/.venv/`, ni `backups/`).
- [ ] **Adaptador de señales con `Player`:** conectar `PlayerLocomotionController` (velocidad, dash, backpedal), `WeaponController` (`aim_dir`, `fire_recoil`) y `PlayerDamageProcessor` (`hit_flash`, `impact_frame`, expresión facial) sin convertir `player.gd` en God-Object.
- [ ] **Presupuesto de rendimiento en combate:** validar 60+ FPS con `BulletServer` activo, `CanvasGroup` (`UnifiedCharacterGroup`), `SettingsManager.space_background_quality` y opciones de calidad/LOD de VFX.
- [ ] **Integración de Power-Up Sandevistan:** activar `SandevistanTrailController` únicamente bajo estado de habilidad/power-up (respetando cero coste cuando está inactivo).
- [ ] **Regresión completa:** validar `-CoreOnly` + test de integración en `MainGame`.

### Fase C — Escalado Multi-Piloto
- Replicar el mismo esquema de `PilotRigProfile` + `PilotBasePropulsionConfig` + 6 configs de animación `.tres` para el segundo piloto usando `tools/build_valentina_v2_rig_assets.py` y `tools/build_valentina_v2_wings.py` como plantilla canónica (ver [`PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md)).
