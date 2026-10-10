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

El `EventBus` expone señales desacopladas categorizadas:

- **Ciclo de Partida y Oleadas:**
  - `run_started`: Emitida al arrancar una incursión.
  - `wave_completed(wave_index: int)`: Fin de oleada estándar.
  - `boss_spawned(boss_node: Node2D)`: Inicio de combate contra coloso o rival.
  - `player_died`: Notifica la caída del jugador para disparar la secuencia cinemática.
- **Economía y Modificadores:**
  - `credits_updated(new_total: int)`: Cambio en saldo de créditos in-run.
  - `biomass_collected(amount: int)`: Obtención de recurso meta permanente.
  - `arcana_acquired(arcana_data: Resource)`: Inyección de modificación de reglas.
- **HUD e Interfaz:**
  - `satellite_approaching(distance: float)`: Proyección en radar del satélite más cercano.
  - `emergency_alert_triggered(title: String, duration: float)`: Alertas sensoriales en pantalla.
