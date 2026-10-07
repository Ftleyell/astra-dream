# **Arquitectura de Alto Impacto para Interfaces de Acción en Godot 4: Análisis y Pipeline Cinemático Estilo 32-Bits**

El diseño de pantallas de título y transiciones de alto impacto en los videojuegos de acción retro —particularmente ilustrado en entregas de la era de 32 bits como *Mega Man X3* y *Mega Man X5*— se fundamenta en la modulación extrema de la energía cinética percibida. Lograr que una interfaz interactiva despierte una respuesta sensorial visceral requiere sincronizar aceleración no lineal, descompresión temporal mediante microcongelamiento de fotogramas (*hitstop*), retroalimentación luminosa de alto rango dinámico (HDR), dispersión balística de partículas y desestabilización óptica controlada1.  
En una disposición asimétrica dividida estrictamente al 50%, donde la mitad izquierda concentra la violencia visual del logotipo y la mitad derecha alberga notas de parche y texto crítico, el desafío técnico no solo radica en elevar la espectacularidad, sino en garantizar una estricta contención espacial para preservar la ergonomía de lectura y la estabilidad visual del usuario3.

## **Fundamentos Cinemáticos y Confinamiento Espacial de Pantalla Dividida**

El aislamiento visual es el pilar arquitectónico que permite detonar efectos explosivos sin contaminar los paneles informativos adyacentes. Cuando se ejecutan efectos como aberración cromática, temblores de cámara (*screen shake*) o dispersión radial de partículas, cualquier desbordamiento hacia la mitad derecha destruye el contraste y fatiga la visión periférica del jugador5.  
Para maximizar el rendimiento sin sacrificar fidelidad gráfica, la arquitectura óptima prescinde de leer la pantalla global (hint\_screen\_texture) para las distorsiones del logotipo, operando en su lugar con transformaciones directas sobre el espacio de textura local (![][image1])7. Simultáneamente, el contenedor izquierdo se configura con un nodo de interfaz que activa el recorte de contenido o se encapsula en un sub-árbol dedicado, garantizando que ninguna partícula con velocidad terminal escape hacia el panel adyacente8.

| Método de Aislamiento | Impacto en Rendimiento | Confinamiento de Shaders de Pantalla | Confinamiento de Partículas | Idoneidad en Diseño 50/50 |
| :---- | :---- | :---- | :---- | :---- |
| Control.clip\_contents \= true | Despreciable (recorte por tijera / *scissor rect*) | Nulo (los shaders con hint\_screen\_texture ignoran el recorte)7 | Total (restringe la rasterización de quads al rectángulo)8 | Excelente para partículas y geometrías UI nativas |
| SubViewportContainer \+ SubViewport | Medio (requiere un búfer FBO adicional fuera de pantalla) | Absoluto (el espacio de pantalla se circunscribe a la textura del Viewport)11 | Absoluto | La solución técnica definitiva para efectos de distorsión global |
| Shaders Per-Item (Espacio UV Local) | Muy bajo (una sola pasada de fragmentos sin muestreo del backbuffer) | Total por diseño matemático (las operaciones no leen la pantalla)7 | No aplica (se gestiona a nivel de material de sprite) | Ideal para logotipos vectoriales o rasterizados individuales |

La organización jerárquica de la escena se estructura desacoplando la capa de animación, el ancla de perturbación física y la interfaz de datos:

* **MainLayout** (HBoxContainer configurado en pantalla completa con separación en cero)  
  * **LeftPanel** (Control, con banderas de tamaño horizontal SIZE\_EXPAND\_FILL y clip\_contents \= true)3  
    * **BackgroundParticles** (GPUParticles2D, emisor continuo de ambiente)9  
    * **VFXAnchor** (Marker2D, nodo pivote centrado para absorción de sacudidas)  
      * **GhostSpawner** (Node2D, gestor de imágenes residuales en tiempo de ejecución)  
      * **LogoSprite** (Sprite2D o TextureRect, receptor del material de shader dinámico)  
      * **ImpactSparks** (GPUParticles2D, sistema de chispas explosivas unidireccionales)9  
      * **ShockwaveRings** (GPUParticles2D, anillos de choque de alta velocidad)  
  * **RightPanel** (PanelContainer, con SIZE\_EXPAND\_FILL para notas de parche y menús)

## **Fase 1: El Impacto de Alta Energía**

La llegada del logotipo debe sentirse como un impacto cinético dotado de masa real. Para superar una interpolación convencional, la secuencia integra simultáneamente una aproximación acelerada, microcongelamiento de fotogramas, sacudida no lineal localizada y un fogonazo de luminancia cegadora1.

### **Cinemática, Sobreaceleración y Deformación Mecánica**

El movimiento inicial trasciende la clásica traslación lineal mediante la combinación asíncrona de escala y trayectoria balística. El logotipo se inicializa fuera de la vista superior con una sobreescala masiva de ![][image2] y desciende hacia su punto de anclaje mediante curvas de interpolación que transmiten inercia gravitacional1.  
Godot 4 proporciona enumeraciones matemáticas de interpolación que permiten modelar este comportamiento con precisión. Al seleccionar Tween.TRANS\_QUAD combinado con Tween.EASE\_IN durante la aproximación, el objeto acumula aceleración continua hasta el instante del contacto1. En el instante cero del choque, se transiciona a una respuesta elástica calculada (Tween.TRANS\_ELASTIC o Tween.TRANS\_BOUNCE con Tween.EASE\_OUT)1.  
Para acentuar la compresión física (*squash and stretch*), la escala debe deformarse instantáneamente en el plano cartesiano: en el momento exacto del aterrizaje, se comprime en el eje vertical (![][image3]) y se expande en el horizontal (![][image4]), antes de retornar elásticamente a su proporción neutral de reposo1.

### **Microcongelamiento de Fotogramas (Hitstop)**

El recurso cinematográfico definitivo para comunicar solidez física en los clásicos de combate de Capcom es el *hitstop*: pausar por completo el flujo temporal de la simulación durante decenas de milisegundos en el momento de contacto1. Si el tiempo simplemente se detuviera manipulando variables de script, el motor congelaría también las llamadas asíncronas convencionales. La solución nativa en Godot 4 reside en modular Engine.time\_scale mientras se aguarda un temporizador desacoplado mediante el argumento ignore\_time\_scale1:

GDScript  
func trigger\_hitstop(duration: float \= 0.08) \-\> void:  
	Engine.time\_scale \= 0.0  
	await get\_tree().create\_timer(duration, true, false, true).timeout  
	Engine.time\_scale \= 1.0

Este hiato de ![][image5] suspende todo el árbol de procesamiento del motor, grabando en la retina del jugador el fotograma de impacto exacto antes de permitir que la energía residual continúe su curso1.

### **Sacudida Localizada Mediante Trauma y FastNoiseLite**

El temblor de pantalla clásico basado en números pseudoaleatorios genera aberraciones visuales erráticas y desarticuladas. Siguiendo la fórmula clásica de trauma cinético, la intensidad del temblor disminuye exponencialmente a lo largo del tiempo mientras el vector de desplazamiento se muestrea desde un gradiente continuo usando FastNoiseLite6.  
La traslación del elemento se rige por la relación matemática:  
![][image6]  
donde ![][image7] es el vector de amplitud máxima, ![][image8] representa la función de ruido continuo y el exponente ![][image9] asegura que las perturbaciones menores decrezcan con suavidad mientras que los impactos máximos retengan violencia perceptible6. Al aplicar este vector exclusivamente sobre el nodo VFXAnchor y no sobre la cámara global del sistema, la mitad derecha que aloja las notas de parche permanece completamente estática, eliminando interferencias de lectura.

### **Partículas Explosivas y Parámetros del Choque**

En el frame exacto del impacto se emiten ráfagas unidireccionales (*bursts*) mediante sistemas GPUParticles2D configurados con la bandera one\_shot \= true9. Se desacopla la emisión en dos sistemas especializados: chispas balísticas de alta fricción y ondas de choque anulares de disipación rápida.

| Parámetro (ParticleProcessMaterial) | Valor: Sistema de Chispas | Valor: Anillo de Onda Expansiva |
| :---- | :---- | :---- |
| emission\_shape | Point | Ring (radio interior: 10 px, exterior: 25 px) |
| amount | 48 partículas9 | 1 partícula (quad de malla expandible) |
| lifetime | 0.45 segundos | 0.25 segundos |
| one\_shot / explosiveness | true / 1.09 | true / 1.0 |
| spread | ![][image10] | ![][image11] |
| initial\_velocity\_min / max | 450.0 / 800.0 px/s | 0.0 / 0.0 px/s |
| damping\_min / max | 90.0 / 120.0 | 0.0 / 0.0 |
| scale\_curve | Curva decreciente (![][image12]) | Curva hiperbólica ascendente (![][image13]) |
| color | HDR Color(3.5, 2.5, 1.2, 1.0) | Color(1.0, 1.0, 1.0, 0.8) |

## **Fase 2: Asentamiento Dinámico, Desgarro Digital y Flujo Secuencial**

Tras la descompresión temporal del hitstop, el sistema no se estabiliza de inmediato; experimenta una disipación energética caracterizada por el rastro cinético de su trayectoria descendente, distorsiones electromagnéticas en su estructura y la posterior entrada en cascada de la interfaz secundaria7.

### **Estelas de Velocidad Cinemáticas (Afterimages)**

En la animación interactiva de alta energía, las siluetas residuales comunican desplazamientos supersónicos. Durante la trayectoria de descenso del logotipo, se capturan instantáneas visuales del nodo de sprite cada intervalo infinitesimal (![][image14]), insertándolas en el árbol de escena como clones traslúcidos teñidos con modulación aditiva de color16.  
El clon hereda la matriz de transformación del logotipo en ese instante y se somete a una interpolación lineal de desvanecimiento rápida:

GDScript  
func spawn\_ghost\_trail(source: Sprite2D, container: Node2D) \-\> void:  
	var ghost: Sprite2D \= Sprite2D.new()  
	ghost.texture \= source.texture  
	ghost.global\_transform \= source.global\_transform  
	ghost.modulate \= Color(0.2, 0.8, 2.5, 0.65) \# Cyan incandescente en HDR  
	container.add\_child(ghost)  
	  
	var tw: Tween \= ghost.create\_tween().set\_parallel(true)  
	tw.tween\_property(ghost, "modulate:a", 0.0, 0.22).set\_ease(Tween.EASE\_OUT)  
	tw.tween\_property(ghost, "scale", source.scale \* 0.92, 0.22).set\_ease(Tween.EASE\_OUT)  
	tw.chain().tween\_callback(ghost.queue\_free)

Al utilizar valores de color superiores a la unidad (![][image15] en el canal azul) y habilitar la canalización de rango dinámico del renderizador, estas imágenes residuales interactúan directamente con el búfer de brillo (*glow*) del entorno18.

### **Glitch Digital y Aberración Cromática en Espacio UV**

En lugar de procesar la pantalla completa mediante costosos muestreos de textura del búfer posterior, la distorsión analógica se sintetiza directamente en el fragmento del logotipo dividiendo sus coordenadas verticales de textura en bandas discretas mediante cuantización modular7. Si se detecta activación de glitch, los canales ![][image16], ![][image17] y ![][image18] se muestrean con desfases independientes sobre el eje horizontal, emulando la desincronización de haces catódicos de pantallas CRT15.  
La ecuación de división cromática horizontal sobre la coordenada normalizada ![][image19] responde a:  
![][image20]  
donde ![][image21] representa la magnitud del desplazamiento y ![][image22] define la densidad de las franjas de desgarro15.

### **Coreografía y Cascada de Atención**

El panel derecho que hospeda las notas de parche debe mantenerse invisible e inerte durante la violencia del impacto inicial. Introducir estímulos simultáneos en ambos hemisferios de la pantalla satura la capacidad perceptiva y arruina el clímax emocional del impacto.  
La coreografía temporal establece una pausa obligatoria mediante tween\_interval(0.15) una vez consumado el impacto primario1. Tras completarse el primer ciclo elástico de asentamiento del logotipo, un evento de señalización desencadena la revelación del panel informativo mediante un barrido vertical de escala (![][image23]) acoplado a una curva de alfa ascendente (![][image24]) en ![][image25] segundos con Tween.TRANS\_BACK1. De esta forma, el ojo del jugador es guiado en una progresión natural: choque cinético a la izquierda, absorción del impacto y posterior lectura fluida a la derecha.

## **Fase 3: Estado de Reposo Activo y Post-Procesado Lumínico**

Cuando cesa la violencia del choque, el logotipo no puede quedar como un recurso estático sin vida. Para mantener la atmósfera electrizante de la saga espacial, se establece un bucle de latido continuo, un destello luminoso periódico que recorre el texto y una sutil niebla de partículas en suspensión detrás de él9.

### **Oscilación Mecánica y Latido Asíncrono**

Mediante la propiedad set\_loops() del interpolador nativo de Godot 4, se encadena un movimiento sinusoidal asíncrono que simula levitación o respiración biomecánica1. Para evitar rigidez estocástica, la oscilación vertical no se sincroniza numéricamente con el ciclo de escala, introduciendo una diferencia de frecuencias que confiere organicidad al sprite:

GDScript  
func start\_idle\_loop(logo: CanvasItem) \-\> void:  
	\# Bucle de respiración mecánica en escala  
	var tw\_scale: Tween \= logo.create\_tween().set\_loops()  
	tw\_scale.tween\_property(logo, "scale", Vector2(1.025, 0.985), 1.6)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)  
	tw\_scale.tween\_property(logo, "scale", Vector2(0.985, 1.025), 1.6)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)  
	  
	\# Bucle de flotación vertical desfasado  
	var base\_y: float \= logo.position.y  
	var tw\_pos: Tween \= logo.create\_tween().set\_loops()  
	tw\_pos.tween\_property(logo, "position:y", base\_y \- 5.0, 2.1)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)  
	tw\_pos.tween\_property(logo, "position:y", base\_y \+ 5.0, 2.1)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)

### **Barrido de Luz Espectral (Shine Sweep)**

El barrido lumínico genera un haz blanco-azulado que cruza diagonalmente la geometría del logotipo a intervalos regulares20. Se computa proyectando el vector ![][image1] contra una dirección angular normalizada.  
Definiendo un vector director ![][image26], la proyección escalar de un píxel viene dada por:  
![][image27]  
Un pulso temporal cíclico ![][image28] desplaza el centro de una campana suave conformada por la función smoothstep, sumando su contribución fotométrica al canal RGB únicamente donde el canal alfa del sprite original es positivo20:  
![][image29]  
donde ![][image30] representa el grosor del haz, ![][image31] su velocidad de traslación y ![][image32] el período de reposo entre barridos20.

### **Micropartículas Ambientales y Resplandor HDR 2D**

En la retaguardia del logotipo (índice Z inferior), un emisor continuo GPUParticles2D mantiene fragmentos digitales y bits de datos flotando verticalmente en un flujo ascendente continuo9. La contención espacial se asegura asignando un volumen de emisión restringido a un rectángulo estricto dentro de la mitad izquierda9.  
Para intensificar el brillo retro sin alterar las texturas originales, se incorpora un nodo WorldEnvironment configurado para 2D. En el panel de configuración del proyecto se activa el soporte de luminancia en coma flotante mediante la instrucción RenderingServer.viewport\_set\_use\_hdr\_2d(get\_viewport().get\_viewport\_rid(), true)18. El recurso Environment asociado opera con los siguientes valores calibrados:

* glow\_enabled \= true  
* glow\_levels/1 \= 1.0, glow\_levels/2 \= 1.0, glow\_levels/4 \= 0.5  
* glow\_intensity \= 0.8  
* glow\_strength \= 1.15  
* glow\_bloom \= 0.2  
* glow\_blend\_mode \= GLOW\_BLEND\_MODE\_ADDITIVE  
* glow\_hdr\_threshold \= 1.0 (los píxeles estándar de la UI derecha quedan intactos; solo los valores de color mayores a 1.0 en la izquierda emiten radiación difusa)

## **Implementación Completa: Ensamblaje del Pipeline y Código Fuente**

A continuación se detalla la integración técnica integral: el shader que unifica destello, desgarro analógico y barrido de luz, seguido por el script en GDScript encargado de dirigir la coreografía cinemática7.

### **Shader Multifunción del Logotipo (mega\_man\_logo\_vfx.gdshader)**

Este material opera íntegramente en el espacio del ítem (canvas\_item), prescindiendo de dependencias externas del búfer de pantalla y garantizando una tasa de cuadros estable sin fugas visuales hacia el cuadrante informativo7.

OpenGL Shading Language  
shader\_type canvas\_item;  
render\_mode blend\_mix;

// Controles de Flash (Fase 1\)  
uniform float flash\_amount : hint\_range(0.0, 1.0) \= 0.0;  
uniform vec4 flash\_color : source\_color \= vec4(1.0, 1.0, 1.0, 1.0);

// Controles de Glitch y Aberración Cromática (Fase 2\)  
uniform float glitch\_intensity : hint\_range(0.0, 1.0) \= 0.0;  
uniform float glitch\_frequency : float \= 24.0;  
uniform float chromatic\_separation : float \= 0.035;

// Controles de Barrido de Luz Espectral (Fase 3\)  
uniform bool shine\_active \= true;  
uniform vec4 shine\_color : source\_color \= vec4(2.0, 2.0, 2.5, 1.0); // HDR Glow  
uniform float shine\_speed : float \= 0.8;  
uniform float shine\_width : float \= 0.15;  
uniform float shine\_angle : float \= 45.0;  
uniform float shine\_pause : float \= 3.5;

float random\_noise(vec2 co) {  
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) \* 43758.5453);  
}

void fragment() {  
    vec2 uv \= UV;

    // 1\. Desplazamiento por Franjas Horizontales (Glitch)  
    if (glitch\_intensity \> 0.0) {  
        float band \= floor(uv.y \* glitch\_frequency);  
        float noise \= random\_noise(vec2(band, floor(TIME \* 25.0)));  
        if (noise \< glitch\_intensity \* 0.7) {  
            float shift \= (random\_noise(vec2(noise, band)) \- 0.5) \* glitch\_intensity \* 0.12;  
            uv.x \= clamp(uv.x \+ shift, 0.0, 1.0);  
        }  
    }

    // 2\. Muestreo con Aberración Cromática Local  
    float chrom\_offset \= chromatic\_separation \* glitch\_intensity;  
    vec4 tex\_r \= texture(TEXTURE, vec2(uv.x \+ chrom\_offset, uv.y));  
    vec4 tex\_g \= texture(TEXTURE, uv);  
    vec4 tex\_b \= texture(TEXTURE, vec2(uv.x \- chrom\_offset, uv.y));

    vec4 base\_color;  
    base\_color.r \= tex\_r.r;  
    base\_color.g \= tex\_g.g;  
    base\_color.b \= tex\_b.b;  
    base\_color.a \= (tex\_r.a \+ tex\_g.a \+ tex\_b.a) / 3.0;

    // Descarte de fragmentos completamente transparentes  
    if (base\_color.a \<= 0.001) {  
        discard;  
    }

    // 3\. Aplicación del Flash de Impacto  
    vec3 mixed\_color \= mix(base\_color.rgb, flash\_color.rgb, flash\_amount);

    // 4\. Barrido de Luz Espectral (Shine)  
    if (shine\_active) {  
        float rad \= radians(shine\_angle);  
        vec2 dir \= vec2(cos(rad), sin(rad));  
        float proj \= dot(uv, dir);

        float cycle \= shine\_speed \+ shine\_pause;  
        float progress \= mod(TIME \* shine\_speed, cycle);  
        float beam\_pos \= progress \- 0.5;

        float d \= abs(proj \- beam\_pos);  
        float shine\_mask \= smoothstep(shine\_width, 0.0, d);  
          
        // Mezcla aditiva ponderada por el canal alfa original  
        mixed\_color \+= shine\_color.rgb \* shine\_mask \* base\_color.a;  
    }

    COLOR \= vec4(mixed\_color, base\_color.a);  
}

### **Orquestador de Secuencia Cinemática (LogoImpactSequence.gd)**

Este script se asocia al nodo raíz de la secuencia de inicio, coordinando la línea temporal asíncrona mediante señales y referencias directas entre los componentes de la interfaz1.

GDScript  
extends Control

@export\_group("Nodos de Referencia")  
@export var logo\_sprite: Sprite2D  
@export var vfx\_anchor: Node2D  
@export var spark\_particles: GPUParticles2D  
@export var right\_panel: Control  
@export var ghost\_container: Node2D

@export\_group("Cinemática de Impacto")  
@export var drop\_duration: float \= 0.42  
@export var hitstop\_duration: float \= 0.08  
@export var target\_scale: Vector2 \= Vector2(1.0, 1.0)  
@export var start\_scale: Vector2 \= Vector2(4.8, 4.8)

var shader\_material: ShaderMaterial  
var trauma: float \= 0.0  
var noise\_generator: FastNoiseLite

func \_ready() \-\> void:  
	\# Inicialización de Ruido Perlin para sacudida local  
	noise\_generator \= FastNoiseLite.new()  
	noise\_generator.noise\_type \= FastNoiseLite.TYPE\_PERLIN  
	noise\_generator.frequency \= 0.08  
	noise\_generator.seed \= randi()

	\# Configuración de Material  
	shader\_material \= logo\_sprite.material as ShaderMaterial  
	shader\_material.set\_shader\_parameter("flash\_amount", 0.0)  
	shader\_material.set\_shader\_parameter("glitch\_intensity", 0.0)  
	shader\_material.set\_shader\_parameter("shine\_active", false)

	\# Estado inicial de nodos: Ocultar panel de notas y posicionar logotipo  
	right\_panel.modulate.a \= 0.0  
	right\_panel.scale \= Vector2(0.96, 0.96)  
	  
	logo\_sprite.scale \= start\_scale  
	logo\_sprite.position.y \-= 380.0  
	logo\_sprite.modulate.a \= 0.0

	\# Arrancar la coreografía  
	execute\_intro\_sequence()

func \_process(delta: float) \-\> void:  
	\# Procesamiento continuo de temblor en el ancla izquierda  
	if trauma \> 0.0:  
		trauma \= maxf(trauma \- 2.0 \* delta, 0.0)  
		var strength: float \= pow(trauma, 2\)  
		var ox: float \= 28.0 \* strength \* noise\_generator.get\_noise\_2d(float(Time.get\_ticks\_msec()) \* 0.1, 0.0)  
		var oy: float \= 20.0 \* strength \* noise\_generator.get\_noise\_2d(0.0, float(Time.get\_ticks\_msec()) \* 0.1)  
		vfx\_anchor.position \= Vector2(ox, oy)  
	else:  
		vfx\_anchor.position \= Vector2.ZERO

func execute\_intro\_sequence() \-\> void:  
	var final\_pos\_y: float \= logo\_sprite.position.y \+ 380.0  
	  
	\# \==========================================  
	\# FASE 1: APROXIMACIÓN HIPERACELERADA  
	\# \==========================================  
	var tw\_in: Tween \= create\_tween().set\_parallel(true)  
	tw\_in.tween\_property(logo\_sprite, "position:y", final\_pos\_y, drop\_duration)\\  
		.set\_trans(Tween.TRANS\_QUAD).set\_ease(Tween.EASE\_IN)  
	tw\_in.tween\_property(logo\_sprite, "scale", target\_scale, drop\_duration)\\  
		.set\_trans(Tween.TRANS\_QUAD).set\_ease(Tween.EASE\_IN)  
	tw\_in.tween\_property(logo\_sprite, "modulate:a", 1.0, drop\_duration \* 0.3)

	\# Generación de siluetas fantasma durante la caída  
	for i in range(5):  
		await get\_tree().create\_timer(drop\_duration / 6.0).timeout  
		\_spawn\_afterimage()

	await tw\_in.finished

	\# \==========================================  
	\# INSTANTE CRÍTICO: IMPACTO Y FLASH  
	\# \==========================================  
	\# 1\. Detonación de Sistemas de Partículas  
	spark\_particles.restart()  
	spark\_particles.emitting \= true  
	  
	\# 2\. Flash Blanco Inmediato en Shader  
	shader\_material.set\_shader\_parameter("flash\_amount", 1.0)  
	shader\_material.set\_shader\_parameter("glitch\_intensity", 0.85)

	\# 3\. Microcongelamiento temporal desacoplado  
	Engine.time\_scale \= 0.0  
	await get\_tree().create\_timer(hitstop\_duration, true, false, true).timeout  
	Engine.time\_scale \= 1.0

	\# 4\. Inyección de Trauma para Sacudida Localizada  
	trauma \= 1.0

	\# \==========================================  
	\# FASE 2: ASENTAMIENTO, REBOTE Y GLITCH  
	\# \==========================================  
	\# Deformación Squash & Stretch  
	var tw\_settle: Tween \= create\_tween()  
	tw\_settle.tween\_property(logo\_sprite, "scale", Vector2(1.35, 0.65), 0.06)\\  
		.set\_trans(Tween.TRANS\_CUBIC).set\_ease(Tween.EASE\_OUT)  
	tw\_settle.tween\_property(logo\_sprite, "scale", Vector2(0.92, 1.08), 0.12)\\  
		.set\_trans(Tween.TRANS\_ELASTIC).set\_ease(Tween.EASE\_OUT)  
	tw\_settle.tween\_property(logo\_sprite, "scale", target\_scale, 0.2)\\  
		.set\_trans(Tween.TRANS\_BOUNCE).set\_ease(Tween.EASE\_OUT)

	\# Desvanecimiento del destello blanco y atenuación del glitch  
	var tw\_shader: Tween \= create\_tween().set\_parallel(true)  
	tw\_shader.tween\_property(shader\_material, "shader\_parameter/flash\_amount", 0.0, 0.25)\\  
		.set\_ease(Tween.EASE\_OUT)  
	tw\_shader.tween\_property(shader\_material, "shader\_parameter/glitch\_intensity", 0.0, 0.45)\\  
		.set\_ease(Tween.EASE\_OUT)

	\# \==========================================  
	\# ENTRADA DE NOTAS DE PARCHE (PANEL DERECHO)  
	\# \==========================================  
	var tw\_panel: Tween \= create\_tween().set\_parallel(true)  
	tw\_panel.tween\_interval(0.15) \# Retardo táctico tras el choque  
	tw\_panel.chain().tween\_property(right\_panel, "modulate:a", 1.0, 0.45)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_OUT)  
	tw\_panel.tween\_property(right\_panel, "scale", Vector2(1.0, 1.0), 0.45)\\  
		.set\_trans(Tween.TRANS\_BACK).set\_ease(Tween.EASE\_OUT)

	await tw\_settle.finished

	\# \==========================================  
	\# FASE 3: REPOSO ACTIVO (IDLE LOOP)  
	\# \==========================================  
	shader\_material.set\_shader\_parameter("shine\_active", true)  
	\_start\_idle\_loops()

func \_spawn\_afterimage() \-\> void:  
	var ghost: Sprite2D \= Sprite2D.new()  
	ghost.texture \= logo\_sprite.texture  
	ghost.global\_transform \= logo\_sprite.global\_transform  
	ghost.modulate \= Color(0.2, 0.8, 2.5, 0.65)  
	ghost\_container.add\_child(ghost)  
	  
	var tw: Tween \= ghost.create\_tween().set\_parallel(true)  
	tw.tween\_property(ghost, "modulate:a", 0.0, 0.22)  
	tw.tween\_property(ghost, "scale", ghost.scale \* 0.92, 0.22)  
	tw.chain().tween\_callback(ghost.queue\_free)

func \_start\_idle\_loops() \-\> void:  
	\# Latido físico de escala  
	var tw\_scale: Tween \= logo\_sprite.create\_tween().set\_loops()  
	tw\_scale.tween\_property(logo\_sprite, "scale", Vector2(1.025, 0.985), 1.6)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)  
	tw\_scale.tween\_property(logo\_sprite, "scale", Vector2(0.985, 1.025), 1.6)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)

	\# Flotación vertical  
	var origin\_y: float \= logo\_sprite.position.y  
	var tw\_float: Tween \= logo\_sprite.create\_tween().set\_loops()  
	tw\_float.tween\_property(logo\_sprite, "position:y", origin\_y \- 5.0, 2.1)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)  
	tw\_float.tween\_property(logo\_sprite, "position:y", origin\_y \+ 5.0, 2.1)\\  
		.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_IN\_OUT)

## **Consideraciones de Rendimiento y Balance Ergonométrico**

La ejecución exitosa de secuencias de alto impacto inspiradas en la estética de 32 bits demanda un balance riguroso entre saturación sensorial y economía cognitiva1. Si el destello del flash blanco se prolonga más allá de los ![][image33], la retina del observador registra ceguera visual incómoda en lugar de impacto cinético7. Del mismo modo, si la detención del motor mediante Engine.time\_scale \= 0.0 excede los ![][image34], la experiencia pasa de percibirse como un choque masivo a interpretarse erróneamente como un problema de rendimiento o congelamiento de fotogramas del ejecutable1.  
Al segmentar la pantalla de forma simétrica al 50%, aplicar perturbaciones locales mediante un nodo pivote dedicado (VFXAnchor) en lugar de sacudir la cámara global preserva de forma estricta la estabilidad visual del panel adyacente6. Además, consolidar las alteraciones visuales dentro de un único shader que opera en coordenadas de textura locales prescinde por completo del uso del búfer de pantalla (hint\_screen\_texture), evitando pasadas redundantes sobre el backbuffer y manteniendo una tasa de cuadros estable y sin artefactos en cualquier plataforma de exportación7.

#### **Obras citadas**

> 1. Game Juice in Godot 4 (Brackeys Platformer) \- Coding Quests, [https\://codingquests.io/blog/godot-4-game-juice-platformer](https://codingquests.io/blog/godot-4-game-juice-platformer)  
> 2. Game Feel Kit \- Hitstop, Screen Shake, Impact FX for Godot 4, [https\://dimensionalmios.itch.io/almios-game-feel-kit](https://dimensionalmios.itch.io/almios-game-feel-kit)  
> 3. AspectRatioContainer — Godot Engine (stable) documentation in, [https\://docs.godotengine.org/en/stable/classes/class\_aspectratiocontainer.html](https://docs.godotengine.org/en/stable/classes/class_aspectratiocontainer.html)  
> 4. Control — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_control.html](https://docs.godotengine.org/en/4.4/classes/class_control.html)  
> 5. how do I make an effect like this in Godot I'm trying to add ... \- Reddit, [https\://www\.reddit.com/r/godot/comments/tewhn8/how\_do\_i\_make\_an\_effect\_like\_this\_in\_godot\_im/](https://www.reddit.com/r/godot/comments/tewhn8/how_do_i_make_an_effect_like_this_in_godot_im/)  
> 6. Screen Shake :: Godot 4 Recipes \- KidsCanCode, [https\://kidscancode.org/godot\_recipes/4.x/2d/screen\_shake/index.html](https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html)  
> 7. Godot 4 hint\_screen\_texture: Full Guide to Syntax & Errors | GTStudios, [https\://gtstu.com/godot-4-shader-tutorial-visual-effects/](https://gtstu.com/godot-4-shader-tutorial-visual-effects/)  
> 8. Draw Light2D only on Sprite (use Sprite as mask and make it invisible), [https\://www\.reddit.com/r/godot/comments/133miz2/draw\_light2d\_only\_on\_sprite\_use\_sprite\_as\_mask/](https://www.reddit.com/r/godot/comments/133miz2/draw_light2d_only_on_sprite_use_sprite_as_mask/)  
> 9. GPUParticles2D — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_gpuparticles2d.html](https://docs.godotengine.org/en/4.4/classes/class_gpuparticles2d.html)  
> 10. Does Godot support masking a hierarchy of Sprites in 2D? \- Reddit, [https\://www\.reddit.com/r/godot/comments/16nyp5p/does\_godot\_support\_masking\_a\_hierarchy\_of\_sprites/](https://www.reddit.com/r/godot/comments/16nyp5p/does_godot_support_masking_a_hierarchy_of_sprites/)  
> 11. Environment and post-processing \- Godot Docs, [https\://docs.godotengine.org/en/stable/tutorials/3d/environment\_and\_post\_processing.html](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)  
> 12. 12 Free Godot 2D Juice and VFX Tools After PolishFX Lite \- 2026, [https\://gamineai.com/blog/12-free-godot-2d-juice-vfx-tools-after-polishfx-lite-2026](https://gamineai.com/blog/12-free-godot-2d-juice-vfx-tools-after-polishfx-lite-2026)  
> 13. Timer — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_timer.html](https://docs.godotengine.org/en/4.4/classes/class_timer.html)  
> 14. Screen/Camera Shake \[2D\]\[Godot 4\] \- Reddit, [https\://www\.reddit.com/r/godot/comments/17e8s6f/screencamera\_shake\_2dgodot\_4/](https://www.reddit.com/r/godot/comments/17e8s6f/screencamera_shake_2dgodot_4/)  
> 15. Lofi Retro Camera Filter \- Godot Shaders, [https\://godotshaders.com/shader/lofi-retro-camera-filter/](https://godotshaders.com/shader/lofi-retro-camera-filter/)  
> 16. Godot 4 Essential 2D Effects — Free Shader Pack by Hollow Pixel, [https\://hollow-pixel.itch.io/godot-4-essential-2d-effects-free-shader-pack](https://hollow-pixel.itch.io/godot-4-essential-2d-effects-free-shader-pack)  
> 17. CanvasItem — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_canvasitem.html](https://docs.godotengine.org/en/4.4/classes/class_canvasitem.html)  
> 18. RenderingServer | Godot Docs 4.3 | ROKOJORI Labs, [https\://rokojori.com/en/labs/godot/docs/4.3/renderingserver-class](https://rokojori.com/en/labs/godot/docs/4.3/renderingserver-class)  
> 19. Double Vision w/ chromatic aberration \- Godot Shaders, [https\://godotshaders.com/shader/double-vision-w-chromatic-aberration/](https://godotshaders.com/shader/double-vision-w-chromatic-aberration/)  
> 20. 2D Shader for Shine Effect? And understanding how it works? : r/godot, [https\://www\.reddit.com/r/godot/comments/10zsdjd/2d\_shader\_for\_shine\_effect\_and\_understanding\_how/](https://www.reddit.com/r/godot/comments/10zsdjd/2d_shader_for_shine_effect_and_understanding_how/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACEAAAAaCAYAAAA5WTUBAAABwElEQVR4Xu2UvStHURjHH3kpIYu8DCJJKYsk5aUMVpLZZiBlMVCySAYlGWyUt1Aoi0UZlL/AIJPBZJIFA3n5fj331LnP79z7o4z3U59+t/Pc37nPOec5j0hGRphl+Aa/PK9hSxTvhs9e7ANOwip45Y1TzjOgf/uhBB6ad2a8eIwaeAdvo2dLAdyFU7DQxAZFJ98x4w6+fwDnYLGJxeiF73Bf9IOWCngEm2wAdMAXeAKLTIx0wT1YagOWcdHV8DdEKzyG5TYgmtgDvJTcOD+8DdvNeA5cOXeAq+GqQgzBRTsY4Y7yHtaZ2ChckPDuxmCB3UTyOcSaaCIhuPpL+Ci6Y45GeAqrvbFEOuEr3JJwxvwIKzxUD4R1wHrgHJyLcB7euqTEc8hXD/w4k7Dn7bMpOgdvCumD65LnNjhcPfirsKTVg2NWNIlpWCmadHPsjRTcebKwkvrDKuw345YR0SSWRBNJ2tUgZfBCtPOxF1h4xzck/7ayS36KNjv2hLSjCzIhWtltZpzHcwYbzHgI17AoE/8zXOUKfILzcAyeizanWu+9NNgf2CdYO6Eb9mvq4bBohYfqIw0upEf0eDMyMjL+lW8TglTTPeAFVQAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,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>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFwAAAAaCAYAAAA67jspAAAEB0lEQVR4Xu2YbchURRiG78ioMPuwMEqjDAlCISRUhBQpAyP6UQQJRUFChShBZFlQKOEPIf0hWBSFGkQI9kUfpPTjFYOsQAjMQhEziigIQSpIybyvnjPu7OyeffdV360XzgU3uztndnbOPc/zzJyVGhoaGgbCOdYj1m3lhYbRYYZ1xNprTSqujQUImDnWBusl607r3LYevbnYetx61Xq2+py4wHpQ4RHvGXeKIkCva3XrHya73jph/WM91n75fw/zf8raaU21LrfeVJh3XtavjlutAwpTr7JWWO9YF1bXL7W+UHiT60X1N34H060PrPsVpn+pmPRY4WbrF+uWrO1667C1KGvrBvf+k3Vf9flK66Diu5gPF1kfKbKfa5sV2cRCj5gU3Q8oVvQTxerxeaywRu0GwQRrl7VJ9caMs16zvrGuqNroS+A9XF0HDN+i9vFPm2mK9EkRTUQQ5butS1KnAtJoviKy8jrJZC8r2kYbairRVxqOSUPWV4o5dYPy86O1zTpfsXfhQ7lAZ81wBl6t9mhOEyXKF2ftCRaB+viktc9akl1boNh452Zto02ab53hZXvOQkVwfWi9Yj1hvWV9ptgUE4y1VVEJKCuUoPd1GhsmK8zqlvX6HtVH+aOKlJtsfW+tyq6R2kRMPtmciYqS9cMI9Ny/36wHMzG1NLYfw+9SBNYfimwFsvdda4diDOB1u6LOE6ToBWu/dW3Vpy+eV/cTCSZjNqZjfoKahgHcANH/p1rRnFIb8X5QdNvkYCSGl3N+WnHvZABgMHtCXmpmKe5/VdbWE6KbH6o7c2MokxlSa6UTGE/q5RnAqeBnxRl2kNQZW9eec4fiHrcU7RhOO691kBFkxqfW+OJaVxhsWdmYkUd5ebRK5YQSkmDyf6sVFd0gQihfGNCvOAP3gsWnLJbGJsM5qRCd3bjJOqrhDV9rHbduP9WjZfiQOgOyg2us9xTp2As2U36YupseAiD9GCmZwHwinEivg/rIXwf3jkCcd4cDY36zbszaOOZx3OPJM0EQXa1WaUhBxYKlIyCUJYUFIZhyw1NJ6XXsPAWRfUydG1SpXxWGl1GeIiMZzsbBBlLWwkHB0ZbNOj9VzVPMf271mcz62vorawP2MOZOEEK3TZNxV6plLK/PKE5ks6u2Wojqb9X5mDqceBJNUc6kXlaM87r1XdWnV80bbdjcDyn+33hIcWRdqpZJmPexOk8W1N9N1h7F99ibWJi8D/e70Xq76vOGIqMoowOBSTIJ6iub7t1qP7H8VxDFZB0qj7q9YFFuUJQwHui4t5K8zwINMJNnKlKJR2Igcki/PAMaziKk0e+Kvz8xmKcv/uyqe9hpOEMoJ+uszxU7/HI1kd3Q0NDQ0NBwppwEGoDrtDx2DHgAAAAASUVORK5CYII=>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF0AAAAaCAYAAADVLFAXAAADiUlEQVR4Xu2YW6gNURzGP6EIkWtuOSQlhIRIOrnFg5IURSi5JC9ILkVHeFB4UEouHZcU5ZqIkg5eXIqIlCjkUgovyCWX7/NfY9aevffZs7djH7vWV7/O7DVrz5755pv/f80BgoKCgsquJmQRGZ/cEfTvNJC8J/dJ58S+SlMVmZUcLKCuZD3ZQ1aSnpm70YLMhfmk7aakByyoVfG09FLKd5Af5CdZkrm7ItSfLCWXyXdyMHN3vZpKzpPBpBPZRD6T6d6cduQGzB+fbaS5Ny+1BpCzZDbM+JukQ8aM/18yfRoZTV4gvelK7TnYUz7UjfUhr8kD0tGNtXbzVAmekANkJCywRStK+RzSklyA3UF9rkSpTDxDcaafgj0d1W5MZUM3TuZ2cWMyXcfU8f9afclJxMmeDEv7ddI2mpRDeqTGOrStGjeMjHHbjaViTZdkvK4/Sm3kwT7SzI01mOn6kY3ITLUOXgdLe75m1AuWDjWRneQK2UtWkYtkezy17CrFdF9K+VVyy21Hki/HYFVBJeYlOYMSmmhvchzZ9VsNJF/aVYJ2w54QSen+SGrIBNj3apG/1rWHlbDnRaBVRVqVarpWbNdgZeU2rKn61yDTFaiZblyo4T6ChTC1NiD3SkVGy3AZ6HdwSWYv9z5PIV9gZaUVLP1+QsqtUk33NY58ggUpWpnI5Dbub6ThiOelklKubpxvTa7SohJTB7vL+bSFPCXdE+ONpYYwXeYq9WquExP7fEVP+SVY4ApqNVmWHPTkp12NJZei+q8SFTWcQlJSVM5kTlq0Rk6rYk3XddbAlst+ivV9hU4+SVvJN2TehMj0OtQfzN/S29ZpxMuhfFKD1Q+rBquWSyodR2E/rrXxW8QnJi0kk7zPSelx1b8aZhSB1sNpVch0mdwNscF6MdI16jv6ruQvJha7MR0vmfyovNTXw/5ICf+K7IaV5A3sh/20r3BjC8h8t60Tl9RQDiO7MZdTkelHkG2EzusurAeNcmNK6zuyGXH9Vt96RR4i7k8qt2sQH1N/18Jeqka4sbxSunUwmVUMemNV2tUwdeK6qFpYB9eb237YEkrpbwxp5aSVh9IYnfMHco8McnOUYL3u+ysOmad/H+ga1sHKzB3ymAxxcyTdkF3kBJlHDsGeci0kyiKdvP8ykfxciVLZUVlUOVP6c73g6fr6weZUw16qgoKCgoKCgoKCgoIqUL8Aa5HPywGzWAUAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADMAAAAZCAYAAACclhZ6AAACrUlEQVR4Xu2WTahNURTHl1C+PflKyEciUhQGlDKQkkgIeWLG5A1IiJHCgJIyVJKBUqSkV8LgRhlQpDBAieTNvBRm4v+7a+979jnOuU9P6qrzr1/dsz/X2muvta9ZrVq1BquRYpe4KM6KRWJIboRrgXk/4xjPvI7SeHFT7BHTxBLxQByyvENbxSuxVIwRJ8U98/kdox5xvNC2WDwTc8L3TPFGdLdGmE0QT8znd4yuiDOWjwIRwhmihHDim1jWGuHjr4qGeaQ6QqfFT3FBjA5tO0SvZUbSV3QGcRB9Ym6hPapLzBIbxXQxQqwJ3xPDmKHm624Wsy1/qPyeL/aLvWKhWJX0/yY2e23u0Ftz5x6G9iiMrnKmrD3qoOg3X5t1L4ud5ofz2TwPr4l94rD5WgeaM92Rc+KUmGHuyC3zPduKgR/MNwUmjAt9RKdh5UYP5AxaIb6LO5ZVP4z7KD6JeaFtmLhh2bWdKp6az4/CThysFAsTCUJJRcM4HHpkfhW4evdDe9HoP3GGPsawfhQ5+d4859JrxXoNc2cmiZfihdhtbudwMTYOLoqTui2OJm1MIpw4FCtVldFV7amiM+RJVHSmeGVSZ9AGyw43pgFPQ6moVuQL4UuFk1yLuBn3vcxo+rkuHECV/sYZFIsGFfeLeaSmJP0tsREPYVk14u0hUdEm8UOszbqbm/QG+F2lwTrDGL5Tx1ab51nxUJti4F1xzPJ3d7L5oivDN7nzWJwI34jEJSpUp3YigSkAW5K2ds6QJ+QLY/iNA1E85thBmS8VRj03d4rHkYiwCMUgdXC5eCeOiG3mrz+hJymrdN48ovHOXzcvwV+TNq45+8bnAejfbl6E2Id5l8yr23obQPHhwsh1lj2eRdFOPw8cf3H+pbBpVPjN40ue0FarVq1atf4P/QKC3JtTybJycAAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,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b016yJIUQxwj5/e1UXodPno2H4FJeLDeH+c9Nn4ay9OLMZO/H9+Vx8xn/x+ZA5T5S2Pksa8zfImIiMjdGgwfBnAsVEavKJKSEQKEpPp6J5En854o3iHykMbyhQBj3rdPREed5JzHl4KF3lokfZ8/mwfsm6EL6gRqBF7dbX9MDLWhpp2Koa2Yr5uf82BdBnIkFwov13lRxj/De0RdvTm2C8Mroxzv8WpaDcecovCkKJ8ianvZcv5TrgXQK/CuKPUrIiJy5MCo8ymSdqygBM9C5u9sxXCvKEQSIa3bYnmohX3eGos9ofCcvLsr74oivPCgkChcG/pHRFmXXk986+26KJ8iQXggyPJYPxFle4iO/NwMv/zP9DurZVmP7d5STUNIMI3xoHIa6yBm+DwO26+3meMjfTjmx4anDLHEZ4n+JYoH7b5RhgfIEBfirfXMPSNKXeI966tvwpr0hGO/hA37xmtiGcTZsmuRuWOtR0tEROTIgDEkyXbIGCI0bo7y/bmx75/hzbk4Fj9l0QfiBsHT5rx8Vsw/43Kf6BcCgFcIT1D9+ZeDQg7+yPGl94o6ztAi4gSxRNd+8qrIwcqQWQ2eJjxJbSgxYd2x8z8eReS0Ic2WU7tye+gVEhGRIw6jGdP7aT8N4hOijBDfJ8AOM3jF3hhlLB88OojCvkEOyc+6rJ04EYQYH+89q53RkGHIOjQpIiJyZLkkShiszT3ZK/D6IAr2U4AdBKhfxAc9zhhGoC+RnLr5vVjt80M1CE1GqV4mcBBLhAPX3Y+IiMihAgP81ijeiP3qUXRSlLwgfo8Kp0X5fhnJz8+Lxd5sQC4V+Urr8IAoCdnL6hRRRr4VwklERERmYEBviP39uDGG/4qufHo74xBCjs97oyRVr/KtxakQeiMZuy+hugaxe3mUJPVl3iMREZEjx+ldeXss9yzI6iBCEEJ8t+2C2Fy+FF372156IiIiUoEgYhRpjeXhg/DbVeG1FRERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERGRI8b/Aut9QmjdPCgMAAAAAElFTkSuQmCC>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACsAAAAbCAYAAADlJ3ZtAAAB1klEQVR4Xu2WTShEURiGP0URhRQpP7OgSIqwETsbCyWFQjYSNhbK74JSSinlN781FqxQkuwkGwuKBWWrlBULUax4374zzZ3TJIupOem+9TT3nO/OzHvPfb97rogvX77irkQwCCrsgouqB1+gxS64pjRwDr7BaGTJPfWDG1GzM1bNKeWDA9AIPsBOZNkdJYA50ZxWiZrdF20250SDmyAJ5IJH0ewyw04pBQRBpRmHzF6BTDPnjNrBpGgUKBqkURqmcWeUDe5Eu9/mBZSGT42vuJJjoMsuiD4J2GTMshNiRoOimbVFs1xdPsaoAFgGG6ANHII1UAzGwSnolnCUmsE8WAcDoo2bAWZFf2MYlIAFM/51a+ftPxP942iaEjXb5JmrAU+gzoy3RE2mgzxwLRqbVDM/JGp+CfSY73A8ArZBgejF0EtUZYELicxmn6feAF6t+i0oEo0Ej0NNx+14whxzjjVvbHJEL3ZXIrduXtwJOAaFnvmYKprZkAmvWd7yFQMXx3teSIzMMyiz5mOmv5q1z+M7xjToNONq0AtaRVeYKx1TBUTfGz7BIugADwYec+4N7IFycCS6fbO5+HkvmuFV8C6a4VrRV9FLCTdy3MTuT7Ynffn6r/oBcF5h1qR4z0sAAAAASUVORK5CYII=>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAZCAYAAAAxFw7TAAABUElEQVR4Xu2TvyuFYRTHv0JRNxIluSVMNmXyYzSYDHdSFv+AhUEZpKxsMjCQgbIYLMpitotEGZTJH0D58f3eM9zznHvf+15l0v3Up+77nvue5znnPA/w3ynSA/pBd0IsoYtO0bYYcAzRB/pNP+l8Gq7QQc/pKx0JMc8G3aejtDXEEvrpE2zlrFV76BkdjIFajNE3WMJd2pKGy8zQPdSOVTFLr+g9vYPtOLJGF+PLLFboKmx3X3QuDZd7fAirJBeVoGOgkpRICfWxL02DOqUF9y6TPnoBa7Z+39IXOuz+o0Ftuee6aGfHqJy/TdhwfL+2YX1uiNjsSfpOL2knfnlcumHl+mYriZIpqZJP0BPYYHLRB0eovm4LsLI1iCVYFXVZpwOwa1QKMdFLb2C71A3K7Z9Wl9fIPgpaSEfoGQ30T7fhkY7HgKOdLtPpGGjS5A/4AQE7OG2HCg2EAAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAE0AAAAaCAYAAADygtH/AAADiklEQVR4Xu2XTehMURjGH6HId75Don9JKSRWSEIUFghRUvKRBSEUqSkUsrCRkpKFLJANFkg+NkSkyAL1J5EFVuQjH8/jvcec/5l7Z87MZcY/86unmTlz77n3Pud93/NeoEmT/5Eu1OBE+l5PusOuO4DqGPz3TzOPuksdpcYF//1t5sCuexVmXrtBpm0PB8ko6gDsobag9ofSebtQnGdY279/sRu1z98Q0kxbSJ2lxlJTqPvUF2qBf1AEmvsibJ7+MHM+oXSehpimeqC64GpTNXUiNG0gdZOaQXVIxlqoV9QTpEdKGqqPF6j31PhkbCT1mnpE9UvGRF1N60pthd3ECVgKKKWWwuqF/q9EaNoE6gP1DGagkHknqR+weWOQaeeob9S0ZGwo9RJt5xbRpvWE3YBbuW7ULNhNx0TIIOo8tQxxx2cRmtYLlprHYbubQ4si03R8LDKuL4oRO5v6Th2jOrmDEGmaIuAwtQMW9vuoM9Ty5FMR0/n30aXogjpftScvoWlp9KHuUG9gG0QtKMpuwObRd58o01QvdlKjqbcw510qTYTVAR2TxRiYaf5q1UqMaUtgabYNxaiJRbVVNVJpeQ+2KYRzRJm2kppEzYfdjG/QZOortdkbC9GDbkDbwh/KT4tyVDJtOPWYKqB89McwnfqI0rmiTHPspVqpId7YWljtCLdlHz3oJVgaZ0kp39udUIZypqm+aQfciHx109EDFnUKlJneeLRpKvxXYDXMpZk+9Vspq9TNQpG5KRyskSzTnGFKTRexUxH/1qDzC7A67Ue821D8a0ab5noW/+QRsNw/gvL1SnXiVPKZlzTTlDqHUBrte2A116FIzopmzStznqNoiHbja8m4MsoRbZrqmU4uJL+1Gjr5IayOVEI7pzYQRWweQtNkWIH6TL3wpMVshS220C6q3VTjWuwQtU7vYEa7+tUC6xZUI/0dNNo01TPtkreo09R1WGqq/4pBJs+lbsMiwu+pqiE0zTW3WtBQahfUfgg99ANY35XWu+n+1sMab7VWSlO9jj1FaYpHmebCVDVDrYZ2ulofWk3yKlh99CPjMmzeSoSmVctqlH9LUG1T074I2Y17lGlp9axR5DFNdfcg0tOzGqJMWwML9xXILqT1Io9pei3aj7h+sBxRpvn9lF6uG0mtpinKFsPSLy9Rpv1LqOdzdVDf68k62HXV8P6J9qlJkyZN2gU/AYbdsSUNUCv+AAAAAElFTkSuQmCC>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACMAAAAWCAYAAABKbiVHAAACJElEQVR4Xu2VT0hVQRTGP1EhURJL0MAoBROhQAg3gbZRKEIRdCEWErhSRIKgwCIEaaFLEYIIwoUucuVCSQVtKehK7M+iTRG4iFzVRhD9vndmePPuu+++wLd8H/zQe+bMnW/mzTkXKKqo8+s6GYwGA7WQWfKWPCKVmcMpVZAhWI5yNSeUxp+SNfKKXAwHW8kY2SInZCEcDNRPPsDyG8gE2SXXgpxqskmmSRVpI19gc6US8oQ0u+dL5AXMYEp6eR+5Q34h3kwd+Qgz4aUXz5OpIPYcZrAmiD0kX2HvqCWTwZg0AvOQoSvkB+LN3CbfkN6RlxZ/5/6XARmJzm8nf0kv7LSekXI3pg2NwoxmKMlMEzkk38ldF9NPsgFbRNLu/iB7vjbyj7x2zx1khtyEbeaBi2coyYx2oB2dOt6TFdhF1JjkF43Oj4tfgK2nk4pVkhmpFLY7b+g36UbaTI+LR+fHmcmrJDNacBz2s+ii61S0sKpv2OXcd7Ho/IKb0QkckKvuWaekXqJFfKXkWjRXPFFJZlQxc9EgdY8cwRb0lzw635uJlnSikswo5qshlPrOHqySdBk/kVXYBfXqIsfu73/Lm1lE+lJ6qXw/wz4XXsp5TJZImYvpE/GTNAY56sY7sFaQV3KszqvL6CtFTWqf3HI5uiMqbfWRl7CuukzWSb3LkdTM3pBtWFeXEW1Cn4WC6zKshAfIDWSfoKSYxpTTiXS3LaqoguoM9MdxSd3buzEAAAAASUVORK5CYII=>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAWCAYAAADJqhx8AAABEElEQVR4Xu3SP0tCURjH8UciSAhKAl1cCiqaEqKlocmhBsOoqaLBwRfQkrhGS9AmBG69B50achSctb2lqc2Wlvw+POfIidvVC633Bx/uuefPc7k8RyRNmCwu0MYDtn8vywKu0cEjiuHiCl5wh2WUMMJZsEeLH7ixfqyBvF+8xQA5P0Eu8YYCltAUK+5zhLIO9JAefg4WNfsY4wQZ3GAtWD/Frg528CnRAnv4wr1730TLzddQFys83RhXIJxfFPul1WBOKviRZAX+zLH8s0Dcxrj5SDbwIdGNvoC2b2a0tz10xfrtoz3+ds+5ucI71t27tkdvZV/sls6NtucJr6iKHR6KXenE0a9u4RyHYkXTJMgEYd4vzRuy+NgAAAAASUVORK5CYII=>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEsAAAAWCAYAAACIXmHDAAABqElEQVR4Xu2XzSsFURyGX6GIKMrXxlVSilJsKBuhJGWjlJ2ysSALlP9BWYtkoeyVrKytiKWSj/AXsLAQ79uZk7mHrmY6mut2nnrqzm/ONDPvnI97gEAgEPjf5OisWyxAL52hTbSM1tJhOhdvVEp000V6St/pfv7pgijYD8cH2hdvVEoorGk6RB+RLKwpehN5RpdpXV6LEqWV3iN5WOtu8Q/op2NuMUuKOaweugkzLxYFacNS+xOYoXhLF2h5vJEHKmDCUg8rCtKGpYWhITruhJn31uC/F7TTHdrinsiCNGFVRVoU0AFMYB2xukslbYa5ZxInYRaSEfj/GIlIE9ZP6Hr9hZhwT8TQyrudwl36TC+Q8ZBMGlYXfaJHtDpWt2FpiPpEvXGLzsP/nJiY38Kqp2346v76sq/ID8sOQ9V9f3ntClaR8fCz2LD0su4DNdJL+kYHo5rCU9tcdCz0W6uihox6gi80v+3B3DNTRmEmZG117JblhV7B7P2E9nzH9BpmVbIM0HO6QZfoHT2E/5fSM664xf9IDR2H2TLl8L1X+sBddQOBQCBQgE9ACFUQswogBAAAAABJRU5ErkJggg==>

[image13]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEsAAAAWCAYAAACIXmHDAAABqklEQVR4Xu2XvytGURjHH6EoJSm/FjGQMpAkBoNQiBQTJpPVgLLKopRNieSPYDFQFmWQAWU0MDExsPD9du7Jec97j1y6975u51Of3t7n3N57z7fnnnNeEY/H4/mflMMZuAM3YGvu8I/ohMN2MWtUwmO4BitgB7yBU+ZFDnrgMryAH3Aldzh7cIKcbJVRm4W3sNaohcGwxuEofJWMh8WAGNSBVe+GL3DCqrvoknjD4u8P2cWkaYNPkh+Wnvy6VXcRd1jtcBMW2QNJoifpCsuuu4g7rBJRYfE+qcH1hguzHUqhhUUa4S6ssweSYkTSCatU1OZRH9ExeA4HJIVX0hWKq+4ialh9os50Ud2DD/BSUnglm+Gj5IeiJ79q1V1EDes3sBu34DwstsYSgYfQU3gIy4z6IHwPPjU8vDZIePsnERbPfksSfv/EmIP3sCn4zofhaZ5rAwMi1fAKvsHeoGYStROjwvVtX76eJzXY3tvwBE6KCupa1N8eDTvwCN6J2pU0C6LWEG4S2md4BmuM6/4KO3zRLqYFu6kFTsN+UQEWElwizGXC4/F4PN/wCahMWnbIAA6wAAAAAElFTkSuQmCC>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADMAAAAZCAYAAACclhZ6AAACSklEQVR4Xu2WP2gUQRTGv6ABFYNCRBGVpBAhYEARAwoBixCQEBBFIygEEVSsFJGQPiksJBBTJkgKiahNulR6lYKChWgTtFDETkVQsfHP992bp7Obm1vxDLlif/Dj9ube7sybm3k7QElJSaN00pP5xsBxepCupy10Mz1N98RBK00XvUjv0+90NvtzldX0Dv2Z8y7dEMWtOErmCGzW36J2MmKaPqdv6D06QFdlIpqIrfQ10sncoPvyjc3KciSzkXbQQbqNrqGHwvf2EKN/V8/V6uiE7UdH17voeToMW0VaQYUUJTNFJ+hT2HJ8RPdmIpZymX6E7a9xehNWYCbpB3qM3qbn6FX6hV6q3mmJXKdjdDsskXmkx5ehKBkNZBR/9okqmQbU8zuiNvvpV7pA14Y2DU4T8o7uDG0qMtqLFVjF3AKbON3vKCElWEhRMm3Ibngf0BxsICm0hDTjWiqO93UL2WWlviuwZDbRF7Cio4lTf62wcRRSlEwej38Fm8UUnoz2iZPqK05GqGLqXn8VvMRfvtdSHYgz9Ae9ELV5vNR1ikaSEV40rtFPsH9KL+y6pDoQI7CZiZPxZVZBtvM8/5qMYvQ9fnYvbJ8VVtXUOhYHYNVMa9YZot9gFakeXgCORm31ktE+0X5RjK6VgLObPoaV+Zr0wWZYRxlfm5/pM9odYpTcFfqAnoWV1vewY1A+8RiV8vi5Ov6oBOv53rZIT4XPuP8T9CF9Eu6bgVW3w/hP7IC93Pqx/GcyVc514VovX+2Tpj0+lZSUlJQs4RfCcojuaGAQtwAAAABJRU5ErkJggg==>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAZCAYAAAAv3j5gAAABnElEQVR4Xu2UzSsGURSHj1BEFKXY+EjKQhSRoqyUhZJSykZKdoQiysI/oOxkJ71lYaFERNayULZKPiI7C0VZiN+vc6+5d2beeSUbep96aubeM3PunHvuiGT5S1TCJbgOl2G9P52WJjgEK2AOLIbdcMQNsrTDI9GAZrgHP+Cs6MNJDIvGut7BFjeIFMIdOAZzzVg5PIMvsNWMpaMfXhlP4RQs8SIMLNktfBb9Gsui6OpmnLE4mGg+PBhHPlyFh6JJLXyYiTK95NuJ4siD2/Ad9vhTEZhoAx6Ilu8ajkuwDYl0iO4PO5BfnAQTncAyc89uvYdzkqGRSuEx3IRFobk4CowWvjwlmqzWGffg6tfgimg3/hSWkvvbF54gNsmCBPVthL1fEVEa4APcFX9hNhHL6sHP5eGcNteWCTjo3LOsVRLE8IxxL91EtnSRM8iJUfgqWleeausT7DJxPMQX8A12mjEm5ktrzD3hNbsv0kj2wIZ/I/QR1pk4/sP24SWsNmOkDZ6LHvBJeAO3RBfx67A7uZcDol+U2NZZsvwzPgF9AU4DLVsEwwAAAABJRU5ErkJggg==>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAaCAYAAAC+aNwHAAABC0lEQVR4XmNgGAXowBGInwPxfyT8Coh/AfFfID4JxMFAzAzTgAvMAeLfQGyDJAbSlMYAMagMiBmR5FAALxAfBuK7QCyOJicJxA9xyMGBJhC/BeI1QMyCJmcKxN+A+CoQi6DJwYEfA8Tv6egSQNDAAJErRhNHAZMYMP3PCsTJDBCXlUL5WAEPEB9ggIT6MSj7OgPE1ulALAxTiAtg8z8otCsZIKHvChXDCWD+L0ITNwbirwyQ6MULsPkfBKIZIAa3oomjAHzxDzIYZEA5mjgK0AHi9wyY8Q9ir2JANaAaiF1gCmwZIKkLPf2DwgMGQOkfFIggg2KBeDYQcyLJEwVA3vJlgMQEyZpHwfAGAGlHPJOLUE8QAAAAAElFTkSuQmCC>

[image17]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAaCAYAAAC+aNwHAAABMElEQVR4Xu3TsUoDQRDG8REJKAYiaCMYDCJC4jMIIhaWgulS2lhZiIWIhSB5gSAIYqF2PoAIVnaKCNrYmEoIWtmIWCio/2Fuw+66QuqQD36w3Ozt3ezeiXR98phDFWX0Z9eHMJ6Nk6ngCu84xTpOcIEZnGOhPdtLDtv4xCYGw7LM4g0tSbyB3ryPLyxHNZcBnGV0HGQVP9hFX1Tzc4yt+OIUntFEMarFOZRE/ztiT29E11MpiLXbjh7VJb4lsXInGcMTXsXO2o/uxYjYHN+wP8ktoHTsRz8YPdZrsaPVNu+w4k8axYOkF3Bxbb5gMizZa+6J7cFiVHPR1rTF5PlrJvCIe/n7hemOH4i9fj2qBZnGDT5whJrYDbdYwwbm3eT/ou2UsCT2B+qPE5x5L72k8gtjiDLfS9nv4AAAAABJRU5ErkJggg==>

[image18]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAZCAYAAADXPsWXAAAA/ElEQVR4Xu2SwQoBURSGj9goWUkpRYryABaUB7BgK09g5RlseAFZKcnCI9hYeQIrslJIJMlGShH/deYy9xozS5v56mum+e/t3HvOELk4kYNr+DB5hlvj/Q6HMCU32NGCF5jRvifhAs5hVMsUAnAMZzCkRi/6xKcq6oGZBNzBHvRomSxwhVk1UikRV6rqASgT96UNfVqm0CSuVIARwxiswz2sQO97tQXyuAfi63QMu8Q9asCgXPwLu37EiSczgWE1UrHrh0BORlzVEqfR5ol7NSJea0kaHuGA1KuIJorKJzglbvIXosKKPr+5GOGG+PcXzxtcwhr08xYXlz/xBB76OKePI6vzAAAAAElFTkSuQmCC>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAaCAYAAADxNd/XAAACrElEQVR4Xu2WTahNURTHl3xE+SYSEhMDiiIhjCQGDAykGPkcKt8ZvYkBGUgy8pGBJIoSE4ViIEYGoqSQyFRRJvj/2nt3z1v2vveee3PfK/dXv+57e9979trrrL3OMeszPBkvx/rBHtLV+kvlFTnJT/SQefJW/KzFHPlILvITQ8BaecdqJHKEPCsH3PhQQTzn5TE/UWKxfBM/hwur5Gs530/kYKf3rIvD8w+YIl/IHX7CQ9AEf8JPRObKTXKiG+d3dIw6jJbr5DI5Mo7xuVpOT1+qcFFes1BSRWbJD3KznxBb5VV5Sr6U0+I4wd+WN6wRSCs4kFzrgHwrd8dxkvPbQrAeKuOJnOAnqpCNr3KNG58hL1sImrvz2RqtbYH8Ig/G/9thv4VyoKY/WeOATrUQJJvzkFSSS5KLsIGP8bPKcrnHQuaeyetyVJwjaz/t702X4HcETFK2yx8WDmmCjeWSwQZIFAkrUtpAgoVYkIUTJ+V7Obsy1g5shESQkGqPPyrXV/5PsIFvcomfqNJqA2SumoV06DvpWqn0SEBinIVnUO4Qt1VCXJT6pixyUJuPrdFxUhCcCy58Wo6Jc5OjJUjSdxvcMLjD3IEclNY7OdNPVGHnrywcshx0h9QJaGcsRtcgiI1yV/zeQgvNgANaevhQCpQE3Q0oowsWXmNykKSWd5qgeIE75yciHGaC4gWLtnlcPpTP5V0LBxMIglb7y/ItGXgO0JK53iX5wML1c3BeWLOt1wkOKAHx9MvBwtzGVEb0fu4c4569Vi7HBNfhernfJ7iLvEpUu1URev1TCyXRDWTtjJVLqA47LdzxZpscxBZ500JX6BQSQIk0ffS3AQm9L1f4iWaw6JFoJwGQ/W1W4x2+AGsPyEPx71pwuw7LlX6ih2yQ+6yD4Pv0+d/4A/UqaONj+d5FAAAAAElFTkSuQmCC>

[image20]: <data:image/png;base64,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>

[image21]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAaCAYAAACO5M0mAAAA5klEQVR4Xu3RMQtBURQH8CMpSpSBDBYpsSqlTCYGZovdJ6AYZZfBbvABZDEYjCYx+AAWJovNgv955z3OvVaDwb9+5d3zf8999xH9VPIwhg4UIWiOJVmYkBTm8ICu0XBTh6H7209yQ+Q9ficHW8jYAzshWMIKotbsIy24wwB81sxJDGawgB3coGQ0kCRsSI6En9IkeeOeLvFgRFL09sUvdYGpV+Kk4UzmefE/HMl6Yo1kP2W1xjefoKHWnOIVCmqNCwdIqDVKuYtV95rPkj9f+9VQqcCeZPNr6ENAF3T428YhbA/++V6edoEhw7l7aiQAAAAASUVORK5CYII=>

[image22]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAZCAYAAAABmx/yAAAAx0lEQVR4Xu3RsQpBURzH8aMoYlCSxSAvYCMzBikr5QEMTIxmD4BFGcwegcFoMXgCs7LIZsL3OMfp7+QJbvdXn27//z39O/d/lQoTpERQQMzrf5NEzT5/0sAWKf+FzQQv9GUzgQ0qsumlhCtGslnFDFFb62v30HYnTNZoysYQdVHncMZU9PTQBYqi95kkp3dwRNbWemFLdN0Jmzkuytx/hQee2GOAE3bqz+LKuCmztTtaGNtaOyDvTnuJK/Nt8j+mkVFmWWECmjfv0Bxvg842fwAAAABJRU5ErkJggg==>

[image23]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF8AAAAZCAYAAABXTfKEAAADsUlEQVR4Xu2YW6hNQRjHPyHk3hG57yMdyQshKeQIkUiOJMSDoiREUTxQklLkEiIlSRTyRIpye6B4US5Fcskligchl8L/3zfTnjXrrLXXbFtHmX/92mvNmrX3N/818823tkhUVFRU1P+oDmABOAx2gCHJy7nqAlaL3rvRnDenVmAM2AsOgAmm7V9SazAPlLz2PPnjmiH6PYXUFVwCW0EnMBw8AE1upwwNFe27FvQGy815g9sJ6giOgnOi9wwDd8AUt1MLiRNvJtgDXoHPYGSiR7Zo/HpwDdSDOnBCdCK2dfplagO4Dbo7bQvBQ9DLafPFB3UVXBQdANUGnAEnzTHFAHeD66IPmuLD+iX62y0txj4dTASbJcx89nsLxjltg8BzMM1pa1Y0nMYf89pHg09gltfuajL4Kel7aeh70RlOMUAOiKvCqh/YJhpordQeLBOdFNWKsYeYzzHQaK56q87ghuhKz02rNIhG+QZaw/jlWeJS5ez17+UA2M7r1BbwQ3R20BgGSqNqLQ6U8RY1rjmFmM8xnJe0+TYj+NkkJWuyb2BWu6tK5jO12AD5XdvBIdP+GKyQCjOjCjHunVJOeaEKMd+anGW+355SloFFzK8HL0U3GGuizfk2n9tAeH7EXKcawUfJT2vViHGsAYvNcahCzKexNNg3ubD53GiqNZ+D407PWVwybSy5PkjafO4N3COsbOBcFXkpqJto3xAGiObbfZJd9mYpxHwWI08kbXJh87NMzmr3xXp2JXgBnonWuSxZbc5niXlZ0gOy5ucFyHs3iZZtobAC428ylnZSXCHmZ5mc1Z4Sq403kjbZms+XplDxZcOtdphu/AEVMb9ajQKnRSuqUIWYb1OsPwZrPiseVj6Zsh395c8U8d18WrFG7yPJ/M7N7ay5Rtnvc+v8+eCbJGtha77/u3+qOnAcDPQvFFSe+VzlJUnG65fVVA9wX3QSVtQi0bRRb85pLpfrLSmbykHdFTVxrGmzRnPTtfc2ia6kEeac6gnuSfKFqlH+zobLCooPu1oxxi+i7zm+loqmU3diDRYdv/ub48E7KfuUK74GHwRXwGxR4/nk+DeDFY2+AB5JclatAzdF34j5pJ+CSc51K7YxSJabq8wx77WrqBbijNwP+voXKoh7yykpFwqW12CX04972FfRIsONe47ouPmCt0T075WgMpodG8Bc0T+8Cv0vIXpfSfShVbqPg5wq2re/d60WYizMsYUHXUMxM/DhEB5HRUVFRUVFRUVFtZR+A/4429IPoGUSAAAAAElFTkSuQmCC>

[image24]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFUAAAAZCAYAAABAb2JNAAADBklEQVR4Xu2XS8gOURzGH6GISBbuuSRSlHIpkoVQEgkLYaWkpER9lFJKFpSSjZJLFhLZkiK+hYVYiEKxcElkYccCuTxPZ07OnJnzzjnv+00szq9+fd/7n5l33vPMmXMBMplMJtMGw+lWepaeoLPLhzsyiu6FufYwnVA+/N8wjW7xiw0oB+Whtikf5RTFaHqbHqUj6Xz6nG5yTwowlT6hO+kwuoa+pIvdk/4hc+huepf+pJfKhzui9isH5aFclI9yUl6NHKSP6Binto2+oOOcms8Qeo5eL/63HKO3kPBUW0ShbqBL6XvEhzqFvoLJwaJ8lNMep1aLPdG/2SL6ha736i4z6EeYh+KykX6lC7x6L+i7VvnFBDQkvUW1nSEUpt+GQfQy7YfpuUH0JD+jejN9mb5UvS7ESvoL1VDX0d8oP+VemUtPwjSsG1JDPY1qqELXqyOpQwWx4fk3C9VdbHihUP16L2h4Uah+I2NJDVXnhUKtq5ewAfg3iwlVodWF10aoQpOixvDx/oEIUkLVq92P+vCiQtVs3W2o+1EfXkyoQ2EmQTU2xbX0AV2BtKEgJdQR9A7qw4sKNRReqO4SCi9Ud9FsrLVfqufpB/oYDQ3zSAlVhMIL1UvYGdy/mQ31kFd3WUZ/oBqeDVWrgIFEvfsU3UEHe8eaSA1VE3RdeLpeS7PJXr2EHT9uwCzeLZrZvxd/LVr0TsTf124SfQMzU7rsgllRaGUxkGg10Ye0197SFKqGorHOZy0ltVlw2698lJOfVS3b6Ts6vfisH63dg8Yuu3vQDbVz+kaXdDhPvekavYLyhqBX1OiLiNzN1GBD1TrTfyjain6C6YE2A7X3IT1SfBYzYc6J2uoqiDP0HszuQ0E9g9meWdSjb8JsQTULW9RI1a/CTHoX6H00vB5doB6zzy9GoOsUhHqdhiSpTc1TOq84R79VHUaTk/vQFtLX9ADdDLNJOg6TVxR6erNgLl6OhAthxjeNPbpWf1PHuxj0ujW+ci2glcBqmM6mrWsmk8lkMplMpn3+AOjer/4Z724RAAAAAElFTkSuQmCC>

[image25]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACUAAAAZCAYAAAC2JufVAAACEklEQVR4Xu2VT0gVURTGv5CgMCkJlCLw5cIQWgSS4iZa1KJFEWgkKbWL1m1KV0G4UNSdBLXQgiAXLoIKIsG3LFoFWhC0MPqzSjcVVER+X2eu7859d8bHE3fzgx+jZ+bee96cc+8ABQXbx256id6l4/RI+nbNtNFHtMWL7aKX6dHk7wZ6iF6lpcpjafbSF/Q23UOP0be0z3+oBnbSGbpCD3jxffQV/Rc4ARsT5QZ9TZu92CB9R1u92GZcoH9QnZR+6FO6RD/QWdpDd3jPpFAiSuh+ED9Ov9NzQTyLEqz0TxBPSvP7sVw66TdUJ9VFf9DRIB5DJZik3bB5tpyUWzwrqTAeQ713HVaOrKTm6BSshJ/pY+Q0+VlY04WL15qUdts92GYRWUk9pxdhiUttqvew8VWcQf1JqWzaQWpaRywpJdGUXB3q2Z/0lhfbIGvxrLiPNoErmyOWVAw3/wJtDO6hnX5F9eJu0EgQ91GPfAz8DXvzX2CHqBYcgx0Vp23Yf9z8ZVh5UyhQhp0jOm0dp2AL6OpQ3xxEzvmC+JtS7C/SSbny6bCNzjcE+5WHk//1kBrxJSoNvJ++ob9obxIL0biH9BPsM+IYoDeT+0LXYboGO0aiqGHv0EV6HpbQMuxz49AbfYbsHXONrqLyCdFbduXT/NN0nl6hD2BnozZZLsq+g/bTE8j5JtWJP/9JpFuloKCgIIt1O7tzg74xY70AAAAASUVORK5CYII=>

[image26]: <data:image/png;base64,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>

[image27]: <data:image/png;base64,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>

[image28]: <data:image/png;base64,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>

[image29]: <data:image/png;base64,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>

[image30]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAaCAYAAABozQZiAAABBElEQVR4Xu3RP0tCURjH8SesLREpCMElaWlyiAaHwlfQ4KQvIJpak6Shpa1AHNsaXKq9wSVSaHDuBQRRU7Q5+/15nlPnRr2B8gcfLs9zz797rtk8/yk5bGEXS0l/AXl/KhuoJvVscBcdPOAiviB7+LAwYRVPeEMlDqjjBAUM0bevlXsWJmiiekd4tWTyPjZRwwRN7xcxtuxiZdxZWCyTU7xg3Wst+I6DOMB755Z8s7KMe9xi0XsNCyfZ9lrRqVpJPUsJzxYuLabtPb1TtKh2jSf7TLzJM6/1B64te7M7OLZvR47RMfWNNxjgECM84gqXFv7Ir9GOaxbuQNEuK+7HHef5+5kCasIlUVci1xkAAAAASUVORK5CYII=>

[image31]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAZCAYAAADnstS2AAAAsUlEQVR4XmNgGAX0BMxAbAzEdkDMChVjBGJ9IJaHKQIBkGQvEJcC8QkoGwRACj8B8R4g5oaKMbgCcQ0QCzJAFC+EinMC8QIgPgDEPFAxhlQg1gRiSyD+BsQRMAkgsAHiyUh8OGgA4idArIgkFgTE6Uh8MJAE4odAXI4kBtLUA8QsSGJgIA7Ed4G4CsoHeboTiA3hKpAAKJiygPglEC8C4h1AHICiAgvgYIA4CUSPggECANGPFVWQ2UcUAAAAAElFTkSuQmCC>

[image32]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAaCAYAAAC+aNwHAAAA3UlEQVR4Xu3SvwsBYRzH8WcwGPzIJFFmZZJFMSizf8J/YPRXyCglg81qwaAsyt+gWCjCYpHC++I5d1931y22+9Srrvs8zz337U6pIDJV7PG0OOPwub6ijZje4JYe7iiL+wX1ftgEEdGZiWKBNZKiMzbN8UDNXn2TwwkjhESXwEo5v52ZunrP25QFKeGGJeKiM9NRzicYG2Y4oig6M3pG45Qhuh8D7NBHRi92ip5/iixSFmHLOtfo+Vuy8Btjfs9P5BX9/TdI2yt/yeOCsfI5r04FW/X7/zesi4IE+WteEE4wNyAyaW0AAAAASUVORK5CYII=>

[image33]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAD0AAAAZCAYAAACCXybJAAAC00lEQVR4Xu2WTahOQRjH/zeUz2TBTVFYkIUiH6FYSUmkECESRZYkYXdlwUahlJQkKWwsrBS3KF9lIR8rCyIrVhTKx//vmefe58y55z147+Kl869f7znzzpyZ/8wzzwzQqFGj/11TyMa8MGk9WUxGky4ygWwhs2MlagTZRM6S42RG8e/O0Eyyh9wi38iF4t+/NJRcIT8yrpKxoZ6eb5IjsMnRhDwna0OdjpBMr4Gt4hsMbFo6R56S1+QaWUmGFGoAB8gjMi6UbSYvSHco6xhNJK9QbfoUmZsXBsmoDOft55OPZHVW3hFq17Qi5j3K7dXmEzmalbu0DSaR5bBvDCPzYNE3OdVRDplO1qU6eYSNIivIPrIUNtHjCzUqVGf6NDlBHsO2wT0yJ/zv5vL2VeUumXsLyxFKfhdhW+IwrN3OVL6X7E51NRblGUmTcJcshHnYCtuCrRaoT3Wmz5OD6J9lZe4PZEF6XwUbeN6+zrSkldZExr0/htwhX8iSVCYpYjROjVfSZFyCRYOrB4NkWoOIYeUDvQybdYXX35r2vk+GMoV9L8y4+nYpWUbTu2CnjrafFkDtFO7aJrWqM53L67+ErU6VuaryKP+WDLnctNCzKzetY1JHZzxKj2EQTG8n32F7yuX1fQDTyDuU27vpQ1l5VDumpS7YxWobuY3yWCvVyrQ60gzGD3l498IG5YO8QYb31QKWka/pt0rtmN6P4nGoFdZFaiAfJXnHeVKQFsEyZgyZDeQzirctJTdlzqnpXd/R7ew+ije3XD6BMRpamdbRqKzt7zLpY1OfGmucwJK0AupQycD3hC4TT8isVEcf0hmo0NkBSzjqWNfXOEHq+Eyqp6NIhp+hfD+PUvQoErzvh+g/GbxMzyrTMellaqO2WukHsInV0XYdtnCtJvmPpMuCzOgiUfVRTYJfJHRR+K2E0oZGwk4V9aOEGqOiUaNGjRo1+lf1E5v9saZUACS4AAAAAElFTkSuQmCC>

[image34]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAD0AAAAZCAYAAACCXybJAAACvElEQVR4Xu2WTahNURTH1wvlM0mSopDIQCkfSTGSMqBXDISYKJIRoZiIDBiilJlkwsjAiLxXlK+ZwsBAREaMGFA+/j/rLO2z79n34hpcOv/69c5dZ6939n/vtT/MWrVq9b9rrtiaBxMtEmfERbFNTKi//iFivKMNbckZOC0W+8Rt8UVcqr/+qc3iqVgqJouT4qaYmrThmRjvaENbcsgdKGF6WKwWr63Z9BzxXGxPYtPEI7E/iR2pYrwLkfNMzExiA6NZ4qU1m6bjH8WyJDYkrohR81mNQcjzV4gPYlMWHwh1M33WOk0j2r4V880r5l0VS0UOuaeyeIgBmy3Wm/+PcWK5efVRYYgBXii2VG3GVPHQJLFBHBRrzQd6Rq1FQd1MEyuZjniYy/NL8RDm3ohv5pvfZfPKOmaet7uKHxB7q7bnxViSzQfhrlhl7mGneGWdfW1UyTQzMWq9TW8073ie38s0YqbZT9K1P0XcEZ/EmiqGqBj6SX8Rg8EyoxpCJ6yzr40qmaZ0bllv05TXn5qOb7OMQjHYGGcAQmyWqek95qfOObHSPI8+s0x6qmQapeZK8ZK5UjxVfBtDoTANPIdy0xyT18wHPDhtf8E0JVUyTVlSnmxmbGp5fpg+msVT9WMaDZlfrHaJEfHVfP33VDfTHDeU0LokNl7cqOA5Ohm/Q+R8rv6W1I/pQ1Y/Dpnhq9bso0Px4XxTQNPFQ3E8iS0wn+X02rrDfOecV/3m/3A7u2/1m1uu2MjSauhmmqORXTt+YzLKmW+yu6cD2CFmgA8yk7EmuEw8FkuSdpydL8Rh8/OSi0i+dni+YF5iHEUYfmJ+HS2JMqQS4tsMLoP3PonxTOxeEiOHXGb6gfnAcrRdN5+4boP8W2JX5BKRXhxyMdJxkeCi8EsbSh+aaH5Z4Tscd2lVtGrVqlWrVv+qvgOsY7b1JCKRsQAAAABJRU5ErkJggg==>