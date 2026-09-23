# Guía de Especificaciones Técnicas y de Arte: Parallax del Espacio Exterior (Hub 3D)

**Proyecto:** Astra: Dream  
**Módulo:** Hangar Espacial / Hub 3D (Gran Ventanal Panorámico)  
**Destinatario:** Equipo de Arte 2D / Background Artists  
**Versión:** 1.0  

---

## 1. Visión General del Sistema Visual

El Hangar 3D donde comienza el juego cuenta con un **Gran Ventanal Panorámico** al frente. A través de este ventanal, el jugador contempla el espacio exterior mientras camina libremente por la sala.

Para lograr una sensación de escala colosal y profundidad tridimensional sin sobrecargar el rendimiento, el fondo espacial se compone de **3 capas de planos 2.5D superpuestas en el espacio 3D a distintas distancias en el eje Z**. Cuando la cámara del jugador se desplaza lateralmente con WASD, cada capa se mueve a una velocidad relativa diferente, generando un **efecto Parallax real y dinámico**.

```
[ Interior del Hangar 3D ]
      |
[ Gran Ventanal Panorámico ]
      |
      |   (Z = -25m)   Capa 3: Near Space (Polvo cósmico, asteroides, satélites) -> Movimiento rápido
      |   (Z = -50m)   Capa 2: Midground (Estrellas nítidas, planeta/luna gigante) -> Movimiento medio
      |   (Z = -90m)   Capa 1: Deep Space (Nebulosas galácticas, vacío cósmico) -> Movimiento ultra lento
```

---

## 2. Especificación Detallada de las 3 Capas

### Capa 1: Deep Space (Fondo Lejano / Vacío y Nebulosa)
* **Archivo:** `space_parallax_layer0_deep.png`
* **Ubicación 3D:** Plano de fondo a `Z = -90m`.
* **Dimensiones:** `3840 x 2160 px` (4K UHD) o `2048 x 2048 px` (Tileable horizontalmente).
* **Formato:** PNG 24-bit (Opaco o con gradientes suaves).
* **Contenido Visual:**
  - Nubes de gas estelar y nebulosas galácticas envolventes.
  - Gradiente cósmico profundo: violeta oscuro (`#0A051B`), azul abisal (`#050814`) y destellos difusos en magenta y cian.
  - Brillos de galaxias lejanas sin estrellas individuales nítidas (para no competir con la Capa 2).
* **Comportamiento:** Prácticamente estático; reacciona con parallax imperceptible, anclando el horizonte infinito.

---

### Capa 2: Midground (Capa Media / Planeta Orbital y Campo Estelar)
* **Archivo:** `space_parallax_layer1_mid.png`
* **Ubicación 3D:** Plano a `Z = -50m`.
* **Dimensiones:** `2048 x 2048 px` (o lienzo panorámico `4096 x 2048 px`).
* **Formato:** PNG 32-bit con **canal Alfa (Transparencia completa requerida)**.
* **Contenido Visual:**
  - **Planeta Colosal / Luna Tecnológica:** Planeta ciberpunk visible en uno de los cuadrantes (con líneas de luz de ciudades o circuitos bioluminiscentes verdes/cian, o anillos planetarios estilizados).
  - **Campo de Estrellas Nítidas:** Cúmulos estelares brillantes en primer plano medio, con variación de tamaño (puntos de 2 a 5 px) y tonos blanco puro, cian neón (`#00F0FF`) y ámbar.
* **Comportamiento:** Movimiento suave al caminar el piloto; el planeta ofrece un punto focal cinematográfico impactante.

---

### Capa 3: Foreground Space (Capa Frontal / Polvo Cósmico y Restos Espaciales)
* **Archivo:** `space_parallax_layer2_near.png`
* **Ubicación 3D:** Plano a `Z = -25m` (justo detrás del cristal exterior).
* **Dimensiones:** `2048 x 1080 px`.
* **Formato:** PNG 32-bit con **canal Alfa (Transparencia completa requerida)**.
* **Contenido Visual:**
  - Partículas de polvo cósmico brillante y micro-meteoritos flotantes.
  - Fragmentos de chatarra espacial, paneles solares a la deriva o una baliza satelital parpadeante con luz roja/cian.
  - Elementos dispersos para no tapar la vista del planeta ni la nebulosa.
* **Comportamiento:** Movimiento pronunciado (efecto de cercanía inmediata). Al desplazarse el piloto 2 metros a la derecha, estos elementos se desplazan notablemente en el campo de visión.

---

## 3. Paleta Cromática y Estilo Artístico (Psycho-Pop / Cyberpunk)

El juego utiliza una identidad visual de **Sci-Fi Anime / Psycho-Pop**:

| Elemento | Color Hexadecimal | Descripción |
| :--- | :--- | :--- |
| **Fondo Abisal** | `#050711` a `#0E0B1F` | Negro azulado profundo y violeta noche espacial |
| **Acentos Nebulosa** | `#7928CA` y `#FF0080` | Púrpura cósmico y magenta brillante |
| **Bioluminiscencia** | `#00FF9D` | Verde esmeralda (Biomasa de las constelaciones) |
| **Luces de Nave y Estrellas** | `#00F0FF` y `#FFFFFF` | Cian neón puro y blanco nítido |
| **Alerta / Balizas** | `#FFB703` y `#FF0055` | Ámbar dorado y rojo láser |

---

## 4. Requisitos de Entrega para el Artista

1. **Estructura de Carpetas:**
   ```
   assets/
     environments/
       hub_space_parallax/
         space_parallax_layer0_deep.png
         space_parallax_layer1_mid.png
         space_parallax_layer2_near.png
   ```
2. **Configuración de Texturas en Godot:**
   - Modo de importación: `Texture2D`.
   - Compresión: `Lossless` o `VRAM Compressed`.
   - Filtro: `Linear Mipmap`.
3. **Seamless / Repetición:**
   - La Capa 0 (Deep Space) debe tener bordes horizontales continuos (seamless horizontal tiling) si es de 2048x2048, o abarcar una relación ultra-ancha (3840x2160) para no requerir repetición visible.
