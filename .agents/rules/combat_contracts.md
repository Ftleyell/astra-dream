---
trigger: model_decision
description: "Contratos de interfaz de combate (take_damage, HitContext, proc_coefficient), grupos de entidades y binding orbital en Astra Dream."
---

# Contratos de Interfaz de Combate — Astra Dream

1. **Entidades Atacables (Enemigos, Jefes, Emisores, Planetas Destruibles):**
   - Deben pertenecer al grupo `"enemies"` (`add_to_group("enemies")` en `_ready()`).
   - Deben implementar obligatoriamente el método:
     ```gdscript
     func take_damage(ctx: HitContext) -> void:
     ```
   - Aplicar `ctx.final_damage` y procesar bifurcaciones si corresponde.
   - Al morir, otorgar recompensas a `Player` si es válido y llamar a `queue_free()`.

2. **Armas y Fuentes de Daño (Láseres, Misiles, Drones aliados):**
   - Encapsular todo daño en una instancia tipada de `HitContext`.
   - Respetar el `proc_coefficient` y utilizar `ctx.fork_child_hit(...)` para cualquier efecto secundario, rebote o explosión derivada.

3. **Canales de Comunicación y Grupos Estándar:**
   - Grupos de gameplay: `&"player"`, `&"enemies"`, `&"emitters"`.
   - Grupos de infraestructura: `&"main_game"`, `&"bullet_server"`, `&"cosmos_root"`.
   - DTOs tipados: `HitContext`.
   - Bus de eventos global: `EventBus`.

4. **Sincronización de Entidades con el Fondo Espacial:**
   - Toda entidad física o interactiva en GameplayWorld (planetas destructibles, estaciones de transmutación, balizas de satélite) que deba coincidir visualmente con un elemento de fondo debe utilizar el componente desacoplado `OrbitalWorldFollower2D` vinculado a un `CosmosOrbitSlot`.
   - Prohibido mover entidades de combate reparentándolas a nodos del fondo espacial o CanvasLayers de parallax.
