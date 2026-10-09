# Contexto del Agente — Astra Dream
> **Leer este archivo SIEMPRE antes de explorar cualquier otro.**
> Contiene todo lo necesario para orientarse en una sesión sin exploración ciega.

**Versión:** Alpha 0.1 · **Motor:** Godot 4.7.2 · **Milestone activo:** M7 (Balance Fino)

---

## 🗂️ Mapa Sistema → Archivo Principal

> Para encontrar el código de cualquier sistema, ir primero a este archivo.
> Leer solo el rango indicado mediante `view_file` con `StartLine` y `EndLine` — no el archivo completo.

| Si el cambio/bug está en... | Archivo | Rango clave |
| Selección de personaje (ESC, launch, skins, hero picker) | `scenes/ui/character_select/character_select.gd` | Orquestador: L234, Input: L447, Roster: L488 |
| Enrutamiento de modales CharacterSelect | `scenes/ui/character_select/components/character_select_modal_router.gd` | — |
| Presentación visual y habilidades CharacterSelect | `scenes/ui/character_select/components/character_select_display_manager.gd` | — |
| Secuencia de lanzamiento y retorno Hub | `scenes/ui/character_select/components/character_select_launch_controller.gd` | — |
| Coordinador de skins / companion / gacha | `scenes/ui/character_select/components/character_skin_coordinator.gd` | — |
| Malla y router de foco teclado/gamepad | `scenes/ui/character_select/components/character_focus_router.gd` | — |
| Combate (oleadas, bosses, rivales, modales in-run) | `scenes/combat/main_game.gd` | Encounters: L773, Bosses: L834, Game over: L1099 |
| Pipeline y ciclo de vida de oleadas | `scenes/combat/directors/combat_wave_pipeline.gd` | State machine & subsystem dispatch |
| Contexto desacoplado de combate | `scenes/combat/systems/combat_context.gd` | Inyección de actores centrales |
| Interfaz base de subsistemas Plug&Play | `scenes/combat/systems/combat_subsystem.gd` | Contrato virtual CombatSubsystem |
| Fin de partida y derrota | `scenes/combat/controllers/combat_end_run_controller.gd` | Telemetría y modal de game over |
| Jugador (movimiento, dash, bomba, daño, muerte) | `scenes/combat/player/player.gd` | Movement: L426, Dash: L475, Damage: L615 |
| Hub 3D (hangar, pilotos, terminales, skill tree) | `scenes/ui/hub/hub_world.gd` | Pilot select: L382, Interactables: L312 |
| Coordinación de jefes y colosos (CombatSubsystem) | `scenes/combat/directors/combat_boss_coordinator.gd` | — |
| Narrativa, radio, diálogos in-run (CombatSubsystem) | `scenes/combat/directors/combat_narrative_director.gd` | — |
| Satélites orbitales y odómetro (CombatSubsystem) | `scenes/combat/systems/combat_satellite_coordinator.gd` | — |
| Recompensas y tragamonedas (CombatSubsystem) | `scenes/combat/systems/combat_loot_coordinator.gd` | — |
| Skins / cosméticos / recolors | `core/systems/cosmetics_manager.gd` | DB load: L1 |
| Sistema de save y persistencia | `core/autoloads/save_manager.gd` | Fachada estática → delega en core/systems/persistence/ |
| Perfil del jugador (biomasa, trofeos, unlocks) | `core/systems/persistence/meta_progression_state.gd` | — |
| Run activa (armas, ítems, estado de partida) | `core/systems/persistence/active_run_storage.gd` | — |
| Items y loot pool | `core/types/item_pool_manager.gd` | — |
| Satélite orbital (tienda in-run) | `scenes/combat/satellite/satellite_shop.gd` | — |
| Tarjetas de tienda | `scenes/combat/satellite/components/satellite_shop_card_builder.gd` | — |
| Gacha modal | `scenes/ui/cosmetics/gacha_modal.gd` | — |
| Carrusel de skins | `scenes/ui/cosmetics/cosmetic_carousel_modal.gd` | — |
| Transición entre escenas | `core/autoloads/scene_transition.gd` | — |
| Pausa (tokens de pausa) | `core/autoloads/pause_arbitrator.gd` | — |
| Audio y música | `core/autoloads/audio_manager.gd` | — |
| Debug de combate (F1 en partida) | `scenes/ui/debug/ingame_debug_modal.gd` | — |
| Debug de metajuego (Character Select) | `scenes/ui/debug/debug_menu_modal.gd` | — |

---

## 🚫 ZONAS PROHIBIDAS — Nunca explorar

```
addons/                  ← Plugin Godot AI (herramienta, no es código del juego)
addons/.godot_ai_update/ ← Staging obsoleto de actualización del addon
.godot/                  ← Cache del motor, generado automáticamente
scratch/                 ← Código temporal, ignorado por git
sandbox/                 ← Shaders y escenas de prueba
preprocess/              ← Fuentes crudas de arte (JPGs sin procesar, 23 MB)
```

Si el agente necesita encontrar algo y no está en la tabla de arriba → leer
`docs/DOMAIN_MAP.md` → luego `ARCHITECTURE.md`. Nunca explorar el árbol de carpetas
directamente.

---

## ⚙️ Los 7 Autoloads (Servicios Globales)

Acceder via nombre de clase directamente. No referenciar por ruta de nodo.

| Autoload | Ruta del script | Responsabilidad |
|---|---|---|
| `PauseArbitrator` | `res://core/autoloads/pause_arbitrator.gd` | Tokens de pausa concurrentes. **NUNCA** asignar `get_tree().paused` directo. |
| `SettingsManager` | `res://core/autoloads/settings_manager.gd` | Gráficos, volumen, controles |
| `SaveManager` | `res://core/autoloads/save_manager.gd` | Fachada de persistencia (delega en `core/systems/persistence/`) |
| `DebugManager` | `res://core/autoloads/debug_manager.gd` | Poda de debug en producción. Usar `DebugManager.is_debug_enabled()` |
| `EventBus` | `res://core/autoloads/event_bus.gd` | Señales globales desacopladas |
| `AudioManager` | `res://core/autoloads/audio_manager.gd` | BGM, SFX, anti-fatiga |
| `SceneTransition` | `res://core/autoloads/scene_transition.gd` | Fundidos entre escenas |

> `BulletServer` no es autoload — es nodo hijo de `MainGame`.

---

## 🏗️ Contratos de Arquitectura Obligatorios

**Modales:** Todo modal extiende `BaseModal` (`res://scenes/ui/components/base_modal.gd`).
Asignar `modal_token = &"nombre"` en `_ready()`. Usar `open_modal()` y `close_modal()`.
**Nunca** gestionar `PauseArbitrator` manualmente desde un modal.

**Daño:** Todo daño viaja en `HitContext`. Todo enemigo implementa `take_damage(ctx: HitContext)`.
`proc_coefficient = 0.0` en proyectiles hijos (Regla Cero Balística).

**Saves:** Nunca escribir directo a `user://`. Siempre usar `SaveManager.*` o los módulos
en `core/systems/persistence/`.

---

## 🧪 Cómo Correr Tests (Iteración Rápida)

```powershell
# 1. EN ITERACIÓN ACTIVA: Suite específica del módulo tocado (2-3 segundos)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_weapons_runner.tscn"

# 2. AL FINALIZAR TAREA: Regresión Core completa (21 suites, ~80 seg)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly

# 3. Solo para CI / validación total (~25 min)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

> **Regla de Oro:** Durante el desarrollo, **NUNCA** correr `-CoreOnly` en bucle repetitivo. Usar `-Test <suite>` correspondiente para tener feedback instantáneo de 2 segundos. Correr `-CoreOnly` solo una vez antes del commit final.


---

## 📊 Estado Actual

| Campo | Valor |
|---|---|
| Versión | Alpha 0.1 |
| Milestone activo | **M7** — Balance Fino de Combate y Feedback |
| M7.1 | Rebalanceo 8 armas base → `data/weapons/roster/*.tres` |
| M7.2 | Oleadas y colosos → `data/timeline/default_encounter_timeline.tres` |
| M7.3 | Drop rates y créditos → `data/items/roster/*.tres` |
| M7.4 | Feedback audiovisual → `scenes/combat/enemies/`, `scenes/ui/hud/` |

---

## 🐛 Bugs Conocidos Pendientes

| Bug | Archivo principal | Estado |
|---|---|---|
| Nyx desbloqueada permanentemente (workaround temporal) | `character_select.gd` L629, `meta_progression_state.gd` | Pendiente restaurar condición de unlock |
| ValentinaO2 / RoxyO2 sin integrar al Hub3D | `hub_world.gd`, `hub_pilot_showcase_controller.gd` | Pendiente sesión de integración |

---

## 📋 Template de Inicio de Sesión

Copiar y completar al iniciar cada conversación:

```
[SESIÓN ASTRA DREAM]
Sistema: [CHARACTER_SELECT | HUD | COMBAT | HUB | PERSISTENCIA | BALANCE | COSMETICS | ART]
Contexto: [qué se hizo la última vez en este sistema]
Archivos probables: [2-4 archivos]
Pedidos (máx. 4):
  1.
  2.
  3.
```
