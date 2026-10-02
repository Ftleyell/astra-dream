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
7. **Verificación Pragmática:** Ejecutar pruebas automatizadas enfocadas en modo headless (`--headless`) tras cambios lógicos para asegurar que el proyecto compila y pasa tests sin errores críticos, evitando bucles redundantes de sobre-verificación.
