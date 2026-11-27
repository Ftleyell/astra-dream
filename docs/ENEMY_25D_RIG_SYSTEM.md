# Sistema de Rig Procedural 2.5D/3D de Enemigos (`VoidScarabRig25D`)

> **Estado:** En Producción (`EnemyBase` + todos los arquetipos estándar) + Workbench (`sandbox/enemy_art_lab/`).  
> **Single Source of Truth:** Los shaders, schemas `.gd`, recursos `.tres`, mapas PNG y scripts de rig residen exclusivamente en producción (`scenes/combat/enemies/`, `data/enemies/`, `assets/enemies/void_scarab/`). `sandbox/enemy_art_lab/` consume los mismos archivos de producción y no es importado jamás por combate.

---

## 1. Arquitectura y Flujo de Datos

La separación estricta desacopla la lógica de combate/movimiento (`EnemyBase` y subclases) de la presentación 2.5D/3D (`EnemyVisualController` → `VoidScarabRig25D`):

```
EnemyBase (scenes/combat/enemies/enemy_base.gd)
 └─ VisualController: EnemyVisualController (scenes/combat/enemies/rig/enemy_visual_controller.gd)
     ├─ Consulta data/enemies/default_enemy_visual_catalog.tres (EnemyArchetypeVisualCatalog) por owner.enemy_id
     ├─ Oculta Sprite2D / sprites legacy (mantiene nodos intactos para compatibilidad con suites existentes)
     ├─ Instancia VoidScarabRig25D (combat_lite_mode = true)
     │   ├─ Config: data/enemies/void_scarab/void_scarab_config.tres (EnemyScarabRigConfig)
     │   └─ Estilo: data/enemies/void_scarab/style_biomech_void.tres (EnemyFactionStyle)
     ├─ Sincroniza estado IA (IDLE_HOVER, CRUISE_BANK, CHARGE_TELEGRAPH, ATTACK_LUNGE, DEATH_SHATTER)
     └─ Muestrea CosmosHostController.sample_lighting_at() cada 0.08s (CosmicLightingSample)
```

### Contratos clave de Producción & `EnemyNodePool`

1. **Zero-Allocation / Caché Estática GPU (`combat_lite_mode = true`):**
   - `VoidScarabRig25D` mantiene cachés estáticas globales `_texture_cache` (`<= 28` texturas: 7 piezas × 4 mapas) y `_mesh_cache` (`<= 8` `ArrayMesh`). Cientos de enemigos comparten exactamente los mismos recursos de textura y malla sin duplicar VRAM ni regenerar geometría al spawnear.
   - Con `combat_lite_mode = true`, se omiten capas de workbench innecesarias en hordas masivas (sombras de suelo, extruded shells adicionales, ghosts pesados, partículas extra y gizmo de pivotes) y se usan subdivisiones ligeras (`10×10`, `6×6`, `8×8`, `16×16`). Las cintas de vuelo (`enable_combat_ribbons`) solo se activan en arquetipos veloces/embestidores.
2. **Ciclo de Vida con Pooling (`EnemyNodePool`):**
   - `EnemyBase._ready()` crea `visual_controller` tras `_apply_silhouette_outline()`.
   - `EnemyBase.reset_from_pool(pos)` llama a `visual_controller.reset_for_pool()`, que re-resuelve el catálogo, re-aplica escala/paleta, vuelve a ocultar sprites legacy (guardado también en `enemy_splitter.gd` y `enemy_micro_flock.gd` para evitar nodos duplicados) y ejecuta `rig.respawn()`.
   - `take_damage()` dispara `visual_controller.on_hit()`; el ataque por contacto llama a `visual_controller.on_contact_bite()` (cierre de mandíbulas y destello HDR); `_die()` llama a `visual_controller.on_die()` y desvanece `modulate:a` en `0.24s`.
3. **Paridad de Orientación:**
   - `_art_up_root.rotation = PI * 0.5` dentro de `VoidScarabRig25D`, de modo que `rotation = 0.0` apunta hacia `+X` igual que `EnemyBase.rotation = dir.angle()`.
4. **Alcance Explícito (No Tocados):**
   - Los jefes (`scenes/combat/bosses/`) y las estructuras estáticas de evento (`ResonanceContainmentNode`) conservan su visual dedicada y **no** montan `VoidScarabRig25D`.

---

## 2. Pipeline de Mapas 3+1 y Shader (`enemy_stylized_25d.gdshader`)

Cada una de las **7 piezas articuladas** (`body_core`, `mandible_l`, `mandible_r`, `inner_wing_l`, `inner_wing_r`, `elytron_l`, `elytron_r`) en `assets/enemies/void_scarab/` utiliza **4 mapas PNG** (`28` texturas en total):

| Sufijo | Canal / Contenido | Uso en Shader |
|---|---|---|
| `_albedo.png` | Color base sRGB + alfa | Base des-sombreable (`albedo_de_shade`) + fuente de luminancia HSV para recolor por zonas |
| `_normal.png` | `RGB` normal tangente + `A` heightfield | Relieve 2.5D (`relief_depth_px`), especular, fresnel/rim, iridiscencia y apertura 3D cóncava del élitron |
| `_ilm.png` | `R`: máscaras de material/zona · `G`: AO · `B`: **Ink SDF 2×** | `R/ID` para recolor multi-zona (`armor`, `accent`, `energy`); `G` para AO; `B` (`sdf_ink_line`, cargado sin mipmaps) para entintado caligráfico limpio |
| `_fx.png` | Emisivo / venas / máscara de movimiento | Flujo de plasma, núcleo reactor verde/variante y flexión orgánica (patas, abdomen, alas) |

### Invariantes Críticos del Shader

1. **Prohibido `* COLOR` al final de `fragment()`:** En Godot `canvas_item`, el parámetro de entrada `COLOR` ya llega pre-multiplicado (`albedo * vertex_modulate`). Multiplicar nuevamente por `COLOR` oscurece cuadráticamente al personaje. Siempre capturar `varying vec4 v_modulate = COLOR;` en `vertex()` y multiplicar por `v_modulate` al escribir `COLOR`.
2. **Protección de Croma Oscura por HSV Value (`orig_val`):** La quitina oscura del núcleo tiene ~47.5% de píxeles con luminancia Rec.601 `< 0.165`. Nunca filtrar tinta o recolor con `orig_luma`; usar `orig_val = max(r, max(g, b))` con `smoothstep(0.022, 0.062, orig_val)` junto a `ilm_sdf_tex.b` (`sdf_ink_line`, sin mipmaps).
3. **Élitrones 3D Cóncavos y Alas Shutter:** Los élitrones (`elytron_l/r`) proyectan caras convexa externa (`ely_face_mode = 1`) y cóncava oscura interna (`ely_face_mode = 2`) al abrirse en V en `CHARGE_TELEGRAPH`, revelando el núcleo interno y alas bio-mecánicas (`inner_wing_l/r`) con barrido estroboscópico de alta frecuencia (`wing_shutter_intensity`, `wing_strobe_phase`).
4. **Cero Sombras en Suelo Espacial:** En Cosmos Engine (`BackdropMode = 2` y combate real), las sombras proyectadas sobre un plano inferior están desactivadas (`is_floor_shadow_enabled() == false`).

---

## 3. Catálogo de Variantes en Producción (`default_enemy_visual_catalog.tres`)

Todos los enemigos estándar heredan `combat_base_rig_scale = 0.175` multiplicado por `size_multiplier`, con paleta de 3 canales (`armor_tint`, `accent_tint`, `energy_tint`) y cintas de vuelo opcionales (`enable_flight_ribbons`):

| `enemy_id` | Etiqueta (`display_label`) | Escala | Recolor | Cintas | Rol Visual / Paleta |
|---|---|---|---|---|---|
| `enemy_drone` | Void Scarab Base | `1.00×` | `false` | `false` | Quitina void base, acento púrpura, núcleo verde |
| `enemy_kamikaze` | Crimson Overlord | `0.94×` | `true` | `true` | Rojo carmesí agresivo con estelas de vuelo |
| `enemy_shooter` | Abyssal Sovereign | `1.12×` | `true` | `false` | Púrpura abisal / magenta |
| `enemy_tank` | Ironclad Juggernaut | `1.48×` | `true` | `false` | Acero bronce pesado / núcleo ámbar |
| `enemy_splitter` | Bio-Mitosis Jade | `1.14×` | `true` | `false` | Quitina jade / energía lima bio-mitótica |
| `enemy_splitter_micro` | Mitosis Micro-Cell | `0.96×` | `true` | `false` | Sub-clon jade compacto generado al dividir |
| `enemy_micro_flock` | Swarmlet Mint | `0.64×` | `true` | `false` | Enjambre diminuto cian-menta |
| `enemy_assault_cone` | Solar Charger | `1.34×` | `true` | `true` | Dorado solar de asalto con cintas activas |
| `enemy_vanguard_ring` | Cobalt Vanguard | `1.42×` | `true` | `true` | Azul cobalto / cian eléctrico con cintas activas |
| `enemy_specter_wave` | Astral Specter | `1.24×` | `true` | `true` | Violeta astral / rosa neón con cintas activas |
| `enemy_rainbow` | Prismatic Jackpot | `1.32×` | `true` (+ciclo HSV) | `true` | Ciclo prismático dinámico continuo + cintas activas |

---

## 4. Workbench (`EnemyArtLab`) y Verificación

- **Escena interactiva:** `sandbox/enemy_art_lab/enemy_art_lab.tscn` — inicia directamente en **Cosmos Live** (`BackdropMode = 2`) reproduciendo secuencias (`ControlMode = 0`) mediante `EnemySequenceDirector`. Posee controles en vivo de geometría 3D del élitron, iluminación `EnemyFactionStyle` y selector de variantes, leyendo el shader/rig de producción sin modificar `sandbox/enemy_art_lab/data/void_scarab_config.tres`.
- **Comandos de prueba:**
  - Integración producción: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_25d_production" -TimeoutSeconds 35`
  - Workbench sandbox + shader brace/invariants: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_art_lab" -TimeoutSeconds 35`
  - Compatibilidad outlines legacy: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_enemy_outline_suite" -TimeoutSeconds 35`
  - Regresión de spawning/crisis/campeones: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_crisis_events_suite"` y `-Test "test_alien_champions"`
