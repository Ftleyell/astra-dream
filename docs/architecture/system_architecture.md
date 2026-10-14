# Arquitectura del Sistema — Astra Dream

Este documento detalla la estructura desacoplada del motor de combate, ciclo de vida de nodos, gestión de modales, HUD táctico, entorno espacial y persistencia.

---

## 1. Orquestación de Combate (`MainGame`)

La escena de combate principal (`scenes/combat/main_game.gd`) opera como un orquestador ligero desacoplado. Delega sus funciones en subsistemas especializados:

- **`CombatSceneAssembler`**: Encargado del montaje de escena, inyección de dependencias y cableado reactivo al iniciar.
- **`CombatContext`**: Almacén desacoplado de referencias del entorno de combate (jugador, directores, fábrica).
- **`CombatWavePipeline`**: Máquina de estados que gestiona el ritmo de spawn de oleadas, temporizadores de crisis y eventos de colosos.
- **`CombatModalCoordinator`**: Cola FIFO de modales in-game (Level Up, Tienda Satelital, Selección de Arcanas, Banlist) que arbitra pausas seguras.
- **`CombatSatelliteCoordinator`**: Gestión de trayectorias, distancias y aparición de estaciones orbitales interactuables.
- **`SpaceEnvironmentHost`**: Anfitrión desacoplado de fondo cósmico (`scenes/combat/environment/space_environment_host.gd`). Conecta e intercambia plug & play el entorno visual, instanciando por defecto [`CosmosCombatEnvironment`](../scenes/combat/environment/cosmos_combat_environment.gd), gobernando transiciones de bioma e inyectando de forma determinista la semilla `run_seed`.
- **`RunStateSerializer`**: Serializa y restaura `run_seed`, inventario, armas y estado de partida activa.

---

## 2. Contrato de Daño y Combate (`HitContext`)

Todo intercambio de daño en el juego obedece al contrato formalizado en `HitContext`:

- Toda entidad destructible implementa:
  ```gdscript
  func take_damage(context: HitContext) -> void:
  ```
- **Regla Cero Balística:** Todo proyectil hijo generado por efectos en cadena (shrapnel, split, rebote) debe asignar `proc_coefficient = 0.0` para impedir bucles infinitos de activación.
- El jugador procesa el daño a través de `PlayerDamageProcessor`, garantizando la ejecución de mitigación de armadura, invulnerabilidad post-daño y **One-Shot Protection (OSP)** si la salud supera el umbral crítico configurado.

---

## 3. Arquitectura de Proyectiles Masivos (`BulletServer`)

Para soportar miles de proyectiles simultáneos a 60+ FPS sin presión sobre el Garbage Collector:

- Los proyectiles se almacenan en búferes lineales (`PackedFloat32Array`) gestionados por `BulletServer`.
- Prohibido instanciar `Area2D` individuales para proyectiles enemigos masivos.
- Las colisiones se procesan vectorialmente por lotes contra la hitbox central del jugador (`core_hitbox`).
- `BulletServer` opera en el espacio absoluto de `GameplayWorld`. Para prevenir desincronizaciones físicas en el búfer contiguo, `FloatingOriginTracker` está estrictamente inhabilitado durante el combate.

---

## 4. Jerarquía de Modales (`BaseModal`)

Todo modal de UI en el juego extiende `BaseModal`:
- Debe inicializar un identificador único: `modal_token = &"nombre_del_modal"`.
- Los métodos `open_modal()` y `close_modal()` adquieren y liberan automáticamente tokens en `PauseArbitrator`.
- Prohibido manipular directamente `get_tree().paused` desde clases de modal.

---

## 5. HUD Táctico y Radares de Combate

El HUD (`scenes/ui/hud/hud.gd`) es una fachada modular que coordina múltiples controladores especializados:
- **`HUDEdgeTrackerManager`**: Proyecta indicadores perimétricos para jefes (`BossEdgeIndicator`) y cofres interactivos (`ChestEdgeIndicator`).
- **`HUDDragonRadarDisplay`**: Miniradar esférico táctico con shader CRT (`dragon_radar_screen.gdshader`) y blips direccionales para entidades celestiales y balizas.
- **`HUDSatelliteRadarController`**: Detección y guía hacia estaciones orbitales y tiendas.
- **`HUDCombatStatsDockController`**: Visualización reactiva en tiempo real de estadísticas de combate del jugador.

---

## 6. Persistencia y Guardado Modular

El sistema de guardado está desacoplado mediante esquemas DTO fuertemente tipados:
- Fachada principal: `SaveManager` (`core/autoloads/save_manager.gd`).
- Persistencia separada en:
  - `MetaProgressionState`: Biomasa, desbloqueos permanentes, cosméticos y árbol de talentos.
  - `ActiveRunStorage`: Estado volátil de la partida activa (armas en inventario, ítems pasivos, estadísticas de la sesión, `run_seed`).
  - `SettingsManager`: Ajustes de usuario, buses de audio y perfiles gráficos (`space_background_quality`).
