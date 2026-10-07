#!/usr/bin/env python3
"""Processes pilot talent grids from preprocess/ into assets/characters/talents/<pilot>/."""
import os
import sys
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE_DIR, "tools"))
from process_pilot_skill_grids import remove_magenta_chroma

PREPROCESS_DIR = os.path.join(BASE_DIR, "preprocess")
OUTPUT_BASE_DIR = os.path.join(BASE_DIR, "assets", "characters", "talents")

PILOTS = {
    "nova": "Nova.jpg",
    "nyx": "Nyx.jpg",
    "valentina": "Valentina.jpg",
    "roxy": "Roxy.jpg",
    "selene": "Selene.jpg",
    "echo": "Echo.jpg",
    "kira": "Kira.jpg",
}

NODE_MAPPING = {
    # Fila 0: Core + Velocidad 1-3
    (0, 0): "talent_core.png",
    (0, 1): "talent_speed_1.png",
    (0, 2): "talent_speed_2.png",
    (0, 3): "talent_speed_3.png",
    # Fila 1: Daño 1-3 + Crítico 1
    (1, 0): "talent_damage_1.png",
    (1, 1): "talent_damage_2.png",
    (1, 2): "talent_damage_3.png",
    (1, 3): "talent_crit_1.png",
    # Fila 2: Crítico 2-3 + Vida/Blindaje 1-2
    (2, 0): "talent_crit_2.png",
    (2, 1): "talent_crit_3.png",
    (2, 2): "talent_hp_1.png",
    (2, 3): "talent_hp_2.png",
    # Fila 3: Vida/Blindaje 3 + Comodines
    (3, 0): "talent_hp_3.png",
    (3, 1): "misc/talent_wildcard_1.png",
    (3, 2): "misc/talent_wildcard_2.png",
    (3, 3): "misc/talent_wildcard_3.png",
}

def process_pilot(pilot_id: str, img_name: str):
    img_path = os.path.join(PREPROCESS_DIR, img_name)
    if not os.path.exists(img_path):
        print(f"[ERROR] No existe {img_path}")
        return

    out_pilot_dir = os.path.join(OUTPUT_BASE_DIR, pilot_id)
    out_misc_dir = os.path.join(out_pilot_dir, "misc")
    os.makedirs(out_pilot_dir, exist_ok=True)
    os.makedirs(out_misc_dir, exist_ok=True)

    print(f"\n--- Procesando {pilot_id.upper()} desde {img_name} ---")
    raw = Image.open(img_path).convert("RGBA")
    total_w, total_h = raw.size
    cell_w = total_w / 4.0
    cell_h = total_h / 4.0

    count = 0
    for (row, col), rel_path in NODE_MAPPING.items():
        left = int(col * cell_w)
        top = int(row * cell_h)
        right = int((col + 1) * cell_w)
        bottom = int((row + 1) * cell_h)

        crop = raw.crop((left, top, right, bottom))
        cleaned = remove_magenta_chroma(crop)

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

        target_file = os.path.join(out_pilot_dir, rel_path)
        final_img.save(target_file, format="PNG")
        count += 1

    print(f"[OK] {pilot_id.upper()}: {count} iconos guardados en {out_pilot_dir}")

def main():
    for pilot_id, img_name in PILOTS.items():
        process_pilot(pilot_id, img_name)

if __name__ == "__main__":
    main()
