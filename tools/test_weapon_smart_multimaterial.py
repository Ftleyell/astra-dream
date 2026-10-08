#!/usr/bin/env python3
"""
tools/test_weapon_smart_multimaterial.py
Pipeline de Recoloreo Smart Multi-Material para Armas (Zero-Mask / 100% Automático).
Aisla los materiales mecánicos directamente a partir de la luminosidad y oclusión del sprite:
  1. Paneles de armadura modulares (Color temático de la skin)
  2. Chasis estructural / aleación (Titanio oscuro o tungsteno)
  3. Juntas, rejillas y pernos (Negro de oclusión profunda)
  4. Núcleo / Sensor / Cañón de aceleración (Inyección de energía reactiva con bloom)
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEAPON_BASE = os.path.join(BASE_DIR, "assets", "characters", "weapons", "weapon_base_transparent_hd.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison")


def decompose_weapon_materials(img: Image.Image):
    """
    Segmenta automáticamente el arma en 4 máscaras de material sin intervención manual:
      - m_plates: paneles modulares exteriores (brillantes y claros)
      - m_chassis: estructura media (cuerpo del cañón y montura)
      - m_recesses: ranuras oscuras, pernos y sombras de oclusión
      - m_energy: zonas emisivas / sensor central y bocas
    """
    img_rgba = img.convert("RGBA")
    r, g, b, alpha = img_rgba.split()
    gray = ImageOps.grayscale(img)

    # 1. Paneles de blindaje exteriores: Brillo alto (> 175) dentro de la silueta opaca
    lut_plates = [255 if x >= 175 else 0 for x in range(256)]
    m_plates = ImageChops.multiply(gray.point(lut_plates), alpha)

    # 2. Ranuras oscuras / pernos / oclusión mecánica: Brillo bajo (< 75)
    lut_dark = [255 if x <= 75 else 0 for x in range(256)]
    m_recesses = ImageChops.multiply(gray.point(lut_dark), alpha)

    # 3. Chasis estructural medio (76 a 174)
    lut_chassis = [255 if 75 < x < 175 else 0 for x in range(256)]
    m_chassis = ImageChops.multiply(gray.point(lut_chassis), alpha)

    # 4. Sensor frontal / Sensor óptico central: círculo/óvalo en la recámara
    # Detectar el sensor óptico en el centro (coordenadas relativas x: 500-550, y: 470-520)
    w, h = img.size
    m_energy = Image.new("L", (w, h), 0)
    # Crear máscara de energía focalizada en el sensor y ranuras de cañón
    sensor_box = Image.new("L", (w, h), 0)
    # Seleccionar pequeños reflejos de lente en la zona frontal
    lut_lens = [255 if 90 <= x <= 140 else 0 for x in range(256)]
    lens_c = ImageChops.multiply(gray.point(lut_lens), alpha)
    # Mascara delimitada al centro
    lens_mask_region = Image.new("L", (w, h), 0)
    for y in range(int(h * 0.44), int(h * 0.54)):
        for x in range(int(w * 0.49), int(w * 0.55)):
            lens_mask_region.putpixel((x, y), 255)
    m_energy = ImageChops.multiply(lens_c, lens_mask_region)

    # Suavizado subpíxel
    m_plates = m_plates.filter(ImageFilter.GaussianBlur(0.8))
    m_chassis = m_chassis.filter(ImageFilter.GaussianBlur(0.8))
    m_recesses = m_recesses.filter(ImageFilter.GaussianBlur(0.5))
    m_energy = m_energy.filter(ImageFilter.GaussianBlur(1.0))

    return m_plates, m_chassis, m_recesses, m_energy


def generate_smart_weapon_skin(
    base_img: Image.Image,
    primary_tint: tuple[int, int, int],     # Color de los paneles de armadura
    chassis_tint: tuple[int, int, int],     # Tinte de la aleación del chasis (ej. titanio oscuro o grafito)
    energy_color: tuple[int, int, int],     # Color de los LEDs / sensores
    accent_plates: bool = True
) -> Image.Image:
    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]
    gray = ImageOps.grayscale(base_rgb)

    m_plates, m_chassis, m_recesses, m_energy = decompose_weapon_materials(base_img)

    result = base_rgb.copy()

    # A) Chasis estructural: Aleación metálica profunda (Titanio / Tungsteno)
    chassis_colored = ImageOps.colorize(
        gray,
        black=(12, 14, 18),
        mid=chassis_tint,
        white=(180, 190, 205)
    )
    result = Image.composite(chassis_colored, result, m_chassis)

    # B) Paneles modulares exteriores: Color temático principal con sombras ricas y brillo especular limpio
    plates_colored = ImageOps.colorize(
        gray,
        black=(int(primary_tint[0] * 0.25), int(primary_tint[1] * 0.25), int(primary_tint[2] * 0.25)),
        mid=primary_tint,
        white=(255, 255, 255)
    )
    # Mezcla ponderada al 88% para preservar las micro-texturas del metal original
    plates_blended = Image.blend(base_rgb, plates_colored, 0.88)
    result = Image.composite(plates_blended, result, m_plates)

    # C) Ranuras, pernos y sombras: Oclusión profunda (Negro grafito mate)
    recesses_colored = ImageOps.colorize(
        gray,
        black=(5, 6, 8),
        mid=(20, 22, 28),
        white=(75, 80, 90)
    )
    result = Image.composite(recesses_colored, result, m_recesses)

    # D) Inyección de Energía / Sensor / LEDs con Bloom Aditivo
    if m_energy.getbbox():
        energy_solid = Image.new("RGB", base_rgb.size, energy_color)
        energy_core = Image.composite(energy_solid, Image.new("RGB", base_rgb.size, (0, 0, 0)), m_energy)
        energy_glow = energy_core.filter(ImageFilter.GaussianBlur(5.0))
        result = Image.composite(energy_solid, result, m_energy)
        result = ImageChops.screen(result, energy_glow)

    return Image.merge("RGBA", (*result.split(), alpha))


def run_weapon_test():
    if not os.path.exists(WEAPON_BASE):
        print(f"Error: No se encontró el asset base: {WEAPON_BASE}")
        return False

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    base_img = Image.open(WEAPON_BASE).convert("RGBA")

    # Variante 1: "Cyber Neon / Cyan Pulse" (Paneles Cian Neón, Chasis Titanio Grafito, Sensor Magenta Reactivo)
    w_cyber = generate_smart_weapon_skin(
        base_img,
        primary_tint=(0, 215, 245),       # Cian eléctrico brillante
        chassis_tint=(30, 36, 48),         # Titanio oscuro
        energy_color=(255, 40, 160)        # Sensor Magenta neón
    )
    out_cyber = os.path.join(OUTPUT_DIR, "smart_weapon_cyber_neon.png")
    w_cyber.save(out_cyber)

    # Variante 2: "Crimson Void" (Paneles Rojo Carmesí, Chasis Obsidiana, Sensor Cian de Plasma)
    w_crimson = generate_smart_weapon_skin(
        base_img,
        primary_tint=(235, 35, 65),       # Carmesí combate
        chassis_tint=(22, 22, 28),         # Obsidiana / Carbón
        energy_color=(0, 240, 255)         # Plasma Cian
    )
    out_crimson = os.path.join(OUTPUT_DIR, "smart_weapon_crimson_void.png")
    w_crimson.save(out_crimson)

    # Variante 3: "Solar Gold / Prototype" (Paneles Oro Estelar, Chasis Blanco Perlado / Acero Suizo, Sensor Ámbar)
    w_solar = generate_smart_weapon_skin(
        base_img,
        primary_tint=(255, 195, 25),       # Oro estelar
        chassis_tint=(65, 75, 88),         # Acero frío pulido
        energy_color=(255, 240, 100)       # Núcleo solar
    )
    out_solar = os.path.join(OUTPUT_DIR, "smart_weapon_solar_gold.png")
    w_solar.save(out_solar)

    # Collage comparativo: Base Original vs Variantes
    tw, th = 480, 480
    grid = Image.new("RGBA", (tw * 4, th), (18, 20, 26, 255))
    images = [
        ("Base Original (Gris)", base_img),
        ("Cyber Neon (Cian/Titanio)", w_cyber),
        ("Crimson Void (Carmesí/Obsidiana)", w_crimson),
        ("Solar Gold (Oro/Acero)", w_solar)
    ]
    for i, (title, img) in enumerate(images):
        thumb = img.resize((tw, th), Image.Resampling.LANCZOS)
        grid.paste(thumb, (i * tw, 0), thumb)

    comp_path = os.path.join(OUTPUT_DIR, "weapon_multimaterial_comparison.png")
    grid.save(comp_path)
    print(f"Comparativa de armas generada: {comp_path}")
    return True


if __name__ == "__main__":
    run_weapon_test()
