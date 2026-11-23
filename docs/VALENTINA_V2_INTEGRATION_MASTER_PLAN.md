# Plan Maestro — Integración Integral de Valentina v2, Upgrade de Cosmos Engine, Hub 2.5D, Skins por Shader y Anillo Orbital de Armas

> **Estado actual:** **Fase 1 COMPLETADA Y VERIFICADA** (Cosmos Engine v3.2c + Puente de Luz Dinámica) · **Próximo paso (nueva sesión):** **Fase 2** (Promoción *Single Source of Truth* + Icono + Bloqueo Roster + Live Banner).  
> **Documento de estado del rig:** [`VALENTINA_V2_MILESTONE_STATUS.md`](VALENTINA_V2_MILESTONE_STATUS.md)

## Objetivo General

Llevar **Valentina v2** desde `sandbox/pilot_rig_lab/` hasta producción como la nueva base arquitectónica y visual de **Astra Dream**, elevando primero **Cosmos Engine** al estándar **Anime Space-Opera estilizado** y conectando su iluminación dinámica al rig, para luego cerrar el ciclo completo de juego (**Character Select**, **Hub 3D**, **Skins por Shader** y **Combate In-Game** con **Anillo Orbital 2.5D multi-arma**).

La ejecución se divide en **5 Fases Secuenciales e Independientes** (con verificación visual y suite de tests en verde al cierre de cada fase, cumpliendo la higiene de sesiones atómicas).

```mermaid
flowchart TD
    F1["Fase 1: Cosmos Engine Anime Space-Opera + Puente de Luz Dinámica"]
    F2["Fase 2: Promoción Single Source of Truth + Icono + Bloqueo Roster + Live Banner"]
    F3["Fase 3: Rework Radical Hub 3D (Cámara 2.5D Diorama + Rig sin Alas/Anillo)"]
    F4["Fase 4: Skins 100% por Shaders (Piloto / Alas / Arma + Carrusel y Gacha Live)"]
    F5["Fase 5: Player In-Game Twin-Stick Kiting + Poderes/VFX + Anillo Orbital 1–4 Armas"]

    F1 --> F2 --> F3 --> F4 --> F5
```

---

## Decisiones Aprobadas

1. **Fuente Única de Verdad en Producción:** El runtime y assets compilados de Valentina v2 se mueven a `scenes/pilots/`, `data/pilots/` y `assets/pilots/`. Los laboratorios de `sandbox/pilot_rig_lab/` pasarán a consumir producción (dependencia estricta de una sola vía: **Producción nunca importa de `sandbox/`**).
2. **Bloqueo del Roster y Migración de Saves:** `CharacterData` incorporará `is_playable_rework_ready: bool`. Solo `valentina` iniciará activa (`true`). Los perfiles existentes con otra piloto seleccionada se migrarán automáticamente a `valentina` y las otras 6 heroínas quedarán grisadas/bloqueadas (*"En Rework"*) en UI y excluidas del Gacha, conservando intactos sus `.tres` y scripts para futuros reworks.
3. **Repropósito del Slot `ship` -> `wings` (Alas/Propulsión):** Para pilotos v2, `pilot` controla el exo-traje unificado (Banner, Hub y Combate), el antiguo slot `ship` se convierte en **Alas / Propulsión** (`ValentinaBasePropulsionController`), y `weapon` controla el **Rail-Lance 3D**. Cero PNGs pre-horneados de recolor.
4. **Limpieza de Assets Legacy de Valentina:** Se eliminan los PNGs legacy exclusivos de Valentina (`fullbody_valentina*`, `ship_valentina*`, `weapon_valentina*`, `recolors/*valentina*`) al cerrarse la Fase 2/4 (historial respaldado en Git).
5. **Nuevo Icono Close-Up Estilizado:** Generar con `image-generator` usando `valentina_v2_icon_1x1.png` como referencia estricta para lograr un close-up facial con mayor personalidad.
6. **Hub 3D Diorama 2.5D:** Cámara fija en ángulo `~42°` y `FOV 38°` sin giro de 180°, retirando/abriendo el techo oclusor y utilizando `PlanarCombatRig` en `SubViewport` HDR sin alas ni anillo en levitación Zero-G.
7. **Combate In-Game Twin-Stick Kiting 360° & Anillo Multi-Arma:** `Player` orienta el rig 8-Dir hacia el cursor/objetivo fijado (strafe + reversa), dispara `SandevistanTrailController` + Alas Overdrive + Monóculo HUD / Ojo Amatista durante todo el bullet-time del Repliegue Táctico, y soporta 1–4 armas independientes en el Anillo Orbital 2.5D naciendo desde sus bocas 3D proyectadas (usando paletas por `WeaponData` sobre la malla 3D actual como placeholders iniciales).

---

## Arquitectura Transversal de Iluminación y Promoción

```mermaid
flowchart LR
    subgraph Cosmos["Cosmos Engine (scenes/combat/environment/cosmos/)"]
        SS["CosmosSolarSystemStreamer"]
        NB["CosmosNebulaBackdropController"]
        SP["CosmosPlanetaryShadowProjector2D"]
        LS["CosmicLightingSampler (Analítico Zero-Alloc)"]
    end

    DTO["CosmicLightingSample (Value Object)"]

    subgraph ProdRig["Producción Rig v2 (scenes/pilots/)"]
        RIG["PlanarCombatRig (Pass1 + Pass2)"]
        RING["OrbitalWeaponRingController (1–4 Slots 3D)"]
        WINGS["ValentinaBasePropulsionController (12 Cuchillas)"]
        SAND["SandevistanTrailController"]
        BANNER["PilotLiveBannerController"]
    end

    SS --> LS
    NB --> LS
    SP --> LS
    LS --> DTO
    DTO -->|"light_dir_2d, key_tint, rim, shadow_tint, eclipse"| RIG
    DTO -->|"light_dir_3d, key_tint, eclipse"| RING
```

---

## Fase 1 — Upgrade Visual de Cosmos Engine (Anime Space-Opera) + Puente de Iluminación al Rig

### Objetivo
1. Elevar la calidad gráfica y coherencia estética de Cosmos Engine al lenguaje **Anime Space-Opera estilizado** (*Trigger / Honkai: Star Rail / Guilty Gear*): nebulosas pictóricas con bandas suaves de contraste profundo, planetas con terminador semi-cel y rim atmosférico vibrante, estrellas con corona estilizada y destellos anamórficos, y escombros con silueta limpia — preservando oscuridad controlada para legibilidad danmaku y respetando `SettingsManager.space_background_quality` (`0/1/2`).
2. Implementar el puente analítico de iluminación (`Cosmos Engine` -> `Rig Valentina v2` + `Anillo 3D`): **Sol + Bioma + Eclipse planetario**, con piso mínimo de legibilidad en combate.

### Cambios Clave
- **Shaders Cosmos (`scenes/combat/environment/cosmos/shaders/`):** `universe_nebula.gdshader`, `celestial_body.gdshader`, `star_corona.gdshader`, `star_light_field.gdshader`, `debris_cutout.gdshader`.
- **Balance Data-Driven (`.tres`):** calibración de los 6 biomas (`biome_01..06`), `default_cosmic_biome.tres`, `default_star_visual.tres`, `default_shadow_system.tres`, `default_cosmos_environment.tres`.
- **Puente Analítico Zero-Alloc:** `CosmicLightingSample`, `CosmicRigLightingConfig` (`default_rig_lighting.tres`), `CosmicLightingSampler` y `CosmosHostController.sample_lighting_at(...)`.
- **Consumo en Rig y Armas 3D:** `apply_cosmic_lighting(...)` en `PlanarRigMaterialController`, `PlanarCombatRig`, `ValentinaBasePropulsionController`, `OrbitalWeapon3DRenderer`, `OrbitalWeaponRingController` y `rail_lance_toon_3d.gdshader`.
- **Calibración y Tests:** `sandbox/pilot_rig_lab/cosmos_lighting_lab/valentina_cosmos_lab.tscn` + `tests/unit/test_cosmic_lighting_sampler.tscn`.

### Estado: ✅ COMPLETADA (Cosmos Engine v3.2c)
- **Entregables cerrados y verificados:**
  - 7 arquetipos estelares (`black_hole` con lente gravitacional y `emerald_nova`), rotación/relieve planetario multi-mapa, anillos y cometas tangentes a `-vel.normalized()`.
  - Órbitas keplerianas 3D inclinadas + overlay `[O]`/`[G]` (`CosmosOrbitGuidesOverlay2D`), 4 sectores no estelares en ~35% de parcelas (`Rogue World`, `Derelict Armada`, `Warp Relay`, `Ion Nursery` + teletransporte `[N]`), corredores interestelares (`hyperspace`, `bow-shocks`, meteoros, ríos laminares de asteroides) y landmarks lejanos en perspectiva 3D integrados detrás de `DustMidSprite` (`z_index = -25`).
  - Puente analítico zero-alloc (`CosmicLightingSampler`) conectado a `PlanarCombatRig` + `AstralWings` + `OrbitalWeapon3D`, auditado en Vulkan 1.4 y validado con `24/24 -CoreOnly PASS`.
  - **Siguiente paso (nueva sesión):** Iniciar **Fase 2** (*Single Source of Truth* bajo `scenes/pilots/`, `data/pilots/`, `assets/pilots/`, nuevo icono close-up, bloqueo de roster con `is_playable_rework_ready` y `Live Banner` en `CharacterSelectUI`).

---

## Fase 2 — Promoción *Single Source of Truth*, Nuevo Icono, Bloqueo del Roster y Live Banner

### Objetivo
1. Promover runtime, shaders, `.tres` y assets compilados de Valentina v2 a producción (`scenes/pilots/`, `data/pilots/`, `assets/pilots/`), dejando `sandbox/pilot_rig_lab/` consumiendo producción para labs y conservando `tools/`, `.venv/`, `source_refs/` y `backups/` aislados.
2. Generar mediante `image-generator` un close-up facial estilizado de Valentina tomando `valentina_v2_icon_1x1.png` como referencia estricta (`512×512`).
3. Incorporar `is_playable_rework_ready: bool` en `CharacterData`: solo `valentina` activa, migrando saves viejos a `&"valentina"`, bloqueando/grisando (*"En Rework"*) las otras 6 pilotos en `CharacterSelectUI` y excluyéndolas de Gacha.
4. Montar `PilotLiveBannerController` en `CharacterSelectUI` (`CharacterLiveBannerViewport`) con parallax, parpadeo, jiggle y secuencia Lock-In (12 cuchillas + 2 Impact Frames) al desplegar.
5. Eliminar los PNGs legacy exclusivos de Valentina.

---

## Fase 3 — Rework Radical del Hub 3D (Cámara Fija 2.5D Diorama + Rig Valentina v2 sin Alas ni Anillo)

### Objetivo
1. Reemplazar el `Sprite3D` legacy del Hub por `HubRigAvatar3D` (`SubViewport` `512×512`, `transparent_bg`, `use_hdr_2d`, `MSAA_4X` con `PlanarCombatRig` sin alas ni anillo orbital, `enable_face_live = true`, estilo `02_valentina_razor_sharp`).
2. Configurar cámara fija **2.5D Diorama**: `FOV 38°`, pitch fijo `-42°` (offset `Vector3(0, 9.2, 10.2)`), sin giro orbital de 180°, mapeando `WASD` directamente a las 8 direcciones del rig en levitación Zero-G.
3. Retirar/abrir el techo sólido (`BoxMesh_ceiling`) y rebajar muros oclusores en `+Z` de `hub_world.tscn` manteniendo pisos, terminales, ventanales `SpaceParallax`, mascotas y trofeos.
4. Dejar pedestales del resto del roster bloqueados/apagados (*"EN REWORK"*).

---

## Fase 4 — Sistema de Skins 100% por Shaders (Piloto, Alas/Propulsión y Arma)

### Objetivo
1. Unificar los 3 slots por shader en `CosmeticsManager`, `SaveManager`, `CosmeticCarouselModal` y `GachaModal`:
   - `pilot`: exo-traje (aplica a Banner, Hub y Rig de Combate).
   - `wings` (repropósito del antiguo slot `ship`): 12 cuchillas psíquicas + glow HDR + polvo estelar (default `"follow_pilot"`).
   - `weapon`: Rail-Lance 3D Cel-Shaded (`SURFACE_ARMOR`, `SURFACE_CHASSIS`, `SURFACE_CRYSTAL`, default `"follow_pilot"`).
2. Usar los 10 `PilotSkinPreset` curados de Valentina v2 como catálogo unificado (`ShaderSkinEntry` + `valentina_v2_skin_catalog.tres`), eliminando entradas PNG legacy de Valentina.
3. Implementar `ShaderSkinLivePreview` (`SubViewport` en vivo) en Carrusel y Gacha, y renombrar la tarjeta de Nave a **"ALAS / PROPULSIÓN"** para pilotos v2.

---

## Fase 5 — Personaje Main In-Game, Poderes/VFX y Anillo Orbital Multi-Arma (1–4 Slots)

### Objetivo
1. Integrar `Player` <-> `PlanarCombatRig` mediante un componente desacoplado `PlayerRigV2Controller` (anti God-Object):
   - Orientación **Twin-Stick / Kiting 360°** hacia cursor/objetivo fijado.
   - Iluminación cósmica en tiempo real (`CosmosHostController.sample_lighting_at(...)` zero-allocation).
   - Calibración de escala junto a `HitboxCore` (`z_index = 25`) y `set_cinematic_duel_facing()`.
2. Conectar Poderes y VFX de Valentina v2:
   - **Repliegue Táctico / Sobre-Enfoque (`Dash` + `1.5s` bullet-time `0.55×`):** `SandevistanTrailController` activo en todo el bullet-time (usando `unscaled_delta`) + Alas Overdrive + brillo de monóculo HUD/ojo Amatista + micro Impact Frame.
   - **Bomba Táctica, Daño, Escudo y OSP:** `hit_flash`, `trigger_impact_frame()`, expresiones faciales y conservación de `PlayerBombController` / `PlayerShieldController`.
3. Conectar **Anillo Orbital 2.5D** con **1–4 armas independientes**:
   - Añadir `orbital_armor_color`, `orbital_chassis_color`, `orbital_crystal_color` y `orbital_mesh_id` a `WeaponData` y los 14 `.tres` en `data/weapons/roster/` (paletas placeholder sobre el Rail-Lance 3D actual).
   - Puntería independiente por slot (`0` cursor/blanco principal, `1..3` blancos pasivos o cursor en disparo activo), naciendo cada proyectil desde `get_slot_muzzle_world_pos(slot_idx)` proyectado `3D -> 2D` con recoil y muzzle flash propios.

---

## Verificación por Fase y Pitfalls Vigilados

| Fase | Suites de Verificación |
|---|---|
| **Fase 1** | `test_cosmic_lighting_sampler`, `space_environment`, `cosmos_host_controller`, `pilot_rig_lab`, `valentina_guns_lab` |
| **Fase 2** | `pilot_rig_lab`, `valentina_face_lab`, `valentina_vfx_lab`, `valentina_guns_lab`, `valentina_banner_lab`, `persistence`, `test_roster_rework_lockout` |
| **Fase 3** | `test_hub_25d_valentina_rig` + recorrido manual del Hub |
| **Fase 4** | `test_shader_skins_system` + prueba manual de Carrusel/Gacha |
| **Fase 5** | `weapons`, `proc_coefficients_and_osp`, `test_player_valentina_v2_combat` + regresión final `-CoreOnly` |

### Pitfalls Clave
- Oclusión de techo `BoxMesh_ceiling` en Hub 3D con cámara a `42°`.
- Doble escalado entre `Player.scale (1.2)` y `display_scale (0.378)`.
- Invariante `z_index = 0` dentro de `CanvasGroup` (`UnifiedCharacterGroup` y `UnifiedBannerGroup`).
- Cadencia `unscaled_delta` de Sandevistan durante slow-mo `0.55×`.
- Tests antiguos que asuman `nova` como piloto inicial por defecto.
