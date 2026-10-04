# Balance de Objetos, Pasivas y Arcanas — Astra Dream

Este documento es la **fuente autoritativa** de balance para todos los objetos pasivos, cartas de subida de nivel, ítems exclusivos de tienda satelital y Arcanas de **Astra Dream**.

---

## 1. Álgebra de Daño y Separación de Contenedores (3-Bucket Architecture)

El daño de las armas y entidades se calcula mediante tres contenedores matemáticos desacoplados:
$$D_{\text{final}} = (D_{\text{base}} + D_{\text{plano}}) \cdot \max(0.0, 1.0 + \sum B_{\text{aditivo}}) \cdot \prod \max(0.0, 1.0 + M_{\text{multiplicativo}})$$

* **Contenedor 1 — Aditivo Plano ($D_{\text{plano}}$):** Cofres espaciales, mejoras base directas de armas y stats planos (`Enums.ModifierType.FLAT`).
* **Contenedor 2 — Porcentual Aditivo ($\sum B_{\text{aditivo}}$):** Subidas de nivel ordinarias (`StatDeckManager`) sujetas a rendimientos decrecientes relativos (`Enums.ModifierType.ADDITIVE_PERCENT`).
* **Contenedor 3 — Multiplicativo Puro ($\prod (1 + M_{\text{multiplicativo}})$):** Exclusivo de Módulos de Sobrecarga del Satélite, Artefactos de Conversión y Pactos Arcanos (`Enums.ModifierType.MULTIPLICATIVE`). Este factor escala de manera independiente, justificando matemáticamente las penalizaciones y riesgos implícitos.

---

## 2. Cartas de Estadísticas al Subir de Nivel (`StatDeckManager`)

Las cartas de progresión ordinaria otorgan incrementos calibrados y aditivos (entre +6% y +25% según la métrica) para evitar la inflación descontrolada:

| Carta | Rareza | Bracket | Efecto Numérico Calibrado | Tipo de Modificador |
| :--- | :--- | :--- | :--- | :---: |
| **card_dmg_1 (Músculo Sintético)** | Común | Lv 1+ | `+12% Daño Base` | `ADDITIVE_PERCENT` |
| **card_dmg_2 (Núcleo de Potencia)** | Rara | Lv 5+ | `+24% Daño Base` | `ADDITIVE_PERCENT` |
| **card_atk_spd (Gatillo Rápido)** | Común | Lv 1+ | `+10% Cadencia de Ataque` | `ADDITIVE_PERCENT` |
| **card_crit_chance (Visor Táctico)** | Común | Lv 1+ | `+6% Probabilidad Crítica` | `FLAT` |
| **card_crit_dmg (Lente Focal)** | Rara | Lv 5+ | `+30% Daño Crítico` | `ADDITIVE_PERCENT` |
| **card_hp_up (Nanobots Médicos)** | Común | Lv 1+ | `+25.0 Vida Máxima` | `FLAT` |
| **card_speed_up (Propulsor Ligero)** | Común | Lv 1+ | `+10% Velocidad de Movimiento` | `ADDITIVE_PERCENT` |
| **card_armor_1 (Blindaje Básico)** | Común | Lv 1+ | `+3.0 Armadura Plana` | `FLAT` |
| **card_armor_2 (Blindaje Reforzado)** | Rara | Lv 5+ | `+6.0 Armadura Plana` | `FLAT` |
| **card_regen_1 (Regenerador Celular)** | Común | Lv 1+ | `+0.8 Regeneración HP/s` | `FLAT` |
| **card_regen_2 (Reactor Bio-sintético)**| Rara | Lv 5+ | `+1.8 Regeneración HP/s` | `FLAT` |
| **card_magnet_1 (Imán Gravitatorio)** | Común | Lv 1+ | `+35.0 Radio de Recogida` | `FLAT` |
| **card_magnet_2 (Vórtice Magnético)** | Rara | Lv 5+ | `+70.0 Radio de Recogida` | `FLAT` |
| **card_exp_1 (Chip de Aprendizaje)** | Común | Lv 1+ | `+12% Ganancia de EXP` | `ADDITIVE_PERCENT` |
| **card_exp_2 (Algoritmo Neural)** | Rara | Lv 5+ | `+25% Ganancia de EXP` | `ADDITIVE_PERCENT` |

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

### D. Catálogo de los 12 Nuevos Ítems Estratégicos (Rework v0.6.0)

#### 1. Categoría A: Riesgo y Maldición (Curse Enablers)
| ID | Nombre | Rareza | Efecto Positivo (Multiplicativo / Plano) | Sacrificio / Maldición | Coste |
| :--- | :--- | :---: | :--- | :--- | :---: |
| `abyssal_contract` | **Pacto Abisal** | Rara | `+35% Daño Base (MULTIPLICATIVE)` | `+20 Maldición (FLAT)` (+20% mobs, +20% créditos) | 85c |
| `antimatter_core` | **Núcleo de Antimateria** | Épica | `+100% Daño Crítico` con procs masivos | `-50% Regen HP (MULTIPLICATIVE)` y `+10 Maldición` | 110c |
| `blood_capacitor` | **Capacitador Sanguíneo** | Rara | Carga de Dash acelerada y daño por ráfaga cinética | `-10% Vida Máxima (MULTIPLICATIVE)` | 80c |
| `entropy_engine` | **Motor Entrópico** | Épica | Daño escala exponencialmente por punto de Maldición | `+15 Maldición (FLAT)` | 115c |

#### 2. Categoría B: Sinergia Cruzada y Especialización
| ID | Nombre | Rareza | Efecto Táctico | Etiquetas | Coste |
| :--- | :--- | :---: | :--- | :--- | :---: |
| `bifocal_lens` | **Lente Bifocal** | Rara | Convierte daño crítico excedente en onda de choque expansiva | `offense`, `crit`, `conversion` | 80c |
| `inertial_thruster` | **Propulsor Inercial** | Poco Común | Convierte la velocidad de movimiento en daño de impacto balístico | `mobility`, `damage`, `kinetic` | 60c |
| `chain_battery` | **Batería en Cadena** | Rara | Al absorber daño con escudo, dispara arcos de relámpago en cadena | `defense`, `proc`, `shield` | 75c |
| `photonic_prism` | **Prisma Fotónico** | Poco Común | Bifurca los proyectiles energéticos en haces gemelos refractados | `offense`, `projectiles`, `bifurcation` | 65c |

#### 3. Categoría C: Manipulación Espacial y Economía
| ID | Nombre | Rareza | Efecto Táctico | Sinergia Específica | Coste |
| :--- | :--- | :---: | :--- | :--- | :---: |
| `orbital_relay` | **Repetidor Orbital** | Rara | Reduce el tiempo de despliegue satelital de 15.0s a 10.0s | Balizas satelitales en combate | 85c |
| `quantum_recompiler` | **Recompilador Cuántico** | Poco Común | Otorga +1 uso adicional a las Forjas Cuánticas (4 usos en vez de 3) | Estación de Transmutación | 60c |
| `heavy_salvager` | **Chatarrero Pesado** | Común | Abrir cápsulas de chatarra otorga permanentemente +2 Max HP y +3c | Cápsulas gratuitas | 45c |
| `chronos_bank` | **Banco de Cronos** | Rara | Genera 10% de interés sobre créditos no gastados por oleada (tope 50c) | Inversión y ahorro | 75c |

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

---

## 5. Dinámica y Balance de Monolitos Arcanos (`ArcaneMonolith`)

* **Morfología y Físicas Espaciales:**
  * **Silueta Erguida:** El monolito se presenta erguido verticalmente, a gran escala (~200px de altura), diferenciándose claramente de los meteoritos y satélites.
  * **Deriva Inercial (Drift):** Flota libremente por el cuadrante con velocidad residual lenta y rotación inercial continua.
* **Mecánica de Destrucción y Feedback Táctil:**
  * No se activa por mero contacto; requiere **impactos directos de armas** para romperse (`health = 600.0`).
  * **Feedback Visual:** Al recibir daño emite un *hit-flash* blanco de shader, sacudida física (*wobble*) y expulsión de esquirlas de energía arcana.
  * Al destruirse, libera un destello de resonancia y despliega el modal de pacto arcano (`ArcanaSelectionModal`).
* **Cadencia y Límites por Partida (Pacing):**
  * **Límite Fijo:** Máximo de **4 monolitos por run completa**, programados rítmicamente en los hitos de oleada **[3, 6, 9, 12]**.
  * **Bonus Tardío:** Probabilidad reducida del 10% de un único monolito adicional a partir de la oleada 14.
  * **Cuota Concurrente:** Solo puede haber **1 monolito activo** en el cuadrante al mismo tiempo; si el jugador no destruye el anterior, no se generará uno nuevo en el siguiente hito.
* **Claridad en la Selección de Arcanas:**
  * Las cartas del modal presentan tipografías contrastadas con separación explícita de Bendición (`Boon`, cian brillante) y Sacrificio (`Curse`, ámbar/carmesí), evitando ambigüedades en combate.
