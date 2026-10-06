# Changelog — Astra Dream

Todos los cambios notables en este proyecto serán documentados en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Alpha 0.1] - 2026-10-06 — Selección de Personajes Rework, Animaciones Procedurales de Vuelo, Modales & Pulido Visual

### Añadido y Mejorado
* **Menú Principal & Identidad Visual (`TitleScreen`):**
  * Versión del juego actualizada formalmente a **Alpha 0.1**.
  * Alineación y centrado geométrico estricto del bloque de presentación en pantalla de título (Logo `Astra Dream`, Prompt de interacción interactivo y Etiqueta de Versión).
* **Rework de Selección de Personajes & Hangar de Despliegue (`CharacterSelectUI`):**
  * **HeroPickerModal:** Selector modal inmersivo de heroínas en cuadrícula con desenfoque de fondo y aislamiento de navegación, activado al tocar barra espaciadora o doble clic.
  * **Botón de Despegue en Cinta Continua (`TapeMarqueeButton`):** Sustitución del botón de lanzamiento estándar por un botón estilizado de cinta transportadora militar continua con animación infinita y shader reactivo.
  * **Transición de Escenas Global (`SceneTransition`):** Autoload desacoplado para fundidos cinematográficos y barridos diagonales de entrada y salida entre pantallas y partidas.
  * **Animación Procedural de Vuelo de Pilotos (`ExoPilotFlight`):** Sistema de balanceo y cabeceo inercial de la piloto con máscara RGBA para estelas de propulsores de plasma y llamaradas reactivas.
  * **Carrusel Cosmético de Aspectos (`CosmeticCarouselModal`):** Modales independientes para inspección 360° y equipamiento de skins de Heroínas, Naves, Armas, Mascotas y Navegadoras con preview en tiempo real y soporte para estrellas cosméticas.
  * **Centrado Óptico de Armas por AtlasTexture:** Recorte y encuadre dinámico de sprites de armas orbitales (256x256 y 1024x1024) para eliminar márgenes descompensados y centrarlas perfectamente en la tarjeta de equipamiento.
* **Integración Visual de Diálogos (`DialogueBackdropLayer`):**
  * Shader de post-procesado holográfico (`pilot_showcase_hologram.gdshader`) con corrección de bordes (alpha feathering / defringing) en los retratos de las pilotos durante las secuencias de diálogo.
  * Luz perimetral aditiva de contraluz (`BacklightGlow`) modulada al color característico de la piloto activa.
* **Sincronización de Iconos de Combate al HUD In-Game:**
  * Transferencia de los iconos de Sistemas de Combate de cada heroína (`icon_dash_<pilot>`, `icon_tactical_<pilot>`) directamente a los slots y botones del HUD en partida.

---

## [0.6.0] - 2026-10-03 — Rework Maestro de Balance, Álgebra de Daño, Economía Híbrida, Balística & 12 Nuevos Ítems

### Añadido
* **Fase 1: Álgebra de Daño en 3 Contenedores y Sistema de Maldición (`CharacterStats` & `StatDeckManager`):**
  * Desacoplamiento matemático estricto: $(D_{\text{base}} + D_{\text{plano}}) \cdot (1 + \sum B_{\text{aditivo}}) \cdot \prod (1 + M_{\text{multiplicativo}})$.
  * Nuevo enum `Enums.ModifierType` (`FLAT`, `ADDITIVE_PERCENT`, `MULTIPLICATIVE`).
  * Estadística base `curse` con escalado dinámico (+0.5% velocidad y densidad enemiga por punto) y bonificación de créditos (+1% por punto de maldición).
  * Rebalanceo numérico de cartas de subida de nivel para mitigar la inflación pasiva (+12%/+24% daño aditivo, +10% cadencia, +6% crítico plano, +30% crítico aditivo).
* **Fase 2: Economía Híbrida Wave-Inflation y Consumo Activo de Llaves (`SpatialChest` & `ChestDirector`):**
  * Transición de curva cuadrática a fórmula híbrida de oleada: $C(w, k) = \lfloor (20 + 4w) \cdot (1 + 0.15k) \cdot \text{key\_discount} \rfloor$.
  * Reseteo automático de inflación local ($k \to 0$) al avanzar de oleada en `ChestDirector`.
  * Llave Cuántica (`quantum_key`): Consumo activo (1 llave abre un cofre regular gratis a 0c sin aumentar $k$) y descuento pasivo permanente del -20% en pagos con créditos.
  * Cofre Dorado fijado en 120 créditos inmune a llaves.
* **Fase 3: Balística de Armas, Coeficientes de Activación (Proc) y Protocolo OSP (`WeaponData`, `Player` & `BulletServer`):**
  * Calibración de `proc_coefficient` en todo el arsenal (0.10 a 1.00).
  * **Regla Cero Balística:** Prohibición absoluta de efectos secundarios en cadena ($\kappa_{\text{child}} = 0.0$).
  * Enfriamiento Interno Dinámico (ICD Throttling) para armas de alta frecuencia continua (`tachyon_beam`, `hive_cannon`).
  * **Protocolo One-Shot Protection (OSP):** Supervivencia garantizada con al menos 1 HP y 0.5s de invulnerabilidad táctica si el impacto letal ocurre con $\ge 90\%$ de salud/escudo combinados.
  * Compensación temprana para armas pesadas: Pulso a quemarropa (< 80px) con 30% daño y 250px/s knockback, fragmentación de Scatter Laser y aura Stutter-Field en recargas.
* **Fase 4: Catálogo de 12 Nuevos Ítems Estratégicos y Sistema de Pity PRD (`ItemPoolManager`):**
  * 12 nuevos artefactos tácticos divididos en 3 categorías:
    * *Riesgo y Maldición:* `abyssal_contract`, `antimatter_core`, `blood_capacitor`, `entropy_engine`.
    * *Sinergia Cruzada:* `bifocal_lens`, `inertial_thruster`, `chain_battery`, `photonic_prism`.
    * *Espacio y Economía:* `orbital_relay` (10s despliegue de satélite), `quantum_recompiler` (+1 uso en Forja Cuántica), `heavy_salvager` (+2 HP y +3c por cápsula), `chronos_bank` (10% interés por oleada, cap 50c).
  * Corrección de `nanotitanium_plating` a `FLAT` (+3.0 armadura) para pilotos con 0 base.
  * Sistema de Pity Dinámico Pseudo-Aleatorio (PRD) con aceleración de umbrales por Suerte (`player_luck`).
* **Fase 5: UI/HUD Rework & Feedback Visual (`GameHUD`, `HUDBannerManager`, `CharacterStatsOverlay`):**
  * Insignia reactiva de Maldición (`CurseBadge`) en HUD, vinculada al evento `stat_changed` de `CharacterStats` con micro-animación de escala y visibilidad contextual (oculta en 0).
  * Banners cinematográficos de alerta táctica (`TacticalAlertPanel`) gestionados por `HUDBannerManager` para avisos prioritarios:
    * Alerta de activación del Protocolo One-Shot Protection (OSP).
    * Alerta de dividendos de interés de Banco Cronos (`chronos_bank`).
    * Alerta de recompensas de chatarra por cápsulas abiertas con Recuperador Pesado (`heavy_salvager`).
  * Integración de categoría `"☣️ RIESGO Y CORRUPCIÓN"` con atributo `"MALDICIÓN"` en el Cuadro de Mando Táctico (`CharacterStatsOverlay`).
* **Suites de Pruebas Unitarias Automatizadas (336 Pruebas Totales Headless):**
  * `test_damage_buckets_runner.tscn` (17 pruebas).
  * `test_hybrid_chest_economy_runner.tscn` (45 pruebas).
  * `test_proc_coefficients_and_osp_runner.tscn` (66 pruebas).
  * `test_new_items_and_pity_runner.tscn` (157 pruebas).
  * `test_phase5_ui_feedback_runner.tscn` (19 pruebas).
  * `test_chest_economy_runner.tscn` (29 pruebas).
  * `test_satellite_items_runner.tscn` (4/4 suites).

---

## [0.5.1] - 2026-10-03 — Economía de Cofres Espaciales, Llaves Cuánticas y Draft Táctico

### Añadido
* **Sistema de Cofres Espaciales e Inflación Dinámica (`SpatialChest` & `ChestDirector`):**
  * Tres tipos de cofres desplegados en el espacio: Cápsula de Chatarra (0c, gratuita), Cofre Regular (25c base con inflación cuadrática `25 + 8n + 1.5n^2`) y Cofre Dorado (150c fijo, inmune a llaves).
  * Apertura fluida por contacto directo (`activation_radius`) o teclas de interacción (`E`, `Espacio`, `Enter`).
  * `ChestDirector` gestiona la población periférica, cuotas máximas e inflación acumulativa en tiempo real.
* **Mecánica y Asset de Llave Cuántica (`quantum_key`):**
  * Asset gráfico de tarjeta militar sci-fi generado en vista estrictamente cenital top-down 90° con fondo chroma magenta (`#FF00FF`) y despill automatizado.
  * Fórmula de descuento asintótica `P = 1.0 - (1.0 / (1.0 + 0.1 * keys))` que congela el coste inflacionario al activarse aperturas gratuitas.
  * Nuevo badge HUD translúcido cian (`KeyBadge`) centrado en pantalla directamente sobre las ranuras de armas (`WeaponSlotsRow`), con formato interactivo `x{N} ({%}% Gratis)` y animación de escala elástica.
* **Modal de Selección Táctica de 3 Ítems (`ChestRewardModal`):**
  * Despliega 3 cartas interactivas por cofre mediante `ItemPoolManager.roll_chest_draft()`, con prevención de duplicados y filtros por rareza.
  * Pausa el combate durante la selección; admite atajos de teclado numérico `[1]`, `[2]`, `[3]` o selección con ratón.
* **Forja Cuántica Orbital (`TransmutationStation` & `TransmutationModal`):**
  * Estación interactiva de 3 usos para transmutar ítems del inventario por otros de su misma categoría de rareza.
* **Suite de Pruebas Unitarias Automatizadas:**
  * `tests/test_chest_economy_runner.tscn` y `test_chest_economy_suite.gd` con 29/29 pruebas unitarias exitosas en modo headless.

---

## [0.5.0] - 2026-10-02 — Balística Alienígena Danmaku, Telegrafiado Holográfico y Campeones Élite

### Añadido
* **Nuevo Sistema de Balística Alienígena Zero-Allocation (`BulletServer` & `danmaku_bullet.gdshader`):**
  * Diseñados e integrados 3 proyectiles de geometría circular con efectos energéticos diferenciados:
    * **Tipo 4 — Dardo Cónico Ámbar (Delta Dart):** Proyectil directivo de alta penetración y velocidad para ráfagas apuntadas y barridos focales.
    * **Tipo 5 — Anillo Radiante de Cobalto (Radial Star):** Anillo concéntrico pulsante para erupciones radiales, ecos temporales y flores de Rhodonea.
    * **Tipo 6 — Onda Púrpura Abisal (Lissajous Wave):** Diamante oscilatorio de fase para trenzas helicoidales, ondas serpenteantes y espirales de Fermat.
  * Atlas balístico unificado (`alien_bullet_atlas.png`) procesado mediante chroma-key verde puro (`#00FF00`) y pipeline de despill en Python.
  * Escalado dinámico en `BulletServer` ajustando quads de `MultiMeshInstance2D` proporcionalmente al radio de colisión (`radius / 5.0`).
* **Componente Desacoplado `TelegraphIndicator` (`scenes/combat/enemies/components/telegraph_indicator.gd`):**
  * Sistema modular de anticipación visual con 3 tipos de avisos holográficos: `CONE` (abanico directivo), `RING` (anillo expansivo) y `WAVE` (carril oscilatorio).
  * Renderizado `top_level = true` con seguimiento de posición en tiempo real para evitar rotaciones o distorsiones de escala anómalas heredadas del CharacterBody2D del emisor.
  * Transición fluida con shaders de resplandor, crecimiento progresivo (0.0 a 1.0) y fade-out instantáneo en el momento exacto del disparo.
* **Integración en Jefes de Dominio y Heraldos de Oleada:**
  * **Ermitaño del Vacío (`BossHermitVoid`):** Ráfagas serpenteantes con Dardos Ámbar (Tipo 4), Rosas de Rhodonea con Anillos Cobalto (Tipo 5) y Espirales de Fermat con Ondas Púrpura (Tipo 6).
  * **Reloj de Cenizas (`BossAshClock`):** Manecillas cardinales rotatorias con Tipo 4 en Fase 1 y Tipo 6 en Fase 2; detonaciones de Eco del Arrepentimiento telegiadas con Anillos Cobalto (Tipo 5).
  * **Espejo Quebrado (`BossBrokenMirror`):** Mirada disociativa cónica telegrafiada con Dardos Ámbar (Tipo 4), trenzas de Lissajous con Ondas Púrpura (Tipo 6) y novas rotatorias entrelazadas (Tipos 5 y 6).
  * **Vórtice del Desborde (`BossOverflowVortex`):** Espirales respiratorias de Fermat continuas con Ondas Púrpura (Tipo 6), novas telegiadas de alta energía con Anillos Cobalto (Tipo 5) y ráfagas apuntadas con Tipo 4.
  * **Heraldo de Dominio (`EliteHeraldBoss`):** Mini-jefe de oleadas 3, 5 y 7 adaptado con telegrafiado específico (Cono para Tiempo, Onda para Espejo, Anillo para Vórtice) y balística alienígena homologada.
  * **Desaceleración de Combate:** Reducción de velocidad al 45% durante el telegrafiado (wind-up) en todos los jefes para otorgar ventanas de lectura táctica y maniobrabilidad al jugador.
* **Nuevos Enemigos Campeones Élite:**
  * `EnemyAssaultCone` (Asaltante Cónico Élite), `EnemyVanguardRing` (Vanguardia Radial Élite) y `EnemySpecterWave` (Espectro Ondulatorio Élite) integrados en el spawn de oleadas de `EnemySpawner`.
* **Suites de Pruebas Automatizadas en Godot Headless:**
  * `test_alien_champions_and_bullets_runner.tscn`: Valida integridad de assets, pooling SoA de `BulletServer` e instanciación de campeones.
  * `test_boss_telegraphs_and_bullets_runner.tscn`: Valida instanciación, posesión de `TelegraphIndicator` y ciclo de telegrafiado en los 5 jefes.

### Corregido
* **Fallo Crítico de Renderizado de Balas MultiMesh (`danmaku_bullet.gdshader`):**
  * Removido el comando prematuro `return;` dentro de la función `fragment()`, el cual provocaba fallo de compilación en el pipeline gráfico de Godot 4 y hacía que todos los proyectiles del `BulletServer` se mostraran como quads blancos sin textura ni transparencia.
  * Implementado redondeo seguro `int(round(v_custom.r))` en el shader para prevenir truncamiento por precisión flotante en GPUs móviles o Vulkan.

---

## [0.4.3] - 2026-09-27 — Optimización Radical de Contexto y Arquitectura Modular

### Añadido
* **Reglas con Progressive Disclosure (`.agents/rules/`):**
  * Reemplazado el archivo monolítico `project_rules.md` (177 líneas siempre cargadas en contexto) por `core_rules.md` ultraligero (<15 líneas, `always_on`).
  * Desplegadas reglas especializadas bajo demanda: `gdscript_style.md` (activada por glob `*.gd`), `combat_contracts.md`, `architecture_data.md` y `git_workflow.md` (activadas por `model_decision`). Reducción estimada de ~2.500 tokens por turno.
* **Fragmentación de la Base de Datos de Cosméticos (`data/cosmetics/categories/`):**
  * Desacoplado el catálogo monolítico `skin_database.json` (+3.300 líneas) en 6 archivos categorizados: `palettes.json`, `skins_pilots.json`, `skins_ships.json`, `skins_weapons.json`, `skins_pets.json` y `skins_navigators.json`.
  * `CosmeticsManager` ahora carga y une automáticamente las categorías o recupera colecciones puntuales mediante `get_category_skins()`.
* **Modularización de `SaveManager` (`core/autoloads/save_modules/`):**
  * Extraído `SaveSkinsModule` para la gestión de tokens de gacha, desbloqueo y equipamiento de aspectos cosméticos.
  * Extraído `SaveRosterModule` para persistencia y estados de mascotas (`selected_pet`, `unlocked_pets`), navegantes (`selected_navigator`, `unlocked_navigators`) y finales (`unlocked_endings`).
  * Extraído `SaveActiveRunModule` para serialización de partidas en curso (mid-run resume) y tabla de récords (`highscores.json`).
  * `SaveManager` mantiene 100% de compatibilidad estática pública operando como Facade limpio.

### Optimizado
* **Higiene de Repositorio Git:**
  * Actualizado `.gitignore` con exclusiones para `.import/`, `*.tmp`, artefactos binarios `.res`, `.scn` y presets de exportación (`export_presets.cfg`), preservando el control de versiones de texturas (`*.png`) y audio (`*.ogg`, `*.wav`).

---

## [0.4.2] - 2026-09-27 — Armario de Cosméticos, Carrusel de Navegantes, Shaders 3D en Hub y Blindaje de Savegame

### Añadido
* **Shader Spatial 3D con Billboarding Esférico (`skin_glow_spatial.gdshader`):**
  * Implementada función de transformación de vértices `vertex()` con billboard esférico dinámico que preserva la escala del nodo y garantiza que los Sprite3D en el Hangar miren siempre a la cámara.
  * Mascotas errantes (`HubPetRoamer`) y pedestales holográficos de pilotos en el Hub 2.5D ahora reflejan los aspectos equipados con sus auras pulsantes de 2★ y 3★ sin cortes ni distorsiones angulares.
* **Refresco en Caliente del Hangar 3D tras Salir de Menús:**
  * Métodos `update_skin()` en `HubPetRoamer` y `_refresh_pedestal_skins()` en `HubWorld` invocados automáticamente al cerrar cualquier ventana modal (Gacha, Selección de Personaje, Árbol de Talentos, etc.).
* **Suite de Pruebas Automatizadas de Cosméticos y Guardado:**
  * Añadido runner `tests/test_skin_carousel_and_save_runner.tscn` y suite de verificación para persistencia de skins, equipamiento, billboarding 3D y layout de Cover Flow.

### Corregido
* **Blindaje Crítico de Guardado en `SaveManager`:**
  * Carga incondicional de `existing_prof = load_profile()` en `save_profile()`. Se elimina el riesgo de que llamadas parciales (fin de incursión, ajustes de velocidad de juego o compra de talentos) sobreescriban `unlocked_skins`, `equipped_skins` o `gacha_tokens` con diccionarios vacíos.
* **Profundidad y Resplandor del Carrusel de Skins de Navegantes (`NavigatorSelectionModal`):**
  * Disposición Cover Flow perfeccionada: separación negativa (`-45px`) en `CardsRow` para ubicar las cartas laterales ligeramente por detrás del círculo central.
  * Asignación jerárquica de `z_index` (`artwork_frame.z_index = 2`, cartas laterales en `0` con modulación atenuada `Color(0.75, 0.82, 0.95, 0.65)`).
  * Ocultamiento automático de los textos "ANTERIOR" / "SIGUIENTE" en modo aspectos circulares para evitar que se superpongan a los retratos de las navegantes.
  * Removido `clip_contents = true` en `ArtworkFrame` para permitir que el resplandor y halo luminoso holográfico (`shadow_size = 18`) se expanda de forma continua y suave sin cortes rectangulares en sus bordes.
* **Fallback Robusto en Selección de Personajes (`CharacterSelectUI`):**
  * Prevención de texturas nulas al equipar aspectos no cargados, garantizando la visualización continua de los sprites y retratos de cada piloto.
* **Restablecimiento Forzoso de Velocidad al Hub (1x):**
  * Al regresar al Hub desde la pantalla de selección de personajes (botón "VOLVER AL HUB" o tecla ESC), tras abandonar la run desde el menú de pausa o tras la pantalla de Game Over, `Engine.time_scale` y `SaveManager.set_game_speed()` retornan obligatoriamente a 1.0 (Normal), evitando desplazarse por el Hangar espacial en 2x o 4x.

---

## [0.4.1] - 2026-09-25 — Pantalla de Game Over, Secuencia de Muerte y Controles de Despliegue

### Añadido
* **Secuencia de Destrucción de la Nave & VFX/SFX:**
  * Al llegar a 0 HP, la nave explota con un efecto visual procedimental multi-capa (`PlayerExplosionVFX`): destello nuclear central, ondas expansivas concéntricas de plasma, fragmentos de casco con dispersión angular y chispas radiales.
  * Sonido masivo de detonación espacial (`explosion` SFX) y sacudida de pantalla con trauma de cámara.
  * Bloqueo inmediato de controles, anulación de velocidad y desactivación de colisiones de la nave.
* **Pantalla de Game Over & Telemetría Post-Incursión (`GameOverModal`):**
  * Despliegue tras pausa dramática de 1.0s con interfaz Psychopop Sci-Fi centrada.
  * **Puntuación Final:** Cálculo algorítmico basado en bajas, oleadas, jefes, créditos y tiempo de supervivencia.
  * **Indicador de Récord:** Distintivo luminoso dinámico `★ ¡NUEVO RÉCORD HISTÓRICO - TOP #1! ★` o indicador de posición en el Top 10.
  * **Métricas de Combate:** Oleadas sobrevividas, tiempo de incursión (MM:SS), jefes derrotados y bajas enemigas.
  * **Recursos Recolectados:** Biomasa extraída, antimateria/materia oscura y créditos acumulados.
  * **Carga Táctica (Loadout):** Desglose visual de Pactos Astra sellados, ítems de inventario con multiplicadores de acumulación (`x2`, `x3`) y armas desplegadas con nivel.
  * **Acciones de Fin de Partida:** Botones con soporte para atajos `[R] Reiniciar Misión` (recarga instantánea) y `[H] Volver al HUB` (retorno al Hangar 3D).
* **Despawn Inteligente de Satélites Lejanos:**
  * Desespawn automático cuando el piloto se aleja más de 10.000 px de una baliza orbital activa, liberando el slot para que una nueva baliza spawnee en la dirección de vuelo.
* **Modificadores de Velocidad en Despliegue (1x / 2x / 4x):**
  * Selector tipo radio-button integrado directamente en el Menú de Despliegue de Piloto, con hotkeys `1`, `2` y `3` y persistencia automática en el perfil de guardado.

---

## [0.4.0] - 2026-09-24 — Pre-Alpha Playtest: Jefes de Dominio, Arcanas y Hangar 3D

### Añadido
* **4 Nuevos Jefes de Dominio:**
  * Eremita del Vacío (Ola 2), Reloj de Cenizas (Ola 4), Espejo Quebrado y Vórtice del Desborde con patrones trigonométricos danmaku complejos.
* **Ecosistema de 24 Arcanas Místicas:**
  * Monolitos arcanos flotantes en el espacio que despliegan selección mística de cartas con alteración profunda de mecánicas.
* **Armamento Balístico Autónomo (Capa Pasiva Rediseñada):**
  * Misiles de trayectoria balística directa con fijación táctica inteligente y escalado 1:1 con Imán.
  * Alternador de modo en caliente [E / RB] entre apuntado automático y manual.
* **Maniobras Evasivas Avanzadas (Dashes Únicos):**
  * Habilidades evasivas diferenciadas para las 6 heroínas (Nova Omega Spin, Valentina Bullet-Time, Kira Decoy Mine, Selene Quantum Vortex, Roxy Seismic Ram, Echo Dimensional Flash).
* **Hangar Estelar 3D & Mirador Panorámico:**
  * Hub tridimensional interactivo con máquinas arcade, sala de trofeos y árbol de talentos permanente.
* **Radar Perimétrico Orbital & HUD Táctico:**
  * Indicador dinámico en los bordes de la pantalla que guía hacia satélites y monolitos lejanos y se acopla al entrar en rango.

### Corregido
* **Blindaje Total de Menús y Pausa:**
  * Resuelta la despausa prematura al cerrar arcanas en medio de subidas de nivel o menú de pausa.
  * Encolado seguro de ventanas modales de combate (`ArcanaSelectionModal`, `LevelUpModal`).

---

## [0.3.0] - 2026-09-20 — Milestone 1: Sistema de Interfaces, Navegación y QoL

### Añadido
* **Navegación Cósmica y Fondo Parallax Infinito:**
  * Implementado `SpaceBackground` (`scenes/combat/environment/space_background.tscn`) con el nodo nativo `Parallax2D` de Godot 4.3+ en 3 planos de profundidad óptica (estrellas lejanas tenues 0.12x, cúmulos medios 0.35x, estrellas brillantes 0.70x).
  * Fondo base espacial negro abisal (`Color(0.025, 0.025, 0.055, 1.0)`).
* **Cámara Inteligente Suave con Screen Shake:**
  * Componente `GameCamera2D` (`scenes/combat/environment/game_camera.gd`) con seguimiento asintótico frame-rate independent (`1.0 - exp(-speed * delta)`).
  * Sistema de Trauma Shake: sacudida reactiva al detonar bombas (`trauma = 0.6`) y al recibir impactos directos (`trauma = 0.4`).
* **Sistema de EXP Blobs con Fusión Inteligente (Blob Merging):**
  * Componente `ExpBlob` (`scenes/combat/pickups/exp_blob.tscn`) soltado por enemigos al morir con impulso radial inicial.
  * Fusión de proximidad automática ($d \le 52\text{ px}$) para evitar saturación de entidades en pantalla y mantener 60 FPS estables.
  * 4 Tiers de escalado visual y color: Cian (<45 EXP), Amatista (45–149 EXP), Oro solar (150–449 EXP) y Supernova carmesí ($\ge 450$ EXP).
  * Aspiración magnética hacia la nave del jugador con rango extendido durante el Dash.
* **Pantalla Principal (Main Menu):**
  * `scenes/ui/main_menu/main_menu.tscn`: Portada inicial del juego con botones Jugar, Configuración y Salir.
  * Configurada como escena principal de inicio (`run/main_scene`).
* **Selección de Personaje:**
  * `scenes/ui/character_select/character_select.tscn`: Roster de las 6 heroínas (**Nova, Valentina, Kira, Selene, Roxanne, Echo**).
  * Retratos con siluetas vectoriales personalizadas y paletas cromáticas temáticas.
  * Ficha de combate con desglose de estadísticas base y lore.
  * Botón de acceso directo a Custom Loadout / Banlist y botón de despegue hacia la run.
* **Menú de Pausa In-Game con Inspector de Build:**
  * `scenes/ui/pause_menu/pause_menu.tscn`: Se activa con la tecla `Escape` (`ui_cancel`).
  * Inspector en dos columnas:
    * Columna de Ítems Equipados con multiplicadores de acumulación (`x%d`) y descripciones.
    * Columna de Mejoras de Nivel (Brotato) con insignias de rareza (Común, Raro, Épico, Legendario).
  * Botones: Reanudar, Configuración, Reiniciar Run y Volver al Menú Principal.
* **Reinicio Rápido Protegido (Hold-to-Reset con tecla R):**
  * `scenes/ui/hold_to_reset_overlay.tscn`: Capa que oscurece progresivamente la pantalla durante **1.2 segundos** al mantener presionada la tecla `R`.
  * Cancelación instantánea si se suelta antes de tiempo para evitar reinicios por error.
* **Barra de Vida Flotante sobre la Nave:**
  * `scenes/combat/player/overhead_health_bar.tscn`: Barra compacta sobre el sprite del jugador con porcentaje numérico (`100%`) y cambio dinámico de color (verde $\to$ amarillo $\to$ rojo).
* **Modal de Configuración Avanzado (SettingsModal):**
  * Reorganizado en 3 pestañas completas:
    1. **Pantalla y Audio:** Selector con 9 resoluciones de pantalla incluyendo monitores Widescreen, Ultrawide 21:9 (`2560×1080`, `3440×1440`), 16:10 Steam Deck (`1280×800`) y laptops. Alternador de pantalla completa exclusiva y sliders de volumen.
    2. **Teclado y Ratón:** Interfaz interactiva de remapeo de teclas y botones del ratón en tiempo real.
    3. **Mando / Joystick:** Soporte de fábrica para gamepads USB/Bluetooth (Stick/Cruceta para movimiento y menús, R2/X para láser, A/L1 para dash, Y/B para bomba, Start para pausa) y slider de calibración de zona muerta (*Deadzone*).
  * Navegación por menús e interfaces con cruceta/stick mediante `grab_focus()`.
  * Modo de estiramiento `aspect="expand"` en `project.godot` para visualización panorámica sin barras negras.

### Corregido
* **Culling y Visibilidad de Proyectiles Danmaku:**
  * Resuelto el bug por el cual las balas se volvían invisibles según el ángulo respecto al emisor. Se configuró `mm.custom_aabb` y `canvas_item_set_custom_rect` a `[-100.000, 100.000 px]` para impedir el descarte erróneo por frustum culling del motor 2D.
  * Ampliada la distancia segura de culling a 3600 px en `bullet_server.gd`.
  * Rediseñado `danmaku_bullet.gdshader` con `render_mode unshaded` y geometría circular procedural con núcleo blanco brillante y halo de emisión lumínica (bloom).
  * Inicialización explícita de los 12 floats de matriz de transformación y custom data por proyectil en cada frame.
* **Superposición de Capas de Interfaz (Z-Order):**
  * Elevado `SettingsModal` a `layer = 45` para garantizar que al abrirse desde el menú de pausa (`layer = 30`), siempre aparezca al frente e interactuable.
* **Corrección de APIs de Tema en GDScript:**
  * Sustituido el acceso inválido `theme_override_constants.set()` por `add_theme_constant_override()` en `settings_modal.gd` y `pause_menu.gd`.

---

## [0.2.0] - 2026-09-20 — Arquetipos de Armas, Drones y Bucle In-Run

### Añadido
* **Arquetipo de Armas de Doble Capa:**
  * Haz Láser Perforante de Pantalla Completa (on-click) con cooldown reactivo en HUD e impacto geométrico punto-segmento.
  * Lanzador de Misiles Guiados Pasivo (auto-aim) con disparo 100% autónomo desde el arranque y daño radial.
* **Primer Enemigo (`EnemyDrone`):**
  * 60 HP, persecución continua del jugador, hit-flash blanco, animación de explosión al morir y enfriamiento de contacto (0.6s).
* **Generador Continuo de Enemigos (`EnemySpawner`):**
  * Spawneo de oleadas circulares fuera de pantalla escalando de 2.0s a 0.5s de intervalo.
* **Indicador de Cooldown en HUD:**
  * Etiqueta reactiva `Láser: [LISTO]` (cian) o `Láser: [X.Xs]` (naranja).
* **Narrativa In-Run con Dialogic 2.0:**
  * Caja cinemática flotante (capa 15, `mouse_filter = IGNORE`) con skip instantáneo (`Tab`) y atenuación dinámica de música con filtro Low-Pass (`audio_duck_manager.gd`).
* **Hangar y Banlist Megabonk:**
  * Matriz de baneo de ítems (máx. 5 vetos) con persistencia JSON (`save_manager.gd`).
* **Satélites, Tienda y Mazo Brotato:**
  * Balizas con zona de radar, tienda in-run con pausa y modal de 4 cartas de subida de nivel ponderadas por suerte.

---

## [0.1.0] - 2026-09-20 — Esqueleto Base y Motor Danmaku

### Añadido
* **Motor Danmaku Zero-Allocation:**
  * Arquitectura SoA con `PackedFloat32Array` y `MultiMeshInstance2D` GPU batching para 5.000 proyectiles a 60 FPS.
  * Comprobación matemática de colisión de núcleo diminuto ($\Delta x^2 + \Delta y^2 \le R^2$).
  * Detección de graze (roce de balas) y bombas de pantalla $O(1)$.
  * Patrones procedurales: espirales de Fermat y anillos radiales.
* **Contenedor Reactivo de Estadísticas:**
  * `CharacterStats` con dirty flags para recálculo bajo demanda.
* **Trazabilidad de Procs e Inventario Ilimitado:**
  * DTO `HitContext` con máscara de bits anti-bucles infinitos (`MAX_DEPTH = 4`).
  * `InventoryComponent` para acumulación ilimitada de ítems.
* **Controlador de Jugador:**
  * Movimiento omnidireccional 360°, dash con i-frames (0.25s) y detonador de bombas.
