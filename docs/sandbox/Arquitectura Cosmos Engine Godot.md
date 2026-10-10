# **Blueprint de Arquitectura Técnica: Cosmos Engine para Godot 4.3+**

## **1\. Topología del Sistema y Jerarquía del Árbol de Escenas**

El desarrollo de un motor procedural infinito en dos dimensiones sobre Godot 4.3+ exige resolver la discrepancia intrínseca entre las dimensiones matemáticas no acotadas del universo y la precisión numérica finita de los registros de coma flotante de 32 bits (float32) en la GPU y la CPU1. La arquitectura de Cosmos Engine desacopla los estratos visuales del espacio métrico interactivo del jugador mediante una estructura jerárquica gobernada por el nodo unificado Parallax2D, introducido en Godot 4.3 para reemplazar las dependencias complejas de los nodos heredados ParallaxBackground y ParallaxLayer1.  
Al heredar directamente de Node2D, Parallax2D sincroniza su transformación con las propiedades de la Camera2D activa (desplazamiento, rotación y zoom métrico) a través de su propiedad vectorial scroll\_scale2. Esta integración simplifica el árbol de nodos, pero requiere una segregación estricta de responsabilidades operativas para evitar que las compensaciones del sistema de origen flotante induzcan artefactos visuales o desalineaciones físicas5.  
A continuación se detalla la estructuración canónica del árbol de nodos dentro de la escena principal del motor:

* CosmosRoot (Node2D): Nodo raíz métrico y contexto de coordenadas principal de la simulación.  
  * FloatingOriginTracker (Node): Supervisor lógico pasivo responsable de calcular el desplazamiento de coordenadas métricas y coordinar los saltos de origen cinemático.  
  * ParallaxNebulaDeep (Parallax2D): Estrato estacionario de fondo cósmico ultra-profundo con factor scroll\_scale \= Vector2(0.0, 0.0)3.  
    * NebulaBackdropRect (ColorRect): Malla cuadrilátera de cobertura total enlazada a universe\_nebula.gdshader para la síntesis de gas y filtrado estocástico del mapa estelar 8K.  
  * ParallaxMacroGalaxies (Parallax2D): Estrato cinemático de paralaje ultra-lento con factor scroll\_scale \= Vector2(0.02, 0.02)3.  
    * GalaxyStreamer2D (Node2D): Controlador de streaming determinista ![][image1], frustum culling analítico y pooling de sprites galácticos.  
  * ParallaxStarfield8K (Parallax2D): Capa de paralaje estelar profundo con factor scroll\_scale \= Vector2(0.05, 0.05)3.  
    * StarfieldSprite (Sprite2D): Visualizador de muestreo continuo que proyecta el buffer estelar estocástico de ![][image2] píxeles.  
  * ParallaxSolarSystems (Parallax2D): Estrato astronómico intermedio configurado con factor scroll\_scale \= Vector2(0.20, 0.20)3.  
    * SolarSystemStreamer (Node2D): Orquestador de macroceldas celestes y reciclaje de sistemas solares.  
      * SolarSystemPool (Node2D): Banco de instancias persistentes pre-asignadas de tipo SolarSystem2D.  
  * ParallaxDebrisBelt (Parallax2D): Estrato de alta densidad visual y velocidad acentuada configurado con scroll\_scale \= Vector2(0.60, 0.60)3.  
    * DebrisStreamer2D (Node2D): Supervisor de sectores deterministas de polvo y chatarra espacial.  
      * DebrisMultiMesh (MultiMeshInstance2D): Búfer gráfico instanciado por GPU en una única llamada de dibujo (*single draw call*).  
  * GameplayWorld (Node2D): Capa física interactiva con factor nativo scroll\_scale \= Vector2(1.0, 1.0)3.  
    * WorldEntities (Node2D): Contenedor de cuerpos interactivos, restos acoplables y estaciones estelares abordables.  
    * PlayerVessel (CharacterBody2D): Entidad cinética local controlada por el usuario sujeta a colisiones.  
    * CosmosCamera2D (Camera2D): Transductor de proyección global con suavizado y compensación cinemática4.

La configuración analítica de renderizado para cada nivel del árbol de escenas se sintetiza en la siguiente tabla técnica:

| Nodo del Estrato | Tipo de Nodo Godot | scroll\_scale | Rango Z-Index | Tasa de Despacho | Estrategia de Culling y Batching |
| :---- | :---- | :---- | :---- | :---- | :---- |
| ParallaxNebulaDeep | Parallax2D | ![][image3] | ![][image4] | Continuo (\_process) | Evaluación estocástica completa en GPU vía fragment shader |
| ParallaxMacroGalaxies | Parallax2D | ![][image5] | ![][image6] | Eventual por macrocelda | Culling analítico de AABB y banco de objetos con ![][image7] activo |
| ParallaxStarfield8K | Parallax2D | ![][image8] | ![][image9] | Motor (Parallax2D) | Repetición procedural infinita sin transformaciones manuales3 |
| ParallaxSolarSystems | Parallax2D | ![][image10] | ![][image11] | Continuo (\_process) | Evaluación analítica kepleriana ![][image1] sin asignación en memoria |
| ParallaxDebrisBelt | Parallax2D | ![][image12] | ![][image13] | Por frontera de cuadrante | Búfer por hardware MultiMeshInstance2D en 1 draw call |
| GameplayWorld | Node2D | ![][image14] | ![][image15] | Físico (\_physics\_process) | Árbol BVH espacial estándar de Godot 4.3 |

## **2\. Formulación Matemática Analítica**

### **Proyección de Frustum en Espacio de Paralaje Dinámico**

Sea ![][image16] el vector de posición global de la cámara en el marco de coordenadas relativas de Godot y ![][image17] el desplazamiento acumulado administrado por el subsistema FloatingOriginTracker. La posición invariable y absoluta del observador en el cosmos euclidiano se define mediante la suma:  
![][image18]  
En el modelo de proyección de Godot 4.3, un nodo Parallax2D que opera con follow\_viewport \= true traslada sus elementos secundarios según una escala de movimiento ![][image19], donde ![][image20] para objetos de fondo3. La posición aparente de un elemento estático ![][image21] en el espacio local del paralaje respecto a la pantalla viene condicionada por:  
![][image22]  
donde el operador ![][image23] representa el producto de Hadamard. Cuando la cámara opera bajo un factor de aumento dinámico ![][image24] (donde ![][image25]) y proyecta un viewport de dimensiones en píxeles ![][image26], las semidimensiones métricas del cono visual observable equivalen a:  
![][image27]  
Dado que el nodo Parallax2D responde nativamente a la rotación y al zoom cuando sus elementos residen en el espacio canónico de Node2D2, el centro geométrico del frustum visible proyectado dentro del marco local de coordenadas del estrato de paralaje se obtiene mediante la escala directa del observador:  
![][image28]  
Por lo tanto, los límites de la caja envolvente alineada con los ejes (AABB) del frustum proyectado en la capa de paralaje se definen analíticamente por:  
![][image29]

### **Compensación Pasiva del Origen Flotante**

Cuando el vector de desplazamiento local del jugador o de la cámara supera un umbral euclidiano de tolerancia crítica ![][image30] (frecuentemente configurado en ![][image31] unidades métricas), el subsistema FloatingOriginTracker ejecuta una traslación instantánea para devolver la cámara al origen7:  
![][image32]  
![][image33]  
![][image34]  
Dado que Parallax2D lee la posición de la cámara en cada frame para determinar el desplazamiento cinemático3, si no se realiza ninguna acción correctiva, el salto instantáneo inducirá una discrepancia en pantalla cuantificada por:  
![][image35]  
Para mantener la continuidad posicional en pantalla (![][image36]) sin necesidad de iterar sobre los hijos del estrato ni alterar sus posiciones locales, se actualiza el vector scroll\_offset del nodo Parallax2D3:  
![][image37]  
Esta formulación garantiza que el vector de compensación visual absorba la discontinuidad de la cámara exactamente en el frame en que se ejecuta el recentrado, manteniendo los transforms de los objetos en un rango numérico estable.

### **Resolución de Celda Determinista y Exclusividad Galáctica 1-a-1**

Para garantizar matemáticamente que dos macro-galaxias nunca coincidan dentro del frustum de la cámara bajo ningún nivel de zoom ni desplazamiento, se deriva una distancia métrica mínima analítica entre macro-entidades independientes.  
Sea ![][image38] el límite inferior absoluto del factor de zoom de la Camera2D (el campo visual más extenso posible durante la partida). La diagonal máxima del frustum en el plano de proyección equivale a:  
![][image39]  
Sea ![][image40] el radio máximo acotado del disco de renderizado de cualquier macro-galaxia, y sea ![][image41] un margen de guarda destinado a evitar saltos abruptos durante el desvanecimiento (*fade-in* o *fade-out*). La condición necesaria y suficiente para garantizar la exclusividad visual estricta entre dos galaxias localizadas en ![][image42] y ![][image43] es:  
![][image44]  
Para prescindir de bases de datos espaciales y estructuras de aceleración en memoria, el espacio bidimensional de la capa de paralaje se particiona en una cuadrícula infinita uniforme cuyas celdas tienen una dimensión ![][image45]. Si cada macrocelda genera a lo sumo una galaxia mediante un proceso determinista basado en hashes, la posición de una galaxia asociada a la celda ![][image46] se define como:  
![][image47]  
donde ![][image48] sitúa el centro de la celda y ![][image49] representa un vector de dispersión estocástica acotado en el intervalo ![][image50]. La menor distancia euclidiana posible entre galaxias situadas en celdas contiguas se produce a lo largo de un eje cartesiano cuando dos entidades se desplazan hacia el borde común:  
![][image51]  
Imponiendo la cota inferior estricta ![][image52], se establece la relación óptima de diseño:  
![][image53]  
![][image54]  
Bajo estas restricciones de diseño geométrico, cualesquiera dos galaxias ![][image55] satisfacen invariablemente ![][image56], haciendo imposible la coincidencia de dos macro-galaxias dentro del cono visual observable.

## **3\. Arquitectura Data-Driven y Modelado de Recursos**

Para desacoplar el ajuste estético y técnico de la lógica de compilación, todos los parámetros de configuración se aíslan en recursos serializados .tres.

### **Implementación de Clases de Recursos**

GDScript  
\# CosmicBiomeConfig.gd  
class\_name CosmicBiomeConfig  
extends Resource

@export\_group("Identificación")  
@export var biome\_id: StringName \= &"void\_default"  
@export var display\_name: String \= "Vacío Interestelar"

@export\_group("Paleta de Color")  
@export var color\_deep\_space: Color \= Color(0.01, 0.01, 0.03, 1.0)  
@export var color\_gas\_primary: Color \= Color(0.18, 0.04, 0.28, 0.8)  
@export var color\_gas\_secondary: Color \= Color(0.02, 0.22, 0.38, 0.6)  
@export var color\_star\_tint: Color \= Color(0.85, 0.92, 1.0, 1.0)

@export\_group("Parámetros de Ruido FBM")  
@export\_range(0.00001, 0.005, 0.00001) var noise\_frequency: float \= 0.0008  
@export\_range(1, 6, 1\) var noise\_octaves: int \= 4  
@export\_range(0.1, 1.0, 0.05) var gas\_density: float \= 0.55  
@export\_range(0.5, 4.0, 0.1) var gas\_contrast: float \= 1.8

@export\_group("Óptica")  
@export\_range(0.0, 0.02, 0.0005) var chromatic\_aberration\_strength: float \= 0.003  
@export\_range(0.0, 2.0, 0.05) var starfield\_energy: float \= 1.0

GDScript  
\# CelestialSystemProfile.gd  
class\_name CelestialSystemProfile  
extends Resource

@export\_group("Estrella Central")  
@export var star\_name\_prefix: String \= "SOLARIS"  
@export var star\_texture: Texture2D  
@export var star\_base\_radius: float \= 400.0  
@export var star\_emission\_color: Color \= Color(1.0, 0.78, 0.35, 1.0)  
@export\_range(0.001, 0.1, 0.001) var star\_axial\_rotation\_speed: float \= 0.012

@export\_group("Planetas Primarios")  
@export\_range(3, 6, 1\) var min\_planets: int \= 3  
@export\_range(3, 6, 1\) var max\_planets: int \= 6  
@export var orbit\_radius\_min: float \= 1000.0  
@export var orbit\_radius\_max: float \= 6000.0  
@export var planet\_textures: Array\[Texture2D\] \= \[\]

@export\_group("Cinemática Orbital")  
@export\_range(0.005, 0.1, 0.001) var base\_angular\_velocity: float \= 0.025  
@export\_range(0.0, 0.3, 0.01) var max\_orbital\_eccentricity: float \= 0.04

@export\_group("Estructuras Secundarias")  
@export\_range(0.0, 1.0, 0.05) var moon\_spawn\_probability: float \= 0.70  
@export var moon\_orbit\_radius\_range: Vector2 \= Vector2(160.0, 300.0)  
@export var moon\_textures: Array\[Texture2D\] \= \[\]

GDScript  
\# GalaxyLandmarkProfile.gd  
class\_name GalaxyLandmarkProfile  
extends Resource

@export\_group("Visuales")  
@export var galaxy\_id: StringName \= &"spiral\_andromeda\_type"  
@export var galaxy\_textures: Array\[Texture2D\] \= \[\]

@export\_group("Dimensiones y Frustum")  
@export var maximum\_bounding\_radius: float \= 1600.0  
@export var safety\_padding: float \= 400.0  
@export var base\_scale\_range: Vector2 \= Vector2(0.8, 1.3)

@export\_group("Dinámica")  
@export\_range(0.0001, 0.005, 0.0001) var max\_drift\_rotation\_speed: float \= 0.0006  
@export var modulate\_colors: Array\[Color\] \= \[  
	Color(0.82, 0.88, 1.0, 1.0),  
	Color(1.0, 0.82, 0.92, 1.0),  
	Color(0.72, 1.0, 0.88, 1.0)  
\]

GDScript  
\# DebrisLayerProfile.gd  
class\_name DebrisLayerProfile  
extends Resource

@export\_group("Instanciación GPU")  
@export var mesh\_texture: Texture2D  
@export\_range(50, 2500, 50\) var instance\_count: int \= 600  
@export var field\_bounding\_box: Vector2 \= Vector2(8192.0, 8192.0)

@export\_group("Variación Estocástica")  
@export var scale\_range: Vector2 \= Vector2(0.3, 1.4)  
@export\_range(0.0, 6.28318, 0.1) var max\_initial\_rotation: float \= 6.28318  
@export var alpha\_modulation: Color \= Color(0.85, 0.9, 0.95, 0.6)

### **Serializaciones de Recursos del Motor (.tres)**

Ini, TOML  
\[gd\_resource type="Resource" script\_class="CosmicBiomeConfig" load\_steps=2 format=3\]

\[ext\_resource type="Script" path="res://CosmicBiomeConfig.gd" id="1\_biome"\]

\[resource\]  
script \= ExtResource("1\_biome")  
biome\_id \= &"biome\_perseus\_rift"  
display\_name \= "Grieta de Perseo"  
color\_deep\_space \= Color(0.008, 0.012, 0.025, 1.0)  
color\_gas\_primary \= Color(0.22, 0.06, 0.32, 0.85)  
color\_gas\_secondary \= Color(0.04, 0.28, 0.36, 0.65)  
color\_star\_tint \= Color(0.88, 0.94, 1.0, 1.0)  
noise\_frequency \= 0.00065  
noise\_octaves \= 4  
gas\_density \= 0.58  
gas\_contrast \= 2.1  
chromatic\_aberration\_strength \= 0.0025  
starfield\_energy \= 1.2

Ini, TOML  
\[gd\_resource type="Resource" script\_class="GalaxyLandmarkProfile" load\_steps=2 format=3\]

\[ext\_resource type="Script" path="res://GalaxyLandmarkProfile.gd" id="1\_galaxy"\]

\[resource\]  
script \= ExtResource("1\_galaxy")  
galaxy\_id \= &"spiral\_andromeda\_type"  
galaxy\_textures \= \[\]  
maximum\_bounding\_radius \= 1600.0  
safety\_padding \= 400.0  
base\_scale\_range \= Vector2(0.8, 1.3)  
max\_drift\_rotation\_speed \= 0.0006  
modulate\_colors \= \[Color(0.82, 0.88, 1, 1), Color(1, 0.82, 0.92, 1), Color(0.72, 1, 0.88, 1)\]

## **4\. Implementación del Núcleo en GDScript 4.3+**

### **Hashing Matemático Determinista y Stateless: CosmicHasher.gd**

Este componente estático implementa una variante optimizada de SplitMix64 para enteros con signo de 64 bits en GDScript, garantizando una dispersión determinista uniforme en el rango normalizado ![][image57] sin estados internos ni asignaciones de memoria8.

GDScript  
class\_name CosmicHasher  
extends RefCounted

const BIT\_MIXER\_1: int \= \-7046029254386353131 \# 0x9E3779B97F4A7C15  
const BIT\_MIXER\_2: int \= \-4417276706814111751 \# 0xC2B2AE3D27D4EB4F  
const BIT\_MIXER\_3: int \= 3266489917342721      \# 0x00165667B19E3779

static func hash\_2d(x: int, y: int, seed: int) \-\> int:  
	var h: int \= seed ^ (x \* BIT\_MIXER\_1)  
	h \= (h ^ (h \>\> 30)) \* BIT\_MIXER\_2  
	h \= h ^ (y \* BIT\_MIXER\_3)  
	h \= (h ^ (h \>\> 27)) \* BIT\_MIXER\_1  
	h \= h ^ (h \>\> 31\)  
	return h

static func hash\_2d\_float(x: int, y: int, seed: int) \-\> float:  
	var raw\_hash: int \= hash\_2d(x, y, seed)  
	var positive\_bits: int \= raw\_hash & 0x7FFFFFFFFFFFFFFF  
	return float(positive\_bits) / 9223372036854775807.0

static func hash\_2d\_vector(x: int, y: int, seed: int) \-\> Vector2:  
	var vx: float \= hash\_2d\_float(x, y, seed)  
	var vy: float \= hash\_2d\_float(x, y, seed \+ 1013904223\)  
	return Vector2(vx, vy)

### **Gestor de Cuadrícula Espacial: CosmicMacroGrid.gd**

GDScript  
class\_name CosmicMacroGrid  
extends RefCounted

var cell\_size: float  
var global\_seed: int

func \_init(p\_cell\_size: float, p\_seed: int) \-\> void:  
	cell\_size \= p\_cell\_size  
	global\_seed \= p\_seed

func world\_to\_grid\_coords(world\_position: Vector2) \-\> Vector2i:  
	return Vector2i(  
		int(floor(world\_position.x / cell\_size)),  
		int(floor(world\_position.y / cell\_size))  
	)

func grid\_to\_world\_center(grid\_coords: Vector2i) \-\> Vector2:  
	return Vector2(  
		(float(grid\_coords.x) \+ 0.5) \* cell\_size,  
		(float(grid\_coords.y) \+ 0.5) \* cell\_size  
	)

func get\_cell\_normalized\_offset(grid\_coords: Vector2i, stream\_salt: int) \-\> Vector2:  
	return CosmicHasher.hash\_2d\_vector(grid\_coords.x, grid\_coords.y, global\_seed ^ stream\_salt)

func get\_cell\_pseudorandom\_float(grid\_coords: Vector2i, stream\_salt: int) \-\> float:  
	return CosmicHasher.hash\_2d\_float(grid\_coords.x, grid\_coords.y, global\_seed ^ stream\_salt)

### **Detección de Frustum y Streaming Exclusivo 1-a-1: GalaxyStreamer2D.gd**

El streaming galáctico aplica la formulación de exclusividad geométrica. Al verificarse analíticamente la presencia de una galaxia candidata, se actualiza una única entidad pre-asignada en el árbol, suprimiendo las llamadas a queue\_free() o Node.new() durante el bucle de renderizado1.

GDScript  
class\_name GalaxyStreamer2D  
extends Node2D

@export var landmark\_profile: GalaxyLandmarkProfile  
@export var parallax\_layer: Parallax2D  
@export var camera: Camera2D  
@export var run\_seed: int \= 8943719

var \_macro\_grid: CosmicMacroGrid  
var \_calculated\_cell\_size: float  
var \_safe\_min\_distance: float

var \_active\_galaxy\_sprite: Sprite2D  
var \_active\_cell: Vector2i \= Vector2i(2147483647, 2147483647\)  
var \_is\_rendered: bool \= false  
var \_target\_alpha: float \= 0.0  
var \_current\_alpha: float \= 0.0

var \_cached\_frustum\_half\_extents: Vector2 \= Vector2.ZERO  
var \_cached\_screen\_center\_layer: Vector2 \= Vector2.ZERO

func \_ready() \-\> void:  
	assert(landmark\_profile \!= null, "GalaxyLandmarkProfile no asignado.")  
	assert(parallax\_layer \!= null, "Parallax2D no asignado.")  
	assert(camera \!= null, "Camera2D no asignada.")  
	\_initialize\_exclusivity\_geometry()  
	\_initialize\_node\_pool()

func \_initialize\_exclusivity\_geometry() \-\> void:  
	var viewport\_size: Vector2 \= get\_viewport\_rect().size  
	var worst\_case\_zoom: float \= 0.25  
	var frustum\_diagonal: float \= viewport\_size.length() / worst\_case\_zoom  
	  
	\_safe\_min\_distance \= frustum\_diagonal \+ (2.0 \* landmark\_profile.maximum\_bounding\_radius) \+ (2.0 \* landmark\_profile.safety\_padding)  
	\_calculated\_cell\_size \= 2.0 \* \_safe\_min\_distance  
	\_macro\_grid \= CosmicMacroGrid.new(\_calculated\_cell\_size, run\_seed)

func \_initialize\_node\_pool() \-\> void:  
	\_active\_galaxy\_sprite \= Sprite2D.new()  
	\_active\_galaxy\_sprite.centered \= true  
	\_active\_galaxy\_sprite.visible \= false  
	\_active\_galaxy\_sprite.modulate \= Color(1.0, 1.0, 1.0, 0.0)  
	add\_child(\_active\_galaxy\_sprite)

func \_process(delta: float) \-\> void:  
	\_evaluate\_frustum\_and\_stream(delta)

func \_evaluate\_frustum\_and\_stream(delta: float) \-\> void:  
	var zoom: Vector2 \= camera.zoom  
	var viewport\_half: Vector2 \= (get\_viewport\_rect().size \* 0.5) / zoom  
	var cam\_pos: Vector2 \= camera.get\_screen\_center\_position()  
	  
	\_cached\_screen\_center\_layer \= cam\_pos \* parallax\_layer.scroll\_scale  
	\_cached\_frustum\_half\_extents \= viewport\_half

	var current\_cell: Vector2i \= \_macro\_grid.world\_to\_grid\_coords(\_cached\_screen\_center\_layer)  
	  
	var candidate\_found: bool \= false  
	var candidate\_pos: Vector2 \= Vector2.ZERO  
	var candidate\_cell: Vector2i \= Vector2i.ZERO

	for ox: int in range(-1, 2):  
		for oy: int in range(-1, 2):  
			var test\_cell: Vector2i \= current\_cell \+ Vector2i(ox, oy)  
			  
			if \_macro\_grid.get\_cell\_pseudorandom\_float(test\_cell, 551\) \> 0.65:  
				continue  
				  
			var cell\_base\_center: Vector2 \= \_macro\_grid.grid\_to\_world\_center(test\_cell)  
			var offset\_norm: Vector2 \= \_macro\_grid.get\_cell\_normalized\_offset(test\_cell, 883\)  
			var max\_jitter: float \= \_calculated\_cell\_size \- \_safe\_min\_distance  
			var jitter: Vector2 \= (offset\_norm \- Vector2(0.5, 0.5)) \* max\_jitter  
			var galaxy\_layer\_pos: Vector2 \= cell\_base\_center \+ jitter  
			  
			if \_intersects\_frustum(galaxy\_layer\_pos, \_cached\_screen\_center\_layer, \_cached\_frustum\_half\_extents):  
				candidate\_found \= true  
				candidate\_pos \= galaxy\_layer\_pos  
				candidate\_cell \= test\_cell  
				break  
		if candidate\_found:  
			break

	if candidate\_found:  
		if not \_is\_rendered or \_active\_cell \!= candidate\_cell:  
			\_configure\_galaxy\_instance(candidate\_cell, candidate\_pos)  
		\_target\_alpha \= 1.0  
	else:  
		\_target\_alpha \= 0.0

	\_update\_fade\_state(delta)

func \_intersects\_frustum(pos: Vector2, center: Vector2, half\_extents: Vector2) \-\> bool:  
	var delta\_pos: Vector2 \= (pos \- center).abs()  
	var boundary: Vector2 \= half\_extents \+ Vector2.ONE \* (landmark\_profile.maximum\_bounding\_radius \+ landmark\_profile.safety\_padding)  
	return delta\_pos.x \<= boundary.x and delta\_pos.y \<= boundary.y

func \_configure\_galaxy\_instance(cell: Vector2i, layer\_pos: Vector2) \-\> void:  
	\_active\_cell \= cell  
	\_is\_rendered \= true  
	\_active\_galaxy\_sprite.position \= layer\_pos  
	  
	if not landmark\_profile.galaxy\_textures.is\_empty():  
		var tex\_idx: int \= int(\_macro\_grid.get\_cell\_pseudorandom\_float(cell, 11\) \* landmark\_profile.galaxy\_textures.size())  
		tex\_idx \= clampi(tex\_idx, 0, landmark\_profile.galaxy\_textures.size() \- 1\)  
		\_active\_galaxy\_sprite.texture \= landmark\_profile.galaxy\_textures\[tex\_idx\]  
	  
	var scale\_factor: float \= lerpf(  
		landmark\_profile.base\_scale\_range.x,  
		landmark\_profile.base\_scale\_range.y,  
		\_macro\_grid.get\_cell\_pseudorandom\_float(cell, 22\)  
	)  
	\_active\_galaxy\_sprite.scale \= Vector2.ONE \* scale\_factor  
	\_active\_galaxy\_sprite.rotation \= \_macro\_grid.get\_cell\_pseudorandom\_float(cell, 33\) \* TAU  
	  
	var color\_idx: int \= int(\_macro\_grid.get\_cell\_pseudorandom\_float(cell, 44\) \* landmark\_profile.modulate\_colors.size())  
	color\_idx \= clampi(color\_idx, 0, landmark\_profile.modulate\_colors.size() \- 1\)  
	\_active\_galaxy\_sprite.modulate \= landmark\_profile.modulate\_colors\[color\_idx\]  
	\_active\_galaxy\_sprite.modulate.a \= 0.0  
	\_current\_alpha \= 0.0  
	\_active\_galaxy\_sprite.visible \= true

func \_update\_fade\_state(delta: float) \-\> void:  
	if not \_is\_rendered:  
		return  
		  
	\_current\_alpha \= move\_toward(\_current\_alpha, \_target\_alpha, delta \* 0.75)  
	\_active\_galaxy\_sprite.modulate.a \= \_current\_alpha  
	\_active\_galaxy\_sprite.rotation \+= landmark\_profile.max\_drift\_rotation\_speed \* delta  
	  
	if \_current\_alpha \<= 0.0 and \_target\_alpha \== 0.0:  
		\_active\_galaxy\_sprite.visible \= false  
		\_is\_rendered \= false  
		\_active\_cell \= Vector2i(2147483647, 2147483647\)

### **Cinemática Orbital y Sistemas Solares: SolarSystem2D.gd y OrbitalBody2D.gd**

El modelado planetario descarta la acumulación de deltas temporales discretos para evitar la desviación orbital numérica (*numerical drift*). Todas las posiciones espaciales se obtienen evaluando analíticamente la función de Kepler en base al tiempo global continuo ![][image58]8.

GDScript  
class\_name SolarSystem2D  
extends Node2D

@export var profile: CelestialSystemProfile  
@export var system\_seed: int \= 409923

var \_star\_sprite: Sprite2D  
var \_planets: Array\[OrbitalBody2D\] \= \[\]

func \_ready() \-\> void:  
	\_build\_system\_hierarchy()

func \_build\_system\_hierarchy() \-\> void:  
	\_star\_sprite \= Sprite2D.new()  
	\_star\_sprite.texture \= profile.star\_texture  
	\_star\_sprite.modulate \= profile.star\_emission\_color  
	add\_child(\_star\_sprite)  
	  
	var num\_planets: int \= profile.min\_planets \+ (system\_seed % (profile.max\_planets \- profile.min\_planets \+ 1))  
	var radius\_step: float \= (profile.orbit\_radius\_max \- profile.orbit\_radius\_min) / float(num\_planets)  
	  
	for i: int in range(num\_planets):  
		var p\_seed: int \= system\_seed ^ (i \* 7919\)  
		var p\_radius: float \= profile.orbit\_radius\_min \+ (i \* radius\_step) \+ (CosmicHasher.hash\_2d\_float(i, 0, p\_seed) \* (radius\_step \* 0.35))  
		var p\_speed: float \= profile.base\_angular\_velocity \* sqrt(profile.orbit\_radius\_min / p\_radius)  
		var p\_theta\_0: float \= CosmicHasher.hash\_2d\_float(i, 1, p\_seed) \* TAU  
		  
		var planet: OrbitalBody2D \= OrbitalBody2D.new()  
		var p\_tex: Texture2D \= profile.planet\_textures\[i % profile.planet\_textures.size()\] if not profile.planet\_textures.is\_empty() else null  
		planet.setup\_body(p\_radius, p\_speed, p\_theta\_0, p\_tex, Vector2.ONE \* 0.75)  
		add\_child(planet)  
		\_planets.append(planet)  
		  
		if CosmicHasher.hash\_2d\_float(i, 2, p\_seed) \<= profile.moon\_spawn\_probability:  
			var m\_seed: int \= p\_seed ^ 98317  
			var m\_radius: float \= lerpf(profile.moon\_orbit\_radius\_range.x, profile.moon\_orbit\_radius\_range.y, CosmicHasher.hash\_2d\_float(i, 3, m\_seed))  
			var m\_speed: float \= p\_speed \* 3.2  
			var m\_theta\_0: float \= CosmicHasher.hash\_2d\_float(i, 4, m\_seed) \* TAU  
			  
			var moon: OrbitalBody2D \= OrbitalBody2D.new()  
			var m\_tex: Texture2D \= profile.moon\_textures\[0\] if not profile.moon\_textures.is\_empty() else null  
			moon.setup\_body(m\_radius, m\_speed, m\_theta\_0, m\_tex, Vector2.ONE \* 0.3)  
			planet.add\_child(moon)

func update\_astronomical\_state(global\_time: float) \-\> void:  
	\_star\_sprite.rotation \= profile.star\_axial\_rotation\_speed \* global\_time  
	for planet: OrbitalBody2D in \_planets:  
		planet.evaluate\_orbital\_position(global\_time)

GDScript  
class\_name OrbitalBody2D  
extends Node2D

var orbit\_radius: float \= 0.0  
var angular\_velocity: float \= 0.0  
var initial\_theta: float \= 0.0  
var axial\_rotation\_velocity: float \= 0.0

var \_sprite: Sprite2D  
var \_secondary\_bodies: Array\[OrbitalBody2D\] \= \[\]

func setup\_body(  
	p\_radius: float,  
	p\_velocity: float,  
	p\_theta\_0: float,  
	p\_texture: Texture2D,  
	p\_scale: Vector2  
) \-\> void:  
	orbit\_radius \= p\_radius  
	angular\_velocity \= p\_velocity  
	initial\_theta \= p\_theta\_0  
	axial\_rotation\_velocity \= p\_velocity \* 1.6  
	  
	\_sprite \= Sprite2D.new()  
	\_sprite.texture \= p\_texture  
	\_sprite.scale \= p\_scale  
	add\_child(\_sprite)

func \_ready() \-\> void:  
	for child: Node in get\_children():  
		if child is OrbitalBody2D:  
			\_secondary\_bodies.append(child)

func evaluate\_orbital\_position(global\_time: float) \-\> void:  
	var current\_theta: float \= initial\_theta \+ (angular\_velocity \* global\_time)  
	  
	position.x \= orbit\_radius \* cos(current\_theta)  
	position.y \= orbit\_radius \* sin(current\_theta)  
	  
	if \_sprite \!= null:  
		\_sprite.rotation \= axial\_rotation\_velocity \* global\_time  
		  
	for moon: OrbitalBody2D in \_secondary\_bodies:  
		moon.evaluate\_orbital\_position(global\_time)

### **Supervisor Pasivo de Precisión: FloatingOriginTracker.gd**

GDScript  
class\_name FloatingOriginTracker  
extends Node

signal origin\_shifted(shift\_vector: Vector2)

@export var player\_target: Node2D  
@export var camera: Camera2D  
@export var threshold\_distance: float \= 10000.0

@export\_group("Capas Parallax2D para Compensación")  
@export var parallax\_layers: Array\[Parallax2D\] \= \[\]

var accumulated\_world\_offset: Vector2 \= Vector2.ZERO

func \_ready() \-\> void:  
	assert(player\_target \!= null, "PlayerTarget requerido.")  
	assert(camera \!= null, "Camera2D requerida.")

func \_physics\_process(\_delta: float) \-\> void:  
	var current\_pos: Vector2 \= player\_target.global\_position  
	if current\_pos.length\_squared() \>= (threshold\_distance \* threshold\_distance):  
		\_execute\_origin\_shift(current\_pos)

func \_execute\_origin\_shift(shift: Vector2) \-\> void:  
	accumulated\_world\_offset \+= shift  
	  
	player\_target.global\_position \-= shift  
	camera.global\_position \-= shift  
	camera.reset\_smoothing()  
	  
	for layer: Parallax2D in parallax\_layers:  
		layer.scroll\_offset \+= shift \* layer.scroll\_scale  
		  
	origin\_shifted.emit(shift)

## **5\. Shader de Biomas Cósmicos y Buffer 8K Anti-Tiling**

El shader de pantalla completa universe\_nebula.gdshader implementa el renderizado continuo del fondo. Para muestrear la textura estelar sin artefactos ortogonales ni costuras repetitivas, el código evalúa dos frecuencias de UV desfasadas estocásticamente sobre los canales RGB empaquetados (R: densidad, G: temperatura espectral, B: magnitud). Las transiciones de bioma se resuelven de forma continua mediante una función de mezcla no lineal, eliminando las recompilaciones de pipelines1.

OpenGL Shading Language  
shader\_type canvas\_item;  
render\_mode unshaded;

// Buffer estelar 8K (8192x8192) empaquetado:  
// R \= Densidad tenue, G \= Temperatura (Kelvin normalizado), B \= Magnitud / Gigantes  
uniform sampler2D starfield\_texture : filter\_linear\_mipmap, repeat\_enable;

// Bioma Cósmico A  
uniform vec4 biome\_a\_deep : source\_color \= vec4(0.01, 0.01, 0.03, 1.0);  
uniform vec4 biome\_a\_gas1 : source\_color \= vec4(0.22, 0.05, 0.35, 0.85);  
uniform vec4 biome\_a\_gas2 : source\_color \= vec4(0.03, 0.20, 0.40, 0.60);

// Bioma Cósmico B  
uniform vec4 biome\_b\_deep : source\_color \= vec4(0.00, 0.02, 0.03, 1.0);  
uniform vec4 biome\_b\_gas1 : source\_color \= vec4(0.04, 0.38, 0.25, 0.85);  
uniform vec4 biome\_b\_gas2 : source\_color \= vec4(0.40, 0.22, 0.05, 0.60);

// Control de mezcla e interpolación  
uniform float biome\_blend\_factor : hint\_range(0.0, 1.0) \= 0.0;  
uniform vec2 camera\_world\_position \= vec2(0.0);  
uniform vec2 viewport\_resolution \= vec2(1920.0, 1080.0);  
uniform float noise\_uv\_scale \= 0.00012;  
uniform float chromatic\_offset \= 0.0025;

vec2 hash\_noise(vec2 p) {  
    p \= vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));  
    return \-1.0 \+ 2.0 \* fract(sin(p) \* 43758.5453123);  
}

float gradient\_noise(vec2 p) {  
    vec2 i \= floor(p);  
    vec2 f \= fract(p);  
    vec2 u \= f \* f \* (3.0 \- 2.0 \* f);

    return mix(mix(dot(hash\_noise(i \+ vec2(0.0, 0.0)), f \- vec2(0.0, 0.0)),  
                   dot(hash\_noise(i \+ vec2(1.0, 0.0)), f \- vec2(1.0, 0.0)), u.x),  
               mix(dot(hash\_noise(i \+ vec2(0.0, 1.0)), f \- vec2(0.0, 1.0)),  
                   dot(hash\_noise(i \+ vec2(1.0, 1.0)), f \- vec2(1.0, 1.0)), u.x), u.y);  
}

float fbm\_nebula(vec2 uv) {  
    float total \= 0.0;  
    float amp \= 0.52;  
    mat2 rot \= mat2(vec2(0.80, 0.60), vec2(\-0.60, 0.80));

    for (int i \= 0; i \< 4; i++) {  
        total \+= amp \* gradient\_noise(uv);  
        uv \= rot \* uv \* 2.04;  
        amp \*= 0.5;  
    }  
    return clamp(total \* 0.5 \+ 0.5, 0.0, 1.0);  
}

vec3 sample\_starfield\_anti\_tile(vec2 world\_pos) {  
    const float BUFFER\_SIZE \= 8192.0;  
    vec2 base\_uv \= world\_pos / BUFFER\_SIZE;

    // Descorrelación angular de muestras secundarias para evitar patrones repetitivos  
    vec2 uv\_primary \= base\_uv;  
    vec2 uv\_secondary \= (base\_uv \* 1.37) \+ vec2(0.318, 0.673);

    vec3 sample\_a \= texture(starfield\_texture, uv\_primary).rgb;  
    vec3 sample\_b \= texture(starfield\_texture, uv\_secondary).rgb;

    return max(sample\_a, sample\_b \* 0.8);  
}

void fragment() {  
    vec2 screen\_centered \= SCREEN\_UV \- vec2(0.5);  
    vec2 absolute\_pos \= camera\_world\_position \+ (screen\_centered \* viewport\_resolution);

    // Muestreo del Starfield Buffer 8K a velocidad atenuada  
    vec3 star\_data \= sample\_starfield\_anti\_tile(absolute\_pos \* 0.05);

    // Muestreo FBM con dispersión cromática angular  
    vec2 gas\_uv \= absolute\_pos \* noise\_uv\_scale;  
    float gas\_g \= fbm\_nebula(gas\_uv);  
    float gas\_r \= fbm\_nebula(gas\_uv \+ vec2(chromatic\_offset \* 120.0, 0.0));  
    float gas\_b \= fbm\_nebula(gas\_uv \- vec2(chromatic\_offset \* 120.0, 0.0));  
    vec3 gas\_dispersion \= vec3(gas\_r, gas\_g, gas\_b);

    // Evaluación cromática del Bioma A  
    vec3 col\_a \= mix(biome\_a\_deep.rgb, biome\_a\_gas1.rgb, gas\_dispersion.y \* biome\_a\_gas1.a);  
    col\_a \= mix(col\_a, biome\_a\_gas2.rgb, gas\_dispersion.z \* biome\_a\_gas2.a \* 0.7);

    // Evaluación cromática del Bioma B  
    vec3 col\_b \= mix(biome\_b\_deep.rgb, biome\_b\_gas1.rgb, gas\_dispersion.y \* biome\_b\_gas1.a);  
    col\_b \= mix(col\_b, biome\_b\_gas2.rgb, gas\_dispersion.x \* biome\_b\_gas2.a \* 0.7);

    // Interpolación no lineal entre configuraciones de bioma  
    float blend\_weight \= smoothstep(0.0, 1.0, biome\_blend\_factor);  
    vec3 final\_nebula \= mix(col\_a, col\_b, blend\_weight);

    // Composición espectral de las estrellas (Canal B \= Magnitud, Canal G \= Tinte)  
    vec3 star\_color \= vec3(star\_data.r \* 0.65) \+ vec3(star\_data.b \* 1.8 \* star\_data.g);  
    vec3 out\_color \= final\_nebula \+ star\_color;

    COLOR \= vec4(out\_color, 1.0);  
}

## **6\. Cinturón de Escombros y Polvo Masivo: Optimización MultiMesh2D**

Para mantener una tasa sostenida superior a 60 FPS en capas con densidades superiores a miles de fragmentos de roca y chatarra (scroll\_scale entre ![][image59] y ![][image60]), la creación individual de nodos Sprite2D resulta inviable debido a la saturación del SceneTree y la fragmentación de llamadas a la API gráfica1.  
La solución implementa una arquitectura basada en MultiMeshInstance2D. El espacio de paralaje se particiona en macro-sectores persistentes. Al cruzar una frontera espacial, el componente regenera analíticamente el buffer de instancias en memoria local de GPU mediante un único draw call, dispersando elementos deterministamente a través de CosmicHasher.

GDScript  
class\_name DebrisStreamer2D  
extends Node2D

@export var profile: DebrisLayerProfile  
@export var parallax\_layer: Parallax2D  
@export var camera: Camera2D  
@export var run\_seed: int \= 552199

var \_multimesh\_instance: MultiMeshInstance2D  
var \_multimesh: MultiMesh  
var \_active\_quadrant: Vector2i \= Vector2i(2147483647, 2147483647\)

func \_ready() \-\> void:  
	assert(profile \!= null, "DebrisLayerProfile requerido.")  
	assert(parallax\_layer \!= null, "Parallax2D requerido.")  
	assert(camera \!= null, "Camera2D requerida.")  
	\_allocate\_multimesh()

func \_allocate\_multimesh() \-\> void:  
	\_multimesh\_instance \= MultiMeshInstance2D.new()  
	\_multimesh \= MultiMesh.new()  
	\_multimesh.transform\_format \= MultiMesh.TRANSFORM\_2D  
	\_multimesh.use\_colors \= true  
	\_multimesh.use\_custom\_data \= false  
	\_multimesh.instance\_count \= profile.instance\_count  
	  
	var quad\_mesh: QuadMesh \= QuadMesh.new()  
	quad\_mesh.size \= Vector2(128.0, 128.0)  
	\_multimesh.mesh \= quad\_mesh  
	  
	\_multimesh\_instance.multimesh \= \_multimesh  
	\_multimesh\_instance.texture \= profile.mesh\_texture  
	add\_child(\_multimesh\_instance)

func \_process(\_delta: float) \-\> void:  
	var cam\_pos: Vector2 \= camera.get\_screen\_center\_position()  
	var layer\_pos: Vector2 \= cam\_pos \* parallax\_layer.scroll\_scale  
	  
	var current\_quadrant: Vector2i \= Vector2i(  
		int(floor(layer\_pos.x / profile.field\_bounding\_box.x)),  
		int(floor(layer\_pos.y / profile.field\_bounding\_box.y))  
	)  
	  
	if current\_quadrant \!= \_active\_quadrant:  
		\_active\_quadrant \= current\_quadrant  
		\_rebuild\_quadrant\_buffer(current\_quadrant)

func \_rebuild\_quadrant\_buffer(quadrant: Vector2i) \-\> void:  
	var quadrant\_base: Vector2 \= Vector2(  
		quadrant.x \* profile.field\_bounding\_box.x,  
		quadrant.y \* profile.field\_bounding\_box.y  
	)  
	\_multimesh\_instance.position \= quadrant\_base  
	  
	var quad\_seed: int \= CosmicHasher.hash\_2d(quadrant.x, quadrant.y, run\_seed)  
	  
	for i: int in range(profile.instance\_count):  
		var i\_seed: int \= quad\_seed ^ (i \* 4093\)  
		  
		var lx: float \= CosmicHasher.hash\_2d\_float(i, 0, i\_seed) \* profile.field\_bounding\_box.x  
		var ly: float \= CosmicHasher.hash\_2d\_float(i, 1, i\_seed) \* profile.field\_bounding\_box.y  
		var scale\_factor: float \= lerpf(profile.scale\_range.x, profile.scale\_range.y, CosmicHasher.hash\_2d\_float(i, 2, i\_seed))  
		var rotation\_angle: float \= CosmicHasher.hash\_2d\_float(i, 3, i\_seed) \* profile.max\_initial\_rotation  
		  
		var transform\_2d: Transform2D \= Transform2D(rotation\_angle, Vector2(lx, ly))  
		transform\_2d \= transform\_2d.scaled\_local(Vector2(scale\_factor, scale\_factor))  
		\_multimesh.set\_instance\_transform\_2d(i, transform\_2d)  
		  
		var alpha\_variance: float \= lerpf(0.2, 1.0, CosmicHasher.hash\_2d\_float(i, 4, i\_seed))  
		var instance\_color: Color \= profile.alpha\_modulation  
		instance\_color.a \*= alpha\_variance  
		\_multimesh.set\_instance\_color(i, instance\_color)

## **7\. Matriz de Rendimiento y Gotchas en Godot 4.3+**

La sustitución del antiguo paradigma ParallaxBackground / ParallaxLayer por el nodo Parallax2D aporta notables ventajas en Godot 4.3+, pero introduce dependencias que pueden comprometer el rendimiento o la estabilidad visual si no se gestionan adecuadamente2. A continuación se detallan las trampas críticas detectadas en entornos de mundo abierto espacial y las mitigaciones arquitectónicas aplicadas en Cosmos Engine.

| Escenario Crítico | Mecanismo Interno en Godot 4.3 | Consecuencia en Ejecución | Estrategia de Mitigación en Cosmos Engine |
| :---- | :---- | :---- | :---- |
| **Zoom Dinámico Extremo y repeat\_times** \[cite: 5\] | Parallax2D duplica el contenido de sus hijos tantas veces como indique repeat\_times en múltiplos de repeat\_size3. El valor por defecto (repeat\_times \= 1\) asume que el viewport no supera el doble de la textura base1. | Al alejarse la cámara con zoom mínimo (![][image61]), los extremos de la pantalla quedan vacíos, mostrando costuras o bordes cortados5. | Suprimir el uso de repeat\_size para fondos y nebulosas continuas3. Delegar las capas no acotadas a shaders de pantalla completa con coordenadas globales invariantes1. |
| **Desfase Cinemático por Recentrado Flotante** \[cite: 5\] | Parallax2D calcula su transformación interna en base a la posición absoluta de la cámara en cada frame1. Un salto de posición instantáneo altera el cálculo relativo de la capa5. | Desplazamientos visuales abruptos (*snapping/jitter*) de miles de píxeles en las capas de paralaje durante el fotograma del recentrado1. | El supervisor FloatingOriginTracker intercepta el salto y compensa vectorialmente layer.scroll\_offset \+= shift \* layer.scroll\_scale en el mismo frame3. |
| **Transformaciones Locales en Hijos de Parallax2D** \[cite: 1, 5\] | Parallax2D altera su matriz de proyección global relativa al viewport3. Los nodos anidados multiplican sus transforms locales sobre este espacio relativo alterado1. | Desincronización física si los elementos hijos intentan consultar posiciones globales respecto a objetos de la capa interactiva GameplayWorld1. | Prohibir el uso de componentes físicos (Area2D, CollisionShape2D) bajo capas de paralaje. Todas las entidades interactivas deben residir en GameplayWorld1. |
| **Fragmentación de Memoria por Ciclo de Vida Dinámico** | Crear y destruir nodos (.instantiate(), queue\_free()) al cruzar fronteras de celdas espaciales fragmenta la memoria interna del motor. | Caídas periódicas de framerate (*stutter spikes*) asociadas a la recolección de elementos liberados en el SceneTree. | Uso estricto de bancos de nodos persistentes (*object pooling*) con pre-asignación en \_ready(), actualizando transformaciones existentes mediante asignaciones directas. |
| **Consumo Excesivo de VRAM en Buffers 8K** | Una textura de ![][image2] píxeles sin compresión en formato RGBA8 ocupa 256 MB de memoria de vídeo de forma continua. | Desbordamientos de memoria gráfica y bloqueos del pipeline de renderizado en hardware con recursos limitados. | Importación forzada bajo compresión de bloques (VRAM Compressed / BPTC para escritorio, ETC2/ASTC para plataformas móviles) y empaquetado de canales RGB funcionales. |
| **Deriva Acumulativa por Integración con delta** | Integrar rotaciones astronómicas mediante la acumulación sucesiva de delta en \_process genera deriva de precisión flotante tras sesiones prolongadas. | Desincronización del estado del universo: los planetas no se encuentran en la misma posición al reingresar a un cuadrante tras horas de juego. | Eliminación completa de la dependencia de delta cinemático. Las órbitas se evalúan analíticamente en base al tiempo global continuo: ![][image62]. |

## **8\. Consideraciones de Síntesis Arquitectónica**

La arquitectura técnica de "Cosmos Engine" para Godot 4.3+ resuelve los retos del renderizado procedural espacial infinito desacoplando estrictamente el espacio físico interactivo del entramado visual de paralaje2. Mediante el cálculo cerrado de órbitas keplerianas, el aislamiento analítico del frustum galáctico y la corrección vectorial pasiva sobre Parallax2D.scroll\_offset, el motor mantiene una ejecución determinista ![][image1] sin recurrir a estructuras mutables ni almacenamiento en disco3.  
Asimismo, la combinación de shaders de cobertura total con texturas de distribución estocástica y la instanciación por hardware mediante MultiMeshInstance2D maximiza el aprovechamiento de la GPU, garantizando un rendimiento estable superior a 60 FPS en coordenadas de mundo abierto no acotadas1.

#### **Obras citadas**

> 1. Godot Parallax2D Guide: Setup, Loops, And Fixes \- Yelzkizi, [https\://yelzkizi.org/creating-parallax-effect-with-godot-parallax2d-setup-infinite-backgrounds-and-common-fixes/](https://yelzkizi.org/creating-parallax-effect-with-godot-parallax2d-setup-infinite-backgrounds-and-common-fixes/)  
> 2. Parallax2D Progress Report \- Godot Engine, [https\://godotengine.org/article/parallax-progress-report/](https://godotengine.org/article/parallax-progress-report/)  
> 3. Parallax2D — Godot Engine (stable) documentation in English, [https\://docs.godotengine.org/en/stable/classes/class\_parallax2d.html](https://docs.godotengine.org/en/stable/classes/class_parallax2d.html)  
> 4. Camera2D — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_camera2d.html](https://docs.godotengine.org/en/4.4/classes/class_camera2d.html)  
> 5. Godot Parallax2D Setup Guide For Infinite Backgrounds \- Yelzkizi, [https\://yelzkizi.org/godot-parallax2d-infinite-backgrounds-guide/](https://yelzkizi.org/godot-parallax2d-infinite-backgrounds-guide/)  
> 6. 2D Parallax — Godot Engine (4.3) documentation in English, [https\://docs.godotengine.org/en/4.3/tutorials/2d/2d\_parallax.html](https://docs.godotengine.org/en/4.3/tutorials/2d/2d_parallax.html)  
> 7. How do infinite space sims handle levels? : r/gamedev \- Reddit, [https\://www\.reddit.com/r/gamedev/comments/16qx64c/how\_do\_infinite\_space\_sims\_handle\_levels/](https://www.reddit.com/r/gamedev/comments/16qx64c/how_do_infinite_space_sims_handle_levels/)  
> 8. Parallax2D — Godot Engine (4.3) documentation in English, [https\://docs.godotengine.org/en/4.3/classes/class\_parallax2d.html](https://docs.godotengine.org/en/4.3/classes/class_parallax2d.html)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACsAAAAaCAYAAAAue6XIAAACcElEQVR4Xu2WT6hNURTGvxeKIn8j/yYyEQPyJwMMJDFASVEmZox5iNE1eAOT10tKmWBEMUWZeEUSMyUKiUQIEzN5fJ+1N/use84+517uK3W/+rXf22vfs799ztprb6Cv/0dTyWTfmdEkMt13dqPZZCvZQ5aRCcVwm1aSC+hscpkdIbt9oIkGyCbygNwk+wO3yDOy9s/QghaR22S5DwRNIQfIDNcv6aXcIOt8ICet8jR5iXZTip0nX8gqF9MC9XZarn8W2Usuwn73isxPByTaBnshSqNaycw58hnVK1QqfCJnYQajVpCnoU0ls7vIGnIFebNKnXtknw+U6RAZC22VZpKH5DGZk/QfJ9eR31iXkDcrDZFrZKIPpFpK3pInZJ6LpYpm00llUEZPxkEVamJ2O2yM8r9SLfIDtrKclpB3KE6qVv/viIMq1MTsavIG7fvlt5TQo7AU2FIMtUlxjbtDpoU+TfCebIiDKtTEbO3C4wBtHG2gnM7AvkAr6ZPZ16HNqROzKpWligPqHrQYVmc/olhLe2H2sA9EaVdrd+ceNEBOwN7qERfrhdnKNFCZuEy+oTrvVHdV1HUoqB6n0qZTJdFOzqmJ2UbP0okkMzrXvZnN5AMZhh2ZXvHLHPQBJ5nVTs+VJVWBF6jfO78GPofdCeJ9QHeDRzDDSoUyqV+L1ObzmgurHF9hKSS+w0yXHT6acxQNj1zdqrQq3bKUNwtQbTKVjkgtUodGt4rp2HL9/1y6Nd2FXUa6lU7R+6HtuXaSqyjP6zrp650ix8LfPZcmORrodMKNsAtMJ5f2v5YqySBZ7wMZLYTdScbVaF99jYd+ApnHebmMY+0wAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF8AAAAWCAYAAACmG0BRAAADBElEQVR4Xu2YS8hNURiGP6HIrUguieMyIWXgFhkYoBRSRFEyICUmFJFSZECR20hKlJIB6e/vlwwOSmYyQEmJXIqYUQYu72Ptdc7a6997u01sZ731DPZaa6999vut9a1vH7OkpKSkpE7UQLFOnBFHxDTRJzeirb5ijWhE7V7hXIfEuHz3D4VjTopF5ubtOA0TV8QGMUbMELfFTmsHALOWixPilfgoZmZ9oUaLW+K4OdOXiWdiQTDGP2+zmCz2iy+iJ+vrKG0Te6O26eK+mJhdY/5SsdCcWUXm9xNnxWMxKmhn9d+ztrE874IYml0T4IPim9idtXWMzovDlk8z7ADMZxfEwqAi86eK96IpBgft7Jiv5lIL4nkYvaM1wmy2+CRuikFBeyz6wsDG4h3GWo1SGCsTM8i9/sXXim7Lm+hVZj7XtDett/nhql4pHorFrRHl98YaKS6LWXGHOeM3ilOif77r39UE8cScQU/NBeNO1l6kPzWflFSm9ebGHI07CsRZcl3MCdpqabwXKeOFOQOA1OBzcqwy88np5HYCNyRo9zuLOYvEfRzwLICygMcKA1Br43kRDNtiruLBWMy6K0YE47zKzEerxDsxN7tumDuAy8zHuF3mdhwL4HfkA3Daamo8VUyX5asMXuqaOcOoTGJVmY+ZlJeY+VxcNRfUskqGYBH4RtT+K+JZHNoEe37UVwtRzbDd41VHUFhVRau1yvwiYX5Y7XhhfI8Ynl1zTpD7B7RGlAvjWRis+PHmghyeAbUQBj4Sk+IOc7U/FVCsKvO3W/6wxqRzlq/zEUZdjNpYAHzEcU+VQuN9quHjrnYBYLXdEHss/9KUdE0xL2jzwnxqcmrzWOyUz9a+DzPeiBWtEc5k0tJbc4e854O5w7lK/Mat5r6g4xxfywBMEQ/MBYFtz4qnDufw9QGh/r9kziBfEcFrcSwbgzCZnbRJ7BMvLT8PIkDhHCE8v0r853TAehvvRQrjvymfymohvghJI6vFEqv+yvyZ+AKltv/beZKSkpKSkv4LfQcFLaO2S1/ufAAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAWCAYAAAC1zAClAAADo0lEQVR4Xu1YXahNQRReNxQh6cpNEReRKOoSCk+I5CfXg1AeFKX7QP7K0yl5IEoU8iJKHni9eSCuKOLZT0kiEeWNkhLru2tmn7Vnzzp79jkPTjpffe0za2Z/s2bN7DUzh6iDDv4njGOODo0dlGIEcyKzK6zwWMS8ypwQVnRQCgT1EPOg+53DVOYD5vzAjoZLmeeZF5kbSGYpBWOYO5hXmKeZc/PVGWBHPdqhPd5rBs3qpI6xTH8U8zqzXxshfo5Z00ZnP8p8yOxldjNvkIhDqBGw+u8yT5CkGnwVLyno2JVhRz3aoT3eq/r1NKuTOsZU/QXMJ6HhtXtq9DG/MFco20zme+Y6ZYvhGPM5SR7y2Ml8xexx5WnMN87ugfZ4b0DZytCKTsoYq+iPZN7UBgRikIob2UmSTqYo23jmI5LcXMgtDr7ja4F9CfM7c5Mrw9kfJAP0gCZWzhDJCklBKzopY6yqn00CAorAHq/X5exhxxAaouKq1JjH/EbF4MI5OIkBAchxodMA3vtMsoJS0KxO6hir6i/0PyAK8Y31umH4DqyOQ7uGD6IVXG/H03I6ZrdgtbfsHtZYQrulY9kzrVjOAXzQyzqOARP1hxoH1+vEnLOcjqEVnZQxzna/YzqWfpYmUPHBPTWw6bylxh1bwV1P5cEdy7znymHfltMxtKKTMsZZVF2/NLhWEC27hg5iI7vlnGW3YLW37B7WWEK7pWPZS4OLI8VtsjvGbopdNQYkeCR6K7h+88TGFnMO730kudikoFmd1DFW1c+Ci0B8IvmUQ+CIhl0fu7/HJOYLkh3UA4ft6e4JeOcGKX+8W8385Z4AjmS/VRnwO7h+F7elyaocoorODFUGUsaYqu+RnaK80L56XQYkc8zMdmVbyfzKXK5sZ0lybE3ZdpF8Eb2u3EVyq3lK9VtNN/MZ5d+L9bmHRB+Hc6y2EK3oxNqFY0zV98hWMgaNw7JeiRpbme+Ye5m7Sa6A+yl/gThAsiL7lQ2r+BLJ/xVbSAKLScT1UWMxiT6uoNtIzpanKH/1xOnjJ8nmY+X5Kjpoo/1PGWOKvkfu5IXoY2asSwFmDo6B+J0KODeHxJlVFHcEwI6/lmQScNWMAZ/eBapfnWNI0bGQMsZU/ZouQOwxlf9f8C+B9HKG4mmhnYBY3g+NSNq3qPg3WjsAGxECuyasaENgr7kcGvEJH3HUuaYdgDy7mdrPrxDY5O6QnJwKQE48zFwWVnRQCn8eHj4p/AUfLiMNk3HO3QAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAWCAYAAACCAs+RAAACKUlEQVR4Xu2WT0gWURTFj6iQZEgoSVDQP4p2iooE2SrCEkPSRajQLiJcK7gSxIXtcmHQRly4a9uqIMWdrm0jEUYoBrlzGXnOd+fqm2menzCgLebAD2buu2++e97Mu98DSpUqdZpqJ4+ywUQ1pJvMkXnSR2pTGaY75A15T4ZJQ3q4IsU0phzlak5hqbhxsk7+kon0cEUyoZwVcp00kyVYIfVB3iD5StpII5kmn0hTkKNrxTSmHOVqTmHJSD95QvaRb6SD7JL7QewG2SK9yf1VsklGDjOAi7AFGgtier5iGnOFcwpLxcaMzMCKvhzELpBVsgB7YypG8/Ucl+J6c8uw1Xdji0GO1JW5L6SYkXPkI/41osKWcbS62jtZI5KK3oG9wbvkdxILlZ1TSDEjXnDMiMdVXMyIx/03zsSIilSxxxm5lVxXM6K9qIYSNaLO0Qr7oWpcQn7bjBnRc7/heCM3yWdUN/IYVYyohakVnoS35FplVloxI9lPKBb/7z+tOvIBcSPqXOpg6mwxIz/JFdiG18Y/EyOSYuo26jquFrIB61bSU/KHPDzMOOp4Qtdu3u9d4ZzCciOT2QHYZtaqPg9iPeQXuZfcN5M1MuUJyJ83Sn7ATghSDexfvrBekW3YJnT2YJ+MGoPrGflOXpIXsGPFa1ghrs4kR8eZIdh/zCzSxxhdvyNfyADMhN7sqUqrrhYqdJ2n87CDp4rUsSVPMn8bZvYB0kZLlSqVowP6kI7tLsNLuwAAAABJRU5ErkJggg==>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAWCAYAAAC1zAClAAAELklEQVR4Xu2YX+hNWRTHl1CEjMif0Iw/zSTKlP+FJ0QyM+FhMsqDzJQ8mGZQXvxKHogShaRESQ3lSR5omKGI0jyMGSVNNBHFvJgSyazP3Wedu88+Z9+z732Zm+63vt171j53/dt/1tpXpIcePiQMVQ4KhT3Uor9yhLJfOGD4XHlSOTwc6KEWJPUH5ffZ9wImKK8qpwdyXpynPKQ8olwpbpZSMFi5TnlcuU/5WXG4AXShE91wrbjfdQL0Ywd72E3VkxJjip8DlaeVa3whyg8q+3xhJt+u/EU5STlSeUac8yhqBVb/ZeVucUcNu+IPKRpGx2HlLuUU5Sblv8rflR9776UAvejHDvawi/26XZgSYzt+zlDeDAX3s08fs5TPlAs92WTlI+VyT1aFHco74s4hwzfKP5Vjsmd0XFGOz98QWa98rzyhHODJW2Gi8oE4/QbsYn+LJ6tCSozt+Mn3s95zIxEXpVzI9ogzMs6TDVNeF3c2l86WDBbYqUA+R/lK+UX2jF1z0MDx9LfyoTQnoQ4klZVEogz4xgq8Jm4lx5ASY7t+5pNMQknszuZYQR4axtFrUl6VPqYpX0g5uQRPEggIzFb+pvw2f8PZwmZotxU4K8PkAuw/FbcSq5AaY7t+zrQv9tKq5lgDZiD8cUzuw5IYS24o98H2fKu8IOWdFAP6YsmtkhtiscTkPlr5mf+m6swBsZlJMcxEsY3CJNYll8LBVvxHOTcYi8H8qUpiXXI7jbHOz/wYwvDj7NMH5wjnSWigzjBYIZ0ld424bbwkHGiBIeKKTVUS65LbaYx1ftYmN2YgJvcRS2JMDlgBd8UVvXYRS2JMbojFEpODFD9rk0tLcV7KBsww1ZSqWgUKCDMbJtGSGxZPHL6hnJo9Y5tW56P8jdagQFYlEftUdCp7FdqNMdXPPLkk4om4rRyCFoSqT/U3jFLeE1ehDZxBNNPWdJtzF6V42LON3mSfBn5HgH4zjg2aeAuM29FoKRcOA63dOynqtU7A9wE9n3jPIDXGFD8NeRdlir5rjuVghpj5rz3ZIuVz5QJPdkDcGdvnyZhRdsSk7LmfuFvTLWnemsYqf1W+FPeuEf0/SbM53yhOP825yXyMVN6Wov0q36v0VL0XxpjqpyHfKQRN5fNnycdq5V/ierwN4q6Ym6V4gdgqbkVy0BtYxUfF/V/xlbjEMolcTw3WnFfRemFA9/FaXPEJz0ADvSh+cpXl3k+PuleK13TTwzu+/3UxpvppKHRezBozH7sUsDJwDPI9FTj3qbhgF0v9/xGtwFY+LOXbkA86h2XiJpMrcTvoNMYq9PkPKLsh9f8X/J/geNkv5S3YbSCXP4dCisI5Kf+N1g2gEJHYpeFAF4JacywUsoW3ZfTPo24A5+yX0n1+haA4XpLy35ANcCb+qJwfDvRQC9oxilujU/gPwnkeF8nQp0UAAAAASUVORK5CYII=>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAWCAYAAABdTLWOAAACNUlEQVR4Xu2WT0hUURjFj5iQaEoUimBkKvRnJSSKoFEiUkQSJhi1qJVCm1YVLpQgXNgmCiloIwbtBFctwhamC8HECLIWISIEURCuWiiknjPf+3Pf05mRmQYh5sCPeffe79137p/v3gHyyuv/VBm5S16SQXIs2pxQAWkmz8hzcpkURiJMJ8ljWF83SHG0OTMdJ2/JRVJFzpNPpNuJkcH75D05QY6Q1zAjRU7cNfKFNJBS8ohMOe0ZSR8fRdSQJMMzpNwrnyU/SWsQAdSSVVispNn/Rm4GEcBh8sEpZySNdprcjlYnTC2QSq88DDOkmfZ1iMySMdhgZe4P7F1fqteMZ6UDZIJskHuwpVPHA+SF136QvMFOk/4ANVOaMe3VuElpPFbOSE1kjWyRefKETCJcat9MMpN+vczkzKR0gazDjIohhFkpAzKSymS995zSpJZJ+0edpKMC0aNDmbhIrsKW+S/M6CuYUfW7jNQm68g7pDGpD+k42AtPSU3iLTMsg252nyEfySYsc+PL6iten7PlvkQ+k6Oxes3eV/IAYXIlM6kMV6brBMiJySsIs9NVAezo6PfKMvubnA4ibGBLsKyWumBbpSOICE+GrFQNu116Y/WnyBzsdpGUGN/J9SACaCO/SItX1i2k0+GhH4Dwvaylj/yAJYpMjMCWut0Ngu3bFdJHbsGuvzuwWffV6MXoCu2BrZL6+yfS6XAO1rF+3fvYlWZLW0ToeTeVkE7YabHbH5W88tp3bQNqA3gaiNMbuAAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAXCAYAAABJXhw0AAABTElEQVR4Xu2WvytGURjHH7H4ESmRUVmUMsigLGRQNlnEblHKX/CuFgYmJpNFZvkLDGZ22SSLhQGf7z3n5bxn0L1d6tw6n/rU6Tz39Pac8zznPWaZTKYKi/iEn94r7A3ig3gdxOUl9gffJEMXnuA7vuF8Z7hgDS+sM8nkGMYz3DW348fmkgvZw81oLjlm8BDH8R4fcSKI9+Cp/y5ptNPbftwydyo731GzEXMnppNLmgOc9eNpfMEbHPJzC3jkx8nS7g/tulAZneMHrvg5nVbZ/pjEW3yo4Eaxsibt/gibWwkoESWkW6px/dFGJaXSUoktWQP6Q6eg2p+LA7BlrunvcD+K/UY3jpq7Acs6UKysQdwfIWPmrmIlU7Y/hP7xV3G9glPFyhqobPTc6IsDnhY+2x/80H+xjK/283bSs0S7GKOrWG+vpPsjk8lkmsEXrpNDhjGK7yoAAAAASUVORK5CYII=>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAWCAYAAAC1zAClAAAEE0lEQVR4Xu1YW6gOURReJxQh6YgUcSQShdyFJ0RyySVC6aSQPNBxiadT8kBEjpCUKCnO68kDcUQR5cmtJJGI4omScvm+f8+eWbNnz8yelHPS/9XXP//a07rtvdfae0TqqON/Qj+wtyusoxQ9wIFggztgMQm8AA5wB+ooBZPaAu6KnlMYBt4GxztyvjgDPAmeBpeImaUQ9AHXg+fAI+DY9HANa8DZYnYMbQ0GN4qZ6KqgftqhPdql/RCExBjiZy/wErhKyWovnwBbtTCS7wXvgE1gI3hZjPNUVASu/hvgQTEO0YlnkjbcE7wK/nZ4TarvHuqlftqhPdql/TI9ITFW8XMCeN8VvIh+NaaAH8E5SjYKfAMuUjIf9oGPxNQhiw3gc3CIkp0Hn4BvwXbxr5oyDAdfitFvQbu0v0PJfAiNMdRPTsQVLWAiOiTbyA6JMTJUyfqDd8XU5kxtiWADu+jIp4FfwWVK1iYmwL8Bk/pN0nroG1dgp5iVnIfQGKv4GU8yE8rEHkjGUnLXMB3tlOyq1BgHfpZscukck8CALKo4nQfWSje5BO1/ELMSfagSYxU/J9oHKqXypclYDdZAnmFXrmGTmJdcLT8FHgcfg+/E1KvJajwE1JeXXJ/cIi8Wn7yKn7EuX80hbNJDDLvgRLHghySXW2+/JPWLHfgLOD1+oxjWH18Sy5JbJcYqfsZliIZZpF0H2HReSZhhF4slPLmsb7ox8EjIlcGmwOZQhr7gTfEnsSy5VWKs4mdpcn0GiuQaviQWyTXsamLQ+lRRhLwk5skt8mLJk2sU+VmaXM5Gu2QNWMPsppxNH9hA2EjcJNrk2ubZDP4Ct8Vv5G/VIrBB+pJI+1xdXGU+hMZY1c84uUzEezFb2QWPaOz67P4Wg8CnYjq0BQ/bI6JfwjrXIenj3XzwR/RLUD/Lh3babrdOSZzkduSNyD0qWvBo91MSvYQ9CWgfqGek+k+ExBjqp0V8irKKtiZjMUaLUbBOyeaCn8BZSnZMjPFWJWPB545oiv43iLk1PZDkVkMd7ML6trcW/C7pm9xmMfp99Y1oBB9K2r7Pd58e33tujKF+WsQ7hUGzE+qVqLESfA1uATeJuWJul/QFYqeYFakN0ZEzYr5XrBCTWE6ivotTR0v0DgOnD1xFrn6ePhgI65u7BS2mivGTV9nVYs6ohyWdEKuH72j9ZTGG+mmROnlx1jjzeZcCrgw6RvI5FDQ8Rkyw8yT/ewSvr5yAhZK9q1twK7dJtnlo8ORAHdRFnVUQEmOIn0Sr/kNl96T8e0FXguXlqPjLQncCc3nLFbIp8CtP6Ge6fwk2IiZ2gTvQDcFec9YVcgvvieirI10J1tnl0v38csHmeF3MySkD1sTd4Ex3oI5S8DzM83btpPAHf3MYcffVXpsAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAWCAYAAABdTLWOAAACHklEQVR4Xu2VTchNURSGXyHkQyJSvvxGMqAoKQwkkUgooigDyUQplJGSATMGipQMZCImTDAgBqKUAQOSFAPKRBn6eV5r7+/sc74/7u2WdN96unfvs/Y+79nrrHWkrrr6fzURDsMlOJHGpUbACjgPF2ATjKxFhBbCWcU+u2Fc/XLrWgtvYC/MgKNwU9UNbPAYPIQ5MAWuKYyMTjHWdngFS6EHTsG94nrLWgwfYWcaT4e38F5h2FoGn2BVGltzFTEb0rhX8aB7+iKkyfCsGLekUXAZXsLUNOdT8432p+vWadVNWxPgEVxRteab4oGyPO8Tb0tO3Qe4AWNgmiKV3jxrLNxRf5NO5wPFSfnE/K42TVpXG+O/1jr4AbfhIhyB6/AYZqaYbGYwk3neZjpicjP8VH1zF8ItuKswYgM2MpTJ+en/kCa9sV94bzIcTmluHdmk0+m0Zh1XnLBPeqBCskqT8+C+hjHpknc7+BPOwezfq6SNCpPNlNik5/3bTGtWc75j6V4CX9V/o9KkK9yFNZhJV7gr3R2gIyYnwROFidxurDLdefwFFvVFRMty63JVW1vgu6o1Vu4MbesgvFY0Y6tZOJYLw61qVxpbq+EzrExjt66ncDIHqFrXtsYrGvJz2KdoQS9gVhmEtsE7OKCI8+fvkOo9dXmK8Sd0h6KHnimutyXfaIFi4zWqf49L+bTcEYz/DyQ/9HrYqio7XXX1T+kXnbt6onu7vvkAAAAASUVORK5CYII=>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAWCAYAAAC1zAClAAAEJElEQVR4Xu2YX6hVRRTGl6RgqIUZhpD4FyIMDFIzKOghI4lU1IewIFFUiB7yX1Eg3ogeigo1iPBFVMSHRHyJEEWvGgT1nIh/ECOKhHwQlBAkv58zs8/sOXvu3uecCx7ifPBx9qzZ+7tr1sysWXPNBhjg/4SJ4vjUOEAtHhIni2PSjoBnxX3io2nHALUgqFvFzf65hCfF0+K8xM6Lz4t7xG/F183NUhNME3eIe8VPxLnl7gJPiV+Ye2+N+HC5uzG61eE93uc7xvmKVY+xTn+ceEBcFRsJ4C5xKDZ6+wfiGXGWOEU8ZE4coZGwSDwhviTOF38Q/zM3u/HM4sh5c7uGlPSpue863T3d6tB/VNwgzhF3infFH31fQFP9Z8SfU8MF/xvjOfFv8cXINlu8Jr4W2VIwo8fEddZaAUzML+Itc7pgunhJfMu3AXnrV/G9yFaHXnToZ7U94ttMPIFjIXzobZ3ojxUPxwZEWFnpQfaZuUCyvQMmiefM5ea23OLB+3x309yqDfjYnNNbfBtn42ADNNkdw+ZWSBP0orPfyj6BheJt8aQ4wTrXLyaBgBJYBh4j2NPgIjRsbtaYvSqQMnaLx638LZMYrwjyW+o0YMB/mdslTdCLzgrxN3FJZEMHvWFz4+1Uv1hQYZW90eq7jxDEXHBTex3YLkfM5bOXvQ3nck5X2XPIvZ+z14GVxyL4yrdzOjl7EZeqvApC0NMgdhtcKg4cCYdh0KlyLud0FUZLJ4AD6qx4UZxh3ekXaYKO3/1vjCfEK9YexG6Ci8Pkr4PmchjgF1uVczmnqzBaOmCMuerosvi0t3WjXxvcXBBz9hxYpd+JX1t7XZhzLmfPIfd+zp7DKnOH9czEntPJ2WuDG3JkGsQQXJygchgJIbAfWaskY0W86p+pRqqcw+k/zF1smmA0dAgste1jvs04yb0c7J3qF8HlpPtTXNrqK8Cp/o+1tgh43NzpygkaQBDJT/HFgi221dqvg5vElf55mbkDjhtRQKhSYCgNmZipUTtFJzozo3YAFx7KqvhCwJipePC9qX5AUUWFYDHoFFxXmZk3Ixs3ruviC5GNU5XTdci3cWituVqR79kZgTesdXhOMXexGPJtUPU315vTpzhnR6XoRYcgkmMZU+onKxY01Q8oVjKB4EIQr8QYrLKr4kbxHXNXwHetvBrfF+9Y604dKg0GkjKtCxeY0+cgWW2ufv7cyruAMvFfcwdsLs93osM7wX+2dupjYHwja6IfUKq8iD4zk7sUMHM4BnkebXAik4cp6LlqVoGt9425KiaHJjq9oKn+UNwgYD/ZyP8veNCYJX5p1Wmhn0AsT6VGkvb31l4u9QM4iAhsfEXtV7xtrkIqgRy03TPOp/0A8uxy6z+/UnDIUc7NSDsAyXmbuDjtGKAW1PxUF/crhXuBzR4m64RTKQAAAABJRU5ErkJggg==>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAWCAYAAABdTLWOAAAB10lEQVR4Xu2VTyhFQRTGj6QISUSK/C3ZKSLFTlIi+VNiYSdZWrBVsiAUCwsWslAWlqxYkB1rNpJIimJnQ+L7Onfemzvvn7xL0vvq13tz7sztu+fMnBFJKaX/r3KwA4qceBpoBqtgDXSBdN8MVS1YAOtgGGT5HyevDLAJbkCJFafBKXAMKkEB2BY1wjVG/eAC1IMcMAsOrOeBaBC8SaTJBvAAWq1Ylei8Tm9cBi7BSGiGSD44s8ZJq0I0M3sSaXIuSiwXnIhmnpmmuRfRDzJinBkPRCzZEmgCW+I3lAn2nRjFch6JZooZ4151TVJ8XyDiXpoU/XLXpDETy6SJc92PmeRp3gB53tg1yV+O45ms8f7HNclyFYu+JBFsLaZ1cN2iaGsxck3yvVdOjLJNVoNDSWCSR56b/iusiB4SqkfCZTZyTbplNXLjXBfX5He1DG4dXsEHuBdt6twGuxLbJE84Tzo7wI+YjCY3k9Q0eAJ1VqwQnIueaopVeQftoRnhzhCoWHb2tTtQasV5MBgbsmJt4BG0eGPeQqdgxkyQ8LrANA6eRUtNWHaWO9t73geuwRgYFb3+JsS/nxu9ObxCB0R76Lz1/FfEbHV78H808aM6QK/oVZlSSn9On5ZDc73O+YY1AAAAAElFTkSuQmCC>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAWCAYAAAC1zAClAAAEN0lEQVR4Xu2YW8hVRRTHl6RgpIQoSqCoEYgoGCRooMLnDUVM8QKigQ9BgUikVl4fDoiIoiCKYiKIQvig4JP4oOinBYr14ENfBiGhRKLiixB4wcv/79rr7HXmzLT3dj90kPODP+fsNbPXmVkzs2bmiHTp8jYxCBoYGrsU8g40BOoXFhgfQ8eg98OCLoUwqBugddn3FkZCl6AJgZ0Vp0D7oUPQAtFRKsu70EroCLRD9HdCxkG7ReuwLt95E+r4Cfs5I7N5ivwPgE5AS72RTvZBDW/M7N9Dl6Gx0FDoR1HndFTEeOgGtFk0qMuh69BwV4cN+V101TAlbYfOS/XVU8fPe6Ir9oxomznBfoXmuDpl/U+EroaGP7JPzyfQPWias30I3YbmOVsMBvA30cBykNiBC9C/on7JKOhPaFX2TJi3foHWOlsRdfzYxLoieaDWQy+hjdlzFf/9oZPeQCdnpX0j4zJmID9wtsHQT6IjHS4bD30+FJ0Jxixok+TLiY31wSb0ydXRKzpDylDHD9/hu185G1cZ+86JRKr6bw4CA8rAbsnLWuxhcOmoV3TUOHoxOAOuidZhKqE4k8NczfwWNpoch+5K3rki6vhpQM9EVyf7xr6Gk6yq/0n2hc4YwIV52WssiKnghnYPZytnLQN8ENoKHYD6RHOWwcalGh2zp0jVT9kNm0CssxP6QTQlMAWskXxlpvyk7M24sCDMq8SCHgaxTHBtqb2AlmQ2NnQXdFN02ZmfWONSjY5Rx4+9y/x6VDRfkh7oEfSZqxPzk/LfTBMsuJN9ekZAt6Q9iFWC2wcNc3auDnaE+S22wRmpRseo48f6wkkw29ltYp0VTWlV/RcGNxXElN3DnMOR75XWZG/BZaNIqnEpe4pU/ZTdSA1MuGpTflL2wuByiZyW9iBacHli4Mkhhs36Xvnv4HJHjjWO5X9L/MIRo44fpoPw3TC4Vf03+8yd7h9ofl7WJHac4jLvE91BDV4oRmefxM564YnCpwXCnPZcWpekbTKU7do8ZfC0Ee7iRhU/Y9wzWQE9kdY9x6cF1i3r32j22YLlz3nGR6IjwwYY06H70KfOtlc0aA1n4+3mgeSj3U9aNzQyVPTG1sieSew3vxD1zwGzTcdTx49dduzCQHok39BIWf9Gcyaz07wQ+Jno4W7/F/QltFr0CuiPKeQb6Km03qk5i7dJ/u4B0cZMdnUIn1mH1+xlorOdg+Cv15zxj0VTTSrPV/HDOr79M0XbxuPY19n3DUGdMv6NlpMXo8+RSV0KOHJsGMXvVeDVcTE0V3QDiUE7y1mP9WNw6XGAmM9TlPGTosy7ZeqQhn9gwH6W4v8L/k/GQnsknhY6CcbyYmhkfjkl7X+jdQLciBhY/y9Vp/I5dDg0Mr98l8nnmk6AeXaRdF67QrjJnRM9ObXB5PwtNDUs6FIIz/w8D78+KbwCCp0lUpGLqQEAAAAASUVORK5CYII=>

[image13]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAWCAYAAABdTLWOAAAB+0lEQVR4Xu2VPShFYRjHH6EISUQG+SyZKCSFSSKRUMRgM1gMivUWBiYMBosMNkYTA9kYTBgkH0lRRgMl/v/7nNd5z3U/dK8r6fzrV+f9es7/vM/7PkfEl6//qWqwCNbAFCj2DgeVAprAClgF3SDVM0NlxxoBmd7h+DQAtkEtaAUn4BX0W3NocBocgHKQDzZFjaRb8xjrDNSBbDALdq3xuFQEDkG7qBGqCtyDC1Di9NWDB9DitKkKcAM6nTbncs3o5wyRPHBsteMSX/4MLkUNUzTLXXoHXU7fvKgh+xjkiH7guugammMsxjQysRJSrmiq+SKmx2hD1GQPyAA78tUk5++L7hR3jGc11CTFWD8ukyKml5fAmIlk0vTTzK+ZHAJvoheF6aIBGolmkueYz1FN8obxTDFILAolfOmgSsE5CIh7axmXZzaayUqwJzFM8sqzHHyHZVAWXOUVzyfP3qR4PyI0rZH6k55uY5CpZoqpNtGPTwNbEtkkbzhvOitA0kwyrUviLd7UHGh0nmfAE6hxh6UAnIreaqpX9Cyz5hqZypCQaDAAXsCtxR24Fi3YFC8G+4adNsW/0yNodtr8Cx2JxjMy6xKSKeasiaGY+mfEnb4C42BM9Pc3Ie7xoBqcOawMg6IxFqzxXxF3iwWe8DmcskAH6BP3t+rL15/SB8HDdzenoU74AAAAAElFTkSuQmCC>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAWCAYAAAC1zAClAAAD50lEQVR4Xu2YW6hNQRjHvxOKkMsRKXIOIlEUQiEPiOSSI4SiFJIHcisvTskDIZdCXlxKFK8nD8QRRTy7lCRyicILkhLfz8zsPWv2Wmuv0TnZaf/r31rzzWV985/bN0ukjjr+J/RSdg+NdVRFF2U/ZUOY4TBBeVbZJ8yooyoQdbtym31PYIjylnJsmGHRQ7lO2Tew54E6q5RnlAeVo5PZJWAnn3KUp97fghm0XNkU2POAGFOUx5UnlQvEtBOimp/dlBeULb6Rxo8qW32jor9yhfKc8rPypXKwXyAHzP7ryn1ithpWxWMJPmzT2MmnHOWpF7N66ORC5THlG+VX5cREiWzQ913K28pmZaPyohgBEcuhqJ/jlPdCw1P79IG4i5WTlJclTtzdyodi9iGH1conykE2PVT5zNodKE+9LZ6tGhB3vnKWcq/EiUu598rpnm24mL7Os+kYP7sqL/kGhGiT/IPsvBQX132YOj4mK78oF9k0zoZCMJOYOe1iZkgs6EvYZh72S2W/eivviDl/8CfWz9IgICjC7innpSJG3DHKj1IpLs7hJB0C7HGh04B678TMoFjEiOv6HvYLsdqlvPJi/RzvXmiUxtmz8hAjrhMxS1xn55nldJq9CGLEdSKG/QrtWf5k2Uttpe05aYgRl4H6Jfniug6kOZfldBHEiOsmVtgvX9yR9j2tzSw/S9sEGa/sMw8x4nK4VBO3p/KGTYffznK6CGLE5WB9LpX98sUdIfF+dqq4voh59iznsuxFECNuuPyz7Fn+ZNk7VVw2eDb6LHHd4cnBluYc9V6LudjEIkZcwqarUtkvJy4RA5FDrJ8lcRHirZilnIc8cQm2h9kncM61STK8m638YZ+AkOynlwbuBPfrclsa6KXzkCcu7TRJsh3KE9kQ4TgMUD4SEyWAon46lGJ719DGcl4qskYJHBazx7Z6tjViVkSzTTeIudXcl/KtplH5QJL1OED4zkrPtl5M+wTnzLY8INY3MTF1iLR20r43Q/lBOc2mi/rpUNKIThMsu1HywWxhaRD44xRkBGl0k1duq5gZ2eLZmMWnxPyvWCJGWAaR66MPbn8vxFxBl4mJLQ9I8upJ9PFdzOGTtnI4HLlBfpKyn5AVecQr59rhW/TbYakYHzYo14q55m4OyhTx0yEReaE+I+NfVTsCODdKjDMzJd0RgDhzxQwCV800sPROSPnq3NFgdiI+5D0NRfwErX6Cxu5K+S5di2B7OSTVt4V/DbS8GRrZtK9I5W+0WgAHEcLOCTNqEJw1p0MjS3inpb/X1ALYZ/k7V2t+heCQuyYmcqoAe+IO5dQwo46qcPHwn0jhN6GvBb+jidhoAAAAAElFTkSuQmCC>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAAAWCAYAAABwvpo0AAACH0lEQVR4Xu2WvytGURjHH4MiSjJIkR+JDEphMZikDKQYhL9ABhNlUjJQFouyGfwJJsIoJgqDQaRksLEo8f3e857buee9z3kNcqn7qW9v7/Pce97n+5zz3vuI5OTk5BgqoWloB9qAOpPpzGmBpvygA+tl3ayfPujHR/VYAx1Aq1A11ANdQxP2gozoguagI+gD2k2mY1gn62XdrJ8+6Ie+LJrHiCXoHKq1ATAD3UD1Tuy3YQPGoQHoUdIb0ATdiqnXQh/0M+/ENI/xxf7i/dArNObFs6ABupfiGglNvEG9TqwM2oNOxOx2yGPU5RcpTnJBLrzmxbMg1IAtKW4A4bVPUJuEPcZG05Jp8SwINYAxrQE2rnmJ7hmFPiU9mXZTFmgN4PE+kdINCHmUEdGTf70BVdChlG5AyKNqVItngdYA4hrV4pqX6B4+JPiwSEvypmUvngWhBvAhrTWAr85GCXuM/0f7UIWTHILeC59plEPNhU8NzhB1ftDhO2uQUAP4muaQ5NZJH/RjPYU8RsxCD1Br4XuZmInpVJLTlMummP/Vihe3cMx8FrMLdl2fUmtYbAP4bmdtLmzwmSTXaBfzu+7orHmM4A5sQ8diJi8mrsSMixoLYk7IhJ8owKN3IeYhpTXRrqENW9whGuEOs1EUh7NLqNu5rg+6gxahSTFDz7okT5bmMYYd6RCzwKCUPpZ/Db4RhsWY43icxn/3mJOT88N8AVexkrRLRtwbAAAAAElFTkSuQmCC>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHIAAAAbCAYAAACgJtvvAAAE9ElEQVR4Xu2ZaahuUxjH/7rIPGRKZpEMGTKPnWQsU4aM+YIMyXQNdYkrKXNIpshQplwhUyHeUITwgZLoRl2SKEL5xPPzrHXPPs/Z0zuc99xz7/7Vv/2etfZ7zt7rWev/PGsdqaOjo6Ojnp1M9ybxebllLdNqsTEwz7S+aaXYsYyzh+ky+fMfaPrBdNCUO5YTdjc9Zlo3dgQI4HzT5enzXOEa03emTUwrmxaZHplyRwXHmv5toS9NF5lW96/NCpub3jXtHDsqWMX0pOmk2DEGzjG9b/rY9LCpZ/rW9KrpT9MS0+2mTdP9mQ1N+8gnH67zmtxiG+FmftmRpr/lQXs+tWWdbfor9b2t5tUwE/Bid5sWhvbMjqZPTAeH9l1MH5q2CO3jgLG7KX2+wLRn+kxquMu0l9xdCFwZ3M/qxG5bw5dysJ4IfcCsyKvz/NA3DgjI1+laBs/0qzygRbCnZ1Q9AZpgVWNzxYm9gdrZdVUg4VTTYfLfTVBjzmexPG3aP7Q30hRIvDsHsqx/puHvYzPxhYFBfUq+IilwImequq+KdeQO8IXpUbk93mg62TQhnyBN1AWSlIZ49ls01WIJIrbLpOTvbF/oa6SfQLby7BGSc8WC0J5XCzmT1YpNMSBYV5HdTN+b9g7tVTCA75gOVbuVV0VdIE8wHS2fXHeY1kztvNMN8pXI97Hd81JfK+oCyS9/MfX9o+l5aKbhhQgEM7jIrqYHTW/Kn40rK+e44k2a/P6Job0MJsELqs5b/VAVSMaTdnLknfKgZiiS8oLJavPcSykGcrF8QLI+T+2/m47RcLN0EHi2n1W9n6rKjxmC05O7ShNHma6NjQNSDCTbIBbDS6bf5IUlk3CH1D8yioH8RW5TOZBsOyZUnp/GAc/GxrhoTZmm/Ag5kDeH9jIula+QYnETtd7Su+uJKxIrvd+0kelW09apb6QUA9nT9Dwzm9QFkn3XV6rP2zmQbTbWeeUUHSnqKrWb1DGQPP/hpivk1fdtcpsdKXM1kBQw2BSVaRX9WCuFRcyxg1IWSKpQnIEcTD48JfWPjEECia0dIt+nPWu6Tj7D9pWvkHvk+7dckfHg5AgOGGh/S37qcoDpOXmZz+lNZFvTj3JripAf/5BXpnC66fjJ7v/BcrFeVkITVMCs3FGcYJUFEnjH++T7UYqdURRWpSc7nIRsp+aNLzbxnvy+CdM3pi3lSTzb2MXyh4Wcz9joEnAGf4kmq7IFKrfIbJ9lBxHcn/PjVqYHNP3kiYHjhIQNeBM8I9Z5vYa3vapAAiuRic0zv5yuQ1F31tpT/cokWFUFBIN5hDypF7czfM4Wx4syEfIqpD1ufYDBpfgqCzKV7E/yFb1I5Suae5gIm8WOCuaZLpGf67LVapMPIwSJaj+ftXJlr3u1aVX5JMGxOAt+Re44ONmswKCzioow6PPle7Ft5BOlLpC9dIWqQMJp8sEoq0wZ6I3lAShjodz+25zGFOG5eJeP5Dk663ENFtxlFuzidU3mE/IL9sGxVrYRihCCw5VcOWggse8P5Pu8fuB7nNKM+xBjTkEAsU6s41z56lxDnqewQuyFHPGZ3IIvlNvgp6YzTA/JCyyu/Ez74vS9Mqgm+c9MP4XIWfKcPWy+WyHAZmIu5efYNiy5EEF8boKC7Q2NoJDoGD2srCtN+8WOwNpyFygrfjo6Ojo6OjpWEP4D6IETZJySsL8AAAAASUVORK5CYII=>

[image17]: <data:image/png;base64,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>

[image18]: <data:image/png;base64,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>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGcAAAAaCAYAAACq/ULmAAAEaUlEQVR4Xu2ZechlYxzHv0LR2I0tuyxpSJbUWBrZomyDZPuLLEkURfkDJUmIhJBMlLKGDCaJN/whZIvIUkjEH0QIZfl+5neeOec+7zn33HPnznvfO91vfXrn3ufec8/57c8z0lRTTTXVVGPU+mbT/M0J0EZmg/zNrlrHbGm2K/7yGi1QGGacwin3mYPzhQnQzubJ4u9QWmK+MP+Z780/5kdzjfnGnFh+dM61nrnbXJwvTJAON89oiMzf3/xsnjebFO+ta5aa3xUOG6dzjjEzGuLB5pGoQneZq/OFNt2pcMCp+YJ1rsbrnA3NCnNpvjCBWmw+MbvmC02in7yscMAyze4t25uvND7nHGg+N3vnCxOozc3b5px8oUmkG07BOfCeucrso5gw0pCw2tPGkLrIvG42zhcq4t6OMKeYHXuXRipKPUFyuiJoeN1VD5hHVA5braKmMwAkB1V5zuyy6pNzr4cKmnSQ+dBcYs40byieZ9Si3y03tyucw4ByhzoYuRA9py3YesQPUNObHPSZ2sfAsxRT3aC8Y3Zf+c1msT+YMTdm7yelfpTKBDX9L0W2jVrYh3GYyRFHvakYoLpWFNrD14rtSifxBR6Mke839TqISaNrlKyuknOaJhzulwd9yeynqOlHKfroqEX2fqfIGqL+ELUHbJ1wDluV3fKFOmFwfojGn2sPRQPDOTMKY82l2pxD5lB2UwD9rZgu14TYY1WD9UHF73cVzvlVEUytSgZoKgWM14M4h/QmkgdlG82eDHO1OQdhoBPMwwrnfKm49qhFEGNQSizZik2O7/nEYOpU1pIBXlP9Jo+LcSPL1L+skeKk/KCcbLZY+c1mUd+p80w4uY42f5rLKu/Rez42C4vXOP8887RiQ32ducdsVawnbVZQp63Nu+ZFleWSkoSBuQd0gHlWpbOwI8FeF8zc48ABlJyDA94yh6qMaG7sFcXpwbjOtNgg1zXeK8wvivtFjLX3mhtUBtHZCkPuZN43JykMk4yK9jI/mG9VvzkkW34y16q8LpnKVMgWAxtR8k4zjynug+tXnVkVx2F1z1MrnPOqucXcZv5Qb23lvG3Jqk/PvTDoRyqzIYlMxUAY5H5FgDHaJoOQdfRMhLEYGohoDFrdn+xgPjD/qn6jTaAyDBGk/M4TCnvtWayT/dsqKkuaGnFA3YSZKkG/Mj1LTB/VGybFqYnVk+lxiWj+1ByWL6jcILf1L4xRZ6yqLlD/HkIQY5O6UsUwxd6FLCUjGFLqrsWzcHyzOF+YVOEAShXR2yVQMOKj5lhFGWGw4fv0qDwLiehbVV/WBhGnBcsVQU4msgeqG5WZJMn0foE0ceKBKSWL8oU+IqOeUvQK9m30LjKIfVCu48zN6ub8qiiXj5vLFWWPs8q833A/L2h8vXuNiofCAHUTZZOI0GSkpv8wJGvOULfr5tpXcabHJvgmze4pOP16c2Xx77VSRyqicz4pjdoME00BRGm9UGuxY+arMDiOoS+er+FODaaaaqqR6X8qNtSO182EuwAAAABJRU5ErkJggg==>

[image20]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHoAAAAaCAYAAAB4rUi+AAADzUlEQVR4Xu2ZW8gNURTH1xeK3HInd7nkwSXXUMKHUu48CCk8kAfKAyXxICm3hJCSKPeEECG+4kEpSaGUQsqTB0WhxP/fmu3smTPnzJw9c44T+1f/zjd7Lntmr73XWnt9Ih6Px+PxeOqdVtBS6Di0GxoSPu2pI/pBS6KNaWgP3YV2QG2gkdBLaJF9keevMhRaB92HfkKnwqfTsRl6AnWw2pZBr6BuVltW2kLNoo3/Oa2hFtHGGGjo+dBE6IM4GJrGpZGjN46FvkBzI+2V0gCNhx5A+0RDhEdD4yXoLNQlcq4cPaB3UmyvRDhTPknxjaOhr9DOSHtauHLnQY+hrVCn8OlUtISmiM7k3uFTuVKrfuxJf1jc+nI2tDFo9MZS7UnQDTFReAptEHVNLoyBnovGJT7vETQjdEU+1KIfTvpp0ENoj7hNeoOzoedAv6T4xkoNTZe8CnoW/GZx0bz3tmieQCZA36E1f67Ih2r3E/Vq7cKnnXA29CzJZmiuWK5crmCuiDSJRRLmY+5AI0TziEZx9w6lqFY/eXm1OJwNXcqgpdqjrIReQwslv4yaK+266ASkfkDLQ1fkQ7X6mQq9hdZKNs8Wh7OhB0AfpfhGY+gtkfY47FW9QvL5OD5jNnRa1ABvJN+tnqFa/direpPk47aJs6FZIGmCbopmn4bpoh/O37SYOM1ii6vLYn/foPVWG2PoC6hzcMxBZD9XoAXQduiIhLcp9C5dJfxNNmn6GQVdEw1vhIUlxm+OWVpMnOYWNmsiRpwNTeiu3kP9g+MG0SoZkwh+XKVkSUI2Qp+hScExn3VM9H34XoSlWnqiPqLJH/f6XIn2pFwt6o7PQc2tdkNSP5wkdL2sDl4IzvP5t8RtAvOZ9taKBnPBGPqMFMYjNVwhR0VfgntJfixnNkuhWeDgVLqt6Cu6xeHgsu7eBB2QwuDSaIOCvznwTKQ4GflsO0fgboIrlhMgblCT+ukIdYdOSiErZxhzrSsYaJzhohPmhBQWVxL8VlbEWP40OQULWtwaDrOuS4QvMBhaDE2WfLJng/m4/aIDmASvp+EYK8u9B0u35QaebvuQlI65Sf30FJ2k9B58FhM348bzgEbmP5AGRk94ND6eh2aK5hXM9mkwxloTWw0cyL0S77rTwIT0hmiNvpdoKKLRPTWAK/AytA26Ch0UXdmN9kWibpxGzlLlYki4KJpYsi59T9zis8cRulkz4PyNc7uMy0wIK05YLBj7WI9mIWWX6ITy/GMw6+YemEndONGV7bID8dQ59AQ0Mncg3KrlUQTyeDwejyctvwFkmr13OrUvrwAAAABJRU5ErkJggg==>

[image21]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAaCAYAAAD1wA/qAAACUElEQVR4Xu2XQUiVQRSFj1iQ1KYMLRA0LSoMEgJTs0VLg1YJBgVBZQq1iIhctEnd5CoScRFEhuAiFIPARQqKbaJFgRCCIBhEEkGB6NLqHO4d/vHxdPn8X74DH+95Z/7HPf/MvTMCBRVU0I7RGbJG/mZhhhz2z8yxrz6WGu0m5aSSTCBJdJgcJMWklNwhq+QizECZj6VSR8l3mJF1ctnjteQHeUiKPJZ6tZE/MDML5DSZIu/Ivmhe6qWt9hzJFpOpRVIVzckbqV60GsHMg43D+SUVddhiP2F1kncqIW+RGBGb1cgJMg9r0dnGt03qSupOv8gFMovEzGZdS2fRG6TMyHnyG0nrrfe/ZUQH51mPx0qdkVDk6lrqXlJYobAqH2EHZKzYiLblI/KEvCTnfE4d7HfFTVgXfObo+yHylAyRXrLX56n13yfjpBVbaA/spK4gL8gXcgrJ29XpXQMzEMwM+jMyJKOxEZ074fzRjUGJHIdJvztHqmHPKeFjsOeUqHZDiN+FvUzFB8h10oMtdAlJgjFdPq6Eda/KHBczsCQyt5bMnyTXyAcfl3aRUXIVZlLJSs3kG2mHvfU+8srH9Kkcc6LYSCV5DzNxwOPBiHQFdqfTZ4PHWsgSsl9Ct82IVjK8zf1kktwgjR7TSnwmr2H1FGLaumGO4jIn5cxIFRkhK6Qf1rI/kU5Ykxgj09i4Ko9h2yuWTGjebdINq7EOsgw7w1T4OVe4+sfXfBWxOpGkZI9EY0Gao1VM7b8HUhNspVQXt5D9YM0LaTXuOWFlCvpv9Q+W2ohsKfHYiAAAAABJRU5ErkJggg==>

[image22]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAAFEklEQVR4Xu3dQahtVRkH8BUZVCoZSiZmZg5SCBOURDFwYIKDEiLITGgQlQkONNTpcxBEiWgkpAY+BxlZoSI2KKE7ykpolBRlSCI1kkBsYJC1/qy9dN119309vefau/j7wcfZe+179z77nMH986213ysFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADYhLfV+so8+H/2jVqfmQcXd84DB8z5td4zDy4+XnY/9ka9s9Zpy+vba524/TAAcBB8tNY/ar1vPlD9Z6X+Xes3pf3x3y93lBYk15xcWrDZpPkee/2+1ruGn9uEX84Dk+/Vesc8+AYdX9p9vLS83lf+9/UBgGPQY7W+UOu3pYWh2adK+2PfpVPzeK1XhrFNSUj77vLa9evltftVrauH/U24oGy/z/jOytheJBynRl+tde6wn/vK/e3mhlp/rPVcrb/U+sj2w6/KOV8o2ztq+Y63hn0A4ABIMLq2tC5Sgkm2Z3NgiwdWxjbh9Fp/msY+UOv5aSxTpj+ZxvZqLbDdujK2FznfGDzz+f+g1nuHsQ/XembYH+Wz+HzZ3t38YVnvRl5Z2nu/aBjL9beGfQDgALht2N4q6+FkDmzpwv2u1t+GsU2ZA8UXaz1b6+XSul1nL+MJV3OI26s5sGVa8uHSrr0JWUf212H/vFo/L+2a9w7jkUC8FsI+Nw8sEtrmKe2E8HRPc/5eXy77O5UNAOyD64btLHb/ddm52L8HtoSK1JdqXbgcO6fWH2qdsOzvVYJKapRglo7aaA4/m9AD2/2l3ef1tS4bf2CPcv5MY47SXXtqGosE17HrFum89RB3Zmnv9evL/uW1bly2Z5eVtiawh7asVwQADoizys6uTNZPbU1jc4dtliCyn4HtX6UFktF+BrZN3ctsLbA9XVrncJbAduo0lt/vLi3tvX5/ODaG7zil1ieG/XQM88DIkb5LAOAYckatR+bBRf6gj09Gvp7Alk7O10oLB98srVP1/uU1a6oO1Tq8jP2otMBxe3nteumkPbFsR9Z7ZT9PO36rtDVckW7TblOynz1CXTX83OxoAtvh0rpi6UYmaN1V2nuLfJ6Hav2i1iWl3V9/v7H2nl+s9bHS1qWN8jn083bHlZ0PLHR3l53H8r3ND4Zs1frnNAYAHKMyjdmnyNYqa5/6gwhjzd2vGANbukIJNOkQRZ4+TXhLtyeBJeMJTj8rLVDM58u5/jzsZwowC/ATfsZ/6iLn3Rr292q+z61tR5ubSgtNXULbFeW1e+iv6f71oDbeX+7l/mE//l52BrtMheZpzjWZ9pz/mZF0H8ff7/L55inSnKvfV0LmHAQBgLeAHtgSqNLpSSjrgS3Trp9ettNJGqf11gJbX0c3OmmpURbZH5rG9lvuqa8hy+tPS7u/tcCWGse6TDmPa9PSQZynpS8uLVCvyXXzwEfW1+UaCWv5LNbk++jhLNv9PQEAbzEfqvVgaZ2bD9b69lJZm9UdHrYzXZhO1SdrPVnaE6BzGEv4y/HdJLTcsry+mfJ05UOlPbmajmG6ZXkAIwEqU5jpll1T656lsp37m/14HphkCvjMeRAAYFPG8PXu0kJO77B1R/NfLz1adg8tWUh/NOfYD+lU9WsnWB5pvdtubi67h82cf35KFwBg32TK87Z5EAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADgSP4LtHnab1npr1YAAAAASUVORK5CYII=>

[image23]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAZCAYAAAA4/K6pAAABFUlEQVR4Xu3SsUtCURTH8RMpFCphRuAWEkLUEEQ6NLg4NDU09Ac0Njloiy5hEA0R2BCFi/oXNBsKbW3+Ay0t/Rn2Pd6XHa+ibTb4g8/wzrm8e+95T2SR/5dlnKGHz8AHXpDF0u/S8ayhgUuser0EHnCDsNcbRIu3yPsNE929FBg7yTGKkxpe9GR17NpiCPdI2SJZwaa4udicoGALcdQQMzWdxxv6eBS3yU92cGeeJSlueFFT09N8iXvBKyKmp+ur5nnQ1AlvmJrO4hxtHJm65hDXXk3K4gb5l0xcuy3uGnr3adHpt2T0usOcool1vxFEh9fBvt+wyeEdFeyJG1gGT+hia7hySvS7H+AKz7hAWmb/ZIvMLd/bhiFk839T1wAAAABJRU5ErkJggg==>

[image24]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIMAAAAaCAYAAACU9O/tAAAE10lEQVR4Xu2ZW8gVVRTH/5FJapqpZJHkZ1gSiUJlIpmCJSZdHrKbFT4IXnoINFGxIvwiwSDES1SEYApaRGmRF1BRQYkgkQok8fJQZBG+BUEPXVw/1wwz7m++c2bOxfOd4/zhz5yz9zmzZ6/132utvUcqUaJEiRIlShTEtcabjNeEHX0c1xlvDBtL1A4Musb4VNjRBuDZ16vOZ3/C+H8O/mmcGP2nU7HMuE7tFxViDDfuNT4QduRFLIZ/5cq603ir8XbjzqgPfiRXX6fiHuN3xjFhR5vhUeN+4w1hRx4ghv+MzwXtfKcdIZw2jr68u6NAJHgvYrtGhRjUDd8Ynw878uBF+YqgaIrRZTynJGLMSfV1Im6TC/6RsKNNQd3zubFf2FENi40blKwIUsEWXT3pASACxD8q7EiBfDzLOCT6PkjNqaEaMc5s48+qPJ9ceEmJEDo9PcRYaTyi3vMszvlLbhNEM9m4yvhk+kcNQKPGuc/4q3FS2FEEY42/qe+mB57vuPGXApx76Z+VsVW9h1Vy8A65Y1hp1Fg/GleosfVFI8dhA0Bk4B41gVTwmZKo8IES4ww1dhvvir53GhADrAac8ozxNTU3ddY7TiwG6sGakE4PP+nyfMPNv5eHn05EHjHgoHnyswhOKZuFRowTi+HVsCMPwvQQ5qipxj/UejFgnJvlk83L3uqANKqJgXGXGF9W8ZBdBI0ap+Y0USk9AHLZQePvxjuiNirdt4zbjF8ZJxgHGF83rpXvRh6Mftsl37+zK3lWfpD1ofxwa5Vxn3wl5Jk8lfVjxqcL8O5L/6wMtmLMkfuHwEGsUsJ2/Ixcu5UsjinyfE9Y53zmi6gtDVIt7A3Vxhlm3CS3Oz6jj7OErPnhJxY3u4pCSKcHCi6OMlHWeONC49moD6XRjtMRAP+73rhLLgK2P+w+uI6UG3ecHFS1VLdEGLBZLgKERjqiKMya1JXCIuNJ44igHYNTwP1jPBR9xgEsAuaNLZjv43JnfmpcavzEuFEJsAORFRuMSbXHqDbOQPkRwL3yAyV2eDzrUWVvO7E3u5FCNmUl4LRYDJXIzXEyg2O4OEqkgUF4AITyrZKVw5WaAzEBtnKsIkBbq+sRxj6jnsZ7SH4Gg9NnGC/IbYHNbol+g2PoxznH5PciArBQYiD4H+Qnulmhu9o4RGoiKembKM53HI5w0oeFMSgcjyhfiqwLTJYtDxNMA6OgVIRASPtSlcUAQV8QAxEK8YbVN4slXc3j4OHKTmk8/wFlOyfGAmWH7jzj8HmLkmckmhFhQyAUItPqoL0poIA7IX8hAlDzdLlzt0ZtGATDzJfnzr4uBoCIeePHfIrgFXkexznb5U572Dgt/SO5k95VdprIA1b51/KIwBiMFYoXsBlA2FyvCHggQhg1xTvyXHa/XCTkNnIeRdRheVjk89/yPPqC8VREPtPG63EKsC61Dhh7t3Fm2FEFb8uL5o+Ne+SiQCDh+QCLB1tlRZU84H/L5W+WVxvPq2e9wG+6VdtBVV1gMCJAei/MZ8JbrfvjVoNUR3HMNS+ww+DoigCydiREBXZSpKNaQU1C9OQe1BVEsbAmoPbgJLWecUqkQBHJ6uofdrQY78u36Cw2ikh2fWnw5pUtcimEqwC8CnjT+IZ6Fu8lSpQo0QRcBMAmA61EpQA5AAAAAElFTkSuQmCC>

[image25]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJEAAAAaCAYAAAC3r744AAAER0lEQVR4Xu2ZW8hOWRjHHyEmxmlEIsPkkAtGCZHcUGgcMkMSIodmboZQlCjHDFeOMxMzUnKaGXdOIQpFceNmlCu5cWWUcuM0nt/37OVbe7/v9+69v3d7v03rV//e/a137/2tvdd/Pc+z1isSCAQCgUAgEAg0ju6qu6r/Pf2nehJ9ur+/dRc0kG6qNaojqi2qfvGvA2VhjOqF6lfVV157R7HBe6v6wWtvFF+rHqhWqTqrZqgeqcb5JwXKwUbVPlU7rw0DbVW9U21IfFcNBhkVRQfVH6p/omPHLtVl1RdeW6CNYeB/Vw322jAMxsFAv4kZKo1vVFdVeyQezVoL93sqZnCf71UvxaJnbrqopkhzTuTBRkvcpWWBQRimmqRqH7URmvt/OKM89FAtlvh7JHWRwkhlWQzk4LlHqS6p/pS4MfMyVczESRPNEqvRFiXaUxkpVuRx8XPVTNUS1Wr/pJLAYDAbXYF6UjVCdVQ1wDuvrEwUe8fXxAru1jJc9XckjvPizNKSiZLtNWFQDosZhyiEQ69I/lmSpJdYbsWcWcXqII0JYn0j8gxVrRW7tp5icIjqvlT2p5YWNl2ZD/qIgShe6X8REI2ISjdV4yW9tnJgkmpmaZWJkjBT9oult7JD8bdXzPhlB9NgnqSBSMFFGIoAQDDIaqZ1Ut0sdZuIwWBQPoXKHJNjdkxfdojK18WiUDJibhar7YqAgptC/bZqUPyrCloyS0vtqeDaeaptUl8K8+GePBQzJKsoQrPAoFADUfgXAcV5H6nsTy11bboyHeoe6p9qe0F9xWqa3on2vNCfQ6obki0KAcZ9LZVmcSZilZYZ/uF81XppXukAG1BzouMJqlOqTaoFqnNRWy0wI6s9zJlVvIA0MBBLZuoYBwZgI+9L1TTVRWk2GMX2cqm9yiSqfSeV/aklivk0/M3EZRIfXLfMP5hozwP1EJPpvNiqLc99SKOPVQcS7T+qnkm25/sAs+OV6p5YJOIFcWO26RkctuIpujHYGbFC9nR0TqNxs5q0wKpsRSSK4p/EHpz+Y/atdknTS2FTrdE4k1TbTCQC/aJ6o5rutWeB+xSxzOc+O8TG2a0SMf1fYuNba9LFYDafEJvdDMBDsVDGp3MiRR81Um+xXMsmFGmnyN3TLPDQ1A9Ewk7RMX1FHPMCMP1AsUhEuOYazJZ7z6MAMIfrX0viPWOoLPAsRGpS1iGxFFYvmId3dVbsJ49jYmOca6skuZXOQGAWP605MA87pj2TXzQIXiLpyp/RmDlZm/j95FluSdv8sFk0DPJuKWa32oex5p0RwfmsNvZ187Nqu1haYFYziNQ6k/2TSgSFoevnWLFVUVsZPxCxUyx/H1ddEDMTxipqFVc0pF/6uVJ1R9qmHgok8NMIxinzJqSLPtQZhH2KxNmxMwKBFPgN8F+xGohVJ8vnskbMQEnBMEvFUvBc+UhFYiAQCAQCgc+K96340Zk+Pk/UAAAAAElFTkSuQmCC>

[image26]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIcAAAAaCAYAAACdH0+XAAAFVklEQVR4Xu2Za6htUxTH/0J55hkJOR7J4+YZuiHJI+WRcIvwTR51lUfer1MUKfIWCZe8SiGREAeF8gEfPFJyr0QIJT5c7/E7Y832POOsvfZaZ+19dmdbv/p39p5jrbPXnHPMMcacS+ro6Ojo6OhYBDYzrR8blxibmDaIjR3tON50m5a+c+xkerb4uyCuMP1bot9NB2bXbWdaE67hO+2TxP6mN03bFN+3Nr2nuf3+Tj42O5g+DLYvTLvP3imdFWwvmDYubHU50vSj5v6fn01ny5/tLdPfme0309Pq/c7hpuflkbAxhB4m+DL1fuDxoi1fOevKB+w60+emvYvvtE8KG8on8PRoUG8RrYwG42q57ZRoMPYxvWGaCu1Necj0j+noaJC3YXvEtE6w8f0e+fMvmJ1N38g7yV++R/C+903ToX1SOM70sWnbaDDOlI9N2SAn5+CaHCbmWtMxob0pW5g+MK02bT/XNEty3Pj7ieWmz1Q+p7VIHpaiR9kgMHjfm5ZFwwRA/1l5d0VDwYnyccERcqZMX6p8zIiut6p97bKn6Sd5/bBesPGdduxcV0Zyrn7OUws8bK28o3havoJ4iKcKxQecBMjfn6g8NUAK3auyNhzqJtMdmu8cjNHNcgdpS1XUIpKslk8+TtAP0tITmp92akPOfUW96JHnXqIFUYPoMYlQYH5d/C2Ddor03Dlou0XuUIxXbqMQvEotJiODaPaX6WR5LZhrhdxp+0W8BI71jmnTaGgCHeXH6CyOgsPQQVbHjLyAHSdbyp+LiawriuhBkDbYhewSDQXJOV6X7wRIFXeadstsyTkYo/tNOxbf25BSAv//MdODQV+put5I0L81arm7TEUnP0iKYQVQyDDIZVV8P441Xan2+XaxGDR4aSs/I598isyLClt0HCbqvMLWlrb1RmKQ89eG7VpKLdQYF2t+DTKIC+VbYiLPUqCuc7CKiRYPq3cWkiZwxrSr6V4NL8KmeuOSaFD9egPo36+mfaOhKUSKtK3lgIVVMZ1fMEZIcVtpfu6t0uazd1YzyDlSeOeaG+S5PpEch5x+vdpvXXMoJP80HRYN8jZsg+oNGNS/2jAB+bb2F/XfvnIthRKFGQ+J9pLf/4A8zO4nz49U7zfKj6bJx9xLjUOEoZI+VIMhTR1lOq2BDpm9sxoG+lv1X1lEghl5PcYJZB4Rk3OkSFsnlXINkafq2rbnGzlcw5a7SfTvS8qj/DgTzUSWwcAwsVTB5EDCHwN5kOnF4jM7nBPkA5EKKT6fJC+y+EyoflVDevgFQGrAOdiyloGTU1OslddhOclx4iuHKlggjO10aM9Jc1BWb/BC7SXVTxWcz3D9UF7EpXMNBmN5sOVQwL4rf8fAriCFLTrGmT4Dx2DSfqrpbXlaSMUUjsXq5j0EhXDdwR02aYKrCslV8jAfJyrdS1Tst4giFLNEIRwu1ic4KI6aIjf6wXSGfOxeM/2R2fjMOG7EzSWksS47J1kweBkPU9Vh3q1wDZP7nOkjebjMnQM4DPrUdLBpD3nqYWCG+sAtmVb5Kk3QJw7LyjhAvs1uAv/rbjV/GdcUakg2FFWLfCQQEdiy4kDoPvkg5s5BdMHbLy3uOb+wr9TcE1feiE4Vn8cBqQ3nXhYNI4LJujw2jgAW7jOqrm9GAs5BrXCB6Vx5LiUqPCl/tUyquUZe1D4qrzF4ucV9FHUUsBwYnSPfMi96BwI48O2qjpbDgEXDdngYx+tVENVflkfsRYdBJLWQgmLurEube4cNzkmopz4aJRTAR8TGIcPcTMsdftTO/r+BGoDisvVp4pjhlJpo3jlGR0dHR8e4+Q934DUDXtaUlQAAAABJRU5ErkJggg==>

[image27]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAA/CAYAAABdEJRVAAAE5klEQVR4Xu3dW6hmYxgH8EdGOR+LFM2MSKSQU04XTiMXKCQhc0EyQlyghCZSXKgxlJyaXCA5Jzle7LgghAs17mRyiAtKUaPE88y71nzft8xm7z1jz2Z+v/q313rX+r6921dP77veZ0UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMHe3Zv4Yyy/d+P6Zr8bG6xwAgK1kaebrLnXc2yOzcuwcAICt6MRoM2lru/NFmWe6nwAALAA7xWj5sxyR+X50GQCAheCDaAXbqZl1mUsmL09YltlhOAgAwL/rumgFWy2F1tLofpOXJ1wfbVYOAIB5tF3moWhFWy2JDq/dm1mdOTzafbt0Y6syD2bOylyQeSpzcvsYAABbWm0yWD8cjLZj9NPMHd35MZldM8dnFkdbRq3PVrF2ebTlVQCAORn2Het7jA3HqiDZVu0zHEjbRyvEXsrsG6OCrZZFX8nslTk92v8XAGCznRutKHtybKyKj6lojWO35WJtOlXUrshcHW1J9Olos20/ZV7NfBHt/1pLpldlbmofAwCYGwXb7NUzbDtG+z/9k5ncAwDwt/qC7d3MRV1qua9miRRsAAALwExn2I6N9szW/d05AADzZKYF23OZU6IVbrNx2nBgKxhuovgvBABgo5kWbN9Em2G7OfNmtIfr6/idzJIY9SK7M1o/sjMz12be6q5fmbkms2fm+cxR0X7n8mjfdUjmjcwZMb3FMVq2Heb8zN6jWwEA/h+qMLsiWsFWM2i1+7FaVhyceT/za+bsaK9dejla8VZtLj7J3JXZLfNeNDWTVt9XzWJLNY4tVRCWelC/b3PR9yWrew+KVug9nDku2u8FAGAO+oKtirI6Lv1MXOmvHZ25J9psWqmCrXqVlb5gm+p+1rV+F2Ud13d81p0DADAL1cLih8zr0fqN/Zg5p7t2Y+ayzJpohdrj0V6U3s+wvZg5oDuu93JenPk52tsAajbttmjfUcfVz6yu1bLplvZC5shobyj4bXBtLqaizUzWUmzNTJ7XnVcvNgCABadmyWrZtNTSZ3X679VyZ6/uqdc67Tw2Nh/qxe31TF39bbXc+23mwIk7Rh7LrOvyeWb3ycsbTUVrhdKr4yrYbhkbAwBghqpIrBnAfvm1Njv0z9aNe2A4EG2jQ2WoZhtrxq6cEK1Yq3eJAgCwmWr276PMoYPxeg/oksFY775os3ObUpswPoxWsE13DwAAs7A2s3I4GO05vF49Z1fPotUGilI7Yqd748P6aMVaf28921c7bQEAmKVaFn0tRrNg1QduXL+JotQmieol1z9/V0ulh40ub1Dfc3e0Yq16zZVF0XrMAQAwB6ti1COuVM+3cUujLYtuSu18HV6rXa41uzY+E3dh5vfuuAq62hV7e7TNFqujFX5VBFYT4WqNsjLzduakzBMx2k0LALDNqeXMmgkbz/hO1t6z8dfn0OrNDf0O2HHD7xtPqSJvXM3wLYvRGyX6n9USpAq16lHXjwEAMI2a/ardn7WDtHaGLs/cMHHHzI0XX1UEVh+4msXbVMFWUbABAMyzWkJ9NFpj4Oo7tybaUmi91mtF5rvMpZlHunyc+XLDJwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGDCnw/z+RtRc+JCAAAAAElFTkSuQmCC>

[image28]: <data:image/png;base64,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>

[image29]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAAJzUlEQVR4Xu3ce8h12RzA8Z9ccpvcSZRnXMO4k0uuMW65lBGGKX+4ExlCSN4JuSUxxi08mIYwbiEMmcMfhEn8oZFGZhRKUYRCLvvb2stZ53fWec55nmefd97nne+nVufstc9lr7XX3ut31tr7REiSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmStLndId0gZ44uyBkTumRIH0557xrSNVPett0z9i7/qnUHcfUh3XxINxyXTxkfrzaks8dHLaJNHG/rjolV6w6CfX6TMeF6TT5t4qrgcUP6zpBumVdI0ons1kP69JD+20l/aF43Bb7rrjmzcVZsL4B6TVq+V5RgBrncNb14SNcZXzMFyn9xzmxQ/g/mzAOiA/7zkP4dpSyXDuk3zfpPDumMZvmgZrFcb0/s5F1/fP2JrLYJOvIrYrkMpPOi7MepbHJMTNUmcFmUctAuXhfLbWIKHGu53np1ep/6hivBm8KATdIRdYshXTika+QVE/pFzhj8MS1/P6YdUajagO2xQ/pZs4y/RelEWrVjmQrlPy3lUf47N8vPiL3L/9IonSzpY0O60+Lq//vakO7XLBPAUcaK/UygPpVeXdU6PQrBWq9NzGIebFT/GfOu3eQdRu+Y+Gda3qtNMIr6tJi3iS/H6pHT9w7pKc0ywWC7z2gTx5rlVe6RM1bgsz+R8mZR2sWVGazBgE3SkfXgIb0gZ06MIKJFx/LjlMcIANsytTZg243SebWOR8BG+duOvpb/Rk3ebWN1+RmNObNZPjVK0NXroH81pNfG4rp2NAXPisXvPoxeXR2lgK3XJmaxHLDVMk3V2edjAr9Py3u1CQKiVzfLTHW+NZZHqpn6/HaUctZ1txrS5fUFo9weezYNtgzYJGkLZrHdjpWTI1NlFdM8F43pSU0+J/htXMvWBmwELrnDyAEbnRrL/2jyDiOX/+4xL3++to7y5yCMYPrpKa/qjZS9MOZBFIkpsBsvvKJsUzvichj1e57apH+NedtsV1PptYlZLAdntZx5/xxEbhPvHtIXo1xv+fxY/I7eMcGoYG87mMb/SM4cnB6LbeIrQ9ppXxBl2nJdm8j1tArf8b1YbBOMKBqwSdIhcL1aPalybRNTLXTyU+EE3Z6k6WjohPKveQKrPOo2hTZgo1PKJ+sasO1GCaC4fm2qaS/k8qNXfvRGObgYvnbOl8dicPmo5nnr9lFGX5hiq510i0DqLSkP3KRA/fTSquCr9/l5hI3tJ5BgFPVE02sTsyjbTxBFmzgnyqUDU+m1Ca4rY0Qt6x0T7YgggRHbWi9paKfZW5SR4P+v0Q8+Z7HcJljPyF1tA49pntfUw2evG2G7b5T6Pd43exiwSTqS6ITelzNj+WR7GLlzuumQft4sVwRWTOdNbdOAbVVAcli5/OiVH5Q/BwbnNs/ryFWVPxcPbZ7T4T4glgMqytobiXlVlACll57TvK61ScBGEEG5GBnaj175ptZrE7Mo27+t789tgh8Iedq86h0T7fHJNCrbWu/6zGWhDTwo5REE5jY/i+U2wY0Y74x5G6gBbJt6NgnYPhdlupfAbT8ekTP2yYBN0pHD9Mk3xsesnmzvP6T3RLkgmc6EEzTLdN48pzM4P8qI0U6U6c43DulmMceoAbfTV/zK/8v4/MlNPr/uudYmY4qynVrJiW3cSxuw/S6WL5zOwUXPx6METlwAzugGdUAHST18KUr9fCtKx/jRWLybMJcftfxnLuSW8teOtzovlm9YqFiXEYDk65hyQMUo3itS3kGtC9gYtSMQ2B3S46NM43LTxL2H9NUodfOZ8ra445DeFqUTf3uUAIFlAklGE3eG9KEodZTrnc9o6x2MFveCoFavTcxi74DtLrHYJt4cpYxsP3/fwvHz7Cht+g5RjrNH8sZRbhOUrY5qc3NJq3dMvD5nNPI69sEsFm9eqHfzcvxWBHHr2sSq+sg2Cdh+G2X/sm+/GWWalueUdyfKD0n2M+2ANkC9Mvp90bieY4/pf9rXheP6Wu98Vq/eYcAm6ci4NMoJ9e9DemVaV7Un20dHOWmCX8TfjXL3GqMmnCgJms6K+ahBDnzoFNopHD6DUQHe2/pRLF7TNpU2YJvF4g0WNdioifUZnVh7By0dH3VS66g+0gkQMPB9bf3l8qOWvw0wCKJ65ef9Z8dyYE0nnwMU/DJK0Fj/1oNEINFiH3Dh+WHMYrn+Vv2tR9suCLSqn46PdR8dixKQUeb6PvC8XvPF+1nO9Y4cJPCe3ghVaxbzNsFnXRGL298LUth3bZsgQH5ezKcv+d66jVwXxmfUsiK3CfYP13gRwLZWtQnwVxz52kT+Y4zApcV2XBxl6pFjnjJdNqSHtS+KMuq7rk306qLFfsz7f1Wdsh9ru6htogaXqOu4ZKO2CbTX/tV2Mxsfa72jV+8wYJN0ZNxuSO+I1X8LAToaTpAEdKfG/CRJsMI1M/wSpsPKv/57ARsIxlqMejD60SKQ5Lum1gZsx2I5UFyH99fOgsfPR9nOGhy0gQMpB2yg/O21ab3yPzBWl5/v/UmUUQO+gzL0bjjAKeMj7+G1jEBkx2K7f+OSbRqwMaLC6OXpMQ/YmJZbF7DVDjjXO87NGcmx2H+bYES5tgn8MErQOBuX24CN573AIR8TBH15ZHSvNkHAxfeeFqX8BDU77QsatU2A17bbXtGe1rWJdQHbfmwasD085m0C1Gf9H8W9ArZV9W7AJumk8usoJ7wPRJl64CTH9A7oQGrwwagPr3lulAvdCWbeP65rMUqQR4havPc2OXMibcAGgtBeh7UKgdVnowS5XH+3G6VOCKBeFGW07JlROkzSJVHqr0X5uWZnFcqfg99tYTR0yj9kXWdnSJ+KUjeM7DFiQh7If0mUEaAnRJniZfT2blH2EcFWnaZjRIq/I2E6mbaY653nud7Zd7Wj38t+28TLYt4m+BFD4MRUJNOzTHX+IMpNBGwjzykn290Gz5scE8ezTeRgcZv4wUI7+PqQ3jCkP8V8ivjlUfYzxxn7mTqubQJfiPmIKkEm/0VH3T4k5vXOZ6yqdwM2SSetdsSMk3r+xc/Jt31ND50ho3KrOkVOztuSAzbKcEbKW6ftzCjruvJmm5SfKZzjgU5yW8HxQVC31x2fM8LTjkQyMlRHIms7u9Z89VqrRpOyw7YJnm/yPa0TrU2cSNjPtX7Z/22baK/x5DUEzLX9bMKATdJVwjmxfMeZJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJOkk8j8KWxZzFXqwQAAAAABJRU5ErkJggg==>

[image30]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADkAAAAaCAYAAAANIPQdAAACUElEQVR4Xu2XS6hNYRTH/0J55hmKkaIUSl7lUVdRDDzCwESGJgYiGYgupVAGXomUMKAQ8ggpJ+ZmMkVKFFLII4/fv7VPZ/va59xb95y6u/a/fp19vrXP2mvt71vr+45UqVKl/qxl8Bb+5vgI77Prn3AHptd/UGadg1+wJBmfArfgEyxIbKXSSHgKz2F8YrMmwgu4D0MTW2k0Az7ANRiU2Oq6oLjH95ZSaxT1tzU15OQkv8H81FAWHVdxPdY1HB7BV5ib2EqhEVBT83q0JsNLRRee+r+pHOpNPS6HP3AXhiQ2axhchM9q/0y3xXdP9TgATiqSXJ8bd+L5h3pF3EzG2qU+++6pHuco9sizMDgbc+IHVZIke9ofJ8ETRdMZlY15nzwM3+EGHILRagSyVvECrsNsxfLeBQ9gO9yGRQothvNwGTYoXp5PVvZvv5dglpr77pVmKmYprUfP2DpFs7miRoJ1Fb1Zjz2GbkWwq+ChojOPg2ewDQ7AZsUKuZfZjK8dj0ujvk25lPyMVr6baim8UuOs+hvewGvFmfWH4ry6UOE0VbMka7A6+26b7/F40f2eEa+SjRm+9m+7FTGcUeP5rXx3TPmgJ8DYbKym4kCKkvRZ2QeMVJ6dLjgG72CFWvvumPJBd2WfrQIpSnKlYvbqpTBNUX97FGdly918t1r77pi8hI7CCdihaFp7FSci14qDc3P4Avsz/PfNjcr1ZA2EnXAVtsA+RcKn4AhsgtMwT819e7xo326r3J0dbF/kJpdvbG6A9jlGxf2gUqVKlfqn/gHqM4pIe1QePwAAAABJRU5ErkJggg==>

[image31]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADkAAAAZCAYAAACLtIazAAAChUlEQVR4Xu2WT8hOQRSHzxeKkPQpKerzJ7JQComwkkgkLISyUBaypqyULD5LC8pGFrKxtSI+2YidwkISKVF2lJT4Pc0dzh0z9456lcX91dN73zMz554zc++5x2zQoEH/uybEodTotEpcFFfFYTGrPVzUmNgoLonLYreY1poRVOMfG2PMYS5rerVanBT3xHdxvT38SwfEc7FWzBHnxR0xz0/KiARPiwdiqRgXNywEOcPNq/HPNTbGmMNc1rC2UyS5T2wW7yyf5BLxUhxxtvniiTjlbDmtEx/EFmdbJt6Inc3/Wv9nGhtjUax5IRY6W1GLLNw4lySOvlgIOIoT4kSmLOxqSRcs+MV/1FzxUFyz4KfGf0w6jW+D+Cz2JvasupLkXUqDQMx9b+FkcpopbtufSRL0lP0+lRr/PHGfGpsXa1jLZvaqK0lspSBy9qiYTCnJaC/58faYTBpfyZ5VKckYUF8QOUWfXUmuaK5zfrz/PeJHY/MaSZKzxV3rDyInisEr605yudX532X/MElUSqZkj0ofy5K95MfbS8mU7Fl1JclLXQqCz87ixB41XdyycpJUWCptjX+KD0UojS8meTaxZ9WVJOWZRmG7s8XKCVwjupgJ9x/xbaMqUh2jFohnFqoqqvEfN8bfD7HmW/Pbq5gk36axZGxcPBbnnI2CwS77NvC4hffmpoVTRLl5W8VHsan5X+v/qHhroXNCxEn388h6Oi92AGfsJAECH9enYo2bt168ttCiHbTwjZu0dmtGBfzazPEbtd/C2hPimIVWjFbSz6nxz/UVcd9Cl0aCPBG0dyMTlXaHhRvQiv2NOC02AbjOqcY/G7PSwkZss/YmDBo0aNCgQaPST1pOwcYZnhWgAAAAAElFTkSuQmCC>

[image32]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAADN0lEQVR4Xu3cS6iuUxgH8KUQueUSKXIpAxTlViJlIhQmRo4MyK3IKXVOyEQpDBQxICWKJNeUgdR5ZxQDE5GJy8RAJkJmPE9rfXuvb+19zubs/X3nU79f/Xu/9bzrnN726Ol5L6UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD8f5wQeWksNme1AAAsxTGRtyI/HSCnru0+tKbI35vk98gF69t2xIuR+8Zi54NSmzoAgIU7PfJjt57aOuvp+sila2dXQzZpf3Tr81vt6662HUdHHhhqp0Se79ZXRr7p1gAAC5PNznfdeirzDdtpkRvWzq6GsWHLax1r25ENav5depdHdnXrEyNfdGsAgKWZynzDtorG5uzaVnu7q23Ha93vIyOvRn5px6e7c3sjx3VrAIClmMrWDds1Zb6pSddFjij1Yfz3W46a27FzZs+uvRx5JnJr5LC5HQfv2FL/Br2crv051NJNkXPHIgDAok1l64YtjQ3bg6U++5XPeeWtw5x6XTG3Y+fMGrZF2Kxhuzfy61BL2bBdPBYBABZtKps3bHdGnow83tZvlDpF2xM5O/JCqW+cfh/5JPJQqbctn2v7RzmJy8nY/nLL+tYNtmrYnoi8Hrmo1CbyqchV7VxeZ07m3oucF3kkckdZn9AdHnmn/Z7JlxleiZwcebarZ2Oaz/gBACzFVDZ+LqNv3H5oe45v6/ydZpO2fFA/p1O5zslTf26nTGXjNY5y4jXepswXCD4v9RozX7X6o+2Y6/5N2JtLfSt0Jpu/LyP3lwM3dgAAh9SZpd4a/LDUqdXU6ls1bCe138uS13FGt85J3u2lfjdtbNjypYE0NmznRK7u1tmk5XStl3t81gMAWCkfRe6KPFZqc5NvTe6O/By5MfJmqbdL85boZ+3f3N32LNunkXsil0QuK/UDuO9G9rXjX5HbIt+242+lXn8v91441Hofl8U9owcAcFByypQTtP8q3xxdtrzW/E7azDgd+zeyGdvfZ0Ly/3+4HQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABW1z/XXYj7Tn+ftQAAAABJRU5ErkJggg==>

[image33]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAAFHUlEQVR4Xu3dW6htVR0H4BEpGApZQSEIimUQRAYqoigoqChiRvWQN3yLLuJDID0FCvqiKCIqGIUXUFC7QnlJwQOGaEaIFIoJooiBYILkg0jU+DHW5Iwz9lxn7+1aZ5+tfR/82XOOuc7ac8x1YP3OGGPOUwoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/B04ZGwAA2Dlfr/XpsXHw/bGhuqXWt8bGj5Dry/Lz/6j3DQDYAf9dUn+r9anudas6utaTY+OMucD2uVoPj40r+knZ2OfUs7W+3b1uHW6u9YmxcWHdfXt9k9pNPlnrK7W+WZZfHwBg4cTSwkrv1pm2VbxU66tD29ulfWH35gJbZGTuu2Pjii4srY8Jb5M/LNrO7tpWcVvZGEbyOw7r9tfZtxdrfWGxPYXQyaPd9sGWfwzk3C5b7Gf753sPAwCjucA2jUCtyxhSEmKeq/WZri2WBbb4Za1DxsYVzAW2e2baVvHy2FC9MTaU1rd16EPPGNh+XOvwbv9gOrXWe6X93YsPar2z9zAAMBoD26G1flPr/a5tFUeVFo4mX6v1x0X9rGuP/QW2BJ2Tx8YVzAW2vy7avtS1rWJPt31Faf3Ndc0I5he7Y3MhblVjYNtNsq6vH2FNeNut5woAu8IU2O4qLVD8sNaZ/QtWlPefRlIm95WNo2ubea3WpWPjCqbA9mpp/b6j1kmlBdZ1yYhdL2v5ElZG6duchN1ltZmtBLZ7y8bP5qbFz4yCZsTule7YuuS6pM9TPwQ2ANjEFNiOGA+syVxg+/uwvxX5gs+03rpMgW0MVes0vnfWxs2tj5sLbJlCTpBcVpvZSmDLZz5+Nk8tfmb0K+vhzqv1o72H1yKh9d1aJyz2BTYA2MRWAtvdpY2KZYH8dbVuqPXlxbHf1rqm1uO1Tqv1i9JGkibH1Tq/2498WcfF+7Tu35tl4/vEMbW+s6QuqvXZvS/dx2aBLQvjM9qY/p1b2t2Md9b6QWlh6urSfsdjtc6o9buy8bElT3Tb+TNZy5d1ZLl+/TVK39ZtLrBl1Cz9yJRsKp95rlECVKaqc46/rnVkaaNrGXW9vLRRyLlrHxmRHK97X3PP1ssNKP0atpzngZgWBoCPhelLfao9+xxtMqrVL/bPF3SmDnPTQKa0psCT7YSQrAnrQ1BCQsJB75+lLbTvQ8tm9pT9h8rtGB/rMRfaXqh1+tCWkJfgGjmX7Cd0/H7RNt6s8I9uO9fh2loPlI3TrnuG/VVMQXSsSKB8utZPS/u8pj5Egmn28zPSr+l6z12fVeUZdP+p9a/Swu94TQCAbUgISdiY5Fll55QWMsbAlhoDW/y57LtmLSM5eQ7XViUwXjM2HmAJbP1NDreX9ty0KZT1gW0KOWNge2bYj4xe9Xayb7nm6UNuKnm+bC+wHb/YXqeEtM+PjQDA9uVL/sHS7nLMCE0CW7YzBfqr0kbLLiltujD1l9Km0HrfqPXQ0LZV08hUHxp3wrG1HiltNOqC0qY8Mx16Y62rFu250zXX4N+1riyt7/3UYQJPwu0yO923BOqc8/dKu7lg6kP+t4X0IefyVmkji/eX9nkeW+tPtc4qAMCulpGQaX1WtpetC1smgSTTXh8mmGR9WKZPD5Z+qq5/ltxWJegdMzYu7HTfcv0TwLc7tWy6EgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADgw/geZ8+9aHSp3FwAAAABJRU5ErkJggg==>

[image34]: <data:image/png;base64,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>

[image35]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAADTElEQVR4Xu3cTahtYxgH8EcoQoqiG0ph4CukO/BVDBQDE5mITBnIwESpewvp6taNRCH5GEgYUAwk6ZaBYm6AcomRoszF8/Su5b57nb32vvd0HGfX71f/9vp492nvdSb/3vWuHQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwBb7Mj9l/u5SxzbNWZmfV+TLzAX/jv5//RDtOv+VeTLa5wMAWOueaCXiiemJDVEl89Fh++zM0WhFdPR75sZufyddlfkkWvE6lnlo4eyiFzP3dvsPRrvuAABrbXphuzJz3bC9rLB9n7m7298pp2TezVzcHasS1u+Pahbw88ybmdOHYxdFK3kAAGttemHrLSts/5VXpwcGDw+ZujMWbz9/nLm0HwAAMGe3CtuB2Lq+rM+nx4du204VtvPi+EzYnPu77Vojd8awXTNnr3fnRjUjV2vX+tL23cIIAIAZu1XYtuu5zGszmd7qPNHCVt/57W7/tMyz0UpVrTW7LHNHrF77Np6r99b1+7M790y3Xerv3jw59k2099VnBgBYMK6nqrJQheeBYfvxbszz0UrHOLbO3TfZLi9kHsucmXkl2pquN4ZzU9dGe99cpuVrO1YVtoOZ96IVsSps72Q+jDaTdn3m0DDux2hPcB4ZzldhXObw9MDgpth6bvxc53bHxqJcZQ4AYEHNCFWx+iNzTeb9zG+Zq4fzVS5ui1bY6unLKi0vZZ6ebN+QOT/aQvuXoxWhX6L9vd1Wpac+y+WZrzK/Rnt6tP85j3pC89Zoa8mqLNVt2CqkY1EcZ9zG17oOq2bYqqAu81a0a9MbC9vXmVuGY19E+x8AAMyqNVdVasa1V6MqMP3vsVWBqYIz3R7XaVWpqScx6/Wj4dheVCXqWOaRaN/h6HC8/27961jYVv2G2wfRxtf1uiLzbczPmJ3Tbdf4uXEAAGtdGO22Xt3mrPI2V9hqxqrG3JX5LPZ+YavZxP3RZghPprDdPuzPuSTaerqnYv2DCgAAO6Zmf06dHlxikwrKiX6nXs2Knex7AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPa+fwBKYJEchGOmqgAAAABJRU5ErkJggg==>

[image36]: <data:image/png;base64,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>

[image37]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAAGlElEQVR4Xu3cW6htUxzH8b9QbrlfEjr7RMJRSBEhitwv4eGUk4cjIQ9uuZRo51IkOshdTkgo15Bcyi5FePKgI5ccCkWIUDzg/2vM0R7rv8dce6291l5r7e37qX9nrrGuc8xV83f+Y+5lBgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABYZvb0WhkHAQAAlpNtvHb32j7eMSHWe20XBwuHeh0bxlZ4PRfGhm3S5+1Or83joNvE64o4OASnWnrPpUbHcbdmu5yvp4ptAADGaq3Xv17fNf/+4LVlxyPGS92zVXEwqAU2Odq6B71BTPq8HeK1axwsPBEHhuAdS++5tdczXt+01LvN4ybBC5aO3+9e93u9XNy3xuqBFwCAkVFX4U2vz8P4TpZOYIsVdPpxoNenYewir5/CWFtgkw023OXSpTBvJ3l9HMbivG3mNV3cbnNQHGih98xdKnUdv262NV8zzW2Ny8+WjtliUMB/xGbD4TWdd3c43lIXTR1H2cdSAC+9Z5NxTAEA/1M6wf7jdWu8w1LwWB0Hx+Bar9fCmE6wH4WxboFNjz0vDg5gKcyblpDvCWO1edPtHcJY1Guw0ntm+3t91mzXApvC7snN9rApTB9Q3D7B6+DidulKry+9pprbCm7lfsgXXkeFMQAARkbLUgoY6jJEf3h94rVzvGPEdJI/vbj9oKXPrJPyGcV4t8Cm0Kd9HZalMG/qLJVBq23eNL9nF7dreg1ses+aWmBbLFrSrFFouz0OWlqW1bzkUjiLQfJx41o2AMAYqbuik1QZiLI/LXUe8hLXQh3j9YvXVl6/Wu8n/ywGD3VAeukKlbR/38fBAYxq3hQUFjpvMRy1zduMze0U6rFa3tXzVScW27lq8hJo1Gtg0/dE+1y6ztI1ZCsshaYXO++eowyfOkZ6zeymYruk6w5P89pos8GtPH4K/LEzCQDAyOgvKHVyqi0XalxLkVvEOxYgB5uXrP/gEQObOldxqW8+ev/f4uAARjVvObwsZN5iOGqbtxmvR8OYuk53eD3clEJS3s5VM2hg03GKge1JS4FKn31vr+OaalOG6By+souL7UxBsLTO0nPK+VZgUwgHAGAs8sXzP4bxKUsnrXyh9duWrvV51WYvzr7L6yFL3Y+rvd7wesXrSK9bLIWAfZvHxsB2uKUT8LSln8O4zdJr7Gdzw4AuAC+XqHThfL4I/sxivBsFq7YT7rldKi6NZcOaNy1TPu31mNcuNnfeYmA7y9JzL7HOebvb6vNW/rFA27ypc6TP2E2vYTFerJ91C2xrLXX4brD0PcldNM3PlKX91V+cfmUpOF1mae61zzUxfGYrrX6fXlPfx0yfT59zj2JMn0/HEgCAsTrfUtD4u/n3W+v8eQoFhxy61F3SXxdqyUhjOuHphKxQkelke6HNLiPFwCYKNeU1RepKKfBF662zM6SLv5+1/n5fTY/V5xy2QedNc9Ft3mJgkxxqMs1b7BLJjKWQlrXNm663K8NJTa+BbSYOWBrLna5cCkTZRkuP2dbSvmlbyu+Mvl9l5622FJ3pe6Vr9HJAFs2rOob6N9JxuNTStWv5WCoElz60zuv+AAAYGy3hqbtQW8org4c6Deru3GfpOqdaYPvA0k8rzDS3Y2C7yuv5YlwUfmrXmekvLnXCLGnJbtMw1s0GryPi4JAMMm8xsMV5i4GtfG6meVtV3M6mbW44q82bOnwKkt30Gtimbf7XivayFCz122f9BLYdi9vROq/XLc2lwqwCcNzvrDxuOo61UKfvjzp0AABMNJ0sdQLUspuWp9TFUMdCS3Pq0Gg5S7+rlZcQFTyu93qrGdMS1o2WlhC1/YClztnNln4VX0uDF1haTn3f5lJ3o+xc9UMB57A4OCLzzZtCq35sd6p5fJw3zVc5bwo1eq5eQ8uY+otIzdtfVp83BeOy0xStsXpAGYSWfLu9Z6SuqvZB+6190L5e3myfYul7pe+XlkT1ONEP3eoxo6DfZat1MAEAmDi5U6ROR6ZuUa2rJAoB8520y9eaj15Ly1TzvWakx083/47DYsxb23Nr9HrnxMGCwuSw3Wvd3zPS/vbzXRCF32EHzTb6jwUAAEuCLsCfhB+DXWqYNwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGCZ+Q8v1FoP9Vw3oAAAAABJRU5ErkJggg==>

[image38]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACcAAAAaCAYAAAA0R0VGAAABqklEQVR4Xu2WPyhFcRTHj1CErEQpmxBFBosFRVkYyMBgYDBYUCzKbGFBJANlIEURhhfKYldKSqQYTEZ/vt/O+XHfz3vDQ9dT91Of7r3n/Lqd9zu/3+8+kYiIv6cHvgV8gbcm7xmb/xgdIhlwBd7AFpgZyDXAJ3gECwPx0CiBZ7DSi1fAK3gJy7xcaDTDSS/GYljUI6z3cqHSKjpLDraPbWQ72da0IRcuiW6CLi/3p2TDRdGdOSa6UdICFsKCXu3qCsuCtaKFp0IpnLHrj2Ah3aKt5MwFCymHc6JFpkINPJH4tfwtuLZYWKKzbBgOerHQcIfsMSzycjxOTmGVPQ/AbdgHp+Ch6A9rhBtwWbSNOXAUbsFq0WWxKtrmfrgDp0U3X1LcWeYfsmxrE7yA+/L5ErZ/Da7bGLbuDnZafgLO2n0B3IV19swx/AJxmeTBA9hmuS9wwJ7Ef08TybYG4QyM232x6Iy7Rc848yRfdJZdcR0wZnHCcYz9Kn5xMbuSqLhkcNfew3PYCxfgs135zPg1HBJdfw9wE7aL/rHgd5rxEdH3MMbNEhER8S95B/J6YotEEMpYAAAAAElFTkSuQmCC>

[image39]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAABCCAYAAADqrIpKAAAFFklEQVR4Xu3dTainVR0H8GNjNL7EaISaGuqQQiSoSJrkQrQWLQIxdxIKgzaLAaMEMRRHw40ogRMZooiLWtkLBFE5i5sIIm7cBBIZKmIgpJsSNNTO1/Mc7pln5r4xd5x7/34+8OU+5zz3Mszux++8PKUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsLKv1Ny0zQMAsLC+UfPgfBIAgK3jZzXnzSfX4cSai2pOqvl1zWcPfX1M/bBmR83rNVfP3gEALJy9NSfU/KPmoynn1lw+jJ+dfvenw9yXan40zb9Zc8n0fDROLq346//GwZo9NW8Pc9+qeaXmzJqnax7/+C8BABbU3bPxAzXfHca/qvnfME4X7WvDONJpe3T6uZqH5hOrSGF25zA+p+bFmtOHuUjhdtlsDgBgobwwG6dIumEY/7e04qn7dmnduFF+P8uiazkwn1hFisRxqTPPjwzj2FVz1WwOAGDbOq3mttnc7povzubSXeudreun516wHek05k9qzq65o7Rl1NWst2D7as0fa75c2rJr9tc9M81395ZWrF1Rc+swDwCwLV1T2r6v94a5s2ruG8Zd9q09Vdq+sRRsKeBSsKWrlu7aRuwsreDqeWI2nnfqunTS5t21cVkWAGBhvVtzxvSc4uue4V2Xgi0b+X9Z2jJnCr0PS9u3ttYetbkbax4b8vJsnK7fXPaoZa9aDhR0Y5cPAGCh5XLcXihlefIzh77+WDpf75fl7lcKuOxjO1I3bqPWsySaJdd5cfZqaUUcAMDC+1zNP0tbYrx49q5LZytXdHQp4F4rbT/Z0VpPwfZkOXz5Mx0+V3cAwKdc7v5KVymdnQ9q3pie95Xly2A/X7O/5js1b5XWgcqVF9GLiYenn98rbSP+L6bxVvKHmn/NJwdZ9jxlNr5yGB+N9RRsAAArytUU86W4FGzp7sSppW3AzxLh76e5bM5P4fabmgumcZeLXje6SR8AgFXkZOJ8Ka7v34qVCrYsGWauj7MHK9dQfLPmuWkeAIBN8O/STkeOsvw577odSYq5BACAYyiF2Q9mc1vpOokv1PyptI+drxQAgIWV7tjfyuG3/r9TszSMddEAAI6THDiYd9duKe20Z5cLZHN/2XiCci05kLBZRV5Oq15X2mW0KwUAYGH9vBz6KaTcOZbu2igHDjYqd5ptVsEGAMAaesH2u9IKvPun8VJp3a/M57Ro7l7L55Ui416wfb0sfz+zf1w9971F7nHbVdrH08cPnG9V/Z66JHvn/lPz97L82SsAgOOiF2y5umPsti0N87mL7dWa26e5sWDLcwq26AXbS7PxeEXIVpbrT+6anlNoHqy5Yvk1AMDxsVrBlqIsP1Nsfb+0ryL04ivv9k7P8w7bdizYcjAjRVqks5gu24+XXwMAbD0pwHaUdhghPzPeObxP8dal0EmRk9/b7vL/zGe8+qe7AADYYnKCNkuhAABsQTlgkEQ+Dn9geHckOUxx7XwSAIDN1w8Y5E667rGafTWXlra/7+aaB2ouLO3LDLk7bk9pf5Ol4t+Wdmfcn/PHAABsrhRn2bfWnV/aN1gvnsa5gHh3zV9qHi3tKpPnS9vv1g9q/LVmf2nfad3IJcQAAGyCFGU5FdtP0ubEaz8J2wu2peGdS4UBAD5hCjYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGD0fxDWzkId2bezAAAAAElFTkSuQmCC>

[image40]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAbCAYAAAAH+20UAAACw0lEQVR4Xu2XWchNURTHl1CEyJgSX4qMpfBAKEXxQCIeCA9C8kbmQoYSReZZUSgZkiTDw1eKxIMXkfKglCIpIUPi/2vt7R7bzXfc++WedP/1656zh9Pae6+19rpmddX1f2m8eCm+Z3glvohv4p6YIVqKBrFPHBGzxEVxSPQTa8Q1MU+0MNc0sVMcFktEa9FJbDP/xgoxQOwO78N8Wj4dE1/FmEwbRi4yN3yluSEjxYvMOOZhaEfRSzwQA0W70L7MfN5esSDM4Z3vHRe9zRfUPfTlUgdxWzwTPZK+nuJ5pm+4eBja0SqxNjzTRh9jopgzRZw2HxvFAq+KK6JPpj2X2JE34rxolfSxox/FI9HVyhscDckazPHvD3RJxkXhPrjj4KS9SU01993FaYe00bxveXjPa3A6bqvYJOaE9xFioZhpvtPseG7tsd/9lx3C59h5goP3BnFBfDKfM1s8CfBM2ztxRgwVl8UO84Djl1PCpw+I9+bfHy0+i7tisuVQe9FonhXuhOfH5rt60Pw4qxFZoU3aWI3K+S9RTJoiO0wMbYVR9F+OKit88IN52iqUyvkvIjhYCMFSjcaJt+Jk2lGJ/pR/WQgGp6moEpGHm8XgIearT/Mvz+fsV4PXiQk/R/ydqjZ4rPntldYP+HMU9QNBh+FzxVHR1vz6ZfcvmQfmKfNFdRNbxHZzv+9vJVVtcF7Fa5VMgbFAwYO/kw6vh37GTRJPwzMnd8tKKfGfGZwKYyhuyCC4Da4Uby7E5RJvsPtWuuVqZjAia3DkS80LmnilYiilKKeB2zRaAQymZNxsftTp3Y9BMUD7mt+axAFXdM0MRhusFKjUA7vMFzLdfIfnm2eUm+Z1B/XBDfHavAxt1mu6KY0SJ8x9FRGElI/Rj2nvbKV/HDUXdetZc6MQBvPXpnD1RlYE0mqx3rxWHmQF2tG6KtEPOTCdSdcAr+QAAAAASUVORK5CYII=>

[image41]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEcAAAAaCAYAAADloEE2AAADJUlEQVR4Xu2YS6hNURzGP3lE3pc8Bgp5xPSGiAFFHnmEAUmK0k1EFIWkJBkoDLwSGZh4FCGUckRSSihG5CoRZWLEBN/Xf6+7X2ffvfc523Ef+6tf59y11jlnrW////+11gVKlSrVAE0lJ8luMp30DXd3X00mp2Cm3CR/yJ7QiM6tHmQG7OFrnUtIz9CIdrSUHPbe60MyaZDf3aklY5QNj8g4MoxcJudI78C4RE0hL8iEaEeDpYUM9F6LUjP5SmYH2saTj2RhoC1R/cg98oAMjvQ1Ur3IDvKQzEOO0G9HyggZMTrQpgfwmFxExgexnvwmh5DxA/9Q/cl2WDSvQcbwryJtKncQN2cAqZDnZGigPaYmWA7eIi/JLzIzNOL/SRG9ETYvvervPHImJJkTbQ9JHc9gBUvRoqeknWpvcFAHkCJHc3tN9iP7ZqH1yYCoCanmyIzjMHNcnVFh/k4uuUF1SkcEPfVWJEwip1SDlsPS4QDSTRpJ3iNuQqo5qthfED7POKeLjBztFjKo6iRqkAyaT96QXZG+qJJMSGpv0yJYfYlucZ/JskBbvSrKHBc1ivSsqaXd7xriJjhztGNp54pJ5vyATd5JpuiJKBzHkjPkKtlGrpATZJQ31p041XYQtsM4TSIXYJ9Rn2pFrea4eiNTtIMFfyeLlBkqFSoZTsNh69T8q2oMbIA7CGkn0NWhpW0EMBe2sImwGrWV3Ic5L+POe+PUfsx7r4NkBWaupO94i/zmFLWdaz6fYN/hNId8Q8qurIPWK1gBrpB9CE9CUXUDZoaktHsHPxVVyBeQo/CL+E5YKCukpbxppXRR2ihSlEZFHARXkg9kM9kAe1hbkOE8px8fAd+AoKLmaIGtZDGsGF6H3Vd0N3PmKIzdeymPOcp/hXpRp+OgdKfSPIXe1y0t7Db8oqUU0ULdgl29WgczRK8ryFP4J89pqK/mdFhp8Uoj3U8Ukk9gT1Wpdxp2N9kEu3KoNmicatcR2K13Lawo/yRnyRB0Ibm0Um1RKEZDXelWLR0l3WvUJyP7RPq6hGaRu0i5nHVHqUasIqth2335b9NSpUrVqr9gOY+MoKSaYQAAAABJRU5ErkJggg==>

[image42]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAaCAYAAACgoey0AAABj0lEQVR4Xu2VvStGURzHv8IgCimyUUryNiiLxaCkKIP/gomiTM9ikEUpyiKDBYtBFsOTSRn8BQaKxWCyKPH9du7tvLjHo557J/dTn577nN99zu+8/M55gJL/TCPtpr20hzY7MT23Ot/rpoGO0Uv6Sb8C9+g4vaMbyW/qRrPYhk1yQPtgBiO66L4TzyWxOl+H7VTPaUIXDe4QOSYepq8wHd7Sdj/sMULfkFNidZLOdiuIhaiorpFDYi3pCWziVT9cHG20Cpt4wYvWh1anP2xMCWccLqEKSudY5zlU51znPQv1u4saW7eC+B5P0PckFvoIM4AsJmGK8DgMuAzQF9SuarcIw5VxaaEVukPPaZMXDViD7TR2jv+aeJFOw7xThamjKNor9xK5oKNJu1CR3DjxWGLtu2KqDRWqrtdO740Ig/SIfuDnnp7SGXoFs0IhWiUdx026BHMF/1YHUTqQ/e8UQzfgMmzVz9IHOuS+lDcaWAVmqVN0Ip6Sz0KYo/f0mc4nbZrlGczfq7ZmKmkvKSmWb7UJXuorAS7uAAAAAElFTkSuQmCC>

[image43]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB8AAAAaCAYAAABPY4eKAAABmUlEQVR4Xu2VvytGURjHv0IpCilSCqUkvwb/gsVAshj8CyaKyWiwGBBlkUFKCoMsBrGIxWCVLBbJpKTE99tzb/ec414vuXd7P/Xpvfc89z3PPc/5cYEyZRIqaTNtpS202onputa5z4UKOkCP6Qf9DFylg/Sazkf/yQWNZglJog3aAXsh0UTXnXhuyZVgDknHuo6TuugFN5Fz8l76BOv0ktb7YY8++oIck6ujeNSLQSxEC+0UOSVXeXeQJJ/xw8VSR8+QJB/1ogUTjjwspxaZ9rn2e6jOAZ0HMeP0it7RC9ig9LsP2zmpTCN7zofoaxQLfYC9hMsULKkqKjS4NXpAa6I2jy76iNKr3V2YYYViVuAPQMm36C6tcto9ZpF0nLXPSyVvhJV9LLpXH5Ow0rfFD6WhuXMPmiPaH7WLTnruxNOS99B7ukwXYFU4pO3uQz/RDSvTO77P8R4dpiewSoWE8x233cIW559oQPpXLYtwvsUEfYZVpTDC+RZauDoN9ZHKXGz/ZQS2l99gW0ofn216A9vGv6lamTLF8gWNZGcMY2jgiwAAAABJRU5ErkJggg==>

[image44]: <data:image/png;base64,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>

[image45]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABh0lEQVR4Xu2WzSsFURjGX/koUZIFsiIlH6GslJSiSHYWirK1srBRVlI2lmQjioWU7tqCP4GyF5FkI1nZkI/n6T3HXK/cOzPda0rzq1937nlPzXPPeefcEUlJKSxD8AF+ZPkCT2Bd1rw/Zxu+w1FbSIJaeApvYNP3UjK0w0eYgWWmlgjTor2zaAtJsQ5f4YAtJIHvnytYb2qJkK9/KmC5HczDIHyCe+77KnyDE18zcuD7Z8EWQAlcgV22EALe3AcivA4ViOfPb/3TCndgpS2EIFagXOcPt2lLdAU9HXAX7sMNWAOr4LIb58PRoFPjBeqDz/KzfxpFw9zCZjfWCc9EV60NXsB+uAln3Bx+Mii3OlKgYXgvwX8XG+7OyWs/fiBBUPaYDd4CL0XPr0n3eQSrJWKgOPBm3Cr+ek+P6HZzpS1FDzQCzyU4q7iV3aIrMuXGGHZc9KgoeqBSOA8P4SxcE21q9hRfVbilS6LBe+Gx6GsNx+bgtWgPjkmB4dPHIBaORT1AU1L+J5/yUVLGYImciQAAAABJRU5ErkJggg==>

[image46]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFkAAAAaCAYAAADcx/BtAAAEQklEQVR4Xu2YWahNYRTHl1BEhshQZAhlCpEhlERRpgyFvHHzYixDeTAkJTzgIkl0k6F4uzwYigfJ8MKDeOCBRBJKkpRYP2tvd+/v7Pnce92r/a9/Z5/97bPP963vv/5r7S1SokQLxQjlUY8cF0JnZQf3ZBOhq7K9e7IFY5xyk7KtcqrytXJa6IoMGKs8K7b45sBE5Xlpvv+rFtuVL5W9le2UV5SnQ1ekoJ/ytnKkO6Boo1zkkeOiGKbcrOwUOLdKeVL+jaLXKW8ovyg/KW8pTynrlU+948fK5d71PcWEQQzI9mtitpEJ/Oiwcrdz3scYsYlw06JWQmBZxEfl8MD5jmKLWhw411yoVd5XzpQG8aDQPWJiQ3jHxCzUxXgxVWMhmTBK+dz7jAIqmyG2k9VgtNiGudmAUu5JMdvAH3sp+wbId84ngTmcUE5yzs9Srhcb3yaV44B5XlBOcQeSgNdUo9JqMVj5QvIVETJgq1ha14ml9gGxDZvrjSeBtWJVwTX3EAs8nwQXRbuCIMAHxbIR1Q8ND0fD95Yd7oCH/mKT7uIO5ACT5h7cKwq+lcTNwUUf5VXlSklXbB6gYJSMPWAT2EUQZPQuMQWTMfhzTeiKGHDxK+V8d0DMJ1HJceUTsWDlBcXyoljB+6CcHR7+C/6HTsNVjgvUw3yWuANVAg9GudyfbFgWHv6D1cpfDjPVEgz8vVSmKr52Riyw2Mlb5YDQFelg4igCBZBeFD3uFQXO35HoIhMEdYMgE4zGAvM7ohyiHOgdp9lNLhBkmmo+g5igXCPmQVRg1Jh3YXgeKQWwi59i6RgFgvxI2d0dcEDGbZBwoXOJMNIyIgiyDZXym52So2PIirgg+8B/vklDr1gU+5RvpNLnfAQb/SQQZHpbCl0c9yu7+T9IARlL+0oGTVdulMoNmiPZ7xeJtCDTbD+T9MUnwS+uSR1MVrsgE/D3xkCwTSNj6SwIehDYBhtHhhQG7RN+Szq7ILAEmEATHFoXfxJ+fxoXtCD4j3diao4DY3QYwafBKPCfWJcbjCIguASZYNNZRBV/Cux1Sd/8RPCAQa+51h0QS5PvYkXR7Rv9SpvFq1HfD+8zCtyTziLrIyoL551B2oYkIdimUfDY5OCjPSJaITYvxOVaSC7wY14KRS2QCdC60ZOek/ATGbvOBuCjaamU5scUu4fKBe5ADJjzPOUDsRaqiMqWir2XwAoQWb13DCn0X8Uy/JJk798TQVFjkVGVnd1F7VFNP1ZRK8l+7T9oJPkxxRVbGuQOpIAHJDKK+1NXfN6UYj19k4IJ3RWzhzwgKIek0i5424Z6US597WexN15RQJV7PVaVkq0BpOplyd6Eo2wCHPUEVyfWE1NM8U6UFvfyBz9kPO+DTqsEKuKFC8yiKHx4oURfS3DxciyIqh23cVgR9SDTo+n/Aha9RTnZHWgi1Eh+iypRokSJEiUK4TcqN6/xalArnAAAAABJRU5ErkJggg==>

[image47]: <data:image/png;base64,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>

[image48]: <data:image/png;base64,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>

[image49]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADYAAAAbCAYAAAA3d3w1AAAC7klEQVR4Xu2XT6hNURTGP6EIISJFD4mEJFL+TYQYkJEJKQN/BiQMFKUXGSgToigTA4kUE5KUFxMxUkTJgJQklIGi/Pm+9t7Ovuvufc4973XeQPdXX/e21u2cvfZee611gS5d/huGU2OtsSFGUyOssQkU0EVqqXU0RA91w392zBTqLfUnIdnljxlGnaf2GHtgBbUD7kT7y2zqADUqsq2ibqFGlgylJsEFsB1FUCe8Xf6YtVQf0i+YTL2hXlATja9TFMx96jM1N7IPoc5RhyNbx2xEEVjqASOpu9Re6/Do5ctRM2USLKAWwj0vZhn1kpph7JVUBbaYeo3WnRxMxlNPqa3WUUVVYLupR9QY6yATqA1ov5N1CM+YZh0Rl6graD/NUqoCu+xlWULdpI5T76g5re6O2ExdhSsan+DucgqtK7e5WcoCUy/po04au+7dBWoWtYn6DncX6jAPrjCokirNVTjs+wNaY6pal9JJYNautDkKtyjt+GOkK2YZ21D0RKXiL2pN4W5Ba/xAzbSOMvoTWECV6j3Va+x1UUboOVOtw6M1foOrmknUSB9Qx1A004EEpsLylZpvHTXQ2HTbKzdCVaaimmAIQscvVEaD7aC3BTRxaKxRVbKE/hYWdASuFwXGeVWh9FKa2XscozVqCNAwkET3QQGEXdapXfc2VSVdaMtZpHdTQeg5eul06gxcsEIV8iNcelU1Vt2rn/4zhzYttYZ/KIcfUj/gSvQXuKCeUIui38Wo6j1H+7ikNL3npXmuJ/LpPc+o33BpVEbV/QpZk7sOLShy5auU3QWPdvwVtdI64GZKBZwbfneiSPkUYUYsOw29XyNV3XZSibq9hmP1nDqdXzt9Gu2pqClep6QT0nVQOufmUKG2cA35zRsQWoSqaeoO5lhPnUL7ZmiKUc/SSaoo6cRyPVDj1h00/B9QD1ehyS0iRqe1BenfKiDdP93rfSgKjkUb0ksd8t8bZTW13xobYh21C4MQVJcuXcr5C9PvlMFJ9I2CAAAAAElFTkSuQmCC>

[image50]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIcAAAAZCAYAAAAbiz05AAAEkklEQVR4Xu2aa6hlYxzGH6Fo3E3kOmOQNCbKLSHJJT5I4QMhRTFEKaHcIsklI7eQ1OSDywfXUAzluJRLQqKREkkURYmScnl+/dfbWuedd89Ze5+zz157rKd+7bPWu85e7/tfz/q/ty316tXrf6fNzZnmUXOd2W52cXttZnY2u1WfHPeaDm1pdlU8u60a5y8xxyhMcoN5V/Fsh9Y25hXzhLlas2+yUMJwF5sT8oIp1L6Kt3H7vGACWm7uM+vMadU5nueMeaw6XmF+MKdWx0OJL3tc4b5x6SDzq/nc7JKVTZMw+YPmX7M6K5ukMEYyB1plllV/H6gwx4l1cXuN2xwE9B7zj7oX1GG10vyoaEeXjJ6bo6lrFZmF5zy0xm0OAvqSOVdhkA81Yv83YSWT05+/qjDIebOumJwGmeMI86TZKS9oq3GaIwWUIG6t7gV1GCWTY+xT1C2jl8xxiLndLFGYY6QsN05z7GeeUx3AFNT31Y0BXVth8ltUm7pp9LPTRRNUbg7GG3eZvRXP9XxzeKO8tcZljjygKI2kuxLUtspNjs5Qd4zeNAezzecVMU58b/asyofSuMyxj3lGG6bdLgW1rW7Shl1hl4yeZ44FU8kcvPVpYawNpbURAlqamWAIjIFBMErXhclZByr12ZgCc8xoxNnAAmlRzbGDuUOx/NqGfIFlYwFFXQlqGw0yOeqK0RfVHPMVc+vL85MNNYPKILWr2su8oFiiHqRkdAaoDFQnoakxR5uAIvrwZlDpmli+Z+B3lmJZ+DVzrKLhL5q7VY9TjjT3V9fdrJiype8gm5H5llefpezGvgOZrdQlJs1lckT3y5S2aXSmkcR0jblAMQW+zeyvqA9tTlsJtP366vxac3R1nvqmzMz3XVT9XdrimBpzEMy/zHdz8JPCHM2gbmveUjxsxj0EiOsOq47Z/2ERCj2iev+Ae/IgktiRXGd2Nw+ZAxplSQSb+z9ltsjKEOb+QnH/vO45tDfPHnQzlK1QGJf6PKzYLGNa+Z5Zag42X1Wf3PMN1fVlSvqB4kW4zJyjMHWuqTAHjVuv2dOoNvBmEdQ0A0gNPdS8rDANop68zUlkkZPNnVVZEg8A87ytMFZJ3ONP87XKbcdweT3n4m9zEv+s+P4Z1WMq6pfGJbTrU9X35YGzB0I2pbulPAmjY55LNXjHfCrMMV+VzEEX1Qww5iBIV5lnFYNfrm+aAx1nflH9sEoiPT+gubvAUVQyR7NdyRzLzDsKY7CSSXub5qDbwjD3qjdHK3NQV4Kbgsi+DWV8ksIJONfRf/NbBo5LwliMY0rdynzV1hzUMxl7R/O6udAcpciAlNPlMPsji5S0yZuDt/hG84eifyYFkxl+r86T5r8xHykCQf+9VjF2uNV8rOheuJZxwhrFAPBb82V1XVOkcoyxscwyqhhAMqb4WfHbjysVu7mco11shv2mGFAfr6j7anONos1vmivMJxV7KMZbxIYMwlJDU5u8OUYRdU9v5rCivadrcKpeTGFUuo/SYLONxmYO0vDTipE1nxz3mg6tMp8pnt1IP+bp1atXr169FkH/AVkrHYE3Z6psAAAAAElFTkSuQmCC>

[image51]: <data:image/png;base64,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>

[image52]: <data:image/png;base64,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>

[image53]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAxCAYAAABnGvUlAAACjklEQVR4Xu3bP6iNYRwH8EehSPmTSCn5N9iUbJIBWSwohQxSjDJQBiaDWQZFsrAgEyXDTQbJYFESAylJFEUm/H6e99z7Ojk3dI/TPffzqW/nfZ7nvL3P+Ov3vG8pAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgzEvMq17EgBgWF2IfOueHJAbkZWRU5Hbkbm/Lo/60j0BADDM3keudU8OyPfWdRZld1vjjuysPemeBAAYZlkkHe+eHJB2IfY5MtIaz4hsjSyNXGrNAwAMtfmRF5HF3QsT4FHk1TgZTx6FPossa8ZvI7tL7a6diaxr5gEAht6aUo9Dp7fmZrauf2dj5HJkduRjmfjiKYuyY6XuLWXx9qD5zbXsri1s1nrZHznQPQkAMBnlBwcbWuNVkYutcS9ZsKWbpXfBtiiyZJz0kh8bLIjMiewt9bh2c7OWz8qjUgCAKaFT/HS6a1lE5VHl8siWyL3IpsiKyLnmP/tK7XL9ScH2L56XsSPTD5HTkW1l7Bl5TPoycjayPvK6mc/CMztweQybnbkdpe4x93ql1PffHpb+HP0CAPRFdqzyY4NMFj2ZvL5aagGXBVAWSykLtiykdpXa7crOV78Kts6eOskOWxZb90t95s5Si7kjpT73cb1t9KOJHOf89jK2x87aSBm/swcAMKkcjtxqrle3rrNjle+49atg+xsKNgBgSptV6teYB0vtcOW7bUcjJyJrI+8iJ5vfO809/9v1yNfInsjT5vdTqUeguac3kUOlHpPmWh7/nv95JwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPTFD7BwZlW6Z4J5AAAAAElFTkSuQmCC>

[image54]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAA9CAYAAAAQ2DVeAAAFMUlEQVR4Xu3dW6hlcxwH8J9QhAiR0LiVWy4lRKPQKBLKKELIJR6EMYmU8CDK5UFyayRNiMYt5FpOPBCSFy9qEo3UlHkQU0wu/5//Wu11ljln5kx7n7PP9vnUt7P2+u9z1jr7PJxf/9uKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADG0l4l2/VPjpF9SrbvnwQAGLa9S/7u5LTpzQviupI/S1b1G8bEGSW/l3xYskuvDQBgJO6LWqyNk8tKTuifHCNLS87vnwQAGJW3S37qn1xAOQz6bNTev3F1e8mR/ZMAAKPyV9RetoV2ZsnKkrVRh0THTRZo95d8XfJHrw0AYGR2itq7dkjn3JYm0h9RMlWya9TC6rxprQP7zZDNLSb4rEnK3rVvOm0zuaNkx/7JEXmxZF1znL1rP3faZvJwyQH9kwAAc5WFWn/y/Nmd45m8HrVgey5mLtieniEPlOzReV/q9vJ9EbVo25LVJTv3T45IFmhrmuP8OjVomtEnYdgUABiCLJK6k+eXlzzfHB/VHO8etUcsC6S2bWsKtrn4peS45nhjyYkll5TcVnJRyXtRV7C+UfJQyUElT0UtNPNerij5IEYnF2Wc0xxvKrmwZEXJNTG4dn52L5U8E7Xn8tWSY6J+RleWvBnzV2ACABMiC66pGAyHZjHxa9RC6eiSL0sOLzkpalGXw4+Hlewbwy/YNkRdFbqk5PuSA6P2Tu1Wck/UYml91MKxLRqzAMp7yNcvRC348t5GIXvY8jPI4vW3qPe6LOr9tNf+sXnvnc3Xt5r3ZXGXn3EWl23RBwCMgUNj8I97Mcp5Wm1hlIVGDpt2DbtgSzlMmgVQ9k7lPLeU18ifn4VPXjPlNVP3HvJ+2zlyo5LXyvl9Wbh2V7C2157qvE55f3nfef/5vWlYnxUAMAQ5kT+H0XI3/IWQBUT28PTnim2tLExuijqUl71K2fv2RMm1UXvZcgjz0ZLvovbEjUIWbneVvF/yStTevxujXvOqqL1y2Z6fdd5DDpFmtvV33hbXx+Da2fN2afP6hqg9gnnfn0Yt3m9pjo//9zsBgAWVvUT5j/zdkst7bfMh51C9E/9dibktslhrZQHV9hQBACxaWSTd2xxnr9R8PUHg5JKPos79AgBgFjlcmKsDW7ldRbeXathy6PLckgdjMO8LAIBZ5GOeuvPWcsXlVIx2KPHgqEOgx/YbZtF94PukZpj6P3sYAQAWSE4278retexly60dRikXGTwWdWgUAIAZtNs59H0etWhLWbj9EHWrjFz9mFtE5MrB3Cbi26j7ebVbaGSxd3HUvbvm8gimm0u+irl9z//Fkqgb8W4uF5TsOXgrADCJ+kNe/ZwVdR+uqeb97X5i+TDx7CHLRxnlqtJ2v7G0Juru/gAAzJPZCrb2dT7m6JSoK05PLXmyOV6M2kURj8dkP5Yp/365J1yuEM6FJwDAhMriZq4rPXO4tP9w9TZ3x2gXO2yNHN7dvznOXsZVnbZJkYXo1TH4++UQeD7hAABgUegWaetK1nbaJkX2rnUfXp9PNbh10AwAsHhsKnmtf3LC7BB13uHpvfMAAGNvecmy/skJlEPAq/snAQAWg9xmZNLlNiqPxGQvrgAAJlDue5ZDhCn3msvFEJNoZcmKzutRb5QMADA0H5dsiLpZ8PqSl6c3T4TccmVj1EUV+Xtmlk57BwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABPoHw27F1VmZziZAAAAAElFTkSuQmCC>

[image55]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFkAAAAaCAYAAADcx/BtAAADoElEQVR4Xu2YXagNURTH/0IR8lUkdJFIvhMlKQ9uKF+hkJISKUooStQtlI+UEJIS5QUvikgeDl6E4kGRyEchPIjiQYn1t2Y3e/aZPR/XmTluza/+3XP3mjNn7bXXrL32ABUVFRUVHYHOogGiQaKBoq6WjZ97WP+XCf2Z6w7mpCf0PlQfx9YLOvfC6CSaILom+iX67eiYaKLogWhH8J0yoX+7RK2uIQNMis2id6if1wvoPbeInkODXwjMzgMIf/ikaBh0YqS/6IRlb0aQR4pOibq7hhQmQQNpArpE1C2wMWsZ4LeB/Q0KCjIDuR1hAPnZBNeGC3EazQlye7O4BZqd9Jl/+X8c00RfUGCQx4o+Qx25J+odNUcYB3Wm7CDTxzPIl8VcmCMIk2dF1ByB1x5HgUFmwIwj+xybC2vbLZQbZAZgr2ima0hhsOg1dF4fRCMi1nrmQa9veJA5gQsIg7w1av4v4NPDPcLucLIwVfQDOq+X0C6pKbCdqSEM8oKI9d9g1g93Bz2shG4+cfom+uiMPYRuhElwLmZeNehcm4KbyW4ZYPYwA0xfaYt9tK+nNPUwrfykMQXaUXRxDRmwMzmu1rJHdudkZC8IrzsP3TgfQxeM4v61Dv4YRNgEf03mJL8HNldxjhvMbn3ONeSAgT0M9aE9MDmeQn2Nq8n0zZ2TL9n6iu6LFlpjLGPvRbOsMS987Hgxb57UXdgbpOuEDTuANtEh0WVky0L2rW42zYFm8dAYGwOYVqP5NO1B6LOvu+D9mDBJiTMGmsX2QnHxGbfp1lgi2xA64+uTswZ5MXR1eU0N2Wphi2iZpeWim1Bf7HGjRaJ+f7+ZzBCE2ezrk7MEeRWic+FvX4dWgbhYxcK6Yh9IrojGB+OEG9gdy+4LMus0bcwybjw8gvNRywuz4yByTCABPqlPoH5/Fa1F+LTST9ZV8xrBF+Sjotui3dCn9IZoPTLWY5fRorOinwgDanRRNBu6gsx8FwaELeBOaLbxmO5zOglOnAcDHkAaBUvYatEz1M/rk2gN9N0Gy6Xrb1w9NmMbrLF2YXbfLPWPMCgbEa2p7E9Zz/LAQwcPH43I4jjsjsl9CxdHXD3m27q70AwvDTreBi0XBm4M7GnzdAfMOG52aT1wmbj1mCyFdiyTrbFC4XH0EfQ14vxgjKt/CVrrWF5mBONptEJfBBWVxXlglu+HlphX0JdjFF8rXBWNCi/tOLCNYy3mJltRUVFRUdFw/gDepeMJS/SnNwAAAABJRU5ErkJggg==>

[image56]: <data:image/png;base64,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>

[image57]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACsAAAAZCAYAAACo79dmAAACNklEQVR4Xu2XPUgcQRiGv6ABRSUaxSCmSbARS41BUGwNQYQ0BlIklQQrEdRWC0tBFCxS+FOIKdJqIRYXAkGwNp1IggQUxCatSd7XuYHZ72ZuZ++4a7wHHlZn1m/fm5uZHUVqVJYHsB125a/8vZo8hI90Y4hmuA934RxsSHZXHIZdhW90hw+G3REzsi4c4ZdwDW7A17AucUc2GuEH2KraCb/RAzioOzS+sAw6D7/CZ2KKceQ/iRmJWB7DSbgNb+BPKRwUyxg8FJMniC9sP7yEw07bczEPY9FYGHYCDsDPUjws5+13+FZ3uPjCLkth4Rb4DW5JaYuQz9A1NXzuF1ivOyw6LBcYF5wuzPty8AS2Oe2xxIR9Jeaep7rDosPaULpwqD2WmLCcfhfwhe6w6LC8sqguXI2w9tnjusOiwz6BZ1JYuJph3+kOiw4bChVqjyVL2FndYdFhuRK5InVhG5Y7AneGrGQJGz0NyAK8hr1OWwc8FfNGs/AF0Zm/phETlnv5bzG7ghdf2B4xq9LdoEfgFRxy2lbgP7jotIXgM1gzuC2J2QW4XtxBSuALS3iwOIdT8D38Aacl+UKYgX/hkZg6Go46p80fMR+K3ooJ/dG5z8KFlRN/rTtCYQnPBJw/lD/74PRYh026IyNcK3uS8i0VCxsDpwUPPeXCqXecvwYpJyz/dhP26Y6McGotifnQ7jQroJywXAijurEEuHi5Xab+x8C5xuPbr/y13LmXlW4xp63UoDXuPf8BC8FxdXPzX4QAAAAASUVORK5CYII=>

[image58]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAC4AAAAaCAYAAADIUm6MAAACRElEQVR4Xu2WT0gWQRjGHzFBKcgsMCGIsu6BQQf/dBFJooggCjwIShHhQSoQOvkHDwoSRpJGFBWhQZ36I5QXuxrVRU+CCYKHDp1LIp+Hd4Zdp892tct+tA/8+PbbeWfm2XnfmV0gV65cRaEO8p7sDRuyrHLyxqHrotEBskIGw4asahepIRfIGrlEqklZPCiLaif3yRL5QZ6RO6Q2HpRV/Tf13US+k8dhQ6C0caHk4xc5EzaEaiY/3W9aadA0hs4jXVwo9Uk0fousksNhw1+U1njauFCJxn19z5CdsNNkGFY+pbDT5jW5TQbIW3IQGw2VkEYyRibIRVhfSXGvyE3YONdIhWs7ATsIRkkvbH6vROP7yDyi+lZqu2FmTpFJsoOcJS/JUdjDxY2r7Ym7r3595IZrU9wHstv97yL3YGOOkwex+yPuWko07idaJM/dtT/DryMy10BmyR733xuXgRekx933bXOw2LBU6sgCorLUA7WQIWyMSzTuVemIS6srs1dhAykbXt6Q0qsyC40ri8pmIeNfyTFYVpTFQ/gzLrXxQmol52CrEr5J4xPJ9F1Y9iSlXSWgbChOLzXfpvJ7R46QL7AHkdpg4+lXi/FPxpXOZfLb8ZmchK2WJv8GO5H0NalN1g/bH1NkP0ynyUPYw12BZUf9tRCq9UekE7bxP8H22mXYm/wjbPG2JK2WVk2nhddxMo2ozkPphNK3TyHJaBWilfdS/GZ9tiVNoA2jo81PVk+eIjrOMiudxUq1SkCp9PWXK1exaB3o+Wxm+0SVIQAAAABJRU5ErkJggg==>

[image59]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACUAAAAZCAYAAAC2JufVAAACD0lEQVR4Xu2VP0hVYRjGnxChMJFIkkKwG1G0CVESZJODIkZoQVjQFuHoUNAaLaENDQU5REPg0JguDiougpNDCkJEEYlCTTlYgz7Pee+n333POfdeErfzwI97z3P+vM/3fef9DlCo0OHpGBkmb8kLcrHydN3qIJPklPOPkC7yirwm/aSh4gqnFjJDnpHjpJOskKH4ojrUSN6Rb+R05CvQYzJPSuQk+QCbAN2TqSdkiZyIvHtklbRFXi3dIf+QDnWZbJDrkXcOdl1v5O1JQRTovfOvkD/kpvPzdBY28k9Ih3qe4TWTBdjMaiYrdIn8QjqURrcFe2AtaQnGyVXYc+IAR8mU8yS9JnNIr1CiUDwvlPezpHdvFDZiHyoUzwvl/UQDZAfp4vWGUrdNwJpF8qH0q2NfvGqoPvx/KC3bGKzVg3woNcoX50lVQ+UVz/NjqQnCsgX5UHnF8/xEas11pIuHUE+dH+sl+e74C5v5n7BNVMv6EeniIZQ6UJ1YoXBSHaJOCeqBFdBvkAqcQUYLR/IzJWkfVIer04NayWfYDp+p+7BRlsrHKqrdfRH7L7B24WWyTa6VPS/dp536B2mP/PNl727kdZNN5D8reWHfkFlyCxZIo9DnJkgzOk3WYB3n9Yj8hi2d0Cxr+ZrK5wfJV/KQPIB9xkZQfdaTkxfIbXIDVb5JB5BmW1uQ0P9ChQoVqqVdb8t4th7klVIAAAAASUVORK5CYII=>

[image60]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACUAAAAZCAYAAAC2JufVAAACWUlEQVR4Xu2VS0hVURSG/6igqKxQlKKwGvTCQRAqTUSloAZFlFBYZCMbNopMKIJwoERNDMGJGTQIimhQEApJk15SBD0gaBJEI3FiQonl/7POdu+z7z0HI5ydHz7OvWu/1j7rcYBChRZPK0k7GSR9ZEd6OFcV5Dxs7WWyOT2MFeQMqUt+LyWbSCfZ4qeltZaMkGtkNdlDPpHj4aQM1ZKn5CDZQJrJe3IsmLOOvCJ/I66T5cG8lC6SN2R9YDtFPpOawBZrCelH2gFJDj6HXVbSRR+TD+QruU0aYevLSo7IoeHIXk+myJHIHkqHjZGzaTP2knH4C2me9tebXJB2kQmUOqWNf5KeyB5qGblPfpMLsFDo9pfIQDIu/bNT7vAsp2J7rAYyCcuR1+QmeQgfOklO3SM3YCH8Th4hJ8kPwzaMD1+oU1IL+QWfwFdg1ewkp1QMJ2BvUqiovsAKpUSH8H9OqVLfkqOwsM3C9rsD75icWJM8nZSz0+RqYJtX1uFZ9lDVMIfC6ttN3pE/sCrMktt/lKyKxrCN/EDp4W5Rd2QPpbesHKmK7Ko6tRO1GqmXzJAD8zP8/mOw8Kbkylp9RN3WaT+sqvR0UvJuhA+D8jHub5LG75JzyX9dWGENnXLhG0JGvzpNvpGtyX+XiC/hq6gS1qmV0PsSmz4VsimBQ+0kL+D3O0m64A/XU/mnqlX1lpX6i/rKM1jCyqGPsCR20ht9gtKKkYMKvxJbhytUCl1rMEf73yIPSAdsrnqjwp8reb+dtJEm5HyTykhztSZvbbh/M9KpUqhQoUJZmgM9u3fghjy0PgAAAABJRU5ErkJggg==>

[image61]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEYAAAAXCAYAAAC2/DnWAAABlUlEQVR4Xu2XzytEURTHj1A0itiQJDYSyUIsbVCynAVrGxtlxcbCH2DJQiL/gIWFYqEUys5WKRvJxsJf4Mf325mn+04j7738uJf7qU8z3TNvenPePefcEYlEIpGfZQ6+Oj7D+4p8z7Wt90//E2rgHryDk7DWiY3CJ3gCm531onTATXgIW0zMOzrhJRww6/3wFt7AbhPLSw/chUdwSPRheM8EXDVrTAQT8ghHTCwr/PFMApOxD/vSYf+ZEt0dCSwZlg5LiKWUFyZkDJ6Klk1XOhwmjXBHtOGWTewz2Jtm4Dlch23pcLjUw23RCbQi+fvAMnyQYrvMW5gEJuOl8pokpQ4OiyYtC0E22Y/gzc+Klg93jJuEXrghmqA8JGOZfYb9JsgEsZcwKdXOKotwwazlgX2G/YZ9h/3HPSN5TXKAO4PtJsaRfQEHzXoRSnAJXomesrOW5q+QnFXsAY43PQ6v4bHopPoq+F3z8AC2mpgX8AmyQbr/j6rJUopEvocG0WmURTblICdVEaZFx30W12CTXhaJRP4Yb1IRSeTMnypiAAAAAElFTkSuQmCC>

[image62]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJ4AAAAXCAYAAAD6OvZrAAAE60lEQVR4Xu2aa6itQxjH/3KJOO7XqHOOpIQkIUIKJxIJdZSTjySUS1IkR/LBBwqnjlBuSUcKhdxiR7mXfJAiH8glJBFyKTw/z8xZs2bNmrX3a5112eZX/9Za86537Xfeeeb/PDPvlhqNRqMxmq1Nu5m2yg9k7GTaPm9sNHIIpINNa0w7Zsci25puNZ2bHyiw0vREeJ0l6Bt9pK+jJk9jC7ODaaPpftMVpjdNB/R9w7nGdIcWP2Anmp4y7ZIfmBLHmd42XWx6Ut6fxpTAxe41PRDekx6fNV2Xfsk41PSuaXXWDgQiTvig+tMr7Rs0+FvT4BjTp6Zjw+dTTR+b9t/8jcZEWWv6xnRY+EywPBoUnS0GECq53Z6mD0135QfkLvORygE7KXDc19R//Uebvgyv4+JK0xl5Y2OQPUzvmB4zbRPaWBQsBPEecAXcAZcoweD9arowPyBfiOCUpWOTYp38+pgEkbNMf4fXcYGzj/P3li0XmP4Kr5H9TJ+p3/EIONJUXvftKv/+taafTCeb9pavfFOoHdPfmyS43VtBaa1JkBCM43S8roHHfVklL3VKsCA6JbzOPTgcTve16cCkPbpXmja5oQvqOSBsZ7paXht+F8T72+ROmsL5r5tWZO2TAJf7XV6DRmI58b3pkKT9v9I18E4zvaD++5tyg9ydL8kPzCP7yF3sD9PniX6WdzJNjQ/Jt0ZiOk6p1XcRBgMXxR1r3Kj+axml5027/3vmcJgc9Odb9c77KrRRAlAKjIsugceOwib1Fj0ljpBfP32Ze44y/aL+gCGwCLDcCQg8VKJW30UYjNxZJwXXnffnBNOf6vUdBzzJdIu8bNg5tA+DlMjEZSKl4vyLCu2l8iOCI9+p3qTmWriXZ2/+hkM2qS1czjF9YTozPzBrxOI6DRhWnlx8utiAWuBh//nA5vC3qAGZuZMkLpRyZ1svT78MOjDI98gDCud5RO5EwzhevgWV6z3Ti4V2AmsVJxa4XP2LtpiJ0tKAsbhb9YlLHc143p4fmDUIhry4ZpFBGxu/KcMCL9ZK+cDmLDbVEii5W9RUcxKIgZcubOJi43F5oEWXjymSc56Tu+JS6ZJqCSiyT4T3lAJxUsBB8gCuPYLEpXHt2oSZCbix7N/FTnPB1EwbNVjLMfte1uCqKtZ3zDZgUcGTjbxIxlWZxczmGoebzl+CSD21Gx2DKp00p8v7fWT4HPuQBt6C6qXDMLoEHik0Tatr5RN5r/CZyYEbpzsPcw1BQGogAHEDLP8llR9vkU4ZHAYphfRKmmWQ+A02UEvPca+XPw2pzdgtBf2KC6N95X0+LzmOc+LGeeARREulS+BRZ1L/snC4z/SbfIvrFdNlpvfl6TufzHMNA/CBfGAIDAamBK74iQbrONzmYflg8huXanCvLrpOl4EcB0wk+sY1cJ0U/+k1TjvweJT3g7w++1G+OOAZMp/RGxrcP10WcKPZCK4R66JS+mEQSbHDZuRq+SOztGaZNNSBuHVpg3aFfI8xD7ySc4+iS+ABmYAMlF4fY8J9zSfy/w4eO1F012qqEpy3SeVBnwUY2A3qTSoC9FUNuvtiYLXb5bxGBZzgGfku+2JhxhKspJNZZqU8HRM4N5muUnOamYIBejq8joKBWy+vV+ZhEOOm8KiyozElSCU3y5/V1lgj/4fLeQi6RqOxnPkHi2XwMbhtla0AAAAASUVORK5CYII=>