"""Compilador de Live Banner 2.5D + Icono 1:1 para PilotRigLab (Banner Lab).

Soporta modo HQ asistido por las 3 máscaras IA:
  --mask-parts : Máscara 1 (R=torso/busto, G=pelo, B=brazo libre, Y=brazo cadera, C=rostro, M=piernas)
  --mask-mat   : Máscara 2 (B=ojo, G=monóculo, Y=trim carmesí, R=traje, C=piel, M=pelo)
  --mask-depth : Máscara 3 (Depth Map 2.5D en escala de grises)

Salidas limpias sin fantasmas de borde:
  1. <pilot>_splash_base.png        (RGBA completo original)
  2. <pilot>_body_layer.png         (RGBA cuerpo sin brazo libre, con solape limpio en hombro)
  3. <pilot>_free_arm_layer.png     (RGBA solo brazo libre derecho pivotado en hombro)
  4. <pilot>_splash_motion_mask.png (R=respiración busto, G=cabello DILATADO sin escalón de borde)
  5. <pilot>_splash_fx_mask.png     (R=traje/skin, G=monóculo+trim carmesí, B=ojo amatista)
  6. <pilot>_splash_depth.png       (Depth Map 2.5D DILATADO hacia afuera 28px para cero fantasmas)
  7. <pilot>_icon_1x1.png           (Icono 512x512 rostro + monóculo)
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def _remove_white_background(bgr: np.ndarray) -> np.ndarray:
    h, w = bgr.shape[:2]
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    near_white = (bgr[:, :, 0] > 236) & (bgr[:, :, 1] > 236) & (bgr[:, :, 2] > 236)

    ff_mask = np.zeros((h + 2, w + 2), dtype=np.uint8)
    bg_seed = near_white.astype(np.uint8) * 255
    for x in range(0, w, max(1, w // 40)):
        if bg_seed[0, x] == 255 and ff_mask[1, x + 1] == 0:
            cv2.floodFill(bg_seed, ff_mask, (x, 0), 128)
        if bg_seed[h - 1, x] == 255 and ff_mask[h, x + 1] == 0:
            cv2.floodFill(bg_seed, ff_mask, (x, h - 1), 128)
    for y in range(0, h, max(1, h // 40)):
        if bg_seed[y, 0] == 255 and ff_mask[y + 1, 1] == 0:
            cv2.floodFill(bg_seed, ff_mask, (0, y), 128)
        if bg_seed[y, w - 1] == 255 and ff_mask[y + 1, w] == 0:
            cv2.floodFill(bg_seed, ff_mask, (w - 1, y), 128)

    num_lbl, labels, stats, _ = cv2.connectedComponentsWithStats(near_white.astype(np.uint8), connectivity=4)
    is_bg = (bg_seed == 128)
    for lbl in range(1, num_lbl):
        area = int(stats[lbl, cv2.CC_STAT_AREA])
        if area > 450:
            comp = (labels == lbl)
            if float(gray[comp].mean()) > 248.0:
                is_bg |= comp

    alpha = (~is_bg).astype(np.uint8) * 255
    dist_in = cv2.distanceTransform(alpha, cv2.DIST_L2, 3)
    edge_band = (dist_in > 0.0) & (dist_in <= 2.2)
    alpha_f = alpha.astype(np.float32) / 255.0
    whiteness = np.clip((gray.astype(np.float32) - 210.0) / 45.0, 0.0, 1.0)
    alpha_f[edge_band] *= (1.0 - whiteness[edge_band] * 0.78)
    alpha_u8 = np.clip(alpha_f * 255.0, 0, 255).astype(np.uint8)

    bgr_out = bgr.copy()
    eroded = cv2.erode(alpha, np.ones((3, 3), np.uint8), iterations=1)
    fringe = (alpha_u8 > 0) & (eroded == 0)
    if np.any(fringe):
        dark_nbr = cv2.erode(bgr, np.ones((3, 3), np.uint8), iterations=1)
        bgr_out[fringe] = np.clip(
            bgr_out[fringe].astype(np.float32) * 0.45 + dark_nbr[fringe].astype(np.float32) * 0.55,
            0,
            255,
        ).astype(np.uint8)

    return np.dstack([bgr_out, alpha_u8])


def _dilate_field_outside(field: np.ndarray, valid_mask: np.ndarray, radius_px: int = 28) -> np.ndarray:
    """Extiende un campo escalar (ej. depth o hair_mask) más allá del borde de la silueta
    para eliminar el escalón brusco que genera fantasmas al deformar UV en fragment()."""
    out = field.copy()
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    known = valid_mask.astype(np.uint8)
    steps = max(1, radius_px // 3)
    for _ in range(steps):
        dil_val = cv2.dilate(out, kernel)
        dil_known = cv2.dilate(known, kernel)
        ring = (dil_known > 0) & (known == 0)
        out[ring] = dil_val[ring]
        known = dil_known
    return cv2.GaussianBlur(out, (15, 15), 0)


def _compute_crop_box(alpha: np.ndarray, pad_ratio: float = 0.045) -> tuple[int, int, int, int, int, int, int, int]:
    ys, xs = np.where(alpha > 16)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    ch = y1 - y0 + 1
    cw = x1 - x0 + 1
    pad_y = int(round(ch * pad_ratio))
    out_h = ch + pad_y * 2
    out_w = max(int(round(out_h * 0.72)), cw + int(round(cw * 0.14)))
    cx = (x0 + x1) * 0.5
    dst_x0 = int(round(out_w * 0.5 - (cx - x0)))
    src_x0 = max(0, x0 - max(0, -dst_x0))
    dst_x0 = max(0, dst_x0)
    copy_w = min(cw, out_w - dst_x0, alpha.shape[1] - src_x0)
    copy_h = min(ch, out_h - pad_y, alpha.shape[0] - y0)
    return src_x0, y0, copy_w, copy_h, dst_x0, pad_y, out_w, out_h


def _apply_crop_and_scale(
    img: np.ndarray,
    box: tuple[int, int, int, int, int, int, int, int],
    target_h: int,
    interp: int,
    pad_value: int = 0,
) -> np.ndarray:
    src_x0, y0, copy_w, copy_h, dst_x0, dst_y0, out_w, out_h = box
    ch = img.shape[2] if img.ndim == 3 else 1
    if ch > 1:
        canvas = np.full((out_h, out_w, ch), pad_value, dtype=img.dtype)
    else:
        canvas = np.full((out_h, out_w), pad_value, dtype=img.dtype)
    canvas[dst_y0 : dst_y0 + copy_h, dst_x0 : dst_x0 + copy_w] = img[y0 : y0 + copy_h, src_x0 : src_x0 + copy_w]
    if out_h != target_h:
        scale = float(target_h) / float(out_h)
        canvas = cv2.resize(canvas, (int(round(out_w * scale)), target_h), interpolation=interp)
    return canvas


def _bake_normal_map_from_depth(depth_raw: np.ndarray, sil: np.ndarray, strength: float = 2.0) -> np.ndarray:
    """Deriva un Normal Map tangente RGB limpio SOLO dentro de la silueta (neutro afuera, cero arcoíris)."""
    # Extender depth solo 6px suavemente para evitar caída en el borde del Sobel
    depth_clean = _dilate_field_outside(depth_raw, (depth_raw > 0.04) & (sil > 0), radius_px=8)
    d_smooth = cv2.GaussianBlur(depth_clean.astype(np.float32), (13, 13), 0)
    gx = cv2.Sobel(d_smooth, cv2.CV_32F, 1, 0, ksize=3) * strength
    gy = cv2.Sobel(d_smooth, cv2.CV_32F, 0, 1, ksize=3) * strength
    nx = -gx
    ny = -gy
    nz = np.ones_like(nx, dtype=np.float32) * 0.55
    norm = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    nx /= norm
    ny /= norm
    nz /= norm

    # Neutralizar completamente fuera de la silueta (0, 0, 1)
    sil_soft = cv2.GaussianBlur(sil.astype(np.float32), (7, 7), 0)
    nx *= sil_soft
    ny *= sil_soft
    nz = nz * sil_soft + (1.0 - sil_soft)

    nb = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    ng = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    nr = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    return np.dstack([nb, ng, nr])


def _bake_ink_sdf(ink_bgr: np.ndarray, sil: np.ndarray, range_px: float = 8.0) -> np.ndarray:
    """Hornea un mapa Ink SDF limpio (±range_px en [0..255], 128=borde, <128=tinta, 255=fondo)."""
    gray = cv2.cvtColor(ink_bgr, cv2.COLOR_BGR2GRAY)
    sil_dil = cv2.dilate(sil.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))) > 0
    is_ink = ((gray < 155) & sil_dil).astype(np.uint8)
    dist_out = cv2.distanceTransform(1 - is_ink, cv2.DIST_L2, 5)
    dist_in = cv2.distanceTransform(is_ink, cv2.DIST_L2, 5)
    signed_dist = dist_out - dist_in
    norm = np.clip(0.5 + signed_dist / (2.0 * range_px), 0.0, 1.0)
    return np.clip(norm * 255.0, 0, 255).astype(np.uint8)


def build_banner_pack(
    src_path: Path,
    out_dir: Path,
    prefix: str = "valentina_v2",
    mask_parts_path: Path | None = None,
    mask_mat_path: Path | None = None,
    mask_depth_path: Path | None = None,
    mask_ink_path: Path | None = None,
) -> dict:
    bgr = cv2.imread(str(src_path), cv2.IMREAD_COLOR)
    if bgr is None:
        raise FileNotFoundError(f"No se pudo leer {src_path}")
    src_h, src_w = bgr.shape[:2]

    rgba_full = _remove_white_background(bgr)
    box = _compute_crop_box(rgba_full[:, :, 3], pad_ratio=0.045)
    target_h = max(1536, box[7])

    rgba = _apply_crop_and_scale(rgba_full, box, target_h, cv2.INTER_LANCZOS4)
    h, w = rgba.shape[:2]
    alpha_f = rgba[:, :, 3].astype(np.float32) / 255.0
    sil = (rgba[:, :, 3] > 24).astype(np.uint8)

    ys, xs = np.where(sil > 0)
    top_y, bot_y = float(ys.min()), float(ys.max())
    body_h = max(1.0, bot_y - top_y)
    center_x = float(np.median(xs))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    def _load_aligned(p: Path | None, interp: int, pad_val: int = 0) -> np.ndarray | None:
        if p is None or not p.exists():
            return None
        im = cv2.imread(str(p), cv2.IMREAD_COLOR)
        if im is None:
            return None
        if im.shape[:2] != (src_h, src_w):
            im = cv2.resize(im, (src_w, src_h), interpolation=interp)
        return _apply_crop_and_scale(im, box, target_h, interp, pad_value=pad_val)

    m_parts = _load_aligned(mask_parts_path, cv2.INTER_NEAREST, 0)
    m_mat = _load_aligned(mask_mat_path, cv2.INTER_NEAREST, 0)
    m_depth = _load_aligned(mask_depth_path, cv2.INTER_LINEAR, 0)
    m_ink = _load_aligned(mask_ink_path, cv2.INTER_AREA, 255)

    # --- 1. Depth Map 2.5D DILATADO hacia afuera (cero escalón en bordes!) ---
    if m_depth is not None:
        depth_raw = cv2.cvtColor(m_depth, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
        depth_valid = (depth_raw > 0.04) & (sil > 0)
        depth_padded = _dilate_field_outside(depth_raw, depth_valid, radius_px=30)
    else:
        dist_sil = cv2.distanceTransform(sil, cv2.DIST_L2, 5)
        depth_raw = np.clip(dist_sil / max(1.0, float(dist_sil.max())), 0.0, 1.0)
        depth_padded = _dilate_field_outside(depth_raw, sil > 0, radius_px=30)

    # --- 2. Material & FX Mask (de Máscara 2 IA) ---
    if m_mat is not None:
        mb, mg, mr = m_mat[:, :, 0].astype(np.float32), m_mat[:, :, 1].astype(np.float32), m_mat[:, :, 2].astype(np.float32)
        eye_bin = (mb > 140) & (mr < 90) & (mg < 90)
        monocle_bin = (mg > 140) & (mr < 90) & (mb < 90)
        hair_mat_bin = (mr > 140) & (mb > 140) & (mg < 90)
        yellow_bin = (mr > 140) & (mg > 140) & (mb < 90)
        sil_eroded = cv2.erode(sil, np.ones((13, 13), np.uint8), iterations=1) > 0
        maroon_in = (mr > 60) & (mr < 165) & (mg < 55) & (mb < 75) & sil_eroded
        yellow_dil = cv2.dilate(yellow_bin.astype(np.uint8) * 255, np.ones((9, 9), np.uint8)) > 0
        num_m, lbl_m, _, _ = cv2.connectedComponentsWithStats(maroon_in.astype(np.uint8), connectivity=8)
        maroon_clean = np.zeros_like(maroon_in)
        for lbl_idx in range(1, num_m):
            comp = (lbl_m == lbl_idx)
            if np.any(comp & yellow_dil):
                maroon_clean |= comp
        crimson_trim_bin = yellow_bin | maroon_clean
        suit_bin = (mr > 150) & (mg < 80) & (mb < 80)
        hair_clean_bin = hair_mat_bin & (~monocle_bin)

        # Expandir ojo de Máscara 2 (iris) a la almendra ocular completa (esclera + iris)
        # excluyendo cabello y cejas, conservando solo el componente conexo del centroide del iris.
        b_im, g_im, r_im = rgba[:, :, 0].astype(np.float32), rgba[:, :, 1].astype(np.float32), rgba[:, :, 2].astype(np.float32)
        ey_s, ex_s = np.where(eye_bin)
        if len(ey_s) > 0:
            ecx_s, ecy_s = float(ex_s.mean()), float(ey_s.mean())
            e_box = (np.abs(xx - ecx_s) < 34.0) & (np.abs(yy - ecy_s) < 15.0)
            sclera_px = e_box & (b_im > 155.0) & (g_im > 145.0) & ((r_im - b_im) < 28.0)
            iris_px = e_box & (b_im > 90.0) & (b_im > g_im + 10.0)
            raw_eye = (sclera_px | iris_px | eye_bin) & (~hair_clean_bin) & (yy >= (ecy_s - 10.0))
            almond_u8 = cv2.morphologyEx(raw_eye.astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
            num_e, lbl_e, _, _ = cv2.connectedComponentsWithStats((almond_u8 > 128).astype(np.uint8), connectivity=8)
            seed_lbl = int(lbl_e[int(round(ecy_s)), int(round(ecx_s))])
            if seed_lbl > 0:
                eye_almond_bin = (lbl_e == seed_lbl)
            else:
                # Fallback: componente que más solape con eye_bin
                best_lbl, best_ov = 0, 0
                for lbl_idx in range(1, num_e):
                    ov = int(np.sum((lbl_e == lbl_idx) & eye_bin))
                    if ov > best_ov:
                        best_ov = ov
                        best_lbl = lbl_idx
                eye_almond_bin = (lbl_e == best_lbl) if best_lbl > 0 else eye_bin
        else:
            eye_almond_bin = eye_bin

        eye_mask = cv2.GaussianBlur(eye_almond_bin.astype(np.float32), (3, 3), 0) * alpha_f
        fx_emissive = cv2.GaussianBlur((monocle_bin | crimson_trim_bin).astype(np.float32), (5, 5), 0) * alpha_f
        suit_mask = cv2.GaussianBlur(suit_bin.astype(np.float32), (5, 5), 0) * alpha_f
    else:
        eye_mask = np.zeros((h, w), dtype=np.float32)
        fx_emissive = np.zeros((h, w), dtype=np.float32)
        suit_mask = alpha_f
        hair_clean_bin = np.zeros((h, w), dtype=bool)
        eye_bin = np.zeros((h, w), dtype=bool)

    eye_ys, eye_xs = np.where(eye_bin)
    eye_cx = float(eye_xs.mean()) if len(eye_xs) > 0 else center_x - w * 0.045
    eye_cy = float(eye_ys.mean()) if len(eye_ys) > 0 else top_y + body_h * 0.115

    # --- 3. Separación de Brazo Libre + Motion Mask DILATADA ---
    body_rgba = rgba.copy()
    free_arm_rgba = np.zeros_like(rgba)

    if m_parts is not None:
        pb, pg, pr = m_parts[:, :, 0].astype(np.float32), m_parts[:, :, 1].astype(np.float32), m_parts[:, :, 2].astype(np.float32)
        torso_bin = (pr > 150) & (pg < 80) & (pb < 80)
        free_arm_bin = (pb > 150) & (pr < 80) & (pg < 80)
        hair_parts_bin = (pg > 150) & (pr < 80) & (pb < 80)
        hair_final_bin = hair_clean_bin if np.any(hair_clean_bin) else hair_parts_bin

        # Separar SOLO la parte baja del brazo libre (debajo de la hombrera!), dejando
        # la hombrera 100% ESTÁTICA en el cuerpo tapando limpiamente la articulación!
        arm_u8 = (free_arm_bin.astype(np.uint8) * 255)
        arm_u8 = cv2.morphologyEx(arm_u8, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
        a_ys, a_xs = np.where(free_arm_bin)
        if len(a_ys) > 0:
            ay_min, ay_max = float(a_ys.min()), float(a_ys.max())
            arm_h = max(1.0, ay_max - ay_min)
            # La hombrera ocupa el 26% superior del bloque azul; el brazo móvil nace justo debajo!
            pauldron_cut_y = ay_min + arm_h * 0.255
            # Pivote oculto justo debajo del borde inferior de la hombrera
            hinge_band = (a_ys >= pauldron_cut_y - 12.0) & (a_ys <= pauldron_cut_y + 18.0)
            sh_x = float(np.median(a_xs[hinge_band])) if np.any(hinge_band) else float(np.median(a_xs))
            sh_y = pauldron_cut_y
            # Brazo móvil = solo píxeles por debajo del corte de hombrera (con 14px de solape oculto arriba)
            lower_arm_bin = free_arm_bin & (yy >= (pauldron_cut_y - 14.0))
            lower_arm_remove_bin = free_arm_bin & (yy >= (pauldron_cut_y + 2.0))
        else:
            sh_x, sh_y = center_x - body_h * 0.12, top_y + body_h * 0.28
            lower_arm_bin = free_arm_bin
            lower_arm_remove_bin = free_arm_bin

        l_arm_u8 = cv2.morphologyEx(lower_arm_bin.astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
        l_arm_dil = cv2.dilate(l_arm_u8, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
        arm_alpha_f = cv2.GaussianBlur(l_arm_dil.astype(np.float32) / 255.0, (5, 5), 0)
        # Suavizar suavemente la parte superior oculta bajo la hombrera para cero corte
        top_feather = np.clip((yy - (sh_y - 14.0)) / 18.0, 0.0, 1.0)
        free_arm_rgba[:, :, :3] = rgba[:, :, :3]
        free_arm_rgba[:, :, 3] = np.clip(alpha_f * arm_alpha_f * top_feather * 255.0, 0, 255).astype(np.uint8)

        # En el cuerpo base: dejar la HOMBRERA intacta y remover solo la parte baja del brazo!
        torso_dil = cv2.dilate(torso_bin.astype(np.uint8) * 255, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
        pauldron_keep = (free_arm_bin & (yy < (sh_y + 6.0))).astype(np.uint8) * 255
        pauldron_keep_dil = cv2.dilate(pauldron_keep, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
        l_rem_u8 = cv2.dilate(lower_arm_remove_bin.astype(np.uint8) * 255, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)))
        l_rem_u8 = l_rem_u8 & (~torso_dil) & (~pauldron_keep_dil)
        body_keep_f = 1.0 - cv2.GaussianBlur(l_rem_u8.astype(np.float32) / 255.0, (5, 5), 0)
        body_rgba[:, :, 3] = np.clip(alpha_f * body_keep_f * 255.0, 0, 255).astype(np.uint8)

        # R: Respiración interna del busto (100% contenida dentro del torso, nunca toca bordes!)
        t_ys, t_xs = np.where(torso_bin)
        if len(t_ys) > 0:
            ty_min, ty_max = float(t_ys.min()), float(t_ys.max())
            chest_cx = float(t_xs.mean())
            chest_cy = ty_min + (ty_max - ty_min) * 0.36
        else:
            chest_cx, chest_cy = center_x, top_y + body_h * 0.28

        torso_dist_in = cv2.distanceTransform(torso_bin.astype(np.uint8), cv2.DIST_L2, 5)
        edge_safe = np.clip(torso_dist_in / 18.0, 0.0, 1.0)
        d_chest = np.sqrt(((xx - chest_cx) / (body_h * 0.125)) ** 2 + ((yy - chest_cy) / (body_h * 0.10)) ** 2)
        chest_radial = np.exp(-(d_chest ** 2) * 1.25)
        bust_depth_boost = np.clip((depth_raw - 0.55) / 0.45, 0.0, 1.0)
        chest_raw = torso_bin.astype(np.float32) * edge_safe * np.clip(chest_radial * 0.72 + bust_depth_boost * 0.50, 0.0, 1.0)
        chest_mask = cv2.GaussianBlur(chest_raw, (21, 21), 0)

        # G: Cabello Zero-G DILATADO hacia afuera 26px (cero fantasmas ni bordes cortados en mechones!)
        h_ys, _ = np.where(hair_final_bin)
        if len(h_ys) > 0:
            hy_min, hy_max = float(h_ys.min()), float(h_ys.max())
            hair_grad = np.clip((yy - hy_min) / max(1.0, hy_max - hy_min), 0.15, 1.0)
        else:
            hair_grad = np.ones((h, w), dtype=np.float32)
        hair_inner = hair_final_bin.astype(np.float32) * hair_grad
        # Dilatar el peso del cabello hacia el fondo externo (protegiendo rostro, monóculo y ojo al 100%!)
        face_bin = (pb > 140) & (pg > 140) & (pr < 80)
        hair_dilated = _dilate_field_outside(hair_inner, hair_final_bin, radius_px=24)
        if m_mat is not None:
            protect_u8 = (face_bin | monocle_bin | eye_bin).astype(np.uint8) * 255
        else:
            protect_u8 = face_bin.astype(np.uint8) * 255
        protect_dil = cv2.dilate(protect_u8, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (21, 21)))
        face_protect = 1.0 - cv2.GaussianBlur(protect_dil.astype(np.float32) / 255.0, (13, 13), 0)
        hair_mask = np.clip(hair_dilated * face_protect, 0.0, 1.0)
    else:
        chest_cx, chest_cy = center_x, top_y + body_h * 0.28
        sh_x, sh_y = center_x - body_h * 0.12, top_y + body_h * 0.22
        chest_mask = np.zeros((h, w), dtype=np.float32)
        hair_mask = np.zeros((h, w), dtype=np.float32)

    # Ensamblar PNGs finales (OpenCV BGR)
    motion_bgr = np.dstack([
        np.zeros((h, w), dtype=np.uint8),                        # B = 0 (brazo ya es capa propia!)
        np.clip(hair_mask * 255.0, 0, 255).astype(np.uint8),     # G = Cabello Zero-G dilatado
        np.clip(chest_mask * 255.0, 0, 255).astype(np.uint8),    # R = Respiración interna busto
    ])
    fx_bgr = np.dstack([
        np.clip(eye_mask * 255.0, 0, 255).astype(np.uint8),      # B = Ojo amatista
        np.clip(fx_emissive * 255.0, 0, 255).astype(np.uint8),   # G = Monóculo + acentos carmesí
        np.clip(suit_mask * 255.0, 0, 255).astype(np.uint8),     # R = Traje/armadura (skins)
    ])
    depth_u8 = np.clip(depth_padded * 255.0, 0, 255).astype(np.uint8)
    normal_bgr = _bake_normal_map_from_depth(depth_raw, sil, strength=1.8)
    ink_sdf_u8 = _bake_ink_sdf(m_ink, sil, range_px=8.0) if m_ink is not None else np.full((h, w), 255, dtype=np.uint8)

    # Icono 1:1 (512x512)
    face_cy = top_y + body_h * 0.135
    crop_half = int(round(body_h * 0.145))
    ix0 = max(0, int(round(center_x - crop_half)))
    iy0 = max(0, int(round(face_cy - crop_half)))
    ix1 = min(w, ix0 + crop_half * 2)
    iy1 = min(h, iy0 + crop_half * 2)
    icon_512 = cv2.resize(rgba[iy0:iy1, ix0:ix1], (512, 512), interpolation=cv2.INTER_AREA)

    out_dir.mkdir(parents=True, exist_ok=True)
    p_base = out_dir / f"{prefix}_splash_base.png"
    p_body = out_dir / f"{prefix}_body_layer.png"
    p_arm = out_dir / f"{prefix}_free_arm_layer.png"
    p_motion = out_dir / f"{prefix}_splash_motion_mask.png"
    p_fx = out_dir / f"{prefix}_splash_fx_mask.png"
    p_depth = out_dir / f"{prefix}_splash_depth.png"
    p_normal = out_dir / f"{prefix}_splash_normal.png"
    p_ink_sdf = out_dir / f"{prefix}_splash_ink_sdf.png"
    p_icon = out_dir / f"{prefix}_icon_1x1.png"

    cv2.imwrite(str(p_base), rgba)
    cv2.imwrite(str(p_body), body_rgba)
    cv2.imwrite(str(p_arm), free_arm_rgba)
    cv2.imwrite(str(p_motion), motion_bgr)
    cv2.imwrite(str(p_fx), fx_bgr)
    cv2.imwrite(str(p_depth), depth_u8)
    cv2.imwrite(str(p_normal), normal_bgr)
    cv2.imwrite(str(p_ink_sdf), ink_sdf_u8)
    cv2.imwrite(str(p_icon), icon_512)

    meta = {
        "size": [w, h],
        "chest_center_uv": [round(chest_cx / w, 4), round(chest_cy / h, 4)],
        "eye_center_uv": [round(eye_cx / w, 4), round(eye_cy / h, 4)],
        "iris_center_uv": [round(eye_cx / w, 4), round(eye_cy / h, 4)],
        "right_shoulder_uv": [round(sh_x / w, 4), round(sh_y / h, 4)],
    }
    (out_dir / f"{prefix}_banner_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return meta


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=Path)
    ap.add_argument("--out-dir", required=True, type=Path)
    ap.add_argument("--prefix", default="valentina_v2")
    ap.add_argument("--mask-parts", type=Path, default=None)
    ap.add_argument("--mask-mat", type=Path, default=None)
    ap.add_argument("--mask-depth", type=Path, default=None)
    ap.add_argument("--mask-ink", type=Path, default=None)
    args = ap.parse_args()
    meta = build_banner_pack(args.src, args.out_dir, args.prefix, args.mask_parts, args.mask_mat, args.mask_depth, args.mask_ink)
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
