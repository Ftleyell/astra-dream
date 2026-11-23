# Valentina v2 — Estado de Milestone y Hoja de Ruta (`PilotRigLab`)

> **Propósito:** Índice ejecutivo liviano del milestone alcanzado en **Valentina v2 (8-Dir Nativo)** en producción (`scenes/pilots/`, `data/pilots/`, `assets/pilots/`) y laboratorios de calibración en `sandbox/pilot_rig_lab/`.
> Permite retomar el desarrollo en sesiones futuras con cero exploración ciega y saber qué está cerrado, qué labs/tests existen y cuáles son los siguientes pasos hacia Hub 3D y Combate.
> **Plan Maestro de Integración (Fase 4 Completada — Próximo: Fase 5 Combate):** [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md)
> **Reglas de edición y tabla contractual:** [`.agents/rules/pilot_rig_lab.md`](../.agents/rules/pilot_rig_lab.md)

---

## 1. Resumen del Milestone Alcanzado (Cerrado y Verificado)

| Área | Estado | Artefactos Clave | Especificación Técnica |
|---|---|---|---|
| **Rig 8-Dir Nativo + Mallas + 18 Huesos** | **Cerrado (Prod.)** | `scenes/pilots/rig/planar_combat_rig.gd`, `planar_rig_mesh_builder.gd`, `planar_rig_view_router.gd` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Máscaras HQ + Ink SDF 2× (65 mapas)** | **Cerrado (Prod.)** | `assets/pilots/valentina_v2/planar/**`, `sandbox/pilot_rig_lab/tools/ink_hq_pipeline.py` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Shaders Cel 2.5D + 3 Estilos + 10 Skins + 10 Pelos** | **Cerrado (Prod.)** | `scenes/pilots/shaders/pilot_rig_{stylizer,pass2}.gdshader`, `data/pilots/styles/*.tres`, `data/pilots/valentina_v2/skins/*.tres` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Animación Data-Driven (6 sistemas `.tres`)** | **Cerrado (Prod.)** | `data/pilots/valentina_v2/valentina_v2_*.tres` (Pose Base, Idle, Locomoción/Freno, Kiting 360°, Giros 2.5D, Jiggle) | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |
| **Rig Facial Vivo + Cabello 3-Zonas + Ojos Amatista** | **Cerrado (Prod.)** | `scenes/pilots/rig/planar_rig_face_controller.gd`, `data/pilots/valentina_v2/valentina_v2_face_anim.tres`, `rig_face_live.gdshaderinc` | [`VALENTINA_V2_FACE_RIG_REFERENCE.md`](VALENTINA_V2_FACE_RIG_REFERENCE.md) |
| **Alas Psíquicas & Propulsión Base Multi-Piloto** | **Cerrado (Prod.)** | `scenes/pilots/vfx/valentina_base_propulsion_controller.gd`, `wing_red_glow.gdshader`, `data/pilots/valentina_v2/valentina_v2_base_propulsion.tres` | [`VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) |
| **VFX Power-Up Sandevistan (Estela Ping-Pong)** | **Cerrado (Prod. listo)** | `scenes/pilots/vfx/sandevistan_trail_controller.gd`, `scenes/pilots/shaders/sandevistan_*.gdshader`, `data/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres` | [`VALENTINA_PROPULSION_VFX_SPEC.md`](VALENTINA_PROPULSION_VFX_SPEC.md) |
| **Anillo Orbital 2.5D & Guns Lab (Base Armas)** | **Base Activa (Prod. lista)** | `scenes/pilots/weapons/orbital_weapon_{ring_controller,3d_renderer}.gd`, `scenes/pilots/shaders/orbital_weapon_25d.gdshader`, `data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres` | [`VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md) |
| **3D Lab & Alas 3D Cel-Shaded (*Astral Seraph*)** | **Cerrado (Estándar Prod.)** | `scenes/pilots/vfx/astral_wings_3d_{mesh_builder,controller}.gd`, `scenes/pilots/shaders/astral_wing_*.gdshader`, `data/pilots/valentina_v2/valentina_v2_wings_3d.tres` | [`VALENTINA_3D_LAB_SPEC.md`](VALENTINA_3D_LAB_SPEC.md) · [`VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md) |
| **Live Banner 2.5D + Icono 512×512 + Lockout Roster** | **Cerrado en Select (Fase 2)** | `scenes/pilots/banner/pilot_live_banner_controller.gd`, `character_live_banner_viewport.gd`, `data/pilots/valentina_v2/valentina_v2_live_banner.tres`, `assets/pilots/valentina_v2/banner/` | [`VALENTINA_LIVE_BANNER_SPEC.md`](VALENTINA_LIVE_BANNER_SPEC.md) |
| **Hub 3D 2.5D Diorama + `HubRigAvatar3D`** | **Cerrado en Hub (Fase 3)** | `scenes/ui/hub/components/hub_rig_avatar_3d.gd`, `scenes/ui/hub/resources/hub_diorama_config.gd`, `data/hub/default_hub_diorama_config.tres`, `scenes/ui/hub/hub_world.tscn` | [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) |
| **Skins 100% por Shaders (`pilot` / `wings` / `weapon`)** | **Cerrado en UI, Hub y Gacha (Fase 4)** | `data/pilots/schemas/{shader_skin_entry,pilot_shader_skin_catalog}.gd`, `data/pilots/valentina_v2/valentina_v2_skin_catalog.tres`, `scenes/ui/cosmetics/components/{shader_skin_live_preview,shader_skin_swatch}.gd`, `core/systems/cosmetics_manager.gd` | [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) |
| **Backup Inmutable de Baseline** | **Cerrado** | `sandbox/pilot_rig_lab/backups/valentina_v2_clean_baseline/` + tag Git `valentina-v2-clean-baseline` | [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) |

---

## 2. Mapa de Laboratorios Interactivos y Suites de Prueba

### Escenas de Laboratorio (`sandbox/pilot_rig_lab/`)
1. **Arena Principal del Rig:** `proto/planar_combat_rig_proto.tscn` — Rig completo (8-Dir, animación data-driven, rostro vivo, alas psíquicas base, skins/pelos/estilos).
2. **Laboratorio de Animación (6 pestañas):** `proto/planar_anim_test.tscn` — Calibración y guardado `.tres` de Pose Base, Idle, Vuelo/Freno, Giros, Jiggle y Kiting 360°.
3. **Laboratorio Facial Aislado:** `face_lab/valentina_face_lab.tscn` — Hero Close-Up, Galería 8-Dir, expresiones, cabello 3-zonas y guardado `.tres`.
4. **Laboratorio A/B de Shaders:** `shader_lab/planar_shader_lab.tscn` — Comparativa A/B, luz rotatoria, Rayos-X `0..6` y guardado `.tres`.
5. **Laboratorio VFX Alas + Sandevistan:** `vfx_lab/valentina_vfx_lab.tscn` — Calibración de alas base, estela Sandevistan, danmaku simulado y guardado `.tres`.
6. **Laboratorio de Armamento Orbital 2.5D (Guns Lab):** `guns_lab/valentina_guns_lab.tscn` — Base oficial para el rework de armas (anillo orbital 3D con Z-sorting atrás/delante, 1–4 slots, deformación trapezoidal/escorzo/extrusión 2.5D, recoil, HUD y guardado `.tres`).
7. **Laboratorio Live Banner 2.5D (Banner Lab):** `banner_lab/valentina_banner_lab.tscn` — Base oficial para el Splash Art vivo de Character Select + icono `1:1` (`512×512`) compilados vía `tools/build_valentina_live_banner.py` con 4 máscaras IA (`refs/mask1..4_*.png`), `UnifiedBannerGroup` (`CanvasGroup` + `pilot_rig_pass2.gdshader`), brazo libre bajo hombrera estática, ojo Amatista Profundo con parpadeo anatómico, iluminación roja direccional y despliegue firme de las 12 cuchillas de alas con 2-phase Impact Frames (`Enter` / `E`).
8. **Laboratorio 3D Cel-Shaded / Alas 3D (3D Lab — Estándar):** `3d_lab/valentina_3d_lab.tscn` — Estándar oficial Multi-Piloto de las Alas *Astral Seraph* 3D (`enable_3d_wings` en `PlanarCombatRig`, activo en `planar_combat_rig_proto.tscn` y `valentina_guns_lab.tscn`), dual-pass `768×768` Back/Front, canales rojos enmarcados con glow HDR + flujo raíz→punta, *crease ink*, Post-Pass 2D (`CAS Sharpen` + contorno caligráfico), 6 animaciones (`1`–`6`), Turntable 360° (`T`), comparativa A/B (`B`), sync 10 skins + iluminación `Cosmos` y guardado `.tres` (ver [`VALENTINA_3D_LAB_SPEC.md`](VALENTINA_3D_LAB_SPEC.md) y [`VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md)).
9. **Laboratorio de Iluminación Cósmica (Cosmos Lighting Lab — Fase 1 Completada):** `cosmos_lighting_lab/valentina_cosmos_lab.tscn` — Banco integrado sobre Cosmos Engine v3.2c (`CosmicLightingSampler`, biomas `[B]`, eclipses/soles `[T]`, sectores `[N]`, guías 3D `[O]`/`[G]`, skins `[K]` y calidades `0/1/2`), validado visualmente en Vulkan 1.4 antes de iniciar la **Fase 2** (promoción a producción en `scenes/pilots/`).

### Comandos Rápidos de Verificación (`tests/sandbox/` & `tests/unit/`)
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "pilot_rig_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_face_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_guns_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_3d_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_banner_lab"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_roster_rework_lockout"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_hub_25d_valentina_rig"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_shader_skins_system"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "cosmic_lighting_sampler"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "kepler_3d_orbits"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "living_universe_sectors"
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "interstellar_corridors"
```

---

## 3. Próximos Pasos (Backlog Ordenado)

### Fase A — Animaciones de Combate (Aditivas en `.tres`)
1. **Etapa 4 — Maniobras de Impulso (`DASH_BOOST`, `AIR_BRAKE` explosivo, `LAUNCH`):** overlays aditivos temporizados con curva *anticipation-overshoot*, refuerzo 2.5D (`torso_trap`), compresión distal y disparo de whiplash/afterimage.
2. **Etapa 5 — Reacción de Combate (`ATTACK_RECOIL`, `HIT_REACT`):** micro-retroceso direccional hacia `aim_dir` / `-hit_dir` acoplado a `trigger_impact_frame()`, `hit_flash` y micro-gestos faciales (`planar_rig_face_controller.gd`).

### Fase B — Promoción Controlada a Producción (Plan Maestro Fases 2–5)
> **Regla vigente:** *Single Source of Truth* ya promovida en `scenes/pilots/`, `data/pilots/` y `assets/pilots/` (Fase 2 cerrada con Live Banner y Lockout en `CharacterSelectUI`; Hub 3D, Skins Shader y Player In-Game pendientes en Fases 3–5).

Checklist de integración en producción:
- [x] **Empaquetado de producción (*Single Source of Truth*):** movido runtime + shaders + `.tres` + assets compilados a `scenes/pilots/`, `data/pilots/` y `assets/pilots/` (manteniendo `source_refs/`, `tools/.venv/`, y `backups/` en sandbox).
- [ ] **Adaptador de señales con `Player`:** conectar `PlayerLocomotionController` (velocidad, dash, backpedal), `WeaponController` (`aim_dir`, `fire_recoil`) y `PlayerDamageProcessor` (`hit_flash`, `impact_frame`, expresión facial) sin convertir `player.gd` en God-Object.
- [ ] **Presupuesto de rendimiento en combate:** validar 60+ FPS con `BulletServer` activo, `CanvasGroup` (`UnifiedCharacterGroup`), `SettingsManager.space_background_quality` y opciones de calidad/LOD de VFX.
- [ ] **Integración de Power-Up Sandevistan:** activar `SandevistanTrailController` únicamente bajo estado de habilidad/power-up (respetando cero coste cuando está inactivo).
- [ ] **Regresión completa:** validar `-CoreOnly` + test de integración en `MainGame`.

### Fase C — Escalado Multi-Piloto
- Replicar el mismo esquema de `PilotRigProfile` + `PilotBasePropulsionConfig` + 6 configs de animación `.tres` para el segundo piloto usando `tools/build_valentina_v2_rig_assets.py` y `tools/build_valentina_v2_wings.py` como plantilla canónica (ver [`PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md)).
