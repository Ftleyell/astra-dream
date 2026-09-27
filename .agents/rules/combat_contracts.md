---
trigger: model_decision
description: "Contratos de interfaz de combate (take_damage, HitContext, proc_coefficient) y grupos de entidades en Astra Dream."
---

# Contratos de Interfaz de Combate — Astra Dream

1. **Entidades Atacables (Enemigos, Jefes, Emisores):**
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

3. **Canales de Comunicación:**
   - Grupos estándar: `"player"`, `"enemies"`, `"emitters"`.
   - DTOs tipados: `HitContext`.
   - Bus de eventos global: `EventBus`.
