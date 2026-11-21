# Referencia Técnica y de Arte — VFX Power-Up *Sandevistan Astral* (Valentina v2)

> **Estado:** **Implementado y verificado en laboratorio aislado (`vfx_lab/`)**.
> **Rol en Diseño:** Reservado para **Power-Up / Sobrecarga / Habilidad Activa** (se descartó como propulsión default por tener alto impacto visual y jerarquía de estado especial).
> **Propulsión Base (Default):** [`docs/VALENTINA_BASE_PROPULSION_WINGS_SPEC.md`](VALENTINA_BASE_PROPULSION_WINGS_SPEC.md) (*Alas de Luz Rojo + Silver + Slipstream Ribbons + Polvo Estelar*).
> **Escena de Laboratorio:** [`sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn)
> **Suite de Verificación:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "valentina_vfx_lab"`
> **Referencia de Rig:** [`docs/VALENTINA_V2_RIG_REFERENCE.md`](VALENTINA_V2_RIG_REFERENCE.md)

---

## 1. Arquitectura y Archivos Implementados

| Componente | Archivo | Responsabilidad |
|---|---|---|
| **Esquema Data-Driven** | [`sandbox/pilot_rig_lab/data/pilot_propulsion_vfx_config.gd`](../sandbox/pilot_rig_lab/data/pilot_propulsion_vfx_config.gd) | `PilotPropulsionVFXConfig` (`Resource`) con curvas de opacidad, gradiente, espaciado por distancia, paso de pincel ping-pong, tinta interna y aberración cromática |
| **Preset Calibrado** | [`sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres`](../sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres) | Paleta **Turquesa → Bordó → Amatista**, curvas de calco y valores guardados en vivo desde el HUD |
| **Controlador Runtime** | [`sandbox/pilot_rig_lab/vfx_lab/sandevistan_trail_controller.gd`](../sandbox/pilot_rig_lab/vfx_lab/sandevistan_trail_controller.gd) | `SandevistanTrailController`: disparo por distancia, compresión en giros, pincel ping-pong congelado por copia, caché de materiales de tinta y ciclo de vida |
| **Shader Pasada 1 (Piezas)** | [`sandbox/pilot_rig_lab/vfx_lab/sandevistan_ghost_part.gdshader`](../sandbox/pilot_rig_lab/vfx_lab/sandevistan_ghost_part.gdshader) | Extrae la tinta interna `*_ink_sdf.png` (`2×` + RGSS al alejar cámara) en el canal `R` del `CanvasGroup` del ghost |
| **Shader Pasada 2 (`CanvasGroup`)** | [`sandbox/pilot_rig_lab/vfx_lab/sandevistan_ghost.gdshader`](../sandbox/pilot_rig_lab/vfx_lab/sandevistan_ghost.gdshader) | Compone relleno plano unlit + outline exterior 12-tap + tinta interna SDF compartiendo color oscurecido y `outline_alpha` ("calco de animación") |
| **Post-FX Bordes** | [`sandbox/pilot_rig_lab/vfx_lab/sandevistan_edge_aberration.gdshader`](../sandbox/pilot_rig_lab/vfx_lab/sandevistan_edge_aberration.gdshader) | Pulso breve de aberración cromática RGB exclusivamente en los bordes de pantalla al activar la ráfaga |
| **Escena + HUD Lab** | [`valentina_vfx_lab.tscn`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn) · [`valentina_vfx_lab.gd`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.gd) · [`valentina_vfx_lab_hud.gd`](../sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab_hud.gd) | Modos auto (Curva S, Órbita Kiting, Burst Loop) + manual (`WASD`/Mouse/`Espacio`/`B`), balas danmaku simuladas con slow-mo y guardado directo a `.tres` |
| **Test Automatizado** | [`tests/sandbox/test_valentina_vfx_lab.tscn`](../tests/sandbox/test_valentina_vfx_lab.tscn) · [`tests/sandbox/test_valentina_vfx_lab.gd`](../tests/sandbox/test_valentina_vfx_lab.gd) | Verifica carga `.tres`, 0 copias en reposo, disparo por distancia, límites de densidad, curvas de calco, expiración y reinicio del pincel |

---

## 2. Contrato Estético Final Aprobado

### 2.1 Pincel Ping-Pong con Color Congelado al Nacer
* **Copias congeladas:** Cada *afterimage* captura la pose exacta del `Skeleton2D` + cabeza desacoplada en su `CanvasGroup` y **congela el color con el que nació** durante toda su vida útil (cero *motion blur*).
* **Paleta canónica (Ping-Pong):** `Turquesa (#18E6D8) → Bordó (#A81E4C) → Amatista (#8A2BE2 / #B45CFF) → Bordó → Turquesa`.
* **Ritmo por copia:** El cursor avanza un paso discreto por cada copia generada (`color_step_per_ghost = 0.18`, ~5–6 copias por ida).
* **Reinicio limpio:** Al detenerse en reposo (*idle*) o al disparar una nueva ráfaga (`trigger_burst_impulse`), el cursor reinicia en `0.0` (**Turquesa**).

### 2.2 Outline Coloreado Oscuro + Tinta Interna SDF ("Calco de Animación")
* **Outline del mismo tono más oscuro:** Derivado con `base_col.darkened(outline_darken_amount)` sin sobre-exposición HDR (evita blanqueamiento bajo tonemapper `AgX` + `Glow`).
* **Tinta interna SDF unificada:** La Pasada 1 vuelca `ink_sdf_tex` de cada pieza al canal `R` (con caché de `ShaderMaterial` por textura para evitar allocs); la Pasada 2 dibuja los detalles internos del traje, hombreras, pelo y rostro con exactamente el mismo color y `outline_alpha` que el contorno exterior.
* **Decaimiento en calco:** `fill_alpha_curve` cae más rápido que `outline_alpha_curve` (tramo `30% – 70%` de vida), dejando el dibujo lineal (*genga*) visible y legible sobre balas de `BulletServer` antes de afinarse y disolverse (`70% – 100%`).

### 2.3 Disparo por Distancia y Acabado de Impacto
* **Espaciado espacial:** Instanciación por distancia recorrida (`base_spawn_distance_px` / `burst_spawn_distance_px`) con compresión automática en giros cerrados (`turn_angle_compress_deg`, `turn_distance_compress_factor`).
* **Reposo limpio:** `0` copias nuevas bajo `base_min_speed_px_s`.
* **Impacto de activación:** Breve `burst_hitstop_sec`, pulso de aberración cromática solo en bordes y asimetría temporal opcional (`burst_world_time_scale`) sobre proyectiles/entorno.

---

## 3. Cómo Integrarlo en el Futuro (Cuando se Implemente el Power-Up)
1. Instanciar `SandevistanTrailController` en la capa trasera del rig (`z_index` menor que Valentina) enlazado a `valentina_v2_propulsion_vfx.tres`.
2. Llamar `trigger_burst_impulse(rig)` al activar el Power-Up / Overdrive y `step(delta, rig, velocity, is_powerup_active)` cada frame mientras dure el estado.
3. Conectar el pulso de `sandevistan_edge_aberration.gdshader` al evento de activación del Power-Up.
