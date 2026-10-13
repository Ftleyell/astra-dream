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
     - Campo estelar 8K (`CanvasLayer` -105)
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
  var env_host: SpaceEnvironmentHost = main_game.space_environment_host
  var host_ctrl: CosmosHostController = env_host.get_cosmos_controller()
  ```
- Todas las consultas sobre órbitas, slots y posiciones deben realizarse a través de `host_ctrl` o su `CosmosOrbitalSlotTracker` fuertemente tipado.
