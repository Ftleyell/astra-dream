#!/usr/bin/env python3
"""
tools/test_soft_hair_eyes.py
Prueba comparativa de tratamiento para Pelo y Ojos:
  - Ropa: Multi-material inteligente (Mono + Placas de contraste + Juntas + Visor)
  - Pelo y Ojos:
      Opción A: Tratamiento "Agresivo" (Rampa completa de gradiente saturada)
      Opción B: Tratamiento "Suave / Orgánico" (Hue-shift natural, retención de sombras/brillos originales, iris cristalino sin halo exagerado)
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from PIL import Image, ImageOps, ImageChops, ImageFilter
from tools.test_skin_methods import extract_masks
from tools.test_smart_multimaterial import decompose_clothing_materials

BASE_IMG_PATH = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_nova.png")
MASK_IMG_PATH = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_nova_mask.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison")


def apply_soft_hair_tint(
    base_rgb: Image.Image,
    hair_mask: Image.Image,
    target_tint_rgb: tuple[int, int, int],
    strength: float = 0.65
) -> Image.Image:
    """
    Tratamiento Suave / Orgánico para Cabello:
    Conserva las sombras profundas, los mechones oscuros y los brillos blancos originales.
    Aplica una modulación de tono usando modo Color / Multiplicación balanceada.
    """
    gray = ImageOps.grayscale(base_rgb)
    # Rampa suave: sombras permanecen castaño oscuro/carbón, medios reciben el tinte, brillos quedan limpios
    soft_colored = ImageOps.colorize(
        gray,
        black=(20, 15, 20),           # Sombras profundas neutras naturales
        mid=target_tint_rgb,          # Color deseado
        white=(250, 245, 245)         # Brillo blanco especular original
    )
    # Mezcla ponderada suave sobre el color original
    blended = Image.blend(base_rgb, soft_colored, strength)
    return Image.composite(blended, base_rgb, hair_mask)


def apply_soft_eyes(
    base_rgb: Image.Image,
    eyes_mask: Image.Image,
    iris_tint_rgb: tuple[int, int, int]
) -> Image.Image:
    """
    Tratamiento Suave / Cristalino para Ojos:
    Conserva la pupila negra y el punto de brillo blanco del ojo original.
    Tiñe solo el iris con acabado cristalino sin generar un halo de linterna exterior.
    """
    gray = ImageOps.grayscale(base_rgb)
    # Conservar negro puro en pupila (black=(0,0,0)) y blanco puro en reflejos
    iris_colored = ImageOps.colorize(
        gray,
        black=(0, 0, 0),
        mid=iris_tint_rgb,
        white=(255, 255, 255)
    )
    blended = Image.blend(base_rgb, iris_colored, 0.85)
    return Image.composite(blended, base_rgb, eyes_mask)


def run_soft_comparison():
    base_img = Image.open(BASE_IMG_PATH).convert("RGBA")
    mask_img = Image.open(MASK_IMG_PATH).convert("RGBA")
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]

    clothes_m, hair_m, eyes_m = extract_masks(mask_img)
    m_suit, m_plates, m_visor, m_mech = decompose_clothing_materials(base_img, clothes_m)
    gray = ImageOps.grayscale(base_rgb)

    # Base de ropa Multi-Material para ambas versiones
    def apply_clothing_base(canvas_rgb, suit_mid, plates_mid, visor_mid):
        suit_c = ImageOps.colorize(gray, black=(10, 22, 45), mid=suit_mid, white=(225, 255, 255))
        canvas = Image.composite(Image.blend(canvas_rgb, suit_c, 0.92), canvas_rgb, m_suit)

        plates_c = ImageOps.colorize(gray, black=(60, 75, 95), mid=plates_mid, white=(255, 255, 255))
        canvas = Image.composite(plates_c, canvas, m_plates)

        visor_c = ImageOps.colorize(gray, black=(20, 10, 25), mid=visor_mid, white=(255, 255, 255))
        canvas = Image.composite(visor_c, canvas, m_visor)

        mech_c = ImageOps.colorize(gray, black=(15, 18, 22), mid=(45, 50, 60), white=(120, 130, 145))
        canvas = Image.composite(mech_c, canvas, m_mech)
        return canvas

    # =========================================================================
    # VERSIÓN 1: Cyber Valkyrie (Comparativa Pelo Agresivo vs Suave)
    # =========================================================================
    # A) Pelo Agresivo (La que hicimos antes: rampa magenta fuerte)
    v1_agressive = apply_clothing_base(base_rgb.copy(), (0, 205, 235), (220, 232, 245), (255, 30, 150))
    hair_aggr = ImageOps.colorize(gray, black=(35, 10, 48), mid=(235, 45, 160), white=(255, 215, 240))
    v1_agressive = Image.composite(Image.blend(v1_agressive, hair_aggr, 0.88), v1_agressive, hair_m)
    v1_agressive = Image.composite(ImageOps.colorize(gray, (0, 30, 40), (0, 255, 220), (255, 255, 255)), v1_agressive, eyes_m)

    # B) Pelo Suave / Orgánico (Reflejo frambuesa suave manteniendo textura y raíces originales)
    v1_soft = apply_clothing_base(base_rgb.copy(), (0, 205, 235), (220, 232, 245), (255, 30, 150))
    v1_soft = apply_soft_hair_tint(v1_soft, hair_m, target_tint_rgb=(185, 45, 120), strength=0.62)
    v1_soft = apply_soft_eyes(v1_soft, eyes_m, iris_tint_rgb=(0, 210, 220))

    # C) Pelo Natural Original con apenas un brillo frío (mantiene el castaño original pero afinado)
    v1_natural = apply_clothing_base(base_rgb.copy(), (0, 205, 235), (220, 232, 245), (255, 30, 150))
    v1_natural = apply_soft_hair_tint(v1_natural, hair_m, target_tint_rgb=(120, 80, 95), strength=0.40)
    v1_natural = apply_soft_eyes(v1_natural, eyes_m, iris_tint_rgb=(0, 210, 220))

    # =========================================================================
    # VERSIÓN 2: Carmesí Abisal (Pelo Negro Azabache Suave con Ojos Rubí Cristalinos)
    # =========================================================================
    v2_soft = apply_clothing_base(base_rgb.copy(), (180, 20, 50), (235, 235, 240), (255, 60, 80))
    # Pelo negro azabache con brillo azulado sutil
    v2_soft = apply_soft_hair_tint(v2_soft, hair_m, target_tint_rgb=(50, 45, 60), strength=0.70)
    v2_soft = apply_soft_eyes(v2_soft, eyes_m, iris_tint_rgb=(255, 35, 65))

    # Guardar
    out_a = Image.merge("RGBA", (*v1_agressive.split(), alpha))
    out_b = Image.merge("RGBA", (*v1_soft.split(), alpha))
    out_c = Image.merge("RGBA", (*v1_natural.split(), alpha))
    out_d = Image.merge("RGBA", (*v2_soft.split(), alpha))

    out_b.save(os.path.join(OUTPUT_DIR, "soft_hair_eyes_valkyrie.png"))
    out_d.save(os.path.join(OUTPUT_DIR, "soft_hair_eyes_crimson.png"))

    tw, th = 400, 533
    grid = Image.new("RGBA", (tw * 4, th), (18, 20, 26, 255))
    images = [
        ("Pelo Agresivo (Magenta Fuerte)", out_a),
        ("Pelo Suave (Frambuesa Orgánico)", out_b),
        ("Pelo Castaño Natural Afinado", out_c),
        ("Pelo Azabache Suave / Rubí", out_d)
    ]
    for i, (title, img) in enumerate(images):
        thumb = img.resize((tw, th), Image.Resampling.LANCZOS)
        grid.paste(thumb, (i * tw, 0), thumb)

    comp_path = os.path.join(OUTPUT_DIR, "hair_eyes_soft_comparison.png")
    grid.save(comp_path)
    print(f"Comparativa suave generada: {comp_path}")


if __name__ == "__main__":
    run_soft_comparison()
