# **Arquitectura e Ingeniería de la Terminal de Ignición Orbital en Godot 4**

El diseño e implementación de componentes diegéticos de alta fidelidad en interfaces de usuario exige un alejamiento radical de los paradigmas convencionales basados en rectángulos estáticos y texturas pre-renderizadas. La Terminal de Ignición Orbital se concibe como una consola militar integrada al zócalo inferior del puente de mando espacial, requiriendo una sinergia absoluta entre el pipeline de renderizado en alto rango dinámico (HDR), sombreadores procedurales en el espacio de la pantalla, trazado vectorial analítico en tiempo real y una máquina de estados cinéticos orquestada mediante interpolaciones elásticas.

## **1\. Pipeline de Renderizado 2D HDR y Calibración Óptica**

Para que las líneas vectoriales, los diodos de estado y la tipografía militar emitan un halo de difusión luminosa (*bloom*) calibrado a nivel milimétrico sin degradar la profundidad de los negros del espacio exterior ni enturbiar el vidrio ahumado, el motor de renderizado de Godot 4 debe operar en un espacio de color no acotado1.  
Por defecto, los lienzos bidimensionales en Godot procesan la información visual en un búfer de color de bajo rango dinámico (LDR) de 8 bits por canal, truncando cualquier luminancia cromática superior a 1.0 y eliminando la base matemática necesaria para el resplandor físico1. La activación de la directiva rendering/viewport/hdr\_2d en la configuración general del proyecto instruye al backend de Vulkan (Forward+ o Mobile) a preservar búferes de coma flotante de precisión media (FP16) para la composición del lienzo 2D1. Esta modificación habilita el uso de canales ![][image1], transformando colores planos en radiación lumínica emisiva que alimenta directamente las etapas de postprocesamiento1.  
El control milimétrico de la dispersión óptica requiere la presencia de un nodo WorldEnvironment configurado para procesar elementos de lienzo bidimensionales mediante un recurso Environment dedicado3. El umbral de activación del resplandor debe posicionarse por encima de la unidad para garantizar que las superficies pasivas del cristal y los biseles de grafito no generen halos indeseados, reservando la difusión exclusivamente para los diodos sobrecargados, los delimitadores de alta prioridad y los destellos de enclavamiento5.

| Parámetro del Entorno (Environment) | Valor Óptimo | Justificación Técnica de Calibración |
| :---- | :---- | :---- |
| glow\_enabled | true | Habilita la cadena de reducción piramidal de luminancia en el compositor4. |
| glow\_levels/1 | 0.15 | Difusión de altísima frecuencia para bordes de glifos de un solo píxel6. |
| glow\_levels/2 | 0.50 | Halo secundario inmediato para simular retroiluminación interna de panel6. |
| glow\_levels/3 | 1.00 | Núcleo de dispersión visual para el cuerpo de la tipografía y los diodos LED6. |
| glow\_levels/4 | 0.30 | Dispersión atmosférica residual en la vecindad del zócalo del panel. |
| glow\_intensity | 0.80 | Amplitud equilibrada para evitar el lavado de los contrastes del fondo estelar6. |
| glow\_strength | 0.95 | Factor de escala sobre la mezcla final de emisión en el lienzo. |
| glow\_bloom | 0.10 | Dispersión basal controlada para transiciones de luminancia6. |
| glow\_blend\_mode | Additive (0) | Evita el deslavado característico de los modos Screen en composiciones oscuras6. |
| glow\_hdr\_threshold | 1.05 | Barrera estricta que impide el resplandor en elementos no sobreexcitados. |
| glow\_hdr\_scale | 1.80 | Factor multiplicador de respuesta emisiva para valores en coma flotante. |

El sistema cromático diegético queda articulado en tres niveles electromagnéticos diferenciados: el estrato de carbón y grafito desaturado, confinado a valores submáximos (![][image2] con ![][image3]); el fósforo cian técnico estándar para la lectura telemétrica pasiva (![][image4]); y los emisores HDR para brackets excitados, cheurones de avance, barridos especulares y estados de alerta crítica (![][image5]), que detonan la difusión luminosa controlada en el compositor visual1.

## **2\. Jerarquía de Nodos y Arquitectura de Composición**

La arquitectura del componente abandona los nodos de interfaz de usuario rígidos y adopta como base estructural la clase abstracta BaseButton de Godot 47. Esta herencia dota a la terminal de las capacidades nativas de interacción del motor (captura y delegación de foco, navegación accesible por teclado o gamepad, y gestión de señales operativas) sin imponer estilos predeterminados por temas de interfaz estándar7.  
La disposición de los subsistemas internos desacopla el muestreo de fondo, el enmascaramiento óptico de la telemetría, el renderizado tipográfico dinámico y la proyección geométrica vectorial en capas independientes.

| Nodo | Clase / Tipo | Configuración Esencial | Responsabilidad Arquitectónica |
| :---- | :---- | :---- | :---- |
| OrbitalTerminal | BaseButton | custom\_minimum\_size \= (720, 36), focus\_mode \= FOCUS\_ALL \[cite: 7\] | Nodo raíz, máquina de estados finitos y arbitraje de eventos de hardware. |
| BackBufferCapture | BackBufferCopy | copy\_mode \= COPY\_RECT, rect \= Rect2(0, 0, 720, 36\) \[cite: 8\] | Aislamiento y captura del fondo estelar en coordenadas locales8. |
| GlassBackground | ColorRect | material \= ShaderMaterial (glass\_telemetry.gdshader) \[cite: 8\] | Superficie de vidrio ahumado, refracción, micro-rejilla y barrido especular9. |
| MarqueeZone | Control | clip\_contents \= false, mouse\_filter \= MOUSE\_FILTER\_IGNORE | Contenedor de delimitación espacial del bus de telemetría. |
| MarqueeDisplay | CanvasGroup | material \= ShaderMaterial (soft\_marquee\_mask.gdshader) | Agrupador que aplica la atenuación de bordes por degradado suave11. |
| MarqueeLabelA | Label | horizontal\_alignment \= LEFT, autowrap\_mode \= OFF | Bloque tipográfico primario de avance continuo. |
| MarqueeLabelB | Label | horizontal\_alignment \= LEFT, autowrap\_mode \= OFF | Bloque tipográfico secundario para continuidad cíclica sin costura. |
| ChassisSeparator | ColorRect | color \= Color(0.3, 0.8, 1.0, 0.4), ancho de 1 píxel | Límite diegético vertical entre telemetría viva y el percutor táctil. |
| ConfirmationAnchor | HBoxContainer | Anclado a la derecha, mouse\_filter \= MOUSE\_FILTER\_IGNORE | Bloque fijo de afordancia que hospeda el texto de acción y el glifo contextual. |
| AnchorActionLabel | Label | Tipografía condensada, color cian fósforo | Rótulo interactivo que muta según el estado del sistema. |
| PromptGlyph | Control | custom\_minimum\_size \= (18, 18\) | Lienzo con dibujo vectorial reactivo para el botón físico o tecla activa13. |
| VectorOverlay | Control | Anclado a todo el marco, mouse\_filter \= MOUSE\_FILTER\_IGNORE | Capa superior para dibujo vectorial de brackets, retículas HUD y láser13. |

Esta estructura modular resuelve la necesidad de aislar los cálculos visuales. El nodo BackBufferCopy captura únicamente la región subyacente para alimentar el sombreador del vidrio sin incurrir en penalizaciones por lectura global continua8. Por su parte, el nodo CanvasGroup amalgama las dos etiquetas de texto antes de transferirlas al sombreador de fragmento, permitiendo que la máscara de degradado horizontal atenúe simultáneamente ambos textos en los márgenes sin presentar discontinuidades en las intersecciones11.

## **3\. Desarrollo de Sombreadores de Superficie**

La materialidad de la consola no se apoya en texturas estáticas, sino en formulaciones analíticas evaluadas en la GPU que conservan fidelidad matemática independientemente del escalado de la ventana de visualización.

### **Vidrio Blindado, Refracción, Trama Hexagonal y Barrido Especular**

El sombreador glass\_telemetry.gdshader se aplica sobre el nodo GlassBackground. Este material realiza un muestreo de la textura de pantalla obtenida mediante la directiva hint\_screen\_texture, desplazando ligeramente las coordenadas en función del espesor óptico simulado para calcular refracción y aberración cromática transversal8.  
Simultáneamente, calcula una distancia de Voronoi hexagonal procedural sin necesidad de consultar texturas auxiliares10, proyecta un tren de ondas senoidales para recrear líneas de escaneo tenues y procesa un parámetro de barrido oblicuo para generar un destello especular instantáneo (*shimmer*) al recibir la interacción del cursor16.

OpenGL Shading Language  
shader\_type canvas\_item;  
render\_mode blend\_mix;

uniform sampler2D screen\_texture : hint\_screen\_texture, filter\_linear\_mipmap;  
uniform vec4 glass\_tint : source\_color \= vec4(0.015, 0.025, 0.04, 0.88);  
uniform float refraction\_strength : hint\_range(0.0, 0.05) \= 0.003;  
uniform float chromatic\_aberration : hint\_range(0.0, 0.02) \= 0.0015;

uniform float hex\_scale : hint\_range(5.0, 100.0) \= 48.0;  
uniform float hex\_opacity : hint\_range(0.0, 1.0) \= 0.05;  
uniform vec4 hex\_color : source\_color \= vec4(0.3, 0.85, 0.95, 1.0);

uniform float scanline\_density : hint\_range(0.5, 5.0) \= 2.2;  
uniform float scanline\_opacity : hint\_range(0.0, 0.5) \= 0.07;

uniform float shimmer\_position : hint\_range(\-0.5, 1.5) \= \-0.5;  
uniform float shimmer\_width : hint\_range(0.05, 0.5) \= 0.18;  
uniform float shimmer\_intensity : hint\_range(0.0, 3.0) \= 0.0;

float hex\_distance(vec2 p) {  
    p \= abs(p);  
    float c \= dot(p, normalize(vec2(1.0, 1.7320508)));  
    c \= max(c, p.x);  
    return c;  
}

vec4 generate\_hex\_grid(vec2 uv, vec2 aspect\_ratio) {  
    vec2 p \= uv \* aspect\_ratio \* hex\_scale;  
    vec2 r \= vec2(1.0, 1.7320508);  
    vec2 h \= r \* 0.5;  
      
    vec2 a \= mod(p, r) \- h;  
    vec2 b \= mod(p \- h, r) \- h;  
    vec2 gv \= length(a) \< length(b) ? a : b;  
      
    float edge \= hex\_distance(gv);  
    float line \= smoothstep(0.48, 0.50, edge) \- smoothstep(0.50, 0.52, edge);  
    return vec4(hex\_color.rgb, line \* hex\_opacity);  
}

void fragment() {  
    vec2 screen\_uv \= SCREEN\_UV;  
      
    // Muestreo con aberración cromática transversal  
    float r \= textureLod(screen\_texture, screen\_uv \+ vec2(refraction\_strength \+ chromatic\_aberration, 0.0), 0.5).r;  
    float g \= textureLod(screen\_texture, screen\_uv \+ vec2(refraction\_strength, 0.0), 0.5).g;  
    float b \= textureLod(screen\_texture, screen\_uv \+ vec2(refraction\_strength \- chromatic\_aberration, 0.0), 0.5).b;  
    vec3 scene\_sample \= vec3(r, g, b);  
      
    // Mezcla de absorción cromática del vidrio ahumado  
    vec3 composite \= mix(scene\_sample, glass\_tint.rgb, glass\_tint.a);  
      
    // Cálculo e inyección de la micro-rejilla hexagonal  
    vec2 aspect \= normalize(vec2(1.0 / TEXTURE\_PIXEL\_SIZE.x, 1.0 / TEXTURE\_PIXEL\_SIZE.y));  
    vec4 hex \= generate\_hex\_grid(UV, aspect);  
    composite \+= hex.rgb \* hex.a;  
      
    // Líneas de escaneo horizontales (CRT falloff)  
    float scanline \= sin((UV.y / TEXTURE\_PIXEL\_SIZE.y) \* scanline\_density);  
    scanline \= (scanline \* 0.5 \+ 0.5) \* scanline\_opacity;  
    composite \-= scanline;  
      
    // Barrido especular de alta pureza (Shimmer)  
    float sweep\_axis \= UV.x \- UV.y \* 0.35;  
    float sweep \= smoothstep(shimmer\_position \- shimmer\_width, shimmer\_position, sweep\_axis)  
                \- smoothstep(shimmer\_position, shimmer\_position \+ shimmer\_width, sweep\_axis);  
    vec3 sweep\_glow \= vec3(0.6, 1.8, 2.4) \* max(0.0, sweep) \* shimmer\_intensity;  
    composite \+= sweep\_glow;  
      
    COLOR \= vec4(composite, 1.0);  
}

### **Máscara de Atenuación Lateral Suave para Telemetría**

El flujo de telemetría no debe chocar abruptamente contra los límites físicos del panel, sino desvanecerse en los márgenes como si transitara por un canal óptico confinado. El sombreador soft\_marquee\_mask.gdshader, alojado en el CanvasGroup, procesa la composición tipográfica agrupada y modula el canal alfa mediante dos funciones de interpolación suave (*smoothstep*) dependientes de la coordenada horizontal normalizada11.

OpenGL Shading Language  
shader\_type canvas\_item;  
render\_mode blend\_premul\_alpha;

uniform float fade\_margin\_left : hint\_range(0.0, 0.35) \= 0.12;  
uniform float fade\_margin\_right : hint\_range(0.0, 0.35) \= 0.16;

void fragment() {  
    vec4 text\_buffer \= texture(TEXTURE, UV);  
      
    // Desvanecimiento óptico gradual en extremos izquierdo y derecho  
    float left\_falloff \= smoothstep(0.0, fade\_margin\_left, UV.x);  
    float right\_falloff \= smoothstep(1.0, 1.0 \- fade\_margin\_right, UV.x);  
    float alpha\_vignette \= left\_falloff \* right\_falloff;  
      
    COLOR \= vec4(text\_buffer.rgb, text\_buffer.a \* alpha\_vignette);  
}

## **4\. Dinamismo de la Cinta Telemétrica y Motor Tipográfico**

La ilusión de un flujo continuo e infinito de telemetría de vuelo en tiempo real demanda una calibración matemática precisa de las dimensiones tipográficas para prevenir desajustes posicionales a lo largo de ciclos prolongados de renderizado18.  
La traslación horizontal sin saltos se implementa emparejando dos nodos Label idénticos sincronizados con un acumulador de desfase posicional ![][image6]18. En Godot 4, el cálculo de las dimensiones espaciales de una cadena tipográfica no se extrae directamente de las propiedades del nodo, sino a través de la interfaz de bajo nivel de la fuente18:  
![][image7]  
A partir de esta métrica ![][image8], la posición en el eje horizontal para cada cuadro se calcula mediante la relación matemática:  
![][image9]  
![][image10]  
El primer nodo se posiciona en ![][image11], mientras que el segundo se ubica con absoluta precisión en ![][image12]. Cuando el primer nodo rebasa completamente el margen izquierdo de la ventana visible, la función módulo garantiza una reubicación suave sin crear nuevos objetos en memoria ni provocar fluctuaciones en el recolector de basura del motor.  
La narrativa militar programada para la cinta consta de una secuencia de enlace que alterna la telemetría viva con hitos de confirmación operacional:  
/// ENLACE NEURAL ESTABLECIDO // PROTOCOLO DE SALTO: AUTORIZADO // VECTOR ORBITAL SINCRONIZADO // CONFIRMAR DESPLIEGUE \>\>\> CARGANDO SISTEMAS TÁCTICOS // IGNICIÓN EN ESPERA ///  
Para que los delimitadores de protocolo (/// y \>\>\>) proyecten una mayor jerarquía visual sin distorsionar la sobriedad del bloque, la tipografía técnica se procesa con colores modulados donde los caracteres operativos base operan en Color(0.55, 0.85, 0.95, 0.90), mientras que los símbolos direccionales se configuran con un multiplicador de luminancia que alcanza el rango emisivo HDR en Color(1.3, 2.2, 2.8, 1.0), detonando los niveles primarios de difusión luminosa en el compositor de postproceso1.

## **5\. Renderizado Vectorial HUD y Geometría Procedural**

Para garantizar bordes vectoriales con nitidez independiente de la escala, el marco estructural de la terminal, los brackets exteriores, las marcas de telemetría en ángulo y el haz de energía se generan enteramente mediante llamadas a la API de dibujo de bajo nivel en el método \_draw() del nodo VectorOverlay13.  
El chasis principal se define como un recuadro de un píxel de grosor trazado en el tono cian grafito base mediante draw\_rect(), complementado por una línea superior que pulsa armónicamente14.  
Los corchetes angulados rematan los extremos izquierdo y derecho en biseles de 45 grados. Cada bracket se calcula a partir de un conjunto de cuatro vértices ordenados procesados mediante draw\_polyline() con antialiasing activo14. En el extremo izquierdo, el bracket ![][image13]\\delta\_{\\text{bracket}}\$), que se contrae cuando el sistema gana foco y se expande súbitamente en la secuencia de detonación.  
En el interior del bracket izquierdo reside un diodo LED de instrumentación renderizado con draw\_circle() y un halo exterior trazado con draw\_arc()13. En reposo, la intensidad luminosa responde a una función senoidal suave:  
![][image14]  
Al ingresar en el estado de enclavamiento por foco del sistema, la señal conmuta a un estroboscopio cuadrado de alta frecuencia (![][image15]), transmitiendo urgencia técnica mientras el sistema aguarda la autorización humana.  
Cuando la terminal adquiere el estado de enclavamiento (*Target Lock Framing*), en las cuatro esquinas exteriores del panel se activan retículas vectoriales en forma de L invertida14. Cada marca posee brazos ortogonales de ![][image16] de longitud situados a una separación de ![][image17] respecto al chasis primario, renderizados en cian puro sobrecargado14.  
Simultáneamente, un hilo de luz láser de un píxel de grosor recorre de manera ininterrumpida el contorno exterior del panel en sentido horario. Dado el perímetro total del rectángulo ![][image18], la posición angular en píxeles del emisor ![][image19] se calcula paramétricamente:  
![][image20]  
A partir de ![][image19], el trazador divide el haz en segmentos ortogonales sobre los cuatro bordes (superior, derecho, inferior e izquierdo) aplicando una ponderación lineal de atenuación sobre una estela de ![][image21], generando la percepción táctica de un cerrojo electromagnético activo14.

## **6\. Sistema de Estados Reactivos y Orquestación del Game Feel**

La terminal transita a través de cuatro estados operativos mutuamente excluyentes gobernados por una máquina de estados determinista. Las variaciones cinéticas no se producen mediante cambios de estado discontinuos, sino a través de secuencias de interpolación (*Tweens*) que transmiten rigidez e inercia mecánica8.  
Las transiciones entre estados responden a los siguientes eventos y parámetros de control:  
La terminal se inicializa en el estado de reposo pasivo (IDLE). Al recibir la señal mouse\_entered, el sistema avanza al estado de selección (HOVERED). Si desde el reposo o la selección se detecta navegación direccional mediante focus\_entered, se produce la captura del enclavamiento (FOCUSED). El retorno al reposo se efectúa a través de mouse\_exited o focus\_exited. Finalmente, la confirmación de activación mediante la señal pressed ejecuta la detonación irreversible del cerrojo (COMMITTED).

| Parámetro Dinámico | Reposo (IDLE) | Selección Ratón (HOVERED) | Enclavamiento (FOCUSED) | Detonación (COMMITTED) |
| :---- | :---- | :---- | :---- | :---- |
| **Color del Chasis** | Color(0.20, 0.45, 0.55, 0.85) | Color(0.60, 1.80, 2.20, 1.00) | Color(0.80, 2.40, 3.20, 1.00) | Color(5.00, 5.00, 5.00, 1.00) (Flash 1F) |
| **Transparencia Cristal** | **![][image22]** opacidad (alpha \= 0.85) | ![][image23] opacidad (alpha \= 0.88) | ![][image24] opacidad (alpha \= 0.92) | ![][image25] opacidad (alpha \= 0.98) |
| **Velocidad Cinta** | **![][image26]** (Pausada) | ![][image27] (Aceleración ![][image28]) | ![][image29] (Firme / Decidida) | ![][image30] (Bloqueo instantáneo) |
| **Inflexión Brackets** | **![][image31]** (Posición nominal) | ![][image31] (Posición nominal) | ![][image32] (Contracción elástica) | ![][image33] (Eyección violenta) |
| **Retículas L** | Inactivas (![][image34]) | Inactivas (![][image34]) | Parpadeo doble ![][image35] Fijadas | Sobrecarga ![][image35] Desvanecimiento |
| **Trazador Láser** | Inactivo | Inactivo | Activo (Recorrido horario continuo) | Descarga generalizada |
| **Frecuencia LED** | **![][image36]** (Senoidal relajada) | ![][image37] (Atención activa) | ![][image15] (Urgencia táctica) | Saturación máxima continua |
| **Cursor del Ratón** | Puntero estándar de sistema | Retícula táctica hardware | Retícula táctica hardware | Bloqueo de entrada |

En el estado de selección (HOVERED), la terminal excita su chasis elevando su color a un cian eléctrico brillante mientras un Tween proyecta el parámetro shimmer\_position en el sombreador de vidrio desde ![][image38] hasta ![][image39] en ![][image40] mediante una curva cúbica suavizada8. Simultáneamente, el cursor del ratón se transmuta a nivel de sistema operativo en una mira telescópica militar mediante la llamada Input.set\_custom\_mouse\_cursor(), garantizando cero latencia de arrastre al procesarse como hardware cursor en el compositor de la ventana21.  
Al ganar el foco (FOCUSED), los corchetes exteriores se contraen ![][image41] hacia el centro con una curva elástica seca (TRANS\_BACK, EASE\_OUT), simulando el cierre mecánico de mordazas sobre la bahía. El fondo oscurece levemente su transparencia (del ![][image22] al ![][image24]) para maximizar el contraste de los glifos, las retículas en L ejecutan dos ciclos de parpadeo estroboscópico antes de estabilizarse, y el flujo de telemetría inyecta en tiempo real el prefijo de combate:  
\[ TARGET LOCKED // LISTO PARA DESPLIEGUE \] \>\>\> ENLACE ORBITAL ESTABLECIDO // AUTORIZAR IGNICIÓN \>\>\>  
Si la terminal pierde el foco hacia otro panel de la interfaz (focus\_exited), el sistema ejecuta un desacople armónico: los corchetes mecánicos se abren con suavidad en ![][image42], las retículas se disuelven progresivamente y la velocidad de desplazamiento desacelera gradualmente hasta su cadencia de patrulla de ![][image26] sin cortes visuales abruptos.  
Al presionar el disparador (COMMITTED), se ejecuta una coreografía milimétrica:

> 1. **Destello de Sobrecarga (1 cuadro):** El cristal y los marcos vectoriales conmutan instantáneamente a un valor blanco sobreexpuesto en coma flotante Color(5.0, 5.0, 5.0, 1.0).  
> 2. **Colapso Dimensional:** La marquesina congela su traslación y reduce su escala horizontal a cero en ![][image43] convergiendo hacia el centro; en ese instante crítico, la cadena de texto se sustituye por:  
>    \>\>\> IGNICIÓN DE HIPERESPACIO: COMPROMETIDA \<\<\<  
>    y vuelve a expandirse con un rebote elástico seco.  
> 3. **Descarga y Eyección:** Los corchetes angulados se disparan hacia afuera en sentido opuesto (![][image44]) simulando la despresurización de las esclusas mecánicas, culminando en la emisión de la señal ignition\_committed para desencadenar la transición de escena.

## **7\. Detección Contextual de Hardware y Renderizado de Glifos**

Para satisfacer la afordancia de interacción diegética sin recurrir a instrucciones superpuestas ajenas al universo del juego, el ancla de confirmación ubicada en el extremo derecho (\[ EJECUTAR DESPLIEGUE \]) actualiza sus representaciones visuales de acuerdo con el último periférico detectado23.  
El componente intercepta el flujo global de eventos en el método \_input(event)23. Si el evento procesado corresponde a las clases InputEventKey, InputEventMouseButton o InputEventMouseMotion, el esquema se cataloga como entrada de escritorio23. Si por el contrario el evento proviene de InputEventJoypadButton o de una palanca analógica que sobrepasa el umbral de zona muerta fijado en ![][image45], el esquema conmuta a mando de control23. En este último caso, el sistema evalúa la cadena descriptiva provista por Input.get\_joy\_name(device\_id) para segregar iconografía específica entre periféricos tipo PlayStation y mandos del estándar Xbox/PC25.  
El nodo PromptGlyph renderiza vectorialmente los iconos dentro de su método \_draw()13:

* **Modo Teclado:** Traza el perímetro de una tecla en fósforo cian de ![][image46] acompañada por la flecha quebrada representativa de \[ ENTER ↵ \] o la barra espaciadora con un micro-borde pulsante14.  
* **Modo Gamepad:** Renderiza un círculo de fósforo digital de ![][image47] de radio rodeado por un anillo exterior concéntrico que oscila en amplitud sincronizado con el ciclo respiratorio del panel13. En su centro dibuja vectorialmente la letra A estilizada o el glifo en cruz ✕, dotando al testigo de una presencia visual plenamente diegética.

## **8\. Guía de Ensamble y Código Maestro en GDScript**

A continuación se expone la implementación unificada de la terminal de control en el archivo orbital\_ignition\_terminal.gd, integrando los cálculos de sincronización temporal, control de sombreadores, arbitraje de periféricos y primitivas de dibujo vectorial.

GDScript  
class\_name OrbitalIgnitionTerminal  
extends BaseButton

signal ignition\_committed

enum TerminalState { IDLE, HOVERED, FOCUSED, COMMITTED }  
enum InputScheme { KEYBOARD, GAMEPAD\_XBOX, GAMEPAD\_SONY }

const BASE\_TELEMETRY: String \= "/// ENLACE NEURAL ESTABLECIDO // PROTOCOLO DE SALTO: AUTORIZADO // VECTOR ORBITAL SINCRONIZADO // CONFIRMAR DESPLIEGUE \>\>\> CARGANDO SISTEMAS TÁCTICOS // IGNICIÓN EN ESPERA /// "  
const LOCKED\_TELEMETRY: String \= "\[ TARGET LOCKED // LISTO PARA DESPLIEGUE \] \>\>\> ENLACE ORBITAL ESTABLECIDO // AUTORIZAR IGNICIÓN \>\>\> "  
const COMMIT\_TELEMETRY: String \= "\>\>\> IGNICIÓN DE HIPERESPACIO: COMPROMETIDA \<\<\<"

@export\_group("Tipografía y Telemetría")  
@export var terminal\_font: Font  
@export var font\_size: int \= 13  
@export var base\_speed: float \= 38.0  
@export var hover\_speed: float \= 85.0  
@export var focus\_speed: float \= 55.0

@export\_group("Paleta Cromática y HDR")  
@export var color\_idle: Color \= Color(0.20, 0.45, 0.55, 0.85)  
@export var color\_hover: Color \= Color(0.60, 1.80, 2.20, 1.00)  
@export var color\_focus: Color \= Color(0.80, 2.40, 3.20, 1.00)  
@export var color\_flash: Color \= Color(5.00, 5.00, 5.00, 1.00)  
@export var color\_laser: Color \= Color(1.20, 3.00, 4.00, 1.00)

@onready var glass\_bg: ColorRect \= \$GlassBackground  
@onready var marquee\_display: CanvasGroup \= \$MarqueeZone/MarqueeDisplay  
@onready var label\_a: Label \= \$MarqueeZone/MarqueeDisplay/MarqueeLabelA  
@onready var label\_b: Label \= \$MarqueeZone/MarqueeDisplay/MarqueeLabelB  
@onready var chassis\_sep: ColorRect \= \$ChassisSeparator  
@onready var anchor\_action\_label: Label \= \$ConfirmationAnchor/AnchorActionLabel  
@onready var prompt\_glyph: Control \= \$ConfirmationAnchor/PromptGlyph  
@onready var vector\_overlay: Control \= \$VectorOverlay

var current\_state: TerminalState \= TerminalState.IDLE  
var current\_input\_scheme: InputScheme \= InputScheme.KEYBOARD

var marquee\_offset: float \= 0.0  
var marquee\_string\_width: float \= 0.0  
var current\_speed: float \= 38.0  
var active\_telemetry\_text: String \= BASE\_TELEMETRY

var bracket\_inset: float \= 0.0  
var corner\_reticle\_alpha: float \= 0.0  
var laser\_progress: float \= 0.0  
var led\_time\_accumulator: float \= 0.0  
var is\_flashing: bool \= false  
var current\_chassis\_color: Color \= Color(0.20, 0.45, 0.55, 0.85)

var active\_tween: Tween

func \_ready() \-\> void:  
	custom\_minimum\_size \= Vector2(720, 36\)  
	focus\_mode \= FOCUS\_ALL  
	  
	\_configure\_label(label\_a)  
	\_configure\_label(label\_b)  
	\_update\_telemetry\_metrics()  
	  
	mouse\_entered.connect(\_on\_mouse\_entered)  
	mouse\_exited.connect(\_on\_mouse\_exited)  
	focus\_entered.connect(\_on\_focus\_entered)  
	focus\_exited.connect(\_on\_focus\_exited)  
	pressed.connect(\_on\_pressed)  
	  
	vector\_overlay.draw.connect(\_on\_vector\_overlay\_draw)  
	prompt\_glyph.draw.connect(\_on\_prompt\_glyph\_draw)  
	  
	\_update\_input\_prompt\_label()

func \_input(event: InputEvent) \-\> void:  
	var prev\_scheme := current\_input\_scheme  
	  
	if event is InputEventKey or event is InputEventMouseButton:  
		current\_input\_scheme \= InputScheme.KEYBOARD  
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis\_value) \> 0.3):  
		var joy\_name := Input.get\_joy\_name(event.device).to\_lower()  
		if "sony" in joy\_name or "ps" in joy\_name or "playstation" in joy\_name:  
			current\_input\_scheme \= InputScheme.GAMEPAD\_SONY  
		else:  
			current\_input\_scheme \= InputScheme.GAMEPAD\_XBOX  
			  
	if prev\_scheme \!= current\_input\_scheme:  
		\_update\_input\_prompt\_label()  
		prompt\_glyph.queue\_redraw()

func \_configure\_label(lbl: Label) \-\> void:  
	if terminal\_font:  
		lbl.add\_theme\_font\_override("font", terminal\_font)  
	lbl.add\_theme\_font\_size\_override("font\_size", font\_size)  
	lbl.vertical\_alignment \= VERTICAL\_ALIGNMENT\_CENTER  
	lbl.autowrap\_mode \= TextServer.AUTOWRAP\_OFF

func \_update\_telemetry\_metrics() \-\> void:  
	label\_a.text \= active\_telemetry\_text  
	label\_b.text \= active\_telemetry\_text  
	  
	if terminal\_font:  
		marquee\_string\_width \= terminal\_font.get\_string\_size(  
			active\_telemetry\_text,   
			HORIZONTAL\_ALIGNMENT\_LEFT,   
			\-1.0,   
			font\_size  
		).x  
	else:  
		marquee\_string\_width \= label\_a.get\_theme\_default\_font().get\_string\_size(active\_telemetry\_text).x

func \_process(delta: float) \-\> void:  
	if current\_state \!= TerminalState.COMMITTED:  
		marquee\_offset \= fmod(marquee\_offset \+ current\_speed \* delta, marquee\_string\_width)  
		label\_a.position.x \= \-marquee\_offset  
		label\_b.position.x \= \-marquee\_offset \+ marquee\_string\_width  
	  
	if current\_state \== TerminalState.FOCUSED:  
		var perimeter := 2.0 \* (size.x \+ size.y)  
		laser\_progress \= fmod(laser\_progress \+ (perimeter \* 0.45 \* delta), perimeter)  
	  
	led\_time\_accumulator \+= delta  
	vector\_overlay.queue\_redraw()  
	prompt\_glyph.queue\_redraw()

func \_on\_mouse\_entered() \-\> void:  
	if current\_state \== TerminalState.COMMITTED:  
		return  
	if current\_state \!= TerminalState.FOCUSED:  
		current\_state \= TerminalState.HOVERED  
		\_transition\_to\_hover()

func \_on\_mouse\_exited() \-\> void:  
	if current\_state \== TerminalState.COMMITTED or has\_focus():  
		return  
	current\_state \= TerminalState.IDLE  
	\_transition\_to\_idle()

func \_on\_focus\_entered() \-\> void:  
	if current\_state \== TerminalState.COMMITTED:  
		return  
	current\_state \= TerminalState.FOCUSED  
	\_transition\_to\_focused()

func \_on\_focus\_exited() \-\> void:  
	if current\_state \== TerminalState.COMMITTED:  
		return  
	if is\_hovered():  
		current\_state \= TerminalState.HOVERED  
		\_transition\_to\_hover()  
	else:  
		current\_state \= TerminalState.IDLE  
		\_transition\_to\_idle()

func \_on\_pressed() \-\> void:  
	if current\_state \== TerminalState.COMMITTED:  
		return  
	current\_state \= TerminalState.COMMITTED  
	\_execute\_commit\_sequence()

func \_transition\_to\_idle() \-\> void:  
	if active\_tween and active\_tween.is\_valid():  
		active\_tween.kill()  
	active\_tween \= create\_tween().set\_parallel(true)  
	  
	active\_tween.tween\_property(self, "current\_speed", base\_speed, 0.35).set\_trans(Tween.TRANS\_SINE)  
	active\_tween.tween\_property(self, "current\_chassis\_color", color\_idle, 0.30)  
	active\_tween.tween\_property(self, "bracket\_inset", 0.0, 0.25).set\_trans(Tween.TRANS\_QUAD)  
	active\_tween.tween\_property(self, "corner\_reticle\_alpha", 0.0, 0.20)  
	  
	\_set\_glass\_tint(Vector4(0.015, 0.025, 0.04, 0.85))  
	\_set\_shimmer\_intensity(0.0)  
	  
	active\_telemetry\_text \= BASE\_TELEMETRY  
	\_update\_telemetry\_metrics()

func \_transition\_to\_hover() \-\> void:  
	if active\_tween and active\_tween.is\_valid():  
		active\_tween.kill()  
	active\_tween \= create\_tween().set\_parallel(true)  
	  
	active\_tween.tween\_property(self, "current\_speed", hover\_speed, 0.20).set\_trans(Tween.TRANS\_QUAD).set\_ease(Tween.EASE\_OUT)  
	active\_tween.tween\_property(self, "current\_chassis\_color", color\_hover, 0.15)  
	  
	var mat := glass\_bg.material as ShaderMaterial  
	if mat:  
		mat.set\_shader\_parameter("shimmer\_intensity", 1.8)  
		mat.set\_shader\_parameter("shimmer\_position", \-0.3)  
		active\_tween.tween\_property(mat, "shader\_parameter/shimmer\_position", 1.3, 0.45).set\_trans(Tween.TRANS\_CUBIC).set\_ease(Tween.EASE\_OUT)

func \_transition\_to\_focused() \-\> void:  
	if active\_tween and active\_tween.is\_valid():  
		active\_tween.kill()  
	active\_tween \= create\_tween().set\_parallel(true)  
	  
	active\_tween.tween\_property(self, "current\_speed", focus\_speed, 0.25)  
	active\_tween.tween\_property(self, "current\_chassis\_color", color\_focus, 0.10)  
	active\_tween.tween\_property(self, "bracket\_inset", 5.0, 0.18).set\_trans(Tween.TRANS\_BACK).set\_ease(Tween.EASE\_OUT)  
	  
	\_set\_glass\_tint(Vector4(0.010, 0.018, 0.03, 0.92))  
	  
	var blink := create\_tween()  
	corner\_reticle\_alpha \= 0.0  
	blink.tween\_property(self, "corner\_reticle\_alpha", 1.0, 0.04)  
	blink.tween\_property(self, "corner\_reticle\_alpha", 0.0, 0.04)  
	blink.tween\_property(self, "corner\_reticle\_alpha", 1.0, 0.04)  
	blink.tween\_property(self, "corner\_reticle\_alpha", 0.2, 0.04)  
	blink.tween\_property(self, "corner\_reticle\_alpha", 1.0, 0.06)  
	  
	active\_telemetry\_text \= LOCKED\_TELEMETRY \+ BASE\_TELEMETRY  
	\_update\_telemetry\_metrics()

func \_execute\_commit\_sequence() \-\> void:  
	if active\_tween and active\_tween.is\_valid():  
		active\_tween.kill()  
		  
	is\_flashing \= true  
	current\_chassis\_color \= color\_flash  
	\_set\_glass\_tint(Vector4(1.0, 1.0, 1.0, 0.98))  
	vector\_overlay.queue\_redraw()  
	  
	var commit := create\_tween()  
	commit.tween\_callback(func():  
		is\_flashing \= false  
		\_set\_glass\_tint(Vector4(0.01, 0.02, 0.03, 0.95))  
		current\_chassis\_color \= color\_focus  
	).set\_delay(0.03)  
	  
	commit.tween\_property(marquee\_display, "scale:x", 0.0, 0.08).set\_trans(Tween.TRANS\_CUBIC).set\_ease(Tween.EASE\_IN)  
	commit.tween\_callback(func():  
		active\_telemetry\_text \= COMMIT\_TELEMETRY  
		label\_a.text \= active\_telemetry\_text  
		label\_b.text \= ""  
		label\_a.position.x \= 0  
		label\_a.horizontal\_alignment \= HORIZONTAL\_ALIGNMENT\_CENTER  
		label\_a.size.x \= marquee\_display.size.x  
	)  
	commit.tween\_property(marquee\_display, "scale:x", 1.0, 0.12).set\_trans(Tween.TRANS\_BACK).set\_ease(Tween.EASE\_OUT)  
	commit.parallel().tween\_property(self, "bracket\_inset", \-18.0, 0.20).set\_trans(Tween.TRANS\_EXPO).set\_ease(Tween.EASE\_OUT)  
	  
	commit.tween\_interval(0.35)  
	commit.tween\_callback(func():  
		ignition\_committed.emit()  
	)

func \_set\_glass\_tint(tint: Vector4) \-\> void:  
	var mat := glass\_bg.material as ShaderMaterial  
	if mat:  
		mat.set\_shader\_parameter("glass\_tint", tint)

func \_set\_shimmer\_intensity(val: float) \-\> void:  
	var mat := glass\_bg.material as ShaderMaterial  
	if mat:  
		mat.set\_shader\_parameter("shimmer\_intensity", val)

func \_update\_input\_prompt\_label() \-\> void:  
	match current\_input\_scheme:  
		InputScheme.KEYBOARD:  
			anchor\_action\_label.text \= "\[ EJECUTAR DESPLIEGUE "  
		InputScheme.GAMEPAD\_XBOX:  
			anchor\_action\_label.text \= "\[ EJECUTAR DESPLIEGUE "  
		InputScheme.GAMEPAD\_SONY:  
			anchor\_action\_label.text \= "\[ EJECUTAR DESPLIEGUE "

func \_on\_vector\_overlay\_draw() \-\> void:  
	var r := Rect2(Vector2.ZERO, size)  
	var col := current\_chassis\_color  
	  
	if is\_flashing:  
		vector\_overlay.draw\_rect(r, Color(3.5, 3.5, 3.5, 0.95), true)  
		return  
	  
	\# Delimitación estructural de 1 píxel  
	vector\_overlay.draw\_rect(r, col \* 0.5, false, 1.0)  
	  
	\# Hilo superior de carga pulsante  
	var breath: float \= 0.55 \+ 0.45 \* sin(led\_time\_accumulator \* 2.0)  
	vector\_overlay.draw\_line(Vector2(0, 0), Vector2(size.x, 0), col \* breath, 1.0)  
	  
	var h := size.y  
	var cut := 7.0  
	  
	\# Corchete Izquierdo \[ //  
	var lx := bracket\_inset  
	var left\_bracket := PackedVector2Array(\[  
		Vector2(lx \+ cut, 0),  
		Vector2(lx, cut),  
		Vector2(lx, h \- cut),  
		Vector2(lx \+ cut, h)  
	\])  
	vector\_overlay.draw\_polyline(left\_bracket, col, 1.2, true)  
	vector\_overlay.draw\_line(Vector2(lx \+ 4, cut), Vector2(lx \+ 9, h \- cut), col \* 0.6, 1.0, true)  
	vector\_overlay.draw\_line(Vector2(lx \+ 8, cut), Vector2(lx \+ 13, h \- cut), col \* 0.6, 1.0, true)  
	  
	\# Corchete Derecho // \]  
	var rx := size.x \- bracket\_inset  
	var right\_bracket := PackedVector2Array(\[  
		Vector2(rx \- cut, 0),  
		Vector2(rx, cut),  
		Vector2(rx, h \- cut),  
		Vector2(rx \- cut, h)  
	\])  
	vector\_overlay.draw\_polyline(right\_bracket, col, 1.2, true)  
	vector\_overlay.draw\_line(Vector2(rx \- 9, cut), Vector2(rx \- 4, h \- cut), col \* 0.6, 1.0, true)  
	vector\_overlay.draw\_line(Vector2(rx \- 13, cut), Vector2(rx \- 8, h \- cut), col \* 0.6, 1.0, true)  
	  
	\# Diodo LED de telemetría de vuelo  
	var led\_pos := Vector2(lx \+ 20.0, h \* 0.5)  
	var led\_intensity: float  
	var led\_col := Color(0.40, 2.00, 2.60, 1.00)  
	  
	if current\_state \== TerminalState.FOCUSED:  
		led\_intensity \= 1.0 if fmod(led\_time\_accumulator \* 3.0, 1.0) \> 0.45 else 0.1  
	else:  
		led\_intensity \= 0.4 \+ 0.6 \* (0.5 \+ 0.5 \* sin(led\_time\_accumulator \* 2.5))  
		  
	vector\_overlay.draw\_circle(led\_pos, 2.0, led\_col \* led\_intensity)  
	vector\_overlay.draw\_arc(led\_pos, 3.8, 0, TAU, 12, led\_col \* (led\_intensity \* 0.35), 1.0, true)  
	  
	\# Retículas HUD de Enclavamiento en las cuatro esquinas  
	if corner\_reticle\_alpha \> 0.01:  
		var ret\_col := color\_focus \* corner\_reticle\_alpha  
		var arm := 8.0  
		vector\_overlay.draw\_line(Vector2(-3, \-3), Vector2(-3 \+ arm, \-3), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(-3, \-3), Vector2(-3, \-3 \+ arm), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(size.x \+ 3, \-3), Vector2(size.x \+ 3 \- arm, \-3), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(size.x \+ 3, \-3), Vector2(size.x \+ 3, \-3 \+ arm), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(-3, size.y \+ 3), Vector2(-3 \+ arm, size.y \+ 3), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(-3, size.y \+ 3), Vector2(-3, size.y \+ 3 \- arm), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(size.x \+ 3, size.y \+ 3), Vector2(size.x \+ 3 \- arm, size.y \+ 3), ret\_col, 1.2)  
		vector\_overlay.draw\_line(Vector2(size.x \+ 3, size.y \+ 3), Vector2(size.x \+ 3, size.y \+ 3 \- arm), ret\_col, 1.2)  
		  
	\# Trazador de láser horario perimetral  
	if current\_state \== TerminalState.FOCUSED:  
		\_draw\_laser\_trail(r)

func \_draw\_laser\_trail(bounds: Rect2) \-\> void:  
	var total\_p := 2.0 \* (bounds.size.x \+ bounds.size.y)  
	var trail\_len := 48.0  
	var steps := 8  
	  
	for i in range(steps):  
		var factor := float(i) / float(steps)  
		var dist := fmod(laser\_progress \- (factor \* trail\_len) \+ total\_p, total\_p)  
		var pt := \_sample\_perimeter\_point(bounds, dist)  
		var next\_dist := fmod(dist \+ (trail\_len / float(steps)), total\_p)  
		var next\_pt := \_sample\_perimeter\_point(bounds, next\_dist)  
		  
		if pt.distance\_to(next\_pt) \< (trail\_len \* 1.5):  
			var col := color\_laser \* (1.0 \- factor)  
			vector\_overlay.draw\_line(pt, next\_pt, col, 1.4, true)

func \_sample\_perimeter\_point(b: Rect2, d: float) \-\> Vector2:  
	var w := b.size.x  
	var h := b.size.y  
	  
	if d \< w:  
		return Vector2(d, 0\)  
	d \-= w  
	if d \< h:  
		return Vector2(w, d)  
	d \-= w  
	if d \< w:  
		return Vector2(w \- d, h)  
	d \-= w  
	return Vector2(0, h \- d)

func \_on\_prompt\_glyph\_draw() \-\> void:  
	var center := prompt\_glyph.size \* 0.5  
	var glyph\_color := color\_hover  
	  
	match current\_input\_scheme:  
		InputScheme.KEYBOARD:  
			var box := Rect2(center \- Vector2(7, 6), Vector2(14, 12))  
			prompt\_glyph.draw\_rect(box, glyph\_color \* 0.45, false, 1.0)  
			var pts := PackedVector2Array(\[  
				Vector2(center.x \+ 3, center.y \- 3),  
				Vector2(center.x \+ 3, center.y \+ 1),  
				Vector2(center.x \- 3, center.y \+ 1\)  
			\])  
			prompt\_glyph.draw\_polyline(pts, glyph\_color, 1.0)  
			prompt\_glyph.draw\_line(Vector2(center.x \- 3, center.y \+ 1), Vector2(center.x \- 1, center.y \- 1), glyph\_color, 1.0)  
			prompt\_glyph.draw\_line(Vector2(center.x \- 3, center.y \+ 1), Vector2(center.x \- 1, center.y \+ 3), glyph\_color, 1.0)  
			  
		InputScheme.GAMEPAD\_XBOX:  
			prompt\_glyph.draw\_arc(center, 6.5, 0, TAU, 16, glyph\_color, 1.0, true)  
			var ring\_scale: float \= 8.0 \+ 1.4 \* sin(led\_time\_accumulator \* 4.0)  
			prompt\_glyph.draw\_arc(center, ring\_scale, 0, TAU, 16, glyph\_color \* 0.35, 1.0, true)  
			var a\_pts := PackedVector2Array(\[  
				Vector2(center.x \- 3, center.y \+ 3),  
				Vector2(center.x, center.y \- 3),  
				Vector2(center.x \+ 3, center.y \+ 3\)  
			\])  
			prompt\_glyph.draw\_polyline(a\_pts, glyph\_color, 1.0)  
			prompt\_glyph.draw\_line(Vector2(center.x \- 2, center.y \+ 1), Vector2(center.x \+ 2, center.y \+ 1), glyph\_color, 1.0)  
			  
		InputScheme.GAMEPAD\_SONY:  
			prompt\_glyph.draw\_arc(center, 6.5, 0, TAU, 16, glyph\_color, 1.0, true)  
			var ring\_s: float \= 8.0 \+ 1.4 \* sin(led\_time\_accumulator \* 4.0)  
			prompt\_glyph.draw\_arc(center, ring\_s, 0, TAU, 16, glyph\_color \* 0.35, 1.0, true)  
			prompt\_glyph.draw\_line(Vector2(center.x \- 2.5, center.y \- 2.5), Vector2(center.x \+ 2.5, center.y \+ 2.5), glyph\_color, 1.0)  
			prompt\_glyph.draw\_line(Vector2(center.x \+ 2.5, center.y \- 2.5), Vector2(center.x \- 2.5, center.y \+ 2.5), glyph\_color, 1.0)

## **9\. Síntesis Técnica y Consideraciones de Rendimiento**

La arquitectura descrita para la Terminal de Ignición Orbital consolida un elemento diegético avanzado capaz de operar sin incurrir en costes computacionales desmedidos. El uso de sombreadores de pantalla y generación procedural analítica asegura una apariencia militar e industrial que preserva el rendimiento gráfico en tiempo de ejecución.  
El aislamiento del área de muestreo mediante el modo rectangular de BackBufferCopy restringe la captura de fotogramas estrictamente a los píxeles que ocupa el panel, evitando la saturación del ancho de banda de memoria que provocaría un copiado continuo de pantalla completa8. Asimismo, la concentración de las geometrías de interfaz (líneas perimetrales, retículas angulares, brackets móviles y diodos luminosos) dentro del método \_draw() del nodo VectorOverlay consolida los elementos en primitivas vectoriales nativas que el motor agrupa en lotes de renderizado eficientes13.  
La integración entre la máquina de estados reactiva de BaseButton, el postprocesamiento en espacio de color HDR y las funciones matemáticas continuas permite que la terminal funcione como un elemento narrativo de instrumentación táctica1. El dispositivo transmite estabilidad durante la configuración de sistemas y tensión latente previa al lanzamiento orbital, respondiendo de forma coherente ante cualquier método de control sin romper la estética del puente de mando23.

#### **Obras citadas**

> 1. Dev snapshot: Godot 4.2 dev 3 \- Reddit, [https\://www\.reddit.com/r/godot/comments/15ob5hi/dev\_snapshot\_godot\_42\_dev\_3/](https://www.reddit.com/r/godot/comments/15ob5hi/dev_snapshot_godot_42_dev_3/)  
> 2. Made a 2D glow screen shader with support for rgb values above 1.0, [https\://www\.reddit.com/r/godot/comments/1fyd6sp/made\_a\_2d\_glow\_screen\_shader\_with\_support\_for\_rgb/](https://www.reddit.com/r/godot/comments/1fyd6sp/made_a_2d_glow_screen_shader_with_support_for_rgb/)  
> 3. Vulkan: Environment \`background\_mode\` set to Canvas causes 2D, [https\://github.com/godotengine/godot/issues/52467](https://github.com/godotengine/godot/issues/52467)  
> 4. Godot \- How to Add Glow/Bloom to 2D Scenes (Correct Setup), [https\://www\.youtube.com/watch?v=tGZPqp61Hjg](https://www.youtube.com/watch?v=tGZPqp61Hjg)  
> 5. Tutorial: How to get a nice Glow effect in Godot ( \+ Post-Processing, [https\://www\.reddit.com/r/godot/comments/nmxfa0/tutorial\_how\_to\_get\_a\_nice\_glow\_effect\_in\_godot/](https://www.reddit.com/r/godot/comments/nmxfa0/tutorial_how_to_get_a_nice_glow_effect_in_godot/)  
> 6. Godot Engine Official Documentation | PDF \- Scribd, [https\://www\.scribd.com/document/817383768/Godot-Engine](https://www.scribd.com/document/817383768/Godot-Engine)  
> 7. ProjectSettings — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_projectsettings.html](https://docs.godotengine.org/en/4.4/classes/class_projectsettings.html)  
> 8. Godot 4 hint\_screen\_texture: Full Guide to Syntax & Errors | GTStudios, [https\://gtstu.com/godot-4-shader-tutorial-visual-effects/](https://gtstu.com/godot-4-shader-tutorial-visual-effects/)  
> 9. Rain on Glass \- Godot Shaders, [https\://godotshaders.com/shader/rain-on-glass/](https://godotshaders.com/shader/rain-on-glass/)  
> 10. Hexagon pattern \- Godot Shaders, [https\://godotshaders.com/shader/hexagon-pattern/](https://godotshaders.com/shader/hexagon-pattern/)  
> 11. Simple way for sprite masks in Godot 4, [https\://godotforums.org/d/36452-simple-way-for-sprite-masks-in-godot-4](https://godotforums.org/d/36452-simple-way-for-sprite-masks-in-godot-4)  
> 12. GradientTexture2D — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_gradienttexture2d.html](https://docs.godotengine.org/en/4.4/classes/class_gradienttexture2d.html)  
> 13. CanvasItem — Godot Engine (stable) documentation in English, [https\://docs.godotengine.org/en/stable/classes/class\_canvasitem.html](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)  
> 14. CanvasItem — GEQO (latest) documentation in English, [https\://geqo-docs.readthedocs.io/en/latest/godot-docs/classes/class\_canvasitem.html](https://geqo-docs.readthedocs.io/en/latest/godot-docs/classes/class_canvasitem.html)  
> 15. simple glass broken \- Godot Shaders, [https\://godotshaders.com/shader/simple-glass-broken/](https://godotshaders.com/shader/simple-glass-broken/)  
> 16. Smooth anti-aliased sprite outline \- Godot Shaders, [https\://godotshaders.com/shader/smooth-anti-aliased-sprite-outline/](https://godotshaders.com/shader/smooth-anti-aliased-sprite-outline/)  
> 17. Your First Shader from ZERO in Godot 4 | GDQuest Library, [https\://www\.gdquest.com/library/first\_shader\_godot4\_portal/](https://www.gdquest.com/library/first_shader_godot4_portal/)  
> 18. Font.get\_string\_size() always return the same size without checking, [https\://github.com/godotengine/godot/issues/63328](https://github.com/godotengine/godot/issues/63328)  
> 19. Font — Godot Engine (4.4) documentation in English, [https\://docs.godotengine.org/en/4.4/classes/class\_font.html](https://docs.godotengine.org/en/4.4/classes/class_font.html)  
> 20. Line width issue when drawing with draw\_polyline compared to, [https\://godotforums.org/d/41746-line-width-issue-when-drawing-with-draw-polyline-compared-to-draw-line](https://godotforums.org/d/41746-line-width-issue-when-drawing-with-draw-polyline-compared-to-draw-line)  
> 21. Bite-Sized Godot: Custom cursors \- The Shaggy Dev, [https\://shaggydev.com/2021/09/28/custom-cursors/](https://shaggydev.com/2021/09/28/custom-cursors/)  
> 22. Mouse trail has 1-frame delay, is there anything I can do? \- UI, [https\://forum.godotengine.org/t/mouse-trail-has-1-frame-delay-is-there-anything-i-can-do/38852](https://forum.godotengine.org/t/mouse-trail-has-1-frame-delay-is-there-anything-i-can-do/38852)  
> 23. How to make Godot detect if you're using a keyboard/controller, [https\://www\.reddit.com/r/godot/comments/11rjm8h/how\_to\_make\_godot\_detect\_if\_youre\_using\_a/](https://www.reddit.com/r/godot/comments/11rjm8h/how_to_make_godot_detect_if_youre_using_a/)  
> 24. Made easy by Godot: automatic switch between Gamepad ... \- Reddit, [https\://www\.reddit.com/r/godot/comments/lpzbzb/made\_easy\_by\_godot\_automatic\_switch\_between/](https://www.reddit.com/r/godot/comments/lpzbzb/made_easy_by_godot_automatic_switch_between/)  
> 25. Fix: Godot Controller/Gamepad Input Not Detected | Bugnet Blog, [https\://bugnet.io/blog/fix-godot-controller-gamepad-input-not-detected](https://bugnet.io/blog/fix-godot-controller-gamepad-input-not-detected)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGYAAAAaCAYAAABFPynYAAAEO0lEQVR4Xu2YXahVRRTHl5RQmJUlShhkEkoaooiIUFKhUvSBpPWQ+iQYhA+iqFgP3oiIgj41gj6w6CUyqCAJKfCSEmUQ9KD1Eln4AYX2kkGG1v/n2sPZZ/aefc8+91wlmB/8uWfP7Ltnz1qz1prZZplMJpNJMF6aI62S7pSuKNrHSbdIlxXXmR65Szop/VvSb9JZ6Zz0jbTS0oa9WnrV/P5h6SnpGek76T5pq/RyuLngOmmf+fPDmPw+Zv4crn80HxfHXkqY9yPS9Ki9iSulR6U3pOelWd3d7XhL+ke6vdTGS603NxoGjo10t/S79Il0Y9R3vfSVuZEfivoCS6Xz0hNROxN7x3zcB7u7LgqM/4D0inRcOiMt6LojzTXS59LT0lXSPOmI+SJrzUTpgPSTNDXqu0H6paYPY7O6WRWksToek05Jt8YdBdvMHYODYjAMTn037oggZYa0OShwzL3mKXmHtXMMc/pWmlRqWy39YFXbjgiGw4AfSpdHfQulv6TD0uSijVpCpBwyj4wUGBeH4/gYxmG8o9K07q4LMEEcMxS1x8wwX6HPWfO79Avv0atjcAZOiRcTNvzT+oh+/gEjsMJjhsz7NhfXRMcH5is9laICOIb6UwfOOCrtteqKn24eod9bNUXWQYqdK30mvS3d3N09Kto4Jizw2DH8L8+g9rYC48X1BQesMx9oS3ENi6W/rTuCUmBw8mwdjMWYrHTSZRDO/lnaab6xaAuFdk+hURXdgjaOCQ5IOSZubwTDDZvXC4o1v8mHRMnrVk0PIcWkIqFXQn35yLxOBZH6PpZmd27tC6KG6PlSWmTVjUuvtHFMqi725Zi6+sIktpvvipYVbQEenkp7OLm8+tEUq261m+oLkbnbfKHUbQrawju8Zv07qI1j2DAMzDGhvmyK2sPD2EaXCY5hdcQ8bL7aT1vnPPSSdG35JmuuLxBWXjx2vxD1RP9Ba3cegTaOSTkg1d5IXX0BtngYJy5Y3J9yTCCkO55RR+r8Ethgg0mXRMsuab/1Fy3QxjHsEDmsxw4IjknNt0LT+SU4gBcrc4+5UZlw3USJACKh3/MLq5tt+B/S/KivV6gvb0qfmu/W6t6zV5ocQ9q9qfgLoV7HmYB5tkrNt5kbID6/8JstcdkxT5o/mJegSLMzu7/oK7PSvDbFh6xAcNwxq26FMSi1gEmMtBWPwfhjsWVm/pzjFsYd4gVzGw2V2tZIv1pnfN6LrwBfm38VaOQO89M8Dw2iHpQPQMHAOGit+QrkRAwTzCOK/mHp8UJfSO+ZR9WO4t4AkcBBMHwLC2MyCcQBDDFO7LAmmDhpinRFFJO+Rgvze986tTLohPRi6b6N5vPBVgEWLvWM91lh7pTD5p9mBgbpjVrCziw4pQwrYLl1viinzixjCTuhZ626rb+UsFhmmttliaU/WWUymUwmk8lkMpnM/5r/ANzBBDOhm/yhAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,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>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHoAAAAaCAYAAAB4rUi+AAAFWElEQVR4Xu2ae6hmYxTGH6HI3bhfMsO4RoghJQ4h/iCZEblOKaQpt8adTuEPcoloyiWXEjNMkkZu5US5R4QRSYmUQgnlbv2s/drvt87e37fP/o7xnZn91NN3znr3917Ws971rnefI3Xo0KHDqsCGxm2NWxvXDW1rMjaV+2WWca3QNiNxufF54x3G2b1NazTOMT5gXCbfDDMeCH18NBp2N95svMd4mnH93uZG2ETurH1iQwMwHuMyPvNgPk2xsfFC+XevNe7Y26z1jGcZ9y5+Xtu4g/Fc9QY7At9QfM54VAk93/iRcT/5Iq83viAXrilId1cafzIeENoGgXEYj3EZn3kwH+Y1CDsZnzMeK0+9Y8b3jCdlz5CW3zD+FXiLeo+vkRM6nbM5m04uCk30f2o8PbNtZnzLuCizDcLBxu/UTmjmxHiMm8B8VspriToQXHepV1SA6C+rDFR8s8L4gfEz44Py+cazeGSE3sv4kvFFeZqCFxgXGPfMnuuHKDQOjeLggEeME2q2aBx6r3w+sa9BSEH1ULDPM/5oPCHYczC3CePCXvM/47+tMkh4jv7ZEP0wLUIzKA4ek58TUwGOXygvFDhbhkEU+k5Vi4NjvjbuHOwRzO0SeZql76q++oEA/VaThaYP+rox2HOsY3zC+KtxsTwNpyNkSdEOVonQ28gn86TxVOPVxi+NBxbt2xt3LX6uA4terqmdmXWIQuOAKnHq7BEHGW+VO7mN0EnQOqGjPYLxv5efuW8ab5f7OvcVwi013iZP318Zn9LkW0droSkU6JiUlg59ouxR47PySvMa46FFWxWIUKrQQ2JDS+RCp9RXJU4ToXEma5td/N5GaOaCSFHQpkKDI4y/qCyyrlPvrYF1UrCdIvcnpPD7RK5R/tyUhUbQ++S7d05owyE/yIsGriP9diqD3m3cQ5MLsJxNj4Nc6A3k532VOIOExlkXG0/ObG2EPk7DCU2F/o7xRHnK/kPe38MqxWauGxWfCfOMPxvHM1srodPZQ9pOZ0VCKoAQmSjrBwblbObZVIBVEYc1wXSl7v1VpuyENkLXCVpnz7GVXOS86qZgfdf4p3wj1SH1T6AT8KCV0CklnRcbVLY9rcEvJtip7GjO8ulAFJpip0ocHEw2qiv+zjd+EUiVzLq+Mb4iF2IQKPYo+qKgSYirgj0Hwc3RuEWwU/iulK8V3GT8zXj0v0+U/U+oFLaV0Ckl5U5NwPa78fDYUAOCpSpg2iAKzfWFdHdUZiO4VhRMRwI7l/Os3/vxuh2N42Zp8r0VpDohHwswH6rpfF4ccdup7Id1xPs3oJ3rYfIZQcQac6FT6iZTpv5aCZ1eRCzKbHR4pPFjlUHAjokRGcECSd/5otsiCo0AVKvjmW2ufDdzS0ggTTPn8cwWwe7DeTgxgf55U0WxVFdQniHPCHOK3/ETxdLrKuuXqn7wHbZ4/FHPvKayP9ZxhUpB+eQ8p1qnak9oJTRA1M+Njxvvl0/8UuOWxmfkDqb6ziu/Omwur9ZJ47vI39e2QRQacNVjnpfJX76wS0h3+e69SL7D5me2BAKQdE0gQHbPq/LUjdNYK2fm4vSFAMZZIn8ZRFGFyB/KC62E1E+slBGd1E/xhaDMm7SN7xPoH78tN54tf5b6KdY1rYUGCMKCY+rCzk7ulwoj+D5pkb88kRXy8/HM7Ll+qBIaUJAcI3d0/KPAdIBgyLNbBGvbTR5oh2lqfuFZvtPvu3n/Y6q+pQwl9KihTuj/GmSLutQ9KuiEHhL7yt8pDLph/N/ohB4SqegcdaxWQqf77/tq9w8Cqyt4D45fHlP5AqVDhw4dOnToMEPxN/auJx/ZP/tQAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,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>

[image5]: <data:image/png;base64,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>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAaCAYAAADBuc72AAACeElEQVR4Xu2WS6hNURjH/0IIeVyRIpGUx0DdUoqJKI+ijAwYeiSSgZSJWzIyUB55pGQgJZFQRIiSMFTkkYkyNFPI4/+/31r3rvNZa+99LyfU+dWvs8/69tpn7bW+b60DdPh/GE7H+cYMukf3/hX046foIh/IoHvOo9lL9TGPvqE/Ej/RpSF+1MXe0TkhFhlGj9Ntrr2KjfQkBjGzi+ln+ppOTdpH0Ct0Px2dtKesoPeRn6HJ9C7d5NpH0Wt0vWuvRR1v0u90ZWgbQvcEdZ0j9tvhA4Hl9Ev49Gygj5B/wUrUUct7AbYkGuChcF2iG7YKc30gsI9+oLN8ANamtFviA3VMoS/oR3oAlp9VgxRb6UM6NmkbClvyGfQ2vUdn0vHJPUKpdAf2MgPmIGxWH6DZkpwLpkynh2G5rVR6Rk/TLfg1hdRXO4Bvr2U17OGPUT/QMbAi0svlqMrPyF7YM/SsxijPVKGv0FpUJeJA9WM5qvIzor5P6QQfKKF8ukpno7WotEeWqBroSHojqOsS6vsWVh+1aIkvov9USYtqQbwpQ9VAp9H3KKdFpPHSa5CX6RrX3gObVX2W0Gxfomd8AJaX3+iq8F0n3c7+cB96EVV+6TDpRVuGlnu3D8D2tq/0Ce1ysZQjyC+vtq2Yn5qME7D0SlGlq+L1jCw6zlSN8fzWm69L4ttDWxq/RScm90TW0ud0kmvX/4GXsC3qOl3YGu5FBaSJ0DPajlZFA8qdLjostPGXDg39v1At6BltR8unU+xYuG5K7CcH0u+3UIXrmJzvAxVoG1QR+bxtO9ratMXVnWZCqXAWg/iL96dYRnf5xgybUX/qdejwz/MTNW52mpLpn24AAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,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>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAaCAYAAACHD21cAAAAuUlEQVR4XmNgGHnAEYhfA/F/JPwLiHcDsTCSOpxgDhD/A2IPdAl8QBCITwPxAyCWRpXCDzSB+C0QrwFiFjQ5vCCaAeK3cnQJQmASEP8GYht0CXwA5r+7QCyOJocXEPIfGxCzoguCAMx/RegSQMAIxE1ArIMuAQKg+MPlPxUgngvEnOgS+OIP5LxZDBAXYQBjIP7KgOk/SQaIpkdArIgkzuACxM8YEGnzLxA/gWIQGya+nAF7gI2CkQgA+LEntuOlP9kAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,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>

[image10]: <data:image/png;base64,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>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADoAAAAaCAYAAADmF08eAAACnklEQVR4Xu2XS6hNURjH//LIM3knRJISoUQGDJQBCsWEmBmYKHmljM7g3rHXgERKSR4TRUJ5lCjGYiIxIAOUgYES///59mrv85291jmDu0/n1P7Vr31b39737m+vb31rXaCmphdMpuP9oGM0nUZH+cCgsJpepVN9wKEEj9Ej2c89YxP9Rf8V/EiX0on0nou9pDOaT+bMp0/pcjceYyy9Rnf7QC/YA0vkMZ1UGJ8FS+4A7AU9mpUztOHGA8voG7rRja+gr+gCN145c+g7+hP2EkKJnUf6y+ve99m1jIP0OyzhImPoDcQ/UKU0YLOqa0jyENJr6SS9j/ImpOeuw2ZUDcizD/FYpWhWNKOaodP0BNJJKjklecqN6yOpQrRm9bvUpObCunKRVfQTXevGK0fldAc2q3q5sjVZRC+vF93uxlfSi/QR7HfpeonuKN6E/PldbrwnHIa9nNaPEk+xhn6jG3wgI7Y+A5rhZ7DyTxJKRF+mk7Nhm3WKzfQ5/YLWphRDiX7Orp5O61OERIfdeBvapFUS3XiWLmo+Vc46eptOR2tTSpFKdCZ9S8/5QIGQ6GU3XhkL6d3sKkJT0najiomRSlQN5jess8bounRHAiX3EFYdgbDHaVZ1kIixGFbmW30Atj514lJnFXvpzjzcRCWt0j7qxkcUrSF1R/2hbS4mNBNK9Bbi3TeUp5LyqGTD+tTHvID2c7COjh9gvaEShuhf5OfXH2gtP63nEJN/6BU6rnCP0MfSNlS2DtWJv9KbsC1LSXl0jz7UPB/oR1Tar1HeWXWgSHX7BrrbxvoC/Sfzgm7xgQ7ouSdoP+z3NTrxaGua4AMJ9sNOT7H135dorepc3OlsHFhCHyDfzgYKzcxxut4HHFNgJ6Gy5lRTUzNg/AcnU36G5IJ7iAAAAABJRU5ErkJggg==>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGEAAAAaCAYAAACn4zKhAAADe0lEQVR4Xu2YWchNURTH/zJkTHyGhAxJiVAiDzwoZchQvhfizYMXJVPK033giTIWiW4pyVBSJEN8Iopn8SKRiEJJHpRh/e+6u3vuuvvsc+7QvR/2r/6d297n3M5ea+211tlAJBLpvQwVDbSDhr6iEaI+diLSPHNFRdFwO2Gg8XeKtpd/R4Qloq+i3wm9Ek0XDRZdM3OPRF2lJytMEN0TzTTjafQXnRV124k2M0r0ANXro16LFifuaxvroS9wWzQkMT4aavjNUONZGM2HRQUz7pgheoraRc0SPRZNNOOdYAV07cfR4d05VvRc9AVqIEKjH0M4Ynnvi/LVxxbRJ6gzkvQTnUe687KYIzpoBxtkP9QJa+xEJyhAX4ZX54CtCEfHHtF1+AsynzsH3QksxpaNSJ/LYh70/ZqF7833fy+aauY6AqOZO4GRfUi0G2EHuAXsNeN0IHcWawT/qygaB+2ekjCamX/nm/E8tMoJNDwd0IPa9+sITBGXobuBhvPVgCQ0LI242ozPFp0U3YL+F6+nULvd3fPrzHgeWuWEpaJf0JTUa9gGNRzzNZ0Sgob4IFpkJ8qk1QMHI68HmtLqpVVOcPWAxbkh3LZnRGVpDPRDKQSj4r7oHaoLdBo0xJvy1ZJVD4hzQigK+T9sie16lonOeMYpX33ykVUPaC+26UH4gcRtnkdHRJNLT/lZILokGonqAh0i5AT24M9ER+1EAueE02Y8CYPnAGrXcwVab+w4lTeqXT24g+q23LEcupvbwiTR1fKVuALNlpU7LY2QE1hsv0M7oDQ6nY7c94FvJzLLnEB2NmgJNPxN6K5yuB6eL8iPuDQYSUxdvshjBPFLnB0Q2SBaW5kuwTTFdLXDjOehFU4IfR90Q9NpVl1sCuZadjE0wkozRxjBfMGLSO+SXMrxbVmmIVcP6GhGlT1X4nHHS2gtqpdmneB2oa0Hg6CnA98QDsCm2Sf6icpZyWdUpxTWDzdH/YAWwQGJewgdWYQ/77Nj4gIvQNteGtzCe+jE8XYiB406gTWG50Vck1vfR2hapeHd2FvRlPIzvR5GyxP4OyB2H6GurIB8rbCPRp3wT9IlegjtJOqBz91F7cFeXtiKrrKD/zMsbGxvmU/zsgn6VZ1WbyJ1wtrAc6assybHNNENVFriSItgRO8SLbQThmHQ1tBXqCORSCQS+Sv5A4X4t/2uytoaAAAAAElFTkSuQmCC>

[image13]: <data:image/png;base64,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>

[image14]: <data:image/png;base64,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>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAAAZCAYAAABkdu2NAAACpUlEQVR4Xu2WTahPQRjGH6HIVyLlq1uSKDckSkl3oWTBAgulbCSyEUKRhWRhQbKUdCX5SFmRZHGLhVgpKx+FBaUuEQr5eJ7eGWdmzpnz/5+bdBfnqV///3lnzjnvc2bmnQFatWo1XDSR7CZnyVEyj4yIeuQV3nuETI+bS9pJPpPfAe/JatJLniZtP8lVMk43D0WLyADpI5PJDvKd7ENnkz3kMdlOxpC1sASXh50yOgQzcDBtoJaRr7C8xsdNzXUG9pXWu2uZfEQGyQLfqUKjyDly3f33Ok5uk7FBrEoyJoPr0gZqKfmCf2TwJOxF29z1BHKPfIKNbk5zyFuUR2ADLDklWaf/ZnA0mUpGuuuF5AM6P1xr5hfKBpWwEt+SxFM1Naj8psHWeEpdnpFUMC6R12Rx0pbKG8kZTOOpvMGtKCe8BuU1qPgr8gRW0ITWfzj7slKFugIz9gL2Aj+iOfkEUyNNDd5BkbDnBmx2DKAwqFHV2p7krlXINNOuwWZh15pP3pCLqC/Ne1FtpKnBbqeoYqfcf5m8C6vYPS7WtbQ1aJrq5dqzcsoZycVTNTWoUdIHV36nEVf+rHTTHkc4zP7lF4JYqpXkB8pGvEFV0zo1Nei1EfbeAzCzveRw1COQf1Ba1mVML9ce6aVpMQPF5j+TvETcR9JBYRD1e6g0FIOajpqWmp5+LWoU9//tkWg2eUb6UdwwhTyELeAlQUwV6xtZ4WIyeow8QHGvZoEW/WXEm3+V6k4yVQb1q4Kk+jDXxXSY6Id91Kx0vHpOTpDN5Cb56OJeevgtlBe1jCmus6L6nyf3yaygTyqt63cwcx4l7c+i2ga0vnybzq2q8LvctY6RqvbCn2mrZkEknSP7yCayCs3KrrYTfXHdq99O20urVq1atWo1HPQHezeyQyVC1y4AAAAASUVORK5CYII=>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADYAAAAZCAYAAAB6v90+AAAC3UlEQVR4Xu2WTYhOURjH/xOKfKchHzVjkvJRs1BKLCx8RNmgFCUl2ShhoREriZkUYSWRlc9IMglpGpJYSGEhChtJ2LCQGP9/zzndc8/7nnvHZl5v3X/9eud95tz3nP85z/OcC1SqVGmoNIpsJKdJD5lLWnIj0hpHdsKePUCm5v/dOI0n18hm2KI6ST/Zg3JzbeQ52UZGklXkNVkYDmqUdpB9UWw+eUZmRvFQw8kZctX97XWI3IZlQUN1nnQjfzo6ORnT6aXUQT6SvVF8LflBFkTxIZd2eICcIKNdbAO5Rcb4QXW0jPxBrbE1sN/bFMW9JsBSWOOmw1J4qfs+KRuGEWQKbJPFZFhmaEwYG+YfiKVJVBdazBuY0QcuXiRvIGUsjnvtIp9gY56Q67BNOAw7aZWGsqed3CDf3dhHsI244r4rfhG2UUnNIR9gDwilp7pdkbTwegbKjElKU5k4imzHZeYg+U2Wu5jUTt7Cuq5OcQustktreAbshLbDOqMm9DsUpkas3ahv4F+MxWPUtL6htiGtg41Xk7sA6+SFkuubyE8go0oBLU5pkVLKQCoeKmVMdfOePCUTg7hO8zisplcH8aTU9VRfSsVQMqyWrZRMaQn5hdrFeWPqjimVGVMGjQ3iMrYf9sw9DOLENMErWOuOpWNXp/TSj01Ddi2okN8hP0ZSSn9B7WaFShlbRH6SU8hfP0rFk2QxLFVVi4UvD2rnd0gX8gNbSR9sIkm1pjcMTepjvtgfI9tBFfdlWB2ENRLLGzsHe0bSp75/JvNcTHOshN2pKhFJ5aEGI7OFmgVbtAyq7eqkXsIaiTerDeiFpW2bi0kypPgl2OvUWfIQ2SJS8sbuk7uwjvcC1v5nuzErYAZ8p1az0j2rVPSxr7D7NCm1XE22HvaD/qIejMJn9Zm8MAOFqajxumiVFYXp1QxK1VhTS28K6pzqqMdQ8lrUTNoKqynPEZS8FlWqVOn/0l9wyptPSUUHnAAAAABJRU5ErkJggg==>

[image17]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADYAAAAZCAYAAAB6v90+AAAC0UlEQVR4Xu2WS6iNURTH/0KRd0Re3ZuBiEJKiXQHHlEMMFAmSmKgxB0oMZCEIsJI8kjyLBmQIimSGEgZeRQGJCFigDz+f2uvvn32Pft890zuubfOv36db69vfefba39rrb2Bpppqqqs0mGwix8hOMpH0qvDIK352BxldebtxmkbukDYyjKwnP0k7yoNrIU/IOtKPLCbPyKzYqVE6TH6TZWGs4B6Rj2SyO1VRH3KcXA7Xrt3kBukf2RqiA+QvWRvGg8hd8hX2NXOaQN6RrYl9OflOZib2LldfMoL0DuOp5DMsPQcGWzXNJ3/QMbClsIVandhdQ2EpLL+xsBRuC+Phhdv/eY2C1awYCcsM+cQ2n3dNqRGcJW/I9OReKg8gF1hqd20m72E+D8kV2CLsgX3pjbDabiVXybfgex+2EJfCWPbzsIXKagDMSQG9JItQvhKaeLUAygKTlKYKYj+K9yiYXbB6XxBsUitsTuq6+oprYLVddw1PIm/JGVjAOW1B9QDqCSz18TJIG9IKmP82co4Mie51Wlo5paMmtyG5FysXQM4eKxeY6uY1rCurO7s0p0Owml4S2bPSp1XOC127PM1OR7ZUc8kvdJycB6bumFNZYOrK6s4uBbYd9swtdOKL+QvS9qyANDntcS792RgUm7YK+RUqfSRt8GV7YC6w2eQHOYrKw4FS8QiZA0tV1WLNw8N48pycQrEKaqfqVvqDGZFNJwy9VC+XvNgfoHhWX/0irA7iGknlgZ1EkSn61fgDmRJseoca2WMyLtjUNdVgFGxN6Rj0guwjq8g18iXYXdrPrsOOSy2RXQHJfgHmf4LcQzGJnDyw2+QmrOM9hS2ozqnSQlgAyhyhZqVmplR02yfYfpqVb5IryTxU1luZ1K41UT2r37JtQopTUf7aaJUVNdOrJyhXYz1aOimoc6qjHkQdx6LuLh22VVPOXpQci5pqqqnupX+BT5rZ2A56TgAAAABJRU5ErkJggg==>

[image18]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIgAAAAaCAYAAABsFBQaAAAE4UlEQVR4Xu2Za6ilUxjHH7lEbrlkmtCgSYyRcplpRFEoioRvJPFhfJJLElEzSWaamoyQREJSkih30ml8IHyQ+GJmmhkZilAaCrn8f7P201n72evd+333u89xxn5/9e+cWWvv96x3rf/zrGetMevo6OjoKLOvdIS0T+yYIro5qGB/6QHpqtgxZWCMO6Tber+34kLpO+mfTD9J3/d+3y09JB3mX5hnFkv3SU9Ia6Wl/d19MCkbbXZSlklbrf/dPpeOk86Svg59m6Wj9nzT7P7Q90ivfT65ydL85+PYJZ1v6d2+CH2sG+8PBMuz0tW9f7fmSelP6bzQfqYls7wjHRL65poV0ruWJuQM6XVLE4ERYmScJn0inRja4Rnpb+mS0M4znpd+k84JfXCZ9LJ0ZOyYRw6W3pN+lE4NfbDa0pzcFTvEculD6fjY0ZRDpQ+kbdKi0IcpZixN8EX9XXPKQdIr0o2W9lQguj+WfrWUARwWmghH0TjAtsMkXh7a3SClwCACeR7GG4dbpUtj4xicZCnDz9hggDL+p608fthPekFaE9obgzNx6EuWHppDsUNkVg1irmBr2Sn9Yil7OPdYWuzbs7Zjpa+s2sBEF9+JtclKS2YrmediS3+jZLg68DfjM8eBdyI4MXnE1+ZL6ejQ51xr6TN8dmyusMFJd1ZJv0sfSYeHvrmECN4kvW3JLI4vdp5SmUSyH7VFiVIaJkM9bikCo0GI1EelY7K2pkzKIJ79WKMIWRSDlwLbIbgItNIWWpuHrZwhMAT73w/S2aHvv4BJYDL+ki7I2lmMGRtMwQ4LFQ1ypXRLry32EXWoDZMwyIGW6i6yO4FKoOS609LYCYAqPBPH7FkbrzHIEuzHnBYQhd23liKsKjJzOGlwKqirt6x58edbAuMjwziMdVgUuUEoxIFa5rHez2ge3pXMUmW2ukzCIF5/oKdsdm0Q60LglgI7x9c3D4BGeP3BaWGJ9TsUBy8UPJs9Z6myz8EgqApPxf4Zjo9kEMjNQ71xr6X6oy4YdZENRjfH5OsL7WxbXnSPom39AW6Q0jNq4fUHxd9ChUUgqjnjUztE6hqELHOKpWf5c3wR+D4nlgetOhOVONf6I9v1qaWrgdhOXXUCX6yB1x+l01Cd+gPcIJ49G0P9MYkjLAOJ0TJMdSPJzXG3zX6erJffaYwyiKfqzZYu/diqHJ/oF6V1Nv6xNtJ2i/H7D8bN+CPUSKPqD2i1xfj9xw5LR8U2nC5d00BERSkb5JDyS1fGTEpedBFpTGbcehwMSaH2h7TB+p/lBiFI1oa+NrQ1iJt6xgbrIcZIDTKq/gDfikon1JEsl362VCkvpHoDmIQbLN1yfmP9BS5XyvnEYJhhezE1Asdgiu6loc/Ns8UmcOOY0dYgvvWXagfek/ctXWxGKLr5XKMdgqtrJoUBuJh0ireFgi9cPkZXTLtkARa4dBUNw9Isf2eHdF1ob8u4BrnZZv8fzLXdUq1zsvSZpWO+9+2W1u/5ZhkCCTO13SH2ajjhcJFXdXdBEbfKylsQfdQko7a7poxrkEmzxtJ1+7BCdiogA7xhk1/ocSHiqzLafME9z/uWdoyph23kNWt2h/F/h6DhBJhfKk41S6RXez+nHYrxN62biwFI6xxXD4gdUwTXF5x+OMF0dHR0dHR0dOwV/Au8KC02Go4HtwAAAABJRU5ErkJggg==>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACEAAAAaCAYAAAA5WTUBAAACRUlEQVR4Xu2WTUgVURTHT6RQoKj0hagU4UY0EyJo4ccmoRZaWAsl17b2q8CFuGkfQSQiiIKIVEsRCtSFFNrGhYIYLmphuHDjQnAh+f977vXdd97MU997y/eDH+O7Z+bOnXPPmVEkT/YUwSt20HAZlsFLNpALGuAELLEBA2/eD3vd3zmjEi7CWhuIoRBOwRc2kCl8mvdwxIx7auAv2GTG6+BPWGXGM4KTbbpjFK/hnuhiQgrgjMQv/kK8hXMSXZDM0rRoJliMllcSH0uCE92Bz2Gz6H56eGMuYCgYIzznlmiNMEss2HLR7gm5D//Ah2Y8CU72UTRtL+Ew/Aqvujgn5iRt7renHo7Cb/C/O47B9vAkSVzfYcaTeAJ/iKbL7+EGvO7iD+AubHS/LXH14GFmlkS3NBYGD2EPvAbvOT1cxF93tJxVD8Qv4p0ZT6IVHommlH6HN4J4ukUwW8zaBxsI8IsYN+MpVMM3cF10IX1BLN0iWGwHoh0QR9rtYOGxALfgTTfGlDK13GfPXbgDnwZjHp63L9oBpAs+S4RP8HOGD3YK2+u3aGv5TuC3YU00Mx6f8nBhHm6Dr4fb8JOkflf4ut+Gj834CSwqfmA4CVtrEq7AlvAk0fO40Kh9Z8f8g7Pwi+gNLTyHD1FhAyF8GbGXS20goBOuSnQH8HpuJz/fUYyItj3bPyvYusui75SLwOsWJPXDljF8E36WRP2ch27Rt2r4GcgK1sag8zz/qLC450ULNqfwiQbgIxswFIu+IaMKNU+eWI4BLglbrqCKvNsAAAAASUVORK5CYII=>

[image20]: <data:image/png;base64,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>

[image21]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAZCAYAAAB3oa15AAAClUlEQVR4Xu2WTchNURSGl1AkEcUnRApJRF8oExNEYoISkjIhUnwhMjCRUiYy8psBColM/MwoFEMiUTJRhAiJ/LxPa+/Ovufb597u6N7Beevp3rPO3vuctfZaax+zWrVq5TRCnBOzyjek6eKoOCk2imGNtzuvAWK/+C56S/dWi8tihpggdorHYlI6qNNaID5ZfwfGilvmLx6FsyfEocTWUZE6p8zTo+wA/1+IqYkN7ROnS7aOiGjuNk8TXqrswBTxTrwSi4INh++IVXFQSaw52tzpFWKU+ZylgbR+hohxCcwbJMaUbKyZ1XxxTAy2vANM3Cv+BSjyG6Iv3MuJl6Lgv4m/4qH5vHXibLDjGJojHolf5utfEuPNa4xr0pq1WLOfiAppMzlc5xxAA8VhK5z4IJZYtQNRK83Hb7FiLIGiIbDGzGBD1OBX82DxvCPmTYX/WbHgLrE2seUcYNwO85RZaB59XuqP2JSMyyk6wG+qZeY7Q1Ci4k4Tcd6DJoGzlZprRepE5Rwg0k/FxHBNRNabj3tu3qWqVOUA6zP/qnm+Rw0VN8UXMTuxZ7VVvC1BbvLA9+K+eSHRaY6HOamIItEqp1uqVg5csMY0JJjnxU/z1G66AznldoAF062O4lx4Yn64VanKAYoZO6kZhSN7AqT1b/MTvy0dED/EvMRGq3xmRaEjHrZZXLTGFCgrOkAxxkjTOO6ZpyU7jEhLCv2uGG7FQfnZvEu21GLztIldhgJ9YP4AFqe4PoqDYoO4Im6LHiY3UXTguvlpfka8EdesmLs9jIksN6+r14ntpeW/z9oShwkvtEZMs9YtFKUpRD7zYiMbRnS5qmqg68XusGPbzB3gt+nnQLeJY59uQiuMcJ39HKhVq1b7+g+QNZGL9/tgLQAAAABJRU5ErkJggg==>

[image22]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAZCAYAAABdEVzWAAACsklEQVR4Xu2WS6hOURiGX2Egt4GQkNwGpJAoBjoKKZFcIqRkQFJCkUspZeAWYSApGUi5JilJEUVSLoWBy4BMDJgpI7zP+fY6/9rrHOcwIOm89bT3v/a6fOu7rPVLnfo31NUMML3KD4V6mu5l459SX3PFHDDnzSrTpdYjNErRb0j5oVQPs9ycNPvNWLWecImZpvAE3/DKSjMh67PNXDTdTD/zwNw1c8wgM9rsMB/N/GrMT8UuLyt2x+Dxism2qGEcC+GB7wUXFOMRobmlWDhpu5lumswKs8xsNEcVc7arDapPhsaZJ2Z41nbKPDfvFV6Zq8inJDb1TuG1JN7nZb/xMhvsMITojNmneuhYBMPwXtIxMyn7Xaq3uae6YVvNzOqd+VmnwxAm7VWEBfcSDrTUXFe9sjoyDB0yZxVGkLcnzODq2yxzRL8QwqRh5pXCuDcKQ9k57bmOm8PmsfmgSOyJtR4x5pHZqTBic9VO6C5Vz9/SGEXupKQmvH1qPaTTimROeUVFfjZTWnqE8BTeIQ3wHB7CyBTCdAJQ/SOrtjbFLvDQWkVlflEYd19R8knkUJ7sjMNz59R+eDAohZADlSNpt8IZFFQZmWZh/TXVE5YFryqMo2J/plSFb83A4ltSGcKp5rUZUf3mfNtUvdeEu8kvrM+FwTcUIUWrzTezrqVHwzDgvVQZQkTO5f0xmJxuJarspRo7yMXZRqUiPIoHc8NSKO+o7XsxD2ES8+SG8Tyoeoo0iwlvKpI6P8f6KxbE9YgnVZlfuhwpX82irC0JozlIOVBzLVTdMByzp/G5Li7UZwoDuTbw1AvVL2CeXFG3zRqFJz+Z9VmfpBRCKrPUUPPUzFCM26W2+7UIV2L9YjNbjYO2FBMvUPRJd2SpJsWCpcFJk81DRQ6TX3/tr0+nOtWp/04/AInMef3MNVvHAAAAAElFTkSuQmCC>

[image23]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAZCAYAAABdEVzWAAACvUlEQVR4Xu2VSciOURiGb2Eh00KmkJlIWciCBb9CNixQhGRnI0KRoUhZmEqykJQsWBiTFLIQRaJQprBhI4mdpbivnnP+7538P0pZfHddvcM57znPdJ5Xauv/UE8zxPSrDlTU1/SuvvxXGmiumEPmvFlrepRmhCYo5o2sDlTVx6wyJ81BM1XNC05WjDNvjcLrorabi6aXGWQemLtmkRluJpqd5pNZkr75pfDyssI7Pp6uWGyrysYtU0RhisLTjeaRGZ3GMfK2YuOsHWaO6TCrzUqzyRxTGN+lNqi8GJpmnpix6XmouaFy6DH6uNmbnnHqvSJqWdwvLjxTezjXbQrRGXNA5eiwCYYRPTTDvFakoig2PpXu+5t76V3WNjM/3bM++3Sbwqz95ocivLlmVpjrap2sceajeWfmpneUwC2VNzpiziqMoG5PmBFpbIE5qt9IYRY18kZhHBtjKJ7n2kFshPfMgdPmqup1yDfU3S6FEVvSe1J3KV3/SBT0B7U2Jr0DSjOiP+XowmdFFKqnl0jxnjJgjAhhZI5s7gCc7vHpXaPwggitV5zMb4qN7yuOPGIDDgmpm62IFnO+p2+6EgblFNJQaTV7FMGgPouZ6RTWX1O5YDE0b4wxiAg8N6PSM9HDa5x4pTi1TaqmcJZ5q6hZRH/bnO5LItzUF9YXhcG0B1KK8IzDURULf1Wc2qqqKUTUHC2FU48wmPKoiQVfquVBUfS2bAwGNi3Awo9VdwwVU5hFZoqGcT2syEBJtAPqhg5dLOLB5o4i9IhNXpgx6Rkxf505p3oLwGAaKQ21qKUqG0Zg9rWGy+KH+kxhIL8NIoURxR8wHtEuvpjdad4Fc9MMS3Oycgqpy6qo0admnmJt1mqa1yk2xvrlZqHqP+csTim/GOZNUr1VoA7Fhk1jaKZ5qKhhyoOT2lZbbbX1N/oJw8h9owj3Ft0AAAAASUVORK5CYII=>

[image24]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAZCAYAAABdEVzWAAACmElEQVR4Xu2VS6hOURiGX6EIUeQSIpeBkYFbSjoKKZcBBkJGLiOJwZFLKWXgVqIkKRmYiEwNDI5LISUDMUAiJYSRgRTep2+v/197nf8cf6QM/ree9t5rrb3Xt77bljr6PzTQjDXDy4lCw8zgcvBfaaS5bo6bK2aLGVBbEZqhWDepnCg11Gw0580RtX4BT6w0ZyvWK97LtddcNYPMaHPP3DYrzAQz0+w3782a6p0+Nd7cMqcUBq0yr8yibA0uP2MOmelmm/lqnpgp1RpCc1OxcdI+s9h0mU1mg9llTiuM71NMXjDPzLhsHK/dV4QGcWI2ndhYIW02PxXv8x088lrhtSTuV2fP5B4hbhWRmmaZT6ZH9WTlYz/M0uqZDZIRSXz8rXmpONQIc0d1w7rV/Aa5dlRthBDNUYSkR70Nw5C0yVzz2GxvrGh6CLhHJ81lhRHk3zk1vbxMkS79hjDpd4blHipFDn5XVNeQaox8e2gOKIzYU43j3WvVtS2RQ+QSISAUSeQYhl3KxnJRDBfNFzO/mMNTeGe2wnN4CCNTCFMHOKYopD61znw0C6rnqYpi6M8w3nmnZv70JwxKIeRAtCSqm/wmIqmqe4lT0SJeKPKF0OxQPcdy4aFHZl450UJlCBea52Za9Uy1767u2xKG5VWZhFF3FZ0b4QXaxqjGiqbKECJyLi8WDCZtWmqnIseSS/Eg+ZP3McQ8XT13/RhFaPL8TMpDmEQEcsO4nlD8VXqJPPqmcDPCK+RPflL+DvxaPps3GR8UDbNsAXiCcRpqrrWqG0ZXONycrgsDnpqt5qCiaZY/39RgW1GGIoWQyiw1WdEPlyi+z36t1jVE56Z3LVf88/5GXYoN84PlomgemBuKQ1GpHXXUUUd/ol/Xp4AcnVdagQAAAABJRU5ErkJggg==>

[image25]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAZCAYAAABdEVzWAAACsklEQVR4Xu2VS8hNURiGX2EgZKBcQuSakYEQiV8hAwwwEJKBMnEJRS5FysCtJANJyYCBSzJDBi4DxMDArSgpJYmZgYHL+/St9Z+19znn96eUwXnr6ey91jprfbf1bamj/0N9zTAzqD5R00DTvz74rzTEXDfHzGWz3vSprAhNVKwbXZ+oa4BZY86aw2r/hynmqGLdOoXXpXabq6afGWoemvtmiRlpJpm95pNZnv7TViPMPXNSYdBS887MLRdZKxVRmKpYt9U8MWPTPEbeURyctcfMM11mrVlttplTCuPbislz5pUZXowTtUeK1CDmbqoaSVJ02hxM70TkvSJqWTwvK96pPZxrl5Fu4f0Xc1fVYmWzn2Zhep9uXitSUYqDcQwNNg/SWNYuNfbAkSPqRQoRB35Ta8N+qXHIePPRvDXz0xjRvK3qQSfMRYUR1O0ZMyrNLVKUS48pzPqTYTkaHIT3jMF5c8PsTHNZ1Bt1t09hxI40Tuqupd9eCa+pJVJAKrKoMQy4UIzRn/I4fFZEod4OiBTj09IcEcLIHNncAbjdE9JYS3HbOGRWeh+nuAylYRywWZG6OYpoMf9D0at6EgblFNJQaTUHFPVNRvKtbhKH0iKoH24VjW+TqjVGBJ6bMemd6OE1ZVC/0aXqKZxt3ihqFtHftqfnXgnDyluJZ/Seutj4q6JW66qnEFFzOE9rQRhMebTUFkWN5ZASQYq77GOktNUGbPxUkZa6yhRmkYHSMH6PKzLQJA79rggzmqloDaWnPL9Q1F8WDmwwl9TcAjCYRkpDLbVCVcOI9KHGdFUc+tJsNPvNBzV/fPGIdkEzZg2flyvmluKTViqnkLqsixp9ZhYo9mevVuu6RfHSuxar+cNcig8z61aZyWpuFahLcWCrOTTDPFZ84igPbmpHHXXU0d/oN+NAgO9mxe9MAAAAAElFTkSuQmCC>

[image26]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFIAAAAZCAYAAACis3k0AAAEi0lEQVR4Xu2YW8hmUxzGHzlknDVyGvKNHEZNISGTw3dBSFygCDk0GZIIxQUXQ1yYIgySQ045hBtFIRcfSkKUnHJIZEYIUWRG4vn138u79nrXft/v/UxmRvupp/n2f693HZ71P+2RevTosWFiC3Pz0thjMmxi3mAuLl/MBduZl5v3mteb+ykWKLG/uUIx7hxz6/brTjDX4eYd5t3mSeamrRHrDwvN+8155YtJcaA5Y06bO5oXmWvNq9QW8zTzKfMAcw/zMvMtc69sTA3McbX5imLT883HFJexIYTTmeaFpXEuwEv+NE9pnhETgX5QiAZ2MV9QCJiAQHeayzNbDYeY35pHZra9zS/NEzLb+sCW5n2K/fxr3GL+ZS5tnrc1XzN/UXgrQIyPzX2b54RrFGExCjcpRNsts6U1HlQ9hfxXIC/eZW5WvpgLCK+dNMhZTP6TIty3aWzc2DfmZ+YxjW178yUNPLkGbvx5DQvJvDMKzycCSvA7xk8rcit7IzpOVzt/8y+pgrGJ/Jb5S1sNlyhCOwdzsgYp7jzFuktaI2YBig756yvzoMye8hyeC/GkZzWcR0skwbqELO0JRMD7irXYy4wiJy9rnp9WXCQCUXFXNWN/M48yL2ieSVnvKeYrwe85B2krgbMQoTcq0hgics6HszEjQfV9UrHJz83jNVxVeSZMk5jfm8dptJCIhFilYOOEBGnMu+bOmR2h1pi3abA2UYUonyiKHyloxtyneV/DEYoOJN8/or5jHprZEBNxJ8Yic7X5qAbtDYtdqghl3JxbSjd+bjOmBjbGxZSCTSIkTCkG0KZQ+Eg1eZFAQITEex5RpIRRWG4eW9hIcR8oooH2Dq/kksjpEwPRCG+Eurix4XlMvmfzjHeeZf5qfqR2eOToEqzLnqNLSIBYf6jdCQD2yeXeo9GRgmDMUcvP9LicK0UedSFPc1Wg9hUN856OaswkLAaozLRJJWhfflQ9BwGq4TMaFiyJROXuuu1xQpIP8xAEhP0XimJ5WPEuB/u+tjRmIPdOmzebPyucKE8vQ0AA1Ie5GGwUIZN4PJMfS+D6b2vQb+KpU2pXSS4l70lBCqHa5SR0CUmReEPDkUBok3Jo2V4231RU9BJ46u2qXz6XzVnz9bgcUl1t/D8gVD81H1JsELA4m+BWD25stDgcfKp5BmzofPNxDfowelEu4InMRsL/Wu02g819p0j4XUhCkmOnMvsZivBNaQdwoa+apzbPixX7r309LVT3JyFCck72l8Bc6LEgs1VxoiIP4MYclr4Pd8aegKfR/uBZ15lnK1qQF81ds3Enm78rxuY5igMScssUvdmHih5uVB5LQrI3igue8pxiD4jJbwm31CZBPJECeWVm43P3Vg3AGVm7BoR8XdHfcr4HFFU812IkUk6g4T1aw7eYgLciVtkYzwbpt7AWciXK0N5BEcpde5sNiJKV6v4kxGG2av5mPS6qbAM3OpRCrguQpxFynXwSbgwgQvgvO5pxyN9dn3mToPZJ+L8GfRuFIufYXm4MKC5U666et8cssbvGF7gePXr0SPgbrjPnymS6h7sAAAAASUVORK5CYII=>

[image27]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFIAAAAZCAYAAACis3k0AAAEZ0lEQVR4Xu2XacilYxzGL1ky9mks2TIjS6MpJETUfEAkJUuETJMMST6YInyR+EDZl2RJlBSTEkpSXtQQRWQpkUyWKOQDWbJcv/7nfs//uc/znPOe95V5m56rrs45/3Mvz3Pd/+2WevTosTixnbltbewxHbYybzJX1X/MB0vMC8yHzNvMwxQbZJxrHm/uNPhvT/Mi84g8qAOMP9a8x3zAPN3cujFi82GF+YhCgwVhV/NZ82Jzb/Nw83VzvYZibmM+bf5T8RnF/HFgjWvM1xQPvcx8UnFoiyGczjcvrY3zwZXm9ZUNN39P8eIFnNqH5iZzg+buVUeZ35knJNuB5pfmqcm2ObC9+bDieRaMx81b1QxlPBMh8c6CexWiTItbFKKxZsHO5hvmYxpNIf8ncJj7FRG3YPCihCn5a8eB7TzzRUU+LJiPkJw469RCsu6M+Y65NNkLmMf41YrciuevNM8xD9FQfD5JFYwtZC7r17Y2XKEI7QzWZI/LzDWKfakNE3GA+alCzM8UwuIt2DPuM+803zW/Mt80j2yMGEURrEvI2l7AgZFGeCZSyYx5lblu8LvkZgSi4n49GPureaK5dvD7L/MDtTsA84mIvZINEW83bzb3U4j4nCJq5wQm8ICliDBxl8aI2PQ6DfMiFftH85jZEaNAJMSqBZskJChjSDF0CAUI9bt5l4aeSdHi+XAIHOBgxdyDBv+34ThFh5JTC6LiKEcnG9og7kSgPB6IK1O5f1GIuVERNgXktVxcmIdnPqXuHMODfa5RwaYREuYUQ5vykvmtmkWiRBZO8IQiJYzDjeZJlW138yNFNOAovCOHxLuPBQ/1vHltsjEZd0ZMKnoXirchVA6PjC7BuuwZXUICxPpTzU4AnKwI5wc1voghGGu05We6keJMJd1N7JWpypwi7ptRTr3khrXm3+blsyO6wzYDT92g0TFFJCKh67QnCUk+zCEICPsvzJ80PuXQdt1QGxPIvasV3czPCg/N6WUEJOGP1d5H0VtSyQEey+lkIUtoz2j4ooT+cjWrJHN/UPOwSgiV9dvQJSRF4i3zEzUjgdAmknCOV8y31UxNBXjq3WovQBw2h5T343C+Ufv4WTDhZUURyaGwh+IFSMiAT6p2vonQIv1mnp1slygEz3mThI/guc3g4b7XcP02FCFJHcuTnX0J3/pQuY2dNfi9SuGVbbenFeq+EiIkB8zzFbAWh7JvsrWCF31fIeiFCk9kMQpPEZfP9earCrHwJLyMPiwfwBkKcbkSZjsvSMitU/RmREE9t0YRkhxV0swLin0Rk7mEW2mTIJ5IL3x1sv1h3qEhOFD2bgNCblT0t7RYjyqq+Gl50DgQkrguDe8pGjbmNfY3z1SMmXTHrkGYITRsC7kadWjvpgjl2sOmAVHCxaItlQF02GHwnf04qLlcgxc1aiH/C5CnEbKrXdviQLE6VNGMQ753XfOmQduVcIsGfRuFInNiLzcBFBeqdVfP22OO2EeTC1yPHj16FPwLSsDkmtUsVYsAAAAASUVORK5CYII=>

[image28]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAZCAYAAAAv3j5gAAABRklEQVR4Xu2UvytFYRjHH2GQwWChWGQxGYiFMvkDJJPhZrFYMIgy+AdEFhnZpCgU8ReY/AukbAbFJj7Pfc5z73vee3Rcx6LOpz6de973OX3fn1ek5D/Ri5t4gFs4mO7+G8bwBidxGC/xE1exJagrRAee4QK2Jm3deIdvOJK0FUaX7AFfxWbjbIjNaiVoU/qxPWoL6RQbaAP60S5ei4U6a2JB+gyZxx3JDuvBU7Gt+BFteIIfOJXuqu7ZEu5JOqzpEGVcbH/0BGaNPA77VUgX3uKR2Hp/h4cd47k0GaKj28dtsdOYhx6MezyU7Jln4iHrUj/mQzhdq0jTh1diy1yRxj3LRJdBL+dy8ttZxJng3fEQXy79piI5YV70jk/4GPiCE7VKQ0MucDRqzw3zC6t3JvYZB+qlVfT/MA5xNGwW5+KOkpKS4nwB/U03kyJfickAAAAASUVORK5CYII=>

[image29]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFIAAAAZCAYAAACis3k0AAAEU0lEQVR4Xu2XW6iVRRTHl3hBrdBIlC7SMbIIBJOwKCp8qEjEkEoMCUIiCx96UFDShy7UQ4WVV6QLoSCCBSEU9BB0VDAtqIhuRCFFFxRKfFAysfr/WHvOXnv2N+dze8GjfH/4cfaeM9+e+f4za60Zs0aNGg1NjRIj88ZGvWmYeE5My//Rq/rEQnGVGC5Gi+licetz0nxxm7jYfPCJ4mFxY+hTEv1vEWvFRjHHfKyhoCniTTEm/0evwpxj4r/AEfOXTRohtmd94B0xLvSrEiYuFzvNJ32Z2Cpet6ERTg+Jx/LGU9FN4lvxvfhSPCsu7+jhYtW+Fr+Id+3kdxW/f0DcHtquET+Le0PbuRAR94b5fE5bvOi6vLFC9KFvr3rB3LS4OJeI3eJt8x17rkRe3GAecaets2kkK/6BdRtJnu0Xn4lLQ3sSz9F/lnluZeffIB4U11nbfP6SKuib4Fl+P2+r0hLz0I7iNxnjcfGI+bikv1phzntii/jRPHSftu7ku168Kj4Xv4pPxIyOHt1KhpWMzNuTmBNphDzMfPrFk+YFkO8pN2MQFfe3Vt+j4g6xqPX9hPjKqjcAzxMRk0IbJq4Wz5sXX0zcITaHPkUxyD5xbes7K/ypdRcDBn3K2nmRiv2XuHmgR7cwCbNyw+qMRKnPF+YnhCSMOiZes/bOZJ7M7wdxtZhq/mx6pyrdKl6yztSCqWyUmaENMzG3VkzioqxtpflkGSyJvBaLCyvGztxm5RzDxH6ybsN6MRL4nESkfCj+sM4igYEYye4hukgJg+kZcVfWNkF8Yx4NbBTeEX9491PSCvPQWJr/IyjtNoyK4RFVMqzUHlUyEmHWces8CaC7zcN5kw1exDCM36jKz5xGOP6lIx7prvasTBiT8FmBGD7JSP6iReJf8cRAj3LYRrFTOSrlfZJJVO7SatcZST6MIYgI+/3ikA2ecjh2rcobg8i9s8SL4rB1+9OlZEbekdDGyPta35Ox0cgU2v3WflFCv886qyTP/mmea5JSCHHTKalkJEVir/jOOiOB0KYwcCv7yDzPs1FysVPXWHUBwg8WKY7H4vxu1f0HxI4hDGI+YaK7zCeTbi3kSqp2LD4LxN/igdD2qLnhMW+S8DE8HjOY3EHrzMG5kpGkjr7QzriEb76ozPn+1vdp5rsyL5hoipWvhBjJAjO/JH6LRbkytFWKlSTEXjY3giq5x3xySaziMvFxqw87iV3GOSzmornm5nIljO28ICG32Pxsxk0qfzZXMpIcRXFhp7xvPi5m8ixRlI5JwOJTOMntqe0f8Yq1xYIydpUwkncn3XHEesu8is+OnQYTq3an+YGXECxd/SaLeeIeq79j5yLMMBqqQi5XHtrjzUM532G9iCjhYlG6EvLeY1ufGY+FKnlx3ig38kyITYKRpePaBSeK1fXmaQb4XLrm9aKqK+EFLc5tFIpI7VmuRhQXqnXpzNvoJHWF1Re4Ro0aNUr6H51u4PlrhbYkAAAAAElFTkSuQmCC>

[image30]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAZCAYAAACSP2gVAAADtklEQVR4Xu2XWahOURiGX6HMQwcnQ53DBYkLJSKSC3ORcCGEkkhKSMpQIhlS5hRyciFjyQUpQpEMF1KGUgo3knDDBTK8b99e/Wuvvdf/n98p57/YT72d83977WG9+1vftzZQUFBQnjZU5zBYUGI4tR1mVIvoSC2gjlN7qSHpw2XpRq2BnbuV6ps+3KpspqaFwWrpTt2gdlBdqBHUC2quPyhCA/WUWk51oKZTr6jR/qBWQvM6RfUKD1TLRuox1dOLLaReUvVeLKQddZK6lPzv2Eldh2VlazKJ2hYGq0WmyJzTQXwU9ZWaFcR9BlHvYQb7zKG+USOD+P9ENUelYmx4oFqGUp+QNUiT0ySVDTH0hn4ja9BM6g8sC/PoAVuaGtcftjQnJr/rSsPQHpbBqmlSH1imaowfa+tO8NB5TbBl5qOOpjKwnpoAS4TeqREBzoiYQWHcxxkRMyiMO9ZSH2BjHlGXYWbugt1zNSwDGqkrsEzW2PswQy8mvxU/BzM8ZD61KogpGe5RY2DmLqbeoUKmu8mERjTHIBmQZ0Qlg4S7/j6UMkCmqFH8oiYnMdFIvYZ1SWXVUljti9U4ZdlRWIv3WUedQbrlawtQ1iCl278apBvmGVGNQeEYTeoLsoVfHVXjN1FnkV06PqqNJ2BL12cFzPzDsC6rjq0lJ9OjxIyIxX1iRsTiPjGDlPpvke2qeusHYDVvhhfPQ0bk1T+Z6pan0x5UMMh1otAINwG9sRjjqZ/ITtIZpG4Wo5JBd6muXlwGbYGdcxPxDNKy0/IbGB5I0HUaqSXUbZjhK/0BIUqzO9RVpFNSHepH8tehh+qH0hpWwXxDHXIDEvQG1RlVFGPEDFJb/k4dQbpWaIlpaYyDLUHVKv+4Q9c9iPxjG5DetihzLiCbHBkWwaq5c10X1wM8QOlN1cF2zHp4t7fIG+duqjrh15AQZ1ATSimuv/r9kRqWxHSPqdQTakASU5dTLZFpIeU+LfQy9Gzufrq2XkT4kjLohGOwlJsNm/Rz2CeHQ5l2DfYZ0eDFZYzi52EFX1t7tVI3mRjOoFuwzxx1qGewtj84GTMFZoSrF2oKKqpaYi72GaUs17PI4Prkd4gy6CHshep+2kKoq8WWawq5qQebB9tAlS1cAWrTmrDO1d+8jVuIv8Q0Xhs+ZWne0mguqomqUzE6we7lNqB66TVLrAa1BG00W/xpUQto56tOpw64H/HPhWpQRmh5NWu51DrLYDXAaTfyPxeqQYVZ3bMggjaG5bYVBQUFtcdfzbfCisyN4KEAAAAASUVORK5CYII=>

[image31]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADYAAAAZCAYAAAB6v90+AAACtUlEQVR4Xu2WTchNURSGX6HIf4r81PcxIDFQokQy8BNFwggDJZkoMVFiJJEUoZRERn5LBqQIRRIDKT+lFCaSMGGA/Lxva6/Ovvucfe9l8N3vq/PW071n3X3O3u8+a627gVq1avWUBpN15CQ5SKY2/txUw8k22L17yLjGnzunEeQm2UuGkpnkBVkTD8qoizwlm8kgsoy8InPiQZ3STvKYjIpi68lLMjaKpRpATpHL4btrH7kBy4KOSWZk6mwSn02+kpVJPNZk8h62MbFWk29kVhLvUU0jn1A2pkVpcdr9nBaR3ygbW0H+wN56lUbCUljjJsBSeGG4Hl0Mw0BYxqhmxRhYZmhMHOvvN8RyAzljaTyWG8gZS+Ou7eQDbMwjcgW2Cfthc24l/Ug3uQrLHI19ANuIS+Fa8fOwjSrJF5EaaMeYFl5loJUxyZ9/CMWOy4wa2C+yOMSkbvIa1nX1FjfCartpDauL/a+xHag28C/G0jEzyBeUG5I6tMbvIudgnbypcgZy8Vg5A7l4rJwx1c1blLu03uYRWE0vj+JZeWdLDfjE2qGc5pOfKC/Ojak75tTK2D0yLIrL2G7YPbfQxhvTH/Jdcg3WnVzqeD/Cp0sPGw+bRFIhvyFHfUDQFlinVcfNKWdsLvlOjqOYR1IqHiPzYKmqWox/r9QG8o5MCtdexA9R7IxarE4YmlST58apuC/C6iCukVRu7AzsHkmfuv5IpoeY5lhKnpCJIaauqQYjs02lB54gd8gq2GKfw45WLr3Z67DjUlcUlyHFL8Aa0WlyH8UicnJjt2HHOXW8Z7D2PyWMWQIzoLQWalZDYKnosc9ozKqStDN64FqyAMUutiO1ay1U9+qz8g8zUZyKGq8/WmVFy/Tq7crVWJ+WTgrqnOqoh9HkWNTXtAlWU84BZI5FtWrV6p36CxoznO6hmzZIAAAAAElFTkSuQmCC>

[image32]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEYAAAAZCAYAAACM9limAAADBUlEQVR4Xu2XS6hNURzGP6G88rpFQh0SCV1FlEcMpAxIuBEDA5lI1wh5DJQMGCEjExnIayQpIe5IokiJAfLIIyQjJRLf579Xd+111t5n74ts7K9+nbP/a+2z1v72+v/XOkCtWrVqVVvTSAcZQXqRQWQ+Wed3ytEkcoAcJWtJ/3Tz36s15FvAczLd75ShleQ+rK8M3UsukyF+p6ppJOwtDgwbAi0ljxNukC1kcKpHXGPJQ6RX1jByi2z2YpXTKHIc9ibzJGO2h8ECkiEfyQwvplQ8QbrQetw/pt9tzGE0GyNpzNdkfBCX+sJW8iyyMLlukOWw3+ntOlJDYc/g0HP0i8RKq4wx6ncRlk5PyEakJxmT7skyJhaXGuQa+UreketkN2z13YGl4Zik7ybyCFbz1H89WUA+JzG1ydDSKmPMVTI8uZ5AXpBtsNSISb/ZhbgBecY4qc9bMtmLadxX5Dy6dzaNv4N8gK2yNnKJzEnaWypcdqKdnIUNGLb5Zml5CidXJ2TOOC/uSwX9CuIGFDXmGWwuThr3CPlC5nlx7XAaSy/vIFntteVKk9wF24F89HBKi2ORtg0/7syWJq7luiRs8JRlQFbcV8wYSbVO44ZnqCmw1NNqGRC0lVaRVJpIXiK9fCVnjNIsS/sQN0D3arW5WhFTK2NWBHGt+nvkE+zs9FMqYoweSg8X5rVWW/jQ2k2U407LYEVxkRdTSl5I8NMzVMyYPuQkrJ5M9eJKpTNkLmy1qw7JqB6riDEaVCY0vJi+a3fSJLSdSjr2v0G67sikm2RPci25wq3TdJ5cus32YvqumOqIXo6kg6bmtzO51st5AKs5PT5dFzFGmkluwwbvJE/JKaQHVlrcRfOEdK/qmHawVbDtdj+6Dc2S5qWVcY6chm0S78lW2L2qm2pzf1H0omSKap6LabXq3lYn+yYVNUbSjy+GnQsayN6mY/Lv1d+EIvJTSfPTZ17q/VJpwA5Y7lZNsRrzX0tpMhpW7HXA06GtyIr+59Ugh5A+U+WdlWrVqlWrkvoOqgepliefDZgAAAAASUVORK5CYII=>

[image33]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFAAAAAZCAYAAACmRqkJAAADQklEQVR4Xu2XW6hNQRzGP6HcLx2RW3YelEgk5PLgwSVKCQ/Ki5J4ECGXRCmJIneSRPLgWvIiRShyLVJKnVK8kIQXHpDL9/nPtGfP3rPOPnX2zj7WV7/2Xv81a62Zb2b+MwPkypUrV6620jgyKw46dSCTyCFyjMwjnUtKpNWLrCEnyDYysPR2Y0umbCRPyG+yqfT2X8m8DeQoGebYQ66R3kG5SlLZ52Q56ULmkGYyMSzUyJKBGk1zyVdUNnA0uUJ6BrGuMAMXB7FYnchJctn999pJrsPe0W40HmkDZfBT0hTFz5B1USzUcPIO5e9cAPuWvtlulGXgNPKDPCYjXKxAHsHyZkozyC+Uv1MdonSxJIp79YFNfZUbDJv609112InKwQNgOVX0h410lQljHf0DtVSWgaqoFgA1+jvZR+7CRlKWvFHxO1Nxr7XkPayMOk3pQ2bvgtVxFSwvF8hV8sWVvQ8z/JK7Vvw8rENqriwDpW7kAqxi4iUZU1KiXHpXJaNaMlDy9dmL4giSaTvITzLTxaQCeQXrZHX2UljurTrHxkM5i9SQzjJQ71dDzpIp5BnMAJXX9E5J+bGSUa0xMC6jBe0zyhemhbDyW8g5tLw7KNFYmPvVcBDWY7FSFZZWktukh7tWz26GjYSs1TRlVCoeKlUfDYI3sG1X3yCu0XkAlnO1o6i7UhXuTm6SFVFcUi5SY1IbY7/4xO/0Bmbl0FR9vIHKweG2SgZuhT2j+rZqBLaFUhXWqLuDyivmBPKA9HPXqvQgWGMkJfTXsNNLKHXGRzIyiodK1Wcy+UaOoPgdSVP4MJkKm+LKleH9mstXWDkk1nqYiWGvKo9qVdzurptgJw41To2UfNJ/iOKzyqcXYXkqzGGxfH1Oo3hk1K+uP5BRLqZvzIbl5SEuppmh9CJTay7lt7corq7iE2yKaMGRlOOOw0bTarIMNk1Owaa4pJGqk0kzbA/nJeMU1wquY5yeuYdiY1PyBt4iN2D5+wVK96I6t8soX28tWj7lhG3RfvSf0FAy36H/1UqjVYYscr+VdgGxwims8upMjfK6TstGVioH5qpCOjlopdYKvh/pvWuuhJRjw73rbtTpOJYrV65c/5P+AK0GvZZ8imZjAAAAAElFTkSuQmCC>

[image34]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEMAAAAaCAYAAADsS+FMAAACfElEQVR4Xu2XS6hOURTH/zcURfImJPLITCEpr2RA8gjlWWaUDJSiMFAyUSYGlEgGMqAMROoOLpkIQ6+SREqUiZhI8f/f9e1719nn7O/7rrpHH/tXv+7X2ud0zlpn77X3BTKZTObfoosuoefoebqeDilckWYE3UUv0jN0XnG4s1AhjtAHdCYdR6/BkhvmrqtiNO2mp+hIuoC+oFv9RZ3EQvqJLnOxWfQdXetiVRylT+gYF9tNX9JJLtYxnIYlPsXFRtGH9Aps5lShAqgQV6P4YvqNboziSVS1DXQVHV4cqhU9+w7KxdCUv4/yV/fMp19QLoZm2ndYkZsymd6kt+gOepx+oIsa41PpnMbvOghJp4oRxz0h6VQx4niBGfQZio1pKL1O78G68gkU127MTvp+AD6ls3vvrEaJKuE46XaKoZn9C+WkWxZDSV+CzQJ1bI+a0FdYs9IaVYeuCy3XNygn3U4x1uEPixHWl5aICuNR99XNKsT2aGywSSWdintSSafifYQptT8eQP/YbdhSaYYanl6uXfXlm50V9GH0geKkQzG0o2hnqULb70eUkw7FOBbF+whTSonHKPaTrowHKlDf2TYAN9GxvXem0TLVrNXsDYynz2En0oCKqueH4oaCaTfyO+Ia+qPxt5Lp9DU96GJddDV9hf5CTYO9SJ2owaqXaXcLLKef6VIXOwt7z5MutgfWqEMfVE46jT5Ci96nxN/SG/Qy7IbDdAK9Sx/DdhVVv262wN5tH90LO1IfQPHAdQj2xf1RW7PkAu2hm2GF0IzSsbwl+udnIuz87x+kuGZEs/U92OidNDulfreL8pgLW5Yr8HdzyGQymUwm8x/zG8+Mhz1IRcOaAAAAAElFTkSuQmCC>

[image35]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAYCAYAAAAVibZIAAAAdklEQVR4XmNgGAWjYMABBxCnATEPugQlgBGIW4HYGF2CUgAysBeIWdAlKAEg1xYAcRyUjRUIALEkiVgOiOcD8WQg5mOgEjAB4tVALIMuQS4QBuLFQCyPLkEJyALiCHRBSgAonU4FYml0CUoAKLZ5ofQoGAX0AAA5bAi7Yfn2hgAAAABJRU5ErkJggg==>

[image36]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAAAZCAYAAABkdu2NAAACjklEQVR4Xu2WS6hOURiGX0kREYqYOCQyUMqlDBiJDEgdSshEIgNGKIYyOQOZKSMGChMDkRBnqJRSLqXkkkspTFDI5X371udfe+21/n3+c3Q6g/3W0//vb6299veuO9CqVauxoklkBzlLBsjianFRS8k2MouMI1PIGrIzrpRoP/lC/kR8Iutg7T1Lyn6RS2SyXh6OppFb5AQswWXkCemPKxW0HdVkxGtYG006Bqt/NC2gVpJvZBCW04ikD9wn06OYRuApmR3FctpEngfukUNkaqVGWfquDKqNVMvJV/wHgzIlc+eTuHpQ02hzEk+l5HIjMBSNisEl5CPqBv0DJ5N4qtE0OB621udkKHaCN1QymMZTKTnVuQGbpi/IXlgyTXKDu1FPeAPqa1DxV+QRbDMUD2Ft7Al1alKCqpAa6cXgHTIjPC8kb8gR2K7aTW7wJjoJO1fIb1QNKid1pDZFaRX5TC6TCSFW00aMzODEgEumLsBMzo/iOfU6RRU7Ff7L5G3YkTIvxLIqGSnFhyK9o8TVed3Uq0GNks5CdeJp2PnYtAliAXmPuhH/gM6qkhaRt+Qq7KLgcoO5xGP1atDVT36iswx0OTheqRFJLw+Sa6hONd0qfoRfl6bFXHTWlicRG/QpqrjKu2k4BjUdNS01PX0tahQP/6uR0S7Y7cPXjJLUrUYHtzcyE7ZjfSerQ0xlMtMXniX9126qjaK48IO63WRyBvWrDekdbDOT1LHnyL7wnJUSOUPuki0wc49RvW6p8euoL+oV5AEs2YPkJbmITsfkpLvoB5g5R0n7XVTHgNaXl+nCoTYPhGfNLA2I8DttbhZUpFHTmtpK1qK592Np4a+HdU4fmo+HVq1atWrVaizoL7vVrzhVJ8HjAAAAAElFTkSuQmCC>

[image37]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAAAZCAYAAABkdu2NAAACR0lEQVR4Xu2WQUgVQRzGvwgPURAiJAVRRBAeokAMCuwURIci6qAnLx6MLh1CBb28g6cO0blLeQgsCE9GRETQsYMYgWAIJSLowS4pZFh+H/8Z386+3XX36UFoPvjx3s7M7v6/2f/M/IGoqKj9ptOkN924g86RR+QpeUiOh90Nukd+kX8JVsk1cp7Mpfo2yUtyWDc3ow5yn3yAPWw87C7UXfKaXCDdZJpskDvJQTkagRkYTndQXWSdfCRHwq7qksHb5ApZRHmD7eQTbOYPuLazZIl8IyddW55kTAZvpjuoTrKGPTLopdT6gfIGfRDzMLOSjL6ABX7DteVp3xs8CkvPZwiD0P15gSdV1eBBcgwWZ5pSk1DVYJZayWeyDNt8iuQN9qEx4OtoXIM+vq+wDU3MwJ7R78YUai8M9sA2qiHU12WevMF3qAfsmSR/ERrUV30LyxzpEvlJXpEW11ao3Ro8RWZJDeVeWDVF1fbY/ZfJ97AjRe8tpd0Y1AunyAPYWimjqgY1aToLlRlPYJlyy/WVUrMGvTmlp0/Lq+Ti9ohsVTXopbP3D+rLQMXBaDAiRzsZlJETCNeWZlWzmT7Yx2CHdZGaMah0VFoqPf1a1Fcc3B5RIG9Q51h6g2iD7Vi/yWXXJnM117aQQMXCd3LGjctTUSWTZVC/2pBUSKigkA6R52TAXWdKlYiCUk7rhUK14hfY55f08DcIF7UPwt+TREeFjowsqRZdQTheQftaVMdAOpYJWDmpa5WCfjJ9TZuVBVFRUVFRUf+1tgA/B6Nhgohj+wAAAABJRU5ErkJggg==>

[image38]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAZCAYAAABHLbxYAAAByklEQVR4Xu2VTygFURTGj1BEKCIhj5JspISNpcJCSazYSZaKhZWVZGNDIpKy8idrSVaysFVWVkgJYYONwvc59/Zm5s285/Vmocyvfs17Z+bOfHfuzBmRiIj/QRGcgOtwBla6dweSBTvgElyBQ7DAdUSI1MJzOAbzYC+8hO3Og3zIgYtwDlbDBngCL0TPGSq82AbcN78tvPghzHfUvDTBJ3gEC01tGH6J3uFQqYd3cNpTH4BvsNVTd9II70VXo9TUOI5BOflQ6YKfkhi0T/SCvEPJKJH43eTzuix6PgYOFRsoKKi3HgRDdsNnuABz3bszh0H8AqUTlKtyAx/gGixz73bDGVSItpVUlsNsHSaT4h8onaAWnnMevoiG96VFtAf+RraU2M+o4EBB9VS0wXfRFsUbEhqd8EMSA9mgyV6KZtE2xK2FK3YtqTtG2lTBK0nse+OiPZK90sJHy7YhsiU6GW4tDMeQ3rEZw7d1Fp7BYlPj874HtyX+EbA98xbWmRpX4RH2mP9kRDT8qrg/IKHAgAdwV/TzuQlPRT+LFv5mYz+W+IS45WRYG4VT8BXuOI4JHb6xXLZBs7VdIRVckRjsN9a49kZERET8fb4B3fFbfZ9ESdgAAAAASUVORK5CYII=>

[image39]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAZCAYAAAAv3j5gAAABZElEQVR4Xu2UzSsFURiHX6EsyMJXRCQbCyErVhKyUZKF8gcoWwullOKvkI2FtRVLiaW6oqTEQokdG4mFj+ftvGPmzFyume6G7lNP3fueM/M7550zI1LiL9KBs/FiAZpxBTdwEdv84ZBuXMB9fMMtf/hHJnEPe7EB1/AFp6OTAjRoCofwVn4fVIW7+Ij9VuvEezzHeqsl0BbcSLqgHXFdGLZaq7jFXmOT1RKkDVI0rA7L7P8EvuMmVgST4mQJiqK7OcRj+/0tWYMa8Uhcy3LiDkaww7xkDYoygs+4ipX+UEgxgmrE7U4PyFhs7Iu0QbXiVj4nfqv0+g9citQ8CgXpjVskvKm+rHpDvUavVarxwOrzVksQBG1L8mHqET7FVxy02gA+4LqEz6ML7/BC8py8UXEnRvuqK1Gf8Ax7bI6uVD81l9huNV2Mfrr0K7AsroUneIV9NqeoaEvHcUbcLsv94RIl/jWf9M5E9cB6iPYAAAAASUVORK5CYII=>

[image40]: <data:image/png;base64,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>

[image41]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAZCAYAAABdEVzWAAACAUlEQVR4Xu2VTyhEURTGj1BEUYqUIvmTUpQQIRsrZSGl7KRkZWGjbMRWSdnIRmwtpCwsLCZK/ixIQiJRspIVhcT3dd5t7tx5byYWM6Pmq1/z3pl77/veOefeJ5JWWolRBRgCZSAT5IAGMOpdJ03t4B18W7yCXntQMtQELsAVOAUzoDRiRJJEY4tuMBX0F2PsPWa1G7SK9mYdGAA1IMMbx98ib6yBc/N9YlGisQ2wBm7AA5gGufYgR5xzLtqPHB8C46IbhvfroED0gbPg0Rv7BjrBsHf/Bc5E14sSg4egyrvnGx6BZZBtBvmIbx0CJ6DYivPB3EwLEs4c11kB16AcVIvONc/0FSflObEp0cXbnLgtY4zw2oiZ3gZPoNKK0xCNrYpWhy3wa02KpnrC/cNSkDGKD/8EHU68R7R8SxLOpq9YtmPRfrHLYYzxN0jxjLGfmp04y3wHXkCL81+EuCPuJdoYS0ljfVbMVZAxNv0BuAQlVpyl3BT9quyI9jET46ss0bTa9ebCu6KTeR0kY+xW9LNmNCharjErxs8d1+z37utFsxZzg/FN9sAcGBHdZfuii8WSMcYjhs3O8m2BZ1Fz7CFWwRwrhC/LjcbeNbEPMC8Bousu0QOSByUPzHhyS1koWrrADCRKrrGUEE/0WtGyE177flYSrUbRxrVhLK20/oV+AHGkasvX3fOyAAAAAElFTkSuQmCC>

[image42]: <data:image/png;base64,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>

[image43]: <data:image/png;base64,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>

[image44]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAAAZCAYAAACB6CjhAAACj0lEQVR4Xu2WTYhPURjGn0lqMBpFJmWiaZCSj4QSZcNCKUlRVlJYyGLkIyvZWIyEIlkQVrKQkiyUaSzMUJSU0kw+asYKq1FIPI/3nO69r3vvzGIu88996tfc/3vPPXPPc9/3PQeoVatWrfHTCrLJB4OayBpynlwkW8jkzIgGlRZ1hDwlP8nR7O3f0uIPkwtkXqCb3COtqXENKRmgr7mZjCDfgCXkNpmeik2BGbAzFWtorUSxATLoGZnp4tdIl4s1rMoMWEe+kydkYYjNJ/2wvpGnZjKHbIBl2SSymGyHzaGykvRXxmpsRM+25MQqVZkBanaXYT3iGzlDHpFt6UFOmu8l7Jn3pIccJHvD71uw/qGFnSRDYewXsp7sDr9/kBew+SpVmQHSVHIT9lLiFVmaGfGn9BV7yHMyOxXXAr+Ss0gyQSZfJa9hTXYB7NnOcL9UergN2ZQpQi+idPQqM0DznyY3yFrYgmSCxqs8ihQNELqOUgO9Tz6QjlRcC5cB6i3XYaUzJi2HpehYOAerX68yA/aTh0gWoQUcg6WnFqLfeSoyQNIi1Ve8gRth815Ckh1/RUUGTCMPyD4Xlw6Qd7DMytNoBqjeV7m4yuMN+UxWu3uVqsiAuIhdLi7p5R+TWf5GUJEBan59sD6i0o1SCdwhy2Cma9fxW29ligYc9zeoQ7BFpE996iOnyIlUzCsaMIhs2e2ApblKK2ou6UWys+jwpSxQ2VZ65NZLDCPp7uITbJuLnVs1rpp8C9vK9sC+0BVYiRQpGjAA6xVK+7vkI8wE1bj+R9wuhebVnDpgxVjcev+52snWgK5Hky+BGbCUr/SLTiR5A/4r6YS3CHZmELqu/Dg7kZR3NlGsVq1atcZNvwAKM5CzqaJFiwAAAABJRU5ErkJggg==>

[image45]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAZCAYAAAAv3j5gAAABsUlEQVR4Xu2UzytEURTHj1AUSX5FJBJZIVnYSEIsSFhhr2wtlFJT2PgHlGbjL7BiY0FslCILlFiQWGGDUH58v869M/fd6c0kK5pPfZp55953zrv33fNE0vwlcuEYXIFLsCE4nJRyOCd67zSsCg7HKYCbcB7mwWZ4AkfcSSEMwA3YBEtEc7zAYXeSZQbuw0InNg5PYZkT88mB6/ABtphYLbyFx7DYxL5hchZZdYOgDT7CQS/uwkJr8B12mlglvIYX4j1kI7yTxEKt8AkuenEfFiuCGea6D37AKMyyk4hNGFbIjyeDq9kR3SH+D8CX+SmJCX9SqBTuim7ZgejBsCuM0S+/L+TSBZ9hBGa7A2EJw+KpyBddHQ9Ijztgj6Of0Baa9eIu7L+IaCu4W8Vc3CW2TQw26LZoP/AEWbrhm/m1MHGFxJPa93sp+nUgNh/jkyYWYwJewRpzzUTs8D3R5IRH+Ai+wnYT46rv4YLE30cdvBFt9oSTx0nLcAsOiRZhZ/NTZOGT8lNzBqtNjA80JTqXW8wtPITnErw3AG+qh6OwQ7wTkwKuulf0Xq4yMzicJs2/5gsixVOqHkFlLAAAAABJRU5ErkJggg==>

[image46]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF4AAAAZCAYAAAC4j5m6AAADX0lEQVR4Xu2XW+hNQRTGl1AuidAfUU6hSKTcSh4lklIoD95EbikK0T+eRC5P5ME1DyIJhSLygKKUJE9KIVEUESVy+b7WnnPmzJmZfenglPnV1zl7zjp71lp79lozIolEIpH4n6hBy9zBAIugve7gX6QmYV97Qgugw5mWQH2bLDqACdBa6Bb0AzrV/LOXGvRMitm2kyK+9oYOQjuhMdBK6Av0BBpt2f1zGAxX7yzolfiDsWFgx6Bfkm/bbor4Og+6CY20xpaL+ku/e1njHcEI6IX4g7FZCh2QcOAuPUTfEH6GGAL1dwcjxHzdKo0kG0aJ+su3dJg13hHEgjHUoCPQeMm3NXCFbYc2ij/5XMVXpVwZiPk6DXoErbLGjD3F7y70iw9/nGhvGAwNhOZmshdFH9F7GPF/jLHLGfPF6iUWDGGJ2Q/NlHxbF/53H7RZmh2qknRSdv7Z0HfoomjiXDjGjcJn6Cd0Dzop2rxPZON8IGQKdB/6JvpmnREtaw+y6/ei9/LN4yUvmMXQJtHE5dn6cJNfNemkzPycl0n8AM1wfnNZKJq8FdJYIPz/OegdNDEbI1yAn6Atoruo3dC27HspYsEwOUdFXz8Ss41hks97VU06KTM/F8wbaI77gweTeH7asGHzTdhljfHBMOlc4ewrh0TjK00oGNavPaJP2BCyLQJr8GuoW0rUQYei83OFP4Smuz8ECCV+quiW9Lw074p4NrgMfYQmW+OlCAXDpnEHemmJiaODrHO8Xl23jsP6eF20ie2Q1ppflJCvNkz6XWhsds2EcVs5qG7RSl7iT0uzv1zh9OGr6KajrSveRxlbg0m6KS90smry8+bnHFyddikbKpqcAdaYSyjxbLIcX2+N0Wf6TnGLzebNB1saE4z7VH2YfXERW8KkX5HWml41+TFfh0O3RWuv/Za+FW2SsQOUSTybpLkv+xrvx5Mv337CBsoGfEP0QdKWNb5IA6/DpsMk8gjOSSlunx5Dkyw7wv3sWWlspSgGGCs1/UQbqpt0A4PYIHoazaOIr+YA5ZPdHH2YxF+CrkHHoefQBdEHStZlNkbzRQ9lPJyZsafSmrtEBLvU8G1kQmM9IdEmQjU+8YdgjeYxf41o4vlZ6tifqAaP92zw3PUY8brwsT+RSCQSCfIbCl7WDLcTuGIAAAAASUVORK5CYII=>

[image47]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAZCAYAAABdEVzWAAAB3ElEQVR4Xu2WzSsGURTGj1BEUURKkXykFCVsKBtlYyNlYWWDlYUFe3+AZEMoYWFBSVGKhaxko6SUiJSsZEUh8Tyduea6mXmHxaDmqV/vzLlfZ845995XJFGieNQJlkAdKHEoBpl+13g1Bt4CuAO1ftd4NQ/WwazFHLgCoyDto2eMygXToNCxt4BlkO3YYxMXphMZlq0IrIEyy+YqS7QG20XHp4umvAdUix9l/hZ4fQ0cy4C4tlDRwSnQ6zY4agQnonV4DfbAMBjw3ldBnuiC4+DG6/sI2kC/9/4KjkXnCxUH7YhOmkr86j1wJBplI87xBCbFjxx39gI4E81ElejYSq89VIzWimjEosg4RvhsxPLYBregwrLTITq2KHo8sQQiiefYPehzGwIU5BjFxV9Aq2PvEE3fjHxjtw+K5r3LbQhQKsdYT02OnWm+FA1As9MWKJ5nX31lkIIcY30egFPRm8OIqdwA9WAXHIru2FBx92yBB4mwQzwZxy5AuWXnjma6hixbKdgH3d67KRse5qFXXo7oV/zEsXPRYmf6NkWvMTrHGuJuNccK4Rpca8SyPYMJCRFDzTTysIwiN5X58suXvpHr2J8Qa7JG9HAlfE55rcShBvn8b4TQlijRv9A7hllkb8HUbHAAAAAASUVORK5CYII=>