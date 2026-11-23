#!/usr/bin/env python3
"""
tools/test_cielab_nova_showcase.py
Genera una comparativa de Nova en las 7 paletas oficiales de la nueva colección
utilizando la tecnología de arquitectura matemática estricta CIELAB:
  1. Gótica (Gothic Dark / Cuero Burdeos / Pelo Azabache / Ojos Rubí)
  2. Soft Pastel (Pastel Dream / Rosa Bebé / Menta / Pelo Platino Pastel / Ojos Celestiales)
  3. Poison (Tóxica / Verde Ácido Fluorescente / Violeta / Ojos Esmeralda Tóxico)
  4. Solar Valkyrie (Oro Sagrado / Blanco Perlado / Pelo Rubio Cálido / Ojos Ámbar)
  5. Glacial (Hielo Ártico / Cero Absoluto / Pelo Platino Escarcha / Ojos Zafiro)
  6. Cyber Mecha (Retro Arcade / Cian Eléctrico / Magenta Neón / Pelo Frambuesa)
  7. Crimson Blood (Samurai / Rojo Sangre / Obsidiana / Pelo Negro / Ojos Rubí)
"""

import os
import sys
import math
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison", "nova_cielab_showcase")

NOVA_BASE = os.path.join(SELECTION_DIR, "selection_nova.png")
NOVA_MASK = os.path.join(SELECTION_DIR, "selection_nova_mask.png")

PALETTES = {
    "1_gotica": {
        "name": "1. Gótica",
        "suit_lab": (8.0, 1.0),            # Cuero burdeos / obsidiana
        "suit_l_mult": 0.42,
        "suit_chroma": 1.2,
        "plates_lab": (-2.0, -4.0),        # Plata envejecida fría
        "plates_l_mult": 0.85,
        "plates_chroma": 0.4,
        "hair_lab": (-2.0, -8.0),          # Negro azabache / cuervo
        "hair_l_scale": 0.45,
        "hair_spec_thresh": 80.0,
        "eyes_lab": (45.0, 25.0)           # Rubí sangre
    },
    "2_soft_pastel": {
        "name": "2. Soft Pastel",
        "suit_lab": (18.0, 4.0),           # Rosa pastel bebé suave
        "suit_l_mult": 1.15,
        "suit_chroma": 0.75,
        "plates_lab": (-12.0, 6.0),        # Menta suave / crema
        "plates_l_mult": 1.18,
        "plates_chroma": 0.60,
        "hair_lab": (14.0, 8.0),           # Rosa pastel sedoso
        "hair_l_scale": 1.10,
        "hair_spec_thresh": 85.0,
        "eyes_lab": (-15.0, -22.0)         # Celeste cielo pastel
    },
    "3_poison": {
        "name": "3. Poison (Tóxica)",
        "suit_lab": (22.0, -28.0),         # Violeta / ciruela profundo
        "suit_l_mult": 0.50,
        "suit_chroma": 1.3,
        "plates_lab": (-45.0, 38.0),       # Verde ácido fluorescente
        "plates_l_mult": 1.12,
        "plates_chroma": 1.7,
        "hair_lab": (28.0, -32.0),         # Púrpura venenoso
        "hair_l_scale": 0.55,
        "hair_spec_thresh": 82.0,
        "eyes_lab": (-52.0, 44.0)          # Ojos verde ácido tóxico
    },
    "4_solar_valkyrie": {
        "name": "4. Solar Valkyrie",
        "suit_lab": (6.0, 52.0),           # Oro solar cálido
        "suit_l_mult": 1.05,
        "suit_chroma": 1.4,
        "plates_lab": (2.0, 8.0),          # Blanco marfil perlado
        "plates_l_mult": 1.25,
        "plates_chroma": 0.35,
        "hair_lab": (10.0, 40.0),          # Rubio dorado miel
        "hair_l_scale": 1.05,
        "hair_spec_thresh": 85.0,
        "eyes_lab": (8.0, 58.0)            # Ámbar solar puro
    },
    "5_glacial": {
        "name": "5. Glacial",
        "suit_lab": (-18.0, -36.0),        # Azul hielo profundo
        "suit_l_mult": 0.95,
        "suit_chroma": 1.35,
        "plates_lab": (-8.0, -14.0),       # Blanco ártico cero absoluto
        "plates_l_mult": 1.28,
        "plates_chroma": 0.40,
        "hair_lab": (-10.0, -20.0),        # Platino escarcha
        "hair_l_scale": 1.15,
        "hair_spec_thresh": 88.0,
        "eyes_lab": (-22.0, -48.0)         # Zafiro glaciar
    },
    "6_cyber_mecha": {
        "name": "6. Cyber Mecha",
        "suit_lab": (-32.0, -18.0),        # Cian eléctrico arcade
        "suit_l_mult": 1.02,
        "suit_chroma": 1.5,
        "plates_lab": (42.0, -15.0),       # Magenta neón de contraste
        "plates_l_mult": 0.98,
        "plates_chroma": 1.6,
        "hair_lab": (38.0, -10.0),         # Frambuesa mecha suave
        "hair_l_scale": 0.85,
        "hair_spec_thresh": 82.0,
        "eyes_lab": (-35.0, -16.0)         # Turquesa cibernético
    },
    "7_crimson_blood": {
        "name": "7. Crimson Blood",
        "suit_lab": (48.0, 32.0),          # Rojo sangre de combate
        "suit_l_mult": 0.72,
        "suit_chroma": 1.65,
        "plates_lab": (-2.0, 0.0),         # Obsidiana / carbón frío
        "plates_l_mult": 0.45,
        "plates_chroma": 0.20,
        "hair_lab": (-2.0, -8.0),          # Negro azabache samurai
        "hair_l_scale": 0.45,
        "hair_spec_thresh": 80.0,
        "eyes_lab": (52.0, 36.0)           # Rubí sangre penetrante
    }
}

# --- CONVERSIÓN VECTORIAL DETERMINISTA sRGB <-> CIELAB (D65) ---

def srgb_to_linear(v: float) -> float:
    return v / 12.92 if v <= 0.04045 else math.pow((v + 0.055) / 1.055, 2.4)

def linear_to_srgb(v: float) -> float:
    return 12.92 * v if v <= 0.0031308 else 1.055 * math.pow(max(0.0, v), 1.0 / 2.4) - 0.055

def lab_f(t: float) -> float:
    return math.pow(t, 1.0 / 3.0) if t > 0.008856 else (7.787 * t) + (16.0 / 116.0)

def lab_f_inv(t: float) -> float:
    return math.pow(t, 3.0) if t > 0.206893 else (t - 16.0 / 116.0) / 7.787

LUT_SRGB_TO_LIN = [srgb_to_linear(i / 255.0) for i in range(256)]

def rgb_to_lab(r: int, g: int, b: int) -> tuple[float, float, float]:
    r_l = LUT_SRGB_TO_LIN[r]
    g_l = LUT_SRGB_TO_LIN[g]
    b_l = LUT_SRGB_TO_LIN[b]

    X = r_l * 0.4124564 + g_l * 0.3575761 + b_l * 0.1804375
    Y = r_l * 0.2126729 + g_l * 0.7151522 + b_l * 0.0721750
    Z = r_l * 0.0193339 + g_l * 0.1191920 + b_l * 0.9503041

    fx = lab_f(X / 0.95047)
    fy = lab_f(Y / 1.00000)
    fz = lab_f(Z / 1.08883)

    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b_val = 200.0 * (fy - fz)
    return L, a, b_val

def lab_to_rgb(L: float, a: float, b_val: float) -> tuple[int, int, int]:
    fy = (L + 16.0) / 116.0
    fx = (a / 500.0) + fy
    fz = fy - (b_val / 200.0)

    X = 0.95047 * lab_f_inv(fx)
    Y = 1.00000 * lab_f_inv(fy)
    Z = 1.08883 * lab_f_inv(fz)

    r_l = X *  3.2404542 + Y * -1.5371385 + Z * -0.4985314
    g_l = X * -0.9692660 + Y *  1.8760108 + Z *  0.0415560
    b_l = X *  0.0556434 + Y * -0.2040259 + Z *  1.0572252

    r = int(max(0.0, min(1.0, linear_to_srgb(r_l))) * 255.0 + 0.5)
    g = int(max(0.0, min(1.0, linear_to_srgb(g_l))) * 255.0 + 0.5)
    b = int(max(0.0, min(1.0, linear_to_srgb(b_l))) * 255.0 + 0.5)
    return r, g, b

def preprocess_mask_continuous(mask_channel: Image.Image, erode_radius: int = 1, blur_radius: float = 1.2) -> Image.Image:
    m = mask_channel.copy()
    if erode_radius > 0:
        m = m.filter(ImageFilter.MinFilter(3))
    if blur_radius > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur_radius))
    smoothstep_lut = [int(( (i / 255.0) ** 2 * (3.0 - 2.0 * (i / 255.0)) ) * 255.0 + 0.5) for i in range(256)]
    return m.point(smoothstep_lut)

def recolor_hair_cielab(base_rgb: Image.Image, hair_mask: Image.Image, p_data: dict) -> Image.Image:
    res = base_rgb.copy()
    w, h = base_rgb.size
    pix_in = base_rgb.load()
    pix_out = res.load()
    mask_pix = hair_mask.load()

    target_a, target_b = p_data["hair_lab"]
    l_scale = p_data["hair_l_scale"]
    spec_thresh = p_data["hair_spec_thresh"]
    softness = 12.0

    for y in range(h):
        for x in range(w):
            m_val = mask_pix[x, y]
            if m_val < 5:
                continue

            r, g, b = pix_in[x, y]
            L, a, b_val = rgb_to_lab(r, g, b)

            low_b = spec_thresh - softness
            high_b = spec_thresh + softness
            spec_norm = max(0.0, min(1.0, (L - low_b) / (high_b - low_b + 1e-5)))
            spec_factor = spec_norm * spec_norm * (3.0 - 2.0 * spec_norm)
            tint_weight = 1.0 - spec_factor

            alpha = (m_val / 255.0) * tint_weight
            new_L = L * (1.0 - alpha + alpha * l_scale)
            new_a = a * (1.0 - alpha) + target_a * alpha
            new_b = b_val * (1.0 - alpha) + target_b * alpha

            nr, ng, nb = lab_to_rgb(new_L, new_a, new_b)
            pix_out[x, y] = (nr, ng, nb)

    return res

def recolor_zone_cielab(canvas: Image.Image, mask: Image.Image, target_lab: tuple[float, float], l_mult: float, chroma: float) -> Image.Image:
    res = canvas.copy()
    w, h = canvas.size
    pix_in = canvas.load()
    pix_out = res.load()
    mask_pix = mask.load()

    target_a, target_b = target_lab

    for y in range(h):
        for x in range(w):
            m_val = mask_pix[x, y]
            if m_val < 5:
                continue

            alpha = m_val / 255.0
            r, g, b = pix_in[x, y]
            L, a, b_val = rgb_to_lab(r, g, b)

            new_L = max(0.0, min(100.0, L * (1.0 - alpha + alpha * l_mult)))
            new_a = a * (1.0 - alpha) + (target_a * chroma) * alpha
            new_b = b_val * (1.0 - alpha) + (target_b * chroma) * alpha

            nr, ng, nb = lab_to_rgb(new_L, new_a, new_b)
            pix_out[x, y] = (nr, ng, nb)

    return res

def run_nova_showcase():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    base_img = Image.open(NOVA_BASE).convert("RGBA")
    mask_img = Image.open(NOVA_MASK).convert("RGBA")

    rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]

    mr, mg, mb, ma = mask_img.split()
    raw_clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    raw_hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    raw_eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    # Descomponer ropa de Nova en Mono vs Placas de Blindaje de alto contraste
    hsv = rgb.convert("HSV")
    h, s, v = hsv.split()
    lut_desat = [255 if x < 75 else 0 for x in range(256)]
    lut_bright = [255 if x >= 140 else 0 for x in range(256)]
    raw_plates = ImageChops.multiply(s.point(lut_desat), v.point(lut_bright))
    raw_plates = ImageChops.multiply(raw_plates, raw_clothes)
    raw_suit = ImageChops.subtract(raw_clothes, raw_plates)

    # Máscaras preprocesadas con morfología continua
    m_suit = preprocess_mask_continuous(ImageChops.multiply(raw_suit, ma), 1, 1.2)
    m_plates = preprocess_mask_continuous(ImageChops.multiply(raw_plates, ma), 1, 1.2)
    m_hair = preprocess_mask_continuous(ImageChops.multiply(raw_hair, ma), 1, 1.2)
    m_eyes = preprocess_mask_continuous(ImageChops.multiply(raw_eyes, ma), 0, 0.5)

    th_w, th_h = 320, 426
    # 8 columnas: Original + 7 Paletas
    grid = Image.new("RGBA", (th_w * 8, th_h), (16, 16, 20, 255))

    th_orig = base_img.resize((th_w, th_h), Image.Resampling.LANCZOS)
    grid.paste(th_orig, (0, 0), th_orig)

    for idx, (p_key, p_data) in enumerate(PALETTES.items()):
        print(f"Renderizando Nova en {p_data['name']}...")
        # 1. Cabello con preservación dieléctrica
        canvas = recolor_hair_cielab(rgb, m_hair, p_data)

        # 2. Placas de blindaje
        canvas = recolor_zone_cielab(canvas, m_plates, p_data["plates_lab"], p_data["plates_l_mult"], p_data["plates_chroma"])

        # 3. Mono del traje
        canvas = recolor_zone_cielab(canvas, m_suit, p_data["suit_lab"], p_data["suit_l_mult"], p_data["suit_chroma"])

        # 4. Ojos
        canvas = recolor_zone_cielab(canvas, m_eyes, p_data["eyes_lab"], 1.1, 1.8)

        final_rgba = Image.merge("RGBA", (*canvas.split(), alpha))
        out_single = os.path.join(OUTPUT_DIR, f"nova_{p_key}.png")
        final_rgba.save(out_single)

        th = final_rgba.resize((th_w, th_h), Image.Resampling.LANCZOS)
        grid.paste(th, ((idx + 1) * th_w, 0), th)

    master_path = os.path.join(OUTPUT_DIR, "nova_7_palettes_cielab_showcase.png")
    grid.save(master_path)
    print(f"\n¡Showcase de Nova generado con éxito!: {master_path}")

if __name__ == "__main__":
    run_nova_showcase()
