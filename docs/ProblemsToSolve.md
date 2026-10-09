# 📋 ProblemsToSolve — Registro de Deuda Técnica, Monolitos y God-Objects Residuales
**Fecha:** 2026-10-08 | **Versión:** Alpha 0.1 | **Hito Activo:** Milestone M7 (Balance Fino)

---

## 1. Resumen Ejecutivo

A lo largo de la jornada se desmantelaron los bloqueadores críticos primarios:
* ✅ 75 rutas rotas reparadas en documentación técnica.
* ✅ 136 archivos de staging duplicados eliminados en `addons/`.
* ✅ Desacoplamiento de los monolitos de mayor tránsito: `CharacterSelect` (modularizado en 4 controladores), `MainGame` (dividido en subsistemas y despachadores), y `Player` (locomoción y economía separadas).
* ✅ Descompresión de la "segunda capa" de modales: `arsenal_banlist_modal`, `weapon_selection_modal`, `transmutation_modal` y `pause_menu`.
* ✅ Micro-runner ultra rápido creado: `tools/run_unit_fast.ps1` (8.3 segundos).
* ✅ Corrección del bug de skins de Nyx y protección de rostro en shaders espaciales 3D del Hub con máscaras.

Este documento cataloga los **scripts largos (>400 líneas)**, **god-objects residuales** y **deudas técnicas arquitectónicas** que aún persisten para ser abordadas de forma quirúrgica cuando sea necesario.

---

## 2. Inventario de Scripts Largos y God-Objects Residuales

> Censo extraído de código fuente de producción (`.gd`), excluyendo tests (`tests/`), herramientas temporales (`tools/`), plugins externos (`addons/`) y cache (`.godot/`).

| Archivo | Líneas | Responsabilidades Acopladas / Diagnóstico | Prioridad |
|---|---|---|---|
| `scenes/combat/main_game.gd` | **1.088** | Orquestador central de escena. Aunque delegó oleadas e inputs, aún coordina pausa, audio, telemetría, game over, satélites y pools. | 🔴 Alta |
| `scenes/ui/character_select/character_select.gd` | **914** | Conserva inicialización de decenas de nodos `@onready`, mallas de foco cruzado, callbacks de tabs y conexión de señales. | 🔴 Alta |
| `scenes/ui/debug/ingame_debug_modal.gd` | **688** | Panel de trucos y comandos en partida: spawners arbitrarios, timescale, arcanas, economía y god-mode. | 🟡 Media (Debug) |
| `scenes/combat/player/player.gd` | **667** | Orquestador del jugador: colisiones, secuencias de muerte, efectos Sandevistan, arcanas y shaders. | 🟠 Media-Alta |
| `scenes/ui/hud/hud.gd` | **652** | Telemetría in-game completa: barras de vida, banners, EXP, cooldowns de armas, maldición y estadísticas. | 🟠 Media |
| `scenes/combat/directors/combat_boss_coordinator.gd` | **640** | Cinemáticas de colosos, barras de vida compuestas de jefes, drops de núcleos y eventos de derrota. | 🟠 Media |
| `scenes/ui/character_select/arsenal_banlist_modal.gd` | **637** | Bajó de 1.116 a 637 líneas. Mantiene sincronización visual densa con la interfaz padre. | 🟡 Media |
| `scenes/ui/character_select/tome_selection_modal.gd` | **624** | Construcción procedural de cartas de grimorios, cálculo de sinergias y navegación por código. | 🟠 Media |
| `scenes/ui/cosmetics/skin_selection_modal.gd` | **607** | Modal alternativo/antiguo de selección de skins; duplica parte de la lógica del carrusel nuevo. | 🟠 Media (Redundancia) |
| `scenes/ui/cosmetics/cosmetic_carousel_modal.gd` | **588** | Viewport 3D, animación de rotación de skins, inputs A/D/W/S, estrellas y shader de silueta. | 🟡 Media |
| `core/systems/persistence/profile_storage.gd` | **584** | Serialización JSON cruda de más de 25 campos con sanitización manual por fuerza bruta. | 🟠 Media |
| `scenes/ui/hub/hub_world.gd` | **572** | Orquestador del hangar 3D: colisiones de entorno, pedestales, interactables y terminales. | 🟠 Media |
| `scenes/combat/bosses/rival_pilot_boss.gd` | **565** | IA de pilotos rivales, diálogos reactivos, fases de duelo cinemático y patrones de balas. | 🟡 Media |
| `scenes/combat/satellite/satellite_shop.gd` | **547** | Tienda satelital in-run: generación de tarjetas, precios, rerolls, compra y animación. | 🟡 Media |
| `core/autoloads/bullet_server.gd` | **543** | Servidor SoA de balas masivas. *Nota: Tamaño justificado por optimización zero-allocation.* | 🟢 Baja (Válido) |
| `scenes/ui/gacha/gacha_modal.gd` | **525** | Ruleta cuántica, animaciones de cápsula, cálculo de pity y conversión de duplicados. | 🟡 Media |
| `scenes/ui/hub/components/hub_pilot_showcase_controller.gd` | **517** | Muestra de pedestales 3D, materiales y rotación de pilotos en el hangar. | 🟡 Media |
| `scenes/combat/player/weapon_controller.gd` | **499** | Orquestación de slots de armas activas, auto-apuntado, cadencias y spawn de disparos. | 🟠 Media |
| `scenes/ui/modals/weapon_swap_modal.gd` | **486** | Modal in-run para reemplazar armas cuando el inventario de 6 slots está lleno. | 🟡 Media |
| `scenes/ui/character_select/navigator_selection_modal.gd` | **480** | Selección y presentación de navegantes espaciales. | 🟡 Media |
| `core/systems/persistence/meta_progression_state.gd` | **480** | Fachada de metaprogresión: compras con biomasa, trofeos y desbloqueo de personajes. | 🟡 Media |
| `scenes/ui/character_select/pet_selection_modal.gd` | **467** | Selección y presentación de mascotas/drones acompañantes. | 🟡 Media |
| `scenes/ui/hud/components/hud_banner_manager.gd` | **455** | Gestor de avisos flotantes: desbloqueos, satélites, oleadas y banners de combate. | 🟡 Media |
| `scenes/ui/components/orbital_terminal/orbital_ignition_terminal.gd` | **445** | Terminal de ignición orbital y telemetría de lanzamiento en CharacterSelect. | 🟡 Media |
| `scenes/ui/hub/hub_player_controller_3d.gd` | **444** | Movimiento 3D y colisiones del jugador dentro del Hangar. | 🟡 Media |
| `scenes/combat/directors/combat_radio_feed_controller.gd` | **442** | Sistema de transmisión por radio y alertas de combate. | 🟡 Media |

---

## 3. Modales Gemelos Pendientes de Desacoplamiento (~450 - 625 líneas)

Existe una familia de modales que comparten la misma deuda técnica ya resuelta en `weapon_selection_modal` y `transmutation_modal`: construyen sus tarjetas visuales mediante bloques gigantes de código GDScript imperativo dentro del propio controlador:

1. **`tome_selection_modal.gd` (624 L):**
   * *Acción recomendada:* Extraer `TomeCardRenderer` y `TomePoolDataController`.
2. **`navigator_selection_modal.gd` (480 L):**
   * *Acción recomendada:* Extraer `NavigatorCardRenderer`.
3. **`pet_selection_modal.gd` (467 L):**
   * *Acción recomendada:* Extraer `PetCardRenderer`.
4. **`weapon_swap_modal.gd` (486 L):**
   * *Acción recomendada:* Reutilizar `WeaponCardRenderer` ya creado para la selección de armas.

---

## 4. Deudas Técnicas Arquitectónicas de Fondo

### A. Redundancia de Modales de Skins
* **Situación:** Conviven dos modales con el mismo propósito:
  1. `scenes/ui/cosmetics/cosmetic_carousel_modal.gd` (588 L) → El carrusel moderno 3D con shaders y estrellas.
  2. `scenes/ui/cosmetics/skin_selection_modal.gd` (607 L) → Modal en grilla anterior que todavía subsiste como fallback en `character_select.gd`.
* **Riesgo:** Duplicación de lógica de equipamiento y posibles desincronizaciones de loadouts.
* **Solución futura:** Eliminar o deprecatear definitivamente `skin_selection_modal.gd` redirigiendo todas las llamadas al carrusel moderno.

### B. Serialización por Diccionarios Planos (`profile_storage.gd`)
* **Situación:** `profile_storage.gd` almacena todo el estado del perfil en un único archivo JSON con más de 25 campos sin tipado estricto.
* **Riesgo:** Si se agrega o renombra una llave en el metajuego, se requiere validación manual exhaustiva en `clean_and_validate_data()`.
* **Solución futura:** Tipar los bloques del perfil (ej. `PlayerProfileData` Resource o DTOs tipados por subsistema).

### C. Acoplamiento de UI a Jerarquías de Nodos
* **Situación:** Uso disperso de `get_node_or_null("Ruta/Larga/De/Nodos")` y `find_child()`.
* **Riesgo:** Si un nodo se reordena en el editor de Godot, el script puede fallar silenciosamente en tiempo de ejecución.
* **Solución futura:** Migrar hacia `@export var` directos o contratos de interfaz por componente.

---

## 5. Hoja de Ruta de Intervención

```
PASO 1: HIGIENE INMEDIATA [COMPLETADO]
└── ✅ Commitear archivos .uid huérfanos y registrar docs/ProblemSolutions.md.

PASO 2: HITOS JUGABLES (MILESTONE M7)
└── Balance numérico en data/weapons/roster/*.tres y data/timeline/*.tres (sin tocar código).

PASO 3: MODULARES A DEMANDA (Solo si se requiere expandir la funcionalidad)
└── Tome Selection Modal → TomeCardRenderer.
└── Weapon Swap Modal → Reutilizar WeaponCardRenderer.
└── Unificar sistema de skins eliminando skin_selection_modal.gd.
```
