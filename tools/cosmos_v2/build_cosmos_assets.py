#!/usr/bin/env python3
"""
Compilador Offline Completo de Assets v2.5 para Cosmos Engine.

Incluye:
- Ingesta automática desde artifacts/ y sandbox/temp/ -> assets/environments/cosmos_v2/raw/.
- Hito 1 + Expansión (10 planetas 1024x512, 3 lunas 1024x512, 3 anillos polares 512x128).
- Hito 2 + Expansión (4 estrellas/anomalías 1024x1024, 2 nebulosas 2D seamless, 4 landmarks RGBA).
- Hito 3 + Mega-Atlas Debris (3 estaciones 512x512, 2 mega-atlas 2048x2048 con 20 siluetas totales -> 60 slices).
"""

from __future__ import annotations

import argparse
import json
import math
from collections import deque
from pathlib import Path
from typing import Callable, Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageOps


ROOT_DIR = Path(__file__).resolve().parents[2]
ARTIFACT_DIR = Path(r"C:\Users\Aimol\.gemini\antigravity\brain\0ccb0d87-da01-45d1-aae9-fcfaac56e210")
TEMP_DIR = ROOT_DIR / "sandbox" / "temp"
COSMOS_V2_DIR = ROOT_DIR / "assets" / "environments" / "cosmos_v2"
RAW_DIR = COSMOS_V2_DIR / "raw"
PLANETS_DIR = COSMOS_V2_DIR / "planets"
MOONS_DIR = COSMOS_V2_DIR / "moons"
RINGS_DIR = COSMOS_V2_DIR / "rings"
STARS_DIR = COSMOS_V2_DIR / "stars"
NEBULAE_DIR = COSMOS_V2_DIR / "nebulae"
LANDMARKS_DIR = COSMOS_V2_DIR / "landmarks"
STATIONS_DIR = COSMOS_V2_DIR / "stations"
DEBRIS_DIR = COSMOS_V2_DIR / "debris"

DEFAULT_SHEET_OUT = ARTIFACT_DIR / "scratch" / "cosmos_v2_hito1_assets_sheet.png"
SHEET_H23_OUT = ARTIFACT_DIR / "scratch" / "cosmos_v2_hito23_assets_sheet.png"
SHEET_V25_OUT = ARTIFACT_DIR / "scratch" / "cosmos_v25_new_assets_sheet.png"

EQ_W = 1024
EQ_H = 512
RING_W = 512
RING_H = 128

ARTIFACT_INGEST_MAP: Dict[str, str] = {
    "planet_volcanic_forge_raw.png": "planet_volcanic_forge_raw_v3_1795327147406.jpg",
    "planet_arid_canyon_raw.png": "planet_arid_canyon_raw_v2_1795327125581.jpg",
    "planet_oceanic_paradise_raw.png": "planet_oceanic_paradise_raw_v3_1795327150768.jpg",
    "planet_cyber_ecumenopolis_raw.png": "planet_cyber_ecumenopolis_raw_1795327106504.jpg",
    "planet_gas_giant_storm_raw.png": "planet_gas_giant_storm_raw_1795327106080.jpg",
    "planet_cryo_crystal_raw.png": "planet_cryo_crystal_raw_v3_1795327167142.jpg",
    "planet_clouds_anime_raw.png": "planet_clouds_anime_raw_1795327176493.jpg",
    # --- v2.5 Expansión (+10 assets) ---
    "debris_crystals_atlas_raw.png": "debris_crystals_atlas_raw_1795361585195.jpg",
    "debris_warship_wrecks_atlas_raw.png": "debris_warship_wrecks_atlas_raw_1795361610985.jpg",
    "debris_volcanic_ice_atlas_raw.png": "debris_volcanic_ice_atlas_raw_1795361592477.jpg",
    "planet_shattered_core_raw.png": "planet_shattered_core_raw_1795361594148.jpg",
    "planet_biolum_jungle_raw.png": "planet_biolum_jungle_raw_1795361625329.jpg",
    "planet_crimson_gas_giant_raw.png": "planet_crimson_gas_giant_raw_1795361822070.jpg",
    "planet_relic_dyson_raw.png": "planet_relic_dyson_raw_1795361825076.jpg",
    "star_black_hole_singularity_raw.png": "star_black_hole_singularity_raw_1795361827698.jpg",
    "star_emerald_nova_raw.png": "star_emerald_nova_raw_1795361829548.jpg",
    "ring_plasma_nebula_raw.png": "ring_plasma_nebula_raw_1795361834757.jpg",
    # --- v3.0 Estrellas y Supernova Remnant AAA ---
    "star_yellow_dwarf_v3_raw.png": "star_yellow_dwarf_v3_raw_1795379186492.jpg",
    "star_red_dwarf_v3_raw.png": "star_red_dwarf_v3_raw_1795379137889.jpg",
    "star_blue_giant_v3_raw.png": "star_blue_giant_v3_raw_1795379138928.jpg",
    "star_white_dwarf_v3_raw.png": "star_white_dwarf_v3_raw_1795379186836.jpg",
    "star_magnetar_v3_raw.png": "star_magnetar_v3_raw_1795379149186.jpg",
    "landmark_supernova_remnant_v3_raw.png": "landmark_supernova_remnant_v3_raw_1795379171214.jpg",
}

TEMP_INGEST_MAP: Dict[str, str] = {
    "moon_crater_raw.png": "Gemini_Generated_Image_78sum278sum278su.jpg",
    "moon_magma_raw.png": "Gemini_Generated_Image_b2dyob2dyob2dyob.jpg",
    "moon_cryo_raw.png": "Gemini_Generated_Image_uvbyujuvbyujuvby.jpg",
    "ring_crystal_ice_raw.png": "Gemini_Generated_Image_dc1y6bdc1y6bdc1y.jpg",
    "ring_gold_debris_raw.png": "Gemini_Generated_Image_ea3uxpea3uxpea3u.jpg",
    "star_photosphere_warm_raw.png": "Gemini_Generated_Image_smc03ysmc03ysmc0.jpg",
    "star_photosphere_blue_raw.png": "Gemini_Generated_Image_jbbpxsjbbpxsjbbp.jpg",
    "nebula_anime_filaments_raw.png": "Gemini_Generated_Image_9g52o69g52o69g52.jpg",
    "nebula_anime_wisps_raw.png": "Gemini_Generated_Image_5x71lz5x71lz5x71.jpg",
    "landmark_spiral_galaxy_raw.png": "Gemini_Generated_Image_xa9s4xa9s4xa9s4x.jpg",
    "landmark_supernova_remnant_raw.png": "Gemini_Generated_Image_yvh4d8yvh4d8yvh4.jpg",
    "landmark_dust_pillars_raw.png": "Gemini_Generated_Image_gpkrf2gpkrf2gpkr.jpg",
    "landmark_edge_galaxy_raw.png": "Gemini_Generated_Image_qsytn7qsytn7qsyt.jpg",
    "station_ring_citadel_raw.png": "Gemini_Generated_Image_7w57hx7w57hx7w57.jpg",
    "station_spire_relay_raw.png": "Gemini_Generated_Image_pdrwu7pdrwu7pdrw.jpg",
    "station_shipyard_dock_raw.png": "Gemini_Generated_Image_jx3k40jx3k40jx3k.jpg",
    "debris_asteroids_atlas_raw.png": "Gemini_Generated_Image_mwlyhsmwlyhsmwly.jpg",
    "debris_mecha_ruins_atlas_raw.png": "Gemini_Generated_Image_kmpsq0kmpsq0kmps.jpg",
}


def _ensure_dirs() -> None:
    for d in (
        RAW_DIR,
        PLANETS_DIR,
        MOONS_DIR,
        RINGS_DIR,
        STARS_DIR,
        NEBULAE_DIR,
        LANDMARKS_DIR,
        STATIONS_DIR,
        DEBRIS_DIR,
    ):
        d.mkdir(parents=True, exist_ok=True)


def _ingest_dir(src_dir: Path, mapping: Dict[str, str]) -> None:
    if not src_dir.exists():
        return
    for raw_name, src_name in mapping.items():
        dst = RAW_DIR / raw_name
        src = src_dir / src_name
        if not dst.exists() and src.exists():
            Image.open(src).convert("RGB").save(dst, format="PNG")
            print(f"[INGEST] {src.name} -> {dst.relative_to(ROOT_DIR)}")


def _norm_01(x: np.ndarray) -> np.ndarray:
    return np.clip(x, 0.0, 1.0)


def _smoothstep(edge0: float, edge1: float, x: np.ndarray | float) -> np.ndarray | float:
    t = np.clip((x - edge0) / max(edge1 - edge0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _box_blur(arr: np.ndarray, radius: int, passes: int = 2) -> np.ndarray:
    if radius <= 0:
        return arr
    out = arr.astype(np.float32, copy=True)
    k = 2 * radius + 1
    for _ in range(passes):
        pad_x = np.concatenate([out[:, -radius:], out, out[:, :radius]], axis=1)
        csum_x = np.cumsum(np.pad(pad_x, ((0, 0), (1, 0)), mode="constant"), axis=1)
        out = (csum_x[:, k:] - csum_x[:, :-k]) / float(k)

        pad_y = np.pad(out, ((radius, radius), (0, 0)), mode="edge")
        csum_y = np.cumsum(np.pad(pad_y, ((1, 0), (0, 0)), mode="constant"), axis=0)
        out = (csum_y[k:, :] - csum_y[:-k, :]) / float(k)
    return out


# ==============================================================================
# PLANETAS, LUNAS Y ANILLOS POLARES
# ==============================================================================

def _tectonic_scramble_equirectangular(arr: np.ndarray) -> np.ndarray:
    h, w, _ = arr.shape
    flipped = np.flipud(arr)
    rolled = np.roll(flipped, w // 3, axis=1)

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / float(w)
    v = yy / float(max(h - 1, 1))

    du = 0.085 * np.sin(2.0 * np.pi * v) + 0.055 * np.cos(4.0 * np.pi * u + 1.3)
    dv = 0.08 * np.sin(4.0 * np.pi * u + 0.7) * np.sin(np.pi * v)

    u_src = np.mod(u + du, 1.0) * float(w)
    v_src = np.clip(v + dv, 0.0, 1.0) * float(max(h - 1, 1))

    x0 = np.floor(u_src).astype(np.int32) % w
    x1 = (x0 + 1) % w
    fx = (u_src - np.floor(u_src))[:, :, None]

    y0 = np.clip(np.floor(v_src).astype(np.int32), 0, h - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    fy = (v_src - y0.astype(np.float32))[:, :, None]

    warped = (
        (rolled[y0, x0] * (1.0 - fx) + rolled[y0, x1] * fx) * (1.0 - fy)
        + (rolled[y1, x0] * (1.0 - fx) + rolled[y1, x1] * fx) * fy
    )
    return np.clip(warped, 0.0, 255.0)


def _make_seamless_equirectangular(
    img: Image.Image, w: int = EQ_W, h: int = EQ_H, apply_tectonic_scramble: bool = False
) -> np.ndarray:
    resized = img.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    arr = np.asarray(resized, dtype=np.float32)

    if apply_tectonic_scramble:
        arr = _tectonic_scramble_equirectangular(arr)

    rolled = np.roll(arr, w // 2, axis=1)
    xs = np.linspace(0.0, 1.0, w, endpoint=False, dtype=np.float32)
    band = 0.14
    dist_seam = np.minimum(xs, 1.0 - xs)
    t = np.clip(dist_seam / band, 0.0, 1.0)
    w_orig = (0.5 - 0.5 * np.cos(np.pi * t))[None, :, None]
    blended = arr * w_orig + rolled * (1.0 - w_orig)

    polar_rows = max(4, int(round(h * 0.06)))
    top_mean = blended[:polar_rows].mean(axis=1, keepdims=True)
    bot_mean = blended[-polar_rows:].mean(axis=1, keepdims=True)
    for r in range(polar_rows):
        alpha = 0.88 * (1.0 - r / float(polar_rows))
        blended[r] = blended[r] * (1.0 - alpha) + top_mean[r] * alpha
        blended[h - 1 - r] = blended[h - 1 - r] * (1.0 - alpha) + bot_mean[polar_rows - 1 - r] * alpha

    return np.clip(blended, 0.0, 255.0)


def _build_clouds_base() -> np.ndarray:
    fp = RAW_DIR / "planet_clouds_anime_raw.png"
    eq = _make_seamless_equirectangular(Image.open(fp)) / 255.0
    luma = 0.299 * eq[:, :, 0] + 0.587 * eq[:, :, 1] + 0.114 * eq[:, :, 2]
    return np.power(_norm_01((luma - 0.10) / 0.62), 1.12)


def _compute_bump(rgb_01: np.ndarray, strength_scale: float = 1.0, invert_craters: bool = False) -> np.ndarray:
    luma = 0.299 * rgb_01[:, :, 0] + 0.587 * rgb_01[:, :, 1] + 0.114 * rgb_01[:, :, 2]
    low_freq = _box_blur(luma, radius=14, passes=2)
    detail = luma - low_freq * 0.45
    if invert_craters:
        detail = detail * 1.15
    d_min = float(np.percentile(detail, 2.0))
    d_max = float(np.percentile(detail, 98.0))
    norm_d = _norm_01((detail - d_min) / max(d_max - d_min, 1e-4))
    return np.clip(18.0 + (norm_d * strength_scale + 0.5 * (1.0 - strength_scale)) * 220.0, 16.0, 240.0)


def _cyl_grad(field: np.ndarray, step: int) -> Tuple[np.ndarray, np.ndarray]:
    gx = (np.roll(field, -step, axis=1) - np.roll(field, step, axis=1)) / float(2 * step)
    padded = np.pad(field, ((step, step), (0, 0)), mode="edge")
    gy = (padded[2 * step :, :] - padded[: field.shape[0], :]) / float(2 * step)
    return gx, gy * 0.5


def _compile_normal_ao_map(height_u8: np.ndarray, spec_01: np.ndarray, body_name: str) -> np.ndarray:
    """Genera mapa tangente Normal.xy (RG) + Cavity Ambient Occlusion (B) sin costuras cilíndricas."""
    h = height_u8.astype(np.float32) / 255.0
    if "oceanic" in body_name or "biolum" in body_name:
        h = h * (1.0 - spec_01 * 0.70)

    is_gas = "gas_giant" in body_name
    if is_gas:
        strength = 2.8
        w_fine, w_med, w_mac = 0.15, 0.45, 0.40
    elif "oceanic" in body_name or "biolum" in body_name:
        strength = 5.0
        w_fine, w_med, w_mac = 0.42, 0.36, 0.22
    else:
        strength = 6.2
        w_fine, w_med, w_mac = 0.42, 0.36, 0.22

    h_med = _box_blur(h, radius=2, passes=1)
    h_mac = _box_blur(h, radius=6, passes=2)

    fx, fy = _cyl_grad(h, 1)
    mx, my = _cyl_grad(h_med, 3)
    lx, ly = _cyl_grad(h_mac, 7)

    gx = fx * w_fine + mx * w_med + lx * w_mac
    gy = fy * w_fine + my * w_med + ly * w_mac

    # Atenuación suave hacia los polos para evitar pellizcos en proyección equirectangular
    yy = (np.arange(h.shape[0], dtype=np.float32) + 0.5) / float(h.shape[0])
    pole_atten = np.power(np.sin(np.pi * yy), 0.65)[:, None]

    nx = -gx * strength * pole_atten
    ny = -gy * strength * pole_atten
    nz = np.ones_like(nx, dtype=np.float32)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nx *= inv_len
    ny *= inv_len

    # Cavity / Ambient Occlusion multi-escala en el canal Azul
    local_avg = _box_blur(h, radius=6, passes=2) * 0.58 + _box_blur(h, radius=16, passes=2) * 0.42
    cavity = np.clip(1.0 + (h - local_avg) * (1.5 if is_gas else 3.2), 0.36, 1.0)

    out_rgb = np.zeros((h.shape[0], h.shape[1], 3), dtype=np.uint8)
    out_rgb[:, :, 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0.0, 255.0).astype(np.uint8)
    out_rgb[:, :, 1] = np.clip((ny * 0.5 + 0.5) * 255.0, 0.0, 255.0).astype(np.uint8)
    out_rgb[:, :, 2] = np.clip(cavity * 255.0, 0.0, 255.0).astype(np.uint8)
    return out_rgb


def _extract_volcanic(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    warm = (r - b) * 1.35 + (r + g * 0.55 - 0.55)
    emissive = np.maximum(_norm_01((warm - 0.22) / 0.58), _norm_01((r - 0.68) * (1.0 - b * 0.6) / 0.28))
    emissive = np.power(emissive, 1.25)
    spec = _norm_01((b + 0.15 - r) * 0.25) * 0.20
    return np.roll(clouds, 110, axis=1) * 0.55, emissive, spec, _compute_bump(rgb_01, strength_scale=0.95)


def _extract_arid_canyon(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, _g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    salt_mask = _norm_01((b - r * 0.65) / 0.28) * 0.55
    return np.roll(clouds, 260, axis=1) * 0.45, np.zeros_like(r), salt_mask, _compute_bump(rgb_01, strength_scale=1.0)


def _extract_oceanic(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    water_score = np.minimum(b - r * 1.10, b - g * 0.82)
    spec = _box_blur(_norm_01((water_score - 0.03) / 0.16), radius=1, passes=1)

    blurred_w = _box_blur(spec, radius=5, passes=2)
    coast = np.clip(4.0 * blurred_w * (1.0 - blurred_w), 0.0, 1.0)
    land = _norm_01(1.0 - spec * 1.4)
    yy, xx = np.mgrid[0:EQ_H, 0:EQ_W].astype(np.float32)
    u = xx / EQ_W * np.pi * 2.0
    v = yy / EQ_H * np.pi
    grid_a = np.power(
        0.5 + 0.5 * np.sin(u * 26.0 + np.cos(v * 18.0) * 2.2) * np.cos(v * 22.0 + np.sin(u * 14.0) * 1.8), 3.0
    )
    grid_b = np.power(0.5 + 0.5 * np.sin(u * 58.0 - v * 42.0) * np.cos(v * 48.0 + u * 31.0), 4.0)
    equator_mask = np.clip(1.0 - np.abs(v / np.pi - 0.5) * 2.2, 0.0, 1.0)
    city_lights = np.power(_norm_01((coast * 1.15 + land * 0.35) * (grid_a * 0.75 + grid_b * 1.15) * equator_mask * 1.8), 1.15)
    return np.roll(clouds, 410, axis=1), city_lights, spec, _compute_bump(rgb_01, strength_scale=0.80)


def _extract_cyber(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    emissive = np.power(_norm_01(((max_c - 0.42) * 1.35 + ((max_c - min_c) - 0.18) * 1.15)), 1.30)
    spec = _norm_01((luma - 0.14) / 0.35) * (1.0 - emissive * 0.75) * 0.85
    return np.roll(clouds, 620, axis=1) * 0.38, emissive, spec, _compute_bump(rgb_01, strength_scale=1.0)


def _extract_gas_giant(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    luma = 0.299 * rgb_01[:, :, 0] + 0.587 * rgb_01[:, :, 1] + 0.114 * rgb_01[:, :, 2]
    return np.roll(clouds, 790, axis=1) * 0.65, np.zeros_like(luma), _norm_01((luma - 0.52) / 0.40) * 0.28, _compute_bump(rgb_01, strength_scale=0.55)


def _extract_cryo(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    cyan_rift = _norm_01((g + b - 2.0 * r - 0.25) / 0.55) * _norm_01((luma - 0.35) / 0.40)
    amethyst_rift = _norm_01((r + b - 2.0 * g - 0.15) / 0.45) * _norm_01((b - 0.55) / 0.35)
    crystal_glow = np.power(_norm_01(np.maximum(cyan_rift, amethyst_rift * 1.15)), 1.15)
    spec = _norm_01((luma - 0.35) / 0.45) * 0.92
    return np.roll(clouds, 910, axis=1) * 0.48, crystal_glow, spec, _compute_bump(rgb_01, strength_scale=0.90)


def _extract_shattered_core(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    sat = max_c - min_c
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    # Grietas violeta/magenta/oro incandescentes excluyendo placas oscuras de basalto
    emissive = _norm_01((luma - 0.32) / 0.38 + (sat - 0.30) * 0.45) * _norm_01((np.maximum(r, b) - 0.34) / 0.32)
    emissive = np.power(emissive, 1.12)
    spec = _norm_01((0.36 - luma) / 0.25) * 0.18
    return np.roll(clouds, 210, axis=1) * 0.32, emissive, spec, _compute_bump(rgb_01, strength_scale=1.0)


def _extract_biolum_jungle(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    sat = max_c - min_c
    # Ríos cian bioluminiscentes y arboledas magenta brillantes
    bio_glow = _norm_01((max_c - 0.40) / 0.38) * _norm_01((sat - 0.14) / 0.32)
    bio_glow = np.power(bio_glow, 1.10)
    # Océanos profundos zafiro reciben especular limpio excluyendo bosques
    water_score = np.minimum(b - r * 1.10, b - g * 0.78)
    spec = _box_blur(_norm_01((water_score - 0.05) / 0.13) * (1.0 - bio_glow * 0.65) * 0.80, radius=1, passes=1)
    return np.roll(clouds, 520, axis=1) * 0.72, bio_glow, spec, _compute_bump(rgb_01, strength_scale=0.82)


def _extract_crimson_gas(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    luma = 0.299 * rgb_01[:, :, 0] + 0.587 * rgb_01[:, :, 1] + 0.114 * rgb_01[:, :, 2]
    return np.roll(clouds, 680, axis=1) * 0.44, np.zeros_like(luma), _norm_01((luma - 0.55) / 0.38) * 0.24, _compute_bump(rgb_01, strength_scale=0.52)


def _extract_relic_dyson(rgb_01: np.ndarray, clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    turq_score = (g + b) * 0.5 - r
    glyph_glow = _norm_01((turq_score - 0.34) / 0.35) * _norm_01((luma - 0.46) / 0.32)
    glyph_glow = np.power(glyph_glow, 1.08)
    gold_plate = _norm_01((r - b - 0.22) / 0.32) * 0.88
    sapphire_basin = _norm_01((b - r - 0.14) / 0.24) * 0.72
    spec = np.clip(np.maximum(gold_plate, sapphire_basin) * (1.0 - glyph_glow * 0.4), 0.0, 0.92)
    return np.roll(clouds, 830, axis=1) * 0.26, glyph_glow, spec, _compute_bump(rgb_01, strength_scale=0.95)


def _extract_moon_crater(rgb_01: np.ndarray, _clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    z = np.zeros((EQ_H, EQ_W), dtype=np.float32)
    return z, z, z + 0.08, _compute_bump(rgb_01, strength_scale=0.90, invert_craters=True)


def _extract_moon_magma(rgb_01: np.ndarray, _clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    warm = (r - b) * 1.45 + (r + g * 0.48 - 0.48)
    emissive = np.maximum(_norm_01((warm - 0.16) / 0.52), _norm_01((r - 0.65) * (1.0 - b * 0.55) / 0.28))
    emissive = np.power(emissive, 1.10)
    z = np.zeros((EQ_H, EQ_W), dtype=np.float32)
    return z, emissive, z + 0.08, _compute_bump(rgb_01, strength_scale=0.88)


def _extract_moon_cryo(rgb_01: np.ndarray, _clouds: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb_01[:, :, 0], rgb_01[:, :, 1], rgb_01[:, :, 2]
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    cyan_rift = _norm_01((g + b - 2.0 * r - 0.26) / 0.48) * _norm_01((luma - 0.30) / 0.45)
    amethyst_rift = _norm_01((r + b - 2.0 * g - 0.14) / 0.40) * _norm_01((b - 0.48) / 0.40)
    emissive = np.power(_norm_01(np.maximum(cyan_rift, amethyst_rift * 1.15)), 1.05)
    spec = _norm_01((b - 0.25) / 0.55) * (1.0 - emissive * 0.35) * 0.90
    z = np.zeros((EQ_H, EQ_W), dtype=np.float32)
    return z, emissive, spec, _compute_bump(rgb_01, strength_scale=0.85)


BODY_SPECS: Dict[str, Tuple[Path, str, Callable]] = {
    "planet_volcanic_forge": (PLANETS_DIR, "planet_volcanic_forge_raw.png", _extract_volcanic),
    "planet_arid_canyon": (PLANETS_DIR, "planet_arid_canyon_raw.png", _extract_arid_canyon),
    "planet_oceanic_paradise": (PLANETS_DIR, "planet_oceanic_paradise_raw.png", _extract_oceanic),
    "planet_cyber_ecumenopolis": (PLANETS_DIR, "planet_cyber_ecumenopolis_raw.png", _extract_cyber),
    "planet_gas_giant_storm": (PLANETS_DIR, "planet_gas_giant_storm_raw.png", _extract_gas_giant),
    "planet_cryo_crystal": (PLANETS_DIR, "planet_cryo_crystal_raw.png", _extract_cryo),
    "planet_shattered_core": (PLANETS_DIR, "planet_shattered_core_raw.png", _extract_shattered_core),
    "planet_biolum_jungle": (PLANETS_DIR, "planet_biolum_jungle_raw.png", _extract_biolum_jungle),
    "planet_crimson_gas_giant": (PLANETS_DIR, "planet_crimson_gas_giant_raw.png", _extract_crimson_gas),
    "planet_relic_dyson": (PLANETS_DIR, "planet_relic_dyson_raw.png", _extract_relic_dyson),
    "moon_crater": (MOONS_DIR, "moon_crater_raw.png", _extract_moon_crater),
    "moon_magma": (MOONS_DIR, "moon_magma_raw.png", _extract_moon_magma),
    "moon_cryo": (MOONS_DIR, "moon_cryo_raw.png", _extract_moon_cryo),
}


def compile_ring_polar(raw_name: str, out_name: str) -> Path:
    fp = RAW_DIR / raw_name
    out_path = RINGS_DIR / out_name
    raw_img = Image.open(fp).convert("RGB")
    arr = np.asarray(raw_img, dtype=np.float32) / 255.0
    h, w, _ = arr.shape
    luma = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]

    yy_i, xx_i = np.mgrid[0:h, 0:w].astype(np.float32)
    active = luma > 0.07
    if active.any():
        cx = float((xx_i[active].min() + xx_i[active].max()) * 0.5)
        cy = float((yy_i[active].min() + yy_i[active].max()) * 0.5)
    else:
        cx, cy = w * 0.5, h * 0.5

    r_map = np.sqrt((xx_i - cx) ** 2 + (yy_i - cy) ** 2)
    max_half = min(cx, cy, w - cx, h - cy)
    valid_r = r_map[active & (r_map > max_half * 0.22) & (r_map < max_half * 0.99)]
    if valid_r.size > 64:
        r_in = float(np.percentile(valid_r, 1.0))
        r_out = float(np.percentile(valid_r, 99.3))
    else:
        r_in = max_half * 0.44
        r_out = max_half * 0.94
    r_out = max(r_out, r_in + 16.0)

    xs = np.linspace(r_in, r_out, RING_W, dtype=np.float32)[None, :]
    thetas = np.linspace(0.0, np.pi * 2.0, RING_H, endpoint=False, dtype=np.float32)[:, None]
    sx = np.clip(np.round(cx + xs * np.cos(thetas)).astype(np.int32), 0, w - 1)
    sy = np.clip(np.round(cy + xs * np.sin(thetas)).astype(np.int32), 0, h - 1)
    polar_rgb = arr[sy, sx]

    radial_profile = np.median(polar_rgb, axis=0, keepdims=True)
    azim = np.clip(0.58 * radial_profile + 0.42 * polar_rgb, 0.0, 1.0)

    p_luma = 0.299 * azim[:, :, 0] + 0.587 * azim[:, :, 1] + 0.114 * azim[:, :, 2]
    p_max = np.max(azim, axis=2)
    alpha = _norm_01((np.maximum(p_luma, p_max * 0.78) - 0.045) / 0.36)
    alpha = np.power(alpha, 0.80)
    u_x = np.linspace(0.0, 1.0, RING_W, dtype=np.float32)[None, :]
    edge_fade = np.clip(u_x / 0.045, 0.0, 1.0) * np.clip((1.0 - u_x) / 0.045, 0.0, 1.0)
    alpha *= edge_fade

    rgb_clean = np.clip(azim / np.maximum(alpha[:, :, None] * 0.65 + 0.35, 0.22), 0.0, 1.0)

    out_rgba = np.zeros((RING_H, RING_W, 4), dtype=np.uint8)
    out_rgba[:, :, :3] = np.clip(rgb_clean * 255.0, 0.0, 255.0).astype(np.uint8)
    out_rgba[:, :, 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    Image.fromarray(out_rgba, mode="RGBA").save(out_path)
    return out_path


# ==============================================================================
# ESTRELLAS, NEBULOSAS SEAMLESS Y LANDMARKS
# ==============================================================================

def _compile_star_photosphere(raw_name: str, out_name: str, pad_ratio: float = 0.0, fade_start: float = 0.45) -> Path:
    fp = RAW_DIR / raw_name
    out_path = STARS_DIR / out_name
    im = Image.open(fp).convert("RGB")
    if pad_ratio > 0.0:
        pad_px = int(round(max(im.size) * pad_ratio))
        im = ImageOps.expand(im, border=pad_px, fill=(0, 0, 0))
    im = im.resize((1024, 1024), Image.Resampling.LANCZOS)
    arr = np.asarray(im, dtype=np.float32)

    arr_clean = np.clip((arr - 3.5) * (255.0 / 251.5), 0.0, 255.0)
    luma = 0.299 * arr_clean[:, :, 0] + 0.587 * arr_clean[:, :, 1] + 0.114 * arr_clean[:, :, 2]
    clean_mask = _smoothstep(3.0, 14.0, luma)
    yy, xx = np.mgrid[0:1024, 0:1024].astype(np.float32)
    r = np.sqrt(((xx + 0.5) / 1024.0 - 0.5) ** 2 + ((yy + 0.5) / 1024.0 - 0.5) ** 2)
    radial_fade = 1.0 - _smoothstep(fade_start, 0.495, r)
    out = np.clip(arr_clean * (clean_mask * radial_fade)[:, :, None], 0.0, 255.0).astype(np.uint8)
    Image.fromarray(out, mode="RGB").save(out_path)
    return out_path


def _make_seamless_2d_nebula(raw_name: str, out_name: str, size: int = 1024) -> Path:
    fp = RAW_DIR / raw_name
    out_path = NEBULAE_DIR / out_name
    im = Image.open(fp).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0
    luma = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    luma = np.power(_norm_01((luma - 0.028) / 0.94), 1.04)

    coord = np.linspace(0.0, 1.0, size, endpoint=False, dtype=np.float32)
    band = 0.18
    dist_x = np.minimum(coord, 1.0 - coord)
    wx = (0.5 - 0.5 * np.cos(np.pi * np.clip(dist_x / band, 0.0, 1.0)))[None, :]
    pass_x = luma * wx + np.roll(luma, size // 2, axis=1) * (1.0 - wx)

    wy = wx.T
    seamless = pass_x * wy + np.roll(pass_x, size // 2, axis=0) * (1.0 - wy)

    u8 = np.clip(seamless * 255.0, 0.0, 255.0).astype(np.uint8)
    rgb = np.stack([u8, u8, u8], axis=2)
    Image.fromarray(rgb, mode="RGB").save(out_path)
    return out_path


def _compile_landmark_rgba(
    raw_name: str,
    out_name: str,
    size: int = 1024,
    mode: str = "luminous",
    pad_ratio: float = 0.0,
) -> Path:
    fp = RAW_DIR / raw_name
    out_path = LANDMARKS_DIR / out_name
    im = Image.open(fp).convert("RGB")
    if pad_ratio > 0.0:
        pad_px = int(round(max(im.size) * pad_ratio))
        im = ImageOps.expand(im, border=pad_px, fill=(0, 0, 0))
    im = im.resize((size, size), Image.Resampling.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0

    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt(((xx + 0.5) / float(size) - 0.5) ** 2 + ((yy + 0.5) / float(size) - 0.5) ** 2)
    radial_fade = 1.0 - _smoothstep(0.43, 0.494, r)

    if mode == "dust_pillar":
        rgb_u8 = np.clip(arr * 255.0, 0.0, 255.0).astype(np.uint8)
        max_u8 = np.max(rgb_u8, axis=2)
        bg_cand = max_u8 < 22
        ext_bg = _flood_fill_mask(bg_cand, seeds_from_edges=True)
        fg_mask = (~ext_bg)
        fg_mask = _remove_large_dark_pockets(rgb_u8, fg_mask, pocket_thresh=14, min_area=96)
        alpha = _box_blur(fg_mask.astype(np.float32), radius=1, passes=1)
        alpha = _smoothstep(0.18, 0.92, alpha)
        fade_bottom = 1.0 - _smoothstep(0.84, 0.985, (yy + 0.5) / float(size))
        alpha *= radial_fade * fade_bottom

        # Color-bleed desde el interior hacia bordes semitransparentes para evitar halos negros
        bleed = arr.copy()
        valid_fg = fg_mask & (max_u8 >= 20)
        for _ in range(3):
            blur_rgb = np.stack([_box_blur(bleed[:, :, c], radius=2, passes=1) for c in range(3)], axis=2)
            bleed = np.where(valid_fg[:, :, None], arr, blur_rgb)
        rgb_clean = np.where(alpha[:, :, None] > 0.02, np.where(valid_fg[:, :, None], arr, bleed), 0.0)
    else:
        arr_clean = np.clip((arr - 0.036) / 0.964, 0.0, 1.0)
        luma = 0.299 * arr_clean[:, :, 0] + 0.587 * arr_clean[:, :, 1] + 0.114 * arr_clean[:, :, 2]
        max_c = np.max(arr_clean, axis=2)
        val = np.maximum(luma * 0.85, max_c)
        alpha = np.power(_norm_01((val - 0.018) / 0.30), 0.90) * radial_fade
        rgb_clean = np.where(
            alpha[:, :, None] > 0.02,
            np.clip(arr_clean / np.maximum(alpha[:, :, None], 0.10), 0.0, 1.0),
            0.0,
        )

    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(rgb_clean * 255.0, 0.0, 255.0).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    Image.fromarray(rgba, mode="RGBA").save(out_path)
    return out_path


# ==============================================================================
# FLOOD-FILL CUTOUT, ESTACIONES Y MEGA-ATLASES DE ESCOMBROS (20 SILUETAS)
# ==============================================================================

def _flood_fill_mask(candidate: np.ndarray, seeds_from_edges: bool) -> np.ndarray:
    h, w = candidate.shape
    visited = np.zeros((h, w), dtype=bool)
    q: deque[Tuple[int, int]] = deque()
    if seeds_from_edges:
        for x in range(w):
            if candidate[0, x] and not visited[0, x]:
                visited[0, x] = True
                q.append((0, x))
            if candidate[h - 1, x] and not visited[h - 1, x]:
                visited[h - 1, x] = True
                q.append((h - 1, x))
        for y in range(h):
            if candidate[y, 0] and not visited[y, 0]:
                visited[y, 0] = True
                q.append((y, 0))
            if candidate[y, w - 1] and not visited[y, w - 1]:
                visited[y, w - 1] = True
                q.append((y, w - 1))
    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and candidate[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))
    return visited


def _remove_large_dark_pockets(rgb_u8: np.ndarray, alpha_bool: np.ndarray, pocket_thresh: int = 9, min_area: int = 64) -> np.ndarray:
    h, w = alpha_bool.shape
    max_rgb = np.max(rgb_u8, axis=2)
    cand = alpha_bool & (max_rgb <= pocket_thresh)
    if not cand.any():
        return alpha_bool
    visited = np.zeros((h, w), dtype=bool)
    pockets = np.zeros((h, w), dtype=bool)

    ys, xs = np.where(cand)
    for sy, sx in zip(ys.tolist(), xs.tolist()):
        if visited[sy, sx]:
            continue
        comp: List[Tuple[int, int]] = []
        q: deque[Tuple[int, int]] = deque([(sy, sx)])
        visited[sy, sx] = True
        while q:
            cy, cx = q.popleft()
            comp.append((cy, cx))
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and cand[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
        if len(comp) >= min_area:
            for py, px in comp:
                pockets[py, px] = True
    return alpha_bool & (~pockets)


def _cutout_solid_object_from_black(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB"), dtype=np.uint8)
    max_rgb = np.max(rgb, axis=2)
    bg_cand = max_rgb < 20
    ext_bg = _flood_fill_mask(bg_cand, seeds_from_edges=True)

    fg_solid = ~ext_bg
    fg_solid = _remove_large_dark_pockets(rgb, fg_solid, pocket_thresh=9, min_area=64)

    fg_f = fg_solid.astype(np.float32)
    up = np.pad(fg_f[:-1, :], ((1, 0), (0, 0)), mode="constant")
    dn = np.pad(fg_f[1:, :], ((0, 1), (0, 0)), mode="constant")
    lf = np.pad(fg_f[:, :-1], ((0, 0), (1, 0)), mode="constant")
    rt = np.pad(fg_f[:, 1:], ((0, 0), (0, 1)), mode="constant")
    neighbor_avg = (up + dn + lf + rt) * 0.25

    edge_border = fg_solid & (neighbor_avg < 0.99) & (max_rgb < 34)
    alpha = np.where(fg_solid, 1.0, 0.0)
    alpha = np.where(edge_border, np.clip(max_rgb.astype(np.float32) / 30.0, 0.25, 1.0), alpha)

    rgba = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    return Image.fromarray(rgba, mode="RGBA")


def _compile_station(raw_name: str, out_name: str, out_size: int = 512) -> Path:
    fp = RAW_DIR / raw_name
    out_path = STATIONS_DIR / out_name
    raw_im = Image.open(fp).convert("RGB")
    cut = _cutout_solid_object_from_black(raw_im)
    bbox = cut.getbbox()
    if bbox is not None:
        cut = cut.crop(bbox)
    max_dim = int(round(out_size * 0.88))
    cut.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (out_size, out_size), (0, 0, 0, 0))
    px = (out_size - cut.width) // 2
    py = (out_size - cut.height) // 2
    canvas.paste(cut, (px, py), cut)
    canvas.save(out_path)
    return out_path


def _compile_multi_debris_atlas(raw_names: List[str], out_name: str, prefix: str) -> Tuple[Path, List[Dict[str, object]]]:
    """Fusiona múltiples atlas 2x2 crudos en un Mega-Atlas 2048x2048 clasificable en micro/medium/macro."""
    pieces: List[Image.Image] = []
    for raw_name in raw_names:
        fp = RAW_DIR / raw_name
        raw_im = Image.open(fp).convert("RGB")
        w, h = raw_im.size
        hw, hh = w // 2, h // 2
        for box in ((0, 0, hw, hh), (hw, 0, w, hh), (0, hh, hw, h), (hw, hh, w, h)):
            q_im = raw_im.crop(box)
            cut = _cutout_solid_object_from_black(q_im)
            bbox = cut.getbbox()
            if bbox is not None:
                cut = cut.crop(bbox)
            pieces.append(cut)

    atlas_size = 2048
    margin = 20
    pad = 22
    atlas = Image.new("RGBA", (atlas_size, atlas_size), (0, 0, 0, 0))
    entries: List[Dict[str, object]] = []

    cursor_x = margin
    cursor_y = margin
    row_max_h = 0

    def _place_by_area(piece: Image.Image, target_area: float, max_side: int, rot_deg: int) -> None:
        nonlocal cursor_x, cursor_y, row_max_h
        p = piece.copy()
        if rot_deg != 0:
            p = p.rotate(rot_deg, expand=True, resample=Image.Resampling.BICUBIC)
        scale = math.sqrt(target_area / float(max(p.width * p.height, 1)))
        nw = max(16, int(round(p.width * scale)))
        nh = max(16, int(round(p.height * scale)))
        if max(nw, nh) > max_side:
            clamp_f = float(max_side) / float(max(nw, nh))
            nw = max(16, int(round(nw * clamp_f)))
            nh = max(16, int(round(nh * clamp_f)))
        if cursor_x + nw + margin > atlas_size:
            cursor_x = margin
            cursor_y += row_max_h + pad
            row_max_h = 0
        resized = p.resize((nw, nh), Image.Resampling.LANCZOS)
        atlas.paste(resized, (cursor_x, cursor_y), resized)
        entries.append({"prefix": prefix, "rect": [cursor_x, cursor_y, nw, nh]})
        cursor_x += nw + pad
        row_max_h = max(row_max_h, nh)

    # Tier Macro: área objetivo ~44000 (> 28000)
    for idx, p in enumerate(pieces):
        _place_by_area(p, target_area=44000.0, max_side=270, rot_deg=(90 if idx % 2 == 1 else 0))

    # Tier Medium: área objetivo ~16500 (en [9500..24000])
    cursor_x = margin
    cursor_y += row_max_h + pad + 4
    row_max_h = 0
    for idx, p in enumerate(pieces):
        _place_by_area(p, target_area=16500.0, max_side=178, rot_deg=(180 if idx % 2 == 0 else 270))

    # Tier Micro: área objetivo ~4200 (< 7000)
    cursor_x = margin
    cursor_y += row_max_h + pad + 4
    row_max_h = 0
    for idx, p in enumerate(pieces):
        _place_by_area(p, target_area=4200.0, max_side=86, rot_deg=(90 * (idx % 4)))

    out_path = DEBRIS_DIR / out_name
    atlas.save(out_path)
    return out_path, entries


# ==============================================================================
# HOJAS DE CONTACTO Y MAIN BUILD
# ==============================================================================

def _checkerboard(w: int, h: int, cell: int = 16) -> Image.Image:
    yy, xx = np.mgrid[0:h, 0:w]
    c = (((xx // cell) + (yy // cell)) % 2 == 0)
    bg = np.where(c[:, :, None], np.array([44, 50, 68], dtype=np.uint8), np.array([28, 32, 46], dtype=np.uint8))
    return Image.fromarray(bg, mode="RGB").convert("RGBA")


def build_all(sheet_path: Path) -> None:
    _ensure_dirs()
    _ingest_dir(ARTIFACT_DIR, ARTIFACT_INGEST_MAP)
    _ingest_dir(TEMP_DIR, TEMP_INGEST_MAP)

    # --- PLANETAS Y LUNAS ---
    clouds_base = _build_clouds_base()
    compiled_rows = []
    normal_preview_rows: List[Tuple[str, np.ndarray, np.ndarray]] = []
    for name, (out_dir, raw_fn, extractor) in BODY_SPECS.items():
        raw_fp = RAW_DIR / raw_fn
        albedo_fp = out_dir / f"{name}_albedo.png"
        maps_fp = out_dir / f"{name}_maps.png"
        normal_fp = out_dir / f"{name}_normal.png"

        raw_im = Image.open(raw_fp)
        rgb_255 = _make_seamless_equirectangular(
            raw_im, EQ_W, EQ_H, apply_tectonic_scramble=(name == "planet_cryo_crystal")
        )
        rgb_u8 = rgb_255.astype(np.uint8)
        r_clouds, g_emissive, b_spec, a_bump_u8 = extractor(rgb_255 / 255.0, clouds_base)

        Image.fromarray(rgb_u8, mode="RGB").save(albedo_fp)
        maps_rgba = np.zeros((EQ_H, EQ_W, 4), dtype=np.uint8)
        maps_rgba[:, :, 0] = np.clip(r_clouds * 255.0, 0.0, 255.0).astype(np.uint8)
        maps_rgba[:, :, 1] = np.clip(g_emissive * 255.0, 0.0, 255.0).astype(np.uint8)
        maps_rgba[:, :, 2] = np.clip(b_spec * 255.0, 0.0, 255.0).astype(np.uint8)
        maps_rgba[:, :, 3] = np.clip(a_bump_u8, 16.0, 240.0).astype(np.uint8)
        Image.fromarray(maps_rgba, mode="RGBA").save(maps_fp)

        normal_ao_u8 = _compile_normal_ao_map(a_bump_u8, b_spec, name)
        Image.fromarray(normal_ao_u8, mode="RGB").save(normal_fp)

        print(f"[OK BODY+NORMAL] {name} | max G={maps_rgba[:, :, 1].max()} max B={maps_rgba[:, :, 2].max()} | AO_min={normal_ao_u8[:, :, 2].min()}")
        compiled_rows.append((name, rgb_u8, maps_rgba))
        if name in (
            "planet_volcanic_forge",
            "planet_oceanic_paradise",
            "planet_shattered_core",
            "planet_crimson_gas_giant",
            "planet_relic_dyson",
            "moon_crater",
        ):
            normal_preview_rows.append((name, rgb_u8, normal_ao_u8))

    r1 = compile_ring_polar("ring_crystal_ice_raw.png", "ring_crystal_ice.png")
    r2 = compile_ring_polar("ring_gold_debris_raw.png", "ring_gold_debris.png")
    r3 = compile_ring_polar("ring_plasma_nebula_raw.png", "ring_plasma_nebula.png")
    print(f"[OK RINGS] {r1.name}, {r2.name}, {r3.name}")

    # --- ESTRELLAS, NEBULOSAS Y LANDMARKS ---
    s_warm = _compile_star_photosphere("star_photosphere_warm_raw.png", "star_photosphere_warm.png")
    s_blue = _compile_star_photosphere("star_photosphere_blue_raw.png", "star_photosphere_blue.png")
    s_bh = _compile_star_photosphere("star_black_hole_singularity_raw.png", "star_black_hole_singularity.png", pad_ratio=0.06, fade_start=0.41)
    s_nova = _compile_star_photosphere("star_emerald_nova_raw.png", "star_emerald_nova.png", pad_ratio=0.06, fade_start=0.42)
    s_y_v3 = _compile_star_photosphere("star_yellow_dwarf_v3_raw.png", "star_yellow_dwarf_v3.png", pad_ratio=0.06, fade_start=0.45)
    s_r_v3 = _compile_star_photosphere("star_red_dwarf_v3_raw.png", "star_red_dwarf_v3.png", pad_ratio=0.04, fade_start=0.45)
    s_b_v3 = _compile_star_photosphere("star_blue_giant_v3_raw.png", "star_blue_giant_v3.png", pad_ratio=0.04, fade_start=0.45)
    s_w_v3 = _compile_star_photosphere("star_white_dwarf_v3_raw.png", "star_white_dwarf_v3.png", pad_ratio=0.09, fade_start=0.44)
    s_m_v3 = _compile_star_photosphere("star_magnetar_v3_raw.png", "star_magnetar_v3.png", pad_ratio=0.14, fade_start=0.45)

    neb_fil = _make_seamless_2d_nebula("nebula_anime_filaments_raw.png", "nebula_anime_filaments.png")
    neb_wisp = _make_seamless_2d_nebula("nebula_anime_wisps_raw.png", "nebula_anime_wisps.png")
    lm1 = _compile_landmark_rgba("landmark_spiral_galaxy_raw.png", "landmark_spiral_galaxy.png", mode="luminous", pad_ratio=0.06)
    lm2 = _compile_landmark_rgba("landmark_supernova_remnant_v3_raw.png", "landmark_supernova_remnant.png", mode="luminous", pad_ratio=0.14)
    lm3 = _compile_landmark_rgba("landmark_dust_pillars_raw.png", "landmark_dust_pillars.png", mode="dust_pillar", pad_ratio=0.02)
    lm4 = _compile_landmark_rgba("landmark_edge_galaxy_raw.png", "landmark_edge_galaxy.png", mode="luminous", pad_ratio=0.06)
    print(f"[OK HITO 2/v3.0] 9 stars ({s_y_v3.name}..{s_m_v3.name}), 2 nebulae, and 4 decontaminated landmarks compiled.")

    # --- ESTACIONES Y MEGA-ATLASES DE ESCOMBROS (20 SILUETAS -> 60 SLICES) ---
    st1 = _compile_station("station_ring_citadel_raw.png", "station_ring_citadel.png")
    st2 = _compile_station("station_spire_relay_raw.png", "station_spire_relay.png")
    st3 = _compile_station("station_shipyard_dock_raw.png", "station_shipyard_dock.png")

    deb_rock_fp, rock_entries = _compile_multi_debris_atlas(
        ["debris_asteroids_atlas_raw.png", "debris_crystals_atlas_raw.png", "debris_volcanic_ice_atlas_raw.png"],
        "debris_asteroids_v2.png",
        "debris_0",
    )
    deb_scrap_fp, scrap_entries = _compile_multi_debris_atlas(
        ["debris_mecha_ruins_atlas_raw.png", "debris_warship_wrecks_atlas_raw.png"],
        "debris_mecha_ruins_v2.png",
        "debris_1",
    )
    all_entries = rock_entries + scrap_entries
    meta_fp = DEBRIS_DIR / "debris_metadata_v2.json"
    meta_fp.write_text(json.dumps(all_entries, indent=2), encoding="utf-8")
    print(f"[OK HITO 3/v2.5] 3 stations + 2 mega-debris atlases ({len(all_entries)} slices -> {meta_fp.name}).")

    # --- Hoja de contacto nuevos assets v2.5 ---
    SHEET_V25_OUT.parent.mkdir(parents=True, exist_ok=True)
    new_planet_rows = [row for row in compiled_rows if row[0] in ("planet_shattered_core", "planet_biolum_jungle", "planet_crimson_gas_giant", "planet_relic_dyson")]
    thumb_w, thumb_h, pad = 256, 128, 8
    v25_sheet = Image.new("RGBA", (5 * (thumb_w + pad) + pad, (len(new_planet_rows) + 3) * (thumb_h + 24) + pad), (18, 22, 34, 255))
    d25 = ImageDraw.Draw(v25_sheet)

    for idx, (name, alb, mp) in enumerate(new_planet_rows):
        y = pad + idx * (thumb_h + 24)
        panels = [
            ("albedo", Image.fromarray(alb, mode="RGB").convert("RGBA")),
            ("R:clouds", Image.fromarray(np.stack([mp[:, :, 0]] * 3, axis=2), mode="RGB").convert("RGBA")),
            ("G:night_em", Image.fromarray(np.stack([mp[:, :, 1], mp[:, :, 1] // 2, np.zeros_like(mp[:, :, 1])], axis=2), mode="RGB").convert("RGBA")),
            ("B:spec", Image.fromarray(np.stack([np.zeros_like(mp[:, :, 2]), mp[:, :, 2] // 2, mp[:, :, 2]], axis=2), mode="RGB").convert("RGBA")),
            ("A:bump", Image.fromarray(np.stack([mp[:, :, 3]] * 3, axis=2), mode="RGB").convert("RGBA")),
        ]
        for ci, (tag, p_im) in enumerate(panels):
            x = pad + ci * (thumb_w + pad)
            v25_sheet.paste(p_im.resize((thumb_w, thumb_h), Image.Resampling.BILINEAR), (x, y))
            d25.text((x + 4, y + thumb_h + 2), f"{name[7:20]}:{tag}", fill=(210, 225, 255, 255))

    y_row_b = pad + len(new_planet_rows) * (thumb_h + 24)
    for si, (lbl, fp_item, is_sq) in enumerate([
        ("star_black_hole", s_bh, True),
        ("star_emerald_nova", s_nova, True),
        ("ring_plasma_nebula", r3, False),
    ]):
        x = pad + si * (thumb_w + pad)
        im_it = Image.open(fp_item).convert("RGBA")
        if is_sq:
            bg_c = Image.new("RGBA", (thumb_w, thumb_h), (0, 0, 0, 255))
            im_it = im_it.resize((thumb_h, thumb_h), Image.Resampling.BILINEAR)
            v25_sheet.paste(bg_c, (x, y_row_b))
            v25_sheet.paste(im_it, (x + (thumb_w - thumb_h) // 2, y_row_b), im_it)
        else:
            v25_sheet.paste(_checkerboard(thumb_w, thumb_h), (x, y_row_b))
            im_it = im_it.resize((thumb_w, thumb_h), Image.Resampling.BILINEAR)
            v25_sheet.paste(im_it, (x, y_row_b), im_it)
        d25.text((x + 4, y_row_b + thumb_h + 2), lbl, fill=(255, 220, 140, 255))

    y_deb = y_row_b + thumb_h + 24
    for di, (dlbl, dfp) in enumerate([("mega_debris_rocks_12", deb_rock_fp), ("mega_debris_mecha_8", deb_scrap_fp)]):
        box_sz = thumb_h * 2
        x = pad + di * (box_sz + pad)
        v25_sheet.paste(_checkerboard(box_sz, box_sz), (x, y_deb))
        rim = Image.open(dfp).convert("RGBA").resize((box_sz, box_sz), Image.Resampling.BILINEAR)
        v25_sheet.paste(rim, (x, y_deb), rim)
        d25.text((x + 4, y_deb + box_sz + 2), dlbl, fill=(170, 240, 255, 255))

    v25_sheet.save(SHEET_V25_OUT)
    print(f"[SHEET v2.5] {SHEET_V25_OUT}")

    # --- Hoja de contacto Normal + Cavity AO v2.7 ---
    v27_sheet_fp = ARTIFACT_DIR / "scratch" / "cosmos_v27_normals_sheet.png"
    v27_sheet_fp.parent.mkdir(parents=True, exist_ok=True)
    n_rows = len(normal_preview_rows)
    if n_rows > 0:
        v27_sheet = Image.new("RGBA", (3 * (thumb_w + pad) + pad, n_rows * (thumb_h + 24) + pad), (18, 22, 34, 255))
        d27 = ImageDraw.Draw(v27_sheet)
        for idx, (b_name, alb_u8, n_ao_u8) in enumerate(normal_preview_rows):
            y_n = pad + idx * (thumb_h + 24)
            n_xy = np.stack([n_ao_u8[:, :, 0], n_ao_u8[:, :, 1], np.full_like(n_ao_u8[:, :, 0], 200)], axis=2)
            ao_gray = np.stack([n_ao_u8[:, :, 2]] * 3, axis=2)
            panels_v27 = [
                ("albedo", Image.fromarray(alb_u8, mode="RGB").convert("RGBA")),
                ("RG:normal", Image.fromarray(n_xy, mode="RGB").convert("RGBA")),
                ("B:cavity_ao", Image.fromarray(ao_gray, mode="RGB").convert("RGBA")),
            ]
            for ci, (tag, p_im) in enumerate(panels_v27):
                x_n = pad + ci * (thumb_w + pad)
                v27_sheet.paste(p_im.resize((thumb_w, thumb_h), Image.Resampling.BILINEAR), (x_n, y_n))
                d27.text((x_n + 4, y_n + thumb_h + 2), f"{b_name[:20]}:{tag}", fill=(210, 225, 255, 255))
        v27_sheet.save(v27_sheet_fp)
        print(f"[SHEET v2.7] {v27_sheet_fp}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compila todos los assets Cosmos v2.5.")
    parser.add_argument("--sheet", type=Path, default=DEFAULT_SHEET_OUT)
    args = parser.parse_args()
    build_all(args.sheet)
