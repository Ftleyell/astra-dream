---
trigger: model_decision
description: "Directrices de arquitectura data-driven, Custom Resources (.tres) y composición modular de nodos en Godot 4."
---

# Arquitectura de Datos y Desacoplamiento — Astra Dream

1. **Data-Driven con Custom Resources (`.tres`):**
   - **Ítems y Mejoras:** Recursos inmutables heredando de `ItemData` o `ItemEffect`.
   - **Heroínas y Pilotos:** Definidos mediante recursos heredando de `CharacterData`.
   - **Armamento:** Modelado en recursos heredando de `WeaponData` con arrays de niveles (`WeaponLevelStats`).
   - **Composición y Cronograma de Oleadas:** Modelado en recursos `EncounterTimelineConfig` y `WaveData` para duraciones, composición de spawns, pesos y milestones de jefes/rivales.
   - **Mascotas y Navegantes:** Heredando de `PetData` y `NavigatorData`.
   - **Prohibición de Números Mágicos:** Ningún script de entidad (`EnemySpawner`, `MainGame`, `Player`) debe contener tablas numéricas de progresión escritas a mano; deben inyectarse o cargarse vía recurso `.tres`.

2. **Composición de Nodos vs Herencia Profunda:**
   - Preferir agregar componentes específicos (`HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `DashController`) antes que crear jerarquías de herencia complejas.
   - Entidades principales (`Player`, `EnemyBase`, `MainGame`) actúan como orquestadores livianos, delegando el comportamiento en componentes hijos desacoplados.

3. **Inmutabilidad y Sincronización:**
   - Los recursos compartidos no deben mutar su estado base en tiempo de ejecución.
   - Para estados variables durante la partida (ej. stacks de ítems, nivel de arma activa), delegar en componentes de runtime (`InventoryComponent`, `WeaponController`).
