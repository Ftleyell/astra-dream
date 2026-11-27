---
trigger: model_decision
description: Reglas de arquitectura, tabla contractual, invariantes de shader y comandos de test para el rig 2.5D/3D de enemigos en producción (VoidScarabRig25D, EnemyVisualController, catálogo de variantes) y su workbench EnemyArtLab.
---

# Rig Procedural 2.5D/3D de Enemigos — Reglas y Tabla Contractual

> **Documentación completa:** [`docs/ENEMY_25D_RIG_SYSTEM.md`](../../docs/ENEMY_25D_RIG_SYSTEM.md)  
> **Regla de Frontera Producción ↔ Sandbox:** Toda la verdad de producción vive en `scenes/combat/enemies/`, `data/enemies/` y `assets/enemies/void_scarab/`. **PROHIBIDO** importar scripts, escenas o `.tres` desde `sandbox/enemy_art_lab/` hacia producción. No sobrescribir `sandbox/enemy_art_lab/data/void_scarab_config.tres` al trabajar en producción.

---

## Tabla Contractual: "¿Qué quieres tocar? → Archivo exacto"

| Qué quieres modificar | Archivo exacto | Notas / Regla |
|---|---|---|
| **Controlador visual en `EnemyBase`** | `scenes/combat/enemies/rig/enemy_visual_controller.gd` | Orquesta estado IA, escala, paleta, pooling y muestreo cada `0.08s` de `CosmosHostController`. |
| **Rig procedural 7 piezas (`VoidScarabRig25D`)** | `scenes/combat/enemies/rig/void_scarab_rig_25d.gd` | Single Source of Truth. Respetar `_texture_cache`, `_mesh_cache` y `combat_lite_mode`. |
| **Shader 2.5D + Élitrones 3D + Ink SDF** | `scenes/combat/enemies/shaders/enemy_stylized_25d.gdshader` | Compartido por las 7 piezas. Nunca usar `* COLOR;` ni cortar croma con Rec.601 `0.165`. |
| **Paletas, tamaños y cintas por arquetipo** | `data/enemies/default_enemy_visual_catalog.tres` | Catálogo data-driven (`EnemyArchetypeVisualCatalog` + 11 `EnemyArchetypeVisualEntry`). |
| **Schemas de catálogo, rig y estilo** | `data/enemies/schemas/enemy_archetype_visual_catalog.gd`, `enemy_archetype_visual_entry.gd`, `enemy_scarab_rig_config.gd`, `enemy_faction_style.gd` | Tipado estricto GDScript 4 en todos los campos exportados. |
| **Calibración base del escarabajo y estilo** | `data/enemies/void_scarab/void_scarab_config.tres`, `style_biomech_void.tres` | Posiciones de pivotes, apertura 3D de élitrones, iluminación ArcSys/Cosmos. |
| **Mapas PNG 3+1 de las 7 piezas** | `assets/enemies/void_scarab/*_{albedo,normal,ilm,fx}.png` | `28` texturas totales. `_ilm.png` se carga sin mipmaps para preservar Ink SDF 2×. |
| **Hooks de ciclo de vida y pooling en combate** | `scenes/combat/enemies/enemy_base.gd` | Llama `setup()`, `on_hit()`, `on_contact_bite()`, `on_die()`, `reset_for_pool()`. |
| **Workbench interactivo (Cosmos Live)** | `sandbox/enemy_art_lab/{enemy_art_lab,enemy_sequence_director,enemy_art_lab_hud}.gd` | Consume rig/shader/schemas de producción para ajustar look & feel. |

---

## Invariantes Obligatorios

1. **Zero-Allocation & Pool Safe:** En combate (`combat_lite_mode = true`), `VoidScarabRig25D` **debe** reutilizar `_texture_cache` (`<= 28`) y `_mesh_cache` (`<= 8`). Al reciclar un enemigo en `EnemyNodePool`, `reset_from_pool()` debe invocar `reset_for_pool()` y jamás duplicar `Sprite2D`, `SplitterSprite` o `FlockSprite`.
2. **Nodos Legacy Ocultos pero Presentes:** `EnemyVisualController.hide_legacy_visuals()` oculta (`visible = false`) `Sprite2D` y sprites legacy, **sin eliminarlos**, manteniendo compatibilidad con `test_enemy_outline_suite.gd` y geometrías de referencia.
3. **Shader Safety (`canvas_item`):**
   - Usar `varying vec4 v_modulate = COLOR;` en `vertex()` y multiplicar por `v_modulate` al final de `fragment()`; **prohibido** multiplicar por `COLOR`.
   - Usar HSV `orig_val` (`smoothstep(0.022, 0.062, orig_val)`) + `sdf_ink_line` (`ilm_sdf_tex.b`), nunca umbral luma `0.165`.
   - Tras tocar `.gdshader`, validar **siempre** compilación real en GPU Vulkan (headless no compila GLSL).
4. **Exclusiones:** No inyectar `VoidScarabRig25D` en jefes (`scenes/combat/bosses/`) ni estructuras estáticas (`ResonanceContainmentNode`).

---

## Verificación Obligatoria

```powershell
# Suite de integración producción (catálogo 11 IDs, cachés GPU, pooling y shaders)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_25d_production" -TimeoutSeconds 35

# Suite workbench + balanceo de llaves y guardas de shader
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_art_lab" -TimeoutSeconds 35

# Compatibilidad de outlines legacy en escenas EnemyBase
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_outline_suite" -TimeoutSeconds 35
```
