# Servicios Globales (Autoloads) y EventBus

Astra Dream cuenta con 7 Autoloads canónicos registrados en `project.godot`. Cada uno posee una responsabilidad única y aislada.

---

## 1. Catálogo de Autoloads

| Autoload | Ubicación | Responsabilidad Principal |
|---|---|---|
| **`PauseArbitrator`** | `core/autoloads/pause_arbitrator.gd` | Gestión de tokens de pausa concurrentes. El árbol sólo se despausa cuando el recuento de tokens activos llega a 0. |
| **`SettingsManager`** | `core/autoloads/settings_manager.gd` | Almacena y aplica configuraciones de resolución, pantalla completa, volumen de buses y accesibilidad. |
| **`SaveManager`** | `core/autoloads/save_manager.gd` | Fachada que encapsula la serialización JSON / binaria y delega en subsistemas de persistencia DTO. |
| **`DebugManager`** | `core/autoloads/debug_manager.gd` | Provee utilidades de inspección, hotkeys de desarrollo y garantiza la eliminación de debug en builds de producción. |
| **`EventBus`** | `core/autoloads/event_bus.gd` | Bus de señales central desacoplado para comunicación entre escenas sin referencias cruzadas. |
| **`AudioManager`** | `core/autoloads/audio_manager.gd` | Manejo de pistas musicales interactivas, volumen adaptativo, mitigación de fatiga acústica y reproducción de SFX. |
| **`SceneTransition`** | `core/autoloads/scene_transition.gd` | Administra cortinillas de transición y fundidos entre el Hub 3D, Selección de Personaje y Combate. |

> **Nota:** `BulletServer` no es un Autoload; es un nodo de procesamiento instanciado dentro del árbol de combate (`MainGame`).

---

## 2. Bus de Señales (`EventBus`)

El `EventBus` (`core/autoloads/event_bus.gd`) expone las siguientes señales globales de alto nivel:

- **Progresión y Subida de Nivel:**
  - `level_up_offered(level: int)`: Emitida cuando se ofrece una selección de subida de nivel al jugador.
  - `level_up_selected(stat_card: StatCardData)`: Emitida al elegir una carta de estadística en el modal de subida de nivel.
  - `arcana_orb_collected(orb: Node2D)`: Emitida al recolectar un orbe arcano en el campo.
- **Satélites y Economía en Partida:**
  - `satellite_planted(satellite_index: int, position: Vector2)`: Emitida cuando se despliega una baliza/satélite en el mundo.
  - `satellite_exited(satellite_index: int)`: Emitida al abandonar o cerrar la interacción con un satélite.
  - `run_currency_changed(new_amount: int)`: Notifica cambios en el saldo de monedas de la partida activa.
- **Combate, Jefes y Ciclo de Vida:**
  - `boss_spawn_requested(timeline_id: String, boss_id: String, is_secret: bool)`: Solicita la aparición de un jefe de dominio o encuentro secreto.
  - `boss_defeated(boss_id: String)`: Notifica la derrota de un jefe activo.
  - `enemy_killed(enemy_type: String)`: Emitida al eliminar una entidad hostil estándar.
  - `player_died()`: Notifica la caída del jugador para disparar la secuencia cinemática de fin de partida.
