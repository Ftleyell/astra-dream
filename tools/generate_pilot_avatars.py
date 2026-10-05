#!/usr/bin/env python3
"""
generate_pilot_avatars.py
Genera avatares faciales 256x256 con antialiasing Lanczos y defringing alfa
a partir de los artes de selección 1200x1600 en assets/characters/selection/.
"""

import os
from PIL import Image

COORDINATES = {
    "nova": (581, 350, 480),
    "valentina": (588, 430, 480),
    "roxy": (535, 425, 480),
    "selene": (613, 380, 500),
    "nyx": (609, 340, 480),
    "echo": (611, 350, 480),
    "kira": (578, 375, 480),
}

def generate_avatars(base_dir: str = ".") -> None:
    in_dir = os.path.join(base_dir, "assets", "characters", "selection")
    out_dir = os.path.join(base_dir, "assets", "portraits", "avatars")
    os.makedirs(out_dir, exist_ok=True)

    for pilot, (cx, cy, box_size) in COORDINATES.items():
        in_path = os.path.join(in_dir, f"selection_{pilot}.png")
        if not os.path.exists(in_path):
            print(f"Advertencia: no se encontró {in_path}")
            continue

        im = Image.open(in_path).convert("RGBA")
        half = box_size // 2
        x0 = max(0, cx - half)
        y0 = max(0, cy - half)
        x1 = min(im.width, x0 + box_size)
        y1 = min(im.height, y0 + box_size)

        crop = im.crop((x0, y0, x1, y1))

        # Defringing: limpiar artefactos residuales en bordes alfa semi-transparentes
        r, g, b, a = crop.split()
        a_clean = a.point(lambda p: 0 if p < 18 else (p if p > 60 else int(p * 0.92)))
        crop.putalpha(a_clean)

        avatar = crop.resize((256, 256), Image.Resampling.LANCZOS)
        out_path = os.path.join(out_dir, f"avatar_{pilot}.png")
        avatar.save(out_path, "PNG")
        print(f"[OK] Generado avatar: {out_path} ({avatar.size})")

if __name__ == "__main__":
    generate_avatars()
