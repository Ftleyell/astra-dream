#!/usr/bin/env python3
"""
tools/test_all_selection_skins.py
Batch test de recoloreo avanzado para los 7 pilotos del roster de Selección:
  - echo, kira, nova, nyx, roxy, selene, valentina
Aplica la convención oficial:
  - Ropa: Smart Multi-Material (Mono temático + Placas de contraste claras + Juntas oscuras)
  - Pelo: Modulación suave y orgánica (62% blend, conservando sombras y brillos anime)
  - Ojos / Visor: Iris cristalino sin halo desbordado
Genera tiras comparativas por piloto y un collage maestro con el roster completo.
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "selection_batch")

PILOTS = ["echo", "kira", "nova", "nyx", "roxy", "selene", "valentina"]

# Definición de 3 Paletas Universales de Prueba
PALETTES = {
    "cyber_neon": {
        "name": "Cyber Neon",
        "suit_mid": (0, 205, 235),          # Cian eléctrico
        "suit_black": (10, 22, 45),
        "plates_mid": (220, 232, 245),      # Blanco perlado con sombra celeste
        "plates_black": (60, 75, 95),
        "hair_tint": (185, 45, 120),        # Frambuesa suave orgánico
        "eyes_tint": (0, 215, 225),         # Turquesa cristalino
        "mech_mid": (45, 50, 60)
    },
    "crimson_void": {
        "name": "Crimson Void",
        "suit_mid": (195, 25, 55),          # Rojo carmesí de combate
        "suit_black": (35, 8, 14),
        "plates_mid": (240, 238, 242),      # Marfil / Titanio claro
        "plates_black": (70, 65, 75),
        "hair_tint": (60, 48, 65),          # Azabache oscuro con subtono frío
        "eyes_tint": (255, 40, 70),         # Rubí cristalino
        "mech_mid": (35, 32, 38)
    },
    "solar_gold": {
        "name": "Solar Gold",
        "suit_mid": (255, 190, 20),         # Oro estelar cálido
        "suit_black": (45, 28, 5),
        "plates_mid": (248, 246, 235),      # Blanco marfil cálido
        "plates_black": (80, 70, 55),
        "hair_tint": (125, 85, 55),         # Castaño ámbar suave
        "eyes_tint": (255, 215, 30),        # Ámbar dorado cristalino
        "mech_mid": (45, 42, 38)
    }
}


def extract_masks(mask_img: Image.Image) -> tuple[Image.Image, Image.Image, Image.Image]:
    mask_rgba = mask_img.convert("RGBA")
    mr, mg, mb, ma = mask_rgba.split()

    # Separación por canal dominante puro
    clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    # Recortar con transparencia si la hay
    clothes = ImageChops.multiply(clothes, ma)
    hair = ImageChops.multiply(hair, ma)
    eyes = ImageChops.multiply(eyes, ma)

    # Suavizado subpíxel
    clothes = clothes.filter(ImageFilter.GaussianBlur(0.7))
    hair = hair.filter(ImageFilter.GaussianBlur(0.7))
    eyes = eyes.filter(ImageFilter.GaussianBlur(0.5))

    return clothes, hair, eyes


def decompose_clothing_universal(base_img: Image.Image, clothes_mask: Image.Image):
    """
    Descompone universalmente cualquier ropa de cualquier piloto en 3 materiales:
      - m_plates: placas claras / rodilleras / franjas blancas (brillo alto y desaturado)
      - m_mech: suelas, juntas, ranuras mecánicas oscuras (brillo bajo)
      - m_suit: mono / cuerpo principal del traje
    """
    img_rgb = base_img.convert("RGB")
    hsv = img_rgb.convert("HSV")
    h, s, v = hsv.split()
    gray = ImageOps.grayscale(img_rgb)

    # 1. Placas de blindaje claras: desaturado y brillante
    lut_desat = [255 if x < 80 else 0 for x in range(256)]
    lut_bright = [255 if x >= 140 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    m_plates = ImageChops.multiply(m_plates, clothes_mask)

    # 2. Partes oscuras y mecánicas: brillo < 65
    lut_dark = [255 if x < 65 else 0 for x in range(256)]
    m_mech = ImageChops.multiply(gray.point(lut_dark), clothes_mask)

    # 3. Cuerpo principal (restante)
    m_suit = ImageChops.subtract(clothes_mask, ImageChops.add(m_plates, m_mech))

    m_plates = m_plates.filter(ImageFilter.GaussianBlur(0.6))
    m_mech = m_mech.filter(ImageFilter.GaussianBlur(0.5))
    m_suit = m_suit.filter(ImageFilter.GaussianBlur(0.6))

    return m_suit, m_plates, m_mech


def apply_palette_to_pilot(
    base_img: Image.Image,
    mask_img: Image.Image,
    pal_data: dict
) -> Image.Image:
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)

    clothes_m, hair_m, eyes_m = extract_masks(mask_img)
    m_suit, m_plates, m_mech = decompose_clothing_universal(base_img, clothes_m)

    res = base_rgb.copy()

    # 1. Cuerpo del traje (Smart Multi-Material)
    suit_c = ImageOps.colorize(
        gray,
        black=pal_data["suit_black"],
        mid=pal_data["suit_mid"],
        white=(230, 255, 255)
    )
    res = Image.composite(Image.blend(res, suit_c, 0.90), res, m_suit)

    # 2. Placas de blindaje claras de contraste
    plates_c = ImageOps.colorize(
        gray,
        black=pal_data["plates_black"],
        mid=pal_data["plates_mid"],
        white=(255, 255, 255)
    )
    res = Image.composite(plates_c, res, m_plates)

    # 3. Juntas y partes mecánicas oscuras
    mech_c = ImageOps.colorize(
        gray,
        black=(12, 14, 18),
        mid=pal_data["mech_mid"],
        white=(120, 130, 145)
    )
    res = Image.composite(mech_c, res, m_mech)

    # 4. Cabello suave y orgánico (62% blend, sombras protegidas)
    hair_c = ImageOps.colorize(
        gray,
        black=(20, 15, 22),
        mid=pal_data["hair_tint"],
        white=(250, 245, 245)
    )
    blended_hair = Image.blend(base_rgb, hair_c, 0.62)
    res = Image.composite(blended_hair, res, hair_m)

    # 5. Ojos cristalinos (pupila negra y brillo blanco protegidos)
    eyes_c = ImageOps.colorize(
        gray,
        black=(0, 0, 0),
        mid=pal_data["eyes_tint"],
        white=(255, 255, 255)
    )
    blended_eyes = Image.blend(base_rgb, eyes_c, 0.88)
    res = Image.composite(blended_eyes, res, eyes_m)

    return Image.merge("RGBA", (*res.split(), alpha))


def process_all_pilots():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_results = {}

    thumb_w, thumb_h = 360, 480

    for pilot in PILOTS:
        base_path = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
        mask_path = os.path.join(SELECTION_DIR, f"selection_{pilot}_mask.png")

        if not os.path.exists(base_path) or not os.path.exists(mask_path):
            print(f"Omitiendo {pilot}: no se encontró base o máscara.")
            continue

        print(f"Procesando piloto: {pilot.capitalize()}...")
        base_img = Image.open(base_path).convert("RGBA")
        mask_img = Image.open(mask_path).convert("RGBA")

        pilot_skins = {"original": base_img}

        for pal_key, pal_info in PALETTES.items():
            skin_img = apply_palette_to_pilot(base_img, mask_img, pal_info)
            pilot_skins[pal_key] = skin_img
            # Guardar versión HD individual
            hd_path = os.path.join(OUTPUT_DIR, f"selection_{pilot}_{pal_key}.png")
            skin_img.save(hd_path)

        all_results[pilot] = pilot_skins

        # Generar tira comparativa de 4 columnas para este piloto
        strip = Image.new("RGBA", (thumb_w * 4, thumb_h), (20, 22, 28, 255))
        cols = [
            ("Original", base_img),
            ("Cyber Neon", pilot_skins["cyber_neon"]),
            ("Crimson Void", pilot_skins["crimson_void"]),
            ("Solar Gold", pilot_skins["solar_gold"])
        ]
        for col_idx, (label, img) in enumerate(cols):
            thumb = img.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            strip.paste(thumb, (col_idx * thumb_w, 0), thumb)

        strip_path = os.path.join(OUTPUT_DIR, f"comparison_{pilot}.png")
        strip.save(strip_path)

    # -------------------------------------------------------------
    # Generar Collage Maestro del Roster Completo (7 pilotos)
    # Mostrando: Original vs Cyber Neon
    # -------------------------------------------------------------
    roster_thumb_w, roster_thumb_h = 240, 320
    master_grid = Image.new("RGBA", (roster_thumb_w * 7, roster_thumb_h * 3), (16, 18, 24, 255))

    for p_idx, pilot in enumerate(PILOTS):
        if pilot not in all_results:
            continue
        skins = all_results[pilot]
        # Fila 0: Original
        t_orig = skins["original"].resize((roster_thumb_w, roster_thumb_h), Image.Resampling.LANCZOS)
        master_grid.paste(t_orig, (p_idx * roster_thumb_w, 0), t_orig)
        # Fila 1: Cyber Neon
        t_cyber = skins["cyber_neon"].resize((roster_thumb_w, roster_thumb_h), Image.Resampling.LANCZOS)
        master_grid.paste(t_cyber, (p_idx * roster_thumb_w, roster_thumb_h), t_cyber)
        # Fila 2: Crimson Void
        t_crim = skins["crimson_void"].resize((roster_thumb_w, roster_thumb_h), Image.Resampling.LANCZOS)
        master_grid.paste(t_crim, (p_idx * roster_thumb_w, roster_thumb_h * 2), t_crim)

    master_path = os.path.join(OUTPUT_DIR, "master_roster_recolor_comparison.png")
    master_grid.save(master_path)

    print(f"\n¡Todos los 7 pilotos procesados con éxito!")
    print(f"Salida en: {OUTPUT_DIR}")
    print(f"Collage Maestro: {master_path}")
    return True


if __name__ == "__main__":
    process_all_pilots()
