# Balance de Oleadas, Enemigos y Colosos — Astra Dream

Este documento es la **fuente autoritativa** de balance para el cronograma de oleadas (Waves 1-16), composición de enemigos comunes, mecánicas de jefes de dominio, encuentros de rivales y fórmulas de mitigación/escalado adaptativo en **Astra Dream**.

---

## 1. Cronograma General de Oleadas (Waves 1 a 16)

* **Duración Estándar de Oleada:** `30.0 segundos` de combate activo por ronda.
* **Tope de Enemigos Simultáneos:** Escalado progresivo de 50 (Wave 1) a 80 (Wave 3+).
* **Intervalo de Generación:** Desciende de `1.2s` iniciales a `0.28s` conforme avanza la oleada.

| Oleada | Tipo de Encuentro | Composición Dominante de Enemigos | Hito / Evento Especial |
|:---:|:---:|---|---|
| **1** | Horda Inicial | 75% Drones, 15% Kamikazes, 10% Micro-Flocks | Introducción táctica y recolección de EXP |
| **2** | **JEFE DE DOMINIO** | Pausa de comunes durante el duelo | **Eremita del Vacío** (Coloso 1: `1600 HP`) |
| **3** | Horda de Presión | 45% Drones, 25% Kamikazes, 15% Shooters, 15% Flocks | Aparición de artillería a distancia |
| **4** | **RIVAL PILOT** | Horda común + llegada de Rival vía portal | **Duelo de Rival 1** (Recompensa: Arma Insignia Lv1) |
| **5** | **JEFE DE DOMINIO** | Pausa de comunes | **Espejo Roto** (Coloso 2: `3200 HP`, Clones y Reflejos)|
| **6** | Horda Blindada | 30% Tanques, 30% Splitters, 25% Shooters, 15% Drones | Choque contra armaduras pesadas |
| **7** | **RIVAL PILOT** | Horda + Rival 2 | **Duelo de Rival 2** |
| **8** | **JEFE DE DOMINIO** | Pausa de comunes | **Reloj de Cenizas** (Coloso 3: `2400 HP`, Dilatación) |
| **9** | Horda Caótica | 35% Splitters, 25% Micro-Flocks, 25% Kamikazes, 15% Drones | Densidad balística extrema |
| **10** | **RIVAL PILOT** | Horda + Rival 3 | **Duelo de Rival 3** |
| **11** | **JEFE DE DOMINIO** | Pausa de comunes | **Vórtice del Desborde** (Coloso 4: `4500 HP`) |
| **12** | Horda Élite | 30% Tanques, 25% Shooters, 25% Heralds, 20% Drones | Bombarderos élite con telegraphs |
| **13** | **RIVAL PILOT** | Horda + Rival 4 | **Duelo de Rival 4** |
| **14** | **JEFE DE DOMINIO** | Pausa de comunes | **Nave Nodriza Aegis** (Coloso 5: `5500 HP`) |
| **15** | Tormenta Final | Mezcla equilibrada de todas las unidades hostiles | Supervivencia previa al Clímax |
| **16** | **FINAL BOSS** | Coloso Divino | **Astra Prime** (`6500 - 8000 HP`, Danmaku Completo) |

---

## 2. Eventos Periódicos de Combate

1. **Enjambre Masivo Repentino (`Swarm Rush`):**
   * Se dispara periódicamente cada **45.0 segundos**.
   * Hace aparecer de 8 a 16 drones rápidos en formación circular envolvente alrededor del jugador para forzar el uso de dash o armas de control de masas.
2. **Nave Arcoíris (`Loot Goblin`):**
   * Spawnea entre los 50s y 75s en los bordes del cuadrante.
   * Vuelo transversal a alta velocidad. Al ser destruida, garantiza un cofre de créditos dorados y orbes arcanos.

---

## 3. Escalamiento Adaptativo de Vida de Jefes y Rivales

Para evitar que un jugador altamente potenciado elimine a los colosos en 2 segundos, o que un jugador en desventaja quede estancado en un combate de 10 minutos, la vida máxima de los jefes se calibra dinámicamente al momento del spawn:

$$\text{WaveFactor} = 1.0 + (\text{CurrentWave} \times 0.08)$$
$$\text{DPSFactor} = \operatorname{clamp}\left(\frac{\text{PlayerBaseDamage}}{20.0} \times \frac{\text{PlayerAttackSpeed}}{1.0},\ 0.85,\ 2.50\right)$$
$$\text{AdaptiveBossHP} = \text{BaseHP} \times \text{WaveFactor} \times \text{DPSFactor}$$

### Mitigación de Daño Instantáneo (Burst Compression)
Para preservar la tensión táctica, los jefes aplican compresión sobre impactos excesivamente destructivos:
* Si un impacto individual supera el **12% de la vida máxima restante del coloso**, el daño excedente se atenúa mediante una raíz cuadrada:
  $$\text{DmgExcedente} = \text{DmgReal} - \text{UmbralBurst}$$
  $$\text{DmgFinal} = \text{UmbralBurst} + \sqrt{\text{DmgExcedente} \times 10.0}$$
* Esto asegura un piso de combate de entre **20 y 55 segundos**, garantizando que el jugador experimente las fases mecánicas de cada coloso.
