# Balance de Armamento — Astra Dream

Este documento es la **fuente autoritativa** de balance para el arsenal de **Astra Dream**. Define los parámetros base, fórmulas de escalamiento por nivel (Lv1 a Lv5), proyectiles y mecánicas únicas.

---

## 1. Reglas Globales del Sistema de Armas

* **Capacidad Máxima de Ranuras:** **4 armas activas simultáneas** (`MAX_WEAPON_SLOTS = 4`).
* **Bloqueo Inmutable del Arma Base (Slot 0):** El arma insignia inicial de la heroína ocupa de forma fija la primera ranura (`slot 0`) y **no puede ser reemplazada, vendida ni descartada**. Esto garantiza la identidad del arquetipo durante toda la run.
* **Sustitución y Swap (Slots 1 a 3):** Al adquirir un arma cuando el inventario está lleno (por Tienda Satelital o cápsula de Rival derrotada), se abre el modal de reemplazo permitiendo al jugador seleccionar exclusivamente qué arma secundaria (ranuras 1 a 3) sustituir.
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

## 3. Arsenal Canónico y Coeficientes de Activación (Proc Coefficients)

Cada proyectil cuenta con un **coeficiente de activación** $\kappa_{\text{proc}} \in [0.0, 1.0]$. La probabilidad real de disparo de artefactos reactivos se modula según $P_{\text{real}} = P_{\text{base}} \cdot \kappa_{\text{proc}}$:

| ID / Recurso (`.tres`) | Tipo / Origen | Daño Base (Lv1) | Cooldown Base | Proyectiles Base | $\kappa_{\text{proc}}$ | Efectos y Perforación | Crecimiento por Nivel (Lv 1 $\rightarrow$ 5) |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **`rail_launcher`** | Lineal / Nova | `28.0` | `0.45s` | 1 | **0.60** | Perforación ilimitada en línea recta | `+25% Daño/Lv`<br>Lv5: `56.0` Daño, 5 Proy |
| **`scatter_laser`** | Francotirador / Valentina| `95.0` | `1.40s` | 1 | **0.25** | Crítico a larga distancia (+50% crit dmg) + Fragmentación | `+35% Daño/Lv`<br>Lv5: `228.0` Daño, 5 Proy |
| **`swarm_missiles`**| Teledirigido / Kira | `14.0` | `0.65s` | 4 abanico | **0.40** | Micro-cohetes guiados | `+20% Daño/Lv`<br>Lv5: `25.2` Daño, 8 Proy |
| **`void_siphon`** | Vórtice / Selene | `45.0` | `1.80s` | 1 vórtice | **0.15** | Atracción continua + Aura Stutter-Field (-25% vel) | `+30% Daño/Lv`<br>Lv5: `99.0` Daño, 5 Vórtices |
| **`plasma_flak`** | Escopeta / Roxy | `16.0` | `0.90s` | 6 dispersión| **0.35** | Empuje cinético pesado + fragmentación | `+25% Daño/Lv`<br>Lv5: `32.0` Daño, 10 Proy |
| **`crescent_blade`**| Melee / Nyx | `55.0` | `0.75s` | 1 arco | **1.00** | Destruye balas hostiles en su arco (100% proc) | `+30% Daño/Lv`<br>Lv5: `121.0` Daño, 5 Arcos |
| **`tachyon_beam`** | Rayo / Satélite | `18.0` | `0.10s` (Tic)| 1 haz | **0.10** | Haz continuo perforante (ICD de 0.15s) | `+15% Daño/Lv`<br>Lv5: `28.8` Daño/tic, 5 Haces |
| **`singularity_cannon`**| Gravitatorio / Satélite| `60.0` | `1.20s` | 1 esfera | **0.20** | Colapso estelar masivo al final de trayectoria | `+30% Daño/Lv`<br>Lv5: `132.0` Daño, 5 Proy |

---

## 4. Regla Cero y Limitadores de Bucles Infinitos

1. **Aislamiento de Disparos Hijos (Regla Cero — $\kappa_{\text{child}} = 0.0$):**
   * Ningún efecto secundario reactivo (rayos de Tesla Coil, esquirlas de Batería Piroclástica, misiles de Represalia) puede activar otros procs secundarios. Su `proc_coefficient` viaja forzado a `0.0`.
2. **Enfriamiento Interno Dinámico (ICD Throttling):**
   * Armas de alta frecuencia (como `tachyon_beam` o `hive_cannon`) disponen de un limitador por ítem (`_proc_cooldowns`) para prevenir cascadas masivas sobre el procesador y `BulletServer`.

---

## 5. Compensación Temprana de Armas Lentas

Para solventar la vulnerabilidad en oleadas 1-3 de armas con cadencia pesada ($CD > 1.1s$):
* **Pulso a Quemarropa Innato (Point-Blank Pulse):** Si al disparar un arma con $CD > 1.1s$ hay enemigos a menos de $80\text{px}$, el jugador libera automáticamente una onda radial que inflige un 30% del daño base con $250\text{px/s}$ de retroceso (evitando doble impacto con el proyectil principal).
* **Fragmentación de Scatter Laser:** Al eliminar enemigos debilitados (< 20% HP) en niveles 1-2, dispersa 4 esquirlas radiales con un 25% de daño.
* **Aura Stutter-Field:** Durante la recarga de armas de vórtice/agujero negro, se proyecta un aura de $140\text{px}$ que ralentiza en un 25% a las naves hostiles cercanas.

---

## 6. Protocolo One-Shot Protection (OSP)

* **Garantía de Supervivencia:** Si la nave del jugador posee $\ge 90\%$ de salud combinada (Vida + Escudos) y recibe un impacto que supera su vitalidad restante:
  * El daño letal se trunca a `VidaCombinada - 1.0`, preservando a la nave con al menos `1 HP`.
  * Se activa un período de invulnerabilidad táctica de `0.5s` (`is_invulnerable = true`).
  * Se emite la señal `osp_triggered` con feedback holográfico de advertencia en el HUD.
* **Compatibilidad:** Mantiene la protección incluso bajo efectos de armadura negativa por maldición o arcanas de cristal.

