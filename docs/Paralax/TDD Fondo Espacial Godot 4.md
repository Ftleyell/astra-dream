# **Arquitectura de Fondos Espaciales Infinitos Multicapa y Transición de Biomas en Godot 4.3**

## **1\. Requerimientos de Arquitectura en Godot 4.3+**

### **Evaluación Técnica de Soluciones de Scroll: Parallax2D frente a Shaders en Espacio de Pantalla**

El desarrollo de simuladores y juegos de exploración espacial en dos dimensiones donde la entidad del jugador puede navegar de forma irrestricta plantea un desafío de diseño: la eliminación de la percepción de planaridad y la mitigación de los artefactos de repetición visual o *tiling*1. Históricamente, las implementaciones en motores gráficos 2D han dependido de sistemas de scroll por capas ortogonales, los cuales revelan rápidamente patrones cíclicos e inflexibles al desplazarse distancias considerables sobre el espacio cartesiano1.  
En Godot 4.3+, la arquitectura de renderizado 2D incorporó una renovación completa con la introducción del nodo Parallax2D, concebido para consolidar y reemplazar la jerarquía heredada de ParallaxBackground y ParallaxLayer3. A diferencia de los nodos anteriores —que dependían de un acoplamiento estricto a un CanvasLayer y presentaban fallos de posicionamiento al sincronizarse con cámaras rotadas o con zoom pronunciado—, el nodo Parallax2D hereda directamente de Node2D3. Esta naturaleza simplifica su integración espacial, admite el seguimiento nativo de rotaciones de la cámara, responde adecuadamente a las operaciones de zoom sin desfases de proyección y gestiona el ciclo modular infinito a través de su propiedad repeat\_size1.  
No obstante, cuando se diseñan fondos cósmicos profundos que contienen nebulosas densas, campos de polvo de gas y gradientes lumínicos continuos, el uso aislado de Parallax2D exhibe debilidades estructurales1. Incluso al emplear texturas extensas (como ![][image1] o ![][image2] píxeles), el ojo humano identifica con rapidez la repetición periódica de cúmulos de gas y formas singulares al atravesar el eje de repetición1.  
Para resolver este compromiso técnico, la arquitectura óptima consiste en un **modelo desacoplado híbrido**:

> 1. **Plano Cósmico Base Procedural Continuo:** Se procesa mediante un ColorRect a pantalla completa anclado a un CanvasLayer en un plano de orden negativo profundo (layer \= \-100). Dicho cuadrilátero ejecuta un shader de lienzo (*canvas\_item*) que proyecta las coordenadas del mundo reconstruidas analíticamente a partir de la posición real de la cámara y el tamaño del viewport5. La nebulosa y las estrellas de fondo no experimentan saltos de textura ni duplicación modular física; se calculan matemáticamente mediante combinaciones de ruido y campos de hashes matriciales continuos5.  
> 2. **Capas Cinemáticas Discretas de Parallax:** Los elementos macroscópicos del entorno espacial (cuerpos planetarios, restos estructurales, estaciones espaciales, asteroides y campos de partículas volumétricas) se instancian a través de nodos Parallax2D distribuidos con factores de escala de desplazamiento (scroll\_scale) escalonados y configuraciones analíticas de repeat\_size calculadas para exceder el marco de la vista1.

| Parámetro de Evaluación | Implementación Clásica (ParallaxLayer) | Parallax2D Nativo Puro | Arquitectura Híbrida (CanvasLayer \+ Parallax2D) |
| :---- | :---- | :---- | :---- |
| **Mitigación de Tiling** | Nula; visible en cada ciclo de réplica1. | Limitada al tamaño de repetición de la textura1. | Absoluta en fondo gaseoso; controlada en props dispersos2. |
| **Soporte de Rotación de Cámara** | Roto; requiere parches matemáticos en script3. | Integrado nativamente en C++ dentro de Godot 4.3+3. | Fondo procedural compensado por shader; props nativos3. |
| **Sobrecarga de Dibujado (Overdraw)** | Variable según la cantidad de cuadriláteros2. | Escasa si los props se recortan con precisión2. | Mínima: un pase de fondo a pantalla completa y props aislados2. |
| **Consumo de Memoria VRAM** | Alto; depende de texturas cósmicas gigantescas2. | Elevado si se intentan mitigar las repeticiones2. | Óptimo: mapas de ruido reducidos y generadores analíticos7. |
| **Manejo de Zoom Dinámico** | Se desajusta el factor de repetición3. | Soporta duplicación mediante repeat\_times1. | Resuelto nativamente en shader y en los nodos hijos3. |

### **Jerarquía Estructurada de Capas**

El orden de renderizado en el árbol de nodos de la escena define la percepción de profundidad atmosférica. Los componentes se apilan de acuerdo con sus propiedades espaciales y ópticas:

| Nivel de Profundidad | Nodo en Godot 4.3 | Configuración Clave | Propósito Visual y Comportamiento |
| :---- | :---- | :---- | :---- |
| **Capa 0: Fondo Cósmico y Nebulosa** | CanvasLayer (layer \= \-100) ![][image3] ColorRect | Material: Shader procedural continuo. Coordenadas mundo de la cámara. | Síntesis matemática del vacío, nubes de gas volumétrico e iluminación difusa interestelar5. |
| **Capa 1: Polvo Estelar y Estrellas Lejanas** | Parallax2D | scroll\_scale \= Vector2(0.02, 0.02) repeat\_size \= Vector2(2048, 2048\) | Partículas finas y cúmulos galácticos lejanos con desplazamiento apenas perceptible1. |
| **Capa 2: Landmarks Cósmicos Lejanos** | Parallax2D | scroll\_scale \= Vector2(0.08, 0.08) repeat\_size \= Vector2(8192, 8192\) | Planetas gigantes, estrellas binarias lejanas y lunas de fondo con baja frecuencia de aparición1. |
| **Capa 3: Campo Estelar Medio** | Parallax2D | scroll\_scale \= Vector2(0.25, 0.25) repeat\_size \= Vector2(1920, 1080\) | Estrellas principales con destellos y gradientes cromáticos diferenciados1. |
| **Capa 4: Cinturón de Chatarra y Asteroides** | Parallax2D | scroll\_scale \= Vector2(0.60, 0.60) repeat\_size \= Vector2(3000, 3000\) | Siluetas mecánicas rotas, desechos orbitales y asteroides con paralaje acentuado1. |
| **Capa 5: Plano Físico Interactivo** | Node2D (z\_index \= 0\) | Entidades dinámicas, colisiones, proyectiles, nave del jugador y Camera2D. | Espacio de simulación cinemática donde se ejecutan las mecánicas de juego. |

### **Implementación en Godot Shading Language (GLSL)**

El siguiente sombreador (universe\_nebula.gdshader) se asigna al material del ColorRect de pantalla completa. Utiliza una matriz analítica de celdas pseudoaleatorias para el campo estelar continuo y dos muestras de ruido con desfases asimétricos para la formación de gas cósmico, eliminando cualquier costura visible5.

OpenGL Shading Language  
shader\_type canvas\_item;  
render\_mode unshaded;

// Sincronización de proyección espacial  
uniform vec2 camera\_world\_position \= vec2(0.0);  
uniform vec2 viewport\_size \= vec2(1920.0, 1080.0);

// Control visual del bioma y gas cósmico  
uniform sampler2D noise\_texture : repeat\_enable, filter\_linear;  
uniform vec4 base\_space\_color : source\_color \= vec4(0.01, 0.012, 0.025, 1.0);  
uniform vec4 nebula\_color\_primary : source\_color \= vec4(0.18, 0.05, 0.32, 1.0);  
uniform vec4 nebula\_color\_secondary : source\_color \= vec4(0.02, 0.22, 0.40, 1.0);  
uniform float nebula\_density : hint\_range(0.0, 3.0) \= 0.90;  
uniform float nebula\_scale : hint\_range(0.00001, 0.005) \= 0.00035;

// Control analítico de estrellas procedurales  
uniform float star\_density : hint\_range(10.0, 300.0) \= 90.0;  
uniform float star\_brightness\_cutoff : hint\_range(0.70, 0.999) \= 0.965;  
uniform float chromatic\_aberration : hint\_range(0.0, 0.02) \= 0.0;

// Función de dispersión analítica sin dependencia de texturas  
float hash21(vec2 p) {  
    p \= fract(p \* vec2(123.34, 456.21));  
    p \+= dot(p, p \+ 45.32);  
    return fract(p.x \* p.y);  
}

// Generador analítico de estrellas en celdas espaciales discretas  
float evaluate\_star\_field(vec2 world\_pos, float cell\_scale, float threshold) {  
    vec2 grid\_uv \= world\_pos \* cell\_scale;  
    vec2 id \= floor(grid\_uv);  
    vec2 gv \= fract(grid\_uv) \- 0.5;

    float n \= hash21(id);  
    float star \= 0.0;

    if (n \> threshold) {  
        vec2 offset \= vec2(hash21(id \+ 1.1), hash21(id \+ 2.3)) \- 0.5;  
        float dist \= length(gv \- offset \* 0.65);  
        float brightness \= smoothstep(0.07, 0.001, dist);  
        float twinkle \= sin(TIME \* (1.5 \+ n \* 4.0) \+ n \* 6.28) \* 0.35 \+ 0.65;  
        star \= brightness \* twinkle \* smoothstep(threshold, 1.0, n);  
    }  
    return star;  
}

void fragment() {  
    // Reconstrucción de coordenadas globales reales del mundo  
    vec2 screen\_coord \= SCREEN\_UV \* viewport\_size;  
    vec2 world\_uv \= screen\_coord \+ camera\_world\_position;

    // 1\. Color base de radiación de fondo  
    vec3 out\_color \= base\_space\_color.rgb;

    // 2\. Composición de nebulosa mediante muestreo asimétrico no periódico  
    vec2 uv\_gas\_layer\_a \= world\_uv \* nebula\_scale \* 0.5;  
    vec2 uv\_gas\_layer\_b \= (world\_uv \+ vec2(2341.0, \-1193.0)) \* (nebula\_scale \* 1.25);

    // Lectura con soporte de aberración cromática opcional  
    float gas\_a \= texture(noise\_texture, uv\_gas\_layer\_a).r;  
    float gas\_b \= texture(noise\_texture, uv\_gas\_layer\_b \+ vec2(chromatic\_aberration, 0.0)).g;  
      
    float composite\_gas \= smoothstep(0.20, 0.88, (gas\_a \* 0.65 \+ gas\_b \* 0.55) \* nebula\_density);  
    vec3 gas\_palette \= mix(nebula\_color\_primary.rgb, nebula\_color\_secondary.rgb, gas\_b);  
    out\_color \+= gas\_palette \* composite\_gas;

    // 3\. Campo de estrellas lejanas (desplazamiento analítico ultra-lento)  
    float stars\_far \= evaluate\_star\_field(world\_uv \* 0.04, 0.05 \* star\_density, star\_brightness\_cutoff);  
    out\_color \+= vec3(stars\_far);

    // 4\. Campo de estrellas intermedias  
    float stars\_mid \= evaluate\_star\_field(world\_uv \* 0.12, 0.025 \* star\_density, star\_brightness\_cutoff \+ 0.015);  
    out\_color \+= vec3(stars\_mid \* 0.8, stars\_mid \* 0.9, stars\_mid);

    COLOR \= vec4(out\_color, 1.0);  
}

### **Script de Vinculación de Cámara (BackgroundSync.gd)**

El script se ancla al nodo ColorRect para sincronizar las matrices de transformación del viewport y la posición global de la cámara activa en cada iteración de renderizado8.

GDScript  
class\_name BackgroundSync  
extends ColorRect

@export var target\_camera: Camera2D

var \_mat: ShaderMaterial

func \_ready() \-\> void:  
	assert(material is ShaderMaterial, "BackgroundSync requiere un recurso ShaderMaterial asignado.")  
	\_mat \= material as ShaderMaterial  
	\_sync\_viewport\_dimensions()  
	get\_viewport().size\_changed.connect(\_sync\_viewport\_dimensions)

func \_process(\_delta: float) \-\> void:  
	if not is\_instance\_valid(target\_camera):  
		target\_camera \= get\_viewport().get\_camera\_2d()  
		if not is\_instance\_valid(target\_camera):  
			return

	var cam\_pos: Vector2 \= target\_camera.global\_position  
	\_mat.set\_shader\_parameter("camera\_world\_position", cam\_pos)

func \_sync\_viewport\_dimensions() \-\> void:  
	var vp\_rect: Vector2 \= get\_viewport\_rect().size  
	size \= vp\_rect  
	if is\_instance\_valid(\_mat):  
		\_mat.set\_shader\_parameter("viewport\_size", vp\_rect)

## **2\. Sistema de Biomas y Transición Gradual**

### **Formulación Matemática de Transición**

Las transiciones abruptas en el espacio provocan saltos de luminancia perceptibles. Para obtener una transición natural, el sistema debe garantizar continuidad de clase ![][image4] en las fronteras entre sectores. La interpolación lineal estándar genera discontinuidades en las primeras derivadas de los vectores de color en los puntos de contacto.  
Por consiguiente, la razón de cambio entre dos biomas ![][image5] y ![][image6] se evalúa mediante la formulación quíntica de Ken Perlin (*smootherstep*):  
![][image7]  
En esta formulación, ![][image8] representa las coordenadas globales de la nave, ![][image9] el centro del bioma objetivo, ![][image10] su radio total de cobertura y ![][image11] la longitud del margen de transición o borde difuso. Cuando la nave se desplaza dentro de una región de influencia compartida entre múltiples sectores, la mezcla se computa a través de la normalización de funciones de base radial:  
![][image12]  
Donde los pesos individuales ![][image13] calculan el decaimiento gradual del sector hacia el vacío espacial neutro circundante.

### **Recurso de Datos del Bioma (BiomeData.gd)**

GDScript  
class\_name BiomeData  
extends Resource

@export var sector\_name: String \= "Vacío Neutro"  
@export var space\_color: Color \= Color(0.01, 0.012, 0.025, 1.0)  
@export var nebula\_primary: Color \= Color(0.18, 0.05, 0.32, 1.0)  
@export var nebula\_secondary: Color \= Color(0.02, 0.22, 0.40, 1.0)  
@export var nebula\_density: float \= 0.90  
@export var star\_density: float \= 90.0  
@export var star\_brightness\_cutoff: float \= 0.965  
@export var chromatic\_aberration: float \= 0.0

### **Gestor Espacial de Sectores (SectorManager.gd)**

El script SectorManager.gd procesa las distancias relativas de la nave del jugador, pondera los factores de interpolación mediante curvas ![][image4] y actualiza suavemente los uniforms del shader en tiempo de ejecución sin provocar picos de procesamiento (*frametime spikes*) ni recolocaciones abruptas8.

GDScript  
class\_name SectorManager  
extends Node

class SpatialSector:  
	var center: Vector2  
	var radius: float  
	var transition\_width: float  
	var data: BiomeData

	func \_init(p\_center: Vector2, p\_radius: float, p\_width: float, p\_data: BiomeData) \-\> void:  
		center \= p\_center  
		radius \= p\_radius  
		transition\_width \= p\_width  
		data \= p\_data

@export var ship\_reference: Node2D  
@export var cosmic\_quad: ColorRect  
@export var neutral\_biome: BiomeData  
@export var blend\_speed: float \= 2.0

var \_sectors: Array\[SpatialSector\] \= \[\]  
var \_shader\_material: ShaderMaterial

\# Estados interpolados actuales en memoria  
var \_cur\_space\_color: Color  
var \_cur\_neb\_primary: Color  
var \_cur\_neb\_secondary: Color  
var \_cur\_density: float  
var \_cur\_star\_density: float  
var \_cur\_star\_cutoff: float  
var \_cur\_aberration: float

func \_ready() \-\> void:  
	if is\_instance\_valid(cosmic\_quad) and cosmic\_quad.material is ShaderMaterial:  
		\_shader\_material \= cosmic\_quad.material as ShaderMaterial

	\_setup\_neutral\_baseline()  
	\_register\_world\_sectors()

func \_setup\_neutral\_baseline() \-\> void:  
	if not neutral\_biome:  
		neutral\_biome \= BiomeData.new()  
	\_cur\_space\_color \= neutral\_biome.space\_color  
	\_cur\_neb\_primary \= neutral\_biome.nebula\_primary  
	\_cur\_neb\_secondary \= neutral\_biome.nebula\_secondary  
	\_cur\_density \= neutral\_biome.nebula\_density  
	\_cur\_star\_density \= neutral\_biome.star\_density  
	\_cur\_star\_cutoff \= neutral\_biome.star\_brightness\_cutoff  
	\_cur\_aberration \= neutral\_biome.chromatic\_aberration

func \_register\_world\_sectors() \-\> void:  
	\# Sector 1: Nebulosa Ionizada Roja  
	var red\_biome \= BiomeData.new()  
	red\_biome.sector\_name \= "Nebulosa Ionizada"  
	red\_biome.space\_color \= Color(0.04, 0.006, 0.012, 1.0)  
	red\_biome.nebula\_primary \= Color(0.85, 0.15, 0.05, 1.0)  
	red\_biome.nebula\_secondary \= Color(0.95, 0.50, 0.02, 1.0)  
	red\_biome.nebula\_density \= 1.60  
	red\_biome.star\_density \= 60.0  
	red\_biome.star\_brightness\_cutoff \= 0.975  
	red\_biome.chromatic\_aberration \= 0.003  
	\_sectors.append(SpatialSector.new(Vector2(5000, 0), 3000.0, 1200.0, red\_biome))

	\# Sector 2: Cementerio de Chatarra y Desechos Metálicos  
	var scrap\_biome \= BiomeData.new()  
	scrap\_biome.sector\_name \= "Cementerio Mecánico"  
	scrap\_biome.space\_color \= Color(0.008, 0.02, 0.018, 1.0)  
	scrap\_biome.nebula\_primary \= Color(0.12, 0.38, 0.30, 1.0)  
	scrap\_biome.nebula\_secondary \= Color(0.40, 0.45, 0.25, 1.0)  
	scrap\_biome.nebula\_density \= 0.45  
	scrap\_biome.star\_density \= 140.0  
	scrap\_biome.star\_brightness\_cutoff \= 0.940  
	scrap\_biome.chromatic\_aberration \= 0.001  
	\_sectors.append(SpatialSector.new(Vector2(-5000, 4000), 3500.0, 1500.0, scrap\_biome))

func \_process(delta: float) \-\> void:  
	if not is\_instance\_valid(ship\_reference) or not is\_instance\_valid(\_shader\_material):  
		return

	var target \= \_sample\_spatial\_biome(ship\_reference.global\_position)  
	var t: float \= clampf(delta \* blend\_speed, 0.0, 1.0)

	\_cur\_space\_color \= \_cur\_space\_color.lerp(target.space\_color, t)  
	\_cur\_neb\_primary \= \_cur\_neb\_primary.lerp(target.nebula\_primary, t)  
	\_cur\_neb\_secondary \= \_cur\_neb\_secondary.lerp(target.nebula\_secondary, t)  
	\_cur\_density \= lerpf(\_cur\_density, target.nebula\_density, t)  
	\_cur\_star\_density \= lerpf(\_cur\_star\_density, target.star\_density, t)  
	\_cur\_star\_cutoff \= lerpf(\_cur\_star\_cutoff, target.star\_cutoff, t)  
	\_cur\_aberration \= lerpf(\_cur\_aberration, target.chromatic\_aberration, t)

	\_shader\_material.set\_shader\_parameter("base\_space\_color", \_cur\_space\_color)  
	\_shader\_material.set\_shader\_parameter("nebula\_color\_primary", \_cur\_neb\_primary)  
	\_shader\_material.set\_shader\_parameter("nebula\_color\_secondary", \_cur\_neb\_secondary)  
	\_shader\_material.set\_shader\_parameter("nebula\_density", \_cur\_density)  
	\_shader\_material.set\_shader\_parameter("star\_density", \_cur\_star\_density)  
	\_shader\_material.set\_shader\_parameter("star\_brightness\_cutoff", \_cur\_star\_cutoff)  
	\_shader\_material.set\_shader\_parameter("chromatic\_aberration", \_cur\_aberration)

func \_sample\_spatial\_biome(ship\_pos: Vector2) \-\> Dictionary:  
	var total\_weight: float \= 0.0  
	var acc\_space: Color \= Color.BLACK  
	var acc\_prim: Color \= Color.BLACK  
	var acc\_sec: Color \= Color.BLACK  
	var acc\_density: float \= 0.0  
	var acc\_star\_density: float \= 0.0  
	var acc\_cutoff: float \= 0.0  
	var acc\_aberration: float \= 0.0

	for sector in \_sectors:  
		var dist: float \= ship\_pos.distance\_to(sector.center)  
		var inner\_boundary: float \= sector.radius \- sector.transition\_width  
		  
		if dist \< sector.radius:  
			var w: float \= 1.0  
			if dist \> inner\_boundary:  
				var factor: float \= (sector.radius \- dist) / sector.transition\_width  
				\# Curva quíntica de Ken Perlin (Smootherstep)  
				w \= factor \* factor \* factor \* (factor \* (factor \* 6.0 \- 15.0) \+ 10.0)  
			  
			total\_weight \+= w  
			acc\_space \+= sector.data.space\_color \* w  
			acc\_prim \+= sector.data.nebula\_primary \* w  
			acc\_sec \+= sector.data.nebula\_secondary \* w  
			acc\_density \+= sector.data.nebula\_density \* w  
			acc\_star\_density \+= sector.data.star\_density \* w  
			acc\_cutoff \+= sector.data.star\_brightness\_cutoff \* w  
			acc\_aberration \+= sector.data.chromatic\_aberration \* w

	if total\_weight \< 1.0:  
		var fill: float \= 1.0 \- total\_weight  
		acc\_space \+= neutral\_biome.space\_color \* fill  
		acc\_prim \+= neutral\_biome.nebula\_primary \* fill  
		acc\_sec \+= neutral\_biome.nebula\_secondary \* fill  
		acc\_density \+= neutral\_biome.nebula\_density \* fill  
		acc\_star\_density \+= neutral\_biome.star\_density \* fill  
		acc\_cutoff \+= neutral\_biome.star\_brightness\_cutoff \* fill  
		acc\_aberration \+= neutral\_biome.chromatic\_aberration \* fill  
	else:  
		acc\_space /= total\_weight  
		acc\_prim /= total\_weight  
		acc\_sec /= total\_weight  
		acc\_density /= total\_weight  
		acc\_star\_density /= total\_weight  
		acc\_cutoff /= total\_weight  
		acc\_aberration /= total\_weight

	return {  
		"space\_color": acc\_space,  
		"nebula\_primary": acc\_prim,  
		"nebula\_secondary": acc\_sec,  
		"nebula\_density": acc\_density,  
		"star\_density": acc\_star\_density,  
		"star\_cutoff": acc\_cutoff,  
		"chromatic\_aberration": acc\_aberration  
	}

## **3\. Pipeline de Assets (IA \+ Python \+ Upscaling)**

### **Taxonomía Exhaustiva de Assets Requeridos**

| Elemento Técnico | Formato | Resolución Base | Perfil de Compresión en Godot | Rol Funcional |
| :---- | :---- | :---- | :---- | :---- |
| **Mapa de Perturbación de Ruido** | PNG | ![][image14] | Lossless / Sin Mipmaps | Muestreo repetible (repeat\_enable) en fragment shader10. |
| **Textura de Nebulosa Atmosférica** | PNG (RGBA) | ![][image1] | VRAM Compressed (BC7/ASTC) | Gas decorativo semitransparente con procesado seamless. |
| **Planeta Rocoso / Gaseoso** | PNG (RGBA) | ![][image14] | VRAM Compressed (BC7/ASTC) | Landmark discreto asignado a Parallax2D lento1. |
| **Estación Espacial Modular** | PNG (RGBA) | ![][image15] | VRAM Compressed (BC7/ASTC) | Megaestructura de punto de referencia visual2. |
| **Atlas de Restos y Asteroides** | PNG (RGBA) | ![][image1] | VRAM Compressed (BC7/ASTC) | Colección de props dispersos instanciados vía AtlasTexture. |

### **Especificaciones y Fórmulas de Generación con IA**

La generación con modelos generativos (Midjourney v6, FLUX.1 dev o Stable Diffusion XL) requiere directrices formales para evitar la dispersión de luz parásita y garantizar que la dirección de iluminación de todos los cuerpos celestes coincida con una clave lumínica común (vector direccional estándar: superior-izquierdo a ![][image16]).

#### **1\. Nebulosas Loopeables y Polvo de Gas Cósmico**

* **Estructura del Prompt:**  
  \[Descriptor de gas volumétrico denso\] \+ \[Gama cromática específica\] \+ \[Estructura de filamentos sin estrellas\] \+ \[Parámetro de continuidad de textura\]  
* **Prompt Base:**  
  dense cosmic nebula gas texture, volumetric interstellar dust clouds, intricate ionized hydrogen filaments, glowing dark cyan and crimson gradients, deep space photography, scientific illustration style, completely seamless tileable pattern \--tile \--no stars, planets, sparkles, glare, text, borders

#### **2\. Cuerpos Planetarios Aislados**

* **Estructura del Prompt:**  
  \[Tipo geológico/atmosférico\] \+ \[Iluminación clave estricta superior-izquierda\] \+ \[Silueta definida\] \+ \[Aislamiento sobre negro puro\]  
* **Prompt Base:**  
  full circular shot of an ancient desert exoplanet, detailed geological canyons and atmospheric haze, harsh directional key lighting from upper-left at 45 degrees, realistic terminator shadow line, pristine edge silhouette, centered isolation on pitch black background \#000000, 8k resolution, cinematic sci-fi render \--no stars, nebula, atmosphere leak, flare, clipping

#### **3\. Props Mecánicos, Estaciones y Desechos Espaciales**

* **Estructura del Prompt:**  
  \[Categoría del objeto estructural\] \+ \[Detalle de superficie/greebles\] \+ \[Perspectiva ortogonal/axonométrica\] \+ \[Iluminación consistente\] \+ \[Fondo neutro\]  
* **Prompt Base:**  
  abandoned modular orbital deep space station wreckage, scorched metal panels, exposed truss structures, solar panel arrays, flat orthographic side-view projection, illuminated strictly from upper-left, sharp hard surface edges, isolated on absolute solid black background \#000000 \--no perspective warp, background stars, planet glow, blur

### **Scripts de Postprocesamiento Automatizado en Python**

#### **Extracción sin Halos Oscuros (color\_key\_unpremultiply.py)**

Al generar elementos aislados sobre fondo negro, el filtrado suavizado produce píxeles de transición donde el color del objeto se mezcla gradualmente con el negro absoluto. Aplicar un umbral de canal alfa clásico sin compensación introduce un anillo perimetral oscuro (halo residual).  
El script mitiga este fenómeno calculando la luminancia según la especificación Rec. 709 (![][image17]) y **des-premultiplicando** (*un-premultiplying*) los canales RGB respecto al alfa derivado mediante:  
![][image18]

Python  
"""  
color\_key\_unpremultiply.py  
Extracción limpia de elementos sobre fondo negro absoluto mediante   
des-premultiplicación matricial y estimación de alfa por luminancia Rec. 709\.  
"""

import sys  
import numpy as np  
from PIL import Image

def extract\_alpha\_unpremultiplied(  
    source\_file: str,   
    output\_file: str,   
    black\_cutoff: float \= 0.02,   
    transition\_width: float \= 0.08  
) \-\> None:  
    raw \= Image.open(source\_file).convert("RGB")  
    rgb \= np.array(raw, dtype=np.float32) / 255.0

    \# Estimación de luminancia fotométrica  
    lum \= 0.2126 \* rgb\[..., 0\] \+ 0.7152 \* rgb\[..., 1\] \+ 0.0722 \* rgb\[..., 2\]

    \# Rampa suave de alfa  
    span \= max(transition\_width, 1e-5)  
    alpha \= np.clip((lum \- black\_cutoff) / span, 0.0, 1.0)

    \# Des-premultiplicación para restaurar la pureza de color en bordes semitransparentes  
    eps \= 1e-4  
    alpha\_divisor \= np.maximum(alpha, eps)\[..., np.newaxis\]  
    unpremult\_rgb \= np.clip(rgb / alpha\_divisor, 0.0, 1.0)

    \# Recomposición RGBA  
    rgba \= np.dstack(\[unpremult\_rgb, alpha\])  
    final\_data \= (rgba \* 255.0).astype(np.uint8)

    out \= Image.fromarray(final\_data, mode="RGBA")  
    out.save(output\_file, format\="PNG")  
    print(f"\[OK\] Elemento procesado sin halos oscuros: {output\_file}")

if \_\_name\_\_ \== "\_\_main\_\_":  
    if len(sys.argv) \< 3:  
        print("Uso: python color\_key\_unpremultiply.py \<origen.png\> \<destino.png\> \[black\_cutoff\] \[transition\_width\]")  
        sys.exit(1)  
          
    cutoff \= float(sys.argv\[3\]) if len(sys.argv) \> 3 else 0.02  
    trans \= float(sys.argv\[4\]) if len(sys.argv) \> 4 else 0.08  
    extract\_alpha\_unpremultiplied(sys.argv\[1\], sys.argv\[2\], cutoff, trans)

#### **Conversor a Mosaicos Continuos Seamless (seamless\_tile\_generator.py)**

Este módulo toma una imagen cuadrada generada y la convierte en un mapa repetible bidimensional continuo11. El algoritmo traslada los cuadrantes exteriores hacia el centro mediante un desfase modular (numpy.roll) y funde la discontinuidad resultante utilizando una ponderación armónica por coseno12.

Python  
"""  
seamless\_tile\_generator.py  
Transformación de texturas cuadradas en mapas continuos mediante   
desplazamiento de fase circular y enmascaramiento por coseno (Hann).  
"""

import sys  
import numpy as np  
from PIL import Image

def build\_seamless\_tile(source\_file: str, output\_file: str, overlap\_ratio: float \= 0.25) \-\> None:  
    img \= Image.open(source\_file)  
    original\_mode \= img.mode  
    data \= np.array(img, dtype=np.float32) / 255.0  
    h, w \= data.shape\[:2\]

    \# Desfase de medio período para llevar costuras perimetrales al centro  
    shift\_y, shift\_x \= h // 2, w // 2  
    rolled \= np.roll(data, (shift\_y, shift\_x), axis=(0, 1))

    \# Cálculo del margen de mezcla  
    bw \= int(w \* overlap\_ratio)  
    bh \= int(h \* overlap\_ratio)

    x \= np.arange(w, dtype=np.float32)  
    y \= np.arange(h, dtype=np.float32)

    dx \= np.abs(x \- float(shift\_x))  
    dy \= np.abs(y \- float(shift\_y))

    \# Curvas de decaimiento suave (Hann / Coseno)  
    wx \= np.clip(1.0 \- (dx / (bw \* 0.5)), 0.0, 1.0)  
    wx \= 0.5 \* (1.0 \+ np.cos(np.pi \* (1.0 \- wx)))

    wy \= np.clip(1.0 \- (dy / (bh \* 0.5)), 0.0, 1.0)  
    wy \= 0.5 \* (1.0 \+ np.cos(np.pi \* (1.0 \- wy)))

    \# Unión ortogonal de máscaras  
    mask \= np.maximum(wx\[np.newaxis, :\], wy\[:, np.newaxis\])  
    if data.ndim \== 3:  
        mask \= mask\[..., np.newaxis\]

    \# Fusión entre el patrón desfasado y el continuo original  
    seamless \= rolled \* (1.0 \- mask) \+ data \* mask  
    out\_bytes \= (np.clip(seamless, 0.0, 1.0) \* 255.0).astype(np.uint8)

    result \= Image.fromarray(out\_bytes, mode=original\_mode)  
    result.save(output\_file, format\="PNG")  
    print(f"\[OK\] Textura continua generada: {output\_file}")

if \_\_name\_\_ \== "\_\_main\_\_":  
    if len(sys.argv) \< 3:  
        print("Uso: python seamless\_tile\_generator.py \<origen.png\> \<destino.png\> \[overlap\_ratio\]")  
        sys.exit(1)  
          
    ratio \= float(sys.argv\[3\]) if len(sys.argv) \> 3 else 0.25  
    build\_seamless\_tile(sys.argv\[1\], sys.argv\[2\], ratio)

### **Pipeline de Superresolución (Upscaling) por Estilo Visual**

La preservación del estilo artístico tras la síntesis por IA requiere pipelines de escalado especializados, ejecutados preferentemente mediante grafos de procesamiento por lotes en herramientas como **chaiNNer**13.

| Parámetro de Pipeline | Pipeline A: Estilo Pixel Art Clásico | Pipeline B: Estilo HD Ilustrado / Vectorial |
| :---- | :---- | :---- |
| **Modelos de IA Recomendados** | Modelos ESRGAN compactos (RetroEdge, OmniScale-PT)16. | Arquitecturas de alta capacidad (4x-UltraSharp, DAT-2, Nomos8k)16. |
| **Alineación de Grilla** | Desactivar antialiasing bicúbico; ajustar a coordenadas discretas. | Reconstrucción bicúbica con reducción de artefactos de ringing. |
| **Cuantización de Color** | Reducción estricta a paleta cerrada indexada (16 a 64 colores). | Preservación de 32 bits de profundidad de color con gradientes continuos. |
| **Filtrado en Godot 4.3** | Texture Filtering: **Nearest**1. | Texture Filtering: **Linear Mipmap**1. |
| **Formato de Importación** | Lossless (PNG optimizado con zopflipng). | VRAM Compressed (BC7 en Desktop / ASTC en Mobile). |

## **4\. Guía Paso a Paso para Construir la Prueba de Concepto (POC)**

### **Fase 1: Inicialización y Parámetros del Motor**

> 1. Iniciar un proyecto en blanco en Godot 4.3 configurando el backend de renderizado en **Forward+** para estaciones de sobremesa o **Compatibility** para despliegues web/móvil18.  
> 2. En Project Settings ![][image3] Display ![][image3] Window:  
   * Establecer Viewport Width en 1920 y Viewport Height en 1080\.  
   * Fijar Stretch Mode en canvas\_items y Aspect en expand.  
> 3. En la pestaña de importación de recursos, verificar que las texturas que serán utilizadas para mosaicos posean activada la bandera Repeat1.

### **Fase 2: Implementación de la Nave y la Cámara Dinámica**

Crear la escena del jugador con un nodo raíz CharacterBody2D (PlayerShip.tscn), asignándole un Sprite2D y una colisión geométrica CollisionPolygon2D. Añadir como nodo hijo directo una Camera2D con Position Smoothing habilitado a una velocidad de arrastre de 6.0 px/s.

GDScript  
\# PlayerShip.gd  
extends CharacterBody2D

@export var max\_speed: float \= 900.0  
@export var acceleration: float \= 650.0  
@export var dampening: float \= 220.0  
@export var angular\_speed: float \= 3.8

func \_physics\_process(delta: float) \-\> void:  
	var steer: float \= Input.get\_axis("ui\_left", "ui\_right")  
	rotation \+= steer \* angular\_speed \* delta

	var throttle: float \= Input.get\_axis("ui\_down", "ui\_up")  
	var forward\_heading: Vector2 \= Vector2.UP.rotated(rotation)

	if throttle \> 0.0:  
		velocity \= velocity.move\_toward(forward\_heading \* max\_speed, acceleration \* delta)  
	else:  
		velocity \= velocity.move\_toward(Vector2.ZERO, dampening \* delta)

	move\_and\_slide()

### **Fase 3: Integración del Lienzo Procedural y el Gestor Espacial**

> 1. Crear la escena del universo (MainWorld.tscn) con raíz Node2D.  
> 2. Instanciar la nave PlayerShip en las coordenadas de origen ![][image19].  
> 3. Agregar un nodo CanvasLayer con Layer asignado en \-100.  
> 4. Incorporar un hijo ColorRect (CosmicBackgroundQuad) fijando los anclajes en *Full Rect*.  
> 5. Crear un ShaderMaterial en el inspector del ColorRect, vincular el código universe\_nebula.gdshader y configurar la textura de ruido (noise\_texture) generada por el script Python o sintetizada en el motor10.  
> 6. Asignar al ColorRect el script BackgroundSync.gd, enlazando la propiedad exportada target\_camera a la cámara de la nave.  
> 7. Instanciar un nodo Node con el nombre SectorManager, adjuntar el script SectorManager.gd y conectar sus variables exportadas a PlayerShip y CosmicBackgroundQuad.

### **Fase 4: Incorporación de Nodos Parallax2D para Props y Cuerpos Celestes**

> 1. Añadir como hijo del nodo raíz un nodo Parallax2D nombrado ParallaxPlanets1:  
   * Asignar scroll\_scale en Vector2(0.08, 0.08)1.  
   * Configurar repeat\_size en Vector2(8192, 8192\)1.  
   * Configurar repeat\_times en 11.  
> 2. Como hijo de ParallaxPlanets, añadir un nodo Sprite2D con la textura del planeta extraída mediante color\_key\_unpremultiply.py. **Desmarcar** la opción Centered para garantizar la alineación con la esquina superior izquierda del área modular de repetición1.  
> 3. Instanciar un nodo adicional Parallax2D nombrado ParallaxDebrisField:  
   * Asignar scroll\_scale en Vector2(0.60, 0.60)1.  
   * Asignar repeat\_size en Vector2(3000, 3000\)1.  
   * Incorporar múltiples nodos Sprite2D dispersos utilizando regiones extraídas del atlas de restos mecánicos1.

### **Fase 5: Validación Operativa de la POC**

> 1. Ejecutar el proyecto (F5).  
> 2. Pilotar la nave desde el sector de origen ![][image19] en dirección al punto cardinal ![][image20].  
> 3. Comprobar cómo los tonos fríos y tenues del vacío neutro transicionan de manera continua hacia los tonos carmesí y ámbar de la "Nebulosa Ionizada", al tiempo que la densidad de gas y la aberración cromática se incrementan de forma orgánica.  
> 4. Validar que la posición visual de los planetas y asteroides no presente sacudidas ni desajustes angulares al rotar o acelerar la nave3.

## **5\. Directrices de Optimización de Motor**

### **Gestión de VRAM y Agrupamiento de Dibujado (Batching)**

El rendimiento en escenas 2D con sobreposición de fondos depende críticamente de minimizar los cambios de estado en la API gráfica (*draw calls*) y limitar el ancho de banda consumido por la memoria2:

* **Formato de Texturas VRAM:** Todas las texturas de capas intermedias y props deben importarse forzando el modo **VRAM Compressed** (utilizando algoritmos de compresión por bloques BC7 en Windows/Linux y ASTC en dispositivos móviles). Esto reduce el consumo de memoria en una proporción aproximada de 4:1 respecto al formato RGBA8 sin comprimir (*Lossless*), evitando cuellos de botella en el bus de transferencia al dibujar múltiples planos transparentes superpuestos.  
* **Consolidación en Atlas de Sprites:** Los restos estructurales y asteroides no deben cargarse como recursos individuales. La dispersión de múltiples texturas distintas rompe el agrupamiento automático de primitivas en el renderizador 2D de Godot 4.3, disparando las llamadas de dibujado. Al agrupar los elementos en un atlas único gestionado mediante sub-regiones AtlasTexture, el motor procesa todos los elementos de la capa en una sola llamada de dibujado (*single draw call*).

### **Evaluación Computacional de Ruido: CPU frente a GPU**

La síntesis de patrones de gas cósmico puede resolverse por dos vías computacionales7:

| Criterio Técnico | Ruido Procedural Analítico en GLSL (GPU Puro) | Mapeo Pre-calculado con FastNoiseLite en GPU |
| :---- | :---- | :---- |
| **Carga de ALU por Fragmento** | Muy Alta: requiere evaluar bucles de ruido fractal (FBM) con 4 a 6 octavas por píxel7. | Mínima: lecturas de textura directas aceleradas por hardware (TMU)7. |
| **Consumo de Memoria VRAM** | Nulo: no almacena datos de textura en memoria7. | Reducido: un mapa de ruido monocromático de ![][image21] o ![][image14]7. |
| **Escalabilidad en Pantallas 4K** | Deficiente: provoca caídas de frames en tarjetas gráficas integradas7. | Excelente: el filtrado bilineal interpola los píxeles sin penalizar la tasa de cuadros. |
| **Costuras y Tiling** | Inexistente: evaluación matemática en coordenadas infinitas. | Mitigado mediante la propiedad seamless \= true y desfase de UVs no armónico10. |

En aplicaciones en tiempo real, calcular ruido procedural analítico por píxel para un fondo de pantalla completa en resoluciones de alta definición penaliza de manera innecesaria el tiempo de dibujado (*fragment throughput*)7.  
La estrategia recomendada para optimizar recursos consiste en generar un mapa de ruido en memoria a través de un recurso NoiseTexture2D con seamless \= true, vinculado a un generador nativo FastNoiseLite10.  
El motor sintetiza la textura una única vez en un hilo secundario y la transfiere a la GPU21. En el shader de fragmentos, el coste computacional se reduce a **dos operaciones de muestreo de textura desfasadas con escalas de coordenadas no armónicas** (por ejemplo, con factores de escala primos como ![][image22] y ![][image23]), sintetizando una apariencia no repetitiva y orgánica que preserva un tiempo de fotograma estable de 60 o 120 FPS incluso en hardware de gama de entrada.

#### **Obras citadas**

> 1. Godot Parallax2D Setup Guide For Infinite Backgrounds \- Yelzkizi, [https\://yelzkizi.org/godot-parallax2d-infinite-backgrounds-guide/](https://yelzkizi.org/godot-parallax2d-infinite-backgrounds-guide/)  
> 2. Godot Parallax2D Guide: Setup, Loops, And Fixes \- Yelzkizi, [https\://yelzkizi.org/creating-parallax-effect-with-godot-parallax2d-setup-infinite-backgrounds-and-common-fixes/](https://yelzkizi.org/creating-parallax-effect-with-godot-parallax2d-setup-infinite-backgrounds-and-common-fixes/)  
> 3. Parallax2D Progress Report \- Godot Engine, [https\://godotengine.org/article/parallax-progress-report/](https://godotengine.org/article/parallax-progress-report/)  
> 4. Parallax2D — Godot Engine (stable) documentation in English, [https\://docs.godotengine.org/en/stable/classes/class\_parallax2d.html](https://docs.godotengine.org/en/stable/classes/class_parallax2d.html)  
> 5. Space Background Parallax \- Godot Shaders, [https\://godotshaders.com/shader/space-background-parallax/](https://godotshaders.com/shader/space-background-parallax/)  
> 6. How to create a parallax shader for crystals in Godot 4 \- Facebook, [https\://www\.facebook.com/groups/godotengine/posts/3031422566994317/](https://www.facebook.com/groups/godotengine/posts/3031422566994317/)  
> 7. Plugin with GLSL version of FastNoiseLite library for Godot ... \- GitHub, [https\://github.com/MAGGen-hub/FastNoiseLiteRuntimeShaderPlugin](https://github.com/MAGGen-hub/FastNoiseLiteRuntimeShaderPlugin)  
> 8. Shading language — Godot Engine (stable) documentation in English, [https\://docs.godotengine.org/en/stable/tutorials/shaders/shader\_reference/shading\_language.html](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)  
> 9. ShaderMaterial — Godot Engine (stable) documentation in English, [https\://docs.godotengine.org/en/stable/classes/class\_shadermaterial.html](https://docs.godotengine.org/en/stable/classes/class_shadermaterial.html)  
> 10. 2D Fire Mask \- Godot Shaders, [https\://godotshaders.com/shader/2d-fire-mask/](https://godotshaders.com/shader/2d-fire-mask/)  
> 11. img2texture \- PyPI, [https\://pypi.org/project/img2texture/](https://pypi.org/project/img2texture/)  
> 12. [unknown\_url](http://docs.google.com/unknown_url)  
> 13. Upscaling AI Art for High-Quality Printing | Guide \- Midlibrary.io, [https\://midlibrary.io/midguide/upscaling-ai-art-for-printing](https://midlibrary.io/midguide/upscaling-ai-art-for-printing)  
> 14. chaiNNer \- Node-Based Image Processing, [https\://chainner.app/](https://chainner.app/)  
> 15. How can I convert a low-quality image to high-quality without, [https\://techcommunity.microsoft.com/discussions/windows10space/how-can-i-convert-a-low-quality-image-to-high-quality-without-watermark/4553357](https://techcommunity.microsoft.com/discussions/windows10space/how-can-i-convert-a-low-quality-image-to-high-quality-without-watermark/4553357)  
> 16. The best place to find AI Upscaling models, [https\://openmodeldb.info/?t=dedither](https://openmodeldb.info/?t=dedither)  
> 17. Comparison of Upscaling Models for AI generated images \- Reddit, [https\://www\.reddit.com/r/StableDiffusion/comments/yev37i/comparison\_of\_upscaling\_models\_for\_ai\_generated/](https://www.reddit.com/r/StableDiffusion/comments/yev37i/comparison_of_upscaling_models_for_ai_generated/)  
> 18. Screen Space Shaders Demo \- Godot Asset Library, [https\://godotengine.org/asset-library/asset/2730](https://godotengine.org/asset-library/asset/2730)  
> 19. Shaders / Procedural Slash \- The Godot Barn, [https\://thegodotbarn.com/contributions/shader/86/procedural-slash](https://thegodotbarn.com/contributions/shader/86/procedural-slash)  
> 20. glaiveai/godot\_4\_docs · Datasets at Hugging Face, [https\://huggingface.co/datasets/glaiveai/godot\_4\_docs](https://huggingface.co/datasets/glaiveai/godot_4_docs)  
> 21. Godot 4.2.1: Calling get\_data() on Image from NoiseTexture2D, [https\://gamedev.stackexchange.com/questions/210575/godot-4-2-1-calling-get-data-on-image-from-noisetexture2d-returns-null](https://gamedev.stackexchange.com/questions/210575/godot-4-2-1-calling-get-data-on-image-from-noisetexture2d-returns-null)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF8AAAAWCAYAAACmG0BRAAADHklEQVR4Xu2YS8hNURiGX6FcE797LieJyDW3EmUgM5JLiYkYkKT4cy3lkuSae6JIMiDFhIhyShGKGQMDfilFGQgDEu/bt5az9tp7H4rBf/a/33o6Z397r733ede3vrXWAUqVKlWqVFvUALKdnCE7yfDk6d8aSfbDrltKOidPp9SDnCdjo3g7Mo0cI6fIXNIxcUUb0VRyh8wk48kN8pM0w0zyWkiekwmkG9kNayeDs6S2W8kXMimKbyQnyVDHAXIT+fcqpJS518kK0t7FmshjJE0bTF6SZe5Y6kmekLVBLJQy+yPS5o8h10j3IKb3kPlLgljhpXLTQj7Bst5rGyz7N7hjmR6bqAy+RKqwkRBKGXwWVp7idioxT2GdHOoCas/LU1fSLw4G0jsNRC2RWrVUZ4+S27CO8NoMM1+fkmpzbKIkw96RYUFMBshElSm1j9vNIN9ho2uEi1XIIzLRHeepD7lCJscnYM9dTo6jgeePDuQq+UFmuZhMjk3Mi2sOOQQzIMt8xTUi1LnfyGFynywIrqmnQeQW7DlehTBeUq2WYTJIP0QlpepifzJf5UbtKu44y3ypC7kM6wDxgoxLXFFfYQcUxniZd5dchNVXSZ+KZZkYmi8T1pPFwfks82XQQdgzppNnsA7QdSpJfyvfASdQAOP18qdhZSBev8cZnhVXvfblxivL/NXkHmqTtJ61BVbmZGb87Dz5ueUDrBMbVt54rcv9SmEUmeO+70HaREnmv4VloUx9E/EZltXvYXW9AhtFq5CWlqwtSE78eZLxul4ZPwS2dA3ngIaRfkgzrGTou5cM8pPgPFhmzq6dRifYhkzoe5bizPfzR7hf8JpCHpLe8YlIofF+lPVHA3aAn6y+wjI4zFptkHwNboItDXe4Y0l/QahNvY2R9gu6t4z1UkdXkdzNarTtRfL+WdL7riFHkK7xDdcBfpPlVx0h8fpda+tXZBNZBNvd7kPaBEkjRKXG30uj5gHpC6vpKnGvyTqyElaKzqE2yedpNNmF7GdKvWD/PemzcJI5mgfmw/5y+Bepve7zP+5VqlSpUqVKtVr9AjzuqvK6SZx7AAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGsAAAAZCAYAAAA2VdDGAAAFNUlEQVR4Xu2Ya8hmUxTHlxByi8G4e0iuCbk1kowQNTTNEJFLLpEGIUTUg+QSJUQumXyQS+ILEj68LklMLsUolwa5FPFBKOTy/8066332Wec87/M8L42ZOv/69z57n/3us9f6r732OtusQ4cOHTp0WLOxqbhU3Cc/EHYXbxMfEE8VN6g/Xgn6eMaYm8Tt64+nsZZ4iHiXeK94eNX3f2KhuX0Zm4iXmNt0nbhN/fFKTGJPOd81VXtiMPnV4i/iAenZYnG5uJ+4kXij+JK5uIGtxVfEO81FWiCuEA8rxoANzQPiGXFPcW9xmXh0OWgVoyd+Jj6S+ncS3xfPE9cXjxM/Fg8uxqwr9sW3zIMcm/DD9dYU7EjxE/EMc9GvEJ+29sCfEUTGj9YUawfzF5xW9G0mvi0uqdrriA+JH4lzY5D57nrTBqKyeMR8tei7TPxbvKpqr2rgbNbOGkqxwqanqt8BbHrBBg5eJP4uHjs9wgP0B3Fe0UdQfi2eXLXxEwHyhbXv1qHAcQ+ab80sFiLlPpz+qDhlvtOIJhYX7cDx4l/iUVWbOZjr/OkRvgtxwC5FXxvYkWUgZLCmbcW184MROEm8Q/zK6mKxnm+tGUSIE/5gtz1XtAM4HxFIiyCE/1Dcoupjvfj27Or5WOCfiG5SHQvLL+aFuQ9gGMZgVIgwZU2xyl3TF/8wjzzGYRQGj4MtxSfFA/MDcxvOEu823ynjomceoHuYO7cUiwAj0LJYYROOxoYpa/onxOIZY3Y2DwZ26XriVuIca6bJkSD/ElkY2SYWBuS+3D9KLKKqjMKbxfvNg4QUe6GNt3B2ISmoPDNmKxRjbzdP/+HcUqwcaG39o8QizZENQvhnbWD3Y+LrNrwIa4D0R2T1qnYWa9hiQCkW83A2vSZuXIwhvcVZEHOFeLH154s/iSdU7VEoBZutUGCxudOYo00sfDFKLNAXfxUPigHmmYMMwpzMHf9T+pH1UmS9aPUAbwWLvNQ8ZweyWJwTL6e+QCkWwPjvzSMV9MwLjixWeYaBcBS7btyUGILdY7MTiiqPMzqKnDaxhhU+WSzmokKkksanZcGSxco2Mkf2Ryv2t0H6C2SxQBZlWD8LXSB+ar5IooZCIgwbJnw4KgwbB7wLZxIch6Zno8COvsUGQQXaxMqizNTfM7eNau9d8XSrn1mU/BG0JYbt3gYuEL9M/Nn8n78zT2kchKSy7GDAizk0Z8q5iFVGDhGX55pULIRaYr6jdjQPivIMGwVswrbS7m/M7aYEp41vIpVlR4ZYVIXDENVxVIP7mqf6WYvVhradxVnyp9W3ahQL5ba+yNwJpAWAU5da/TvrFPE3q38oT5IGS6EiI/AxPqlgGW07azvxcxs4PEAAIgSCAIR4z/wGJIDPOMfmVe0406kGyzJ97DTYBq4/8mE5x/zrvF/07Wq+q3B+AEMRIhaI8yjty8KBqP7A6pE038YrMBCKqpGP6nxG/VvByA7Yw7cj7wH85aamDDbey+cDlVw4PXZav2ozlpR4XzEGsFs527hkABMVGCVQltTHSyE76Q1z5wK+bVaIV4onmt9e3Gp1p+Hs5eK54rXmxnOtEsYHuHLhGeX7xdXvy605LmMv8QZrChXY3Pxuj7/jgnP0cfP0F7Zzi4NjAY5/XnzC/Nx52JrlNr+XmQt7TvWbjMLcJeKa7R3xTHPBucqKTPSfgpcdY77dIzoy5ppHGuPyYkuMM9fqAm5EOBYIUv623ZCQvo+w0fYQkLuZz8Vl77DA69ChQ4cOHTp06NChw5qHfwAMtFInRf8VEgAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAYCAYAAAAVibZIAAAAdklEQVR4XmNgGAWjYMABBxCnATEPugQlgBGIW4HYGF2CUgAysBeIWdAlKAEg1xYAcRyUjRUIALEkiVgOiOcD8WQg5mOgEjAB4tVALIMuQS4QBuLFQCyPLkEJyALiCHRBSgAonU4FYml0CUoAKLZ5ofQoGAX0AAA5bAi7Yfn2hgAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAaCAYAAACtv5zzAAABSklEQVR4Xu3UPyhFYRjH8UdS5BZSosgNC0abUpKBTbm7MlkphSSL0WCySFikbJIyiWK4y53ucE1K7JKBwvfpvOdyHq73/lvU+dWnTu9zOs973vO+R+SfpBGzaLaFStOKQ5wgi45o2Z8ERpFCP2rduM64011rhpCREhoM4AbPOMICDnCOQZxhPH93CQ3qsIpXLKEhWpYRPOFeyngDffg23jBtamHqcerodZiiGszhA8uoMbXv2ceKGfM26MMDbtFlajY7El1/jbfBugSz3zDjv6VJguXU6DItSvDRdWmPMelq+ehWvMC7/JxZVaKvdYdH9JhaVRI2UAXX0EU3wrAd9KUFafE30N/CLtpsoZhsSvANJmzBRbetnuZC58ObbuRwiXZT09O8hnn5+3x4k8Q1XrCHGWzhCmNS4cPD6EOSmHJ65esPGidOnDLzCXzRNqI8wPWAAAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB0AAAAaCAYAAABLlle3AAABXklEQVR4Xu2UPyhGURiHX6GIQimZCIsoSbEYlSSTlJDNKhkok5JMFoPJIqPZbrApI1ISA5NE2MTzOvdzzz1u537d74z3qWe45733/jrv+SNSUBCIKfwuwxfcxVbzWWXUYTuO46eYgK1orOQI3ka1G+z4/TIAQ/gh5sfrTk2Zl3jW204tN1mh9jIcOrXc+EKrxLS8FDqbLOfHDrXXtB938AtfcQmro28qxg59xwfLRzGhx2I2lc48ix6sdwddfO1VpsUEa31N/MF9eIFdbsElK7QFz8XUn7E3Wf6jFg/wTcw/vWSFNuKpxJtpIlGNGcNVvMRRp/aPrNA2vBL/TJtwA7vxXswxS6WcG2kAT6Kab03ncFjiruiFkkq5d69uojOclPQj04lHOIMLeC3pHQuGznoFByXujh6vPful0OiGWXTG9KoMdl3aNOO+mMtEW6vPNbiMd/iEm9gQvV9QEI4f2hdsOeH3zbAAAAAASUVORK5CYII=>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAaCAYAAACgoey0AAABZ0lEQVR4Xu2UPyhGYRTGH1kMFFIyKYNSSjLIZpPEYlFmMpiZlJJYLEYbq5UYDJ8YxGIjJWVgkhQ28ZzvvLfv3D/fvbfu+5nuU7/lPPe9z33Ped8LlCrVQE2T3xy8kx3SpcuKq4X0kAnyDQ3ZcLWAUfLovAfSW13pSSPkC/ry1Ygnmkdt95sRr5Cygu1I9iNeIaUFN0HbHwTPhe1issF2xoNki/yQD7JAmt0aL7LBn+TZ8AINPoQeNOmAN6W1WjQLDRd/BeHwdnIAPfG3pOK4Qo4OZQV3kBuo/0YGwnbVvyYzpiZjkm6Nm1pMWcGt0F0EB2wy5OqHyG77TE3eKcFjphZTVnA3uUP9Hcs9r0A/UNRJTsgy6pyJPH+uIXLsvKQZi3bJOVkj6+SULCJlvnn/1XKwLskU4i9Lmm9QWzI170qabxu5gHaiYYrOVyTX75UMm5o3yf3dJvfkiew5zsgR6a89WqrUP+kP7UZ0aL/XrssAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,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>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAZCAYAAADqrKTxAAAAp0lEQVR4XmNgGAXDGmgCcQgS9gdiISCWRhN3AGIWiBYGhgwgfgLEf4H4PxC/A2J9IHaDioEwSH4FEHND9cBBMANCEYgNwl+hNE7ACMRlDBDb/jFANIP4IHG8gB+I9zBANILwLCBmRVGBBkCSIEUgTSD/vGeAaMRqmwAQSwJxNRA/AmIdqHgsA8KZMUAszoBk60IGhHNAuBwqDqKRxUGBYgyVGwVDAAAALdEn4qUbfHcAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAaCAYAAABsONZfAAAAyElEQVR4XmNgGAXDGmgCcQgQRwNxJxCrArEJEJcB8SQg9gVibrhqKMgA4ndA/B+KfwLxASCeBcTHoWKPgNgAqh4OjIH4KwNEQQKSOD8QH4KKn4Dy4QBZE8g5yCAdKv4PiF2QJfBpAvFhTkeRo7qmVqj4WwZISMMBsqalQMwHFbcC4vdQcVAUMELFwQBZ0zYgfsaAiIZXQBwJxMxw1VCAzXk8QMwBV4EFYNOEF4A8Vw7EvxkgmkBJyRxFBRbgyQBJMsg4GUXFCAAAVTs8456mzu4AAAAASUVORK5CYII=>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAaCAYAAAC+aNwHAAABC0lEQVR4XmNgGAXowBGInwPxfyT8Coh/AfFfID4JxMFAzAzTgAvMAeLfQGyDJAbSlMYAMagMiBmR5FAALxAfBuK7QCyOJicJxA9xyMGBJhC/BeI1QMyCJmcKxN+A+CoQi6DJwYEfA8Tv6egSQNDAAJErRhNHAZMYMP3PCsTJDBCXlUL5WAEPEB9ggIT6MSj7OgPE1ulALAxTiAtg8z8otCsZIKHvChXDCWD+L0ITNwbirwyQ6MULsPkfBKIZIAa3oomjAHzxDzIYZEA5mjgK0AHi9wyY8Q9ir2JANaAaiF1gCmwZIKkLPf2DwgMGQOkfFIggg2KBeDYQcyLJEwVA3vJlgMQEyZpHwfAGAGlHPJOLUE8QAAAAAElFTkSuQmCC>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABYAAAAaCAYAAACzdqxAAAABTUlEQVR4Xu2ULUsEURSGj2BQ0KKCQcNiM4pY/ACDRo3rD7CYLWrbYhBEMBtFLEYFEYN/wigYXDaJIGpQ/HjeOfeye/cDdwymeeBhhz2HM2feubtmBf/NLNbwO3iLI0lHyjJ+mvfq8xqHk44m9rGKDzjeVItowCk+4xn2puVWBvAYD/EVp9NyRg9u4A5+4WZabs8EHmHZ/BFX0nLGlPngbfzA+bTcnlXzTWbwzVq36ccKjuEF3uFoY0MnKriEk/iIu0nVbM28rsH3ljNfvTBtoW1OzDMVJdwyH6ThufPtM7/JTVDXGqahJW/NrnPnK7Slto0ZakPFIHTjP+UbUb7KeRH3zF+cUFQ6413nqwOvOCLKTydDA3TEIrnyncNzHGz4TmdYZ1nxxBco9CS/5ruAT1b/f3jH9VDTr+7K6r//A3wJfbH3EodCvaCgoBt+AHZzRnAvsxTcAAAAAElFTkSuQmCC>

[image12]: <data:image/png;base64,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>

[image13]: <data:image/png;base64,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>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF8AAAAWCAYAAACmG0BRAAACrklEQVR4Xu2YS6hNYRiGX6GIEifX0ElKlCi3iDKQoeRSYnIyIRnglBOlXDJwzW0gM8lEioki0hkZMDMwMRApRRkIM/G+vvXZ31p7rbX3ObNl/089nb2/ddmn9//Xf1lAIpFIJHqZfrqrWAwsoufpLbqbTswf/stsegJ2zim6MH+4jTH0EN1fPNALLKYH6HP6i97OH/7HdvqGLqeT6Rn6lE4J56zOahvoMvqI/qaDsJDLWEN/0KHigV5A4W+l6+hHlIc/j76le0JtKn1FD2bf9RQ8pHvp2KzWR1/Cwl2R1SJqODW6Gqgnw3c0XLxHefgKvRigevJdOgx7Evz6b7Be7xyHhXsk1ISuV+0Cuu/5k+jMYjGge85Bq/EbQ13419AevtC5n+gCOp5epU9g93IUalnP1nBzka5F9+FPp/foyuIBWPAD9Drsf2kUdeGrVhV+Wd0ZR+/D5pKNoa7hRhNyP+zabsMXc+lj2PziNDp4URW+hpRhlIfcKXyfTBW0h6KgDtOd2feRhi9iAzQ+eFEVvsbZZygPuS589W5ddwd2D0eBXUIrqNGEL7wBbqDhwYuq8EVVyFV1BXGTXkZ+L6CnSPX+UBtt+OrxmrC/wFZqjaYu/LMoD1nnanmqXuh48MfQWnVoObuZLqWv6YfgZ9iE/D37vim7pg4FryWuevx8+gD5OaBx1IW/BTZpxmAmwDZRUp+FQhmEjen67Oyj28L3yEh7fgzeh5pZaHgDePhau8fgRB9ss3Qy1PTaQL3eX0fomgH6M6vH3v2Vrs/OK7IKdo32A53Qb2g3fgXtY3wjG0C9WWGpZ+vx9yFAw4OGCUdr63f0KN0B292eQysEbzy/R9T3ApEZ9AXyv6shqG7YWUJPoz14Zxrs3ZP+/ndo1aKxW68j9MohkUgkEolEB/4AIXid1dZItk8AAAAASUVORK5CYII=>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF8AAAAWCAYAAACmG0BRAAADCElEQVR4Xu2YS6hNURzGP6GUV96PkAzkGSIi6V55JCWFGBiQAUnEHcgMJVEipEghiS5lpAzknhgoZCAzDEgmQm6URx7fd/9r2Wuve8/dRwzse9ZXv+7d66yz9tnf+q//f60NJCUlJSXVs8aSdXGj0xoyj/Qh3chQsp5MDztR/cgOcobsI+Nh/WOpbQ45Tk6RBa6trjSRbCW3yXdyIf9xm3qQZvIz4irpH/SbRiqkgQwgm8lX0oS8sb3JOXIddv/J5CFZHPSpC+nhV8Ki+hU6Nl86S56Ql+QaWU6653pYFGsCV7hrTcAD8hZ2H0mTcIzcQTZxu2CTudtd151GkBeobv4JMjNujHQEZuImd92X3CWtsFUhaYxPsFXhNYocIOOCto6kFTMsbgykiR2J9kHx3+tfmN+TDEb28FPIe1gqUq2Q9pJvZL5r0317uc+KNASW/mbFH8CM3wD7nfodpVKR+SfJUfIIlp7ukRm5Hnmp8F6CpSlflGXyDVjkHySnYSnnKazu1FJwtUpuktlBW6mNl4rMV4HcgyyqtdN5h7wJklLDFZjpz8lSZN9RpFdgqUk1RIVcaoSlJl8rihROQOmNl4rMV/4Oc6kM0Aq4jMzEWBPIa3IRNine/B9kUdbt9721KmpNQX4CtCJLbbxUZH4s31/RXa0IKiqVehTpW2ATcAuWdsL64ccS+r8WaWylrDewnVqp1Zn5G2HRKgO9YsMUeTsdYRRq+yjz/bhKN39rvozfBov4MbDzQpz+SqXOzPcGhub7tFOBpRO/hYyN1Xj6rs4Akk7QX2C7Ha8/STuh8X6Sh6PkE+ANUJrQA4aaC8utYUSvJZ/JKnc9GrZrOY/s8DSI3IdtN/3OSK8ldFgLD1SNqK3g6ndpV6RDWpzjSzkBKnyKYJ1M/WuDj+Qxmer66KGbSAvsAKUo1qk13h4uI8/IIViEK5I/uPZQC2H31HZzu/tf48eTHmsS2Y/2xnsNJIfd3y4nRbdeRSxB/p1OKKWNBrIa9rKsmlEqvhpH42ncpKSkpKSkLqlfodCf1pIchHIAAAAASUVORK5CYII=>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB0AAAAZCAYAAADNAiUZAAABiElEQVR4Xu2UzStFQRjGH6EoohQpcv8BRUKsJWWjJCUb2cjG18LHvyApHxuUpbos7SnFzsrWgqwUK2Tj43l6z2TOOffoXre7cn71qzNz5px35p15B0j5L9TRQ9oe6R+j/bSGltFGOkk7vDEZuktP6Sgt994lop+t0lfa5fVX0Cz9ingMm6TQJFZoddDWBCeC51/ppc+IBxUH9Ibe0xM6jPBKBuiQ11ZG1miV1xdDM96ne8gddDtHn4/eKaWOBjrntWMorYuwj5bxt6Dagnk6DRu3TttCIyL00A1aieSgO3STXtMHekU7QyOMetoE+1ciSqtSmgnaSUF1onXI3D7q5Gr/NeGCUFoXYOXgSApai/DBaYGt+AiW2rxRelxaHUlBozTTO3oLS2fezMBKwPcFVoOP9AJWf1P0MxjvcEGlnosi10rVp4n4QV16z2E1WRQq6Dfa7fX1wU6vvw3j9B3h2iwY3ShKqbviPuglLL06cEv0DFaHW/SJzgbvSkorHaGD+LlzU1JSSsc3QEtNtH3pcNkAAAAASUVORK5CYII=>

[image17]: <data:image/png;base64,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>

[image18]: <data:image/png;base64,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>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAC4AAAAZCAYAAABOxhwiAAACR0lEQVR4Xu2XwUtVQRjFP7EgqQgxkrBN0UZ0EYiVoLhVpBathBbuDFxFqEGrWrgURKFFC11FC93qQgRfJBG1LtpIFCIU+C+o5zB3ZO5353tv7n0gLd4PDlfOnXdm7r3zzYwiLf4PrkCXtHkOXISuaTOVe9CaNBHQBBz4EvRE32jELWgX6lN+G/QAWobeQhNQe65FGik5XdAWdF/5Jgzl076O+PPQR+i2uOD30DtxbyiVMjlj0La4KduQfuhndg0ZgP5Cw4F3B/otroNUyuRwmn6GJpUf5SW0KcWiXBAXfjPwrkKfxNUC32QKZXPYfgO6oPwcHCwH/crwdYf8hDXoG9QZ+BZVcsbFtWfdmTCMjR4p3wdbHWrfwmpv+YRT6wAaVH6O2Pwj/oF0cL0OY1TJsV5mDg78T3YN6Yb2pRhcr8MYVXL8wJ8qP4c1cCvY8i2s9pZP/MBfKD+HNXBWNCtbB/sOuSJwZWhElZykqcL19FBcJWu4TB5BvYF3Hfoubgf0cBO5kV1jpOZ46o3pDB/wTN8Ad8VVd7gZjED/oKHAW4ROpLjzelJzPFxNWBfhgxZoE7cJxJ6c8NDzC5qGpqAf0IzkN43n0DG0I24KxEjJ8bAoa2JnncE38VWKG4GHZwvON4p/x+CXW4Eu6xsBKTmsiQ9if70cDNmT4rmhDPzkPEg1C6fVl+yaxGNoHerQNxLgJ12V4pG4LJw2b8S9gNgUisKGc5mSf5TBIhrVZgVYsFw6S/8jw+VsFnqob5wDPeJOhaUH3aKFwSnBRYRtGUoA/wAAAABJRU5ErkJggg==>

[image20]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAE0AAAAZCAYAAAB0FqNRAAADmUlEQVR4Xu2YW6gNURzGP6HIPUpCHIlEUXIrygNF4gGhiCeUF7lfSp2SB3WSFElyHCW5PXhwK3FEuT0pJCWXXKLkiRe5fN9Zs8zaa8+c+c85See0v/o1M2tmf/Nf/1nXDdRU0/9Ub9IjLuyE6koGkC7xjbKaRBpJv/hGJ5SStYVsSs7bpGHkFhkflKnFrSYTknN9HT23joxMH2tRX7KRHCN7yJDK2y1ScNPIIXKELIDzjGXxsqjIpzs5RZZE5SapMgdJfVTenzwgvyMa4F7oNYI8JmvhkjufvCBTg2f0ju3kNqkjA8lpuAqV9bLI6qMGcY8Mj8oLpR8+T46hNL5dJk/IS3ISrqWEzbkbOU4uJOde+8g10jO5nkw+kZl/nwBGkTdkXnJt9SpSGR/dP4PqBlOoHXDJiScAJa0J1c06lCr+Ec4j1GLyDS5ZkgJWgkKvPuQO3DiqD2H1KlJZn5XkEdzEYJISpYTtjm/AlrQ55BeqA1wI15UVkH9HnDT5NyMN2OJlUVmfiXCxTYnKc6VK6AcyjKVKnSUH4Lroe3IJlZOADyQvQJX75OQlzZdbvCzKez6v3OdALdGkrLHGS5W6TpbDdR+xF25A1UArKYCsQMIAfVBFSbN4WVTWx8cRl+dKSXubHGMpSRp3dPRSE/6OdODcjOxAwgAHw00kRUmzeFlU1sfHoXHXpNaSliU9p8H0BumF/EA6Uvf0cWjGNam1pO0nP8jcoMwnrRnuZerWeiYOxAeocULTuqb/vKRpBlWLtnhZVNandPfU9PwBbvEXq4n8RGXSfPdshOu2Q8lruFV+qPXkCxmXXCug8FoaRJ4i/a3VS9LCW2SpjI+kmVszuLq1ST5wGcZaQXYiHdN03EW+Il1Z+8nhPtI9q1b45+AWjX5xOZq8g/P0mkU+kxnJtdVrLNzkJb+6pCyU1cdLW0ONuVqqmKQXqNXEX0XSiw6Ti2QN3D5NXypulQrsCtzyRPdOkLtwwYRSt3gFt3eV3zOyAZUTjcVL59oiaS2mLpcli4+XurMajlqoWfr6D5G9IlaFxpClZDaqdw1e2nhrvNNzOmZtxCXtOVVRofMsWb20r4w/YCirTz2yW2CrUvD6Cn4P2BGkCjYgu3uWkep+E26oKK1F5Dzsm+L/LX1gze5h126LVpGjqPynxSy9fFtCewP511IrW4b2/1mqyekq0t1Nm6RsbyXT4xudUFoXageQNTHUVFNNHU9/ABW5+V6TuH8NAAAAAElFTkSuQmCC>

[image21]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAE0AAAAWCAYAAACFQBGEAAACR0lEQVR4Xu2XPWgVQRSFj5iIYiFEEBQhQbQQCwVRUaIkTSAELSRYWImCdoIGEQUV7UQIqI1olzQpBNOkCIYUCQjRQguRFLFQ/OksBAUL0XO47yaTebP7Ighv85gPPrKZmV12z87c2QdkMplM69FFT9PtdC1dT/fS87XjGI05BTsvxVZ6gz6mt+nO5d2twRH6i/4J/EEHgjEb6HF6n36u9e8P+p2D9Dk9Cgt+Ana9IbomGLfq0cO/o/P0DWx2aLaEKLR+2kNvIR2axozTs7DZKDbTl0iPX9XoYR7GjSVcRToEBf2BfofNMuc6bLZdDtpSdNQsQi9iGyoyY/9XaO2w5TuJ5TNV4xWa/paxiz6jnXEH7No36RVUKDTd7AhdoB9hS1DLLUVRaCna6FP6G7a0G7EPFnoYXOUCE3r4OSztcl6HtPvphmP+JbRDsLFF10oRBlfJwIRubGPUpjqkHfVw1C5WGtomOkVHUX/9Rii4afoEFQysCK9DqeK9ktD0Ih7RYRQv8zJ0/gP6nu6I+pqOluIr+pZuCdrLinej0Dywa1j69NhN+xZHlKPz78Fm2B7Yt15qc2ga/pkQh+afCSeCNqcsNC2jIXqpduxcoCeD/4sIA/PzFXilgtPuplmhgu2oFs3A6pGOYxTaT3ogatdDnoH1fYLtwu432r04Mo0Cu4v6wEXlgtONzMLe8Dn6mr6A/RZ1VMjHYA+vGeh+gdUt4bM27He/onFt6qUXUR+Yo939Dl0XdzQLveVjdBD2Vr0WZTKZTKaF+QtVx3WHoOTadgAAAABJRU5ErkJggg==>

[image22]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADUAAAAZCAYAAACRiGY9AAACNklEQVR4Xu2WTYhOURjH/zKKDIp8jM/YiBWRIstJTZOSjyxYkERSioVmYTOTjQ1hJbEUpuwmC8VCmdWUslIKKUnslFL4/z33eJ973vvM+3pvirq/+vXe97n3Puc855577gEaGhr+RebTM/QGvUAHyqdDDtAdtJ/OoEvoYbrJX4Te8/fMGvqcHqez6RB9Sbf5iyroo/foj8z7dIG7rtf8PaOO3aTjxXHiIn1I57hYFbr3BX0LyzFMZ7rzdfNjLl2aBx2aHstRbnQdfU/Pu5jYS7/QLVk85xqmv6ZufiyGTYet+QlYQUdgnZjl4oP0O9ob3Q2bSoeyeE6nourm/8VK2GP18zUqSKTkUaN5POc6vUyn6Dv6jG5256M8UTzEFzZdQUJJq5J32+htOoLWlNbK9xmtQa2bv0QqTCMZFSTOojp5t43OQ/kdVbt6YndgC0Pd/CX0hJTwI+w7EhElj+Kd0PfnDX0FW7SiPFE8RAWdhj2h1fQB4m/CTvoN7clTo1qlIo7CFoGTLpaKkjquk/83vqA05ZYhLmwFfU2vZvET9BPd4GIa+UXuf3pffFFp+j2B7TL+JH8lKugUvYL2dygqTPeM0Um0dgG6V5+G9F6I9fQDrMNri9h22Dvr2zpIv9J9xf9u84dspKNoLyixkF4qfj1qbILehW1hbtGnsFFP6FhbnUdodU4dPkcf02Owp6HR18DqXKKb/H8FrWD6iO4vfv2K1olVdA/dhfKez1Mnf0NDQ0PD/8tPsdSKPbHsxHQAAAAASUVORK5CYII=>

[image23]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADUAAAAZCAYAAACRiGY9AAACUklEQVR4Xu2WT0hVQRjFT1igmCWVlRVpJAWCYFQGYbuILIKgBKEWbQoRMXCR0CYQ2rQKihYRiAshInDhxkW0qBZBIAVupT+UoUGuWrWoc/pmcO68e3339Vwo3B/8eM+ZeeOcO9+de4GCgoK1zBF6Jm5cgRp6nj5yXqZ1iRFAB+2lO+kGupmeolfCQavNCXqLvqN/6EiyO5NN9AG9Qw/S6/QXnaUtwbg+2LyhX2hnMGbVUagL9BxsUXlDnaUv6N6g7Sps0U/oRtemueecb+lNusX1laWe7oobA7T1e2Alk8ZRVBZK43wAzz76FRbAr0Wh8s5ZQhN9Ro/FHbBA12DlorJJo9JQ+j/v6Y2grZl+duq7qCqU0JWapl1BW55AotJQaXTT33SS1ro2hRqHrUs7+BF2/2VVTCphsLyBRLWhNP8YXULyoirUS7rN/d0GK1EdTlpfbnywh8gXSFQb6hL9Tk9H7doxv2tCQSZgwQ4E7WXRD4fpD3oy6suimlDamRl6PO7IQOWoQ6Yn7shCgQZhO7QfVt9hOWTxv6E09xtYWQkd5TraG+kh+o1OIflQ9qFUmmUJA/mS2418wcqF0hG9PWrTQ/a5+/TsoI9pA5bnDEP58lO7+ldEgwfofZTeQ3mC+QXcjjvIYbqA5H2gOV/Rn7A3BO8i7NGiHdsKC9BqP/mHvusUVPB4nSW001FkD9Tpc899hvTTeSRfY7TQ17D3NaGD5wPsDUILFf7hm+ZdN0boeab7TRdriH6iT7E8z7pFbzt6Ub4I26mKjvKCgoKCgnXLX9C+eYG2JiY+AAAAAElFTkSuQmCC>