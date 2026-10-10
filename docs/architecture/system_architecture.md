# Arquitectura del Sistema — Astra Dream

Este documento detalla la estructura desacoplada del motor de combate, ciclo de vida de nodos, gestión de modales y persistencia.

---

## 1. Orquestación de Combate (`MainGame`)

La escena de combate principal (`scenes/combat/main_game.gd`) opera como un orquestador ligero desacoplado. Delega sus funciones en subsistemas especializados:

- **`CombatSceneAssembler`**: Encargado del montaje de escena, inyección de dependencias y cableado reactivo al iniciar.
- **`CombatContext`**: Almacén desacoplado de referencias del entorno de combate (jugador, directores, fábrica).
- **`CombatWavePipeline`**: Máquina de estados que gestiona el ritmo de spawn de oleadas, temporizadores de crisis y eventos de colosos.
- **`CombatModalCoordinator`**: Cola FIFO de modales in-game (Level Up, Tienda Satelital, Selección de Arcanas) que arbitra pausas seguras.
- **`CombatSatelliteCoordinator`**: Gestión de trayectorias, distancias y aparición de estaciones orbitales interactuables.

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

---

## 4. Jerarquía de Modales (`BaseModal`)

Todo modal de UI en el juego extiende `BaseModal`:
- Debe inicializar un identificador único: `modal_token = &"nombre_del_modal"`.
- Los métodos `open_modal()` y `close_modal()` adquieren y liberan automáticamente tokens en `PauseArbitrator`.
- Prohibido manipular directamente `get_tree().paused` desde clases de modal.

---

## 5. Persistencia y Persistencia Modular

El sistema de guardado está desacoplado mediante esquemas DTO fuertemente tipados:
- Fachada principal: `SaveManager` (`core/autoloads/save_manager.gd`).
- Persistencia separada en:
  - `MetaProgressionState`: Biomasa, desbloqueos permanentes, cosméticos y árbol de talentos.
  - `ActiveRunStorage`: Estado volátil de la partida activa (armas en inventario, ítems pasivos, estadísticas de la sesión).
