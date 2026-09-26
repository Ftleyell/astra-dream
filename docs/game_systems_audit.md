# GUÍA Y AUDITORÍA MAESTRA DE SISTEMAS: ASTRA DREAM
**Versión del Proyecto:** 0.4.1-prealpha  
**Motor:** Godot Engine 4.7.2 Forward Mobile (Vulkan 1.4)  
**Arquitectura:** Modular, Data-Driven (.tres), Zero-Allocation Danmaku (SoA BulletServer)

---

## 1. RESUMEN EJECUTIVO Y ARQUITECTURA DEL JUEGO

**Astra Dream** es un videojuego híbrido de *Roguelite Danmaku Arena Shooter* y narrativa *Visual Novel* con dirección de arte *Psycho-Pop* / *Cyberpunk espacial*. El bucle central de jugabilidad combina la intensidad esquiva-y-disparo en tiempo real con micro-objetivos tácticos (recolección y defensa de satélites balísticos, minería de macro-objetos espaciales) y capas profundas de metajuego y progresión permanente.

### Pilares Arquitectónicos
1. **Zero-Allocation en Combate:** El servidor de balas `BulletServer` procesa miles de proyectiles hostiles en paralelo empleando memoria contigua en vectores planos SoA (`PackedFloat32Array`), eliminando por completo la instanciación de nodos `Area2D` individuales durante el combate.
2. **Cobertura Balística Dual:** Los proyectiles del `BulletServer` y las armas aliadas colisionan e interactúan de forma reactiva con los obstáculos espaciales destructibles neutros (Asteroides, Fragmentos Planetarios, Monolitos, Cápsulas, Geodas y Capullos).
3. **Data-Driven mediante Recursos Inmutables (`.tres`):** Todos los personajes, armas, arcanas e ítems se modelan mediante recursos GDScript (`CharacterData`, `WeaponData`, `ArcanaData`, `ItemData`), garantizando desacoplamiento y escalabilidad.
4. **Economía Tripartita de Recursos:**
   - **Créditos (In-Run):** Obtenidos en combate por bajas y minería; se gastan en la Tienda del Satélite (`SatelliteShop`) para comprar ítems pasivos y armas.
   - **BioMasa (Meta-Moneda de Piloto):** Obtenida al derrotar enemigos y romper objetos biológicos; se gasta en el Árbol de Habilidades Hexagonal de cada heroína en el Hub.
   - **Materia Oscura (Meta-Moneda de Maestría Global):** Obtenida de Bosses principales y núcleos planetarios; se gasta en la Sala de Trofeos 3D del Hangar para potenciar bonos pasivos permanentes globales para todas las partidas.

---

## 2. ROSTER COMPLETO DE HEROÍNAS (6 PERSONAJES)

El juego cuenta con **6 pilotos jugables** completamente diferenciadas en identidad visual, estadísticas de combate, armas iniciales, habilidades activas de esquiva (Dash con efectos únicos) y árboles de talentos.

```
                    ┌─────────────────────────┐
                    │      NOVA (Asalto)      │
                    ├─────────────────────────┤
                    │ VALENTINA (Francotirado)│
                    ├─────────────────────────┤
    HEROÍNAS        │   KIRA (Enjambre/Dron)  │
  ASTRA: DREAM      ├─────────────────────────┤
                    │   SELENE (Ocultista)    │
                    ├─────────────────────────┤
                    │   ROXY (Tanque Pesado)  │
                    ├─────────────────────────┤
                    │   ECHO (Ciber-Guerra)   │
                    └─────────────────────────┘
```

---

### 2.1. Nova — Piloto de Vanguardia
* **Identidad:** Asalto frontal a hiper-velocidad. Su reactor sobrecalienta armas térmicas aumentando el daño base a quemarropa.
* **Color Temático:** Cian Neón (`#1AE6FF`).
* **Arma Inicial:** *Rail Launcher* (`data/weapons/roster/rail_launcher.tres`).
* **Atributos Base:**
  - **Salud Máxima:** 100 HP | **Regeneración:** 0.5 HP/s | **Armadura:** 0
  - **Velocidad de Movimiento:** 340 px/s
  - **Daño Base:** 40.0 | **Cadencia de Ataque:** 1.0x | **Prob. Crítica:** 5% | **Daño Crítico:** 1.5x
  - **Suerte:** 0 | **Radio de Recogida:** 110 px | **Proyectiles:** 2 | **Vel. Proyectil:** 1.0x
* **Esquiva Activa (Dash):** *Fire Trail Dash*. Cuenta con 2 cargas de regeneración rápida que proyectan un rastro de partículas térmicas y fuego en la dirección apuntada.
* **Restricciones de Banlist:** Etiquetas vetadas: `[&"slow", &"heavy"]`.

---

### 2.2. Valentina — Francotiradora Táctica
* **Identidad:** Calculista orbital de precisión quirúrgica. Sus lásers de telemetría perforan blindajes con un multiplicador de daño crítico masivo.
* **Color Temático:** Carmesí / Rosa Táctico (`#FF5966`).
* **Arma Inicial:** *Sniper Rifle* (`data/weapons/roster/sniper_rifle.tres`).
* **Atributos Base:**
  - **Salud Máxima:** 85 HP | **Regeneración:** 0.3 HP/s | **Armadura:** 0
  - **Velocidad de Movimiento:** 300 px/s
  - **Daño Base:** 55.0 | **Cadencia de Ataque:** 0.8x | **Prob. Crítica:** 18% | **Daño Crítico:** 2.2x
  - **Suerte:** +5 | **Radio de Recogida:** 95 px | **Proyectiles:** 1 | **Vel. Proyectil:** 1.6x
* **Esquiva Activa (Dash):** *Sniper Charge Dash*. Impulso lineal de alta aceleración que incrementa la probabilidad crítica del siguiente disparo al 100%.
* **Restricciones de Banlist:** Etiquetas vetadas: `[&"spread", &"shotgun"]`.

---

### 2.3. Kira — Ingeniera de Enjambre
* **Identidad:** Especialista en nanobots y munición de racimo automática. Su cadencia pasiva de misiles guiados y drones satélites es un 35% más veloz.
* **Color Temático:** Amarillo Ámbar Neón (`#FFCC1A`).
* **Arma Inicial:** *Hive Cannon* (`data/weapons/roster/hive_cannon.tres`).
* **Atributos Base:**
  - **Salud Máxima:** 90 HP | **Regeneración:** 0.4 HP/s | **Armadura:** 0
  - **Velocidad de Movimiento:** 310 px/s
  - **Daño Base:** 35.0 | **Cadencia de Ataque:** 1.35x | **Prob. Crítica:** 8% | **Daño Crítico:** 1.4x
  - **Suerte:** +12 | **Radio de Recogida:** 120 px | **Proyectiles:** 3 | **Vel. Proyectil:** 0.9x
* **Esquiva Activa (Dash):** *Drone Decoy Dash*. Deja un señuelo holográfico en la posición inicial que atrae temporalmente la atención de los proyectiles y esbirros enemigos.
* **Restricciones de Banlist:** Etiquetas vetadas: `[&"melee", &"single_target"]`.

---

### 2.4. Selene — Ocultista del Vacío
* **Identidad:** Canaliza anomalías de gravedad negativa. Ralentiza los proyectiles enemigos en su proximidad y posee el doble de radio de aspiración de EXP.
* **Color Temático:** Púrpura Astral (`#BF66FF`).
* **Arma Inicial:** *Singularity Pulsar* (`data/weapons/roster/singularity_pulsar.tres`).
* **Atributos Base:**
  - **Salud Máxima:** 110 HP | **Regeneración:** 0.6 HP/s | **Armadura:** 1
  - **Velocidad de Movimiento:** 290 px/s
  - **Daño Base:** 38.0 | **Cadencia de Ataque:** 0.95x | **Prob. Crítica:** 6% | **Daño Crítico:** 1.5x
  - **Suerte:** +20 | **Radio de Recogida:** 200 px (Doble radio base) | **Proyectiles:** 1 | **Vel. Proyectil:** 0.85x
* **Esquiva Activa (Dash):** *Black Hole Phase Dash*. Teletransporte de fase instantáneo que genera un vórtice de implosión en el punto de llegada, atrayendo orbes de EXP y fragmentos.
* **Restricciones de Banlist:** Etiquetas vetadas: `[&"kinetic", &"physical"]`.

---

### 2.5. Roxanne (Roxy) — Especialista Pesada
* **Identidad:** Blindaje de casco reforzado y escopeta sísmica de metralla. Comienza con escudo cinético pasivo que absorbe impactos directos.
* **Color Temático:** Verde Esmeralda Tóxico (`#33F280`).
* **Arma Inicial:** *Titan Shotgun* (`data/weapons/roster/titan_shotgun.tres`).
* **Atributos Base:**
  - **Salud Máxima:** 150 HP | **Regeneración:** 0.8 HP/s | **Armadura:** 4 (Mitigación pasiva)
  - **Velocidad de Movimiento:** 260 px/s
  - **Daño Base:** 48.0 | **Cadencia de Ataque:** 0.85x | **Prob. Crítica:** 4% | **Daño Crítico:** 1.6x
  - **Suerte:** -5 | **Radio de Recogida:** 90 px | **Proyectiles:** 5 (Perdigones) | **Vel. Proyectil:** 1.1x
* **Esquiva Activa (Dash):** *Seismic Barrier Dash*. Placaje frontal con barrera cinética que desvía proyectiles hostiles menores y empuja bruscamente a los enemigos circundantes.
* **Restricciones de Banlist:** Etiquetas vetadas: `[&"fragile", &"evasion"]`.

---

### 2.6. Echo — Androide de Ciber-Guerra
* **Identidad:** Inyecta virus de latencia cuántica que encadenan arcos eléctricos y procs infinitos entre grupos densos de enemigos.
* **Color Temático:** Azul Glitch Neón (`#80D9FF`).
* **Arma Inicial:** *Tesla Arc* (`data/weapons/roster/tesla_arc.tres`).
* **Atributos Base:**
  - **Salud Máxima:** 80 HP | **Regeneración:** 0.2 HP/s | **Armadura:** 0
  - **Velocidad de Movimiento:** 360 px/s (La más veloz del elenco)
  - **Daño Base:** 42.0 | **Cadencia de Ataque:** 1.2x | **Prob. Crítica:** 12% | **Daño Crítico:** 1.7x
  - **Suerte:** +10 | **Radio de Recogida:** 105 px | **Proyectiles:** 2 | **Vel. Proyectil:** 1.25x
* **Esquiva Activa (Dash):** *Quantum Glitch Dash*. Parpadeo de micro-teletransporte con cuadros de invulnerabilidad ampliados y descarga de interferencia EMP radial.
* **Restricciones de Banlist:** Etiquetas vetadas: `[&"organic", &"ballistic"]`.

---

### 2.7. Tabla Comparativa de Heroínas

| Heroína | HP Base | Regen | Vel. (px/s) | Armadura | Daño Base | Cadencia | Crítico % | Crítico Mult. | Suerte | Radio Imán | Arma Inicial |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Nova** | 100 | 0.5 | 340 | 0 | 40.0 | 1.0x | 5% | 1.5x | 0 | 110 px | Rail Launcher |
| **Valentina** | 85 | 0.3 | 300 | 0 | 55.0 | 0.8x | 18% | 2.2x | +5 | 95 px | Sniper Rifle |
| **Kira** | 90 | 0.4 | 310 | 0 | 35.0 | 1.35x | 8% | 1.4x | +12 | 120 px | Hive Cannon |
| **Selene** | 110 | 0.6 | 290 | 1 | 38.0 | 0.95x | 6% | 1.5x | +20 | 200 px | Singularity Pulsar |
| **Roxy** | 150 | 0.8 | 260 | 4 | 48.0 | 0.85x | 4% | 1.6x | -5 | 90 px | Titan Shotgun |
| **Echo** | 80 | 0.2 | 360 | 0 | 42.0 | 1.2x | 12% | 1.7x | +10 | 105 px | Tesla Arc |

---

### 2.8. Árbol de Habilidades Hexagonal (Constelación Radial)
Cada heroína cuenta en el Hangar del Hub con su propio Árbol de Habilidades interactivo (`CharacterSkillTreeModal`), estructurado en una constelación de **13 nodos** (1 Núcleo de origen + 4 ramas cardinales de 3 nodos cada una):

```
                     [SPEED 3 (+60%)]
                            │
                     [SPEED 2 (+40%)]
                            │
                     [SPEED 1 (+20%)]
                            │
 [CRIT 3] ── [CRIT 2] ── [CRIT 1] ── [CORE] ── [DMG 1] ── [DMG 2] ── [DMG 3 (+45%)]
                            │
                      [HP 1 (+25)]
                            │
                      [HP 2 (+50)]
                            │
                      [HP 3 (+75)]
```

* **Coste por Nodo:** 25 unidades de BioMasa persistente.
* **Coste de Maestría Completa:** 300 unidades de BioMasa por personaje (12 mejoras x 25).
* **Ramas y Efectos Acumulados:**
  1. **Rama Norte — Velocidad (`speed_1`, `speed_2`, `speed_3`):** +20% / +40% / +60% Velocidad de Movimiento permanente en combate.
  2. **Rama Este — Daño (`damage_1`, `damage_2`, `damage_3`):** +15% / +30% / +45% Daño General infligido permanente en combate.
  3. **Rama Sur — Supervivencia (`hp_1`, `hp_2`, `hp_3`):** +25 HP / +50 HP / +75 HP Máximo permanente en combate.
  4. **Rama Oeste — Utilidad y Crítico (`crit_1`, `crit_2`, `crit_3`):** +5% Crítico & +5% Cadencia / +10% & +10% / +15% & +15% permanente.

---

## 3. CATÁLOGO MAESTRO DE ARMAS (10 ARMAS)

El arsenal de *Astra Dream* consta de **10 armas especializadas**, divididas entre las 6 armas distintivas de las heroínas y 4 armas pesadas de adquisición táctica en la Tienda del Satélite.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ARSENAL MAESTRO (10 ARMAS)                      │
├──────────────────────────────────┬─────────────────────────────────────┤
│     ARMAS DISTINTIVAS (ROSTER)   │     ARMAS DE TIENDA (SATÉLITE)      │
├──────────────────────────────────┼─────────────────────────────────────┤
│ 1. Rail Launcher (Nova)          │ 7. Cluster Submunition              │
│ 2. Sniper Rifle (Valentina)      │ 8. Dimensional Blade                │
│ 3. Hive Cannon (Kira)            │ 9. Nova Flak                        │
│ 4. Singularity Pulsar (Selene)   │ 10. Solar Beam                      │
│ 5. Titan Shotgun (Roxy)          │                                     │
│ 6. Tesla Arc (Echo)              │                                     │
└──────────────────────────────────┴─────────────────────────────────────┘
```

### 3.1. Detalle Técnico de Armas
1. **Rail Launcher (`rail_launcher.tres`):**
   - *Tipo:* Proyectil cinético acelerado por riel electromagnético.
   - *Daño Base:* 35.0 | *Cadencia:* 1.1s | *Velocidad:* 750 px/s | *Perforación:* 2 enemigos.
   - *Comportamiento:* Trayectoria lineal recta con alta velocidad inicial y estela de plasma.
2. **Sniper Rifle (`sniper_rifle.tres`):**
   - *Tipo:* Rayo concentrado de telemetría de largo alcance.
   - *Daño Base:* 70.0 | *Cadencia:* 1.8s | *Velocidad:* 1400 px/s | *Perforación:* 4 enemigos.
   - *Comportamiento:* Proyectil casi instantáneo con probabilidad de crítico incrementada (+15%).
3. **Hive Cannon (`hive_cannon.tres`):**
   - *Tipo:* Lanzador de micro-misiles bio-mecánicos con guiado autónomo.
   - *Daño Base:* 18.0 x 3 misiles | *Cadencia:* 0.9s | *Velocidad:* 450 px/s | *Perforación:* 0 (Explosivo).
   - *Comportamiento:* Los proyectiles rastrean al enemigo más cercano con corrección angular dinámica.
4. **Singularity Pulsar (`singularity_pulsar.tres`):**
   - *Tipo:* Esfera de distorsión gravitatoria.
   - *Daño Base:* 28.0 | *Cadencia:* 1.4s | *Velocidad:* 320 px/s | *Perforación:* Infinita (duración 2.5s).
   - *Comportamiento:* Pulsa daño por segundo a todos los enemigos en su radio mientras los arrastra lentamente.
5. **Titan Shotgun (`titan_shotgun.tres`):**
   - *Tipo:* Cañón sísmico de dispersión múltiple.
   - *Daño Base:* 14.0 x 5 perdigones | *Cadencia:* 1.2s | *Velocidad:* 600 px/s | *Perforación:* 1.
   - *Comportamiento:* Cono frontal amplio con dispersión angular de 45° y retroceso inercial en el usuario.
6. **Tesla Arc (`tesla_arc.tres`):**
   - *Tipo:* Descarga eléctrica voltaica encadenada.
   - *Daño Base:* 24.0 | *Cadencia:* 0.75s | *Velocidad:* Instantánea | *Cadenas:* 3 saltos.
   - *Comportamiento:* Salta entre enemigos adyacentes a menos de 180 px reduciendo un 15% el daño por salto.
7. **Cluster Submunition (`cluster_submunition.tres`):**
   - *Tipo:* Granada orbital de fragmentación.
   - *Daño Base:* 45.0 (Impacto) + 15.0 x 6 (Submuniciones) | *Cadencia:* 2.0s | *Coste Tienda:* 70 créditos.
   - *Comportamiento:* Vuela hacia la posición fijada y detona liberando un anillo de 6 micro-bombas cinéticas.
8. **Dimensional Blade (`dimensional_blade.tres`):**
   - *Tipo:* Proyectil de corte dimensional a corta distancia.
   - *Daño Base:* 50.0 | *Cadencia:* 0.65s | *Velocidad:* 500 px/s | *Coste Tienda:* 75 créditos.
   - *Comportamiento:* Onda creciente de plasma con hitbox ancha que destruye balas hostiles a su paso.
9. **Nova Flak (`nova_flak.tres`):**
   - *Tipo:* Artillería antiaérea espacial de detonación retardada.
   - *Daño Base:* 60.0 en área (radio 90 px) | *Cadencia:* 1.6s | *Coste Tienda:* 80 créditos.
   - *Comportamiento:* Explota tras recorrer 350 px o al entrar en contacto con una masa densa.
10. **Solar Beam (`solar_beam.tres`):**
    - *Tipo:* Haz continuo sostenido de energía solar concentrada.
    - *Daño Base:* 90.0 DPS (ticks cada 0.1s) | *Cadencia:* Canalización continua | *Coste Tienda:* 95 créditos.
    - *Comportamiento:* Haz continuo que sigue la orientación de la nave derritiendo armaduras pesadas.

---

## 4. CATÁLOGO DE ÍTEMS PASIVOS Y CONSUMIBLES DE CAMPO

El sistema de ítems opera bajo el gestor de inventario `ItemPoolManager` e interactúa con la `SatelliteShop` durante las pausas de abastecimiento.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CATÁLOGO DE 12 ÍTEMS CANÓNICOS                       │
├──────────────────┬─────────────────┬───────────────────┬───────────────┤
│ Ítem             │ Efecto          │ Rareza / Coste    │ Etiquetas     │
├──────────────────┼─────────────────┼───────────────────┼───────────────┤
│ Botas            │ +10% Move Speed │ Común (35 cr.)    │ mobility      │
│ Espada           │ +5 Daño Base    │ Común (35 cr.)    │ offense, dmg  │
│ Escudo           │ +2 Armadura     │ Común (35 cr.)    │ defense, arm  │
│ Corazón          │ +20 Vida Máxima │ Común (35 cr.)    │ sustain, hp   │
│ Manzana          │ +0.5 Regen/s    │ Común (35 cr.)    │ sustain, reg  │
│ Imán             │ +35 px Radio    │ Común (35 cr.)    │ utility, mag  │
│ Gafas            │ +7% Crítico     │ Poco Común (55 cr)│ offense, crit │
│ Lupa             │ +30% Daño Crít. │ Poco Común (55 cr)│ offense, crit │
│ Guante           │ +12% Atk Speed  │ Poco Común (55 cr)│ offense, spd  │
│ Trébol           │ +20% Suerte     │ Poco Común (55 cr)│ utility, luck │
│ Carcaj           │ +1 Proyectil    │ Rara (90 cr.)     │ projectiles   │
│ Chip Telemetría  │ +20% EXP Ganada │ Poco Común (45 cr)│ utility, exp  │
└──────────────────┴─────────────────┴───────────────────┴───────────────┘
```

### Consumibles Tácticos de Campo (`FieldConsumable`)
Soltados por cápsulas de suministros militares y recompensas de oleada:
1. **Nanobots de Reparación (Heal):** Restaura inmediatamente el 30% de la salud máxima de la nave.
2. **Barrera de Vacío / Recarga de Bomba (Shield/Bomb):** Restaura 1 carga de Bomba de pantalla completa y otorga 2 segundos de invulnerabilidad cinética.
3. **Pulso Gravitatorio (Magnet):** Absorbe instantáneamente todos los orbes de EXP, BioMasa y Materia Oscura esparcidos por el mapa hacia la posición del jugador.

---

## 5. ECOSISTEMA DE DESTRUCTIBLES Y COBERTURA BALÍSTICA

Astra Dream cuenta con un ecosistema de **7 entidades destructibles espaciales** que actúan como cobertura física tanto para el jugador como para los enemigos, alterando dinámicamente la balística de combate.

```
                    ┌─────────────────────────┐
                    │       ASTEROIDES        │
                    ├─────────────────────────┤
                    │   ANILLOS PLANETARIOS   │
                    ├─────────────────────────┤
    ECOSISTEMA      │    MONOLITO ARCANO      │
   DESTRUCTIBLE     ├─────────────────────────┤
   (COBERTURA)      │  CÁPSULA DE SUMINISTRO  │
                    ├─────────────────────────┤
                    │   GEODA CUARZO ASTRAL   │
                    ├─────────────────────────┤
                    │   CAPULLO BIOMECÁNICO   │
                    ├─────────────────────────┤
                    │   ESQUIRLAS CINÉTICAS   │
                    └─────────────────────────┘
```

1. **Asteroides (`asteroid.gd`):**
   - *Tiers:* 1 (Pequeño, 40 HP), 2 (Medio, 80 HP), 3 (Grande, 140 HP).
   - *Mecánica:* Absorben balas del `BulletServer`. Al destruirse emiten la señal `shattered(pos, tier)` y se fragmentan en 4-6 esquirlas cinéticas balísticas.
2. **Anillos Planetarios (`planet_segment.gd` & `planet_core.gd`):**
   - *Biomas:* Planeta Verde (Biosfera), Planeta Volcánico (Magma) y Planeta Criogénico (Hielo).
   - *Estructura:* Macro-entidades compuestas por capas geológicas destructibles concéntricas (Corteza y Manto) con colisionadores poligonales curvos.
   - *Núcleo Digitalizable:* Al destruir las capas protectoras, el núcleo queda expuesto y puede digitalizarse con la tecla `[E]`, otorgando abundantes créditos, BioMasa, orbes de Materia Oscura y desbloqueando el trofeo planetario correspondiente en la Sala de Trofeos.
3. **Monolito Arcano-Tecnológico (`arcane_monolith.gd`):**
   - *Salud:* 150 HP | *Tier:* 2 | *Radio de Cobertura:* 44 px.
   - *Mecánica:* Reliquia rúnica pulsante. Al ser destruida por disparos aliados o fuego cruzado, libera un **ArcanaOrb** que detona la invocación de pactos de alto riesgo/recompensa. Desbloquea `trophy_monolith_master`.
4. **Cápsula de Suministros Militares (`supply_pod.gd`):**
   - *Salud:* 220 HP | *Armadura Plana:* 3.0 (mitiga 3 puntos de todo daño entrante).
   - *Mecánica:* Contenedor táctico de supervivencia. Al destruirse suelta consumibles garantizados (Heal, Bomb Recharge o Magnet).
5. **Geoda de Cuarzo Astral (`astral_geode.gd`):**
   - *Salud:* 300 HP | *Radio Prismático:* 85 px.
   - *Mecánica:* **Prisma Refractor:** Todo proyectil aliado que atraviesa la geoda ve su **daño incrementado en un +50%**, su tamaño aumentado en un +50% y convierte el impacto resultante en golpe crítico garantizado. Al quebrarse estalla en esquirlas prismáticas de Tier 3.
6. **Capullo Biomecánico (`bio_cocoon.gd`):**
   - *Salud:* 180 HP | *Ritmo de Desove:* Cada 5 segundos.
   - *Mecánica:* Colmena orgánica que engendra esbirros kamikaze (máx. 3 activos). Al ser destruido produce una **detonación en cadena biológica**, eliminando instantáneamente a todos los esbirros que engendró y soltando BioMasa.
7. **Esquirlas Cinéticas (`shrapnel_shard.gd`):**
   - *Mecánica:* Proyectiles balísticos secundarios expulsados al fracturarse cualquier destructible.
   - *Daño:* Escalado según el nivel del objeto: `D = max(15.0, tier * 20.0)` (Tier 1: 20 dmg, Tier 2: 40 dmg, Tier 3: 60 dmg). Aplican knockback físico de 360 px/s a los enemigos impactados.
8. **Generador Dinámico Periférico (`SpaceObjectSpawner`):**
   - *Inyección Continua:* Genera macro-objetos en la periferia de navegación del jugador (radio 1000-1350 px), proyectando su posición hacia el vector de velocidad del piloto.
   - *Garantía por Oleada:* Invocación forzosa asegurada de al menos un Monolito Arcano al iniciar la partida y en cada transición de oleada (`force_spawn_monolith()`).
   - *Respawn Dinámico de Monolitos (45s):* Si en cualquier momento hay 0 monolitos activos en el espacio (`get_active_monolith_count() == 0`), un temporizador genera automáticamente uno nuevo en la trayectoria de vuelo.
   - *Separación Estricta de Cupos:* Cuota independiente y prioritaria para Monolitos (`max_active_monoliths = 2`), garantizando que la acumulación pasiva de cápsulas, geodas o capullos nunca asfixie la aparición de Arcanas.
   - *Filtrado de Nodos en Muerte:* Exclusión instantánea de entidades en proceso de destrucción (`is_dying` o `is_queued_for_deletion()`) para un recálculo determinista de cupos libres.

---

## 6. GRIMORIO COMPLETO DE LAS 24 ARCANAS (PACTOS MÍSTICOS)

Las Arcanas son cartas cuánticas de **Alto Riesgo y Alta Recompensa** implementadas mediante el recurso `ArcanaData` (`data/arcanas/arcana_data.gd`) y almacenadas en `data/arcanas/roster/`. Se manifiestan en combate al destruir un Monolito Arcano y recolectar el **ArcanaOrb** violeta.
Al recoger el orbe, el juego entra en pausa táctica y el modal `ArcanaSelectionModal` despliega **3 cartas seleccionadas aleatoriamente** de entre las no adquiridas. Cada arcana inyecta modificadores en el sistema reactivo `CharacterStats`, aplicando tanto un **Bono Divino** masivo como una **Maldición Devastadora**.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          GRIMORIO DE ARCANAS (24 CARTAS)                         │
├─────────────────────────┬──────────────────────────┬─────────────┬───────────────┤
│ Cuadrante               │ Enfoque Táctico          │ Cantidad    │ Color Acento  │
├─────────────────────────┼──────────────────────────┼─────────────┼───────────────┤
│ 1. Glass Cannon         │ Cañón de Cristal y Sangre│ 6 Arcanas   │ Carmesí       │
│ 2. Danmaku Chaos        │ Caos Balístico y Ráfagas │ 6 Arcanas   │ Cian Eléctrico│
│ 3. Spacetime            │ Espacio-Tiempo y Evasión │ 6 Arcanas   │ Violeta Vacío │
│ 4. Greed                │ Avaricia y Sobrecarga    │ 6 Arcanas   │ Dorado Midas  │
└─────────────────────────┴──────────────────────────┴─────────────┴───────────────┘
```

---

### 6.1. Cuadrante 1: Cañón de Cristal & Sangre (`glass_cannon`)
Enfocado en potenciar agresivamente el daño, cadencia y críticos a costa de sacrificar vida máxima, regeneración o armadura. Ideal para builds de alta destreza y evasión perfecta.

#### 1. Furia Agónica (`agonic_fury.tres`)
* **ID Interno:** `agonic_fury` | **Cuadrante:** `glass_cannon`
* **Bono:** +50% Cadencia de disparo ultra-rápida.
* **Maldición:** -50% Regeneración de salud por segundo.
* **Modificadores GDScript (`stat_modifiers`):**
  - `attack_speed_pct`: `+0.50` (+50% velocidad de ataque y cadencia).
  - `health_regen_pct`: `-0.50` (-50% regeneración continua de vida).
* **Impacto Táctico:** Duplica casi la saturación de fuego de armas pesadas como el *Rail Launcher* o *Titan Shotgun*, penalizando el sustento pasivo.

#### 2. Pacto de Sangre (`blood_pact.tres`)
* **ID Interno:** `blood_pact` | **Cuadrante:** `glass_cannon`
* **Bono:** +60% Daño base a todas las armas.
* **Maldición:** -35% Vida máxima del chasis.
* **Modificadores GDScript (`stat_modifiers`):**
  - `base_damage_pct`: `+0.60` (+60% daño base en todas las fuentes ofensivas).
  - `max_health_pct`: `-0.35` (-35% capacidad máxima de salud, clampeando la salud actual si excede el nuevo tope).
* **Impacto Táctico:** Eleva radicalmente el DPS por impacto; requiere extrema precaución ante proyectiles densos de jefes.

#### 3. Drenaje Vampírico (`vampiric_drain.tres`)
* **ID Interno:** `vampiric_drain` | **Cuadrante:** `glass_cannon`
* **Bono:** +4.0 Regeneración masiva de vida continua.
* **Maldición:** -20% Velocidad de desplazamiento.
* **Modificadores GDScript (`stat_modifiers`):**
  - `health_regen`: `+4.0` (+4.0 HP planos regenerados por segundo).
  - `move_speed_pct`: `-0.20` (-20% velocidad de traslación de la nave).
* **Impacto Táctico:** Otorga casi invulnerabilidad contra desgaste continuo o roces danmaku a cambio de volver la nave más lenta al posicionarse.

#### 4. Sed de Núcleo (`core_thirst.tres`)
* **ID Interno:** `core_thirst` | **Cuadrante:** `glass_cannon`
* **Bono:** +40% Daño base y +30% Tamaño de proyectiles.
* **Maldición:** -30% Radio magnético de recogida de EXP.
* **Modificadores GDScript (`stat_modifiers`):**
  - `base_damage_pct`: `+0.40` (+40% daño base).
  - `weapon_size_pct`: `+0.30` (+30% escala visual y radio de colisión de balas).
  - `pickup_radius_pct`: `-0.30` (-30% radio de atracción de orbes).
* **Impacto Táctico:** Incrementa el volumen del hitbox de las armas, facilitando impactos múltiples a costa de forzar al piloto a acercarse más a los orbes.

#### 5. Último Aliento (`last_breath.tres`)
* **ID Interno:** `last_breath` | **Cuadrante:** `glass_cannon`
* **Bono:** +45% Daño base y +20% Reducción de enfriamiento.
* **Maldición:** -40% Vida máxima total.
* **Modificadores GDScript (`stat_modifiers`):**
  - `base_damage_pct`: `+0.45` (+45% daño base).
  - `cooldown_reduction`: `+0.20` (+20% reducción de enfriamiento en armas y dashes).
  - `max_health_pct`: `-0.40` (-40% vida máxima del chasis).
* **Impacto Táctico:** Convierte a la nave en un auténtico cañón de cristal con recargas ultra veloces de habilidades activas.

#### 6. Sacrificio de Escudo (`shield_sacrifice.tres`)
* **ID Interno:** `shield_sacrifice` | **Cuadrante:** `glass_cannon`
* **Bono:** +25% Probabilidad crítica y +0.50x Daño crítico.
* **Maldición:** -8 Armadura de protección reactiva.
* **Modificadores GDScript (`stat_modifiers`):**
  - `crit_chance`: `+0.25` (+25% probabilidad crítica plana).
  - `crit_damage`: `+0.50` (+0.50x multiplicador de impacto crítico).
  - `armor`: `-8.0` (-8 armadura plana, aumentando el daño neto recibido de cada impacto).
* **Impacto Táctico:** Sinergia destructiva combinada con pilotos como Valentina, permitiendo críticos garantizados superiores a 3.0x de daño.

---

### 6.2. Cuadrante 2: Danmaku & Caos Balístico (`danmaku_chaos`)
Especializado en alterar la física de los proyectiles aliados: número de balas, dispersión, escala colosal, perforación y rebotes en la arena.

#### 7. Proyectil Colosal (`colossal_projectile.tres`)
* **ID Interno:** `colossal_projectile` | **Cuadrante:** `danmaku_chaos`
* **Bono:** +100% Tamaño colosal de proyectiles y +35% Daño.
* **Maldición:** -40% Velocidad de desplazamiento de balas.
* **Modificadores GDScript (`stat_modifiers`):**
  - `weapon_size_pct`: `+1.00` (+100% tamaño, duplicando diámetro de colisión de proyectiles).
  - `base_damage_pct`: `+0.35` (+35% daño base).
  - `projectile_speed_pct`: `-0.40` (-40% velocidad balística).
* **Impacto Táctico:** Las balas se convierten en gigantescas barreras de energía lentas pero devastadoras que limpian hordas enteras.

#### 8. Fisión Inestable (`unstable_fission.tres`)
* **ID Interno:** `unstable_fission` | **Cuadrante:** `danmaku_chaos`
* **Bono:** +2 Proyectiles y +20% Probabilidad crítica.
* **Maldición:** -25% Cadencia de disparo.
* **Modificadores GDScript (`stat_modifiers`):**
  - `projectile_count`: `+2.0` (+2 proyectiles adicionales por andanada).
  - `crit_chance`: `+0.20` (+20% probabilidad crítica plana).
  - `attack_speed_pct`: `-0.25` (-25% cadencia de disparo).
* **Impacto Táctico:** Otorga disparos múltiples con alto índice crítico compensando el retraso entre salvas.

#### 9. Lluvia de Metralla (`shrapnel_rain.tres`)
* **ID Interno:** `shrapnel_rain` | **Cuadrante:** `danmaku_chaos`
* **Bono:** +3 Proyectiles adicionales en cada disparo.
* **Maldición:** -30% Daño de cada bala individual.
* **Modificadores GDScript (`stat_modifiers`):**
  - `projectile_count`: `+3.0` (+3 proyectiles adicionales).
  - `base_damage_pct`: `-0.30` (-30% daño base por disparo).
* **Impacto Táctico:** Saturación de pantalla absoluta. Aunque cada bala hace menos daño individual, el daño total por ráfaga aumenta drásticamente si impactan varias.

#### 10. Balística Pesada (`heavy_ballistics.tres`)
* **ID Interno:** `heavy_ballistics` | **Cuadrante:** `danmaku_chaos`
* **Bono:** +50% Daño devastador y +6 Armadura frontal.
* **Maldición:** -25% Velocidad de maniobra y giro.
* **Modificadores GDScript (`stat_modifiers`):**
  - `base_damage_pct`: `+0.50` (+50% daño base).
  - `armor`: `+6.0` (+6 armadura plana para mitigación física).
  - `move_speed_pct`: `-0.25` (-25% velocidad de movimiento).
* **Impacto Táctico:** Transforma a la nave en una fortaleza volante pesada con capacidad de aguantar colisiones accidentales con asteroides.

#### 11. Rebote Cuántico (`quantum_ricochet.tres`)
* **ID Interno:** `quantum_ricochet` | **Cuadrante:** `danmaku_chaos`
* **Bono:** +40% Velocidad de proyectil e hiper-penetración.
* **Maldición:** -15% Daño base de proyectiles.
* **Modificadores GDScript (`stat_modifiers`):**
  - `projectile_speed_pct`: `+0.40` (+40% velocidad balística).
  - `base_damage_pct`: `-0.15` (-15% daño base).
* **Impacto Táctico:** Balas a hiper-velocidad que cruzan la pantalla de inmediato y castigan a enemigos lejanos antes de que puedan desplegar danmaku.

#### 12. Espejo Danmaku (`danmaku_mirror.tres`)
* **ID Interno:** `danmaku_mirror` | **Cuadrante:** `danmaku_chaos`
* **Bono:** +4 Proyectiles en abanico y +30% Cadencia de fuego.
* **Maldición:** -50% Tamaño de proyectil y -20% Daño base.
* **Modificadores GDScript (`stat_modifiers`):**
  - `projectile_count`: `+4.0` (+4 proyectiles en abanico disperso).
  - `attack_speed_pct`: `+0.30` (+30% cadencia de disparo).
  - `weapon_size_pct`: `-0.50` (-50% tamaño del proyectil).
  - `base_damage_pct`: `-0.20` (-20% daño base).
* **Impacto Táctico:** Crea un patrón de micro-balas danmaku aliado ultra denso que emula los ataques radiales de los jefes del juego.

---

### 6.3. Cuadrante 3: Espacio-Tiempo & Evasión (`spacetime`)
Manipulación de las constantes físicas del espacio: dilatación de cooldowns, aceleración de maniobra y gravedad de absorción de recursos.

#### 13. Dilatación Temporal (`time_dilation.tres`)
* **ID Interno:** `time_dilation` | **Cuadrante:** `spacetime`
* **Bono:** +40% Aceleración de recargas y +15% Crítico.
* **Maldición:** -20% Velocidad lineal de proyectiles.
* **Modificadores GDScript (`stat_modifiers`):**
  - `cooldown_reduction`: `+0.40` (+40% reducción de enfriamiento en todas las habilidades y armas).
  - `crit_chance`: `+0.15` (+15% probabilidad crítica).
  - `projectile_speed_pct`: `-0.20` (-20% velocidad lineal de proyectil).
* **Impacto Táctico:** Maximiza la frecuencia de uso del Dash y el spam de armas activas a costa de requerir mayor anticipación al apuntar.

#### 14. Motor de Curvatura (`warp_engine.tres`)
* **ID Interno:** `warp_engine` | **Cuadrante:** `spacetime`
* **Bono:** +60% Velocidad extrema de traslación estelar.
* **Maldición:** -50% Radio magnético de captación.
* **Modificadores GDScript (`stat_modifiers`):**
  - `move_speed_pct`: `+0.60` (+60% velocidad de movimiento).
  - `pickup_radius_pct`: `-0.50` (-50% radio de atracción magnética).
* **Impacto Táctico:** Hiper-maniobrabilidad para cruzar campos de balas cerrados o alcanzar satélites lejanos en segundos.

#### 15. Salto Dimensional (`dimensional_leap.tres`)
* **ID Interno:** `dimensional_leap` | **Cuadrante:** `spacetime`
* **Bono:** +45% Velocidad de maniobra y +35% Recarga de dash.
* **Maldición:** -20% Resistencia e integridad de casco (Max HP).
* **Modificadores GDScript (`stat_modifiers`):**
  - `move_speed_pct`: `+0.45` (+45% velocidad de movimiento).
  - `cooldown_reduction`: `+0.35` (+35% recarga de dash).
  - `max_health_pct`: `-0.20` (-20% salud máxima).
* **Impacto Táctico:** Permite encadenar dashes de evasión de forma casi ininterrumpida.

#### 16. Evasión Fantasma (`phantom_evasion.tres`)
* **ID Interno:** `phantom_evasion` | **Cuadrante:** `spacetime`
* **Bono:** +10 Armadura espectral y +25% Velocidad.
* **Maldición:** -20% Daño infligido por armas.
* **Modificadores GDScript (`stat_modifiers`):**
  - `armor`: `+10.0` (+10 armadura plana).
  - `move_speed_pct`: `+0.25` (+25% velocidad de movimiento).
  - `base_damage_pct`: `-0.20` (-20% daño base).
* **Impacto Táctico:** Aumenta de forma drástica la capacidad de absorción de impactos y la supervivencia pasiva.

#### 17. Parpadeo de Fase (`phase_flicker.tres`)
* **ID Interno:** `phase_flicker` | **Cuadrante:** `spacetime`
* **Bono:** +30% Velocidad y +20% Cadencia con micro-saltos cuánticos.
* **Maldición:** -25% Capacidad máxima de salud.
* **Modificadores GDScript (`stat_modifiers`):**
  - `move_speed_pct`: `+0.30` (+30% velocidad de movimiento).
  - `attack_speed_pct`: `+0.20` (+20% cadencia de ataque).
  - `max_health_pct`: `-0.25` (-25% vida máxima).
* **Impacto Táctico:** Incremento ágil de DPS y movilidad para partidas de alta velocidad.

#### 18. Vórtice Gravitatorio (`gravitational_vortex.tres`)
* **ID Interno:** `gravitational_vortex` | **Cuadrante:** `spacetime`
* **Bono:** +120% Radio gravitatorio de aspiración de orbes.
* **Maldición:** -15% Velocidad de eyección de proyectiles.
* **Modificadores GDScript (`stat_modifiers`):**
  - `pickup_radius_pct`: `+1.20` (+120% radio de atracción de orbes de EXP, BioMasa y Materia Oscura).
  - `projectile_speed_pct`: `-0.15` (-15% velocidad de proyectil).
* **Impacto Táctico:** La nave aspira orbes desde casi media pantalla sin tener que abandonar posiciones defensivas seguras.

---

### 6.4. Cuadrante 4: Pacto de Avaricia & Sobrecarga (`greed`)
Pactos comerciales de alto riesgo enfocados en multiplicar la ganancia de BioMasa, Créditos, EXP y Suerte a cambio de penalizaciones severas en salud o potencia ofensiva.

#### 19. Alquimia de Midas (`midas_alchemy.tres`)
* **ID Interno:** `midas_alchemy` | **Cuadrante:** `greed`
* **Bono:** +50 Puntos de Suerte cósmica y +50% Ganancia de EXP.
* **Maldición:** -20% Potencia de daño base.
* **Modificadores GDScript (`stat_modifiers`):**
  - `luck`: `+50.0` (+50 suerte plana).
  - `exp_multiplier_pct`: `+0.50` (+50% ganancia de experiencia).
  - `base_damage_pct`: `-0.20` (-20% daño base).
* **Impacto Táctico:** Dispara la aparición de cartas de nivel de Tier Épico y legendarias en la subida de nivel, acelerando el escalado de la partida.

#### 20. Cosecha Voraz (`voracious_harvest.tres`)
* **ID Interno:** `voracious_harvest` | **Cuadrante:** `greed`
* **Bono:** +100% Cosecha duplicada de BioMasa y Créditos.
* **Maldición:** -25% Vida máxima y -5 Armadura.
* **Modificadores GDScript (`stat_modifiers`):**
  - `biomass_multiplier`: `+1.00` (Duplica al 200% toda la BioMasa recolectada en la partida).
  - `credits_multiplier`: `+1.00` (Duplica al 200% los créditos ganados por bajas y satélites).
  - `max_health_pct`: `-0.25` (-25% vida máxima).
  - `armor`: `-5.0` (-5 armadura plana).
* **Impacto Táctico:** La arcana económica definitiva para farmear meta-progresión y comprar todo el catálogo de la tienda espacial.

#### 21. Mercado Negro (`black_market.tres`)
* **ID Interno:** `black_market` | **Cuadrante:** `greed`
* **Bono:** +75% Daño crítico y +30% Daño de armas.
* **Maldición:** -30 Suerte (peores probabilidades de botín).
* **Modificadores GDScript (`stat_modifiers`):**
  - `crit_damage`: `+0.75` (+0.75x multiplicador crítico).
  - `base_damage_pct`: `+0.30` (+30% daño base).
  - `luck`: `-30.0` (-30 suerte plana).
* **Impacto Táctico:** Daño devastador para pilotos que ya cuentan con builds definidas y no dependen de la suerte de las tiradas.

#### 22. Inversión de Alto Riesgo (`high_risk_investment.tres`)
* **ID Interno:** `high_risk_investment` | **Cuadrante:** `greed`
* **Bono:** +75% Ganancia de EXP y +35% Cadencia de ataque.
* **Maldición:** -40% Integridad de casco (Max HP).
* **Modificadores GDScript (`stat_modifiers`):**
  - `exp_multiplier_pct`: `+0.75` (+75% multiplicador de EXP).
  - `attack_speed_pct`: `+0.35` (+35% cadencia de ataque).
  - `max_health_pct`: `-0.40` (-40% salud máxima).
* **Impacto Táctico:** Acelera la curva de subida de nivel de forma vertiginosa a costa de dejar a la nave al borde del colapso.

#### 23. Sobrecarga de Imanes (`magnet_overload.tres`)
* **ID Interno:** `magnet_overload` | **Cuadrante:** `greed`
* **Bono:** +150% Rango de atracción de todo mineral en pantalla.
* **Maldición:** -20% Velocidad por sobrecarga de masa.
* **Modificadores GDScript (`stat_modifiers`):**
  - `pickup_radius_pct`: `+1.50` (+150% radio de absorción magnética).
  - `move_speed_pct`: `-0.20` (-20% velocidad de movimiento).
* **Impacto Táctico:** Limpia automáticamente la arena de minerales y esferas de experiencia sin desviarse del objetivo principal.

#### 24. Aura de Extracción (`extraction_aura.tres`)
* **ID Interno:** `extraction_aura` | **Cuadrante:** `greed`
* **Bono:** +30 Suerte, +40% Radio de absorción y +50% BioMasa.
* **Maldición:** -15% Daño infligido por armas.
* **Modificadores GDScript (`stat_modifiers`):**
  - `luck`: `+30.0` (+30 suerte).
  - `pickup_radius_pct`: `+0.40` (+40% radio de atracción).
  - `biomass_multiplier`: `+0.50` (+50% BioMasa adicional acumulada).
  - `base_damage_pct`: `-0.15` (-15% daño base).
* **Impacto Táctico:** Equilibrio ideal entre utilidad de farmeo y probabilidad de mejores recompensas en metajuego.

---

### 6.5. Tabla Maestra de Modificadores de las 24 Arcanas

| ID Arcana | Nombre | Cuadrante | Modificador Bono (Exacto) | Modificador Maldición (Exacto) |
| :--- | :--- | :---: | :--- | :--- |
| `agonic_fury` | Furia Agónica | Glass Cannon | `attack_speed_pct`: +50% | `health_regen_pct`: -50% |
| `blood_pact` | Pacto de Sangre | Glass Cannon | `base_damage_pct`: +60% | `max_health_pct`: -35% |
| `vampiric_drain` | Drenaje Vampírico | Glass Cannon | `health_regen`: +4.0 HP/s | `move_speed_pct`: -20% |
| `core_thirst` | Sed de Núcleo | Glass Cannon | `base_damage_pct`: +40%<br>`weapon_size_pct`: +30% | `pickup_radius_pct`: -30% |
| `last_breath` | Último Aliento | Glass Cannon | `base_damage_pct`: +45%<br>`cooldown_reduction`: +20% | `max_health_pct`: -40% |
| `shield_sacrifice` | Sacrificio de Escudo | Glass Cannon | `crit_chance`: +25%<br>`crit_damage`: +0.50x | `armor`: -8.0 |
| `colossal_projectile`| Proyectil Colosal | Danmaku Chaos | `weapon_size_pct`: +100%<br>`base_damage_pct`: +35% | `projectile_speed_pct`: -40% |
| `unstable_fission` | Fisión Inestable | Danmaku Chaos | `projectile_count`: +2<br>`crit_chance`: +20% | `attack_speed_pct`: -25% |
| `shrapnel_rain` | Lluvia de Metralla | Danmaku Chaos | `projectile_count`: +3 | `base_damage_pct`: -30% |
| `heavy_ballistics` | Balística Pesada | Danmaku Chaos | `base_damage_pct`: +50%<br>`armor`: +6.0 | `move_speed_pct`: -25% |
| `quantum_ricochet` | Rebote Cuántico | Danmaku Chaos | `projectile_speed_pct`: +40% | `base_damage_pct`: -15% |
| `danmaku_mirror` | Espejo Danmaku | Danmaku Chaos | `projectile_count`: +4<br>`attack_speed_pct`: +30% | `weapon_size_pct`: -50%<br>`base_damage_pct`: -20% |
| `time_dilation` | Dilatación Temporal | Spacetime | `cooldown_reduction`: +40%<br>`crit_chance`: +15% | `projectile_speed_pct`: -20% |
| `warp_engine` | Motor de Curvatura | Spacetime | `move_speed_pct`: +60% | `pickup_radius_pct`: -50% |
| `dimensional_leap` | Salto Dimensional | Spacetime | `move_speed_pct`: +45%<br>`cooldown_reduction`: +35% | `max_health_pct`: -20% |
| `phantom_evasion` | Evasión Fantasma | Spacetime | `armor`: +10.0<br>`move_speed_pct`: +25% | `base_damage_pct`: -20% |
| `phase_flicker` | Parpadeo de Fase | Spacetime | `move_speed_pct`: +30%<br>`attack_speed_pct`: +20% | `max_health_pct`: -25% |
| `gravitational_vortex`| Vórtice Gravitatorio | Spacetime | `pickup_radius_pct`: +120% | `projectile_speed_pct`: -15% |
| `midas_alchemy` | Alquimia de Midas | Greed | `luck`: +50.0<br>`exp_multiplier_pct`: +50% | `base_damage_pct`: -20% |
| `voracious_harvest` | Cosecha Voraz | Greed | `biomass_multiplier`: +100%<br>`credits_multiplier`: +100% | `max_health_pct`: -25%<br>`armor`: -5.0 |
| `black_market` | Mercado Negro | Greed | `crit_damage`: +0.75x<br>`base_damage_pct`: +30% | `luck`: -30.0 |
| `high_risk_investment`| Inversión de Alto Riesgo | Greed | `exp_multiplier_pct`: +75%<br>`attack_speed_pct`: +35% | `max_health_pct`: -40% |
| `magnet_overload` | Sobrecarga de Imanes | Greed | `pickup_radius_pct`: +150% | `move_speed_pct`: -20% |
| `extraction_aura` | Aura de Extracción | Greed | `luck`: +30.0<br>`pickup_radius_pct`: +40%<br>`biomass_multiplier`: +50% | `base_damage_pct`: -15% |

---

### 6.6. Mecánica de Agotamiento de Catálogo (`quantum_overload_mastery`)
Si un jugador adquiere las **24 Arcanas disponibles**, el sistema no se bloquea ni genera excepciones: `ArcanaData.get_random_selection()` detecta el catálogo agotado y genera dinámicamente la carta especial **Sobrecarga Cuántica Infinita**:
- **Efecto de Sobrecarga:**
  * **+500 Créditos inmediatos** para gastar en la Tienda del Satélite.
  * **+15 unidades de Materia Oscura** transferidas y persistidas de inmediato en `SaveManager`.
- **Despausa Limpia:** Despausa el árbol de juego y reproduce el efecto audiovisual de invocación cósmica sin interrumpir el flujo de combate.

---

## 7. SISTEMAS DE PROGRESIÓN, DAÑO Y METARECOMPENSAS

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FLUJO DE PROGRESIÓN INTEGRAL                    │
├───────────────────┬───────────────────────────┬────────────────────────┤
│ En la Partida     │ En el Satélite / Tienda   │ En el Hub / Metajuego │
├───────────────────┼───────────────────────────┼────────────────────────┤
│ • Subida de Nivel │ • Compra de Armas         │ • Sala de Trofeos 3D   │
│   (Cartas Brotato)│ • Compra de Ítems         │ • Árbol Hexagonal      │
│ • Orbes de Arcana │ • Reparación de Casco     │ • Desbloqueo Heroínas  │
│ • Minería Planetas│ • Banish de Ítems         │ • Highscores Globales  │
└───────────────────┴───────────────────────────┴────────────────────────┘
```

### 7.1. Cartas de Subida de Nivel (Estilo Brotato)
Gestionadas por `StatDeckManager`, ofrecen 4 cartas al subir de nivel con probabilidad de rareza escalonada según la suerte del piloto:
- **18 cartas canónicas** (+Daño, +Cadencia, +Prob. Crítica, +Daño Crítico, +Vida Máxima, +Velocidad, +Suerte, +Proyectiles, +Armadura, +Regeneración, +Imán, +Multiplicador de EXP).
- **Mecánica de Reroll:** Permite relanzar la selección gastando créditos iniciales (5 cr., +3 cr. por cada reroll consecutivo).
- **Encolamiento Protegido:** Las subidas de nivel consecutivas se almacenan en una cola FIFO para evitar pérdidas por selección apresurada.

### 7.2. Sala de Trofeos 3D y Maestría con Materia Oscura
Ubicada en la sección norte del Hangar 3D (`HubWorld`), contiene **5 pedestales interactivos** con hologramas 3D animados:
1. **Corazón de Nodriza Aegis (`trophy_boss_aegis`):**
   - *Obtención:* Derrotar al Dreadnought Nodriza Aegis (`BossMothership`).
   - *Bono Global:* **+10% Daño permanente a todas las heroínas (+5% por nivel de maestría)**.
2. **Núcleo Bio-Planeta (`trophy_biosphere_core`):**
   - *Obtención:* Digitalizar el núcleo del Planeta Verde (Verdant).
   - *Bono Global:* **+15 HP Máximo global para todas las partidas (+5 HP por nivel de maestría)**.
3. **Núcleo Criogénico (`trophy_cryo_core`):**
   - *Obtención:* Digitalizar el núcleo del Planeta de Hielo (Cryo).
   - *Bono Global:* **+5% Vel. Proyectil y +5% Reducción de enfriamiento (+2% por nivel)**.
4. **Núcleo Volcánico (`trophy_volcanic_core`):**
   - *Obtención:* Digitalizar el núcleo del Planeta de Magma (Volcanic).
   - *Bono Global:* **+5% Prob. Crítica y +0.25x Daño Crítico (+2% / +0.1x por nivel)**.
5. **Reliquia del Monolito (`trophy_monolith_master`):**
   - *Obtención:* Destruir Monolitos Arcanos y recolectar arcanas.
   - *Bono Global:* **+15% Radio de Recogida y +10% Suerte global (+5% / +5% por nivel)**.

### 7.3. Indicador Periférico de Satélite (`SatelliteEdgeIndicator`)
Un radar cyberpunk proyectado dinámicamente en los bordes de la pantalla que rastrea el satélite de la oleada cuando queda fuera del viewport. Calcula el ángulo y la distancia euclidiana en tiempo real para guiar al piloto a través de la inmensidad del espacio, desprendiéndose al centro al entrar en visión.

### 7.4. Indicador Direccional Arcano en el Borde del HUD (`ArcanaEdgeIndicator`)
- **Estética Mística Psycho-Pop:** Panel perimétrico compacto con reborde magenta (`#FF1493`), resplandor cian neón (`#00F0FF`), icono rúnico vectorial (`icon_arcana_rune.svg`) y etiqueta de telemetría de distancia en metros.
- **Rastreo y Conmutación Inteligente:** Detecta en tiempo real el `ArcaneMonolith` más próximo al jugador. Si se destruye, conmuta automáticamente al siguiente sin saltos bruscos.
- **Comportamiento en Pantalla:**
  * *Fuera de pantalla:* Se proyecta fijado al margen del viewport apuntando con una flecha orientada hacia las coordenadas exactas de la anomalía.
  * *Dentro de pantalla / Sin Monolitos:* Se oculta de forma limpia (`hide()`) para no saturar el campo de combate cuando el objeto ya es visible o no hay entidades activas.

### 7.5. Pantalla de Game Over y Telemetría Post-Incursión (`GameOverModal`)
- **Secuencia de Destrucción de la Nave (`PlayerExplosionVFX`):**
  * Al llegar a 0 HP, la nave detona con un efecto procedimental multi-capa: destello nuclear central, ondas expansivas concéntricas de plasma, esquirlas de fuselaje con dispersión angular y chispas radiales.
  * Pausa dramática de 1.0s con bloqueo inmediato de controles y trauma de sacudida de cámara.
- **Telemetría y Resumen Táctico:**
  * **Puntuación Algorítmica:** Puntuación global calculada sobre bajas hostiles, oleadas completadas, jefes abatidos, créditos y tiempo de supervivencia.
  * **Distintivo de Récord:** Indicador visual dinámico `★ ¡NUEVO RÉCORD HISTÓRICO - TOP #1! ★` o puesto en el ranking histórico persistente de los 10 mejores registros (`SaveManager`).
  * **Métricas de Combate:** Oleadas alcanzadas, tiempo de incursión (MM:SS), jefes derrotados y conteo de bajas enemigas.
  * **Recursos Extraídos:** BioMasa, Materia Oscura y Créditos consolidados.
  * **Desglose de Carga (Loadout):** Panel visual con todas las Arcanas adquiridas, ítems pasivos con sus multiplicadores de acumulación (`x2`, `x3`, etc.) y armas activas con su nivel alcanzado.
  * **Navegación Rápida:** Atajos integrados `[R] Reiniciar Misión` (reinicio instantáneo) y `[H] Volver al HUB` (retorno al Hangar 3D).

### 7.6. Modificadores de Velocidad en Despliegue (1x / 2x / 4x)
- Selector de ritmo de juego integrado directamente en el Menú de Despliegue de Piloto (`CharacterSelectUI`).
- Permite acelerar la escala temporal del motor (`Engine.time_scale`) a 1x (Normal), 2x (Acelerado) o 4x (Hiper-Velocidad) para jugadores veteranos o sesiones rápidas.
- Soporte para atajos de teclado (`1`, `2`, `3`) y persistencia automática en el perfil de guardado.

### 7.7. Autotargeting y Apuntado Manual Híbrido (Tecla `E` / Botón `RB`)
- **Trayectoria Balística Directa:** Los misiles y armas secundarias viajan en línea recta estricta a alta velocidad sin curvas asistidas artificiales.
- **Fijación Automática Inteligente:** Prioriza automáticamente al hostil más próximo dentro del perímetro de disparo efectivo de la nave.
- **Escalado con Radio de Imán:** Rango de autoaim acoplado linealmente al radio de atracción magnética ($2 \times \text{pickup\_radius}$ base), beneficiándose directamente de mejoras pasivas y arcanas de imán.
- **Conmutación Manual en Caliente:** Alterna en cualquier instante entre auto-apuntado y puntero del ratón mediante la tecla `E` o `RB` en gamepad, acompañado de retícula holográfica e indicador `AUTOAIM: ON / OFF`.

### 7.8. Maniobras Evasivas Avanzadas y Dashes Únicos por Heroína
Cada heroína dispone de una mecánica de dash con invulnerabilidad temporal y efectos tácticos exclusivos:
1. **Nova — Fire Trail & Nova Omega Spin:**
   - Doble carga de propulsión rápida dejando un rastro ígneo continuo que daña a enemigos que lo cruzan.
   - *Omega Spin:* Al realizar un dash con el condensador láser al 100% de carga, Nova ejecuta un giro continuo de 360° barriendo toda la arena con un haz láser circular de pantalla completa (con deduplicación de daño por enemigo).
2. **Valentina — Sniper Charge & Bullet-Time:**
   - Salto de repliegue táctico en sentido opuesto a la mira.
   - Activa dilatación temporal (*Bullet-Time* al 55% de velocidad del juego) y garantiza un impacto crítico al 100% en el siguiente disparo.
3. **Kira — Drone Decoy Dash:**
   - Despliega una mina señuelo holográfica reactiva en las coordenadas de despegue que absorbe proyectiles, atrae esbirros y detona en área al expirar.
4. **Selene — Quantum Void Phase:**
   - Teletransporte cuántico de fase de 240 px en la dirección del cursor.
   - Genera un vórtice gravitacional de implosión que atrae esbirros y absorbe orbes de EXP y fragmentos hacia el punto de destino.
5. **Roxy — Seismic Barrier Ram:**
   - Embestida pesada frontal con escudo cinético que desvía proyectiles hostiles e inflige un golpe físico de alto impacto con knockback masivo (360 px/s).
6. **Echo — Quantum Glitch EMP:**
   - Parpadeo dimensional instantáneo de 200 px con cuadros de invulnerabilidad ampliados y descarga de arco voltaico en cadena que electrocuta a múltiples hostiles cercanos.

### 7.9. Cola de Subida de Nivel y Protección contra Miss-Clicks (`LevelUpModal`)
- **Encolamiento Seguro FIFO:** Si el jugador acumula múltiples niveles simultáneamente (por absorber grandes cúmulos de EXP o matar jefes), las subidas se encolan ordenadamente. El encabezado notifica dinámicamente: `¡SUBIDA DE NIVEL X! (+Y PENDIENTES)`.
- **Protección contra Clics Accidentales (Miss-Clicks):**
  * Botones de selección compactos y centrados (110x30 px).
  * Los clics sobre el cuerpo o panel de la carta son ignorados para no seleccionar mejoras por accidente durante tiroteos intensos.
  * Período de gracia inicial con bloqueo temporal de ratón (`_mouse_lockout_active`) al desplegarse el modal para descartar clics remanentes del arma.

### 7.10. Overlay Táctico de Estadísticas del Cockpit ([Tecla `C`])
- Pausa táctica activable en cualquier momento del combate mediante la tecla **`C`**.
- Presenta el retrato oficial de la heroína en combate, cabecera temática y colores característicos adaptados dinámicamente a la paleta del personaje activo.
- Desglose exhaustivo de las **14 estadísticas clave** en formato unificado `ESTADISTICA = VALOR` (Daño, Vel. Ataque, Prob. Crítica, Daño Crítico, Proyectiles, Vel. Proyectil, Rango, Vida Máxima, Armadura, Regeneración, Vel. Movimiento, Cooldown, Suerte e Imán).
- Listado en vivo de todas las **Arcanas Activas** en la run y los **Trofeos Globales Permanentes** aplicados.

### 7.11. Menú de Depuración / Cheat Menu (`DebugMenuModal`)
- Acceso táctico de depuración y testing para balance rápido en partidas de prueba.
- Permite alternar invencibilidad (Modo Dios), créditos infinitos, agregar BioMasa o Materia Oscura, forzar subidas de nivel inmediatas y saltar a oleadas avanzadas.

### 7.12. Menú de Despliegue con Parallax Estelar y Naves Ambientales (`DeploymentSpaceBackground`)
- Fondo cinemático interactivo en el hangar y pantalla de selección de personajes con 3 planos ópticos de profundidad, polvo estelar flotante y tránsito periódico de naves aliadas y de carga en segundo plano.

### 7.13. Blindaje de Menús y Sistema Anticolapso de Pausa
- Arquitectura estricta de capas CanvasLayer para evitar solapamientos (`GameHUD` capa 10, `GameOverModal` capa 35, `LevelUpModal` capa 40, `PauseMenu` capa 50, `SettingsModal` capa 60, `ArcanaSelectionModal` capa 60).
- La reanudación del combate (`get_tree().paused = false`) está condicionada a que ningún otro modal o diálogo esté activo o tenga selecciones pendientes en cola (`is_any_combat_modal_active()`).

---

## 8. INVENTARIO DE ASSETS DEL PROYECTO Y PAUTAS DE REUTILIZACIÓN

Para mantener coherencia estilística, optimizar memoria y no duplicar recursos, el proyecto utiliza:

1. **Modelos 3D (Hangar del Hub):**
   - Colecciones modulares de Kenney (`assets/models/kenney_modular_space/` y `kenney_mini_arcade/`).
   - Estructuras de mamparos, terminales arcade holográficas, ventanas panorámicas y pedestales.
2. **Sprites y Arte 2D (Combate y UI):**
   - Siluetas vectoriales de naves aliadas (`Polygon2D`) mapeadas por vértices y colores característicos.
   - Retratos e ilustraciones Full-Body de las heroínas (`assets/characters/fullbody/` y `assets/portraits/`).
   - Iconos vectoriales SVG limpios para todos los ítems y estadísticas (`assets/icons/items/`).
3. **Audio y Efectos Sonoros:**
   - Gestor `AudioManager` con sistema de atenuación dinámica `AudioDuckManager` que reduce la música durante transmisiones de radio o diálogos de `Dialogic`.
   - Efectos de interfaz (`ui_click`, `level_up`, `hit`, `explosion`, `laser_shoot`).

---

## 9. ORGANIZACIÓN DEL EQUIPO Y FLUJO DE TRABAJO (`/teamwork-preview`)

Para mantener el proyecto libre de conflictos en Git, robusto ante compilaciones y coordinado entre subsistemas, se define la siguiente división de responsabilidades:

```
┌────────────────────────────────────────────────────────────────────────┐
│               MATRIZ DE TRABAJO EN EQUIPO (TEAMWORK PREVIEW)           │
├───────────────────┬────────────────────────────────────────────────────┤
│ Rol               │ Responsabilidades Primarias                        │
├───────────────────┼────────────────────────────────────────────────────┤
│ 1. Core & Engine  │ • Compilación limpia GDScript (cero parse errors). │
│    Specialist     │ • Optimización SoA en BulletServer.                │
│                   │ • Prevención de Autoload Shadowing y nulos en HUD. │
├───────────────────┼────────────────────────────────────────────────────┤
│ 2. Game Systems & │ • Balance de atributos de las 6 heroínas y armas.  │
│    Economy Lead   │ • Expansión de Arcanas y equilibrio de pactos.     │
│                   │ • Mantenimiento de la Triada Económica.            │
├───────────────────┼────────────────────────────────────────────────────┤
│ 3. UI/UX & Hub    │ • Experiencia Psycho-Pop en Hangar 3D y modales.   │
│    Architect      │ • Navegabilidad con UIFocusHelper (gamepad/teclado)│
│                   │ • Indicadores periféricos y radares tácticos.      │
├───────────────────┼────────────────────────────────────────────────────┤
│ 4. Quality & E2E  │ • Ejecución de suites de prueba sin --headless.    │
│    Verification   │ • Verificación de logs limpios en godot.log.       │
│                   │ • Auditoría de integridad de escenas y recursos.   │
└───────────────────┴────────────────────────────────────────────────────┘
```

---
*Fin de la Auditoría Maestra. Documento mantenido por Antigravity para Astra Dream.*
