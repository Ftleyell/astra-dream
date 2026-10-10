# Especificación Técnica y Hoja de Ruta: Motor de Simulación y Entorno Espacial Procedural

> **Estado:** Arquitectura Completa e Implementada (Sesiones 1 a 7 Verificadas)  
> **Ubicación:** `docs/sandbox/MOTOR_ESPACIAL_PROCEDURAL_ARQUITECTURA.md`  
> **Área:** `sandbox/rendering/`, `sandbox/astronomy/`, `sandbox/environment/` & `sandbox/core/`  
> **Motor:** Godot 4.3+ / 4.7+ (GDScript Tipado Estricto + Shaders GLSL CanvasItem)  
> **Guía de Migración:** Ver `docs/sandbox/GUIA_MIGRACION_COSMOS_PRODUCCION.md`

---

## 1. Visión y Alcance del Sistema

Buscamos construir un **motor de simulación y proyección espacial procedural** que proporcione un entorno cósmico infinito, orgánico y dinámico para el espacio de juego:

* **Topología Infinita y Streaming Determinista:** Universo navegable sin barreras físicas donde cada run posee una semilla (*seed*) única. Las ubicaciones de estrellas, planetas, estaciones y macro-galaxias se resuelven en tiempo real mediante funciones matemáticas cerradas sin estado ($O(1)$) a través de `CosmicMacroGrid` y `CosmicHasher`.
* **Biomas Espaciales Dinámicos:** Regiones del cosmos diferenciadas por parámetros continuos en GPU (`universe_nebula.gdshader`), modulando tonalidades de gas, densidad de nebulosa, aberración cromática e iluminación difusa con transiciones suaves.
* **Jerarquía Astronómica Completa:**
  1. *Estrellas Centrales:* Focos gravitacionales y lumínicos.
  2. *Planetas en Órbita:* Desplazamiento orbital analítico dependiente de tiempo global ($t_{\text{global}} \cdot \omega$).
  3. *Lunas y Estaciones Espaciales:* Cuerpos anidados que orbitan directamente a los planetas madre.
* **Macro-Galaxias de Profundidad Extrema:** Landmarks cósmicos de magnitud colosal en capas ultra-lentas. Al alejarse la nave, la galaxia desaparece gradualmente; tras una breve travesía por el vacío, el jugador divisa una nueva aproximándose de forma natural sin solapamientos.
* **Cinturones de Escombros y Basura Espacial (*Debris Layer*):** Partículas, chatarra mecánica y restos minerales con texturas de canal alfa (*alpha cutout*) distribuidos en capas con paralaje acentuado para acentuar el volumen tridimensional.
* **Textura Estelar Maestra 8K Anti-Tiling:** Para eliminar la ilusión de grilla y los patrones repetitivos de mosaicos pequeños, se utiliza un búfer de $8192 \times 8192$ píxeles generado estocásticamente en Python con distribución estelar pura en canales RGB, muestreado mediante ventanas dinámicas de recorrido (ej. $1920 \times 1080$).
* **Filosofía Data-Driven y Configuración Fina:** Cero números mágicos; 100% regulado por Recursos Personalizados (`.tres`) para ajuste artístico de radios, densidades, factores de scroll, escalas y velocidades.

---

## 2. La Magnitud Real de la Complejidad Técnica

No se trata de un simple fondo con `Parallax2D`; estamos abordando la intersección de **cinco problemas de nivel sénior de ingeniería de motores**, todos acoplados en el mismo subsistema visual:

### Desafío 1: Floating Origin + Parallax Fraccionario
Cuando la nave se aleja y el `FloatingOriginTracker` recentra las coordenadas del mundo a $(0, 0)$, cada capa de paralaje debe absorber ese salto en proporción directa a su `scroll_scale`. Un error de medio píxel o un desfase de un fotograma genera tirones visuales (*stutter / jitter*) inaceptables.

### Desafío 2: La Trampa Matemática del Frustum Ultra-Lento ($scroll\_scale = 0.02 - 0.05$)
En una capa estándar ($1.0$), una pantalla de $1920 \times 1080$ cubre exactamente esa área en el mundo. Sin embargo, en una capa profunda con `scroll_scale = 0.03`, la pantalla proyectada cubre un área en coordenadas lógicas de fondo equivalente a:

$$\text{Ancho Proyectado} = \frac{1920}{0.03} \approx 64.000\text{ px} \quad \times \quad \text{Alto Proyectado} = \frac{1080}{0.03} = 36.000\text{ px}$$

La "ventana" que ve el jugador en esa capa es **gigantesca**. Garantizar la regla de la *galaxia única sin solapamiento* exige calcular el AABB proyectado de forma analítica exacta; de lo contrario, cualquier celda vecina en un radio de más de $60.000\text{ px}$ se colará en el borde de la pantalla de forma errática.

### Desafío 3: Jerarquía Orbital Animada Bajo Paralaje
Anidar nodos hijos (`Sprite2D` de planetas y estaciones) orbitando alrededor de un padre (`Sol`) que a su vez es transformado por el `Parallax2D` nativo de Godot tiende a desajustar las matrices locales si se mezclan transformaciones locales y globales en cuadros asíncronos.

### Desafío 4: Determinismo Analítico $O(1)$ sin Base de Datos
Las posiciones orbitales y espaciales no pueden acumularse con `delta`; deben ser funciones puras del tiempo universal y de las coordenadas de la celda:
$$\theta(t) = \theta_0 + t_{\text{global}} \cdot \omega$$
Esto garantiza persistencia absoluta con cero impacto en memoria, pero exige fórmulas analíticas cerradas y sin estado.

### Desafío 5: Shaders Dinámicos en Coordenadas Infinitas
El shader de nebulosa en coordenadas continuas requiere que los vectores pasados a la GPU absorban el origen flotante; de lo contrario, los ruidos procedurales (Simplex/FBM) sufren degradación de precisión de 32 bits a distancias extremas, provocando artefactos de pixelado o vibración.

---

## 3. Estrategia de Abordaje por Fases (Desacople Riguroso)

El error crítico en sistemas de este calibre es intentar resolver todos los problemas a la vez en la escena principal. La estrategia consiste en partir el problema en 3 fases secuenciales e independientes en `sandbox/`:

```
┌────────────────────────────────────────────────────────────────────────┐
│ Fase 1: La Galaxia Única                                               │
│ Proyección exacta de frustum en capas lentas con un sprite de prueba.  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Validado y aislado)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Fase 2: El Sistema Solar Determinista                                  │
│ 1 Estrella + 3 Planetas + Lunas orbitando con t_global en Parallax2D.  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Validado y aislado)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Fase 3: Integración Total, Debris y Shaders                            │
│ Unificación con FloatingOriginTracker, texturas 8K, Debris y Biomas.   │
└────────────────────────────────────────────────────────────────────────┘
```

### Fase 1: Aislamiento del Frustum Lento y Macro-Galaxias
* **Objetivo:** Escena limpia (`sandbox/test_galaxy_frustum.tscn`) con una `Camera2D` con desplazamiento libre.
* **Meta Técnica:** Validar exclusivamente el cálculo analítico del frustum proyectado para capas con `scroll_scale \in [0.02, 0.05]`.
* **Criterio de Éxito:** Una galaxia entra en pantalla, cruza el campo visual, desaparece completamente al salir del frustum proyectado, y tras recorrer el espacio vacío aparece la siguiente de manera orgánica, sin colisiones ni solapamientos dobles.

### Fase 2: Jerarquía Orbital Determinista en Parallax
* **Objetivo:** Escena aislada (`sandbox/test_solar_hierarchy.tscn`).
* **Meta Técnica:** Implementar un nodo solar que proyecte 1 estrella central con 3 planetas orbitando y lunas satelitales, evaluando posiciones angulares directamente mediante $t_{\text{global}} \cdot \omega$ bajo un layer de `Parallax2D` (`scroll_scale = 0.20`).
* **Criterio de Éxito:** La cámara puede desplazarse decenas de miles de unidades en cualquier dirección y regresar; las posiciones de los cuerpos celestes se conservan continuas, estables y sincronizadas con el tiempo cósmico, sin saltos en los transforms.

### Fase 3: Integración de Sistemas, Debris y Shaders
* **Objetivo:** Escena unificada en `sandbox/` ensamblando todos los componentes.
* **Meta Técnica:**
  1. Enlazar `FloatingOriginTracker` con `process_priority` configurado para sincronizar el recentrado de coordenadas antes de los renders de paralaje.
  2. Integrar el búfer estelar 8K y la capa de escombros con canal alfa (`DebrisLayerProfile.tres`).
  3. Activar el shader continuo `universe_nebula.gdshader` recibiendo offsets de origen flotante y blending de biomas.
* **Criterio de Éxito:** Rendimiento a 60 FPS estables sin micro-tirones durante recentrados de origen, cero artefactos visuales a grandes distancias y transición fluida entre regiones estelares.

---

## 4. Estructura de Datos y Recursos Exportados (`.tres`)

Toda variable de balance y arte debe ser encapsulada en recursos:

| Recurso | Tipo | Parámetros Clave |
|---|---|---|
| `CosmicBiomeConfig.tres` | `Resource` | Colores primario/secundario de gas, densidad de nebulosa, tipos de estrellas dominantes, curvas de blending. |
| `CelestialSystemProfile.tres` | `Resource` | Radios orbitales mínimos/máximos, velocidad angular ($\omega$), cantidad de planetas por sistema, probabilidad de estaciones lunares. |
| `GalaxyLandmarkProfile.tres` | `Resource` | Factor de escala visual, distancias de fade in/out, tamaño de macrocelda ($60.000\text{ px}$), scroll scale ($0.03$). |
| `DebrisLayerProfile.tres` | `Resource` | Texturas alfa de basura espacial, rangos de escala, velocidad de giro, factor de scroll ($0.50 - 0.70$). |

---

## 5. Conclusión y Próximos Pasos

Este documento sirve como la guía de referencia técnica y mental para el desarrollo del subsistema. La complejidad es intrínseca a la arquitectura; su resolución se logra manteniendo el desacople modular, respetando el ciclo de validación en tres fases independientes y asegurando que cada cálculo sea puramente analítico y determinista.
