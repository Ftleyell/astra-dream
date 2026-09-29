import os
from PIL import Image

artifacts = [
    ("planet_volcanic_interior_1790664276462.jpg", "planet_volcanic_interior.png"),
    ("planet_verdant_interior_1790664305816.jpg", "planet_verdant_interior.png"),
    ("planet_cryo_interior_1790664343023.jpg", "planet_cryo_interior.png"),
]

brain_dir = r"C:\Users\Frani\.gemini\antigravity\brain\44df32f7-5ab8-4934-a8a9-df902a10c5b8"
out_dir = r"c:\Users\Frani\.gemini\antigravity\scratch\astra_dream\assets\sprites\environment"

for src_name, dst_name in artifacts:
    src_path = os.path.join(brain_dir, src_name)
    dst_path = os.path.join(out_dir, dst_name)
    
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    cx, cy = w // 2, h // 2
    r_outer = min(cx, cy) - 20
    r_inner = int(r_outer * 0.38) # Radio del hueco central
    
    pixels = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # Distancia al centro
            dist = ((x - cx)**2 + (y - cy)**2)**0.5
            
            # 1. Fondo exterior fuera del disco
            if dist > r_outer:
                # Borde suave exterior
                fade = max(0.0, min(1.0, (r_outer + 15 - dist) / 15.0))
                brightness = max(r, max(g, b))
                if brightness < 25:
                    pixels[x, y] = (r, g, b, 0)
                else:
                    pixels[x, y] = (r, g, b, int(a * fade))
            # 2. Cavidad central interior donde va el nucleo
            elif dist < r_inner:
                fade = max(0.0, min(1.0, (dist - (r_inner - 18)) / 18.0))
                brightness = max(r, max(g, b))
                if brightness < 30:
                    pixels[x, y] = (r, g, b, 0)
                else:
                    pixels[x, y] = (r, g, b, int(a * fade))
            else:
                # Eliminar negros puros / ruido de fondo si quedaron parches oscuros
                brightness = max(r, max(g, b))
                if brightness < 12:
                    pixels[x, y] = (r, g, b, 0)

    # Redimensionar limpiamente a 512x512 para que coincida exactamente con las texturas de la corteza
    img_resized = img.resize((512, 512), Image.Resampling.LANCZOS)
    img_resized.save(dst_path, "PNG")
    print(f"Procesado exitosamente: {dst_name} (512x512 PNG transparente)")
