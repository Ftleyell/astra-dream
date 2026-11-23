# Style Bible: Stylized Retro-SciFi Mecha Pilots (Newgrounds / Skullgirls Aesthetic)

Este documento define las reglas de diseño visual, arquitectura de prompts para IA y el pipeline programático con Python para reproducir de forma consistente el estilo gráfico de las pilotos y sus exotrajes.

---

## 1. Manifiesto Visual y ADN del Estilo

El estilo fusiona la animación vectorial Flash de los 2010s (*Newgrounds*, *WayForward*, *Shane Glines*) con el lenguaje de formas de *Skullgirls* (*Alex Ahad*) y toques retro-sci-fi de *Gainax / Studio Trigger*.

### Pilares Fundamentales
1. **Contraste "Carne Suave vs. Metal Rígido" (Soft vs. Chunky):**
   * El cuerpo de la piloto es elástico, curvado y suave, enfundado en un traje de compresión (*plugsuit/flight suit*) sin pliegues realistas ni texturas complejas.
   * El exotraje se compone de piezas mecánicas masivas, simplificadas y modulares (botas con propulsores, guanteletes de choque, cascos con visera).
2. **Inmunidad al "AI Slop":**
   * Cero fotorrealismo, cero sombreado con gradientes suaves, cero brillos volumétricos hiperdetallados.
   * Acabado de cel-shading puro en dos tonos: color base + una sola sombra dura de borde recortado (*hard-edge shadow*).
3. **Línea de Tinta Gruesa (Clean Heavy Lineart):**
   * Contornos exteriores gruesos y continuos que separan con nitidez los bloques de color y la silueta del personaje respecto al fondo.

---

## 2. Reglas de Construcción y Anatomía

### Anatomía de la Piloto
* **Proporciones "Taper & Squash":** Torso compacto y de cintura corta, caderas y muslos fluidos y prominentes que se estrechan suavemente hacia los tobillos o se insertan directamente en las botas.
* **Simplificación muscular:** No dibujar gemelos, bíceps ni clavículas realistas. La sensualidad nace de la curva limpia de la silueta (*S-curve / bean shape*), no del detalle anatómico.
* **Rostro y Expresión:** Ojos grandes y expresivos con pestañas gruesas y cejas dinámicas. Actitud confiada, pícara o relajada (*smug smirk*, media sonrisa, descaro).

### Anatomía del Exotraje
* **Modularidad:** El exotraje **no** cubre a la piloto por completo; se concentra en extremidades y puntos clave:
  * Manos: Guanteletes gigantescos, articulaciones redondeadas, pistones visibles estilizados.
  * Piernas: Botas de gravedad pesadas con suela de tractor y toberas/escapes de cohete.
  * Cabeza: Cascos abiertos con visera panorámica o auriculares/antenas robustas.
* **Detalles Industriales Caricaturescos:** Rayas de peligro diagonales (*hazard stripes*), remaches circulares grandes y toberas de propulsión simplificadas.

---

## 3. Arquitectura del Prompt Maestro

Para replicar este resultado exacto en herramientas como Midjourney, Stable Diffusion o Imagen, utiliza la siguiente estructura por bloques:

### Template Base

```text
[VISTA Y FORMATO]: Full-body character turnaround of an attractive female sci-fi space pilot, multiple angles (front, 3/4, back),
[ESTILO ARTÍSTICO]: Skullgirls art style, Alex Ahad aesthetic, 2010s Western-anime hybrid animation, Newgrounds Flash vector art,
[ANATOMÍA Y CUERPO]: voluptuous and curvy stylized cartoon proportions, hourglass figure, thick thighs, tiny waist, confident relaxed stance, smug smirk,
[TRAJE Y EXOTRAJE]: wearing a form-fitting retro sci-fi flight suit, equipped with oversized chunky mechanical exoskeleton armor boots with exhaust thrusters, bulky robotic gauntlets, retro space helmet with transparent visor, industrial hazard warning stripes,
[TÉCNICA DE RENDER]: clean thick black outlines, bold line weight, flat vibrant 2D cel shading, minimal hard-edged shadows, no gradients, no textures, no 3D render,
[FONDO]: solid flat chroma green background (#00FF00) --ar 16:9 --stylize 250
```

### Palabras Clave Obligatorias (Whitelist)
* `Skullgirls art style`
* `thick bold black outlines`
* `flat 2D cel shading`
* `stylized cartoon proportions`
* `chunky mechanical exoskeleton boots`
* `oversized gauntlets`
* `hazard stripes`
* `solid flat chroma green background`

### Palabras Clave Prohibidas (Negative Prompts / Blacklist)
* `photorealistic, octane render, unreal engine 5, 3d, realistic skin texture, pores, complex shading, gradients, cinematic lighting, blurry lines, soft edges, hyperdetailed, micro-details`

---

## 4. Matriz de Arquetipos para el Cast Principal

Usa esta matriz para diseñar cada piloto del juego variando la silueta geométrica dominante sin romper la coherencia de estilo:

| Arquetipo | Silueta Base | Enfoque de Armadura | Actitud | Prompt Modifier |
| :--- | :--- | :--- | :--- | :--- |
| **La Artillera / Tanque** | Triángulo inferior (Pera) | Piernas gigantes, orugas y amortiguadores | Perezosa, relajada, despreocupada | `teardrop bottom-heavy silhouette, massive shock-absorber boots, lazy half-lidded eyes` |
| **La Demoledora / Brawler** | Columna / Reloj de arena ancho | Guanteletes colosales, placas pectorales | Enérgica, canchera, ruidosa | `broad shoulders, sturdy athletic curves, colossal mining gauntlets, confident wide grin` |
| **La Exploradora / Speedster** | Maní / Compacto (Shortstack) | Propulsor dorsal masivo y patines antigravedad | Traviesa, hiperactiva, pícara | `shortstack compact build, oversized twin-thruster jetpack backpack, dynamic bouncy posture` |
| **La Francotiradora / Táctica** | Reloj de arena estilizado (Afilado) | Estabilizadores dorsales finos, visor monóculo | Fría, cínica, mascando chicle | `long-legged sleek silhouette, minimalist high-tech spinal frame, bored aloof gaze` |

---

## 5. Pipeline de Variaciones de Color con Python

Dado que los personajes se generan con trazos negros gruesos y bloques de color sólidos sobre fondo verde croma (`#00FF00`), este script realiza el recorte automático con transparencia y permite aplicar paletas de colores alternativos mediante máscaras de rango de tono (HSV).

```python
import cv2
import numpy as np
from PIL import Image

def remove_chroma_background(img_bgr, lower_green=(35, 100, 100), upper_green=(85, 255, 255)):
    """
    Elimina el fondo verde croma y devuelve una imagen RGBA con fondo transparente.
    """
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, np.array(lower_green), np.array(upper_green))
    
    # Invertir máscara para conservar al personaje
    alpha = cv2.bitwise_not(mask)
    
    # Suavizar levemente el borde del alfa sin perder la línea dura
    kernel = np.ones((2, 2), np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_CLOSE, kernel)
    
    b, g, r = cv2.split(img_bgr)
    rgba = cv2.merge([b, g, r, alpha])
    return rgba

def swap_color_region(img_bgr, lower_color_hsv, upper_color_hsv, new_hue):
    """
    Reemplaza el tono (Hue) de una zona específica respetando sombras y saturación.
    new_hue: Valor entre 0 y 179 (espacio HSV de OpenCV).
    """
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, np.array(lower_color_hsv), np.array(upper_color_hsv))
    
    h, s, v = cv2.split(hsv)
    h_shifted = np.where(mask > 0, np.uint8(new_hue), h)
    
    modified_hsv = cv2.merge([h_shifted, s, v])
    return cv2.cvtColor(modified_hsv, cv2.COLOR_HSV2BGR)

# --- EJEMPLO DE USO ---
if __name__ == "__main__":
    # Cargar la imagen generada
    img = cv2.imread("space_pilot_raw.png")
    
    # 1. Quitar fondo verde
    cutout_rgba = remove_chroma_background(img)
    cv2.imwrite("pilot_transparent.png", cutout_rgba)
    
    # 2. Definir rangos para recolorear (ej. cambiar el traje azul a rojo carmesí o verde tóxico)
    # Rango de azules oscuros del traje en HSV (OpenCV: H 0-179, S 0-255, V 0-255)
    SUIT_BLUE_LOWER = (100, 50, 40)
    SUIT_BLUE_UPPER = (130, 255, 180)
    
    # Generar Skin 1: Traje Carmesí (Hue ~ 0 / 175)
    skin_crimson_bgr = swap_color_region(img, SUIT_BLUE_LOWER, SUIT_BLUE_UPPER, new_hue=0)
    skin_crimson_rgba = remove_chroma_background(skin_crimson_bgr)
    cv2.imwrite("pilot_skin_crimson.png", skin_crimson_rgba)
    
    # Generar Skin 2: Traje Verde Tóxico (Hue ~ 45)
    skin_toxic_bgr = swap_color_region(img, SUIT_BLUE_LOWER, SUIT_BLUE_UPPER, new_hue=45)
    skin_toxic_rgba = remove_chroma_background(skin_toxic_bgr)
    cv2.imwrite("pilot_skin_toxic.png", skin_toxic_rgba)
```

---

## 6. Checklist de Control de Calidad (Anti-Slop QA)

Antes de integrar una imagen generada al juego o al sprite sheet:

- [ ] **Líneas:** ¿El contorno exterior es continuo, nítido y de color oscuro uniforme?
- [ ] **Sombreado:** ¿Las sombras son cortes duros sin degradados borrosos ni ruido digital?
- [ ] **Proporciones:** ¿El cuerpo responde a una silueta caricaturesca con contraste claro frente a las piezas del exoesqueleto?
- [ ] **Separación cromática:** ¿Los colores del traje, las armaduras y el fondo están bien diferenciados para que el script de Python los aísle sin sangrado de píxeles?