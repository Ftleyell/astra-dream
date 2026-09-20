# 🚀 MANUAL DE INICIO Y GUÍA DE TRABAJO — DESARROLLADOR 1
## Rol: Ingeniero de Arsenal, Proyectiles y Jugador
**Proyecto:** Astra Dream | **Repositorio:** `https://github.com/Ftleyell/astra-dream.git`

---

## 1. INSTALACIÓN DEL ENTORNO (DESDE CERO EN WINDOWS)

Abre **PowerShell como Administrador** y ejecuta los siguientes comandos paso a paso:

### Paso 1: Instalar Git y Git LFS
```powershell
winget install --id Git.Git -e --source winget
```
*Cierra y vuelve a abrir PowerShell para que tome la variable de entorno PATH, luego ejecuta:*
```powershell
git lfs install
```

### Paso 2: Instalar Godot Engine 4 (Versión Oficial del Proyecto)
```powershell
winget install --id GodotEngine.GodotEngine -e --source winget
```

### Paso 3: Clonar el Repositorio y Descargar Assets LFS
Ubícate en la carpeta donde quieras guardar tus proyectos (por ejemplo en tu directorio de usuario):
```powershell
git clone https://github.com/Ftleyell/astra-dream.git
cd astra-dream
git lfs pull
```

### Paso 4: Inicializar la Caché del Motor
Ejecuta el siguiente comando para que Godot escanee los scripts y genere el mapa de clases internas sin abrir ventanas:
```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --editor --headless --quit
```

### Paso 5: Abrir el Proyecto en Antigravity
Abre tu **Antigravity**, selecciona la carpeta clonada `astra-dream` como espacio de trabajo y ¡listo! Tu asistente leerá automáticamente las reglas del juego en `.gemini/rules/project_rules.md`.

---

## 2. TU TERRITORIO EXCLUSIVO (LO QUE PUEDES MODIFICAR)

Tienes control total sobre el poder de fuego del jugador, las armas y los proyectiles:

| Carpeta / Archivo | Propósito | Qué puedes hacer aquí |
| :--- | :--- | :--- |
| `scenes/combat/weapons/` | Armas activas y pasivas | Crear nuevas armas, láseres, misiles, proyectiles y sus efectos visuales. |
| `scenes/combat/player/` | Heroína y Controles | Físicas de movimiento, lógica de dash, partículas, recolección de EXP. |
| `data/weapons/` | Recursos de Armas (`.tres`) | Estadísticas de daño, cadencia, velocidad de proyectil y coeficientes de proc. |
| `core/shaders/` | Shaders visuales | Shaders de proyectiles danmaku, distorsión y estelas. |
| `data/items/` | Nuevos Ítems | Crear archivos `.tres` de ítems ofensivos (aumento de cadencia, daño crítico, etc.). |

---

## 3. ZONAS PROHIBIDAS (LO QUE NO DEBES TOCAR)

Para no pisar el trabajo de tu compañero, **NUNCA** debes modificar directamente:
* ❌ `scenes/combat/enemies/` (Territorio de tu compañero: enemigos y spawners).
* ❌ `scenes/combat/bosses/` (Territorio de tu compañero: jefes de oleada).
* ❌ `scenes/combat/main_game.tscn` (Escena raíz: nadie la toca directamente).
* ❌ `scenes/ui/` (Territorio de tu compañero: menús de pausa, HUD y game over).
* ❌ `addons/dialogic/` (Narrativa y guiones de jefes).

---

## 4. EL CONTRATO SAGRADO: CÓMO DAÑAR ENEMIGOS

Tus armas **no necesitan conocer el código de los enemigos**. Solo deben seguir este estándar para que todo funcione mágicamente:

1. **Buscar enemigos:** Tus armas buscan objetivos usando el grupo `"enemies"`:
   ```gdscript
   var targets := get_tree().get_nodes_in_group("enemies")
   ```
2. **Aplicar daño:** Cada impacto debe crear y enviar un `HitContext`:
   ```gdscript
   var ctx := HitContext.new()
   ctx.attacker = player
   ctx.raw_damage = 45.0
   ctx.final_damage = 45.0 # Si es crítico, multiplicar aquí
   ctx.is_crit = false
   ctx.proc_coefficient = 1.0 # Permite detonar procs de ítems
   ctx.hit_position = target.global_position

   if target.has_method("take_damage"):
       target.take_damage(ctx)
   ```
3. **Explosiones secundarias:** Si un misil o láser crea una explosión hija, usa `ctx.fork_child_hit()` para evitar bucles infinitos:
   ```gdscript
   var child_ctx := ctx.fork_child_hit(ctx.final_damage * 0.5, 0.3, &"explosion")
   ```

---

## 5. FLUJO DE TRABAJO EN GIT (CERO CONFLICTOS)

1. **Antes de empezar cualquier tarea:**
   ```powershell
   git checkout master
   git pull origin master
   ```
2. **Crear una rama para tu arma o mejora:**
   ```powershell
   git checkout -b feat/arma-escopeta-plasma
   ```
3. **Trabajar y commitear:**
   ```powershell
   git add .
   git commit -m "feat(weapons): agregar escopeta de plasma activa"
   ```
4. **Subir a GitHub:**
   ```powershell
   git push origin feat/arma-escopeta-plasma
   ```
5. En GitHub, abres el **Pull Request** y tu compañero lo fusionará a `master`.

---

## 6. PRIMERA MISIÓN SUGERIDA PARA TU ANTIGRAVITY

Copia y pega este prompt en tu Antigravity para arrancar con tu primera arma:

> *"Crea un nuevo arquetipo de arma en `scenes/combat/weapons/` llamado `PlasmaShotgun`. Debe tener una habilidad activa on-click que dispare un abanico de 5 perdigones de energía con dispersión angular y una habilidad pasiva autónoma que genere 2 satélites orbitales protectores alrededor de la nave del jugador. Respeta las reglas de `.gemini/rules/project_rules.md` y usa `HitContext` para el cálculo de daño."*
