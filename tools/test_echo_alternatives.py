#!/usr/bin/env python3
"""
tools/test_echo_alternatives.py
Exploración de alternativas de recoloreo para Echo (Androide Sintética).
Dado que su cuerpo es un chasis biomecánico/sintético, exploramos 4 direcciones:
  1. Stealth Android / Chasis Titanio Oscuro (tipo NieR / Ghost in the Shell) con circuitos neón
  2. Chasis Esmaltado de Combate (Color temático cubre las placas con acabado deportivo)
  3. Bicolor Cyberpunk (Cuerpo con tinte profundo, placas en contraste claro, pelo brillante)
  4. Fibra Óptica Radiante (Pelo y circuitos con modulación emisiva de alta frecuencia)
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from tools.test_all_selection_skins import extract_masks

ECHO_BASE = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_echo.png")
ECHO_MASK = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_echo_mask.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison")


def test_echo_variants():
    base_img = Image.open(ECHO_BASE).convert("RGBA")
    mask_img = Image.open(ECHO_MASK).convert("RGBA")
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)

    clothes_m, hair_m, eyes_m = extract_masks(mask_img)

    # Aislar ranuras y articulaciones oscuras de Echo (brillo < 130)
    lut_joints = [255 if x < 130 else 0 for x in range(256)]
    m_joints = ImageChops.multiply(gray.point(lut_joints), clothes_m)
    m_body_plates = ImageChops.subtract(clothes_m, m_joints)

    # -------------------------------------------------------------------------
    # VARIANTE 1: STEALTH TITANIO / OBSIDIANA (Chasis Negro Carbón + Pelo Platino + Ojos Neón)
    # -------------------------------------------------------------------------
    v1 = base_rgb.copy()
    # Chasis de carbono oscuro preservando volumen
    lut_dark = [int(pow(x / 255.0, 1.5) * 130) for x in range(256)]
    dark_gray = gray.point(lut_dark)
    body_dark = ImageOps.colorize(dark_gray, black=(10, 12, 16), mid=(25, 28, 38), white=(150, 160, 185))
    v1 = Image.composite(body_dark, v1, m_body_plates)

    # Articulaciones y líneas de circuito: Cian Eléctrico vivo
    joints_cyan = ImageOps.colorize(gray, black=(0, 20, 30), mid=(0, 220, 255), white=(220, 255, 255))
    v1 = Image.composite(joints_cyan, v1, m_joints)

    # Pelo: Blanco Platino anime puro con sombras gris lila
    lut_plat = [min(255, int(pow(x / 255.0, 0.65) * 220 + 35)) for x in range(256)]
    hair_plat = ImageOps.colorize(gray.point(lut_plat), black=(140, 145, 175), mid=(235, 238, 248), white=(255, 255, 255))
    v1 = Image.composite(hair_plat, v1, hair_m)

    # Ojos: Turquesa reactivo
    eyes_c = ImageOps.colorize(gray, black=(0, 0, 0), mid=(0, 240, 255), white=(255, 255, 255))
    v1 = Image.composite(eyes_c, v1, eyes_m)
    out_v1 = Image.merge("RGBA", (*v1.split(), alpha))
    out_v1.save(os.path.join(OUTPUT_DIR, "echo_alt1_stealth_titanium.png"))

    # -------------------------------------------------------------------------
    # VARIANTE 2: ESMALTADO CARMESÍ / COMBATE (Chasis Rojo Rubí Metálico + Juntas Negras)
    # -------------------------------------------------------------------------
    v2 = base_rgb.copy()
    # El chasis blanco se convierte en esmaltado rojo metálico de alta gama
    body_crimson = ImageOps.colorize(gray, black=(35, 5, 12), mid=(205, 30, 60), white=(255, 220, 230))
    v2 = Image.composite(body_crimson, v2, m_body_plates)

    # Articulaciones y líneas: Negro carbón profundo
    joints_dark = ImageOps.colorize(gray, black=(8, 8, 12), mid=(30, 30, 38), white=(80, 85, 95))
    v2 = Image.composite(joints_dark, v2, m_joints)

    # Pelo: Negro azabache suave con reflejos rubí
    hair_crim = ImageOps.colorize(gray, black=(15, 8, 12), mid=(70, 35, 45), white=(240, 220, 230))
    v2 = Image.composite(Image.blend(base_rgb, hair_crim, 0.70), v2, hair_m)

    # Ojos: Rubí vivo
    eyes_crim = ImageOps.colorize(gray, black=(0, 0, 0), mid=(255, 35, 65), white=(255, 255, 255))
    v2 = Image.composite(eyes_crim, v2, eyes_m)
    out_v2 = Image.merge("RGBA", (*v2.split(), alpha))
    out_v2.save(os.path.join(OUTPUT_DIR, "echo_alt2_crimson_enamel.png"))

    # -------------------------------------------------------------------------
    # VARIANTE 3: ORO SOLAR / PROTOTIPO DIVINO (Chasis Blanco Perlado + Placas Oro + Circuitos Dorados)
    # -------------------------------------------------------------------------
    v3 = base_rgb.copy()
    # Chasis blanco marfil refinado
    body_pearl = ImageOps.colorize(gray, black=(45, 42, 40), mid=(245, 242, 235), white=(255, 255, 255))
    v3 = Image.composite(body_pearl, v3, m_body_plates)

    # Articulaciones y líneas de circuito: Oro solar brillante
    joints_gold = ImageOps.colorize(gray, black=(50, 30, 5), mid=(255, 195, 20), white=(255, 250, 210))
    v3 = Image.composite(joints_gold, v3, m_joints)

    # Pelo: Oro ámbar fluido
    hair_gold = ImageOps.colorize(gray, black=(35, 22, 10), mid=(210, 150, 45), white=(255, 245, 210))
    v3 = Image.composite(Image.blend(base_rgb, hair_gold, 0.75), v3, hair_m)

    # Ojos: Ámbar solar
    v3 = Image.composite(ImageOps.colorize(gray, (0, 0, 0), (255, 215, 30), (255, 255, 255)), v3, eyes_m)
    out_v3 = Image.merge("RGBA", (*v3.split(), alpha))
    out_v3.save(os.path.join(OUTPUT_DIR, "echo_alt3_solar_prototype.png"))

    # -------------------------------------------------------------------------
    # VARIANTE 4: VIOLETA ABISAL / NEÓN MAGENTA (Chasis Púrpura Profundo + Circuitos Magenta)
    # -------------------------------------------------------------------------
    v4 = base_rgb.copy()
    # Chasis azul marino / púrpura cósmico profundo
    body_void = ImageOps.colorize(gray, black=(15, 10, 30), mid=(55, 35, 95), white=(190, 180, 230))
    v4 = Image.composite(body_void, v4, m_body_plates)

    # Articulaciones y líneas: Magenta neón reactivo
    joints_mag = ImageOps.colorize(gray, black=(30, 5, 25), mid=(255, 30, 160), white=(255, 210, 245))
    v4 = Image.composite(joints_mag, v4, m_joints)

    # Pelo: Pelo cian cuántico brillante
    hair_cyan = ImageOps.colorize(gray, black=(5, 25, 35), mid=(0, 215, 240), white=(230, 255, 255))
    v4 = Image.composite(Image.blend(base_rgb, hair_cyan, 0.85), v4, hair_m)

    # Ojos: Magenta
    v4 = Image.composite(ImageOps.colorize(gray, (0, 0, 0), (255, 40, 160), (255, 255, 255)), v4, eyes_m)
    out_v4 = Image.merge("RGBA", (*v4.split(), alpha))
    out_v4.save(os.path.join(OUTPUT_DIR, "echo_alt4_void_magenta.png"))

    # Collage comparativo
    tw, th = 360, 480
    grid = Image.new("RGBA", (tw * 5, th), (16, 18, 24, 255))
    images = [
        ("Base Original", base_img),
        ("Alt 1: Stealth Titanio", out_v1),
        ("Alt 2: Esmaltado Carmesí", out_v2),
        ("Alt 3: Oro Prototipo", out_v3),
        ("Alt 4: Violeta Abisal", out_v4)
    ]
    for i, (title, img) in enumerate(images):
        thumb = img.resize((tw, th), Image.Resampling.LANCZOS)
        grid.paste(thumb, (i * tw, 0), thumb)

    comp_path = os.path.join(OUTPUT_DIR, "echo_alternatives_comparison.png")
    grid.save(comp_path)
    print(f"Comparativa de alternativas para Echo generada: {comp_path}")
    return True


if __name__ == "__main__":
    test_echo_variants()
