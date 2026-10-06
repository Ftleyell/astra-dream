"""
Script para recortar, limpiar croma (#FF00FF) y normalizar
las Grillas 4x4 de Iconos de Habilidades de Pilotos para Astra Dream.

Uso:
    python tools/process_pilot_skill_grids.py --grid 1 --input ruta/a/grilla1.png
    python tools/process_pilot_skill_grids.py --grid 2 --input ruta/a/grilla2.png
"""

import os
import sys
import argparse
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_SKILLS_DIR = os.path.join(BASE_DIR, "assets", "characters", "skills")

GRID_1_MAPPING = {
    # Fila 1: Armas 1-4
    (0, 0): ("weapons", "icon_weapon_nova.png"),
    (0, 1): ("weapons", "icon_weapon_valentina.png"),
    (0, 2): ("weapons", "icon_weapon_roxy.png"),
    (0, 3): ("weapons", "icon_weapon_selene.png"),
    # Fila 2: Armas 5-7 + Táctica 1
    (1, 0): ("weapons", "icon_weapon_nyx.png"),
    (1, 1): ("weapons", "icon_weapon_echo.png"),
    (1, 2): ("weapons", "icon_weapon_kira.png"),
    (1, 3): ("tacticals", "icon_tactical_nova.png"),
    # Fila 3: Tácticas 2-5
    (2, 0): ("tacticals", "icon_tactical_valentina.png"),
    (2, 1): ("tacticals", "icon_tactical_roxy.png"),
    (2, 2): ("tacticals", "icon_tactical_selene.png"),
    (2, 3): ("tacticals", "icon_tactical_nyx.png"),
    # Fila 4: Tácticas 6-7 + Comodines
    (3, 0): ("tacticals", "icon_tactical_echo.png"),
    (3, 1): ("tacticals", "icon_tactical_kira.png"),
    (3, 2): ("misc", "icon_wildcard_overdrive.png"),
    (3, 3): ("misc", "icon_wildcard_void_beacon.png"),
}

GRID_2_MAPPING = {
    # Fila 1: Dashes 1-4
    (0, 0): ("dashes", "icon_dash_nova.png"),
    (0, 1): ("dashes", "icon_dash_valentina.png"),
    (0, 2): ("dashes", "icon_dash_roxy.png"),
    (0, 3): ("dashes", "icon_dash_selene.png"),
    # Fila 2: Dashes 5-7 + Pasiva 1
    (1, 0): ("dashes", "icon_dash_nyx.png"),
    (1, 1): ("dashes", "icon_dash_echo.png"),
    (1, 2): ("dashes", "icon_dash_kira.png"),
    (1, 3): ("passives", "icon_passive_nova.png"),
    # Fila 3: Pasivas 2-5
    (2, 0): ("passives", "icon_passive_valentina.png"),
    (2, 1): ("passives", "icon_passive_roxy.png"),
    (2, 2): ("passives", "icon_passive_selene.png"),
    (2, 3): ("passives", "icon_passive_nyx.png"),
    # Fila 4: Pasivas 6-7 + Comodines
    (3, 0): ("passives", "icon_passive_echo.png"),
    (3, 1): ("passives", "icon_passive_kira.png"),
    (3, 2): ("misc", "icon_wildcard_chrono.png"),
    (3, 3): ("misc", "icon_wildcard_core_synthesis.png"),
}

def remove_magenta_chroma(img: Image.Image) -> Image.Image:
    """Remueve fondo magenta puro (#FF00FF) con despill y preserva contenido del icono."""
    im = img.convert("RGBA")
    w, h = im.size
    pix = im.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            # Magenta se caracteriza por alto R y B con muy bajo G
            min_rb = min(r, b)
            excess = min_rb - g

            if excess > 30 and min_rb > 100:
                if excess > 70:
                    alpha = 0
                else:
                    alpha = int(255 * (1.0 - (excess - 30) / 40.0))
                # Despill magenta eliminando la fuga violeta/magenta residual
                rb_despilled = max(g, min_rb // 2)
                pix[x, y] = (min(r, rb_despilled), g, min(b, rb_despilled), min(a, alpha))
            elif r > 160 and b > 160 and g < 70:
                pix[x, y] = (0, 0, 0, 0)

    return im

def process_grid(image_path: str, grid_num: int, target_size: int = 256) -> None:
    if not os.path.exists(image_path):
        print(f"Error: No se encontró la imagen en {image_path}")
        return

    mapping = GRID_1_MAPPING if grid_num == 1 else GRID_2_MAPPING
    print(f"Abriendo imagen de Grilla {grid_num}: {image_path}")
    raw_img = Image.open(image_path).convert("RGBA")
    total_w, total_h = raw_img.size

    # Dividir en 4 columnas y 4 filas
    cell_w = total_w / 4.0
    cell_h = total_h / 4.0

    for (row, col), (subfolder, filename) in mapping.items():
        left = int(col * cell_w)
        top = int(row * cell_h)
        right = int((col + 1) * cell_w)
        bottom = int((row + 1) * cell_h)

        cell_crop = raw_img.crop((left, top, right, bottom))
        cleaned = remove_magenta_chroma(cell_crop)

        # Autocrop a la caja no transparente (al marco del HUD)
        bbox = cleaned.getbbox()
        if bbox:
            cleaned = cleaned.crop(bbox)

        # Centrar con padding cuadrado uniforme
        cw, ch = cleaned.size
        dim = max(cw, ch)
        padded = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
        offset_x = (dim - cw) // 2
        offset_y = (dim - ch) // 2
        padded.paste(cleaned, (offset_x, offset_y))

        final_icon = padded.resize((target_size, target_size), Image.Resampling.LANCZOS)

        # Carpeta destino
        dest_dir = os.path.join(OUTPUT_SKILLS_DIR, subfolder)
        os.makedirs(dest_dir, exist_ok=True)
        out_path = os.path.join(dest_dir, filename)

        final_icon.save(out_path, "PNG")
        print(f"  [OK] Exportado: {subfolder}/{filename} ({target_size}x{target_size})")

    print(f"\n¡Grilla {grid_num} procesada con éxito! Iconos guardados en {OUTPUT_SKILLS_DIR}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Procesador de Grillas de Habilidades de Astra Dream")
    parser.add_argument("--grid", type=int, choices=[1, 2], required=True, help="Número de grilla (1 o 2)")
    parser.add_argument("--input", type=str, required=True, help="Ruta a la imagen generada por Gemini")
    parser.add_argument("--size", type=int, default=256, help="Tamaño cuadrado del icono (por defecto 256)")
    args = parser.parse_args()

    process_grid(args.input, args.grid, args.size)
