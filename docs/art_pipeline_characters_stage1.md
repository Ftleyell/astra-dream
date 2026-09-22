# GUÍA TÉCNICA Y ESPECIFICACIÓN DE ASSETS: PERSONAJES (ETAPA 1)
# PROYECTO: ASTRA DREAM / DANMAKU SPACE PROTOCOL
**Versión:** 1.0 (Etapa 1: Sprites Estáticos de 1 Frame)  
**Destinatario:** Artista / Ilustrador 2D  
**Objetivo:** Proporcionar las directrices visuales, dimensiones de lienzo, nombres de archivo y reglas técnicas exactas para crear e importar los assets iniciales de las 6 heroínas principales sin fricción técnica.

---

## 1. REGLAS MAESTRAS DE PRODUCCIÓN

### 1.1 Formato de Archivo y Espacio de Color
* **Formato:** PNG con canal alfa activo (fondo 100% transparente, RGBA 8-bit por canal).
* **Espacio de Color:** sRGB.
* **Margen / Padding:** Dejar entre 6 y 10 píxeles libres respecto a los bordes del lienzo para evitar cortes bruscos en rotaciones o escalados.

### 1.2 La Regla del "Hitbox Core" (Vital para Bullet Hell / Danmaku)
En el combate de *Astra Dream*, los proyectiles enemigos colisionan únicamente contra un punto diminuto de la nave del jugador:
* **Ubicación obligatoria:** El centro geométrico exacto de la nave: coordenada $(128, 128)$ en el lienzo de 256×256.
* **Elemento visual:** El diseño de la nave DEBE incluir en esa posición un **núcleo, reactor, cabina brillante o gema de energía** con un diámetro de **10 a 16 píxeles**, de color brillante y altamente contrastante con el fuselaje (ej. cian brillante, ámbar, magenta).
* **Alas y alerones decorativos:** Todo el resto del fuselaje, alas y alerones son visualmente decorativos; las balas pueden atravesarlos sin infligir daño.

### 1.3 Convenciones de Orientación en Motor (Godot 4)
* **Naves de Combate:** Deben dibujarse con la **PROA (frente de la nave) apuntando verticalmente hacia ARRIBA** ($-\text{Y}$, ángulo de $90^\circ$). Las toberas/motores deben apuntar hacia abajo.
* **Armas Rotatorias:** Deben dibujarse en posición horizontal con el **CAÑÓN / BOCA DE DISPARO apuntando hacia la DERECHA** ($+\text{X}$, ángulo nativo $0^\circ$ de Godot). El punto de montaje/anclaje pivota en el centro $(64, 64)$ o centro-izquierdo $(32, 64)$ del lienzo de 128×128.

---

## 2. RESUMEN DE ENTREGABLES Y RUTAS EN EL PROYECTO

Cada personaje requiere exactamente **4 archivos**. La estructura de carpetas en el proyecto es:

```
astra_dream/
└── assets/
    └── characters/
        ├── ships/       # Naves de combate (256x256 px, vista superior, hacia ARRIBA)
        ├── weapons/     # Armas de combate (128x128 px, horizontal, hacia la DERECHA)
        ├── portraits/   # Retratos / Bustos (512x512 px, cuadrados, selección y HUD)
        └── fullbody/    # Ilustraciones de piloto (1200x1600 px, 3:4, cuerpo entero/3 cuartos)
```

### Tabla Resumen de Nomenclatura
| Personaje | ID Interno | Nave de Combate | Arma Principal | Retrato UI | Cuerpo Completo |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Nova** | `nova` | `ship_nova.png` | `weapon_nova.png` | `portrait_nova.png` | `fullbody_nova.png` |
| **Valentina** | `valentina` | `ship_valentina.png` | `weapon_valentina.png` | `portrait_valentina.png` | `fullbody_valentina.png` |
| **Kira** | `kira` | `ship_kira.png` | `weapon_kira.png` | `portrait_kira.png` | `fullbody_kira.png` |
| **Selene** | `selene` | `ship_selene.png` | `weapon_selene.png` | `portrait_selene.png` | `fullbody_selene.png` |
| **Roxy** | `roxy` | `ship_roxy.png` | `weapon_roxy.png` | `portrait_roxy.png` | `fullbody_roxy.png` |
| **Echo** | `echo` | `ship_echo.png` | `weapon_echo.png` | `portrait_echo.png` | `fullbody_echo.png` |

---

## 3. FICHAS TÉCNICAS Y CONCEPTUALES POR PERSONAJE

---

### 1. NOVA — "La Piloto de Vanguardia Impulsiva"
* **Rol / Arquetipo:** Asalto a hiper-velocidad, combate a corta/media distancia, daño ígneo.
* **Paleta de Color:** Blanco ártico `#FFFFFF`, Naranja neón `#FF7A00`, Acento Cian energético `#00F0FF`, Gris espacial `#2C3345`.

#### Archivos a entregar:
1. `res://assets/characters/ships/ship_nova.png`
   - **Dimensiones:** $256 \times 256\text{ px}$.
   - **Orientación:** Proa hacia ARRIBA.
   - **Concepto Visual:** Caza interceptor delta de alta aerodinámica. Alas en flecha invertida o ala delta pronunciada, toberas gemelas con resplandor térmico, fuselaje blanco pulido con franjas de competición naranja neón.
   - **Hitbox Core:** Reactor de fusión circular cian/naranja en el centro exacto $(128, 128)$.
2. `res://assets/characters/weapons/weapon_nova.png`
   - **Dimensiones:** $128 \times 128\text{ px}$.
   - **Orientación:** Cañón apuntando a la DERECHA.
   - **Concepto Visual:** *Blaster Ígneo Vectorial*. Cañón doble corto con rejillas de ventilación de calor residual al rojo vivo y celda de plasma visible.
3. `res://assets/characters/portraits/portrait_nova.png`
   - **Dimensiones:** $512 \times 512\text{ px}$ (Cuadrado).
   - **Concepto Visual:** Rostro y busto de Nova. Expresión confiada y enérgica, visor panorámico naranja levantado en la frente, coletas castañas con reflejos cobrizos, cuello de mono de vuelo térmico.
4. `res://assets/characters/fullbody/fullbody_nova.png`
   - **Dimensiones:** $1200 \times 1600\text{ px}$ (Proporción 3:4).
   - **Concepto Visual:** Cuerpo completo en pose dinámica de piloto de vanguardia. Traje de vuelo ceñido de alta tecnología, botas de propulsión vectoriales, casco bajo el brazo o visera translúcida.

---

### 2. VALENTINA — "La Francotiradora y Estratega Fría"
* **Rol / Arquetipo:** Ataques quirúrgicos a larga distancia, daño crítico letal, Bullet-Time.
* **Paleta de Color:** Negro azabache `#12141C`, Azul eléctrico `#0066FF`, Acento Carmesí táctico `#FF2A55`, Plata `#D8E0F0`.

#### Archivos a entregar:
1. `res://assets/characters/ships/ship_valentina.png`
   - **Dimensiones:** $256 \times 256\text{ px}$.
   - **Orientación:** Proa hacia ARRIBA.
   - **Concepto Visual:** Exocaza de intercepción y francotirador. Fuselaje extremadamente estilizado y afilado, alas de flecha delgadas tipo aguja, estabilizadores magnéticos extendidos hacia atrás.
   - **Hitbox Core:** Lente de telemetría / prisma gravitatorio azul gélido en $(128, 128)$.
2. `res://assets/characters/weapons/weapon_valentina.png`
   - **Dimensiones:** $128 \times 128\text{ px}$.
   - **Orientación:** Cañón apuntando a la DERECHA.
   - **Concepto Visual:** *Riel Acelerador Magnético*. Cañón de riel extra-largo con bobinas electromagnéticas cilíndricas azul eléctrico y mira telescópica holográfica.
3. `res://assets/characters/portraits/portrait_valentina.png`
   - **Dimensiones:** $512 \times 512\text{ px}$ (Cuadrado).
   - **Concepto Visual:** Busto de Valentina. Mirada fría, analítica y calculadora; monóculo táctico con retícula roja en el ojo izquierdo; cabello plateado/blanco corto con corte asimétrico.
4. `res://assets/characters/fullbody/fullbody_valentina.png`
   - **Dimensiones:** $1200 \times 1600\text{ px}$.
   - **Concepto Visual:** Pose formal y elegante de pie. Capa táctica corta con forro electromagnético azul, uniforme militar espacial negro ceñido con placas ligeras, guantes de francotiradora.

---

### 3. KIRA — "La Ingeniera Caótica de Drones"
* **Rol / Arquetipo:** Invocaciones de drones, control de área, daño de racimo y metralla.
* **Paleta de Color:** Amarillo industrial `#FFB800`, Gris grafito mate `#383C45`, Naranja de advertencia `#FF5500`, Blanco técnico `#EBF0F5`.

#### Archivos a entregar:
1. `res://assets/characters/ships/ship_kira.png`
   - **Dimensiones:** $256 \times 256\text{ px}$.
   - **Orientación:** Proa hacia ARRIBA.
   - **Concepto Visual:** Nave de taller y despliegue rápido. Chasis asimétrico, placas de blindaje atornilladas, bahías laterales de lanzamiento de micro-drones, antenas de comunicación y cables visibles.
   - **Hitbox Core:** Generador de sobrecarga nanotecnológica ámbar/amarillo brillante en $(128, 128)$.
2. `res://assets/characters/weapons/weapon_kira.png`
   - **Dimensiones:** $128 \times 128\text{ px}$.
   - **Orientación:** Cañón apuntando a la DERECHA.
   - **Concepto Visual:** *Lanzador de Racimo Nanotecnológico*. Tambor rotatorio pesado con cabezales de micro-misiles y cableado de ignición expuesto.
3. `res://assets/characters/portraits/portrait_kira.png`
   - **Dimensiones:** $512 \times 512\text{ px}$ (Cuadrado).
   - **Concepto Visual:** Sonrisa traviesa e hiperactiva, gafas de aumento holográficas múltiples sobre la frente, marcas de hollín o grasa en la mejilla, cabello alborotado color trigo o caramelo.
4. `res://assets/characters/fullbody/fullbody_kira.png`
   - **Dimensiones:** $1200 \times 1600\text{ px}$.
   - **Concepto Visual:** Pose inquieta y energética. Mono de trabajo con tirantes caídos, guantes exoesqueleto sobredimensionados para ensamblaje mecánico, cinturón cargado de herramientas flotantes y nanodrones.

---

### 4. SELENE — "La Navegante y Ocultista del Vacío"
* **Rol / Arquetipo:** Manipulación gravitatoria, vórtices de vacío, succión y teletransporte.
* **Paleta de Color:** Púrpura cósmico `#4A1570`, Morado nebulosa `#8E3CD8`, Oro estelar `#E6B800`, Negro profundo `#0A0612`.

#### Archivos a entregar:
1. `res://assets/characters/ships/ship_selene.png`
   - **Dimensiones:** $256 \times 256\text{ px}$.
   - **Orientación:** Proa hacia ARRIBA.
   - **Concepto Visual:** Crucero del vacío en forma de arco o luna creciente envolvente. Superficie biomecánica suave con runas doradas que brillan tenuemente y alerones curvados que parecen abrazar el espacio.
   - **Hitbox Core:** Orbe de singularidad gravitacional morado pulsante con halo dorado en $(128, 128)$.
2. `res://assets/characters/weapons/weapon_selene.png`
   - **Dimensiones:** $128 \times 128\text{ px}$.
   - **Orientación:** Apuntando a la DERECHA.
   - **Concepto Visual:** *Cetro de Singularidad Gravitatoria*. Reliquia ceremonial tecnológica con tres aros concéntricos dorados flotando magnéticamente alrededor de un núcleo de energía oscura.
3. `res://assets/characters/portraits/portrait_selene.png`
   - **Dimensiones:** $512 \times 512\text{ px}$ (Cuadrado).
   - **Concepto Visual:** Expresión serena, misteriosa y espiritual; ojos violetas profundos; corona o diadema con estética de media luna dorada; cabello ondulado oscuro con destellos de polvo estelar.
4. `res://assets/characters/fullbody/fullbody_selene.png`
   - **Dimensiones:** $1200 \times 1600\text{ px}$.
   - **Concepto Visual:** Pose etérea flotante. Túnica ceremonial fluida adaptada al vacío espacial con bordados dorados, orbes gravitatorios flotando en la palma de su mano.

---

### 5. ROXY — "La Especialista en Armamento Pesado"
* **Rol / Arquetipo:** Tanque agresivo de demolición, absorción de daño, dispersión de escopeta masiva y embestida sísmica.
* **Paleta de Color:** Rojo carmesí de combate `#CC1133`, Grafito blindado `#20242B`, Bronce industrial `#A86D32`, Acero templado `#8A9BA8`.

#### Archivos a entregar:
1. `res://assets/characters/ships/ship_roxy.png`
   - **Dimensiones:** $256 \times 256\text{ px}$.
   - **Orientación:** Proa hacia ARRIBA.
   - **Concepto Visual:** Acorazado ariete pesado. Silueta ancha y trapezoidal con frontal reforzado tipo espolón rompehielos/deflector, placas de blindaje multicapa superpuestas con remaches y toberas de escape masivas.
   - **Hitbox Core:** Celda de impacto reforzada de color rojo rubí resplandeciente en $(128, 128)$.
2. `res://assets/characters/weapons/weapon_roxy.png`
   - **Dimensiones:** $128 \times 128\text{ px}$.
   - **Orientación:** Cañón apuntando a la DERECHA.
   - **Concepto Visual:** *Cañón de Impacto Sísmico*. Escopeta de dispersión pesada de dos o cuatro bocas cuadradas con pistones amortiguadores visibles y boca de fuego masiva.
3. `res://assets/characters/portraits/portrait_roxy.png`
   - **Dimensiones:** $512 \times 512\text{ px}$ (Cuadrado).
   - **Concepto Visual:** Expresión desafiante, audaz y protectora; cabello castaño oscuro recogido en una cola de caballo alta; pequeña cicatriz en el puente de la nariz; hombrera blindada visible en el encuadre.
4. `res://assets/characters/fullbody/fullbody_roxy.png`
   - **Dimensiones:** $1200 \times 1600\text{ px}$.
   - **Concepto Visual:** Pose firme y sólida con las piernas separadas. Exotraje de exploración pesada con coraza pectoral masiva, hombreras deflectoras angulares y botas reforzadas con anclajes al suelo.

---

### 6. ECHO — "La Androide de Telemetría y Ciber-Guerra"
* **Rol / Arquetipo:** Debuffs digitales, descargas de rayos encadenados, teletransporte cuántico ("flicker").
* **Paleta de Color:** Blanco cerámico pulido `#F5FAFF`, Cian ciberespacial `#00E5FF`, Azul de datos `#0055AA`, Gris platino `#B8C5D0`.

#### Archivos a entregar:
1. `res://assets/characters/ships/ship_echo.png`
   - **Dimensiones:** $256 \times 256\text{ px}$.
   - **Orientación:** Proa hacia ARRIBA.
   - **Concepto Visual:** Aguja cuántica geométrica y minimalista. Chasis blanco cerámico sin costuras visibles, alas flotantes magnéticas desprendidas del cuerpo central y filamentos de datos cian brillantes conectando las piezas.
   - **Hitbox Core:** Núcleo de computación cuántica cian hiperbrillante en $(128, 128)$.
2. `res://assets/characters/weapons/weapon_echo.png`
   - **Dimensiones:** $128 \times 128\text{ px}$.
   - **Orientación:** Emisor apuntando a la DERECHA.
   - **Concepto Visual:** *Transmisor de Código Corruptor*. Emisor de interferencia cibernética con prisma cristalino flotante y agujas conectoras de inducción eléctrica.
3. `res://assets/characters/portraits/portrait_echo.png`
   - **Dimensiones:** $512 \times 512\text{ px}$ (Cuadrado).
   - **Concepto Visual:** Rostro androide de belleza sintética y expresión estoica/curiosa; ojos cian luminosos sin pupilas convencionales o con marcas de código; uniones articulares finas en la mandíbula; cabello que se difumina en filamentos de fibra óptica.
4. `res://assets/characters/fullbody/fullbody_echo.png`
   - **Dimensiones:** $1200 \times 1600\text{ px}$.
   - **Concepto Visual:** Pose elegante e ingrávida. Chasis androide bio-mecánico blanco con juntas de rótula visibles en rodillas y codos, paneles translúcidos con microchips iluminados y cableado de datos cian fluido.

---

## 4. LISTA DE COMPROBACIÓN FINAL ANTES DE EXPORTAR

* [ ] ¿Las 6 naves tienen un tamaño de lienzo de exactamente **256 × 256 px**?
* [ ] ¿La proa de las 6 naves apunta hacia **ARRIBA**?
* [ ] ¿El **Hitbox Core** brillante de $10\text{-}16\text{ px}$ está centrado en la coordenada $(128, 128)$ de cada nave?
* [ ] ¿Las 6 armas tienen un tamaño de lienzo de exactamente **128 × 128 px** apuntando hacia la **DERECHA**?
* [ ] ¿Los 6 retratos de UI son de **512 × 512 px** centrados en rostro/hombros?
* [ ] ¿Las 6 ilustraciones de piloto son de **1200 × 1600 px** sobre fondo 100% transparente?
* [ ] ¿Los nombres de archivo coinciden al 100% con la tabla de nomenclatura (minúsculas, con guión bajo `_`)?

---

*Cualquier duda o propuesta de ajuste estilístico, comunicarse con el equipo de desarrollo técnico de Astra Dream.*
