# Astra Dream (Greybox MVP)

Roguelite de acción híbrido desarrollado en **Godot 4.7+ (GDScript)** que combina Danmaku 360° (*Picayune Dreams*), acumulación infinita de ítems y cadenas de procs (*Risk of Rain*), mazo de estadísticas in-run (*Brotato*), banlist previa a la run en el Hangar (*Megabonk*) y narrativa in-run no intrusiva con audio ducking (*Dialogic 2.0*).

---

## 🛠 Requisitos de Entorno
* **Godot Engine 4.7+ (Stable)**
* **Git** con soporte para **Git LFS** (`git lfs install`)

---

## 🚀 Puesta en Marcha (Clonar y Ejecutar)

```powershell
# 1. Clonar el repositorio con LFS
git clone <URL_DEL_REPOSITORIO>
cd astra-dream
git lfs pull

# 2. Inicializar la caché interna del motor
& "C:\Ruta\Hacia\Godot_console.exe" --editor --headless --quit

# 3. Ejecutar el prototipo de juego
& "C:\Ruta\Hacia\Godot_console.exe" --path .
```

---

## 🎮 Controles en Combate
* **WASD:** Movimiento omnidireccional.
* **Shift:** Dash con 0.25s de invulnerabilidad a las balas (i-frames).
* **Click Izquierdo:** Disparo del Haz Láser Perforante de pantalla completa (con cooldown en HUD).
* **Disparo Automático:** Lanzador de misiles guiados pasivos (auto-aim hacia el enemigo más cercano).
* **Espacio:** Bomba de pantalla que destruye instantáneamente todas las balas hostiles.
* **Rozar Balas (Graze):** Acercarse al núcleo de las balas enemigas otorga EXP sin recibir daño.
* **T:** Disparar transmisión de radio de jefe (Dialogic 2.0 con Low-Pass audio ducking).
* **Tab:** Skip instantáneo de diálogos.

---

## 📂 Arquitectura Modular y Reglas de Trabajo en Equipo
Consulta las directrices completas de colaboración y arquitectura en:
* [Reglas de Arquitectura y Antigravity](.gemini/rules/project_rules.md)
* Guía de contribución por ramas: `feat/nombre-de-la-funcionalidad`
