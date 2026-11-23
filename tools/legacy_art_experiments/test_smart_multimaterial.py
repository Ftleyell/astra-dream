#!/usr/bin/env python3
"""
tools/test_smart_multimaterial.py
Prueba de recoloreo inteligente con preservación de multi-materiales del asset original.
Dentro de la máscara roja de la ropa detecta automáticamente:
  1. Paneles de blindaje claros/blancos
  2. Visor/cristales secundarios
  3. Partes mecánicas oscuras (suelas, juntas)
  4. Cuerpo principal del traje
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from PIL import Image, ImageOps, ImageChops, ImageFilter
from tools.test_skin_methods import extract_masks
BASE_IMG_PATH = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_nova.png")
MASK_IMG_PATH = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_nova_mask.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison")


def decompose_clothing_materials(base_img: Image.Image, clothes_mask: Image.Image):
    """
    Descompone la máscara de ropa en 3 sub-máscaras basadas en las propiedades
    naturales de color y luminosidad del dibujo original:
      - suit_body: el tejido/mono dominante
      - plates_light: placas de blindaje, rodilleras y franjas claras
      - visor_crystals: visores, cristales o acentos cromáticos secundarios
      - mechanical_dark: suelas, juntas y partes mecánicas profundas
    """
    img_rgb = base_img.convert("RGB")
    hsv = img_rgb.convert("HSV")
    h, s, v = hsv.split()
    gray = ImageOps.grayscale(img_rgb)

    # 1. Visor / Cristales (Cian/Azul original: Hue ~ 110-160 en escala 0-255, Sat > 40)
    lut_visor_h = [255 if 105 <= x <= 165 else 0 for x in range(256)]
    lut_sat_hi = [255 if x >= 40 else 0 for x in range(256)]
    m_visor = ImageChops.multiply(h.point(lut_visor_h), s.point(lut_sat_hi))
    m_visor = ImageChops.multiply(m_visor, clothes_mask)

    # 2. Placas de blindaje claras (Gris/blanco o desaturado con alto brillo)
    lut_desat = [255 if x < 65 else 0 for x in range(256)]
    lut_bright = [255 if x >= 145 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    m_plates = ImageChops.multiply(m_plates, clothes_mask)
    # Excluir visor si se solapa
    m_plates = ImageChops.subtract(m_plates, m_visor)

    # 3. Juntas y partes mecánicas oscuras (Bajo brillo)
    lut_dark = [255 if x < 60 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_mask)
    m_mech = ImageChops.subtract(m_mech, m_visor)

    # 4. Cuerpo principal del traje (Todo lo que queda de la ropa)
    m_suit = ImageChops.subtract(clothes_mask, ImageChops.add(m_visor, ImageChops.add(m_plates, m_mech)))

    # Suavizado leve de bordes para evitar aliasing
    m_suit = m_suit.filter(ImageFilter.GaussianBlur(0.6))
    m_plates = m_plates.filter(ImageFilter.GaussianBlur(0.6))
    m_visor = m_visor.filter(ImageFilter.GaussianBlur(0.6))
    m_mech = m_mech.filter(ImageFilter.GaussianBlur(0.5))

    return m_suit, m_plates, m_visor, m_mech


def run_smart_test():
    base_img = Image.open(BASE_IMG_PATH).convert("RGBA")
    mask_img = Image.open(MASK_IMG_PATH).convert("RGBA")
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]

    clothes_m, hair_m, eyes_m = extract_masks(mask_img)
    m_suit, m_plates, m_visor, m_mech = decompose_clothing_materials(base_img, clothes_m)

    gray = ImageOps.grayscale(base_rgb)

    # =========================================================================
    # EJEMPLO 1: "CYBER VALKYRIE" (Cian Neón + Blindaje Blanco Perlado + Visor Magenta)
    # =========================================================================
    res1 = base_rgb.copy()
    # Pelo: Magenta/Púrpura vibrante
    hair_c = ImageOps.colorize(gray, black=(35, 10, 48), mid=(235, 45, 160), white=(255, 215, 240))
    res1 = Image.composite(Image.blend(res1, hair_c, 0.88), res1, hair_m)

    # Cuerpo del traje: Cian eléctrico
    suit_c = ImageOps.colorize(gray, black=(10, 22, 45), mid=(0, 205, 235), white=(225, 255, 255))
    res1 = Image.composite(Image.blend(res1, suit_c, 0.92), res1, m_suit)

    # Placas: Blanco perlado con sombra fría celeste (¡NO SE TIÑEN DE CIAN PLANO!)
    plates_c = ImageOps.colorize(gray, black=(60, 75, 95), mid=(220, 232, 245), white=(255, 255, 255))
    res1 = Image.composite(plates_c, res1, m_plates)

    # Visor/Gafas: Magenta emisivo que hace juego con el cabello y genera contraste
    visor_c = ImageOps.colorize(gray, black=(40, 5, 30), mid=(255, 30, 150), white=(255, 220, 245))
    res1 = Image.composite(visor_c, res1, m_visor)

    # Juntas mecánicas: Grafito oscuro neutro
    mech_c = ImageOps.colorize(gray, black=(15, 18, 22), mid=(45, 50, 60), white=(120, 130, 145))
    res1 = Image.composite(mech_c, res1, m_mech)

    # Ojos: Turquesa brillante
    eyes_c = ImageOps.colorize(gray, black=(0, 30, 40), mid=(0, 255, 220), white=(255, 255, 255))
    res1 = Image.composite(eyes_c, res1, eyes_m)

    out1 = Image.merge("RGBA", (*res1.split(), alpha))
    out1_path = os.path.join(OUTPUT_DIR, "smart_multimaterial_cyber_valkyrie.png")
    out1.save(out1_path)

    # =========================================================================
    # EJEMPLO 2: "SOLAR KNIGHT" (Negro Carbón + Placas Oro Solar + Visor Ámbar)
    # =========================================================================
    res2 = base_rgb.copy()
    # Pelo: Blanco platino con sombras lila
    lut_plat = [min(255, int(pow(x / 255.0, 0.7) * 220 + 35)) for x in range(256)]
    plat_gray = gray.point(lut_plat)
    hair_plat = ImageOps.colorize(plat_gray, black=(145, 150, 185), mid=(235, 238, 248), white=(255, 255, 255))
    res2 = Image.composite(hair_plat, res2, hair_m)

    # Cuerpo del traje: Negro titanio mate (Stealth body)
    lut_dark = [int(pow(x / 255.0, 1.6) * 155) for x in range(256)]
    dark_gray = gray.point(lut_dark)
    suit_dark = ImageOps.colorize(dark_gray, black=(8, 10, 14), mid=(28, 32, 42), white=(160, 170, 190))
    res2 = Image.composite(suit_dark, res2, m_suit)

    # Placas: ORO SOLAR resplandeciente (¡Alto contraste contra el traje negro!)
    plates_gold = ImageOps.colorize(gray, black=(60, 35, 5), mid=(255, 195, 25), white=(255, 250, 210))
    res2 = Image.composite(plates_gold, res2, m_plates)

    # Visor/Gafas: Oro ámbar reflectante
    visor_gold = ImageOps.colorize(gray, black=(45, 20, 0), mid=(255, 140, 0), white=(255, 240, 180))
    res2 = Image.composite(visor_gold, res2, m_visor)

    # Ojos: Dorados con resplandor
    eyes_gold = ImageOps.colorize(gray, black=(30, 20, 0), mid=(255, 215, 0), white=(255, 255, 255))
    res2 = Image.composite(eyes_gold, res2, eyes_m)

    out2 = Image.merge("RGBA", (*res2.split(), alpha))
    out2_path = os.path.join(OUTPUT_DIR, "smart_multimaterial_solar_knight.png")
    out2.save(out2_path)

    # =========================================================================
    # Collage comparativo: Plano vs Multi-Material
    # =========================================================================
    flat_cyan = Image.open(os.path.join(OUTPUT_DIR, "method1_gradient_mapping.png"))
    flat_gold = Image.open(os.path.join(OUTPUT_DIR, "method2_emissive_bloom.png"))

    tw, th = 400, 533
    grid = Image.new("RGBA", (tw * 4, th), (18, 20, 26, 255))
    comparisons = [
        ("Cian Plano (Anterior)", flat_cyan),
        ("Cian Multi-Material (Nuevo)", out1),
        ("Oro Plano (Anterior)", flat_gold),
        ("Oro Multi-Material (Nuevo)", out2)
    ]
    for i, (title, img) in enumerate(comparisons):
        thumb = img.resize((tw, th), Image.Resampling.LANCZOS)
        grid.paste(thumb, (i * tw, 0), thumb)

    comp_path = os.path.join(OUTPUT_DIR, "multimaterial_vs_flat_comparison.png")
    grid.save(comp_path)
    print(f"Comparativa Multi-Material generada: {comp_path}")


if __name__ == "__main__":
    run_smart_test()
