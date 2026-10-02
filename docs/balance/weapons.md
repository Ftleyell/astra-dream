# Balance de Armamento — Astra Dream

Este documento es la **fuente autoritativa** de balance para el arsenal de **Astra Dream**. Define los parámetros base, fórmulas de escalamiento por nivel (Lv1 a Lv5), proyectiles y mecánicas únicas.

---

## 1. Reglas Globales del Sistema de Armas

* **Capacidad Máxima de Ranuras:** **4 armas activas simultáneas** (`MAX_WEAPON_SLOTS = 4`).
* **Sustitución y Swap:** Al adquirir una 5ª arma (por Tienda Satelital o cápsula de Rival derrotada), se abre el modal de reemplazo permitiendo al jugador seleccionar qué arma sustituir.
* **Conservación de Nivel:** El arma entrante **conserva el nivel del arma reemplazada**, y el jugador recibe una bonificación de reciclaje en créditos según el nivel:
  $$\text{Créditos Reciclaje} = 20 + (\text{Nivel} \times 15) \quad \longrightarrow \quad \text{Lv1: 35c, Lv2: 50c, Lv3: 65c, Lv4: 80c, Lv5: 95c}$$
* **Escalado Universal de Proyectiles:** Toda arma gana proyectiles extra según su nivel actual:
  $$\text{Proyectiles Extra} = \text{Nivel} - 1 \quad (\text{Lv1: +0, Lv2: +1, Lv3: +2, Lv4: +3, Lv5: +4})$$

---

## 2. Fórmulas de Escalamiento Analítico

$$\text{Daño Base Arma} = \text{BaseDamage} \times \big(1.0 + (\text{Nivel} - 1) \times \text{DamageGrowth}\big)$$
$$\text{Daño Total por Disparo} = \text{Daño Base Arma} \times (1.0 + \text{PlayerDamageBonusPct}) + \text{PlayerFlatDamage}$$
$$\text{Cooldown Final} = \max\Big(0.2 \times \text{BaseCD},\ \text{BaseCD} \times \big(1.0 - (\text{Nivel} - 1) \times \text{CDRStep}\big)\Big) \times (1.0 - \text{PlayerCDR})$$
$$\text{Intervalo de Fuego} = \frac{\text{Cooldown Final}}{\max(0.2, \text{PlayerAttackSpeed})}$$

---

## 3. Arsenal Canónico (8 Armas Principales)

| ID / Recurso (`.tres`) | Tipo / Origen | Daño Base (Lv1) | Cooldown Base | Proyectiles Base | Vel. Bala | Efectos y Perforación | Crecimiento por Nivel (Lv 1 $\rightarrow$ 5) |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **`rail_launcher`**<br>`data/weapons/roster/rail_launcher.tres` | Lineal / Roster (Nova) | `28.0` | `0.45s` | 1 | 950.0 px/s | Perforación ilimitada en línea recta | `+25% Daño/Lv`<br>Lv5: `56.0` Daño, `0.34s` CD, 5 Proy |
| **`scatter_laser`**<br>`data/weapons/roster/scatter_laser.tres` | Ráfaga / Roster (Valentina)| `95.0` | `1.40s` | 1 | 1400.0 px/s| Crítico a larga distancia (+50% crit dmg) | `+35% Daño/Lv`<br>Lv5: `228.0` Daño, `0.98s` CD, 5 Proy |
| **`swarm_missiles`**<br>`data/weapons/roster/swarm_missiles.tres`| Teledirigido / Roster (Kira)| `14.0` | `0.65s` | 4 abanico | 520.0 px/s | Micro-cohetes dirigidos con viraje continuo | `+20% Daño/Lv`<br>Lv5: `25.2` Daño, 8 Proy |
| **`void_siphon`**<br>`data/weapons/roster/void_siphon.tres` | Vórtice / Roster (Selene) | `45.0` | `1.80s` | 1 vórtice | 280.0 px/s | Atracción gravitatoria + daño continuo radial | `+30% Daño/Lv, +Área`<br>Lv5: `99.0` Daño, 5 Vórtices |
| **`plasma_flak`**<br>`data/weapons/roster/plasma_flak.tres` | Escopeta / Roster (Roxy) | `16.0` | `0.90s` | 6 dispersión| 750.0 px/s | Empuje cinético pesado + fragmentación | `+25% Daño/Lv`<br>Lv5: `32.0` Daño, 10 Proy |
| **`crescent_blade`**<br>`data/weapons/roster/crescent_blade.tres`| Melee / Roster (Nyx) | `55.0` | `0.75s` | 1 arco | 600.0 px/s | Destruye balas hostiles en su arco | `+30% Daño/Lv, +Arco`<br>Lv5: `121.0` Daño, 5 Arcos |
| **`tachyon_beam`**<br>`data/weapons/roster/tachyon_beam.tres` | Rayo / Tienda Satelital | `18.0` | `0.10s` (Tic)| 1 haz | Continuo | Haz continuo perforante con alto DPS sostenido | `+15% Daño/Lv`<br>Lv5: `28.8` Daño/tic, 5 Haces |
| **`singularity_cannon`**<br>`data/weapons/roster/singularity_cannon.tres`| Gravitatorio / Tienda | `60.0` | `1.20s` | 1 micro-agujero| 450.0 px/s | Colapso estelar masivo al final de trayectoria | `+30% Daño/Lv`<br>Lv5: `132.0` Daño, 5 Proy |

---

## 4. Prioridad de Sinergias y Moduladores

1. **Armas Perforantes (`rail_launcher`, `tachyon_beam`):** Escalan exponencialmente con `collimator_lens` (+15% Crit) y `tachyon_prism` (+35% Crit Dmg).
2. **Armas de Alta Densidad (`swarm_missiles`, `plasma_flak`):** Máxima sinergia con `tesla_coil` (proc en crítico) y `pyroclastic_battery` (explosiones en bajas).
3. **Armas Defensivas / Control (`crescent_blade`, `void_siphon`):** Clave para mitigar oleadas cerradas de danmaku y proteger al jugador durante el plantado de satélites.
