#!/usr/bin/env python3
"""
tools/generate_all_production_skins.py
=============================================================================
PIPELINE MAESTRO DE PRODUCCIÓN DE SKINS — ASTRA DREAM
Arquitectura Matemática CIELAB + Morfología Continua + Smart Multi-Material
=============================================================================
Genera y sincroniza la nueva colección base de 7 paletas oficiales para:
  1. SELECTION (7 Pilotos x 7 Paletas + Flipped)
  2. PORTRAITS (Derivación matemática 1080x1080 pegada al borde + Flipped)
  3. FULLBODY (7 Pilotos x Front/Back x 7 Paletas + Flipped)
  4. SHIPS (7 Exotrajes de combate x 7 Paletas)
  5. WEAPONS (7 Armas de pilotos 256x256 y 1024x1024 HD x 7 Paletas)
Actualiza automáticamente la base de datos de cosméticos (JSONs modulares).
"""

import os
import sys
import json
import math
import shutil
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
CHARACTERS_DIR = os.path.join(ASSETS_DIR, "characters")
RECOLORS_DIR = os.path.join(ASSETS_DIR, "recolors")
DATA_DIR = os.path.join(BASE_DIR, "data", "cosmetics")
CATEGORIES_DIR = os.path.join(DATA_DIR, "categories")

SELECTION_DIR = os.path.join(CHARACTERS_DIR, "selection")
FULLBODY_DIR = os.path.join(CHARACTERS_DIR, "fullbody")
SHIPS_DIR = os.path.join(CHARACTERS_DIR, "ships")
WEAPONS_DIR = os.path.join(CHARACTERS_DIR, "weapons")
PORTRAITS_CHAR_DIR = os.path.join(CHARACTERS_DIR, "portraits")
PORTRAITS_ROOT_DIR = os.path.join(ASSETS_DIR, "portraits")

RECOLORS_PILOTS_DIR = os.path.join(RECOLORS_DIR, "pilots")
RECOLORS_SHIPS_DIR = os.path.join(RECOLORS_DIR, "ships")
RECOLORS_WEAPONS_DIR = os.path.join(RECOLORS_DIR, "weapons")

PILOTS = ["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"]
RAW_FACES_RIGHT = {"valentina"}

# =============================================================================
# DEFINICIÓN OFICIAL DE LAS 7 PALETAS DE LA COLECCIÓN
# =============================================================================
PALETTES = {
    "gotica": {
        "id": "gotica",
        "name": "Gótica",
        "description": "Estética oscura victoriana con cuero burdeos, plata fría y destellos rubí.",
        "rarity": "epic",
        "glow_hex": "#9B51E0",
        "accent_hex": "#FF3366",
        "tint_rgb": [65, 30, 50],
        "secondary_rgb": [160, 165, 175],
        # CIELAB
        "suit_lab": (8.0, 1.0),
        "suit_l_mult": 0.42,
        "suit_chroma": 1.2,
        "plates_lab": (-2.0, -4.0),
        "plates_l_mult": 0.85,
        "plates_chroma": 0.4,
        "hair_lab": (-2.0, -8.0),       # Cuervo / Midnight Blue
        "hair_l_scale": 0.45,
        "hair_spec_thresh": 80.0,
        "eyes_lab": (45.0, 25.0),
        # Weapon smart tinting
        "weapon_plates": (38, 30, 42),
        "weapon_chassis": (18, 18, 22),
        "weapon_energy": (255, 35, 75)
    },
    "soft_pastel": {
        "id": "soft_pastel",
        "name": "Pastel Dream",
        "description": "Armadura en rosa pastel suave, paneles menta y reflejos celestiales.",
        "rarity": "rare",
        "glow_hex": "#FFB6C1",
        "accent_hex": "#7FFFD4",
        "tint_rgb": [245, 180, 200],
        "secondary_rgb": [180, 235, 220],
        # CIELAB
        "suit_lab": (18.0, 4.0),
        "suit_l_mult": 1.15,
        "suit_chroma": 0.75,
        "plates_lab": (-12.0, 6.0),
        "plates_l_mult": 1.18,
        "plates_chroma": 0.60,
        "hair_lab": (14.0, 8.0),
        "hair_l_scale": 1.10,
        "hair_spec_thresh": 85.0,
        "eyes_lab": (-15.0, -22.0),
        # Weapon smart tinting
        "weapon_plates": (245, 195, 210),
        "weapon_chassis": (60, 70, 85),
        "weapon_energy": (120, 240, 255)
    },
    "poison": {
        "id": "poison",
        "name": "Tóxica (Poison)",
        "description": "Bio-blindaje violeta ciruela con paneles de advertencia en verde ácido fluorescente.",
        "rarity": "rare",
        "glow_hex": "#39FF14",
        "accent_hex": "#BF00FF",
        "tint_rgb": [130, 40, 160],
        "secondary_rgb": [57, 255, 20],
        # CIELAB
        "suit_lab": (22.0, -28.0),
        "suit_l_mult": 0.50,
        "suit_chroma": 1.3,
        "plates_lab": (-45.0, 38.0),
        "plates_l_mult": 1.12,
        "plates_chroma": 1.7,
        "hair_lab": (28.0, -32.0),
        "hair_l_scale": 0.55,
        "hair_spec_thresh": 82.0,
        "eyes_lab": (-52.0, 44.0),
        # Weapon smart tinting
        "weapon_plates": (45, 22, 55),
        "weapon_chassis": (20, 25, 22),
        "weapon_energy": (65, 255, 30)
    },
    "solar_valkyrie": {
        "id": "solar_valkyrie",
        "name": "Valquiria Solar",
        "description": "Blindaje en oro solar templado, titanio perlado blanco y sensores ámbar sagrado.",
        "rarity": "legendary",
        "glow_hex": "#FFD700",
        "accent_hex": "#FFF8DC",
        "tint_rgb": [255, 200, 40],
        "secondary_rgb": [245, 245, 250],
        # CIELAB
        "suit_lab": (6.0, 52.0),
        "suit_l_mult": 1.05,
        "suit_chroma": 1.4,
        "plates_lab": (2.0, 8.0),
        "plates_l_mult": 1.25,
        "plates_chroma": 0.35,
        "hair_lab": (10.0, 40.0),
        "hair_l_scale": 1.05,
        "hair_spec_thresh": 85.0,
        "eyes_lab": (8.0, 58.0),
        # Weapon smart tinting
        "weapon_plates": (255, 195, 35),
        "weapon_chassis": (85, 95, 110),
        "weapon_energy": (255, 240, 110)
    },
    "glacial": {
        "id": "glacial",
        "name": "Glaciar Ártico",
        "description": "Cero absoluto en azul glaciar profundo con placas de escarcha perlada y zafiro.",
        "rarity": "common",
        "glow_hex": "#00E5FF",
        "accent_hex": "#E0F7FA",
        "tint_rgb": [40, 140, 200],
        "secondary_rgb": [210, 240, 255],
        # CIELAB
        "suit_lab": (-18.0, -36.0),
        "suit_l_mult": 0.95,
        "suit_chroma": 1.35,
        "plates_lab": (-8.0, -14.0),
        "plates_l_mult": 1.28,
        "plates_chroma": 0.40,
        "hair_lab": (-10.0, -20.0),
        "hair_l_scale": 1.15,
        "hair_spec_thresh": 88.0,
        "eyes_lab": (-22.0, -48.0),
        # Weapon smart tinting
        "weapon_plates": (35, 120, 185),
        "weapon_chassis": (30, 40, 52),
        "weapon_energy": (140, 245, 255)
    },
    "cyber_mecha": {
        "id": "cyber_mecha",
        "name": "Ciber Mecha",
        "description": "Estética arcade táctica con cian eléctrico, contrastes magenta y circuitos neón.",
        "rarity": "rare",
        "glow_hex": "#00F0FF",
        "accent_hex": "#FF007F",
        "tint_rgb": [0, 225, 255],
        "secondary_rgb": [255, 20, 147],
        # CIELAB
        "suit_lab": (-32.0, -18.0),
        "suit_l_mult": 1.02,
        "suit_chroma": 1.5,
        "plates_lab": (42.0, -15.0),
        "plates_l_mult": 0.98,
        "plates_chroma": 1.6,
        "hair_lab": (38.0, -10.0),
        "hair_l_scale": 0.85,
        "hair_spec_thresh": 82.0,
        "eyes_lab": (-35.0, -16.0),
        # Weapon smart tinting
        "weapon_plates": (0, 215, 245),
        "weapon_chassis": (28, 34, 46),
        "weapon_energy": (255, 30, 140)
    },
    "crimson_blood": {
        "id": "crimson_blood",
        "name": "Sangre Carmesí",
        "description": "Blindaje de combate samurái en rojo sangre coagulada, placas de obsidiana y rubí puro.",
        "rarity": "rare",
        "glow_hex": "#FF1744",
        "accent_hex": "#B71C1C",
        "tint_rgb": [220, 25, 50],
        "secondary_rgb": [25, 25, 30],
        # CIELAB
        "suit_lab": (48.0, 32.0),
        "suit_l_mult": 0.72,
        "suit_chroma": 1.65,
        "plates_lab": (-2.0, 0.0),
        "plates_l_mult": 0.45,
        "plates_chroma": 0.20,
        "hair_lab": (-2.0, -8.0),
        "hair_l_scale": 0.45,
        "hair_spec_thresh": 80.0,
        "eyes_lab": (52.0, 36.0),
        # Weapon smart tinting
        "weapon_plates": (210, 28, 48),
        "weapon_chassis": (20, 20, 24),
        "weapon_energy": (0, 240, 255)
    }
}

# =============================================================================
# CONVERSIÓN VECTORIAL DETERMINISTA sRGB <-> CIELAB (D65)
# =============================================================================
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

# =============================================================================
# MORFOLOGÍA CONTINUA Y RECOLOREADO CIELAB
# =============================================================================
SMOOTHSTEP_LUT = [int(((i / 255.0) ** 2 * (3.0 - 2.0 * (i / 255.0))) * 255.0 + 0.5) for i in range(256)]

def preprocess_mask_continuous(mask_channel: Image.Image, erode_radius: int = 1, blur_radius: float = 1.2) -> Image.Image:
    m = mask_channel.copy()
    if erode_radius > 0:
        m = m.filter(ImageFilter.MinFilter(3))
    if blur_radius > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur_radius))
    return m.point(SMOOTHSTEP_LUT)

def recolor_hair_cielab(base_rgb: Image.Image, hair_mask: Image.Image, p_data: dict, is_echo: bool = False) -> Image.Image:
    res = base_rgb.copy()
    w, h = base_rgb.size
    pix_in = base_rgb.load()
    pix_out = res.load()
    mask_pix = hair_mask.load()

    target_a, target_b = p_data["hair_lab"]
    l_scale = p_data["hair_l_scale"]
    spec_thresh = p_data["hair_spec_thresh"]

    # Adaptación para técnica 5 de Echo en Gótica si aplica
    if is_echo and p_data["id"] == "gotica":
        target_a, target_b = (4.0, 2.0)
        l_scale = 0.55

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

# =============================================================================
# RECOLOR DE ARMAS (SMART MULTI-MATERIAL ZERO-MASK)
# =============================================================================
def decompose_weapon_materials(img: Image.Image):
    img_rgba = img.convert("RGBA")
    r, g, b, alpha = img_rgba.split()
    gray = ImageOps.grayscale(img)

    lut_plates = [255 if x >= 170 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(gray.point(lut_plates), alpha)

    lut_dark = [255 if x <= 75 else 0 for x in range(256)]
    m_recesses = ImageChops.multiply(gray.point(lut_dark), alpha)

    lut_chassis = [255 if 75 < x < 170 else 0 for x in range(256)]
    m_chassis = ImageChops.multiply(gray.point(lut_chassis), alpha)

    w, h = img.size
    lens_mask_region = Image.new("L", (w, h), 0)
    for y in range(int(h * 0.40), int(h * 0.60)):
        for x in range(int(w * 0.45), int(w * 0.58)):
            lens_mask_region.putpixel((x, y), 255)

    lut_lens = [255 if 85 <= x <= 145 else 0 for x in range(256)]
    lens_c = ImageChops.multiply(gray.point(lut_lens), alpha)
    m_energy = ImageChops.multiply(lens_c, lens_mask_region)

    m_plates = m_plates.filter(ImageFilter.GaussianBlur(0.8))
    m_chassis = m_chassis.filter(ImageFilter.GaussianBlur(0.8))
    m_recesses = m_recesses.filter(ImageFilter.GaussianBlur(0.5))
    m_energy = m_energy.filter(ImageFilter.GaussianBlur(1.0))

    return m_plates, m_chassis, m_recesses, m_energy

def generate_smart_weapon(
    base_img: Image.Image,
    plates_tint: tuple[int, int, int],
    chassis_tint: tuple[int, int, int],
    energy_color: tuple[int, int, int]
) -> Image.Image:
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)

    m_plates, m_chassis, m_recesses, m_energy = decompose_weapon_materials(base_img)

    result = base_rgb.copy()

    # Chasis estructural
    chassis_colored = ImageOps.colorize(
        gray,
        black=(10, 12, 16),
        mid=chassis_tint,
        white=(180, 190, 205)
    )
    result = Image.composite(chassis_colored, result, m_chassis)

    # Paneles modulares
    plates_colored = ImageOps.colorize(
        gray,
        black=(int(plates_tint[0] * 0.25), int(plates_tint[1] * 0.25), int(plates_tint[2] * 0.25)),
        mid=plates_tint,
        white=(255, 255, 255)
    )
    plates_blended = Image.blend(base_rgb, plates_colored, 0.88)
    result = Image.composite(plates_blended, result, m_plates)

    # Ranuras y pernos
    recesses_colored = ImageOps.colorize(
        gray,
        black=(5, 6, 8),
        mid=(20, 22, 28),
        white=(75, 80, 90)
    )
    result = Image.composite(recesses_colored, result, m_recesses)

    # Inyección de energía en sensor
    if m_energy.getbbox():
        energy_solid = Image.new("RGB", base_rgb.size, energy_color)
        energy_core = Image.composite(energy_solid, Image.new("RGB", base_rgb.size, (0, 0, 0)), m_energy)
        energy_glow = energy_core.filter(ImageFilter.GaussianBlur(4.0))
        result = Image.composite(energy_solid, result, m_energy)
        result = ImageChops.screen(result, energy_glow)

    return Image.merge("RGBA", (*result.split(), alpha))

# =============================================================================
# DERIVACIÓN MATEMÁTICA DE PORTRAITS (1080x1080)
# =============================================================================
def derive_portrait_from_selection(sel_rgba: Image.Image, pilot: str) -> tuple[Image.Image, Image.Image]:
    """
    Encuadra 1080x1080 pegado a la espalda del personaje.
    Retorna (portrait_left_facing_right, portrait_right_facing_left).
    """
    if pilot in RAW_FACES_RIGHT:
        facing_right = sel_rgba
    else:
        facing_right = ImageOps.mirror(sel_rgba)

    w, h = facing_right.size
    S = 1080
    top_slice = facing_right.crop((0, 0, w, min(h, S)))
    alpha = top_slice.split()[-1]
    bbox = alpha.getbbox()
    x_back = bbox[0] if bbox else 0

    portrait_left = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    portrait_left.paste(facing_right, (-x_back, 0))
    portrait_right = ImageOps.mirror(portrait_left)
    return portrait_left, portrait_right

# =============================================================================
# GENERACIÓN PRINCIPAL
# =============================================================================
def generate_all():
    os.makedirs(RECOLORS_PILOTS_DIR, exist_ok=True)
    os.makedirs(RECOLORS_SHIPS_DIR, exist_ok=True)
    os.makedirs(RECOLORS_WEAPONS_DIR, exist_ok=True)

    print("==================================================================")
    print("[*] INICIANDO GENERACION MAESTRA DE SKINS CIELAB PARA 7 PILOTOS")
    print("==================================================================")

    total_tasks = len(PILOTS) * len(PALETTES)
    current_task = 0

    for pilot in PILOTS:
        cap = pilot.capitalize()
        is_echo = (pilot == "echo")

        # 1. Cargar bases y máscaras
        sel_path = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
        # Si existe versión JPG actualizada para selection (como Nova y Valentina), usarla prioritariamente
        sel_mask_jpg = os.path.join(SELECTION_DIR, f"selection_{pilot}_mask.jpg")
        if os.path.exists(sel_mask_jpg):
            sel_mask_path = sel_mask_jpg
        else:
            sel_mask_path = os.path.join(SELECTION_DIR, f"selection_{pilot}_mask.png")

        fb_path = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}.png")
        fbb_path = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}_back.png")
        fb_mask_path = os.path.join(FULLBODY_DIR, f"{cap}_skin_mask.jpg")
        fbb_mask_path = os.path.join(FULLBODY_DIR, f"{cap}Back_skin_mask.jpg")
        sh_path = os.path.join(SHIPS_DIR, f"ship_{pilot}.png")
        # Máscaras de skins para naves (Echo_skin_mask.jpg, etc.) en lugar de las procedurales de animación
        sh_skin_mask_path = os.path.join(SHIPS_DIR, f"{cap}_skin_mask.jpg")
        if os.path.exists(sh_skin_mask_path):
            sh_mask_path = sh_skin_mask_path
        else:
            sh_mask_path = os.path.join(SHIPS_DIR, f"ship_{pilot}_mask.png")

        w_path = os.path.join(WEAPONS_DIR, f"weapon_{pilot}.png")
        w_hd_path = os.path.join(WEAPONS_DIR, f"weapon_{pilot}_hd.png")

        sel_img = Image.open(sel_path).convert("RGBA")
        sel_mask_img = Image.open(sel_mask_path).convert("RGB").resize(sel_img.size, Image.Resampling.LANCZOS)
        fb_img = Image.open(fb_path).convert("RGBA")
        fbb_img = Image.open(fbb_path).convert("RGBA")
        sh_img = Image.open(sh_path).convert("RGBA")
        sh_mask_img = Image.open(sh_mask_path).convert("RGB").resize(sh_img.size, Image.Resampling.LANCZOS)
        w_img = Image.open(w_path).convert("RGBA")
        w_hd_img = Image.open(w_hd_path).convert("RGBA")

        # Máscaras fullbody adaptadas con Lanczos al tamaño base (1200x1600)
        fb_mask_raw = Image.open(fb_mask_path).convert("RGB").resize(fb_img.size, Image.Resampling.LANCZOS)
        fbb_mask_raw = Image.open(fbb_mask_path).convert("RGB").resize(fbb_img.size, Image.Resampling.LANCZOS)

        # Canal alfa de cada base
        sel_alpha = sel_img.split()[3]
        fb_alpha = fb_img.split()[3]
        fbb_alpha = fbb_img.split()[3]
        sh_alpha = sh_img.split()[3]

        # LUT para limpiar ruido JPG
        lut_clean = [0 if x < 25 else x for x in range(256)]

        # Descomposición de canales de Selection
        sm_r, sm_g, sm_b = sel_mask_img.split()
        sm_clean_r = sm_r.point(lut_clean)
        sm_clean_g = sm_g.point(lut_clean)
        sm_clean_b = sm_b.point(lut_clean)
        s_raw_c = ImageChops.subtract(sm_clean_r, ImageChops.add(sm_clean_g, sm_clean_b))
        s_raw_h = ImageChops.subtract(sm_clean_g, ImageChops.add(sm_clean_r, sm_clean_b))
        s_raw_e = ImageChops.subtract(sm_clean_b, ImageChops.add(sm_clean_r, sm_clean_g))

        # Descomponer placas claras de la ropa en selection
        s_hsv = sel_img.convert("RGB").convert("HSV")
        s_h, s_s, s_v = s_hsv.split()
        lut_desat = [255 if x < 80 else 0 for x in range(256)]
        lut_bright = [255 if x >= 135 else 0 for x in range(256)]
        s_raw_plates = ImageChops.multiply(s_s.point(lut_desat), s_v.point(lut_bright))
        s_raw_plates = ImageChops.multiply(s_raw_plates, s_raw_c)
        s_raw_suit = ImageChops.subtract(s_raw_c, s_raw_plates)

        s_m_suit = preprocess_mask_continuous(ImageChops.multiply(s_raw_suit, sel_alpha), 1, 1.2)
        s_m_plates = preprocess_mask_continuous(ImageChops.multiply(s_raw_plates, sel_alpha), 1, 1.2)
        s_m_hair = preprocess_mask_continuous(ImageChops.multiply(s_raw_h, sel_alpha), 1, 1.2)
        s_m_eyes = preprocess_mask_continuous(ImageChops.multiply(s_raw_e, sel_alpha), 0, 0.5)

        # Descomposición de canales de Fullbody Front
        fbm_r, fbm_g, fbm_b = fb_mask_raw.split()
        fb_clean_r = ImageChops.multiply(fbm_r, fb_alpha).point(lut_clean)
        fb_clean_g = ImageChops.multiply(fbm_g, fb_alpha).point(lut_clean)
        fb_clean_b = ImageChops.multiply(fbm_b, fb_alpha).point(lut_clean)
        fb_raw_c = ImageChops.subtract(fb_clean_r, ImageChops.add(fb_clean_g, fb_clean_b))
        fb_raw_h = ImageChops.subtract(fb_clean_g, ImageChops.add(fb_clean_r, fb_clean_b))
        fb_raw_e = ImageChops.subtract(fb_clean_b, ImageChops.add(fb_clean_r, fb_clean_g))

        fb_hsv = fb_img.convert("RGB").convert("HSV")
        fb_h, fb_s, fb_v = fb_hsv.split()
        fb_raw_plates = ImageChops.multiply(fb_s.point(lut_desat), fb_v.point(lut_bright))
        fb_raw_plates = ImageChops.multiply(fb_raw_plates, fb_raw_c)
        fb_raw_suit = ImageChops.subtract(fb_raw_c, fb_raw_plates)

        fb_m_suit = preprocess_mask_continuous(fb_raw_suit, 1, 1.2)
        fb_m_plates = preprocess_mask_continuous(fb_raw_plates, 1, 1.2)
        fb_m_hair = preprocess_mask_continuous(fb_raw_h, 1, 1.2)
        fb_m_eyes = preprocess_mask_continuous(fb_raw_e, 0, 0.5)

        # Descomposición de canales de Fullbody Back
        fbbm_r, fbbm_g, fbbm_b = fbb_mask_raw.split()
        fbb_clean_r = ImageChops.multiply(fbbm_r, fbb_alpha).point(lut_clean)
        fbb_clean_g = ImageChops.multiply(fbbm_g, fbb_alpha).point(lut_clean)
        fbb_clean_b = ImageChops.multiply(fbbm_b, fbb_alpha).point(lut_clean)
        fbb_raw_c = ImageChops.subtract(fbb_clean_r, ImageChops.add(fbb_clean_g, fbb_clean_b))
        fbb_raw_h = ImageChops.subtract(fbb_clean_g, ImageChops.add(fbb_clean_r, fbb_clean_b))
        fbb_raw_e = ImageChops.subtract(fbb_clean_b, ImageChops.add(fbb_clean_r, fbb_clean_g))

        fbb_hsv = fbb_img.convert("RGB").convert("HSV")
        fbb_h, fbb_s, fbb_v = fbb_hsv.split()
        fbb_raw_plates = ImageChops.multiply(fbb_s.point(lut_desat), fbb_v.point(lut_bright))
        fbb_raw_plates = ImageChops.multiply(fbb_raw_plates, fbb_raw_c)
        fbb_raw_suit = ImageChops.subtract(fbb_raw_c, fbb_raw_plates)

        fbb_m_suit = preprocess_mask_continuous(fbb_raw_suit, 1, 1.2)
        fbb_m_plates = preprocess_mask_continuous(fbb_raw_plates, 1, 1.2)
        fbb_m_hair = preprocess_mask_continuous(fbb_raw_h, 1, 1.2)
        fbb_m_reactor = preprocess_mask_continuous(fbb_raw_e, 0, 0.8)

        # Descomposición de canales de Ships (R=Chasis/Hull, G=Alas/Placas, B=Reactores)
        shm_r, shm_g, shm_b = sh_mask_img.split()
        sh_clean_r = ImageChops.multiply(shm_r, sh_alpha).point(lut_clean)
        sh_clean_g = ImageChops.multiply(shm_g, sh_alpha).point(lut_clean)
        sh_clean_b = ImageChops.multiply(shm_b, sh_alpha).point(lut_clean)
        sh_hull = preprocess_mask_continuous(ImageChops.subtract(sh_clean_r, ImageChops.add(sh_clean_g, sh_clean_b)), 0, 0.8)
        sh_plates = preprocess_mask_continuous(ImageChops.subtract(sh_clean_g, ImageChops.add(sh_clean_r, sh_clean_b)), 0, 0.8)
        sh_reactor = preprocess_mask_continuous(ImageChops.subtract(sh_clean_b, ImageChops.add(sh_clean_r, sh_clean_g)), 0, 0.8)

        print(f"\n[+] Procesando piloto: {cap.upper()}...")

        for pal_key, pal_data in PALETTES.items():
            current_task += 1
            print(f"  ({current_task}/{total_tasks}) Generando {pal_data['name']}...")

            # -------------------------------------------------------------
            # A) SELECTION SPLASH
            # -------------------------------------------------------------
            sel_rgb = sel_img.convert("RGB")
            c_sel = recolor_hair_cielab(sel_rgb, s_m_hair, pal_data, is_echo)
            c_sel = recolor_zone_cielab(c_sel, s_m_plates, pal_data["plates_lab"], pal_data["plates_l_mult"], pal_data["plates_chroma"])
            c_sel = recolor_zone_cielab(c_sel, s_m_suit, pal_data["suit_lab"], pal_data["suit_l_mult"], pal_data["suit_chroma"])
            c_sel = recolor_zone_cielab(c_sel, s_m_eyes, pal_data["eyes_lab"], 1.1, 1.8)
            final_sel = Image.merge("RGBA", (*c_sel.split(), sel_alpha))
            final_sel_flip = ImageOps.mirror(final_sel)

            final_sel.save(os.path.join(RECOLORS_PILOTS_DIR, f"selection_{pilot}_{pal_key}.png"))
            final_sel_flip.save(os.path.join(RECOLORS_PILOTS_DIR, f"selection_{pilot}_{pal_key}_flipped.png"))

            # -------------------------------------------------------------
            # B) PORTRAITS (Derivados con precisión milimétrica)
            # -------------------------------------------------------------
            port_left, port_right = derive_portrait_from_selection(final_sel, pilot)
            port_left.save(os.path.join(RECOLORS_PILOTS_DIR, f"portrait_{pilot}_{pal_key}.png"))
            port_right.save(os.path.join(RECOLORS_PILOTS_DIR, f"portrait_{pilot}_{pal_key}_flipped.png"))

            # -------------------------------------------------------------
            # C) FULLBODY OVERWORLD (FRENTE Y ESPALDA)
            # -------------------------------------------------------------
            # Frente
            fb_rgb = fb_img.convert("RGB")
            c_fb = recolor_hair_cielab(fb_rgb, fb_m_hair, pal_data, is_echo)
            c_fb = recolor_zone_cielab(c_fb, fb_m_plates, pal_data["plates_lab"], pal_data["plates_l_mult"], pal_data["plates_chroma"])
            c_fb = recolor_zone_cielab(c_fb, fb_m_suit, pal_data["suit_lab"], pal_data["suit_l_mult"], pal_data["suit_chroma"])
            c_fb = recolor_zone_cielab(c_fb, fb_m_eyes, pal_data["eyes_lab"], 1.1, 1.8)
            final_fb = Image.merge("RGBA", (*c_fb.split(), fb_alpha))
            final_fb_flip = ImageOps.mirror(final_fb)

            final_fb.save(os.path.join(RECOLORS_PILOTS_DIR, f"fullbody_{pilot}_{pal_key}.png"))
            final_fb_flip.save(os.path.join(RECOLORS_PILOTS_DIR, f"fullbody_{pilot}_{pal_key}_flipped.png"))

            # Espalda
            fbb_rgb = fbb_img.convert("RGB")
            c_fbb = recolor_hair_cielab(fbb_rgb, fbb_m_hair, pal_data, is_echo)
            c_fbb = recolor_zone_cielab(c_fbb, fbb_m_plates, pal_data["plates_lab"], pal_data["plates_l_mult"], pal_data["plates_chroma"])
            c_fbb = recolor_zone_cielab(c_fbb, fbb_m_suit, pal_data["suit_lab"], pal_data["suit_l_mult"], pal_data["suit_chroma"])
            if fbb_m_reactor.getbbox():
                c_fbb = recolor_zone_cielab(c_fbb, fbb_m_reactor, pal_data["eyes_lab"], 1.15, 1.8)
            final_fbb = Image.merge("RGBA", (*c_fbb.split(), fbb_alpha))
            final_fbb_flip = ImageOps.mirror(final_fbb)

            final_fbb.save(os.path.join(RECOLORS_PILOTS_DIR, f"fullbody_{pilot}_{pal_key}_back.png"))
            final_fbb_flip.save(os.path.join(RECOLORS_PILOTS_DIR, f"fullbody_{pilot}_{pal_key}_back_flipped.png"))

            # -------------------------------------------------------------
            # D) SHIPS (EXOTRAJES ESPACIALES)
            # -------------------------------------------------------------
            sh_rgb = sh_img.convert("RGB")
            c_sh = recolor_zone_cielab(sh_rgb, sh_hull, pal_data["suit_lab"], pal_data["suit_l_mult"], pal_data["suit_chroma"])
            c_sh = recolor_zone_cielab(c_sh, sh_plates, pal_data["plates_lab"], pal_data["plates_l_mult"], pal_data["plates_chroma"])
            if sh_reactor.getbbox():
                c_sh = recolor_zone_cielab(c_sh, sh_reactor, pal_data["eyes_lab"], 1.25, 2.0)
            final_sh = Image.merge("RGBA", (*c_sh.split(), sh_alpha))
            final_sh.save(os.path.join(RECOLORS_SHIPS_DIR, f"ship_{pilot}_{pal_key}.png"))

            # -------------------------------------------------------------
            # E) WEAPONS (NORMAL 256x256 Y HD 1024x1024)
            # -------------------------------------------------------------
            final_w = generate_smart_weapon(w_img, pal_data["weapon_plates"], pal_data["weapon_chassis"], pal_data["weapon_energy"])
            final_w_hd = generate_smart_weapon(w_hd_img, pal_data["weapon_plates"], pal_data["weapon_chassis"], pal_data["weapon_energy"])
            final_w.save(os.path.join(RECOLORS_WEAPONS_DIR, f"weapon_{pilot}_{pal_key}.png"))
            final_w_hd.save(os.path.join(RECOLORS_WEAPONS_DIR, f"weapon_{pilot}_{pal_key}_hd.png"))

    print("\n[OK] Todos los assets visuales PNG han sido exportados exitosamente.")

# =============================================================================
# ACTUALIZACIÓN DE BASE DE DATOS DE COSMÉTICOS
# =============================================================================
def update_databases():
    print("\n[+] Sincronizando Base de Datos de Cosmeticos...")

    # 1. Actualizar palettes.json
    palettes_json_path = os.path.join(CATEGORIES_DIR, "palettes.json")
    palettes_dict = {}
    for p_id, p_val in PALETTES.items():
        palettes_dict[p_id] = {
            "name": p_val["name"],
            "description": p_val["description"],
            "tint_rgb": p_val["tint_rgb"],
            "glow_hex": p_val["glow_hex"],
            "accent_hex": p_val["accent_hex"],
            "secondary_rgb": p_val["secondary_rgb"],
            "rarity": p_val["rarity"]
        }

    with open(palettes_json_path, "w", encoding="utf-8") as f:
        json.dump({"palettes": palettes_dict}, f, indent=2, ensure_ascii=False)
    print(f"  [OK] {palettes_json_path} actualizado.")

    # 2. Actualizar skins_pilots.json
    pilots_meta = {
        "nova": "Nova",
        "valentina": "Valentina",
        "kira": "Kira",
        "selene": "Selene",
        "roxy": "Roxy",
        "echo": "Echo",
        "nyx": "Nyx"
    }
    pilots_json_path = os.path.join(CATEGORIES_DIR, "skins_pilots.json")
    pilot_skins = {}
    for pid, pname in pilots_meta.items():
        for pal_id, pal_val in PALETTES.items():
            sid = f"pilot_{pid}_{pal_id}"
            pilot_skins[sid] = {
                "id": sid,
                "category": "pilot",
                "target_id": pid,
                "target_name": pname,
                "palette_id": pal_id,
                "skin_name": f"{pal_val['name']} - {pname}",
                "description": pal_val["description"],
                "rarity": pal_val["rarity"],
                "glow_hex": pal_val["glow_hex"],
                "accent_hex": pal_val["accent_hex"],
                "texture_path": f"res://assets/recolors/pilots/fullbody_{pid}_{pal_id}.png",
                "flipped_texture_path": f"res://assets/recolors/pilots/fullbody_{pid}_{pal_id}_flipped.png",
                "back_texture_path": f"res://assets/recolors/pilots/fullbody_{pid}_{pal_id}_back.png",
                "back_flipped_texture_path": f"res://assets/recolors/pilots/fullbody_{pid}_{pal_id}_back_flipped.png",
                "selection_texture_path": f"res://assets/recolors/pilots/selection_{pid}_{pal_id}.png",
                "selection_flipped_texture_path": f"res://assets/recolors/pilots/selection_{pid}_{pal_id}_flipped.png",
                "portrait_texture_path": f"res://assets/recolors/pilots/portrait_{pid}_{pal_id}.png",
                "portrait_flipped_texture_path": f"res://assets/recolors/pilots/portrait_{pid}_{pal_id}_flipped.png"
            }
    with open(pilots_json_path, "w", encoding="utf-8") as f:
        json.dump({"category": "pilot", "skins": pilot_skins}, f, indent=2, ensure_ascii=False)
    print(f"  [OK] {pilots_json_path} actualizado ({len(pilot_skins)} skins).")

    # 3. Actualizar skins_ships.json
    ships_json_path = os.path.join(CATEGORIES_DIR, "skins_ships.json")
    ship_skins = {}
    for pid, pname in pilots_meta.items():
        for pal_id, pal_val in PALETTES.items():
            sid = f"ship_{pid}_{pal_id}"
            ship_skins[sid] = {
                "id": sid,
                "category": "ship",
                "target_id": pid,
                "target_name": f"Nave de {pname}",
                "palette_id": pal_id,
                "skin_name": f"{pal_val['name']} - Nave {pname}",
                "description": pal_val["description"],
                "rarity": pal_val["rarity"],
                "glow_hex": pal_val["glow_hex"],
                "accent_hex": pal_val["accent_hex"],
                "texture_path": f"res://assets/recolors/ships/ship_{pid}_{pal_id}.png"
            }
    with open(ships_json_path, "w", encoding="utf-8") as f:
        json.dump({"category": "ship", "skins": ship_skins}, f, indent=2, ensure_ascii=False)
    print(f"  [OK] {ships_json_path} actualizado ({len(ship_skins)} skins).")

    # 4. Actualizar skins_weapons.json
    weapons_json_path = os.path.join(CATEGORIES_DIR, "skins_weapons.json")
    weapon_skins = {}
    for pid, pname in pilots_meta.items():
        for pal_id, pal_val in PALETTES.items():
            sid = f"weapon_{pid}_{pal_id}"
            weapon_skins[sid] = {
                "id": sid,
                "category": "weapon",
                "target_id": pid,
                "target_name": f"Arma de {pname}",
                "palette_id": pal_id,
                "skin_name": f"{pal_val['name']} - Arma {pname}",
                "description": f"Aspecto cosmetico para el cañon de {pname} en acabado {pal_val['name']}.",
                "rarity": pal_val["rarity"],
                "glow_hex": pal_val["glow_hex"],
                "accent_hex": pal_val["accent_hex"],
                "tint_rgb": pal_val["tint_rgb"],
                "texture_path": f"res://assets/recolors/weapons/weapon_{pid}_{pal_id}.png"
            }
    with open(weapons_json_path, "w", encoding="utf-8") as f:
        json.dump({"category": "weapon", "skins": weapon_skins}, f, indent=2, ensure_ascii=False)
    print(f"  [OK] {weapons_json_path} actualizado ({len(weapon_skins)} skins).")

    # 5. Reconstruir skin_database.json monolítico integrado
    merged_skins = {}
    merged_skins.update(ship_skins)
    merged_skins.update(pilot_skins)
    merged_skins.update(weapon_skins)

    # Conservar skins de pets y navigators existentes si están en las categorías
    pets_path = os.path.join(CATEGORIES_DIR, "skins_pets.json")
    if os.path.exists(pets_path):
        with open(pets_path, "r", encoding="utf-8") as f:
            pd = json.load(f)
            merged_skins.update(pd.get("skins", {}))

    navs_path = os.path.join(CATEGORIES_DIR, "skins_navigators.json")
    if os.path.exists(navs_path):
        with open(navs_path, "r", encoding="utf-8") as f:
            nd = json.load(f)
            merged_skins.update(nd.get("skins", {}))

    db_path = os.path.join(DATA_DIR, "skin_database.json")
    with open(db_path, "w", encoding="utf-8") as f:
        json.dump({
            "version": "1.0",
            "palettes": palettes_dict,
            "skins": merged_skins
        }, f, indent=2, ensure_ascii=False)
    print(f"  [OK] {db_path} reconstruido exitosamente con {len(merged_skins)} skins totales.")

if __name__ == "__main__":
    generate_all()
    update_databases()
    print("\n[OK] PROCESO DE PRODUCCION COMPLETADO AL 100%!")
