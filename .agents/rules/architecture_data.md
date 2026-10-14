---
trigger: model_decision
description: "Directrices de arquitectura data-driven, Custom Resources (.tres), Value Objects y composición modular de nodos en Godot 4."
---

# Arquitectura de Datos y Desacoplamiento — Astra Dream

1. **Data-Driven con Custom Resources (`.tres`):**
   - **Ítems y Mejoras:** Recursos inmutables heredando de `ItemData` o `ItemEffect`.
   - **Heroínas y Pilotos:** Definidos mediante recursos heredando de `CharacterData`.
   - **Armamento:** Modelado en recursos heredando de `WeaponData` con arrays de niveles (`WeaponLevelStats`).
   - **Composición y Cronograma de Oleadas:** Modelado en recursos `EncounterTimelineConfig` y `WaveData` para duraciones, composición de spawns, pesos y milestones de jefes/rivales.
   - **Mascotas y Navegantes:** Heredando de `PetData` y `NavigatorData`.
   - **Configuración Espacial (Cosmos Engine):** Recursos de datos bajo `scenes/combat/environment/cosmos/resources/data/` (`CosmosEnvironmentConfig`, `CelestialSystemConfig`, `CosmicBiomeData`, `ShadowSystemConfig`, `StarVisualConfig`).
   - **Prohibición de Números Mágicos:** Ningún script de entidad (`EnemySpawner`, `MainGame`, `Player`, `CosmosRootNode`) debe contener tablas numéricas de progresión o constantes estéticas escritas a mano; deben inyectarse o cargarse vía recurso `.tres`.

2. **Value Objects y DTOs Desacoplados:**
   - Para transferir datos o cálculos matemáticos entre subsistemas dispares (ej. Cosmos Engine hacia GameplayWorld), utilizar **Value Objects** matemáticos puros (como `CosmosOrbitSlot`) sin referencias vivas a nodos (`Node2D`, `SceneTree`). Esto previene fugas de memoria, fallos por reciclaje en Object Pools y desincronización de transforms.
   - Para eventos de combate y daño, encapsular los parámetros en DTOs tipados como `HitContext`.

3. **Composición de Nodos vs Herencia Profunda:**
   - Preferir agregar componentes específicos (`HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `PlayerLocomotionController`, `OrbitalWorldFollower2D`) antes que crear jerarquías de herencia complejas.
   - Entidades principales (`Player`, `EnemyBase`, `MainGame`) actúan como orquestadores livianos, delegando el comportamiento en componentes hijos desacoplados.

4. **Inmutabilidad y Sincronización:**
   - Los recursos compartidos (`.tres`) no deben mutar su estado base en tiempo de ejecución.
   - Para estados variables durante la partida (ej. stacks de ítems, nivel de arma activa, recarga de llaves), delegar en componentes de runtime (`InventoryComponent`, `WeaponController`, `PlayerEconomyComponent`).
