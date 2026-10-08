# Sistemas de Combate, Progresión y UI — Astra Dream

> **Propósito:** Documento de referencia arquitectónica para la integración de los sistemas de Tomos, Armas Infinitas, Quantum Chest Leash, Tienda Satelital y UI de Subida de Nivel implementados en el hito de balance y combate. Permite continuar el desarrollo del proyecto en cualquier equipo sin pérdida de contexto técnico.

---

## 1. Sistema de Tomos de Atributos (Megabonk-Style Tomes)

### 1.1 Concepto y Propósito
Para evitar la inflación artificial de drops pasivos en la pool de combate y permitir a los jugadores especializar su build antes de despegar, se introdujo el **Sistema de Tomos**. Cada uno de los 11 atributos primarios de la nave cuenta con un recurso exportado `TomeData` (`data/tomes/*.tres`).

### 1.2 Estructura Data-Driven (`TomeData`)
- **Ruta de recursos:** [`data/tomes/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/tomes/)
- **Script de Definición:** [`data/tomes/tome_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/tomes/tome_data.gd)
- **Campos principales:**
  - `tome_id: StringName`: Identificador único (ej. `&"tome_damage"`, `&"tome_move_speed"`).
  - `stat_name: StringName`: Atributo afectado (ej. `&"base_damage"`, `&"move_speed"`).
  - `stat_value_per_level: float`: Escalado por cada nivel invertido.
  - `is_percentage: bool`: Define si la bonificación es aditiva porcentual o plana.
  - `max_level: int`: Nivel máximo por tomo (por defecto 5).
  - `base_unlocked: bool`: Si está disponible en el draft inicial.

### 1.3 Catálogo y Controlador de Nave
- **Catálogo Central:** [`data/tomes/tome_catalog.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/tomes/tome_catalog.gd) expone `ALL_TOME_IDS` y helpers de carga con caché `load_tome()`.
- **Controlador en Player:** [`scenes/combat/player/tome_controller.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/player/tome_controller.gd):
  - Gestiona una capacidad máxima de **4 tomos equipados** simultáneos.
  - Aplica modificadores directamente a `CharacterStats` mediante `CharacterStats.StatModifier`.
  - Emite `tome_level_changed` y `tomes_updated` para sincronizar el HUD.

### 1.4 Selección en Pantalla de Personajes y Guardado
- Modal interactivo: [`scenes/ui/character_select/tome_selection_modal.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/character_select/tome_selection_modal.gd).
- Persistencia: [`SaveManager`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/autoloads/save_manager.gd) almacena por piloto (`character_tomes`) el conjunto de tomos activos que spawnearán en la run.

---

## 2. Armas Infinitas y Escalado Asintótico

### 2.1 Eliminación del Límite de Nivel
Anteriormente, las armas alcanzaban un límite artificial en nivel 8. En [`core/resources/weapon_instance_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/resources/weapon_instance_data.gd):
- Cada nivel otorga **+1 proyectil adicional** a todas las salvas activas.
- El daño escala asintóticamente mediante una curva hiperbólica decreciente:
  $$\text{Multiplicador de Daño} = 1.0 + \frac{0.6 \cdot (L - 1)}{1.0 + 0.08 \cdot (L - 1)}$$
  Esto asegura un crecimiento tangible en niveles tempranos mientras previene daños astronómicos que rompan el motor de combate en niveles 20+.

### 2.2 Rareza de Mejoras de Armas en Level Up
En [`scenes/ui/level_up/components/level_up_reward_generator.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/level_up/components/level_up_reward_generator.gd), las cartas de mejora de armas aplican una tirada ponderada por la Suerte del piloto:
- **Tier 1 (Común):** Potencia Calibrada (85% daño relativo).
- **Tier 2 (Mejorada):** Potencia Nominal (100% daño relativo).
- **Tier 3 (Avanzada):** Sobrecarga de Plasma (120% daño relativo).
- **Tier 4 (Legendaria):** Reactor Hipercrítico (145% daño relativo).

---

## 3. Mecanismo Quantum Leash para Cofres

### 3.1 Justificación
En mapas infinitos, los cofres que spawneaban lejos del jugador quedaban rezagados y olvidados fuera de pantalla, desaprovechando la economía de llaves.

### 3.2 Implementación
En [`scenes/combat/chests/chest_director.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/chests/chest_director.gd):
- Se evalúa periódicamente la distancia de cada cofre interactivo sin abrir respecto al jugador.
- Si un cofre se encuentra a una distancia superior a **1500 px**:
  - Se reubica de forma invisible hacia un punto en la periferia de combate (radio entre **400 px y 600 px** respecto a la nave).
  - Mantiene intacta su identidad, rareza, llaves requeridas y contenido.

---

## 4. Desacoplamiento de Teletransporte de Rival

### 4.1 Comportamiento Fuera de Combate
En [`scenes/combat/rivals/combat_rival.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/rivals/combat_rival.gd):
- La secuencia de salto hiperespacial y teletransporte forzado queda **deshabilitada** si la rival no se encuentra en combate activo (`state != State.COMBAT`).
- Esto evita apariciones descontextualizadas o saltos visuales durante fases de patrulla o roaming libre.

---

## 5. Rediseño de UI: Tienda Satelital y Subida de Nivel

### 5.1 Tienda Satelital (`SatelliteShop`)
- **Toda la tarjeta es el botón de compra:** [`scenes/combat/satellite/components/satellite_shop_card_builder.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/satellite/components/satellite_shop_card_builder.gd) instancia la tarjeta directamente como un `Button` interactivo con estilos cyberpunk (normal, hover, pressed, focus, disabled).
- Todos los controles internos usan `mouse_filter = MOUSE_FILTER_IGNORE`, garantizando que cualquier click en cualquier punto de la tarjeta accione la compra.
- **Tipografía y Color:** El precio se muestra en una caja dorada `Color(1, 0.85, 0.2, 1)` idéntica al display de créditos del HUD y tienda.
- **Indicador de Teclas:** Conserva `[ TECLA 1 ]`, `[ TECLA 2 ]`, `[ TECLA 3 ]` con navegación por teclado y mando.
- **Metadata:** Al comprar, la tarjeta se inhabilita y actualiza su estado visual a `¡ADQUIRIDO!` / `[ COMPRADO ]`.

### 5.2 Modal de Subida de Nivel (`LevelUpModal`)
- **Dimensiones:** [`scenes/ui/level_up_modal.tscn`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/level_up_modal.tscn) ampliado a **760 px de ancho $\times$ 640 px de alto** (`offset_left = -380, offset_top = -320`), asegurando que las 3 opciones quepan con suficiente respiro visual y sin salirse del contenedor.
- **Formateo de Badges:** En [`LevelUpRewardGenerator`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/level_up/components/level_up_reward_generator.gd) y [`LevelUpCardBuilder`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/level_up/components/level_up_card_builder.gd):
  - Los badges muestran explícitamente `+<ESTADÍSTICA> <CANTIDAD>` (ej. `+DAÑO +5.0 (Efecto total)` o `+VEL. MOVIMIENTO +15% por nivel`).
  - Se eliminó completamente la redundancia de signos `++`.
- **Dock de Estadísticas Lateral:** Al abrir el modal, se proyecta el `CombatStatsDock` del HUD sincronizado en tiempo real.

### 5.3 Indicador de Maldición en HUD
En [`scenes/ui/hud.tscn`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/hud.tscn) y [`hud.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/hud.gd), el badge de Maldición se ubica alineado verticalmente **directamente sobre el contador de llaves**, evitando congestión en la barra inferior de recursos.

---

## 6. Nombres de Cartas Arcanas Adaptados a Sci-Fi

Los 6 arcanas de [`data/arcanas/roster/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/arcanas/roster/) fueron adaptados de arquetipos de tarot de fantasía a la estética espacial y ciberpunk de Astra Dream:
1. `arcana_fool.tres` $\rightarrow$ **El Pionero Descalibrado**
2. `arcana_magician.tres` $\rightarrow$ **El Arquitecto Cuántico**
3. `arcana_priestess.tres` $\rightarrow$ **La Matriz Silente**
4. `arcana_empress.tres` $\rightarrow$ **El Núcleo Génesis**
5. `arcana_emperor.tres` $\rightarrow$ **El Protocolo Titán**
6. `arcana_hierophant.tres` $\rightarrow$ **El Nexo Dogmático**

---

## 7. Verificación Automatizada

Para verificar la integridad de todos los sistemas tras realizar cambios, ejecutar siempre el arnés anti-cuelgues:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
```
Todas las suites críticas (14/14) deben reportar `PASS` sin timeouts ni cuelgues del motor.
