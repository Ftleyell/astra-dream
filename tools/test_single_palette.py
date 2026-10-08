#!/usr/bin/env python3
"""
tools/test_single_palette.py
Prueba y calibración paleta por paleta sobre los 7 pilotos (Selección + Naves):
Inicia con la temática: GÓTICA (Gothic Dark / Void Occult)
  - Pelo: Negro azabache / carbón con sombras frías y volumen anime
  - Ojos: Ónix profundo / negro con brillo blanco cristalino
  - Ropa: Traje negro carbón mate / titanio oscuro con placas de contraste en plata/platino gótico
  - Echo: Muñeca de porcelana gótica (chasis níveo con líneas negro carbón y pelo negro azabache)
  - Naves: Blindaje negro profundo con toberas oscuras y líneas de reactor plata/carmesí
"""

import os
import sys
import colorsys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
SHIPS_DIR = os.path.join(BASE_DIR, "assets", "characters", "ships")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "palette_review")

PILOTS = ["echo", "kira", "nova", "nyx", "roxy", "selene", "valentina"]


def extract_selection_masks(mask_img: Image.Image):
    mr, mg, mb, ma = mask_img.convert("RGBA").split()
    clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    clothes = ImageChops.multiply(clothes, ma).filter(ImageFilter.GaussianBlur(0.7))
    hair = ImageChops.multiply(hair, ma).filter(ImageFilter.GaussianBlur(0.7))
    eyes = ImageChops.multiply(eyes, ma).filter(ImageFilter.GaussianBlur(0.5))
    return clothes, hair, eyes


def extract_ship_masks(mask_img: Image.Image, target_size: tuple[int, int]):
    m_resized = mask_img.resize(target_size, Image.Resampling.LANCZOS)
    mr, mg, mb = m_resized.split()
    clothes = ImageChops.subtract(mr, mg).filter(ImageFilter.GaussianBlur(0.5))
    hair = ImageChops.subtract(mg, mr).filter(ImageFilter.GaussianBlur(0.5))
    return clothes, hair


def apply_gothic_selection(pilot: str, base_img: Image.Image, mask_img: Image.Image) -> Image.Image:
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)
    clothes_m, hair_m, eyes_m = extract_selection_masks(mask_img)

    # Caso Especial Echo: Muñeca de Porcelana Gótica
    if pilot == "echo":
        # Aislar rostro
        w, h = base_img.size
        face_box = Image.new("L", (w, h), 0)
        for y in range(int(h * 0.08), int(h * 0.22)):
            for x in range(int(w * 0.38), int(w * 0.58)):
                face_box.putpixel((x, y), 255)
        lut_skin = [255 if x > 200 else 0 for x in range(256)]
        face_area = ImageChops.multiply(gray.point(lut_skin), face_box).filter(ImageFilter.GaussianBlur(1.5))
        pure_clothes = ImageChops.subtract(clothes_m, face_area)

        # Chasis de porcelana con sombras plateadas/frías
        body_gothic = ImageOps.colorize(gray, black=(25, 25, 32), mid=(225, 228, 235), white=(255, 255, 255))
        res = Image.composite(body_gothic, base_rgb, pure_clothes)

        # Articulaciones y líneas mecánicas en negro azabache
        lut_dark_lines = [255 if x < 135 else 0 for x in range(256)]
        m_dark_lines = ImageChops.multiply(gray.point(lut_dark_lines), pure_clothes)
        lines_black = ImageOps.colorize(gray, black=(5, 5, 8), mid=(18, 18, 24), white=(70, 75, 85))
        res = Image.composite(lines_black, res, m_dark_lines)

        # Cabello: Negro carbón azabache con brillo plata sutil
        lut_dark_hair = [int(pow(x / 255.0, 1.4) * 125) for x in range(256)]
        hair_black = ImageOps.colorize(gray.point(lut_dark_hair), black=(10, 8, 14), mid=(35, 35, 45), white=(210, 215, 225))
        res = Image.composite(hair_black, res, hair_m)

        # Ojos: Ónix oscuro con punto de luz nítido
        eyes_black = ImageOps.colorize(gray, black=(0, 0, 0), mid=(30, 25, 35), white=(255, 255, 255))
        res = Image.composite(eyes_black, res, eyes_m)
        return Image.merge("RGBA", (*res.split(), alpha))

    # Pilotos Normales
    # Descomponer ropa en Smart Multi-Material
    hsv = base_rgb.convert("HSV")
    h, s, v = hsv.split()

    lut_desat = [255 if x < 80 else 0 for x in range(256)]
    lut_bright = [255 if x >= 140 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    m_plates = ImageChops.multiply(m_plates, clothes_m).filter(ImageFilter.GaussianBlur(0.6))

    lut_dark = [255 if x < 65 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_m).filter(ImageFilter.GaussianBlur(0.5))

    m_suit = ImageChops.subtract(clothes_m, ImageChops.add(m_plates, m_mech)).filter(ImageFilter.GaussianBlur(0.6))

    res = base_rgb.copy()

    # 1. Mono base: Negro titanio / carbón oscuro manteniendo costuras y pliegues
    lut_suit_curve = [int(pow(x / 255.0, 1.5) * 135) for x in range(256)]
    suit_dark = ImageOps.colorize(gray.point(lut_suit_curve), black=(8, 8, 12), mid=(28, 28, 36), white=(150, 155, 170))
    res = Image.composite(suit_dark, res, m_suit)

    # 2. Placas de blindaje: Plata gótica / Peltre frío (contraste elegante sin ser blanco chillón)
    plates_silver = ImageOps.colorize(gray, black=(35, 35, 45), mid=(185, 190, 205), white=(245, 248, 255))
    res = Image.composite(plates_silver, res, m_plates)

    # 3. Juntas y detalles mecánicos: Negro obsidiana profundo
    mech_dark = ImageOps.colorize(gray, black=(4, 4, 6), mid=(15, 15, 20), white=(60, 65, 75))
    res = Image.composite(mech_dark, res, m_mech)

    # 4. Cabello: Negro azabache / carbón con sombras violeta/medianoche muy tenues
    lut_hair_curve = [int(pow(x / 255.0, 1.3) * 130) for x in range(256)]
    hair_gothic = ImageOps.colorize(gray.point(lut_hair_curve), black=(12, 10, 16), mid=(38, 36, 46), white=(200, 205, 220))
    res = Image.composite(hair_gothic, res, hair_m)

    # 5. Ojos: Ónix / Negro profundo con reflejos plateados
    eyes_gothic = ImageOps.colorize(gray, black=(0, 0, 0), mid=(25, 25, 35), white=(255, 255, 255))
    res = Image.composite(eyes_gothic, res, eyes_m)

    return Image.merge("RGBA", (*res.split(), alpha))


def apply_gothic_ship(pilot: str, base_img: Image.Image, mask_img: Image.Image) -> Image.Image:
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)
    clothes_m, hair_m = extract_ship_masks(mask_img, base_img.size)

    # Si es Echo
    if pilot == "echo":
        body_g = ImageOps.colorize(gray, black=(20, 20, 25), mid=(220, 225, 230), white=(255, 255, 255))
        res = Image.composite(body_g, base_rgb, clothes_m)
        lut_hair = [int(pow(x / 255.0, 1.3) * 130) for x in range(256)]
        hair_g = ImageOps.colorize(gray.point(lut_hair), black=(10, 8, 14), mid=(35, 35, 45), white=(200, 205, 220))
        res = Image.composite(hair_g, res, hair_m)
        return Image.merge("RGBA", (*res.split(), alpha))

    hsv = base_rgb.convert("HSV")
    h, s, v = hsv.split()

    lut_plasma_h = [255 if 100 <= x <= 170 else 0 for x in range(256)]
    lut_sat = [255 if x >= 35 else 0 for x in range(256)]
    m_plasma = ImageChops.multiply(h.point(lut_plasma_h), s.point(lut_sat))
    m_plasma = ImageChops.multiply(m_plasma, clothes_m)

    lut_desat = [255 if x < 75 else 0 for x in range(256)]
    lut_bright = [255 if x >= 135 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    m_plates = ImageChops.multiply(m_plates, clothes_m)
    m_plates = ImageChops.subtract(m_plates, m_plasma)

    lut_dark = [255 if x < 60 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_m)
    m_mech = ImageChops.subtract(m_mech, m_plasma)

    m_suit = ImageChops.subtract(clothes_m, ImageChops.add(m_plasma, ImageChops.add(m_plates, m_mech)))

    res = base_rgb.copy()

    # Traje negro carbón
    lut_suit = [int(pow(x / 255.0, 1.4) * 135) for x in range(256)]
    res = Image.composite(ImageOps.colorize(gray.point(lut_suit), (8, 8, 12), (28, 28, 36), (150, 155, 170)), res, m_suit)

    # Placas plata fría
    res = Image.composite(ImageOps.colorize(gray, (35, 35, 45), (185, 190, 205), (245, 248, 255)), res, m_plates)

    # Líneas de plasma del reactor: Resplandor carmesí oscuro / plata lunar
    if m_plasma.getbbox():
        plasma_gothic = ImageOps.colorize(gray, (0, 0, 0), (220, 30, 60), (255, 200, 215))
        res = Image.composite(plasma_gothic, res, m_plasma)

    # Toberas oscuras
    res = Image.composite(ImageOps.colorize(gray, (5, 5, 8), (20, 20, 25), (70, 75, 85)), res, m_mech)

    # Cabello negro azabache
    lut_hair = [int(pow(x / 255.0, 1.3) * 130) for x in range(256)]
    res = Image.composite(ImageOps.colorize(gray.point(lut_hair), (12, 10, 16), (38, 36, 46), (200, 205, 220)), res, hair_m)

    return Image.merge("RGBA", (*res.split(), alpha))


def run_gothic_test():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    gothic_dir = os.path.join(OUTPUT_DIR, "theme_gothic")
    os.makedirs(gothic_dir, exist_ok=True)

    sel_results = []
    ship_results = []

    for pilot in PILOTS:
        # 1. Selección
        sel_base = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
        sel_mask = os.path.join(SELECTION_DIR, f"selection_{pilot}_mask.png")
        if os.path.exists(sel_base) and os.path.exists(sel_mask):
            b_img = Image.open(sel_base).convert("RGBA")
            m_img = Image.open(sel_mask).convert("RGBA")
            gothic_sel = apply_gothic_selection(pilot, b_img, m_img)
            out_sel_p = os.path.join(gothic_dir, f"selection_{pilot}_gothic.png")
            gothic_sel.save(out_sel_p)
            sel_results.append((pilot, b_img, gothic_sel))

        # 2. Nave
        ship_base = os.path.join(SHIPS_DIR, f"ship_{pilot}.png")
        ship_mask = os.path.join(SHIPS_DIR, f"{pilot.capitalize()}_skin_mask.jpg")
        if os.path.exists(ship_base) and os.path.exists(ship_mask):
            sb_img = Image.open(ship_base).convert("RGBA")
            sm_img = Image.open(ship_mask).convert("RGB")
            gothic_ship = apply_gothic_ship(pilot, sb_img, sm_img)
            out_ship_p = os.path.join(gothic_dir, f"ship_{pilot}_gothic.png")
            gothic_ship.save(out_ship_p)
            ship_results.append((pilot, sb_img, gothic_ship))

    # Generar Collage de Selección Gótica (Original vs Gótica para los 7)
    tw_sel, th_sel = 240, 320
    grid_sel = Image.new("RGBA", (tw_sel * 7, th_sel * 2), (16, 16, 20, 255))
    for idx, (p, orig, goth) in enumerate(sel_results):
        t_orig = orig.resize((tw_sel, th_sel), Image.Resampling.LANCZOS)
        t_goth = goth.resize((tw_sel, th_sel), Image.Resampling.LANCZOS)
        grid_sel.paste(t_orig, (idx * tw_sel, 0), t_orig)
        grid_sel.paste(t_goth, (idx * tw_sel, th_sel), t_goth)

    collage_sel_p = os.path.join(gothic_dir, "gothic_roster_selection_comparison.png")
    grid_sel.save(collage_sel_p)

    # Generar Collage de Naves Góticas
    tw_ship, th_ship = 256, 256
    grid_ship = Image.new("RGBA", (tw_ship * 7, th_ship * 2), (16, 16, 20, 255))
    for idx, (p, orig, goth) in enumerate(ship_results):
        grid_ship.paste(orig, (idx * tw_ship, 0), orig)
        grid_ship.paste(goth, (idx * tw_ship, th_ship), goth)

    collage_ship_p = os.path.join(gothic_dir, "gothic_squadron_ships_comparison.png")
    grid_ship.save(collage_ship_p)

    print(f"¡Prueba Gótica generada con éxito!")
    print(f"Collage Selección: {collage_sel_p}")
    print(f"Collage Naves: {collage_ship_p}")
    return True


if __name__ == "__main__":
    run_gothic_test()
