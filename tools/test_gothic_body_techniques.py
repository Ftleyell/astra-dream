#!/usr/bin/env python3
"""
tools/test_gothic_body_techniques.py
Estudio comparativo de 4 técnicas para el cuerpo/ropa gótica
con el cabello ya fijado (Técnica 2 Midnight Blue para 6 pilotos, Técnica 5 Velvet para Echo).

Técnicas de cuerpo a evaluar:
  1. Cuero y Carbón Puro (Full Black Stealth): Mono negro carbón mate + placas grafito oscuro + juntas ónix
  2. Gótico Plata / Peltre (Silver Contrast): Mono negro carbón + placas plata fría/peltre de alto contraste
  3. Gótico Ciruela / Sangre (Crimson/Plum Accent): Mono negro con sutil matiz borgoña en tela + placas obsidiana + detalles sangre
  4. Porcelana / Bicolor Alto Impacto (Gothic Lolita / Ivory Armor): Mono negro medianoche + placas marfil/hueso nítidas
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison", "gothic_body_studies")

PILOTS = ["nova", "valentina", "selene", "kira", "echo", "roxy", "nyx"]

def extract_masks(mask_img: Image.Image):
    mr, mg, mb, ma = mask_img.convert("RGBA").split()
    clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    clothes = ImageChops.multiply(clothes, ma).filter(ImageFilter.GaussianBlur(0.7))
    hair = ImageChops.multiply(hair, ma).filter(ImageFilter.GaussianBlur(0.7))
    eyes = ImageChops.multiply(eyes, ma).filter(ImageFilter.GaussianBlur(0.5))
    return clothes, hair, eyes

def decompose_clothes(base_rgb: Image.Image, gray: Image.Image, clothes_m: Image.Image):
    hsv = base_rgb.convert("HSV")
    h, s, v = hsv.split()

    lut_desat = [255 if x < 80 else 0 for x in range(256)]
    lut_bright = [255 if x >= 140 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    m_plates = ImageChops.multiply(m_plates, clothes_m).filter(ImageFilter.GaussianBlur(0.6))

    lut_dark = [255 if x < 65 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_m).filter(ImageFilter.GaussianBlur(0.5))

    m_suit = ImageChops.subtract(clothes_m, ImageChops.add(m_plates, m_mech)).filter(ImageFilter.GaussianBlur(0.6))
    return m_suit, m_plates, m_mech

def apply_fixed_hair(pilot: str, base_rgb: Image.Image, gray: Image.Image, hair_m: Image.Image) -> Image.Image:
    if pilot == "echo":
        # Técnica 5: Black Velvet para Echo
        lut = [int(pow(x / 255.0, 1.4) * 120) for x in range(256)]
        dark_gray = gray.point(lut)
        colored = ImageOps.colorize(dark_gray, black=(16, 8, 10), mid=(42, 22, 26), white=(210, 190, 195))
        return Image.composite(colored, base_rgb, hair_m)
    else:
        # Técnica 2: Midnight Blue para el resto
        lut = [int(pow(x / 255.0, 1.35) * 125) for x in range(256)]
        dark_gray = gray.point(lut)
        colored = ImageOps.colorize(dark_gray, black=(10, 12, 22), mid=(25, 32, 50), white=(175, 195, 225))
        return Image.composite(colored, base_rgb, hair_m)

def apply_gothic_eyes(base_rgb: Image.Image, gray: Image.Image, eyes_m: Image.Image) -> Image.Image:
    eyes_c = ImageOps.colorize(gray, black=(0, 0, 0), mid=(25, 25, 35), white=(255, 255, 255))
    return Image.composite(eyes_c, base_rgb, eyes_m)

# ----------------- TÉCNICAS DE CUERPO -----------------

# Técnica A: Carbón Puro / Stealth Total
def body_tech_pure_stealth(base_rgb: Image.Image, gray: Image.Image, m_suit: Image.Image, m_plates: Image.Image, m_mech: Image.Image) -> Image.Image:
    lut_s = [int(pow(x / 255.0, 1.5) * 130) for x in range(256)]
    suit_c = ImageOps.colorize(gray.point(lut_s), (6, 6, 8), (22, 22, 28), (135, 140, 150))
    plates_c = ImageOps.colorize(gray, (18, 18, 22), (55, 58, 68), (160, 165, 178))
    mech_c = ImageOps.colorize(gray, (4, 4, 6), (14, 14, 18), (60, 65, 75))

    res = Image.composite(suit_c, base_rgb, m_suit)
    res = Image.composite(plates_c, res, m_plates)
    res = Image.composite(mech_c, res, m_mech)
    return res

# Técnica B: Plata Gótica / Contraste de Peltre
def body_tech_silver_contrast(base_rgb: Image.Image, gray: Image.Image, m_suit: Image.Image, m_plates: Image.Image, m_mech: Image.Image) -> Image.Image:
    lut_s = [int(pow(x / 255.0, 1.45) * 135) for x in range(256)]
    suit_c = ImageOps.colorize(gray.point(lut_s), (8, 8, 12), (28, 28, 36), (145, 150, 165))
    plates_c = ImageOps.colorize(gray, (30, 32, 42), (180, 185, 202), (245, 248, 255))
    mech_c = ImageOps.colorize(gray, (4, 4, 6), (15, 15, 20), (60, 65, 75))

    res = Image.composite(suit_c, base_rgb, m_suit)
    res = Image.composite(plates_c, res, m_plates)
    res = Image.composite(mech_c, res, m_mech)
    return res

# Técnica C: Acento Borgoña / Sangre Gótica
def body_tech_crimson_accent(base_rgb: Image.Image, gray: Image.Image, m_suit: Image.Image, m_plates: Image.Image, m_mech: Image.Image) -> Image.Image:
    lut_s = [int(pow(x / 255.0, 1.4) * 135) for x in range(256)]
    # Mono negro con sutil matiz ciruela oscuro en las luces
    suit_c = ImageOps.colorize(gray.point(lut_s), (12, 6, 8), (32, 18, 22), (155, 135, 142))
    # Placas en carmesí oscuro profundo de combate
    plates_c = ImageOps.colorize(gray, (25, 6, 10), (120, 20, 35), (235, 180, 190))
    mech_c = ImageOps.colorize(gray, (4, 4, 6), (15, 12, 14), (60, 55, 60))

    res = Image.composite(suit_c, base_rgb, m_suit)
    res = Image.composite(plates_c, res, m_plates)
    res = Image.composite(mech_c, res, m_mech)
    return res

# Técnica D: Marfil Gótico / Porcelana Alto Contraste
def body_tech_ivory_contrast(base_rgb: Image.Image, gray: Image.Image, m_suit: Image.Image, m_plates: Image.Image, m_mech: Image.Image) -> Image.Image:
    lut_s = [int(pow(x / 255.0, 1.5) * 130) for x in range(256)]
    suit_c = ImageOps.colorize(gray.point(lut_s), (8, 8, 10), (22, 22, 26), (140, 142, 150))
    # Placas en marfil hueso / blanco crema gótico nítido
    plates_c = ImageOps.colorize(gray, (45, 42, 40), (225, 222, 215), (255, 255, 252))
    mech_c = ImageOps.colorize(gray, (4, 4, 6), (15, 15, 20), (60, 65, 75))

    res = Image.composite(suit_c, base_rgb, m_suit)
    res = Image.composite(plates_c, res, m_plates)
    res = Image.composite(mech_c, res, m_mech)
    return res

# Caso especial Echo para el cuerpo
def body_echo_gothic(tech_idx: int, base_rgb: Image.Image, gray: Image.Image, clothes_m: Image.Image) -> Image.Image:
    w, h = base_rgb.size
    face_box = Image.new("L", (w, h), 0)
    for y in range(int(h * 0.08), int(h * 0.22)):
        for x in range(int(w * 0.38), int(w * 0.58)):
            face_box.putpixel((x, y), 255)
    lut_skin = [255 if x > 200 else 0 for x in range(256)]
    face_area = ImageChops.multiply(gray.point(lut_skin), face_box).filter(ImageFilter.GaussianBlur(1.5))
    pure_clothes = ImageChops.subtract(clothes_m, face_area)

    lut_dark_lines = [255 if x < 135 else 0 for x in range(256)]
    m_lines = ImageChops.multiply(gray.point(lut_dark_lines), pure_clothes)
    m_body = ImageChops.subtract(pure_clothes, m_lines)

    if tech_idx == 0: # Stealth total
        body = ImageOps.colorize(gray, (10, 10, 14), (28, 28, 36), (145, 150, 160))
        lines = ImageOps.colorize(gray, (4, 4, 6), (14, 14, 18), (55, 60, 70))
    elif tech_idx == 1: # Chasis plata
        body = ImageOps.colorize(gray, (25, 26, 32), (180, 185, 200), (245, 248, 255))
        lines = ImageOps.colorize(gray, (5, 5, 8), (18, 18, 24), (70, 75, 85))
    elif tech_idx == 2: # Chasis con líneas sangre
        body = ImageOps.colorize(gray, (22, 22, 26), (220, 222, 228), (255, 255, 255))
        lines = ImageOps.colorize(gray, (20, 4, 8), (110, 15, 28), (220, 160, 170))
    else: # Porcelana pura con articulaciones negras
        body = ImageOps.colorize(gray, (30, 30, 35), (235, 236, 240), (255, 255, 255))
        lines = ImageOps.colorize(gray, (4, 4, 6), (12, 12, 16), (50, 55, 65))

    res = Image.composite(body, base_rgb, m_body)
    res = Image.composite(lines, res, m_lines)
    return res

def run_body_studies():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    th_w, th_h = 240, 320
    grid = Image.new("RGBA", (th_w * 4, th_h * len(PILOTS)), (18, 18, 22, 255))

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

        # 1. Aplicar cabello oficial y ojos
        base_with_head = apply_fixed_hair(pilot, rgb, gray, h_m)
        base_with_head = apply_gothic_eyes(base_with_head, gray, e_m)

        # 2. Descomponer ropa
        m_suit, m_plates, m_mech = decompose_clothes(rgb, gray, c_m)

        # 3. Generar las 4 técnicas de cuerpo
        if pilot == "echo":
            tA = body_echo_gothic(0, base_with_head, gray, c_m)
            tB = body_echo_gothic(1, base_with_head, gray, c_m)
            tC = body_echo_gothic(2, base_with_head, gray, c_m)
            tD = body_echo_gothic(3, base_with_head, gray, c_m)
        else:
            tA = body_tech_pure_stealth(base_with_head, gray, m_suit, m_plates, m_mech)
            tB = body_tech_silver_contrast(base_with_head, gray, m_suit, m_plates, m_mech)
            tC = body_tech_crimson_accent(base_with_head, gray, m_suit, m_plates, m_mech)
            tD = body_tech_ivory_contrast(base_with_head, gray, m_suit, m_plates, m_mech)

        techs = [tA, tB, tC, tD]
        for t_idx, img_t in enumerate(techs):
            final_rgba = Image.merge("RGBA", (*img_t.split(), alpha))
            th = final_rgba.resize((th_w, th_h), Image.Resampling.LANCZOS)
            grid.paste(th, (t_idx * th_w, p_idx * th_h), th)

    master_path = os.path.join(OUTPUT_DIR, "gothic_body_techniques_master_grid.png")
    grid.save(master_path)
    print(f"Estudio de cuerpo gótico generado: {master_path}")

if __name__ == "__main__":
    run_body_studies()
