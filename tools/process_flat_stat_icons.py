#!/usr/bin/env python3
"""Processes the 4x4 flat stats item grid and outputs icons to assets/icons/items/."""
import os
import sys
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE_DIR, "tools"))
from process_pilot_skill_grids import remove_magenta_chroma

INPUT_IMAGE = r"C:\Users\Frani\.gemini\antigravity\brain\f3d48a17-0926-45a1-b2e8-cca630d9946d\flat_stat_items_grid_1791325604138.jpg"
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "icons", "items")
MISC_DIR = os.path.join(OUTPUT_DIR, "misc")

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(MISC_DIR, exist_ok=True)

MAPPING = {
    # Fila 0
    (0, 0): (OUTPUT_DIR, "icon_espada.png"),
    (0, 1): (OUTPUT_DIR, "icon_botas.png"),
    (0, 2): (OUTPUT_DIR, "icon_corazon.png"),
    (0, 3): (OUTPUT_DIR, "icon_carcaj.png"),
    # Fila 1
    (1, 0): (OUTPUT_DIR, "icon_gafas.png"),
    (1, 1): (OUTPUT_DIR, "icon_guante.png"),
    (1, 2): (OUTPUT_DIR, "icon_lente_amplificadora.png"),
    (1, 3): (OUTPUT_DIR, "icon_lupa.png"),
    # Fila 2
    (2, 0): (OUTPUT_DIR, "icon_manzana.png"),
    (2, 1): (OUTPUT_DIR, "icon_propulsor.png"),
    (2, 2): (OUTPUT_DIR, "icon_reliquia_maldita.png"),
    (2, 3): (OUTPUT_DIR, "icon_moneda_oro.png"),
    # Fila 3 (Wildcards)
    (3, 0): (MISC_DIR, "icon_deflector_barrier.png"),
    (3, 1): (MISC_DIR, "icon_flux_battery.png"),
    (3, 2): (MISC_DIR, "icon_neural_processor.png"),
    (3, 3): (MISC_DIR, "icon_chrono_capsule.png"),
}

def process():
    print(f"Abriendo {INPUT_IMAGE}...")
    raw = Image.open(INPUT_IMAGE).convert("RGBA")
    total_w, total_h = raw.size
    cell_w = total_w / 4.0
    cell_h = total_h / 4.0

    for (row, col), (out_dir, fname) in MAPPING.items():
        left = int(col * cell_w)
        top = int(row * cell_h)
        right = int((col + 1) * cell_w)
        bottom = int((row + 1) * cell_h)

        crop = raw.crop((left, top, right, bottom))
        cleaned = remove_magenta_chroma(crop)

        # Autocrop al contenido no transparente con padding de seguridad
        bbox = cleaned.getbbox()
        if bbox:
            bx0, by0, bx1, by1 = bbox
            pad = 2
            bx0 = max(0, bx0 - pad)
            by0 = max(0, by0 - pad)
            bx1 = min(cleaned.width, bx1 + pad)
            by1 = min(cleaned.height, by1 + pad)
            bw = bx1 - bx0
            bh = by1 - by0
            side = max(bw, bh)
            sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            sq.paste(cleaned.crop((bx0, by0, bx1, by1)), ((side - bw) // 2, (side - bh) // 2))
            final_img = sq.resize((256, 256), Image.Resampling.LANCZOS)
        else:
            final_img = cleaned.resize((256, 256), Image.Resampling.LANCZOS)

        out_path = os.path.join(out_dir, fname)
        final_img.save(out_path, format="PNG")
        print(f"OK: {fname} guardado en {out_dir}")

if __name__ == "__main__":
    process()
