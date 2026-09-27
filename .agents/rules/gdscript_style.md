---
trigger: glob
globs: "*.gd"
description: "Estándares de tipado estricto, nomenclatura, señales y ciclo de vida de nodos en GDScript para Godot 4."
---

# Convenciones de GDScript para Godot 4.7+

1. **Tipado Estricto:** Obligatorio en variables miembro, variables locales, argumentos y retornos:
   - `var movement_speed: float = 200.0`
   - `func take_damage(ctx: HitContext) -> void:`
2. **Nombres de Clases Globales:** Declarar `class_name PascalCase` al inicio de cada script de entidad o componente.
3. **Señales y Callables:** Prohibido el uso de cadenas de texto para conectar señales; usar Callables fuertemente tipados:
   - `body_entered.connect(_on_body_entered)`
4. **Ciclo de Vida:**
   - Usar `_physics_process(delta)` exclusivamente para físicas y movimiento de entidades deterministas.
   - Usar `_process(delta)` para interpolaciones visuales, HUD y lógica desacoplada de cuadros fijos.
5. **Autoloads vs Componentes:** Restringir autoloads a servicios de infraestructura puros (`SaveManager`, `AudioManager`, `EventBus`, `BulletServer`). Lógica de entidades debe ser modular mediante nodos hijos.
