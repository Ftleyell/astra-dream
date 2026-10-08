"""
Procesador de assets O2 para Hub 3D (Overworld) de Astra Dream.
Procesa ValentinaO2.jpg y RoxyO2.jpg:
1. Divide la imagen en mitades: Frontal (izquierda) y Dorsal/Espalda (derecha).
2. Remueve el fondo magenta (#FF00FF) aplicando despill y suavizado de bordes.
3. Encuadra la figura ajustando la escala proporcional para altura estandarizada (~1520px).
4. Centra horizontalmente en un lienzo transparente de 1200x1600 con anclaje al piso (y=1560).
5. Genera versiones flipped (espejadas horizontalmente).
6. Guarda en assets/characters/fullbody/
"""

import os
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREPROCESS_DIR = os.path.join(BASE_DIR, "preprocess")
FULLBODY_DIR = os.path.join(BASE_DIR, "assets", "characters", "fullbody")

CANVAS_WIDTH = 1200
CANVAS_HEIGHT = 1600
TARGET_HEIGHT = 1520
TARGET_BOTTOM_Y = 1560

CONFIGS = [
    {
        "pilot": "valentina",
        "file": "ValentinaO2.jpg",
        "front_crop": (0, 0, 1000, 2048),
        "back_crop": (1048, 0, 2048, 2048),
    },
    {
        "pilot": "roxy",
        "file": "RoxyO2.jpg",
        "front_crop": (0, 0, 1000, 2048),
        "back_crop": (1048, 0, 2048, 2048),
    }
]

def clean_magenta_chroma(img: Image.Image) -> Image.Image:
    im = img.convert("RGBA")
    w, h = im.size
    pix = im.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            min_rb = min(r, b)
            excess = min_rb - g

            if excess > 30 and min_rb > 100:
                if excess > 70:
                    alpha = 0
                else:
                    alpha = int(255 * (1.0 - (excess - 30) / 40.0))
                # Despill: neutraliza el tinte magenta en bordes semi-transparentes
                rb_despilled = max(g, min_rb // 2)
                pix[x, y] = (min(r, rb_despilled), g, min(b, rb_despilled), min(a, alpha))
            elif r > 160 and b > 160 and g < 70:
                pix[x, y] = (0, 0, 0, 0)

    return im

def process_pose(cropped_raw: Image.Image) -> Image.Image:
    # 1. Limpiar croma
    cleaned = clean_magenta_chroma(cropped_raw)
    
    # 2. Obtener bounding box exacto
    bbox = cleaned.getbbox()
    if not bbox:
        raise ValueError("No se detectó contenido tras limpiar croma.")
    
    tight = cleaned.crop(bbox)
    tw, th = tight.size
    
    # 3. Escalar proporcionalmente a TARGET_HEIGHT
    scale_factor = float(TARGET_HEIGHT) / float(th)
    new_w = max(1, int(round(tw * scale_factor)))
    new_h = TARGET_HEIGHT
    resized = tight.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # 4. Crear lienzo 1200x1600 transparente
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    
    # 5. Centrar horizontalmente y alinear a TARGET_BOTTOM_Y
    paste_x = (CANVAS_WIDTH - new_w) // 2
    paste_y = TARGET_BOTTOM_Y - new_h
    
    canvas.paste(resized, (paste_x, paste_y), resized)
    return canvas

def main() -> None:
    os.makedirs(FULLBODY_DIR, exist_ok=True)
    
    for cfg in CONFIGS:
        pilot = cfg["pilot"]
        src_path = os.path.join(PREPROCESS_DIR, cfg["file"])
        if not os.path.exists(src_path):
            print(f"Error: No existe {src_path}")
            continue
            
        print(f"\n=== Procesando {pilot.upper()} desde {cfg['file']} ===")
        raw_img = Image.open(src_path).convert("RGBA")
        
        # Frontal
        front_raw = raw_img.crop(cfg["front_crop"])
        front_canvas = process_pose(front_raw)
        front_flipped = front_canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        
        # Dorsal (Espalda)
        back_raw = raw_img.crop(cfg["back_crop"])
        back_canvas = process_pose(back_raw)
        back_flipped = back_canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        
        # Rutas de destino
        path_front = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}.png")
        path_front_flipped = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}_flipped.png")
        path_back = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}_back.png")
        path_back_flipped = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}_back_flipped.png")
        
        front_canvas.save(path_front, "PNG")
        front_flipped.save(path_front_flipped, "PNG")
        back_canvas.save(path_back, "PNG")
        back_flipped.save(path_back_flipped, "PNG")
        
        print(f"  [OK] Guardado: {os.path.basename(path_front)} (bbox: {front_canvas.getbbox()})")
        print(f"  [OK] Guardado: {os.path.basename(path_front_flipped)}")
        print(f"  [OK] Guardado: {os.path.basename(path_back)} (bbox: {back_canvas.getbbox()})")
        print(f"  [OK] Guardado: {os.path.basename(path_back_flipped)}")

    print("\nProcesamiento O2 completado exitosamente.")

if __name__ == "__main__":
    main()
