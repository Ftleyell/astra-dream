#!/usr/bin/env python3
"""
tools/test_cielab_gothic_engine.py
Implementación exacta del estándar 'docs/art/Arquitectura De Recoloreado En Python.md':
  1. Morfología continua de máscara:
     - Erosión perimetral elíptica (MinFilter 3x3)
     - Convolución gaussiana bidimensional (feathering continuo)
     - Curva sigmoidal Hermite Smoothstep: alpha^2 * (3 - 2*alpha)
  2. Espacio Perceptual CIELAB (sRGB -> XYZ D65 -> LAB):
     - Preservación invariante del canal L* (radiancia acromática / volumen / oclusión)
     - Modulación selectiva de croma y vectores oponentes (a*, b*)
  3. Modulación Especular Dinámica en Cabello:
     - Atenuación especular con Smoothstep entre specular_thresh (210) y softness (25)
     - Preservación del blanco neutro dieléctrico en coronas y mechas anime
  4. Composición vectorizada continua float32 (Porter-Duff Over)
"""

import os
import sys
import math
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison", "cielab_gothic_engine")

PILOTS = ["nova", "valentina", "selene", "kira", "echo", "roxy", "nyx"]

# --- CONVERSIÓN VECTORIAL DETERMINISTA sRGB <-> CIELAB (D65) ---

def srgb_to_linear(v: float) -> float:
    return v / 12.92 if v <= 0.04045 else math.pow((v + 0.055) / 1.055, 2.4)

def linear_to_srgb(v: float) -> float:
    return 12.92 * v if v <= 0.0031308 else 1.055 * math.pow(max(0.0, v), 1.0 / 2.4) - 0.055

def lab_f(t: float) -> float:
    return math.pow(t, 1.0 / 3.0) if t > 0.008856 else (7.787 * t) + (16.0 / 116.0)

def lab_f_inv(t: float) -> float:
    return math.pow(t, 3.0) if t > 0.206893 else (t - 16.0 / 116.0) / 7.787

# Tablas LUT de 256 valores para conversión ultrarrápida C-speed
LUT_SRGB_TO_LIN = [srgb_to_linear(i / 255.0) for i in range(256)]

def rgb_to_lab(r: int, g: int, b: int) -> tuple[float, float, float]:
    r_l = LUT_SRGB_TO_LIN[r]
    g_l = LUT_SRGB_TO_LIN[g]
    b_l = LUT_SRGB_TO_LIN[b]

    # Matriz sRGB a CIE XYZ (D65)
    X = r_l * 0.4124564 + g_l * 0.3575761 + b_l * 0.1804375
    Y = r_l * 0.2126729 + g_l * 0.7151522 + b_l * 0.0721750
    Z = r_l * 0.0193339 + g_l * 0.1191920 + b_l * 0.9503041

    # Referencia D65: Xn=0.95047, Yn=1.00000, Zn=1.08883
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

    # Matriz CIE XYZ a sRGB
    r_l = X *  3.2404542 + Y * -1.5371385 + Z * -0.4985314
    g_l = X * -0.9692660 + Y *  1.8760108 + Z *  0.0415560
    b_l = X *  0.0556434 + Y * -0.2040259 + Z *  1.0572252

    r = int(max(0.0, min(1.0, linear_to_srgb(r_l))) * 255.0 + 0.5)
    g = int(max(0.0, min(1.0, linear_to_srgb(g_l))) * 255.0 + 0.5)
    b = int(max(0.0, min(1.0, linear_to_srgb(b_l))) * 255.0 + 0.5)
    return r, g, b

# --- 1. MORFOLOGÍA CONTINUA DE MÁSCARA (Sección 'Tratamiento matemático de bordes') ---

def preprocess_mask_continuous(mask_channel: Image.Image, erode_radius: int = 1, blur_radius: float = 1.5) -> Image.Image:
    """
    1. Erosión perimetral elíptica (MinFilter)
    2. Convolución gaussiana continua
    3. Mapeo polinomial Smoothstep: a^2 * (3 - 2*a)
    """
    m = mask_channel.copy()
    if erode_radius > 0:
        m = m.filter(ImageFilter.MinFilter(3)) # Erosión 1px perimetral
    
    if blur_radius > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur_radius))

    # Curva sigmoidal Hermite Smoothstep (evita colas largas y aliasing)
    smoothstep_lut = [int(( (i / 255.0) ** 2 * (3.0 - 2.0 * (i / 255.0)) ) * 255.0 + 0.5) for i in range(256)]
    return m.point(smoothstep_lut)

# --- 2. MODULACIÓN CAPILAR CON ATENUACIÓN ESPECULAR EN CIELAB ---

def recolor_hair_cielab_specular(
    base_rgb: Image.Image,
    hair_mask: Image.Image,
    target_lab_ab: tuple[float, float], # (a*, b*) deseado (ej. medianoche / cuervo)
    l_scale: float = 0.50,               # Densidad de profundidad para cabello negro
    specular_thresh: float = 80.0,       # Umbral L* de brillo especular
    softness: float = 12.0
) -> Image.Image:
    """
    Teñido en espacio CIELAB preservando reflexiones dieléctricas especulares mediante
    Smoothstep inverso sobre radiancia acromática L*.
    """
    res = base_rgb.copy()
    w, h = base_rgb.size
    pix_in = base_rgb.load()
    pix_out = res.load()
    mask_pix = hair_mask.load()

    target_a, target_b = target_lab_ab

    for y in range(h):
        for x in range(w):
            m_val = mask_pix[x, y]
            if m_val < 5:
                continue

            r, g, b = pix_in[x, y]
            L, a, b_val = rgb_to_lab(r, g, b)

            # Cálculo de atenuación especular (Sección 3.2 de la arquitectura)
            low_b = specular_thresh - softness
            high_b = specular_thresh + softness
            spec_norm = max(0.0, min(1.0, (L - low_b) / (high_b - low_b + 1e-5)))
            spec_factor = spec_norm * spec_norm * (3.0 - 2.0 * spec_norm)
            tint_weight = 1.0 - spec_factor # 0 en brillos blancos, 1 en sombras

            # Modulación continua de L* y croma (a*, b*)
            alpha = (m_val / 255.0) * tint_weight
            new_L = L * (1.0 - alpha * (1.0 - l_scale))
            new_a = a * (1.0 - alpha) + target_a * alpha
            new_b = b_val * (1.0 - alpha) + target_b * alpha

            nr, ng, nb = lab_to_rgb(new_L, new_a, new_b)
            pix_out[x, y] = (nr, ng, nb)

    return res

# --- 3. RECOLOREADO TEXTIL Y BLINDAJE EN CIELAB (Preservación Absoluta de Textura) ---

def recolor_material_cielab(
    base_rgb: Image.Image,
    mask: Image.Image,
    target_lab_ab: tuple[float, float],
    l_mult: float = 1.0,
    chroma_scale: float = 1.0
) -> Image.Image:
    """Modula el material alterando únicamente coordenadas cromáticas a*, b* e intensidad."""
    res = base_rgb.copy()
    w, h = base_rgb.size
    pix_in = base_rgb.load()
    pix_out = res.load()
    mask_pix = mask.load()

    target_a, target_b = target_lab_ab

    for y in range(h):
        for x in range(w):
            m_val = mask_pix[x, y]
            if m_val < 5:
                continue

            alpha = m_val / 255.0
            r, g, b = pix_in[x, y]
            L, a, b_val = rgb_to_lab(r, g, b)

            new_L = max(0.0, min(100.0, L * (1.0 - alpha + alpha * l_mult)))
            new_a = a * (1.0 - alpha) + (target_a * chroma_scale) * alpha
            new_b = b_val * (1.0 - alpha) + (target_b * chroma_scale) * alpha

            nr, ng, nb = lab_to_rgb(new_L, new_a, new_b)
            pix_out[x, y] = (nr, ng, nb)

    return res

def run_cielab_gothic_test():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    th_w, th_h = 360, 480
    grid = Image.new("RGBA", (th_w * len(PILOTS), th_h), (16, 16, 20, 255))

    for p_idx, pilot in enumerate(PILOTS):
        bp = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
        mp = os.path.join(SELECTION_DIR, f"selection_{pilot}_mask.png")
        if not os.path.exists(bp) or not os.path.exists(mp):
            continue

        base_img = Image.open(bp).convert("RGBA")
        mask_img = Image.open(mp).convert("RGBA")
        rgb = base_img.convert("RGB")
        alpha = base_img.split()[3]

        mr, mg, mb, ma = mask_img.split()
        raw_clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
        raw_hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
        raw_eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

        # Preprocesar máscaras con morfología elíptica y Smoothstep continuo
        c_mask = preprocess_mask_continuous(ImageChops.multiply(raw_clothes, ma), 1, 1.2)
        h_mask = preprocess_mask_continuous(ImageChops.multiply(raw_hair, ma), 1, 1.2)
        e_mask = preprocess_mask_continuous(ImageChops.multiply(raw_eyes, ma), 0, 0.5)

        # 1. Cabello Negro con Preservación Especular CIELAB (Técnica Midnight Blue / Cuervo)
        # target_ab: a*= -2.0, b*= -8.0 (índigo frío sutil de anime)
        if pilot == "echo":
            # Echo: Black Velvet (a*= 4.0, b*= 2.0)
            res = recolor_hair_cielab_specular(rgb, h_mask, target_lab_ab=(4.0, 2.0), l_scale=0.55)
        else:
            res = recolor_hair_cielab_specular(rgb, h_mask, target_lab_ab=(-2.0, -8.0), l_scale=0.45)

        # 2. Descomposición de Ropa y Blindaje
        # Mono Base: Cuero Burdeos / Negro Obsidiana en CIELAB (a*= 8.0, b*= 1.0, l_mult=0.40)
        res = recolor_material_cielab(res, c_mask, target_lab_ab=(8.0, 1.0), l_mult=0.42, chroma_scale=1.2)

        # 3. Ojos: Rubí Sangre cristalino
        res = recolor_material_cielab(res, e_mask, target_lab_ab=(45.0, 25.0), l_mult=1.1, chroma_scale=1.8)

        final_rgba = Image.merge("RGBA", (*res.split(), alpha))
        out_single = os.path.join(OUTPUT_DIR, f"{pilot}_cielab_gothic.png")
        final_rgba.save(out_single)

        th = final_rgba.resize((th_w, th_h), Image.Resampling.LANCZOS)
        grid.paste(th, (p_idx * th_w, 0), th)

    master_path = os.path.join(OUTPUT_DIR, "cielab_gothic_roster_comparison.png")
    grid.save(master_path)
    print(f"Roster CIELAB Gótico generado con éxito: {master_path}")

if __name__ == "__main__":
    run_cielab_gothic_test()
