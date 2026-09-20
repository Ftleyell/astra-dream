# 🛡️ MANUAL DE TRABAJO Y ARQUITECTURA — DESARROLLADOR 2
## Rol: Diseñador de Bestiario, Jefes, Oleadas y UI de Sistema
**Proyecto:** Astra Dream | **Repositorio:** `https://github.com/Ftleyell/astra-dream.git`

---

## 1. TU TERRITORIO EXCLUSIVO (LO QUE TÚ DESARROLLAS)

Eres el dueño exclusivo del diseño de encuentros, la progresión de oleadas, las amenazas y la interfaz de menús:

| Carpeta / Archivo | Propósito | Qué desarrollas aquí |
| :--- | :--- | :--- |
| `scenes/combat/enemies/` | Bestiario de Enemigos | Crear nuevos arquetipos de enemigos comunes (kamikazes, tanques, francotiradores). |
| `scenes/combat/bosses/` | Jefes de Oleada | Jefes mayores de cada minuto/fase, barras de vida de jefe y fases de combate. |
| `scenes/combat/spawner/` | Ritmo de la Partida | Control de oleadas por tiempo (ej. Minuto 1: Drones ligeros, Minuto 3: Jefe Vanguard). |
| `scenes/ui/menus/` | Menús del Sistema | Menú de Pausa (`pause_menu.tscn`), Pantalla de Muerte/Game Over (`game_over.tscn`). |
| `addons/dialogic/timelines/`| Narrativa In-Run | Timelines de diálogo de radio de jefes con audio ducking. |
| `data/items/` | Nuevos Ítems | Crear archivos `.tres` de ítems defensivos, de utilidad, escudos o recolección. |

---

## 2. ZONAS PROHIBIDAS (NO TOCAR PARA NO PISAR A TU COMPAÑERO)

Para garantizar cero conflictos con tu compañero del Segmento 1, **NUNCA** debes modificar:
* ❌ `scenes/combat/weapons/` (Territorio de tu compañero: escopetas, misiles, láseres, armas).
* ❌ `scenes/combat/player/` (Territorio de tu compañero: movimiento, dash, controles de la nave).
* ❌ `data/weapons/` (Territorio de tu compañero: recursos de armas).
* ❌ `core/shaders/` y `bullet_server.gd` (Territorio de tu compañero: motor balístico).
* ❌ `scenes/combat/main_game.tscn` (Escena raíz: nadie la modifica directamente).

---

## 3. EL CONTRATO SAGRADO: LA INTERFAZ DE ENEMIGOS

Para que cualquier arma creada por tu compañero pueda dañar automáticamente a tus enemigos sin que ustedes dos tengan que comunicarse ni coordinar código, **TODO ENEMIGO O JEFE NUEVO QUE PROGRAMES DEBE CUMPLIR ESTAS 3 REGLAS OBLIGATORIAS**:

### Regla 1: Registrarse en el grupo `"enemies"`
En la función `_ready()` de tu script de enemigo:
```gdscript
func _ready() -> void:
    add_to_group("enemies")
```

### Regla 2: Implementar la función `take_damage(ctx: HitContext)`
Tus enemigos deben recibir el objeto DTO `HitContext`:
```gdscript
func take_damage(ctx: HitContext) -> void:
    if is_dying:
        return

    current_health -= ctx.final_damage

    # Feedback visual (hit-flash)
    modulate = Color(3.0, 3.0, 3.0, 1.0)
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color.WHITE, 0.08)

    if current_health <= 0.0:
        _die()
```

### Regla 3: Recompensas al Morir
Cuando un enemigo muere, busca al nodo en el grupo `"player"` para otorgarle EXP y créditos de forma desacoplada:
```gdscript
func _die() -> void:
    is_dying = true
    var player := get_tree().get_first_node_in_group("player") as Player
    if is_instance_valid(player):
        player.add_exp(exp_reward)
        player.add_credits(credits_reward)

    # Animación de muerte y liberación de memoria
    queue_free()
```

---

## 4. FLUJO DE TRABAJO EN GIT (CERO CONFLICTOS)

1. **Estar al día con `master` antes de iniciar:**
   ```powershell
   git checkout master
   git pull origin master
   ```
2. **Crear tu rama de trabajo:**
   ```powershell
   git checkout -b feat/nuevos-enemigos-y-pausa
   ```
3. **Desarrollar tus enemigos o menús y commitear:**
   ```powershell
   git add .
   git commit -m "feat(enemies): agregar enemigo kamikaze y menu de pausa con ESC"
   ```
4. **Subir a GitHub:**
   ```powershell
   git push origin feat/nuevos-enemigos-y-pausa
   ```
5. **Merge en GitHub:**
   Hacer el Pull Request y merge a `master`. Como tu compañero trabaja en `scenes/combat/weapons/` y tú en `scenes/combat/enemies/`, **el merge será 100% automático y sin conflictos**.

---

## 5. NUESTRO PLAN DE ACCIÓN INMEDIATO (SPRINT 1)

Tareas listas para programar en este momento:
1. **`EnemyKamikaze` (`scenes/combat/enemies/enemy_kamikaze.tscn`):**
   * 25 HP, velocidad alta (260 px/s).
   * Color rojo/naranja brillante, aceleración agresiva hacia el jugador.
   * Explota al estar a menos de 45 px del jugador o al recibir daño letal, provocando 25 de daño al jugador si no está en dash.
2. **`EnemyTank` (`scenes/combat/enemies/enemy_tank.tscn`):**
   * 350 HP, velocidad lenta (90 px/s).
   * Tamaño mayor (radio 36 px), actúa como esponja de daño absorbiendo proyectiles para proteger al enjambre.
3. **Menú de Pausa Flotante (`scenes/ui/menus/pause_menu.tscn`):**
   * Escucha la tecla `Escape` (`ui_cancel`).
   * Pausa el árbol (`get_tree().paused = true`).
   * Botones estilizados: **Reanudar**, **Ajustes de Volumen**, y **Volver al Hangar**.
