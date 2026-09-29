"""
chromakey_extractor.py
Herramienta de procesamiento de imagen para Astra Dream.
Remueve fondos chromakey (verde o magenta) con tolerancia cromática euclidiana,
suavizado de bordes (alpha feathering), despill y recorte inteligente a PNG transparente.
"""

import sys
import os
import math
import argparse
from PIL import Image, ImageFilter, ImageOps


def parse_hex_color(hex_str: str) -> tuple[int, int, int]:
    clean = hex_str.strip().lstrip("#")
    if len(clean) == 3:
        clean = "".join([c * 2 for c in clean])
    r = int(clean[0:2], 16)
    g = int(clean[2:4], 16)
    b = int(clean[4:6], 16)
    return (r, g, b)


def color_distance_sq(c1: tuple[int, int, int], c2: tuple[int, int, int]) -> float:
    # Perceptually weighted Euclidean color distance squared
    # Red: 0.30, Green: 0.59, Blue: 0.11
    dr = c1[0] - c2[0]
    dg = c1[1] - c2[1]
    db = c1[2] - c2[2]
    return 0.30 * (dr * dr) + 0.59 * (dg * dg) + 0.11 * (db * db)


def process_chromakey(
    input_path: str,
    output_path: str,
    key_color_rgb: tuple[int, int, int],
    tolerance: float = 65.0,
    softness: float = 25.0,
    feather_radius: float = 1.0,
    despill: bool = True,
    trim: bool = True,
    target_max_size: int = 512,
) -> bool:
    if not os.path.exists(input_path):
        print(f"Error: No existe el archivo {input_path}")
        return False

    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    pixels = img.load()

    # Si key_color no está definido explícitamente, muestrear las 4 esquinas
    kr, kg, kb = key_color_rgb
    tol_min_sq = (tolerance - softness) ** 2
    tol_max_sq = (tolerance + softness) ** 2

    # Construir máscara de opacidad (alpha)
    alpha_mask = Image.new("L", (w, h), 255)
    mask_pixels = alpha_mask.load()

    # Identificar canal dominante del fondo para despill
    is_magenta = (kr > 180 and kb > 180 and kg < 100)
    is_green = (kg > 180 and kr < 100 and kb < 100)

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            dist_sq = color_distance_sq((r, g, b), (kr, kg, kb))

            if dist_sq <= tol_min_sq:
                # Fondo total transparente
                mask_pixels[x, y] = 0
            elif dist_sq >= tol_max_sq:
                # Objeto completamente opaco
                mask_pixels[x, y] = 255
            else:
                # Borde suave interpolado
                factor = (math.sqrt(dist_sq) - (tolerance - softness)) / (2.0 * softness)
                factor = max(0.0, min(1.0, factor))
                mask_pixels[x, y] = int(factor * 255.0)

            # Despill: remover contaminación de color en los bordes
            if despill and mask_pixels[x, y] > 0 and mask_pixels[x, y] < 255:
                if is_magenta:
                    # Limitar rojo y azul hacia el verde
                    max_rb = max(r, b)
                    if max_rb > g:
                        excess = max_rb - g
                        factor_edge = 1.0 - (mask_pixels[x, y] / 255.0)
                        sub = int(excess * factor_edge * 0.75)
                        pixels[x, y] = (max(0, r - sub), g, max(0, b - sub), a)
                elif is_green:
                    # Limitar verde hacia el promedio de rojo y azul
                    avg_rb = (r + b) // 2
                    if g > avg_rb:
                        excess = g - avg_rb
                        factor_edge = 1.0 - (mask_pixels[x, y] / 255.0)
                        sub = int(excess * factor_edge * 0.75)
                        pixels[x, y] = (r, max(0, g - sub), b, a)

    # Aplicar suavizado de bordes (Feathering) a la máscara
    if feather_radius > 0.0:
        alpha_mask = alpha_mask.filter(ImageFilter.GaussianBlur(feather_radius))

    # Reintegrar canal alfa
    img.putalpha(alpha_mask)

    # Auto-recorte de bordes transparentes
    if trim:
        bbox = img.getbbox()
        if bbox:
            # Añadir margen de 8px
            pad = 8
            x0 = max(0, bbox[0] - pad)
            y0 = max(0, bbox[1] - pad)
            x1 = min(w, bbox[2] + pad)
            y1 = min(h, bbox[3] + pad)
            img = img.crop((x0, y0, x1, y1))

    # Escalar si supera el tamaño máximo conservando relación de aspecto
    if target_max_size > 0:
        cur_w, cur_h = img.size
        if max(cur_w, cur_h) > target_max_size:
            ratio = float(target_max_size) / float(max(cur_w, cur_h))
            new_size = (int(cur_w * ratio), int(cur_h * ratio))
            img = img.resize(new_size, Image.Resampling.LANCZOS)

    # Crear directorio de salida si no existe
    out_dir = os.path.dirname(os.path.abspath(output_path))
    os.makedirs(out_dir, exist_ok=True)

    img.save(output_path, "PNG", optimize=True)
    print(f"[OK] Procesado con exito: {output_path} ({img.size[0]}x{img.size[1]})")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="Extractor de Chromakey para Astra Dream")
    parser.add_argument("--input", "-i", required=True, help="Ruta de imagen de entrada")
    parser.add_argument("--output", "-o", required=True, help="Ruta de imagen PNG resultante")
    parser.add_argument("--color", "-c", default="#FF00FF", help="Color de fondo chromakey en hexadecimal (#FF00FF o #00FF00)")
    parser.add_argument("--tolerance", "-t", type=float, default=65.0, help="Tolerancia cromatica (default: 65)")
    parser.add_argument("--softness", "-s", type=float, default=25.0, help="Suavizado de transicion (default: 25)")
    parser.add_argument("--feather", "-f", type=float, default=1.0, help="Radio de desenfoque de mascara (default: 1.0)")
    parser.add_argument("--max-size", "-m", type=int, default=512, help="Tamano maximo de salida (default: 512)")
    parser.add_argument("--no-trim", action="store_true", help="Desactivar recorte de bordes")
    parser.add_argument("--no-despill", action="store_true", help="Desactivar correccion de despill")

    args = parser.parse_args()
    key_rgb = parse_hex_color(args.color)

    success = process_chromakey(
        input_path=args.input,
        output_path=args.output,
        key_color_rgb=key_rgb,
        tolerance=args.tolerance,
        softness=args.softness,
        feather_radius=args.feather,
        despill=not args.no_despill,
        trim=not args.no_trim,
        target_max_size=args.max_size,
    )

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
