#!/usr/bin/env python3
"""
tools/purify_sprite_pipeline.py
Pipeline automatizado con OpenCV y NumPy para purificación de sprites 2D / Cel-Shading:
  1. Despill & Aplanar el ruido (Edge-Preserving Bilateral + Median con protección de bordes)
  2. Forzar una paleta estricta (Cuantización perceptual vectorizada en espacio CIELAB: Curada o K-Means)
  3. Endurecer las líneas (Extracción adaptativa de tinta + silueta hard-edge sin halo sobre fondo verde plano)
"""

from __future__ import annotations
import argparse
import json
import os
from typing import Sequence
import cv2
import numpy as np


# Paleta maestra curada (RGB) para Piloto 1 (Cabello plata / Acentos carmesí / Capa oliva)
CURATED_PALETTE_HEX: list[str] = [
    # 0. Fondo Chroma Green Puro (1 solo color plano)
    "#52ab4e",
    # 1. Tinta Negra Pura (Lineart endurecido)
    "#070709",
    # 2-5. Cabello Plata / Blanco & Esclerótica
    "#f4eff7",  # Brillo máximo cabello / esclerótica (plata frío)
    "#c8c1c8",  # Base plata cabello
    "#a89fa5",  # Sombra media cabello / brillo metálico alto
    "#837981",  # Sombra profunda cabello / placa metálica clara
    # 6-8. Piel
    "#f1c8b8",  # Piel base iluminada
    "#cba4a0",  # Piel transición / rubor suave
    "#a57e80",  # Piel sombra cel-shaded
    # 9-13. Acentos Carmesí & Monóculo Rosa
    "#ac4761",  # Rosa vivo del monóculo
    "#844353",  # Rosa medio / espiral monóculo
    "#882f3f",  # Rojo carmesí base (armadura/traje)
    "#531c29",  # Rojo carmesí sombra
    "#2d0811",  # Rojo carmesí oclusión profunda
    # 14-15. Medias Semitransparentes (Sheer Stockings)
    "#815c62",  # Medias zona iluminada
    "#6b4c51",  # Medias zona base/sombra
    # 16-21. Traje, Metal Grebas/Guanteletes y Capa
    "#695e65",  # Metal iluminado (grebas/brazales)
    "#564e54",  # Gris medio traje / metal neutro
    "#463f3d",  # Gris oliva oscuro (capa base)
    "#382d33",  # Carbón frío (traje sombra / placas oscuras)
    "#2b2324",  # Sombra oscura de capa y botas
    "#21171b",  # Oclusión interior muy oscura (casi negro)
]

# Paleta maestra curada (RGB) para NYX (Cabello negro azabache / Bufanda y circuitos magenta neón / Traje índigo)
NYX_PALETTE_HEX: list[str] = [
    # 0. Fondo Chroma Green Puro (1 solo color plano)
    "#4da954",
    # 1. Tinta Negra Pura y Cabello Negro Azabache
    "#050407",
    # 2. Blanco Puro (Esclerótica / Tipografía)
    "#f7f7f9",
    # 3-5. Piel (Tonos cálidos/rosados bajo luz magenta)
    "#edc4ca",  # Piel base iluminada
    "#bd95a4",  # Piel sombra media
    "#976982",  # Piel sombra profunda / labios
    # 6-13. Bufanda de Plasma, Filo de Katana, Circuitos y Reflejos del Cabello (Rampa Magenta Neón)
    "#fa76f8",  # Rosa neón pastel (brillo máximo de bufanda y filo de katana)
    "#d052ca",  # Rosa magenta suave (transición de bufanda)
    "#f044e4",  # Magenta neón puro (núcleo vibrante de bufanda y circuitos)
    "#c937c4",  # Magenta medio (circuitos del traje y pliegues de bufanda)
    "#a934a7",  # Magenta sombra (pliegues oscuros de bufanda)
    "#832282",  # Magenta púrpura profundo (brillo especular en cabello negro)
    "#611460",  # Violeta-magenta oscuro (transición de reflejos en el cabello)
    "#3a043b",  # Púrpura abisal (oclusión de mechones del cabello)
    # 14-20. Traje Ninja Índigo / Armadura Pizarra-Violeta
    "#7f5d9b",  # Brillo especular de armadura índigo-violeta
    "#6b4f72",  # Violeta pizarra cálido (placas iluminadas)
    "#544879",  # Índigo acero base (muslos, pecho, grebas)
    "#4b3b60",  # Pizarra violeta medio (transición de placas)
    "#3c2a52",  # Índigo sombra (volumen de traje y botas)
    "#2a1f35",  # Carbón púrpura oscuro (paneles interiores del traje y empuñaduras)
    "#18061d",  # Oclusión violeta casi negra
]

PALETTE_PRESETS: dict[str, list[str]] = {
    "default": CURATED_PALETTE_HEX,
    "nyx": NYX_PALETTE_HEX,
}


def detect_best_preset(rgb: np.ndarray, fg_mask: np.ndarray) -> str:
    """Detecta automáticamente si la lámina corresponde a la paleta de Nyx (dominancia magenta/índigo) o default."""
    fg_pixels = rgb[fg_mask]
    r = fg_pixels[:, 0].astype(np.int16)
    g = fg_pixels[:, 1].astype(np.int16)
    b = fg_pixels[:, 2].astype(np.int16)
    # Píxeles magenta/púrpura fuertes: R y B altos simultáneamente respecto a G
    magenta_purple_ratio = np.mean((r - g > 30) & (b - g > 30))
    if magenta_purple_ratio > 0.12:
        return "nyx"
    return "default"


def hex_to_rgb_array(hex_list: Sequence[str]) -> np.ndarray:
    """Convierte una lista de códigos hexadecimales (#RRGGBB) a un array NumPy (N, 3) uint8."""
    rgb_list: list[tuple[int, int, int]] = []
    for h in hex_list:
        h_clean = h.lstrip("#")
        rgb_list.append((int(h_clean[0:2], 16), int(h_clean[2:4], 16), int(h_clean[4:6], 16)))
    return np.array(rgb_list, dtype=np.uint8)


def segment_and_despill_green(
    rgb: np.ndarray,
    green_excess_bg: int = 32,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Separa el fondo chroma green con precisión subpíxel y elimina el halo verde (despill)
    en los bordes del personaje propagando el color interior limpio más cercano.
    """
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)

    max_rb = np.maximum(r, b)
    min_rb = np.minimum(r, b)
    excess_g = g - max_rb

    # Píxeles de tipografía blanca nítida sobre verde (R y B altos y balanceados)
    white_text_mask = (min_rb > 155) & (np.abs(r - b) < 25) & (g >= max_rb)

    # Fondo verde franco (respetando núcleo de tipografía blanca)
    raw_bg_mask = (
        ((excess_g > green_excess_bg) & (g > 90) & (~white_text_mask))
        | ((excess_g > 14) & (g > 135) & (min_rb > 75) & (~white_text_mask))
    )

    # Eliminar únicamente motas microscópicas aisladas (<= 6 px) sin erosionar trazos finos ni letras
    fg_raw_u8 = (~raw_bg_mask).astype(np.uint8)
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(fg_raw_u8, connectivity=8)
    fg_mask = fg_raw_u8 > 0
    if num_labels > 1:
        areas = stats[:, cv2.CC_STAT_AREA]
        tiny_specks = np.isin(labels, np.where((areas <= 6) & (np.arange(num_labels) > 0))[0])
        fg_mask = fg_mask & (~tiny_specks)

    # Color verde plano canónico (mediana estadística del fondo original)
    bg_color = np.median(rgb[~fg_mask], axis=0).astype(np.uint8)

    # Despill en píxeles de borde del personaje que tienen exceso de verde
    rgb_despilled = rgb.copy()
    spill_zone = fg_mask & (excess_g > 0)

    # Suprimir el exceso de canal G y reconstruir luminancia oscura de borde
    g_clamped = np.minimum(g, max_rb).astype(np.uint8)
    rgb_despilled[:, :, 1] = np.where(spill_zone, g_clamped, rgb[:, :, 1])

    # Para píxeles de la silueta exterior contaminados por antialiasing con el fondo verde:
    # - Si eran parte del trazo negro exterior (bajo R y B), oscurecerlos hacia la línea negra
    edge_dark_spill = spill_zone & (max_rb < 75) & (excess_g > 8)
    rgb_despilled[edge_dark_spill] = np.array([5, 4, 7], dtype=np.uint8)
    # - Si eran parte de tipografía blanca, fijarlos a blanco puro
    rgb_despilled[white_text_mask & fg_mask] = np.array([247, 247, 249], dtype=np.uint8)

    return rgb_despilled, fg_mask, bg_color


def step1_flatten_noise(
    rgb_despilled: np.ndarray,
    fg_mask: np.ndarray,
    bilateral_passes: int = 3,
    d: int = 9,
    sigma_color: float = 42.0,
    sigma_space: float = 9.0,
) -> np.ndarray:
    """
    PASO 1: Aplanar el ruido (JPEG artifacts, difusión y micro-gradientes).
    Aísla únicamente los trazos de línea fina antes de aplanar las superficies con
    mediana + filtro bilateral iterativo, protegiendo tanto las sombras amplias como
    las masas de cabello negro sólido (ej. Nyx) mediante apertura morfológica.
    """
    gray = cv2.cvtColor(rgb_despilled, cv2.COLOR_RGB2GRAY).astype(np.float32)
    local_mean = cv2.GaussianBlur(gray, (0, 0), sigmaX=1.8, sigmaY=1.8)
    valley_depth = local_mean - gray

    # Distinguir masas negras amplias (cabello negro azabache) de líneas finas de tinta:
    dark_u8 = ((gray < 20.0) & fg_mask).astype(np.uint8) * 255
    kernel_5 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    wide_black_mass = cv2.morphologyEx(dark_u8, cv2.MORPH_OPEN, kernel_5) > 0

    # Solo rellenar temporalmente con inpaint las líneas finas de tinta, nunca masas sólidas de cabello negro
    thin_ink_seed = (
        (((gray < 20.0) & (~wide_black_mass)) | ((valley_depth > 7.5) & (gray < 85.0)))
        & fg_mask
    )

    valid_color_mask = fg_mask & (~thin_ink_seed)
    inpaint_mask = (~valid_color_mask).astype(np.uint8) * 255

    canvas_bgr = cv2.cvtColor(rgb_despilled, cv2.COLOR_RGB2BGR)
    padded_bgr = cv2.inpaint(canvas_bgr, inpaint_mask, inpaintRadius=2.0, flags=cv2.INPAINT_TELEA)

    # Mediana 3x3 en zonas de bajo gradiente para destruir bloques 8x8 de compresión JPEG
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    grad_mag = cv2.magnitude(gx, gy)
    flat_interior = (grad_mag < 45.0) & valid_color_mask

    median_bgr = cv2.medianBlur(padded_bgr, 3)
    work_bgr = np.where(flat_interior[:, :, None], median_bgr, padded_bgr)

    # Pasadas iterativas de Filtro Bilateral para aplanar gradientes ruidosos conservando bordes duros
    for _ in range(bilateral_passes):
        work_bgr = cv2.bilateralFilter(
            work_bgr,
            d=d,
            sigmaColor=sigma_color,
            sigmaSpace=sigma_space,
        )

    flattened_rgb = cv2.cvtColor(work_bgr, cv2.COLOR_BGR2RGB)
    return np.where(fg_mask[:, :, None], flattened_rgb, rgb_despilled)


def extract_kmeans_palette_lab(
    rgb_flattened: np.ndarray,
    fg_mask: np.ndarray,
    bg_color: np.ndarray,
    n_colors: int = 18,
) -> np.ndarray:
    """Extrae automáticamente una paleta estricta en espacio perceptual CIELAB usando K-Means++."""
    lab = cv2.cvtColor(rgb_flattened, cv2.COLOR_RGB2Lab)
    gray = cv2.cvtColor(rgb_flattened, cv2.COLOR_RGB2GRAY)
    color_mask = fg_mask & (gray >= 22)

    samples = lab[color_mask].astype(np.float32)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.25)
    _, _, centers_lab = cv2.kmeans(
        samples,
        n_colors,
        None,
        criteria,
        attempts=5,
        flags=cv2.KMEANS_PP_CENTERS,
    )
    centers_lab_u8 = np.clip(np.round(centers_lab), 0, 255).astype(np.uint8).reshape(-1, 1, 3)
    centers_rgb = cv2.cvtColor(centers_lab_u8, cv2.COLOR_Lab2RGB).reshape(-1, 3)

    ink_rgb = np.array([[7, 7, 9]], dtype=np.uint8)
    bg_rgb = bg_color.reshape(1, 3).astype(np.uint8)
    return np.vstack([bg_rgb, ink_rgb, centers_rgb])


def step2_force_strict_palette(
    rgb_flattened: np.ndarray,
    fg_mask: np.ndarray,
    palette_rgb: np.ndarray,
    min_island_area: int = 10,
) -> np.ndarray:
    """
    PASO 2: Forzar una paleta estricta en espacio perceptual CIELAB.
    Mapea cada píxel del personaje al swatch más cercano según distancia Delta-E (CIELAB)
    y limpia islas residuales de ruido por componentes conexas en zonas planas.
    """
    fill_palette_rgb = palette_rgb[2:]
    img_lab = cv2.cvtColor(rgb_flattened, cv2.COLOR_RGB2Lab).astype(np.float32)
    pal_lab = cv2.cvtColor(fill_palette_rgb.reshape(-1, 1, 3), cv2.COLOR_RGB2Lab).reshape(-1, 3).astype(np.float32)

    # En OpenCV uint8 Lab, L está escalado x2.55 (0..255 para L=0..100) mientras a,b están en escala 1:1 (+128).
    # Compensamos el factor 1/2.55 (~0.4) en L y priorizamos la fidelidad cromática (a, b) para separar piel cálida de pelo plata.
    weights = np.array([0.4, 1.8, 1.8], dtype=np.float32)
    diff = (img_lab[:, :, None, :] - pal_lab[None, None, :, :]) * weights[None, None, None, :]
    dist_sq = np.sum(diff * diff, axis=-1)
    nearest_idx = np.argmin(dist_sq, axis=-1).astype(np.uint8)

    # Limpieza de micro-islas de cuantización (escamas de ruido JPEG en sombras de capa y traje)
    if min_island_area > 1:
        # Ordenar distancias para tener el 2º mejor color de paleta como reemplazo natural
        second_best_idx = np.argsort(dist_sq, axis=-1)[:, :, 1].astype(np.uint8)
        for k in range(len(fill_palette_rgb)):
            swatch_mask = ((nearest_idx == k) & fg_mask).astype(np.uint8)
            num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(swatch_mask, connectivity=8)
            if num_labels <= 1:
                continue
            areas = stats[:, cv2.CC_STAT_AREA]
            small_labels = np.where((areas < min_island_area) & (np.arange(num_labels) > 0))[0]
            if len(small_labels) > 0:
                is_small = np.isin(labels, small_labels)
                nearest_idx[is_small] = second_best_idx[is_small]

    quantized_rgb = fill_palette_rgb[nearest_idx]
    quantized_rgb[~fg_mask] = palette_rgb[0]
    return quantized_rgb


def step3_harden_lines(
    rgb_despilled: np.ndarray,
    quantized_rgb: np.ndarray,
    fg_mask: np.ndarray,
    bg_color: np.ndarray,
    ink_color: np.ndarray,
    dark_thresh: int = 21,
    ridge_thresh: float = 7.5,
) -> np.ndarray:
    """
    PASO 3: Endurecer las líneas (Line Hardening & Silhouette Crispness).
    1. Distingue entre sombras amplias (ej. interior de capa, luminancia 25-42) y trazos de
       tinta reales (negro profundo < 21 o valles locales estrechos con Difference of Gaussians).
    2. Endurece el contorno exterior contra el fondo verde eliminando cualquier píxel
       intermedio y asegurando una silueta sólida y limpia de 1px.
    """
    gray = cv2.cvtColor(rgb_despilled, cv2.COLOR_RGB2GRAY).astype(np.float32)

    # 1. Tinta negra profunda (núcleo de líneas de entintado)
    abs_ink = (gray < float(dark_thresh)) & fg_mask

    # 2. Detector adaptativo de valles (Difference of Gaussians) en dos escalas para líneas finas y medias
    local_mean_fine = cv2.GaussianBlur(gray, (0, 0), sigmaX=1.4, sigmaY=1.4)
    local_mean_mid = cv2.GaussianBlur(gray, (0, 0), sigmaX=2.8, sigmaY=2.8)
    valley_fine = local_mean_fine - gray
    valley_mid = local_mean_mid - gray

    adaptive_ink = (
        ((valley_fine > ridge_thresh) & (gray < 105.0))
        | ((valley_mid > (ridge_thresh + 2.0)) & (gray < 68.0))
    ) & fg_mask

    # 3. Contorno exterior (silueta del personaje contra el fondo verde)
    fg_u8 = fg_mask.astype(np.uint8) * 255
    kernel_3 = np.ones((3, 3), np.uint8)
    eroded_fg = cv2.erode(fg_u8, kernel_3, iterations=1)
    outer_border_ring = (fg_u8 > 0) & (eroded_fg == 0)
    silhouette_ink = outer_border_ring & (gray < 140.0)

    ink_mask = abs_ink | adaptive_ink | silhouette_ink

    # Eliminar motas aisladas de 1-2 píxeles en la máscara de tinta
    ink_u8 = ink_mask.astype(np.uint8)
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(ink_u8, connectivity=8)
    if num_labels > 1:
        areas = stats[:, cv2.CC_STAT_AREA]
        tiny_ink = np.isin(labels, np.where((areas <= 2) & (np.arange(num_labels) > 0))[0])
        ink_mask = ink_mask & (~tiny_ink)

    final_rgb = quantized_rgb.copy()
    final_rgb[ink_mask] = ink_color
    final_rgb[~fg_mask] = bg_color
    return final_rgb


def purify_sprite_sheet(
    input_path: str,
    output_path: str,
    mode: str = "curated",
    preset: str = "auto",
    kmeans_colors: int = 18,
    bilateral_passes: int = 3,
    dark_thresh: int = 21,
    ridge_thresh: float = 7.5,
    custom_palette_hex: Sequence[str] | None = None,
) -> dict[str, int | str]:
    """Ejecuta el pipeline completo de purificación y guarda el PNG resultante sin compresión con pérdida."""
    bgr = cv2.imread(input_path, cv2.IMREAD_COLOR)
    if bgr is None:
        raise FileNotFoundError(f"No se pudo cargar la imagen: {input_path}")

    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)

    # Paso 0: Segmentación Chroma y Despill
    rgb_despilled, fg_mask, detected_bg = segment_and_despill_green(rgb)

    # Paso 1: Aplanar el ruido
    rgb_flattened = step1_flatten_noise(
        rgb_despilled,
        fg_mask,
        bilateral_passes=bilateral_passes,
    )

    # Selección de paleta (Curada con autodetección de preset vs K-Means CIELAB)
    resolved_preset = preset
    if mode == "kmeans":
        palette_rgb = extract_kmeans_palette_lab(rgb_flattened, fg_mask, detected_bg, n_colors=kmeans_colors)
    else:
        if custom_palette_hex is not None:
            hex_list = custom_palette_hex
        else:
            if preset == "auto":
                resolved_preset = detect_best_preset(rgb_despilled, fg_mask)
            hex_list = PALETTE_PRESETS.get(resolved_preset, CURATED_PALETTE_HEX)
        palette_rgb = hex_to_rgb_array(hex_list)
        # Usar el verde mediano exacto de la lámina como swatch 0
        palette_rgb[0] = detected_bg

    # Paso 2: Forzar paleta estricta en CIELAB
    quantized_rgb = step2_force_strict_palette(rgb_flattened, fg_mask, palette_rgb)

    # Paso 3: Endurecer las líneas y sellar silueta
    final_rgb = step3_harden_lines(
        rgb_despilled=rgb_despilled,
        quantized_rgb=quantized_rgb,
        fg_mask=fg_mask,
        bg_color=palette_rgb[0],
        ink_color=palette_rgb[1],
        dark_thresh=dark_thresh,
        ridge_thresh=ridge_thresh,
    )

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    final_bgr = cv2.cvtColor(final_rgb, cv2.COLOR_RGB2BGR)
    cv2.imwrite(output_path, final_bgr)

    # Verificar número real de colores únicos en el archivo final
    unique_colors_before = len(np.unique(rgb.reshape(-1, 3), axis=0))
    unique_colors_after = len(np.unique(final_rgb.reshape(-1, 3), axis=0))

    return {
        "input": input_path,
        "output": output_path,
        "width": int(rgb.shape[1]),
        "height": int(rgb.shape[0]),
        "mode": f"{mode}:{resolved_preset}" if mode == "curated" else mode,
        "unique_colors_before": int(unique_colors_before),
        "unique_colors_after": int(unique_colors_after),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Pipeline OpenCV + NumPy para purificar sprites: aplanar ruido, paleta estricta y endurecer líneas."
    )
    parser.add_argument("input", help="Ruta de la imagen de entrada (.jpg / .png)")
    parser.add_argument("output", help="Ruta de la imagen PNG purificada de salida")
    parser.add_argument(
        "--mode",
        choices=["curated", "kmeans"],
        default="curated",
        help="Modo de paleta estricta: 'curated' (paleta explícita) o 'kmeans' (automático en CIELAB)",
    )
    parser.add_argument(
        "--preset",
        choices=["auto", "default", "nyx"],
        default="auto",
        help="Preset de paleta curada ('auto' detecta automáticamente el personaje por su firma cromática)",
    )
    parser.add_argument("--colors", type=int, default=18, help="Número de colores de relleno en modo kmeans")
    parser.add_argument("--bilateral-passes", type=int, default=3, help="Pasadas de filtro bilateral")
    parser.add_argument("--dark-thresh", type=int, default=21, help="Umbral de luminancia para tinta negra (0-255)")
    parser.add_argument("--ridge-thresh", type=float, default=7.5, help="Sensibilidad de líneas finas adaptativas")
    parser.add_argument("--palette-json", type=str, default=None, help="Archivo JSON opcional con lista de colores #HEX")

    args = parser.parse_args()
    custom_hex = None
    if args.palette_json:
        with open(args.palette_json, "r", encoding="utf-8") as f:
            custom_hex = json.load(f)

    stats = purify_sprite_sheet(
        input_path=args.input,
        output_path=args.output,
        mode=args.mode,
        preset=args.preset,
        kmeans_colors=args.colors,
        bilateral_passes=args.bilateral_passes,
        dark_thresh=args.dark_thresh,
        ridge_thresh=args.ridge_thresh,
        custom_palette_hex=custom_hex,
    )
    print(
        f"[OK] Purificación completada ({stats['mode']}): "
        f"{stats['unique_colors_before']} colores ruidosos -> {stats['unique_colors_after']} colores exactos. "
        f"Guardado en: {stats['output']}"
    )


if __name__ == "__main__":
    main()
