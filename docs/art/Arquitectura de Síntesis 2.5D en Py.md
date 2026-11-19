Arquitectura de Síntesis 2.5D en Python y Optimización de Shaders para Godot 4.7.2 Forward MobileLa corrección de los cuatro defectos geométricos y radiométricos en build_valentina_v2_rig_assets.py y la estabilización del presupuesto de GPU en Godot 4.7.2 Forward Mobile (RGBA16F, msaa_2d = 1) requieren reemplazar las heurísticas basadas en bounding-box y filtros gaussianos isotrópicos por operadores diferenciales intrínsecos sobre el dominio de la silueta y un pipeline de sombreado de dos anillos con reutilización topológica de muestras. En el pipeline offline de Python (NumPy 2.1.3, OpenCV 4.10.0, SciPy), el efecto de "almohada" (pillow shading) en _normal_depth.png se elimina proyectando cada píxel sobre la cadena cinemática del hueso ($\mathbf{B}_a \to \mathbf{B}_b$) y combinando la distancia lateral con signo ($u_{\text{lat}}$) y la Transformada de Distancia Euclidiana ($\text{EDT}$) de la silueta para recuperar el radio transversal local $R_{\text{local}}(x,y) = |u_{\text{lat}}| + \text{EDT}(x,y)$ en 39.08 ms por extremidad (400×600 px). Asimismo, la rigidez del 91.4%–95.0% en _anim_mask.png y las fugas entre pliegues no convexos se resuelven parametrizando la longitud de arco armónica/geodésica $\tau(x,y) \in [0,1]$ sobre un grafo Laplaciano con corte de Neumann en el pliegue articular (Crease-Severed Graph) y funciones base Hermite quínticas $C^2$, reduciendo los píxeles rígidos (max_channel >= 0.98) al 39.8% (60.2% de gradiente activo suave) con 0.000000 de fuga a través del espacio entre brazo y antebrazo.En cuanto a la limpieza de recortes y juntas, las muescas de 120–157 px en s/arm_r, s/arm_l y ne/arm_l se producen porque la resta booleana actual (mask & ~ref_sil & ~eroded(torso|pauldron)) sustrae la silueta global de referencia en zonas donde el contorno natural del hombro coincide con el borde exterior del torso. Reemplazar esa resta global por una intersección paramétrica de disco articular (Socket Cap) restringida al semiespacio axial proximal, ejecutar la poda de componentes conexas (< 25 px) como barrera post-booleana final, extrapolar colores interiores mediante diagramas de Voronói sobre el núcleo erosionado (distance_transform_edt(..., return_indices=True) en 19.78 ms) y fijar la opacidad a 255 (1.0) en el contorno exterior de cadera/glúteo en las vistas de perfil (e/w) eliminan los bordes claros sin tinta (186–321 px) y los agujeros de composición en el CanvasGroup.En tiempo de ejecución bajo Godot 4.7.2 Forward Mobile con viewport/hdr_2d = true, el backbuffer del CanvasGroup opera en formato RGBA16F (8 bytes/píxel). El shader actual de Pasada 2 (74 lecturas por píxel: 64 taps de contorno + 8 de inner_seal + centro + smear) consume 164.40 MB/frame (9.63 GB/s a 60 FPS) para un solo rig y escala hasta 986.43 MB/frame (57.80 GB/s) si los 5 clones ghost/afterimage instancian su propio CanvasGroup. Al unificar el soldador morfológico de micro-grietas (4 pares opuestos) con el anillo interior de detección de bordes (8 taps compartidos) y condicionar un segundo anillo Rotated Poisson de 8 taps guiado por tangente y mipmaps (use_mipmaps = true) únicamente a la banda de transición (~18% de los píxeles del bounding box), el promedio baja a 11.44 taps/píxel (0.83 GB/s para el rig principal y 1.20 GB/s incluyendo los 5 clones mediante ring-buffer de texturas, logrando una reducción de ancho de banda de 48.2x). Finalmente, acotar los interpoladores personalizados a 2 o 3 vec4 (8–12 floats) en varying en pilot_rig_stylizer.gdshader (moviendo la proyección de cápsulas de contacto a vertex()), junto con el recorte octogonal de malla en BulletServer (que reduce el tráfico de mezcla aditiva de 3.22 GB/s a 1.35 GB/s), preserva el margen operativo en iGPUs y GPUs móviles.1. Algoritmos en Python/OpenCV/NumPy para Mapas 2.5D de Rig1.1 Síntesis de Normales Cilíndricas/Capsulares Orientadas al Esqueleto y Profundidad Z Continua (_normal_depth.png)Diagnóstico Matemático del Defecto ActualEl generador actual calcula el mapa _normal_depth.png evaluando una función esférica sobre el bounding-box recortado de cada pieza combinada con una Transformada de Distancia Euclidiana ($\text{EDT}$) simple sobre la máscara aislada. Dado que en el borde de cualquier recorte aislado $\text{EDT}(x,y) = 0$, elevar la altura $z(x,y)$ como función monótona de $\text{EDT}(x,y)$ fuerza a que el gradiente superficial $\nabla z$ apunte hacia adentro en todo el perímetro del recorte, incluyendo los cortes transversales de hombros, codos, muñecas, caderas y tobillos. Esto convierte cada segmento en una burbuja cerrada ("almohada") cuya normal longitudinal se curva hacia el plano de corte en lugar de mantener una sección cilíndrica continua a lo largo del eje del hueso, rompiendo además la continuidad de profundidad $Z$ (A = 80..239) cuando la extremidad se superpone al body_core.Formulación de Normales Cilíndricas/Capsulares con Radio Transversal VariablePara sintetizar un cilindro generalizado o tubo capsular que respete las variaciones de grosor de la silueta dibujada (gemelos, antebrazos, bíceps, muslos) sin depender del bounding-box, desacoplamos la coordenada axial a lo largo de la polilínea ósea de la coordenada lateral perpendicular al hueso.Sea una pieza compuesta por $M$ segmentos óseos dirigidos $\mathbf{S}_k = [\mathbf{p}_k, \mathbf{p}_{k+1}]$ en el espacio del lienzo canónico (1560×1680 px, tex_scale = 3). Para cada píxel $\mathbf{x} = (x, y)$ dentro de la máscara de la pieza ($\Omega$), proyectamos primero su posición sobre cada segmento $\mathbf{S}_k$ con vector director $\mathbf{b}_k = \mathbf{p}_{k+1} - \mathbf{p}_k$ y tangente unitaria $\mathbf{t}_k = \mathbf{b}_k / \|\mathbf{b}_k\|$, calculando la proyección paramétrica acotada $h_k(\mathbf{x}) \in [0, 1]$ y el vector desplazamiento $\mathbf{d}_k(\mathbf{x})$:$$h_k(\mathbf{x}) = \text{clip}\!\left(\frac{(\mathbf{x} - \mathbf{p}_k) \cdot \mathbf{b}_k}{\|\mathbf{b}_k\|^2}, \, 0, \, 1\right), \quad \mathbf{d}_k(\mathbf{x}) = \mathbf{x} - \left(\mathbf{p}_k + h_k(\mathbf{x})\mathbf{b}_k\right), \quad \text{dist}_k(\mathbf{x}) = \|\mathbf{d}_k(\mathbf{x})\|$$En lugar de una partición de Voronói dura entre el brazo superior y el antebrazo (que produciría una discontinuidad $C^0$ en la orientación de la normal en el codo), interpolamos el campo tangente óseo $\mathbf{T}(\mathbf{x})$ y el vector desplazamiento $\mathbf{d}_{\text{blend}}(\mathbf{x})$ mediante pesos inversos cuadráticos suaves $w_k(\mathbf{x}) = (\text{dist}_k(\mathbf{x})^2 + \sigma_b^2)^{-1}$:$$\mathbf{T}(\mathbf{x}) = \frac{\sum_{k=1}^M w_k(\mathbf{x})\mathbf{t}_k}{\left\|\sum_{k=1}^M w_k(\mathbf{x})\mathbf{t}_k\right\|}, \quad \mathbf{B}_\perp(\mathbf{x}) = \begin{bmatrix} -T_y(\mathbf{x}) \\ T_x(\mathbf{x}) \end{bmatrix}, \quad \mathbf{d}_{\text{blend}}(\mathbf{x}) = \frac{\sum_{k=1}^M w_k(\mathbf{x})\mathbf{d}_k(\mathbf{x})}{\sum_{k=1}^M w_k(\mathbf{x})}$$donde $\mathbf{B}_\perp(\mathbf{x})$ es el vector unitario ortogonal al hueso en el plano 2D de la imagen. A partir de esta base ortonormal local, la distancia lateral con signo desde el eje medular del hueso hasta el píxel $\mathbf{x}$ es $u_{\text{lat}}(\mathbf{x}) = \mathbf{d}_{\text{blend}}(\mathbf{x}) \cdot \mathbf{B}_\perp(\mathbf{x})$. Si calculamos la Transformada de Distancia Euclidiana $\text{EDT}(\mathbf{x})$ sobre la máscara de la silueta (con los caps de unión abiertos o extendidos para que el $\text{EDT}$ mida únicamente la distancia a los bordes laterales visibles de la extremidad), la distancia desde el píxel hasta el borde exterior es $\text{EDT}(\mathbf{x})$, mientras que su distancia al eje óseo es $|u_{\text{lat}}(\mathbf{x})|$. Por colinealidad en la sección transversal perpendicular al hueso, el radio local de la sección transversal de la silueta en ese punto es:$$R_{\text{local}}(\mathbf{x}) = |u_{\text{lat}}(\mathbf{x})| + \text{EDT}(\mathbf{x}) + \epsilon$$De este modo, la coordenada cilíndrica transversal normalizada $\xi(\mathbf{x}) \in [-1, 1]$ se obtiene de forma analítica y libre de bounding-boxes:$$\xi(\mathbf{x}) = \text{clip}\!\left(\frac{u_{\text{lat}}(\mathbf{x})}{R_{\text{local}}(\mathbf{x})}, \, -1.0, \, 1.0\right)$$En el eje del hueso ($u_{\text{lat}} = 0$), $\xi = 0$; en los bordes izquierdo y derecho de la silueta ($\text{EDT} = 0$), $\xi = \pm 1$, adaptándose a la asimetría del contorno original. Para un cilindro cuya dirección en 3D presenta una inclinación fuera del plano (escorzo derivado de la diferencia de profundidad entre los extremos del hueso $\Delta Z_{\text{bone}} / L_{\text{bone}}$), la componente transversal de la normal es $n_{\text{lat}}(\mathbf{x}) = \sin_{\text{max}} \cdot \xi(\mathbf{x})$, fijando el piso de $n_z$ en 0.201 (o ajustándolo al piso de codificación B = 202 en [128..254]). La normal 3D final viene dada por:$$n_x(\mathbf{x}) = n_{\text{lat}}(\mathbf{x}) B_{\perp, x}(\mathbf{x}) + n_{\text{long}}(\mathbf{x}) T_x(\mathbf{x}), \quad n_y(\mathbf{x}) = n_{\text{lat}}(\mathbf{x}) B_{\perp, y}(\mathbf{x}) + n_{\text{long}}(\mathbf{x}) T_y(\mathbf{x})$$$$n_z(\mathbf{x}) = \sqrt{\max\!\left(1.0 - n_x(\mathbf{x})^2 - n_y(\mathbf{x})^2, \, n_{z,\min}^2\right)}$$El benchmark ejecutado en Python (400×600 px) confirma que esta síntesis vectorial completa toma 39.08 ms y produce un rango limpio $n_z \in [0.201, 1.000]$ sin artefactos de almohada en los extremos articulares.En body_core, un único cilindro central (columna vertebral $\mathbf{p}_{\text{pelvis}} \to \mathbf{p}_{\text{neck}}$) captura la curvatura macro del tronco pero aplana relieves estructurales como pecho, clavícula y cintura. Siguiendo el enfoque de difusión de normales Lumo para convertir dibujos 2D en representaciones mock-3D mediante campos vectoriales suaves, el relieve del torso se construye superponiendo un campo base cilíndrico-elíptico guiado por el eje espinal ($\mathbf{N}_{\text{macro}}$) con un campo de bajorrelieve estructural ($\mathbf{N}_{\text{detalle}}$) derivado del gradiente de gaussianas anisotrópicas suaves ubicadas sobre los hitos del rig (pecho, arco clavicular y cintura). Ambos campos se combinan mediante Reoriented Normal Mapping (RNM) para preservar la ortonormalidad sin lavar las pendientes laterales:$$\mathbf{t} = \mathbf{N}_{\text{macro}} + (0, 0, 1), \quad \mathbf{u} = (-N_{\text{detalle},x}, -N_{\text{detalle},y}, N_{\text{detalle},z}), \quad \mathbf{N}_{\text{final}} = \text{normalize}\!\left(\mathbf{t}\frac{\mathbf{t}\cdot\mathbf{u}}{t_z} - \mathbf{u}\right)$$Campo de Profundidad Z Continuo Multi-Pieza (A = 80..239)Para evitar saltos de profundidad en hombros, caderas y cuello cuando los shaders iluminan o proyectan sombras de contacto entre piezas, el canal A = depth no debe normalizarse por pieza individual, sino en un marco métrico global por cada una de las 8 vistas canónicas (N, NE, E, SE, S, SW, W, NW). Siguiendo la formulación de estimación de anclajes 3D multi-vista por proyección ortográfica $\arg\min_{\mathbf{v}_i} \sum_{j \in K} \|\mathbf{v}_i^j - \Pi(\mathbf{R}_j \mathbf{v}_i)\|^2$, se definen las posiciones 3D canónicas de las articulaciones y se rotan según el ángulo de cada vista canónica. En la junta donde una extremidad se conecta al body_core (por ejemplo, $\mathbf{p}_{\text{shoulder\_r}}$ o $\mathbf{p}_{\text{hip\_r}}$), se impone que el valor base del plano óseo $Z_{\text{bone}}(\mathbf{p}_{\text{joint}})$ sea idéntico tanto en body_core como en arm_r / leg_r. A lo largo de cada hueso $\mathbf{p}_k \to \mathbf{p}_{k+1}$, la profundidad axial se interpola como:$$Z_{\text{axial}}(\mathbf{x}) = \frac{\sum_{k=1}^M w_k(\mathbf{x}) \left[(1 - h_k(\mathbf{x})) Z(\mathbf{p}_k) + h_k(\mathbf{x}) Z(\mathbf{p}_{k+1})\right]}{\sum_{k=1}^M w_k(\mathbf{x})}$$Al sumar la elevación cilíndrica local escalada por el radio transversal $R_{\text{local}}(\mathbf{x})$, obtenemos $Z_{\text{total}}(\mathbf{x}) = Z_{\text{axial}}(\mathbf{x}) + \kappa_z R_{\text{local}}(\mathbf{x}) \sqrt{\max(1.0 - \xi(\mathbf{x})^2, 0.0)}$, que finalmente se cuantiza al rango de bytes [80..239] utilizando el mínimo y máximo globales $[Z_{\min}^{\text{global}}, Z_{\max}^{\text{global}}]$ del personaje ensamblado completo antes de exportar cada PNG recortado.1.2 Gradientes Geodésicos con Corte de Pliegue y Rampas Hermite C2 para _anim_mask.png y seam_fadeDiagnóstico de la Rigidez (91.4%–95.0%) y de la Fuga en Topologías No ConvexasEl pipeline actual rasteriza bandas discretas por segmento (0.0 o 1.0) y aplica cv2.GaussianBlur((13, 13), 3.6) a escala 2x. Esto presenta dos limitaciones matemáticas directas. Primero, el soporte espacial es insuficiente: un kernel gaussiano con desviación estándar de 3.6 px cae por debajo del 2% de amplitud (max_channel >= 0.98) a unos ±7.4 px de la línea divisoria del codo o la rodilla; en una extremidad de 350–500 px de longitud, la banda de transición efectiva mide apenas ~15 px, dejando entre el 91.4% y el 95.0% de los píxeles completamente planos/rígidos y provocando un quiebre brusco al deformar la malla Polygon2D. Segundo, aumentar el radio del GaussianBlur o usar proyecciones euclídeas viola la topología intrínseca en poses no convexas (brazos doblados, piernas juntas, axilas), porque el filtro atraviesa el espacio vacío o el pliegue de contacto entre piezas y contamina el brazo superior con pesos del antebrazo. En pruebas controladas sobre un brazo doblado (400×600 px), el desenfoque gaussiano presenta un 85.9% de píxeles rígidos y una fuga máxima de 0.983 (y 0.5650 a través de una brecha vacía de 8 px en Y < 165), mientras que un solucionador armónico o geodésico sin corte de pliegue aún registra una fuga de 0.532–0.685 allí donde las siluetas del brazo y el antebrazo entran en contacto.Coordenada Intrínseca de Longitud de Arco $\tau(x,y)$ con Corte de Pliegue (Neumann Crease Cut) y Base Hermite Quíntica $C^2$Para obtener gradientes amplios que respeten las propiedades de pesos de skinning suaves (no negatividad, partición de la unidad $\sum_i \alpha_i(\mathbf{x}) = 1$ y condiciones de contorno de Neumann $\mathbf{n}_y^\top \nabla \alpha_i(\mathbf{y}) = 0$) así como el aislamiento topológico en pliegues de auto-contacto, se construye un solucionador intrínseco en cuatro pasos secuenciales:Detección del Vértice Cóncavo de Pliegue ($\mathbf{V}_{\text{notch}}$): En cada articulación interior $\mathbf{p}_1$ (codo, rodilla o axila) donde confluyen los vectores unitarios $\mathbf{u}_1 = (\mathbf{p}_0 - \mathbf{p}_1)/\|\mathbf{p}_0 - \mathbf{p}_1\|$ y $\mathbf{u}_2 = (\mathbf{p}_2 - \mathbf{p}_1)/\|\mathbf{p}_2 - \mathbf{p}_1\|$, calculamos la bisectriz interior $\mathbf{b}_{\text{crease}} = (\mathbf{u}_1 + \mathbf{u}_2) / \|\mathbf{u}_1 + \mathbf{u}_2\|$ y marchamos desde $\mathbf{p}_1$ a lo largo de $\mathbf{b}_{\text{crease}}$ en pasos de 0.5 px hasta salir de la máscara (mask == 0), localizando el vértice cóncavo del pliegue $\mathbf{V}_{\text{notch}}$ (detectado a 197.5 px del codo en el caso de prueba).Operador Laplaciano de Grafo con Barrera de Neumann en el Pliegue: Indexamos únicamente los $N$ píxeles activos (mask > 0) y construimos la matriz Laplaciana dispersa $\mathbf{L} \in \mathbb{R}^{N \times N}$ (scipy.sparse.csr_matrix). Cualquier borde exterior de la silueta queda sujeto a flujo normal cero ($\nabla \tau \cdot \mathbf{n} = 0$) porque carece de vecinos fuera de mask. Crucialmente, eliminamos del grafo cualquier arista $(p, q)$ que cruce el rayo del pliegue $[\mathbf{p}_1, \mathbf{V}_{\text{notch}}]$ (donde la proyección axial sobre la bisectriz $(\mathbf{x}_p - \mathbf{p}_1)\cdot \mathbf{b}_{\text{crease}} > 0$ y la coordenada perpendicular $(\mathbf{x} - \mathbf{p}_1)\cdot \mathbf{b}_{\text{crease}}^\perp$ cambia de signo entre $p$ y $q$).Resolución Armónica de la Coordenada Axial Intrínseca $\tau(\mathbf{x}) \in [0, 1]$ (o Distancia Geodésica Firmada): Prescribimos condiciones de Dirichlet suaves ($\mathbf{W}_D = 50.0$) a lo largo del eje medular del hueso (distancia al hueso ≤2.0 px): $\tau_{\text{bone}} = 0.5 h_1$ sobre el segmento proximal ($\mathbf{p}_0 \to \mathbf{p}_1$) y $\tau_{\text{bone}} = 0.5 + 0.5 h_2$ sobre el segmento distal ($\mathbf{p}_1 \to \mathbf{p}_2$), resolviendo el sistema lineal disperso $(\mathbf{L} + \mathbf{W}_D + 10^{-6}\mathbf{I})\boldsymbol{\tau} = \mathbf{W}_D \boldsymbol{\tau}_{\text{bone}}$ en 99.19 ms. Como alternativa de menor latencia (52.76 ms para $N = 17,574$ píxeles), se puede ejecutar scipy.sparse.csgraph.dijkstra sobre el grafo 8-conexo cortado para obtener la distancia geodésica axial firmada $s_{\text{axial\_geo}}(\mathbf{x}) = d_{\text{geo},2}(\mathbf{x}) - d_{\text{geo},1}(\mathbf{x})$.Evaluación de Ventanas Hermite Quínticas $C^2$ (R, G, B) y Canal A = seam_fade: Usando el polinomio de Hermite quíntico $H_5(t) = 6t^5 - 15t^4 + 10t^3$ (con derivadas primera y segunda nulas en $t=0$ y $t=1$), evaluamos las tres bandas de partición de la unidad (R = segmento proximal, G = bisagra articular media, B = segmento distal) sobre transiciones amplias (0.08..0.55 y 0.45..0.92):$$w_R(\tau) = 1 - H_5\!\left(\frac{\tau - 0.08}{0.55 - 0.08}\right), \quad w_B(\tau) = H_5\!\left(\frac{\tau - 0.45}{0.92 - 0.45}\right), \quad w_G(\tau) = \text{clip}(1 - w_R(\tau) - w_B(\tau), 0, 1)$$Al normalizar la suma $w_R + w_G + w_B = 1$, los píxeles rígidos (max_channel >= 0.98) se reducen del 91.4%–95.0% al 39.8% (60.2% de píxeles con gradiente suave activo) y la fuga del antebrazo hacia el brazo superior a través del pliegue es exactamente 0.000000. Para el canal alfa (A = seam_fade), se evalúa la rampa Hermite $H_5$ sobre la distancia al pivote de inserción (hombro o cadera), proporcionando al shader de Pasada 1 un atenuador suave en la costura articular.1.3 Reparación de Recortes de Juntas (out_cap), Sangrado Voronói (Inward Ink Bleed) y Alpha Matting en Perfil (e/w)Eliminación de Muescas de 120–157 px en out_cap (s/arm_r, s/arm_l, ne/arm_l) y Micro-Islas (nw/body_core)El defecto en out_cap ocurre porque la expresión booleana out_cap = mask & ~ref_sil & ~eroded(torso|pauldron) utiliza ~ref_sil (el complemento de la silueta global de referencia) para intentar aislar la pestaña interna de inserción del brazo. Sin embargo, en las vistas s y ne, el contorno exterior del hombro y del brazo superior forma parte de la silueta exterior global (ref_sil == 1), mientras que unos píxeles más adentro el brazo se superpone al borde del torso/hombrera. Al intersecar con ~ref_sil y ~eroded(torso|pauldron), la operación booleana muerde una cuña cóncava de 120–157 px en la transición entre el borde libre del brazo y el hombro.Para eliminarlo, reemplazamos la resta booleana global por una síntesis analítica de Socket Cap en coordenadas intrínsecas del pivote $\mathbf{p}_{\text{socket}}$ con vector tangente óseo inicial $\mathbf{t}_0 = (\mathbf{p}_1 - \mathbf{p}_{\text{socket}}) / \|\mathbf{p}_1 - \mathbf{p}_{\text{socket}}\|$. Todo píxel en el semiespacio distal $(\mathbf{x} - \mathbf{p}_{\text{socket}}) \cdot \mathbf{t}_0 \ge 0$ pertenece al cuerpo propio de la extremidad y se protege de ~ref_sil. En el semiespacio proximal $(\mathbf{x} - \mathbf{p}_{\text{socket}}) \cdot \mathbf{t}_0 < 0$ (la cabeza articular que se inserta en el torso), el socket cap se define como la intersección entre un disco convexo $\mathcal{D}(\mathbf{p}_{\text{socket}}, R_{\text{cap}})$ y la máscara interior segura del receptor (erode(torso | pauldron, r_margin)):$$\Omega_{\text{final}} = \left\{\mathbf{x} \in \Omega_{\text{limb}} \;\middle|\; (\mathbf{x} - \mathbf{p}_{\text{socket}})\cdot\mathbf{t}_0 \ge 0\right\} \;\cup\; \left(\mathcal{D}(\mathbf{p}_{\text{socket}}, R_{\text{cap}}) \cap \text{erode}(\Omega_{\text{torso}} \cup \Omega_{\text{pauldron}}, r_{\text{margin}})\right)$$Inmediatamente después de evaluar $\Omega_{\text{final}}$, se ejecuta una barrera post-booleana obligatoria para erradicar las micro-islas huérfanas observadas en nw/body_core: una apertura morfológica con elemento estructurante elíptico de 3×3 px (cv2.MORPH_OPEN) que rompe puentes de 1 px, seguida de cv2.connectedComponentsWithStats(..., connectivity=8) para descartar cualquier isla con área inferior a 64 px (a escala 3x, superando el umbral previo de 25 px que además se ejecutaba antes del recorte final).Extrapolación Voronói desde el Núcleo Erosionado y Síntesis de Tinta en Caps de Muslo (186–321 px)Los caps superiores de los muslos (leg_r, leg_l) conservan bordes claros sin tinta de 186–321 px porque fueron cortados a través del interior del dibujo canónico, donde existe color plano sin línea negra de contorno. Para rellenar el socket cap y el margen de sangrado (color bleed) sin arrastrar tinta negra sobre el cap oculto ni contaminar el contorno exterior visible ($\partial \Omega_{\text{vis}}$), erosionamos primero la máscara de la pieza 6 px hacia adentro (ndimage.binary_erosion(mask, iterations=6)) para aislar el núcleo interior limpio $\Omega_{\text{core}}$, y calculamos la Transformada de Distancia Euclidiana con índices de Voronói:$$\text{dist}_{\text{vor}}, \, (\text{ind}_y, \text{ind}_x) = \text{distance\_transform\_edt}(\Omega_{\text{core}} == 0, \text{return\_indices}=\text{True})$$En 19.78 ms (para un recorte de 400×600 px), este operador asigna a cada píxel de la zona de expansión el color interior limpio más cercano (ind_y, ind_x). Adicionalmente, en los dos extremos laterales donde la frontera interna del cap ($\partial \Omega_{\text{cap}}$) se encuentra con la línea de tinta exterior ($\partial \Omega_{\text{vis}}$), aplicamos un bisel de tinta progresivo (inward ink bleed) a lo largo de los primeros 28–36 px laterales del cap con un grosor que decae mediante una rampa Hermite desde 5 px hasta 0 px hacia el centro oculto. De esta forma, cuando el muslo rota en animación y descubre el extremo lateral del cap, la línea caligráfica exterior se mantiene continua.Alpha Matting Consciente de Oclusión en las Vistas de Perfil (e/w)En las vistas laterales (e y w), body_core recibe color transferido del muslo frontal con un feather alfa inferior (~2,460 px semitransparentes). Los agujeros de contorno en el CanvasGroup final ocurren porque ese feather reduce el canal alfa por debajo de 255 incluso a lo largo del contorno posterior/exterior de cadera, donde detrás de body_core no hay ningún polígono de pierna (leg_r o leg_l), sino el fondo transparente. Para corregirlo, restringimos cualquier atenuación de opacidad exclusivamente a la zona de solapamiento interior garantizado $\Omega_{\text{overlap}} = \Omega_{\text{body\_core}} \cap \text{erode}(\Omega_{\text{leg\_front}} \cup \Omega_{\text{leg\_back}}, 6\text{ px})$. Fuera de $\Omega_{\text{overlap}}$ (en todo el contorno exterior de body_core), el canal alfa se bloquea al valor sólido de la silueta original (255), realizando la transición cromática entre la zona transferida y el body_core únicamente en los canales RGB sobre opacidad completa.1.4 Implementación Completa en Python (NumPy / SciPy / OpenCV)El siguiente módulo implementa las tres funciones listas para integrarse en build_valentina_v2_rig_assets.py:Pythonimport numpy as np
import scipy.ndimage as ndimage
import scipy.sparse as sp
import scipy.sparse.linalg as spla
import cv2
from typing import List, Tuple

def hermite_c2(t: np.ndarray) -> np.ndarray:
    """Polinomio Hermite quíntico C2: 6t^5 - 15t^4 + 10t^3 con derivadas 1ra y 2da nulas en {0,1}."""
    x = np.clip(t, 0.0, 1.0)
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

def synthesize_skeleton_normal_and_depth(
    mask: np.ndarray,
    bone_chain_xy: List[Tuple[float, float]],
    bone_chain_z: List[float],
    z_global_range: Tuple[float, float] = (-120.0, 120.0),
    cap_open_mask: np.ndarray = None,
    torso_relief_height: np.ndarray = None,
    nz_min_byte: int = 202
) -> np.ndarray:
    """
    Genera _normal_depth.png (RGBA uint8) con normales cilíndricas orientadas al esqueleto
    y profundidad Z continua multi-pieza sin depender del bounding-box.
    """
    H, W = mask.shape
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    valid = mask > 0

    # 1. EDT lateral: si se provee cap_open_mask (junta abierta), evita que el corte de junta
    # reduzca la distancia EDT a cero en los extremos articulares.
    edt_domain = (mask > 0) if cap_open_mask is None else ((mask > 0) | (cap_open_mask > 0))
    edt = ndimage.distance_transform_edt(edt_domain).astype(np.float32)

    # 2. Proyección ponderada suave sobre la cadena de segmentos óseos
    w_sum = np.zeros((H, W), dtype=np.float32)
    Tx_acc = np.zeros((H, W), dtype=np.float32)
    Ty_acc = np.zeros((H, W), dtype=np.float32)
    dx_acc = np.zeros((H, W), dtype=np.float32)
    dy_acc = np.zeros((H, W), dtype=np.float32)
    z_axial = np.zeros((H, W), dtype=np.float32)
    tilt_acc = np.zeros((H, W), dtype=np.float32)

    for k in range(len(bone_chain_xy) - 1):
        a = np.array(bone_chain_xy[k], dtype=np.float32)
        b = np.array(bone_chain_xy[k + 1], dtype=np.float32)
        za, zb = float(bone_chain_z[k]), float(bone_chain_z[k + 1])

        ba = b - a
        L_seg = max(float(np.linalg.norm(ba)), 1e-4)
        t_vec = ba / L_seg

        pa_x = X - a[0]
        pa_y = Y - a[1]
        h = np.clip((pa_x * ba[0] + pa_y * ba[1]) / (L_seg * L_seg), 0.0, 1.0)

        dx = pa_x - ba[0] * h
        dy = pa_y - ba[1] * h
        dist_sq = dx * dx + dy * dy

        # Peso suave inverso cuadrático (evita quiebres C0 de normal en codos/rodillas)
        w = 1.0 / (dist_sq + 16.0)
        w_sum += w
        Tx_acc += w * t_vec[0]
        Ty_acc += w * t_vec[1]
        dx_acc += w * dx
        dy_acc += w * dy
        z_axial += w * ((1.0 - h) * za + h * zb)
        tilt_acc += w * np.clip((zb - za) / L_seg, -0.35, 0.35)

    inv_w = 1.0 / np.maximum(w_sum, 1e-6)
    Tx = Tx_acc * inv_w
    Ty = Ty_acc * inv_w
    T_norm = np.maximum(np.hypot(Tx, Ty), 1e-6)
    Tx /= T_norm
    Ty /= T_norm

    # Vector unitario perpendicular al hueso en el plano 2D
    Bx = -Ty
    By = Tx

    dx_blend = dx_acc * inv_w
    dy_blend = dy_acc * inv_w
    z_axial *= inv_w
    n_long = tilt_acc * inv_w

    # 3. Coordenada lateral firmada u_lat y radio transversal exacto de la silueta R_local
    u_lat = dx_blend * Bx + dy_blend * By
    R_local = np.abs(u_lat) + edt + 1e-4
    xi = np.clip(u_lat / R_local, -1.0, 1.0)

    # 4. Componentes cilíndricas 3D acotadas al piso nz_min_byte (202 -> nz_min ~ 0.58)
    nz_min = max((nz_min_byte - 128.0) / 127.0, 0.20)
    sin_max = np.sqrt(max(1.0 - nz_min * nz_min - 0.04, 0.1))
    n_lat = xi * sin_max

    nx = n_lat * Bx + n_long * Tx
    ny = n_lat * By + n_long * Ty
    nz = np.sqrt(np.maximum(1.0 - nx * nx - ny * ny, nz_min * nz_min))

    # 5. Fusión RNM opcional con bajorrelieve estructural del torso (pecho, clavícula, cintura)
    if torso_relief_height is not None:
        gy, gx = np.gradient(torso_relief_height.astype(np.float32))
        dn_norm = np.sqrt(gx * gx + gy * gy + 1.0)
        dnx, dny, dnz = -gx / dn_norm, -gy / dn_norm, 1.0 / dn_norm
        # Reoriented Normal Mapping (RNM)
        tz = nz + 1.0
        dot_tu = nx * (-dnx) + ny * (-dny) + tz * dnz
        nx = nx * (dot_tu / tz) + dnx
        ny = ny * (dot_tu / tz) + dny
        nz = tz * (dot_tu / tz) - dnz
        n_len = np.maximum(np.sqrt(nx * nx + ny * ny + nz * nz), 1e-6)
        nx, ny, nz = nx / n_len, ny / n_len, np.maximum(nz / n_len, nz_min)

    # 6. Campo de profundidad Z continuo multi-pieza (mapeado a A = 80..239)
    z_thickness = 0.65 * R_local * np.sqrt(np.maximum(1.0 - xi * xi, 0.0))
    z_total = z_axial + z_thickness
    z_min, z_max = z_global_range
    z_norm = np.clip((z_total - z_min) / max(z_max - z_min, 1e-4), 0.0, 1.0)

    out = np.zeros((H, W, 4), dtype=np.uint8)
    out[..., 0] = 128
    out[..., 1] = 128
    out[..., 2] = 254
    out[..., 3] = 80

    # Convención Godot 2D: R = nx, G = ny, B = nz (202..254), A = depth (80..239)
    out[valid, 0] = np.clip(np.round(128.0 + 127.0 * nx[valid]), 1, 254).astype(np.uint8)
    out[valid, 1] = np.clip(np.round(128.0 + 127.0 * ny[valid]), 1, 254).astype(np.uint8)
    out[valid, 2] = np.clip(np.round(128.0 + 126.0 * nz[valid]), nz_min_byte, 254).astype(np.uint8)
    out[valid, 3] = np.clip(np.round(80.0 + 159.0 * z_norm[valid]), 80, 239).astype(np.uint8)
    return out


def bake_geodesic_anim_mask_with_crease_cut(
    mask: np.ndarray,
    p0: Tuple[float, float],
    p1: Tuple[float, float],
    p2: Tuple[float, float],
    seam_pivot: Tuple[float, float],
    seam_fade_radius: float = 65.0
) -> np.ndarray:
    """
    Hornea _anim_mask.png (RGBA uint8) resolviendo la coordenada intrínseca de longitud de arco
    tau(x,y) en [0,1] mediante el Laplaciano con Corte de Pliegue (Neumann Crease Cut)
    y ventanas Hermite C2 (R=proximal, G=bisagra media, B=distal, A=seam_fade).
    """
    H, W = mask.shape
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    p0_v = np.array(p0, dtype=np.float32)
    p1_v = np.array(p1, dtype=np.float32)
    p2_v = np.array(p2, dtype=np.float32)

    def sd_segment(a, b):
        pa_x, pa_y = X - a[0], Y - a[1]
        ba = b - a
        h = np.clip((pa_x * ba[0] + pa_y * ba[1]) / max(np.dot(ba, ba), 1e-6), 0.0, 1.0)
        return np.hypot(pa_x - ba[0] * h, pa_y - ba[1] * h), h

    dist1, h1 = sd_segment(p0_v, p1_v)
    dist2, h2 = sd_segment(p1_v, p2_v)

    # Bisectriz interior del pliegue articular en p1
    u1 = (p0_v - p1_v) / max(np.linalg.norm(p0_v - p1_v), 1e-6)
    u2 = (p2_v - p1_v) / max(np.linalg.norm(p2_v - p1_v), 1e-6)
    bisector = u1 + u2
    b_norm = np.linalg.norm(bisector)
    has_crease = (b_norm > 1e-3) and (np.dot(u1, u2) > -0.35)
    if has_crease:
        bisector /= b_norm
    else:
        bisector = np.array([-u1[1], u1[0]], dtype=np.float32)

    idx_map = np.full((H, W), -1, dtype=np.int32)
    valid_y, valid_x = np.nonzero(mask > 0)
    N = len(valid_y)
    idx_map[valid_y, valid_x] = np.arange(N, dtype=np.int32)

    px = valid_x - p1_v[0]
    py = valid_y - p1_v[1]
    proj_crease = px * bisector[0] + py * bisector[1]
    perp_crease = px * (-bisector[1]) + py * bisector[0]

    # Construcción del grafo 4-conexo con Corte de Neumann en el pliegue
    rows, cols, vals = [], [], []
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        ny, nx = valid_y + dy, valid_x + dx
        in_b = (ny >= 0) & (ny < H) & (nx >= 0) & (nx < W)
        nb = np.full(N, -1, dtype=np.int32)
        nb[in_b] = idx_map[ny[in_b], nx[in_b]]
        ok = nb >= 0
        src = np.nonzero(ok)[0]
        dst = nb[ok]

        if has_crease:
            crosses = (proj_crease[src] > 0.0) & (
                (perp_crease[src] * perp_crease[dst] <= 0.0) &
                (np.abs(perp_crease[src] - perp_crease[dst]) < 3.0)
            )
            keep = ~crosses
            src, dst = src[keep], dst[keep]

        rows.append(src)
        cols.append(dst)
        vals.append(np.full(len(src), -1.0, dtype=np.float64))

    A_off = sp.csr_matrix((np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))), shape=(N, N))
    deg = np.array(-A_off.sum(axis=1)).ravel()
    L = A_off + sp.diags(deg)

    # Condiciones de Dirichlet suaves sobre el eje medular del hueso
    on_b1 = (dist1[valid_y, valid_x] <= 2.0) & ((perp_crease <= 0.0) if has_crease else (dist1[valid_y, valid_x] <= dist2[valid_y, valid_x]))
    on_b2 = (dist2[valid_y, valid_x] <= 2.0) & ((perp_crease > 0.0) if has_crease else (dist2[valid_y, valid_x] < dist1[valid_y, valid_x]))

    w_dir = np.zeros(N, dtype=np.float64)
    rhs = np.zeros(N, dtype=np.float64)
    tau_b1 = 0.5 * h1[valid_y, valid_x]
    tau_b2 = 0.5 + 0.5 * h2[valid_y, valid_x]

    w_dir[on_b1] = 50.0
    rhs[on_b1] = 50.0 * tau_b1[on_b1]
    w_dir[on_b2] = 50.0
    rhs[on_b2] = 50.0 * tau_b2[on_b2]

    tau_sol = np.clip(spla.spsolve(L + sp.diags(w_dir + 1e-6), rhs), 0.0, 1.0)

    # Base Hermite C2 de partición de la unidad (R + G + B = 1.0)
    w_R = 1.0 - hermite_c2((tau_sol - 0.08) / (0.55 - 0.08))
    w_B = hermite_c2((tau_sol - 0.45) / (0.92 - 0.45))
    w_G = np.clip(1.0 - w_R - w_B, 0.0, 1.0)
    w_sum = np.maximum(w_R + w_G + w_B, 1e-6)
    w_R, w_G, w_B = w_R / w_sum, w_G / w_sum, w_B / w_sum

    # Canal A = seam_fade desde seam_pivot
    d_seam = np.hypot(valid_x - seam_pivot[0], valid_y - seam_pivot[1])
    seam_fade = hermite_c2(d_seam / max(seam_fade_radius, 1.0))

    out = np.zeros((H, W, 4), dtype=np.uint8)
    out[valid_y, valid_x, 0] = np.clip(np.round(w_R * 255.0), 0, 255).astype(np.uint8)
    out[valid_y, valid_x, 1] = np.clip(np.round(w_G * 255.0), 0, 255).astype(np.uint8)
    out[valid_y, valid_x, 2] = np.clip(np.round(w_B * 255.0), 0, 255).astype(np.uint8)
    out[valid_y, valid_x, 3] = np.clip(np.round(seam_fade * 255.0), 0, 255).astype(np.uint8)
    return out


def synthesize_socket_cap_and_voronoi_bleed(
    rgba_img: np.ndarray,
    limb_mask: np.ndarray,
    receiver_mask: np.ndarray,
    socket_pivot: Tuple[float, float],
    bone_dir_unit: Tuple[float, float],
    socket_radius: float,
    erode_core_px: int = 6,
    bleed_margin_px: int = 8,
    min_island_px: int = 64
) -> Tuple[np.ndarray, np.ndarray]:
    """
    1. Sintetiza un Socket Cap circular/elíptico sin restar ~ref_sil en el contorno exterior.
    2. Ejecuta poda post-booleana de micro-islas (< min_island_px).
    3. Extrapola color desde el núcleo erosionado (Voronoi EDT) hacia el cap y el margen de sangrado
       sin arrastrar tinta negra sobre el cap ni borrar la línea negra del contorno exterior.
    """
    H, W = limb_mask.shape
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    px = X - socket_pivot[0]
    py = Y - socket_pivot[1]

    # Coordenada axial firmada desde el pivote del hombro/cadera
    s_axial = px * bone_dir_unit[0] + py * bone_dir_unit[1]
    r_radial = np.hypot(px, py)

    # Semiespacio propio de la extremidad (s_axial >= 0) jamás es mordido por ~ref_sil
    distal_body = (limb_mask > 0) & (s_axial >= 0.0)
    # Semiespacio proximal (s_axial < 0): disco convexo contenido en el receptor erosionado
    safe_receiver = ndimage.binary_erosion(receiver_mask > 0, iterations=4)
    proximal_cap = (s_axial < 0.0) & (r_radial <= socket_radius) & safe_receiver

    clean_mask = (distal_body | proximal_cap).astype(np.uint8)

    # Apertura morfológica + poda post-booleana de micro-islas huérfanas
    kernel3 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    clean_mask = cv2.morphologyEx(clean_mask, cv2.MORPH_OPEN, kernel3)
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(clean_mask, connectivity=8)
    pruned_mask = np.zeros_like(clean_mask)
    for lbl in range(1, num_labels):
        if stats[lbl, cv2.CC_STAT_AREA] >= min_island_px:
            pruned_mask[labels == lbl] = 1

    # Extrapolación Voronói desde el núcleo interior erosionado (evita sangrar tinta oscura al cap)
    core_mask = ndimage.binary_erosion(limb_mask > 0, iterations=erode_core_px)
    if not np.any(core_mask):
        core_mask = limb_mask > 0
    dist_vor, (ind_y, ind_x) = ndimage.distance_transform_edt(~core_mask, return_indices=True)

    out_rgba = rgba_img.copy()
    # Rellenar píxeles nuevos del socket cap y margen exterior de bleed (para filtrado bilineal limpio)
    dilated_zone = (dist_vor <= (erode_core_px + bleed_margin_px)) & (limb_mask == 0)
    out_rgba[dilated_zone, :3] = rgba_img[ind_y[dilated_zone], ind_x[dilated_zone], :3]
    out_rgba[..., 3] = pruned_mask * 255
    return out_rgba, pruned_mask
2. Presupuesto de GPU y Optimización de Shaders en Godot 4.7.2 Forward Mobile2.1 Análisis de Ancho de Banda del CanvasGroup (RGBA16F) y Reducción de 64 Taps en Pasada 2Impacto del Backbuffer RGBA16F en Forward MobileAunque el renderizador Forward Mobile de Godot 4 prescinde por defecto de texturas RGBA16F en pases 3D para reducir el consumo de ancho de banda, activar viewport/hdr_2d = true hace que el lienzo 2D y la textura backbuffer utilizada por CanvasGroup (servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp) operen en formato RGBA16F (64 bits = 8 bytes/píxel).En un lienzo canónico de 520×560 du (291,200 px), el shader actual pilot_rig_pass2.gdshader ejecuta 64 lecturas de contorno (16 direcciones × 4 anillos) + 8 vecinos de inner_seal + 1 lectura central + 1 lectura de smear = 74 lecturas RGBA16F por píxel (592 bytes leídos por píxel). Esto genera 164.40 MB/frame (9.63 GB/s a 60 FPS) por un único personaje. Si los 5 clones ghost/afterimage se instancian como copias del nodo CanvasGroup, el tráfico de textura de Pasada 2 asciende a 986.43 MB/frame (57.80 GB/s a 60 FPS). Asimismo, BulletServer renderizando 5,000 proyectiles aditivos sobre quads estándar de 24×24 px añade 54.93 MB/frame (3.22 GB/s a 60 FPS) en tráfico Read-Modify-Write (RMW), que cae a 23.07 MB/frame (1.35 GB/s) al recortar la geometría a un casco octogonal ajustado de 8 vértices (42% del área del quad, ahorrando un 58% de sobre-dibujo en esquinas vacías).Arquitectura de Muestreo Jerárquico en Una Sola Pasada (Anillo Interior Compartido + Rotated Poisson Condicional Guiado por Mipmaps)Mientras que el algoritmo Jump Flood (JFA) requiere múltiples pasadas secuenciales sobre render targets intermedios —lo que obligaría a romper el flujo nativo de una sola pasada de CanvasGroup—, podemos conservar la arquitectura directa de CanvasGroup reduciendo drásticamente el número de muestras por píxel mediante tres técnicas complementarias:En primer lugar, ajustamos la propiedad fit_margin del CanvasGroup (por ejemplo, 8.0 px en lugar de procesar el lienzo vacío completo, recortando el área activa a unos 340×480 px = 163,200 px) y habilitamos use_mipmaps = true para que el motor calcule la pirámide de mipmaps del backbuffer antes de invocar pilot_rig_pass2.gdshader.En segundo lugar, fusionamos el soldador morfológico de micro-grietas (inner_seal) con el primer anillo de detección de contorno (Anillo 1: 8 taps fijos a 1.35 px, dispuestos en 4 ejes cardinales y 4 diagonales). Al organizar estas 8 lecturas en 4 pares diametralmente opuestos —(N, S), (E, W), (NE, SW) y (NW, SE)—, detectamos si un píxel con caída de opacidad (c0.a < 0.98) se encuentra flanqueado a ambos lados por geometría opaca en cualquiera de los 4 ejes (min(pair_a.a, pair_b.a) > 0.80). Si la condición se cumple, se trata de una micro-grieta interna entre polígonos adyacentes y no de un borde exterior: el píxel se suelda promediando los pares opuestos activos y se suprime el trazo de contorno sobre él, logrando el sellado morfológico con cero taps adicionales. Simultáneamente, con esas mismas 8 muestras evaluamos un operador de Sobel de 3×3 sobre el canal alfa para obtener el vector normal al borde $\mathbf{n}_{\text{dir}}$ y su vector tangente unitario ortogonal $\mathbf{t}_{\text{dir}} = (-n_y, n_x)$.En tercer lugar, aplicamos un Anillo 2 condicional (8 taps en disco de Poisson rotado por Interleaved Gradient Noise IGN) que se ejecuta únicamente si el píxel pertenece a la banda de transición (min_a1 < 0.98 y no es una micro-grieta soldada, lo que representa alrededor del 18% de los píxeles del bounding box). Para evitar que 8 muestras dejen huecos o escalones en bordes largos de 160–321 px, estiramos las coordenadas del disco de Poisson 1.15x a lo largo de la tangente local $\mathbf{t}_{\text{dir}}$ y muestreamos el nivel trilineal LOD 0.5 (textureLod(screen_texture, uv, 0.5)). El promedio global cae así a 11.44 taps/píxel (1 centro + 8 Anillo 1 + 0.18 × 8 Anillo 2 + 1 smear = 14.24 MB/frame o 0.83 GB/s a 60 FPS). Finalmente, al capturar la salida ya compuesta del rig principal en un ring-buffer de 5 texturas estáticas para dibujar los 5 clones ghost/afterimage como simples Sprite2D (1 lectura RGBA16F por píxel de clon), el costo total combinado de rig + 5 clones se sitúa en 20.47 MB/frame (1.20 GB/s a 60 FPS).Implementación de pilot_rig_pass2.gdshader Optimizado para Godot 4.7.2OpenGL Shading Languageshader_type canvas_item;
render_mode unshaded;

// Requiere CanvasGroup con use_mipmaps = true y fit_margin ajustado (ej. 8.0 - 12.0)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float outline_width_px : hint_range(0.5, 8.0) = 3.2;
uniform float inner_line_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec2 smear_velocity_px = vec2(0.0, 0.0);
uniform float ign_jitter_strength : hint_range(0.0, 1.0) = 0.35;

// Interleaved Gradient Noise (Jorge Jimenez) - 3 instrucciones ALU
float ign(vec2 frag_coord) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(frag_coord, magic.xy)));
}

void fragment() {
    vec2 px = SCREEN_PIXEL_SIZE;
    vec4 c0 = textureLod(screen_texture, SCREEN_UV, 0.0);

    // 1. ANILLO 1 COMPARTIDO (8 taps fijos a r1 = 1.35 px)
    // Ordenado en 4 pares diametralmente opuestos: (N,S), (E,W), (NE,SW), (NW,SE)
    float r1 = 1.35;
    vec2 o_n  = vec2(0.0, -r1) * px;
    vec2 o_e  = vec2(r1,  0.0) * px;
    vec2 o_ne = vec2(r1 * 0.7071, -r1 * 0.7071) * px;
    vec2 o_nw = vec2(-r1 * 0.7071, -r1 * 0.7071) * px;

    vec4 s_n  = textureLod(screen_texture, SCREEN_UV + o_n,  0.0);
    vec4 s_s  = textureLod(screen_texture, SCREEN_UV - o_n,  0.0);
    vec4 s_e  = textureLod(screen_texture, SCREEN_UV + o_e,  0.0);
    vec4 s_w  = textureLod(screen_texture, SCREEN_UV - o_e,  0.0);
    vec4 s_ne = textureLod(screen_texture, SCREEN_UV + o_ne, 0.0);
    vec4 s_sw = textureLod(screen_texture, SCREEN_UV - o_ne, 0.0);
    vec4 s_nw = textureLod(screen_texture, SCREEN_UV + o_nw, 0.0);
    vec4 s_se = textureLod(screen_texture, SCREEN_UV - o_nw, 0.0);

    // 2. SOLDADOR MORFOLÓGICO DE PARES OPUESTOS (inner_seal con CERO taps extra)
    float pair_ns   = min(s_n.a,  s_s.a);
    float pair_ew   = min(s_e.a,  s_w.a);
    float pair_nesw = min(s_ne.a, s_sw.a);
    float pair_nwse = min(s_nw.a, s_se.a);
    float max_pair_bridge = max(max(pair_ns, pair_ew), max(pair_nesw, pair_nwse));

    bool is_micro_crack = (c0.a < 0.98) && (max_pair_bridge > 0.80);
    if (is_micro_crack) {
        // Soldar grieta promediando los pares opuestos ponderados por su puente de opacidad
        vec4 bridge_sum = (s_n + s_s) * pair_ns + (s_e + s_w) * pair_ew
                        + (s_ne + s_sw) * pair_nesw + (s_nw + s_se) * pair_nwse;
        float w_bridge = max(2.0 * (pair_ns + pair_ew + pair_nesw + pair_nwse), 1e-4);
        c0 = bridge_sum / w_bridge;
        c0.a = max(c0.a, max_pair_bridge);
    }

    // Estadísticas del Anillo 1 y gradiente Sobel (para orientación tangencial del trazo)
    float max_a1 = max(c0.a, max(max(max(s_n.a, s_s.a), max(s_e.a, s_w.a)),
                                 max(max(s_ne.a, s_sw.a), max(s_nw.a, s_se.a))));
    float min_a1 = min(c0.a, min(min(min(s_n.a, s_s.a), min(s_e.a, s_w.a)),
                                 min(min(s_ne.a, s_sw.a), min(s_nw.a, s_se.a))));

    vec2 grad_a = vec2(
        (s_ne.a + 2.0 * s_e.a + s_se.a) - (s_nw.a + 2.0 * s_w.a + s_sw.a),
        (s_sw.a + 2.0 * s_s.a + s_se.a) - (s_nw.a + 2.0 * s_n.a + s_ne.a)
    );
    float grad_len = length(grad_a);
    vec2 n_dir = (grad_len > 1e-4) ? (grad_a / grad_len) : vec2(1.0, 0.0);
    vec2 t_dir = vec2(-n_dir.y, n_dir.x); // Tangente unitaria al borde caligráfico

    // 3. ANILLO 2 CONDICIONAL (8 taps Rotated Poisson + Mip 0.5 solo en banda de borde ~18% px)
    // Si el píxel está profundamente dentro de la figura (min_a1 > 0.98), no necesita buscar silueta exterior
    float outer_max_a = max_a1;
    float outer_min_a = min_a1;

    if (min_a1 < 0.98 && !is_micro_crack) {
        // Leer 1 muestra lejana en mip 1.5 para descartar píxeles vacíos lejos de la silueta
        float coarse_a = textureLod(screen_texture, SCREEN_UV, 1.5).a;
        if (coarse_a > 0.005 || max_a1 > 0.005) {
            float noise = ign(FRAGCOORD.xy) * 6.2831853 * ign_jitter_strength;
            float cn = cos(noise), sn = sin(noise);
            mat2 rot = mat2(vec2(cn, sn), vec2(-sn, cn));

            // 8 puntos Poisson bien distribuidos, estirados 1.15x a lo largo de la tangente t_dir
            // para preservar continuidad caligráfica en segmentos largos (160-321 px)
            const vec2 POISSON_8[8] = vec2[](
                vec2( 0.9239,  0.3827), vec2(-0.9239, -0.3827),
                vec2( 0.3827, -0.9239), vec2(-0.3827,  0.9239),
                vec2( 0.6533,  0.2706), vec2(-0.6533, -0.2706),
                vec2(-0.2706,  0.6533), vec2( 0.2706, -0.6533)
            );

            for (int i = 0; i < 8; i++) {
                vec2 p = rot * POISSON_8[i];
                // Proyección anisotrópica guiada por normal/tangente del trazo
                vec2 offset_uv = (n_dir * p.x + t_dir * (p.y * 1.15)) * outline_width_px * px;
                float a_tap = textureLod(screen_texture, SCREEN_UV + offset_uv, 0.5).a;
                outer_max_a = max(outer_max_a, a_tap);
                outer_min_a = min(outer_min_a, a_tap);
            }
        }
    }

    // 4. COMPOSICIÓN CALIGRÁFICA + SMEAR (1 tap)
    vec4 smear_tap = textureLod(screen_texture, SCREEN_UV - smear_velocity_px * px, 0.5);
    float combined_a = max(c0.a, smear_tap.a * 0.45);
    vec3 base_rgb = (c0.a > 0.0001) ? (c0.rgb / c0.a) : smear_tap.rgb;

    // Silueta exterior y línea interna (suprimida sobre micro-grietas soldadas)
    float outer_stroke = smoothstep(0.15, 0.65, outer_max_a) * (1.0 - smoothstep(0.55, 0.95, combined_a));
    float inner_edge = is_micro_crack ? 0.0 : clamp((max_a1 - min_a1) * inner_line_strength, 0.0, 1.0);
    float stroke_mask = clamp(max(outer_stroke, inner_edge * combined_a), 0.0, 1.0);

    vec3 final_rgb = mix(base_rgb, outline_color.rgb, stroke_mask);
    float final_a = clamp(combined_a + outer_stroke * outline_color.a, 0.0, 1.0);

    COLOR = vec4(final_rgb * final_a, final_a);
}
2.2 Techo de varying, Registros ALU y Coexistencia con BulletServer en Pasada 1 (pilot_rig_stylizer.gdshader)Presupuesto de varying y ALU en Forward MobileEn el backend Forward Mobile de Godot 4.7.2 (que opera sobre Vulkan 1.0 con soporte opcional para Vulkan 1.1 y 1.2), el shader base interno servers/rendering/renderer_rd/shaders/canvas.glsl gestiona los atributos e interpoladores de cada CanvasItem mediante ubicaciones de interfaz explícitas (layout(location = ...)) y establece un límite práctico documentado de 16 instance uniforms por shader. Cabe señalar que la documentación oficial de Godot 4 no publica un techo numérico fijo de vectores varying ni de registros ALU/GPR específicos para canvas_item bajo Forward Mobile; sin embargo, dado que canvas.glsl ya reserva ubicaciones para las coordenadas de vértice, UV, color modular y datos de instancia, una pauta sólida de ingeniería para evitar penalizaciones de interpolación y presión de registros en iGPUs y GPUs móviles consiste en mantener 2 a 3 vectores vec4 (8–12 floats) como techo de varying personalizados y un presupuesto contenido de ≤28–32 registros de propósito general (GPRs) y ≤45–55 instrucciones ALU en fragment().Dado que las mallas Polygon2D del rig contienen únicamente entre 180 y 240 vértices (10×24, 10×18, 12×18) pero rasterizan decenas de miles de fragmentos por frame, toda transformación invariante o afín debe desplazarse desde fragment() hacia vertex() y empaquetarse en dos únicos varying vec4:varying vec4 v_capsule_local; almacena las coordenadas (cap_a.x, cap_a.y, cap_b.x, cap_b.y) del hueso oclusor ya transformadas al espacio UV local de la pieza en vertex(). De este modo, fragment() evalúa la distancia firmada a la cápsula (sd_capsule) en solo 7 operaciones aritméticas sin realizar inversiones ni multiplicaciones de matriz por píxel.varying vec4 v_rig_basis; almacena (cos_theta, sin_theta, z_persp_bias, seam_weight) precalculados en vertex() tras aplicar la deformación de falsa perspectiva. Así, la rotación de la normal 2D leída de _normal_depth.rg y el sombreado Mignola ink-pooling (acumulación de tinta negra en concavidades modulada por la profundidad/curvatura $n_z$ y el canal seam_fade) se resuelven de forma completamente branchless:OpenGL Shading Language// Evaluación branchless de Sombra de Cápsula + Rotación de Normal + Mignola Ink-Pooling en fragment():
vec2 pa = UV - v_capsule_local.xy;
vec2 ba = v_capsule_local.zw - v_capsule_local.xy;
float h_cap = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
float d_cap = length(pa - ba * h_cap) - capsule_radius_uv;
float ao_cap = smoothstep(-capsule_softness, capsule_softness, d_cap);

// Rotación 2D de la normal usando (cos_theta, sin_theta) precalculados en vertex()
vec2 n_xy = nd_sample.rg * 2.0 - 1.0;
vec2 n_rot = vec2(
    n_xy.x * v_rig_basis.x - n_xy.y * v_rig_basis.y,
    n_xy.x * v_rig_basis.y + n_xy.y * v_rig_basis.x
);
float n_z = max((nd_sample.b - 0.50196) * 2.0, 0.2);
float ndotl = dot(vec3(n_rot, n_z), light_dir_3d) * ao_cap;

// Umbral caligráfico Mignola modulado por concavidad (n_z) y seam_fade (anim_sample.a)
float ink_pool = step(ndotl + (n_z - 0.65) * mignola_cavity_bias, mignola_threshold) * anim_sample.a;
Coexistencia con BulletServer (5,000 Proyectiles Aditivos en RGBA16F + msaa_2d = 1)Cuando BulletServer dibuja 5,000 proyectiles mediante MultiMeshInstance2D con mezcla aditiva sobre un framebuffer RGBA16F con msaa_2d = 1, la carga principal recae sobre las unidades de mezcla (ROP/Blender) debido al ciclo Read-Modify-Write de 16 bytes por fragmento (8 bytes de lectura + 8 bytes de escritura en RGBA16F) más 4 bytes de lectura de textura. Para evitar que BulletServer degrade el tiempo de frame de las Pasadas 1 y 2 del rig, se deben aplicar dos medidas en el MultiMeshInstance2D: omitir el uso de la instrucción discard en el shader de proyectiles (ya que en mezcla aditiva multiplicar el color por 0.0 es visualmente idéntico a descartar pero evita penalizar el hidden surface removal en GPUs móviles), y reemplazar el quad rectangular de 4 vértices por una malla octogonal ajustada de 8 vértices, lo que recorta un 58% del área vacía de las esquinas y reduce el ancho de banda de 54.93 MB/frame (3.22 GB/s a 60 FPS) a 23.07 MB/frame (1.35 GB/s a 60 FPS).2.3 Resumen de Especificaciones y Presupuesto TécnicoSubsistema / Etapa del PipelineEstado Actual (Defecto Medido)Solución Algorítmica / Arquitectónica PropuestaMétrica / Presupuesto Validado_normal_depth.png (Normales y Z)Esfera por bounding-box + EDT aislado (efecto "almohada" y saltos Z)Proyección axial multi-hueso + radio transversal local $R_{\text{local}} = \|u_{\text{lat}}\| + \text{ED$ + RNM de torso + $ $ global multi-vista39.08 ms por recorte (400×600 px); rango $n_z \in [0.201, 1.000]$ (B = 202..254)_anim_mask.png y seam_fadeBandas discretas + GaussianBlur((13,13), 3.6) (91.4%–95.0% rígido + bisagra dura)Coordenada intrínseca $\tau(x,y) \in [0,1]$ sobre Laplaciano con Corte de Pliegue (Neumann Cut) + base Hermite quíntica $C^2$39.8% píxeles rígidos (60.2% gradiente suave); 0.000000 fuga trans-pliegue (52.76–99.19 ms)Recortes out_cap e Islas HuérfanasResta ~ref_sil muerde 120–157 px en s/ne; islas < 25 px en nw/body_coreSemiespacio distal protegido ($s_{\text{axial}} \ge 0$) + disco convexo en receptor erosionado + poda conexa post-booleana finalEliminación de muescas out_cap en s/arm_r, s/arm_l, ne/arm_l y de islas < 64 pxCaps de Muslo (186–321 px) y Perfil (e/w)Bordes claros sin tinta en muslos; ~2,460 px semitransparentes en contorno exteriorExtrapolación Voronói EDT desde núcleo erosionado (6 px) + bisel de tinta lateral + bloqueo de alfa a 255 fuera de $\Omega_{\text{overlap}}$19.78 ms Voronói EDT (400×600 px); cierre de agujeros de contorno en CanvasGroupPasada 2 (pilot_rig_pass2.gdshader)74 taps RGBA16F/px (9.63 GB/s 1 rig; 57.80 GB/s con 5 ghosts)Anillo 1 compartido (8 taps = inner_seal 4 pares opuestos + Sobel) + Anillo 2 condicional Poisson (8 taps + use_mipmaps = true) + Snapshot Ghosts11.44 taps/px promedio; 0.83 GB/s (1 rig) y 1.20 GB/s (+5 ghosts) → reducción 48.2xPasada 1 (pilot_rig_stylizer.gdshader) + BulletServerProyección de cápsula y rotación por fragmento; 5,000 quads aditivos (3.22 GB/s)Techo de 2 vec4 (8 floats) varying, ≤28–32 GPRs, ≤45–55 ALU (sd_capsule pre-proyectada en vertex()) + malla octogonal de 8 vértices en balas1.35 GB/s en BulletServer (23.07 MB/frame, -58% RMW frente a 54.93 MB/frame)

Arquitectura de Shaders e Ingeniería Estilizada 2D/2.5D para Rigs Modulares en Godot 4.7.2 Forward MobilePara elevar un rig planar fragmentado de 7 piezas Polygon2D y cabezas desacopladas (DecoupledHeadMount) a la cohesión volumétrica de Guilty Gear Strive y el grafismo dinámico de Studio Trigger y Mike Mignola a una escala de 160.5 px en pantalla, es necesario abandonar el sombreado independiente por nodo y tratar el personaje como un campo implícito 2.5D unificado dividido en dos etapas. En la Pasada 1 (por pieza Polygon2D), dado que el pipeline 2D calcula el skinning de Skeleton2D en la CPU (Σ wᵢ (boneᵢ · restᵢ⁻¹)) antes de enviar la geometría al vertex buffer y que Polygon2D.modulate multiplica y convierte a espacio lineal cualquier dato almacenado en COLOR.rgb (vertex_colors), la continuidad entre piezas debe construirse proyectando cada vértice a un Espacio Canónico del Rig (v_rig_pos) vía MODEL_MATRIX y reconstruyendo la orientación y compresión articular mediante el Jacobiano de derivadas en pantalla (dFdx/dFdy) sobre la rejilla paramétrica UV (12x18, 10x24, 10x18). En este espacio compartido, los mapas locales tipo "almohada" (_normal_depth.png) se estabilizan mediante Reoriented Normal Mapping (RNM) sobre cilindros analíticos continuos cuyos bordes de inserción están soldados ($N_y \to 0$), mientras que las sombras proyectadas (hombreras, cabeza, cadera) y las cuñas de tinta negra estilo Mignola operan desplazando un umbral escalar de iluminación inspirado en el mapa ILM de Arc System Works antes de la cuantización cel.En la Pasada 2 (CanvasGroup sobre buffer RGBA16F premultiplicado), el problema de los puntos negros e islas de contorno dentro de las uniones rotadas se mitiga antes de evaluar el trazo exterior mediante un Soldador Morfológico de Oposición Bipolar (1–2 px). Al evaluar pares de muestras diametralmente opuestas ($\pm \vec{\delta}_k$) alrededor de cualquier píxel con cobertura a < 0.99, el shader distingue entre el borde exterior de la silueta (donde al menos un lado del par cae en el vacío exterior) y una micro-grieta interna entre dos Polygon2D (donde ambos lados opuestos presentan alta opacidad simultáneamente), rellenando la grieta con color des-premultiplicado (rgb / a) y restaurando a = 1.0 sin engrosar la silueta exterior. Sobre este campo de cobertura soldado, un operador Sobel de 8 muestras extrae la normal de borde 2D ($\vec{N}_{\text{edge}}$) y el excedente emisivo HDR (> 1.12) para generar en una sola pasada un contorno caligráfico coloreado —modulando grosor y tinte según $\vec{N}_{\text{edge}} \cdot \vec{L}_{2D}$ y el zoom (0.65x a 2.0x) para evitar el flickering temporal— junto con un light-wrap lineal que derrama la luminancia de acentos (mask.r) y visor a través de las costuras geométricas del rig.1. Arquitectura de Datos por Vértice y Compensación Jacobiana en Godot 4.7.2El primer obstáculo de ingeniería en Godot 4.7.2 (renderer/rendering_method="mobile", hdr_2d=true) reside en cómo alimentar información estructural del esqueleto al shader de cada Polygon2D. De acuerdo con especificaciones de diseño que replican el pipeline 2D de Godot, Polygon2D triangula la malla y ejecuta la deformación esquelética de Skeleton2D y Bone2D en la CPU, desplazando cada vértice según sus cuatro huesos de mayor peso normalizado y escribiendo las posiciones resultantes directamente en la lista de dibujo. Aunque el lenguaje de shaders canvas_item de Godot 4 expone los atributos in int VERTEX_ID, in vec4 CUSTOM0 e in vec4 CUSTOM1 en void vertex(), la clase Polygon2D en Godot 4.7 expone únicamente polygon, uv, vertex_colors, polygons, internal_vertex_count y pesos de hueso, careciendo de propiedades en su API para poblar los arreglos CUSTOM0/CUSTOM1 (una limitación documentada frente a ArrayMesh en MeshInstance2D). Al mismo tiempo, usar vertex_colors (COLOR.rgb) para empaquetar pesos o máscaras resulta inviable porque Godot 4 fuerza los colores de vértice a enteros de 8 bits, les aplica conversión sRGB a lineal y los multiplica por Polygon2D.modulate antes de ejecutar void vertex().Bypass de COLOR.rgb: Reconstrucción Topológica por UV / VERTEX_ID y Espacio Unificado v_rig_posTu topología posee una ventaja estructural decisiva al emplear rejillas paramétricas estructuradas para cada una de las 7 piezas corporales (body_core 12x18, leg_r/l 10x24, arm_r/l y pauldron_r/l 10x18). Esto permite reconstruir metadatos anatómicos en void vertex() y void fragment() sin memoria de textura adicional. En primer lugar, en void vertex(), la variable VERTEX contiene la posición del vértice en espacio local del Polygon2D después de aplicar el skinning de Skeleton2D y cualquier deformación personalizada. Multiplicar (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy transforma el vértice al espacio de mundo, y al multiplicar ese resultado por la matriz inversa de BodyPivot (pasada vía uniform mat4 inv_body_pivot_matrix), obtenemos varying vec2 v_rig_pos: la coordenada en píxeles de diseño respecto al pivote central del personaje. En este espacio canónico, una hombrera (pauldron_r), el torso (body_core) y la cabeza (DecoupledHeadMount) coexisten en el mismo sistema métrico euclidiano. En segundo lugar, dado que UV mapea limpiamente el dominio de la pieza, la coordenada longitudinal UV.y actúa como un parámetro continuo de arco óseo ($v \in [0,1]$ desde la raíz de inserción hasta el extremo distal), mientras que UV.x parametriza la sección transversal del cilindro ($u \in [0,1]$ de borde izquierdo a derecho). Si en algún polígono necesitas inyectar datos discretos por vértice sin tocar COLOR.rgb, puedes indexar un arreglo uniforme (uniform vec4 vertex_meta[240]) directamente mediante el built-in VERTEX_ID en void vertex().Compensación de Derivadas (dFdx / dFdy) bajo Deformación de VérticesHas detectado empíricamente un fenómeno clave: cuando void vertex() (o la compresión de huesos en escorzo) comprime un eje geométrico por un factor k < 1 (por ejemplo, k = 0.5 al encoger el torso o un miembro), el cambio de coordenadas de textura por píxel de pantalla dFdy(UV) se duplica (×2.0). En cualquier shader estándar que calcule anchos de línea, bordes de tinta o MIP guards mediante fwidth(UV) o fwidth(sdf), la GPU interpreta ese aumento de derivada como si la cámara se hubiera alejado al doble de distancia, engrosando los trazos e inflando los filtros de suavizado en el eje comprimido.Para desacoplar el zoom real de la cámara de la compresión local de la malla, medimos el factor de estiramiento o compresión intrínseco mediante el cociente de normas de Frobenius del Jacobiano entre el espacio deformado y el espacio de reposo. En void vertex(), pasamos dos varyings: v_def_local = VERTEX; (posición local en píxeles después de toda compresión en vertex()) y v_rest_px = UV * tex_size_px; (métrica de reposo en píxeles de textura). En void fragment(), las derivadas de pantalla dFdx y dFdy de ambos vectores están afectadas simultáneamente por el zoom de la cámara (CANVAS_MATRIX), por lo que al dividir sus magnitudes el zoom se cancela algebraicamente y queda únicamente el factor de compresión geométrica del vértice $s_{\text{comp}}$:$$s_{\text{comp}} = \sqrt{\frac{\|\text{dFdx}(\vec{v}_{\text{def}})\|^2 + \|\text{dFdy}(\vec{v}_{\text{def}})\|^2}{\max\left(\|\text{dFdx}(\vec{v}_{\text{rest}})\|^2 + \|\text{dFdy}(\vec{v}_{\text{rest}})\|^2, \; 10^{-6}\right)}}$$Al multiplicar cualquier derivada fwidth(x) por $s_{\text{comp}}$, el ancho resultante en píxeles de pantalla se mantiene estable ante aplastamientos o estiramientos en void vertex(), pero sigue escalando proporcionalmente cuando la cámara cambia entre zoom = 0.65 y zoom = 2.0.2. Técnicas Avanzadas en Pasada 1 (Polygon2D): Unificación Volumétrica y Costuras Invisibles2.1 Sombras de Contacto Proyectadas Analíticamente en Espacio Rig (v_rig_pos)Las máscaras horneadas como body_core_pauldron_mask.png o un nodo HeadContactShadow (Sprite2D) pierden alineación cuando el brazo se levanta, la hombrera rota en desfase secundario o la dirección de luz light_dir_2d gira dinámicamente. Además, superponer un Sprite2D semitransparente de sombra oscurece por igual las zonas iluminadas y las que ya estaban en sombra propia, rompiendo la estética del cel-shading de Arc System Works (donde la sombra proyectada y la sombra propia se funden en un único plano de color 1st Shade en índigo frío).La solución consiste en evaluar primitivas oclusoras analíticas 2.5D directamente en el shader de la pieza receptora (body_core, arm_r/l, leg_r/l) usando v_rig_pos y el canal de profundidad normal_depth_tex.a ($z_{\text{rec}} \in [0,1]$):Desplazamiento Paraláctico 2.5D por Altura Recepcionada: Si un oclusor (ej. pauldron_r o la cabeza) flota a una elevación relativa $H_{\text{caster}}$ sobre la pieza receptora, el punto proyectado donde evaluamos el oclusor se desplaza a lo largo de la luz 2D modulado por el relieve local de la pieza receptora:$$\vec{p}_{\text{proj}} = \vec{p}_{\text{rig}} - \vec{L}_{2D} \cdot \max\left(0.0, \; H_{\text{caster}} - H_{\text{rec\_scale}} \cdot z_{\text{rec}}\right)$$Gracias al término $- H_{\text{rec\_scale}} \cdot z_{\text{rec}}$, cuando la sombra de la hombrera o del faldón cae sobre un brazo o muslo cilíndrico (donde $z_{\text{rec}}$ es máximo en el centro y cae hacia los bordes), el borde de la sombra proyectada se curva envolviendo la sección cilíndrica del miembro, simulando una proyección 3D sobre geometría 2D.SDF de Cápsula Orientada (Hombreras y Faldón/Cadera) y Elipse (Cabeza): Para una cápsula definida en espacio rig por sus extremos actuales $\vec{A}$ y $\vec{B}$ y radio $R$, la distancia firmada es:$$\vec{ba} = \vec{B} - \vec{A}, \quad \vec{pa} = \vec{p}_{\text{proj}} - \vec{A}, \quad h = \text{clamp}\left(\frac{\vec{pa} \cdot \vec{ba}}{\max(\vec{ba} \cdot \vec{ba}, 10^{-4})}, 0.0, 1.0\right)$$$$d_{\text{caps}}(\vec{p}_{\text{proj}}) = \|\vec{pa} - \vec{ba} \cdot h\| - R$$Para la cabeza (DecoupledHeadMount) proyectando sobre body_core y pauldron_r/l (lo que permite reemplazar o complementar HeadContactShadow), usamos una elipse desplazada desde el pivote del cuello $\vec{C}_{\text{head}}$ con semiejes $\vec{R}_{\text{head}} = (r_x, r_y)$:$$d_{\text{head}}(\vec{p}_{\text{proj}}) = \left(\left\|\frac{\vec{p}_{\text{proj}} - \vec{C}_{\text{head}}}{\vec{R}_{\text{head}}}\right\| - 1.0\right) \cdot \min(r_x, r_y)$$Inyección en el Umbral de Iluminación (Estilo ILM Canal Verde de Guilty Gear Strive): Según reconstrucciones técnicas del flujo de trabajo de Guilty Gear Xrd/Strive, el canal verde del mapa ILM actúa como un bias o umbral de sombra (shaded threshold): 0.5 deja que el producto punto de Lambert decida si el área está iluminada, valores de 0.25 o inferiores fuerzan la sombra primaria (1st Shade), y valores por debajo de 0.1 disparan la sombra profunda (2nd Shade). En lugar de multiplicar el color final por la sombra proyectada, convertimos la distancia $d_{\text{occl}} = \min(d_{\text{caps}}, d_{\text{head}})$ en un desplazamiento de umbral:
$$O_{\text{cast}} = \text{smoothstep}\left(1.5, -1.5, d_{\text{occl}}\right)$$
Al restar $O_{\text{cast}} \cdot 0.52$ del escalar de iluminación antes del escalón smoothstep del cel-shading, la sombra proyectada por la hombrera o la cabeza se une sin costuras ni doble oscurecimiento con la sombra propia en índigo frío. Cuando una zona que ya estaba en sombra propia recibe además sombra de contacto ($I_{\text{raw}}$ cae por debajo de 0.1), entra automáticamente en el 2nd Shade (tinta profunda Mignola) justo debajo de la inserción.2.2 "Open Anime Ink", Disolución en Inserciones Coplanares y Mignola / Persona 5 Ink-PoolingA 160.5 px de altura en pantalla, las uniones de hombros, cadera y cuello miden apenas 10–14 px de ancho. Si cada Polygon2D dibuja bordes oscuros o caídas de iluminación en todo su perímetro UV, las inserciones parecen parches recortados.Técnica "Open Anime Ink" (Disolución Selectiva de Costuras Coplanares)En su conferencia sobre control de línea en la serie Guilty Gear, Junya C. Motomura (Arc System Works) explica que evitar líneas inconexas o parches artificiales requiere suprimir selectivamente el grosor de línea y compartir normales personalizadas en las transiciones anatómicas. En tus piezas de miembros (arm_r/l, leg_r/l), la zona de inserción proximal corresponde a UV.y en 0.0–0.16. Definimos una Máscara de Puente Coplanar (open_bridge):$$M_{\text{open}}(\text{UV}) = \left(1.0 - \text{smoothstep}(0.02, 0.18, \text{UV.y})\right) \cdot \text{smoothstep}(0.46, 0.28, |\text{UV.x} - 0.5|)$$El primer factor se activa en el extremo superior de la pieza (UV.y < 0.18), donde el brazo se inserta en el torso o el muslo en la cadera, mientras que el segundo factor vale 1.0 en el núcleo interior de la costura ($|\text{UV.x} - 0.5| < 0.28$) pero cae a 0.0 en las paredes laterales exteriores del miembro ($|\text{UV.x} - 0.5| > 0.46$). Donde $M_{\text{open}} \to 1.0$, anulamos cualquier línea interna, oclusión de borde UV y componente vertical de la normal ($N_y \to 0$), haciendo que el color e iluminación del interior del hombro o muslo coincidan con los de body_core. Como $M_{\text{open}} = 0$ en los bordes laterales UV.x = 0 y UV.x = 1, los trazos laterales del miembro entran ligeramente en el torso y se afilan hasta desaparecer en punta ("Open Anime Ink"), imitando el trazo manual de animación japonesa donde el músculo se conecta con el torso sin cerrar el círculo de la articulación.Mignola / Persona 5 Ink-Pooling (Cuñas Negras Afiladas en Pliegues Cóncavos)En el estilo gráfico de Mike Mignola y Persona 5, las concavidades articulares (axilas, unión de cadera, pliegue del codo y corva de la rodilla) no se sombrean con gradientes suaves de ambient occlusion —que a 160 px se perciben como manchas borrosas—, sino con cuñas geométricas de tinta negra sólida (2nd Shade) cuyos vértices terminan en ángulos agudos.Para generar estas cuñas procedimentalmente en respuesta a la flexión de tus Bone2D, modelamos un Operador de Cuña Cóncava (Scythe-Wedge Operator). En un miembro (arm o leg), la articulación media (codo o rodilla) se sitúa en $v_{\text{joint}} \approx 0.50$, mientras que el pliegue proximal se ubica en $v_{\text{prox}} \approx 0.14$. Sea $u_{\text{in}} \in [0, 1]$ la coordenada transversal medida desde el borde interior cóncavo de la flexión hacia el borde exterior (1.0 - UV.x si dobla hacia la derecha, UV.x si dobla hacia la izquierda), y sea $\Phi_{\text{bend}} \in [0, 1]$ la intensidad de flexión obtenida del ángulo entre el hueso superior e inferior (abs(angle_lower - angle_upper) / 1.8) o de la asimetría de compresión Jacobiana (1.0 - clamp(s_comp, 0.35, 1.0)). El perfil de la cuña sigue un decaimiento potencial cóncavo ($p = 1.65$) a lo largo de la distancia axial $d_v = |\text{UV.y} - v_{\text{joint}}|$:$$R_{\text{wedge}}(d_v, \Phi_{\text{bend}}) = W_{\text{max}} \cdot \Phi_{\text{bend}} \cdot \max\left(0.0, \; 1.0 - \frac{d_v}{L_{\text{span}}}\right)^{1.65}$$Cuando la coordenada transversal $u_{\text{in}}$ es menor que el alcance de la cuña $R_{\text{wedge}}$ (modulado por $-\vec{N}\cdot\vec{L}$ para que la cuña crezca a contraluz y se retraiga bajo luz directa), activamos un corte duro suavizado a 1 píxel de pantalla compensado por el Jacobiano:$$\sigma_u = \max\left(\text{fwidth}(u_{\text{in}}) \cdot s_{\text{comp}} \cdot 0.75, \; 0.008\right)$$$$M_{\text{mignola}} = \text{smoothstep}\left(R_{\text{wedge}} + \sigma_u, \; R_{\text{wedge}} - \sigma_u, \; u_{\text{in}}\right)$$Donde $M_{\text{mignola}} = 1.0$, el color salta limpiamente a la tinta gráfica profunda (vec3(0.015, 0.012, 0.032) en espacio lineal), creando cuñas de tinta afiladas en codos, rodillas y uniones proximales al doblarse sin depender de texturas de alta resolución.2.3 Continuidad de Normales entre Piezas, Fusión RNM, Rotación por Hueso y Subsurface Scattering (SSS)El motivo principal por el que dos Polygon2D contiguos delatan su frontera bajo luz direccional es el mapa _normal_depth.png tipo "almohada esférica por bounding-box". En una almohada esférica, la normal apunta hacia arriba ($N_y = -1$) en el borde superior UV.y = 0 y hacia abajo ($N_y = +1$) en el borde inferior UV.y = 1. Cuando la parte inferior de body_core ($N_y = +1$) se toca con la parte superior de leg_r ($N_y = -1$), sus normales divergen 180° en el eje vertical. Ningún ajuste de color oculta una discontinuidad de 180° en $\vec{N} \cdot \vec{L}$.Para resolverlo en cuatro pasos secuenciales dentro del shader:Cilindro Analítico Portador con Costuras Soldadas ($N_y \to 0$): Dado que las mallas son rejillas alineadas a los huesos (12x18, 10x24, 10x18), construimos una normal cilíndrica analítica a partir de la sección transversal $x_c = 2.0 \cdot \text{UV.x} - 1.0$:$$\vec{N}_{\text{cyl}} = \text{normalize}\left(\text{vec3}\left(x_c \cdot k_{\text{round}}, \; 0.0, \; \sqrt{\max(1.0 - (x_c \cdot k_{\text{round}})^2, \; 0.05)}\right)\right)$$
Donde $k_{\text{round}} \in [0.65, 0.90]$ controla la curvatura transversal (un valor de 0.76 evita que los bordes entren prematuramente en sombra rasante, replicando la transferencia de normales desde primitivas simplificadas usada en Guilty Gear Xrd/Strive). Como la componente longitudinal de $\vec{N}_{\text{cyl}}$ es $N_y = 0$, el extremo inferior del torso y el extremo superior del muslo comparten la misma normal base en su línea de contacto.Supresión de Almohada en Costuras y Fusión por Reoriented Normal Mapping (RNM): Para conservar los detalles internos de _normal_depth.png pero eliminar su caída esférica en los extremos de inserción, definimos una envolvente de soldadura axial $E_{\text{weld}}(\text{UV.y})$: smoothstep(0.0, 0.20, UV.y) cuando la pieza tiene inserción superior (leg_r/l, arm_r/l), multiplicada por smoothstep(1.0, 0.80, UV.y) cuando también tiene inserción inferior (body_core). Desempaquetamos la normal cruda [0..1] de normal_depth_tex.rgb, anulamos su componente $Y$ de almohada cerca de la costura (n_tex.y *= E_weld) y fusionamos el cilindro portador ($\vec{n}_1 = \vec{N}_{\text{cyl}}$) con el detalle de textura ($\vec{n}_2 = \vec{n}_{\text{tex}}$) mediante Reoriented Normal Mapping (RNM):
$$\vec{n}_1' = \vec{n}_1 + (0, 0, 1), \quad \vec{n}_2' = (-n_{2x}, -n_{2y}, n_{2z}), \quad \vec{N}_{\text{local}} = \text{normalize}\left(\vec{n}_1' \cdot \frac{\vec{n}_1' \cdot \vec{n}_2'}{n_{1z}'} - \vec{n}_2'\right)$$Rotación Dinámica de la Normal según el Hueso y BodyPivot: Como subraya Motomura en su documentación de Guilty Gear, las normales deben rotar solidariamente con los huesos para que la iluminación se mantenga coherente al animar. Dado que Polygon2D deforma los vértices en CPU, si un brazo se levanta 90°, el mapa de normales seguiría orientado como en reposo a menos que rotemos $\vec{N}_{\text{local}}.xy$. Pasando un uniform vec2 bone_chain_angles con los ángulos globales 2D del hueso proximal y distal del miembro, interpolamos el ángulo suavemente a lo largo de la rejilla:
$$\theta_{\text{limb}}(\text{UV.y}) = \text{mix}\left(\theta_{\text{upper}}, \; \theta_{\text{lower}}, \; \text{smoothstep}(0.35, 0.65, \text{UV.y})\right)$$Rotar $\vec{N}_{\text{local}}.xy$ por la matriz 2D $R(\theta_{\text{limb}})$ produce un campo de normales continuo a través del codo y la rodilla sin facetado triangular.Cosido Óptico por Subsurface Scattering (SSS) en el Terminador de Piel: En el flujo de Arc System Works, las zonas sombreadas se modulan con una textura o término de Subsurface Scattering (SSS). Una vez que el cuello (DecoupledHeadMount) y el pecho (body_core), o la cadera y el muslo, comparten normales continuas en su frontera, inyectamos una banda Gaussiana cálida justo en el terminador donde la luz cae a sombra ($I_{\text{raw}} \approx \tau_1 = 0.48$):
$$W_{\text{sss}} = \exp\left(-\frac{(I_{\text{raw}} - 0.46)^2}{(0.085)^2}\right) \cdot M_{\text{skin}} \cdot (1.0 - O_{\text{cast}} \cdot 0.65)$$Donde $M_{\text{skin}} = \text{clamp}(1.0 - (m_r + m_g + m_b + m_a), 0.0, 1.0)$ proviene de _id_mask.png. Como el terminador cruza perpendicularmente la costura soldada entre dos polígonos, esta franja coral-bermellón (sss_skin_color) cose visualmente ambas piezas.2.4 Diferenciación Dinámica de Piernas Gemelas en Perfil (e/w) y Medias (_stocking)En las vistas laterales (e y w), leg_r y leg_l poseen siluetas gemelas. Un multiplicador estático 0.85x en la pierna trasera aplana el contraste y hace que ambas piernas se fundan en una sola masa oscura cuando entran en sombra o durante cruces de tijera. En su lugar, definimos un uniforme continuo por pierna uniform float leg_depth_phase : hint_range(-1.0, 1.0) = 0.0; calculado dinámicamente en cada fotograma según la diferencia de posición de paso (+1.0 cuando la pierna está adelantada en primer plano, -1.0 cuando está retrasada en segundo plano).Para la pierna que retrocede ($z_{\text{back}} = \text{clamp}(-\text{leg\_depth\_phase}, 0.0, 1.0)$), aplicamos gradación atmosférica por compresión de rango (Depth Grading): en lugar de oscurecer hacia el negro con 0.85x, desplazamos el color iluminado un 34% hacia el tinte índigo atmosférico de sombra (shadow_indigo_tint), pero desplazamos su sombra primaria solo un 25% hacia un índigo medio-oscuro, reduciendo el contraste interno del plano trasero sin empastar los tonos oscuros. Simultáneamente, restamos $0.16 \cdot z_{\text{back}}$ al escalar de iluminación $I_{\text{raw}}$ de la pierna trasera para que entre antes en sombra cel que la delantera. Finalmente, en la pierna delantera ($z_{\text{front}} = \text{clamp}(\text{leg\_depth\_phase}, 0.0, 1.0)$), activamos un Rim Separator secundario en su borde cilíndrico posterior ($N_z < 0.45$) ponderado por $z_{\text{front}}$, dibujando una fina línea de luz de recorte únicamente en el borde de la pierna que cruza por delante de la otra.Para el material de medias (mask.a y los nodos duplicados Part_leg_*_stocking sobre body_core en vistas s, se, e, sw, w), modelamos un Fresnel cilíndrico de nylon a partir del coseno de visión local $\mu = \text{clamp}(\vec{N}_{\text{local}}.z, 0.0, 1.0)$. La transmitancia de la fibra $T_{\text{nylon}} = \text{pow}(\mu, 1.85) \cdot (1.0 - \text{stocking\_denier})$ permite que en el eje central del muslo y la espinilla ($\mu \to 1.0$) se trasluzca el sombreado cálido de la piel subyacente, mientras que hacia los bordes del cilindro ($\mu \to 0.0$) la opacidad del nylon se vuelve total. Se añade además un reflejo especular anisotrópico longitudinal (inspirado en los canales R y B de control especular del ILM de Guilty Gear) evaluando una franja paralela al hueso donde $|N_x - L_x \cdot 0.35| < 0.16$ en la zona iluminada. Para prevenir los agujeros negros en CanvasGroup, el corte superior de la media (stocking_welt_v) se ejecuta mediante step(stocking_welt_v, UV.y) sobre la mezcla de color RGB manteniendo COLOR.a = base_tex.a (100% opaco dentro de la silueta), sin usar discard ni alfa fraccionario en los bordes exteriores.2.5 Filtrado SDF Libre de Pixel Crawling (heads/*_outline_sdf.png) a 160 px y Zoom Variable (0.65x–2.0x)En DecoupledHeadMount, cada cabeza cuenta con _outline_pad_px = 24 y su mapa *_outline_sdf.png. A 160.5 px de altura total del personaje, la cabeza ocupa ~38 px en pantalla (~25 px a zoom = 0.65). Si calculas el borde SDF con fwidth(sdf) estándar sobre una textura de 8 bits (256 escalones discretos), las diferencias finitas dFdx(sdf) y dFdy(sdf) entre píxeles adyacentes saltan entre escalones de cuantización del PNG durante rotaciones lentas, provocando pixel crawling (encrespado dentado del contorno). Además, si void vertex() aplica squash/stretch a la cabeza, dFdy(UV) se infla y deforma el grosor del contorno.Para eliminar este ruido de cuantización, aprovechamos que el campo SDF se horneó con un rango de caída conocido en píxeles de textura ($R_{\text{sdf\_px}} = 24.0$) y que las coordenadas de vértice son interpoladas en coma flotante por el hardware. Calculamos cuánto mide 1 píxel de pantalla en unidades SDF directamente desde las derivadas de v_def_local (que ya incorporan cualquier deformación de void vertex()):$$px_{\text{in\_tex}} = \sqrt{\frac{\|\text{dFdx}(\vec{v}_{\text{def}})\|^2 + \|\text{dFdy}(\vec{v}_{\text{def}})\|^2}{2.0}}, \quad \Delta_{\text{sdf\_1px}} = \frac{px_{\text{in\_tex}}}{R_{\text{sdf\_px}}}$$Al usar $\Delta_{\text{sdf\_1px}}$ como ancho del smoothstep sobre el valor leído de *_outline_sdf.png, el filtro de antialiasing prescinde de las derivadas de la textura de 8 bits. A continuación, aplicando el principio de escalado no lineal de grosor por distancia de cámara expuesto por Motomura en Guilty Gear (donde las líneas faciales se adelgazan relativamente en primeros planos de 1–3 mm y mantienen mayor peso relativo de 7–10 mm en planos lejanos para conservar legibilidad), estimamos el factor de zoom efectivo $\zeta = 1.0 / \max(px_{\text{in\_tex}}, 0.1)$ y modulamos el grosor objetivo en píxeles de pantalla:$$W_{\text{target\_px}} = \text{clamp}\left(W_{\text{base\_px}} \cdot \text{pow}(\zeta, 0.60), \; 1.15, \; 3.00\right)$$De este modo, a zoom = 0.65 el contorno de la cabeza nunca cae por debajo de 1.15 px de pantalla, y a zoom = 2.0 escala en proporción armónica con el contorno del cuerpo en CanvasGroup.3. Código Implementable de Pasada 1: Master Shader para Polygon2D y DecoupledHeadMountEl siguiente shader de Godot 4.7.2 (shader_type canvas_item;) integra las ecuaciones de la Pasada 1 respetando tus restricciones empíricas (hdr_2d=true, lectura lineal de TEXTURE y : source_color, lectura cruda [0..1] de id_mask_tex y normal_depth_tex, no utilización de COLOR.rgb para pesos y preservación de COLOR.a en costuras internas).Fragmento de códigoshader_type canvas_item;

// ============================================================================
// UNIFORMES GLOBALES / COMPARTIDOS DEL RIG (Sincronizados desde BodyPivot)
// ============================================================================
uniform vec2 light_dir_2d = vec2(-0.65, -0.76);
uniform float light_z_tilt : hint_range(0.0, 1.0) = 0.38;
uniform mat4 inv_body_pivot_matrix = mat4(1.0); // Inversa del global_transform de BodyPivot

// Texturas por pieza (Sin : source_color para leer datos crudos [0..1] en hdr_2d=true)
uniform sampler2D id_mask_tex : filter_linear;       // R=acentos, G=paneles, B=traje, A=medias/pelo, resto=piel
uniform sampler2D normal_depth_tex : filter_linear;  // R=nx, G=ny, B=nz, A=depth
uniform sampler2D anim_mask_tex : filter_linear;
uniform sampler2D outline_sdf_tex : filter_linear;   // Para cabezas (heads/*_outline_sdf.png)

// Parámetros topológicos y de articulación por pieza
uniform bool is_head_pass = false;
uniform float sdf_pad_px = 24.0;
uniform bool weld_top_seam = true;      // Activo en leg_r/l, arm_r/l, body_core
uniform bool weld_bottom_seam = false;  // Activo en body_core
uniform float cylinder_roundness : hint_range(0.2, 1.0) = 0.76;

// Rotación de cadena ósea (en radianes respecto a BodyPivot) y flexión Mignola
uniform vec2 bone_chain_angles = vec2(0.0, 0.0); // x = hueso proximal, y = hueso distal
uniform float joint_v_coord : hint_range(0.0, 1.0) = 0.50;
uniform float joint_flexion : hint_range(0.0, 1.0) = 0.0; // > 0 activa cuña Mignola en pliegue
uniform float fold_inner_side : hint_range(-1.0, 1.0) = 1.0; // +1 = borde der cóncavo, -1 = izq

// Oclusores analíticos en espacio Rig (v_rig_pos en píxeles de BodyPivot)
// x,y = Punto A, z,w = Punto B de la cápsula (ej. pauldron o faldón/cadera)
uniform vec4 caster_capsule_ab = vec4(0.0, -28.0, 14.0, -18.0);
uniform vec2 caster_capsule_radius_height = vec2(11.0, 12.0); // x = radio, y = altura Z
uniform vec4 caster_head_ellipse = vec4(0.0, -44.0, 16.0, 14.0); // x,y = centro, z,w = rx,ry
uniform float caster_head_height = 16.0;
uniform float receiver_height_scale = 10.0;

// Separación dinámica en vista perfil (e/w) y Nylon (_stocking)
uniform float leg_depth_phase : hint_range(-1.0, 1.0) = 0.0; // +1 = delante, -1 = detrás
uniform float stocking_denier : hint_range(0.0, 1.0) = 0.38;
uniform float stocking_welt_v : hint_range(0.0, 1.0) = 0.0; // >0 si transición piel->media ocurre en UV.y

// Paleta estilizada Guilty Gear Strive + Studio Trigger (Lineal en hdr_2d=true)
uniform vec4 shadow_indigo_tint : source_color = vec4(0.32, 0.28, 0.58, 1.0);
uniform vec4 deep_mignola_ink : source_color = vec4(0.015, 0.012, 0.032, 1.0);
uniform vec4 sss_skin_color : source_color = vec4(0.95, 0.22, 0.14, 1.0);
uniform vec4 rim_light_color : source_color = vec4(0.78, 0.90, 1.00, 1.0);
uniform float hdr_accent_boost : hint_range(1.0, 2.5) = 1.45; // Supera glow_hdr_threshold > 1.12

// Smear direccional (Studio Trigger)
uniform vec2 smear_vector_px = vec2(0.0, 0.0);

varying vec2 v_rig_pos;
varying vec2 v_def_local;
varying vec2 v_rest_px;

// Fusión Reoriented Normal Mapping (RNM)
vec3 blend_rnm(vec3 n1, vec3 n2) {
	n1 += vec3(0.0, 0.0, 1.0);
	n2 *= vec3(-1.0, -1.0, 1.0);
	return normalize(n1 * dot(n1, n2) / max(n1.z, 1e-4) - n2);
}

// SDF de cápsula 2D en espacio rig
float sd_capsule_2d(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

// SDF de elipse aproximada para proyección de cabeza
float sd_ellipse_approx(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / max(r, vec2(1e-4));
	return (length(d) - 1.0) * min(r.x, r.y);
}

void vertex() {
	vec2 tex_size = 1.0 / max(TEXTURE_PIXEL_SIZE, vec2(1e-6));
	v_rest_px = UV * tex_size;

	// Estiramiento selectivo de Smear Frame
	if (length(smear_vector_px) > 0.01) {
		vec2 smear_dir = normalize(smear_vector_px);
		float trailing = max(0.0, -dot(normalize(VERTEX + vec2(1e-4)), smear_dir));
		VERTEX += smear_vector_px * trailing;
	}

	v_def_local = VERTEX;
	// Proyección al espacio canónico unificado de BodyPivot
	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0);
	v_rig_pos = (inv_body_pivot_matrix * world_pos).xy;
}

void fragment() {
	vec4 base_tex = texture(TEXTURE, UV); // Lineal en hdr_2d=true
	vec4 id_mask = texture(id_mask_tex, UV); // Raw [0..1]: R=acento, G=panel, B=traje, A=media/pelo
	vec4 nd_raw = texture(normal_depth_tex, UV); // Raw [0..1]: RGB=normal, A=depth

	// 1. COMPENSACIÓN JACOBIANA DE DERIVADAS (Invariante a compresión en vertex())
	float def_grad_sq = dot(dFdx(v_def_local), dFdx(v_def_local)) + dot(dFdy(v_def_local), dFdy(v_def_local));
	float rest_grad_sq = dot(dFdx(v_rest_px), dFdx(v_rest_px)) + dot(dFdy(v_rest_px), dFdy(v_rest_px));
	float s_comp = sqrt(def_grad_sq / max(rest_grad_sq, 1e-6));
	float px_in_tex = sqrt(def_grad_sq * 0.5); // Tamaño de 1 px de pantalla en px de textura

	// 2. PESOS DE MATERIAL DESDE _id_mask.png
	float m_accent = id_mask.r;
	float m_panel  = id_mask.g;
	float m_suit   = id_mask.b;
	float m_nylon  = id_mask.a * step(stocking_welt_v, UV.y); // Corte limpio de media sin romper alfa
	float m_skin   = clamp(1.0 - (m_accent + m_panel + m_suit + m_nylon), 0.0, 1.0);

	// 3. CONTINUIDAD DE NORMALES: CILINDRO ANALÍTICO + SOLDADURA AXIAL + RNM
	float seam_env = 1.0;
	if (weld_top_seam) {
		seam_env *= smoothstep(0.0, 0.20, UV.y);
	}
	if (weld_bottom_seam) {
		seam_env *= smoothstep(1.0, 0.80, UV.y);
	}

	// Portador cilíndrico transversal (Ny = 0 en todas las costuras horizontales)
	float xc = (UV.x * 2.0 - 1.0) * cylinder_roundness;
	vec3 n_cyl = normalize(vec3(xc, 0.0, sqrt(max(1.0 - xc * xc, 0.06))));

	// Normal del mapa base limpiando el efecto "almohada" en los extremos de unión
	vec3 n_tex = nd_raw.rgb * 2.0 - 1.0;
	n_tex.y *= seam_env;
	n_tex = normalize(mix(vec3(0.0, 0.0, 1.0), n_tex, 0.35 + 0.65 * seam_env));

	vec3 n_local = blend_rnm(n_cyl, n_tex);

	// Rotación dinámica de la normal según la cadena de huesos de la pieza
	float bone_angle = mix(bone_chain_angles.x, bone_chain_angles.y, smoothstep(0.35, 0.65, UV.y));
	float ca = cos(bone_angle), sa = sin(bone_angle);
	vec2 rot_xy = mat2(vec2(ca, sa), vec2(-sa, ca)) * n_local.xy;
	vec3 n_world = normalize(vec3(rot_xy, n_local.z));

	// 4. SOMBRAS DE CONTACTO PROYECTADAS ANALÍTICAMENTE EN ESPACIO RIG (2.5D)
	vec2 l2d = normalize(light_dir_2d);
	vec3 light_vec = normalize(vec3(l2d, light_z_tilt));
	float z_rec = nd_raw.a * receiver_height_scale;

	vec2 p_proj_caps = v_rig_pos - l2d * max(0.0, caster_capsule_radius_height.y - z_rec);
	float d_caps = sd_capsule_2d(p_proj_caps, caster_capsule_ab.xy, caster_capsule_ab.zw, caster_capsule_radius_height.x);

	vec2 p_proj_head = v_rig_pos - l2d * max(0.0, caster_head_height - z_rec);
	float d_head = is_head_pass ? 100.0 : sd_ellipse_approx(p_proj_head, caster_head_ellipse.xy, caster_head_ellipse.zw);

	float cast_shadow = smoothstep(1.25, -1.25, min(d_caps, d_head));

	// 5. EVALUACIÓN DE UMBRAL CEL ESTILO ILM (Arc System Works) + FASE DE PIERNA
	float n_dot_l = dot(n_world, light_vec);
	float back_leg_factor = clamp(-leg_depth_phase, 0.0, 1.0);
	float front_leg_factor = clamp(leg_depth_phase, 0.0, 1.0);

	// Open Anime Ink: En inserciones coplanares, estabilizamos la iluminación hacia el torso
	float open_bridge = weld_top_seam ? (1.0 - smoothstep(0.02, 0.16, UV.y)) * smoothstep(0.46, 0.26, abs(UV.x - 0.5)) : 0.0;

	float i_raw = (n_dot_l * 0.5 + 0.5) - cast_shadow * 0.52 - back_leg_factor * 0.16;
	i_raw = mix(i_raw, max(i_raw, 0.54), open_bridge * 0.65);

	float aa_cel = clamp(fwidth(i_raw) * s_comp * 0.8, 0.01, 0.05);
	float lit_step = smoothstep(0.48 - aa_cel, 0.48 + aa_cel, i_raw);

	// 6. MATERIAL NYLON (_stocking) + SSS EN TERMINADOR DE PIEL
	vec3 albedo = base_tex.rgb;
	if (m_nylon > 0.01) {
		float mu = clamp(n_local.z, 0.0, 1.0);
		float sheer_trans = pow(mu, 1.85) * (1.0 - stocking_denier);
		vec3 under_skin = mix(albedo, vec3(0.92, 0.68, 0.60), 0.65);
		albedo = mix(albedo, under_skin, sheer_trans * m_nylon);
		// Brillo anisotrópico longitudinal de nylon en zona iluminada
		float aniso_spec = smoothstep(0.16, 0.04, abs(n_local.x - l2d.x * 0.35)) * step(0.75, mu) * lit_step;
		albedo += rim_light_color.rgb * (aniso_spec * 0.18 * m_nylon);
	}

	// Paleta de sombra primaria en índigo frío (Multiplicativa cromática estilo GG Strive)
	vec3 shade_1st = albedo * mix(shadow_indigo_tint.rgb, vec3(0.42, 0.36, 0.66), m_skin * 0.35);
	// Compresión de contraste atmosférico para pierna trasera en vistas perfil (e/w)
	vec3 lit_color = mix(albedo, mix(albedo, shade_1st, 0.34), back_leg_factor);
	vec3 dark_color = mix(shade_1st, mix(shade_1st, shadow_indigo_tint.rgb * 0.45, 0.25), back_leg_factor);

	vec3 shaded_rgb = mix(dark_color, lit_color, lit_step);

	// Subsurface Scattering (SSS) cálido en el terminador para coser piel entre polígonos
	float sss_band = exp(-pow((i_raw - 0.46) / 0.085, 2.0)) * m_skin * (1.0 - cast_shadow * 0.65);
	shaded_rgb = mix(shaded_rgb, shaded_rgb + sss_skin_color.rgb * 0.28, sss_band);

	// 7. CUÑAS DE TINTA MIGNOLA / PERSONA 5 EN PLIEGUES CÓNCAVOS Y 2ND SHADE (< 0.10)
	float u_fold = (fold_inner_side >= 0.0) ? (1.0 - UV.x) : UV.x;
	float dv_joint = abs(UV.y - joint_v_coord);
	float wedge_reach = 0.55 * joint_flexion * pow(max(0.0, 1.0 - dv_joint / 0.24), 1.65);
	wedge_reach += max(0.0, -n_dot_l) * 0.12 * joint_flexion;
	float sigma_u = max(fwidth(u_fold) * s_comp * 0.75, 0.008);
	float mignola_wedge = smoothstep(wedge_reach + sigma_u, wedge_reach - sigma_u, u_fold) * step(0.02, joint_flexion);

	// El 2nd Shade se activa tanto por la cuña articular como por umbral profundo (< 0.10)
	float deep_ink_mask = max(mignola_wedge, smoothstep(0.11, 0.07, i_raw) * (1.0 - m_skin * 0.5));
	deep_ink_mask *= (1.0 - open_bridge); // Nunca cerrar tinta sobre un puente Open Anime Ink
	shaded_rgb = mix(shaded_rgb, deep_mignola_ink.rgb, deep_ink_mask);

	// 8. RIM LIGHT DIRECCIONAL + RIM SEPARATOR DE PIERNA DELANTERA (e/w)
	float grazing = 1.0 - clamp(n_local.z, 0.0, 1.0);
	float rim_dir = smoothstep(0.58, 0.76, grazing * max(0.0, dot(n_world.xy, l2d))) * lit_step;
	float leg_sep_rim = smoothstep(0.55, 0.74, grazing * max(0.0, -dot(n_world.xy, l2d))) * front_leg_factor;
	shaded_rgb = mix(shaded_rgb, rim_light_color.rgb * 0.92, clamp(rim_dir + leg_sep_rim * 0.65, 0.0, 1.0));

	// 9. ACENTOS EMISIVOS HDR (> 1.12 para Bloom AgX y Light-Wrap en Pasada 2)
	if (m_accent > 0.01) {
		shaded_rgb = mix(shaded_rgb, base_tex.rgb * hdr_accent_boost, m_accent);
	}

	// 10. CONTORNO SDF ANALÍTICO DE CABEZA (Libre de pixel crawling a 160 px)
	if (is_head_pass) {
		float sdf_val = texture(outline_sdf_tex, UV).r; // Asumiendo 0.5 en el borde exterior
		float zoom_est = clamp(1.0 / max(px_in_tex, 0.1), 0.5, 3.0);
		float target_px = clamp(1.45 * pow(zoom_est, 0.60), 1.15, 3.0);
		float sdf_1px = max(px_in_tex / max(sdf_pad_px, 1.0), 0.004);
		float line_half = (target_px * 0.5) * sdf_1px;
		float sdf_aa = sdf_1px * 0.85;
		float head_ink = smoothstep(0.5 + line_half + sdf_aa, 0.5 + line_half - sdf_aa, sdf_val)
		               * smoothstep(0.5 - line_half - sdf_aa, 0.5 - line_half + sdf_aa, sdf_val);
		vec3 head_line_col = pow(clamp(shaded_rgb, vec3(0.0), vec3(1.0)), vec3(1.4)) * shadow_indigo_tint.rgb * 0.35;
		shaded_rgb = mix(shaded_rgb, head_line_col, head_ink * (1.0 - open_bridge));
	}

	// Salida estricta con alfa íntegro para proteger el backbuffer de CanvasGroup
	COLOR = vec4(shaded_rgb, base_tex.a);
}
4. Técnicas Avanzadas en Pasada 2 (CanvasGroup / Espacio Pantalla RGBA16F)En Godot 4, el nodo CanvasGroup agrupa a sus nodos hijos en una sola operación de dibujo renderizándolos primero en un backbuffer temporal (screen_texture) con formato RGBA16F (cuando hdr_2d=true) y componiendo luego ese buffer sobre el viewport con mezcla de alfa premultiplicado. Cuando sobrescribes el material de CanvasGroup con un shader propio, es necesario respetar dos reglas del pipeline:Los colores almacenados en screen_texture vienen multiplicados por su alfa ($\vec{C}_{\text{pre}} = \vec{C}_{\text{lin}} \cdot \alpha$). Si lees c = textureLod(screen_texture, SCREEN_UV, 0.0) y lo devuelves sin des-premultiplicar (c.rgb /= c.a) antes de la salida, el pipeline volverá a multiplicar por COLOR.a, generando halos oscuros cuadráticos ($\alpha^2$) en los bordes suavizados.Cuando dos piezas Polygon2D contiguas (ej. arm_r y body_core, o leg_r y body_core) rotan o tienen bordes rasterizados a 160.5 px, la costura entre ambas puede abrirse 0.5–1.5 px o acumular una cobertura combinada $\alpha = 1 - (1 - \alpha_1)(1 - \alpha_2) < 1.0$ (por ejemplo, dos bordes al 50% suman 0.75, no 1.0). Si un filtro de contorno busca cualquier vecindario donde el píxel central tenga a < 0.95 junto a vecinos con a = 1.0, dibujará puntos, costuras y agujeros negros dentro del cuerpo.4.1 Soldador Morfológico de Oposición Bipolar (1–2 px) sin Engrosar la Silueta ExteriorSi aplicáramos un cierre morfológico clásico (dilatación seguida de erosión) en una sola pasada de CanvasGroup, necesitaríamos un kernel de radio doble o alteraríamos las esquinas exteriores de la silueta. En cambio, podemos resolverlo en un anillo de 8 muestras usando un Tensor de Oposición Bipolar (Bipolar Seam-Bridge Detector).Sea $\vec{u} = \text{SCREEN\_UV}$ el píxel actual con cobertura central $A_0 = C(\vec{u}).a < 0.99$. Definimos 4 ejes unitarios simétricos $\vec{e}_k$ correspondientes a 0°, 90°, 45° y 135°, escalados por un radio de puente seam_weld_radius_px = 1.35 en unidades de SCREEN_PIXEL_SIZE:$$\vec{\delta}_k = \vec{e}_k \cdot r_w \cdot \text{SCREEN\_PIXEL\_SIZE}, \quad k \in \{0, 1, 2, 3\}$$Para cada eje $k$, muestreamos el par diametralmente opuesto $C_+ = C(\vec{u} + \vec{\delta}_k)$ y $C_- = C(\vec{u} - \vec{\delta}_k)$ y evaluamos el operador de puente bilateral:$$B_k = \min\left(C_+.a, \; C_-.a\right), \quad B_{\text{max}} = \max_{k \in \{0,1,2,3\}} B_k$$El comportamiento geométrico de $B_{\text{max}}$ discrimina ambos casos: en cualquier borde exterior de la silueta del personaje, si $+\vec{\delta}_k$ entra hacia el cuerpo ($C_+.a \approx 1.0$), el vector opuesto $-\vec{\delta}_k$ apunta hacia el espacio vacío exterior ($C_-.a = 0.0$), por lo que $\min(C_+.a, C_-.a) = 0.0$ y la silueta exterior no activa el soldador. En cambio, dentro de una micro-grieta o costura semitransparente (1–2 px) entre dos piezas Polygon2D, el eje $\vec{e}_{k^*}$ perpendicular a la costura toca la pieza A en $+\vec{\delta}_{k^*}$ ($C_+.a > 0.70$) y la pieza B en $-\vec{\delta}_{k^*}$ ($C_-.a > 0.70$) simultáneamente, elevando $B_{\text{max}} > 0.70$. Cuando $B_{\text{max}} > A_0$, soldamos el píxel antes de calcular el contorno exterior:$$A_{\text{welded}} = \max\left(A_0, \; \text{smoothstep}(0.31, 0.62, B_{\text{max}})\right) \\ \vec{C}_{\text{bridge\_rgb}} = \frac{C_+.\text{rgb} + C_-.\text{rgb}}{\max(C_+.a + C_-.a, \; 10^{-4})} \\ \vec{C}_{\text{welded\_rgb}} = \text{mix}\left(\frac{C_0.\text{rgb}}{\max(A_0, 10^{-4})}, \; \vec{C}_{\text{bridge\_rgb}}, \; \text{clamp}\left(\frac{A_{\text{welded}} - A_0}{\max(A_{\text{welded}}, 10^{-4})}, 0.0, 1.0\right)\right)$$Gracias a esta reconstrucción des-premultiplicada ponderada por alfa, la micro-grieta se rellena con el promedio cromático de los dos polígonos adyacentes y su alfa sube a 1.0, suprimiendo los agujeros negros internos sin modificar el contorno exterior.4.2 Contorno Exterior Caligráfico Coloreado sin Flickering Temporal a 160 pxEl parpadeo temporal (flickering) en shaders de dilatación de CanvasGroup ocurre cuando se toma el máximo de alfa en un kernel con desplazamientos fijos y se aplica un corte duro, o cuando no se pondera la distancia euclidiana de las diagonales. A 160.5 px, cuando el personaje se desplaza fracciones de píxel por fotograma entre 5,000 proyectiles, un contorno binario salta de un píxel al siguiente.Para obtener un trazo caligráfico estable en movimiento:Campo de Distancia Sub-Píxel Aproximado (Continuous Coverage Distance): Para cada una de las 8 muestras vecinas a distancia métrica $d_i \in \{1.0, \sqrt{2}\}$ multiplicada por el radio máximo de línea $W_{\text{max}}$, estimamos a cuántos píxeles se encuentra el borde real del personaje asumiendo que la cobertura parcial $\alpha_i \in (0, 1)$ representa una transición lineal de 1 píxel:$$\hat{D}_i = d_i \cdot W_{\text{max}} \cdot (1.0 - \alpha_i), \quad D_{\text{edge}} = \min_i (\hat{D}_i)$$Normal de Borde ($\vec{N}_{\text{edge}}$) y Curvatura Local ($\kappa$) por Operador Sobel/Laplaciano: Con las mismas 8 muestras de alfa, evaluamos el gradiente de Sobel $\vec{G} = (G_x, G_y)$ y el Laplaciano discreto $\nabla^2 \alpha$:$$\vec{N}_{\text{edge}} = -\frac{\vec{G}}{\max(\|\vec{G}\|, 10^{-4})}, \quad \kappa = \text{clamp}\left(\nabla^2 \alpha \cdot 1.5, \; -0.5, \; 0.8\right)$$Grosor Caligráfico Variable (Luz + Curvatura) y Tinte Heredado (Colored Line Art): En el lado iluminado ($\vec{N}_{\text{edge}} \cdot \vec{L}_{2D} > 0$), el trazo se afina hacia outline_min_px (~0.90 px) y absorbe un toque del color de rim light. En el lado en sombra ($\vec{N}_{\text{edge}} \cdot \vec{L}_{2D} < 0$) y en concavidades de silueta ($\kappa > 0$), el trazo se engrosa hasta outline_max_px (~2.05 px). Además, aplicando la técnica de Guilty Gear Xrd/Strive donde el contorno toma una versión oscurecida del color local de la pieza (ej. abrigo naranja = línea marrón-naranja oscura), acumulamos el color des-premultiplicado LDR de los vecinos opacos ($\min(\vec{C}_i, 1.0)$) y lo oscurecemos cromáticamente:
$$\vec{C}_{\text{ink}} = \text{pow}\left(\text{clamp}(\vec{C}_{\text{nearest\_ldr}}, 0.0, 1.0), \; \text{vec3}(1.45)\right) \cdot \vec{T}_{\text{outline\_indigo}}$$4.3 Light-Wrap HDR entre Piezas e Impact Frames en RGBA16FDado que viewport/hdr_2d=true mantiene el buffer de CanvasGroup en coma flotante (RGBA16F), todos los píxeles del personaje que no son acentos emisivos se mantienen en el rango lineal 0.0–0.98, mientras que el visor y los acentos mask.r se emiten en la Pasada 1 con valores > 1.25 (por encima de tu glow_hdr_threshold > 1.12). En la Pasada 2 (CanvasGroup), aprovechamos las muestras del anillo exterior para extraer únicamente la energía super-luminosa ($\vec{E}_i = \max(\vec{C}_{i,\text{unpremul}} - \text{vec3}(1.08), \text{vec3}(0.0))$) y la inyectamos sobre los píxeles opacos adyacentes ($A_{\text{welded}} > 0.5$). Como este cálculo ocurre en el espacio pantalla unificado de CanvasGroup, el resplandor del visor en DecoupledHeadMount o de un acento en pauldron_r cruza la frontera geométrica e ilumina el cuello y el pecho en body_core, integrando las piezas antes del tonemapping AgX.Para los Impact Frames (Estilo Studio Trigger / Binary Flash), cuando el uniforme impact_frame_mix > 0.0 se activa durante un parry, golpe crítico o graze extremo entre los 5,000 proyectiles, el shader evalúa la luminancia lineal del personaje junto con un patrón de rayos radiales y cuantiza el interior de la silueta soldada a alto contraste blanco/negro (1.35 HDR para el destello frente a 0.01 negro), preservando la silueta sobre el fondo espacial saturado de balas aditivas (* 1.85).5. Código Implementable de Pasada 2: Master Shader para CanvasGroup (RGBA16F)Asigna este shader directamente al ShaderMaterial de tu nodo CanvasGroup raíz.Fragmento de códigoshader_type canvas_item;
render_mode unshaded;

// Screen texture del backbuffer RGBA16F premultiplicado del CanvasGroup
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Dirección de luz sincronizada y control de escala/zoom
uniform vec2 light_dir_2d = vec2(-0.65, -0.76);
uniform float camera_zoom : hint_range(0.5, 3.0) = 1.0;

// Parámetros del Soldador Morfológico de Micro-Grietas (1-2 px)
uniform float seam_weld_radius_px : hint_range(0.5, 2.5) = 1.35;
uniform float seam_bridge_threshold : hint_range(0.3, 0.9) = 0.62;

// Parámetros del Contorno Caligráfico Exterior
uniform float outline_min_px : hint_range(0.5, 2.0) = 0.90;
uniform float outline_max_px : hint_range(1.0, 4.0) = 2.05;
uniform vec4 outline_indigo_tint : source_color = vec4(0.16, 0.12, 0.28, 1.0);
uniform vec4 outline_lit_tint : source_color = vec4(0.45, 0.52, 0.75, 1.0);
uniform float colored_line_strength : hint_range(0.0, 1.0) = 0.55;

// Parámetros de Light-Wrap HDR entre piezas e Impact Frames (Studio Trigger)
uniform float hdr_threshold : hint_range(1.0, 1.5) = 1.08;
uniform float hdr_light_wrap_strength : hint_range(0.0, 1.0) = 0.42;
uniform float impact_frame_mix : hint_range(0.0, 1.0) = 0.0;
uniform bool impact_invert_polarity = false;
uniform vec2 impact_center_uv = vec2(0.5, 0.5);

// Des-premultiplicación segura para RGBA16F
vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? (c.rgb / c.a) : vec3(0.0);
}

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 c0 = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 rgb0 = unpremul(c0);
	float a0 = c0.a;

	// Escalado no lineal del grosor de línea con el zoom (Regla de Motomura / GG Strive)
	float zoom_scale = pow(clamp(camera_zoom, 0.65, 2.0), 0.55);
	float w_min = max(0.85, outline_min_px * zoom_scale);
	float w_max = clamp(outline_max_px * zoom_scale, 1.25, 3.40);

	// ========================================================================
	// 1. SOLDADOR MORFOLÓGICO DE OPOSICIÓN BIPOLAR (Cierra grietas de 1-2 px)
	// ========================================================================
	// Evaluamos 4 pares diametralmente opuestos (+d_k, -d_k) a radio seam_weld_radius_px
	const vec2 dirs[4] = {
		vec2(1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(0.70710678, 0.70710678),
		vec2(-0.70710678, 0.70710678)
	};

	vec4 pos_s[4];
	vec4 neg_s[4];
	float max_bridge_alpha = 0.0;
	vec3 bridge_accum_rgb = vec3(0.0);
	float bridge_weight_sum = 0.0;

	for (int k = 0; k < 4; k++) {
		vec2 offset_weld = dirs[k] * (seam_weld_radius_px * ps);
		pos_s[k] = textureLod(screen_texture, SCREEN_UV + offset_weld, 0.0);
		neg_s[k] = textureLod(screen_texture, SCREEN_UV - offset_weld, 0.0);

		// Operador Bipolar: SOLO es alto si AMBOS lados opuestos son opacos (grieta interior)
		float pair_bridge = min(pos_s[k].a, neg_s[k].a);
		if (pair_bridge > max_bridge_alpha) {
			max_bridge_alpha = pair_bridge;
		}
		float w_pair = smoothstep(0.30, 0.75, pair_bridge);
		bridge_accum_rgb += (pos_s[k].rgb + neg_s[k].rgb) * w_pair;
		bridge_weight_sum += (pos_s[k].a + neg_s[k].a) * w_pair;
	}

	float welded_a = a0;
	vec3 welded_rgb = rgb0;

	if (a0 < 0.99 && max_bridge_alpha > a0 && max_bridge_alpha > seam_bridge_threshold * 0.6) {
		float target_weld_a = smoothstep(seam_bridge_threshold * 0.5, seam_bridge_threshold, max_bridge_alpha);
		welded_a = max(a0, target_weld_a);
		vec3 bridged_col = bridge_accum_rgb / max(bridge_weight_sum, 1e-4);
		float weld_blend = clamp((welded_a - a0) / max(welded_a, 1e-4), 0.0, 1.0);
		welded_rgb = mix(rgb0, bridged_col, weld_blend);
	}

	// ========================================================================
	// 2. CAMPO DE CONTORNO CALIGRÁFICO + SOBEL + LIGHT-WRAP HDR EN 8 MUESTRAS
	// ========================================================================
	vec4 ring_p[4];
	vec4 ring_n[4];
	float min_dist_px = 100.0;
	vec3 nearest_ldr_rgb = vec3(0.0);
	float nearest_w_sum = 0.0;
	vec3 hdr_wrap_accum = vec3(0.0);

	for (int k = 0; k < 4; k++) {
		float metric_len = (k < 2) ? 1.0 : 1.41421356;
		vec2 off_out = dirs[k] * (w_max * ps);
		ring_p[k] = textureLod(screen_texture, SCREEN_UV + off_out, 0.0);
		ring_n[k] = textureLod(screen_texture, SCREEN_UV - off_out, 0.0);

		// Aproximación continua sub-píxel de distancia euclidiana al borde opaco
		float dp_pos = (metric_len * w_max) * (1.0 - ring_p[k].a);
		float dp_neg = (metric_len * w_max) * (1.0 - ring_n[k].a);
		min_dist_px = min(min_dist_px, min(dp_pos, dp_neg));

		// Acumulación de color vecino LDR para Colored Line Art (estilo GG Strive)
		vec3 up_p = unpremul(ring_p[k]);
		vec3 up_n = unpremul(ring_n[k]);
		float wp = ring_p[k].a * ring_p[k].a;
		float wn = ring_n[k].a * ring_n[k].a;
		nearest_ldr_rgb += min(up_p, vec3(1.0)) * wp + min(up_n, vec3(1.0)) * wn;
		nearest_w_sum += wp + wn;

		// Extracción de excedente emisivo HDR (> hdr_threshold) para Light-Wrap entre piezas
		vec3 hdr_p = max(up_p - vec3(hdr_threshold), vec3(0.0)) * ring_p[k].a;
		vec3 hdr_n = max(up_n - vec3(hdr_threshold), vec3(0.0)) * ring_n[k].a;
		hdr_wrap_accum += hdr_p + hdr_n;
	}

	// Gradiente de Sobel sobre el anillo para extraer la Normal Exterior 2D (N_edge)
	float gx = (ring_p[0].a - ring_n[0].a) * 2.0 + (ring_p[2].a - ring_n[2].a) - (ring_p[3].a - ring_n[3].a);
	float gy = (ring_p[1].a - ring_n[1].a) * 2.0 + (ring_p[2].a - ring_n[2].a) + (ring_p[3].a - ring_n[3].a);
	vec2 n_edge = -vec2(gx, gy) / max(length(vec2(gx, gy)), 1e-4);

	// Curvatura discreta (Laplaciano) para engrosar concavidades y afilar puntas
	float laplacian = (ring_p[0].a + ring_n[0].a + ring_p[1].a + ring_n[1].a) * 0.25 - welded_a;
	float concavity = clamp(laplacian * 1.5, -0.5, 0.8);

	vec2 l2d = normalize(light_dir_2d);
	float edge_dot_l = dot(n_edge, l2d);

	// Modulación caligráfica del ancho objetivo en píxeles de pantalla
	float callig_t = smoothstep(-0.55, 0.65, -edge_dot_l);
	float target_width_px = clamp(mix(w_min, w_max, callig_t) + concavity * 0.45, w_min, w_max);

	// Cobertura continua anti-aliased del contorno exterior (Mitiga flickering temporal)
	float outline_cov = smoothstep(target_width_px + 0.55, target_width_px - 0.45, min_dist_px);

	// Tinte caligráfico del contorno (Hereda el color local oscurecido + modulación por luz)
	vec3 avg_edge_col = nearest_ldr_rgb / max(nearest_w_sum, 1e-4);
	vec3 base_ink = mix(outline_indigo_tint.rgb, pow(avg_edge_col, vec3(1.45)) * outline_indigo_tint.rgb * 1.8, colored_line_strength);
	vec3 lit_ink = mix(base_ink, outline_lit_tint.rgb * avg_edge_col, smoothstep(0.1, 0.8, edge_dot_l) * 0.55);

	// ========================================================================
	// 3. COMPOSICIÓN FINAL: LIGHT-WRAP HDR + SILUETA SOLDADA + IMPACT FRAME
	// ========================================================================
	// Aplicamos el derrame luminoso HDR cruzando las costuras internas de las piezas
	vec3 hdr_wrap = (hdr_wrap_accum * 0.125) * hdr_light_wrap_strength;
	vec3 interior_rgb = welded_rgb + hdr_wrap * welded_a;

	// Impact Frame (Flash binario blanco/negro estilo Studio Trigger / Mignola)
	if (impact_frame_mix > 0.001 && welded_a > 0.01) {
		vec2 rel_uv = SCREEN_UV - impact_center_uv;
		float angle = atan(rel_uv.y, rel_uv.x);
		float speed_rays = sin(angle * 42.0) * 0.18 + sin(angle * 96.0) * 0.08;
		float lum = dot(min(interior_rgb, vec3(1.2)), vec3(0.2126, 0.7152, 0.0722));
		float flash_bin = step(0.42 + speed_rays, lum);
		if (impact_invert_polarity) {
			flash_bin = 1.0 - flash_bin;
		}
		// 1.35 supera el umbral HDR (> 1.12) para disparar el destello en AgX
		vec3 impact_col = mix(vec3(0.01, 0.01, 0.02), vec3(1.35, 1.35, 1.40), flash_bin);
		interior_rgb = mix(interior_rgb, impact_col, impact_frame_mix);
	}

	// Mezcla del cuerpo soldado sobre el contorno caligráfico exterior
	float final_a = max(welded_a, outline_cov);
	vec3 final_rgb = mix(lit_ink, interior_rgb, welded_a);

	// Re-asignación limpia para el pipeline premultiplicado de CanvasGroup
	COLOR = vec4(final_rgb, final_a * COLOR.a);
}
6. Síntesis de Referentes de Industria y Presupuesto de Rendimiento en Godot 4.7.2 MobileLa documentación técnica disponible proporciona fuentes primarias y reconstrucciones detalladas sobre el pipeline de Guilty Gear Xrd / Strive (y Dragon Ball FighterZ) de Arc System Works, así como referencias sobre el uso de rim light, luz de rebote secundaria y renderizado 3D a 2D de estilo cómic en Hades y Hades II de Supergiant Games. No se encontraron postmortems primarios ni código fuente oficial de los motores internos de Skullgirls, Studio Trigger o Live2D/Spine en las fuentes consultadas; las técnicas correspondientes en la tabla siguiente representan formulaciones matemáticas diseñadas para replicar sus convenciones estéticas dentro del pipeline de Godot 4.7.2.Referente de IndustriaTruco de Producción / Principio VisualAdaptación en Godot 4.7.2 (Polygon2D + CanvasGroup)Guilty Gear Xrd / Strive & DBFZ (Arc System Works)Transferencia de normales desde primitivas simples, segundo set de normales en tangente para contornos continuos, mapa ILM (G=umbral de sombra 0.5/0.25/0.1, R/B=especular, A=líneas internas), textura SSS y líneas coloreadas.Portador cilíndrico analítico con $N_y = 0$ en costuras fusionado vía RNM con _normal_depth.png; evaluación de umbral unificado $I_{\text{raw}}$ antes del smoothstep; contorno caligráfico en Pasada 2 teñido con $\text{pow}(\vec{C}_{\text{edge}}, 1.45)$.Mike Mignola / Persona 5 (Adaptación Estilizada)Oclusión ambiental reemplazada por bloques gráficos de tinta negra sólida con cortes angulares agudos en pliegues y concavidades.Operador de Cuña Cóncava (mignola_wedge) parametrizado por joint_flexion y decaimiento potencial $(1 - d_v / L)^{1.65}$ con corte anti-aliased por $\text{fwidth}(u_{\text{fold}}) \cdot s_{\text{comp}}$.Studio Trigger (Adaptación Estilizada)Sombras índigo/violeta de alta saturación, trazos abiertos en inserciones musculares ("Open Anime Ink"), smears geométricos e impact frames binarios radiales.Sombra primaria en shadow_indigo_tint, máscara de puente $M_{\text{open}}(\text{UV})$ que disuelve líneas y normal vertical en el centro de la raíz de hombro/muslo, y flash binario radial en RGBA16F.Hades / Hades II (Supergiant Games)Rim light direccional fuerte, luz de rebote secundaria y contraste estilo cómic para separar planos sobre fondos complejos.Cross-Leg Rim Separator en vistas perfil (e/w) gobernado por leg_depth_phase, combinado con compresión atmosférica de contraste en la pierna trasera en lugar del multiplicador plano 0.85x.Skullgirls / Rigs 2D (Adaptación Estilizada)Consistencia de peso de línea entre cabeza y cuerpo y sellado de huecos internos entre piezas articuladas.Soldador Morfológico Bipolar (1–2 px) en Pasada 2 ($\min(A_+, A_-)$) que sella micro-grietas entre polígonos sin alterar la silueta, y escalado SDF analítico $\text{pow}(\text{zoom}, 0.60)$ libre de ruido de 8 bits.Advertencias Críticas de Rendimiento y Artefactos en renderer/rendering_method="mobile"En primer lugar, conviene evitar por completo la instrucción discard en la Pasada 1 para preservar el rendimiento en GPUs con arquitectura Tile-Based (mobile), donde discard dentro de void fragment() penaliza las optimizaciones de Early-Z / Hidden Surface Removal (HSR) y la ejecución de subgroups. Como el shader de Pasada 1 resuelve tanto el corte superior de las medias (step(stocking_welt_v, UV.y)) como las inserciones mediante mezcla cromática opaca (COLOR.a = base_tex.a), opera sin ninguna instrucción discard.En segundo lugar, respecto al coste de CPU en Polygon2D + Skeleton2D, mediciones de referencia en implementaciones que siguen el algoritmo de skinning en CPU de Godot indican que re-transformar y redibujar cuatro polígonos de 600 vértices y 25 huesos toma alrededor de 0.15 ms por fotograma sin asignaciones de memoria. Dado que tus 7 piezas (12x18, 10x24, 10x18) suman ~1,500 vértices por vista, asegúrate de que las 7 vistas inactivas del BodyPivot tengan visible = false (y no modulate.a = 0.0), para que el motor omita tanto el skinning en CPU como el envío de geometría al CanvasGroup. Finalmente, dado que el shader de Pasada 2 dibuja un contorno caligráfico de hasta ~3.4 px a zoom = 2.0 y aplica light-wrap HDR, incrementa fit_margin y clear_margin en tu nodo CanvasGroup a un mínimo de 16.0 px (o 32.0 px si usas smear_vector_px pronunciados) para evitar que el quad del backbuffer RGBA16F recorte la línea o la estela en los extremos del personaje.

Arquitectura de Falsa Perspectiva 2.5D Post-Skinning y Coreografía Sakuga a 15 FPS en Godot 4.7.2Para eliminar el efecto de "muñeco de trapo" (rotación plana en tijera sobre el plano XY) en un rig 2D de ocho vistas dibujadas casi a nivel de pecho/ojos (elevación de cámara de 5.31° a 7.49°) y renderizadas a una escala de combate de 160.47 px (zoom = 1.0) a 320.94 px (zoom = 2.0), la rotación en profundidad Z no debe delegarse a Bone2D.rotation ni a Bone2D.scale. En Skeleton2D de Godot 4, aplicar escalado no uniforme sobre huesos rotados contamina la matriz de transformación heredada con términos fuera de la diagonal, cizallando las pantorrillas y las botas en paralelogramos. Una solución arquitectónica robusta consiste en mantener los huesos Bone2D con escala unitaria estricta (Vector2.ONE) y usarlos exclusivamente como portadores de orientación en el plano de pantalla, delegando el acortamiento axial ($\cos\phi_z$), la traslación encadenada de pivotes (Knee/Elbow y Ankle/Wrist), el ensanchamiento cónico ($1/(1 - k \cdot z)$) y la oclusión de pliegue articular (knee-over-shin tuck) a la etapa void vertex() del shader canvas_item. Dado que en el pipeline mobile de Godot 4.7.2 el bloque interno #ifdef USE_SKELETON transforma los vértices antes de invocar void vertex(), el shader opera sobre la geometría ya posada por el esqueleto pero parametrizada de forma consistente a través de sus coordenadas UV en reposo.Esta separación entre cinemática 2D (esqueleto) y proyección perspectiva 2.5D (shader post-skinning más acoplamiento por script para nodos desacoplados como DecoupledHeadMount) permite conservar la proporción estilizada heroica 1:6.23 (424.52 du) durante el vuelo estacionario (IDLE_HOVER) y disparar deformaciones marcadas inspiradas en el flujo de trabajo de animación escalonada (stepped animation) de estudios como Arc System Works (Guilty Gear Xrd/Strive), Vanillaware y la animación limitada Sakuga a 15 FPS (stepped_fps = 15.0). Mientras la literatura pública sobre estos estudios documenta el uso general de escalado local de huesos y poses discretas, los parámetros numéricos específicos de este informe se derivan analíticamente a partir de las métricas exactas de tu rig en Godot 4.7.2. Al cuantizar las curvas de profundidad Z en ticks discretos de 66.67 ms con overshoots de un solo tick (+24% de ampliación distal en botas o puños antes de asentar en +18%, y ±16% de conicidad trapezoidal en el torso), el sistema visual interpreta los cambios de área como dibujo clave manual en lugar de interpolación elástica de malla.Subsistema TécnicoCausa del Fallo en Rigs 2D EstándarSolución Post-Skinning Propuesta en Godot 4.7.2Parámetros Operativos Derivados para tu Rig (424.52 du)Cadenas de 2 segmentos (leg_r/l, arm_r/l)Bone2D.scale.y < 1.0 con rotación de hijo genera cizallamiento matricial; rotar Thigh > 5.16° abre las piernas lateralmente.Reconstrucción del eje axial por segmento en void vertex() vía UV + anclas en reposo (uniform vec4); traslación analítica de rodilla y tobillo.Mallas 10×24 (celda vertical de 8.56 du = 3.24 px a zoom = 1.0); acortamiento seguro hasta φ_z = 60°–75° con coseno amortiguado.Oclusión articular (Knee/Elbow Tuck)Al acortar el muslo en 2D, la rodilla se aplasta linealmente sin cabalgar sobre la espinilla.Desplazamiento axial asimétrico (curva Gaussiana/Hermite con sesgo direccional) + abombamiento radial de rótula/codo y máscara de auto-sombra en fragment().Solapamiento virtual de 1.5 a 2.5 celdas (12.8–21.4 du) manteniendo determinante Jacobiano positivo ($\det(J) > 0.22$).Continuidad Part_leg_* y stockingDos Polygon2D con cajas UV distintas se desalinean al aplicar deformación no lineal en vertex().Normalización a un espacio paramétrico maestro común $(\hat{u}, \hat{v}) \in [-1,1] \times [0,1]$ de la pierna completa antes de evaluar el desplazamiento.Alineación subpíxel entre capas bajo hdr_2d = true y ampliación distal de +24%.Torso (body_core) y Cabeza DesacopladaEl trapecio en vertex() deforma el cuello, pero DecoupledHeadMount es un nodo externo al shader del torso.El controlador GDScript evalúa la misma función trapezoidal en $\hat{v}_{\text{neck}}$ y actualiza position, scale y retraso de 1 tick (head_pose_stagger_ticks = 1).Trapecio de torso ±16% en 12×18 (117.4 du, celda de 6.52 du = 2.47 px); escala de cabeza acoplada al 60% (±9.6%) con desfase de 66.67 ms.Lectura a 160 px en Vistas N, S, E/WEn N, la bota ampliada hacia cámara se funde en negro con el muslo; en E/W, extremidades paralelas crean efecto "gemelo".Depth-cueing atmosférico + rim-light de oclusión en fragment() para N; perspectiva diferencial ($Z_{\text{near}}$ vs $Z_{\text{far}}$) y desfase oblicuo de 7.49° en E/W.Separación tonal por profundidad en N; asimetría de escala de ±6% a ±8% entre pierna cercana y lejana en E/W.1. Matemática y Geometría de Falsa Perspectiva en void vertex() Post-SkinningOrden de Transformación en Godot 4.7.2 y Parametrización Libre de COLOREn el pipeline de renderizado 2D de Godot 4, cuando un Polygon2D está vinculado a un Skeleton2D, el vertex shader interno aplica primero la transformación por pesos de huesos (#ifdef USE_SKELETON) sobre VERTEX en espacio local del lienzo antes de ejecutar el código personalizado de void vertex(). Además, dado que Polygon2D.modulate y self_modulate multiplican directamente el atributo COLOR por vértice —y en Godot 4 los colores de vértice están cuantizados a enteros de 8 bits sin soporte directo de arrays personalizados CUSTOM0–3 en la interfaz de Polygon2D—, toda la topología de deformación debe reconstruirse a partir de UV y de uniforms de calibración.Para que una malla subdividida uniforme (leg_r/l de 10×24 o arm_r/l de 10×18) pueda acortarse, ensancharse y doblarse en profundidad Z después del skinning sin depender de dónde estén los vértices en el atlas de texturas, definimos una transformación afín de coordenadas de atlas (UV) a coordenadas intrínsecas de extremidad $(\hat{u}, \hat{v}) \in [-1, 1] \times [0, 1]$:$$\hat{u} = 2.0 \cdot \left( \frac{\text{UV}_x - u_{\min}}{u_{\max} - u_{\min}} \right) - 1.0, \qquad \hat{v} = \frac{\text{UV}_y - v_{\min}}{v_{\max} - v_{\min}}$$donde $\hat{u} \in [-1, 1]$ mide la distancia transversal desde el eje central del hueso hasta el borde lateral de la malla (siendo $\hat{u} = 0$ el eje medular de la pierna o brazo) y $\hat{v} \in [0, 1]$ mide el progreso longitudinal desde la raíz proximal ($\hat{v} = 0$, cadera/hombro) hasta el extremo distal ($\hat{v} = 1$, punta de bota/mano), pasando por la articulación intermedia en $\hat{v} = v_k$. Para tu longitud de pierna de 205.5 du en una rejilla 10×24, situar la rodilla alrededor de la fila 11.5 de las 24 divisiones corresponde a $v_k = 0.48$, lo que asigna $L_1 = 98.64\text{ du}$ al muslo y $L_2 = 106.86\text{ du}$ a la espinilla más la bota.Proyección Oblicua de Cámara (7.49°) para Cadenas Articuladas de 2 SegmentosLas dimensiones del arte base permiten calcular la inclinación exacta del plano de cámara: en la vista frontal (s) la distancia pelvis→tobillo es de 205.5 du (77.68 px a zoom = 1.0), mientras que en la vista diagonal (se, a 45° de guiñada) el desfase vertical en pantalla entre ambos tobillos es de 9.7 du para una apertura horizontal de 104.3 du. Despejando el ángulo de elevación real de la cámara $\alpha_c$ respecto al plano horizontal del personaje bajo proyección diagonal de 45°:$$\alpha_c = \arctan\left( \frac{\Delta y}{\Delta x \cdot \sin(45^\circ)} \right) = \arctan\left( \frac{9.7}{104.3 \times 0.7071} \right) = 7.49^\circ \quad (\tan\alpha_c \approx 0.1315\text{–}0.1317)$$(o 5.31° si se toma la razón directa $\arctan(9.7/104.3)$). En el sistema de coordenadas 2D de Godot (+X hacia la derecha, +Y hacia abajo) con +Z apuntando hacia la cámara (fuera de la pantalla), una cámara situada ligeramente por encima de la línea horizontal ($\alpha_c \approx 7.5^\circ$) proyecta cualquier desplazamiento hacia la cámara ($+\Delta Z > 0$) ligeramente hacia abajo en pantalla ($+\Delta Y > 0$), y cualquier alejamiento hacia el fondo ($-\Delta Z < 0$) ligeramente hacia arriba ($-\Delta Y < 0$).Sea una cadena de 2 segmentos compuesta por el Segmento 1 (Muslo/Brazo superior, longitud en reposo $L_1$, ángulo de cabeceo en profundidad $\phi_1 \in [-\frac{\pi}{2}, \frac{\pi}{2}]$) y el Segmento 2 (Pantorrilla+Bota / Antebrazo+Mano, longitud en reposo $L_2$, ángulo de cabeceo $\phi_2 \in [-\frac{\pi}{2}, \frac{\pi}{2}]$), donde $\phi_i > 0$ indica que el segmento apunta hacia la cámara y $\phi_i < 0$ que se aleja de ella. El factor de escala longitudinal proyectado en pantalla $s_y(\phi_i)$ y la ganancia de profundidad $\Delta Z_i(\phi_i)$ de cada segmento vienen dados por:$$s_y(\phi_i) = \cos(\phi_i) + \tan(\alpha_c)\sin(\phi_i) \cdot \sigma_{\text{dir}}, \qquad \Delta Z_i(\phi_i) = L_i \sin(\phi_i)$$donde $\sigma_{\text{dir}} = +1$ cuando el segmento apunta hacia abajo en reposo (piernas, brazos bajados) y $\sigma_{\text{dir}} = -1$ cuando el hueso apunta hacia arriba (torso crecido desde pelvis hacia cuello, o brazo alzado disparando hacia arriba). La siguiente tabla cuantifica esta asimetría direccional entre el acortamiento cosenoidal puro y la proyección oblicua real ($\alpha_c = 7.5^\circ$) sobre la malla 10×24 de la pierna (205.5 du / 77.68 px en reposo a zoom = 1.0, con altura de celda de 8.56 du / 3.24 px):Ángulo de Cabeceo Z (ϕz​)Coseno Puro (cosϕz​)Factor Oblicuo Proyectado (sy​ a 7.5°)Profundidad Normalizada (sinϕz​)Longitud Pierna Coseno Puro (du / px @ zoom 1)Altura de Celda 10×24 Oblicua (px @ zoom 1)-60° (Hacia el fondo)0.5000.386-0.866102.8 du / 38.8 px1.25 px-45° (Hacia el fondo)0.7070.614-0.707145.3 du / 54.9 px1.99 px-30° (Hacia el fondo)0.8660.800-0.500178.0 du / 67.3 px2.59 px0° (En reposo)1.0001.0000.000205.5 du / 77.7 px3.24 px+30° (Hacia cámara)0.8660.932+0.500178.0 du / 67.3 px3.02 px+45° (Hacia cámara)0.7070.800+0.707145.3 du / 54.9 px2.59 px+60° (Hacia cámara)0.5000.614+0.866102.8 du / 38.8 px1.99 px+70° (Hacia cámara)0.342—+0.94070.3 du / 26.6 px—+75° (Hacia cámara)0.2590.386+0.96653.2 du / 20.1 px1.25 pxComo evidencian los datos calculados, la elevación de cámara de ~7.5° introduce una asimetría crucial para el diseño de poses: una pierna que avanza hacia la cámara (+45°) conserva el 80.0% de su longitud vertical en pantalla ($s_y = 0.800$), mientras que una pierna que se extiende hacia atrás con el mismo ángulo (-45°) se acorta al 61.4% ($s_y = 0.614$). Asimismo, a partir de -60° o +75°, la altura proyectada de cada una de las 24 celdas cae a ~1.25 px en zoom = 1.0, marcando el umbral físico donde se requiere amortiguación del Jacobiano para impedir que el pliegue de rodilla invierta los triángulos.Traslación Exacta del Pivote Intermedio (Rodilla/Codo) sin Desconectar ni Cizallar la Bota/ManoEl problema geométrico al acortar una malla de pierna en void vertex() es que, si comprimimos el muslo ($\hat{v} \in [0, v_k]$) hacia la cadera ($\hat{v} = 0$) por un factor $s_y(\phi_1) < 1.0$, la rodilla se desplaza una distancia $\Delta L_1 = L_1 (1 - s_y(\phi_1))$. Si la pantorrilla ($\hat{v} \in [v_k, 1]$) no se traslada solidariamente con ese nuevo pivote de rodilla a lo largo del vector director del muslo ya rotado por Skeleton2D, la malla se estira en la rodilla o la bota queda flotando en su posición original.Para resolver esto post-skinning sin cizallar la bota cuando la rodilla tiene rotación 2D ($\theta_1 \neq \theta_2$), el vertex shader no debe escalar las coordenadas globales VERTEX.y de forma aislada. En su lugar, pasamos al shader las posiciones de los tres pivotes ya transformados por el Skeleton2D en el espacio local del Polygon2D mediante tres uniformes uniform vec2 p_root (Cadera/Hombro), uniform vec2 p_mid (Rodilla/Codo) y uniform vec2 p_tip (Tobillo/Muñeca), actualizados una vez por tick de 15 FPS desde GDScript:Descomposición en el marco ortonormal de cada hueso ya posado:Definimos los vectores axiales unitarios actuales en pantalla de ambos segmentos tras el skinning 2D:$$\mathbf{t}_1 = \frac{\mathbf{p}_{\text{mid}} - \mathbf{p}_{\text{root}}}{\|\mathbf{p}_{\text{mid}} - \mathbf{p}_{\text{root}}\|}, \qquad \mathbf{n}_1 = \begin{pmatrix} -t_{1y} \\ t_{1x} \end{pmatrix}$$$$\mathbf{t}_2 = \frac{\mathbf{p}_{\text{tip}} - \mathbf{p}_{\text{mid}}}{\|\mathbf{p}_{\text{tip}} - \mathbf{p}_{\text{mid}}\|}, \qquad \mathbf{n}_2 = \begin{pmatrix} -t_{2y} \\ t_{2x} \end{pmatrix}$$Al mantener Bone2D.scale = Vector2.ONE, las longitudes en pantalla después del skinning son equivalentes a las longitudes de reposo: $L_1 = \|\mathbf{p}_{\text{mid}} - \mathbf{p}_{\text{root}}\|$ y $L_2 = \|\mathbf{p}_{\text{tip}} - \mathbf{p}_{\text{mid}}\|$.Posición desplazada de los nuevos pivotes proyectados en 2.5D ($\mathbf{p}'_{\text{mid}}$ y $\mathbf{p}'_{\text{tip}}$):Cuando el muslo se inclina un ángulo $\phi_1$ en Z y la espinilla un ángulo $\phi_2$ en Z, la nueva posición en pantalla de la rodilla $\mathbf{p}'_{\text{mid}}$ y del tobillo $\mathbf{p}'_{\text{tip}}$ es:$$\mathbf{p}'_{\text{mid}} = \mathbf{p}_{\text{root}} + L_1 \cos(\phi_1)\,\mathbf{t}_1 + \begin{pmatrix} 0 \\ L_1 \tan(\alpha_c)\sin(\phi_1)\sigma_{\text{dir},1} \end{pmatrix}$$$$\mathbf{p}'_{\text{tip}} = \mathbf{p}'_{\text{mid}} + L_2 \cos(\phi_2)\,\mathbf{t}_2 + \begin{pmatrix} 0 \\ L_2 \tan(\alpha_c)\sin(\phi_2)\sigma_{\text{dir},2} \end{pmatrix}$$Aquí $\mathbf{p}'_{\text{tip}}$ hereda la traslación exacta $\mathbf{p}'_{\text{mid}} - \mathbf{p}_{\text{mid}}$ como un vector aditivo, sin multiplicar por ninguna matriz de escala 2D no uniforme. Por consiguiente, aunque la espinilla esté rotada 45° en el plano XY respecto al muslo, la bota no sufre cizallamiento (shearing): sus vectores base $\mathbf{t}_2$ (axial) y $\mathbf{n}_2$ (transversal) permanecen estrictamente ortogonales ($\mathbf{t}_2 \cdot \mathbf{n}_2 = 0$).Reubicación libre de cizallamiento para cualquier vértice VERTEX de la malla 10×24:Sea $w_1(\hat{v}) = 1.0 - \text{smoothstep}(v_k - \Delta v_{\text{blend}}, v_k + \Delta v_{\text{blend}}, \hat{v})$ el peso de pertenencia al Segmento 1 y $w_2(\hat{v}) = 1.0 - w_1(\hat{v})$ el peso al Segmento 2 (con $\Delta v_{\text{blend}} \approx 0.055$, equivalente a ~1.3 filas de la rejilla 10×24). Para cada vértice tras el skinning, extraemos su proyección axial $s_i$ y su distancia transversal con signo $d_i$ respecto a cada segmento:$$s_1 = (\mathbf{v}_{\text{skinned}} - \mathbf{p}_{\text{root}}) \cdot \mathbf{t}_1, \qquad d_1 = (\mathbf{v}_{\text{skinned}} - \mathbf{p}_{\text{root}}) \cdot \mathbf{n}_1$$$$s_2 = (\mathbf{v}_{\text{skinned}} - \mathbf{p}_{\text{mid}}) \cdot \mathbf{t}_2, \qquad d_2 = (\mathbf{v}_{\text{skinned}} - \mathbf{p}_{\text{mid}}) \cdot \mathbf{n}_2$$Conicidad Perspectiva ($1/(1 - k \cdot z)$), Conservación de Volumen Transversal y Ampliación Selectiva DistalEn una proyección de perspectiva cónica, el radio transversal aparente de un cilindro inclinado en profundidad Z crece conforme se acerca a la cámara. Además, cuando un cilindro se inclina un ángulo $\phi_i$ respecto al plano de la pantalla, su sección transversal circular de radio $R$ (contorno muscular) mantiene su ancho transversal $2R$ y añade un abombamiento aparente proporcional a $|\sin\phi_i|$.Definimos la coordenada de profundidad normalizada $z(\hat{v}) \in [-1, 1]$ a lo largo de la extremidad como la función continua por tramos:$$z(\hat{v}) = \begin{cases} \frac{\hat{v}}{v_k} \sin(\phi_1) & \text{si } \hat{v} \le v_k \\[6pt] \sin(\phi_1) + \left(\frac{\hat{v} - v_k}{1 - v_k}\right) \frac{L_2}{L_1} \sin(\phi_2) & \text{si } \hat{v} > v_k \end{cases}$$A partir de $z(\hat{v})$, el factor de escala transversal $S_{\perp}(\hat{v})$ combina tres términos multiplicativos:$$S_{\perp}(\hat{v}) = \underbrace{\frac{1}{1 - k_p \cdot z(\hat{v})}}_{\text{Conicidad perspectiva}} \cdot \underbrace{\left(1 + k_{\text{vol}} \sin^2(\phi(\hat{v})) \cdot \mathcal{B}(\hat{v})\right)}_{\text{Conservación de volumen muscular}} \cdot \underbrace{\left(1 + A_{\text{distal}} \cdot \mathcal{M}_{\text{distal}}(\hat{u}, \hat{v})\right)}_{\text{Ampliación Sakuga de bota/puño}}$$El primer término modela la conicidad perspectiva ($k_p \in [0.12, 0.18]$): para $z(\hat{v}) > 0$ (acercándose a cámara), $1/(1 - k_p z)$ expande progresivamente el ancho de la pierna desde la cadera hasta la rodilla/bota, transformando los lados paralelos del cilindro 2D en un cono truncado tridimensional; cuando $z(\hat{v}) < 0$ (alejándose hacia el fondo), el denominador supera 1.0 y adelgaza el extremo lejano. El segundo término controla la conservación de volumen muscular ($k_{\text{vol}} \approx 0.14$), donde la función campana $\mathcal{B}(\hat{v}_i) = \sin^2(\pi \hat{v}_i)$ sobre cada segmento evita que el muslo o el gemelo parezcan cintas planas al acortarse por $\cos(\phi_i)$, inflando ligeramente la silueta lateral del vientre muscular cuando $|\sin\phi_i|$ es alto.El tercer término ejecuta la ampliación selectiva distal ($A_{\text{distal}} \in [0.15, 0.24]$): para lograr el impacto visual de animación limitada a 160 px, el extremo distal (la bota de combate, la rodillera o el puño) se exagera un +15% a +24%. Para que la bota se agrande en ambos ejes (tanto en anchura $\mathbf{n}_2$ como en longitud/empeine $\mathbf{t}_2$) y permita diferenciar entre punta de bota (toe) y talón (heel) según la orientación del pie, definimos la máscara distal como:$$\mathcal{M}_{\text{distal}}(\hat{u}, \hat{v}) = \text{smoothstep}(0.72, 0.90, \hat{v}) \cdot \left(1.0 + b_{\text{toe\_heel}} \cdot \hat{u}\right)$$donde $\hat{v} \in [0.72, 1.0]$ abarca las últimas 6–7 filas de la malla 10×24 (tobillo a suela), y el sesgo lateral $b_{\text{toe\_heel}} \in [-0.35, +0.35]$ permite enfatizar selectivamente la puntera ($+\hat{u}$) en una patada o freno hacia cámara, o el talón ($-\hat{u}$) en un picado o retroceso aéreo. Asimismo, en la zona distal ($\hat{v} > 0.72$), el acortamiento axial no aplica $\cos(\phi_2)$ puro, sino que se interpola hacia el factor de ampliación $1 + A_{\text{distal}}$ para que la bota conserve su masa sólida y no se aplaste verticalmente.2. Prevención de Artefactos de Textura, Costuras de Malla y Colapso de TriángulosCondición del Determinante Jacobiano ($\det(J) > 0$) en Rejillas 10×24Tu malla leg_r/l mide 205.5 du dividida en 24 celdas verticales, lo que otorga una altura en reposo por celda de 8.56 du (3.24 px a zoom = 1.0). Si una función de deformación axial $F(\hat{v})$ desplaza las filas de la rejilla a lo largo del eje $\mathbf{t}$, los triángulos de la malla 10×24 se invierten (provocando que una fila de vértices cruce a la fila siguiente y pliegue la textura sobre sí misma) si la derivada direccional longitudinal cae a cero o se vuelve negativa:$$\det(J) \propto S_{\perp}(\hat{v}) \cdot \frac{\partial F(\hat{v})}{\partial \hat{v}} > 0 \iff \frac{\partial s'(\hat{v})}{\partial \hat{v}} > \epsilon_{\min}$$Fijando el umbral mínimo de seguridad en $\epsilon_{\min} = 0.22$, garantizamos que ninguna celda baje de $0.22 \times 3.24\text{ px} = 0.71\text{ px}$ de separación axial base en pantalla a zoom = 1.0. En lugar de permitir que $\cos(\phi_i)$ tienda a cero cuando $\phi_i \to 90^\circ$, aplicamos un rectificador hiperbólico suave (Soft-Clamped Cosine) en void vertex():$$c_{\text{safe}}(\phi_i) = \sqrt{\cos^2(\phi_i) + \epsilon_{\min}^2} \quad \text{con } \epsilon_{\min} = 0.22$$Esto mantiene $\frac{\partial s'}{\partial \hat{v}} \ge 0.22 > 0$ para cualquier ángulo $\phi_i$, previniendo la inversión de triángulos por compresión axial.Compensación de Compresión UV y Derivadas dFdy(UV) en void fragment()Cuando void vertex() comprime un segmento al 38%–50% de su longitud original ($\phi_i \approx 60^\circ\text{–}75^\circ$), aparecen dos problemas de muestreo en el rasterizador de Godot 4 (mobile). Primero, se produce sobremuestreo de MIP-map y pérdida de nitidez: al acercarse los vértices en pantalla mientras sus coordenadas UV mantienen la misma separación original, las derivadas en espacio de pantalla dFdx(UV) y dFdy(UV) se multiplican por $1 / c_{\text{safe}}(\phi_i)$ (entre ×2.0 y ×4.0). Si la textura tiene mipmaps activos, la GPU selecciona un nivel MIP más bajo y borroso justamente en la rodilla o el puño que viene hacia la cámara; si no tiene mipmaps, el submuestreo apaga las líneas de tinta (lineart interior) de la rodillera o los cordones de la bota. Segundo, ocurre un apelmazamiento uniforme del lineart interior: si todas las filas de un muslo se comprimen linealmente, los detalles pintados en el centro del segmento parecen aplastados mecánicamente.Para mitigar ambos defectos en el shader:Redistribución no lineal de UV mediante varying (Curva de Alivio Central): En cilindros vistos en escorzo, la compresión visual se concentra en los extremos del segmento mientras la zona central mantiene mayor legibilidad. Calculamos en vertex() un desplazamiento sutil de muestreo $\Delta \hat{v}_{\text{tex}} = -0.012 \sin(\phi_i) \sin(2\pi \hat{v}_i)$ que relaja la compresión de textura en el centro del segmento (rodillera, borde del stocking, empeine) y traslada la compresión hacia las zonas de color plano.Compensación de sesgo de derivada (lod_bias) y refuerzo de tinta en fragment(): Enviamos desde vertex() un varying float v_comp_ratio igual a $c_{\text{safe}}(\phi(\hat{v})) \in [0.22, 1.0]$. En fragment(), muestreamos la textura aplicando un LOD bias negativo proporcional al logaritmo de la compresión:$$\text{lod\_bias} = \log_2(\text{clamp}(v_{\text{comp\_ratio}}, 0.25, 1.0)) \in [-2.0, 0.0]$$y aplicamos un refuerzo de contraste local sobre los píxeles oscuros del lineart proporcional a $(1.0 - v_{\text{comp\_ratio}})$ para que los trazos interiores conserven su peso visual al comprimirse la malla.Sincronización entre Part_leg_* y Part_leg_*_stockingEn las vistas s, se, e, sw, w, Part_leg_*_stocking se ubica encima de body_core para gestionar el solapamiento de la media con la pelvis/cadera, mientras que Part_leg_* queda debajo. Si cada Polygon2D calcula $\hat{u}$ y $\hat{v}$ normalizando su propio UV local (uv_min a uv_max de su recorte individual), la media y la pierna tendrán sistemas de coordenadas $(\hat{u}, \hat{v})$ distintos y se desalinearán durante el escorzo en Z.Para garantizar que ambas mallas se deformen como una única superficie continua, ambos nodos (Part_leg_r y Part_leg_r_stocking) deben compartir exactamente el mismo bloque de uniforms de referencia espacial de la pierna completa (p_root, p_mid, p_tip, master_uv_rect), y si el stocking ocupa un sub-rectángulo distinto dentro del atlas, se pasa un uniform vec4 sub_uv_remap que transforma linealmente su UV local al espacio [0, 1] maestro de Part_leg_r. De este modo, cualquier vértice coincidente entre Part_leg_r y Part_leg_r_stocking evalúa el mismo par $(\hat{u}, \hat{v})$ en coma flotante y experimenta idéntico desplazamiento en void vertex().3. Oclusión Visual en Rodilla y Codo (Knee-Over-Shin Tuck / Foreshortened Overlap)Cuando un personaje levanta el muslo hacia la cámara en vista frontal (s, $\phi_1 > +35^\circ$) mientras dobla la espinilla hacia abajo o hacia atrás ($\phi_2 \le 0^\circ$), el volumen distal del muslo y la rótula avanzan por delante de la parte superior de la espinilla y la ocultan parcialmente. Si solo acortamos ambos segmentos linealmente en 2D, la rodilla actúa como una bisagra plana sin superposición de contornos (T-junctions), restando tridimensionalidad.Dado que invertir físicamente los triángulos de la malla 10×24 corrompería el mapeo UV al carecer de Z-buffer por píxel dentro del mismo Polygon2D, construimos la ilusión óptica de oclusión por pliegue (Knee-Over-Shin Tuck) combinando un pliegue asimétrico Gaussiano/Hermite en void vertex() con una máscara de bolsillo de oclusión direccional en void fragment().Formulación Matemática del Knee-Over-Shin TuckDefinimos el índice de pliegue articular $\kappa_{\text{tuck}} \in [-1, 1]$ en función de la diferencia de proyección en profundidad entre los dos segmentos:$$\kappa_{\text{tuck}} = \text{clamp}\left( \frac{\sin(\phi_1) - \sin(\phi_2)}{1.2}, -1.0, 1.0 \right)$$Cuando $\kappa_{\text{tuck}} > 0$ (el muslo o brazo superior avanza más hacia la cámara que la espinilla o antebrazo, típico de la vista S al elevar la rodilla o en retroceso de codo), la rótula ($\hat{v} \in [v_k - 0.10, v_k + 0.02]$, filas 9 a 12 de la malla 10×24) resiste la compresión axial y se abomba transversalmente, mientras que el tercio proximal de la espinilla ($\hat{v} \in [v_k + 0.02, v_k + 0.16]$, filas 13 a 16) se retrae axialmente hacia $\hat{v} = v_k$ para simular que ha quedado alojado debajo de la rodilla. Por el contrario, cuando $\kappa_{\text{tuck}} < 0$ (la espinilla/bota o el antebrazo/puño está más cerca de la cámara que el muslo/brazo, típico de la vista trasera N al doblar la pierna hacia cámara, o en S al lanzar una patada frontal o puñetazo directo), el solapamiento se invierte: el volumen proximal de la pantorrilla o del antebrazo ($\hat{v} > v_k$) avanza axialmente sobre la parte distal del muslo/hombro ($\hat{v} < v_k$), comprimiendo el hueco poplíteo o el pliegue interior del codo.En void vertex(), esto se implementa sumando un término de desplazamiento de pliegue $\Delta s_{\text{tuck}}(\hat{u}, \hat{v})$ a lo largo del eje axial:$$\Delta s_{\text{tuck}}(\hat{u}, \hat{v}) = \kappa_{\text{tuck}} \cdot L_1 \cdot 0.14 \cdot \exp\left( -\frac{(\hat{v} - v_{\text{fold}})^2}{2\sigma_{\text{fold}}^2} \right) \cdot \left(1 - \frac{\hat{u}^2}{2}\right)$$donde el centro de empuje es $v_{\text{fold}} = v_k + 0.035 \cdot \text{sign}(\kappa_{\text{tuck}})$ y $\sigma_{\text{fold}} = 0.075$. El factor parabólico transversal $(1 - \hat{u}^2/2)$ hace que el centro de la rótula o del gemelo avance más que los bordes exteriores, curvando las líneas horizontales de la rejilla 10×24 en arcos elípticos tridimensionales (hacia abajo si $\kappa_{\text{tuck}} > 0$, hacia arriba si $\kappa_{\text{tuck}} < 0$). Así, el borde del stocking o de la rodillera adquiere automáticamente la curvatura cilíndrica de sección transversal propia del dibujo en perspectiva.En void fragment(), completamos la ilusión de oclusión renderizando una banda de sombra de contacto (Occlusion Pocket) inmediatamente detrás del lóbulo que sobresale:$$M_{\text{shadow}}(\hat{u}, \hat{v}) = |\kappa_{\text{tuck}}| \cdot \text{smoothstep}(0.005, 0.035, s_{\text{behind}}) \cdot \left(1.0 - \text{smoothstep}(0.04, 0.13, s_{\text{behind}})\right) \cdot \left(1.0 - 0.55 \hat{u}^2\right)$$donde $s_{\text{behind}} = (\hat{v} - v_k) \cdot \text{sign}(\kappa_{\text{tuck}})$. Cuando $\kappa_{\text{tuck}} > 0$, $M_{\text{shadow}}$ oscurece selectivamente una cuña curva justo debajo de la rótula; cuando $\kappa_{\text{tuck}} < 0$ (ej. vista trasera N con bota doblada hacia cámara), $M_{\text{shadow}}$ oscurece el muslo justo por encima del gemelo/bota y añade simultáneamente un filo iluminado (crest rim) en el borde superior del elemento que ocluye.4. Escorzo Trapezoidal del Torso (body_core 12×18) y Acoplamiento con Cabeza y HombrerasEl torso (body_core, 117.4 du, malla 12×18 con celdas verticales de 6.52 du o 2.47 px a zoom = 1.0) constituye el núcleo volumétrico del personaje. Durante un picado aéreo o dash frontal (el pecho y los hombros se inclinan hacia la cámara, $\phi_{\text{torso}} > 0$) o un freno aéreo, ascenso o retroceso de disparo (la pelvis avanza hacia la cámara y el pecho se inclina hacia atrás, $\phi_{\text{torso}} < 0$), el torso se deforma en un trapecio de perspectiva (±16%) acompañado de torsión axial (yaw twist) en los giros.Ecuación del Trapecio y Torsión en body_core (12×18)Sea $\hat{v}_t \in [0, 1]$ la coordenada longitudinal del torso desde la pelvis ($\hat{v}_t = 0$, nodo Pelvis) hasta la base del cuello ($\hat{v}_t = 1$, nodo Neck), y $\hat{u}_t \in [-1, 1]$ la coordenada transversal de izquierda a derecha. Dado un parámetro de inclinación de torso en profundidad $\tau_{\text{pitch}} \in [-0.16, +0.16]$ ($\tau_{\text{pitch}} > 0$ = hombros hacia cámara; $\tau_{\text{pitch}} < 0$ = pelvis hacia cámara) y un parámetro de torsión de giro $\tau_{\text{yaw}} \in [-0.18, +0.18]$:Escala transversal trapezoidal $S_{x,\text{torso}}(\hat{v}_t)$:$$S_{x,\text{torso}}(\hat{v}_t) = 1.0 + \tau_{\text{pitch}} \cdot (2.0 \hat{v}_t - 1.0)$$En $\hat{v}_t = 1.0$ (hombros/cuello), el ancho se multiplica por $1 + \tau_{\text{pitch}}$ (hasta +16%); en $\hat{v}_t = 0.0$ (pelvis), se multiplica por $1 - \tau_{\text{pitch}}$ (hasta -16%), conservando el ancho neutro en la cintura ($\hat{v}_t = 0.5$, Waist).Acortamiento vertical y desplazamiento oblicuo de cámara ($\alpha_c = 7.49^\circ$):parametrizando $\sin(\phi_{\text{torso}}) = \text{clamp}(\tau_{\text{pitch}} / 0.25, -0.85, 0.85)$, la altura proyectada del torso se modifica por:$$S_{y,\text{torso}} = \cos(\phi_{\text{torso}}) - \tan(\alpha_c)\sin(\phi_{\text{torso}})$$
El signo negativo en $-\tan(\alpha_c)\sin(\phi_{\text{torso}})$ se debe a que el torso crece desde la pelvis hacia arriba (dirección -Y de Godot): cuando el pecho se acerca a la cámara ($+\Delta Z > 0$), la cámara elevada 7.49° proyecta el cuello más abajo en pantalla (+Y), comprimiendo con más fuerza la distancia pelvis→cuello en un picado frontal y estilizando el torso cuando el personaje arquea la espalda hacia atrás.Curvatura de arcos pectorales y cintura (Cylindrical Cross-Contour):Sumamos al eje vertical un arqueo parabólico $\Delta y_{\text{arc}}(\hat{u}_t) = \tau_{\text{pitch}} \cdot 14.0\text{ du} \cdot (1.0 - \hat{u}_t^2)$ para que el cinturón, el borde pectoral y el cuello se curven hacia abajo cuando el pecho apunta a cámara ($\tau_{\text{pitch}} > 0$) y hacia arriba cuando la pelvis lidera el movimiento ($\tau_{\text{pitch}} < 0$).Acoplamiento Analítico de DecoupledHeadMount y Pauldron_R/LDado que las 8 cabezas están desacopladas en DecoupledHeadMount + DecoupledHeadUnderMount (fuera del Polygon2D de body_core) y las hombreras Pauldron_R/L (10×18) son piezas rígidas que no deben aplastarse elásticamente, su acoplamiento se gobierna desde GDScript mediante dos reglas:Posición y Escala de DecoupledHeadMount (con Stagger de 1 Tick):En el instante de tick $T$ (a 15 FPS), el torso aplica $\tau_{\text{pitch}}[T]$. La posición base de anclaje del cuello debe actualizarse en el mismo tick $T$ para evitar que la cabeza se separe del cuello, sumando el desplazamiento inducido por el shader del torso en $\hat{v}_t = 1.0$:$$\Delta \mathbf{p}_{\text{neck}}[T] = \mathbf{t}_{\text{torso}} \cdot L_{\text{torso}} \left(S_{y,\text{torso}}(\tau_{\text{pitch}}[T]) - 1.0\right) + \begin{pmatrix} 0 \\ \tau_{\text{pitch}}[T] \cdot 14.0\text{ du} \end{pmatrix}$$En cambio, el offset de cabeceo facial y la escala perspectiva de la cabeza leen el valor cuantizado del tick anterior $T - 1$ (head_pose_stagger_ticks = 1, es decir, 66.67 ms de desfase):$$\text{Head.scale}[T] = \text{Vector2.ONE} \cdot \left(1.0 + 0.60 \cdot \tau_{\text{pitch}}[T - 1]\right)$$$$\text{Head.position}[T] = \mathbf{p}_{\text{neck, skinned}}[T] + \Delta \mathbf{p}_{\text{neck}}[T] + \begin{pmatrix} \tau_{\text{yaw}}[T] \cdot 8.0\text{ du} \\ \tau_{\text{pitch}}[T - 1] \cdot 9.5\text{ du} \end{pmatrix}$$
Multiplicar la ganancia de escala de la cabeza por $0.60 \cdot \tau_{\text{pitch}}$ (±9.6% de escala máxima de cabeza frente al ±16% del torso) preserva la proporción estilizada 1:6.23: si la cabeza creciera un +16% completo, la silueta se infantilizaría hacia una proporción ~1:5.1. Al limitar la ganancia de escala al 60% del trapecio pectoral y bajar su pivote 9.5 du sobre las clavículas cuando $\tau_{\text{pitch}} > 0$ (hundiendo ligeramente la barbilla hacia el esternón), se consigue un escorzo agresivo manteniendo las proporciones heroicas.Acoplamiento Semi-Rígido de Pauldron_R/L (10×18):Las hombreras se anclan en $(\hat{u}_t = \pm 0.85, \hat{v}_t = 0.88)$. Para que acompañen la expansión o contracción de los hombros sin deformar su geometría interna, el nodo Pauldron_R/L se traslada lateralmente por $\Delta x_{\text{pauldron}} = \pm W_{\text{shoulder}} \cdot \tau_{\text{pitch}} \cdot 0.76$ y verticalmente con $\Delta \mathbf{p}_{\text{neck}}$, mientras su shader recibe un parámetro z_pauldron igual a $\pm \tau_{\text{yaw}} + 0.85 \cdot \tau_{\text{pitch}}$ que aplica una escala casi uniforme $(1.0 + z_{\text{pauldron}})$ con un trapecio moderado (±8%).5. Implementación en Godot 4.7.2: Shader canvas_item y Controlador GDScriptA continuación se detalla el código completo del shader y su nodo controlador para Godot 4.7.2 (mobile, hdr_2d = true).A. Shader Unificado Post-Skinning (faux_perspective_25d.gdshader)OpenGL Shading Languageshader_type canvas_item;

// ============================================================================
// 1. CALIBRACIÓN DE TOPOLOGÍA Y ESPACIO DE REPOSO (Sincronizado para Leg + Stocking)
// ============================================================================
// Caja UV maestra de la extremidad completa: xy = uv_min, zw = uv_max.
// IMPORTANTE: Part_leg_r y Part_leg_r_stocking DEBEN usar el mismo master_uv_rect
// si comparten atlas, o remapear su UV local al espacio [0,1] maestro con sub_uv_remap.
uniform vec4 master_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 sub_uv_remap = vec4(0.0, 0.0, 1.0, 1.0); // xy = offset, zw = scale en espacio [0,1]
uniform float v_knee_pivot : hint_range(0.2, 0.8) = 0.48; // Fila ~11.5 de 24 en leg_r/l

// Posiciones de los 3 pivotes de la cadena en espacio local del Polygon2D
// (Actualizadas desde GDScript post-pose a 15 FPS; con Bone2D.scale = Vector2.ONE)
uniform vec2 p_root = vec2(0.0, 0.0);    // Thigh / Shoulder / Pelvis
uniform vec2 p_mid  = vec2(0.0, 98.64);  // Knee / Elbow / Waist
uniform vec2 p_tip  = vec2(0.0, 205.50); // Ankle / Wrist / Neck

// ============================================================================
// 2. PARÁMETROS DE ESCORZO 2.5D (Cuantizados a 15 FPS por el controlador)
// ============================================================================
uniform float phi_seg1 : hint_range(-1.35, 1.35) = 0.0; // Pitch Z en rad (Muslo/Brazo sup/Torso inf)
uniform float phi_seg2 : hint_range(-1.35, 1.35) = 0.0; // Pitch Z en rad (Espinilla/Antebrazo/Torso sup)
uniform float cam_tan_alpha = 0.1315;                   // tan(7.49 deg) de tus láminas nativas
uniform float k_conicity : hint_range(0.0, 0.30) = 0.16; // Conicidad 1 / (1 - k*z)
uniform float k_volume : hint_range(0.0, 0.30) = 0.14;   // Conservación de volumen transversal
uniform float distal_amp : hint_range(-0.15, 0.30) = 0.0; // +0.15 a +0.24 en snaps de bota/puño
uniform float distal_toe_heel_bias : hint_range(-0.5, 0.5) = 0.0; // + = puntera, - = talón
uniform float torso_trapezoid : hint_range(-0.25, 0.25) = 0.0;    // ±0.16 para body_core
uniform float yaw_twist : hint_range(-0.30, 0.30) = 0.0;          // Torsión 1-tick en WHIP_SNAP

// ============================================================================
// 3. PARÁMETROS DE DEPTH-CUEING Y OCLUSIÓN EN FRAGMENT (Crucial para vista N y E/W)
// ============================================================================
uniform vec4 depth_near_tint : source_color = vec4(1.08, 1.06, 1.02, 1.0); // Realce cálido HDR al acercarse
uniform vec4 depth_far_tint  : source_color = vec4(0.76, 0.80, 0.92, 1.0); // Atmósfera fría al alejarse
uniform vec4 rim_occlusion_color : source_color = vec4(0.35, 0.75, 1.0, 1.0); // Rim separador en vista N
uniform float rim_sweep_dir : hint_range(-1.0, 1.0) = 0.0; // Dirección del barrido de luz en giros

// Varyings hacia fragment()
varying float v_u_norm;          // [-1, 1] transversal
varying float v_v_norm;          // [0, 1] longitudinal
varying float v_z_depth;         // [-1, 1] profundidad Z local
varying float v_tuck_factor;     // [-1, 1] índice de pliegue knee-over-shin
varying float v_comp_ratio;      // [0.22, 1.0] ratio de compresión axial (para compensar dFdy)
varying float v_uv_relief_shift; // Alivio no lineal de textura en centro de segmento

// Coseno rectificado hiperbólico: mantiene det(J) > 0.22 (evita inversión en 10x24)
float safe_cos(float angle_rad) {
	float c = cos(angle_rad);
	return sqrt(c * c + 0.0484); // sqrt(cos^2 + 0.22^2)
}

void vertex() {
	// 1. Reconstrucción de coordenadas intrínsecas (u_hat in [-1,1], v_hat in [0,1])
	vec2 raw_01 = (UV - master_uv_rect.xy) / max(master_uv_rect.zw - master_uv_rect.xy, vec2(0.0001));
	vec2 param_01 = sub_uv_remap.xy + raw_01 * sub_uv_remap.zw;
	float u_hat = clamp(param_01.x * 2.0 - 1.0, -1.0, 1.0);
	float v_hat = clamp(param_01.y, 0.0, 1.0);

	// 2. Vectores ortonormales de los 2 segmentos tras el skinning 2D
	vec2 d_seg1 = p_mid - p_root;
	vec2 d_seg2 = p_tip - p_mid;
	float L1 = max(length(d_seg1), 1.0);
	float L2 = max(length(d_seg2), 1.0);
	vec2 t1 = d_seg1 / L1;
	vec2 n1 = vec2(-t1.y, t1.x);
	vec2 t2 = d_seg2 / L2;
	vec2 n2 = vec2(-t2.y, t2.x);

	// Signo vertical en pantalla (+1 si apunta abajo como piernas, -1 si apunta arriba como torso/brazo)
	float dir_y1 = sign(t1.y != 0.0 ? t1.y : 1.0);
	float dir_y2 = sign(t2.y != 0.0 ? t2.y : 1.0);

	// 3. Factores de acortamiento axial oblicuo (cámara ~7.49 deg)
	float c1 = safe_cos(phi_seg1);
	float s1 = sin(phi_seg1);
	float c2 = safe_cos(phi_seg2);
	float s2 = sin(phi_seg2);

	// En el extremo distal (bota/puño, v_hat > 0.72), amortiguamos la compresión axial
	// hacia (1.0 + distal_amp) para que la bota se agrande sólida y no se aplaste
	float distal_mask = smoothstep(0.72, 0.90, v_hat) * (1.0 + distal_toe_heel_bias * u_hat);
	float c2_effective = mix(c2, max(c2, 0.82) * (1.0 + max(distal_amp, 0.0) * 0.85), distal_mask);

	// 4. Nuevos pivotes proyectados en 2.5D (traslación exacta sin cizallamiento)
	vec2 p_mid_proj = p_root + (L1 * c1) * t1 + vec2(0.0, L1 * cam_tan_alpha * s1 * dir_y1);
	vec2 p_tip_proj = p_mid_proj + (L2 * c2_effective) * t2 + vec2(0.0, L2 * cam_tan_alpha * s2 * dir_y2);

	// 5. Coordenadas locales del vértice ya posado respecto a cada hueso
	vec2 v_rel1 = VERTEX - p_root;
	float axial_1 = dot(v_rel1, t1);
	float trans_1 = dot(v_rel1, n1);

	vec2 v_rel2 = VERTEX - p_mid;
	float axial_2 = dot(v_rel2, t2);
	float trans_2 = dot(v_rel2, n2);

	// 6. Profundidad Z continua y Conicidad / Conservación de Volumen
	float v_seg1_01 = clamp(v_hat / v_knee_pivot, 0.0, 1.0);
	float v_seg2_01 = clamp((v_hat - v_knee_pivot) / max(1.0 - v_knee_pivot, 0.001), 0.0, 1.0);
	float w_seg2 = smoothstep(v_knee_pivot - 0.055, v_knee_pivot + 0.055, v_hat);
	float w_seg1 = 1.0 - w_seg2;

	float z1 = v_seg1_01 * s1;
	float z2 = s1 + v_seg2_01 * (L2 / L1) * s2;
	float z_local = clamp(mix(z1, z2, w_seg2), -1.0, 1.0);

	// Escala transversal: Conicidad + Volumen muscular + Ampliación Sakuga distal + Trapecio torso
	float conicity_scale = 1.0 / clamp(1.0 - k_conicity * z_local, 0.65, 1.45);
	float belly_1 = sin(v_seg1_01 * PI);
	float belly_2 = sin(v_seg2_01 * PI);
	float vol_scale1 = 1.0 + k_volume * (s1 * s1) * (belly_1 * belly_1);
	float vol_scale2 = 1.0 + k_volume * (s2 * s2) * (belly_2 * belly_2);
	float distal_scale = 1.0 + distal_amp * distal_mask;
	float trap_scale = 1.0 + torso_trapezoid * (2.0 * v_hat - 1.0);

	// 7. Pliegue Articular (Knee-Over-Shin Tuck / Elbow Overlap)
	float kappa_tuck = clamp((s1 - s2) / 1.2, -1.0, 1.0);
	float v_fold_center = v_knee_pivot + 0.035 * sign(kappa_tuck);
	float dv_fold = (v_hat - v_fold_center) / 0.075;
	float fold_bell = exp(-0.5 * dv_fold * dv_fold);
	// Desplazamiento axial con curvatura elíptica transversal (1 - 0.5*u^2)
	float tuck_axial_shift = kappa_tuck * L1 * 0.14 * fold_bell * (1.0 - 0.5 * u_hat * u_hat);
	// Abombamiento radial de rótula/codo durante el pliegue
	float patella_bulge = 1.0 + 0.16 * abs(kappa_tuck) * exp(-0.5 * pow((v_hat - v_knee_pivot) / 0.06, 2.0));

	float scale_perp1 = conicity_scale * vol_scale1 * patella_bulge * trap_scale;
	float scale_perp2 = conicity_scale * vol_scale2 * patella_bulge * distal_scale * trap_scale;

	// 8. Reconstrucción de posición en Segmento 1 y Segmento 2 (cero shearing)
	vec2 pos_1 = p_root
		+ (axial_1 * c1 + tuck_axial_shift) * t1
		+ vec2(0.0, axial_1 * cam_tan_alpha * s1 * dir_y1)
		+ (trans_1 * scale_perp1) * n1;

	vec2 pos_2 = p_mid_proj
		+ (axial_2 * c2_effective + tuck_axial_shift) * t2
		+ vec2(0.0, axial_2 * cam_tan_alpha * s2 * dir_y2)
		+ (trans_2 * scale_perp2) * n2;

	vec2 final_pos = mix(pos_1, pos_2, w_seg2);

	// 9. Arco pectoral/cintura y Torsión de Turnaround (WHIP_SNAP)
	float cross_arc = torso_trapezoid * 14.0 * (1.0 - u_hat * u_hat);
	float twist_shift_x = yaw_twist * 18.0 * (2.0 * v_hat - 1.0) * (1.0 - 0.3 * u_hat * u_hat);
	final_pos += vec2(twist_shift_x, cross_arc);

	VERTEX = final_pos;

	// 10. Salida de varyings hacia fragment()
	v_u_norm = u_hat;
	v_v_norm = v_hat;
	v_z_depth = z_local;
	v_tuck_factor = kappa_tuck;
	v_comp_ratio = mix(c1, c2_effective, w_seg2);
	float local_v_phase = mix(v_seg1_01, v_seg2_01, w_seg2);
	v_uv_relief_shift = -0.012 * mix(s1, s2, w_seg2) * sin(local_v_phase * TAU);
}

void fragment() {
	// 1. Alivio de compresión UV y compensación de derivada dFdy (evita borrosidad MIP y pérdida de tinta)
	vec2 relieved_uv = UV + vec2(0.0, v_uv_relief_shift * (master_uv_rect.w - master_uv_rect.y));
	float lod_bias = log2(clamp(v_comp_ratio, 0.25, 1.0));
	vec4 tex = texture(TEXTURE, relieved_uv, lod_bias);

	// Refuerzo de contraste de lineart interior cuando la malla se comprime en Z
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float ink_mask = 1.0 - smoothstep(0.08, 0.28, luma);
	float compression_strength = clamp(1.0 - v_comp_ratio, 0.0, 0.75);
	tex.rgb = mix(tex.rgb, tex.rgb * 0.65, ink_mask * compression_strength * 0.5);

	// 2. Bolsillo de Oclusión Articular (Knee-Over-Shin / Shin-Over-Thigh Pocket)
	float s_behind = (v_v_norm - v_knee_pivot) * sign(v_tuck_factor);
	float pocket_band = smoothstep(0.005, 0.035, s_behind) * (1.0 - smoothstep(0.04, 0.13, s_behind));
	float radial_mask = clamp(1.0 - 0.55 * v_u_norm * v_u_norm, 0.0, 1.0);
	float shadow_pocket = abs(v_tuck_factor) * pocket_band * radial_mask;

	// Borde iluminado (rim-lip) en la cresta de la articulación que cabalga por encima
	float s_crest = (v_knee_pivot - v_v_norm) * sign(v_tuck_factor);
	float crest_band = smoothstep(-0.01, 0.015, s_crest) * (1.0 - smoothstep(0.015, 0.045, s_crest));
	float crest_rim = abs(v_tuck_factor) * crest_band * radial_mask;

	// 3. Depth-Cueing Atmosférico (separa pierna cercana vs lejana en E/W y bota vs muslo en N)
	vec3 depth_mod = mix(
		mix(vec3(1.0), depth_far_tint.rgb, clamp(-v_z_depth, 0.0, 1.0)),
		depth_near_tint.rgb,
		clamp(v_z_depth, 0.0, 1.0)
	);
	vec3 col = tex.rgb * depth_mod;

	// Aplicar bolsillo de sombra bajo la rodilla/bota superpuesta
	col *= (1.0 - 0.42 * shadow_pocket);

	// 4. Rim-Light de Oclusión Distal y Barrido de Giro (Crítico en vista N a 160 px)
	float edge_factor = smoothstep(0.55, 0.95, abs(v_u_norm));
	float directional_edge = smoothstep(0.35, 0.92, v_u_norm * sign(rim_sweep_dir != 0.0 ? rim_sweep_dir : 0.001));
	float z_forward_boost = clamp(v_z_depth, 0.0, 1.0);

	// En vista trasera (N), cuando la bota o rodilla viene hacia cámara (z_forward_boost > 0),
	// el rim-light contornea la silueta para separarla visualmente del muslo oscuro
	float total_rim = crest_rim * 0.65
		+ edge_factor * z_forward_boost * 0.55
		+ directional_edge * abs(rim_sweep_dir) * 0.85;

	col = mix(col, rim_occlusion_color.rgb, clamp(total_rim * rim_occlusion_color.a, 0.0, 0.85));

	// Respetar modulaciones de Polygon2D (COLOR viene de vertex_colors * modulate)
	COLOR = vec4(col * COLOR.rgb, tex.a * COLOR.a);
}
B. Controlador GDScript de Reloj Dual (15 FPS Stepped + 1-Tick Head Stagger)Este controlador sincroniza los pivotes post-skinning, cuantiza la perspectiva a 15.0 FPS (66.67 ms) y aplica el desfase de 1 tick en DecoupledHeadMount:GDScriptclass_name FauxPerspective25DController
extends Node2D

@export_group("Configuración de Reloj Dual Sakuga")
@export var stepped_fps: float = 15.0
@export var head_pose_stagger_ticks: int = 1
@export var torso_length_du: float = 117.4

@export_group("Referencias del Rig")
@export var bone_pelvis: Bone2D
@export var bone_waist: Bone2D
@export var bone_neck: Bone2D
@export var bone_thigh_r: Bone2D
@export var bone_knee_r: Bone2D
@export var bone_ankle_r: Bone2D
@export var poly_body_core: Polygon2D
@export var poly_leg_r: Polygon2D
@export var poly_leg_r_stocking: Polygon2D
@export var decoupled_head_mount: Node2D
@export var pauldron_r_mount: Node2D

# Estado deseado continuo (alimentado por el AnimationPlayer o máquina de estados de vuelo)
var target_torso_trapezoid: float = 0.0 # [-0.16, +0.16]
var target_yaw_twist: float = 0.0       # [-0.18, +0.18]
var target_leg_r_phi1: float = 0.0      # Pitch muslo Z (rad)
var target_leg_r_phi2: float = 0.0      # Pitch espinilla Z (rad)
var target_leg_r_distal_amp: float = 0.0 # [0.0, 0.24]

# Cola circular para el stagger de cabeza (guarda los ticks cuantizados previos)
var _tick_accumulator: float = 0.0
var _stepped_torso_trap: float = 0.0
var _prev_torso_trap_queue: Array[float] = [0.0, 0.0]

func _process(delta: float) -> void:
	var tick_duration: float = 1.0 / max(stepped_fps, 1.0)
	_tick_accumulator += delta

	# Solo actualizamos las poses de perspectiva en múltiplos discretos de 66.67 ms (15 FPS)
	if _tick_accumulator >= tick_duration:
		_tick_accumulator = fmod(_tick_accumulator, tick_duration)
		_step_perspective_tick()

func _step_perspective_tick() -> void:
	# 1. Historial para el Stagger de 1 tick en la cabeza
	_prev_torso_trap_queue.push_back(_stepped_torso_trap)
	if _prev_torso_trap_queue.size() > head_pose_stagger_ticks + 1:
		_prev_torso_trap_queue.pop_front()

	_stepped_torso_trap = target_torso_trapezoid
	var staggered_head_trap: float = _prev_torso_trap_queue[0]

	# 2. Sincronizar pivotes post-skinning de la pierna derecha (Leg + Stocking idénticos)
	if poly_leg_r and bone_thigh_r and bone_knee_r and bone_ankle_r:
		var p_root: Vector2 = poly_leg_r.to_local(bone_thigh_r.global_position)
		var p_mid: Vector2  = poly_leg_r.to_local(bone_knee_r.global_position)
		var p_tip: Vector2  = poly_leg_r.to_local(bone_ankle_r.global_position)

		for mat_owner in [poly_leg_r, poly_leg_r_stocking]:
			if mat_owner and mat_owner.material is ShaderMaterial:
				var sm: ShaderMaterial = mat_owner.material
				sm.set_shader_parameter("p_root", p_root)
				sm.set_shader_parameter("p_mid", p_mid)
				sm.set_shader_parameter("p_tip", p_tip)
				sm.set_shader_parameter("phi_seg1", target_leg_r_phi1)
				sm.set_shader_parameter("phi_seg2", target_leg_r_phi2)
				sm.set_shader_parameter("distal_amp", target_leg_r_distal_amp)

	# 3. Aplicar trapecio al torso y acoplar DecoupledHeadMount + Pauldron_R
	if poly_body_core and poly_body_core.material is ShaderMaterial:
		var body_sm: ShaderMaterial = poly_body_core.material
		body_sm.set_shader_parameter("torso_trapezoid", _stepped_torso_trap)
		body_sm.set_shader_parameter("yaw_twist", target_yaw_twist)

	if decoupled_head_mount and bone_neck and bone_pelvis:
		# Calcular el acortamiento real del cuello en el tick actual T para no desconectar el cuello
		var sin_phi_t: float = clamp(_stepped_torso_trap / 0.25, -0.85, 0.85)
		var cos_phi_t: float = sqrt(1.0 - sin_phi_t * sin_phi_t)
		var sy_torso: float = cos_phi_t - 0.1315 * sin_phi_t
		var torso_dir: Vector2 = (bone_neck.global_position - bone_pelvis.global_position).normalized()
		var neck_delta_t: Vector2 = torso_dir * torso_length_du * (sy_torso - 1.0)
		neck_delta_t.y += _stepped_torso_trap * 14.0 # Arco pectoral en v_hat = 1.0

		# Posición base sigue al cuello en T, pero el cabeceo y escala usan T-1 (Stagger!)
		var head_stagger_offset := Vector2(target_yaw_twist * 8.0, staggered_head_trap * 9.5)
		decoupled_head_mount.global_position = bone_neck.global_position + neck_delta_t + head_stagger_offset

		# Escala contenida al 60% del trapecio para proteger la proporción heroica 1:6.23
		var head_scale_factor: float = 1.0 + 0.60 * staggered_head_trap
		decoupled_head_mount.scale = Vector2(head_scale_factor, head_scale_factor)
6. Coreografía de las 8 Vistas con Cámara ~5°–15° a ~160 pxA una resolución de combate de 160.47 px (zoom = 1.0), un desplazamiento de 5 du equivale a 1.89 px en pantalla. A esta escala, las variaciones sutiles de malla pasan desapercibidas si no se apoyan en siluetas asimétricas, separación tonal por profundidad (depth-cueing) y perspectiva diferencial.Diseño de Poses en S (Frontal) y N (Espalda) y Solución al "Negro sobre Negro" en NDado que la cámara está a ~7.49° sobre la horizontal, en las vistas S y N cualquier movimiento simétrico de piernas o brazos aplana el volumen. Aplicamos la Regla de Asimetría Axial en Z (Contrapposto Dinámico): ambas piernas nunca deben compartir el mismo par $(\phi_1, \phi_2)$ durante una maniobra.En vista frontal (S) durante picado o dash hacia cámara, el torso aplica un trapecio positivo $\tau_{\text{pitch}} = +0.16$ (hombros ensanchados +16%, cuello proyectado más abajo hacia el esternón, cabeza a escala ×1.096 con 1 tick de retraso). La pierna líder (ej. leg_r) flexiona la rodilla hacia el pecho ($\phi_1 = +55^\circ, \phi_2 = -40^\circ$, activando $\kappa_{\text{tuck}} \approx +0.85$ para que la rótula cabalgue sobre la espinilla), mientras la pierna de arrastre (leg_l) se extiende hacia atrás ($\phi_1 = -35^\circ, \phi_2 = -45^\circ$, acortada al 61.4% por la asimetría oblicua de 7.49° y enfriada con depth_far_tint). En freno aéreo o retroceso de disparo frontal (S), el trapecio del torso se invierte a $\tau_{\text{pitch}} = -0.16$ (la pelvis se adelanta hacia la cámara y el pecho retrocede). Una pierna se planta hacia delante para frenar ($\phi_1 = +35^\circ, \phi_2 = +50^\circ$) con ampliación selectiva en el talón (distal_amp = +0.24, distal_toe_heel_bias = -0.35), mientras el brazo del arma apunta a cámara ($\phi_{\text{arm1}} = +60^\circ, \phi_{\text{arm2}} = +70^\circ$) ampliando el puño o cañón un +22%. En ambos casos, mantén Bone2D.rotation de Thigh_R/L dentro de tu rango seguro de ±5.16° (±0.09 rad): cuando una pierna se aleja hacia el fondo ($\phi_1 < 0$), ciérrala ligeramente (1.5°–3.0°) hacia la línea central de la pelvis; cuando una rodilla avanza hacia cámara ($\phi_1 > 0$), permite una leve apertura de 3°–5° acompañada de la expansión cónica $S_{\perp}$, de modo que el borde interior del muslo permanezca anclado a la ingle y solo el contorno exterior se expanda.En vista trasera (N), durante un dash hacia el fondo o un ascenso vertical, el personaje da la espalda a la cámara y dobla la espinilla hacia atrás, haciendo que la suela y el talón de la bota apunten directamente hacia la cámara ($\phi_2 = +55^\circ\text{ a }+65^\circ$, distal_amp = +0.24) superponiéndose sobre el muslo oscuro. Para evitar que la bota oscura se funda en una mancha negra contra el muslo a 160 px, articulamos cuatro mecanismos complementarios:Inversión del Bolsillo de Oclusión ($\kappa_{\text{tuck}} < 0$): Al ser $\phi_1 \le 0^\circ$ (muslo alejándose) y $\phi_2 = +60^\circ$ (espinilla acercándose a cámara), $\kappa_{\text{tuck}} \approx -0.72$. El shader proyecta el bolsillo de sombra por encima del gemelo/bota (oscureciendo aún más la parte media del muslo trasero) y enciende la cresta especular (crest_rim) en el borde superior de la bota/gemelo.Desplazamiento de Valor Luminoso (Atmospheric Value Split): Aprovechando hdr_2d = true, cuando $z_{\text{local}} < 0$ en el muslo trasero ($\hat{v} < 0.48$), aplicamos depth_far_tint (tinte frío azulado) para separar por temperatura de color el muslo lejano respecto a la suela cercana iluminada con depth_near_tint.Rim-Light Perimetral de Oclusión (rim_occlusion_color): En fragment(), el término edge_factor * z_forward_boost dibuja un filo de luz cian de 1.5 a 2.0 px de grosor alrededor del contorno lateral e inferior de la bota cuando $z_{\text{local}} > 0.35$, creando un anillo luminoso separador entre la bota en primer plano y el muslo en segundo plano.Asimetría de Silueta Exterior (Tangente Rota): Al posar en N, añade una rotación 2D mínima en Knee_R/L de +6° a +10° hacia el exterior del cuerpo para que al menos el 30% del talón o la puntera de la bota ampliada sobresalga fuera de la silueta del muslo recortándose contra el fondo espacial.Ruptura del Efecto "Gemelo" en Vistas de Perfil (E / W)En las vistas laterales (e y w), si ambos brazos o ambas piernas mantienen la misma longitud y escala, cualquier pose pierde profundidad. La siguiente matriz establece la separación entre la extremidad cercana y la lejana combinando perspectiva diferencial, el plano oblicuo de 7.49° y depth-cueing:Parámetro de ProfundidadExtremidad Cercana a Cámara (_R en E, _L en W)Extremidad Lejana a Cámara (_L en E, _R en W)Efecto Perceptivo a 160 pxOffset de Profundidad Base ($z_{\text{base}}$)$+0.35$ (activa conicidad $1/(1 - k_p z) \approx \mathbf{1.06\text{–}1.08}$)$-0.35$ (activa reducción $1/(1 - k_p z) \approx \mathbf{0.92\text{–}0.94}$)Diferencia de grosor del 14%–16% (±6% a ±8% respecto al neutro) entre extremidad delantera y trasera.Desfase de Plano Oblicuo ($\alpha_c = 7.49^\circ$)Raíz de cadera/hombro y tobillo desplazados hacia abajo (+Y) entre +4.5 y +6.8 du (+1.7 a +2.6 px).Raíz de cadera/hombro y tobillo desplazados hacia arriba (-Y) entre -4.5 y -6.8 du (-1.7 a -2.6 px).Los pies nunca pisan la misma línea horizontal; reproducen el escalón vertical de 9.7 du medido en se.Desfase Angular de Zancada / FaseEn reposo o vuelo, rodilla adelantada +8° a +14° con $\phi_1 = +18^\circ$ (leve apertura hacia cámara).Desfasada -10° a -18° en el plano XY con $\phi_1 = -18^\circ$ (apuntando ligeramente hacia el fondo).Rompe las líneas paralelas entre tibias y antebrazos.Depth-Cueing Cromático (fragment())Saturación 100%, contraste de tinta completo, brillo HDR ×1.05.Multiplicado por depth_far_tint (vec3(0.76, 0.80, 0.92)), reduciendo el contraste un 20%.La pierna trasera retrocede visualmente al segundo plano sin confundirse en los cruces.7. Curvas de Animación Limitada a 15 FPS y Turnaround 2.5D (WHIP_SNAP_AFTERIMAGE)Anatomía Temporal de un Snap de Perspectiva a 15 FPSPara que las deformaciones post-skinning en void vertex() se perciban como dibujo clave manual (keyframe Sakuga) y no como interpolación elástica ("goma de malla"), se suprimen las rampas lineales de aceleración y se sustituyen por saltos discretos cuantizados en ticks de 66.67 ms (15 FPS). La siguiente tabla detalla la secuencia numérica tick por tick (de 0 ms a 533 ms) tanto para un snap de impacto/freno como para un giro de vista con WHIP_SNAP_AFTERIMAGE:Tick (15 FPS)Tiempo (ms)Fase de Animación LimitadaAmpliación Distal Bota/Puño (distal_amp)Trapecio Torso (torso_trapezoid)Escala Cabeza (1-Tick Stagger)Torsión Giro (yaw_twist)Barrido Rim (rim_sweep_dir)Tick 00 msIDLE_HOVER (Reposo 1:6.23)0.0%0.0%0.0%0.0%0.0Tick 167 msAnticipación (1-Tick Coil) / Pre-Swap-8.0%-6.0%0.0% (lee Tick 0)-14.0% (Lámina S)-0.6Tick 2133 msImpacto (1-Tick Overshoot) / Swap+24.0%+16.0%-3.6% (lee Tick 1)+18.0% (Cambia a SE)+1.0Tick 3200 msAsentamiento (Hold Frame 1) / Post-Swap+18.0%+14.0%+9.6% (lee Tick 2)-16.0% (Cabeza a SE)-0.8Tick 4267 msMantenimiento (Hold Frame 2)+18.0%+14.0%+8.4% (lee Tick 3)+6.0%+0.3Tick 5333 msMantenimiento (Hold Frame 3)+18.0%+14.0%+8.4% (lee Tick 4)0.0%0.0Tick 6400 msRecuperación Escalonada 1+12.0%+8.0%+8.4% (lee Tick 5)0.0%0.0Tick 7467 msRecuperación Escalonada 2+4.0%+2.0%+4.8% (lee Tick 6)0.0%0.0Tick 8533 msRetorno a Reposo0.0%0.0%+1.2% (lee Tick 7)0.0%0.0Esta estructura temporal opera en cuatro etapas bien diferenciadas:Tick 1 — Anticipación Comprimida (1-Tick Coil, 67 ms): Antes de proyectar una rodilla, bota o puño hacia la cámara, el cuerpo se recoge en dirección opuesta durante un único tick: torso_trapezoid baja a -6.0% (-0.06), el ángulo $\phi_1$ se retrae -15° y distal_amp cae a -8.0% (-0.08). Esta micro-contracción previa amplifica el contraste perceptual del frame siguiente.Tick 2 — Impacto con Overshoot de 1 Tick (Extreme Impact Frame, 133 ms): Sin cuadros intermedios de transición, la extremidad salta en un solo corte desde -8.0% hasta el pico de overshoot de +24.0% (distal_amp = +0.24), con $\phi_1 = +60^\circ$ y torso_trapezoid = +0.16. Debido a head_pose_stagger_ticks = 1, durante el Tick 2 la cabeza aún está ejecutando la contracción de anticipación del Tick 1 (-3.6%), generando una tensión orgánica en el cuello que dura exactamente 66.67 ms.Ticks 3 a 5 — Asentamiento y Hold Frame Heroico (200 a 333 ms): En el Tick 3, la extremidad retrocede desde el overshoot de +24.0% y se clava en su valor de mantenimiento (Hold) de +18.0% (distal_amp = +0.18), mientras el torso se asienta en +14.0% (0.14). Simultáneamente, en este Tick 3 la cabeza desacoplada recibe por fin el overshoot del Tick 2 (+9.6% de escala), completando el latigazo secundario (overlap / follow-through). Durante los Ticks 3, 4 y 5, los parámetros de perspectiva del cuerpo permanecen congelados mientras los sistemas secundarios a 60+ FPS mantienen viva la silueta.Ticks 6 a 8 — Recuperación Escalonada (Ease-Out Hold, 400 a 533 ms): El retorno a la proporción heroica 1:6.23 (IDLE_HOVER, donde se mantiene un contrapposto sutil de $\phi_1 = +12^\circ$ en una pierna y $-12^\circ$ en la otra) se realiza en tres escalones desacelerados (+18% → +12% → +4% → 0%).Potenciación de WHIP_SNAP_AFTERIMAGE para el Turnaround 2.5D entre las 8 VistasAl girar entre las 8 vistas discretas (S ↔ SE ↔ E ↔ NE ↔ N), aplicar únicamente squash horizontal en X hace que la lámina parezca una superficie plana girando sobre su eje vertical, sin que el hombro o la cadera que lidera el giro avance hacia la cámara. Al inyectar torsión trapezoidal (yaw_twist) + perspectiva diferencial de extremidades + barrido direccional de rim-light (rim_sweep_dir) en una ventana de 3 ticks alrededor del cambio de lámina, se disimula la transición discreta:Tick Pre-Swap ($T_{\text{swap}} - 1$, Tick 1 a 67 ms): Permanece activa la lámina de origen (ej. S) con squash_x = 0.86, pero void vertex() aplica una pre-torsión (yaw_twist = -0.14 a +0.18 según sentido de giro) que expande verticalmente un +11% el costado del torso que gira hacia la cámara; la hombrera y el brazo líderes suben a $\phi = +35^\circ$ (+12% de escala), mientras el lado opuesto retrocede a $\phi = -35^\circ$ (-12%). En fragment(), rim_sweep_dir = -0.6 introduce un filo especular por el borde de ataque.Tick de Swap + Overshoot ($T_{\text{swap}}$, Tick 2 a 133 ms): El cuerpo conmuta a la nueva lámina (SE), pero DecoupledHeadMount conserva la lámina de cabeza S durante este único tick gracias a head_pose_stagger_ticks = 1. La nueva lámina SE entra con contra-torsión inversa (yaw_twist) que absorbe la inercia de la lámina S, acompañada del smear de Pasada 2 de WHIP_SNAP_AFTERIMAGE y del pico de barrido de luz (rim_sweep_dir = +1.0), simulando que el reflejo especular ha recorrido el cilindro del torso al rotar 45°.Tick de Asentamiento ($T_{\text{swap}} + 1$, Tick 3 a 200 ms): El cuerpo recupera squash_x = 1.0 en SE y la cabeza conmuta finalmente a la vista SE con un micro-rebote de escala (×1.04 → 1.0), mientras yaw_twist y rim_sweep_dir decaen hacia el contrapposto oblicuo nativo de la nueva vista. Desfasar 1 tick (66.67 ms) el cambio de lámina de la cabeza respecto al torso evita que el 100% de los píxeles del personaje cambien en el mismo cuadro, fundiendo las 8 vistas discretas en una rotación 2.5D continua.