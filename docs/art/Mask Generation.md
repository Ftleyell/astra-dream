Prompt Plantilla (para aplicar a una imagen cualquiera):



"Generate a precise semantic segmentation mask of the provided image, maintaining its original aspect ratio. The background must be completely solid black (RGB 0,0,0). The entire area corresponding to the person's hair must be solid pure green (RGB 0,255,0). The entire area corresponding to the person's clothing must be solid pure red (RGB 255,0,0). The specific areas corresponding to the person's eyes must be solid pure blue (RGB 0,0,255). The masks should accurately follow the shape and position of these elements in the original image, with no other colors or details present."

Explicación de los elementos clave para que funcione:



"Semantic segmentation mask" (Máscara de segmentación semántica): Esto le dice al modelo que no es una foto, sino un mapa de colores.

"Original aspect ratio" (Relación de aspecto original): Fundamental para que la máscara no se deforme.

Asignación de colores puros: Defines exactamente qué color (usando valores RGB) corresponde a cada categoría.

Fondo: Negro

Pelo: Verde puro

Ropa: Rojo puro

Ojos: Azul puro

"Solid" (Sólido): Asegura que el color sea uniforme y plano, sin sombras ni texturas.

Precisión: Los modelos actuales son muy buenos identificando estas partes, por lo que el prompt debe enfatizar la precisión del trazado.

