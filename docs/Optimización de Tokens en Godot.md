# **Optimización de Consumo de Tokens y Eficiencia Operativa en Google Antigravity para el Desarrollo con Godot 4**

## **Arquitectura de Contexto en Google Antigravity y Diagnóstico del Consumo**

Google Antigravity opera como una plataforma de desarrollo agéntico autónomo construida sobre un fork de Visual Studio Code, orientada a la ejecución delegada de tareas de ingeniería de software de principio a fin1. A diferencia de los entornos asistenciales tradicionales basados exclusivamente en autocompletado en línea, Antigravity despliega agentes y subagentes que investigan el espacio de trabajo, elaboran planes de ejecución, leen dependencias en el sistema de archivos y ejecutan comandos de terminal1. En este paradigma agéntico, el agotamiento prematuro de la ventana de contexto y el consumo desmedido de cuota de tokens no provienen de las consultas directas del usuario, sino de la acumulación progresiva de trazas intermedias, salidas de herramientas y la relectura descontrolada de archivos del repositorio en cada turno conversacional3.  
La preservación de la cuota asignada exige un diagnóstico empírico continuo del búfer de trabajo. Antigravity incorpora comandos de inspección en su consola interactiva y en su interfaz de línea de comandos (CLI) que permiten identificar con precisión los vectores de fuga de tokens6. El comando /context abre un panel de visualización en tiempo real que desglosa el uso del búfer activo, discriminando entre el peso del prompt de sistema, las instrucciones persistentes de las reglas, las definiciones de herramientas del Protocolo de Contexto de Modelo (MCP) y el historial de mensajes8.  
De forma complementaria, el comando /usage (accesible también mediante el alias /quota) detalla el volumen de peticiones y tokens restantes frente a las ventanas de refresco periódicas de cinco horas o semanales definidas por el plan de suscripción8. Para proyectos en los que se ha habilitado el consumo de créditos de cómputo por desbordamiento de cuota basal (*overages*), el comando /credits audita el balance y la velocidad de consumo de los créditos de Google AI11. Finalmente, la revisión de modificaciones intermedias mediante el comando /diff previene la necesidad de solicitar al agente resúmenes o reproducciones completas de código en el chat, permitiendo una inspección directa de los cambios en el árbol de trabajo8.

| Herramienta de Diagnóstico | Ámbito de Inspección | Parámetro de Consumo Evaluado |
| :---- | :---- | :---- |
| /context | Búfer activo en memoria de trabajo | Proporción de tokens asignada a reglas, herramientas MCP y mensajes acumulados8. |
| /usage / /quota | Cuota de modelo por ventana temporal | Consumo relativo frente al límite de refresco de 5 horas o semanal9. |
| /credits | Saldo de facturación auxiliar | Gasto marginal en créditos Google AI por desbordamiento de cuota base11. |
| /diff | Sistema de archivos local | Variación neta de líneas sin reinyección de código al historial conversacional8. |

## **Filtrado de Archivos y Aislamiento del Sistema de Archivos en Godot 4**

El motor Godot 4 estructura sus proyectos utilizando formatos basados íntegramente en texto plano, tales como escenas (.tscn), recursos textuales (.tres) y scripts en GDScript (.gd)15. Si bien esta arquitectura textual resulta ventajosa para los sistemas de control de versiones y los modelos de lenguaje, se convierte en un multiplicador crítico de tokens si el agente escanea de manera indiscriminada los archivos del proyecto15. Una sola escena tridimensional o un recurso con mallas de colisión, curvas de animación o arreglos de parámetros serializados puede contener decenas de miles de líneas que saturan el búfer de entrada en un solo paso de razonamiento16.  
El peligro más severo radica en el directorio interno .godot/, generado de forma automática en la raíz del proyecto para alojar la base de datos de importación, las cachés de sombreadores compilados, los mapas de identificadores únicos (UIDs) y los binarios optimizados del motor19. Asimismo, la presencia de activos multimedia no estructurados (texturas .png, modelos .glb, pistas .ogg o copias de respaldo de Blender \*.blend1) aporta ruido puro que ningún agente de código textual puede procesar ventajosamente21.  
Antigravity mitiga estas fugas mediante su sistema de aislamiento de espacio de trabajo y el cumplimiento estricto del archivo .gitignore6. Dentro de las opciones del proyecto en .gemini/config.json o mediante /config, la política Agent Non-Workspace File Access debe mantenerse en denegación estricta6. Adicionalmente, dentro del módulo de autocompletado inteligente (*Tab completions*), la opción Allow Gitignored Files debe permanecer desactivada para garantizar que el motor predictivo no procese archivos excluidos durante las sugerencias en segundo plano24.  
El archivo .gitignore de la raíz del proyecto debe estructurarse para bloquear tanto los artefactos internos de Godot como los recursos multimedia densos, restringiendo la visibilidad del agente a la lógica pura:

Fragmento de código  
\# Metadatos internos y caché del motor Godot 4  
.godot/  
.import/  
export.cfg  
export\_presets.cfg

\# Archivos de traducción y binarios generados  
\*.translation  
\*.tmp  
\*.res  
\*.scn

\# Activos gráficos, sonoros y modelos 3D masivos  
\*.png  
\*.jpg  
\*.jpeg  
\*.svg  
\*.webp  
\*.wav  
\*.ogg  
\*.mp3  
\*.blend  
\*.blend1  
\*.fbx  
\*.glb  
\*.gltf

\# Metadatos del sistema operativo  
.DS\_Store  
Thumbs.db

| Categoría de Archivo | Densidad de Tokens | Comportamiento del Motor y Riesgo Asociado | Directiva de Configuración |
| :---- | :---- | :---- | :---- |
| Carpeta interna .godot/ | Crítica (\>100k tokens potenciales) | Aloja metadatos volátiles y cachés de importación del editor20. | Exclusión obligatoria en .gitignore19. |
| Escenas complejas (.tscn) | Alta a Crítica | Contienen jerarquías completas, transformadas espaciales y nodos secundarios16. | Aislar; solicitar inspección solo de scripts o nodos puntuales16. |
| Recursos binarios (.res, .scn) | Crítica (Ruido puro) | Serialización binaria ilegible para el razonamiento de modelos textuales16. | Bloquear totalmente en .gitignore19. |
| Scripts GDScript (.gd) | Óptima (Alta densidad semántica) | Código fuente conciso de relevancia directa para la arquitectura del juego15. | Incluir de forma prioritaria en el contexto del agente15. |

## **Arquitectura Modular de Reglas y Activación Progresiva**

Un defecto frecuente en el despliegue de asistentes agénticos es la creación de archivos normativos masivos en la raíz del repositorio, tales como AGENTS.md o GEMINI.md25. Debido a que Antigravity clasifica estos archivos globales como documentos de activación continua (always\_on), la totalidad de su contenido textual se concatena al prompt de sistema en cada ciclo interactivo y en cada invocación de herramientas25. Esto provoca una rápida degradación del presupuesto global de 20.000 tokens que la plataforma reserva exclusivamente para reglas23.  
Cuando el conjunto de reglas acumuladas sobrepasa el umbral de los 20.000 tokens, o cuando un archivo de reglas individual excede el límite estricto de 24 KB (24.000 bytes), Antigravity degrada automáticamente los archivos más extensos a simples punteros sintéticos compuestos por su ruta y descripción, obligando al modelo a realizar lecturas secundarias para acceder a instrucciones que antes poseía en memoria23.  
Para mantener el consumo basal en niveles mínimos sin perder rigor prescriptivo, las pautas de Godot 4 deben fragmentarse en el directorio .agents/rules/ aprovechando los metadatos YAML (*frontmatter*) y sus modos de activación especializada25. El modo glob restringe la inyección de una regla exclusivamente a interacciones en las que el agente examina o altera archivos que coincidan con un patrón determinado, como \*.gd25.  
Por su parte, el activador model\_decision aplica el principio de divulgación progresiva (*progressive disclosure*): el agente solo recibe inicialmente en su prompt de sistema un índice ultraligero compuesto por la ruta y la descripción de la regla (\~30 tokens)25. Si la tarea encomendada requiere conocimientos específicos sobre dicha área, el agente carga el cuerpo íntegro del archivo bajo demanda25. El modo continuo always\_on debe reservarse únicamente para restricciones críticas de menos de 40 líneas25.  
Para regular la sintaxis en scripts de Godot 4 mediante activación por patrón de archivo, se utiliza una regla condicionada en .agents/rules/gdscript\_style.md25:

## **trigger: glob globs: "\*.gd" description: "Estándares de tipado estricto, nombrado y ciclo de vida de nodos en GDScript para Godot 4."**

# **Convenciones de GDScript para Godot 4**

> 1. Es obligatorio el tipado estricto en variables, parámetros y tipos de retorno:  
   * Declaración: var movement\_speed: float \= 200.0  
   * Firma: func take\_damage(amount: int) \-\> void:  
> 2. Prohibido el uso de cadenas de texto para invocar señales; usar Callables tipados:  
   * Correcto: body\_entered.connect(\_on\_body\_entered)  
> 3. Diferenciar con precisión \_physics\_process(delta) para física y \_process(delta) para renderizado o lógica desacoplada de cuadros fijos.

Para directivas complejas de sistemas de datos y desacoplamiento arquitectónico, se configura una regla basada en la decisión del modelo en .agents/rules/game\_architecture.md25:

## **trigger: model\_decision description: "Pautas de arquitectura desacoplada, máquinas de estados y recursos personalizados en Godot 4."**

# **Arquitectura de Sistemas en Godot 4**

> 1. Fomentar la composición por componentes sobre la herencia profunda de escenas.  
> 2. Centralizar datos mutables en objetos Resource personalizados tipados en lugar de diccionarios no estructurados.  
> 3. Restringir los Autoloads a servicios globales de infraestructura pura (EventBus, AudioManager, SaveSystem).

| Archivo de Regla | Modo (trigger) | Mecánica de Inyección en el Búfer | Impacto de Tokens |
| :---- | :---- | :---- | :---- |
| AGENTS.md (Base mínima) | always\_on | Se concatena íntegramente al prompt en cada turno del agente25. | Muy alto si es extenso; debe contener solo restricciones operativas mínimas25. |
| rules/gdscript\_style.md | glob: "\*.gd" | Se activa únicamente si la tarea lee o edita scripts .gd25. | Cero consumo en tareas ajenas a código GDScript25. |
| rules/game\_architecture.md | model\_decision | Inyecta solo ruta y descripción; carga el cuerpo completo bajo demanda25. | Mínimo en reposo (\~30 tokens); óptimo para guías conceptuales25. |
| rules/release\_checklist.md | manual | Se inyecta solo cuando el usuario referencia explícitamente el archivo con @25. | Nulo durante el desarrollo interactivo diario25. |

## **Protocolos Operativos e Ingeniería de Prompts de Alta Eficiencia**

En los sistemas de desarrollo agéntico autónomo, la formulación de prompts imprecisos actúa como un catalizador directo de desperdicio de cómputo2. Cuando un requerimiento es vago, el agente de Antigravity tiende a compensar la falta de especificación ejecutando exploraciones no dirigidas, activando herramientas redundantes y generando archivos auxiliares no solicitados2. Dado que cada acción de herramienta y cada respuesta del entorno se incorpora al historial conversacional, una tarea ambigua multiplica los tokens de entrada de manera exponencial a lo largo del tiempo3.  
El mantenimiento de la higiene contextual exige gobernar activamente el ciclo de vida de la conversación. Las sesiones prolongadas acumulan miles de tokens de conversaciones previas que el modelo relee en cada turno posterior3. La práctica recomendada dicta que, tras completar y verificar una unidad funcional en el editor de Godot, debe ejecutarse el comando /clear (o su alias /new), restableciendo el contexto a cero8. Si se precisa experimentar con una implementación técnica alternativa sin contaminar el hilo principal, el comando /fork clona la sesión en una rama independiente, protegiendo el historial limpio original8. Por otra parte, si el agente se desvía o produce una serie de iteraciones defectuosas, el comando /rewind (o /undo) permite retroceder a un punto de control anterior, eliminando los intercambios erróneos del historial para que no sigan facturándose en los turnos sucesivos8.  
Asimismo, la elección entre fases de planificación y ejecución directa debe calibrarse según la envergadura del cambio. Ante modificaciones arquitectónicas profundas, el comando /plan fuerza al agente a investigar el código existente y emitir un artefacto de especificación antes de realizar cambios físicos en los archivos, evitando refactorizaciones prematuras que agotan cuotas de escritura4. Por el contrario, para correcciones atómicas de errores, la activación del modo rápido mediante /fast suprime la generación de planes multi-agente complejos, ejecutando la modificación de manera inmediata8.  
Un principio determinante en la economía de tokens radica en restringir la regeneración masiva de código. Los tokens de salida poseen un coste computacional y de latencia considerablemente más alto que los tokens de entrada5. Exigir al agente la reimpresión íntegra de un script de varias decenas o cientos de líneas para incorporar una modificación menor en un método de salto o colisión agota la cuota innecesariamente5. Las instrucciones deben redactarse demandando modificaciones quirúrgicas, formateo en parches diferenciales (*unified diffs*) o la reescritura aislada de la función afectada, prohibiendo expresamente la duplicación de código preexistente y la prosa explicativa redundante.

## **Desacoplamiento de Código en Godot 4 para Reducir el Contexto Ingerido**

La estructura organizativa del código fuente en Godot 4 influye directamente en el volumen de contexto que Antigravity debe cargar para razonar sobre un cambio3. En proyectos construidos bajo un enfoque monolítico, donde un único script de varios cientos de líneas gestiona simultáneamente el movimiento cinemático, la detección de colisiones, la lógica de vida, las animaciones y la actualización de la interfaz de usuario, cualquier consulta sobre ese script obliga al modelo a ingerir el archivo en su totalidad3.  
La implementación del principio de responsabilidad única mediante composición modular de nodos mitiga esta sobrecarga. En lugar de centralizar toda la lógica en una escena masiva, la entidad debe fragmentarse en nodos funcionales especializados, tales como un controlador cinemático para la física, un componente de salud puro para el control numérico de vida, y áreas de interacción discretas para la detección de impactos17. Al segmentar el comportamiento del juego en componentes pequeños y autocontenidos, el desarrollador puede dirigir las instrucciones del agente hacia un archivo específico de 40 a 60 líneas mediante referencias directas como @scripts/components/health\_component.gd, evitando que la IA deba procesar el código de físicas o de reproducción visual17.  
De manera análoga, el uso extendido de patrones globales Singleton o Autoloads desmesurados representa un riesgo crítico de sobreexposición contextual. Cuando un script centralizado acumula variables de estado de juego, referencias cruzadas a nodos de interfaz y configuraciones globales, el agente de Antigravity tiende a inspeccionarlo de forma recurrente para inferir relaciones de datos, inyectando cientos de líneas irrelevantes en cada ciclo de planificación3.  
La sustitución de variables globales por recursos personalizados (Custom Resources) permite aislar la información en estructuras puras de datos16. La definición de clases que heredan de Resource (como perfiles de atributos o parámetros de armas) permite que las modificaciones se ejecuten sobre scripts de definición o archivos .tres ligeros, sin comprometer las jerarquías de la escena16. Asimismo, la canalización de eventos a través de un bus de eventos minimalista (EventBus.gd), limitado exclusivamente a declaraciones de señales tipadas sin lógica de negocio agregada, ofrece al agente un contrato de interfaz conciso que puede interpretarse con un consumo ínfimo de tokens.

## **Selección de Modelos Fundacionales y Estrategia Híbrida**

Google Antigravity permite alternar dinámicamente entre diversos modelos de razonamiento según la naturaleza de la tarea en curso4. Emplear modelos de frontera analítica exhaustiva para tareas rutinarias de sintaxis o conexión de señales en GDScript representa una utilización ineficiente de las cuotas de computación4.  
La familia de modelos Gemini Flash ha sido cooptimizada con el entorno de ejecución agéntico de Antigravity para ofrecer un procesamiento de baja latencia con un consumo balanceado de recursos2. Específicamente, Gemini 3.6 Flash introduce mejoras estructurales que reducen el gasto de tokens de salida hasta en un 17% respecto a Gemini 3.5 Flash, completando flujos de trabajo multi-paso con un menor número de llamadas de herramientas intermedias5. Por su parte, Gemini 3.7 Flash amplía las capacidades de razonamiento para desarrollo de software, exhibiendo un alto índice de precisión en el primer pase de generación de código (*first-pass code accuracy*), lo que suprime de raíz los costosos ciclos iterativos de corrección de errores sintácticos o de referencia29.  
El cambio del modelo activo puede gestionarse de forma instantánea mediante el comando /model o a través del menú de configuración global de la plataforma6. Mientras que las arquitecturas complejas de inventarios o la depuración de anomalías físicas sutiles pueden beneficiarse del modo de razonamiento profundo activado mediante /boost con modelos como Gemini 3.1 Pro o Claude4, el trabajo diario sobre GDScript alcanza su máxima eficiencia de costes operando sobre Gemini 3.6 Flash o Gemini 3.7 Flash5.  
Adicionalmente, el SDK de Antigravity admite la integración con modelos locales mediante LiteRT (por ejemplo, ejecuciones de Gemma 4 26B) y conectores compatibles con servidores locales de inferencia (Ollama, LM Studio o vLLM)32. Esto permite descargar tareas mecánicas repetitivas, como el formateo de scripts, linters de GDScript o utilidades de terminal, hacia inferencia ejecutada íntegramente en el hardware local, resultando en un coste nulo de cuota remota en la nube32.

| Modelo en Antigravity | Estructura de Consumo / Coste Relativo | Precisión en GDScript / Agentes | Ámbito Óptimo de Aplicación en Godot 4 |
| :---- | :---- | :---- | :---- |
| **Gemini 3.5 Flash** | Cuota basal alta; bajo coste por consulta31. | Adecuada; puede requerir turnos adicionales de ajuste2. | Consultas rápidas de API, funciones auxiliares básicas31. |
| **Gemini 3.6 Flash** | 17% menos tokens de salida; llamadas de herramientas optimizadas5. | Alta; minimiza ediciones redundantes de código5. | Implementación estándar de mecánicas, señales y nodos5. |
| **Gemini 3.7 Flash** | \$0.75 / 1M entrada, \$3.75 / 1M salida (tarifa promocional de lanzamiento)29. | Máxima en modelos Flash; drástica reducción de fallos de primer pase29. | Sistemas lógicos complejos, máquinas de estados y arquitectura de datos29. |
| **Gemini 3.1 Pro / Claude 4.5** | Alto consumo de cuota; restricciones severas de ventana temporal4. | Razonamiento superior para resolver casos límite complejos3. | Refactorizaciones estructurales profundas y depuración algorítmica vía /boost8. |
| **Gemma 4 26B (SDK Local / LiteRT)** | Inferencia local sin consumo de cuota remota ni tokens en nube32. | Adecuada para tareas acotadas de script y automatización32. | Tareas de consola, validación de sintaxis y generación de scripts auxiliares32. |

## **Conclusiones y Recomendaciones Técnicas**

La optimización del consumo de tokens en Google Antigravity para proyectos de Godot 4 exige articular una disciplina rigurosa entre la configuración del entorno, la arquitectura de reglas, la gestión de sesiones y el diseño del software. El análisis demuestra que la mayor causa de derroche no radica en el tamaño de las consultas del programador, sino en la ingestión pasiva de artefactos del motor, el sobredimensionamiento de las reglas de sistema continuas y la acumulación descontrolada del historial interactivo3.  
Para establecer un entorno de máxima eficiencia, es prioritario implementar de inmediato un archivo .gitignore estricto que bloquee de forma absoluta la carpeta .godot/, los directorios de importación, las exportaciones intermedias y la totalidad de los archivos multimedia binarios19. En las preferencias de Antigravity (/config), debe asegurarse que el acceso a archivos fuera del espacio de trabajo esté denegado y que las sugerencias basadas en archivos ignorados permanezcan desactivadas6.  
Paralelamente, las instrucciones del proyecto deben desmantelarse de los archivos monolíticos AGENTS.md o GEMINI.md para migrar hacia reglas modulares en .agents/rules/ gobernadas por disparadores condicionales25. Al reservar el activador glob para pautas de GDScript y el modo model\_decision para guías arquitectónicas, el sistema evita saturar el presupuesto de 20.000 tokens de reglas activas y preserva el contexto para el razonamiento técnico23.  
En el ámbito del flujo de trabajo, se debe mantener una higiene estricta de la conversación reiniciando el búfer con /clear al culminar cada componente, recurriendo a /fork para exploraciones aisladas y aplicando /rewind ante respuestas improductivas del agente8. En la formulación de prompts, es imperativo instruir al modelo para que responda con modificaciones quirúrgicas de métodos o formato de parche diferencial, impidiendo la regeneración innecesaria de scripts íntegros5.  
Estas prácticas deben respaldarse mediante una arquitectura de juego orientada a componentes desacoplados y recursos personalizados (Custom Resources), limitando la ingesta del agente a clases pequeñas y aisladas16.  
Por último, la selección del modelo de trabajo debe estandarizarse en Gemini 3.6 Flash o Gemini 3.7 Flash mediante /model, reservando los modelos de frontera de alta capacidad analítica exclusivamente para bucles de depuración crítica convocados bajo demanda a través de /boost5.

#### **Obras citadas**

> 1. Getting Started with Google Antigravity, [https://codelabs.developers.google.com/getting-started-google-antigravity](https://codelabs.developers.google.com/getting-started-google-antigravity)  
> 2. Antigravity IDE Google: qué es y cómo funciona \- Blog Donweb, [https://blog.donweb.com/google-antigravity-que-es-guia-completa-ide-ia/](https://blog.donweb.com/google-antigravity-que-es-guia-completa-ide-ia/)  
> 3. I replaced Claude Code with Google Antigravity for a week, and I, [https://www.xda-developers.com/replaced-claude-code-with-google-antigravity-did-not-expect-result/](https://www.xda-developers.com/replaced-claude-code-with-google-antigravity-did-not-expect-result/)  
> 4. Weightless Code: My 7-Day Experiment with Google Antigravity, [https://dev.to/naresh\_007/weightless-code-my-7-day-experiment-with-google-antigravity-9g5](https://dev.to/naresh_007/weightless-code-my-7-day-experiment-with-google-antigravity-9g5)  
> 5. Gemini 3.6 Flash in Google Antigravity, [https://antigravity.google/blog/gemini-3-6-flash-in-google-antigravity](https://antigravity.google/blog/gemini-3-6-flash-in-google-antigravity)  
> 6. Settings | Google Antigravity Docs, [https://antigravity.google/docs/settings/](https://antigravity.google/docs/settings/)  
> 7. Google Antigravity CLI, [https://antigravity.google/product/antigravity-cli/](https://antigravity.google/product/antigravity-cli/)  
> 8. CLI Reference | Google Antigravity Docs, [https://antigravity.google/docs/cli/reference/](https://antigravity.google/docs/cli/reference/)  
> 9. Model Quotas (/usage) | Google Antigravity Docs, [https://antigravity.google/docs/cli/commands/usage/](https://antigravity.google/docs/cli/commands/usage/)  
> 10. Models | Google Antigravity Docs, [https://antigravity.google/docs/models/](https://antigravity.google/docs/models/)  
> 11. Plans | Google Antigravity Docs, [https://antigravity.google/docs/plans/](https://antigravity.google/docs/plans/)  
> 12. AI Credits Command (/credits) | Google Antigravity Docs, [https://antigravity.google/docs/cli/commands/credits/](https://antigravity.google/docs/cli/commands/credits/)  
> 13. AI Credits | Google Antigravity Docs, [https://antigravity.google/docs/cli/credits/](https://antigravity.google/docs/cli/credits/)  
> 14. Antigravity CLI Features, [https://antigravity.google/docs/cli/features/](https://antigravity.google/docs/cli/features/)  
> 15. AI Coding Tools for Video Game Development \- Medium, [https://chierhu.medium.com/ai-coding-tools-for-video-game-development-a-first-principles-analysis-of-what-actually-works-90dfa10edd13](https://chierhu.medium.com/ai-coding-tools-for-video-game-development-a-first-principles-analysis-of-what-actually-works-90dfa10edd13)  
> 16. The Best Game Engine for AI Is the One It Can Read, [https://blog.ax0x.ai/best-game-engine-for-ai](https://blog.ax0x.ai/best-game-engine-for-ai)  
> 17. Creating the player scene \- Godot Docs, [https://docs.godotengine.org/en/stable/getting\_started/first\_2d\_game/02.player\_scene.html](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/02.player_scene.html)  
> 18. Node type customization using name suffixes \- Godot Docs, [https://docs.godotengine.org/en/stable/tutorials/assets\_pipeline/importing\_3d\_scenes/node\_type\_customization.html](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html)  
> 19. Godot.gitignore, [https://gitignore.org/Godot](https://gitignore.org/Godot)  
> 20. Godot.gitignore \- GitHub, [https://github.com/github/gitignore/blob/main/Godot.gitignore](https://github.com/github/gitignore/blob/main/Godot.gitignore)  
> 21. godot-demo-projects/.gitignore at master \- GitHub, [https://github.com/godotengine/godot-demo-projects/blob/master/.gitignore](https://github.com/godotengine/godot-demo-projects/blob/master/.gitignore)  
> 22. Looking for .gitignore settings for Win/Linux/MacOS mixed usage, [https://forum.godotengine.org/t/looking-for-gitignore-settings-for-win-linux-macos-mixed-usage/119535](https://forum.godotengine.org/t/looking-for-gitignore-settings-for-win-linux-macos-mixed-usage/119535)  
> 23. Changelog \- Google Antigravity, [https://antigravity.google/changelog](https://antigravity.google/changelog)  
> 24. Tab | Google Antigravity Docs, [https://antigravity.google/docs/ide/tab/](https://antigravity.google/docs/ide/tab/)  
> 25. Rules | Google Antigravity Docs, [https://antigravity.google/docs/rules/](https://antigravity.google/docs/rules/)  
> 26. Managing Conversations | Google Antigravity Docs, [https://antigravity.google/docs/cli/conversations/](https://antigravity.google/docs/cli/conversations/)  
> 27. Using AGY CLI | Google Antigravity Docs, [https://antigravity.google/docs/cli/using/](https://antigravity.google/docs/cli/using/)  
> 28. Slash commands overview | Google Antigravity Docs, [https://antigravity.google/docs/slash-commands/](https://antigravity.google/docs/slash-commands/)  
> 29. Gemini 3.7 Flash in Google Antigravity, [https://antigravity.google/blog/gemini-3-7-flash-in-google-antigravity](https://antigravity.google/blog/gemini-3-7-flash-in-google-antigravity)  
> 30. A Playdate with Agents \- Invisible Friends, [https://www.invisiblefriends.net/a-playdate-with-agents/](https://www.invisiblefriends.net/a-playdate-with-agents/)  
> 31. Gemini 3.5 Flash in Google Antigravity, [https://antigravity.google/blog/gemini-3-5-flash-in-google-antigravity](https://antigravity.google/blog/gemini-3-5-flash-in-google-antigravity)  
> 32. Introducing Support for Local AI Models in the Antigravity SDK, [https://developers.googleblog.com/introducing-support-for-local-ai-models-in-the-antigravity-sdk/](https://developers.googleblog.com/introducing-support-for-local-ai-models-in-the-antigravity-sdk/)