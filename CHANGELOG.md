# Changelog — Astra Dream

Todos los cambios notables en este proyecto serán documentados en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

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
