# 🛠️ ProblemSolutions — Abordaje Técnico y Soluciones de Desacoplamiento

**Fecha:** 2026-10-09 | **Versión:** Alpha 0.1 | **Referencia Directa:** [`docs/ProblemsToSolve.md`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/ProblemsToSolve.md)

Este documento define el **diseño arquitectónico detallado, las responsabilidades a extraer, los contratos de interfaz y la estrategia de verificación** para cada uno de los conflictos, monolitos residuales y deudas técnicas identificadas en el proyecto Astra Dream.

---

## 📑 Índice de Contenidos

1. [Principios Transversales de Refactorización](#1-principios-transversales-de-refactorización)
2. [Solución a Deudas Técnicas Arquitectónicas de Fondo](#2-solución-a-deudas-técnicas-arquitectónicas-de-fondo)
   - [2.1 Redundancia de Modales de Skins](#21-redundancia-de-modales-de-skins)
   - [2.2 Serialización Débil en Persistencia (`profile_storage.gd`)](#22-serialización-débil-en-persistencia-profile_storagegd)
   - [2.3 Acoplamiento Frágil a Jerarquías de Nodos UI](#23-acoplamiento-frágil-a-jerarquías-de-nodos-ui)
3. [Solución a Modales Gemelos (Card Renderers & Pools)](#3-solución-a-modales-gemelos-card-renderers--pools)
   - [3.1 `tome_selection_modal.gd`](#31-tome_selection_modalgd)
   - [3.2 `navigator_selection_modal.gd`](#32-navigator_selection_modalgd)
   - [3.3 `pet_selection_modal.gd`](#33-pet_selection_modalgd)
   - [3.4 `weapon_swap_modal.gd`](#34-weapon_swap_modalgd)
4. [Abordaje Quirúrgico por Monolito Residual (>400 Líneas)](#4-abordaje-quirúrgico-por-monolito-residual-400-líneas)
   - [4.1 `scenes/combat/main_game.gd` (1.088 L)](#41-scenescombatmain_gamegd-1088-l)
   - [4.2 `scenes/ui/character_select/character_select.gd` (914 L)](#42-scenesuicharacter_selectcharacter_selectgd-914-l)
   - [4.3 `scenes/ui/debug/ingame_debug_modal.gd` (688 L)](#43-scenesuidebugingame_debug_modalgd-688-l)
   - [4.4 `scenes/combat/player/player.gd` (667 L)](#44-scenescombatplayerplayergd-667-l)
   - [4.5 `scenes/ui/hud/hud.gd` (652 L)](#45-scenesuihudhudgd-652-l)
   - [4.6 `scenes/combat/directors/combat_boss_coordinator.gd` (640 L)](#46-scenescombatdirectorscombat_boss_coordinatorgd-640-l)
   - [4.7 `scenes/ui/character_select/arsenal_banlist_modal.gd` (637 L)](#47-scenesuicharacter_selectarsenal_banlist_modalgd-637-l)
   - [4.8 `scenes/ui/cosmetics/cosmetic_carousel_modal.gd` (588 L)](#48-scenesuicosmeticscosmetic_carousel_modalgd-588-l)
   - [4.9 `scenes/ui/hub/hub_world.gd` (572 L)](#49-scenesuihubhub_worldgd-572-l)
   - [4.10 `scenes/combat/bosses/rival_pilot_boss.gd` (565 L)](#410-scenescombatbossesrival_pilot_bossgd-565-l)
   - [4.11 `scenes/combat/satellite/satellite_shop.gd` (547 L)](#411-scenescombatsatellitesatellite_shopgd-547-l)
   - [4.12 `core/autoloads/bullet_server.gd` (543 L - Justificado)](#412-coreautoloadsbullet_servergd-543-l---justificado)
   - [4.13 `scenes/ui/gacha/gacha_modal.gd` (525 L)](#413-scenesuigachagacha_modalgd-525-l)
   - [4.14 `scenes/ui/hub/components/hub_pilot_showcase_controller.gd` (517 L)](#414-scenesuihubcomponentshub_pilot_showcase_controllergd-517-l)
   - [4.15 `scenes/combat/player/weapon_controller.gd` (499 L)](#415-scenescombatplayerweapon_controllergd-499-l)
   - [4.16 `core/systems/persistence/meta_progression_state.gd` (480 L)](#416-coresystemspersistencemeta_progression_stategd-480-l)
   - [4.17 `scenes/ui/hud/components/hud_banner_manager.gd` (455 L)](#417-scenesuihudcomponentshud_banner_managergd-455-l)
   - [4.18 `scenes/ui/components/orbital_terminal/orbital_ignition_terminal.gd` (445 L)](#418-scenesuicomponentsorbital_terminalorbital_ignition_terminalgd-445-l)
   - [4.19 `scenes/ui/hub/hub_player_controller_3d.gd` (444 L)](#419-scenesuihubhub_player_controller_3dgd-444-l)
   - [4.20 `scenes/combat/directors/combat_radio_feed_controller.gd` (442 L)](#420-scenescombatdirectorscombat_radio_feed_controllergd-442-l)
5. [Matriz de Priorización y Flujo de Verificación](#5-matriz-de-priorización-y-flujo-de-verificación)

---

## 1. Principios Transversales de Refactorización

Para cada componente o controlador que se descomponga, deben respetarse las siguientes reglas del motor:
1. **Composición sobre Herencia:** Extraer nodos hijos controladores tipo `Node` sin estado visual innecesario, inyectados vía `@export` o instanciados en `_ready()`.
2. **Tipado Estricto 100%:** Toda variable, parámetro y tipo devuelto debe tener anotación estricta de tipo GDScript 4 (`func bind(target: CanvasItem) -> void:`).
3. **Contratos Inmutables / DTOs:** Pasar datos entre componentes a través de structs/Resources o DTOs en lugar de diccionarios planos con llaves arbitrarias.
4. **Verificación Aislada Inmediata:** Probar cada extracción con micro-tests dedicados (`tools/run_unit_fast.ps1` o suites específicas).

---

## 2. Solución a Deudas Técnicas Arquitectónicas de Fondo

### 2.1 Redundancia de Modales de Skins
* **Problema:** Coexisten `skin_selection_modal.gd` (607 L, rejilla heredada) y `cosmetic_carousel_modal.gd` (588 L, carrusel 3D con shaders). Genera dispersión de llamadas y duplicación de `CosmeticsManager.equip_skin()`.
* **Abordaje:**
  1. **Auditoría de Invocadores:** Buscar todas las referencias a `skin_selection_modal.tscn` en el proyecto (principalmente en `character_skin_coordinator.gd` y `character_select.gd`).
  2. **Unificación:** Modificar `character_skin_coordinator.gd` para abrir exclusivamente `cosmetic_carousel_modal.tscn`.
  3. **Deprecación y Eliminación:** Eliminar `scenes/ui/cosmetics/skin_selection_modal.gd` y `skin_selection_modal.tscn`. Si se requiere soporte de vista de rejilla en el futuro, integrarla como vista alternativa secundaria dentro del carrusel, no como modal paralelo.
* **Suite de Verificación:** `test_nyx_skins_and_hub_shader_suite.gd` y `test_character_select_runner.tscn`.

### 2.2 Serialización Débil en Persistencia (`profile_storage.gd`)
* **Problema:** 584 líneas donde un único diccionario plano con >25 llaves se sanitiza campo por campo por fuerza bruta en `clean_and_validate_data()`.
* **Abordaje:**
  1. **Estructura en DTOs Modulares:** Crear clases de datos en `core/systems/persistence/dto/`:
     - `EconomyProfileDTO.gd` (créditos, biomasa, materia oscura, rerolls).
     - `UnlockProfileDTO.gd` (personajes desbloqueados, armas habilitadas, skins adquiridas).
     - `StatisticsProfileDTO.gd` (runs completadas, enemigos derrotados, jefes caídos).
     - `SettingsProfileDTO.gd` (preferencias de usuario ligadas a perfil).
  2. **Métodos `to_dict()` y `from_dict()`:** Cada DTO valida y sanea sus propios datos con valores por defecto estrictos.
  3. **Refactor de `profile_storage.gd`:** Delegar la carga y sanitización a los DTOs correspondientes. `clean_and_validate_data()` pasa a tener menos de 40 líneas.
* **Suite de Verificación:** `test_save_manager_runner.tscn`.

### 2.3 Acoplamiento Frágil a Jerarquías de Nodos UI
* **Problema:** Múltiples componentes acceden a elementos visuales profundos usando cadenas de texto como `get_node_or_null("MarginContainer/VBoxContainer/Panel/...")` o llamadas genéricas a `find_child()`.
* **Abordaje:**
  1. **Uso de `@export` Tipados:** Convertir referencias nodales críticas en variables exportadas directamente en la raíz de cada escena `.tscn`.
  2. **Encapsulamiento en Sub-Vistas:** Ningún controlador superior debe acceder a los hijos de un contenedor interno; debe comunicarse invocando métodos públicos de la sub-vista (ej. `panel.set_highlight(true)` en lugar de `panel.get_node("Border").modulate = ...`).
  3. **Desacoplamiento por Señales:** Reemplazar llamadas ascendentes por señales emitidas hacia el nodo padre.

---

## 3. Solución a Modales Gemelos (Card Renderers & Pools)

Los siguientes modales construyen proceduralmente interfaces densas dentro de su lógica de control. Se resolverán siguiendo el patrón exitoso de `weapon_selection_modal` y `transmutation_modal`.

### 3.1 `tome_selection_modal.gd` (624 L)
* **División Arquitectónica:**
  - `TomeCardRenderer.gd` (~180 L): Encargado del inflado de nodos visuales, asignación de glifos, tooltips de sinergias y estilos de borde.
  - `TomePoolDataController.gd` (~150 L): Encargado de consultar grimorios disponibles, filtrar tomes ya aprendidos y resolver ponderaciones de rareza.
  - `tome_selection_modal.gd` (~180 L): Se mantiene únicamente como enrutador de input, orquestador de apertura/cierre (`BaseModal`) y emisor de selección.

### 3.2 `navigator_selection_modal.gd` (480 L)
* **División Arquitectónica:**
  - `NavigatorCardRenderer.gd` (~160 L): Construcción de tarjeta de tripulante/navegante, perks pasivos y retratos.
  - `navigator_selection_modal.gd` (~200 L): Gestión de navegación por teclado/gamepad, foco y confirmación de selección.

### 3.3 `pet_selection_modal.gd` (467 L)
* **División Arquitectónica:**
  - `PetCardRenderer.gd` (~150 L): Presentación de drones y acompañantes, stats de soporte y visualizador de perks.
  - `pet_selection_modal.gd` (~190 L): Coordinación de slots activos, equipamiento y guardado de acompañante seleccionado.

### 3.4 `weapon_swap_modal.gd` (486 L)
* **División Arquitectónica:**
  - Reutilización de `WeaponCardRenderer.gd` (ya existente en `scenes/ui/character_select/components/weapon_card_renderer.gd`): Evita código duplicado para representar tarjetas de armas en combate.
  - `weapon_swap_modal.gd` (~190 L): Se enfoca exclusivamente en la comparación del arma nueva entrante contra los 6 slots actuales del jugador y confirmación del reemplazo.

---

## 4. Abordaje Quirúrgico por Monolito Residual (>400 Líneas)

### 4.1 `scenes/combat/main_game.gd` (1.088 L)
* **Diagnóstico:** Pese a haber delegado oleadas e inputs, aún orquesta pools de partículas, satélites, estadísticas de fin de partida, música y señales de pausa.
* **Componentes a Extraer:**
  1. `CombatTelemetryCoordinator.gd` (~220 L): Recopilación de estadísticas de la run (daño total, DPS, kills por arma, tiempo de supervivencia, biomasa recolectada) y empaquetado para el modal de game over.
  2. `CombatSatelliteCoordinator.gd` (~200 L): Encapsula la activación de la tienda satelital orbital, odómetro espacial y recompensas de pasarela.
  3. `CombatVfxPoolManager.gd` (~160 L): Gestión de pools de impacto, destellos y efectos de escenario que no corresponden a balas SoA.
* **Resultado:** `main_game.gd` se reduce a un orquestador limpio de ~380 líneas.

### 4.2 `scenes/ui/character_select/character_select.gd` (914 L)
* **Diagnóstico:** Concentra inicializaciones de decenas de nodos, conexiones manuales de tabs, mallas de foco y callbacks visuales.
* **Componentes a Extraer / Reubicar:**
  1. Migrar la orquestación de tabs (Navegantes, Armas, Mascotas, Dificultad) a un `CharacterSelectTabController.gd` (~220 L).
  2. Trasladar la configuración inicial de mallas de foco a `character_focus_router.gd`.
  3. Trasladar la carga inicial de datos de desbloqueos a `character_skin_coordinator.gd`.
* **Resultado:** `character_select.gd` desciende a ~350 líneas centradas en la máquina de estados de selección.

### 4.3 `scenes/ui/debug/ingame_debug_modal.gd` (688 L)
* **Diagnóstico:** Panel masivo de comandos de prueba (spawners, timescale, invencibilidad, balance de stats, monedas).
* **Componentes a Extraer:**
  1. `DebugSpawnPanel.gd` (~180 L): Lógica de generación arbitraria de enemigos, élites y jefes.
  2. `DebugEconomyPanel.gd` (~140 L): Inyección de recursos (biomasa, créditos, EXP, ítems).
  3. `DebugPlayerTweakPanel.gd` (~150 L): God mode, velocidad, daño forzado, cooldown cero.
* **Resultado:** `ingame_debug_modal.gd` pasa a ser un contenedor de pestañas de ~150 líneas.

### 4.4 `scenes/combat/player/player.gd` (667 L)
* **Diagnóstico:** Gestiona colisiones, secuencias de muerte/revivir, efectos de Sandevistan, arcanas activas y shaders de hit.
* **Componentes a Extraer:**
  1. `PlayerHitReactionController.gd` (~180 L): Implementación del contrato `take_damage(ctx: HitContext)`, cálculo de shields, i-frames y trigger de muerte.
  2. `PlayerVfxCoordinator.gd` (~160 L): Estiramiento de sprite, rastro Sandevistan, shaders de daño y efectos visuales de aura.
* **Resultado:** `player.gd` queda en ~320 líneas actuando como raíz y contenedor del `CombatContext`.

### 4.5 `scenes/ui/hud/hud.gd` (652 L)
* **Diagnóstico:** Orquesta todas las lecturas de telemetría: barras de salud, experiencia, cooldowns de 6 armas, maldición y avisos de oleadas.
* **Componentes a Extraer:**
  1. `HudHealthShieldDisplay.gd` (~150 L): Interpolación visual de barras de vida, escudo y efectos de baja salud.
  2. `HudWeaponCooldownBar.gd` (~160 L): Renderizado de slots de armas, iconos y radial sweeps de recarga.
* **Resultado:** `hud.gd` desciende a ~280 líneas como enrutador de señales desde `CombatContext`.

### 4.6 `scenes/combat/directors/combat_boss_coordinator.gd` (640 L)
* **Diagnóstico:** Controla secuencias cinemáticas de presentación de jefes, barras de vida compuestas multiparte, drops de núcleos y transiciones de fase.
* **Componentes a Extraer:**
  1. `BossCinematicSequence.gd` (~180 L): Slow-motion, banners de presentación con nombre/título y cámaras fijas.
  2. `BossHealthBarManager.gd` (~160 L): Vinculación y actualización de barras de vida colosales en pantalla.
* **Resultado:** `combat_boss_coordinator.gd` pasa a ~260 líneas dedicadas a la máquina de estados del jefe.

### 4.7 `scenes/ui/character_select/arsenal_banlist_modal.gd` (637 L)
* **Diagnóstico:** Mantiene acoplamiento de sincronización visual densa con la interfaz padre de selección.
* **Componentes a Extraer:**
  1. `ArsenalFilterBar.gd` (~140 L): Pestañas de filtrado (armas primarias, secundarias, elementos, tipos).
  2. Delegar la confirmación y persistencia de bans al `ArsenalBanlistDataController` ya existente.
* **Resultado:** `arsenal_banlist_modal.gd` baja a ~320 líneas.

### 4.8 `scenes/ui/cosmetics/cosmetic_carousel_modal.gd` (588 L)
* **Diagnóstico:** Integra la simulación 3D del modelo rotatorio, gestión de shaders, inputs de teclado y navegación de tarjetas en un único script.
* **Componentes a Extraer:**
  1. `Carousel3DStageController.gd` (~180 L): Configuración del `SubViewport`, cámara, luces orbitales e instanciación de mallas/shaders del personaje.
* **Resultado:** `cosmetic_carousel_modal.gd` queda en ~320 líneas centrado en la selección y compra de aspectos.

### 4.9 `scenes/ui/hub/hub_world.gd` (572 L)
* **Diagnóstico:** Monolito del hangar: gestiona colisiones 3D de entorno, interacción con pedestales, terminal de partida y shaders ambientales.
* **Componentes a Extraer:**
  1. `HubInteractableCoordinator.gd` (~180 L): Detección de proximidad y despacho de prompts de interacción ("Presiona E para abrir Terminal").
* **Resultado:** `hub_world.gd` se reduce a ~340 líneas.

### 4.10 `scenes/combat/bosses/rival_pilot_boss.gd` (565 L)
* **Diagnóstico:** IA de combate, despacho de diálogos cinemáticos por radio y patrones danmaku en un solo script.
* **Componentes a Extraer:**
  1. `RivalPilotDialogueTrigger.gd` (~130 L): Disparo de líneas de voz y radio según umbrales de vida (100%, 50%, 15%, derrota).
  2. Patrones balísticos delegados a recursos `DanmakuPatternConfig` en lugar de funciones matemáticas hardcodeadas.
* **Resultado:** `rival_pilot_boss.gd` baja a ~320 líneas.

### 4.11 `scenes/combat/satellite/satellite_shop.gd` (547 L)
* **Diagnóstico:** Generación procedural de tarjetas, cálculo de precios inflados por rerolls, transacciones y animaciones de compra.
* **Componentes a Extraer:**
  1. `SatelliteTransactionController.gd` (~160 L): Lógica matemática de costos, compra de mejoras y actualización de créditos en `SaveManager`.
* **Resultado:** `satellite_shop.gd` desciende a ~300 líneas.

### 4.12 `core/autoloads/bullet_server.gd` (543 L - Justificado)
* **Diagnóstico:** Servidor SoA (Structure of Arrays) de balas en pools contiguos (`PackedFloat32Array`).
* **Resolución:** **No fragmentar**. Su longitud está estrictamente justificada por el requisito arquitectónico de **Zero-Allocation en Combate** (Regla 1 de `core_rules.md`). La división en sub-objetos generaría overhead de llamadas por frame e invalidaría la optimización SoA. Se mantiene catalogado como excepción técnica válida.

### 4.13 `scenes/ui/gacha/gacha_modal.gd` (525 L)
* **Diagnóstico:** Animación de apertura de cápsulas cuánticas, lógica de pity progresivo, conversión de duplicados a biomasa y control de botones.
* **Componentes a Extraer:**
  1. `GachaPityEngine.gd` (~140 L): Lógica matemática pura de probabilidades, pity counter y cálculo de duplicados.
  2. `GachaRevealAnimationPlayer.gd` (~150 L): Secuencia de apertura visual y partículas.
* **Resultado:** `gacha_modal.gd` se reduce a ~210 líneas.

### 4.14 `scenes/ui/hub/components/hub_pilot_showcase_controller.gd` (517 L)
* **Diagnóstico:** Carga de materiales, rotación de pedestales 3D, swaps de mallas y cálculo de reflejos para los pilotos en exhibición.
* **Componentes a Extraer:**
  1. `PilotPedestalMaterialBinder.gd` (~160 L): Asignación de shaders, mapas de normales y máscaras faciales a los modelos 3D.
* **Resultado:** El controlador baja a ~320 líneas.

### 4.15 `scenes/combat/player/weapon_controller.gd` (499 L)
* **Diagnóstico:** Orquesta los 6 slots activos de armas, el sistema de auto-targeting radial y el disparo temporizado.
* **Componentes a Extraer:**
  1. `CombatTargetingSystem.gd` (~160 L): Algoritmos de selección de objetivos (enemigo más cercano, jefe prioritario, mayor masa de salud).
* **Resultado:** `weapon_controller.gd` pasa a ~300 líneas.

### 4.16 `core/systems/persistence/meta_progression_state.gd` (480 L)
* **Diagnóstico:** Maneja compras del árbol de habilidades, trofeos de logros y estado de desbloqueo de pilotos.
* **Componentes a Extraer:**
  1. `MetaSkillTreeEngine.gd` (~150 L): Validación de requisitos de nodo del árbol y cálculo de costos con biomasa.
* **Resultado:** `meta_progression_state.gd` baja a ~300 líneas.

### 4.17 `scenes/ui/hud/components/hud_banner_manager.gd` (455 L)
* **Diagnóstico:** Cola de avisos visuales concurrentes (avisos de oleadas, jefes, satélites, logros).
* **Componentes a Extraer:**
  1. `HudBannerQueue.gd` (~140 L): Estructura de cola FIFO con prioridades y temporizadores de descarte.
* **Resultado:** `hud_banner_manager.gd` desciende a ~280 líneas.

### 4.18 `scenes/ui/components/orbital_terminal/orbital_ignition_terminal.gd` (445 L)
* **Diagnóstico:** Animaciones de cuenta regresiva, telemetría de satélite y confirmación de lanzamiento en CharacterSelect.
* **Componentes a Extraer:**
  1. `OrbitalIgnitionVisuals.gd` (~150 L): Interpolaciones de luces, shaders de escáner y efectos de partículas.
* **Resultado:** `orbital_ignition_terminal.gd` desciende a ~260 líneas.

### 4.19 `scenes/ui/hub/hub_player_controller_3d.gd` (444 L)
* **Diagnóstico:** Locomoción 3D en tercera persona, aceleración, cámara orbitante y detección de pasos.
* **Componentes a Extraer:**
  1. `HubCameraSpringArmController.gd` (~130 L): Suavizado de giro de cámara con mouse/gamepad y oclusión de colisiones.
* **Resultado:** `hub_player_controller_3d.gd` pasa a ~280 líneas.

### 4.20 `scenes/combat/directors/combat_radio_feed_controller.gd` (442 L)
* **Diagnóstico:** Cola de transmisiones por voz, retratos animados, teletipo de texto y prioridades de interrupción de radio.
* **Componentes a Extraer:**
  1. `RadioMessageQueue.gd` (~130 L): Cola de mensajes con descarte por caducidad y orden de prioridad.
* **Resultado:** `combat_radio_feed_controller.gd` se reduce a ~280 líneas.

---

## 5. Matriz de Priorización y Flujo de Verificación

```
[Prioridad 1: Higiene Inmediata]
└── Limpieza de .uid y sync git  ──>  Verificar: git status -s + run_unit_fast.ps1

[Prioridad 2: Eliminación de Redundancia Crítica]
└── skin_selection_modal.gd      ──>  Verificar: test_nyx_skins_and_hub_shader_suite.gd

[Prioridad 3: Desacoplamiento de Modales Gemelos]
├── tome_selection_modal.gd      ──>  Extraer TomeCardRenderer + Pool
├── navigator_selection_modal.gd ──>  Extraer NavigatorCardRenderer
├── pet_selection_modal.gd       ──>  Extraer PetCardRenderer
└── weapon_swap_modal.gd         ──>  Reutilizar WeaponCardRenderer
                                 └──  Verificar: suites de modales + run_unit_fast.ps1

[Prioridad 4: Monolitos Centrales del Juego (>600 L)]
├── main_game.gd                 ──>  Extraer Telemetría + Satélites
├── character_select.gd          ──>  Extraer TabController + Focus
├── player.gd                    ──>  Extraer HitReaction + VfxCoordinator
├── hud.gd                       ──>  Extraer Bars + WeaponDisplay
└── combat_boss_coordinator.gd   ──>  Extraer Cinematic + HealthBars
                                 └──  Verificar: tests de subsistemas tocados

[Prioridad 5: Persistencia Tipada y Monolitos Menores]
├── profile_storage.gd           ──>  Crear DTOs tipados por subsistema
└── Resto de monolitos (440-570L)──>  Extracción gradual en componentes auxiliares
                                 └──  Verificar: -CoreOnly final
```

---

## 6. Plan de Sesiones Atómicas (1 Sesión = 1 Conversación)

Siguiendo la **Regla 9 de Higiene de Sesiones Atómicas** (cumplir el principio de *1 Tarea / Bugfix = 1 Conversación* para no arrastrar contextos mayores a 60k–80k tokens), la ejecución completa se estructura en **12 sesiones independientes**:

| Sesión | Foco / Misión Principal | Archivos Involucrados | Suite de Verificación |
|---|---|---|---|
| **Sesión 1** | ✅ **Higiene Inmediata & Sincronización (Resuelta)** | `git add *.uid`, `docs/ProblemsToSolve.md`, `docs/ProblemSolutions.md`, `docs/architecture/TODO.md` | `tools/run_unit_fast.ps1` (PASS) |
| **Sesión 2** | ✅ **Unificación de Sistema de Skins (Resuelta)** | Modificar `character_skin_coordinator.gd`, eliminar `skin_selection_modal.gd` y `.tscn` | `test_slot_machine_and_gacha_runner.tscn`, `test_character_select_runner.tscn` (PASS) |
| **Sesión 3** | ✅ **Modales Gemelos: Grimorios & Weapon Swap (Resuelta)** | Creados `TomeCardRenderer.gd`, `TomePoolDataController.gd`, `TomeSelectionDetailPanel.gd`, `WeaponSwapCardBuilder.gd`; desacoplados `tome_selection_modal.gd` y `weapon_swap_modal.gd` | `test_talents_and_tomes_blur_runner.tscn`, `test_tomes_and_infinite_weapons_runner.tscn`, `test_weapon_swap_and_hud_runner.tscn`, `tools/run_unit_fast.ps1` (PASS) |
| **Sesión 4** | ✅ **Modales Gemelos: Navegantes & Mascotas (Resuelta)** | Creados `NavigatorCardRenderer.gd`, `NavigatorDataController.gd`, `PetCardRenderer.gd`, `PetDataController.gd`; desacoplados `navigator_selection_modal.gd` y `pet_selection_modal.gd` | `tools/run_unit_fast.ps1` (PASS) |
| **Sesión 5** | ✅ **Monolito MainGame (Parte 1: Telemetría & Satélite) (Resuelta)** | Creado `CombatTelemetryCoordinator.gd`, delegación de compras a `CombatSatelliteCoordinator.gd` y desacople de métricas y compras en `main_game.gd` | `test_game_over_screen_runner.tscn`, `test_satellite_odometer_and_transmutation_runner.tscn`, `tools/run_unit_fast.ps1` (PASS) |
| **Sesión 6** | **Monolito CharacterSelect (Tabs & Foco)** | Extraer `CharacterSelectTabController.gd`; reubicar mallas en `character_focus_router.gd` | `test_character_select_runner.tscn` |
| **Sesión 7** | **Monolito Player (Hit Reactions & VFX)** | Extraer `PlayerHitReactionController.gd` y `PlayerVfxCoordinator.gd` de `player.gd` | `test_player_runner.tscn` |
| **Sesión 8** | **Monolito HUD (Barras & Weapon Slots)** | Extraer `HudHealthShieldDisplay.gd` y `HudWeaponCooldownBar.gd` de `hud.gd` | `test_hud_runner.tscn` |
| **Sesión 9** | **Monolito CombatBossCoordinator** | Extraer `BossCinematicSequence.gd` y `BossHealthBarManager.gd` | `test_boss_runner.tscn` |
| **Sesión 10** | **Persistencia Tipada (`profile_storage.gd`)** | Crear DTOs modulares en `core/systems/persistence/dto/`; compactar validación | `test_save_manager_runner.tscn` |
| **Sesión 11** | **Hub 3D & Ingame Debug Modal** | Extraer `HubInteractableCoordinator.gd` y paneles auxiliares en `ingame_debug_modal.gd` | `tools/run_unit_fast.ps1` |
| **Sesión 12** | **Verificación Integral & Balance M7** | Auditoría final de scripts, revisión de tamaños y corrida completa `-CoreOnly` | `run_tests.ps1 -CoreOnly` |
