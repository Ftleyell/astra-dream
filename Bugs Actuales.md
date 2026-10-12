# Diagnóstico de Bugs Actuales: Sistemas Solares, Órbitas, Satélites y Planetas

Fecha: 12 de Octubre de 2026
Estado: Análisis Profundo y Diagnóstico de Causa Raíz

---

## 1. Problema: El Satélite "escapa" y se reposiciona constantemente

### Síntoma Observado
Al intentar aproximarse a una baliza satelital (`SatelliteBeacon`) o estación de transmutación (`TransmutationStation`), la entidad parece "escapar" o cambiar de lugar de forma abrupta cada pocos segundos, haciendo imposible alcanzarla.

### Causa Raíz Técnica
1. **El Odómetro opera ciego a la presencia de un satélite activo:**
   * En `scenes/combat/satellite/components/satellite_odometer.gd`, la distancia requerida base es de solo **1200 px** ($\approx 2.0$ segundos de vuelo de la nave a velocidad de combate de 600 px/s).
   * En `scenes/combat/systems/combat_satellite_coordinator.gd`, la función `_is_player_interacting_with_satellite()` solo detiene la acumulación del odómetro si el jugador ya está a **menos de 1200 px** del satélite o dentro de su perímetro.
2. **Ciclo de Destrucción Prematura (`queue_free`):**
   * Si un satélite aparece a 1800 px del jugador, la condición de interacción devuelve `false`.
   * El jugador vuela hacia él. Tras recorrer 1200 px (cuando el jugador está a solo 600 px de alcanzarlo), el odómetro alcanza el umbral y emite la señal `required_distance_reached`.
   * Esta señal invoca `spawn_next_satellite_ahead()` -> `spawn_next_satellite()`.
   * En `spawn_next_satellite()`, el código ejecuta:
     ```gdscript
     if current_satellite and is_instance_valid(current_satellite):
         current_satellite.queue_free() # Destruye el satélite existente
     ```
   * **Consecuencia:** El satélite que el jugador estaba a punto de alcanzar es destruido y reemplazado por uno nuevo generado en otra posición más adelante.
   * Este ciclo se repite cada $\approx 2$ segundos, creando la ilusión óptica de que el satélite se "teletransporta" y escapa continuamente.

---

## 2. Problema: Los Planetas flotan en cualquier parte del vacío

### Síntoma Observado
Los planetas destruibles (`Planet`) aparecen aislados en el vacío, sin que se aprecie ninguna estrella o sol cercano que justifique su órbita.

### Causas Raíces Técnicas
1. **Radio Orbital Descomunal frente a la Resolución de Pantalla:**
   * En `scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd`:
     ```gdscript
     var slot_radius: float = maxf(bounding_r * 1.15, 3200.0)
     ```
   * La resolución del viewport es de $1920 \times 1080\text{ px}$.
   * Un radio orbital de **3200 px** sitúa al planeta destruible a más de 3 pantallas completas de distancia de la estrella anfitriona.
   * Cuando el jugador vuela y se encuentra con el planeta, la estrella está completamente fuera del campo de visión, haciendo que el planeta parezca flotar en la nada.
2. **Generación Ciega Inicial en `_spawn_initial_test_planet`:**
   * En `scenes/combat/environment/planet_spawner.gd`:
     `initial_discovery_bonus` está activo por defecto (`true`).
   * En el frame 0, si el streaming de Cosmos Engine aún no tiene una celda estelar inicializada, el spawner cae en el fallback ciego:
     ```gdscript
     var preferred_pos := center + Vector2(1700.0, -400.0)
     _instantiate_planet_at(preferred_pos)
     ```
     Instanciando un planeta huérfano en el vacío sin ninguna relación con un sistema estelar.
3. **Desfase de Origen entre el MacroGrid y el Jugador:**
   * El jugador inicia en $(960, 540)$.
   * Las celdas del `CosmosMacroGrid` son de $7500 \times 7500\text{ px}$, con el centro de la celda (0,0) en $(3750, 3750)$.
   * La estrella de la celda inicial se encuentra a más de $4200\text{ px}$ de la nave, fuera del rango visual de inicio.

---

## 3. Problema: Desacoplamiento Espacial entre Parallax2D y GameplayWorld

### Causa Raíz Técnica
* En Godot 4, los nodos hijos de un `Parallax2D` no mueven su `global_position` en el árbol de escena; el motor aplica su desplazamiento de paralaje a través del `RenderingServer` dentro del CanvasItem.
* Si entidades interactivas con físicas de `GameplayWorld` intentan seguir las coordenadas internas de los cuerpos de `Parallax2D`, se genera un desfase visual y cinemático entre lo que se dibuja en pantalla y las coordenadas lógicas de combate.

---

## 4. Plan Maestro Blindado de Solución

1. **Blindaje del Ciclo de Vida del Satélite:**
   * Mientras `current_satellite` exista y sea válido en la escena, el odómetro debe quedar estrictamente congelado (`distance_traveled = 0.0`).
   * Prohibir terminantemente que el odómetro o timers de avance invoquen `queue_free()` sobre un satélite activo no completado.
   * El satélite solo debe ser reemplazado o despawneado tras ser completado en tienda o si el jugador se aleja más de $12.000\text{ px}$ de abandono.

2. **Ajuste de Escala y Radios Orbitales Visibles:**
   * Reducir el radio orbital de los planetas destruibles respecto a su estrella anfitriona a un rango de **$1300\text{ a }1700\text{ px}$**, garantizando que la estrella permanezca en la periferia visible de la arena de combate.
   * Eliminar el fallback ciego de `_spawn_initial_test_planet()` en el vacío.

3. **Anclaje Físico Directo en GameplayWorld:**
   * Los satélites orbitan directamente al `Planet` de combate o al centro absoluto de la estrella en coordenadas puras de `GameplayWorld` usando el componente modular `CelestialOrbitAnchor2D`, sin depender de transformaciones de nodos hijos de `Parallax2D`.
   * Los sistemas solares de combate se posicionan de modo que el sector inicial contenga la estrella de referencia dentro del área de influencia de la nave.
