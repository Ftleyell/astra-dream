# Guía Rápida de Balanceo — Astra Dream

> **Regla de Oro:** El balance numérico de Astra Dream es 100% Data-Driven. 
> **NUNCA** modifiques scripts `.gd` para alterar daño, vida, precios o cadencias. 
> Todo cambio se realiza editando archivos de recursos `.tres` con Godot o cualquier editor de texto.
> Consulta también [`docs/DOMAIN_MAP.md`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/DOMAIN_MAP.md) para el mapa completo de archivos autoridad.

---

## 1. Armas y Proyectiles (`data/weapons/`)

Ubicación: 
- `data/weapons/roster/` (ej. `rail_launcher.tres`, `crescent_blade.tres`, `tesla_arc.tres`, `singularity_pulsar.tres`).
- `data/weapons/shop/` (ej. `solar_beam.tres`, `nova_flak.tres`, `dimensional_blade.tres`).

| Propiedad en el `.tres` | Tipo | Impacto en Juego | Consejo de Balance |
| :--- | :--- | :--- | :--- |
| `base_damage` | `float` | Daño por impacto en Nivel 1. | Mantener entre 12.0 y 50.0 según cadencia. |
| `cooldown` | `float` | Intervalo en segundos entre ráfagas. | 0.15s para ametralladoras, 1.2s - 2.5s para cañones pesados. |
| `projectiles_per_shot` | `int` | Cantidad de disparos simultáneos. | Cuidado al subir: escala de forma multiplicativa con daño. |
| `spread_degrees` | `float` | Cono de dispersión en grados. | 0.0 para disparos precisos; 15°-45° para escopetas. |
| `damage_per_level` | `float` | Daño adicional sumado en cada subida de nivel. | Típicamente 15% - 25% del `base_damage`. |
| `cooldown_reduction_per_level`| `float` | Reducción plana de enfriamiento por nivel. | Evitar que baje de 0.05s totales en nivel 5. |

---

## 2. Enemigos, Jefes y Colosos (`scenes/combat/enemies/`)

Ubicación: `scenes/combat/enemies/`.

| Propiedad / Variable | Tipo | Impacto en Juego |
| :--- | :--- | :--- |
| `max_health` | `float` | Vida del enemigo base. |
| `movement_speed` | `float` | Velocidad de persecución en píxeles/segundo. |
| `contact_damage` | `float` | Daño infligido al chocar contra la nave del jugador. |
| `exp_value` | `int` | Cristales / experiencia otorgada al morir. |
| `credits_drop_chance` | `float` | Probabilidad (0.0 a 1.0) de soltar créditos de combate. |
| `health_scaling_per_wave` | `float` | Multiplicador porcentual acumulativo por oleada (ej. `0.18` = +18% HP/oleada). |

---

## 3. Composición de Oleadas y Pautas (`data/balance/`)

Ubicación: `data/balance/default_encounter_timeline.tres`.

- **`wave_duration`:** Duración de cada oleada regular (por defecto: 30.0s).
- **`total_waves`:** Cantidad de oleadas por expedición (16).
- **`boss_wave_milestones`:** Diccionario de hitos de Colosos (Oleadas 2, 5, 8, 11, 14, 16).
- **`rival_wave_milestones`:** Array de oleadas con emergencia de rivales (`[4, 7, 10, 13]`).
- **`adaptive_dps_floor` / `adaptive_dps_ceiling`:** Multiplicadores de salud adaptativa de colosos (`0.85` a `2.5`).

---

## 4. Sectores, Satélites y Economía (`data/sectors/`, `data/items/roster/`)

### Sectores Galácticos
Ubicación: `data/sectors/` (ej. `sector_nebula_outskirts.tres`, `sector_plasma_storm.tres`, `sector_void_abyss.tres`, `sector_singularity_core.tres`).
- Permiten ajustar multiplicadores de créditos, densidad de enemigos y rival asignado por sector.

### Recompensas de Satélites
Ubicación: `core/systems/satellite_reward_manager.gd` y `data/weapons/shop/`.
- Precios de reciclaje de armas: fórmula global `recycle_value = 20 + level * 15` (Lv1: 35c, Lv2: 50c, Lv3: 65c, Lv4: 80c, Lv5: 95c).

### Ítems Pasivos, Reactivos y Satelitales (54 ítems canónicos)
Ubicación: `data/items/roster/` (54 archivos `.tres`).
- Todos los ítems y sus efectos residen como recursos `.tres` individuales editables sin tocar código.

---

## 5. Heroínas y Pilotos (`data/characters/`)

Ubicación: `data/characters/` (ej. `char_nova.tres`, `char_valentina.tres`, `char_nyx.tres`, `char_estele.tres`).

- **`base_max_hp`:** Vida máxima inicial (típicamente 100 - 130).
- **`base_speed`:** Velocidad de desplazamiento inicial en px/s (típicamente 280 - 350).
- **`dash_cooldown`:** Tiempo de recarga del dash en segundos (0.8s a 1.5s).
- **`dash_invulnerability_time`:** Ventana de inmunidad durante el dash (0.2s a 0.35s).
- **`starting_weapon`:** Referencia al recurso `.tres` del arma predilecta.
