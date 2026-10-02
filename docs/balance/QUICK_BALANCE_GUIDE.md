# Guía Rápida de Balanceo — Astra Dream

> **Regla de Oro:** El balance numérico de Astra Dream es 100% Data-Driven. 
> **NUNCA** modifiques scripts `.gd` para alterar daño, vida, precios o cadencias. 
> Todo cambio se realiza editando archivos de recursos `.tres` con Godot o cualquier editor de texto.

---

## 1. Armas y Proyectiles (`resources/weapons/`)

Ubicación: `resources/weapons/` (ej. `weapon_rail_launcher.tres`, `weapon_tesla_coil.tres`, `weapon_laser_pulse.tres`).

| Propiedad en el `.tres` | Tipo | Impacto en Juego | Consejo de Balance |
| :--- | :--- | :--- | :--- |
| `base_damage` | `float` | Daño por impacto en Nivel 1. | Mantener entre 12.0 y 50.0 según cadencia. |
| `cooldown` | `float` | Intervalo en segundos entre ráfagas. | 0.15s para ametralladoras, 1.2s - 2.5s para cañones pesados. |
| `projectiles_per_shot` | `int` | Cantidad de disparos simultáneos. | Cuidado al subir: escala de forma multiplicativa con daño. |
| `spread_degrees` | `float` | Cono de dispersión en grados. | 0.0 para disparos precisos; 15°-45° para escopetas. |
| `damage_per_level` | `float` | Daño adicional sumado en cada subida de nivel. | Típicamente 15% - 25% del `base_damage`. |
| `cooldown_reduction_per_level`| `float` | Reducción plana de enfriamiento por nivel. | Evitar que baje de 0.05s totales en nivel 5. |

---

## 2. Enemigos, Jefes y Colosos (`resources/enemies/`)

Ubicación: `resources/enemies/` (ej. `enemy_swarmer.tres`, `enemy_kamikaze.tres`, `boss_aegis.tres`).

| Propiedad en el `.tres` | Tipo | Impacto en Juego |
| :--- | :--- | :--- |
| `max_health` | `float` | Vida del enemigo base. |
| `movement_speed` | `float` | Velocidad de persecución en píxeles/segundo. |
| `contact_damage` | `float` | Daño infligido al chocar contra la nave del jugador. |
| `exp_value` | `int` | Cristales / experiencia otorgada al morir. |
| `credits_drop_chance` | `float` | Probabilidad (0.0 a 1.0) de soltar créditos de combate. |
| `health_scaling_per_wave` | `float` | Multiplicador porcentual acumulativo por oleada (ej. `0.18` = +18% HP/oleada). |

---

## 3. Composición de Oleadas y Pautas (`resources/encounters/`)

Ubicación: `resources/encounters/timeline_config.tres`.

- **`wave_duration_seconds`:** Duración de cada oleada regular (por defecto: 60.0s).
- **`boss_wave_interval`:** Cada cuántas oleadas aparece un Coloso (por defecto: cada 5 oleadas).
- **`spawn_rate_curve`:** Curva de cadencia de spawn exponencial a medida que transcurre el tiempo.
- **`enemy_pool_by_sector`:** Listas de tipos de enemigos habilitados por sector galáctico.

---

## 4. Satélites, Tienda y Economía (`resources/satellites/`, `resources/items/`)

### Recompensas de Satélites
Ubicación: `resources/satellites/` y `core/systems/satellite_reward_manager.gd`.
- Para ajustar el tiempo de carga del satélite, modifica `capture_duration_seconds` en `satellite_config.tres` (por defecto: 10.0s).
- Precios de reciclaje de armas: fórmula global `recycle_value = 20 + level * 15` (Lv1: 35c, Lv2: 50c, Lv3: 65c, Lv4: 80c, Lv5: 95c).

### Ítems Pasivos
Ubicación: `resources/items/` (ej. `item_espada.tres`, `item_botas.tres`, `item_trebol.tres`).
- **`stat_modifiers`:** Diccionario de estadísticas afectadas (`damage_pct`, `speed_pct`, `crit_rate`, `pickup_radius`).
- **`rarity`:** `COMMON` (blanco), `UNCOMMON` (verde), `RARE` (azul), `LEGENDARY` (dorado).
- **`stack_limit`:** Límite máximo de copias del mismo ítem en una run.

---

## 5. Heroínas y Pilotos (`resources/characters/`)

Ubicación: `resources/characters/` (ej. `char_nova.tres`, `char_valentina.tres`, `char_nyx.tres`, `char_estele.tres`).

- **`base_max_hp`:** Vida máxima inicial (típicamente 100 - 130).
- **`base_speed`:** Velocidad de desplazamiento inicial en px/s (típicamente 280 - 350).
- **`dash_cooldown`:** Tiempo de recarga del dash en segundos (0.8s a 1.5s).
- **`dash_invulnerability_time`:** Ventana de inmunidad durante el dash (0.2s a 0.35s).
- **`starting_weapon`:** Referencia al recurso `.tres` del arma predilecta.
