---
trigger: always_on
---

# REGLAS DE ARQUITECTURA Y CONVENCIONES - ASTRA DREAM
## Directrices de Desarrollo para Antigravity y Desarrolladores

Este archivo es leído por Antigravity para mantener la coherencia de código, evitar colisiones en Git y garantizar la arquitectura modular de Astra Dream.

---

### 1. PRINCIPIOS DE ARQUITECTURA
1. **Zero-Allocation en Combate:**
   - No instanciar ni liberar nodos `Area2D` ni `Node2D` para proyectiles danmaku masivos.
   - Toda bala danmaku masiva debe pasar por `BulletServer` (`core/autoloads/bullet_server.gd`) usando su pool contiguo SoA (`PackedFloat32Array`).
2. **Modularidad Estricta y Desacoplamiento:**
   - **PROHIBIDO modificar `scenes/combat/main_game.tscn`** para añadir armas, ítems o enemigos individuales.
   - Cada nueva arma, enemigo o pantalla de UI debe crearse en su propia escena (`.tscn`) y script (`.gd`) aislado dentro de su subdirectorio respectivo.
   - La comunicación entre subsistemas debe realizarse exclusivamente a través de:
     - Grupos estándar: `"player"`, `"enemies"`, `"emitters"`.
     - DTOs tipados: `HitContext`.
     - Bus de eventos global: `EventBus`.
3. **Data-Driven mediante Custom Resources (`.tres`):**
   - Todo ítem nuevo debe definirse como un recurso inmutable heredado de `ItemData` o `ItemEffect`.
   - Toda heroína nueva debe definirse como un recurso heredado de `CharacterData`.
   - Las armas se definen mediante recursos heredados de `WeaponData`.

---

### 2. CONTRATOS DE INTERFAZ DE COMBATE
* **Cualquier entidad atacable (Enemigos, Jefes, Emisores):**
  1. Debe pertenecer al grupo `"enemies"` (`add_to_group("enemies")` en `_ready()`).
  2. Debe implementar obligatoriamente el método:
     ```gdscript
     func take_damage(ctx: HitContext) -> void:
     ```
  3. Al recibir daño debe aplicar `ctx.final_damage` y considerar bifurcaciones de procs si corresponde.
  4. Al morir, debe otorgar recompensas a `Player` si es válido y llamar a `queue_free()`.

* **Cualquier arma o fuente de daño (Láseres, Misiles, Drones aliados):**
  1. Debe encapsular su daño en una instancia de `HitContext`.
  2. Debe respetar el `proc_coefficient` y utilizar `ctx.fork_child_hit(...)` para cualquier efecto secundario o explosión secundaria.

---

### 3. CONVENCIONES DE GDSCRIPT (GODOT 4.7+)
* **Tipado Estricto:** Especificar siempre tipos en variables, argumentos y retornos (`var x: float = 0.0`, `func foo() -> void:`).
* **Nombres de Clases Globales:** Usar `class_name PascalCase` al inicio de cada script de entidad o componente.
* **Caché y Validación:** Tras crear o renombrar scripts, ejecutar el escaneo del editor o usar el servidor MCP para validar el árbol.
* **Git y Conflictos:**
  - Nunca commitear cambios directos en la rama `master`.
  - Trabajar siempre en ramas funcionales: `feat/nombre-de-la-tarea`.

---

### 4. INTEGRACIÓN CON GODOT AI MCP Y POLÍTICA DE VERIFICACIÓN
1. **Uso Proactivo de Godot AI MCP:**
   - Antigravity está conectado al servidor MCP `godot-ai` y puede (y DEBE si es necesario) interactuar y verificar cosas directamente en el editor de Godot en vivo mientras programa.
   - Utilizar plenamente las herramientas MCP disponibles cuando aporten valor:
     - Inspección y manipulación de nodos y jerarquía (`scene_get_hierarchy`, `node_create`, `node_set_property`, `scene_open`).
     - Lectura de logs y errores del motor (`logs_read`).
     - Captura visual del viewport 2D/3D o ventana de juego (`editor_screenshot`).
     - Ejecución de escenas para pruebas puntuales (`project_run`, `game_manage`).
2. **Benchmark Estricto y Verificación Pragmática (No Sobre-Verificar):**
   - NO caer en bucles continuos de comprobación redundante ni sobre-verificación.
   - Ejecutar únicamente las comprobaciones esenciales y estrictamente necesarias para validar el benchmark básico de *"esto compila y funciona sin errores críticos"*.
   - El testing extendido, la jugabilidad y el pulido fino serán realizados manualmente por el usuario o por un agente especializado posterior.
3. **Contrato Obligatorio de Cierre de Mensaje:**
   - SIEMPRE, al final de cada respuesta que involucre cambios de código o nuevas funcionalidades, incluir una sección de comprobación dirigida al usuario indicándole con precisión qué debe verificar en el juego/editor para confirmar que todo opera según lo esperado.
