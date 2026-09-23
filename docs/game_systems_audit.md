# GUÍA Y AUDITORÍA MAESTRA DE SISTEMAS: ASTRA DREAM
**Versión del Proyecto:** 0.1.0-alpha  
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
   - Inyecta periódicamente (cada 28s) macro-objetos en la periferia de navegación del jugador (radio 1000-1350 px), orientando las apariciones según el vector de movimiento de la nave para garantizar encuentros tácticos continuos.

---

## 6. GRIMORIO COMPLETO DE LAS 24 ARCANAS (PACTOS MÍSTICOS)

Las Arcanas son cartas cuánticas de **Alto Riesgo y Alta Recompensa** que se activan al recoger un orbe rúnico de un Monolito. Pausan el juego y ofrecen 3 elecciones estilizadas con bordes Psycho-Pop. Cada una contiene un **Bono Divino** masivo y una **Maldición Devastadora**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                     GRIMORIO DE ARCANAS (24 CARTAS)                    │
├─────────────────────────┬──────────────────────────┬───────────────────┤
│ Cuadrante               │ Enfoque Táctico          │ Cantidad          │
├─────────────────────────┼──────────────────────────┼───────────────────┤
│ 1. Glass Cannon         │ Cañón de Cristal y Sangre│ 6 Arcanas         │
│ 2. Danmaku Chaos        │ Caos Balístico y Ráfagas │ 6 Arcanas         │
│ 3. Spacetime            │ Espacio-Tiempo y Evasión │ 6 Arcanas         │
│ 4. Greed                │ Avaricia y Sobrecarga    │ 6 Arcanas         │
└─────────────────────────┴──────────────────────────┴───────────────────┘
```

### Cuadrante 1: Cañón de Cristal & Sangre (`glass_cannon`)
1. **Furia Agónica (`agonic_fury.tres`):**
   - *Bono:* +80% Daño General (`base_damage_pct: +0.80`).
   - *Maldición:* La regeneración de salud se reduce a 0 (`health_regen: -10.0`).
2. **Pacto de Sangre (`blood_pact.tres`):**
   - *Bono:* +60% Probabilidad Crítica (`crit_chance: +0.60`).
   - *Maldición:* -35% Salud Máxima (`max_health_pct: -0.35`).
3. **Drenaje Vampírico (`vampiric_drain.tres`):**
   - *Bono:* +3.0 HP de Regeneración continua por segundo (`health_regen: +3.0`).
   - *Maldición:* -25% Velocidad de Movimiento (`move_speed_pct: -0.25`).
4. **Sed del Núcleo (`core_thirst.tres`):**
   - *Bono:* +50% Velocidad de Ataque y Cadencia (`attack_speed_pct: +0.50`).
   - *Maldición:* -4 Armadura plana recibida (`armor: -4.0`).
5. **Último Aliento (`last_breath.tres`):**
   - *Bono:* +100% Daño si la salud cae por debajo del 30% (`base_damage_pct: +1.00`).
   - *Maldición:* La nave recibe un 20% más de daño en todo momento (`armor: -2.0`).
6. **Sacrificio de Escudo (`shield_sacrifice.tres`):**
   - *Bono:* +1.0 Multiplicador de Daño Crítico (`crit_damage: +1.0`).
   - *Maldición:* Se pierde 1 carga de bomba máxima (`armor: -1.0`).

### Cuadrante 2: Danmaku & Caos Balístico (`danmaku_chaos`)
7. **Proyectil Colosal (`colossal_projectile.tres`):**
   - *Bono:* +80% Tamaño y radio de proyectiles aliados (`weapon_size_pct: +0.80`).
   - *Maldición:* -30% Velocidad de proyectil (`projectile_speed_pct: -0.30`).
8. **Fisión Inestable (`unstable_fission.tres`):**
   - *Bono:* +3 Proyectiles adicionales en todas las armas (`projectile_count: +3.0`).
   - *Maldición:* -35% Daño individual de cada proyectil (`base_damage_pct: -0.35`).
9. **Lluvia de Metralla (`shrapnel_rain.tres`):**
   - *Bono:* Los destructibles rotos generan el doble de esquirlas cinéticas.
   - *Maldición:* -15% Radio de recogida de orbes (`pickup_radius_pct: -0.15`).
10. **Balística Pesada (`heavy_ballistics.tres`):**
    - *Bono:* +60% Velocidad de proyectil y penetración perforante (`projectile_speed_pct: +0.60`).
    - *Maldición:* -15% Cadencia de disparo (`attack_speed_pct: -0.15`).
11. **Rebote Cuántico (`quantum_ricochet.tres`):**
    - *Bono:* Los proyectiles rebotan una vez más contra los límites de pantalla y obstáculos.
    - *Maldición:* -15% Daño base (`base_damage_pct: -0.15`).
12. **Espejo Danmaku (`danmaku_mirror.tres`):**
    - *Bono:* El Dash desvía y neutraliza proyectiles hostiles en un radio de 60 px.
    - *Maldición:* El tiempo de recarga del Dash se incrementa un 25%.

### Cuadrante 3: Espacio-Tiempo & Evasión (`spacetime`)
13. **Dilatación Temporal (`time_dilation.tres`):**
    - *Bono:* Los proyectiles hostiles del `BulletServer` se mueven un 25% más lento.
    - *Maldición:* La ganancia de EXP de la partida se reduce un 15% (`exp_multiplier_pct: -0.15`).
14. **Motor Warp (`warp_engine.tres`):**
    - *Bono:* +40% Velocidad de Movimiento permanente (`move_speed_pct: +0.40`).
    - *Maldición:* La nave sufre inercia resbaladiza incrementada y fricción reducida.
15. **Salto Dimensional (`dimensional_leap.tres`):**
    - *Bono:* +1 Carga adicional de Dash (`dash_charges: +1`).
    - *Maldición:* -20 HP Máximo (`max_health: -20.0`).
16. **Evasión Fantasma (`phantom_evasion.tres`):**
    - *Bono:* 20% Probabilidad pasiva de evadir completamente cualquier daño recibido.
    - *Maldición:* -25% Daño general infligido (`base_damage_pct: -0.25`).
17. **Parpadeo de Fase (`phase_flicker.tres`):**
    - *Bono:* Duplica la duración de los cuadros de invulnerabilidad tras ser impactado.
    - *Maldición:* -20% Daño crítico (`crit_damage: -0.20`).
18. **Vórtice Gravitatorio (`gravitational_vortex.tres`):**
    - *Bono:* +120 px Radio de atracción de orbes e ítems (`pickup_radius: +120.0`).
    - *Maldición:* -10% Velocidad de movimiento (`move_speed_pct: -0.10`).

### Cuadrante 4: Pacto de Avaricia & Sobrecarga (`greed`)
19. **Alquimia de Midas (`midas_alchemy.tres`):**
    - *Bono:* +100% Créditos ganados por bajas y satélites (`credits_multiplier_pct: +1.00`).
    - *Maldición:* Los precios de la Tienda del Satélite suben un 30%.
20. **Cosecha Voraz (`voracious_harvest.tres`):**
    - *Bono:* +100% BioMasa obtenida para meta-progresión (`biomass_multiplier_pct: +1.00`).
    - *Maldición:* Los enemigos tienen un +25% de salud máxima.
21. **Mercado Negro (`black_market.tres`):**
    - *Bono:* La Tienda ofrece 1 slot adicional de arma o ítem de Tier superior.
    - *Maldición:* Despliega un escuadrón élite adicional por cada oleada de satélite.
22. **Inversión de Alto Riesgo (`high_risk_investment.tres`):**
    - *Bono:* Otorga inmediatamente +300 Créditos directos.
    - *Maldición:* Reduce la salud actual al 1 HP inmediatamente (requiere curación urgente).
23. **Sobrecarga de Imán (`magnet_overload.tres`):**
    - *Bono:* Absorbe periódicamente todos los orbes de la arena cada 45 segundos.
    - *Maldición:* -10 Armadura contra impactos de asteroides.
24. **Aura de Extracción (`extraction_aura.tres`):**
    - *Bono:* Daña pasivamente a los objetos destructibles cercanos con 20 DPS continuos.
    - *Maldición:* Reduce la suerte en -15% (`luck_pct: -0.15`).

### Mecánica de Agotamiento de Catálogo (`quantum_overload_mastery`)
Si un jugador con una build longeva llega a adquirir las 24 Arcanas disponibles, el modal no se bloquea: genera dinámicamente la carta especial **Sobrecarga Cuántica Infinita**, que otorga **+500 Créditos inmediatos** y **+15 unidades de Materia Oscura**, garantizando escalado infinito en partidas extensas.

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
Un radar cyberpunk proyectado dinámicamente en los bordes de la pantalla que rastrea el satélite de la oleada cuando queda fuera del viewport. Calcula el ángulo y la distancia euclidiana en tiempo real para guiar al piloto a través de la inmensidad del espacio.

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
