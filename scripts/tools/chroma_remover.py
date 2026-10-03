#!/usr/bin/env python3
"""
Astra Dream — Chroma Key Background Remover
Elimina fondos de color sólido (verde, magenta, etc.) generados por IA (Gemini)
produciendo sprites PNG con canal alfa transparente y despill en los bordes.
"""

import os
import sys
import argparse
import colorsys
from PIL import Image

KEY_PRESETS = {
    "green": (0.333, 1.0, 1.0),     # Hue ~120 deg
    "magenta": (0.833, 1.0, 1.0),   # Hue ~300 deg
    "blue": (0.666, 1.0, 1.0),      # Hue ~240 deg
    "cyan": (0.500, 1.0, 1.0),      # Hue ~180 deg
}

def parse_key_color(key_str: str) -> tuple[float, float, float]:
    lower = key_str.lower().strip()
    if lower in KEY_PRESETS:
        return KEY_PRESETS[lower]
    
    # Si es formato hex '#RRGGBB'
    if lower.startswith("#") and len(lower) == 7:
        r = int(lower[1:3], 16) / 255.0
        g = int(lower[3:5], 16) / 255.0
        b = int(lower[5:7], 16) / 255.0
        return colorsys.rgb_to_hsv(r, g, b)
    
    # Fallback verde
    return KEY_PRESETS["green"]

def remove_chroma(
    image: Image.Image,
    target_hsv: tuple[float, float, float],
    hue_tolerance: float = 0.08,
    sat_min: float = 0.35,
    val_min: float = 0.20,
    despill: bool = True
) -> Image.Image:
    """
    Convierte los píxeles que coinciden con el color chroma en transparencia alfa.
    """
    img = image.convert("RGBA")
    pixels = img.load()
    width, height = img.size
    
    target_hue = target_hsv[0]

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h, s, v = colorsys.rgb_to_hsv(rf, gf, bf)

            # Distancia angular en el círculo de matiz (Hue)
            hue_diff = abs(h - target_hue)
            if hue_diff > 0.5:
                hue_diff = 1.0 - hue_diff

            # Condición de coincidencia con la pantalla chroma
            if hue_diff < hue_tolerance and s >= sat_min and v >= val_min:
                # Transparencia total
                pixels[x, y] = (0, 0, 0, 0)
            elif hue_diff < (hue_tolerance * 1.5) and s >= (sat_min * 0.7):
                # Borde suave (antialiasing)
                factor = (hue_diff - hue_tolerance) / (hue_tolerance * 0.5)
                new_alpha = int(a * max(0.0, min(1.0, factor)))
                if despill:
                    # Despill: neutralizar tinte verde/magenta en el halo periférico
                    if target_hue > 0.25 and target_hue < 0.45: # Verde
                        gf = min(gf, (rf + bf) * 0.5)
                    elif target_hue > 0.75 and target_hue < 0.95: # Magenta
                        rf = min(rf, gf)
                        bf = min(bf, gf)
                    r = int(rf * 255)
                    g = int(gf * 255)
                    b = int(bf * 255)
                pixels[x, y] = (r, g, b, new_alpha)

    return img

def process_file(in_path: str, out_path: str, key_hsv: tuple[float, float, float], tol: float, despill: bool):
    print(f"Procesando: {in_path} -> {out_path}")
    im = Image.open(in_path)
    clean_im = remove_chroma(im, key_hsv, hue_tolerance=tol, despill=despill)
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    clean_im.save(out_path, "PNG")
    print(f"  [OK] Guardado con exito: {out_path}")

def main():
    parser = argparse.ArgumentParser(description="Remueve fondos chroma key de sprites generados por IA.")
    parser.add_argument("--input", "-i", required=True, help="Ruta de imagen de entrada o directorio.")
    parser.add_argument("--output", "-o", required=True, help="Ruta de imagen de salida o directorio destino.")
    parser.add_argument("--key", "-k", default="green", help="Color clave: 'green', 'magenta', 'blue', o hex '#00FF00'.")
    parser.add_argument("--tolerance", "-t", type=float, default=0.08, help="Tolerancia angular de matiz (por defecto: 0.08).")
    parser.add_argument("--no_despill", action="store_true", help="Desactiva la eliminación de tinte residual en bordes.")

    args = parser.parse_args()
    key_hsv = parse_key_color(args.key)
    despill = not args.no_despill

    if os.path.isfile(args.input):
        process_file(args.input, args.output, key_hsv, args.tolerance, despill)
    elif os.path.isdir(args.input):
        os.makedirs(args.output, exist_ok=True)
        for fname in os.listdir(args.input):
            if fname.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                in_p = os.path.join(args.input, fname)
                out_p = os.path.join(args.output, os.path.splitext(fname)[0] + ".png")
                process_file(in_p, out_p, key_hsv, args.tolerance, despill)
    else:
        print(f"Error: Ruta no encontrada: {args.input}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
