#!/usr/bin/env python3
"""
tools/test_echo_clean.py
Test de recoloreo LIMPIO y SIN QUEMAR para Echo.
Causas del efecto 'frito' anterior:
  1. El rostro de Echo estaba pintado de rojo en la máscara, por lo que el script
     trató su cara como si fuera metal/chasis oscuro.
  2. Las curvas de contraste forzadas (LUT potencias) rompieron los degradados suaves.
Solución:
  - Aislar el rostro para mantenerlo como porcelana limpia y tersa sin artefactos.
  - Usar rotación armónica de Tono y Saturación (modo COLOR en HSL) que preserva
    el 100% de la luminosidad y suavidad original del dibujo (cero banding, cero quemado).
"""

import os
import colorsys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ECHO_BASE = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_echo.png")
ECHO_MASK = os.path.join(BASE_DIR, "assets", "characters", "selection", "selection_echo_mask.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison")


def clean_hue_shift(img: Image.Image, mask: Image.Image, target_hue: float, sat_mult: float = 1.0) -> Image.Image:
    """
    Rotación de tono en espacio HSL matemáticamente continua.
    Preserva el 100% de la textura, anti-aliasing y gradientes del dibujo original sin quemar.
    """
    img_rgb = img.convert("RGB")
    w, h = img.size
    pixels = img_rgb.load()
    m_pix = mask.load()

    out = img_rgb.copy()
    out_pix = out.load()

    for y in range(h):
        for x in range(w):
            m_val = m_pix[x, y]
            if m_val < 15:
                continue

            r, g, b = pixels[x, y]
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h_val, s_val, v_val = colorsys.rgb_to_hsv(rf, gf, bf)

            factor = m_val / 255.0

            # Aplicar nuevo tono respetando el brillo y la saturación relativa
            new_h = target_hue
            new_s = min(1.0, s_val * sat_mult)
            new_v = v_val

            nr, ng, nb = colorsys.hsv_to_rgb(new_h, new_s, new_v)
            ir, ig, ib = int(nr * 255), int(ng * 255), int(nb * 255)

            # Mezcla ponderada suave por máscara
            fin_r = int(r * (1.0 - factor) + ir * factor)
            fin_g = int(g * (1.0 - factor) + ig * factor)
            fin_b = int(b * (1.0 - factor) + ib * factor)
            out_pix[x, y] = (fin_r, fin_g, fin_b)

    return out


def test_clean_echo():
    base_img = Image.open(ECHO_BASE).convert("RGBA")
    mask_img = Image.open(ECHO_MASK).convert("RGBA")
    mr, mg, mb, ma = mask_img.split()
    alpha = base_img.split()[3]

    # Separar pelo y ojos
    hair_m = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    eyes_m = ImageChops.subtract(mb, ImageChops.add(mr, mg))
    clothes_raw = ImageChops.subtract(mr, ImageChops.add(mg, mb))

    # Detectar el rostro dentro de la máscara roja (el rostro tiene brillo alto y está en la cabeza)
    # y excluirlo de la máscara de ropa para que la cara quede limpia y suave de porcelana
    w, h = base_img.size
    face_box = Image.new("L", (w, h), 0)
    # Región aproximada del rostro (cabeza: x de 450 a 650, y de 100 a 300)
    for y in range(int(h * 0.08), int(h * 0.22)):
        for x in range(int(w * 0.38), int(w * 0.58)):
            face_box.putpixel((x, y), 255)

    # La cara de Echo es la piel clara de la cabeza
    gray = ImageOps.grayscale(base_img)
    lut_skin = [255 if x > 200 else 0 for x in range(256)]
    face_area = ImageChops.multiply(gray.point(lut_skin), face_box)
    face_area = face_area.filter(ImageFilter.GaussianBlur(1.5))

    # La ropa/cuerpo ahora NO incluye la cara
    clothes_m = ImageChops.subtract(clothes_raw, face_area)

    base_rgb = base_img.convert("RGB")

    # =========================================================================
    # INTENTO 1: CYBER MAGENTA / SAKURA ANDROID (Suave, cristalina, CERO quemado)
    # =========================================================================
    # Pelo: Magenta/Rosa eléctrico limpio
    res1 = clean_hue_shift(base_rgb, hair_m, target_hue=0.90, sat_mult=1.1)
    # Líneas y circuitos del cuerpo: Magenta/Rosa
    res1 = clean_hue_shift(res1, clothes_m, target_hue=0.90, sat_mult=1.0)
    # Ojos: Magenta vivo
    res1 = clean_hue_shift(res1, eyes_m, target_hue=0.90, sat_mult=1.2)
    out1 = Image.merge("RGBA", (*res1.split(), alpha))
    out1.save(os.path.join(OUTPUT_DIR, "echo_clean_sakura.png"))

    # =========================================================================
    # INTENTO 2: SOLAR GOLD / DIVINE PROTOTYPE (Líneas doradas, pelo oro, piel limpia)
    # =========================================================================
    res2 = clean_hue_shift(base_rgb, hair_m, target_hue=0.12, sat_mult=1.1)
    res2 = clean_hue_shift(res2, clothes_m, target_hue=0.12, sat_mult=1.0)
    res2 = clean_hue_shift(res2, eyes_m, target_hue=0.12, sat_mult=1.2)
    out2 = Image.merge("RGBA", (*res2.split(), alpha))
    out2.save(os.path.join(OUTPUT_DIR, "echo_clean_solar.png"))

    # =========================================================================
    # INTENTO 3: CRIMSON RUBY / COMBAT PROTOCOL (Líneas y pelo carmesí fino)
    # =========================================================================
    res3 = clean_hue_shift(base_rgb, hair_m, target_hue=0.98, sat_mult=1.15)
    res3 = clean_hue_shift(res3, clothes_m, target_hue=0.98, sat_mult=1.0)
    res3 = clean_hue_shift(res3, eyes_m, target_hue=0.98, sat_mult=1.2)
    out3 = Image.merge("RGBA", (*res3.split(), alpha))
    out3.save(os.path.join(OUTPUT_DIR, "echo_clean_crimson.png"))

    # =========================================================================
    # INTENTO 4: EMERALD MATRIX (Verde esmeralda / Jade cuántico)
    # =========================================================================
    res4 = clean_hue_shift(base_rgb, hair_m, target_hue=0.40, sat_mult=1.1)
    res4 = clean_hue_shift(res4, clothes_m, target_hue=0.40, sat_mult=1.0)
    res4 = clean_hue_shift(res4, eyes_m, target_hue=0.40, sat_mult=1.2)
    out4 = Image.merge("RGBA", (*res4.split(), alpha))
    out4.save(os.path.join(OUTPUT_DIR, "echo_clean_emerald.png"))

    # Collage comparativo
    tw, th = 360, 480
    grid = Image.new("RGBA", (tw * 5, th), (16, 18, 24, 255))
    images = [
        ("Base Original", base_img),
        ("Sakura / Magenta", out1),
        ("Solar Gold", out2),
        ("Crimson Ruby", out3),
        ("Emerald Matrix", out4)
    ]
    for i, (title, img) in enumerate(images):
        thumb = img.resize((tw, th), Image.Resampling.LANCZOS)
        grid.paste(thumb, (i * tw, 0), thumb)

    comp_path = os.path.join(OUTPUT_DIR, "echo_clean_comparison.png")
    grid.save(comp_path)
    print(f"Comparativa limpia de Echo generada: {comp_path}")


if __name__ == "__main__":
    test_clean_echo()
