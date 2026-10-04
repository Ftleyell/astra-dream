# Plan de Balance Fino de Combate y Feedback Táctico — Hito M7

> Documento maestro de diseño y calibración jugable para Astra Dream (v0.5.0+).
> Define los 4 ejes de balance numérico y experiencia sensorial antes del playtesting masivo.

---

## 1. Visión y Objetivos del Hito M7

Tras completar la desarticulación de archivos monolíticos y la implantación de la arquitectura Data-Driven, el código ya no contiene números mágicos de combate. El objetivo de **M7** es utilizar exclusivamente los recursos `.tres` para alcanzar una experiencia de combate fluida, tensa y legible, donde cada decisión de equipamiento y maniobra táctica tenga impacto tangible.

---

## 2. Ejes de Calibración Numérica

### Eje 1: Afinación del Arsenal (8 Armas en `data/weapons/`)
* **Identidad Táctica:**
  - `rail_launcher`: Daño cinético de alta perforación, cadencia lenta (1.2s - 1.5s), impacto crítico elevado.
  - `plasma_flak`: Dispersión de perdigones de plasma con daño en área (AoE) para despejar enjambres a corta distancia.
  - `swarm_missiles`: Proyectiles autónomos balísticos en ráfaga con fijación angular.
  - `void_siphon`: Haz continuo de drenaje que ralentiza y roba vida temporal / escudos.
  - `scatter_laser`: Ráfagas cónicas con rebote o refracción.
  - `crescent_blade`: Ataques de corte en medialuna a corta y media distancia (especialidad de Nyx).
  - `tachyon_beam`: Láser de carga instantánea que atraviesa toda la pantalla.
  - `singularity_cannon`: Disparo hiper-denso que colapsa y atrae a los hostiles antes de detonar.
* **Escalado Progresivo:** Ajustar `damage_per_level` y `cooldown_reduction_per_level` para que cada nivel (Lv1 a Lv5) incremente el DPS efectivo en un rango del 18% al 25% sin generar saturación excesiva de proyectiles.

### Eje 2: Curvas de Oleadas y Pacing de Colosos (`data/timeline/default_encounter_timeline.tres`)
* **Cronograma de Oleadas (1 a 16):**
  - Oleadas 1-4: Introducción de patrones y enjambres ligeros (Scouts, Swarmers).
  - Oleada 5: Coloso de Dominio (Hermit / Broken Mirror).
  - Oleadas 6-9: Introducción de Splitters, Artilleros y campos de asteroides hostiles.
  - Oleada 10: Coloso Intermedio y encuentro con Piloto Rival.
  - Oleadas 11-15: Máxima saturación danmaku, unidades blindadas y enjambres mixtos.
  - Oleada 16: Coloso Final (Astra Prime).
* **Escalado Adaptativo de Salud:** Calibración de `adaptive_dps_floor: 0.85` y `adaptive_dps_ceiling: 2.5` para garantizar que la duración de los combates contra Colosos se mantenga entre **35s y 55s**, premiando builds de alto DPS sin degradar el reto danmaku.

### Eje 3: Economía de Run y Sinergias de Satélites (`data/items/roster/`)
* **Generación de Créditos:** Calibrar los créditos otorgados por bajas ($1-3c$ enemigos menores, $15-25c$ élites, $100c$ colosos) para permitir un promedio de **1 compra de ítem/arma y 1 reciclaje** por cada interacción con el satélite.
* **Ítems con Tradeoff:**
  - `Glass Reactor`: +45% Daño total, -35% Vida máxima.
  - `Heavy Capacitor`: +60% Daño de carga, -20% Velocidad de movimiento.
  - `Tachyon Piercer`: Perforación infinita, -25% Cadencia de fuego.

### Eje 4: Feedback Audiovisual y Legibilidad en Pantalla
* **Impact Punch:** Micro-flash blanco (1 cuadro / 0.016s) al recibir impacto en naves enemigas.
* **Capa Acústica de Críticos:** Sonido distintivo modulado por pitch aleatorio ($\pm 0.05$) para disparos críticos y desmembramiento de blindajes.
* **Damage Accumulator:** Verificación de legibilidad del acumulador de daño en pantalla para que los números no obstruyan la retícula de apuntado ni los proyectiles hostiles.

---

## 3. Matriz de Entregables de M7

| Sub-Hito | Tarea Principal | Archivos Involucrados |
| :--- | :--- | :--- |
| **M7.1** | Rebalanceo numérico de las 8 armas base | `data/weapons/*.tres` |
| **M7.2** | Afinación de oleadas, densidad y colosos | `data/timeline/default_encounter_timeline.tres` |
| **M7.3** | Calibración de drop rates de créditos y satélites | `data/items/roster/*.tres` |
| **M7.4** | Pulido sensorial de impacto, audio y VFX | `scenes/combat/enemies/`, `scenes/ui/hud/` |
