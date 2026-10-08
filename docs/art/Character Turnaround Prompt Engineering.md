# **Deterministic Character Turnaround and Multi-Pose Sprite Sheet Generation: Architectural Foundations, Prompt Engineering Taxonomy, and Automated Pipelines in Gemini and Nano Banana**

## **Architectural Root-Cause Analysis: Cross-Attention Mechanics, Token Entanglement, and Representation Skew**

The synthesis of multi-view, multi-pose character turnaround sheets on a unified panoramic canvas reveals fundamental operational dynamics within multimodal latent diffusion models1. When generating four distinct poses across an extended horizontal plane using the Google DeepMind image generation stack—encompassing Imagen 3 and the Gemini Nano Banana multimodal models—developers frequently encounter severe visual anomalies3. These manifest as progressive identity drift across horizontal sub-panels, figure crowding against the upper and lower canvas boundaries, topological degeneration of the zenith flight sprite into an aerospace vehicle, and semantic contamination triggered by negative prompts2. Resolving these failure modes requires examining the mathematical and structural mechanics of vision-language processing2.

### **Spatial Cross-Attention and Attribute Entanglement**

In latent diffusion transformers and cascade diffusion architectures, spatial latents ![][image1] at denoising step ![][image2] are conditioned on textual embeddings through spatial cross-attention mechanisms2. Spatial patch queries ![][image3] attend to text encoder key projections ![][image4] and value projections ![][image5], where ![][image6] represents the input prompt tokens2. Standard diffusion backbones do not maintain rigid coordinate boundaries across sub-regions unless explicitly guided by localized latent masking or spatial cross-attention constraints2. In an unconstrained panoramic generation, attention maps remain diffuse across the entire latent coordinate plane6.  
Attribute leakage across sub-panels is further exacerbated by the bidirectional attention layers of deep language encoders2. During text encoding, word tokens interact globally with one another; sentence terminators, trailing conjunctions, and End-of-Sequence (EOS) tokens aggregate contextual information across all semantic clauses in the prompt2. When spatial queries from Column 2 or Column 3 attend to these entangled text keys, the embeddings propagate unintended visual features across panels2.  
This phenomenon operates via two primary pathways: target-external leakage, wherein stylistic details or weapon features bleed into empty chromakey buffers or modify adjacent panels, and target-internal leakage, where attributes belonging to one pose (such as the dynamic asymmetry of an action stance) alter the strict symmetry demanded by orthographic turnarounds2. Consequently, subtle morphological shifts in armor topology, pauldron dimensions, and facial geometry occur between the front and rear views2.

### **Compositional Prior and Vertical Boundary Compression**

Diffusion models trained on curated concept art and digital illustrations exhibit an inherent compositional prior: focal subjects are framed to optimize pixel saliency within the canvas1. The underlying objective functions maximize mutual information between descriptive subject tokens and visual features1. In the absence of mathematical spatial margin constraints, the denoising trajectory naturally expands the character's vertical extremities toward the extreme limits of the canvas, causing feet and headgear to touch the edges9.  
Furthermore, generating four full-body figures across a 16:9 panoramic aspect ratio introduces lateral spatial pressure9. Because the model balances the 16:9 ratio against the complexity of four distinct figures, adjacent spatial latents experience cross-talk during early denoising steps2. Without explicit spatial padding instructions, this lateral pressure causes the peripheral silhouettes of adjacent figures to intersect, merging weaponry, limbs, and trailing hair into adjacent columns9.

### **The Prone Zenith Flight Perspective Gap**

The failure observed in Column 4—where a strict 90° top-down flight sprite collapses into an empty aerospace cockpit or shifts into a 3/4 isometric aerial angle—stems from severe dataset representation imbalance1. In large-scale vision-language pre-training datasets, human figures are overwhelmingly represented in bipedal, vertically grounded orientations captured at eye-level or slight vertical inclinations1. True zenith nadir-pointing angles of humans in horizontal, prone suspension represent an extreme statistical outlier1.  
Conversely, the co-occurrence of tokens such as "overhead view," "flight," "stabilizer wings," and "jet thrusters" is dominated by fixed-wing military aircraft, spacecraft, and aerial vehicles10. When these propulsion tokens are introduced into a multi-column prompt, cross-attention layers pull the spatial latents of Column 4 toward vehicle representations2. The model prioritizes aerodynamic fuselages, canopies, and cockpits over human anatomy10.  
Additionally, rendering a human body from the zenith involves severe anatomical foreshortening along the longitudinal axis10. The diffusion process penalizes unfamiliar foreshortened geometries, resolving this optimization conflict by tilting the virtual camera into a familiar 3/4 isometric perspective or substituting the prone human form with an aircraft fuselage2.

### **The Semantic Attractor Effect of Negative Prompting**

Addressing vehicle hallucination by employing negative prompts such as "no cockpit, no spaceship, no aircraft, no vehicle" frequently increases the failure rate7. In multimodal foundation models, textual conditioning operates via semantic associative projections rather than symbolic logical operators7. Standard attention layers lack inhibitory mechanisms for negated terms; introducing lexical tokens like "cockpit" or "spaceship" activates their semantic vectors in the latent projection space2.  
During the initial denoising steps where global layout and low-frequency structures are established, these activated concept nodes pull intermediate latents toward vehicular shapes2. Negative tokens function as attractors, drawing the model toward the concepts they were meant to suppress2. Robust perspective disambiguation therefore demands affirmative anatomical and kinesiological anchoring that defines the human physical structure in flight rather than listing prohibited objects7.

## **Paradigma de Producción: La Tríada Modular 1:1 de Alta Fidelidad**

La síntesis de 4 poses en una sola franja panorámica 16:9 (`1024x572`) funcionó como prueba de concepto para alinear identidades, pero adolece de un cuello de botella físico insalvable para producción: **resolución efectiva reducida** ($\sim 180 \times 490$ px por personaje) que al escalarse a $1200 \times 1600$ genera bordes empastados y pérdida de microdetalle.

El estándar oficial de Astra Dream adopta la **Tríada Modular 1:1**: tres generaciones independientes en aspect ratio cuadrado nativo (`1:1`, 1024x1024 o 2048x2048), donde cada sujeto ocupa entre el **85% y 90% del lienzo**, garantizando máxima densidad de píxeles, fidelidad facial y poses adaptadas exactamente a su caso de uso en Godot.

---

### **Composición de la Tríada Modular 1:1**

| Módulo | Formato | Caso de Uso en Godot | Anatomía & Pose |
| :--- | :--- | :--- | :--- |
| **Módulo A: Hub 3D Duo (Frente & Espalda)** | 1:1 (2 columnas 50/50) | `Sprite3D` en `HubPlayerController3D` (caminar en hangar y billboard) | **Pose asimétrica estilizada y relajada:** cadera sutilmente apoyada, una mano en cintura/cadera, otra mano relajada o sosteniendo la correa del arnés. En la espalda refleja exactamente la misma silueta con rifle enfundado a 45°. |
| **Módulo B: Heroic Splash Art** | 1:1 individual | Selección de personaje (`selection_*.png`) y Diálogos (`portrait_*.png`) | **Splash art gacha de máximo impacto:** pose dinámica, contrapposto pronunciado con curvas y actitud empoderada/seductora, sosteniendo el rifle con soltura sobre el hombro. |
| **Módulo C: Flight Combat Sprite** | 1:1 individual | Sprite 2D de nave/combate (`ship_*.png` en `PlayerVisualBuilder`) | **Vuelo dorsal supersónico recto en gravedad cero:** cuerpo perfectamente vertical alineado a 12h-6h, piernas juntas con puntas de pie hacia abajo, brazos pegados a los costados, toberas frías (sin llamas ni VFX). |

---

## **Flujo de In-Context Conditioning (Consistencia Absoluta)**

Para garantizar que los tres módulos pertenezcan de forma idéntica al mismo personaje:
1. **Paso 1 (Ancla Canónica):** Se genera primero el **Módulo B (Heroic Splash Art)**. Al ser una ilustración libre y dinámica, define con máxima riqueza el rostro, peinado, ojos, shaders del plugsuit y el diseño del arma.
2. **Paso 2 (Condicionamiento del Hub 3D):** Se pasa la imagen del Módulo B como `Reference Image 1` a Gemini al generar el **Módulo A (Hub 3D Duo)**, obligando al modelo a calcar la vestimenta, peinado y proporciones en la pose asimétrica de marcha.
3. **Paso 3 (Condicionamiento de Vuelo):** Se genera el **Módulo C (Flight Sprite)** manteniendo la paleta y los reactores dorsales del Módulo A.

---

## **Plantillas Maestras de Prompt (Tríada Modular 1:1)**

### **Módulo A: Hub 3D Duo (Frente & Espalda Asimétrica Relajada)**

```text
SYSTEM SPECIFICATION: TWO-PANEL CHARACTER TURNAROUND (3D HUB SPRITE DUO)

CANVAS CONFIGURATION:
- Aspect Ratio: 1:1 square single-frame concept sheet.
- Background Environment: Uniform, flat, raw solid chromakey magenta background (EXACT pure hex code #FF00FF / RGB 255, 0, 255), completely untextured, 100% matte, zero shadows beneath feet, zero ambient light bouncing onto background.
- Spatial Grid Discipline: Exactly TWO vertical panels split evenly across the square canvas (Left Panel: x=0.00-0.50 Front View; Right Panel: x=0.50-1.00 Back View).
- Vertical Margins: Figures occupy 88% of canvas height, vertically centered with clean 6% magenta margins top and bottom. Zero edge clipping.
- Style: Top-tier anime sci-fi game sprite art, crisp clean linework, smooth cel-shading, rich glossy material highlights on tech plugsuit, vivid cyan emissive circuitry glow. NO TEXT, no labels, no UI overlays.

CORE CHARACTER IDENTITY: [VALENTINA - ACE PILOT]
- Anatomy: Gorgeous alluring young woman with a curvaceous hourglass figure, slender toned waist, pale skin, refined anime face with piercing light blue eyes.
- Hair: Chic silver-white / platinum layered chin-length bob with soft feathered bangs.
- HUD Visor: Translucent glowing cyan holographic tactical monocle / eye-visor (#00F0FF) over left eye with dark ear-mount headset.
- Bodysuit: Second-skin midnight-navy (#1A2238) and dark graphite pilot plugsuit. Segmented shoulder pauldrons with subtle chevron decal, forearm bracers, and tactical boots. Glowing aqua-cyan circuit lines (#00F0FF) tracing feminine curves along torso, ribs, and legs.
- Weapon: Compact sci-fi bullpup sniper rifle with matte charcoal frame and cyan rail glow.

PANEL DESCRIPTIONS:
LEFT PANEL (0.00 - 0.50) - FRONT ELEVATION (RELAXED ASYMMETRICAL POSE):
- Perspective: Orthographic anterior view, eye-level parallel projection, zero perspective tilt.
- Stance: Relaxed, stylish asymmetrical standing pose (natural hub walking posture). Weight resting gently on her right hip with a subtle feminine curve. Her left hand rests casually on her hip, while her right arm hangs relaxed alongside her thigh.
- Equipment: Tactical sling crosses diagonally from right shoulder to left waist. The upper stock/receiver of her sniper rifle peeks neatly behind her right shoulder, with the barrel angling down behind her left hip. Confident calm gaze with glowing cyan monocle.

RIGHT PANEL (0.50 - 1.00) - REAR ELEVATION (MATCHING DORSAL MIRROR):
- Perspective: Orthographic posterior view, exact 180-degree dorsal projection matching Left Panel scale and silhouette.
- Stance: Exact anatomical mirror of the Left Panel seen directly from behind. Weight on right hip, left hand on hip, right arm relaxed.
- Equipment: Full dorsal backplate visibility with cyan spinal conduits and dormant metallic micro-nozzles. The sniper rifle is strapped DIAGONALLY across the backplate at a clean 45-degree angle (stock at upper-right shoulder, barrel angling down past left hip).
```

---

### **Módulo B: Heroic Selection Splash Art (Máximo Impacto & Sexy)**

```text
SYSTEM SPECIFICATION: HEROIC SELECTION SPLASH ART (INDIVIDUAL 1:1)

CANVAS CONFIGURATION:
- Aspect Ratio: 1:1 square canvas.
- Background Environment: Uniform, flat solid chromakey magenta background (pure hex code #FF00FF / RGB 255, 0, 255), completely untextured, zero ground shadows, zero ambient occlusion.
- Vertical Margins: Character occupies 88% of vertical canvas height, centered. Zero edge clipping of rifle or boots.
- Art Style: Premium modern anime gacha splash art (Honkai Star Rail / Nikke aesthetic), ultra-crisp clean linework, luxurious glossy latex/carbon reflections, glowing emissive conduits. NO TEXT, no watermarks.

CHARACTER: [VALENTINA - HEROIC COMMANDER]
- Anatomy & Expression: Stunningly attractive young female commander with a voluptuous hourglass figure, slender waist, and captivating allure. Head slightly tilted with a charming, highly seductive confident smirk and an intense flirtatious gaze aimed directly at the viewer through her glowing cyan tactical monocle (#00F0FF). Loose silver hair strands drifting dynamically in the wind.
- Bodysuit: Second-skin midnight-navy (#1A2238) and dark graphite pilot plugsuit clinging tightly to bust, waist, hips, and thighs. Glowing neon cyan circuitry lines (#00F0FF) tracing seductive curves. Tactical belt with pouches.
- Weapon & Action Pose: Bold dynamic contrapposto with pronounced hip cocking, highlighting her slender waist and curves. Left hand planted firmly on her curved hip. Right hand holding a sleek sci-fi bullpup sniper rifle tilted casually over her shoulder with lethal elegance. Radiates immense charisma, dangerous allure, and effortless superiority.
```

---

### **Módulo C: Flight Combat Sprite (2D Top-Down Shooter Asset)**

```text
SYSTEM SPECIFICATION: 2D SUPERSONIC FLIGHT COMBAT SPRITE (INDIVIDUAL 1:1)

CANVAS CONFIGURATION:
- Aspect Ratio: 1:1 square canvas.
- Background Environment: Uniform, flat solid chromakey magenta background (pure hex code #FF00FF / RGB 255, 0, 255), 100% matte, zero shadows.
- Sizing: Figure occupies 85% of vertical canvas height, centered.
- Art Style: Crisp 2D game asset sprite, clean contours, cel-shaded with specular highlights. NO TEXT.

CHARACTER IN ZERO-G FLIGHT: [VALENTINA]
- Perspective & Orientation: Flat 2D top-down game sprite, strictly dorsal planar view looking straight at Valentina's back in a vertical supersonic dive.
  * Head with silver hair is strictly at 12 o'clock (pointing to upper margin), hair flowing upward into aerodynamic slipstream strands.
  * Body is completely straight along the vertical axis (ABSOLUTELY NOT BENDING FORWARD, NOT HUNCHED).
  * Back, cyan spinal conduits, and glutes face directly towards the camera.
  * Arms are tucked tightly flush against her ribs in a sleek aerodynamic dive.
  * Legs are extended straight together with pointed boots directed toward 6 o'clock (lower margin).
- Propulsion Rig: Compact dorsal metallic micro-thrusters and boot nozzles in cold dormant state. STRICTLY ZERO FIRE, zero thruster flames, zero plasma exhaust, zero jet trails. Completely clean sprite for real-time engine shaders.
```

---

### **Matriz de Sustitución Modular de Personajes (Tríada 1:1)**

| Operative Roster | Color Palette & Materials | Hair & Cranial Identifiers | Exosuit Rigging & Thrusters | Primary Weapon Asset |
| :---- | :---- | :---- | :---- | :---- |
| **Valentina** | Midnight-Navy (#1A2238), Dark Graphite (#121620), Neon Cyan (#00F0FF). | Textured silver-white/platinum bob, glowing cyan holographic monocle on left eye. | Dorsal spinal conduit harness, compact micro-nozzles (cold state). | Sleek sci-fi bullpup sniper rifle with cyan rail glow. |
| **Nova** | Arctic White (#F8F9FA), Polished Chrome, Electric Violet Glow (#8A2BE2). | Platinum-blonde asymmetrical bob, sharp angular silhouette. | Dual scapular magnetic ion rings, floating energy stabilizer fins. | Heavy magnetic rail-rifle slung over shoulder armor. |
| **Roxy** | Hazard Industrial Orange (#FF5E00), Gunmetal Grey, Emerald Plasma (#00FF66). | Magenta undercut with twin micro top-knots. | Heavy twin turbine jump-pack with dual cooling intake manifolds. | Dual drum-fed kinetic micro-submachine guns. |
| **Kira** | Obsidian Black (#0B0B0E), Midnight Navy (#101D28), Solar Amber Glow (#FFBF00). | Jet-black braided dreadlocks secured with gold rings. | Luminescent hard-light wing matrices projecting from lumbar mount. | Modular break-action hard-light sniper system. |

Where text-only synthesis relies entirely on language encoders, multimodal in-context conditioning allows external reference imagery to guide character identity, reducing facial drift and textural instability across columns10.

### **Generative Model Capabilities Across the Google Stack**

Operational capabilities across the Google DeepMind and Gemini image generation ecosystems vary substantially in their capacity to handle multi-panel spatial layouts1:

| Technical Metric / Feature | Imagen 3 (imagen-3.0-generate-002) | Nano Banana 2 (gemini-3.1-flash-image) | Nano Banana 2.1 (gemini-nano-banana-2.1) | Nano Banana Pro (gemini-3-pro-image) |
| :---- | :---- | :---- | :---- | :---- |
| **Underlying Architecture** | Latent Diffusion Transformer (DiT)1 | Multimodal reasoning \+ Fast synthesis10 | Gemini 3.6 Flash reasoning backbone15 | Gemini 3 Pro high-compute reasoning3 |
| **Reference Image Ingestion** | Single-image inpainting & edits18 | Up to 14 reference images (4 characters, 10 objects)10 | Up to 14 reference images (improved character fusion)3 | Up to 14 reference images (studio-grade fidelity)3 |
| **Reasoning / Thinking Levels** | Not configurable | Minimal, High11 | Minimal, Medium (Default), High3 | Native extended reasoning10 |
| **Panoramic Tiling Artifacts** | Prone to horizontal pattern repetition | Occasional pattern duplication at 2K/4K wide ratios3 | Resolved on wide ratios (4:1, 8:1)3 | Robust handling of wide formats5 |
| **Turnaround Workflow Suitability** | High-fidelity single-character hero art8 | Rapid iterative turnaround concepting10 | **Primary Choice:** Balanced speed and layout adherence3 | Complex multi-character sheets requiring dense detail3 |

### **In-Context Image Conditioning and Sequential Token Binding**

When utilizing gemini-nano-banana-2.1 via the official google-genai SDK, developers can pass up to 14 reference images to maintain character consistency across disparate poses3. Gemini Nano Banana pipelines map visual inputs through positional referencing within the prompt12. Passing a canonical character reference (Reference 1\) alongside a weapons or armor reference (Reference 2\) grounds identity across all four synthesized columns12.  
Textual prompts should explicitly refer to each input by its positional index to ensure proper semantic binding12. Formulations such as "The facial features, hair braid, and crimson armor scheme must match Reference Image 1 exactly across all four columns, while the weapon geometry in Columns 1 and 2 must match Reference Image 2" prevent the model from confusing distinct references12.

### **Reasoning Budgets and Latent Compositional Planning**

The introduction of configurable reasoning levels in Gemini Nano Banana 2.1 (minimal, medium, high) provides direct control over the pre-rendering planning phase3. Generating a four-column panoramic sheet requires spatial coordination to avoid merged limbs and perspective collapse9. Setting thinking\_level="high" allows the Gemini reasoning backbone to plan the horizontal column distribution, resolve the prone posture for Column 4, and confirm margin boundaries before synthesizing pixels10.

Python  
from google import genai  
from google.genai import types  
from PIL import Image

client \= genai.Client()

character\_portrait \= Image.open("assets/valentina\_master\_ref.png")  
weapon\_schematic \= Image.open("assets/carbine\_schematic.png")

response \= client.models.generate\_content(  
    model="gemini-nano-banana-2.1",  
    contents=\[  
        character\_portrait,  
        weapon\_schematic,  
        master\_quad\_sheet\_prompt  
    \],  
    config=types.GenerateContentConfig(  
        response\_modalities=\["IMAGE"\],  
        image\_config=types.ImageConfig(  
            aspect\_ratio="16:9",  
            image\_size="2K"  
        ),  
        thinking\_config=types.ThinkingConfig(  
            thinking\_level="high"  
        )  
    )  
)

## **Automated Production Post-Processing Pipeline**

El pipeline de extracción automatizado convierte las imágenes en bruto generadas con fondo magenta `#FF00FF` en assets transparentes finales para el motor:

1. **Módulo A (Hub 3D Duo):** Segmenta las dos mitades (Izquierda: Frente, Derecha: Espalda), recorta el bounding box exacto y exporta ambos a $1200 \times 1600$ px (anclados en la base al 94% de altura).
2. **Módulo B (Heroic Selection):** Remueve el croma magenta y exporta a $1200 \times 1600$ px centrado, generando automáticamente el recorte de busto/cabeza a $1080 \times 1080$ px para `portrait_*.png`.
3. **Módulo C (Flight Sprite):** Remueve el croma magenta, centra el cuerpo extendido y exporta a $256 \times 256$ px para el núcleo de combate.

### **Procesamiento de Croma Magenta Puro y Despill**

Dado que los pilotos de Astra Dream contienen líneas de energía cian/turquesa (`#00F0FF`) y trajes oscuros, el croma oficial es **Magenta Puro (`#FF00FF`)**. El despill en magenta neutraliza cualquier fringe púrpura en los bordes ajustando los canales rojo y azul al promedio del verde:

```python
neutral = (g + b) * 0.5
r_clamped = min(r, neutral)
b_clamped = min(b, neutral * 1.1)
```

    def extract\_alpha\_matte(self, bgr\_image: np.ndarray) \-\> np.ndarray:  
        """  
        Builds a feathered alpha matte from a solid chromakey green background.  
        """  
        hsv \= cv2.cvtColor(bgr\_image, cv2.COLOR\_BGR2HSV)  
          
        lower\_green \= np.array(\[self.hue\_min, 80, 45\], dtype=np.uint8)  
        upper\_green \= np.array(\[self.hue\_max, 255, 255\], dtype=np.uint8)  
          
        \# Segment background and invert to isolate foreground  
        bg\_mask \= cv2.inRange(hsv, lower\_green, upper\_green)  
        fg\_mask \= cv2.bitwise\_not(bg\_mask)  
          
        \# Morphological close to eliminate internal specular noise  
        kernel \= cv2.getStructuringElement(cv2.MORPH\_ELLIPSE, (3, 3))  
        closed\_mask \= cv2.morphologyEx(fg\_mask, cv2.MORPH\_CLOSE, kernel, iterations=1)  
          
        \# Feather mask edges to soften transitional pixels  
        feathered\_alpha \= cv2.GaussianBlur(closed\_mask, (5, 5), sigmaX=1.0)  
        return feathered\_alpha

    def apply\_edge\_despill(self, bgr\_image: np.ndarray) \-\> np.ndarray:  
        """  
        Clamps excessive green channel values to the average of red and blue channels.  
        """  
        b, g, r \= cv2.split(bgr\_image.astype(np.float32))  
        rb\_average \= (r \+ b) / 2.0  
          
        \# Apply despill clamp  
        g\_clamped \= np.minimum(g, rb\_average)  
          
        despilled\_bgr \= cv2.merge(\[b, g\_clamped, r\])  
        return np.clip(despilled\_bgr, 0, 255).astype(np.uint8)

    def locate\_column\_boundaries(self, alpha\_matte: np.ndarray, column\_count: int \= 4) \-\> List\[Tuple\[int, int\]\]:  
        """  
        Identifies column bounds along the horizontal axis using a 1D projection histogram.  
        """  
        projection \= np.sum(alpha\_matte \> 30, axis=0)  
        energy\_threshold \= 0.05 \* np.max(projection)  
        active\_columns \= projection \> energy\_threshold  
          
        transitions \= np.diff(active\_columns.astype(np.int32))  
        starts \= np.where(transitions \== 1)\[0\] \+ 1  
        ends \= np.where(transitions \== \-1)\[0\]  
          
        if active\_columns\[0\]:  
            starts \= np.insert(starts, 0, 0)  
        if active\_columns\[-1\]:  
            ends \= np.append(ends, len(active\_columns) \- 1)  
              
        \# Fallback to geometric segmentation if columns overlap or are poorly separated  
        if len(starts) \!= column\_count or len(ends) \!= column\_count:  
            canvas\_w \= alpha\_matte.shape\[1\]  
            step \= canvas\_w // column\_count  
            return \[(idx \* step, (idx \+ 1) \* step) for idx in range(column\_count)\]  
              
        return list(zip(starts, ends))

    def process\_sheet(  
        self,   
        source\_path: str,   
        output\_directory: str,   
        character\_identifier: str  
    ) \-\> Dict\[str, str\]:  
        """  
        Extracts, despills, and rescales four sprite columns into production formats:  
        \- Columns 1-3: 1200x1600 UI billboard assets (80% figure height)  
        \- Column 4: 256x256 combat flight sprite (85% bounding scale)  
        """  
        out\_dir \= Path(output\_directory)  
        out\_dir.mkdir(parents=True, exist\_ok=True)  
          
        raw\_bgr \= cv2.imread(source\_path)  
        if raw\_bgr is None:  
            raise FileNotFoundError(f"Input image could not be loaded: {source\_path}")  
              
        alpha\_matte \= self.extract\_alpha\_matte(raw\_bgr)  
        despilled\_bgr \= self.apply\_edge\_despill(raw\_bgr)  
          
        b, g, r \= cv2.split(despilled\_bgr)  
        bgra\_canvas \= cv2.merge(\[b, g, r, alpha\_matte\])  
          
        column\_bounds \= self.locate\_column\_boundaries(alpha\_matte, column\_count=4)  
          
        export_specifications = [
            ("combat_flight_sprite", (256, 256), 0.85),     # Zone 1 (Vuelo limpio)
            ("hub_billboard_rear", (1200, 1600), 0.80),     # Zone 2 (Espalda con rifle enfundado)
            ("hub_billboard_front", (1200, 1600), 0.80),    # Zone 3 (Frente con rifle y HUD)
            ("selection_hero", (1200, 1600), 0.80)          # Zone 4 (Splash Art Sexy & Heroico)
        ]  
          
        output\_manifest \= {}  
          
        for idx, (view\_label, (target\_w, target\_h), scale\_ratio) in enumerate(export\_specifications):  
            x\_start, x\_end \= column\_bounds\[idx\]  
              
            sliced\_bgra \= bgra\_canvas\[:, x\_start:x\_end \+ 1\]  
            sliced\_alpha \= alpha\_matte\[:, x\_start:x\_end \+ 1\]  
              
            \# Extract tight bounding box around the isolated figure  
            active\_coords \= np.where(sliced\_alpha \> 25)  
            if active\_coords\[0\].size \== 0 or active\_coords\[1\].size \== 0:  
                continue  
                  
            min\_y, max\_y \= np.min(active\_coords\[0\]), np.max(active\_coords\[0\])  
            min\_x, max\_x \= np.min(active\_coords\[1\]), np.max(active\_coords\[1\])  
              
            cropped\_figure \= sliced\_bgra\[min\_y:max\_y \+ 1, min\_x:max\_x \+ 1\]  
            fig\_h, fig\_w \= cropped\_figure.shape\[:2\]  
              
            \# Compute aspect-preserving scale factor  
            scale \= min((target\_w \* scale\_ratio) / fig\_w, (target\_h \* scale\_ratio) / fig\_h)  
            rescaled\_w \= max(1, int(fig\_w \* scale))  
            rescaled\_h \= max(1, int(fig\_h \* scale))  
              
            resized\_figure \= cv2.resize(  
                cropped\_figure,   
                (rescaled\_w, rescaled\_h),   
                interpolation=cv2.INTER\_LANCZOS4  
            )  
              
            \# Place scaled sprite centered on transparent target canvas  
            output\_canvas \= np.zeros((target\_h, target\_w, 4), dtype=np.uint8)  
            pad\_x \= (target\_w \- rescaled\_w) // 2  
            pad\_y \= (target\_h \- rescaled\_h) // 2  
              
            output\_canvas\[pad\_y:pad\_y \+ rescaled\_h, pad\_x:pad\_x \+ rescaled\_w\] \= resized\_figure  
              
            filename \= f"{character\_identifier}\_{view\_label}.png"  
            export\_path \= out\_dir / filename  
            cv2.imwrite(str(export\_path), output\_canvas)  
            output\_manifest\[view\_label\] \= str(export\_path)  
              
        return output\_manifest

if \_\_name\_\_ \== "\_\_main\_\_":  
    pipeline \= SpriteSheetPipeline(hue\_range=(35, 85))  
    results \= pipeline.process\_sheet(  
        source\_path="valentina\_raw\_generation.png",  
        output\_directory="./production\_output/valentina",  
        character\_identifier="valentina"  
    )  
    for asset\_name, destination in results.items():  
        print(f"Exported: {asset\_name} \-\> {destination}")

## **Technical Synthesis and Production Recommendations**

Achieving deterministic character turnaround sheets across the Gemini and Imagen image generation pipelines relies on three technical practices3:  
First, spatial layout and character identity must be decoupled from negative prompting2. Multi-modal diffusion models interpret negated tokens as semantic attractors, meaning phrases like "no spaceship, no cockpit" increase the likelihood of vehicle hallucinations in Column 42. Developers should rely on affirmative anatomical and kinesiological descriptions, anchoring the subject as a human body in prone flight viewed from an exact nadir zenith perspective7.  
Second, structured prompt hierarchies should be leveraged when targeting reasoning-capable backbones3. When deploying models like gemini-nano-banana-2.1 or gemini-3-pro-image, framing the prompt as an architectural layout specification—defining canvas aspect ratios, chromakey hex values, vertical margins, and indexed columns—allows the model to plan the image layout during reasoning3. Allocating a high thinking budget (thinking\_level="high") ensures the model resolves column distributions and perspective transformations before initiating the diffusion phase10.  
Third, post-generation asset processing should be handled deterministically via automated computer vision9. Combining 1D horizontal projection histograms for adaptive column isolation, red-blue channel clamping for green despill, and Lanczos-rescaled centering allows raw 16:9 panoramic outputs to be converted directly into transparent, engine-ready 2D sprites and 3D billboard textures9.

#### **Obras citadas**

> 1. Imagen 3 \- alphaXiv, [https\://www\.alphaxiv.org/abs/2408.07009](https://www.alphaxiv.org/abs/2408.07009)  
> 2. \[Literature Review\] Addressing Attribute Leakages in Diffusion, [https\://www\.themoonlight.io/en/review/addressing-attribute-leakages-in-diffusion-based-image-editing-without-training](https://www.themoonlight.io/en/review/addressing-attribute-leakages-in-diffusion-based-image-editing-without-training)  
> 3. Gemini Nano Banana 2.1 | Gemini API | Google AI for Developers, [https\://ai.google.dev/gemini-api/docs/models/gemini-nano-banana-2.1](https://ai.google.dev/gemini-api/docs/models/gemini-nano-banana-2.1)  
> 4. Imagen 3 \- Googleapis.com, [https\://storage.googleapis.com/deepmind-media/imagen/imagen\_3\_report.pdf](https://storage.googleapis.com/deepmind-media/imagen/imagen_3_report.pdf)  
> 5. Nano Banana 2.1 is now in Recraft Studio, [https\://www\.recraft.ai/blog/nano-banana-2-1-in-recraft-studio](https://www.recraft.ai/blog/nano-banana-2-1-in-recraft-studio)  
> 6. Addressing Text Embedding Leakage in Diffusion-based Image, [https\://openaccess.thecvf.com/content/ICCV2025/papers/Mun\_Addressing\_Text\_Embedding\_Leakage\_in\_Diffusion-based\_Image\_Editing\_ICCV\_2025\_paper.pdf](https://openaccess.thecvf.com/content/ICCV2025/papers/Mun_Addressing_Text_Embedding_Leakage_in_Diffusion-based_Image_Editing_ICCV_2025_paper.pdf)  
> 7. Ultimate prompting guide for Nano Banana | Google Cloud Blog, [https\://cloud.google.com/blog/products/ai-machine-learning/ultimate-prompting-guide-for-nano-banana](https://cloud.google.com/blog/products/ai-machine-learning/ultimate-prompting-guide-for-nano-banana)  
> 8. What Is Imagen 3? Google's Photorealistic AI Image Generator, [https\://www\.mindstudio.ai/blog/what-is-imagen-3-google-photorealistic](https://www.mindstudio.ai/blog/what-is-imagen-3-google-photorealistic)  
> 9. [unknown\_url](http://docs.google.com/unknown_url)  
> 10. Nano Banana 2 Prompting Guide: The No-Fluff Playbook \- Fliki, [https\://fliki.ai/blog/nano-banana-2-prompting-guide](https://fliki.ai/blog/nano-banana-2-prompting-guide)  
> 11. Nano Banana 2.1, benchmarked against every Nano Banana before it, [https\://medium.com/reading-sh/nano-banana-2-1-benchmarked-against-every-nano-banana-before-it-6b02e32bffd6](https://medium.com/reading-sh/nano-banana-2-1-benchmarked-against-every-nano-banana-before-it-6b02e32bffd6)  
> 12. Nano Banana 2.1 API \- Segmind, [https\://www\.segmind.com/models/nano-banana-2.1](https://www.segmind.com/models/nano-banana-2.1)  
> 13. Nano Banana 2: guía completa con Python \- DataCamp, [https\://www\.datacamp.com/es/tutorial/nano-banana-2](https://www.datacamp.com/es/tutorial/nano-banana-2)  
> 14. Nano Banana | Google AI Studio, [https\://aistudio.google.com/models/nano-banana](https://aistudio.google.com/models/nano-banana)  
> 15. Google ने लॉन्च किया Nano Banana 2.1, अब आधे खर्च में बना सकेंगे शानदार AI तस्वीरें, [https\://bazaar.businesstoday.in/technology/story/google-launches-nano-banana-2-1-with-better-ai-image-generation-and-editing-at-nearly-half-the-previous-cost-1459824-2026-10-07](https://bazaar.businesstoday.in/technology/story/google-launches-nano-banana-2-1-with-better-ai-image-generation-and-editing-at-nearly-half-the-previous-cost-1459824-2026-10-07)  
> 16. Nano Banana 2.1 Halves Image Output Pricing \- XenoSpectrum, [https\://xenospectrum.com/en/nano-banana-image-model-comparison/](https://xenospectrum.com/en/nano-banana-image-model-comparison/)  
> 17. Nano Banana 2.1 \- Model Card \- Google DeepMind, [https\://deepmind.google/models/model-cards/nano-banana-2-1/](https://deepmind.google/models/model-cards/nano-banana-2-1/)  
> 18. Mastering Image Editing with Imagen 3 on Google Cloud \- Medium, [https\://simonleewm.medium.com/mastering-image-editing-with-imagen-3-on-google-cloud-95361c150626](https://simonleewm.medium.com/mastering-image-editing-with-imagen-3-on-google-cloud-95361c150626)  
> 19. Nano Banana 2.1: AI Image Generation and Editing in ComfyUI, [https\://docs.comfy.org/tutorials/partner-nodes/google/nano-banana-2-1](https://docs.comfy.org/tutorials/partner-nodes/google/nano-banana-2-1)  
> 20. 使用Gemini 修改图片 \- Google Cloud Documentation, [https\://docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/gemini-edit-images?hl=zh-cn](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/gemini-edit-images?hl=zh-cn)  
> 21. Imagen 3 Fast Image Generator \- AI Free Forever, [https\://aifreeforever.com/image-generators/imagen-3](https://aifreeforever.com/image-generators/imagen-3)  
> 22. Thinking | Gemini Enterprise Agent Platform, [https\://docs.cloud.google.com/gemini-enterprise-agent-platform/models/thinking](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/thinking)  
> 23. Soft Effects \- Foundry Learn, [https\://learn.foundry.com/hiero/13.0v3/content/timeline\_environment/soft\_effects/soft\_effects.html](https://learn.foundry.com/hiero/13.0v3/content/timeline_environment/soft_effects/soft_effects.html)  
> 24. AdolphGong/aged-despill: Alpha-Gated Edge Despill · GitHub \- GitHub, [https\://github.com/AdolphGong/aged-despill](https://github.com/AdolphGong/aged-despill)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAaCAYAAAC+aNwHAAABAUlEQVR4XmNgGAWjABNwA7EzEEtC+axAbADELHAVeIAuED8C4v9A/B6IfYA4FojzkBXhAiAbpjJANIFsdwHiXUA8iwHiCpKBFRBPZIB4CRlwATEzmhgGANneBcScaOL8QLwDiI3RxOGAEYhDgLiRAbuz9YH4MBCLoEuAAEhzKBAXM6A6MRUqXsoACRNQIIO8JoukBgyCgfgXEJ9mgLgA5JJJQHwCiMWgakD8dCgbBagA8WIgFgJiTSC+zgCJShAN4oOAIBDvA2JTKB8FcEAxDID8D/InsldABu2HipMFooF4KQPE8CwGSIyQBFyBeDcQVwGxIZoc0QCUqLBF7yigFAAAbp0evQLxKTEAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAcAAAAcCAYAAACtQ6WLAAAAkElEQVR4XmNgGOQgCYh3A7EwugQHEG+FYhAbBeCVlAHiJ0DciizIA8SSQBwKxL+BOAKIxYGYFSQZD8SzgPg+EP8E4qVAPAmIlUGSIEC6fTDgAsS/oDQGqALi50CshC4Bs28PEHMzQFzZxQCxikEEiK8yIOwLAuICIGYEcUBEIxDfAeKVUDbYj8hAAIpHATIAAP3zGM9f3v8PAAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFsAAAAaCAYAAADYMiBQAAAELElEQVR4Xu2Ya8hlYxTH/zLEuBUyhEK+MCQx4xI+KKTcEuUyLlEu0TTNDBqXGqFcIuSWQhS+jOSDXBKnfJEvSkQhL4lQlOKD+/83az/eZz9n7/Pu876958xo/+rfPmevfV3PWutZz5Z6enp6FpU9rFOt86xDrG3r5p6Fso11kvW+9Zp1caW3rc+tFbOHTpT7rL+sfyrxe70iAB4rbL9bl8RpOtj6JrP9YB1e2abKdtY91pcadiq2J62frSML26Q4yvrVet3asbDxvL9ZzysCJmep9bJ1doNtKuDMx62frJWFLXGYwtmPaDoPfZD1nTWwdq6b/nP2JmtJYTvRulPTeeZGrrH+rrZt7GN9ZX1s7VnYJkG6/7vWLtl+AuUZRZkYqD4QZMBD1gHZvqlCXfvW+sjaq7DlpJdF/J40DDADXd7/FEWJozYPVHf2OdaV2f/5QrNwmrVr9X8n64hZc3c2KqKC7Sj2U7xQ+bKTAicOVL8/+55QlL4yEHAQkyfbhYCTmSvw0RfWMdYG66z8oC6kF/jDOqFuGgI7x5VpXHKb9fUYYsLbffOZo0nP+otmoyp1S00DsVoR2aPgPLK5ra3dzXpB4WCC7UzrQ+tGzWMOGKc03KRuGbCYPKuIMjoTnPSowmHlQFAaifiya0kcar1oXa8YrIGiXRzlQGznWzcr5ol8P2VlTtomnRJG+D3rR2t5YZskOJvsosO4VVGvYQfrVcVAHG3drhiQEhxzuWINkWfTgdYn1nHZvhzOu9Rap+Es4BzuXXZIQ6RJh1q0rLDlrFJ0K9xsLrgpg9hVo9K45C5Fdt1i3at6hDEQtH/XKZzdFKUM0qeKyM9Jg0XUlvBsa6xr1XzNtdbD5c4m6ElJJ/pn+mge/g7FavH+6j+TD3Zm/Pzl2mCFxhK/q05Xe7qXpFKGw8oMw9nYZjTsTEilZmN992aSs7lGDo4mwCgfydFsGUzqN20li8CBwunbV8e0woowOfNCxYWBGkaUzFgPqLtDFhNeCIcSEGWUpYFg2wRl5Xs1NwIpw7l+guszEf6p+FzB7wus5xQrUvzBee8ovh11hhXYZ4p6SKoyabyiiPCTFTdmlLtE9mJCNPGc+5cGhZP5ptPW6nEurStdRQkDwEDkdZ6SQ+TiVHzAfMVgvmXtXR3DeW9o9HzXCI5kciG1ebCrFI5PnFHZp8m+av+QhG1UhFGuZjTcdaUV6IOqZwsdRh5clBoGMj/manWs13NxhWJ2p2ZxwZe0ZZSS+UI2fGAdr8jcu62LFN0JZYGOaxyY7zZZ5yqufVndPB5EAmmDqOltH6i2JigHLEqeso5VtLM3KL4Mdu2IEkQ42UAjQRs67mDVII02KKKaRcD/BUoDbS4dy9PVb+YsnD8uOJx6XU7WPQWp3SNz31SHRUnPwmDC57Ny+prX09PTs6XyL+w6026BEoxWAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHkAAAAaCAYAAACTmvO9AAAE60lEQVR4Xu2aachtUxjH/0IZM5NQrpCpkJAyRMiQyFBXri8UH0ghJD68kszzJUm5SDKkZMwXt6tkuJkiZcglUYQSPpDh+Z1nr87azzl7n73PcN/z1v7Vv3PPWufss/Z6xrXfK3V0dHR0NGMr08ZxsAV8l2t0zCmnmu7U5Ea+x3RmnBiHY00/mf7L9Ivp/OwzN4b5F0ybZ/OzZj/Tlyqv4WPTrqZDTN+GuTWm7XrfHFz7ymJ8VhxsesO0YzZ2nOkr+Tqb6Hj/Wu8eXjEdVryfmEdM/6r/Azl7md4xrTBtEubWJ4/J13hiGN/A9KTpT9OhYQ5OMT1v2jZOTJlN5QGwPBtjbTjW06bdi/eQ9vuk4v2GpmNM61S+B+ZfN22RjY3FNqb35D+wS3mq54UvyRe42Nwkj8bTwngy8t+mI8McaY9N3j+MzwIM8pFpp2yMfz+jcmRX7TeGfEKeoRLU5bdUdpyx2Nf0s+ll9SMVz7rMdLPcQ+eBa+RGjnXqcNMfxVx0gBNMV6gfQbOC6z9qui+MkxkvD2MHmn4zPWfaKBvH+Hx/y2wMcO742dacJ98gNhGotw/I6/KsN6cNF6u8TsABH5JvcDQykcF95FE0KUQmv3G0yo3V9qZPNeiA55j2DmNxvxPU4Is0uOcnm75ROcJbg/ekVMeCPjC9rflr4dncuDlnyDNOivJ8js1E04B9YU+ekqfO60zPqp/lUgPI6yiox8NKSxVc8zsN7zcakeoDnnKJ/Ca4mbwpaMOeprUa7BjrdG7vm6NJRmaTAM9/sHiNDoDXE+ETNyzy9MoJ5Fr1o2wHeXlL9Zff/8G0R/G+iqp6XMfOcvvEUtSYVI//kXsnKQhPZcMw+ER1YMrg0dReumy4UB7JkDsAhrheXo8jW5seN31u+tC0qhjDUV4txplnDIjUF+WRtKwYw7CUgavUNzq/jyEwSB3pHtrU2GTksbNSqg+5l3ITn5l+NR1QjM0D+QbtI4/UlC5pcMg+OACdNA1j1Sam+plvGsdEHCMes1KT9Jc865DlbpOvJa+dTY1cVY/rSEamgRyLqvqwIF8Mr22gK6fRYWFN1TSlkgpJiWvkT4PoqhPJATiu3KL6IxOf/UKexTAUZekC+dojyXlGGaWJkfktGsRh+11HMvJY6TrVB57GpNqSIIKJZCI6ztVBZ85jvbNbiM1uQrpZoup2lSMpGRmD3BDmInTp3Df3dbXp9PJ0CZodHrIM2+DN1HcMjPa9PPKrGKceA87NtemyW1NXH3jPONG8IswtFhgFh+SGafBykgMQobuFuZwUTTwBu0N+vUtLnyjDCYMUzVk1B+PTs1DLAUdlXUR+FXX7XQe/xTqbBkMPFsKCMGDSj+p3uaTbd8P8Jxrc2PUNaX21hqdOjLxOox0y1eN75fUcAxNdRFkVB8mbNI5MD8uNfrfKz+/T2sgSORy93pf/PSDfz9/lWbLJkYs6vlrNy9qSBu8/QsP/OMIcNXrU07m8HsMyeZTEhxiR1GugYbUbFtQ+SkfBtcgYC2G8owYi7U31Hx2SvleaXtNoBxkFmY6In+aJhGuSORY7iy4JqJ23mr4uxHGJjEAqXit/TrBK9fW8CVea7lJ949cUrkETSXM4jet1TAkeJt1vOitOjMFR8vQ/b4+XO+QZgv+sMOoRZx0csejoOwN3dHR0dHQsYf4Hg6AeSFqODAgAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHQAAAAaCAYAAABmZHgNAAAEsklEQVR4Xu2ZWciuUxTH/zJkTOZMGZIylClRxotDJBIu6Lii07nFMYTUJ1xwYZ6SnHMoMpQLSUp8RREu3OhIXJAIuVFcKMP6Wc/y7Ge/z/hOnzrPr/6d7937Hfaz1l7D3kcaGRkZ2d7Y07RrPjiAHU37mHbIJ0aWz8mmzaa984kB4MhNphuLvwexv+l909+J/jCtS96zi+ml7D23JvPL4Hr5utI1PC3fzTx8Oven6V7/mPY1fZTNXVjMzZvDTO+ZTkjGDjS9a/q2px70j2ln0/OmK4vXg7lU/sBb84kCDPei6Q75j60FB5u+MX1hOiCbw5jfyTfnXtkcu/wx003y51gE/MbDppVs/CLTNtN5Ku12sdzWj6uMwEPkjse+wYmmD02HJ2O9Oc30m+k1007ZHJxhesG0Wz6xRKgrn8idinNTwqHM876UY+TRvMi1Y3w2Gv8GOIuIuyAZg/vkDr0sG7/NdEXyGj+QGVeSsd4cbfrBtCov6ikYYovplGx82bCuVbnjcGCA4W6XGyl3NnN3yzfkIsEZb6raDFHOnlLVnnuY3pHbGpun8AynZ2PrVb9JOznI9LUmDQLXyo0yuEDPGYyF0cgkZJSAmkX2oFbm6+d981o7NqI0natq2Yl1pekSjjddno21Bc4Gec1NOUn+TLmjO4nd/4vpuGT8SNPrmvyhtWKrqg4lLT0gN/JqNofRH5Gn3Fk4Vr5ZSH9Xm+40vaoyhUdtx9ldRP0k7fYhvjtNxb3AMNTP31XuBnb1/ZrM9V1gwE812cG16Zp/P9kNDsUgGAbOkacq1po7m3XfUPw9LUTIzyp/A2jIiEgiFvi9H01nF6/baKqfTUSgkdIH86z8x2KnYSw6sbXqauvgwWKNRAidZXSBqbP3Mz2namZh7GXTl6bPVHX2Xaav5F1ybGi+/w15zT6qGMOJT5huUelgHMqmTMtAHeGcuvrZRHymb0RXCGPR3nMwJsXMmq7mTayRZgFtTOYeLeZwNufWvH5BNCV5veM5GUuPNUTnr/IzLg4j7ZLecVxak/s6tK1+NhEOJdgGQ56O/I5TU2MNAaMQGeT/vur7gDiRNT5kelLVG5l0QxK5TccUIhkFZCCcmXbOsM70l7rTXV+HkmaH1E+YKeXGA2yTd419jZxDFFxiumqA0kasjbgA+UmT57twKFFFuWgC56VHjPNVH82kXnqKumZnd5XRTOR9r7KuNzG0fkKcvdmkg2GH0VSgRZ/bpiW6xFc0WdvD2aSnusuRgMwTN0rUVRqe/LuA6CfN5hGFoylHfBY4b36u9ow2Tf0EsgbHSYJtMNEi36P5nNsWQVt6w6FESlfd530856Hys19695rDZTsNFMeUZ+QOJt2ThQJstVlew1PIAFvka2KjhbhPptHa9N87m6FzZrOw1sGwS89SdbH/N7hsJ0LqNhxzp+aDNfB5HHpdoS6iJ0BNd8GcTz/WFDc6HazIs0FbxtnuoV4TNW+rTJuzwvd8IL+Mnxd8Jxf2bf3AiPwsSRqdt6FodtIbpFnhypX/VKir7yMJpGsaorq0PQt8HxcO6aXDtNAHvGU6Ip8YWS5E082mM/OJAbDZ6Kzzc/HIyMjIyMjIgvgHHrICXmZDpc0AAAAASUVORK5CYII=>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAaCAYAAABozQZiAAAAvklEQVR4XmNgGLnACYjvAvEjIrELRBsDAyMQTwHilUCsAOWDwBwg/gfEHlA+MxDbA/EDIDaFijGIA/EqIBaDCQCBIBCfZoAolEYS5wHixUAsAxMAOaEQLg0B+kD8CYjXADELkjjI0ElAzAsTCAViNbg0BEQD8X8gLkcTFwbiNAaE17ACkH9/A7ENugQhgMu/RAFjIP7KgOlfogAu/xIEoICYzzAk/AuK43NA/I4B4lcY/gLE1xkgBo6CUUAeAAAc6iv7Yi1TmwAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIcAAAAZCAYAAAAbiz05AAAFe0lEQVR4Xu2Ze+hlUxTHv0LI23i/5vdD5BXllWeTvEUyQoiJPJIShRIpmkjyjkgmf0yekUJi8k6ivDIUyaNBaCihkMf6/NZZ7r77nP27587V73cz51vf7j377LPPXmt/91p77yN16NChQ4cOHTrMDiaMp+aFFVY1Hmu8q+JJxrX6ajgoO814r/FG4079t6ewinE/4+3ytmiX9mcLvPtkuf0lrGe8WG7XldV1irY2pe1cbdyi//Z4YWfjhcYXjH8aH+i/PYXVjXcYrzFubzzX+IvxA+PcpN76xueN1xnXMe5p/NA4P6mDEy83vmycNM4xLpY7i/fMFBDxccbbjF/J7dmrr0YPhxo/MZ4pH8zLjI+rNzna2oSv3pP7b03j0caPjfsmdcYKiOME4wHGZWoWx1HGJcatkrIzjH8b7zOuVpVdYXzLuGFUMpxu/Mi4WXXNAHxrPOjfGtJ2xi/k75kpMLAMzjy56Evi2FUunlOqa+z4VN7fmPVtbMJH+Oqx6n9gofFZNUfhsQGGYkyTOBj0EEJga7mYcBQOQxAII39+H+PPxuOra5yROhasa3zVuEg+C0tYWz2RNYFnt1RzOJ8O2NckjhjQpcaNqzLegeDPru6DNjYhlm/k70pxoprfPVaYThx7G981npeURf1wChFouerPYzTG40BC6dOqO5IU9JLqUSfHJsZH5P3JwQAskKe/YdNTSRyT8gnAbF/DuKk8ZaQCbmvTYca/VBcHqY2Jh+CasIE8HVGPyM375lXX9CWAzUwc+gDpK+KlTlo27MSZwnTiaAIh9A/jE/IOhwjy59PycFjJkXl5E4hYhOE0T48iDFASRwzoU8Z7jJcaHzS+Ju8HKPU9Lw8RlMSRlwcukacs6rwp9zdCul7e54vk9k8Yn5RHaeq+LhfTo9U15Q/JxTY0hhEHA0C4/FG9QQoj8+dTceTRJpA7chBSgYwqDFASR9iU3uMdDNBz8n63tSlScy6CQeIA4cOb1Jv52M3Cn03E4VUZmJCn+lgML5CnxpHWNMOIY748fzKzAizuBomjaTEHcke2QQjkTo0mDDBIHKQNomOA+kQU7G9rE1GnSQTDiCOvs5t8guaLXMaH+my5iXTsIkdCW3EwW9+WLzRTzFRaCTBzcPj38p3WKCiJoyT4NAqU+p6Xl0RQKk9REkeMWb5Wwze3ygV8TFK+wmgjDoRBvt2hukatbGnJY7Eaz58Pw1Ax9VF5yZGs7lnlDwLGk2uJGNvKw/woZwUlcexh/El1m1JxtLUp1mj5AIc42LWUMEgcud/wz1XyZ5ZoBiLHXLkT+A2wvSO30bFwRh6CCb2/V78AA5fLdzcB2lkqP10chFQYkUo212gCKYkDp76hetimfqSVuB5kE4vDz5PrwPmqP5ujJI79jb/JUyt+CZBW8M+B8rTD2iS9PzRCHItVbwjnv2L8wfhlwu/kW8twHFGE8snqmnboGA4O9RJ1lqn/mP5geVsYOx1oj9NcQma+xhhFIDj9V9VTJbhAfoq5TXWdL0hBG5uafEFb+I91QSq+HCGORerZHZsC0ioHdYB3HGl8R73dFBOJRSuCGRqoH8NogPAG2fa8b9y9qhNhtIkLqzqADt9tfFF+6oozmD0co6cghH4mPzc5S37EzqDnosyxi/Fa1YUR2Ej+PYffQeBAja0dgk/t+dp4c1aPQWCdRV8ZSI7A5yZ1QBubEMUzxofl65n71b8tLiHEwScOPk8Qrfl0wdZ2x6rOEeofQ9Zj9J20EmXYGtFuVoAz6DAf5g5ReSDnyPMt5P8447+0ia0og01b/LY5lErTCvWbDuM6rKQorTk6rORgJ0gkYqdzi0Y4Au/w/8M58jVG8Aat4BF4hw4dOnTo0KHDuOEfTUqAvMneNVcAAAAASUVORK5CYII=>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHIAAAAZCAYAAADt7nrkAAAFhUlEQVR4Xu2YeeilUxjHv7JEyDKyy6QZkj1bhMgSScmYCFnLHiH70lgmWbKNiWzDaJKdJkXEjT9shWQpkiVL0hAhS5bvx/M+7rnv/d3fvdfvN+NOvd/6du973vOe8zzn+5znPO8rNWjQoEGDBg36YT3zUvMO83JzWuftfzDT3NVcxVzGXNs8yty27FRhJfMIxXizzQ07by8RbGZeq7DhHIWPJVY0jza3rP4vq7DzRHNqu9u/KMeboeg/UtjJfNbc3dzGfMr8S+E8goHlzIeq9pIPm6tVfRKbm2+ZFyoWhgB4TSH8kgIL/ajCH/x60/zNPKTos7r5qrp9ut5cvujH/0vM183tzU3MhebJRZ//HeycJ8zj1Y6wKYqF/0lheOIu8x3zM/MR80B1RyVi0QcRCYKVzefUPdbixDrmS+Y+agciGeZL80Nzo6qNzELQYu9H5r3mzmo/k0AwnptaXR+gEPy+7DAKIN18av6giN7ERQpjzy7a5qi/GOebixS7MrG3eYEiaMbDmhV7gaBZX90LXQc2EjiIg6iAZxYofEIIgJCIUU+5JRAdEW8p2shA7FBEHxmQNm42n1GnQwiC0/wm+gmJg68oUhC7GrJD67u2F6abj5sb128o7LzMPFf9hcQO0uo8hVgJRMOng6rrQYQ8XPHMkYpzlL7lmGMB+/Adf8haBCc27VeRLJXIMZM8xzHGupVt/XweEwxE6vzD3LNov9W80XzD/Nx82dyuuM8uZDci5lzzYoX472rsgmgs0I+gKsUcRsReWEMRYF8rihaAIA+aNyjS6xfmk+osdNiJCHmleb95muL8v0ad52gJxKEo+tH8U7FOBBVBcU/VjsAAf1kvzm/mecDcQGEr198qxmLMoUHKIDVRnZXGYgxnX+4wKlYmolgCmdIwPosKFh6n39fglWsp5mSICA5TBOZ5ao+DkMzDPdoggn2gdiDlLm5V/QE77StFMTge2Pk8e4Lac+IPReM35hZVG2DNOd6wj/W9Wp1rPTRIARQnRF+ZAsCq6hwYYdiZRBG7OIVkB65V9EuHTira+gExnzfv1MRFRBQCaZY6A5Mx8akce0fzZ0VfkEKWtiNoS91+1pF+ZypP7K8I9tlFGzYgIhuD44zs12vH9wUP3q5INf0KE5CFUhYVFEtEVUud50g6xKIMCmwhrTE25f5/BYFJZXqmBovuDEaCmUCmUq+LkULSb7yaoZeQOQfHFxsgwZovNL83ty7ah0KKWG5nzjwOZ3CcIorKd6cUEvIfMVn4liYmJLZcp9iJpB+EyFQ3DFLETJ1gD7XPa1L+7+a+1TXIRW4pfKBqr4sxWUIuUGc2wG/W6Bd1H2sDgcHI92dV/xOkkzzrsoothczU2lI4R3SRZjmoKS4Sw6TWUsS0hYAaVkzGuUmdHwDAVYr0CVg0zs1SyEyt8xTz72L+qqhaExNNrVkJn160MRc+w5mKAKMGGRgMcKzCeEThZT9Jvt6t6odD9bxNpBM9M4o2FoWDPCOV8QctdhibvvWAAsOIyTizFAKU/uDfJ2qnahaU99uci18y0ndqF3CZ7kixmQana7hihzFzDrLEi4oqOb90kQEpiPi6lmc2a13a0ReZHpmwToxNp3PXvqCYlPNrkXlqdS/BIvKy/LHim+UcxQLuUPTphb3MM9QtYmKaeYW5Qv1GDZm66v7AMltg61zFO+cx5nyFT/nBIEEQvad4dcD3t83b1D/1pZB8OXvavFsRSI+Z61Z9eJ0p7WPuPKKyjSp6q6r/pIEvHQcrzk6iqxfKfvXqd5RA0GxqHqp4Z+71voZonK/0o3+vYCtRplaeRyC+7zZYytDrjGywlIDdOsU8RSEkv1wPsosbjBBIz1SfvEIkue6Vths0aNCgQYMGiwl/A6xLQEs9I6u4AAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAAAaCAYAAADCDsDeAAAEdklEQVR4Xu2YfcidYxzHv/KSMY22SJSmtSWySVbysiUvWyIbiaH9sRaKrLUoL3Ukf6y8xUx7S/tjeUlY8hLiCSH8QckWyaNk8QelUUu2/T797mv3dX677vPczto5rPOpb89zrus+97mu39v1u29pxIgRB5cjTVPi4AAZ9u8fNNjUOtPcODFAMO4TpsVxoi03mn4z7cm003RbftGAOcL0tIa7hsRU0xs6ACcfZnrWtNt0aZgbBpeZxvTfSckFprdNk+NEG04wfW4aN53SPTVwJpneMt0RJ4YITv7YdEOcaMO5pj9NL8lTcpiwlu9MZ8SJIfOw+rTPTfJauzJODIFbTR+ajosTFdTAq0wz5eXsWNPlphn5RS3gsLpY7szDs3HuSSbnY7DQ9KPp1DDek1Rv/zZdGOaGweZKJa4xPScPho9Ma03Py0vID6b5+67sDWm+xbTK9I1pWTY33/S76fxsDHDCT6bzwnhPUr393nRSmGvL0fKIwlGkzb9OnQoOjDF5CkbONK2RRxzcY9olN8KT8sy7upqbCLIDB3G+jJs62Ry/jRFjhJ4sj1yypjWlenuBPDUx+Geme8PYl9UYxrxdvmkWu8G0VX7PJaZP5IvnHnwfZpneM30rN8ox1Tgk42K4yPWmi7LPG+VBQXBQIpbKD8OJYI8PyI3FAfWX6iglSF6vxP85ybjsszVN9bbkqTSWNs+h87Lq+sjmXpAbF8iEbfJIyaG1KS2yl3FzUrZRznBwP2BkSsynqlu+00075IETSXuPdmqkV71tY1yKPFHJZhM8lCTjcn+imtYqRRVjLH569TmnrXFTtpUc1JZUEvISxH7+UbnXL9mjJ73629LNonExEPXpA9PNKtdsnPaLaoPzOx2VI45oojyR8hE6ghflayATMG66J4573HRi9RmOr9REclC+PwxN5BLBEcZ+ljugFaV6m0iG5MlkfSVO2F3qjqx58tRPj87PqD50gJQj9TrV5+tMV+yb3R/qcKx5tFvvyp10tukV+dpYI1xrul+1w6jrXIvjSxkCs01/qDbuafJzIP52gi6B82bC/vsWuRfy9wm/qrslaRO5ORhxufw9BTU1h+sxMB3FfeouIxFO/K9N07IxjNaRH4Svyu/xZiXqJg7BAQlO+q/kj/NNaUwAEAgExibTdrkdSnsDStCY+nwEjrQxLu8A8lqNEaixcYFnySNphenOMBch0thoPAO4N85Jm4ufS+DspjTGGRiY0kE5WaTuziEnHX6dMN43bYzL3EOq05G/T2n/fjO1OOOq62QT3IN74qR0337AII+oXBbOkT8opNqOgyh/r6nczs2QZx5/D5g58jrMyUmvSrlgLNXcL6oxjPuO/L0rPSNdAN1HKZqY59VdafER0vp9+YNDv1CaVqvsIKKZ16pXytfzmLzriQ8OwPcfNN1d/T8wjpKnFpFJVJOmTQvgurwuTgTvT+kO+nntSNTy0NH0XdbxqDxwiEhKVZPTeXAh0Jru9b/lEtNdcXCA0DbSnh1yhh0xYsSIQ4G9teLfxXPNx/4AAAAASUVORK5CYII=>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEYAAAAaCAYAAAAKYioIAAAD90lEQVR4Xu2YS6hVVRjHv/CBohWWKKHhvXFBwqAkHJipDVJwYIMCFXIgRGkgqImm0uCINAhUfIFCPlARFYIQfBUh6sSgUZAIhnCDRBqEECqo+Pj/zrcXe+119z6ec9R7Gpwf/Ll777XO2mt963usfc26dPk/MkQaI72QNgwSnX5/KcOkb6WP04ZBBIOsllZl1y3znnRDepTpsjS20KPIHOmBeV/+/iK9WujhE9pqbU7oGcIGHZI+SRtaYbN0Xfpbmpi0BTDAUek/6QdpaLG5zhTpN6k3begQb0mXpNfThmYYLR2Wtku3pXeLzXXY/WXSeumh9FWxuQ59dmXqtLcE2Dw2s5Y8b4o3pO+lBeYhMr/YXGequWHWSfel94vNdSZIV6UP04YO86m5F5OMW+Ijc0+YJt2xgd4w0tziLPyUdE0aH3fIwCC0VYUiMT8rE9dUDrwTI3PdLOF3YZyYl0uevS39Zb6+lqiZL+pN6V/zihKz0Lwdw/RbdX75WjpvHpopk6QfpS+kHdIFcy9dI/0kbcm7NoRFb5M2SBet+LvJ0j/SougZvGZumJaqZMgv7DJewI4fsTxH9JgvGENgnKr8Aget3Gh43B6pL7tnt8llNcvHPGDN5SWq4jfSS+abcNxybyNk8PjUM1jjefN1NE3ILyMsHwBxzQIZrMe71q+r8gtgGJSCQThPBOZJd83HGWXuRVXhl/KleWhMNzdC7B14YtlxI6wrjYSGhPwC7BjeEnIIu0kYAYZrlF+gyjApTLDfPDTbpWZ+tOjN7kmsJNjY2wPBMHuT5w2pWbGKMGnyzAfSd+ZhAOwoEykLlUAzhgmTbDTOkygbAy/ifLU0u49pOZT4ATWecAqQP3BRXkqJDjwpvwBG5SRMeMRg1GPm+SEk+HiSn0tzo3sS7LjsbxkhmcZjkF+qwjx4U6O5F5ghnZRejJ5xhuEsQ3jFLsmiq14cYLfKYpwJMeZn0pLsOpyVqFYk//izgkpDn1r0LCYUiWAYSjQbUvZuYGPoH0dGKTOlm5Z/H90znzRQMX62fKJ889zK+oW+Z6VXsvYYfvunuVfEYMzfzeOf6rPJfBH7pBM2sP9Kc+9ksWWlnw3je4zQZgy8gblVVTbez/ueJqc9Fezcr+ZuncICMXaYeHqfws7vtIFhCRSCUEXxHioU+SU9vwRq5imj3Zz2TFgsnbY8abcLi12bPjQPiyuW5zIWu1v6wzwvpWD8c+ZR0lHYRfIWibZdGGO/+Zd6CtWH0+1yc6OsMP8+eyfuFMFGcbisSuSDCgmV3MHfdiDnzE4fZrBA8gv/SkAcKTgFl9EnnbH25/FcYHEbpeFpwyBBpaWSNnui7tKlS5fnymMj+ryGUrRmMQAAAABJRU5ErkJggg==>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAAAaCAYAAADi4p8jAAACb0lEQVR4Xu2XP2gUQRjFX1AhohYaESKKZyOIRQIBQRCEYGOhhUEQLOzUwkL8F0gVCCltVBCCiAn4p7ATOwkBBRFBsFArC0Us7G1N3vObMbNzub2d2T2Icj947M03s/vtm535dg/o838wQA1Rw+6o9r/AVtg976I2RH0FNPAF9Yi6QQ0Wu/8g4yeovXFHg6Tm0Ng5ahFmtCMyOI+1B+lpnqFeUeep19Spwoj61M0xg7Xv/S9lBieoj1TLtS9SS7BzmqJujmyDLeoLdTmInaa+U3uCWB1aqJ8jy6CWjU5Uov1BfJL6RY0FsVyaypFlUAmV+Am1MYhrXMrsltFUjiyDZ6ll6lwQ2wYrBNovO4N4Lk3lyDJ4H5b8B/XN6aeLPUNxxnNpKkeyQbWX0D6LmmklV5Xz6AWr99FoEKtC1RybqQuw952OasckG9TxK4qzqKP2SlgQpqjnsLEnXawqVXKorRwHYMYeUo+pTW68J9ugLu7xBUEXGwji/knkGizL4cdcdf1HYct5xLU9yQa3U+9g5dqj99RntFe2MoOaaX0nxjMuquSQycNYXcLHYQYPurYn2aAufJeadW3N2CdYspgyg7dg+2k6iouUHELLVUXpnvsdkmxQ7KPewvbEe2o86AspM3iF+k29hI2LqZpD6OvmNhoqMh4tLS0PVcpOlBkUOv8OtSXucFTJoSp9DatLfkexO99gFboZPELdjIMJaMmqEO2G3d91tNeBnhnUzC7AvhvfoP2/pK77gDoUxFLQ/8MPsH3spa8cfe2E9MxgN1TtjsXBHtDVoPbHU9inko6d9st64xLsnvVUtTf79OmzzlgBFqKZr0e6etoAAAAASUVORK5CYII=>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAkMAAAB4CAYAAADxG/bcAAAYh0lEQVR4Xu2dCaxsWVWGF1FRo6AgKIraDyPgAAIKIqD0awKoAUVExFZkDEpIG4MIAoI8QgiD3QwyNCCEVtMqooJh7IbQFzBMdmgkTGkwgBEMECAxaETjsL/etbp27XtO1al6dd+td+/3JSv31hn32WfY/1lr7X0iRERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERM4831rsG/qJIiIiIked6xd7QbH/KHZuN09ERETkSPP9xT5U7J+K/WA3T0RERORIc06xq4t9udiPd/NEREREjjRfW+ziYv9X7JHdPBEREZEjz62ieoQ+Wuw7unkiIiIiR57fjOoVurTYdbp5cvB8c7HvjCpEv66bd1zguDl+6sFejCIicsb5vahi6In9jLMAGtCfK3aLOHuFHPV/ebHnFzuxOOvYcCLq8VMPnM/D4NuK3bPYyZgLMsTZt+QCIiJydEkxxN9VfGOxXy32smLPLnbLxdlbh8bp9cV+pJuOJ+HCYq8r9vJi/xO1ERvj4cW+EvU40z5T7KeK/VDUXnTtvC8Ve841ax481HsvABB2dyz2R8VeXOz+xb5pYYkqIDgX313sa6I24Lcp9huz/4HpD4pahxfNlt0Ehlz47ajn/cnFvmdx9jX7Yz+EXPmf/bIvynJivljcrtifFXt11LrvBSz10NfFQUO9vrLYlVGvE14K/rHYqWJvL3aja5c8M/T3GNdnX0/Avcd8lmN51jtIqId3xuJ98l/F7t4sc91if9Et87hm/mGAmOX83rqZNvV6FZFjxFQxxEPlLcWeFjW0c9tiHyl2v3ahLfMnMVy2Xyn2z8VuFrUB++9YLoaARu+txb4Yw0MHZLiw39dB04shEtrxkjw96gP65sXeEVWwndMsd+diX43Fhuffi92rWYZGkuWAxvLxxb59PnsS7POyYj8T1VNyMqpY+MVmGQbpfG8slgVDsGbo74ejJujT8NC4c92cnM1LNhFDbL8XZ1PhOsYbxTXdhigZZuKzURvRISGSnFfsPVGvx22EOLnH/jZqQ01dI24594+JxXJQd9x73IMcA+Xn3lzXi0W9rVtuzg/nlntzCM7vn0cVlVO2/dBi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>

[image13]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAaCAYAAADMp76xAAACSElEQVR4Xu2WPWgUURSFT4hCEkUjBn/QoBEVBMX/QiJCJIWNhY0kUUGwUBBMFSVqERDRwkZRbGxShFjYCMZGEMuooI2SEBJImgiKCoKV+HOOd97Onbe7wsrKLjIHPnbn3bs779133p0BcuX6v9RFPpCfjk/khMu5EsUfkkUuXhPdIz9IdxygNpHn5DhpimI10TLyksySNdkQDpJHZH00XlNtIR/JGNIKNpJz5BppTsbqRsdg3ryQXMufd2A+bghJ9aRb5BvZTzaT12ScLPVJ9aLg3zlylozCJqsDeMjl1Y2Cf7+TS2Qh6YFZRJNfkKZmtJZchnn8ACq3js7IEdjvZcUl2XB5Bf8OIr3pSjJBPpOtyZjXCvKAdJDlsB3SIivRGTIAu+dJVGBB9d/gX68h2EL0GWsdmYZVaDF5Rq66eDtsp7xUUS0wSLvzFFbZw+Qd2eDiJRX8OwOrqpcqqwqr0nHMS3lTZKcbk80uIp20PvvJnkJGKlX4NrmL8vYraDf5CtveOFnXGleV9YSL1UJukkmUbn9h0mqR5SbbCXuCqv//qSi/H7/zyL4fvCe9SVwefRHF35CNSdxLD5XH5DyKJ72NPCH7ovFY6kb6f1ntn2gV6UP6AjRM3pK2QkZqAxVBXcB7WgvTJEPVw06fLmRUWfrjL2Q77OYjyD7WY8/GntbCtEAdeGkv7LyUevGqirR192GnWxV8RXa4+FGyy11LmvSp5LsWqfeU6zC7qN/fQHFnqarUpuR1HZa/vZFa4mrSGgdy5cpVQ/0CgiRnn0PtKzUAAAAASUVORK5CYII=>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAD0AAAAaCAYAAAAEy1RnAAADc0lEQVR4Xu2XW4iNURTHl1CEkHtINEiK5FLKZRIikUuhPHiQeCCFKJcayYNySy4RyYMIRckliSlCPCkhEkrkQUoo5fb/tb7d2bN9Z+aYZs54OP/6dc7Z67vstfZaa+9jVlFF/6K2onM6WEaV/f287IgYlxrKKJzeJ+anhuZQG3FQrEwNLaBu4oqVIfjTRK2VObXq0QxxXXRMDU2l9uKaWJUaWlAE/65YnBqaSqPFCzEsNbSwdojz5qVXsnqJ2aJatKtrqqMV4rbolBoyUWM8Z4hoJTqI6aIqvqgE0aQmmQe5dTTOM7smY2imeCP6JeO56m0eoQvm6bFZvBVjMntfMTj7jk5m5GmuOC2WiDvikDhjXgqvzANaikjXU2K9eCKWRbZq8UmMj8YQwWHeY5PxvzRAPBZHzSOLSA8mTt1Sv1vEhMxGo6g1T6VUw8UBKzxno/huPrn94reYk9kaEtlE4Aj4a1ET2Xg3zqUr2sd8pcmyosK5Y+YPGJjYmPBn8654wgpdOjiNPdVCMTH6zbMfmqciqb7UPIgNiXltNXeCzPtmhVWl7C5npCUYnCZYRUUj+mj5xc+NX80dXhSN1+d0LBzFYe6nBhujkHH3rRD0QeK92BQuihScXpsaYpEGpByplCrYLlnd1SnVaeqLoNUb9QYUUjsuJZrVTzE1GgsqKb15AI7lXcTYDzE5GSf6ZAapm4oOfdb85QQSp3EeEbi9omf2G3XJKKYQuHh+BICVZsVTMfbO3K+i6m++38aHDFJxinhmhYDQMLpH19CU0ppiW7ohPogR5jsBUScAaIF5QwypPtT82rx+EjTSvK8Ep2m6z+3vdwfRtV9aCecHHGQrOSeOm9fPOtHD/Dz7wLyL88IgOjAdPw4EztSIm+Ki+bZ3NYO6JFAEJohAPhK/LD/TELvAYfHUfG5hIYqVFqVUayUeRdnkSTsOFXHTYRzHwhYUxMowgbCNBXEvzwgvTX/nabkVT0eCxLspAeY3z+p28lih6dUk400mnNluvic3tjMjJrrL8tN7lPkBJPQOAscfirSxBlWZZymfzSbS85b5gaSx4gyw0/IDx+p/EbPMndxjXmrpgQRx/zaxIfverOL/K926MX8vWWUOM8XuJbV3i3vmK7ja8lcYcSBiRyn2rCYXjXBNOlhGsZezjZXN4Yoqquj/0R/VP5d25u5tEwAAAABJRU5ErkJggg==>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAkMAAABOCAYAAAAjOBJsAAANPUlEQVR4Xu3deay01xzA8Z9YQhBLUYJ0SVWoNaohWi2hqYi1UhpFUoo/VFFblORSQmONqi1oSUprl9raiN7StEJjSUpFSUuEINKQElXb+Tpzep859zzL3OWd2/d+P8nJe+88c2eeOc+Z5/ye3/nNvBGSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmStKfcIbXb1jfuQbdO7U71jTvIUP/s9H3fSkP9cHNxy9Tuktot6g0TbOZvtwpjjTEnSdpCD0vt7FjuhM7J/X2pPbPesAMM9Q+3fSS1w+oNe6n9Uvv87N9lIBg7KrVnpfaAyMEJbp/afWY/jyGQOTW1V85+noox+rZY/hhlrJ0b7fEoSdoAJpCLUzuk3rAE+6T29dhZgcVQ/9wqtbNSe2m9Yeb41K5P7b+z9rUYzqrwOOW+/0ztnBi+/0bdLbXvxtpztZ7vMan9o7P9j6k9eLbtiNS+HHt2Mn5gapdH7s/zU3tVap9K7aLIx+YbqT3hpnuPI7Dh74+tNwwggHpPLBZAbZcTUvtwmCGSpE3jpE42ZqW6fZmOiTzBkQFYtrH+eWJqqzEcFBBcMHn/KXIAcsf5zTc5KLULU7sxcvZhT3hS5EDn/fWG5HapfTy1M1Pbt9pGv3wgtddVt28HJvs3Rg7WXh95v7oIzP6a2m9jemaoeFDkAOu+9YYGAq4fpHZAvWFJ6IcLYvlZKkm62WMy+Pns352CwOKy1J5Tb1iCof5hMvpmai+rN1TuHTkD8YXUfp3aveY3/x8T/htSe3vk4IQgZU8g6OL5nlrdfs/Uvji7vS8L8ujUrortDQ7olw9FDhD7MjgEm2TcxrJuLWT2PhP9wW5Rgj9aX38sA+8R3itDwbgkaQRX9huZRLYbkzR1KUxWyzTUP49I7erIdStDDk/tjMiP9bfIf1cj+OEK/+zUfp/agfObt0UJIv4c86/hkZEDt/07t7VQREym5Ln1hi1Ulg1Pj+Eg5JORg8mNYP95HbyePgS0v4jFluH2BMbJLyOPMUlShWWNp0QuNG1N5CiT4dAkQg0Pj3Nw5MmIItWjIy/pLIIr/MdGDgRKwSt4TCah7m0gOCCLsuiyx1Ya65+XxPCyV0EQRKBDa2V97hE5M8GE+9PUvhW5n6cox4Ni4nKMpmIiJfBajbwkyd8+L3IN1NTn/1jkQt6pz8vjv6W+sQdj7HeRA86xZSz2Y6OBykMjjzWCwD489q+ifzwyfhnbHAv6jv7geLCMWi/rjeG1MkZ473UxHuulY56L8dI3RiVpV2J5g4zKlyKn0E+LXEtx6Gw7E+79Zj+zXMMkQLDT8vTISwhcOV+a2gdTOy/ystA1kQOtKUjhM2G+OrWfpfbCzrajUrsu8pJLFxML+z00QW23sf4hG0EbQmaLZR4yL0yo/4n5TAqT5imR61F4zWSOptYLMWH+JeaLoCmonTr5lv3h+ZhUCYL+HuuPxRACvbGAkEChFPly/9Jn9M1Q5m8l+uuZapv5qHk5zkO1N+z3aqwPRsBzfzpyQTfvt59ErjOjX6m54r3Yd0FSYx/oHzKJPE4JiPh7Huf8WH/hwP0XCUglaa+2X2pXpvbRWJsYmGwIaKhtYZKkELWk1Jl8/9D5vYvJmfqI7iR2Q+SJksmpVWfShwwKAQCB2LUxX5/BhEHQU19xjwUiBZ/W+s0C7YqYntUa6h8mxdUYD1xKvRDBAhkICn27V/F8au6k2c/0Uytz1HJA5H7rBkKl8YmnKdh37s8kzrIYEze/L1IXw/HhOLXqoIoTIxePkyVh2YvX/5DI9Ubv6Nyvq/QvwdpGMz5TlecaKgYn4Ggt29JPb41cxI0ybnnP8RpZglyNdhBVI0P4icgBEPtCVoz3NA6MnMVrZYCGAjVJ2lU4SbNUwATJRNnFyZJJ+JiY/64cJnsChFYNy3GxdoIHj13qKkj/vyCmZSDYrzdFniTIVHUzD0OFr2VS2c56lDFD/TNlAkWpF0J5TSUzwmOsRD4eTKocm6n1QvRLHQSVNpapQel77n9h5IxiCbBaY6gPwdDYPhNQc+xZZiIAujbyc5wc/WOo9FVdzwT6ioCB+3Tbnbt3WsCUwJZjVo5b110jX2CU8VsCXo4Pr5tlQb4SYAqyty+KPB6+FzmgKsEXASGfpmsFhozBsZonSdoVmDCYOFpXr5yYWX5hsn125/ahyb6rFMry91MzBjX2iZM7J/kSjA1d7ZbJkKzFsgz1z9RgqNQLgQCFQKXUBD0/1rJOfO/PIvVC9EsdBJXG4/B4Q0rffyfWjgfHlqwQj8FS6BQEQ0z+BAFDWNqhH/iuohsjZ4j6AiGU40+rs070DwEIY4kAgf39Ucwvvy6iHEsC/j59wVCtvNdaY2YqLha4aOh+mrIvgwrGGIHmvvUGSdptmJSYFFhqqZVtF8T8BDQ02XexnRP8ZrI0ZYmse/XNctC/o321WybDsWUyrsjrDMFQY8KYWlsy1D9TgiECwA/FWmaD3wlWCVaOihwEluCS2igmwKHsRBcT5g2xPhCidTMKfeh77ls/X3ncbtA6ZMoy2aMi3+ey1F6R2jtT+2zkJci+JcESHA49djkGY5mpMVOO5ZRgiGN5dmw+S8N+dF9TKZJuZVDhMpkkzZTJrRU8cNu/Ujuyup2TLXUJrQnp6MgTFhMRAVb3apeA6r2RaxwKliiGlilKQNXdPybivolsaN+69ov8Saqp7WmRlzamGNqHEtgMZRMIAOnD7sTI/cmOMLF2r/LpY45f67laCOioDasDoeti2rd3l3qh+vk4ttSXUavDsuoYAuSxrAS1MydGfmwmbvqATNGxkT9h2FKyVEP7QZBJNrQVJPD4T45c9E8/0fi5BKZdJfM5lIWkv1pZOwLGM1N7cawFcAREJcilToptBceN981QQM7YWI214KZk8erAtejbN0nadfg47tUxv7zBCfnxkb80sARKTMBlCaWcvOtsUrkS5cqdiYxPsXSv0JnEWKYoJ/z7R77vUK1JqaUowRBBDN/b0prIQKaESbY1ee0pff1TUEjet//0zfGxfmmRYIAJvrtcWQKrvsCwD8HFayIHQGTYLolp9SljGZVSj0QgNzRpg+xWXx+08PrHMixFGSM/jvXLQ91gsA4S2HZW5KCrfCkh/4UGgQl9VuOxGWutDGXBGGAslPdOUS5C3p3a4yIvAZYME4ESr/Wg2e/gftx/pXNbjf1ejXycGDuvjf4MKtvPjWmfuJOkXYHA55rUPhf5k0EsdZya2t0j/39f34981c8kA06kTNb1iZTbV1L7duT/f+q0yP/vE40lGO7fvQplMuFjwEzyrcwUmKBYMroq8r6VAK1vaYIJeTWWm/rv65+CT9NdGesnSIpmSy0LjSCQiRL0Twky6MPzqvteH7l/bjO7/1YiI0HN0tDzkfFj4u1uJ6hrKUFc3zFsIaDev75xwMGRxy1LiOdEHhcEP1ek9vLIX9fAuO8iADo/5j8JObSPh0cOdMjk9SGzycVGHZwTTP4wckDylcjLgNyPPuU9V+8b23mfcLHRN7YPjXxhQd/y/uN4XRvt/SOrRf9M/WSnJO0KLA8w6e0T8xkJbmfSrq/0mTg4mdY1Dvwtj1FO2PXvLSfF+mWXgomf52Ypjf17RvR/p00ptl6pbl+Gvv7BAZGDOibT3YjXT3DbOoZbibG3f+TvvWKp85BYP46LkikpResloO3L7mElxuusyie8WnVzZMUY0+X7f+rfa7wPWVprLWvxNxTa8/pYeiR4XI3+/aPvOQYcC0nSBhHgXBr9dRlTcaJ+V7RPyg+PvJRD+h8EVBfF+oLugmUFJp7u8sKyDPUPE+3psdj38uxNToj5DMxOwDjku3pYZgVjiLFWL7MVHF8yoEfUGxp4vWR7WmN2EQQwLH3V2Heyp91P55HxodaOJb5aGX+03Tj+JGlLccJlaW0zJ3mChTOifVImW8RyCwWtPAf1G2RbWhMUf//myJNF67GWYah/eA0XR85W7CYEEQQGh9UbdgAydQREZHGoK2KprQ8BDt/aPSWgI4j/arQDk6l4DPatNV5KrR5jjUwUAR01U9QBtt4LBHrcvyx7S5I2gRMthbi01kl3DFe0x0X/R7E5yVM4ennkjM/J0Q4swBU6tRJ9j7UMY/1DQEAd0E7a5+1EH6xErkdr9cdOQHAzdjwIJqiDWySY4L7UBi3yN13UHB1Z39jBtksi13ZRL9RXEM/rY/mvLAdKkrYAJ1eKUflOmGWhQJTi2LFJbBnG+odC2VPqG/dSfO0CHxffqYHQFNTlMNZa2ckxBDRkL7ejyH0q6vNaS7eSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEm6mfofA3d4MHLkVmUAAAAASUVORK5CYII=>

[image16]: <data:image/png;base64,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>

[image17]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAkMAAAB+CAYAAAAnQhXBAAANfUlEQVR4Xu3dC6w1V1UH8OUzIiCPVpFQg/IoNhCL1IJgRW3QaFA0YCJEYghEqRFRQGzQRr4oJIpREQso1jRKGhSrhlSogGk/xIBBYsCUR1RCMYJBoiZGSUBQ99850zt37txzz+v2zim/X7Jyz53z6JyZ6bfXXXvv2VUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMzPw1rc3OJDLd7V4mWLbW9o8Xct3rPY9sX9G1Z09xbPbHHv8RMAAHNzSXXJ0OWDbRcttj1hsG0VF7R4XYubWry/xf0PPw0AMD9PanFbiwsH25IEpTL0gMG2dVxWXVVJMgQAzN4rWtzQ4vMG217a4sYWXzjYtg7JEACwF+7R4nyLt7R4zSKub/GJFlcfvGxtkiEAYC8cN17ogy2uGGxLhei5dZAwjePF1SVWPckQALAXTmO8UEiGAIC9cBrjhUIyBADM2oNbvLq6sUHvbvGsFl/d4toW/9zivS2eX+vfX+hLWrywunsX/Xd1SdV3HXoFAAAAAAAAAAAAAAAAAAAA3GkubfEfLf53EZ9u8Y8rxr8N3jcV/97iEQUAMGO50eKL6iCB+ViLhxx6xWqyDEcSn59p8Q918HnnBq8BAJile7X48zpIYPI42zaVBOvK6pKiD7S43+GnAYC7ilRDcrfldXxBi/vU4aUv5iDVoFSF+oTop2v7fbxvi1taPGf8xBaSpH3ReOOG8jnbJH3bmuu1sMwujz8Ae+6RLa6v9RvTNHwvaPG8xeM5eUqLz1aXDOXntx9+eiMPbPG7tf5xmvLEFr9Su2mMsz+/1eLR4yfuRHO+Fo6T45V17HZxPgE4Y99W3fpbwwG/GRD8L4vH/9ni5S2+rH/DwEUtbm3x8PETK0pj/nvVJR9zkkVZs1ZZfzyyan2SmW0dV034qha/0eLvW/xJdcnlh1v8YR1dy+zrqzvmXzHavol8z1e2uGr8xBmY67WwzNNb/GZNn1MA9tB11S0mesVo+6OqS4zeUl13WC9/wSdJOjfYtokMNn5ndQnBnCRx+Ys6SIiSoJx2o/c9i8hxfsni59DdWryhxVNH2zeVitf5mk91Y67XwnFyPm5q8eTxEwDsn3u2eHuLD9XRQb5pkM+3+J8WTxhsT8P1wcXPbaQ68braPqk6DekKybT4PiFKV85pOikZ+s4W762j52gTacj/rHY7jmlb614Ld6/TT1BPksT0HTWfhBKADV3S4l9b3FhdgzSUga1/XUerRle3eGOtP3B6yg9W99/If2tu0oXUJ0NJjE5zbE2fDCU5/cU6WolLdeoVg23buKy6brmc+zlZ51p4XHVJ/E9UlxidhQdVN1twXFEFYM88qbrG/vnjJ5rHtvhUi7+qg79+kwAlEcq9dI6Tro7vXvyMC6ob/3L/O15x4NIWH2lx+fiJGUjl4TV1kBC9q7rvchr6ZCjHKIOth8nQhS3eVyd3yaRqlM/41lqeqD67ukQiideUfO/HLyKPM+MrCVQa/TxeVf++/nOGpsZQrXst5PNz+4J8l1+u3Zyb7FOOY87DOMbVuiRhuQXDsv8XANgDqTaMKz+Rxir/0H+ixTcMtqdRSIOVRncsFYyfrG4A8g+1eH+Ll1U3ODbT1FONeNgdr+70n3dSQ39WMng6g6j7hCjJ0bgR34VlyVASitztOj+nfGV1lb0MwE7Xzc+2+Kc6OG8PaPHQxePI5yem5Pvmc36kumvjbS1+u8ULW7y5uplsq8gxyriyJAoZfzV8X66Bj9fR8U+bXgu57h5T3eDya2s66V5Fkv9c7/25HsdUNTTH8Yban5lwAIz0Y4JS/ck/6GnoE/kHPvfbSddMZo0NpUFOQzZOniKDcq+pg4Yhn5NGOd0xaUj+q4426P0+pOttmdwD6N11dDmMZfG0/3/n9r65umOUBjHT7U9j1tOyZCjbM+vvQYNtvSQvt9XhJK0ff5NxQRkflHPSn6/+eL908ftQXpsZUjnWkXOVc3auujFjGTuWa2KVhr+/FjIT8XyLP6iDqlK6wz5ZRytAq14Lx8l+fV2Lm6tLDseJ9zL5zuerG5uVc/B91c3yG1aGxolQZF/P19GqEQB7oh8v9NbqGtWT/uGPZVWK57a4ePG470LoxyJ9U4vvraPdLMsa57lII5vKVl8h2HS5jmVOSoZSMRlXPHJcMxMwCefXjJ5LI5311tK4J4HpuzmXJRz5TrnfTy9dm0kCk0jlfKZaNE6Oj/Oj1XV7pdqSxGdYBUrFKd1+6f4b2uW1kEQo194fLx6fJPv34MHv2Yd0J54kx3HVcU4AzFA/XmidMQ/LkqGhVDFSzZhqdIf6BjCN+pxlP3OLgT4h+rHDT29tk2Ro2eD3VF9S1Uki9AOD7cuSobEkBLdX1822qXN1OFnrB+VPdS3t+lrIfzPJULr97j16bpns49tquvo5luM4NRMTgD2Rv9DH0+ZPsmoylESrryoss2rjnIpSbjY4rF6dFLvuuvja6u67tItlOsb6ZOiedXQ22XHJULYnMZuqYPTP3VRd91dv1ePdv24q0VrV1GekWpSK1dQ+r7pvJ0klKDetTKxSFRrLtf23tVoVTDcZwB5Lo5tZOLfXen/5p+KTbqJ0oQwlOXhmdWNO0jAk0bq9Dj47icyvtfjSxe+9vlIwNZttKN00T2zx/WvELqeOZzxOP6bqNAdQ59i9ZPGzl4QyxzyJxFDOQRKevG8s2z7T4ltG25OUJDmZqr6k8f/96sb79FWnYWLywy2+Y/B79jEzuI5LDJO8JYkbfkYqVlMD9mPVa2FKP17oT6sb8D3uNlxH9nfZbLuhVM/SHXxW0/sB2MIjqrt3ztQMmWUyziPjPcZ/2aebIN0FuTFg/hr/mzr4izkNVWYjpSEcSwOc961TnbqzZf9TDcrYqn7sza4tS4aSmCQZGh+j3LogM/SeM9iWfb2yupti9olSjvFwfE4S1anzniQk73lWi2csHveJVsaUvbYOpq/nZ851qn+PXWwb66+JPhnqZyhOjReKTa6FXU+vTxUtA8/TVXmSHOt09+V4ArBHMjMqf633Y18SWY8sDeAq0gBkHMq4AUi1JA1IumXSmPx4dX/lpwrxRy1etHjNWCoEaRzXqU7dmfJ9k2yksV2l22RdU2uTZYxNlt7oq29999E4AY0kAh+urkvod6q7J9QLWnx5izdVd2+knI8kM710Yd5WRxOSnIskOGngsx+/UN25yedmf4aVtuxTPj/drEl0p+TYZV/yffIZuR5yveWzp6pJ61wLSYIyID/f95qaXj9vExdXN71+6liPpZKV45vjCcDnmMy8SSMwnkHTj+vpKw7j36ecq24a+KbjUk7bU6pLEIbJxFk4V8eP3+mP87jLKtuT8IyT0HQhpXI01VU17voa/z6WKs6wMjWU857IZ6RKlApSxguN7y/UO1erXwtX1encfTrHLN83P0+S7/OB2q5LDoA9lcbiL6ubtr2NfM4t1VWr5ijLb+SGi6e5DMeqHtLiPbX9enCRxCZVn2sXj7eR7sOpbrJU0ZIo9ONpkuC8urqKVBK3sblfC2P9MUxsewwB2FPpGkjXzHCm0rqeXt2A63HlYg5SCUpFKJWhbaWxTDVk2+nX6XL61dpN45tk5dYWDx8/sYYM6L6upq+BPPfx6qpGSYRSxUli+cjhiwbmfC1MSXKaRO+sK4YAnKE0yBkrktikcU5jcnPNszHpE6Fn1Gbfbewx1d2BeSppWEcShYwv2kWCFql4vb42HxTeD86ekn1N8vbORfxSHT+uZ87XwpR8t4x7WnfZEADugtIo/FSLbxw/cYJMWc6U5OMa0rOUxCCzxnZ1L6EsOZH7Mk3NpNtEupzSNTO1NMcmMgA7VZuzMudr4Ti5xcC2XcQAMEtJ7nZ1L6GMgclU70/X9HIZAACzktlDmf6fWXK50/T4btbLIlWN3Iww1Z9XVjdIOFPI+zhuKjkAwCwkUUm32DCB2VXkPjy6VACAWctU73Rp9V1ku4ysM7bOIqEAAAAAAAAAAAAAAAAA7INM0398dXeJzlIlxy1BAQBwl5QFbPsFR7Mm2Wtr+zXJAAD2QlZnv7G6BUzjHi3e1OKKO14BADBj961uVfifr66yky6vp7a4ZPiiJS5s8b46nAydr90t0goAcGqS+FzV4lEt3tHigdUlN29fbEuCdH5J/Hp1K8l/pI4mQ1cvfgcAmK10cT20ujE/r1/8fnmLW1rcZ/C6ZbJoq2QIANhbqQ5dXwfdWs9ucd3icdYXG69WP4wLqps5lkrSOBl68uJ3AIBZS/JyU3UVoSRGN1SXGOVxkp1xAjROhj6/xbWL90S62W6t1cccAQCcqSQ9uTfQy1uca/HRFpcOX7CCjDV6Y4vHtXhxi+dV97kAALOXSs5lLe7V4srqpsWnWrSuzES7X3VdawAAe+NV1XVzpcsrg6gfffhpAIC7totb/FyLa1pcNHoOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADgc9v/AWFCb0LHxmpAAAAAAElFTkSuQmCC>

[image18]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAaCAYAAADMp76xAAACoElEQVR4Xu2WTahNURiGX6H8S24kpCRS6sZlIAwURf6KiSIDBkaEm3sjg1MyUX5iQFKiZMJAEiGUAaXEgInUJVHEnTCQwvv27XXOOt9dd5+974+i89TT2Wetdfb59vq+tdYGmvx7jKfDfWMDhtIJdIjvGGzW0GMoH7ACbad7s+vCLKcf6e/Ir/RTdv2NnqTjwg8i5tMHdJLvKIge8hLd5DuKcJ7+pEtd+wJY8HfomKh9JL1ON0dtfWEefUyn+448xtJH9A2d7PoU5EP6i66I2lfRF+g5vizD6BVace25zKVf6FXYDWK0MJ6ifvZVcxfoqTCon2yB/Yf+qxDrYfW6z3eQxfQHfQLbDUQLfUk3hkEJlOK12aeYSFfTKdURNVrpW7rId/SGZipVvwrwHv1MF0btbfRd9unR7O+hZ+g2+ooehS2uDvqazqmONvQQCjhvAqqEGtUsXqbnMi/SD7DUTwuDM9bBdpaZrl2spIdQ26p0n/ewsrtJv6Png4YYOl17klC/d+kM2NMGR0TjYhSwZiSV3t10dnY9GpahsDaW0A2wQyMmBHzEtScJ9XvQd+SQF3CMMqBMNJq5ELC21oaofv2W1YiiAWsyVGp+bXgKl0TYf7vo1PquXBSA6lurO0Z1u52ehQWhyehC7d46EU/QUdn3QNg6U7tUHTplumGLobd6TaG6V8A+KzpEdPjoQNFO8Aw2cwpeD7Mftud6tKj1O3+/KstgKfXvDzviQTmEFO507Xo30K5wg96mu2Azp0V3jR7IxniUMe3rZbJcmgrSJ6N2AKU+ZMx/T1GBHc/+XgPKLPocVlb9QSfgfVjWBx29zx5HyfdZx1bYIk2VyoCjPzmNPr7PwrJ0C3Zg/TV0mh1G+pjOQ1uqTjZ/7Ddp8t/xB8heeJvhT/BKAAAAAElFTkSuQmCC>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHQAAAAaCAYAAABmZHgNAAAE0UlEQVR4Xu2YacguYxjH/7IvJ8dOll6yRNYkhCyh7EKSLeFYsmQJWZMoS4dj6yASstWxJY7tw/vBB6WEkJIcsnzigyhS+P/ONbeZ5z7zzPs+PfOe930e869/08x9z8x9Xf/rvq5rRurQocPcxyrmRuYWxZHzDrOP1c3NFLqslY01Yj3zDfNZ8xoNeHOHGcOEeb/5jnlc71AzEPQpRSR0mHtAzE7QMUIn6JihE3TM0KqgW5vHFkdAF3yU6ueOIlY19zaPNNdVdPg7mkeYa1fmzSZaERTDrjAXm2ebX5h3m0+b15pfmTv9N3s0sb75nHmVeaP5ibnIvMN8wnxFc6Pjb0VQIvQmld+kjH9v7qz4xPldEdmjCuy63TyoOMf2b83nzd3Nn81JhW9mG60Ierki9QBS0XvmEnM18wDzBEW6mm2wyy4ujoNgQ0XAph24h/mreYbig/4sc5dibFgcaP6o5gDhnQvMrfIBtSRoFduZP5nX5QMNmGdekl8cEIdr6iyAEA+pv6OmC4ScyayDIJPqv06EfFz1GrQu6PHmn4pImy52Ne/LLw4AUiK1bKYcXAXvetL80NwgG2sLUwnahKEFxcBzzUeKsQfMZeaWxfimCrHWMTc3bzHvNF80DzX3NT8zvzEfU3TF4ETzXvNRRZokzZDy+N34tqIJe13xjLvMPxSNCc+er16wRp73prlnNpbA2vv9myZFP2heYG5sfq4QNc2lh2AMcO0k8xnF71FKzoQiM2DfqebLigZyk7hlOZj3gmLn3aP+grJRXlPppxxDC8oP4a8VXR+d7EcqF4NxCECKAqRhjAUsDEcAFsAzE6jDSxUdJc/AmecVYzidd1xq3qaoX7zrVfXfoTRnOOAG89beoeXgmayfzLJ/Nga49x9zoSKA/lJZUhCbtW9fnJOh6O4JQK7xbxUf7aNoFFPmQjjsAzRbBFuq7eeoXlA2x5nmyYoNUdeXDC0oC+ec3fKWeZkiHS0xXzKvL+aA08zfFJF7jMoF5YIm4AjGmJ8cWCde3bUqcMQ2CqfVlQLuZ+xvRQDmoC8giFgHu4PswKcYnyvcd1gxjyYQu5l3isL5HyjWBT9W6TfsSTYhLiUjoV/KpTkjy5Ed0ibJMbSgAGFwWuoC8/MEzvdSLH6ZeVFxPQmKQ3ZQBMDDBdk9VePrxKte470YnoOd966aO1waK3Z+HVg7z05BmJ+D1OHXNYRNgmJ79Z5+goJtzfeLYx1aEXS6WKBogAApiLoCkqA8G5Fz4wkA0itROZWghxRHnHulYncBajtOO1rlGnLwE6Qu5Q4CAoLvU4ITEMATWtGmqqDcw85O91CWJhV25XZcqNihrPPg4loVK1VQUhXphdS7SGUNpcYRdVcrahS7iNRGc0BDxJFGhO/dm81fFA1QagyoswsVtZa6xBr5Lv5BpdPSOCWB+Tn4pGFtw/7C436CZ7F5vkIMainlh8aNsdPNLwtiQ6rDBC69wlLFZxG27qZeOxineaKU1a11pQpKBOJM2v28oJNmicYq5mvFtN2Eeep9Lt9rBA/gvYzXiQlwAvPbAuuuS5lNYD73raGy7wBVO0BuZxUDC4rTiZDvimMuwlwCf6hIeaOO6djBTv5UoQu9wNhhTXM/9d+Ro4JxsaNDhw4d/s/4FxJj4AhR//auAAAAAElFTkSuQmCC>