# Balance de Economía y Recursos — Astra Dream

Este documento es la **fuente autoritativa** de balance económico de **Astra Dream**. Define las fuentes de ingreso, tasas de caída, deflación de créditos y tablas de precios de la Tienda Satelital y Balizas Tragamonedas.

---

## 1. Economía Tripartita de Recursos

| Recurso | Tipo de Ámbito | Fuentes de Obtención | Destino de Consumo |
|---|---|---|---|
| **Créditos Estelares** | *In-Run* (Se pierden al terminar) | Bajas enemigas, minería de asteroides, cofres de gacha. | Tienda Satelital (armas e ítems) y Máquinas Tragamonedas. |
| **BioMasa** | *Meta-Moneda* de Piloto (Permanente)| Bajas de enemigos orgánicos y geodas planetarias. | Desbloqueo y subida de nivel en Árbol de Talentos Hexagonal en el Hub. |
| **Materia Oscura** | *Meta-Moneda* Global (Permanente) | Derrota de Jefes de Dominio y destrucción de macro-planetas. | Compra y mejora de Trofeos en la Sala de Trofeos 3D del Hangar. |

---

## 2. Tasas de Generación y Deflación de Créditos

Con el rework integral se aplicó una deflación controlada de créditos para evitar que el jugador acumule miles de créditos trivializando la tienda:

| Fuente de Créditos | Probabilidad de Caída | Cantidad por Entrega |
|---|:---:|:---:|
| **Drone Común** | 35% | `1 - 2 Créditos` |
| **Kamikaze / Micro-Flock** | 25% | `1 Crédito` |
| **Shooter / Splitter** | 60% | `2 - 4 Créditos` |
| **Tanque Blindado** | 100% | `6 - 10 Créditos` |
| **Herald Élite / Campeón** | 100% (Garantizado) | `18 - 28 Créditos` |
| **Asteroide Metálico Minado** | 100% | `12 - 25 Créditos` |
| **Piloto Rival Derrotado** | 100% | `35 - 50 Créditos` + Cápsula de Arma |
| **Jefe de Dominio Derrotado** | 100% | `60 - 90 Créditos` + 2 Materia Oscura |

---

## 3. Calibración de Precios en Tienda Satelital (`SatelliteShop`)

* **Límite de Re-roll Estricto:** **1 solo re-roll por visita** de satélite.
* **Coste de Re-roll:** `30 Créditos` planos. Una vez usado, el botón se bloquea visualmente.

| Categoría en Tienda | Rango de Precios | Ranura en Tienda |
|---|:---:|:---:|
| **Arma Nueva (Lv1)** | `120 - 140 Créditos` | Ranura 1 |
| **Mejora de Arma Equipada (+1 Nivel)** | `75 - 100 Créditos` | Ranura 1 |
| **Módulos de Sobrecarga (Trade-offs)** | `55 - 75 Créditos` | Ranura 2 y 3 |
| **Artefactos Reactivos (Procs)** | `75 - 95 Créditos` | Ranura 2 y 3 |
| **Núcleos de Conversión (Mecánicas)** | `90 - 120 Créditos` | Ranura 2 y 3 |

---

## 4. Baliza Tragamonedas Estelar (`InRunSlotMachine`)

Baliza interactiva opcional que aparece aleatoriamente en el cuadrante de combate:
* **Tiradas Máximas por Baliza:** `3 giros`.
* **Coste Progresivo:** `50 Créditos` en el 1er giro, `+25 Créditos` adicionales en cada giro consecutivo (Giro 1: 50c, Giro 2: 75c, Giro 3: 100c).

| Resultado de los Rodillos | Probabilidad Base | Recompensa Otorgada |
|---|:---:|---|
| **3x 💰 (Jackpot de Oro)** | 8.0% | Devuelve `4x a 5x` el costo invertido (`200 - 350 Créditos`). |
| **3x 💣 (Jackpot de Bombas)** | 10.0% | Otorga `+2 Bombas Inteligentes` inmediatas. |
| **3x 🧲 (Jackpot Magnético)** | 12.0% | Pulso de imán total: absorbe toda la EXP dispersa en el mapa. |
| **3x 💖 (Jackpot Médico)** | 10.0% | Cura `100% de la Vida` actual y otorga `+25 HP Máximo`. |
| **Par (2 símbolos iguales)** | 35.0% | Reembolso del `100%` del costo del giro. |
| **Fallo (3 símbolos dispares)**| 25.0% | Sin recompensa (pérdida de la inversión). |
