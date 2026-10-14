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
   - Todo componente o entidad de combate pausable debe asegurar `process_mode = Node.PROCESS_MODE_PAUSABLE`.
5. **Higiene de Setters y @export:**
   - Los setters de propiedades (`set(v):`) pueden dispararse antes de `_ready()` durante la instanciación de escenas o asignaciones directas.
   - **Prohibido asumir que nodos hijos, cámaras o autoloads están listos dentro de un setter.** Usar siempre guardas (`if not is_inside_tree()`, `if _camera_ref != null and is_instance_valid(_camera_ref)`) o diferir la sincronización al siguiente ciclo de `_process()`.
6. **Autoloads vs Componentes:** Restringir autoloads a servicios de infraestructura puros (`SaveManager`, `AudioManager`, `EventBus`, `BulletServer`). Lógica de entidades debe ser modular mediante nodos hijos.
7. **Vinculación con Recursos (.tres) y Nomenclatura:**
   - Identificadores de armas, ítems y skins en código deben usar `StringName` idénticos a los nombres de sus recursos base (ej. `&"rail_launcher"`, `&"tesla_coil"`, `&"nova_base"`).
   - Constantes de configuración deben agruparse en estructuras tipadas o en recursos exportados para no ensuciar el espacio de nombres de la clase.
