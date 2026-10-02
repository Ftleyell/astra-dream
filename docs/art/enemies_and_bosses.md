# Ficha Técnica de Arte: Enemigos, Jefes y Telegraphs

Guía técnica concisa para el diseño visual, dimensiones, siluetas y señales de advertencia (telegraphs) de amenazas en **Astra Dream**.

---

## 1. Arquetipos de Enemigos Comunes y Élite

| Arquetipo | Tamaño de Sprite (px) | Hitbox (Radio) | Color Dominante | Silueta y Comportamiento Visual |
|---|---|---|---|---|
| **Drone** | `48 x 48` | `16 px` | Púrpura Oscuro (`#4B0082`) | Triangular angular. Vuela en manada errática hacia el jugador. |
| **Kamikaze** | `48 x 48` | `14 px` | Rojo Carmesí (`#FF1E27`) | Agudo en punta de flecha con núcleo intermitente parpadeante. |
| **Shooter** | `64 x 64` | `22 px` | Aguamarina Táctico (`#00FFFF`) | Doble torreta orbital. Rota para alinear cañones antes de disparar. |
| **Tank** | `96 x 96` | `36 px` | Acero Oscuro / Ámbar (`#D4AF37`) | Cuadrangular blindado masivo. Placas protectoras reflectantes. |
| **Splitter** | `64 x 64` | `24 px` | Verde Ácido (`#76FF03`) | Romboide segmentado. Se divide en dos versiones menores al morir. |
| **Micro-Flock** | `32 x 32` | `10 px` | Naranja Neón (`#FF4500`) | Insectoide diminuto. Alta velocidad y spawn en enjambre circular. |
| **Rainbow Enemy** | `64 x 64` | `24 px` | Iridiscente / Arcoíris | "Loot Goblin". Vuelo transversal rápido con estela policromática. |
| **Elite Herald** | `128 x 128` | `44 px` | Dorado Carmesí (`#FFD700`) | Nave insignia de asalto con aura brillante y runas de dominio. |

---

## 2. Jefes de Dominio y Finales (Colosos)

| Coloso | Oleada | Dimensión (px) | Tema Visual / Mecánica Artística |
|---|---|---|---|
| **Ermitaño Abisal (Hermit)** | 2 | `256 x 256` | Caparazón de roca volcánica y cristal oscuro con tentáculos bio-mecánicos. |
| **Espejo Roto (Broken Mirror)** | 5 | `320 x 320` | Estructura fractal prismática que refracta la luz y proyecta reflejos fantasmales. |
| **Reloj de Cenizas (Ash Clock)** | 8 | `384 x 384` | Esfera astrológica antigua con engranajes expuestos y anillo orbital giratorio. |
| **Vórtice Desbordante (Overflow Vortex)** | 11 | `384 x 384` | Núcleo de reactor hiperespacial con anillos electromagnéticos girando en 3 ejes. |
| **Nave Nodriza (Mothership)** | 14 | `512 x 512` | Fortaleza estelar colosal con bahías de hangares activas y cañón troncal. |
| **Astra Prime** | 16 | `512 x 512` | Entidad cósmica divina con alas de materia estelar y corona de agujeros de gusano. |

---

## 3. Guía de Señalización de Ataques (Telegraphs)

1. **Colores de Advertencia Universales:**
   * **Daño Balístico Convencional:** Rojo / Naranja de alta emisión (`#FF2020`).
   * **Haces Perforantes y Láseres:** Cian Eléctrico / Blanco puro con degradado exterior.
   * **Vórtices y Gravedad:** Violeta Oscuro (`#8A2BE2`) con pulso interior.
2. **Texturas de Telegraph:**
   * Franja o línea de trayectoria: textura en bucle con shader de desplazamiento (`boss_telegraph.gdshader`) indicando tiempo hasta impacto (0.6s a 1.2s de aviso).
   * Círculos de impacto: borde contrastado con barrido de llenado radial de 0% a 100%.
3. **Contraste de Siluetas:**
   * Todo sprite hostil debe conservar un delineado de al menos 1 píxel o brillo de contorno para garantizar 100% de visibilidad contra el fondo espacial o zonas oscurecidas.
