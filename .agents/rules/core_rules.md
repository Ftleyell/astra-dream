---
trigger: always_on
---

# Reglas Centrales de Desarrollo — Astra Dream

1. **Zero-Allocation en Combate y Object Pooling Seguro:**
   - Todo proyectil danmaku masivo debe gestionarse a través de `BulletServer` (`core/autoloads/bullet_server.gd`) usando pools contiguos (`PackedFloat32Array`). Prohibido instanciar `Area2D` individuales para balas masivas.
   - **Separación `_ready_custom()` vs `_reset_pool_state()`:** En entidades reciclables (`EnemyBase` y subclases), la instanciación de nodos hijos (`Sprite2D`, `ProgressBar`, materiales) ocurre **exclusivamente una vez** en `_ready_custom()`. `_reset_pool_state()` solo debe restaurar variables numéricas, flags, timers de ataque/telégrafo y visibilidad sin hacer `new()` ni `add_child()`.
2. **Modularidad Radical y Prohibición de Lookups Dinámicos:**
   - Prohibido concentrar múltiples responsabilidades en scripts individuales o en la escena raíz (`main_game.gd`/`.tscn`, `player.gd`, `hub_world.gd`). Toda lógica nueva o refactorizada debe dividirse en componentes y controladores desacoplados con responsabilidad única.
   - **Prohibido `main_game.get()` / `main_game.set()`:** Prohibido usar reflexión por strings (`get("prop")`, `set("prop", val)`) sobre `MainGame` o sus coordinadores. Acceder siempre mediante referencias tipadas explícitas en `MainGame`, `CombatContext` o sub-coordinadores (`CombatBossCoordinator`, `EnemySpawner`, `CrisisManager`).
3. **Data-Driven Estricto e Inmutabilidad de `.tres` en Runtime:**
   - El 100% de las variables de diseño numérico y balance (daño, cadencia, vida, curvas de escalado, composición de oleadas, precios, duraciones, tiempos de satélites) DEBEN residir en recursos exportados `.tres` (`EnemyData`, `BossData`, `WeaponData`, `ItemData`, `CharacterData`, `EncounterTimelineConfig`). Prohibido hardcodear números mágicos en scripts de lógica `.gd`.
   - **Recursos `.tres` Read-Only en Runtime:** Prohibido mutar propiedades de un recurso `.tres` compartido en tiempo de ejecución. Copiar siempre los valores base hacia propiedades de instancia en `_init()` / `_reset_pool_state()`, e incluir un fallback `preload("res://data/...")` cuando el `@export` sea `null` para soportar instanciación `.new()` en tests headless.
4. **Tipado Estricto y Contratos de Interfaz (`HitContext`, `PauseArbitrator`, Modificadores):**
   - Todo script en GDScript 4 debe tener tipado estricto en variables miembro, variables locales, parámetros de funciones y tipos de retorno (`var x: float = 0.0`, `func f() -> void:`).
   - **Contrato Único de Daño:** Toda entidad atacable (`EnemyBase`, `RainbowEnemy`, jefes, `PlanetSector`, `Player`, `PlayerShieldController`) debe implementar exactamente `func take_damage(ctx: HitContext) -> void:`. Prohibido usar `ctx: Variant` o pasar `float`/`int` crudos; envolver daños simples con `HitContext.create_simple(amount)`.
   - **Control Centralizado de Pausa (`PauseArbitrator`):** Prohibido mutar `get_tree().paused` directamente en escenas, modales o controladores. Usar siempre `PauseArbitrator.request_pause(token)` / `PauseArbitrator.release_pause(token)` y limpiar locks con `PauseArbitrator.clear_all_locks()` al entrar a escenas raíz (`MainMenu`, `TitleScreen`, `HubWorld`).
   - **Deltas de Modificadores Reversibles:** Todo efecto de run (`RunModifierManager`, `GenericPropertyRunEffect`) debe registrar el delta o factor exacto aplicado y revertirlo simétricamente en `remove_from_run()` antes de limpiar o reaplicar efectos, evitando acumulación exponencial al serializar/recargar.
5. **Ediciones Quirúrgicas y Ahorro Máximo de Tokens:** 
   - Prohibido reescribir o volcar archivos completos innecesariamente; utilizar `replace_file_content` para parches diferenciales exactos.
   - En inspecciones de código, acotar obligatoriamente las lecturas a rangos precisos con `view_file` (máx. 100-200 líneas pertinentes) evitando lecturas masivas.
   - Respuestas concisas y de alta densidad técnica: evitar repetir bloques de código ya mostrados en diffs o resumir contenido obvio.
6. **Cuestionarios Interactivos (`ask_question`):** Toda aclaración, bifurcación de diseño o confirmación de commit debe realizarse a través de la herramienta interactiva de cuestionarios `ask_question`, nunca con preguntas en texto plano.
7. **Verificación Pragmática con Arnés Anti-Cuelgues y Test Aislado:**
   - Durante la iteración activa de desarrollo, **usar exclusivamente el test específico del sistema tocado**: `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "<subcadena_o_suite>"` (latencia de 2 a 5 segundos; el arnés resuelve subcadenas recursivas como `"space_environment"`, `"weapons"` o `"dragon_radar"`).
   - Prohibido ejecutar `-CoreOnly` de forma repetitiva en pasos intermedios. Reservar `-CoreOnly` únicamente para la verificación integral final antes de dar por concluida la tarea.
   - Prohibido ejecutar comandos directos de `godot --headless` sin timeout para verificar suites. Toda nueva suite de prueba debe heredar de `BaseTestSuite` (`tests/base_test_suite.gd`).
8. **Punto de Entrada Obligatorio (`AGENT_CONTEXT.md`):** Al iniciar cualquier sesión de trabajo en este proyecto, leer `AGENT_CONTEXT.md` (raíz del proyecto) antes de explorar cualquier otro archivo. Este documento contiene el mapa completo de sistemas → archivos, zonas de exploración prohibida, autoloads, contratos de arquitectura y estado actual del proyecto. Está diseñado para eliminar la fase de orientación ciega en cada sesión.
   - **Zonas explícitamente prohibidas de exploración ciega:** `addons/`, `.godot/`, `.godot_ai_update/`, `preprocess/`. El directorio `sandbox/` está reservado exclusivamente para prototipos y mecánicas futuras en I+D (no enlazar con producción). Si el agente necesita orientarse sobre qué archivo buscar, consultar primero `AGENT_CONTEXT.md`, luego `docs/DOMAIN_MAP.md`. Nunca explorar el árbol de carpetas directamente.
9. **Higiene de Sesiones Atómicas y Economía de Tokens:**
   - Cumplir el principio de "1 Tarea / Bugfix = 1 Conversación". Al completar una tarea o superar 12-15 turnos, abrir un nuevo chat para evitar el arrastre de contextos de más de 80.000 tokens.
   - Los comandos de test deben correr con salida filtrada/resumida sin volcar decenas de líneas verdes innecesarias al contexto.


