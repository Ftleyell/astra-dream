---
trigger: always_on
---

# Reglas Centrales de Desarrollo — Astra Dream

1. **Zero-Allocation en Combate:** Todo proyectil danmaku masivo debe gestionarse a través de `BulletServer` (`core/autoloads/bullet_server.gd`) usando pools contiguos (`PackedFloat32Array`). Prohibido instanciar `Area2D` individuales para balas masivas.
2. **Modularidad Radical (Anti God-Objects):** Prohibido concentrar múltiples responsabilidades en scripts individuales o en la escena raíz (`main_game.gd`/`.tscn`, `player.gd`, `hub_world.gd`). Toda lógica nueva o refactorizada debe dividirse en componentes y controladores desacoplados con responsabilidad única.
3. **Data-Driven Estricto para Balance:** El 100% de las variables de diseño numérico y balance (daño, cadencia, vida, curvas de escalado, composición de oleadas, precios, duraciones, tiempos de satélites) DEBEN residir en recursos exportados `.tres` (`WeaponData`, `ItemData`, `CharacterData`, `EncounterTimelineConfig`). Prohibido hardcodear números mágicos en scripts de lógica `.gd`.
4. **Tipado Estricto Obligatorio:** Todo script en GDScript 4 debe tener tipado estricto en variables miembro, variables locales, parámetros de funciones y tipos de retorno (`var x: float = 0.0`, `func f() -> void:`).
5. **Ediciones Quirúrgicas y Ahorro Máximo de Tokens:** 
   - Prohibido reescribir o volcar archivos completos innecesariamente; utilizar `replace_file_content` para parches diferenciales exactos.
   - En inspecciones de código, acotar obligatoriamente las lecturas a rangos precisos con `view_file` (máx. 100-200 líneas pertinentes) evitando lecturas masivas.
   - Respuestas concisas y de alta densidad técnica: evitar repetir bloques de código ya mostrados en diffs o resumir contenido obvio.
6. **Cuestionarios Interactivos (`ask_question`):** Toda aclaración, bifurcación de diseño o confirmación de commit debe realizarse a través de la herramienta interactiva de cuestionarios `ask_question`, nunca con preguntas en texto plano.
7. **Verificación Pragmática con Arnés Anti-Cuelgues y Test Aislado:**
   - Durante la iteración activa de desarrollo, **usar exclusivamente el test específico del sistema tocado**: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "<suite_runner.tscn>"` (latencia de 2 segundos).
   - Prohibido ejecutar `-CoreOnly` de forma repetitiva en pasos intermedios. Reservar `-CoreOnly` únicamente para la verificación integral final antes de dar por concluida la tarea.
   - Prohibido ejecutar comandos directos de `godot --headless` sin timeout para verificar suites. Toda nueva suite de prueba debe heredar de `BaseTestSuite` (`tests/base_test_suite.gd`).
8. **Punto de Entrada Obligatorio (`AGENT_CONTEXT.md`):** Al iniciar cualquier sesión de trabajo en este proyecto, leer `AGENT_CONTEXT.md` (raíz del proyecto) antes de explorar cualquier otro archivo. Este documento contiene el mapa completo de sistemas → archivos, zonas de exploración prohibida, autoloads, contratos de arquitectura y estado actual del proyecto. Está diseñado para eliminar la fase de orientación ciega en cada sesión.
   - **Zonas explícitamente prohibidas de exploración:** `addons/`, `.godot/`, `.godot_ai_update/`, `scratch/`, `sandbox/`, `preprocess/`. Si el agente necesita orientarse sobre qué archivo buscar, consultar primero `AGENT_CONTEXT.md`, luego `docs/DOMAIN_MAP.md`. Nunca explorar el árbol de carpetas directamente.
9. **Higiene de Sesiones Atómicas y Economía de Tokens:**
   - Cumplir el principio de "1 Tarea / Bugfix = 1 Conversación". Al completar una tarea o superar 12-15 turnos, abrir un nuevo chat para evitar el arrastre de contextos de más de 80.000 tokens.
   - Los comandos de test deben correr con salida filtrada/resumida sin volcar decenas de líneas verdes innecesarias al contexto.

