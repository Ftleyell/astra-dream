---
trigger: always_on
---

# Reglas Centrales de Desarrollo — Astra Dream

1. **Zero-Allocation en Combate:** Todo proyectil danmaku masivo debe gestionarse a través de `BulletServer` (`core/autoloads/bullet_server.gd`) usando pools contiguos (`PackedFloat32Array`). Prohibido instanciar `Area2D` individuales para balas masivas.
2. **Modularidad Estricta:** Prohibido modificar `main_game.tscn` para añadir armas o enemigos individuales; crear escenas (`.tscn`) y scripts (`.gd`) desacoplados en sus respectivos directorios.
3. **Tipado Estricto Obligatorio:** Todo script en GDScript 4 debe tener tipado estricto en variables, parámetros de funciones y tipos de retorno (`var x: float = 0.0`, `func f() -> void:`).
4. **Ediciones Quirúrgicas:** Utilizar parches diferenciales y reemplazos precisos de bloques de código (`replace_file_content`) en lugar de reescribir archivos completos para preservar tokens de salida.
5. **Cuestionarios Interactivos (`ask_question`):** Toda aclaración, decisión o consulta al usuario debe realizarse a través de la herramienta interactiva de cuestionarios `ask_question`, nunca con preguntas en texto plano que detengan el flujo.
6. **Verificación Pragmática:** Ejecutar pruebas automatizadas enfocadas tras cambios lógicos para asegurar que el proyecto compila y pasa tests sin errores críticos, evitando bucles redundantes de sobre-verificación.
