# Ficha Técnica de Arte: Lienzos, Resoluciones y Anclas

Esta ficha establece los estándares técnicos de resolución, puntos de pivote, anclas y alineación física para todos los assets 2D de **Astra Dream**.

---

## 1. Lienzo y Especificaciones del Viewport

| Parámetro | Valor Estándar | Razón / Regla de Motor |
|---|---|---|
| **Resolución Base** | `1920 x 1080 px` (Full HD, 16:9) | Lienzo nativo de renderizado (Godot 4.7.2 Forward Mobile / Vulkan 1.4). |
| **Relación de Escala del Mundo** | `1 unidad = 1 píxel` | Toda velocidad o distancia física se expresa en `px` o `px/s`. |
| **Formato de Exportación** | `PNG de 32 bits (RGBA)` | Canales RGB sin pre-multiplicar con canal Alpha limpio y compresión sin pérdidas. |
| **Profundidad de Color** | Espacio de Color `sRGB` | Evitar saturación excesiva en shaders aditivos (`COLOR *= COLOR`). |

---

## 2. Dimensiones y Puntos de Pivote por Tipo de Asset

| Tipo de Entidad | Tamaño de Lienzo (px) | Punto de Pivote (Anchor) | Notas Técnicas |
|---|---|---|---|
| **Naves de Jugador (Exo-Ships)** | `96 x 96` a `128 x 128` | Centro Geométrico `(0.5, 0.5)` | Orientación inicial hacia el Norte/Este (rotación dinámica por vector). |
| **Enemigos Comunes (Drones/Flocks)** | `48 x 48` a `64 x 64` | Centro Exacto `(0.5, 0.5)` | Hitbox física circular `r = 16-24 px`. |
| **Enemigos Élite / Tanques** | `96 x 96` a `144 x 144` | Centro Exacto `(0.5, 0.5)` | Hitbox física `r = 36-48 px`. |
| **Jefes de Dominio (Colosos)** | `256 x 256` a `512 x 512` | Centro de Masa `(0.5, 0.5)` | Desacople de piezas articuladas si usan rotación independiente. |
| **Retratos Dialogic (Heroínas)** | `512 x 768` (relación 2:3) | Base/Centro `(0.5, 0.9)` | Margen de respiración lateral, escala `1.0`. |
| **Retratos Dialogic (Mascotas)** | `384 x 384` (relación 1:1) | Centro Flotante `(0.5, 0.5)` | Orientación *Flipped* (`mirror=true`), escala `0.65` con animación *Tilt & Wiggle*. |
| **Iconos de Armas / Ítems** | `64 x 64` | Centro `(0.5, 0.5)` | Silueta legible a escala 32x32 para HUD y slots de combate. |
| **Proyectiles Danmaku** | `32 x 32` (textura base) | Centro `(0.5, 0.5)` | Escalamiento 1:1 con radio físico: `scale = Vector2.ONE * (radius / 16.0)`. |

---

## 3. Alineación 1:1 de Hitbox y Shaders

1. **Hitboxes Circulares:** Todo proyectil hostil y proyectil de coloso debe tener su centro de colisión exactamente en `(0, 0)` relativo al nodo o al cálculo del `BulletServer`.
2. **Shaders Aditivos:**
   * Las texturas deben tener un reborde transparente mínimo de **2 píxeles** para evitar filtrado de textura (clamping artifacts) en las esquinas de los quads.
   * Multiplicación estricta de color: Todo shader personalizado debe implementar `COLOR *= COLOR;` en el fragment para respetar la modulación de desvanecimiento (`modulate.a`).
