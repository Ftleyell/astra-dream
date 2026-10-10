# Roadmap de Sesiones Atómicas — Parallax & Universo Sandbox

> **Instrucciones de Ejecución:**
> 1. Seguir el principio de desarrollo de Astra Dream: **"1 Tarea / Fase = 1 Sesión Atómica"** (máx. 12-15 turnos por sesión para mantener el contexto por debajo de 80k tokens).
> 2. Cada vez que se complete un paso, tacharlo con markdown (`- [x] ~~tarea~~`).
> 3. Al completar la última tarea de la última sesión (Paso 5.4), el agente **eliminará automáticamente este archivo `.md`**.

---

## 🛰️ Sesión 1: Limpieza del Sandbox y Fundamentos Matemáticos Puros ($O(1)$)
- [x] ~~**Paso 1.1**: Limpieza selectiva de `sandbox/` (eliminar scripts legados obsoletos: `cosmic_chunk_virtualizer.gd`, `cosmic_object_pool.gd`, `cosmic_orbital_system.gd`, `cosmic_socket_director.gd`, `cosmic_viewport_arbiter.gd`, `space_biome_sandbox.gd`, `space_biome_sandbox.tscn`, shaders huérfanos; preservando intactos `sandbox_ship.*` y los assets en `assets/`).~~
- [x] ~~**Paso 1.2**: Crear la nueva estructura de directorios modulares (`sandbox/math/`, `sandbox/core/`, `sandbox/rendering/`, `sandbox/shaders/`).~~
- [x] ~~**Paso 1.3**: Implementar `sandbox/math/cosmic_hasher.gd` con **SquirrelNoise5** determinista en 32 bits y funciones de dispersión espacial 2D ($O(1)$ sin estado).~~
- [x] ~~**Paso 1.4**: Implementar `sandbox/math/kepler_orbital_solver.gd` con resolución analítica de Kepler y convergencia Newton-Raphson ($M \to E \to$ rotación $\omega$).~~
- [x] ~~**Paso 1.5**: Crear un suite de prueba unitario o script de verificación matemática en headless para corroborar determinismo numérico y convergencia orbital.~~

---

## 🌌 Sesión 2: Floating Origin Tracker y Shaders de Parallax Continuo
- [x] ~~**Paso 2.1**: Implementar `sandbox/core/floating_origin_tracker.gd` (gestión de coordenadas lógicas en 64 bits, umbral de tolerancia $\delta_{\max}$ y señales de rebase).~~
- [x] ~~**Paso 2.2**: Crear `sandbox/shaders/space_deep_quad.gdshader` (shader de fondo continuo para cámara con UV scrolling analítico, mezcla de colores base, estrellas procedurales y textura 8K).~~
- [x] ~~**Paso 2.3**: Crear `sandbox/shaders/space_nebula_quad.gdshader` (shader para estratos medios de gas nebular con ruido periódico, premultiplied alpha y modulación cromática).~~
- [x] ~~**Paso 2.4**: Implementar `sandbox/rendering/cosmic_parallax_quad.gd` (nodo CanvasItem/Mesh centrado permanentemente en la cámara que alimenta los uniforms de los shaders sin mover geometría en CPU).~~
- [x] ~~**Paso 2.5**: Validación visual preliminar del scrolling suave y sin costuras vinculándolo a la cámara de la nave.~~

---

## ☄️ Sesión 3: Instanciación Masiva de Debris en GPU (MultiMesh)
- [x] ~~**Paso 3.1**: Crear `sandbox/shaders/debris_cutout.gdshader` (alpha testing con instrucción `discard` para Early-Z rejection en GPU).~~
- [x] ~~**Paso 3.2**: Implementar `sandbox/rendering/cosmic_debris_instancer.gd` utilizando `MultiMeshInstance2D` con buffer compacto alimentado por la semilla del chunk.~~
- [x] ~~**Paso 3.3**: Mapeo y slicing de texturas de restos espaciales usando los atlas ya existentes (`assets/environments/parallax_space/`).~~
- [x] ~~**Paso 3.4**: Configurar el ciclo de reciclaje toroidal de celdas para el debris instanciado alrededor de la nave sin asignaciones volátiles (`zero-allocation`).~~
- [x] ~~**Paso 3.5**: Verificación de rendimiento (1 Draw Call para miles de fragmentos y tasa de refresco a 60 FPS estables).~~

---

## 🪐 Sesión 4: Streamer de Sectores y Cuerpos Celestes Keplerianos
- [ ] **Paso 4.1**: Implementar `sandbox/core/cosmic_sector_streamer.gd` con ventana de visibilidad toroidal y banda de histéresis ($R_{in}$ vs $R_{out}$).
- [ ] **Paso 4.2**: Implementar `sandbox/rendering/cosmic_celestial_renderer.gd` para renderizar soles y sistemas planetarios cuyas órbitas elípticas se evalúan analíticamente en tiempo $O(1)$ con `KeplerOrbitalSolver`.
- [ ] **Paso 4.3**: Jerarquía orbital secundaria (lunas y estaciones espaciales orbitando planetas dominantes).
- [ ] **Paso 4.4**: Verificación de estabilidad matemática: avanzar el tiempo bruscamente o teletransportarse a coordenadas astronómicas y verificar que las órbitas no colapsen ni acumulen deriva.

---

## 🚀 Sesión 5: Ensamblado Final del Sandbox, HUD de Métricas y Limpieza
- [ ] **Paso 5.1**: Construir la escena principal `sandbox/sandbox_space_view.tscn` y el orquestador `sandbox/sandbox_host.gd` ensamblando la nave de vuelo libre (`sandbox_ship.tscn`), el origen flotante, las capas de parallax, el instancer de debris y los sistemas orbitales.
- [ ] **Paso 5.2**: Implementar un HUD minimalista de telemetría (FPS, coordenadas globales lógicas, conteo de Draw Calls, sector actual y estado del floating origin).
- [ ] **Paso 5.3**: Prueba integral de estrés de vuelo a alta velocidad en Godot, verificando ausencia de memory leaks, costuras, jittering o caídas de framerate.
- [ ] **Paso 5.4**: **Cierre de Ciclo**: Confirmar aceptación final con el usuario y **eliminar automáticamente este archivo de roadmap** (`ROADMAP_PARALLAX_SANDBOX.md`).
