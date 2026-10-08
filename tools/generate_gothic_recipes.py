#!/usr/bin/env python3
"""
tools/generate_gothic_recipes.py
Genera 3 recetas maestras de alta costura gótica para los 7 pilotos
siguiendo las directrices del usuario:
  - Ropa: Negro obsidiana, gris plomo oscuro, o cuero vino tinto/burdeos profundo
  - Detalles/Placas: Plata envejecida, cromo oscuro o cobre quemado
  - Luces/Neón: Violeta púrpura neón, rojo sangre o verde tóxico gótico
  - Cabello: Negro azabache cuervo, blanco platino lunar, o morado medianoche
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison", "gothic_recipes")

PILOTS = ["nova", "valentina", "selene", "kira", "echo", "roxy", "nyx"]

RECIPES = {
    "receta_1_sangre_plata": {
        "name": "1. Sangre & Plata (Obsidiana / Cuero Burdeos / Neón Rojo Sangre / Pelo Negro)",
        "suit_black": (14, 6, 8),
        "suit_mid": (34, 16, 20),          # Cuero vino tinto / burdeos profundo
        "suit_white": (145, 135, 140),
        "plates_black": (25, 26, 32),
        "plates_mid": (175, 180, 192),      # Plata envejecida
        "plates_white": (240, 242, 250),
        "neon_glow": (255, 25, 55),         # Rojo sangre neón
        "hair_type": "jet_black",           # Negro azabache
        "eyes_color": (230, 20, 45)         # Ojos rubí sangre
    },
    "receta_2_purpura_cobre": {
        "name": "2. Púrpura Abisal & Cobre (Negro Obsidiana / Cobre Quemado / Neón Violeta / Pelo Platino)",
        "suit_black": (8, 6, 12),
        "suit_mid": (22, 18, 30),           # Negro obsidiana con sombra fría
        "suit_white": (135, 130, 150),
        "plates_black": (35, 18, 8),
        "plates_mid": (185, 115, 65),       # Cobre quemado / bronce oscuro
        "plates_white": (245, 200, 165),
        "neon_glow": (195, 45, 255),        # Púrpura neón reactivo
        "hair_type": "lunar_platinum",      # Blanco platino lunar
        "eyes_color": (185, 40, 240)        # Ojos amatista místico
    },
    "receta_3_toxico_cromo": {
        "name": "3. Tóxico & Cromo (Gris Plomo Oscuro / Cromo Oscuro / Verde Tóxico / Pelo Morado Noche)",
        "suit_black": (10, 12, 14),
        "suit_mid": (28, 32, 36),           # Gris plomo oscuro
        "suit_white": (140, 148, 155),
        "plates_black": (18, 22, 26),
        "plates_mid": (125, 135, 145),      # Cromo oscuro reflejos fríos
        "plates_white": (225, 235, 240),
        "neon_glow": (40, 255, 140),        # Verde tóxico gótico
        "hair_type": "midnight_purple",     # Morado medianoche profundo
        "eyes_color": (35, 255, 120)        # Ojos verde ácido brillante
    }
}

def extract_masks(mask_img: Image.Image):
    mr, mg, mb, ma = mask_img.convert("RGBA").split()
    clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    clothes = ImageChops.multiply(clothes, ma).filter(ImageFilter.GaussianBlur(0.7))
    hair = ImageChops.multiply(hair, ma).filter(ImageFilter.GaussianBlur(0.7))
    eyes = ImageChops.multiply(eyes, ma).filter(ImageFilter.GaussianBlur(0.5))
    return clothes, hair, eyes

def decompose_clothes_advanced(base_rgb: Image.Image, gray: Image.Image, clothes_m: Image.Image):
    hsv = base_rgb.convert("HSV")
    h, s, v = hsv.split()

    # 1. Luces de neón / visores / circuitos (alta saturación o brillo muy singular)
    lut_sat_hi = [255 if x > 110 else 0 for x in range(256)]
    lut_bright = [255 if x > 120 else 0 for x in range(256)]
    m_neon = ImageChops.multiply(s.point(lut_sat_hi), v.point(lut_bright))
    m_neon = ImageChops.multiply(m_neon, clothes_m).filter(ImageFilter.GaussianBlur(0.5))

    # 2. Placas metálicas / ribetes (desaturados y claros)
    lut_desat = [255 if x < 75 else 0 for x in range(256)]
    lut_plates_v = [255 if x >= 145 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_plates_v))
    m_plates = ImageChops.multiply(m_plates, clothes_m)
    m_plates = ImageChops.subtract(m_plates, m_neon).filter(ImageFilter.GaussianBlur(0.6))

    # 3. Mecánica oscura y juntas
    lut_dark = [255 if x < 65 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_m)
    m_mech = ImageChops.subtract(m_mech, m_neon).filter(ImageFilter.GaussianBlur(0.5))

    # 4. Ropa / traje principal
    m_suit = ImageChops.subtract(clothes_m, ImageChops.add(m_neon, ImageChops.add(m_plates, m_mech)))
    m_suit = m_suit.filter(ImageFilter.GaussianBlur(0.6))

    return m_suit, m_plates, m_mech, m_neon

def apply_custom_hair(pilot: str, hair_type: str, base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    if pilot == "echo":
        # Echo con técnica velvet suave adaptada
        if hair_type == "lunar_platinum":
            lut = [min(255, int(pow(x / 255.0, 0.65) * 220 + 35)) for x in range(256)]
            colored = ImageOps.colorize(gray.point(lut), (140, 145, 175), (235, 238, 248), (255, 255, 255))
        elif hair_type == "midnight_purple":
            lut = [int(pow(x / 255.0, 1.35) * 125) for x in range(256)]
            colored = ImageOps.colorize(gray.point(lut), (15, 8, 20), (45, 25, 55), (210, 190, 225))
        else:
            lut = [int(pow(x / 255.0, 1.4) * 120) for x in range(256)]
            colored = ImageOps.colorize(gray.point(lut), (16, 8, 10), (42, 22, 26), (210, 190, 195))
        return Image.composite(colored, base_rgb, hair_m)

    if hair_type == "jet_black":
        # Técnica 2 Midnight Blue
        lut = [int(pow(x / 255.0, 1.35) * 125) for x in range(256)]
        colored = ImageOps.colorize(gray.point(lut), (10, 12, 22), (25, 32, 50), (175, 195, 225))
    elif hair_type == "lunar_platinum":
        # Blanco platino lunar
        lut = [min(255, int(pow(x / 255.0, 0.68) * 225 + 30)) for x in range(256)]
        colored = ImageOps.colorize(gray.point(lut), (145, 148, 175), (232, 235, 245), (255, 255, 255))
    elif hair_type == "midnight_purple":
        # Morado medianoche
        lut = [int(pow(x / 255.0, 1.32) * 130) for x in range(256)]
        colored = ImageOps.colorize(gray.point(lut), (18, 10, 25), (48, 26, 62), (215, 195, 235))
    else:
        lut = [int(pow(x / 255.0, 1.35) * 125) for x in range(256)]
        colored = ImageOps.colorize(gray.point(lut), (10, 12, 22), (25, 32, 50), (175, 195, 225))

    return Image.composite(colored, base_rgb, hair_m)

def apply_echo_special(recipe: dict, base_rgb: Image.Image, gray: Image.Image, clothes_m: Image.Image) -> Image.Image:
    w, h = base_rgb.size
    face_box = Image.new("L", (w, h), 0)
    for y in range(int(h * 0.08), int(h * 0.22)):
        for x in range(int(w * 0.38), int(w * 0.58)):
            face_box.putpixel((x, y), 255)
    lut_skin = [255 if x > 200 else 0 for x in range(256)]
    face_area = ImageChops.multiply(gray.point(lut_skin), face_box).filter(ImageFilter.GaussianBlur(1.5))
    pure_clothes = ImageChops.subtract(clothes_m, face_area)

    lut_lines = [255 if x < 135 else 0 for x in range(256)]
    m_lines = ImageChops.multiply(gray.point(lut_lines), pure_clothes)
    m_body = ImageChops.subtract(pure_clothes, m_lines)

    # Chasis de porcelana / esmalte gótico pulido
    body_col = ImageOps.colorize(gray, (25, 25, 30), (228, 230, 236), (255, 255, 255))
    lines_col = ImageOps.colorize(gray, (8, 6, 10), recipe["neon_glow"], (255, 255, 255))

    res = Image.composite(body_col, base_rgb, m_body)
    res = Image.composite(lines_col, res, m_lines)
    return res

def run_recipes():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    th_w, th_h = 240, 320
    # 7 pilotos x 3 recetas
    grid = Image.new("RGBA", (th_w * 3, th_h * len(PILOTS)), (16, 16, 20, 255))

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
        c_m, h_m, e_m = extract_masks(mask)

        for r_idx, (r_key, r_info) in enumerate(RECIPES.items()):
            # 1. Cabello y Ojos
            canvas = apply_custom_hair(pilot, r_info["hair_type"], rgb, gray, h_m)
            eyes_c = ImageOps.colorize(gray, (0, 0, 0), r_info["eyes_color"], (255, 255, 255))
            canvas = Image.composite(eyes_c, canvas, e_m)

            # 2. Cuerpo
            if pilot == "echo":
                canvas = apply_echo_special(r_info, canvas, gray, c_m)
            else:
                m_suit, m_plates, m_mech, m_neon = decompose_clothes_advanced(rgb, gray, c_m)

                suit_c = ImageOps.colorize(gray, r_info["suit_black"], r_info["suit_mid"], r_info["suit_white"])
                plates_c = ImageOps.colorize(gray, r_info["plates_black"], r_info["plates_mid"], r_info["plates_white"])
                mech_c = ImageOps.colorize(gray, (4, 4, 6), (15, 15, 20), (60, 65, 75))
                neon_c = ImageOps.colorize(gray, (0, 0, 0), r_info["neon_glow"], (255, 255, 255))

                canvas = Image.composite(suit_c, canvas, m_suit)
                canvas = Image.composite(plates_c, canvas, m_plates)
                canvas = Image.composite(mech_c, canvas, m_mech)
                canvas = Image.composite(neon_c, canvas, m_neon)

            final_rgba = Image.merge("RGBA", (*canvas.split(), alpha))
            # Guardar versión individual HD
            single_p = os.path.join(OUTPUT_DIR, f"{pilot}_{r_key}.png")
            final_rgba.save(single_p)

            # Pegar en la grilla comparativa
            th = final_rgba.resize((th_w, th_h), Image.Resampling.LANCZOS)
            grid.paste(th, (r_idx * th_w, p_idx * th_h), th)

    master_path = os.path.join(OUTPUT_DIR, "gothic_recipes_master_grid.png")
    grid.save(master_path)
    print(f"Recetas maestras góticas generadas: {master_path}")

if __name__ == "__main__":
    run_recipes()
