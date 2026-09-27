---
trigger: model_decision
description: "Directrices de arquitectura data-driven, Custom Resources (.tres) y composición modular de nodos en Godot 4."
---

# Arquitectura de Datos y Desacoplamiento — Astra Dream

1. **Data-Driven con Custom Resources (`.tres`):**
   - Ítems definidos como recursos inmutables heredando de `ItemData` o `ItemEffect`.
   - Heroínas definidas como recursos heredando de `CharacterData`.
   - Armas definidas mediante recursos heredando de `WeaponData`.
   - Mascotas heredando de `PetData`.
   - Navegantes heredando de `NavigatorData`.

2. **Composición de Nodos vs Herencia Profunda:**
   - Preferir agregar componentes específicos (ej. áreas de colisión, controladores de sonido, gestores de estado) antes que crear jerarquías de herencia complejas.
   - Entidades principales deben tener responsabilidades acotadas para permitir refactorizaciones quirúrgicas.
