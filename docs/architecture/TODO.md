# TODO: Plan Maestro de Descompresión de Modales, Micro-Tests (<1.5s) y Blindaje Anti-Cuelgue

> **Objetivo:** Eliminar la fricción residual del agente y del desarrollador resolviendo los dos cuellos de botella identificados:
> 1. Modales secundarios de gran tamaño (monolitos > 600-1100 líneas) que disparan el consumo de tokens y dificultan refactors.
> 2. Ciclo de pruebas lento (83s) dependiente de la UI y propenso a cuelgues si fallan los timers o señales.

---

## 🛡️ Hito 0: Infraestructura de Pruebas Rápidas y Blindaje Anti-Cuelgue (Zero-Hang)

- [x] **0.1. Watchdog y Timeout Seguro en `BaseTestSuite` (`base_test_suite.gd`)**
  - [x] Implementar temporizador Watchdog autónomo con límite estricto de tiempo por test (default: 3.0s unitario, 10.0s integración).
  - [x] Añadir método helper `await_signal_or_timeout(target_signal: Signal, timeout: float = 3.0) -> bool` para erradicar llamadas a `await` huérfanas que causan cuelgues.
  - [x] Integrar aborto controlado ante timeout fatal: imprimir traza del test atascado y forzar salida limpia con código de error (`get_tree().quit(1)`).
- [x] **0.2. Runner Rápido con Circuit Breaker a Nivel Proceso (`test_unit_fast.ps1` / `.bat`)**
  - [x] Crear runner que ejecute Godot con flags optimizadas (`--headless`, `--disable-render-loop`).
  - [x] Configurar circuit breaker a nivel shell con timeout duro (mata el proceso si excede 15s en total para evitar bloqueos del CLI).
  - [x] Crear carpeta y estructura para micro-tests desacoplados en `tests/unit/`.

---

## 🧩 Hito 1: Desarticulación de `arsenal_banlist_modal.gd` (1.116 líneas -> < 200 líneas)

- [x] **1.1. Extracción de Lógica de Negocio y Reglas (`arsenal_banlist_data_controller.gd`)**
  - [x] Mover reglas matemáticas (límite del 40% por categoría, conteos de ítems, validaciones de toggle).
  - [x] Mover persistencia en `SaveManager` e insolación de perfiles por piloto.
  - [x] Implementar la clase desacoplada como `RefCounted` o nodo puro sin dependencias visuales.
- [x] **1.2. Micro-Test Unitario Puro Anti-Cuelgue (`tests/unit/test_banlist_rules_unit.gd`)**
  - [x] Crear test puro que valide las 7 pestañas, límites matemáticos y persistencia en **< 0.1s**.
  - [x] Validar que corra de forma síncrona sin instanciar `ArsenalBanlistModalScene`.
- [x] **1.3. Extracción de Renderizado de Tarjetas (`arsenal_card_renderer.gd`)**
  - [x] Mover generación procedural de tarjetas, inyección de `StyleBoxFlat`, iconografía de tags balísticos y manejo de estados visuales.
- [x] **1.4. Extracción de Detalle y Feedback (`arsenal_detail_panel.gd`)**
  - [x] Encapsular el panel lateral (`SideDetailPanel`), estadísticas de armas/tomos y audio de interacción.
- [x] **1.5. Refactor Final del Orquestador (`arsenal_banlist_modal.gd`)**
  - [x] Conectar los tres submódulos mediante señales.
  - [x] Reducir el orquestador principal a menos de 200 líneas.
  - [x] Ejecutar suite existente `test_arsenal_banlist_modal_suite.gd` para garantizar cero regresiones.

---

## 🎛️ Hito 2: Desarticulación de `pause_menu.gd` (878 líneas -> < 180 líneas)

- [x] **2.1. Controlador de Audio (`pause_audio_settings.gd`)**
  - [x] Mover mapeo y volumen de buses (`Master`, `BGM`, `SFX`), conversiones dB $\leftrightarrow$ slider y persistencia.
  - [x] Crear micro-test unitario (`tests/unit/test_pause_audio_unit.gd`) para conversiones numéricas en **< 0.05s**.
- [x] **2.2. Controlador Gráfico y de Pantalla (`pause_video_settings.gd`)**
  - [x] Mover cambio de resoluciones, fullscreen, VSync y ajuste de escala de interfaz.
- [x] **2.3. Controlador de Asignación de Teclas (`pause_input_rebind_controller.gd`)**
  - [x] Mover captura de `InputEventKey` / `InputEventJoypadButton`, detección de colisiones y restablecimiento a defaults.
- [x] **2.4. Refactor y Reducción de `pause_menu.gd`**
  - [x] Dejar el menú de pausa como orquestador liviano de navegación y gestión de tokens de pausa.
  - [x] Verificar que las pruebas del menú de pausa y coexistencia con modales sigan pasando.

---

## 🃏 Hito 3: Modularización de Modales de Selección (~630 líneas c/u -> < 160 líneas)

- [ ] **3.1. Componente Reutilizable de Cartas (`modal_card_grid_view.gd`)**
  - [ ] Unificar el patrón visual de presentación de 3 a 4 cartas para `weapon_selection_modal.gd` y `transmutation_modal.gd`.
  - [ ] Estandarizar navegación con gamepad/teclado y selección con foco.
- [ ] **3.2. Desacoplamiento de Lógica de Reroll y Transmutación**
  - [ ] Extraer reglas de tiradas y costos hacia controladores testeables de forma síncrona.
- [ ] **3.3. Refactor de `weapon_selection_modal.gd` y `transmutation_modal.gd`**
  - [ ] Reducir ambos scripts a controladores ligeros conectando el grid reutilizable.

---

## ⚡ Hito 4: Estratificación y Consolidación del Pipeline de Tests

- [ ] **4.1. Pirámide de Pruebas Operativa**
  - [ ] Nivel 1: `Fast Unit Tests` (`tests/unit/`): ejecución total en **< 1.5s**, blindados con watchdog.
  - [ ] Nivel 2: `Feature Integration Tests`: ejecución bajo demanda al modificar módulos visuales completos.
  - [ ] Nivel 3: `CoreOnly Suite`: reservado para validación integral final antes de commits de hito.
- [ ] **4.2. Documentación y Guía de Uso para Agentes**
  - [ ] Documentar en `docs/architecture/testing_workflow.md` las pautas para agregar tests seguros anti-cuelgue y cómo invocar el runner rápido.
