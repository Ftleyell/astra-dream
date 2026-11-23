# Plan de Implementación Detallado — Sistema de Bifurcaciones de Run (In-Run Decisions)
> **Astra Dream** · Milestone M7 (Balance Fino) · Godot 4.7.2 · Arquitectura Data-Driven Zero-Friction

---

## 1. Contexto y Objetivos

Este documento contiene la guía técnica paso a paso para implementar en una nueva sesión el **Sistema de Bifurcaciones de Run** (*Run Fork Decisions*). 

### Pilares de Diseño Acordados:
1. **Corte y Drenado de Oleada (*Wave Drain*):** Al terminar el temporizador de la oleada, se detiene el spawn de nuevos enemigos, se eliminan (*culling*) instantáneamente enemigos y balas *off-screen*, y el jugador elimina a los restantes en pantalla sin restricciones de disparo ni habilidades. Los enemigos que salgan del área visible se despawnean de inmediato.
2. **Frenado en Seco Inicial (~0.4 s):** Al quedar la pantalla limpia de enemigos (`enemies_on_screen == 0`), la nave se frena a velocidad 0 de golpe (evitando pasarse de largo) y se registra su posición como punto de ancla ($P_0$).
3. **Despliegue y Navegación Minimalista:** Aparecen 4 tarjetas placeholder en las 4 esquinas del HUD. El jugador recupera locomoción de inmediato. Al orientarse y moverse hacia una esquina, esa tarjeta se agranda progresivamente ($1.0\times \to 1.25\times$) y las otras 3 se achican ($1.0\times \to 0.7\times$). Si regresa al centro, las escalas se neutralizan.
4. **Umbral Dinámico Normalizado por Velocidad:** La distancia de confirmación escala según la velocidad de la nave:
   $$D_{\text{threshold}} = T_{\text{decision}} \times V_{\text{player\_speed}} \quad (T_{\text{decision}} \approx 0.8\,\text{s})$$
5. **Transición Fluida (~0.5 s):** Al cruzar el umbral, la tarjeta elegida destella con SFX de confirmación, las otras 3 se desvanecen, se aplican sus efectos polimórficos (`RunEffect`), se registra en persistencia y comienza la siguiente oleada.
6. **Cero Fricción para Nuevas Mecánicas:** Patrón Command polimórfico con recursos `.tres` (`RunEffect`), inyección de `CombatContext` y un efecto genérico de mutación de propiedades (`GenericPropertyRunEffect`).

---

## 2. Mapa de Archivos a Crear y Modificar

```
astra_dream/
├── core/data/run_forks/
│   ├── run_effect.gd                               <- Clase base abstracta de efectos (Resource)
│   ├── run_fork_option_data.gd                     <- Definición de carta de bifurcación (Resource)
│   └── effects/
│       ├── biome_change_run_effect.gd              <- Conmuta bioma cósmico en SpaceEnvironmentHost
│       ├── enemy_spawn_run_effect.gd               <- Modifica spawn rate, vida de enemigos, oro
│       ├── player_stat_run_effect.gd               <- Buffs de velocidad, daño, escudo, etc.
│       ├── satellite_spawn_run_effect.gd           <- Despliega satélites/estaciones de inmediato
│       └── generic_property_run_effect.gd          <- Modifica cualquier variable por clave tipada
├── resources/run_forks/starter/
│   ├── fork_hostile_storm.tres                     <- Carta 1: +Spawns, +Oro
│   ├── fork_sector_jump.tres                       <- Carta 2: Cambio de bioma
│   ├── fork_hyper_propulsion.tres                  <- Carta 3: +Velocidad por 2 oleadas
│   └── fork_orbital_beacon.tres                    <- Carta 4: Baliza satelital
├── scenes/combat/
│   ├── systems/
│   │   ├── run_modifier_manager.gd                 <- Almacena modificadores activos y consultas
│   │   └── run_state_serializer.gd                 <- [Modificación] Serializa modificadores activos
│   ├── directors/
│   │   ├── combat_fork_director.gd                 <- Orquestador del ciclo de drenado y bifurcación
│   │   └── combat_wave_pipeline.gd                 <- [Modificación] Hook de transición pre-bifurcación
│   ├── enemies/
│   │   └── enemy_spawner.gd                        <- [Modificación] Soporte para culling y multipliers
│   └── ui/
│       ├── run_fork_overlay.gd & .tscn             <- CanvasLayer con lógica de cuadrantes y escala
│       └── components/
│           └── fork_choice_card.gd & .tscn         <- Componente visual individual de cada esquina
└── tests/unit/
    └── test_run_fork_system.gd                     <- Suite de pruebas automatizadas
```

---

## 3. Plan Paso a Paso de Implementación

### Fase 1: Recursos Data-Driven y Efectos Polimórficos

#### 1.1 `core/data/run_forks/run_effect.gd`
- Hereda de `Resource`.
- Declara `class_name RunEffect`.
- Propiedades:
  - `@export var effect_name: String = ""`
  - `@export var duration_waves: int = -1` (-1 = permanente toda la run, >0 = número de oleadas).
- Métodos virtuales con tipado estricto:
  - `func apply_effect(context: CombatContext) -> void: pass`
  - `func revert_effect(context: CombatContext) -> void: pass`
  - `func on_wave_tick(context: CombatContext, delta: float) -> void: pass`
  - `func on_enemy_spawned(enemy: Node2D, context: CombatContext) -> void: pass`
  - `func get_modifier_value(stat_key: StringName, base_val: float) -> float: return base_val`

#### 1.2 `core/data/run_forks/run_fork_option_data.gd`
- Hereda de `Resource`.
- Declara `class_name RunForkOptionData`.
- Propiedades:
  - `@export var id: StringName = &""`
  - `@export var title: String = ""`
  - `@export_multiline var description: String = ""`
  - `@export var icon: Texture2D = null`
  - `@export var rarity: int = 0` (0=Common, 1=Rare, 2=Epic, 3=Legendary)
  - `@export var weight: float = 100.0`
  - `@export var min_wave: int = 1`
  - `@export var max_wave: int = 999`
  - `@export var effects: Array[RunEffect] = []`

#### 1.3 Subclases Iniciales de `RunEffect`
- **`BiomeChangeRunEffect`:** Llama a `context.environment_host.change_region(target_region_id, blend_duration)`.
- **`EnemySpawnRunEffect`:** Modifica multiplicadores consultables en `RunModifierManager` (`spawn_multiplier`, `health_multiplier`, `gold_multiplier`).
- **`PlayerStatRunEffect`:** Aplica bonus porcentual o plano a atributos en `player.locomotion_controller` o `player.damage_processor`.
- **`SatelliteSpawnRunEffect`:** Invoca `context.satellite_coordinator.spawn_satellite_beacon(...)`.
- **`GenericPropertyRunEffect`:** Almacena `system_tag: StringName`, `property_key: StringName`, `value: Variant`, `operation: int (ADD, MULTIPLY, SET)`.

#### 1.4 Recursos `.tres` Starter
- Crear en `resources/run_forks/starter/`:
  - `fork_hostile_storm.tres`
  - `fork_sector_jump.tres`
  - `fork_hyper_propulsion.tres`
  - `fork_orbital_beacon.tres`

---

### Fase 2: Gestor de Modificadores en Runtime

#### 2.1 `scenes/combat/systems/run_modifier_manager.gd`
- Hereda de `CombatSubsystem` (o `Node`).
- `class_name RunModifierManager`.
- Mantiene:
  - `var active_modifiers: Array[RunForkOptionData] = []`
  - `var modifier_wave_durations: Dictionary = {}` (instancia_id -> oleadas_restantes).
- Métodos:
  - `func register_fork_choice(option: RunForkOptionData) -> void`: Registra la carta, ejecuta `apply_effect()` en cada efecto y almacena su duración.
  - `func on_wave_completed(wave_idx: int) -> void`: Decrementa duraciones; si expira, ejecuta `revert_effect()` y elimina el modificador.
  - `func get_total_float_modifier(stat_key: StringName, default_value: float = 1.0) -> float`: Itera sobre los efectos activos y acumula multiplicadores o sumas.
  - `func notify_enemy_spawned(enemy: Node2D) -> void`: Propaga el hook a todos los efectos activos.
  - `func serialize_active_modifiers() -> Array[Dictionary]` y `restore_active_modifiers(data: Array)`.

#### 2.2 Integración en `RunStateSerializer`
- Añadir campo `"run_modifiers"` en el guardado de `active_run`.
- Al reanudar run, llamar a `run_modifier_manager.restore_active_modifiers(...)`.

---

### Fase 3: Culling Off-Screen y Drenado en Combate

#### 3.1 Culling en `EnemySpawner` (`scenes/combat/enemies/enemy_spawner.gd`)
- Implementar función:
  ```gdscript
  func despawn_offscreen_enemies(camera_viewport_rect: Rect2, margin: float = 120.0) -> int:
      var expanded_rect: Rect2 = camera_viewport_rect.grow(margin)
      var culled_count: int = 0
      for enemy in get_tree().get_nodes_in_group(&"enemies"):
          if is_instance_valid(enemy) and not expanded_rect.has_point(enemy.global_position):
              enemy.queue_free()
              culled_count += 1
      return culled_count
  ```
- Método para consultar enemigos activos en pantalla:
  ```gdscript
  func get_onscreen_enemy_count(camera_viewport_rect: Rect2, margin: float = 60.0) -> int
  ```

#### 3.2 Culling en `BulletServer`
- Invocar limpieza de proyectiles de enemigos que estén fuera del viewport visible sin alterar el pool contiguo de balas del jugador.

---

### Fase 4: Director de Bifurcaciones (`CombatForkDirector`)

#### 4.1 `scenes/combat/directors/combat_fork_director.gd`
- Hereda de `CombatSubsystem`.
- `class_name CombatForkDirector`.
- Estados (`enum State { IDLE, DRAINING_WAVE, CINEMATIC_BRAKE, SELECTING_FORK, CONFIRMING }`).
- Lógica de estados:
  1. **`start_wave_drain()`:**
     - Disparado cuando `wave_timer <= 0.0` en `CombatWavePipeline`.
     - `enemy_spawner.is_spawning_enabled = false`.
     - Ejecuta `enemy_spawner.despawn_offscreen_enemies(get_camera_rect())`.
     - Pasa a `DRAINING_WAVE`.
  2. **`_process_draining_wave(delta)`:**
     - Si algún enemigo sale del área visible durante esta fase, se despawnea de inmediato.
     - Verifica si `enemy_spawner.get_onscreen_enemy_count(...) == 0`.
     - Al llegar a 0, transiciona a `CINEMATIC_BRAKE`.
  3. **`_enter_cinematic_brake()`:**
     - Frena en seco al jugador:
       ```gdscript
       if context.player and context.player.locomotion_controller:
           context.player.locomotion_controller.velocity = Vector2.ZERO
       ```
     - Registra `anchor_position = context.player.global_position`.
     - Sortea 4 cartas del pool disponible según pesos y oleada.
     - Abre `run_fork_overlay.present_choices(choices)`.
     - Breve timer de transición (~0.4 s) antes de pasar a `SELECTING_FORK`.
  4. **`_process_selecting_fork(delta)`:**
     - Calcula $\vec{\Delta} = P_{\text{player}} - P_0$.
     - Determina cuadrante y calcula $D = \|\vec{\Delta}\|$.
     - Calcula $D_{\text{threshold}} = 0.8 \times \text{player\_speed}$.
     - Notifica a `run_fork_overlay.update_displacement(delta_vector, d_threshold)`.
     - Si $D \ge D_{\text{threshold}}$, fija la elección y transiciona a `CONFIRMING`.
  5. **`_enter_confirming(choice)`:**
     - Dispara SFX y flash en la tarjeta elegida; oculta las otras 3.
     - Tras ~0.5 s:
       - Llama a `run_modifier_manager.register_fork_choice(choice)`.
       - Emite señal `fork_selection_completed`.
       - Reanuda el spawner y avanza a la siguiente oleada.

#### 4.2 Conexión con `CombatWavePipeline`
- En `combat_wave_pipeline.gd`:
  - Cuando `wave_timer <= 0.0`: en lugar de avanzar directamente con `_complete_and_advance_wave()`, emite `wave_completed_drain_requested` o delega en `CombatForkDirector`.
  - La llamada final a `_advance_wave()` se ejecuta una vez recibido `fork_selection_completed`.

---

### Fase 5: Capa Visual y Componentes HUD

#### 5.1 Componente `ForkChoiceCard` (`scenes/combat/ui/components/fork_choice_card.tscn` / `.gd`)
- Jerarquía: `PanelContainer` con `TextureRect` (icono placeholder), `Label` (título en negrita), `Label` (descripción), borde destacado.
- Métodos:
  - `setup_data(data: RunForkOptionData) -> void`
  - `set_focus_ratio(ratio: float) -> void`: Interpola escala entre $1.0\times$ (neutral) y $1.25\times$ (enfoque máximo) o $0.7\times$ (desenfoque).
  - `play_confirm_animation() -> void`
  - `play_dismiss_animation() -> void`

#### 5.2 Overlay `RunForkOverlay` (`scenes/combat/ui/run_fork_overlay.tscn` / `.gd`)
- `CanvasLayer` con 4 anclas configuradas en las 4 esquinas:
  - `TopRightContainer` (Cuadrante 1: `x > 0, y < 0`)
  - `TopLeftContainer` (Cuadrante 2: `x < 0, y < 0`)
  - `BottomLeftContainer` (Cuadrante 3: `x < 0, y > 0`)
  - `BottomRightContainer` (Cuadrante 4: `x > 0, y > 0`)
- Procesa el vector direccional y actualiza los `set_focus_ratio()` de las 4 tarjetas con un `Tween` suave de respuesta ágil.

---

### Fase 6: Suite de Pruebas Automatizadas

#### 6.1 `tests/unit/test_run_fork_system.gd`
- Hereda de `BaseTestSuite`.
- Casos de prueba requeridos:
  1. `test_fork_choice_draw_weighted()`: Verifica que el sorteo respete pesos y restricciones de oleada mínima/máxima.
  2. `test_distance_threshold_speed_normalization()`: Verifica que naves con distinta velocidad calculen un $D_{\text{threshold}}$ proporcional a su velocidad base.
  3. `test_run_modifier_manager_lifecycle()`: Registra modificadores permanentes y temporales; comprueba que tras $N$ oleadas los temporales se reviertan y los permanentes persistan.
  4. `test_biome_change_effect_execution()`: Comprueba que `BiomeChangeRunEffect` invoque correctamente `change_region` sin errores de nulos.
  5. `test_culling_offscreen_enemies()`: Simula enemigos dentro y fuera de un `Rect2` de cámara y verifica que solo los exteriores sean purgados.

#### 6.2 Comando de Verificación PowerShell
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "run_fork"
```

---

## 4. Guía Rápida para el Agente en la Nueva Sesión

Al abrir la nueva sesión para implementar este sistema, seguir esta lista de verificación:

1. [ ] **Leer `AGENT_CONTEXT.md`** y comprobar estado del repositorio.
2. [ ] **Crear la capa de datos:** `run_effect.gd`, `run_fork_option_data.gd` y los 5 efectos concretos.
3. [ ] **Crear las 4 cartas starter `.tres`** en `resources/run_forks/starter/`.
4. [ ] **Crear `RunModifierManager`** y añadir métodos de consulta en `EnemySpawner` y `SpaceEnvironmentHost`.
5. [ ] **Implementar `CombatForkDirector`** y conectarlo con `CombatWavePipeline`.
6. [ ] **Crear la UI de HUD:** `ForkChoiceCard` y `RunForkOverlay`.
7. [ ] **Crear y ejecutar la suite de pruebas unitarias:** `tests/unit/test_run_fork_system.gd`.
8. [ ] **Verificar con el arnés:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "run_fork"`.
9. [ ] **Verificación integral de regresión:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly`.
