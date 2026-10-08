#!/usr/bin/env python3
"""
tools/test_overworld_skins.py
Test de recoloreo para los assets de Overworld (Fullbody Front & Back):
  - Nova (Front y Back)
  - Kira (Front y Back)
Utiliza las máscaras:
  - Nova_skin_mask.jpg / NovaBack_skin_mask.jpg
  - Kira_skin_mask.jpg / KiraBack_skin_mask.jpg
Aplica la convención oficial:
  - Ropa: Smart Multi-Material (Mono temático + Placas de contraste claras + Juntas oscuras)
  - Pelo: Modulación suave y orgánica (62% blend)
  - Ojos: Iris cristalino (en vista frontal)
Genera tiras comparativas para cada vista y un collage de overworld.
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from tools.test_all_selection_skins import (
    PALETTES,
    decompose_clothing_universal
)

FULLBODY_DIR = os.path.join(BASE_DIR, "assets", "characters", "fullbody")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "overworld_batch")

OVERWORLD_TARGETS = [
    ("Nova Front", "fullbody_nova.png", "Nova_skin_mask.jpg"),
    ("Nova Back", "fullbody_nova_back.png", "NovaBack_skin_mask.jpg"),
    ("Kira Front", "fullbody_kira.png", "Kira_skin_mask.jpg"),
    ("Kira Back", "fullbody_kira_back.png", "KiraBack_skin_mask.jpg")
]


def extract_fullbody_masks(mask_img: Image.Image, target_size: tuple[int, int]) -> tuple[Image.Image, Image.Image, Image.Image]:
    """Escala la máscara JPG de 1792x2390 a 1200x1600 y separa canales."""
    m_resized = mask_img.resize(target_size, Image.Resampling.LANCZOS)
    mr, mg, mb = m_resized.split()

    clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    clothes = clothes.filter(ImageFilter.GaussianBlur(0.7))
    hair = hair.filter(ImageFilter.GaussianBlur(0.7))
    eyes = eyes.filter(ImageFilter.GaussianBlur(0.5))

    return clothes, hair, eyes


def apply_overworld_skin(
    base_img: Image.Image,
    mask_img: Image.Image,
    pal_info: dict
) -> Image.Image:
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)

    clothes_m, hair_m, eyes_m = extract_fullbody_masks(mask_img, base_img.size)
    m_suit, m_plates, m_mech = decompose_clothing_universal(base_img, clothes_m)

    res = base_rgb.copy()

    # 1. Cuerpo del traje (Smart Multi-Material)
    suit_c = ImageOps.colorize(
        gray,
        black=pal_info["suit_black"],
        mid=pal_info["suit_mid"],
        white=(230, 255, 255)
    )
    res = Image.composite(Image.blend(res, suit_c, 0.90), res, m_suit)

    # 2. Placas de blindaje claras de contraste
    plates_c = ImageOps.colorize(
        gray,
        black=pal_info["plates_black"],
        mid=pal_info["plates_mid"],
        white=(255, 255, 255)
    )
    res = Image.composite(plates_c, res, m_plates)

    # 3. Juntas mecánicas y suelas oscuras
    mech_c = ImageOps.colorize(
        gray,
        black=(12, 14, 18),
        mid=pal_info["mech_mid"],
        white=(120, 130, 145)
    )
    res = Image.composite(mech_c, res, m_mech)

    # 4. Cabello suave y orgánico
    hair_c = ImageOps.colorize(
        gray,
        black=(20, 15, 22),
        mid=pal_info["hair_tint"],
        white=(250, 245, 245)
    )
    blended_hair = Image.blend(base_rgb, hair_c, 0.62)
    res = Image.composite(blended_hair, res, hair_m)

    # 5. Ojos cristalinos (si la máscara contiene ojos, ej. vista frontal)
    if eyes_m.getbbox():
        eyes_c = ImageOps.colorize(
            gray,
            black=(0, 0, 0),
            mid=pal_info["eyes_tint"],
            white=(255, 255, 255)
        )
        blended_eyes = Image.blend(base_rgb, eyes_c, 0.88)
        res = Image.composite(blended_eyes, res, eyes_m)

    return Image.merge("RGBA", (*res.split(), alpha))


def process_overworld_test():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_results = {}
    tw, th = 360, 480

    for label, base_name, mask_name in OVERWORLD_TARGETS:
        bp = os.path.join(FULLBODY_DIR, base_name)
        mp = os.path.join(FULLBODY_DIR, mask_name)

        if not os.path.exists(bp) or not os.path.exists(mp):
            print(f"Omitiendo {label}...")
            continue

        print(f"Procesando Overworld: {label}...")
        base_img = Image.open(bp).convert("RGBA")
        mask_img = Image.open(mp).convert("RGB")

        views = {"original": base_img}

        tag = os.path.splitext(base_name)[0]
        for pal_key, pal_info in PALETTES.items():
            skin_img = apply_overworld_skin(base_img, mask_img, pal_info)
            views[pal_key] = skin_img
            # Guardar HD individual
            out_hd = os.path.join(OUTPUT_DIR, f"{tag}_{pal_key}.png")
            skin_img.save(out_hd)

        all_results[label] = views

        # Tira comparativa de 4 columnas
        strip = Image.new("RGBA", (tw * 4, th), (20, 22, 28, 255))
        cols = [
            ("Original", base_img),
            ("Cyber Neon", views["cyber_neon"]),
            ("Crimson Void", views["crimson_void"]),
            ("Solar Gold", views["solar_gold"])
        ]
        for i, (col_label, img) in enumerate(cols):
            thumb = img.resize((tw, th), Image.Resampling.LANCZOS)
            strip.paste(thumb, (i * tw, 0), thumb)

        strip_path = os.path.join(OUTPUT_DIR, f"comparison_{tag}.png")
        strip.save(strip_path)

    # Collage maestro de Overworld (Nova Front, Nova Back, Kira Front, Kira Back)
    master_grid = Image.new("RGBA", (tw * 4, th * 3), (16, 18, 24, 255))
    target_keys = ["Nova Front", "Nova Back", "Kira Front", "Kira Back"]
    for idx, key in enumerate(target_keys):
        if key not in all_results:
            continue
        v = all_results[key]
        # Fila 0: Original
        t0 = v["original"].resize((tw, th), Image.Resampling.LANCZOS)
        master_grid.paste(t0, (idx * tw, 0), t0)
        # Fila 1: Cyber Neon
        t1 = v["cyber_neon"].resize((tw, th), Image.Resampling.LANCZOS)
        master_grid.paste(t1, (idx * tw, th), t1)
        # Fila 2: Crimson Void
        t2 = v["crimson_void"].resize((tw, th), Image.Resampling.LANCZOS)
        master_grid.paste(t2, (idx * tw, th * 2), t2)

    master_path = os.path.join(OUTPUT_DIR, "master_overworld_nova_kira_comparison.png")
    master_grid.save(master_path)

    print(f"\n¡Overworld de Nova y Kira procesado con éxito!")
    print(f"Salida en: {OUTPUT_DIR}")
    print(f"Collage Maestro: {master_path}")
    return True


if __name__ == "__main__":
    process_overworld_test()
