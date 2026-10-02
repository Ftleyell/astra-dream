# Balance de Objetos, Pasivas y Arcanas — Astra Dream

Este documento es la **fuente autoritativa** de balance para todos los objetos pasivos, cartas de subida de nivel, ítems exclusivos de tienda satelital y Arcanas de **Astra Dream**.

---

## 1. Separación de Dominios: Level-Up vs Tienda Satelital

* **Subida de Nivel (`LevelUpModal` / `StatDeckManager`):**
  * Dominio exclusivo de **estadísticas planas y porcentuales directas**.
  * Oferta de exactamente **3 cartas** con impacto notable (+25% a +30% en stats principales).
  * *Prohibición de Proyectiles Planos:* Las cartas de proyectil plano universal fueron eliminadas del pool común para evitar roturas tempranas del balance.
* **Tienda del Satélite (`SatelliteShop` / `ItemPoolManager`):**
  * Dominio exclusivo de **Sobrecargas (Trade-offs)**, **Artefactos Reactivos (Procs)** y **Núcleos de Conversión**.
  * No ofrece stats planos vacíos; todo ítem del satélite confiere una mecánica diferenciada.
  * Límites estrictos de acumulación (`max_stacks`).

---

## 2. Cartas de Estadísticas al Subir de Nivel (`StatDeckManager`)

| Carta | Rareza | Bracket | Efecto Numérico Principal |
| :--- | :--- | :--- | :--- |
| **Músculo Sintético** | Común | Lv 1+ | `+25% Daño Base` |
| **Gatillo Rápido** | Común | Lv 1+ | `+20% Cadencia de Ataque` |
| **Visor Táctico** | Común | Lv 1+ | `+10% Probabilidad Crítica` |
| **Propulsor Ligero** | Común | Lv 1+ | `+25 Velocidad de Movimiento` |
| **Blindaje Básico** | Común | Lv 1+ | `+6 Armadura Plana` |
| **Nanobots Médicos** | Común | Lv 1+ | `+1.5 Regeneración de Vida/s` |
| **Núcleo de Potencia** | Rara | Lv 5+ | `+35% Daño Base` |
| **Acelerador de Partículas** | Rara | Lv 5+ | `+30% Cadencia de Ataque` |
| **Lente Focal** | Rara | Lv 5+ | `+40% Daño Crítico` |
| **Imán Gravitacional** | Rara | Lv 5+ | `+60 Radio de Recogida` |
| **Condensador de Flujo** | Rara | Lv 5+ | `+15% Reducción de Enfriamiento` |
| **Blindaje Compuesto** | Rara | Lv 5+ | `+15 Armadura Plana` |
| **Trébol Cuántico** | Rara | Lv 5+ | `+20 Suerte` |
| **Escudo de Fase** | Épica | Lv 10+ | `+60 Vida Máxima, +12 Armadura` |
| **Protocolo Berserker** | Épica | Lv 20 | `+50% Daño Crítico, +30% Cadencia` |
| **Hiperpropulsión** | Épica | Lv 20 | `+45 Vel. Movimiento, +15% Evasión` |

---

## 3. Catálogo de Ítems Exclusivos del Satélite (24 Ítems)

### A. Módulos de Sobrecarga (Trade-offs)
| ID | Nombre | Efecto Positivo | Penalización (Trade-off) | Max Stacks | Coste |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `fusion_reactor` | **Reactor de Fusión** | `+20% Daño Base` | `-15% Vida Máxima` | 2 | 60c |
| `dense_turbine` | **Turbina Densa** | `+25% Daño Base` | `-12% Cadencia de Ataque` | 2 | 65c |
| `collimator_lens` | **Lente Colimadora** | `+15% Probabilidad Crítica` | `-10% Velocidad Movimiento`| 2 | 60c |
| `split_salvo` | **Salva Dividida** | `+1 Proyectil Adicional` | `-18% Daño por Proyectil` | 1 | 75c |
| `rapid_injector` | **Inyector Rápido** | `+20% Cadencia de Ataque` | `-10% Daño Base` | 2 | 65c |
| `nanotitanium_plating`| **Revestimiento Nanotitanio**| `+3 Armadura Base` | `-12% Velocidad Movimiento`| 2 | 55c |
| `afterburn_thruster` | **Post-ignición** | `+20% Velocidad Movimiento`| `-25 px Radio Recogida` | 2 | 55c |
| `tachyon_prism` | **Prisma Taquiónico** | `+35% Daño Crítico` | `-8% Probabilidad Crítica` | 2 | 70c |

### B. Artefactos Reactivos / Proc
| ID | Nombre | Gatillo / Evento | Efecto Pasivo | Max Stacks | Coste |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `tesla_coil` | **Bobina Tesla** | Impacto Crítico | Descarga eléctrica a 3 enemigos (40% daño base, CD: 0.4s). | 2 | 80c |
| `kinetic_plating` | **Blindaje Cinético** | Recibir Daño | Onda expansiva que neutraliza balas hostiles en 90px (CD: 12s). | 1 | 75c |
| `phase_thruster` | **Propulsor de Fase** | Al usar Dash | Trampa de distorsión que ralentiza a enemigos 40% durante 2.5s. | 2 | 75c |
| `retaliation_swarm` | **Enjambre de Represalia** | Recibir Daño | Lanza 4 micromisiles guiados (35% daño c/u, CD: 6s). | 2 | 85c |
| `entropy_catalyst` | **Catalizador de Entropía** | Impacto Crítico (15%) | Vórtice gravitatorio que succiona y daña por 2s (CD: 4s). | 1 | 80c |
| `phase_inverter` | **Inversor de Fase** | Racha de 25 impactos | Barrera de invulnerabilidad de 1 impacto (CD: 15s). | 1 | 95c |
| `pyroclastic_battery`| **Batería Piroclástica** | Baja de Enemigo | Enemigo derrotado estalla en 3 esquirlas incendiarias guiadas. | 2 | 80c |
| `cryo_condenser` | **Condensador Criogénico** | Impacto de Arma (12%)| Ralentiza un 30% la velocidad enemiga por 1.5s. | 2 | 85c |

### C. Núcleos de Conversión (Alteración Mecánica)
| ID | Nombre | Conversión / Mecánica | Trade-off / Regla | Max Stacks | Coste |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `alchemical_converter`| **Convertidor Alquímico** | 15% de la EXP recogida se convierte en créditos al instante. | Progresión de niveles ligeramente menor por riqueza. | 1 | 95c |
| `hemodynamic_cell` | **Célula Hemodinámica** | +3% Daño y +2% Cadencia por cada 10% de Vida Faltante (hasta +25%). | Recompensa jugar al borde de la muerte. | 1 | 100c |
| `kinetic_converter` | **Conversor Cinético** | 25% de Velocidad de Proyectil se suma al Daño porcentual de armas. | Transforma stats de velocidad en potencia pura. | 1 | 90c |
| `gravitational_resonator`| **Resonador Gravitatorio**| Cada 25px de Radio de Recogida otorga +1 punto de Armadura efectiva. | Rango de absorción actúa como escudo pasivo. | 1 | 95c |
| `photonic_transducer`| **Transductor Fotónico** | Al hacer Dash, todas las armas disparan una salva instantánea (CD: 4s). | Transforma la evasión en una ráfaga ofensiva. | 1 | 110c |
| `overdrain_module` | **Módulo de Sobredrenaje** | Los impactos críticos curan 1 HP. | Tu Regeneración Pasiva de Vida se reduce a 0. | 1 | 115c |
| `static_cell` | **Pila de Carga Estática** | Moverse acumula carga (0-100); a 100, el próximo ataque es un crítico garantizado. | Premia reposicionamiento táctico continuo. | 1 | 105c |
| `stellar_scrap` | **Chatarra Estelar** | Al recibir daño letal, consume 100 créditos para resucitar al 30% HP (1 uso). | El saldo económico actúa como seguro de vida. | 1 | 120c |

---

## 4. Compendio de Arcanas del Destino (24 Pactos)

Las Arcanas confieren una bendición de grado mayor (**Boon**) a cambio de un sacrificio proporcional (**Curse**):

| Arcana | Cuadrante | Bendición (Boon) | Sacrificio (Curse) |
| :--- | :--- | :--- | :--- |
| **Vampiric Drain** | Abismo | `+15% Robo de Vida (Lifesteal)` | `-25% Vida Máxima` |
| **Glass Cannon** | Ascendente | `+50% Daño Total` | `-40% Armadura, -30% Vida` |
| **Phantom Evasion** | Umbral | `+25% Probabilidad de Esquivar` | `-15% Daño Base` |
| **Overcharge Reactor** | Vórtice | `+40% Cadencia de Ataque` | `+15% Enfriamiento de Habilidades` |
| **Quantum Ricochet** | Vórtice | `Tus balas rebotan en 2 enemigos extra` | `-20% Velocidad de Proyectil` |
| **Shield Sacrifice** | Umbral | `+35 Armadura Plana` | `-20 Velocidad de Movimiento` |
| **Voracious Harvest** | Ascendente | `x2 Créditos ganados de enemigos` | `Enemigos tienen +20% Vida` |
| **Time Dilation** | Umbral | `Ralentiza proyectiles enemigos un 25%` | `-15% Cadencia propia` |
| **Frenzy Trigger** | Vórtice | `+5% Daño por cada enemigo en pantalla` | `-1.0 Regen de Vida por segundo` |
| **Chaos Spark** | Caos | `+30% Probabilidad Crítica` | `Daño base varía ±35% por disparo` |
| **Iron Will** | Ascendente | `Inmune al retroceso y al empuje` | `-20% Radio de Imán` |
| **Phase Flicker** | Umbral | `1.5s invulnerable tras recibir daño` | `Enfriamiento de esquiva +50%` |
| **Dark Pact** | Abismo | `+2 Proyectiles en todas las armas` | `Pierdes 1 HP cada 2 segundos` |
| **Kinetic Converter** | Vórtice | `Correr acumula hasta +40% Daño` | `Quedarse quieto reduce daño -30%` |
| **Void Magnet** | Abismo | `Imán infinito en todo el sector` | `-15% Velocidad de Movimiento` |
| **Shrapnel Rain** | Vórtice | `Enemigos estallan en 3 metrallas` | `Enemigos son 15% más rápidos` |
| **Unstable Fission** | Caos | `Disparos se duplican al azar (35%)` | `Las balas perdidas pueden dañarte` |
| **Cursed Bounty** | Abismo | `Jefes sueltan doble botín estelar` | `Jefes tienen +35% Vida y Daño` |
| **Nova Burst** | Ascendente | `Genera una onda de choque al esquivar`| `La esquiva cuesta 10 Créditos` |
| **Solar Flare** | Ascendente | `Aura de quemadura solar permanente` | `-10 Armadura Plana` |
| **Warp Engine** | Umbral | `Teletransporte instantáneo al esquivar`| `Incapaz de curar por 3s tras usarlo` |
| **Astral Aegis** | Ascendente | `Escudo absorbe 1 impacto cada 20s` | `-15% Daño Crítico` |
| **Graviton Core** | Umbral | `Aplastamiento gravitatorio a cercanos`| `-25 Velocidad de Movimiento` |
| **Eclipse Blade** | Abismo | `Golpes críticos ejecutan enemigos al 10%`| `-20% Probabilidad Crítica Base` |
