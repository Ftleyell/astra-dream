# Índice Maestro de Documentación — Astra Dream

> Punto de entrada único para ubicar especificaciones vivas sin explorar directorios a ciegas.

## 1. Orientación y Arquitectura General
| Documento | Contenido |
|---|---|
| [`AGENT_CONTEXT.md`](../AGENT_CONTEXT.md) | Mapa rápido de subsistemas, zonas prohibidas, autoloads y comandos de test. **Lectura obligatoria inicial.** |
| [`DOMAIN_MAP.md`](DOMAIN_MAP.md) | Mapa integral de dominios, componentes, grupos, `.tres`, suites y sandbox. |
| [`EXTENSION_GUIDE.md`](EXTENSION_GUIDE.md) | Convenciones para extender armas, ítems, enemigos y sistemas de juego. |
| [`architecture/system_architecture.md`](architecture/system_architecture.md) | Arquitectura modular general y diagramas de flujo del proyecto. |
| [`architecture/autoloads_and_events.md`](architecture/autoloads_and_events.md) | Contratos de los 7 Autoloads y señales en `EventBus`. |

## 2. Fábrica Multi-Piloto v2 & Rigs Valentina v2
| Documento | Contenido |
|---|---|
| [`PILOT_CREATION_PIPELINE.md`](PILOT_CREATION_PIPELINE.md) | **Playbook integral v2 (Etapas 0–9):** de `scaffold_new_pilot.py` + prompts IA hasta la activación de un nuevo personaje en producción. |
| [`VALENTINA_V2_MILESTONE_STATUS.md`](VALENTINA_V2_MILESTONE_STATUS.md) | Estado del milestone (**Fases 1–5 cerradas ✅**), labs, workbenches y roadmap **M8 / M9**. |
| [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) | Registro detallado de las 5 Fases de integración de Valentina v2 en producción. |
| [`PILOT_RIG_ARCHITECTURE.md`](PILOT_RIG_ARCHITECTURE.md) | Arquitectura del rig 2.5D, máscaras, pasadas de shader y métricas técnicas. |
| [`VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md) | Referencia técnica del runtime (`PlanarCombatRig`, animación data-driven `.tres` y estilos). |
| [`VALENTINA_V2_FACE_RIG_REFERENCE.md`](VALENTINA_V2_FACE_RIG_REFERENCE.md) | Rig facial vivo, ojos Live2D Amatista Profundo y cabello 3-zonas. |
| [`VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) | Alas psíquicas 2D multi-piloto y compilador `build_valentina_v2_wings.py`. |
| [`VALENTINA_3D_LAB_SPEC.md`](VALENTINA_3D_LAB_SPEC.md) | Especificación técnica de Alas 3D cel-shaded (*Astral Seraph*). |
| [`VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md) | Guía de modelado/exportación GLB y configuración de Alas 3D para nuevas pilotos. |
| [`VALENTINA_PROPULSION_VFX_SPEC.md`](VALENTINA_PROPULSION_VFX_SPEC.md) | VFX de poder y estela Sandevistan + aberración cromática. |
| [`VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md) | Anillo Orbital 2.5D, Rail-Lance 3D y compiladores `build_valentina_weapon.py` / `build_orbital_ring_texture.py`. |
| [`VALENTINA_LIVE_BANNER_SPEC.md`](VALENTINA_LIVE_BANNER_SPEC.md) | Live Banner 2.5D, icono `512×512` y compilador `build_valentina_live_banner.py`. |
| [`VALENTINA_LIVE_BANNER_PROMPTS.md`](VALENTINA_LIVE_BANNER_PROMPTS.md) | Prompts de referencia para Splash Art y máscaras de banner. |

## 3. Cosmos Engine & Entorno Espacial
| Documento | Contenido |
|---|---|
| [`COSMOS_ENGINE_V2_ART_SPEC.md`](COSMOS_ENGINE_V2_ART_SPEC.md) | Especificación estética *Anime Space-Opera*, shaders y biomas de Cosmos Engine. |
| [`COSMIC_GAMEPLAY_BRIDGE.md`](COSMIC_GAMEPLAY_BRIDGE.md) | Puente orbital, `CosmicLightingSampler` zero-alloc y sectores no estelares. |

## 4. Arte, Diseño y Desarrollo
| Documento | Contenido |
|---|---|
| [`ART_DIRECTION_AND_PIPELINE.md`](ART_DIRECTION_AND_PIPELINE.md) | Dirección artística global y estándares visuales del proyecto. |
| [`MUMBLE_SPEECH_SYSTEM.md`](MUMBLE_SPEECH_SYSTEM.md) | Sistema híbrido de **Mumble Speech** data-driven (`VoiceProfileData` `.tres`), integración Dialogic/HUD y guía de fine-tuning. |
| [`UI_REWORK_ART_DIRECTION.md`](UI_REWORK_ART_DIRECTION.md) | **Dirección aprobada para futuro Rework de UI (*Astral Pop-Ink* — Fusión B+D):** referencia visual, pilares técnicos y plan de profundización. |
| [`HUB_3D_REWORK_BLUEPRINT.md`](HUB_3D_REWORK_BLUEPRINT.md) | **Hub 3D Estación Astral v4 (Promovido a Producción ✅):** mandala de 9 islas sobre Cosmos vivo, Santuario Valkiria, Gacha 3D, shaders *ArcSys* y despegue radial 8-Dir. |
| [`art/`](art/) | Guías de pipeline IA (`character_25d_generation_guide.md`, `character_style_pipeline_bible.md`, `Estilización 2.5D en Godot 4.md`, `art_pipeline_standards.md`, etc.). |
| [`game_design/balance_and_mechanics.md`](game_design/balance_and_mechanics.md) | Balance de combate, economía y progresión. |
| [`game_design/hp_rework_3_layer_hybrid_proposal.md`](game_design/hp_rework_3_layer_hybrid_proposal.md) | Propuesta teórica de rework futuro de HP (Híbrido 3 Capas: Casco + Escudo Reactivo + Barrera 1-Hit). |
| [`dev/testing_and_workflow.md`](dev/testing_and_workflow.md) | Flujo de tests headless y herramientas de verificación. |
| [`tools/README.md`](../tools/README.md) | Índice de scripts de `tools/` (arnés de tests, launcher, procesadores activos y `legacy_art_experiments/`). |
| [`sandbox/pilot_rig_lab/tools/README.md`](../sandbox/pilot_rig_lab/tools/README.md) | Entornos Python, `requirements.txt`, compiladores v2 (`assets/pilots/`) y `legacy_v1/`. |

*(El árbol `sandbox/` queda acotado a 3 áreas limpias: `workbenches/`, `combat_gym/` y `pilot_rig_lab/`.)*

## 5. Archivo Histórico
- [`archive/`](archive/): Planes de implementación cerrados y notas históricas de Cosmos Engine, Run Forks y el handoff inicial de Valentina v2.
