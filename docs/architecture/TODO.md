# TODO: Plan Maestro de Descompresión de Modales, Micro-Tests (<1.5s) y Blindaje Anti-Cuelgue

> **Objetivo:** Eliminar la fricción residual del agente y del desarrollador resolviendo los dos cuellos de botella identificados:
> 1. Modales secundarios de gran tamaño (monolitos > 600-1100 líneas) que disparan el consumo de tokens y dificultan refactors.
> 2. Ciclo de pruebas lento (83s) dependiente de la UI y propenso a cuelgues si fallan los timers o señales.

---

## 🛡️ Hito 0: Infraestructura de Pruebas Rápidas y Blindaje Anti-Cuelgue (Zero-Hang) ✅ (Commit: `6b1d2f99`)

- [x] **0.1. Watchdog y Timeout Seguro en `BaseTestSuite` (`base_test_suite.gd`)**
  - [x] Implementar temporizador Watchdog autónomo con límite estricto de tiempo por test (default: 3.0s unitario, 10.0s integración).
  - [x] Añadir método helper `await_signal_or_timeout(target_signal: Signal, timeout: float = 3.0) -> bool` para erradicar llamadas a `await` huérfanas que causan cuelgues.
  - [x] Integrar aborto controlado ante timeout fatal: imprimir traza del test atascado y forzar salida limpia con código de error (`get_tree().quit(1)`).
- [x] **0.2. Runner Rápido con Circuit Breaker a Nivel Proceso (`tools/run_unit_fast.ps1`)**
  - [x] Crear runner que ejecute Godot con flags optimizadas (`--headless`, `--disable-render-loop`).
  - [x] Configurar circuit breaker a nivel shell con timeout duro (mata el proceso si excede 8s en total para evitar bloqueos del CLI).
  - [x] Crear carpeta y estructura para micro-tests desacoplados en `tests/unit/`.

---

## 🧩 Hito 1: Desarticulación de `arsenal_banlist_modal.gd` (1.116 líneas -> 347 líneas) ✅ (Commit: `6b1d2f99`)

- [x] **1.1. Extracción de Lógica de Negocio y Reglas (`arsenal_banlist_data_controller.gd`)**
  - [x] Mover reglas matemáticas (límite del 40% por categoría, conteos de ítems, validaciones de toggle).
  - [x] Mover persistencia en `SaveManager` e insolación de perfiles por piloto.
  - [x] Implementar la clase desacoplada como `RefCounted` sin dependencias visuales.
- [x] **1.2. Micro-Test Unitario Puro Anti-Cuelgue (`tests/unit/test_banlist_rules_unit.gd`)**
  - [x] Crear test puro que valide las 7 pestañas, límites matemáticos y persistencia en **< 2.5s** (síncrono sin árbol UI).
  - [x] Validar que corra de forma síncrona sin instanciar `ArsenalBanlistModalScene`.
- [x] **1.3. Extracción de Renderizado de Tarjetas (`arsenal_card_renderer.gd`)**
  - [x] Mover generación procedural de tarjetas, inyección de `StyleBoxFlat`, iconografía de tags balísticos y manejo de estados visuales.
- [x] **1.4. Extracción de Detalle y Feedback (`arsenal_detail_panel.gd`)**
  - [x] Encapsular el panel lateral (`SideDetailPanel`), estadísticas de armas/tomos y audio de interacción.
- [x] **1.5. Refactor Final del Orquestador (`arsenal_banlist_modal.gd`)**
  - [x] Conectar los tres submódulos mediante composición y señales.
  - [x] Reducir el orquestador principal a 347 líneas (reducción de -68.9% de código).
  - [x] Ejecutar suite existente `test_arsenal_banlist_modal_suite.gd` para garantizar cero regresiones.

---

## 🎛️ Hito 2: Desarticulación de `pause_menu.gd` (878 líneas -> 179 líneas) ✅ (Commit: `6b1d2f99`)

- [x] **2.1. Controlador de Audio (`pause_audio_settings.gd`)**
  - [x] Mover mapeo y volumen de buses (`Master`, `BGM`, `SFX`), conversiones dB $\leftrightarrow$ slider y persistencia.
  - [x] Crear micro-test unitario (`tests/unit/test_pause_audio_unit.gd`) para conversiones numéricas en **< 2.4s**.
- [x] **2.2. Controlador Gráfico y de Pantalla (`pause_video_settings.gd`)**
  - [x] Mover cambio de resoluciones, fullscreen, VSync y ajuste de escala de interfaz.
- [x] **2.3. Controlador de Asignación de Teclas (`pause_input_rebind_controller.gd`)**
  - [x] Mover captura de `InputEventKey` / `InputEventJoypadButton`, detección de colisiones y restablecimiento a defaults.
- [x] **2.4. Refactor y Reducción de `pause_menu.gd`**
  - [x] Extraer [`PauseBuildInspector`](scenes/ui/pause_menu/components/pause_build_inspector.gd) para atributos, ítems y chips de equipamiento.
  - [x] Dejar el menú de pausa como orquestador liviano de navegación y gestión de tokens de pausa (179 líneas, -79.6% de código).
  - [x] Verificar que las pruebas del menú de pausa y coexistencia con modales sigan pasando al 100% (`test_modals_and_pause_runner.tscn` y 21 suites Core).

---

## 🃏 Hito 3: Modularización de Modales de Selección (625 y 633 líneas -> 381 y 376 líneas) ✅

- [x] **3.1. Extracción de Componentes Modulares de Arsenal (`weapon_selection_modal.gd`)**
  - [x] Extraer [`WeaponPoolDataController`](scenes/ui/character_select/components/weapon_pool_data_controller.gd) para persistencia y validaciones mínimas (8 armas).
  - [x] Extraer [`WeaponCardRenderer`](scenes/ui/character_select/components/weapon_card_renderer.gd) y [`WeaponSelectionDetailPanel`](scenes/ui/character_select/components/weapon_selection_detail_panel.gd).
  - [x] Crear micro-test síncrono [`test_weapon_pool_rules_unit.gd`](tests/unit/test_weapon_pool_rules_unit.gd).
- [x] **3.2. Desacoplamiento de Lógica de Transmutación (`transmutation_modal.gd`)**
  - [x] Extraer [`TransmutationDataController`](scenes/ui/modals/transmutation_data_controller.gd) para reglas de elegibilidad y sacrificio de misma rareza.
  - [x] Extraer [`TransmutationChoiceView`](scenes/ui/modals/transmutation_choice_view.gd) y [`TransmutationCardBuilder`](scenes/ui/modals/transmutation_card_builder.gd).
  - [x] Crear micro-test síncrono [`test_transmutation_rules_unit.gd`](tests/unit/test_transmutation_rules_unit.gd).
- [x] **3.3. Refactor Final y Validación**
  - [x] Reducción masiva de ambos orquestadores (`weapon_selection_modal.gd` a 381 líneas, `transmutation_modal.gd` a 376 líneas).
  - [x] 100% PASS en Fast Unit Runner (4 micro-tests en ~10s) y suites de integración de satélite y pool de armas.

---

## ⚡ Hito 4: Estratificación y Consolidación del Pipeline de Tests ✅

- [x] **4.1. Pirámide de Pruebas Operativa**
  - [x] Nivel 1: `Fast Unit Tests` (`tests/unit/`): 4 suites ejecutadas en ~10s con circuit breaker y watchdog.
  - [x] Nivel 2: `Feature Integration Tests`: ejecución aislada por suite (4-6s) durante desarrollo activo.
  - [x] Nivel 3: `CoreOnly Suite`: reservado para validación integral final antes de commits de hito.
- [x] **4.2. Documentación y Guía de Uso para Agentes**
  - [x] Documentado en [`docs/architecture/testing_workflow.md`](docs/architecture/testing_workflow.md) con pirámide operativa, pautas anti-cuelgue y cómo invocar los runners.
