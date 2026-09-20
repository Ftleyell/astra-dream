# Astra Dream (Greybox MVP v0.3.0)

Roguelite de acción híbrido desarrollado en **Godot 4.7+ (GDScript)** que combina Danmaku 360° (*Picayune Dreams*), acumulación infinita de ítems y cadenas de procs (*Risk of Rain*), mazo de estadísticas in-run (*Brotato*), banlist previa a la run en el Hangar (*Megabonk*) y narrativa in-run no intrusiva con audio ducking (*Dialogic 2.0*).

---

## 🛠 Requisitos de Entorno
* **Godot Engine 4.7+ (Stable)**
* **Git** con soporte para **Git LFS** (`git lfs install`)

---

## 🚀 Puesta en Marcha (Clonar y Ejecutar)

```powershell
# 1. Clonar el repositorio con LFS
git clone https://github.com/Ftleyell/astra-dream.git
cd astra-dream
git lfs pull

# 2. Inicializar la caché interna del motor
& "C:\Ruta\Hacia\Godot_console.exe" --editor --headless --quit

# 3. Ejecutar el juego desde el menú principal
& "C:\Ruta\Hacia\Godot_console.exe" --path .
```

---

## 🎮 Controles

### Teclado y Ratón (Rebindeable en Ajustes)
* **WASD:** Movimiento omnidireccional.
* **Shift:** Dash con 0.25s de invulnerabilidad a las balas (i-frames).
* **Click Izquierdo:** Disparo del Haz Láser Perforante de pantalla completa (con cooldown en HUD).
* **Disparo Automático:** Lanzador de misiles guiados pasivos (auto-aim hacia el enemigo más cercano).
* **Espacio:** Bomba de pantalla que destruye instantáneamente todas las balas hostiles.
* **Rozar Balas (Graze):** Acercarse al núcleo de las balas enemigas otorga EXP sin recibir daño.
* **ESC:** Pausar partida y abrir el **Build Inspector** (ítems equipados y cartas Brotato obtenidas).
* **R (Mantener 1.2s):** Reinicio seguro de la run (con oscurecimiento progresivo de pantalla).
* **T:** Disparar transmisión de radio de jefe (Dialogic 2.0 con Low-Pass audio ducking).
* **Tab:** Skip instantáneo de diálogos.

### Mando / Joystick (Soporte Nativo Xbox / PS / Switch)
* **Stick Izquierdo / D-Pad:** Movimiento y navegación de menús.
* **Botón Sur (A / Cruz):** Dash / Aceptar en menús.
* **Botón Este (B / Círculo):** Bomba / Volver en menús.
* **Gatillo Derecho (RT / R2):** Disparo Láser Activo.
* **Start:** Menú de Pausa.
* **Select:** Saltar diálogo.

---

## 🖥 Menús y Experiencia de Usuario (UI)
* **Menú Principal (`main_menu.tscn`):** Acceso a Partida, Selección de Heroínas, Configuración y Salir.
* **Selección de Personajes (`character_select.tscn`):** Roster de 6 heroínas con retratos vectoriales, atributos base, pasivas y enlace directo a la configuración de Hangar / Banlist.
* **Ajustes y Configuración (`settings_modal.tscn`):**
  * **Pantalla y Audio:** Resoluciones 16:9 (1080p, 1440p, 4K, 720p), 21:9 Ultrawide (2560x1080, 3440x1440) y 16:10 (Steam Deck 1280x800, 1920x1200); modo pantalla completa; sliders de volumen Master, Música y SFX.
  * **Teclado y Ratón:** Reasignación interactiva de todas las teclas y clics en caliente.
  * **Mando / Joystick:** Guía de controles y slider de calibración de zona muerta analógica (*deadzone*).
* **Pausa & Build Inspector (`pause_menu.tscn`):** Detiene completamente la simulación e inspecciona en dos columnas scrollables todos los ítems acumulados (con stacks) y las mejoras de nivel Brotato elegidas (con badges de rareza).
* **Hold to Reset (`hold_to_reset_overlay.tscn`):** Reinicio de partida fluido que previene reseteos accidentales requiriendo sostener `R` por 1.2 segundos con fade progresivo.
* **Barra de Vida Flotante (`overhead_health_bar.tscn`):** Barra sobre la nave del jugador con indicador numérico de porcentaje (`%`) y cambio dinámico de color.
* **EXP Blobs Coalescentes (`exp_blob.tscn`):** Gotas de experiencia que se fusionan por proximidad ($d \le 52\text{ px}$) en 4 tiers escalonados con atracción magnética para eliminar cuellos de botella de rendimiento.

---

## 📂 Registro de Cambios
Consulta el historial de versiones detallado en [CHANGELOG.md](CHANGELOG.md).
