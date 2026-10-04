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

---

## 5. Sistema de Cofres Espaciales, Llaves Cuánticas y Forja Orbital

### A. Variantes de Cofres Espaciales (`SpatialChest`)
Los cofres se invocan dinámicamente en el espacio mediante `ChestDirector`:
* **Cápsula de Chatarra (`SALVAGE_CAPSULE`):**
  * Coste: `0 Créditos` (siempre gratis).
  * Pool: Ítems comunes básicos de economía, supervivencia y aceleración inicial. Sinergiza con `heavy_salvager` (+2 HP Max y +3c por cápsula).
* **Cofre Regular (`REGULAR`):**
  * Coste Base: `20 Créditos` + `4 * Oleada`.
  * **Modelo Híbrido Wave-Inflation Amortiguado:**
    $$C(w, k) = \lfloor (20 + 4w) \cdot (1 + 0.15k) \cdot (1 + 0.10 \cdot \text{cards}) \cdot \text{key\_discount} \rfloor$$
    * $w \in [1, 16]$: Oleada activa.
    * $k \in \mathbb{N}_0$: Aperturas de cofres locales en la oleada activa (se reinicia $k \to 0$ al pasar de oleada).
    * $\text{cards}$: Stacks de Tarjeta de Crédito Verde (`credit_card_green`).
    * $\text{key\_discount}$: Multiplicador de $0.80$ (-20% de descuento) si el jugador porta al menos 1 Llave Cuántica en inventario.
  * Ejemplos calibrados:
    * Oleada 1 ($k=0$): 24c (19c con Llave).
    * Oleada 1 ($k=3$): 34c (27c con Llave).
    * Oleada 8 ($k=0$): 52c.
    * Oleada 16 ($k=0$): 84c.
* **Cofre Dorado (`GOLDEN`):**
  * Coste Fijo: `120 Créditos` (no inflacionario, inmune a consumo o descuento por Llaves Cuánticas).
  * Pool: Ítems épicos, legendarios y de gran sinergia.

### B. Llave Cuántica (`quantum_key`) y Consumo Activo / Descuento Pasivo
* **Consumo Activo (Apertura Gratuita):** Si el jugador posee al menos 1 Llave Cuántica, al interactuar con un Cofre Regular se consume **1 llave** para abrirlo completamente gratis (`0c`), **sin incrementar la inflación local $k$** ni el contador de compras pagadas.
* **Descuento Pasivo (-20%):** Si el jugador decide o debe pagar con créditos teniendo llaves, se le aplica un 20% de descuento permanente en el coste monetario de compra.
* **HUD Integrado:** Píldora cian translúcida (`KeyBadge`) sobre las ranuras de armas (`WeaponSlotsRow`), mostrando `x{N} (-20% Desc.)` con animación elástica al recolectar.

### C. Modal de Selección Táctica de 3 Ítems (`ChestRewardModal`) & Sistema de Pity PRD
* Al abrir cualquier cofre, el combate se pausa y se presenta un borrador de 3 ítems no repetidos generados por `ItemPoolManager.roll_chest_draft()`.
* **Distribución Pseudo-Aleatoria (PRD) y Pity System Dinámico:**
  * Contador interno de tiradas sin rarezas altas:
    * Umbral Raro: 5 cofres (reducido por suerte).
    * Umbral Épico: 10 cofres (reducido por suerte).
    * Umbral Legendario: 15 cofres (reducido por suerte).
  * Reducción por Suerte (`player_luck`): $\Delta = \lfloor \text{luck} / 20 \rfloor$, con piso mínimo garantizado de 5 cofres para Legendario.
  * Al forzar o salir una rareza alta, su contador se reinicia limpiamente a cero.

### D. Forja Cuántica Orbital (`TransmutationStation`)
* Estación interactiva desplegada en fases avanzadas con **3 usos base** (aumentados a **4 usos** con el artefacto `quantum_recompiler`).
* Permite al jugador seleccionar un ítem de su inventario para transmutarlo en otro ítem aleatorio de la misma categoría de rareza.


