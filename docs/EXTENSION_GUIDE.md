# Guía de Extensión y Contratos — Astra Dream

> **Propósito:** Esta guía permite a desarrolladores y agentes de IA añadir nuevo contenido (armas, enemigos, balizas, pilotos, arcanas) gastando el mínimo de tokens posible al evitar explorar o re-leer el código base.

---

## 1. Cómo Añadir una Nueva Arma (`WeaponData`)
**Sin tocar código de combate**, únicamente recursos `.tres`.

1. **Ubicación del recurso:** `data/weapons/<nombre_arma>.tres`
2. **Estructura requerida (`WeaponData`):**
   ```gdscript
   weapon_id: StringName = &"plasma_cannon"
   weapon_name: String = "Cañón de Plasma"
   base_damage: float = 35.0
   cooldown: float = 0.8
   projectile_speed: float = 500.0
   behavior_script: Resource = preload("res://scenes/combat/weapons/behaviors/projectile_weapon_behavior.gd")
   icon: Texture2D = ...
   tier: int = 1
   ```
3. **Behaviors disponibles (`scenes/combat/weapons/behaviors/`):**
   - `projectile_weapon_behavior.gd`: Disparo lineal balístico estándar.
   - `orbiting_weapon_behavior.gd`: Satélites / orbes que orbitan la nave.
   - `aura_weapon_behavior.gd`: Daño continuo de área radial.
   - `chain_lightning_behavior.gd`: Rayo que rebota entre objetivos.
4. **Verificación:** Ejecutar suite aislada:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_weapons_runner.tscn"
   ```

---

## 2. Cómo Añadir una Nueva Baliza o Interactuable Orbital
Las balizas espaciales siguen la arquitectura desacoplada de 3 capas de `SlotMachineBeacon`:

1. **Estructura recomendada en `scenes/combat/satellite/`:**
   - **Nodo Físico:** Hereda o implementa `Area2D` con detección de bumper/proximidad (`~100 líneas`).
   - **Display / Marquee:** `components/<nombre>_display.gd` (Animaciones, Tweens, SFX, texto flotante).
   - **Engine de Recompensas:** `components/<nombre>_payout_engine.gd` (Lógica de entrega de exp, ítems, curación).
   - **Configuración (.tres):** `data/interactables/<nombre>_config.tres`.
2. **Contrato de Interacción:** Notificar a `CombatSatelliteCoordinator` o invocar recompensas pasando la referencia de `player` y `main_game`.

---

## 3. Cómo Añadir un Nuevo Rival o Jefe
1. **Datos de Personaje:** `data/characters/<id_piloto>.tres` (`CharacterData`).
2. **Escena / IA:** `scenes/combat/bosses/rival_pilot_boss.tscn`:
   - Controlador motor: `rival_flight_motor.gd`.
   - Comportamiento de duelo: `rival_engagement_behavior.gd`.
3. **Diálogos de Encuentro:** Añadir líneas en `CombatRadioFeedController.get_rival_dialogue(rival_id, player_id)`.
4. **Pausa Segura:** NUNCA invocar `PauseArbitrator.acquire_pause(&"dialogue")` en el activador si se usa Dialogic; `CombatNarrativeDirector.on_timeline_started` lo adquiere automáticamente.

---

## 4. Cómo Crear un Nuevo Modal de UI
Todos los modales deben extender `BaseModal` (`scenes/ui/modals/base_modal.gd`):

```gdscript
class_name MiNuevoModal
extends BaseModal

func _ready() -> void:
    super._ready()
    modal_token = &"mi_nuevo_modal"

func open_modal() -> void:
    super.open_modal() # Adquiere token en PauseArbitrator y bloquea input de juego limpiamente

func close_modal() -> void:
    super.close_modal() # Libera token en PauseArbitrator
```
- **Separación UI:** Toda tabla, grid o lista generada programáticamente debe ir en un `_layout_builder.gd` o `_presenter.gd`, manteniendo el modal raíz en `<150 líneas`.

---

## 5. Cheat-Sheet de Pruebas Ultra-Rápidas (2s de latencia)

| Tarea / Dominio | Comando de Test Específico |
|---|---|
| **Armas y Proyectiles** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_weapons_runner.tscn"` |
| **Tienda y Economía Satelital** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_satellite_items_runner.tscn"` |
| **Tragamonedas / Gacha** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_slot_machine_and_gacha_runner.tscn"` |
| **Salón de la Fama / Highscores** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_highscores_runner.tscn"` |
| **Game Over / Pantalla Final** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_game_over_screen_runner.tscn"` |
| **Diálogos / Skip de Cabina** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_dialogue_skip_runner.tscn"` |
| **Verificación Integral (Final)** | `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly` |
