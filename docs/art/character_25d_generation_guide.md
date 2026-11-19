# Guía Técnica de Generación de Personajes 2.5D (8 Direcciones) para Animación Procedural en Godot

> **Relación con el pipeline de Astra Dream:**
> Esta guía cubre la **Etapa 0 (Generación de Arte Base e Ilustraciones de Turnaround)** antes de ejecutar el procesamiento local en Python descrito en [PILOT_CREATION_PIPELINE.md](../PILOT_CREATION_PIPELINE.md).
>
> - Para los detalles técnicos del rig en Godot (tanto el rig dual v1 `s`/`n` como el estándar v2 8-dir nativo `s..sw` + 8 cabezas asimétricas sin Flip-H), ver [PILOT_RIG_ARCHITECTURE.md](../PILOT_RIG_ARCHITECTURE.md) y el registro paso a paso en [PILOT_V2_8DIR_HANDOFF.md](../PILOT_V2_8DIR_HANDOFF.md).
> - Para los prompts específicos de zócalos de cabeza asimétrica usados en Valentina, ver [GOOGLE_AI_PROMPTS.md](../../sandbox/pilot_rig_lab/reference_templates/GOOGLE_AI_PROMPTS.md).
> - Para el reparto de herramientas entre Google AI Pro y Python ML local (*See-through* / *Sapiens-Lite*), ver [Google AI Pro Game Pipeline.md](Google%20AI%20Pro%20Game%20Pipeline.md).

---

## 1. Fundamentos de la Perspectiva y Cámara (Plano Cenital Inclinado 45°–60°)

Para juegos 2.5D de desplazamiento espacial o aéreo donde los personajes se mueven en 8 direcciones mediante sprites base, máscaras de segmentación (*Clown Maps* / mapas de ID) y deformación/rotación procedural en Godot, la elección del ángulo de cámara determina tanto la viabilidad del enmascaramiento como la consistencia de la IA generativa.

> **Nota sobre vistas 2.5D de combate en Astra Dream:** En poses neutras de laboratorio/turnaround la elevación de **45°–60°** funciona excelente para proyectar el plano XY; si en alguna pose de vuelo extrema la cámara muy picada genera oclusión fuerte en cuello/cadera al segmentar extremidades, reducir la inclinación hacia un **3/4 heroico (~30°–45°)** (manteniendo la separación de extremidades de la sección 3) facilita cortes sin solapamiento.

### ¿Por qué 45°–60° de elevación (*High-Angle Three-Quarter View*)?
- **Lectura espacial vs. Volumen anatómico:** Una vista cenital estricta (90°) colapsa la silueta y destruye las proporciones faciales y corporales, provocando severos artefactos en modelos de IA. Una vista lateral plana (0°) elimina la percepción de profundidad en el plano XY. La inclinación intermedia de **45° a 60°** permite proyectar la dirección del desplazamiento en el espacio mientras conserva la legibilidad del rostro, el torso y la separación de las extremidades.
- **Estabilidad en modelos generativos:** Los modelos de difusión poseen un sesgo de entrenamiento muy sólido hacia vistas de tres cuartos elevados, lo que reduce drásticamente las mutaciones de vestuario y proporciones al rotar un mismo diseño alrededor de su eje vertical.

---

## 2. Arquitectura de 8 Direcciones mediante 5 Vistas Base (Regla de Simetría)

Generar 8 vistas independientes desde cero multiplica la acumulación de inconsistencias visuales. La estrategia óptima consiste en generar **5 ángulos base** y obtener los 3 restantes mediante espejado horizontal (`flip_h = true` o `scale.x = -1` en Godot):

| Dirección Final | Origen / Generación | Observación Técnica |
| :--- | :--- | :--- |
| **Sur (S)** | Vista generada #1 | Frontal directo con cámara elevada (45°–60°). |
| **Sureste (SE)** | Vista generada #2 | Tres cuartos frontal hacia la derecha. |
| **Suroeste (SO)** | Espejado de **SE** | Inversión horizontal en motor (o post-proceso si hay asimetrías). |
| **Este (E)** | Vista generada #3 | Perfil lateral completo con inclinación de cámara superior. |
| **Oeste (O)** | Espejado de **E** | Inversión horizontal en motor. |
| **Noreste (NE)** | Vista generada #4 | Tres cuartos de espalda hacia la derecha. |
| **Noroeste (NO)** | Espejado de **NE** | Inversión horizontal en motor. |
| **Norte (N)** | Vista generada #5 | Espalda completa con cámara elevada (45°–60°). |

> **Nota sobre diseños asimétricos:** Si el personaje cuenta con detalles asimétricos críticos (un brazo cibernético, un parche/visor monocular, flequillo asimétrico o una funda de arma en un solo muslo), utiliza la imagen espejada como guía estructural (*Image-to-Image* / *Inpainting* ligero) para corregir únicamente el elemento asimétrico sin alterar la silueta ni los pivotes de las extremidades. En `PlanarCombatRig`, las **8 cabezas** se generan/compilan como vistas independientes sin `Flip-H` precisamente para preservar esas asimetrías.

---

## 3. Reglas Anatómicas y de Pose para Máscaras sin Roturas

Cuando un shader o un sistema de huesos 2D en Godot rota o deforma un brazo o una pierna a partir de una imagen estática, cualquier solapamiento previo en la imagen original provoca estiramientos de textura, arrastre de píxeles del torso o huecos vacíos.

Para garantizar máscaras limpias (*Clown Maps* / `*_id_mask.png`, mapas de profundidad y canal alfa), la pose base debe cumplir cuatro condiciones estrictas:

1. **Separación de brazos (A-Pose abierta en flotación):** Los brazos deben mantener una apertura de **30° a 45° respecto al tronco**. Nunca deben cruzar por delante del pecho, tocar las caderas ni quedar ocultos detrás de la espalda en las vistas laterales/diagonales.
2. **Separación de piernas (Compás en gravedad cero):** Las piernas deben estar ligeramente abiertas en forma de "V" invertida estrecha, con una pierna sutilmente más adelantada o flexionada que la otra, evitando que los muslos o las botas se superpongan en el espacio 2D.
3. **Despeje de articulaciones:** El cabello largo, bufandas, cintas o capas deben flotar hacia afuera o hacia atrás sin cubrir los hombros, los codos ni la cintura. Esto permite aislar el cabello en su propia máscara para animarlo por separado con ondas sinusoidales en el shader.
4. **Fondo neutro plano sin sombras proyectadas:** En el espacio no existe un plano de suelo inmediato. El fondo debe ser un color sólido uniforme (gris neutro `#808080` —estándar del pipeline Python en Astra Dream— o magenta croma `#FF00FF`) sin oclusión ambiental en el piso ni sombras arrojadas que contaminen el recorte del canal alfa.

---

## 4. Flujo de Trabajo a partir de un *Character Sheet* (Frente y Espalda)

Partir de una hoja de referencia con vista frontal y trasera permite anclar la identidad visual del personaje (paleta de colores, proporciones, equipamiento y estilo de línea) antes de extrapolar los ángulos diagonales y laterales.

### Paso 1: Preparación de la Referencia
- Asegura que tu imagen de referencia (frente y espalda) tenga proporciones idénticas entre ambas vistas y el traje/equipamiento claramente definido.
- Si tu referencia original está en vista ortogonal plana (0°), el primer prompt debe traducirla a la elevación de cámara de **45°–60°** manteniendo intacto el diseño.

### Paso 2: Estructura Modular del Prompt

Construye tus prompts dividiéndolos en **5 bloques jerárquicos** para que el modelo priorice primero la cámara y la pose limpia antes que los detalles decorativos:

1. **[Cámara y Encuadre]:** Define el ángulo de visión exacto y la escala completa del cuerpo.
2. **[Referencia e Identidad]:** Instruye al modelo a mantener el diseño exacto de la imagen adjunta.
3. **[Dirección Cardinal y Rotación]:** Especifica hacia dónde apunta el cuerpo respecto a la cámara.
4. **[Pose de Articulación Limpia]:** Fuerza la separación de extremidades para el enmascaramiento.
5. **[Estilo y Fondo Técnico]:** Asegura iluminación uniforme y fondo recortable.

---

## 5. Plantillas de Prompts Listas para Usar

Utiliza tu imagen de referencia (frente y espalda) adjunta en cada generación y reemplaza los textos entre corchetes `[...]` según corresponda.

### A. Prompt Base para Traducir Frente (S) y Espalda (N) al Ángulo 2.5D

```text
High-angle three-quarter top-down view (50-degree camera elevation looking down), full body character turnaround sheet showing two views side by side: [FRONT VIEW (South) / BACK VIEW (North)].
Based strictly on the attached character reference sheet, keeping the exact same face, hairstyle, outfit design, colors, and proportions.
Zero-gravity floating pose in space: arms spread apart from the torso at a 40-degree angle with open hands, legs slightly apart in a relaxed suspended stance with no overlapping limbs, hair floating outward away from the shoulders.
Clean cel-shaded anime game sprite art style, crisp dark outlines, even soft studio lighting without harsh cast shadows, isolated on a solid flat neutral gray background (#808080), centered, full body with generous margin around extremities.
```

### B. Prompt para Diagonales Frontales: Sureste (SE) y Suroeste (SO)

```text
High-angle three-quarter top-down view (50-degree camera elevation looking down), full body game sprite of the exact character from the attached reference image, rotated 45 degrees facing diagonally forward-right (Southeast view).
Zero-gravity floating pose: both arms clearly separated from the body at a 35-to-45-degree angle so neither arm overlaps the torso, both legs clearly visible and separated without overlapping thighs or boots, hair floating back away from the shoulders.
Consistent outfit details, facial features, and proportions matching the reference. Clean 2D game art style, sharp outlines, flat even lighting, solid uniform gray background (#808080), no ground shadow, full body completely inside frame.
```

### C. Prompt para Diagonales Traseras: Noreste (NE) y Noroeste (NO)

```text
High-angle three-quarter top-down view (50-degree camera elevation looking down), full body game sprite of the exact character from the attached reference image, seen from a 45-degree rear three-quarter angle facing diagonally away and to the right (Northeast view).
Zero-gravity floating pose: both arms extended outward at a 40-degree angle clearly separated from the torso and back equipment, legs slightly separated in a natural suspended mid-air stride without overlapping, hair floating outward without covering the shoulders.
Consistent back design, accessories, colors, and proportions matching the rear view of the reference. Clean 2D game art style, crisp outlines, even lighting, solid flat gray background (#808080), no ground shadow.
```

### D. Prompt para Perfiles Laterales Inclinados: Este (E) y Oeste (O)

```text
High-angle top-down profile view (50-degree camera elevation looking down), full body game sprite of the exact character from the attached reference image, seen in a side profile facing right (East view).
Zero-gravity floating pose: near arm angled slightly backward and far arm angled slightly forward so both arms are distinctly visible and separated from the torso silhouette, legs separated in a gentle floating scissor stance with no overlap, hair floating backward.
Exact outfit, silhouette, and proportions consistent with the reference sheet. Clean 2D game art style, sharp linework, flat studio lighting, isolated on a solid uniform gray background (#808080), no floor shadow.
```

---

## 6. Recomendaciones de Post-Proceso para el Pipeline en Godot

1. **Verificación de Escala y Anclaje:** Superpón las 5 vistas generadas en capas con 50% de opacidad en tu editor de imágenes (o mediante script en Python/OpenCV) para verificar que la altura de la cabeza, la línea de los hombros y el centro de masa (pelvis) coincidan en coordenadas Y entre todos los ángulos.
2. **Solapamiento Esférico en Máscaras de Hombros y Caderas:** Al trazar el *Clown Map* (máscara de colores por extremidad) o extender muñones bajo solapes, redondea la unión del brazo con el hombro formando un semicírculo que penetre ligeramente en el área del torso. Al colocar el pivote de rotación en Godot en el centro exacto de ese círculo, el brazo podrá rotar ±25° sin revelar cortes rectos ni deformar el contorno del hombro.
3. **Atenuación por Gradiente en Shaders:** Al animar extremidades deformando vértices o pesos por píxel, multiplica el ángulo de rotación por un gradiente progresivo de `0.0` en la articulación (hombro/cadera) a `1.0` en el extremo (mano/pie) —automatizado en Astra Dream vía `process_limb_anim_masks.py` (`*_anim_mask.png`)— para lograr una flexión orgánica continua sin dividir cada extremidad en múltiples sprites rígidos.
4. **Regla Anti-Manchas para Recoloreo (`*_id_mask.png`):** No generar nunca el *Clown Map* final por prompt aislado sin re-bloqueo ni cuantización local. En v2 8-dir, exporta lotes en bloques `16:9`/`4:3`/`1:1` sobre `#FFFFFF` e ingiere con `prepare_ai_mask_workspaces.py --ingest all` + `build_valentina_v2_rig_assets.py` (ver [PILOT_V2_8DIR_HANDOFF.md](../PILOT_V2_8DIR_HANDOFF.md)); para el flujo v1 2-dir se usaba `process_parts5_1to1_maps.py --import-id-mask <ruta> --refine-heads` sobre `id_mask_ink_refiner.py`.
