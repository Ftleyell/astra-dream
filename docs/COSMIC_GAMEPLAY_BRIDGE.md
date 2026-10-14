# Puente de Integración Cosmos Engine <-> Gameplay World (Astra Dream)

## 1. Modelo de Capas y Árbol de Escenas
En combate (`main_game.tscn`), conviven dos espacios con naturalezas y scrolls distintos:

1. **`GameplayWorld` (Capa de Juego Directa, Scroll 1.0):**
   - Aloja entidades físicas con hurtboxes y colisiones: `Player`, `Planet` (destructibles), `Satellite` (balizas/tiendas), proyectiles (`BulletServer`), enemigos y drops.
   - Todo lo que reside aquí se mueve y colisiona en coordenadas del mundo de Godot.
2. **`CosmosEngine` (Entorno de Fondo, Multicapa Parallax2D):**
   - Aloja elementos de fondo no colisionables en múltiples estratos de profundidad:
     - Nebulosa (`CanvasLayer` -100)
     - Galaxias macro (`Parallax2D`, scroll 0.1)
     - Campo estelar 8K (`CanvasLayer` -105, desconectable según perfil de GPU)
     - Sistemas Solares (`Parallax2D`, scroll 1.0 o configurado en perfil)
     - Cinturón de escombros (`Parallax2D`, scroll 0.25)

---

## 2. Regla de Oro de Paternidad de Nodos (Anti-Reparenting)
- **PROHIBIDO reparentar nodos de Gameplay adentro de capas de Parallax de Cosmos Engine.**
- Si una entidad de juego necesita proyectar un efecto visual (como una sombra cósmica) o seguir un objeto de fondo (como un satélite orbitando un planeta):
  - **Sigue existiendo como hija de GameplayWorld.**
  - Para sincronizar movimiento con Parallax se utiliza el componente [`OrbitalWorldFollower2D`](res://scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd), el cual compensa matemáticamente el drag de la cámara y proyecta el slot analítico a coordenadas de Gameplay sin cambiar de padre.
  - Para renderizar sombras sobre el juego, el componente visual reside en el árbol de GameplayWorld con su propio shader de blend (`blend_mix` o `blend_mul`) sin invadir el `CosmicShadowsGroup` del fondo.

---

## 3. Contrato de Acceso Canónico (Anti Duck-Typing)
- **PROHIBIDO el uso de `find_child`, `has_method` o llamadas dinámicas con `call()`** para comunicarse entre entidades de juego y Cosmos Engine.
- La vía canónica tipada de acceso es siempre:
  ```gdscript
  var env_host: SpaceEnvironmentHost = main_game.environment_host
  var host_ctrl: CosmosHostController = env_host.get_cosmos_controller()
  ```
- Todas las consultas sobre órbitas, slots y posiciones deben realizarse a través de `host_ctrl` o su `CosmosOrbitalSlotTracker` fuertemente tipado.
- Para localizar el nodo raíz de Cosmos desde componentes desacoplados en el SceneTree, consultar el grupo global:
  ```gdscript
  var cosmos_root: CosmosRootNode = get_tree().get_first_node_in_group(&"cosmos_root") as CosmosRootNode
  ```

---

## 4. Slots Orbitales Matemáticos Puros (Value Objects)
- `CosmosOrbitSlot` no contiene referencias vivas a nodos (`body_reference` eliminado). Es un *Value Object* que evalúa en $\mathcal{O}(1)$ la posición en capa en función del tiempo global:
  ```gdscript
  var layer_pos: Vector2 = slot.calculate_layer_position(t_global)
  ```
- Para slots planetarios, combina analíticamente la posición estelar central, la órbita del planeta anfitrión y la órbita relativa del satélite.

---

## 5. Anti-Snapping en Parallax Drag
- Cuando una baliza o satélite congela el arrastre de paralaje (`freeze_parallax_drag = true`), `OrbitalWorldFollower2D` captura la posición de la cámara y bloquea la compensación instantáneamente.
- Al salir del radio de interacción (`freeze_parallax_drag = false`), la posición de la cámara compensada interpola suavemente hacia la cámara activa a lo largo de $0.4\,\text{s}$ mediante `move_toward(_freeze_weight, 0.0, delta / 0.4)` y `cam_pos = real_cam.lerp(_frozen_camera_pos, _freeze_weight)`, eliminando cualquier salto brusco o vibración visual.
