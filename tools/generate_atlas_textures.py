"""
Herramienta de segmentación por visión artificial (OpenCV) para generar
recursos AtlasTexture (.tres) de Godot a partir de los atlas de asteroides y chatarra.
"""

import os
import cv2
import numpy as np

OUTPUT_DIR = r"assets\environments\parallax_space\atlas_textures"

ATLAS_CONFIGS = [
    {
        "id": 0,
        "image_file": r"assets\environments\parallax_space\debris_atlas_0.png",
        "res_path": "res://assets/environments/parallax_space/debris_atlas_0.png",
        "prefix": "debris_0"
    },
    {
        "id": 1,
        "image_file": r"assets\environments\parallax_space/debris_atlas_1.png",
        "res_path": "res://assets/environments/parallax_space/debris_atlas_1.png",
        "prefix": "debris_1"
    }
]

def generate_atlas_resources() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_created = []

    for cfg in ATLAS_CONFIGS:
        img_path = cfg["image_file"]
        if not os.path.exists(img_path):
            print(f"[WARN] No encontrado: {img_path}")
            continue

        img = cv2.imread(img_path, cv2.IMREAD_UNCHANGED)
        if img is None or img.shape[2] < 4:
            print(f"[ERR] La imagen {img_path} no tiene canal alfa.")
            continue

        alpha = img[:, :, 3]
        H, W = alpha.shape

        # La máscara alfa ya es sólida y binaria; usamos umbral directo y kernel mínimo
        _, thresh = cv2.threshold(alpha, 128, 255, cv2.THRESH_BINARY)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

        contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        count = 0
        pad = 4
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            area = cv2.contourArea(c)
            if w >= 36 and h >= 36 and area >= 500:
                x1 = max(0, x - pad)
                y1 = max(0, y - pad)
                x2 = min(W, x + w + pad)
                y2 = min(H, y + h + pad)
                final_w = x2 - x1
                final_h = y2 - y1

                filename = f"{cfg['prefix']}_{count:03d}.tres"
                out_path = os.path.join(OUTPUT_DIR, filename)

                tres_content = (
                    f'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                    f'[ext_resource type="Texture2D" path="{cfg["res_path"]}" id="1_atlas"]\n\n'
                    f'[resource]\n'
                    f'atlas = ExtResource("1_atlas")\n'
                    f'region = Rect2({x1}, {y1}, {final_w}, {final_h})\n'
                )

                with open(out_path, "w", encoding="utf-8") as f:
                    f.write(tres_content)

                all_created.append(f"res://assets/environments/parallax_space/atlas_textures/{filename}")
                count += 1

        print(f"[OK] Atlas {cfg['id']}: {count} recursos AtlasTexture generados.")

    # Guardar un manifiesto en JSON para fácil acceso desde GDScript
    manifest_path = os.path.join(OUTPUT_DIR, "debris_manifest.json")
    import json
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(all_created, f, indent=2)

    print(f"\n>>> Total generado: {len(all_created)} recursos AtlasTexture en '{OUTPUT_DIR}'. <<<")

if __name__ == "__main__":
    generate_atlas_resources()
