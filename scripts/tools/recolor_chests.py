#!/usr/bin/env python3
"""
Astra Dream — Script de recoloreado algoritmico de cofres espaciales
Genera las 3 variantes canonicas: Salvage (Chatarra), Regular y Golden a partir del sprite base.
"""

import os
import colorsys
from PIL import Image, ImageEnhance

def recolor_chest(base_path: str, out_path: str, variant: str):
    im = Image.open(base_path).convert("RGBA")
    pixels = im.load()
    w, h = im.size

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h_val, s_val, v_val = colorsys.rgb_to_hsv(rf, gf, bf)

            # Detectar si es núcleo/circuito brillante cian (H ~ 0.45 - 0.58, S > 0.3)
            is_cyan_glow = (0.43 <= h_val <= 0.60) and (s_val > 0.25)
            # Detectar acentos naranja/amarillo originales (H ~ 0.05 - 0.16, S > 0.35)
            is_accent = (0.05 <= h_val <= 0.16) and (s_val > 0.35)
            # Detectar metal/blindaje base (baja saturación)
            is_hull = s_val <= 0.35

            if variant == "salvage":
                # Chatarra: Tono herrumbroso, oxidado, baja energia
                if is_cyan_glow:
                    # Nucleo atenuado a ambar sucio / apagado
                    h_val = 0.08
                    s_val = min(1.0, s_val * 0.7)
                    v_val = v_val * 0.75
                elif is_accent:
                    # Acentos a bronce oscuro / marron
                    h_val = 0.06
                    s_val = s_val * 0.6
                    v_val = v_val * 0.7
                elif is_hull:
                    # Chasis con tinte calido ferroso/oxidado
                    h_val = 0.07
                    s_val = min(0.35, s_val * 1.3 + 0.1)
                    v_val = v_val * 0.9

            elif variant == "regular":
                # Regular: Cibernetico de vanguardia (Azul oscuro / Cian turquesa intenso)
                if is_cyan_glow:
                    # Resaltar azul neon / cian reactivo
                    h_val = 0.50 # Cian puro
                    s_val = min(1.0, s_val * 1.1)
                    v_val = min(1.0, v_val * 1.1)
                elif is_accent:
                    # Acentos a esmeralda / verde menta de estado
                    h_val = 0.38
                    s_val = min(1.0, s_val * 1.0)
                elif is_hull:
                    # Blindaje acero titanio frio
                    h_val = 0.58
                    s_val = min(0.25, s_val * 0.8)

            elif variant == "golden":
                # Dorado: Aleacion aurea brillante, nucleo solar y detalles obsidiana
                if is_cyan_glow:
                    # Nucleo de energia solar dorada / plasma blanco-ambar
                    h_val = 0.13 # Amarillo solar
                    s_val = min(1.0, s_val * 1.15)
                    v_val = min(1.0, v_val * 1.2)
                elif is_accent:
                    # Acentos a dorado intenso
                    h_val = 0.11 # Oro calido
                    s_val = min(1.0, s_val * 1.2)
                    v_val = min(1.0, v_val * 1.1)
                elif is_hull:
                    # Chasis con tono oro bruñido y reflejo solar
                    if v_val > 0.4:
                        h_val = 0.13 # Oro metalico
                        s_val = min(0.55, s_val + 0.35)
                        v_val = min(1.0, v_val * 1.15)
                    else:
                        # Trims oscuros obsidiana
                        h_val = 0.10
                        s_val = min(0.25, s_val * 0.8)
                        v_val = v_val * 0.85

            nr, ng, nb = colorsys.hsv_to_rgb(h_val, s_val, v_val)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    im.save(out_path, "PNG")
    print(f"[OK] Generado {variant}: {out_path}")

def main():
    base = "scratch/spatial_chest_base_clean.png"
    target_dir = "assets/sprites/interactables"

    variants = [
        ("salvage", os.path.join(target_dir, "spatial_chest_salvage.png")),
        ("regular", os.path.join(target_dir, "spatial_chest_regular.png")),
        ("golden",  os.path.join(target_dir, "spatial_chest_golden.png")),
    ]

    for var_name, out_p in variants:
        recolor_chest(base, out_p, var_name)

if __name__ == "__main__":
    main()
