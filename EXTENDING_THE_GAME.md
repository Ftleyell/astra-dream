# Cómo Extender Astra Dream (Guía para Desarrolladores)

Esta guía documenta los flujos estándar para incorporar nuevo contenido al juego garantizando el cumplimiento de las reglas de arquitectura, contratos de combate, data-driven y zero-allocation.

---

## 1. Cómo Añadir una Nueva Heroína / Piloto (4 Pasos)

### Paso 1: Crear el Recurso `CharacterData`
1. Crea un nuevo recurso `resources/characters/char_mi_heroina.tres`.
2. Define los atributos obligatorios:
   - `id`: `StringName` único en minúsculas (ej. `&"aurora"`).
   - `display_name`: Nombre legible (ej. `"Aurora"`).
   - `base_max_hp`, `base_speed`, `dash_cooldown`, `dash_invulnerability_time`.
   - `starting_weapon`: Ruta al recurso `WeaponData` inicial.

### Paso 2: Añadir Arte y Skins
1. Coloca el retrato en `assets/portraits/portrait_aurora.png` (512x512).
2. Coloca las vistas de cuerpo entero en `assets/characters/fullbody/`:
   - `fullbody_aurora.png`
   - `fullbody_aurora_flipped.png` (orientación espejo para el lado derecho del hangar).
3. (Opcional) Registra una entrada en `CosmeticsManager` si posee skins desbloqueables en la máquina gacha.

### Paso 3: Implementar o Asignar Controlador de Dash
En `entities/player/dashes/`:
- Si la heroína posee un dash con mecánicas únicas (como el torbellino de Nyx o el agujero negro de Estele), implementa un script que extienda de `BaseDashController` respetando:
  ```gdscript
  class_name AuroraDashController
  extends BaseDashController

  func execute_dash(player: CharacterBody2D, direction: Vector2) -> void:
      # Lógica de evasión, micro-animación y spawn de VFX
  ```

### Paso 4: Registrar Constelación de Talentos
En `resources/talents/pilot_skill_tree_catalog.gd`:
- Añade el identificador a la lista de constelaciones con sus 13 nodos de habilidades y sus 2 keystones definitivas.
- Asigna los costes de biomasa correspondientes.

---

## 2. Cómo Añadir una Nueva Arma (3 Pasos)

### Paso 1: Crear el Recurso `WeaponData`
1. Crea `resources/weapons/weapon_mi_arma.tres` derivado de `WeaponData`.
2. Completa los valores de balance (`base_damage`, `cooldown`, `spread_degrees`, `projectiles_per_shot`).
3. Asigna la textura del icono para el HUD y las ranuras de inventario (`icon_texture`).

### Paso 2: Crear el Sprite y Montura Visual
1. Guarda la textura del sprite del cañón en `assets/weapons/weapon_mi_arma.png`.
2. El sistema visual [`WeaponMountPoint`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/entities/player/weapons/weapon_mount_point.gd) detectará automáticamente el arma equipada y renderizará el cañón montado sobre el chasis de la nave.

### Paso 3: Asignar Controlador de Disparo
En `entities/player/weapons/`:
- Si dispara proyectiles cinéticos o láseres regulares, utiliza el controlador genérico configurado mediante el recurso.
- Si utiliza lógica personalizada (ej. orbes orbitales, rayos continuos), hereda de `BaseWeaponInstance`:
  ```gdscript
  class_name MiArmaInstance
  extends BaseWeaponInstance

  func fire(target_direction: Vector2) -> void:
      # Spawn de proyectil o disparo de rayo
  ```

---

## 3. Cómo Crear un Jefe o Coloso Danmaku

1. **Heredar de `BaseBoss` (`entities/bosses/base_boss.gd`):**
   - Asegúrate de implementar `take_damage(ctx: HitContext) -> void`.
2. **Uso Estricto de `BulletServer`:**
   - **PROHIBIDO** instanciar `Area2D` para las balas del jefe.
   - En los patrones de disparo en abanico, espiral o flor, genera las balas llamando a `BulletServer.spawn_bullet()`:
     ```gdscript
     for i in range(num_balas):
         var angle := deg_to_rad(i * (360.0 / num_balas))
         var dir := Vector2.RIGHT.rotated(angle)
         BulletServer.spawn_bullet(global_position, dir, 220.0, 15.0, BulletType.ENEMY_ORB)
     ```
3. **Registro en Trofeos:**
   - Asigna un identificador de trofeo en `ProfileStorage` / `MetaProgressionState` (ej. `trophy_boss_aurora`) para otorgar pasivas permanentes al ser derrotado.

---

## 4. Ejecución de Tests Automatizados (Headless)

Astra Dream cuenta con un motor de pruebas unitarias y de integración que se ejecutan sin abrir ventana de gráficos.

### Ejecutar un Runner Específico
Desde PowerShell en el directorio raíz:
```powershell
& "C:\Users\Frani\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless res://tests/test_persistence_runner.tscn
```

### Reglas para Nuevos Tests
- Los runners deben ser escenas `.tscn` que instancien el script de suite `.gd`.
- Al finalizar la suite con éxito, invoca:
  ```gdscript
  get_tree().quit(0) # Código de salida 0 = ÉXITO
  ```
- En caso de fallo de aserción, no captures el error para que el engine reporte la línea exacta y salga con código de error != 0.
