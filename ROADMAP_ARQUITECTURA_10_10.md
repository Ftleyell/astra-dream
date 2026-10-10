# Plan de Ejecución Atómica — Arquitectura 10/10

Este documento organiza la refactorización en **sesiones atómicas independientes** (1 sesión = 1 chat nuevo). 

> **Regla de Operación:**
> - Al terminar cada sesión, marcar con `[X]` las tareas completadas y actualizar el estado de la sesión a `RESUELTO`.
> - La **Sesión 4** (sesión final) tiene como última tarea verificar todo y **eliminar este archivo (`ROADMAP_ARQUITECTURA_10_10.md`)**, concluyendo la deuda técnica del proyecto.

---

## 📌 Sesión 1: Modularización de `GameOverModal`

**Objetivo:** Reducir `game_over_modal.gd` de ~361 líneas a un orquestador liviano (~120 líneas) delegando el ensamblado de la interfaz.

- [X] **Paso 1.1:** Crear `scenes/ui/game_over/game_over_layout_builder.gd` (`class_name GameOverLayoutBuilder`):
  - Responsable de instanciar y poblar los chips visuales de arcanas, armas activas e ítems de inventario en los contenedores `HFlowContainer`.
  - Responsable de aplicar estilos y colores a las tarjetas de loadout.
- [X] **Paso 1.2:** Crear `scenes/ui/game_over/game_over_telemetry_formatter.gd` (`class_name GameOverTelemetryFormatter`):
  - Métodos estáticos puros para formatear el tiempo (`mm:ss`), puntaje con separadores, y textos de recursos/bajas.
- [X] **Paso 1.3:** Refactorizar `scenes/ui/game_over/game_over_modal.gd`:
  - Eliminar la lógica de formateo y construcción de UI en código.
  - Delegar en el builder y el formateador.
  - Conservar únicamente la lógica de recepción del evento de derrota/victoria, animación de entrada y emisión de señales (`restart_requested`, `hub_requested`, `endless_requested`).
- [X] **Paso 1.4:** Ejecutar test unitario para verificar que no hay errores de sintaxis ni regresiones.
- [X] **Paso 1.5:** Marcar esta sesión como `[X] RESUELTO` y realizar commit atómico.

**Estado Sesión 1:** `RESUELTO`

---

## 📌 Sesión 2: Modularización de `HighscoresModal`

**Objetivo:** Desacoplar la construcción programática de tablas y la navegación de pestañas en `highscores_modal.gd` (~307 líneas).

- [X] **Paso 2.1:** Crear `scenes/ui/highscores/highscores_table_builder.gd` (`class_name HighscoresTableBuilder`):
  - Mover la lógica que genera programáticamente los paneles de carrera (`_setup_career_container`) y las filas del Salón de la Fama (Top 10).
- [X] **Paso 2.2:** Crear `scenes/ui/highscores/highscores_tab_controller.gd` (`class_name HighscoresTabController`):
  - Manejo de botones de pestaña (`tab_career_btn`, `tab_hof_btn`), estilos de tab activa e intercambio de visibilidad entre contenedores.
- [X] **Paso 2.3:** Reducir `scenes/ui/highscores/highscores_modal.gd`:
  - Actuar solo como ventana contenedora modal, delegando la presentación al builder y tabs al controller.
- [X] **Paso 2.4:** Verificar ejecución y sintaxis tipada estricta.
- [X] **Paso 2.5:** Marcar esta sesión como `[X] RESUELTO` y realizar commit atómico.

**Estado Sesión 2:** `RESUELTO`

---

## 📌 Sesión 3: Desacoplamiento de `SlotMachineBeacon` (Baliza Arcade)

**Objetivo:** Reducir `slot_machine_beacon.gd` (~450 líneas) separando la física de bumper del display arcade y del cálculo de premios.

- [ ] **Paso 3.1:** Crear `scenes/combat/satellite/components/slot_machine_marquee_display.gd` (`class_name SlotMachineMarqueeDisplay`):
  - Encapsular la creación de labels flotantes del marquee, los tweens de animación de los 3 rodillos y los efectos de texto/flash.
- [ ] **Paso 3.2:** Crear `scenes/combat/satellite/components/slot_machine_payout_engine.gd` (`class_name SlotMachinePayoutEngine`):
  - Lógica pura de evaluación de resultados (3 iguales, pares, combinaciones de símbolos) y spawneo de recompensas (blobs de exp, ítems, curación).
- [ ] **Paso 3.3:** Refactorizar `scenes/combat/satellite/slot_machine_beacon.gd`:
  - Queda como un nodo físico de ~100-120 líneas: colisión `bump`, radio de activación y despacho de eventos.
- [ ] **Paso 3.4:** Validar en runtime/tests que la interacción bumper siga funcionando idénticamente.
- [ ] **Paso 3.5:** Marcar esta sesión como `[X] RESUELTO` y realizar commit atómico.

**Estado Sesión 3:** `PENDIENTE`

---

## 📌 Sesión 4: Blindaje de Repositorio, Verificación Integral y Limpieza

**Objetivo:** Confirmar que no queden scripts God Objects, verificar todas las suites de prueba y auto-eliminar esta guía.

- [ ] **Paso 4.1:** Revisar el tamaño de los scripts modificados para asegurar que ninguno supere el umbral de ~150-200 líneas.
- [ ] **Paso 4.2:** Limpiar y normalizar el estado de git (manejo de archivos `.uid` de Godot 4 en `.gitignore` o en el árbol según corresponda).
- [ ] **Paso 4.3:** Ejecutar la suite de tests del proyecto (`tools/run_tests.ps1`) para confirmar pase al 100% en verde.
- [ ] **Paso 4.4:** Eliminar este archivo (`ROADMAP_ARQUITECTURA_10_10.md`).
- [ ] **Paso 4.5:** Commit final de cierre de deuda técnica: `chore(arch): finalize 10/10 component architecture milestone`.

**Estado Sesión 4:** `PENDIENTE`
