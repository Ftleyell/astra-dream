# Roadmap de Pulido — Parallax Espacial y Transición de Biomas

> **Objetivo:** Transformar el prototipo del sandbox en un fondo espacial dinámico, cinematográfico y deslumbrante, con transiciones sutiles y orgánicas entre biomas, para luego migrarlo como el fondo oficial de combate en Astra Dream.

---

## 📋 Sesión 1: Campo Estelar Orgánico y Polvo Cósmico (Shader Refactor)
- [x] **Eliminar Estrellas Cuadradas:** Reemplazar el cálculo actual de celdas discretas en `scenes/combat/environment/universe_nebula.gdshader` por funciones de dispersión gaussiana/Lorentziana continua con radio de decaimiento suave.
- [x] **Picos de Difracción (Diffraction Spikes):** Implementar destellos de 4 puntas estilo telescopio espacial (Hubble/James Webb) en las estrellas de mayor magnitud/brillo.
- [x] **Diversidad Cromática Espectral:** Asignar colores procedimentales basados en tipos estelares reales (azules calientes clase O/B, amarillas solares clase G, enanas rojas clase M, blancas puras clase A).
- [x] **Polvo Estelar Micro-volumétrico:** Incorporar una capa secundaria de grano y polvo estelar ultra-fino para dar profundidad y textura al vacío sin saturar la pantalla.
- [x] **Validación Visual:** Comprobar navegación en `sandbox/space_biome_sandbox.tscn` a diferentes zooms y velocidades de cámara.

---

## 🪐 Sesión 2: Curación de Assets, Defringing y Shader de Atmósfera Planetaria
- [x] **Defringing Perimétrico en Python:**
  - Actualizar `tools/process_parallax_assets.py` con erosión submétrica de 1–2 píxeles (`cv2.erode`) sobre la máscara exterior para podar el halo negro residual de compresión JPEG.
  - Regenerar los PNGs de planetas y estaciones en `assets/environments/parallax_space/`.
- [x] **Shader de Atmósfera Planetaria (`planet_atmosphere.gdshader`):**
  - Implementar efecto Fresnel / Rim Light en el limbo del planeta, proyectando un resplandor atmosférico suave (cian, naranja o azul según el tipo geológico).
  - Configurar el arco iluminado para que coincida con la luz clave cósmica (superior-izquierda), fundiendo de forma natural el planeta con el espacio.
- [x] **Oclusión del Lado Oscuro:** Garantizar que el terminador y lado en penumbra continúe ocluyendo al 100% las estrellas y nebulosas del fondo (efecto eclipse masivo).

---

## 🛰️ Sesión 3: Dinamismo de Props, Balizas Diegéticas y Jerarquía de Escala
- [x] **Cinemática Individual de Asteroides:**
  - Asignar a cada asteroide instanciado en `ParallaxDebris` una velocidad angular continua (`spin_speed` aleatoria entre -0.4 y +0.4 rad/s) para que giren sobre su propio centro al volar.
- [x] **Balizas de Navegación en Estaciones Espaciales:**
  - Crear un shader ligero o animación procedural de luces estroboscópicas / balizas de posición (destellos rítmicos rojos y blancos) en las puntas de las megaestructuras.
- [x] **Rotación Axial Lenta en Planetas:**
  - Aplicar rotación imperceptible a los cuerpos planetarios para acentuar la sensación de simulación viva.
- [x] **Rebalanceo de Escala y Jerarquía de Capas:**
  - Ajustar tamaños relativos: planetas de escala monumental en la capa profunda (`scroll_scale ~0.04–0.06`), megaestructuras intermedias (`scroll_scale ~0.20`), y asteroides densos en la capa más cercana (`scroll_scale ~0.55`).

---

## 🌌 Sesión 4: Transición Espacial de Biomas y Niebla de Frontera
- [x] **Proyección de Frontera en el Shader:**
  - Evolucionar el shader de nebulosa para proyectar gradientes espaciales de los biomas en función de las coordenadas reales del mundo (permitiendo ver las nubes del nuevo bioma aproximándose a lo lejos en el horizonte).
- [x] **Afinamiento de Curvas en `SectorManager`:**
  - Optimizar los radios de transición y la curva smootherstep quíntica $C^2$ para evitar cualquier salto perceptible de color al cruzar fronteras.
- [x] **Reactividad de Densidad de Props por Bioma:**
  - Modular la visibilidad o densidad de la chatarra metálica para que se concentre con mayor fuerza al ingresar al *Cementerio Mecánico*.

---

## 🚀 Sesión 5: Migración al Combate Principal (`scenes/combat/`)
- [ ] **Integración en `space_background.tscn`:**
  - Reemplazar el fondo estático de combate por el sistema multicapa híbrido pulido.
  - Mantener compatibilidad total con el `enable_auto_drift` existente (para fondos en movimiento en menús o pausas).
- [ ] **Enlace con Jugador y Cámara de Combate:**
  - Conectar `BackgroundSync` y `SectorManager` a la cámara y nave reales del juego (`scenes/combat/player/player.tscn`).
- [ ] **Verificación de Rendimiento y Tests:**
  - Ejecutar tests de combate con `tools/run_tests.ps1` asegurando 60/120 FPS estables y cero leaks en el arnés anti-cuelgues.
