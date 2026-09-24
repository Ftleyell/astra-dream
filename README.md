# Astra Dream (Greybox MVP v0.4.0)

Roguelite de acción híbrido desarrollado en **Godot 4.7+ (GDScript)** que combina combate Danmaku 360°, acumulación sinérgica de artefactos espaciales, mazo dinámico de mejoras de atributos in-run, filtrado estratégico de suministros en el Hangar y narrativa reactiva con modulación acústica dinámica (*Dialogic 2.0*).

---

## 📝 Notas del Parche / Registro de Actualizaciones (v0.4.0 - Master)

### 🚀 Últimas Novedades y Sistemas Implementados

#### 🎯 Armamento Balístico Autónomo (Capa Pasiva Rediseñada)
* **Trayectoria Balística Directa:** Los misiles de apoyo ya no corrigen su curso artificialmente en el aire; ahora vuelan en línea recta estricta a alta velocidad, pudiendo impactar a enemigos en su paso o errar si el objetivo maniobra con rapidez.
* **Fijación Táctica Automática:** El sistema prioriza automáticamente al hostil más próximo dentro del perímetro de disparo efectivo de la nave.
* **Escalado del Radio de Autoaim:** Rango base fijado en el doble del radio de atracción magnética de la nave ($2 \times \text{pickup\_radius}$ base), escalando 1:1 de forma lineal con cualquier mejora o bono de imán adquirido.
* **Conmutación Manual al Cursor (Tecla `E` / Botón `RB`):** Alterna instantáneamente entre el apuntado inteligente y el disparo dirigido hacia el puntero del ratón, con feedback auditivo táctico.
* **Indicador Flotante e Interfaz:** Display táctico `AUTOAIM: ON / OFF` ubicado bajo el chasis de la nave a `(0, 26)` con micro-pulso reactivo y retícula holográfica en pantalla.

#### ⚡ Maniobras Evasivas Avanzadas (Dashes Únicos por Heroína)
* **Nova:** Doble carga de propulsión con rastro ígneo continuo que daña a los enemigos rezagados.
  * **Nova - Omega Spin:** Al dashear teniendo el condensador láser al 100% de carga, Nova desata un giro continuo de 360° barriendo toda la pantalla con su rayo láser, rotando visualmente la nave con deduplicación de daño (máximo 1 impacto por hostil).
* **Valentina:** Salto de repliegue táctico en dirección opuesta a la mira, dilatación temporal (*Bullet-Time* al 55% de velocidad de juego) y proyectil crítico 100% garantizado en su próximo disparo.
* **Kira:** Despliegue de mina señuelo reactiva en las coordenadas de partida que atrae la atención hostil y detona en área al expirar.
* **Selene:** Salto cuántico de fase de 240px en la dirección de la mira, generando un vórtice gravitacional que atrae y desestabiliza a los enemigos cercanos.
* **Roxy:** Embestida sísmica pesada con disipación frontal de proyectiles enemigos e impacto cinético con knockback masivo.
* **Echo:** Parpadeo dimensional instantáneo de 200px con descarga de relámpago en arco que encadena daño entre objetivos próximos.

#### 🌌 Hangar Estelar 3D & Mirador Panorámico
* **Entorno Híbrido 2.5D:** Hangar espacial tridimensional con iluminación ambiental, máquinas arcade interactivas, avatares de cuerpo completo y mirador panorámico al cosmos exterior.
* **Fondo Estelar Multicapa:** Simulación de 3 capas de parallax gigantes con velocidad diferencial y transparencia etérea.
* **Árbol de Talentos Permanente:** 13 nodos navegables con teclado (`WASD`) o mando, desbloqueando mejoras permanentes de chasis, blindaje, daño y aceleración.

#### 🖥️ Soporte Integral Panorámico y Ultrawide (21:9 & 32:9)
* **Anclaje Perimétrico Dinámico de Diálogos:** Los retratos de personajes en cinemáticas y diálogos de novela visual (*Dialogic 2.0*) se adaptan dinámicamente a monitores ultrapanorámicos (21:9, 32:9 y 16:10), manteniéndose permanentemente acoplados a los bordes exteriores de la pantalla sin flotar hacia el centro ni generar huecos negros descompensados.

#### 📡 Radar Perimétrico Orbital & HUD Táctico
* **Seguimiento Perimétrico:** Marcador holográfico dinámico en los márgenes de la pantalla que rastrea la ubicación de satélites de suministros y monolitos lejanos.
* **Desprendimiento Central:** Al entrar en el campo visual del jugador, el indicador se desprende del borde de la pantalla y se acopla directamente sobre el satélite u objetivo.
* **HUD Informativo:** Medidores de blindaje, condensador de carga láser, temporizador de oleada y contadores de biomasa, créditos y materia oscura.

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
* **Shift / Clic Derecho:** Dash evasivo con invulnerabilidad temporal (i-frames) y maniobra única de heroína.
* **Clic Izquierdo:** Disparo del Haz Láser Perforante de pantalla completa (con cooldown en HUD).
* **E:** Alternar modo de apuntado pasivo (Autoaim / Puntero Manual).
* **Q / Espacio:** Bomba de pantalla que destruye instantáneamente todas las balas hostiles.
* **Rozar Balas (Graze):** Acercarse al núcleo de las balas enemigas otorga EXP sin recibir daño.
* **ESC:** Pausar partida y abrir el **Build Inspector** (artefactos equipados y mejoras de nivel obtenidas).
* **R (Mantener 1.2s):** Reinicio seguro de la run (con oscurecimiento progresivo de pantalla).
* **T:** Disparar transmisión de radio de jefe (Dialogic 2.0 con modulación dinámica de audio).
* **Tab:** Saltar diálogos instantáneamente.

### Mando / Joystick (Soporte Nativo Xbox / PS / Switch)
* **Stick Izquierdo / D-Pad:** Movimiento y navegación de menús.
* **Botón Sur (A / Cruz):** Dash / Aceptar en menús.
* **Botón Este (B / Círculo):** Bomba / Volver en menús.
* **Gatillo Derecho (RT / R2):** Disparo Láser Activo.
* **Botón Superior Derecho (RB / R1):** Alternar apuntado pasivo (Auto / Manual).
* **Start:** Menú de Pausa.
* **Select:** Saltar diálogo.

---

## 🖥 Menús y Experiencia de Usuario (UI)
* **Pantalla de Título (`title_screen.tscn`):** Bienvenida cinemática con acceso directo a las Notas de la Versión y transición al Hangar.
* **Hangar Estelar 3D (`hub_world.tscn`):** Hub interactivo para selección de heroínas, terminal de ajustes, árbol de talentos y sala de trofeos.
* **Selección de Personajes (`character_select.tscn`):** Roster de 6 heroínas con retratos vectoriales, atributos base, pasivas y enlaces de personalización.
* **Ajustes y Configuración (`settings_modal.tscn`):** Resoluciones (16:9, 21:9 Ultrawide, 16:10 Steam Deck), volumen Master/Música/SFX y remapeo completo de teclas y mando.
* **Pausa & Build Inspector (`pause_menu.tscn`):** Inspección detallada en dos columnas de artefactos equipados y mejoras activas.
* **EXP Blobs Coalescentes (`exp_blob.tscn`):** Gotas de experiencia que se fusionan por proximidad ($d \le 52\text{ px}$) en 4 tiers escalonados con atracción magnética para garantizar un rendimiento óptimo a 60 FPS.
