# Pendientes de Desarrollo y Pulido — Astra Dream

Estado y registro de tareas pendientes organizadas por niveles de prioridad y costo de tokens.

---

## 🟢 Nivel 1 — Pulido Rápido & Micro-Fixes (COMPLETADO)
- [x] **Cofre en Overworld:** Ocultar el icono del ítem en el pickup físico (`rival_weapon_pickup.gd`) para mantener la sorpresa en el modal.
- [x] **Precio de Cofres:** Píldora cyberpunk con moneda oficial (`credit_coin_icon.png`, 22x22px), texto numérico legible (16px con sombra) y soporte de `"GRATIS"` / faltan créditos.
- [x] **HUD Armas y Tomos:** Ranuras de armas ampliadas a 54x54 y tomos a 40x40 (`hud_inventory_bar_controller.gd`).
- [x] **Arcana Card Builder:** Altura de título estandarizada a 48px con centrado vertical para alinear perfectamente las ilustraciones (`arcana_card_builder.gd`).
- [x] **Indicador de Maldición en HUD:** Separación respecto a llaves (8px), eliminación de emoji y formato limpio `MALDICIÓN +X PTS` (`hud.gd` / `hud.tscn`).
- [x] **Layering de Transición de Pantalla:** Elevada `SceneTransition` a `layer = 150` para tapar de forma absoluta dock de stats, menú de pausa y modales durante cambios de escena.

---

## 🟡 Nivel 2 — Pulido de Modales & Navegación (COMPLETADO)
- [x] **UI de Tienda de Satélite (`satellite_shop.tscn` / `.gd` / `satellite_shop_card_builder.gd`):**
  - Header de créditos centrado arriba de todo con el estilo oficial del HUD (`CreditsCard` con icono de moneda y texto dorado grande).
  - Formato de tarjetas estilo `LevelUpModal` con iconos grandes de 80x80px con marco de rareza, información limpia y badges métricos.
  - Botón de compra interactivo derecho con moneda oficial (`🪙 X`) y atajos `[TECLA 1, 2, 3]`.
  - Navegación natural con `W/S` (vertical entre ofertas), `A/D` (horizontal entre Reroll y Cerrar), y atajos con `Espacio/Enter` que compran o cierran al quedarse sin fondos.
- [x] **UI de Reemplazo de Armas (`weapon_swap_modal.gd`):**
  - Panel superior destacado con el arma entrante en icono de 80x80px y desglose métrico.
  - Fila horizontal con las 4 armas en iconos de 80x80px: ranura 1 insignia bloqueada (fuera del ciclo de foco, tecla 1 ignorada silenciosamente) y ranuras 2 a 4 con comparativa de stats en verde/rojo.
  - Navegación fluida con `A/D`, tecla `S` para descender a Descartar, `W` para regresar, y atajos directos `2, 3, 4` y `ESC`.

---

## 🟠 Nivel 3 — Actualización de Carteles y Pantallas (COMPLETADO)

- [x] **Carteles de Vencer Rivales (`hud_banner_manager.gd`, `hud.gd`, `combat_boss_coordinator.gd`):**
  - Banner táctico cinematográfico horizontal (660x110px) en la parte superior sin pausar el combate ni interrumpir controles.
  - Marco con color de tema distintivo de la rival (`PILOT_COLORS`), retrato de 64x64px a la izquierda, título holográfico `"⚡ OBJETIVO NEUTRALIZADO // PILOTO RIVAL ABATIDA"` y nombre destacado (20px).
  - Sección derecha con indicador de `"ARMA INSIGNIA"` con icono (36x36px) y nombre del arma drop.
  - Animación elástica de entrada con sonido SFX y desvanecimiento progresivo tras 4.5 segundos.
- [x] **Pantalla de Victoria & Loadout (`game_over_modal.tscn`, `game_over_modal.gd`):**
  - Rediseño visual del inventario: tarjetas de ítems y pactos con iconos grandes (28-32px), bordes coloreados según rareza (`COMMON`, `UNCOMMON`, `RARE`, `EPIC`, `LEGENDARY`) e insignias numéricas `[xN]`.
  - Tarjetas de armas con borde dorado, nombre estilizado e indicador de nivel `(Nv. X)`.
- [x] **Modo Endless (Sin Fin):**
  - Botón interactivo `[E] MODO ENDLESS` visible en victorias de incursión, con soporte de teclado (`KEY_E`).
  - Al activarse, la partida se reanuda inmediatamente (`PauseArbitrator.release_pause`), el contador de oleadas progresa indefinidamente (12+), y el spawner escala progresivamente el tope de enemigos y la cadencia de spawn.
  - En caso de muerte en el modo sin fin, la telemetría registra la oleada máxima alcanzada y el récord general.

---

## 🔴 Nivel 4 — Investigación de Bugs & Comportamientos Complejos
1. **Diálogos de Navegadoras In-Game:**
   - Investigar inconsistencias en la carga del avatar/icono de la navegadora en el diálogo in-game.
   - Corregir discrepancia de colores de texto/nombre entre distintos eventos de diálogo.
2. **Sistema de Bombas:**
   - Resolver bug donde las bombas quedan bloqueadas tras ciertos eventos.
   - Auditar sincronización entre el indicador visual derecho del HUD y el valor real/máximo de bombas.
- [x] **Selección de Personajes (Regresiones Recientes):**
   - Restaurado comportamiento de tecla `ESC` directamente en `_input()` para volver al hub de manera inmediata cuando no hay modales abiertos, evitando que el foco de los controles de UI la consuma.
   - Corregido el descentrado del icono de arma: eliminado el override erróneo de posición `position = Vector2.ZERO` sobre el hijo del `VBoxContainer` e implementado recorte simétrico estricto 1:1 en `_apply_weapon_optical_centering()` para centrado perfecto con cualquier skin.
