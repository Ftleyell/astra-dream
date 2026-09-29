"""
Pipeline de Procesamiento de Armas Chroma Key y Recoloreo para Astra Dream.
- Procesa el nuevo asset generado por Gemini (mecha_shoulder_cannon).
- Remueve el fondo verde Chroma Key (#00FF00) con despill y suavizado de bordes anti-aliasing.
- Diseñado específicamente para un cañón dorsal montado (Top-down Mecha Cannon Pod, sin gatillos ni empuñaduras).
- Tinta y recolorea los paneles modulares de armadura según la paleta cromática de cada piloto:
  * Nova (Naranja Neón / Vanguardia)
  * Valentina (Azul Eléctrico / Francotiradora)
  * Kira (Amarillo Industrial / Drones)
  * Selene (Púrpura Nebulosa / Mística)
  * Roxy (Carmesí de Choque / Blindada)
  * Echo (Cian Cuántico / Telemetría)
- Exporta tanto las versiones HD transparentes como los sprites de juego normalizados a 128x128.
"""

import os
import sys
from PIL import Image

PILOT_PALETTES = {
    "nova": {
        "name": "Nova",
        "primary": (255, 122, 0),       # Naranja neón
        "glow": (0, 240, 255)
    },
    "valentina": {
        "name": "Valentina",
        "primary": (0, 102, 255),      # Azul eléctrico
        "glow": (255, 42, 85)
    },
    "kira": {
        "name": "Kira",
        "primary": (255, 184, 0),      # Amarillo industrial
        "glow": (255, 85, 0)
    },
    "selene": {
        "name": "Selene",
        "primary": (150, 60, 230),     # Púrpura nebulosa
        "glow": (230, 184, 0)
    },
    "roxy": {
        "name": "Roxy",
        "primary": (220, 25, 55),      # Carmesí de choque
        "glow": (255, 40, 80)
    },
    "echo": {
        "name": "Echo",
        "primary": (0, 230, 255),      # Cian ciberespacial
        "glow": (0, 140, 255)
    }
}

def remove_chroma_key(img: Image.Image) -> Image.Image:
    """Remueve el fondo verde brillante (#00FF00) con despill y transparencia suave."""
    img = img.convert("RGBA")
    w, h = img.size
    pixels = img.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            max_rb = max(r, b)
            diff = g - max_rb
            if diff > 30 and g > 120:
                # Fondo verde completo
                pixels[x, y] = (0, 0, 0, 0)
            elif diff > 10 and g > 90:
                # Borde / fringe: suavizar alfa y neutralizar derrame de verde
                alpha = max(0, min(255, int(255 * (1.0 - (diff / 40.0)))))
                pixels[x, y] = (r, max_rb, b, alpha)
    return img

def tint_armor_plates(img: Image.Image, tint_rgb: tuple) -> Image.Image:
    """Aplica tinte a las placas de armadura blancas/claras manteniendo sombras mecánicas."""
    res = img.copy()
    w, h = res.size
    pixels = res.load()
    tr, tg, tb = tint_rgb

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            
            # Detectar placas de armadura claras (alto brillo y bajo diferencial de color)
            min_c, max_c = min(r, g, b), max(r, g, b)
            avg = (r + g + b) // 3
            if avg > 165 and (max_c - min_c) < 40:
                # Mezcla ponderada según el brillo del panel
                factor = min(1.0, (avg - 135) / 120.0)
                blend_strength = 0.82
                nr = int(r * (1.0 - factor * blend_strength) + tr * factor * blend_strength)
                ng = int(g * (1.0 - factor * blend_strength) + tg * factor * blend_strength)
                nb = int(b * (1.0 - factor * blend_strength) + tb * factor * blend_strength)
                pixels[x, y] = (nr, ng, nb, a)
    return res

def fit_to_game_slot(img: Image.Image, target_size: int = 128) -> Image.Image:
    """Recorta la silueta del arma y la ajusta al canvas de 128x128 para el motor Godot."""
    bbox = img.getbbox()
    if not bbox:
        return img
    cropped = img.crop(bbox)
    
    # Redimensionar conservando proporción
    cw, ch = cropped.size
    margin_w = 12
    margin_h = 24
    scale = min((target_size - margin_w) / cw, (target_size - margin_h) / ch)
    nw = max(1, int(cw * scale))
    nh = max(1, int(ch * scale))
    
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    
    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    pos_x = (target_size - nw) // 2
    pos_y = (target_size - nh) // 2
    canvas.paste(resized, (pos_x, pos_y), resized)
    return canvas

def process_all(input_image_path: str, output_dir: str):
    os.makedirs(output_dir, exist_ok=True)
    print(f"Cargando imagen base: {input_image_path}")
    raw_img = Image.open(input_image_path)

    print("1. Removiendo fondo Chroma Key verde...")
    transparent_img = remove_chroma_key(raw_img)
    transparent_img.save(os.path.join(output_dir, "weapon_base_transparent_hd.png"))

    print("2. Generando versiones recoloreadas y sprites de juego (128x128)...")
    for pilot_id, pal_info in PILOT_PALETTES.items():
        recolored_hd = tint_armor_plates(transparent_img, pal_info["primary"])
        game_sprite = fit_to_game_slot(recolored_hd, target_size=128)
        
        hd_path = os.path.join(output_dir, f"weapon_{pilot_id}_hd.png")
        game_path = os.path.join(output_dir, f"weapon_{pilot_id}.png")
        
        recolored_hd.save(hd_path, "PNG")
        game_sprite.save(game_path, "PNG")
        print(f"  [+] Piloto {pal_info['name']}:")
        print(f"      - Sprite de juego: {game_path}")
        print(f"      - Sprite HD:       {hd_path}")

    print("\n¡Proceso de Chroma Key y Recoloreo completado exitosamente!")

if __name__ == "__main__":
    default_img = r"C:\Users\Frani\.gemini\antigravity\brain\6d397282-e49c-4acd-b2e3-9dea91aa12df\mecha_shoulder_cannon_1790675462372.jpg"
    inp = sys.argv[1] if len(sys.argv) > 1 else default_img
    out_directory = os.path.join("assets", "characters", "weapons")
    process_all(inp, out_directory)
