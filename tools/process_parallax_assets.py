"""
Script de procesamiento de assets de fondo espacial según especificación TDD.
Utiliza enmascaramiento de silueta sólida exterior (OpenCV) para garantizar que:
- Los interiores de planetas, estaciones y asteroides sean 100% opacos (bloqueando la luz de fondos brillantes).
- Solo el vacío exterior sea transparente, con antialiasing perimetral suave.
- Las nebulosas se conviertan en texturas continuas (seamless).
"""

import os
import sys
import cv2
import numpy as np
from PIL import Image

SOURCE_DIR = r"docs\Paralax"
TARGET_DIR = r"assets\environments\parallax_space"


def extract_solid_silhouette_rgba(
    source_file: str,
    output_file: str,
    threshold: int = 4,
    closing_kernel_size: int = 11,
    min_contour_area: int = 400,
    blur_kernel_size: int = 5,
    blur_sigma: float = 1.5,
    erode_pixels: int = 1
) -> None:
    pil_img = Image.open(source_file).convert("RGB")
    rgb = np.array(pil_img, dtype=np.uint8)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)

    # 1. Umbralización para separar el fondo negro del objeto
    _, thresh = cv2.threshold(gray, threshold, 255, cv2.THRESH_BINARY)

    # 2. Cierre morfológico para unir zonas oscuras/sombras interiores con el cuerpo principal
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (closing_kernel_size, closing_kernel_size))
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

    # 3. Detección de contornos exteriores
    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    valid_contours = [c for c in contours if cv2.contourArea(c) >= min_contour_area]

    # 4. Máscara sólida: Todo el interior del contorno se rellena con opacidad total (255)
    mask = np.zeros_like(gray)
    cv2.drawContours(mask, valid_contours, -1, 255, -1)

    # 5. Defringing perimétrico: erosión submétrica para podar el halo negro residual de compresión JPEG
    if erode_pixels > 0:
        erode_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (erode_pixels * 2 + 1, erode_pixels * 2 + 1))
        mask = cv2.erode(mask, erode_kernel, iterations=1)

    # 6. Suavizado perimetral gaussiano para antialiasing de borde
    if blur_kernel_size > 0:
        mask = cv2.GaussianBlur(mask, (blur_kernel_size, blur_kernel_size), blur_sigma)

    # 7. Recomposición RGBA
    rgba = np.dstack([rgb, mask])
    out_img = Image.fromarray(rgba, mode="RGBA")
    out_img.save(output_file, format="PNG")
    print(f"[OK] Silueta sólida RGBA (defringed): {output_file}")


def build_seamless_tile(
    source_file: str, 
    output_file: str, 
    overlap_ratio: float = 0.25
) -> None:
    img = Image.open(source_file)
    original_mode = img.mode
    data = np.array(img, dtype=np.float32) / 255.0
    h, w = data.shape[:2]

    # Desfase de medio período para llevar costuras perimetrales al centro
    shift_y, shift_x = h // 2, w // 2
    rolled = np.roll(data, (shift_y, shift_x), axis=(0, 1))

    # Cálculo del margen de mezcla
    bw = int(w * overlap_ratio)
    bh = int(h * overlap_ratio)

    x = np.arange(w, dtype=np.float32)
    y = np.arange(h, dtype=np.float32)

    dx = np.abs(x - float(shift_x))
    dy = np.abs(y - float(shift_y))

    # Ventanas de decaimiento suave (Hann / Coseno)
    wx = np.clip(1.0 - (dx / (bw * 0.5)), 0.0, 1.0)
    wx = 0.5 * (1.0 + np.cos(np.pi * (1.0 - wx)))

    wy = np.clip(1.0 - (dy / (bh * 0.5)), 0.0, 1.0)
    wy = 0.5 * (1.0 + np.cos(np.pi * (1.0 - wy)))

    mask = np.maximum(wx[np.newaxis, :], wy[:, np.newaxis])
    if data.ndim == 3:
        mask = mask[..., np.newaxis]

    seamless = rolled * (1.0 - mask) + data * mask
    out_bytes = (np.clip(seamless, 0.0, 1.0) * 255.0).astype(np.uint8)

    result = Image.fromarray(out_bytes, mode=original_mode)
    result.save(output_file, format="PNG")
    print(f"[OK] Textura continua: {output_file}")


def main() -> None:
    os.makedirs(TARGET_DIR, exist_ok=True)

    mappings = [
        # Planetas (contorno exterior sólido, erosión de 2px para podar halo de compresión JPEG)
        ("Cuerpos Planetarios.jpg", "planet_0.png", "solid", 4, 15, 20000, 2),
        ("Cuerpos Planetarios 1.jpg", "planet_1.png", "solid", 4, 15, 20000, 2),
        ("Cuerpos Planetarios 2.jpg", "planet_2.png", "solid", 4, 15, 20000, 2),
        ("Cuerpos Planetarios 3.jpg", "planet_3.png", "solid", 4, 15, 20000, 2),

        # Estaciones espaciales (paneles y sombras interiores 100% sólidos, erosión de 1px)
        ("Estación Espacial Modular.jpg", "space_station_0.png", "solid", 4, 11, 10000, 1),
        ("Estación Espacial Modular 2.jpg", "space_station_1.png", "solid", 4, 11, 10000, 1),
        ("Estación Espacial Modular 3.jpg", "space_station_2.png", "solid", 4, 11, 10000, 1),

        # Atlas de restos y asteroides (cada fragmento con cuerpo de roca sólido, erosión de 1px)
        ("Atlas de Restos y Asteroides.jpg", "debris_atlas_0.png", "solid", 12, 3, 300, 1),
        ("Atlas de Restos y Asteroides 1.jpg", "debris_atlas_1.png", "solid", 12, 3, 300, 1),

        # Nebulosas
        ("Nebulosas y Polvo Cósmico.jpg", "nebula_seamless_0.png", "seamless", 0, 0, 0, 0),
        ("Nebulosas y Polvo Cósmico 1.jpg", "nebula_seamless_1.png", "seamless", 0, 0, 0, 0),
    ]

    for item in mappings:
        src_name, dst_name, mode = item[0], item[1], item[2]
        src_path = os.path.join(SOURCE_DIR, src_name)
        dst_path = os.path.join(TARGET_DIR, dst_name)

        if not os.path.exists(src_path):
            print(f"[WARN] No encontrado: {src_path}")
            continue

        if mode == "solid":
            thresh, k_size, min_area, erode_px = item[3], item[4], item[5], item[6]
            extract_solid_silhouette_rgba(
                src_path, 
                dst_path, 
                threshold=thresh, 
                closing_kernel_size=k_size, 
                min_contour_area=min_area,
                blur_kernel_size=5,
                blur_sigma=1.5,
                erode_pixels=erode_px
            )
        elif mode == "seamless":
            build_seamless_tile(src_path, dst_path, overlap_ratio=0.25)

    print("\n>>> Procesamiento de silueta sólida completado con éxito. <<<")


if __name__ == "__main__":
    main()
