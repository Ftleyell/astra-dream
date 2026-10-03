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
  * Pool: Ítems comunes básicos de economía, supervivencia y aceleración inicial.
* **Cofre Regular (`REGULAR`):**
  * Coste Base: `25 Créditos`.
  * Fórmula de Inflación Cuadrática: `C(n) = CosteBase + 8*n + 1.5*n^2` (donde `n` es el número de cofres abiertos con pago).
  * Recargo por Tarjeta Verde: `+10% acumulativo por stack`.
  * Pool: Ítems poco comunes y raros, procs reactivos y trade-offs tácticos.
* **Cofre Dorado (`GOLDEN`):**
  * Coste Fijo: `150 Créditos` (no inflacionario). Inmune a la apertura por llaves.
  * Pool: Ítems épicos, legendarios y núcleos de conversión de alto impacto.

### B. Llave Cuántica (`quantum_key`) y Mecánica de Descuento
* **Efecto Pasivo:** Proporciona una probabilidad asintótica de apertura gratuita en cofres regulares:
  `P(gratis) = 1.0 - (1.0 / (1.0 + 0.1 * keys))`
  * 1 Llave: ~9.1%
  * 10 Llaves: 50.0%
  * 90 Llaves: 90.0%
* **Congelación de Inflación:** Al activarse la apertura gratuita con llave, el contador de cofres pagados `n` **no se incrementa**, congelando el coste de los siguientes cofres.
* **HUD Integrado:** Píldora cian translúcida centrada sobre el contenedor de armas (`WeaponSlotsRow`) mostrando `x{N} ({%}% Gratis)` con animación de escala elástica al recolectar.

### C. Modal de Selección Táctica de 3 Ítems (`ChestRewardModal`)
* Al abrir cualquier cofre, el combate se pausa y se presenta un borrador de 3 ítems no repetidos generados por `ItemPoolManager.roll_chest_draft()`.
* Selección mediante atajos de teclado numérico `[1]`, `[2]`, `[3]` o clic directo sobre la carta.

### D. Forja Cuántica Orbital (`TransmutationStation`)
* Estación interactiva desplegada en fases avanzadas con **3 usos máximos**.
* Permite al jugador seleccionar un ítem duplicado o no deseado de su inventario para transmutarlo en otro ítem aleatorio de la misma categoría de rareza.

