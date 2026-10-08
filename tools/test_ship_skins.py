#!/usr/bin/env python3
"""
tools/test_ship_skins.py
Test de recoloreo avanzado para las 7 Naves / Exo-Trajes de vuelo espacial:
  - Echo, Kira, Nova, Nyx, Roxy, Selene, Valentina
Utiliza las máscaras existentes: <Pilot>_skin_mask.jpg (2048x2048 escaladas a 256x256)
Aplica la convención oficial:
  - Ropa: Smart Multi-Material (Mono temático + Placas de blindaje de contraste + Toberas mecánicas + Líneas de plasma de reactor)
  - Pelo: Modulación suave y orgánica
  - Echo: Tratamiento limpio continuo HSL (sin quemado)
Genera comparativas por nave y un collage del escuadrón en vuelo.
"""

import os
import sys
import colorsys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIPS_DIR = os.path.join(BASE_DIR, "assets", "characters", "ships")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "ships_batch")

PILOTS = ["Echo", "Kira", "Nova", "Nyx", "Roxy", "Selene", "Valentina"]

PALETTES = {
    "cyber_neon": {
        "name": "Cyber Neon",
        "suit_mid": (0, 205, 235),          # Cian eléctrico
        "suit_black": (10, 22, 45),
        "plates_mid": (220, 232, 245),      # Blanco perlado
        "plates_black": (60, 75, 95),
        "plasma_glow": (255, 30, 160),      # Plasma magenta neón en reactores
        "hair_tint": (185, 45, 120),        # Frambuesa suave
        "mech_mid": (45, 50, 60),
        "echo_hue": 0.50                    # Cian continuo
    },
    "crimson_void": {
        "name": "Crimson Void",
        "suit_mid": (195, 25, 55),          # Carmesí combate
        "suit_black": (35, 8, 14),
        "plates_mid": (240, 238, 242),      # Marfil titanio
        "plates_black": (70, 65, 75),
        "plasma_glow": (0, 240, 255),       # Plasma cian en reactores
        "hair_tint": (60, 48, 65),          # Azabache frío
        "mech_mid": (35, 32, 38),
        "echo_hue": 0.98                    # Carmesí continuo
    },
    "solar_gold": {
        "name": "Solar Gold",
        "suit_mid": (255, 190, 20),         # Oro estelar
        "suit_black": (45, 28, 5),
        "plates_mid": (248, 246, 235),      # Marfil oro
        "plates_black": (80, 70, 55),
        "plasma_glow": (255, 240, 100),     # Fusión solar ámbar
        "hair_tint": (125, 85, 55),         # Castaño ámbar
        "mech_mid": (45, 42, 38),
        "echo_hue": 0.12                    # Dorado continuo
    }
}


def extract_ship_masks(mask_img: Image.Image, target_size: tuple[int, int]) -> tuple[Image.Image, Image.Image]:
    """Escala la máscara JPG de 2048 a 256 con Lanczos y separa ropa y pelo."""
    m_resized = mask_img.resize(target_size, Image.Resampling.LANCZOS)
    mr, mg, mb = m_resized.split()

    clothes = ImageChops.subtract(mr, mg)
    hair = ImageChops.subtract(mg, mr)

    clothes = clothes.filter(ImageFilter.GaussianBlur(0.5))
    hair = hair.filter(ImageFilter.GaussianBlur(0.5))
    return clothes, hair


def decompose_ship_suit(base_img: Image.Image, clothes_mask: Image.Image):
    """
    Descompone el exo-traje de vuelo en:
      - m_plasma: líneas de plasma y energía en la espalda (cian reactivo original)
      - m_plates: placas blancas de las piernas y costados
      - m_mech: toberas de metal oscuro y juntas
      - m_suit: mono principal
    """
    img_rgb = base_img.convert("RGB")
    hsv = img_rgb.convert("HSV")
    h, s, v = hsv.split()
    gray = ImageOps.grayscale(img_rgb)

    # 1. Líneas de plasma cian en la espalda (H entre 100 y 170, Sat > 35)
    lut_plasma_h = [255 if 100 <= x <= 170 else 0 for x in range(256)]
    lut_sat = [255 if x >= 35 else 0 for x in range(256)]
    m_plasma = ImageChops.multiply(h.point(lut_plasma_h), s.point(lut_sat))
    m_plasma = ImageChops.multiply(m_plasma, clothes_mask)

    # 2. Placas claras de blindaje: brillo alto y baja saturación
    lut_desat = [255 if x < 75 else 0 for x in range(256)]
    lut_bright = [255 if x >= 135 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    m_plates = ImageChops.multiply(m_plates, clothes_mask)
    m_plates = ImageChops.subtract(m_plates, m_plasma)

    # 3. Toberas de escape y partes mecánicas oscuras (brillo < 60)
    lut_dark = [255 if x < 60 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_mask)
    m_mech = ImageChops.subtract(m_mech, m_plasma)

    # 4. Mono principal
    m_suit = ImageChops.subtract(clothes_mask, ImageChops.add(m_plasma, ImageChops.add(m_plates, m_mech)))

    return m_suit, m_plates, m_plasma, m_mech


def recolor_ship_echo(base_img: Image.Image, clothes_m: Image.Image, hair_m: Image.Image, pal_info: dict) -> Image.Image:
    """Recoloreo continuo en HSL para la nave de Echo sin quemar."""
    img_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    w, h = img_rgb.size
    pixels = img_rgb.load()
    c_pix = clothes_m.load()
    h_pix = hair_m.load()

    out = img_rgb.copy()
    out_pix = out.load()
    target_hue = pal_info["echo_hue"]

    for y in range(h):
        for x in range(w):
            c_val = c_pix[x, y]
            h_val = h_pix[x, y]
            mask_val = max(c_val, h_val)
            if mask_val < 15:
                continue

            r, g, b = pixels[x, y]
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h_v, s_v, v_v = colorsys.rgb_to_hsv(rf, gf, bf)

            factor = mask_val / 255.0
            new_s = min(1.0, s_v * 1.1)
            nr, ng, nb = colorsys.hsv_to_rgb(target_hue, new_s, v_v)

            fin_r = int(r * (1.0 - factor) + nr * 255 * factor)
            fin_g = int(g * (1.0 - factor) + ng * 255 * factor)
            fin_b = int(b * (1.0 - factor) + nb * 255 * factor)
            out_pix[x, y] = (fin_r, fin_g, fin_b)

    return Image.merge("RGBA", (*out.split(), alpha))


def apply_ship_skin(base_img: Image.Image, mask_img: Image.Image, pilot: str, pal_info: dict) -> Image.Image:
    clothes_m, hair_m = extract_ship_masks(mask_img, base_img.size)

    # Si es Echo, usar tratamiento limpio HSL
    if pilot == "Echo":
        return recolor_ship_echo(base_img, clothes_m, hair_m, pal_info)

    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)

    m_suit, m_plates, m_plasma, m_mech = decompose_ship_suit(base_img, clothes_m)

    res = base_rgb.copy()

    # 1. Mono de vuelo principal
    suit_c = ImageOps.colorize(gray, black=pal_info["suit_black"], mid=pal_info["suit_mid"], white=(230, 255, 255))
    res = Image.composite(Image.blend(res, suit_c, 0.90), res, m_suit)

    # 2. Placas de blindaje claras
    plates_c = ImageOps.colorize(gray, black=pal_info["plates_black"], mid=pal_info["plates_mid"], white=(255, 255, 255))
    res = Image.composite(plates_c, res, m_plates)

    # 3. Líneas de plasma en espalda y reactor con Bloom
    if m_plasma.getbbox():
        plasma_c = ImageOps.colorize(gray, black=(0, 0, 0), mid=pal_info["plasma_glow"], white=(255, 255, 255))
        res = Image.composite(plasma_c, res, m_plasma)

    # 4. Toberas de propulsión mecánicas oscuras
    mech_c = ImageOps.colorize(gray, black=(12, 14, 18), mid=pal_info["mech_mid"], white=(120, 130, 145))
    res = Image.composite(mech_c, res, m_mech)

    # 5. Cabello orgánico suave
    hair_c = ImageOps.colorize(gray, black=(20, 15, 22), mid=pal_info["hair_tint"], white=(250, 245, 245))
    blended_hair = Image.blend(base_rgb, hair_c, 0.62)
    res = Image.composite(blended_hair, res, hair_m)

    return Image.merge("RGBA", (*res.split(), alpha))


def process_all_ships():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_ships = {}
    tw, th = 256, 256

    for pilot in PILOTS:
        base_path = os.path.join(SHIPS_DIR, f"ship_{pilot.lower()}.png")
        mask_path = os.path.join(SHIPS_DIR, f"{pilot}_skin_mask.jpg")

        if not os.path.exists(base_path) or not os.path.exists(mask_path):
            print(f"Omitiendo {pilot}...")
            continue

        print(f"Procesando Nave: {pilot}...")
        base_img = Image.open(base_path).convert("RGBA")
        mask_img = Image.open(mask_path).convert("RGB")

        ship_skins = {"original": base_img}

        for pal_key, pal_info in PALETTES.items():
            skin_img = apply_ship_skin(base_img, mask_img, pilot, pal_info)
            ship_skins[pal_key] = skin_img
            # Guardar versión individual
            out_ship = os.path.join(OUTPUT_DIR, f"ship_{pilot.lower()}_{pal_key}.png")
            skin_img.save(out_ship)

        all_ships[pilot] = ship_skins

        # Tira comparativa de 4 columnas para esta nave
        strip = Image.new("RGBA", (tw * 4, th), (18, 20, 26, 255))
        cols = [
            ("Original", base_img),
            ("Cyber Neon", ship_skins["cyber_neon"]),
            ("Crimson Void", ship_skins["crimson_void"]),
            ("Solar Gold", ship_skins["solar_gold"])
        ]
        for idx, (label, img) in enumerate(cols):
            strip.paste(img, (idx * tw, 0), img)
        strip.save(os.path.join(OUTPUT_DIR, f"comparison_ship_{pilot.lower()}.png"))

    # Collage maestro del escuadrón completo
    master_grid = Image.new("RGBA", (tw * 7, th * 3), (16, 18, 24, 255))
    for p_idx, pilot in enumerate(PILOTS):
        if pilot not in all_ships:
            continue
        skins = all_ships[pilot]
        master_grid.paste(skins["original"], (p_idx * tw, 0), skins["original"])
        master_grid.paste(skins["cyber_neon"], (p_idx * tw, th), skins["cyber_neon"])
        master_grid.paste(skins["crimson_void"], (p_idx * tw, th * 2), skins["crimson_void"])

    master_path = os.path.join(OUTPUT_DIR, "master_ships_squadron_comparison.png")
    master_grid.save(master_path)

    print(f"\n¡Todas las 7 naves procesadas con éxito!")
    print(f"Salida: {OUTPUT_DIR}")
    print(f"Collage del Escuadrón: {master_path}")
    return True


if __name__ == "__main__":
    process_all_ships()
