#!/usr/bin/env python3
"""Offline Multi-Map compiler (Rig v2 / ArcSys standard) for Hub 3D surfaces and signage.

Extracts 4 shader-ready maps + metadata from clean orthographic AI masters (or procedural fallback):
  - `<name>.png`           (RGBA albedo)
  - `<name>_id_mask.png`   (R=emissive accent trim, G=primary armor/ceramic plates, B=dark chassis)
  - `<name>_ilm_mask.png`  (R=specular, G=AO/cel bias, B=rim weight, A=strict HDR emissive)
  - `<name>_ink_sdf.png`   (2x signed distance field, +-8.0 native texels, seamless wrap in tile mode)
  - `<name>_meta.json`     (dimensions, mode, sdf range, source)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import cv2
import numpy as np

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent
PILOT_TOOLS_DIR = REPO_ROOT / "sandbox" / "pilot_rig_lab" / "tools"
if PILOT_TOOLS_DIR.exists() and str(PILOT_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(PILOT_TOOLS_DIR))

try:
    from process_masked_5parts import upscale_with_upscayl  # type: ignore
except Exception:
    upscale_with_upscayl = None  # type: ignore

INK_SDF_RANGE_PX: float = 8.0
DEFAULT_SIZE_PX: int = 1024


def _generate_fallback_master(mode: str, size: int) -> np.ndarray:
    """Synthesize a clean geometric ArcSys test master on BGR if no source image is supplied."""
    w = size
    h = size if mode == "tile" else max(256, int(round(size * 9.0 / 16.0)))
    img = np.full((h, w, 3), (242, 234, 226), dtype=np.uint8)  # #E2EAF2 cool silver-white (BGR)

    ink_col = (34, 22, 18)       # #121622
    chassis_col = (59, 39, 29)   # #1D273B
    bevel_col = (220, 200, 184)  # #B8C8DC
    accent_col = (85, 42, 255)   # #FF2A55

    if mode == "atlas":
        img[:, :] = (0, 0, 0)
        cols, rows = 4, 2
        cw, ch = w // cols, h // rows
        for r in range(rows):
            for c in range(cols):
                cx = c * cw + cw // 2
                cy = r * ch + ch // 2
                rad = min(cw, ch) // 3
                cv2.circle(img, (cx, cy), rad, (255, 255, 232), 4, cv2.LINE_AA)
                cv2.drawMarker(img, (cx, cy), (109, 42, 255), cv2.MARKER_DIAMOND, rad, 3, cv2.LINE_AA)
        return img

    if mode == "tile":
        # Seamless chamfered ceramic deck plates + recessed navy channels + crimson trim
        border = max(12, w // 32)
        cv2.rectangle(img, (0, 0), (w - 1, h - 1), chassis_col, border)
        cv2.rectangle(img, (w // 2 - border // 2, 0), (w // 2 + border // 2, h - 1), chassis_col, -1)
        cv2.rectangle(img, (0, h // 2 - border // 2), (w - 1, h // 2 + border // 2), chassis_col, -1)

        pad = w // 8
        cv2.rectangle(img, (pad, pad), (w - pad, h - pad), bevel_col, max(4, w // 128))
        # Reactive crimson energy strips along quarter lines
        strip = max(4, w // 120)
        cv2.line(img, (pad, h // 4), (w - pad, h // 4), accent_col, strip)
        cv2.line(img, (pad, 3 * h // 4), (w - pad, 3 * h // 4), accent_col, strip)

        # Crisp dark ink panel seams
        ink_t = max(3, w // 256)
        cv2.line(img, (0, h // 2 - border // 2), (w, h // 2 - border // 2), ink_col, ink_t)
        cv2.line(img, (0, h // 2 + border // 2), (w, h // 2 + border // 2), ink_col, ink_t)
        cv2.line(img, (w // 2 - border // 2, 0), (w // 2 - border // 2, h), ink_col, ink_t)
        cv2.line(img, (w // 2 + border // 2, 0), (w // 2 + border // 2, h), ink_col, ink_t)
        cv2.rectangle(img, (pad, pad), (w - pad, h - pad), ink_col, ink_t)
        return img

    # Panel mode (bulkhead elevation)
    bay_w = w // 3
    for i in range(3):
        x0 = i * bay_w
        x1 = (i + 1) * bay_w if i < 2 else w
        cv2.rectangle(img, (x0, int(h * 0.78)), (x1, h), chassis_col, -1)
        cv2.rectangle(img, (x0, 0), (x1, int(h * 0.12)), chassis_col, -1)
        rib_w = max(14, w // 48)
        cv2.rectangle(img, (x0, 0), (x0 + rib_w, h), chassis_col, -1)
        cv2.rectangle(img, (x0 + rib_w + 18, int(h * 0.20)), (x1 - 18, int(h * 0.72)), bevel_col, 4)
        cv2.line(img, (x0 + rib_w + 18, int(h * 0.16)), (x1 - 18, int(h * 0.16)), accent_col, max(5, h // 96))
        cv2.rectangle(img, (x0 + rib_w, int(h * 0.12)), (x1 - 2, int(h * 0.78)), ink_col, max(3, h // 180))
    return img


def _upscale_master(src_path: Path, no_upscayl: bool) -> np.ndarray:
    raw = cv2.imread(str(src_path), cv2.IMREAD_COLOR)
    if raw is None:
        raise RuntimeError(f"Could not read source surface image: {src_path}")
    rh, rw = raw.shape[:2]
    if no_upscayl or upscale_with_upscayl is None or max(rw, rh) >= 3200:
        return raw

    up_dir = src_path.parent / "outputs_upscayl"
    up_dir.mkdir(parents=True, exist_ok=True)
    up_cache = up_dir / f"{src_path.stem}_4x.png"
    if not up_cache.exists() or up_cache.stat().st_mtime < src_path.stat().st_mtime:
        print(f"[UPSCAYL] digital-art-4x: {src_path.name} ({rw}x{rh}) -> {up_cache.name}")
        res_path = upscale_with_upscayl(src_path, up_cache, model="digital-art-4x")
    else:
        print(f"[UPSCAYL] Reusing cache: {up_cache.name}")
        res_path = up_cache

    up_bgr = cv2.imread(str(res_path), cv2.IMREAD_COLOR)
    if up_bgr is None:
        raise RuntimeError(f"Could not read upscaled image: {res_path}")
    return up_bgr


def _extract_ink_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, hr_scale: float, mode: str) -> np.ndarray:
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    val = hsv[:, :, 2]
    sat = hsv[:, :, 1]
    gray = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2GRAY)

    if mode == "tile":
        pad = max(16, int(round(24 * hr_scale)))
        gray_pad = cv2.copyMakeBorder(gray, pad, pad, pad, pad, cv2.BORDER_WRAP)
        bh_size = max(5, int(round(9 * hr_scale)) | 1)
        bh_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (bh_size, bh_size))
        blackhat = cv2.morphologyEx(gray_pad, cv2.MORPH_BLACKHAT, bh_kernel)[pad:-pad, pad:-pad]
    else:
        bh_size = max(5, int(round(9 * hr_scale)) | 1)
        bh_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (bh_size, bh_size))
        blackhat = cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, bh_kernel)

    # Fine dark ink strokes (#121622) plus strong blackhat ridges; exclude broad navy chassis fills
    thin_ridges = (blackhat > 20) & (val < 155)
    deep_ink = (val < 34) & (sat < 165)

    # Subtract broad dark interiors in architectural modes so dark chassis panels remain #FFFFFF in SDF
    if mode in ("tile", "panel"):
        thick_k_sz = max(7, int(round(10 * hr_scale)) | 1)
        thick_k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (thick_k_sz, thick_k_sz))
        if mode == "tile":
            pad_d = thick_k_sz * 2
            deep_pad = cv2.copyMakeBorder(deep_ink.astype(np.uint8), pad_d, pad_d, pad_d, pad_d, cv2.BORDER_WRAP)
            broad_fill = (cv2.erode(deep_pad, thick_k, iterations=1) > 0)[pad_d:-pad_d, pad_d:-pad_d]
        else:
            broad_fill = cv2.erode(deep_ink.astype(np.uint8), thick_k, iterations=1) > 0
        # Keep only the perimeter border of broad dark areas as crisp ink
        deep_ink = deep_ink & (~broad_fill)

    ink = (deep_ink | thin_ridges) & fg_hr
    close_k = np.ones((3, 3), dtype=np.uint8)
    if mode == "tile":
        pad_c = 8
        ink_pad = cv2.copyMakeBorder(ink.astype(np.uint8), pad_c, pad_c, pad_c, pad_c, cv2.BORDER_WRAP)
        ink = (cv2.morphologyEx(ink_pad, cv2.MORPH_CLOSE, close_k)[pad_c:-pad_c, pad_c:-pad_c] > 0) & fg_hr
    else:
        ink = (cv2.morphologyEx(ink.astype(np.uint8), cv2.MORPH_CLOSE, close_k) > 0) & fg_hr
    return ink


def _build_id_mask_hr(bgr_hr: np.ndarray, fg_hr: np.ndarray, ink_hr: np.ndarray, mode: str) -> np.ndarray:
    h, w = fg_hr.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    hue, sat, val = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    b_ch = bgr_hr[:, :, 0].astype(np.int16)
    g_ch = bgr_hr[:, :, 1].astype(np.int16)
    r_ch = bgr_hr[:, :, 2].astype(np.int16)

    is_red_or_magenta = (hue <= 18) | (hue >= 145)
    is_purple_neon = (hue >= 125) & (hue < 145) & (sat >= 110) & (val >= 95) & ((r_ch - g_ch) > 35)
    emissive_trim = (
        fg_hr
        & (~ink_hr)
        & (
            (is_red_or_magenta & (sat >= 55) & ((r_ch - g_ch) > 15) & (val >= 52))
            | is_purple_neon
        )
    )
    navy_chassis = fg_hr & (~ink_hr) & (~emissive_trim) & (val < 135) & (b_ch >= r_ch + 2)
    armor_plates = fg_hr & (~ink_hr) & (~emissive_trim) & (~navy_chassis)

    cls_map = np.zeros((h, w), dtype=np.uint8)
    cls_map[emissive_trim] = 1
    cls_map[armor_plates] = 2
    cls_map[navy_chassis] = 3

    classified = cls_map > 0
    if np.any(classified):
        if mode == "tile":
            pad = 24
            cls_pad = cv2.copyMakeBorder(cls_map, pad, pad, pad, pad, cv2.BORDER_WRAP)
            _, labels = cv2.distanceTransformWithLabels(
                (cls_pad == 0).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            coords = np.argwhere(cls_pad > 0)
            idx = np.clip(labels - 1, 0, len(coords) - 1)
            filled = cls_pad[coords[idx, 0], coords[idx, 1]][pad:-pad, pad:-pad]
        else:
            _, labels = cv2.distanceTransformWithLabels(
                (~classified).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            coords = np.argwhere(classified)
            idx = np.clip(labels - 1, 0, len(coords) - 1)
            filled = cls_map[coords[idx, 0], coords[idx, 1]]
        out[(filled == 1) & fg_hr, 2] = 255  # R channel (BGR idx 2)
        out[(filled == 2) & fg_hr, 1] = 255  # G channel (BGR idx 1)
        out[(filled == 3) & fg_hr, 0] = 255  # B channel (BGR idx 0)

    out[:, :, 3] = np.where(fg_hr, 255, 0).astype(np.uint8)
    return out


def _build_ilm_mask_hr(
    bgr_hr: np.ndarray,
    fg_hr: np.ndarray,
    ink_hr: np.ndarray,
    id_bgra_hr: np.ndarray,
) -> np.ndarray:
    h, w = fg_hr.shape
    hsv = cv2.cvtColor(bgr_hr, cv2.COLOR_BGR2HSV)
    val = hsv[:, :, 2].astype(np.float32) / 255.0

    is_emissive = id_bgra_hr[:, :, 2] > 128
    is_armor = id_bgra_hr[:, :, 1] > 128

    # R (BGR idx 2): Specular intensity
    spec = np.where(
        is_emissive,
        235.0,
        np.where(is_armor, 155.0 + 90.0 * np.clip((val - 0.55) / 0.45, 0.0, 1.0), 72.0),
    )
    spec = np.where(ink_hr, 28.0, spec)

    # G (BGR idx 1): AO / Cel bias
    ao = np.where(
        is_emissive,
        240.0,
        np.where(is_armor, 140.0 + 95.0 * np.clip((val - 0.45) / 0.50, 0.0, 1.0), 75.0 + 45.0 * val),
    )
    ao = np.where(ink_hr, 42.0, ao)

    # B (BGR idx 0): Rim weight
    rim = np.where(is_armor, 190.0, np.where(is_emissive, 220.0, 95.0))
    rim = np.where(ink_hr, 40.0, rim)

    # A: Strict HDR emissive mask on reactive accent channels
    emissive_raw = np.where(is_emissive & (~ink_hr), 255.0, 0.0).astype(np.float32)
    emissive = cv2.GaussianBlur(emissive_raw, (0, 0), sigmaX=0.9)
    emissive = np.where(fg_hr, emissive, 0.0)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, 2] = np.clip(np.round(np.where(fg_hr, spec, 0.0)), 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(np.round(np.where(fg_hr, ao, 128.0)), 0, 255).astype(np.uint8)
    out[:, :, 0] = np.clip(np.round(np.where(fg_hr, rim, 0.0)), 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(np.round(emissive), 0, 255).astype(np.uint8)
    return out


def _encode_sdf_2x(
    ink_hr: np.ndarray,
    native_w: int,
    native_h: int,
    hr_to_native_scale: float,
    seamless_wrap: bool,
) -> np.ndarray:
    out_w, out_h = native_w * 2, native_h * 2
    if not np.any(ink_hr):
        return np.full((out_h, out_w, 4), 255, dtype=np.uint8)

    if seamless_wrap:
        pad = max(32, int(round(32.0 / max(hr_to_native_scale, 0.05))))
        ink_pad = cv2.copyMakeBorder(ink_hr.astype(np.uint8), pad, pad, pad, pad, cv2.BORDER_WRAP) > 0
        d_out = cv2.distanceTransform((~ink_pad).astype(np.uint8), cv2.DIST_L2, 5)[pad:-pad, pad:-pad] * hr_to_native_scale
        d_in = cv2.distanceTransform(ink_pad.astype(np.uint8), cv2.DIST_L2, 5)[pad:-pad, pad:-pad] * hr_to_native_scale
    else:
        d_out = cv2.distanceTransform((~ink_hr).astype(np.uint8), cv2.DIST_L2, 5) * hr_to_native_scale
        d_in = cv2.distanceTransform(ink_hr.astype(np.uint8), cv2.DIST_L2, 5) * hr_to_native_scale

    sdf_2x = cv2.resize(d_out - d_in, (out_w, out_h), interpolation=cv2.INTER_AREA)
    u8 = np.clip(np.round(np.clip(0.5 + sdf_2x / (2.0 * INK_SDF_RANGE_PX), 0.0, 1.0) * 255.0), 0, 255).astype(np.uint8)
    return np.stack([u8, u8, u8, np.full((out_h, out_w), 255, dtype=np.uint8)], axis=2)


def compile_surface_maps(
    bgr_hr: np.ndarray,
    out_dir: Path,
    name: str,
    mode: str,
    target_size: int,
    source_label: str,
) -> dict:
    hr_h, hr_w = bgr_hr.shape[:2]

    if mode == "tile":
        native_w = max(128, int(target_size))
        native_h = native_w
        # Normalize square HR working buffer if input isn't 1:1
        if hr_w != hr_h:
            side = max(hr_w, hr_h)
            bgr_hr = cv2.resize(bgr_hr, (side, side), interpolation=cv2.INTER_CUBIC)
            hr_h, hr_w = bgr_hr.shape[:2]
        fg_hr = np.ones((hr_h, hr_w), dtype=bool)
        alpha_hr = np.full((hr_h, hr_w), 255, dtype=np.uint8)
    elif mode == "panel":
        native_w = max(128, int(target_size))
        native_h = max(128, int(round(native_w * (float(hr_h) / max(float(hr_w), 1.0)))))
        if native_h % 2 == 1:
            native_h += 1
        fg_hr = np.ones((hr_h, hr_w), dtype=bool)
        alpha_hr = np.full((hr_h, hr_w), 255, dtype=np.uint8)
    else:  # atlas
        native_w = max(128, int(target_size))
        native_h = max(128, int(round(native_w * (float(hr_h) / max(float(hr_w), 1.0)))))
        if native_h % 2 == 1:
            native_h += 1
        val_max = bgr_hr.max(axis=2).astype(np.float32)
        alpha_f = np.clip((val_max - 14.0) / 18.0, 0.0, 1.0)
        fg_hr = alpha_f > 0.25
        alpha_hr = np.clip(np.round(alpha_f * 255.0), 0, 255).astype(np.uint8)

    hr_to_native = float(native_w) / max(float(hr_w), 1.0)
    hr_scale = max(float(hr_w) / float(native_w), 1.0)

    ink_hr = _extract_ink_mask_hr(bgr_hr, fg_hr, hr_scale, mode)
    id_hr = _build_id_mask_hr(bgr_hr, fg_hr, ink_hr, mode)
    ilm_hr = _build_ilm_mask_hr(bgr_hr, fg_hr, ink_hr, id_hr)

    albedo_nat = cv2.resize(bgr_hr, (native_w, native_h), interpolation=cv2.INTER_AREA)
    alpha_nat = cv2.resize(alpha_hr, (native_w, native_h), interpolation=cv2.INTER_AREA)
    albedo_bgra = np.dstack([albedo_nat, alpha_nat])

    id_nat = cv2.resize(id_hr, (native_w, native_h), interpolation=cv2.INTER_NEAREST)
    ilm_nat = cv2.resize(ilm_hr, (native_w, native_h), interpolation=cv2.INTER_AREA)
    sdf_2x = _encode_sdf_2x(ink_hr, native_w, native_h, hr_to_native, seamless_wrap=(mode == "tile"))

    out_dir.mkdir(parents=True, exist_ok=True)
    p_albedo = out_dir / f"{name}.png"
    p_id = out_dir / f"{name}_id_mask.png"
    p_ilm = out_dir / f"{name}_ilm_mask.png"
    p_sdf = out_dir / f"{name}_ink_sdf.png"
    p_meta = out_dir / f"{name}_meta.json"

    cv2.imwrite(str(p_albedo), albedo_bgra)
    cv2.imwrite(str(p_id), id_nat)
    cv2.imwrite(str(p_ilm), ilm_nat)
    cv2.imwrite(str(p_sdf), sdf_2x)

    meta = {
        "schema_version": 1,
        "name": name,
        "mode": mode,
        "source": source_label,
        "native_size": [native_w, native_h],
        "sdf_size": [native_w * 2, native_h * 2],
        "sdf_range_px": INK_SDF_RANGE_PX,
        "seamless_wrap": mode == "tile",
        "sha256_albedo": hashlib.sha256(p_albedo.read_bytes()).hexdigest()[:16],
    }
    p_meta.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return meta


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile Hub 3D surface AI masters into Rig v2 multi-map bundles.")
    parser.add_argument("--src", type=Path, default=None, help="Path to source image (PNG/JPG).")
    parser.add_argument("--out-dir", type=Path, required=True, help="Output directory for compiled maps.")
    parser.add_argument("--name", type=str, required=True, help="Base asset name.")
    parser.add_argument("--mode", choices=["tile", "panel", "atlas"], default="tile")
    parser.add_argument("--size", type=int, default=DEFAULT_SIZE_PX, help="Target native width in pixels.")
    parser.add_argument("--no-upscayl", action="store_true", help="Skip Upscayl 4x pass.")
    parser.add_argument("--generate-fallback", action="store_true", help="Synthesize deterministic fallback master.")
    args = parser.parse_args()

    if args.generate_fallback or args.src is None:
        bgr_hr = _generate_fallback_master(args.mode, max(256, int(args.size)))
        source_label = f"procedural_fallback:{args.mode}"
    else:
        if not args.src.exists():
            raise FileNotFoundError(f"Source image not found: {args.src}")
        bgr_hr = _upscale_master(args.src, no_upscayl=args.no_upscayl)
        source_label = str(args.src.relative_to(REPO_ROOT)).replace("\\", "/") if args.src.is_relative_to(REPO_ROOT) else str(args.src)

    meta = compile_surface_maps(bgr_hr, args.out_dir, args.name, args.mode, args.size, source_label)
    print(f"[DONE] Compiled {args.name} ({meta['mode']}, native={meta['native_size']}, sdf={meta['sdf_size']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
