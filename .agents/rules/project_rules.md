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

---

### 5. INTERACCIÓN POR CUESTIONARIOS (QUESTIONNAIRE BOX) Y GESTIÓN DE GIT

#### A. Directriz General de Preguntas (Questionnaire Box)
* **PROHIBIDO detener la ejecución con preguntas en texto plano:** Cuando se requiera una decisión, aclaración o preferencia del usuario, Antigravity debe utilizar SIEMPRE la herramienta interactiva de cuestionarios (`ask_question`) en lugar de responder texto plano y forzar al usuario a redactar un nuevo prompt.
* La herramienta `ask_question` genera un modal interactivo con selección de opciones y campo de respuesta libre ("Custom") automático.

#### B. Momento de Ejecución del Flujo de Git
* Este bucle interactivo de Git se ejecuta **ÚNICAMENTE después de haber finalizado todos los cambios de código y verificaciones básicas**, de modo que el usuario pueda probar el juego/editor por su cuenta antes de responder al cuestionario.

---

#### C. Flujo de Preguntas y Decisiones de Git (10 Pasos)

1. **SI EL USUARIO ESTÁ TRABAJANDO EN LA RAMA PRINCIPAL (`main` / `master`):**
   Lanzar cuestionario (`ask_question`):
   * *Pregunta:* "¿Deberíamos subir los cambios a una rama nueva o directamente en la rama principal?"
   * *Opciones:*
     - A. Subir los cambios a la rama principal (`main`/`master`).
     - B. Subir los cambios a una nueva rama llamada `<nombre_de_rama_generado_por_IA>`.
     - C. Subir los cambios a una nueva rama personalizada.
     *(Nota: La opción Custom viene integrada por defecto en la UI)*.

2. **SI EL USUARIO NO ESTÁ TRABAJANDO EN LA RAMA PRINCIPAL (`feat/...` u otra):**
   * *Regla de Recomendación:* Recomendar la opción C si los cambios se desviaron significativamente del propósito original de la rama; recomendar la opción A si el trabajo sigue siendo pertinente al propósito de la rama.
   * *Pregunta:* "¿Deberíamos subir los cambios a la rama principal o directamente a la rama actual (`<nombre_de_rama_actual>`)?"
   * *Opciones:*
     - A. Subir los cambios a la rama actual (`<nombre_de_rama_actual>`).
     - B. Subir los cambios a la rama principal (`main`/`master`).
     - C. Subir los cambios a una nueva rama llamada `<nombre_de_rama_generado_por_IA>`.
     - D. Subir los cambios a una nueva rama personalizada.

3. **SI EL USUARIO ELIGIÓ LA OPCIÓN DE "NUEVA RAMA PERSONALIZADA" (Opción C en paso 1 u Opción D en paso 2):**
   Lanzar cuestionario:
   * *Pregunta:* "¿Cómo deberíamos llamar a la nueva rama?"
   * *Opciones:*
     - A. `<nombre_alternativo_1_generado_por_IA>`
     - B. `<nombre_alternativo_2_generado_por_IA>`
     - C. `<nombre_alternativo_3_generado_por_IA>`

4. **SI EXISTEN ARCHIVOS ELIMINADOS LOCALMENTE QUE NO HAN SIDO REMOVIDOS CON `git rm`:**
   Lanzar cuestionario:
   * *Pregunta:* "Se han detectado archivos eliminados localmente respecto a Git (`<lista_archivos_eliminados>`). ¿Deseas remover estos archivos también de la versión en Git del proyecto?"
   * *Opciones:*
     - A. Sí, eliminar todos.
     - B. Eliminar solo algunos de ellos.
     - C. No, no eliminar ninguno de los archivos.

5. **SI EL USUARIO ELIGIÓ LA OPCIÓN B ("ELIMINAR SOLO ALGUNOS DE ELLOS"):**
   Lanzar cuestionario:
   * *Pregunta:* "¿Cuáles archivos deberíamos eliminar de Git?"
   * *Opciones:*
     - A. `<grupo_de_archivos_1_generado_por_IA>`
     - B. `<grupo_de_archivos_2_generado_por_IA>`
     - C. `<grupo_de_archivos_3_generado_por_IA>`
     *(O configurar `is_multi_select: true` con los archivos individuales para selección directa)*.

6. **SI EXISTE UN COMMIT PREVIO NO SUBIDO (UNPUSHED COMMIT):**
   Lanzar cuestionario:
   * *Pregunta:* "¿Deseas hacer push de los cambios a Git?"
   * *Opciones:*
     - A. Sí, hacer push al último commit generado (puede no incluir los últimos cambios del agente).
     - B. Sí, hacer push a un nuevo commit que incluya todos los cambios hasta el último.
     - C. No, no hacer push de los cambios.

7. **SI NO HAY COMMITS PENDIENTES DE PUSH, O EL USUARIO ELIGIÓ LA OPCIÓN B ("HACER PUSH A UN NUEVO COMMIT"):**
   Lanzar cuestionario:
   * *Pregunta:* "¿Deseas hacer commit de los cambios a Git?"
   * *Opciones:*
     - A. Sí, con el nombre de commit `<titulo_original_generado_por_IA>`.
     - B. Sí, con un nombre de commit personalizado.
     - C. No, no hacer commit.

8. **SI EL USUARIO ELIGIÓ LA OPCIÓN B ("CON UN NOMBRE DE COMMIT PERSONALIZADO"):**
   Lanzar cuestionario:
   * *Pregunta:* "¿Qué título debería tener el commit?"
   * *Opciones:*
     - A. `<titulo_alternativo_1_generado_por_IA>`
     - B. `<titulo_alternativo_2_generado_por_IA>`
     - C. `<titulo_alternativo_3_generado_por_IA>`

9. **SI EL USUARIO ELIGIÓ UNA OPCIÓN QUE HACE COMMIT DEL CÓDIGO:**
   Lanzar cuestionario:
   * *Pregunta:* "¿Deseas hacer push?"
   * *Opciones:*
     - A. Sí, hacer push del commit #`<tag_o_hash>` con el título "`<titulo_commit>`".
     - B. Sí, pero crear un nuevo commit antes.
     - C. No, no hacer push.

10. **SI EL USUARIO ELIGIÓ LA OPCIÓN B EN EL PASO 9 ("CREAR UN NUEVO COMMIT ANTES"):**
    * Regresar al **Paso 7** en bucle.

---

#### D. Mensajes de Commit en Inglés y Sintaxis Estándar (Conventional Commits)
* TODOS los mensajes de commit generados en cualquiera de las opciones deben redactarse obligatoriamente en **inglés**.
* Se debe utilizar la sintaxis estricta de Conventional Commits con scope:
  - `feat(<scope>): <description>` (ej. `feat(weapons): add plasma shotgun spread and orbital shields`)
  - `fix(<scope>): <description>` (ej. `fix(danmaku): resolve bullet culling at screen boundaries`)
  - `chore(<scope>): <description>` (ej. `chore(rules): update git commit conventions`)
  - `docs(<scope>): <description>` (ej. `docs(weapons): update weapon catalog walkthrough`)
  - `refactor(<scope>): <description>` (ej. `refactor(player): decouple weapon controller logic`)
  - `build(<scope>): <description>` (ej. `build(git): update gitignore patterns`)
  - `revert(<scope>): <description>` (ej. `revert(weapons): temporarily remove plasma shotgun from master`)

