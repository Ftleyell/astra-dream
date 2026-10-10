# Game Design, Fórmulas y Balance — Astra Dream

Documento de referencia para mecánicas numéricas, mitigación, economía in-run y balance data-driven.

---

## 1. Filosofía Data-Driven

El 100% de los números de balance residen en Custom Resources exportados (`.tres`):
- `WeaponData`: Daño base, cadencia, velocidad de proyectil, perforación, coeficientes de dispersión.
- `CharacterData`: Puntos de vida base, armadura, velocidad de vuelo, aceleración, hitbox radius.
- `EncounterTimelineConfig`: Curvas de aparición, peso de enemigos, cronogramas de oleadas.
- **Prohibición:** Ningún archivo `.gd` debe incluir números mágicos de daño o estadísticas directamente en su código.

---

## 2. Fórmulas de Combate y Mitigación

### Mitigación por Armadura
El daño recibido por el jugador y enemigos acorazados se calcula con una curva hiperbólica estándar:

$$\text{Daño Final} = \text{Daño Entrante} \times \frac{100}{100 + \max(0, \text{Armadura})}$$

### One-Shot Protection (OSP)
- **Condición:** Si la salud actual del jugador es superior al **90%** de su salud máxima, ningún golpe individual puede reducir su vida a 0.
- **Efecto:** El golpe reduce la salud a exactamente **1 HP**, activando una ventana de invulnerabilidad táctica de emergencia (0.6 segundos) y un pulso visual de aviso.

---

## 3. Economía In-Run vs Metaprogresión

1. **Economía In-Run (Volátil):**
   - **Créditos:** Obtenidos al derrotar enemigos y romper asteroides. Utilizados exclusivamente en la tienda satelital (`SatelliteShop`) para adquirir mejoras de armas y pasivas durante la partida.
   - **Cristales de EXP:** Escalado por lotes mediante `CombatExpBatchOptimizer`. Aumentan el nivel de la nave y disparan la selección de mejoras (Level Up).
2. **Economía de Metaprogresión (Permanente):**
   - **Biomasa:** Recurso persistente guardado en `MetaProgressionState`. Se invierte en el árbol de talentos del Hub 3D.
   - **Materia Oscura / Llaves:** Monedas especiales para el sistema de gacha y desbloqueo de skins/avatares.

---

## 4. Encuentros Satelitales y Odómetro Espacial

- Las estaciones orbitales no aparecen por tiempo estricto, sino por **distancia recorrida** calculada por `SatelliteOdometer`.
- Al acercarse a una estación satelital, el jugador puede desacelerar para acoplarse y acceder a la tienda o estaciones de reparación táctica.
