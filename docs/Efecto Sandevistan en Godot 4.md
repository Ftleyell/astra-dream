# **Arquitectura y Desarrollo del Efecto Sandevistan en Godot Engine 4: Shaders 2D, Flameo Perimetral y Estelas Cinemáticas**

La transposición técnica del implante de aceleración neural Sandevistan, derivado del imaginario de *Cyberpunk: Edgerunners*, plantea un problema complejo dentro de la arquitectura de renderizado en tiempo real de Godot Engine 41. En la animación tradicional de Studio Trigger, la cinemática de hiperextensión temporal no se reduce a una interpolación lineal de movimiento, sino que se manifiesta mediante una descomposición óptica agresiva caracterizada por imágenes residuales (*afterimages*) desfasadas, aberración cromática direccional, siluetas monocromáticas hiperneón y una emanación calórica o plasmática que flamea y se extingue desde los bordes de la figura en traslación1.  
Para conseguir este comportamiento sobre un sprite bidimensional definido por una textura rasterizada con transparencia (formato PNG), el pipeline de *CanvasItem* de Godot 4 debe estructurarse a través de tres niveles interdependientes: una fase geométrica que rediseña los límites del quad original mediante deformación de vértices, una fase de fragmentos que desacopla la distorsión del contorno perimetral utilizando ruido coherente sobre el canal alfa, y una capa cinemática que desacopla la instanciación de entidades fantasma en el espacio de coordenadas globales1.

## **Fundamentos Visuales y Evaluación Arquitectónica de Persistencia 2D**

El impacto visual del efecto descansa sobre la ilusión de una velocidad de desplazamiento que supera la persistencia de la visión del espectador y la capacidad del ojo para recomponer el espectro lumínico2. Este fenómeno visual se articula a través de una superposición continua de estados pasados del actor que van disolviendo su densidad a medida que la entidad avanza en el espacio, integrando una separación explícita de canales cromáticos en el sentido longitudinal de su vector de velocidad1. Simultáneamente, el contorno perimetral del sujeto proyecta una combustión etérea que no afecta la integridad de la figura interna, preservando el núcleo del arte conceptual del personaje mientras la periferia reacciona al arrastre aerodinámico o a la sobrecarga térmica del implante6.  
Dentro del ecosistema de Godot 4, materializar este comportamiento exige discernir el mecanismo de generación de las imágenes residuales. Las soluciones técnicas habituales en el desarrollo bidimensional presentan compromisos térmicos y computacionales diversos, oscilando entre la manipulación de postprocesamiento en búfer de pantalla, los emisores de partículas basados en GPU y la orquestación discreta de nodos clones1.

| Paradigma de Implementación | Control Artístico de Shaders | Sobrecarga de Renderizado | Desacoplamiento Transformacional | Fidelidad con el Canon Visual de Edgerunners |
| :---- | :---- | :---- | :---- | :---- |
| **Instanciación Discreta de Nodos (Sprite2D)** | Absoluto; permite materiales únicos e interpolaciones asíncronas1. | Controlable mediante reciclaje de memoria (*node pooling*)16. | Completo en coordenadas globales del árbol de escena1. | Máxima fidelidad con la animación clásica por fotograma clave1. |
| **Emisión de Partículas (GPUParticles2D)** | Rígido; constreñido al material de pase de partículas14. | Mínimo impacto en CPU; cálculo masivo en Compute Shaders14. | Relativo a la simulación física del emisor14. | Media; dificultad para mutar siluetas complejas con flameo independiente14. |
| **Búfer de Retroalimentación (Screen-Reading)** | Indirecto; sujeto a la captura global de la ventana13. | Elevado en GPU por conmutación y lectura recursiva13. | Nulo; depende estrictamente de la vista activa13. | Baja; genera un arrastre difuso en lugar de copias nítidas y sólidas13. |

El balance computacional confirma que la instanciación de nodos independientes asociados a un material de sombreado personalizado proporciona la elasticidad paramétrica necesaria para emular la obra animada, garantizando que cada copia fantasma preserve de manera inmutable el cuadro específico de la animación y responda individualmente a su curva de disolución y cromatismo sin contaminar a los demás elementos de la pantalla1.

## **Geometría y Expansión Perimétrica en el Espacio de Vértices**

En el pipeline bidimensional estándar de Godot 4, un nodo Sprite2D se compone de dos triángulos formando un rectángulo plano o quad ajustado con rigidez matemática a la cuadrícula de píxeles del mapa de bits original5. Cuando se busca proyectar un halo de energía, fuego perimetral o distorsión ondulatoria que trascienda la silueta exterior del PNG, los fragmentos generados más allá del límite paramétrico ![][image1] son truncados automáticamente por el rasterizador al alcanzar el borde de la geometría7.  
Para permitir que el fuego emane y se extienda fuera de las dimensiones físicas de la textura sin recurrir a la ineficiente práctica de agregar márgenes vacíos transparentes en los archivos gráficos de origen, resulta imperativo intervenir la función vertex() del sombreador7. Esta intervención requiere desplazar los vértices hacia el exterior a lo largo de sus vectores directores locales y, de forma concurrente, proyectar una transformación inversa sobre las coordenadas paramétricas UV en la etapa de fragmentos7.  
La formulación analítica de este desacoplamiento dimensional se define considerando un vector de posición local del vértice ![][image2] y un margen de expansión escalar ![][image3] expresado en píxeles. La dilatación de la malla se formula mediante la función de signo para garantizar un crecimiento uniforme en las cuatro esquinas:  
![][image4]  
Esta operación incrementa el ancho y el alto geométrico del quad en una magnitud equivalente a ![][image5] unidades lineales7. No obstante, este incremento produce una distorsión por tracción en el mapeo de texturas convencional, ya que el espacio de coordenadas normalizadas continuaría extendiéndose uniformemente de ![][image6] a ![][image7] sobre un área más extensa7. La restitución visual de la escala y posición originales del sprite dentro del nuevo espacio delimitado demanda una contracción y recentrado analítico calculado a través del tamaño del texel original:  
![][image8]  
![][image9]  
![][image10]  
![][image11]  
Cualquier fragmento cuya coordenada resultante ![][image12] se sitúe por debajo de ![][image6] o por encima de ![][image7] reside matemáticamente en la zona expandida creada por el sombreador de vértices7. En dicha franja suplementaria, el canal alfa del sprite es evaluado como nulo, concediendo un lienzo geométrico completamente libre y no deformado para computar el flameo y las llamas sin experimentar cortes abruptos7.

## **Implementación Técnica del Shader CanvasItem**

El programa de sombreado integra la deformación geométrica en vértices, el muestreo isotrópico de convolución sobre el canal alfa para aislar la frontera exterior de la silueta, la modulación oscilatoria basada en un mapa de ruido procedural continuo y la dispersión espacial de los canales de color para provocar la aberración cromática4.

OpenGL Shading Language  
shader\_type canvas\_item;  
render\_mode blend\_mix;

// Geometría y expansión del espacio de trabajo  
uniform float margin\_expansion : hint\_range(0.0, 150.0, 1.0) \= 45.0;

// Propiedades de la emanación y combustión  
uniform sampler2D noise\_texture : repeat\_enable, filter\_linear;  
uniform vec2 flame\_direction \= vec2(0.0, \-1.0);  
uniform float flame\_speed : hint\_range(0.1, 10.0) \= 3.5;  
uniform float flame\_distortion\_intensity : hint\_range(0.0, 0.5) \= 0.08;  
uniform float flame\_thickness : hint\_range(0.0, 60.0) \= 24.0;

// Paleta de sobrecarga energética HDR  
uniform vec4 inner\_flame\_color : source\_color \= vec4(0.0, 2.0, 2.5, 1.0);  
uniform vec4 outer\_flame\_color : source\_color \= vec4(0.9, 0.0, 2.0, 1.0);  
uniform float hdr\_energy\_multiplier : hint\_range(1.0, 10.0) \= 3.0;

// Refracción cinética y aplanamiento de silueta  
uniform vec2 chromatic\_aberration\_offset \= vec2(3.5, 0.0);  
uniform float silhouette\_solidarity : hint\_range(0.0, 1.0) \= 0.0;

varying vec2 corrected\_uv;  
varying vec2 dynamic\_pixel\_ratio;

void vertex() {  
    vec2 expansion\_dir \= sign(VERTEX);  
    VERTEX \+= expansion\_dir \* margin\_expansion;

    vec2 original\_size \= 1.0 / TEXTURE\_PIXEL\_SIZE;  
    vec2 expanded\_size \= original\_size \+ vec2(margin\_expansion \* 2.0);  
    dynamic\_pixel\_ratio \= original\_size / expanded\_size;  
      
    vec2 margin\_uv\_fraction \= vec2(margin\_expansion) / expanded\_size;  
    corrected\_uv \= (UV \- margin\_uv\_fraction) / dynamic\_pixel\_ratio;  
}

float sample\_alpha(sampler2D tex, vec2 coords) {  
    if (coords.x \< 0.0 || coords.x \> 1.0 || coords.y \< 0.0 || coords.y \> 1.0) {  
        return 0.0;  
    }  
    return texture(tex, coords).a;  
}

void fragment() {  
    // Generación de coordenadas desfasadas temporalmente con ruido continuo  
    vec2 noise\_coords \= corrected\_uv \+ (flame\_direction \* TIME \* flame\_speed);  
    vec2 noise\_offset \= (texture(noise\_texture, noise\_coords).rg \- 0.5) \* 2.0 \* flame\_distortion\_intensity;  
    vec2 distorted\_uv \= corrected\_uv \+ noise\_offset;

    // Desfase tricromático en el núcleo del sprite  
    vec2 texel \= TEXTURE\_PIXEL\_SIZE;  
    vec2 ca\_shift \= chromatic\_aberration\_offset \* texel;  
      
    float r \= texture(TEXTURE, clamp(corrected\_uv \- ca\_shift, vec2(0.0), vec2(1.0))).r;  
    float g \= texture(TEXTURE, clamp(corrected\_uv, vec2(0.0), vec2(1.0))).g;  
    float b \= texture(TEXTURE, clamp(corrected\_uv \+ ca\_shift, vec2(0.0), vec2(1.0))).b;  
    float base\_alpha \= sample\_alpha(TEXTURE, corrected\_uv);

    vec4 base\_color \= vec4(r, g, b, base\_alpha);

    // Muestreo morfológico radial en ocho direcciones para localizar la frontera perimetral  
    float perimeter\_accum \= 0.0;  
    float radius \= flame\_thickness;  
    vec2 sample\_vectors\[8\] \= vec2\[\](  
        vec2(1.0, 0.0), vec2(\-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, \-1.0),  
        vec2(0.707, 0.707), vec2(\-0.707, 0.707), vec2(0.707, \-0.707), vec2(\-0.707, \-0.707)  
    );

    for (int i \= 0; i \< 8; i++) {  
        vec2 probe\_uv \= distorted\_uv \+ (sample\_vectors\[i\] \* radius \* texel);  
        perimeter\_accum \+= sample\_alpha(TEXTURE, probe\_uv);  
    }  
    perimeter\_accum /= 8.0;

    // Aislamiento del flameo perimetral externo anulando la densidad interna  
    float flame\_mask \= smoothstep(0.01, 0.8, perimeter\_accum) \* (1.0 \- base\_alpha);

    // Mapeo tonal bicromático y escalado fotométrico de energía  
    vec4 flame\_fx \= mix(outer\_flame\_color, inner\_flame\_color, perimeter\_accum);  
    flame\_fx.rgb \*= hdr\_energy\_multiplier;  
    flame\_fx.a \*= flame\_mask;

    // Fusión compuesta entre la silueta central y el aura de eyección exterior  
    vec4 final\_color \= mix(flame\_fx, base\_color, base\_alpha);

    // Opcional: Aplanamiento estilizado monocromático para siluetas fantasma  
    if (silhouette\_solidarity \> 0.0 && base\_alpha \> 0.01) {  
        vec3 solid\_tint \= inner\_flame\_color.rgb \* hdr\_energy\_multiplier;  
        final\_color.rgb \= mix(final\_color.rgb, solid\_tint, silhouette\_solidarity);  
    }

    COLOR \= final\_color;  
}

## **Configuración del Pipeline de Resplandor 2D HDR**

Para que las emisiones electromagnéticas modeladas en el sombreador dispersen un resplandor atmosférico verosímil y no se degraden a colores planos sobreexpuestos, es necesario configurar el motor para admitir precisión de color superior a la unidad en etapas de renderizado bidimensional17. Durante las primeras versiones de Godot 4, el valor de modulación de los nodos CanvasItem era recortado por encima de ![][image7], impidiendo la interacción correcta con los algoritmos de floración lumínica17. En las versiones contemporáneas de Godot 4, la activación explícita del pipeline HDR para 2D restituye la posibilidad de alimentar el búfer con valores en punto flotante de dieciséis bits (FP16), los cuales son filtrados posteriormente por el subsistema de posprocesamiento de cámara22.  
El establecimiento de este entorno demanda ajustar parámetros críticos a nivel de proyecto y la incorporación de un nodo WorldEnvironment dedicado exclusivamente a la escena bidimensional21. En la ventana de configuración del proyecto, dentro de la sección de renderizado de la ventana gráfica, la propiedad rendering/viewport/hdr\_2d debe fijarse en estado activo, requiriendo un reinicio de la aplicación para instanciar las canalizaciones de renderizado con búferes lineales no acotados21. A partir de este ajuste, el nodo de entorno en el espacio de ejecución 2D actúa extrayendo las frecuencias lumínicas extremas21.

| Categoría de Configuración | Parámetro en el Inspector | Valor Establecido | Justificación Técnica de Renderizado |
| :---- | :---- | :---- | :---- |
| **Ajustes de Proyecto** | rendering/viewport/hdr\_2d | true | Asigna búferes de renderizado en formato FP16 en lugar de enteros fijos22. |
| **WorldEnvironment (Modo)** | Background \-\> Mode | Canvas | Restringe el alcance operativo del entorno al plano bidimensional21. |
| **WorldEnvironment (Glow)** | Glow \-\> Enabled | true | Conmuta la etapa de filtrado y difusión espacial en el pase final21. |
| **WorldEnvironment (Glow)** | Glow \-\> Normalized | false | Impide que el motor normalice las amplitudes forzando fidelidad física21. |
| **WorldEnvironment (Glow)** | Glow \-\> Blend Mode | Additive | Permite que los haces lumínicos se sumen intensificando la saturación21. |
| **WorldEnvironment (Glow)** | Glow \-\> HDR Threshold | 1.0 | Garantiza que solo los fragmentos sobrecargados emitan luz dispersa17. |
| **WorldEnvironment (Glow)** | Glow \-\> HDR Scale | 2.0 | Amplifica la dispersión de las bandas de luz de las siluetas energéticas21. |
| **WorldEnvironment (Glow)** | Glow \-\> Levels/1 a Levels/4 | Activados progresivamente | Distribuye la difusión en múltiples frecuencias de desenfoque gaussiano21. |

## **Orquestación Cinemática y Desacoplamiento Espacial en GDScript**

La generación procedural de la estela Sandevistan mientras el actor ejecuta maniobras de vuelo debe gestionarse mediante una arquitectura basada en la distancia euclidiana recorrida y no mediante temporizadores de intervalo fijo1. Los temporizadores temporales introducen irregularidades: cuando la entidad se traslada a velocidades hipersónicas, las copias residuales quedan visualmente separadas por distancias excesivas; cuando desacelera o describe círculos cerrados, las entidades se acumulan sobre el mismo punto de origen, elevando exponencialmente la sobrecarga de mezcla alfa sobre los mismos fragmentos15.  
El sistema de control cinemático se estructura a través de dos scripts complementarios: uno responsable de gestionar el ciclo vital y la decadencia de cada copia fantasma individual, y otro encargado de monitorear el vector de velocidad e interpolar los puntos de generación en el árbol de ejecución1.

### **Ciclo Vital y Disolución Paramétrica (afterimage\_ghost.gd)**

El script asignado a cada clon instanciado duplica su material para prevenir que las modificaciones sobre las variables uniformes del sombreador se transmitan a las demás copias residuales presentes en la escena28. Con ello, se orquesta una reducción asíncrona de visibilidad y una dilatación paulatina de la combustión periférica mediante el sistema de interpolación de nodos Tween29.

GDScript  
class\_name AfterimageGhost  
extends Sprite2D

var lifetime: float \= 0.35  
var tween: Tween

func setup(  
    source\_texture: Texture2D,  
    world\_pos: Vector2,  
    world\_rot: float,  
    world\_scale: Vector2,  
    base\_material: ShaderMaterial,  
    energy\_color: Color,  
    flight\_velocity: Vector2  
) \-\> void:  
    texture \= source\_texture  
    global\_position \= world\_pos  
    global\_rotation \= world\_rot  
    global\_scale \= world\_scale  
      
    \# Se genera una instancia única del recurso para permitir animación paramétrica aislada  
    var mat\_instance := base\_material.duplicate() as ShaderMaterial  
    material \= mat\_instance  
      
    \# Orientación vectorial del flameo opuesta a la cinemática de la nave  
    var burn\_dir: Vector2 \= \-flight\_velocity.normalized()  
    if burn\_dir.is\_zero\_approx():  
        burn\_dir \= Vector2.UP  
          
    mat\_instance.set\_shader\_parameter("flame\_direction", burn\_dir)  
    mat\_instance.set\_shader\_parameter("inner\_flame\_color", energy\_color)  
    mat\_instance.set\_shader\_parameter("silhouette\_solidarity", 0.9)

    \_animate\_and\_cleanup()

func \_animate\_and\_cleanup() \-\> void:  
    tween \= create\_tween().set\_parallel(true)  
      
    \# Decaimiento cuadrático del canal alfa general  
    tween.tween\_property(self, "modulate:a", 0.0, lifetime)\\  
        .set\_trans(Tween.TRANS\_QUAD)\\  
        .set\_ease(Tween.EASE\_OUT)  
          
    \# Extinción del radio de muestreo perimetral a lo largo de la existencia del fantasma  
    var current\_mat := material as ShaderMaterial  
    tween.tween\_method(  
        func(val: float): current\_mat.set\_shader\_parameter("flame\_thickness", val),  
        current\_mat.get\_shader\_parameter("flame\_thickness"),  
        0.0,  
        lifetime  
    ).set\_trans(Tween.TRANS\_CUBIC).set\_ease(Tween.EASE\_IN)  
      
    tween.finished.connect(queue\_free)

### **Gestor Espacial de Emisión Cinemática (sandevistan\_emitter.gd)**

Este controlador mide el vector traslacional entre fotogramas sucesivos. Al detectarse que el desplazamiento supera un umbral mínimo configurado, calcula el cociente entero de pasos requeridos y ejecuta una interpolación lineal entre la posición previa y la actual, asegurando una densidad volumétrica regular a lo largo del arco de vuelo1.

GDScript  
class\_name SandevistanEmitter  
extends Node2D

@export var source\_sprite: Sprite2D  
@export var ghost\_material: ShaderMaterial

@export\_category("Control de Emisión")  
@export var is\_sandevistan\_active: bool \= false  
@export var distance\_step: float \= 22.0  
@export var ghost\_lifetime: float \= 0.4  
@export var min\_speed\_threshold: float \= 120.0

@export\_category("Paleta Cromática Edgerunners")  
@export var trail\_colors: Array\[Color\] \= \[  
    Color(0.1, 3.5, 1.2, 1.0), \# Cian esmeralda radioactivo  
    Color(0.0, 1.8, 4.0, 1.0), \# Cobalto de polarización iónica  
    Color(3.5, 0.1, 2.0, 1.0)  \# Magenta fucsia de hiperaceleración  
\]

var \_last\_spawn\_position: Vector2 \= Vector2.ZERO  
var \_color\_index: int \= 0  
var \_current\_velocity: Vector2 \= Vector2.ZERO

func \_ready() \-\> void:  
    \_last\_spawn\_position \= global\_position

func set\_sandevistan\_state(active: bool) \-\> void:  
    is\_sandevistan\_active \= active  
    \_last\_spawn\_position \= global\_position

func set\_motion\_vector(velocity: Vector2) \-\> void:  
    \_current\_velocity \= velocity

func \_process(\_delta: float) \-\> void:  
    if not is\_sandevistan\_active:  
        return

    var current\_speed: float \= \_current\_velocity.length()  
    if current\_speed \< min\_speed\_threshold:  
        return

    var dist: float \= global\_position.distance\_to(\_last\_spawn\_position)  
    if dist \>= distance\_step:  
        var total\_ghosts: int \= int(dist / distance\_step)  
        for i in range(total\_ghosts):  
            var weight: float \= float(i \+ 1\) / float(total\_ghosts)  
            var interpolated\_pos: Vector2 \= \_last\_spawn\_position.lerp(global\_position, weight)  
            \_instantiate\_afterimage(interpolated\_pos)  
              
        \_last\_spawn\_position \= global\_position

func \_instantiate\_afterimage(spawn\_pos: Vector2) \-\> void:  
    var ghost := AfterimageGhost.new()  
      
    \# Se añade la instancia directamente a la raíz de la escena para desvincular coordenadas  
    get\_tree().current\_scene.add\_child(ghost)  
      
    var assigned\_color: Color \= trail\_colors\[\_color\_index\]  
    \_color\_index \= (\_color\_index \+ 1\) % trail\_colors.size()  
      
    ghost.lifetime \= ghost\_lifetime  
    ghost.setup(  
        source\_sprite.texture,  
        spawn\_pos,  
        source\_sprite.global\_rotation,  
        source\_sprite.global\_scale,  
        ghost\_material,  
        assigned\_color,  
        \_current\_velocity  
    )

## **Análisis de Rendimiento en GPU y Consideraciones de Producción**

La generación recurrente de capas semitransparentes apiladas introduce un desafío significativo sobre el ancho de banda del subsistema de memoria gráfica, conocido como tasa de sobregiro o *overdraw*16. En escenarios donde múltiples quads expandidos geométricamente coinciden en la misma región del búfer de fotogramas, la GPU se ve forzada a evaluar la función fragment() de forma iterativa antes de escribir el valor final en el objetivo de color16. Para preservar una tasa de refresco estable bajo estas condiciones de estrés, deben implementarse criterios analíticos de optimización en el flujo de ejecución.  
El coste aritmético del sombreador depende en gran medida del método empleado para generar el ruido. La utilización de funciones analíticas de ruido procedimental evaluadas estrictamente dentro del shader impone una carga aritmética recurrente sobre las unidades de cómputo para cada fragmento generado30. Al reemplazar dicho cálculo por el muestreo de una textura continua asignada mediante NoiseTexture2D conectada a un generador FastNoiseLite, el procesado se delega directamente al hardware de filtrado bilineal de la GPU, transformando un cómputo iterativo pesado en una lectura de textura amortizada a bajo costo5.  
La calibración del parámetro de margen en vértices también ejerce un impacto directo sobre la tasa de relleno. Si el valor asignado a margin\_expansion supera ampliamente la suma efectiva de flame\_thickness y la distorsión del ruido, se estarán procesando áreas transparentes periféricas innecesarias que comprometen la tasa de relleno sin aportar detalle visual7. Restringir esta expansión a la envolvente matemática mínima del efecto maximiza la eficiencia del rasterizador7.  
Asimismo, en producciones con trayectorias de vuelo prolongadas o múltiples entidades concurrentes, la continua asignación y liberación de instancias de nodos a través de llamadas a queue\_free() fragmenta la memoria del montículo e introduce pausas en el recolector de basura. La integración de una cola estática de reserva (*object pooling*) para prealojar los nodos de las imágenes residuales y alternar su visibilidad y propiedades en memoria elimina la sobrecarga de instanciación en tiempo de ejecución, asegurando una experiencia visual cinematográfica fluida y plenamente fiel a la estética de *Cyberpunk: Edgerunners*1.

#### **Obras citadas**

> 1. \#effects \- Godot Asset Store, [https://store.godotengine.org/search/?query=%23effects](https://store.godotengine.org/search/?query=%23effects)  
> 2. Still the goat ‼️ \#cyberpunkedgerunners \#davidmartínez \#tiktok, [https://www.facebook.com/jeffery.lewis.249713/videos/still-the-goat-%EF%B8%8F-cyberpunkedgerunners-davidmart%C3%ADnez-tiktok-funnyvideos-anime/1233670238785817/](https://www.facebook.com/jeffery.lewis.249713/videos/still-the-goat-%EF%B8%8F-cyberpunkedgerunners-davidmart%C3%ADnez-tiktok-funnyvideos-anime/1233670238785817/)  
> 3. What exactly is the Sandevistan in game suppose to be? It goes into, [https://www.reddit.com/r/cyberpunkgame/comments/xg9rhs/what\_exactly\_is\_the\_sandevistan\_in\_game\_suppose/](https://www.reddit.com/r/cyberpunkgame/comments/xg9rhs/what_exactly_is_the_sandevistan_in_game_suppose/)  
> 4. Just Chromatic Aberration \- Godot Shaders, [https://godotshaders.com/shader/just-chromatic-aberration/](https://godotshaders.com/shader/just-chromatic-aberration/)  
> 5. Your First Shader from ZERO in Godot 4 | GDQuest Library, [https://www.gdquest.com/library/first\_shader\_godot4\_portal/](https://www.gdquest.com/library/first_shader_godot4_portal/)  
> 6. Transparent noise border \- Godot Shaders, [https://godotshaders.com/shader/transparent-noise-border/](https://godotshaders.com/shader/transparent-noise-border/)  
> 7. 2D outline/inline \- Godot Shaders, [https://godotshaders.com/shader/2d-outline-inline/](https://godotshaders.com/shader/2d-outline-inline/)  
> 8. Could the sandevistan be built and work in real life? \- Reddit, [https://www.reddit.com/r/cyberpunkgame/comments/yszoz0/could\_the\_sandevistan\_be\_built\_and\_work\_in\_real/](https://www.reddit.com/r/cyberpunkgame/comments/yszoz0/could_the_sandevistan_be_built_and_work_in_real/)  
> 9. Mega Combat VFX Kit \- 214 Procedural 2D Effects for Godot 4 by, [https://outoftokensstudio.itch.io/mega-combat-vfx-kit](https://outoftokensstudio.itch.io/mega-combat-vfx-kit)  
> 10. Adjustable Chromatic Aberration \- Godot Shaders, [https://godotshaders.com/shader/adjustable-chromatic-aberration/](https://godotshaders.com/shader/adjustable-chromatic-aberration/)  
> 11. 2D fire \- Godot Shaders, [https://godotshaders.com/shader/2d-fire/](https://godotshaders.com/shader/2d-fire/)  
> 12. Balatro Original Fire Shader, [https://godotshaders.com/shader/balatro-original-flame-shader/](https://godotshaders.com/shader/balatro-original-flame-shader/)  
> 13. Efficient way to sample screen for afterimage shader? \- Godot Forum, [https://forum.godotengine.org/t/efficient-way-to-sample-screen-for-afterimage-shader/78755](https://forum.godotengine.org/t/efficient-way-to-sample-screen-for-afterimage-shader/78755)  
> 14. Particle systems (3D) \- Godot Docs, [https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html)  
> 15. gdquest-demos/godot-visual-effects \- GitHub, [https://github.com/gdquest-demos/godot-visual-effects](https://github.com/gdquest-demos/godot-visual-effects)  
> 16. CanvasGroup — Godot Engine (stable) documentation in English, [https://docs.godotengine.org/en/stable/classes/class\_canvasgroup.html](https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html)  
> 17. CanvasItem Modulate values above 1.0 are clipped \#75153 \- GitHub, [https://github.com/godotengine/godot/issues/75153](https://github.com/godotengine/godot/issues/75153)  
> 18. Create a Ghosting Dash Effect with Particle System Godot 4.3, [https://www.youtube.com/watch?v=j-qVQw7AVrc](https://www.youtube.com/watch?v=j-qVQw7AVrc)  
> 19. How to modify 2D outline shader for dynamic canvas size in Godot, [https://www.facebook.com/groups/godotengine/posts/2640790086057569/](https://www.facebook.com/groups/godotengine/posts/2640790086057569/)  
> 20. How can I apply a stroke shader that works properly on text? : r/godot, [https://www.reddit.com/r/godot/comments/1rwsfzy/how\_can\_i\_apply\_a\_stroke\_shader\_that\_works/](https://www.reddit.com/r/godot/comments/1rwsfzy/how_can_i_apply_a_stroke_shader_that_works/)  
> 21. How to use Glow effect in Godot 4 \- Archive, [https://forum.godotengine.org/t/how-to-use-glow-effect-in-godot-4/1626](https://forum.godotengine.org/t/how-to-use-glow-effect-in-godot-4/1626)  
> 22. Godot 4.2 \- Why does 2D HDR mess up the colors? \- Reddit, [https://www.reddit.com/r/godot/comments/1899ofn/godot\_42\_why\_does\_2d\_hdr\_mess\_up\_the\_colors/](https://www.reddit.com/r/godot/comments/1899ofn/godot_42_why_does_2d_hdr_mess_up_the_colors/)  
> 23. Dev snapshot: Godot 4.2 dev 3, [https://godotengine.org/article/dev-snapshot-godot-4-2-dev-3/](https://godotengine.org/article/dev-snapshot-godot-4-2-dev-3/)  
> 24. How Can I Add a Glow Effect to Line2D in Godot4? : r/godot \- Reddit, [https://www.reddit.com/r/godot/comments/1gdsbf9/how\_can\_i\_add\_a\_glow\_effect\_to\_line2d\_in\_godot4/](https://www.reddit.com/r/godot/comments/1gdsbf9/how_can_i_add_a_glow_effect_to_line2d_in_godot4/)  
> 25. Environment and post-processing \- Godot Docs, [https://docs.godotengine.org/en/stable/tutorials/3d/environment\_and\_post\_processing.html](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)  
> 26. Simple Selective Glow Effect \- Godot Engine Tutorial \- YouTube, [https://www.youtube.com/watch?v=7R4NkOF5b2A](https://www.youtube.com/watch?v=7R4NkOF5b2A)  
> 27. How 2 Glow in 2D \- Looking at the 2D Glow demo project, [https://godotforums.org/d/37660-how-2-glow-in-2d-looking-at-the-2d-glow-demo-project](https://godotforums.org/d/37660-how-2-glow-in-2d-looking-at-the-2d-glow-demo-project)  
> 28. Introduction to Shaders in Godot 4 | Kodeco, [https://www.kodeco.com/43354079-introduction-to-shaders-in-godot-4](https://www.kodeco.com/43354079-introduction-to-shaders-in-godot-4)  
> 29. Internal rendering architecture \- Godot Docs, [https://docs.godotengine.org/en/stable/engine\_details/architecture/internal\_rendering\_architecture.html](https://docs.godotengine.org/en/stable/engine_details/architecture/internal_rendering_architecture.html)  
> 30. 2D Procedural Water \- Godot Shaders, [https://godotshaders.com/shader/perlin-procedural-water/](https://godotshaders.com/shader/perlin-procedural-water/)  
> 31. 4D noise in Godot 4? \- Reddit, [https://www.reddit.com/r/godot/comments/14ay8xs/4d\_noise\_in\_godot\_4/](https://www.reddit.com/r/godot/comments/14ay8xs/4d_noise_in_godot_4/)  
> 32. shader globals are seemingly null, even if they are set (Godot 4), [https://www.reddit.com/r/godot/comments/15j45ua/shader\_globals\_are\_seemingly\_null\_even\_if\_they/](https://www.reddit.com/r/godot/comments/15j45ua/shader_globals_are_seemingly_null_even_if_they/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAZCAYAAACsGgdbAAABtUlEQVR4Xu2WPShGURjHH6EI5StSFrLISEmRVUnKwkYpyWTBamBkoAwGH4PSm9VmIKOZTSILJYvVx//fubfOPfde9+tc7vD+6tfhOfd9zv/e95z3fUXK2KUCtsAOZ+T/f0mjxFi7Hp7DE7gCa7zTuTMPD2FJVJZAOHEs6m50eFeDcAfuwXFY6bkiGbVwTtSTM2GGDWcMJCgkA67CK9gl6q3gk96H1dp1UTTDaXgE3+Gj+B8GSRWyH77AYa3WLWqRMa0WBUNOwgF4KpZDboq/YQO8FrV/Qjf4L3ANs6dL4pA8ODxIZkNedwlvYJNWj4vVkG4Ys2FYPS5WQ3JkM7NhoUK2w3vxNyxUyLAwYfW4WA1ZBc/E39ANyRPOk54UqyHJGnyDvVqtFd6K+gZy4Qd7mzNGYT1kD3yGM1ptBL7CIa22Bb/hulYLg2uwZ6c5ISlDkin4ABfgLLyDS+L9IF+GX/BCghfgU+b2+BB1M/RTVNhF7brUIQm/sycc+XcQ3Aa7sM6cSECmkHHg288fI1nINSRfewD7zImE5BqSp3/ULKYgMiT3En9GPTljlr2Vhm35v7XLFIsfflFqEO8O2doAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAaCAYAAABRqrc5AAAA5ElEQVR4XmNgGAWDH3QC8S8g/o+EJ6KoYGCIQZID4V1AzIeiAggkgfghFIPY2EAYEO8DYjF0CRjgAeIDQPwciJVQpcCAH4hXA7E2ugQyYAHiNUD8FYiN0eRAIB2Ii9AFsYE5DBD/+qKJqwDxOiAWRhPHCsoZIIaAbIUBViCeAcSuSGJ4QTQDxJAqJDGQ5gkMEO8SBUBhAQqTPQyQgK5ggEQtSUAGiJ8A8WkgdgbiBUDMiayAGCACxFeB+D0Q7wdiQ1Rp4gAsrYDCpRKIGVFkSQALgfgUA5HRiQvoArE8uuAoGNEAAFdHJkeIOxpdAAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEoAAAAaCAYAAAAQXsqGAAAC90lEQVR4Xu2XW6gNURjH/zoUuV9K4mHnTUpJKJc6iSKRB/dXiRRCxyWlLTyoQ7xILjkleXF5cUtCXngj8SgSeZISyt3/v7+17DVzzpw9s2efotavfu29Z609a8033/rWDBCJRFrDQDozfTDSnSF0Y/pgXmbRd/S38zkdk+iRZAH9Ceurzzt0dKJH66nQk/QNvUC7YHO+QZ/Rr/QBXUzbav/omVKB8nTSt7DJTEi1eRSQi/QjvUT7J5v7HF3kNDqOHgiOL3Rta+kROiBoCykdKJ3gPD1OP8Mmk6YfbJA99BfdnmzOjS5iLOxivboBOn8jsgI10v1WDdpA57vjg+leesp5jj4MfsvVrm8uJtLTdCVsSS1JNteYCpvobvqdzkk2N2QYPUaf0LOwSe6ny2k78mVnVqB0ow+6z+l0U9AWUjqjlsIyRYN8QfdsGUSrdDy9Tl/AsiIvk+hdOg/5MieLrEANdb+VQWvooqAtpHSgqrB01QW9p4cSrcAqWLsC9QrF6pMmd5nOSDc0QVagtOXvhG00ytThQVtIqUD5+qQCrixRtmhn8Xe+QnfBAqNgFa1PKrSqE60gDJQyVEv4Kf1BH8OKubI/i1KB8vVJhVAnuu/UdwVHQapY19r3ovVpK12GZPFOO+Jv795JZ9Q6uoLOhY1TZlk3xNcnoYGUTb4GKYO07IQC2Ux92kavIrnTpO2Anb8R6UApe7RT62ZrY+jTp+4q6tupUH1SnWqnh1FPZS1NPWMVqU9iPexmtIJ0oIR2Y81T8zuB7PpUCi0vPUDqjnhUf7TzKSCahKeZ+iQm0zPovXbkpadAic2wRxplVCeyHzibZja9BttePRpQz1JajuGaV6YVrU9C59DS2ofyF5AVKGWRskklQWPJltQrFb8PqL/ffYMVRqGJ3Eb9/e0o/eT6+b636CjXnoc2uoXeg42dpx6FVGBP1Xq/Uw2VKg9X6BTXR9l0E7YxvYS9GxYd559BmbCDPqKvA7vwH19UJBKJRCKRSCTJH6yflN7kaDdHAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,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>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAaCAYAAADWm14/AAAB80lEQVR4Xu2UTShFQRTHj3xElAUloV6ysZAkLFAWsqPYSFGyYYuFKLmyV2Qhykeys1Cy8LF4O2WhlOwUUsrCQlGSj///nZn35l7v9Z6dxf3Vr3tnztxm5pw7IxISkqAczsI1OA9r/OE4eXADfsJv46hvhJ8CeCCJsc9wyDcCNMMT2A7r4aHo4EmY5YxzqYVX8B3OBGIu/fASfsC2QCwGV7gPR2C26SuB5/AVNpq+ID1wBd7A7UDMEoFz8Fh0XJkvamDq7+CL6O4t3BWzMOH0uXiwF0aNRU6M5MAp2Apv4Z7p+0UuXIJHooux8GMugM8gnGwHVsFdSb67TtH08/klqTeSFK6UK+aP1uEPxaiG6zAfLsNH02dhCT3R8nIDKeufihbR+vNEMENBWP9p886dvcEm0+ZPOwYbRBfIHzpZhlJSDE9FU1wYiFk80dSSbtFS8Uk4MRfAhVRImvoH4W5X4aJo+pJh619p2tw5M8BM8BtPtATkT/W3kzO19jjyrHfFRyhu/W2b/wD/BR5lmxnCk5RR/ZkuXjrj5t3CG67PaRPWf8Fps7as8YXoTWpTnXH9OeGwaBof4L0jr0139UzxlvgXxZJERSeKOP02M2nrby8ie1e72uPF3bDubuwMloqyCQfNex28dsbRJzhg4iEhISH/ix9h3my51nO7tQAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAZCAYAAAAv3j5gAAABhUlEQVR4Xu2UPyhFYRTAj1CUSAb5U2IgmxKlZLIYSJiwyqgsSplkMVqUpEwiK70yMBiUyYAyyWKyMaDwO879ru/e977Xyyb3V7/uveeee859953vE8n4S1TjNG7hOnYlbxelFhfEnl3BpuTtH+rwBFexBnvwBif9pABteIVzWIUjeIf9fpJjCS+x3ovN4C02erE0FbiNh9G5Yw1zYl8pRotrk10/CH34jGOpuE8HPoq9qM8EvmCvH+zGJ8lvpEmarG8XYhg/JL/RKH6KfZUYVzDUKB33cQVDjRJxF0wXLKWRFsorKIFGOiW/bbQoBQpKoFGoYCjuU7BgKO4mJ13QNVpOxX0G8V3CjXT6YnSBnuGR2IJz6ES9RUeHLuxmLIuuW/AeN1xCxLzYJOtEJ5jFB2yPrrWQ7hIXYsWVBrEd4BUHiuRV4gHuSXIRf6M3N/EUx8Uevhbbihz6y4/FthfddhzaQOP7YoO1g+fY6uUk0LfrxCkcEmteKuVi/6k+q0e9zsj4L3wBkg5VmIuJstYAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAZCAYAAAAv3j5gAAABQUlEQVR4Xu2UvUvDUBRHr6hQQerg5Acobh2cBEFx7OJQEHEQnEVwEVycnMR/wFFEcBBRnEunTh266uikIHTqpoOIH+f63kuT18Q2kEXMgUOam8v9NZB3RXL+IrO46Rd7UMQ9PMVDnIg+7lDCXazjB15EH//KDN7hNhZwFR9wMdzk0KA1XMZn6T9oCM/w1v52HGMNR0K1CPrKT9J/0By28MCrr+MrLnj1gLRBZfyU7qAKfuGWVw9IG+QGJgX59YC0QToobmDmQfsSPzDzoKSBSfWAtEEr+C7dA12Qfn2x9Aoaw0kcsPdT+IgnrsGyg20x5zMWF3QpnWGOcTEb4A2XbE17jrAp5k8ow3iDVxI9xD/oedCNoOtHX1l9wXuctz2jWBWzXnTtODRA69di1s85NnA61JMZg2K2wIa96n1Ozn/hG2QmRuMzjv3UAAAAAElFTkSuQmCC>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAkMAAABoCAYAAADyzfRHAAAMOElEQVR4Xu3da6g1VRnA8UcsSLpnZFHgq6ZRZneR7mJZSRmRZkVhkURRlpFYGEFWSHfNrKzQyqJ6S6MPZVaEni5QVGSFVgShRRokGUT5weiy/q692muvPTN7Zr9e3rPP/wcPnndmz22t41nPXmvNTIQkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZIkSZKkbWTfFCel2NUslyRJ2lj7pTg+xXkprk/xzxSPX/iEJEnSBiMZOi7F0SneESZDkiRpB3trmAxJkqQdzGRIkiTtaCZDkiRpRzMZkiRJO5rJkCRJ2tFMhiRJ0o5mMiRJknY0kyFJkrSjkQzdnOLIdoUkSdKmunuK3SluSvHfKm5IcU71OUmSblN3TXF4ihdEfinmPrNlh1SfkSRJ2kjHpLg2xUdSvCzFJSm+muLLKV5TfU6SJGnjPD/F7yL3ChX0Cr07nLgqSZI23L1T/DjFqe2KyBNWf5Ti/u0KSZKkTfGUFP9K8cJ2ReQeofMi9xJJkiRtpOMj36VzRYr7Nev490ObZZIkSRvloBR/ivmty79NcXaYBEmSpB3kuBR/icXnudwSuddoKobUTk7xqtnP6yIZ+1mKP06Il966pSRJ0poOSHFKiqsjJ0SXpbjbwidWu0uKD0XuXdqTZOj2Uid8hmHcviFJe72HRH7Sb4uk6DcptlLcY3GVJEnSZqAH5/wUB7crIidAWykujfw5eniemuJjKT6Z4sUp9k3xmMgPZbwwxftTfDDFUSkuTvGeyPjci1J8I8W5kZ9d9M0UB87W92G7B6R40IQwcZMkSaM9OPLzhR7erog8X+e6mN9uz0MZPxf51RwkRu9Mcfps3Ssj9yI9LcVXUuwfeTsSIjwnxZciJ1Xsh6daHxp5X0PosXpuihMnRNe1SJIkdSrPFzozFuf27Be5p+dTkRMWkhh6iHhzeMHE6p+muO/s55L4FPWyN1c/c8zvRd5OkiTpTnVG5GErEp2fp3hLijdG7uXh/WRlLhH//W4sJ0PXRH4y9apkiF4gEqDXzpZ1PdxR0jR8gdkV+aXKvEan9No+LPIXGEnSCPzRLH9Ad0X+o0oSw+TpFonQR2Peg8SrO+g94o/uqmSI2/bZN6/9WDU0dkdjTtIPYvkW/b44J29267W1d810xc2RX2lCQsncqn836y+fraOM2m1fH9kRKX4Vy+fSFySdXBevUan3x7E5h5Lksv92/UmxvN0/Yv7YhesjD5HeKxYxX+sPsXwNXUF53zNvNgplzmMe6n1wPsR/Ig/nviFyjyb6yvqmFM/rWTemHqbWeVcdEDekeGbsGf5fYuj5W5Ffqvy+yF9o3pbi25HnznEMrrk+dv07wP/T9Trqmd8fnjlWyodeXUy9dknaSPzxpLfoXSnelGJ3igdGnkDNH/xrU7w3xX1my76T4s+R33Z/cCw2lFeleHrsHWjEeUEt51keIcArSHg5bd1okyB+IXIPWUkmSAxZ1tUAkPQxafxvsfisJrZhAjnl8PnZ54pnpPh9iifNPldwPixn/lT5PPtkHxyfzxLM8/p+5CS14G5BGjfKn2ttkUB8NvLjFOpjlu3KUGhxUORj3JjiCdXyomzXlfAwl+wDkZOXrnMZUsqaYV2GWuvlz45cziQ0JAkF9UR9UU51HWCdesA6db6qDqbiHD4ceX5efd4HRv5d3orFGwlKgtcuJxni9/zlsbgfboBgOWWwq1q+zrVL0kYiYZhyxxY9RzTO3IlW0IjScO0N84ZINL4Yi89SKsnQVixeK0kd38brZRdH/izbdDkr5t+uC5KCn0T+9s2EctCYMEeLu/RaNC4kou0yGjiOXyNR+ET179Jj0yY1NRrFtgEr223Fcn2XuWZMvq+TDwxtBz7PnYSPbleMMFTWlA/lQY9ljW3oPerqiZlaD8XQeeCsWKzzUia3VTLEjQ/XRe4Rar0kxZWxWPbl9/myWPw9p8zqoW+wHV9kKEuSpNbUa5ckRf42SRc+jQs/48mRv42XYY07E3/U2wahLxmip4OGknlSRVfjQGNV7mojcXh7ta44NnIjfHXk4ZQTIicx9Tf0gkSlbfj6kiF6IdhPafRWJSeYmgyV8qEX4IhmXd92j4v5e+8oj7p3Z6yusi7KkE9bHkPbYEo9FF37HKrzvjJZVyn/s9sV0Z2wl8+3ZcOw95HNMoZYKcevR/f/n1OvXZI0w/OCGOJhiI2hCRr2MtR0Z6PHgAag1pcMcc7MX6HRLLoaBxKLkmDREHb1MtBjdkHMh7oYzmGYqwvn1/Zs9CVDnBvnWMp3TEM8NRlap2fo/JiXEY9gYCh1qq6yLkgMKI+2B21oG0yph6Jrn0N13lcm6yIZvybyOZC81YkbPz8ilodZu5IhzrHuqeK6b4ic5D62Wl6beu2SpG2qLxnqQuPAHArmrdAQHBr5OUptb1OXMseDhvjVzbpV+pKh1piGeEoyRLJ1ReSJtl0JTdmOeWQ0rvz7mBS/iP6EZKyuhhj7Rx7uYh7T4c26vm1qU+thap33leWeOD3y+ZZgGPS0yGXR6kuGaiRRn4m8rzNjea5UMfXaJUnb1NRkiAaEO5tIEPhmzb/HNg40YHyeScltL8uQOyoZouFjMvRW5OvjmPTu9fXsle0YemLSMNtwR9OqhGQMrpX5P1+LPFxJsIyyJxk6bP7R/xuTDGFKPUyt8zF1MBW9radGrp86Keqa2D4mGWLOFHVGOXYlVMXUa5ckbVNTk6G2saWRqhsHEoeuOSj0slwZ814Jvu2PNTUZGppAzT76kqGtmJcBDTC9BgyRnTBb1urajrkn3M5dymifyPOv+O8UpSE+OfJxSnAHY5+u+mlNrYeufQ7VeVeZ1PhcX3K5CnVySOS7Ia+KfP5tQrMqGeL6mTNFMnRstZw5Xsz1qk29dknSNrWnyVA9hwLnxfLdUyQCzO1hPtCYuRqtqckQwc9dxiZDKPNVros8cbbVt935MS8jPvPpmJ4AlGSoPdchXfVTW6ceuvY5VOd9ZVJw6/sZ7cIBlBvDU60y1NXePTeUDHH95REDF8TiwxrZjnl+tanXLknapvY0GarRA8JnDmiW86gBhnvK/lfdxdMamwxxXJ4XM5QMdd1V1NeA8zPLup41g77tamx3brtwhNsjGVqnHlbts63zVWVCr86Ua+K4JJddyuT2en9DydBRkde1zxRCm+Rg6rVLkrap2zIZemLk57vU+9k/8rN26t4H1g8936U1Nhnimz63WtPb8chmHWi0Lp39t9bXgJdkiGN3vValb7vaWbHcyI6xbjLU9pQU69bD1DofKhMSLs6B3qGxOC4T1Ns6A4km83nqRxeU32fOqX7O0NC17hM5SW7raeq1S5K2qdJ4dD1FuUaDwe3YXb0krHtU5HkcdcLCEMdFKS6J5fdHsQ/2xVDNqtu7SzLE8TnWEBp7kiEmHNdzOfiZZ+q0jxYAzytiAnRbBpwzyRPHPnu2jKSoJCh924Hj0ehStlMSGpSynpIMUdbcKt+1zbr1sE6dlzJp523xSpOPp/h79CcXXcrv54Wx2HvF8RnyIsGpk5G+J1CXXrD2SdZMID8z8hyiOuFd59olSdsIjePumL+Dq0S5K4p5JTX+Xb/3qb57ika03gffrpmkWia4lrg85vNmnhXL78viXOoeDfZBktG+b+qWmL+TrM9hkSfWMlH2dZHfYcXPp0WehFuUY7DPsn/eWUXZlHPlbqUbIw+t0FiSUDDc1LUd51XuKCvLh3oWurRlTfw6lh/4WJS65Pj1NtTLibF+PbTnMabO2zLhZ7apj/HXmD+0cAzK7oeR5/NQB8zReUXkJOiXkR8VAM65Pa9Sl7tiPmF8KEoSOfXaJUnaK/HtfVfMX8jLMNG6GG45OnJy0faejHVKzG+R74szYnFoZ5ONLQ+G3crk9boeSJLqxFaSJO3luCWehn0oSNhWDQNuCstDkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRJkiRpff8DeFSA7DnGxsgAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,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>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAkMAAABlCAYAAABOU+eZAAAGhUlEQVR4Xu3dWYhl1RUG4CXaEFHRVnFAieWI8xCNgdhIAiIKccABDUZ9EKNgFKM4tUMCKghC6CZJo2IiKig4gyhORM2L46MDKEIUJRCJD6IPCg5r9T4399apartaktTtU98HP33uPucWt98W+6y9dwQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8D+yaWbPzMmZ/brPm2T26q4BAAarip83MvdkzsrckXkh88fMqvFjAADDc1jmvcyxvfFfZb7OnNgbBwAYjM0y92f+FO2V2KRdM69HmzUCABikPTL/zKzs30g7Z+7ObNm/AQAwFIdnPs+8E61RetLmmYN7YwAAg7J15uXMN10+yqyOViT1X5sBAAzSoZm3Y1wQjXLp5EMAAENXs0SnZ56PVgy9mdl+1hMLU6vSrs4s698AAJgmO2S27Q9G6xV6KvN+tCbqDXVx5t5ofwcAYGpdl1nRH+zUKrLXMsv7NwAAhqCWyz+TOaZ/I22XeTVz1cTY/tF2oq79iC6JNuszk7kt2j5Fv8v8NfOj7pnbM1tEa8I+OvNIN3Zt5unMkQEAsIhG+wvdFbN7e+oMsmsyz0brISq1Q/WT0YqkUjtT/znaho0/z3yY+Vnmgcw+mR9nHo9WcB0Y7ZVbzTDVCrUXMwdEK5QAABZNHbFRMzp19litJLs5c17mlcxDmZ3Gj669V6/NRqqoeStaQVXXj8XsjRknx46P1pBd1/V8vXqrfwGAgavC4pOYvVS9ZmK+ynwZbbakXh8t1l4+u8d4dmbHzAnRTqufibm/6c6YWwy9G+2YjvUVQzWbVK/jLs/8IfPbmPv3AYCBqmLjuWhF0ORsSPXb3BStMDp1YnxanRLttddoddhx0QqcKnbWVwwdkrmou/7BxDMAwBJQB51WP00VRP0emSoY6hiM+e5Nm+opqj6iaoz+debhaLNCM931vzJrus+V+6LNil0fbdbppRjPjv0jc0aYHQKAJaFWan0dreemr2Zbqjh4IjaeGZMqikZN1Qt1Q7SG65F6PVeryfQNAcASUEvTqxjqL1+vVVjVvFyvyaqRecguiLYbda1SK3tnHo224SMAMGA121OzPv1+oXolVnvy/DuWxuui+v/9JHNj5veZ38R4iT4AMGC7ROuP+TTa3jovZD6INlNU/TcL6RP6ZbTvLDSvZ/Za+00AgEU2X79Q9dzUJocfR9t4EABgsKpfqBqka9PBSbWfT41f1hv/f5rc+2gaAgAMzLr6hUrNFFUBcFZvfD71d+rU+IWmlrFPHq0BALAo1rW/0KhIqmKoZojWZ7fMaRuQkzLbrv0mAMAiqh2a+/1CZZtoZ3+NiqFaYl9ng9UGhgAAG72zo+3GPNkPU2d41W7TpZaZX9mN35q5NFrBNPTl9QAA/1GFz0y0Q1FXxHgzwmlSv2nPaL+xZq3qc/3uWrY/jb8XAOC/poqfNzL3RGvyviPaHkn1Om/V+DEAgOE5LPNe5tjeeJ0tVj1QQz86BABYwkbnpdXJ9P0eplodV7tba/QGAAar9kOqfZFW9m9E28Po7syW/RsAAENRK94+z7wTc8832zxzcG8MAGBQts68HOMtAT7KrI5WJPVfmwEADNKhmbdj7tlhtR8SAMCSUbNEp2eej1YMvZnZftYTC1ezSheFfiMAYIrtEPOfaVa9Qk9l3o/WRP191OGxt4ViCACYYtdF2w17PrWK7LXM8u7zUZm7oi3DP7UbvyXa5oxXZPaN1mtUn3+R+Vvm4+475wUAwJSpGZtnMsf0b6TtMq9mruo+16aMT3bjlbo+MMZnrv0l88PM7dFmm0o1YD8WZoYAgCk12l+oZm6WTYzXGWTXZJ6N1kNU6lDZv2dO61LXJ3T36pknMo9nduvGimIIAJhqdcRGvfKqs8dqJVkVPPU665XMQ5mdxo/GndFem63LOdEKqwMmxiaLob2j7XQNADA1ds9s0V1Xs3PN9NRp9TMxd3+h46LNBo1miqq4Oai7PiJzfrRVaDVDNHpmshi6sPsXAGCjVK/OLs88mDk3c0O0HqE1mc+izSj9NPNF5qXM8dF6h6qJ+urMmQEAMADVWzSa+VmIKqK26g8CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPBdvgVK/R7nmjW12AAAAABJRU5ErkJggg==>

[image11]: <data:image/png;base64,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>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFUAAAAZCAYAAABAb2JNAAADvUlEQVR4Xu2YWahOURTHlwwRMk+lXB5IETKU4eESRYZMD0QpMuaWZAilm6FEySxSeJA8mDKGcotEShIlLzwoTyjx4AXrZ+3dt7/tO994ry7f+de/73xrn7XP3v+z1tp7H5EUKVKkSNGYWKX8qvwZ8JNysmvvqXwZtV9VzpA//d4rh5rbbwwT6yvsF1vVYKvYxDfHDQ7jlffFRA6xWMzvnLJF1Aa6KBuUCyV3+38NxEScRXGDQx/lWWWHyN5fLEIh1zGw3Vb2ihuqAV7UmXGDQ5KoRN8RMd8FURvAtjM2VgvKFRVMVf5Q3lC2DexcX1CODWxVhUpE7a58pfysHBLYub4ouX2qApWICurF/NcGNq7D/1WHQgvVSOUVSRaVFP+ufKzs5HhNOTi8qQBaKTcq58QNfwH1YuNP2v2UBS9qUqeFRG0ntsozMASGp8SEKhbU4DPKusheCkYrJ8bGIkEmJs2/LKyXwqIek/x7TVKdPg4pD0ju3UBTgzEklbBCaHRRffqyPcolXDH1cYDyg/KL8qEk701nK/crTyhXK1s7+zSx3cJesailFNwTO93ViI0Nn/bK3srtyj3Oh3vWKL8p7ygPOh8yaJu777TYIcaD565UXhdLfw43XtQeyl1iYyHjBjp7SSBNj4ut4GOiNv7nOk3FoI/zYtGa9HIQ5JZYZtB+WLksaKemEzGgo/KBZCKPtL4pVoKY/Fxnn6Cc4q7xDSOVY/Eb98tL5iUNEns2++ct7hqBL0tGVLaJ+OHDLga/bq6tJNAx0fFReVK5RCwKiLqazG15MUss4ploPjBYJs/xNkw5bF5UxGtwNhDWdUoL3x7wn65s6e6JRQW0sWBypGYhpR+e/0KyxxmnP3qMUi5XPhXbAZUNUq9WOV9sAH7AxYBInCSWdrnAQI868uaZRDmiMsYRyt3Kd2IfhoAXtatYZvUTi3YExYY//SDQc3ftEYqKmE/EMqCv2DgqErUpwSSYjB8gouyQzFYun6hkAWUIO9FDWgJWfMoN8KLynFoxkXx/fNy5q1zq2tit+OdSAsKsCQVmrXiknCfZX+GaDdi/8ulwn9gixS+nMa5BKCpYJ7abYPIsNCyCvIgNYgsIZYCdhq+piH1JzI8II+KeiUXyJrETHi8G0YeL1coVYgK+Vb4WWzCp10QqJZCFjpeBL5HfbNFZsr8TUDYoDbGogPuITtrbOBuLItFF9MXlyfflQTulJr4PhH3gx38P+qBkhLZ/BkyGiKkTW5F9fUxRIcaJ1VbqXRhlKVKkaBL8AjnixKHy+AiJAAAAAElFTkSuQmCC>