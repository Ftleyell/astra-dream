#!/usr/bin/env python3
"""Compilador HQ reutilizable de close-ups vivos de diálogo para pilotos v2 (Astra Dream).

Pipeline secuencial optimizado para RTX 2060 (carga 1 modelo por etapa de lote):
  1. Upscayl 4x (`digital-art-4x`) + `isnet-anime` (rembg) + limpieza #808080 + Voronoi RGB bleed + 1024x1024.
  2. Sapiens-Normal-0.3B (`facebook/sapiens-normal-0.3b-torchscript` local) -> `<pilot>_dialogue_<em_>_normal.png` (RGB opaco).
  3. Depth-Anything-V2-Small (`depth-anything/Depth-Anything-V2-Small-hf` local) -> `<pilot>_dialogue_<em_>_depth.png` (RGB opaco).
  4. Máscaras limpias pre-suavizadas con filtro bilateral y morfología (todas RGB opacas):
       - `<pilot>_dialogue_<em_>_id_mask.png`     (R=carmesí/monóculo, G=placas metálicas, B=traje carbón/busto)
       - `<pilot>_dialogue_<em_>_ilm_map.png`     (R=especular metal, G=AO/protección piel, B=cabello exacto)
       - `<pilot>_dialogue_<em_>_motion_mask.png` (R=respiración busto, G=cabello dilatado 20px, B=ojo+monóculo)
  5. Manifiesto JSON + Hoja de auditoría de 6 filas (`audit_dialogue_sheet.png`).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from ml_stage_processors import MODELS_CACHE, clear_vram, get_device  # noqa: E402
from process_masked_5parts import upscale_with_upscayl  # noqa: E402

PILOT_RIG_LAB_DIR = TOOLS_DIR.parent
REPO_ROOT = PILOT_RIG_LAB_DIR.parent.parent
PREFERRED_ORDER: tuple[str, ...] = ("neutral", "thinking", "warm", "focused", "smirk", "alert", "annoyed")
DEFAULT_HF_HUB_CACHE = Path.home() / ".cache" / "huggingface" / "hub"


def _voronoi_bleed_rgb(rgb: np.ndarray, fg_mask: np.ndarray) -> np.ndarray:
    """Propaga el color del borde hacia píxeles transparentes para evitar halos en filtrado bilineal."""
    if not np.any(fg_mask) or np.all(fg_mask):
        return rgb.copy()
    _, labels = cv2.distanceTransformWithLabels(
        (~fg_mask).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    fg_coords = np.argwhere(fg_mask)
    idx = np.clip(labels - 1, 0, len(fg_coords) - 1)
    ys = fg_coords[idx, 0]
    xs = fg_coords[idx, 1]
    out = rgb.copy()
    out[~fg_mask] = rgb[ys[~fg_mask], xs[~fg_mask]]
    return out


def _dilate_field_outside(field: np.ndarray, valid_mask: np.ndarray, radius_px: int = 20, blur_k: int = 13) -> np.ndarray:
    """Extiende un campo escalar más allá de la silueta para evitar fantasmas al deformar UV."""
    out = field.copy()
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    known = valid_mask.astype(np.uint8)
    for _ in range(max(1, radius_px // 3)):
        dil_val = cv2.dilate(out, kernel)
        dil_known = cv2.dilate(known, kernel)
        ring = (dil_known > 0) & (known == 0)
        out[ring] = dil_val[ring]
        known = dil_known
    if blur_k >= 3:
        out = cv2.GaussianBlur(out, (blur_k, blur_k), 0)
    return out


def _fill_ink_gaps(channels: list[np.ndarray], fill_mask: np.ndarray, valid_mask: np.ndarray, steps: int = 5) -> list[np.ndarray]:
    """Propaga canales ID hacia líneas de tinta internas dentro de la silueta para evitar agujeros."""
    out = [c.copy() for c in channels]
    known = valid_mask.astype(np.uint8)
    k3 = np.ones((3, 3), np.uint8)
    for _ in range(steps):
        dil_k = cv2.dilate(known, k3)
        ring = (dil_k > 0) & (known == 0) & fill_mask
        if not np.any(ring):
            break
        for i, ch in enumerate(out):
            out[i][ring] = cv2.dilate(ch, k3)[ring]
        known = dil_k
    return out


def _clean_binary_mask(mask: np.ndarray, min_area: int = 100, open_k: int = 3, close_k: int = 5) -> np.ndarray:
    """Elimina motas aisladas y suaviza bordes de una máscara binaria."""
    m = mask.astype(np.uint8)
    if open_k >= 3:
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((open_k, open_k), np.uint8))
    if close_k >= 3:
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((close_k, close_k), np.uint8))
    num_l, labels, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    clean = np.zeros_like(m, dtype=bool)
    for idx in range(1, num_l):
        if int(stats[idx, cv2.CC_STAT_AREA]) >= min_area:
            clean[labels == idx] = True
    return clean


def _upscale_source(src_path: Path, cache_dir: Path, no_upscayl: bool) -> Image.Image:
    raw_pil = Image.open(src_path).convert("RGB")
    if no_upscayl or max(raw_pil.size) >= 3200:
        return raw_pil
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_png = cache_dir / f"{src_path.stem}_4x.png"
    if not cache_png.exists() or cache_png.stat().st_mtime < src_path.stat().st_mtime:
        print(f"[UPSCAYL] digital-art-4x: {src_path.name} -> {cache_png.name}")
        res_path = upscale_with_upscayl(src_path, cache_png, model="digital-art-4x")
    else:
        print(f"[UPSCAYL] Cache: {cache_png.name}")
        res_path = cache_png
    return Image.open(res_path).convert("RGB")


def _extract_clean_rgba_with_session(pil_rgb: Image.Image, rembg_session: object) -> np.ndarray:
    """Extrae primer plano con sesión compartida isnet-anime y limpia fondo neutro #808080."""
    from rembg import remove

    rgba_pil = remove(pil_rgb.convert("RGB"), session=rembg_session).convert("RGBA")
    rgba = np.array(rgba_pil, dtype=np.uint8)
    alpha = rgba[:, :, 3]

    fg_bin = (alpha > 32).astype(np.uint8)
    num_l, labels, stats, _ = cv2.connectedComponentsWithStats(fg_bin)
    if num_l > 1:
        max_area = int(stats[1:, cv2.CC_STAT_AREA].max())
        keep = np.zeros_like(fg_bin)
        for idx in range(1, num_l):
            if int(stats[idx, cv2.CC_STAT_AREA]) >= max(500, int(max_area * 0.04)):
                keep[labels == idx] = 1
        alpha = np.where(keep > 0, alpha, 0).astype(np.uint8)

    rgb_f = rgba[:, :, :3].astype(np.float32)
    dist_grey = np.linalg.norm(rgb_f - 127.0, axis=2)
    near_grey = (dist_grey < 13.5) & (alpha > 0)
    ng_num, ng_lbl, ng_stats, _ = cv2.connectedComponentsWithStats(near_grey.astype(np.uint8), connectivity=4)
    h, w = alpha.shape
    for lbl in range(1, ng_num):
        x0, y0, bw, bh, area = [int(v) for v in ng_stats[lbl]]
        if ((x0 <= 2) or (y0 <= 2) or (x0 + bw >= w - 2) or (y0 + bh >= h - 2)) and area > 20:
            alpha[ng_lbl == lbl] = 0

    fg_solid = alpha > 200
    eroded = cv2.erode((alpha > 64).astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1)
    fringe = (alpha > 0) & (eroded == 0)
    rgb_out = rgba[:, :, :3].copy()
    if np.any(fringe):
        dark_nbr = cv2.erode(rgb_out, np.ones((3, 3), np.uint8), iterations=1)
        is_neutral_spill = fringe & (dist_grey < 34.0)
        rgb_out[is_neutral_spill] = np.clip(
            rgb_out[is_neutral_spill].astype(np.float32) * 0.35 + dark_nbr[is_neutral_spill].astype(np.float32) * 0.65,
            0,
            255,
        ).astype(np.uint8)

    rgb_bled = _voronoi_bleed_rgb(rgb_out, fg_solid if np.any(fg_solid) else (alpha > 32))
    return np.dstack([rgb_bled, alpha])


def _normalize_to_canvas(rgba: np.ndarray, target_size: int = 1024, top_pad_ratio: float = 0.055) -> tuple[np.ndarray, dict]:
    """Recorta al bbox real del busto, escala de forma uniforme y ancla en base inferior centrada."""
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 20)
    if len(ys) == 0:
        raise RuntimeError("No foreground pixels detected after matting.")
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    crop = rgba[y0:y1, x0:x1]
    ch, cw = crop.shape[:2]

    avail_h = max(64, int(round(target_size * (1.0 - top_pad_ratio))))
    avail_w = max(64, int(round(target_size * 0.94)))
    scale = min(float(avail_h) / float(ch), float(avail_w) / float(cw))
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))

    interp = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_CUBIC
    resized = cv2.resize(crop, (new_w, new_h), interpolation=interp)

    canvas = np.zeros((target_size, target_size, 4), dtype=np.uint8)
    dst_x = (target_size - new_w) // 2
    dst_y = target_size - new_h
    canvas[dst_y : dst_y + new_h, dst_x : dst_x + new_w] = resized

    fg_final = canvas[:, :, 3] > 24
    canvas[:, :, :3] = _voronoi_bleed_rgb(canvas[:, :, :3], fg_final)
    meta = {
        "bbox": [dst_x, dst_y, new_w, new_h],
        "head_top_y": dst_y,
        "center_x": target_size // 2,
    }
    return canvas, meta


def _run_sapiens_normals_batch(items: list[dict]) -> None:
    """Ejecuta Sapiens-Normal-0.3B una sola vez para todo el lote y genera Normal Maps RGB opacos."""
    from huggingface_hub import hf_hub_download

    clear_vram()
    device = get_device()
    model = None
    try:
        ckpt = hf_hub_download(
            repo_id="facebook/sapiens-normal-0.3b-torchscript",
            filename="sapiens_0.3b_normal_render_people_epoch_66_torchscript.pt2",
            cache_dir=MODELS_CACHE,
            local_files_only=True,
        )
        print(f"[SAPIENS] Cargado Normal 0.3B ({device}): {Path(ckpt).name}")
        model = torch.jit.load(ckpt).eval().to(device)
    except Exception as exc:
        print(f"[WARN] No se pudo cargar Sapiens local, usando fallback analítico: {exc}")

    mean = torch.tensor([123.5, 116.5, 103.5]).view(1, 3, 1, 1) / 255.0
    std = torch.tensor([58.395, 57.12, 57.375]).view(1, 3, 1, 1) / 255.0

    for rec in items:
        rgba = rec["rgba"]
        h, w = rgba.shape[:2]
        alpha = rgba[:, :, 3] > 48
        if model is not None:
            rgb_sap = rgba[:, :, :3].copy()
            rgb_sap[~alpha] = 0
            resized = cv2.resize(rgb_sap, (768, 1024), interpolation=cv2.INTER_AREA)
            ten = torch.from_numpy(resized).float().permute(2, 0, 1).unsqueeze(0) / 255.0
            ten = ((ten - mean) / std).to(device)
            with torch.no_grad():
                if device == "cuda":
                    with torch.amp.autocast("cuda", dtype=torch.float16):
                        out = model(ten)
                else:
                    out = model(ten)
            nrm = np.transpose(out[0].float().cpu().numpy(), (1, 2, 0))
            # Sapiens predice +X=derecha, +Y=arriba; en Godot 2D (+Y es abajo) invertimos Y:
            nrm[:, :, 1] = -nrm[:, :, 1]
            nrm[:, :, 2] = np.maximum(nrm[:, :, 2], 0.22)
            nrm /= np.linalg.norm(nrm, axis=2, keepdims=True) + 1e-6
            nrm_u8 = np.clip((nrm * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
            nrm_full = cv2.resize(nrm_u8, (w, h), interpolation=cv2.INTER_CUBIC)
            nrm_smooth = cv2.bilateralFilter(nrm_full, d=9, sigmaColor=24, sigmaSpace=9)
            rec["sapiens_nrm_f"] = nrm_smooth.astype(np.float32) / 255.0 * 2.0 - 1.0
            del ten, out
        else:
            rec["sapiens_nrm_f"] = None

    if model is not None:
        del model
    clear_vram()


def _build_fused_normals(items: list[dict]) -> None:
    """Combina normales multi-escala de Depth-Anything-V2 (65%) con Sapiens 3D (35%) en espacio Godot 2D (+X der, -Y arriba)."""
    for rec in items:
        rgba = rec["rgba"]
        h, w = rgba.shape[:2]
        alpha = rgba[:, :, 3] > 48
        alpha_core = cv2.erode(alpha.astype(np.uint8), np.ones((7, 7), np.uint8), iterations=1) > 0
        dep_f = rec["depth_f"]

        # Normales multi-escala desde Depth-Anything-V2 (macro volumen + micro pliegues/brazales/pelo)
        d_macro = cv2.GaussianBlur(dep_f, (31, 31), 0)
        d_micro = cv2.GaussianBlur(dep_f, (9, 9), 0)
        gx_m = cv2.Sobel(d_macro, cv2.CV_32F, 1, 0, ksize=5) * 0.85
        gy_m = cv2.Sobel(d_macro, cv2.CV_32F, 0, 1, ksize=5) * 0.85
        gx_f = cv2.Sobel(d_micro, cv2.CV_32F, 1, 0, ksize=3) * 1.45
        gy_f = cv2.Sobel(d_micro, cv2.CV_32F, 0, 1, ksize=3) * 1.45

        nx_d = -(gx_m * 0.65 + gx_f * 0.35)
        ny_d = -(gy_m * 0.65 + gy_f * 0.35)
        nz_d = np.full((h, w), 0.72, dtype=np.float32)
        n_dep = np.dstack([nx_d, ny_d, nz_d])
        n_dep /= np.linalg.norm(n_dep, axis=2, keepdims=True) + 1e-6

        sap_f = rec.get("sapiens_nrm_f", None)
        if sap_f is not None:
            n_comb = n_dep * 0.65 + sap_f * 0.35
        else:
            n_comb = n_dep
        n_comb[:, :, 2] = np.maximum(n_comb[:, :, 2], 0.25)
        n_comb /= np.linalg.norm(n_comb, axis=2, keepdims=True) + 1e-6

        # Limpiar cualquier anomalía de borde y dilatar 12px hacia afuera desde el núcleo limpio
        n_clean = n_comb.copy()
        n_clean[~alpha_core] = np.array([0.0, 0.0, 1.0], dtype=np.float32)
        n_dil = np.dstack([
            _dilate_field_outside(n_clean[:, :, 0], alpha_core, radius_px=12, blur_k=7),
            _dilate_field_outside(n_clean[:, :, 1], alpha_core, radius_px=12, blur_k=7),
            _dilate_field_outside(n_clean[:, :, 2], alpha_core, radius_px=12, blur_k=7),
        ])
        sil_soft = cv2.GaussianBlur(cv2.dilate(alpha.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(np.float32), (11, 11), 0)
        n_mix = np.dstack([
            n_dil[:, :, 0] * sil_soft,
            n_dil[:, :, 1] * sil_soft,
            n_dil[:, :, 2] * sil_soft + (1.0 - sil_soft),
        ])
        n_mix /= np.linalg.norm(n_mix, axis=2, keepdims=True) + 1e-6
        rec["normal"] = np.clip((n_mix * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)


def _resolve_depth_anything_dir() -> str | None:
    snap_root = DEFAULT_HF_HUB_CACHE / "models--depth-anything--Depth-Anything-V2-Small-hf" / "snapshots"
    if snap_root.is_dir():
        snaps = sorted([p for p in snap_root.iterdir() if p.is_dir()])
        if snaps:
            return str(snaps[-1])
    return None


def _run_depth_anything_batch(items: list[dict]) -> None:
    """Ejecuta Depth-Anything-V2-Small una sola vez desde caché local para todo el lote."""
    from transformers import AutoImageProcessor, AutoModelForDepthEstimation

    clear_vram()
    device = get_device()
    da_proc = None
    da_model = None
    local_dir = _resolve_depth_anything_dir()
    try:
        model_id = local_dir if local_dir else "depth-anything/Depth-Anything-V2-Small-hf"
        print(f"[DEPTH] Cargando Depth-Anything-V2-Small ({device}): {Path(model_id).name}")
        da_proc = AutoImageProcessor.from_pretrained(model_id, local_files_only=True)
        da_model = AutoModelForDepthEstimation.from_pretrained(model_id, local_files_only=True).to(device)
    except Exception as exc:
        print(f"[WARN] No se pudo cargar Depth-Anything-V2 local, usando fallback analítico: {exc}")

    for rec in items:
        rgba = rec["rgba"]
        h, w = rgba.shape[:2]
        alpha = rgba[:, :, 3] > 32
        if da_model is not None and da_proc is not None:
            comp = np.full((h, w, 3), 128, dtype=np.uint8)
            comp[alpha] = rgba[:, :, :3][alpha]
            da_in = da_proc(images=Image.fromarray(comp), return_tensors="pt").to(device)
            with torch.no_grad():
                da_out = da_model(**da_in)
            dep_pred = torch.nn.functional.interpolate(
                da_out.predicted_depth.unsqueeze(1),
                size=(h, w),
                mode="bicubic",
                align_corners=False,
            ).squeeze().cpu().numpy()
            alpha_core = cv2.erode(alpha.astype(np.uint8), np.ones((7, 7), np.uint8), iterations=1) > 0
            valid = dep_pred[alpha_core] if np.any(alpha_core) else dep_pred[alpha]
            dep_norm = np.zeros((h, w), dtype=np.float32)
            if valid.size > 0:
                d_min, d_max = float(np.percentile(valid, 2)), float(np.percentile(valid, 98))
                dep_norm[alpha_core] = np.clip((dep_pred[alpha_core] - d_min) / max(d_max - d_min, 1e-5), 0.0, 1.0)
            dep_dil = _dilate_field_outside(dep_norm, alpha_core, radius_px=22, blur_k=11)
            dep_u8 = np.clip(dep_dil * 255.0, 0, 255).astype(np.uint8)
            rec["depth_f"] = dep_dil
            rec["depth_rgb"] = np.dstack([dep_u8, dep_u8, dep_u8])
            del da_in, da_out
        else:
            dist = cv2.distanceTransform(alpha.astype(np.uint8), cv2.DIST_L2, 5)
            dep_norm = np.sqrt(np.clip(dist / max(float(dist.max()), 1.0), 0.0, 1.0)).astype(np.float32)
            dep_dil = _dilate_field_outside(dep_norm, alpha, radius_px=20, blur_k=13)
            dep_u8 = np.clip(dep_dil * 255.0, 0, 255).astype(np.uint8)
            rec["depth_f"] = dep_dil
            rec["depth_rgb"] = np.dstack([dep_u8, dep_u8, dep_u8])

    if da_model is not None:
        del da_model, da_proc
    clear_vram()


def _extract_clean_masks(rgba: np.ndarray, depth_f: np.ndarray, bbox: list[int]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Extrae id_mask (RGB opaco), ilm_map (RGB opaco) y motion_mask (RGB opaco) sin ruido ni halos."""
    h, w = rgba.shape[:2]
    alpha = rgba[:, :, 3]
    in_sil = alpha > 32

    # Pre-suavizado bilateral preserva líneas de tinta y elimina textura jpg/pixelado antes de clasificar
    smooth_rgb = cv2.bilateralFilter(rgba[:, :, :3], d=9, sigmaColor=30, sigmaSpace=9)
    r = smooth_rgb[:, :, 0].astype(np.float32) / 255.0
    g = smooth_rgb[:, :, 1].astype(np.float32) / 255.0
    b = smooth_rgb[:, :, 2].astype(np.float32) / 255.0

    luma = 0.299 * r + 0.587 * g + 0.114 * b
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    sat = np.where(max_c > 1e-4, (max_c - min_c) / np.maximum(max_c, 1e-4), 0.0)

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    y_norm = yy / float(h)
    x_norm = xx / float(w)
    bx, by, bw, bh = bbox
    face_cx = (bx + bw * 0.50) / float(w)
    face_cy = (by + bh * 0.22) / float(h)

    # Piel clara porcelana-durazno (incluye reflejos en muslos y pecho)
    is_skin = in_sil & (luma > 0.40) & ((r - b) > 0.060) & ((r - g) < 0.25)
    is_ink = in_sil & (luma < 0.095)

    # Acento carmesí + monóculo rojo (ID R)
    raw_crimson = in_sil & (~is_skin) & (~is_ink) & ((r - g) > 0.095) & ((r - b) > 0.055) & (sat > 0.26)
    is_crimson = _clean_binary_mask(raw_crimson, min_area=90, open_k=3, close_k=5)

    # Ojo amatista
    is_violet_eye = _clean_binary_mask(
        in_sil & (y_norm < (by + bh * 0.36) / float(h)) & (b > r + 0.03) & (b > g + 0.04) & (sat > 0.14),
        min_area=30,
        open_k=0,
        close_k=3,
    )

    # Cabello blanco-plateado conectado a la corona (excluye esclerótica, labios y guantes levantados)
    in_face_features = (
        (np.abs(x_norm - face_cx) < 0.055)
        & (y_norm > (by + bh * 0.205) / float(h))
        & (y_norm < (by + bh * 0.345) / float(h))
    )
    hair_seed = (
        in_sil
        & (y_norm < (by + bh * 0.41) / float(h))
        & (~in_face_features)
        & (~is_skin)
        & (~is_crimson)
        & (~is_violet_eye)
        & (~is_ink)
        & (luma > 0.45)
        & (np.abs(r - b) < 0.070)
        & (sat < 0.17)
    )
    h_num, h_lbl, h_stats, _ = cv2.connectedComponentsWithStats(hair_seed.astype(np.uint8), connectivity=8)
    is_hair_raw = np.zeros_like(hair_seed)
    for idx in range(1, h_num):
        if float(h_stats[idx, cv2.CC_STAT_TOP]) < (by + bh * 0.19) and int(h_stats[idx, cv2.CC_STAT_AREA]) >= 1200:
            is_hair_raw[h_lbl == idx] = True
    is_hair = _clean_binary_mask(is_hair_raw, min_area=1200, open_k=3, close_k=5)

    # Placas metálicas claras / brazales acero (ID G): alta reflectividad neutra en brazos/hombreras/placas claras
    # El busto gris carbón mate (#524E58, luma ~0.315) queda fuera de G y pasa a B (traje/body).
    in_limbs_or_shoulders = (np.abs(x_norm - face_cx) > 0.125) | (y_norm > (by + bh * 0.72) / float(h))
    raw_metal = (
        in_sil
        & (~is_skin)
        & (~is_crimson)
        & (~is_hair)
        & (~is_violet_eye)
        & (~is_ink)
        & (y_norm >= (by + bh * 0.33) / float(h))
        & (sat < 0.18)
        & ((luma >= 0.37) | (in_limbs_or_shoulders & (luma >= 0.335)))
    )
    is_metal = _clean_binary_mask(raw_metal, min_area=120, open_k=3, close_k=5)

    # Traje carbón mate / busto / cuello (ID B)
    raw_suit = (
        in_sil
        & (~is_skin)
        & (~is_crimson)
        & (~is_hair)
        & (~is_metal)
        & (~is_violet_eye)
        & (~is_ink)
        & (y_norm >= (by + bh * 0.30) / float(h))
        & (luma < 0.38)
    )
    is_suit = _clean_binary_mask(raw_suit, min_area=140, open_k=3, close_k=5)

    ch_r = np.where(is_crimson, 255.0, 0.0).astype(np.float32)
    ch_g = np.where(is_metal, 255.0, 0.0).astype(np.float32)
    ch_b = np.where(is_suit, 255.0, 0.0).astype(np.float32)
    ch_hair = np.where(is_hair, 255.0, 0.0).astype(np.float32)

    valid_mat = is_crimson | is_metal | is_suit | is_hair | is_skin | is_violet_eye
    ch_r, ch_g, ch_b, ch_hair = _fill_ink_gaps([ch_r, ch_g, ch_b, ch_hair], in_sil, valid_mat, steps=5)

    # ID Mask estrictamente RGB opaco (cero problemas de premultiplicación alfa en Godot!)
    id_mask_rgb = np.dstack([
        np.clip(cv2.GaussianBlur(ch_r, (3, 3), 0), 0, 255).astype(np.uint8),
        np.clip(cv2.GaussianBlur(ch_g, (3, 3), 0), 0, 255).astype(np.uint8),
        np.clip(cv2.GaussianBlur(ch_b, (3, 3), 0), 0, 255).astype(np.uint8),
    ])

    # --- ILM Map RGB opaco (R=Especular Metal/Satín, G=AO/Protección Piel, B=Máscara exacta Cabello) ---
    ilm_metal = np.where(in_sil, 0.14, 0.0).astype(np.float32)
    ilm_metal[ch_b > 128] = 0.26
    ilm_metal[ch_g > 128] = 0.96
    ilm_metal[is_skin] = 0.0
    ilm_metal[ch_hair > 128] = 0.0

    # AO suave: alto en piel (0.94), medio en pelo (0.56), bajando sutilmente en pliegues oscuros/cuello
    depth_blur = cv2.GaussianBlur(depth_f, (21, 21), 0)
    crease_occ = np.clip((depth_blur - depth_f) * 3.5 + 0.5, 0.0, 1.0)
    ilm_ao = np.full((h, w), 0.54, dtype=np.float32)
    ilm_ao[in_sil] = np.clip(0.56 - crease_occ[in_sil] * 0.24 + (luma[in_sil] - 0.35) * 0.18, 0.20, 0.72)
    ilm_ao[is_skin] = 0.94
    ilm_ao[ch_hair > 128] = np.maximum(ilm_ao[ch_hair > 128], 0.54)
    ilm_ao[ch_r > 128] = np.maximum(ilm_ao[ch_r > 128], 0.65)

    ilm_hair = np.clip(cv2.GaussianBlur(ch_hair, (3, 3), 0), 0, 255).astype(np.uint8)
    ilm_map_rgb = np.dstack([
        np.clip(cv2.GaussianBlur(ilm_metal, (5, 5), 0) * 255.0, 0, 255).astype(np.uint8),
        np.clip(cv2.GaussianBlur(ilm_ao, (7, 7), 0) * 255.0, 0, 255).astype(np.uint8),
        ilm_hair,
    ])

    # --- Motion Mask RGB opaco (R=Respiración busto, G=Cabello dilatado, B=Ojo+Monóculo) ---
    chest_cx = (bx + bw * 0.50) / float(w)
    chest_cy = (by + bh * 0.50) / float(h)
    dist_chest = ((x_norm - chest_cx) / 0.24) ** 2 + ((y_norm - chest_cy) / 0.19) ** 2
    breath_field = np.exp(-dist_chest) * np.where(in_sil, 1.0, 0.0)
    head_suppress = np.clip((y_norm - (by + bh * 0.34) / float(h)) / 0.08, 0.0, 1.0)
    breath_field = cv2.GaussianBlur((breath_field * head_suppress).astype(np.float32), (25, 25), 0)

    hair_bin = (ch_hair > 128).astype(np.float32)
    hair_dilated = _dilate_field_outside(hair_bin, hair_bin > 0.5, radius_px=8, blur_k=9)
    hair_root_pin = np.clip((y_norm - (by + bh * 0.155) / float(h)) / 0.12, 0.0, 1.0).astype(np.float32)
    face_oval = ((x_norm - face_cx) / 0.095) ** 2 + ((y_norm - face_cy) / 0.105) ** 2
    protect_face = np.clip((face_oval - 0.65) / 0.55, 0.0, 1.0).astype(np.float32)
    hair_motion = np.clip(hair_dilated * protect_face * hair_root_pin, 0.0, 1.0)

    in_eye_window = (y_norm > (by + bh * 0.14) / float(h)) & (y_norm < (by + bh * 0.305) / float(h)) & (np.abs(x_norm - face_cx) < 0.11)
    is_eye_or_monocle = _clean_binary_mask(
        (is_violet_eye | is_crimson) & in_eye_window,
        min_area=35,
        open_k=0,
        close_k=3,
    ).astype(np.float32)
    eye_motion = cv2.GaussianBlur(cv2.dilate(is_eye_or_monocle, np.ones((3, 3), np.uint8)), (5, 5), 0)

    motion_mask_rgb = np.dstack([
        np.clip(breath_field * 255.0, 0, 255).astype(np.uint8),
        np.clip(hair_motion * 255.0, 0, 255).astype(np.uint8),
        np.clip(eye_motion * 255.0, 0, 255).astype(np.uint8),
    ])

    return id_mask_rgb, ilm_map_rgb, motion_mask_rgb


def _composite_rgba(rgba: np.ndarray, bg_rgb: np.ndarray) -> np.ndarray:
    a = rgba[:, :, 3:4].astype(np.float32) / 255.0
    fg = rgba[:, :, :3].astype(np.float32)
    return np.clip(fg * a + bg_rgb.astype(np.float32) * (1.0 - a), 0, 255).astype(np.uint8)


def _render_audit_sheet(records: list[dict], audit_path: Path) -> None:
    if not records:
        return
    tile = 260
    n = len(records)
    rows = 6
    pad = 10
    sheet_w = n * tile + (n + 1) * pad
    sheet_h = rows * tile + (rows + 1) * pad + 26
    canvas = np.full((sheet_h, sheet_w, 3), 12, dtype=np.uint8)
    dark_bg = np.full((tile, tile, 3), np.array([10, 13, 24], dtype=np.uint8))

    row_tags = ["ALBEDO", "NORMAL (Sapiens)", "DEPTH (DA-V2)", "ID MASK", "ILM (Spec/AO/Hair)", "MOTION"]
    for col_idx, rec in enumerate(records):
        x = pad + col_idx * (tile + pad)
        cv2.putText(canvas, rec["emotion"].upper(), (x + 6, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.58, (230, 238, 255), 2, cv2.LINE_AA)

        imgs = [
            _composite_rgba(cv2.resize(rec["rgba"], (tile, tile), interpolation=cv2.INTER_AREA), dark_bg),
            cv2.resize(rec["normal"], (tile, tile), interpolation=cv2.INTER_AREA),
            cv2.resize(rec["depth_rgb"], (tile, tile), interpolation=cv2.INTER_AREA),
            cv2.resize(rec["id_mask"], (tile, tile), interpolation=cv2.INTER_AREA),
            cv2.resize(rec["ilm_map"], (tile, tile), interpolation=cv2.INTER_AREA),
            cv2.resize(rec["motion_mask"], (tile, tile), interpolation=cv2.INTER_AREA),
        ]
        for r_idx, tile_img in enumerate(imgs):
            y = pad + 24 + r_idx * (tile + pad)
            canvas[y : y + tile, x : x + tile] = tile_img
            if col_idx == 0:
                cv2.putText(canvas, row_tags[r_idx], (x + 6, y + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 235, 140), 1, cv2.LINE_AA)

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, mode="RGB").save(audit_path)
    print(f"[AUDIT] Guardada hoja de auditoría 6 filas: {audit_path}")


def _collect_sources(src_dir: Path) -> list[Path]:
    files = {p.stem.lower(): p for p in src_dir.glob("*.png") if p.is_file()}
    ordered: list[Path] = []
    for em in PREFERRED_ORDER:
        if em in files:
            ordered.append(files.pop(em))
    for em in sorted(files.keys()):
        ordered.append(files[em])
    return ordered


def main() -> int:
    parser = argparse.ArgumentParser(description="Compila retratos de diálogo con Sapiens Normals, DA-V2 Depth e ILM.")
    parser.add_argument("--pilot-id", default="valentina_v2")
    parser.add_argument("--src-dir", default="")
    parser.add_argument("--out-dir", default="")
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--no-upscayl", action="store_true")
    parser.add_argument("--ignore-ai-motion-masks", action="store_true")
    parser.add_argument("--audit-out", default="")
    args = parser.parse_args()

    pilot_id: str = args.pilot_id.strip()
    source_root = PILOT_RIG_LAB_DIR / "source_refs" / f"{pilot_id}_dialogue"
    src_dir = Path(args.src_dir) if args.src_dir else (source_root / "01_raw")
    out_dir = Path(args.out_dir) if args.out_dir else (REPO_ROOT / "assets" / "pilots" / pilot_id / "dialogue")
    audit_out = Path(args.audit_out) if args.audit_out else (source_root / "audit_dialogue_sheet.png")
    upscayl_cache = source_root / "02_upscayl_4x"

    sources = _collect_sources(src_dir)
    if not sources:
        print(f"[ERROR] No se encontraron PNGs en {src_dir}")
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)

    # Etapa 1: Upscayl 4x + Matting compartido rembg (isnet-anime) + Normalización 1024x1024
    from rembg import new_session

    clear_vram()
    rembg_session = new_session("isnet-anime")
    items: list[dict] = []
    for src_png in sources:
        emotion = src_png.stem.lower()
        print(f"[STAGE 1/4] Matting & Norm '{emotion}'...")
        up_pil = _upscale_source(src_png, upscayl_cache, args.no_upscayl)
        fg_rgba = _extract_clean_rgba_with_session(up_pil, rembg_session)
        norm_rgba, meta = _normalize_to_canvas(fg_rgba, target_size=args.size)
        items.append({"emotion": emotion, "rgba": norm_rgba, "meta": meta})
    del rembg_session
    clear_vram()

    # Etapa 2: Sapiens Normal 0.3B
    print("[STAGE 2/4] Sapiens-Normal-0.3B...")
    _run_sapiens_normals_batch(items)

    # Etapa 3: Depth-Anything-V2-Small
    print("[STAGE 3/4] Depth-Anything-V2-Small...")
    _run_depth_anything_batch(items)
    _build_fused_normals(items)

    # Etapa 4: Máscaras limpias ID / ILM / Motion y exportación
    print("[STAGE 4/4] Máscaras ID/ILM/Motion & exportación...")
    manifest_entries: list[dict] = []
    for rec in items:
        emotion = rec["emotion"]
        id_mask, ilm_map, motion_mask = _extract_clean_masks(rec["rgba"], rec["depth_f"], rec["meta"]["bbox"])
        mot_name = f"{pilot_id}_dialogue_{emotion}_motion_mask.png"
        ai_mot_path = source_root / "04_motion_masks_ai" / "extracted" / mot_name
        if (not args.ignore_ai_motion_masks) and ai_mot_path.is_file():
            motion_mask = np.array(
                Image.open(ai_mot_path).convert("RGB").resize((args.size, args.size), Image.Resampling.BILINEAR),
                dtype=np.uint8,
            )
            print(f"[AI_MASK] Usando motion mask refinada: {ai_mot_path.name}")
        rec["id_mask"] = id_mask
        rec["ilm_map"] = ilm_map
        rec["motion_mask"] = motion_mask

        albedo_name = f"{pilot_id}_dialogue_{emotion}.png"
        normal_name = f"{pilot_id}_dialogue_{emotion}_normal.png"
        depth_name = f"{pilot_id}_dialogue_{emotion}_depth.png"
        id_name = f"{pilot_id}_dialogue_{emotion}_id_mask.png"
        ilm_name = f"{pilot_id}_dialogue_{emotion}_ilm_map.png"

        Image.fromarray(rec["rgba"], mode="RGBA").save(out_dir / albedo_name)
        Image.fromarray(rec["normal"], mode="RGB").save(out_dir / normal_name)
        Image.fromarray(rec["depth_rgb"], mode="RGB").save(out_dir / depth_name)
        Image.fromarray(id_mask, mode="RGB").save(out_dir / id_name)
        Image.fromarray(ilm_map, mode="RGB").save(out_dir / ilm_name)
        Image.fromarray(motion_mask, mode="RGB").save(out_dir / mot_name)

        manifest_entries.append({
            "emotion": emotion,
            "albedo": albedo_name,
            "normal_map": normal_name,
            "depth_map": depth_name,
            "id_mask": id_name,
            "ilm_map": ilm_name,
            "motion_mask": mot_name,
            "size": [args.size, args.size],
            "bbox": rec["meta"]["bbox"],
        })

    manifest = {
        "schema_version": 2,
        "pilot_id": pilot_id,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "canvas_size": args.size,
        "emotions": [e["emotion"] for e in manifest_entries],
        "entries": manifest_entries,
    }
    (out_dir / f"{pilot_id}_dialogue_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    _render_audit_sheet(items, audit_out)
    print(f"[OK] Compilados {len(manifest_entries)} retratos HQ (6 mapas c/u) en {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
