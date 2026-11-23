#!/usr/bin/env python3
"""
tools/test_black_hair_techniques.py
Genera una comparativa de 5 técnicas profesionales distintas para cabello negro de anime
aplicadas a los 7 pilotos (Nova, Valentina, Kira, Selene, Roxy, Echo, Nyx).
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison", "black_hair_studies")

PILOTS = ["nova", "valentina", "selene", "kira", "echo", "roxy", "nyx"]

def extract_hair_mask(mask_img: Image.Image) -> Image.Image:
    mr, mg, mb, ma = mask_img.convert("RGBA").split()
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    hair = ImageChops.multiply(hair, ma)
    return hair.filter(ImageFilter.GaussianBlur(0.7))

# 1. Jet Black Clásico (Curva gamma controlada, negro azabache con brillo neutro puro)
def hair_tech_jet_black(base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    lut = [int(pow(x / 255.0, 1.45) * 115) for x in range(256)]
    dark_gray = gray.point(lut)
    colored = ImageOps.colorize(dark_gray, black=(8, 8, 10), mid=(30, 30, 35), white=(195, 200, 210))
    return Image.composite(colored, base_rgb, hair_m)

# 2. Anime Midnight Blue / Cuervo (Sombras azul medianoche/índigo profundo con brillos celestes tenues)
def hair_tech_midnight_blue(base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    lut = [int(pow(x / 255.0, 1.35) * 125) for x in range(256)]
    dark_gray = gray.point(lut)
    colored = ImageOps.colorize(dark_gray, black=(10, 12, 22), mid=(25, 32, 50), white=(175, 195, 225))
    return Image.composite(colored, base_rgb, hair_m)

# 3. Violeta Abisal / Gótico Bruja (Subtono morado ciruela oscuro con reflejos lila apagados)
def hair_tech_abyssal_violet(base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    lut = [int(pow(x / 255.0, 1.35) * 125) for x in range(256)]
    dark_gray = gray.point(lut)
    colored = ImageOps.colorize(dark_gray, black=(14, 8, 18), mid=(38, 24, 45), white=(200, 185, 215))
    return Image.composite(colored, base_rgb, hair_m)

# 4. Grafito Metálico / Carbón Mate (Aspecto táctico desaturado con reflejos de seda plateada)
def hair_tech_matte_graphite(base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    lut = [int(pow(x / 255.0, 1.25) * 135) for x in range(256)]
    dark_gray = gray.point(lut)
    colored = ImageOps.colorize(dark_gray, black=(16, 16, 18), mid=(48, 48, 52), white=(220, 225, 230))
    return Image.composite(colored, base_rgb, hair_m)

# 5. Velvet / Sangre Negra (Negro oscuro con sombras borgoña/chocolate ahumado muy sutiles)
def hair_tech_black_velvet(base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    lut = [int(pow(x / 255.0, 1.4) * 120) for x in range(256)]
    dark_gray = gray.point(lut)
    colored = ImageOps.colorize(dark_gray, black=(16, 8, 10), mid=(42, 22, 26), white=(210, 190, 195))
    return Image.composite(colored, base_rgb, hair_m)

def run_studies():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    th_w, th_h = 240, 320
    # 7 pilotos x 6 columnas (Original + 5 técnicas)
    grid = Image.new("RGBA", (th_w * 6, th_h * len(PILOTS)), (18, 18, 22, 255))

    for p_idx, pilot in enumerate(PILOTS):
        bp = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
        mp = os.path.join(SELECTION_DIR, f"selection_{pilot}_mask.png")
        if not os.path.exists(bp) or not os.path.exists(mp):
            continue

        base = Image.open(bp).convert("RGBA")
        mask = Image.open(mp).convert("RGBA")
        rgb = base.convert("RGB")
        alpha = base.split()[3]
        gray = ImageOps.grayscale(rgb)
        h_m = extract_hair_mask(mask)

        t1 = hair_tech_jet_black(rgb, gray, h_m)
        t2 = hair_tech_midnight_blue(rgb, gray, h_m)
        t3 = hair_tech_abyssal_violet(rgb, gray, h_m)
        t4 = hair_tech_matte_graphite(rgb, gray, h_m)
        t5 = hair_tech_black_velvet(rgb, gray, h_m)

        versions = [
            ("Original", base),
            ("1_JetBlack", Image.merge("RGBA", (*t1.split(), alpha))),
            ("2_MidnightBlue", Image.merge("RGBA", (*t2.split(), alpha))),
            ("3_AbyssalViolet", Image.merge("RGBA", (*t3.split(), alpha))),
            ("4_MatteGraphite", Image.merge("RGBA", (*t4.split(), alpha))),
            ("5_BlackVelvet", Image.merge("RGBA", (*t5.split(), alpha)))
        ]

        for v_idx, (tag, img_v) in enumerate(versions):
            # Guardar recorte individual o versión completa
            th = img_v.resize((th_w, th_h), Image.Resampling.LANCZOS)
            grid.paste(th, (v_idx * th_w, p_idx * th_h), th)

    grid_path = os.path.join(OUTPUT_DIR, "black_hair_techniques_master_grid.png")
    grid.save(grid_path)
    print(f"Estudio de cabello negro generado: {grid_path}")

if __name__ == "__main__":
    run_studies()
