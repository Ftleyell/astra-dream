#!/usr/bin/env python3
"""Compile runtime live-head textures for Valentina v2 from 16:9 semantic & depth sheets.

Consumes:
- `08_head_live_rig/outputs/heads_8dir_live_mask_16x9.png` (11-zone semantic mask, IoU=1.0)
- Uploaded/saved 2.5D grayscale depth sheet (`--depth-sheet`)
- `08_head_live_rig/head_live_sheet_manifest.json`
- Canonical `heads/<head>.png` and `heads/<head>_id_mask.png`

Generates per head (plus `head_side` alias) in `assets/pilots/valentina_v2/planar/heads/`:
- `<head>_face_live_mask.png`    (RGBA: R=eyelid/blink, G=iris, B=eyebrows, A=mouth + neck weld)
- `<head>_hair_jiggle_mask.png`  (RGB: R=bangs, G=side locks, B=rear/nape; crown=0, face=0)
- `<head>_normal_depth.png`      (RGBA: RGB=70% cranial dome + 30% Sobel relief, A=depth [80..245])

Also writes clean 16:9 depth output + visual audit sheets under `08_head_live_rig/`.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import cv2
import numpy as np
import scipy.ndimage as ndimage

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parents[2]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from export_head_live_mask_sheet import SHEET_H, SHEET_W, WORK_SUBDIR  # noqa: E402
from fuse_head_live_mask_sheet import (  # noqa: E402
    KEY_TO_IDX,
    _classify_all_palette,
    _extract_slot_patch,
)
from process_head_8dir_sheet import _build_clean_head_normal_depth  # noqa: E402
from rig_v2_lib.constants import DEFAULT_OUT_DIR, DEFAULT_SOURCE_DIR  # noqa: E402

DEFAULT_DEPTH_SHEET = Path(
    r"C:/Users/Frani/.gemini/antigravity/brain/6a2782c5-870c-48aa-bd0f-fa06a7ff5fb4/.user_uploaded/media_1795143718015_47c9b6c1.jpg"
)


def _smoothstep01(x: np.ndarray) -> np.ndarray:
    t = np.clip(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _voronoi_fill_array(arr: np.ndarray, valid_mask: np.ndarray) -> np.ndarray:
    """Fill pixels outside valid_mask with nearest valid pixel via Euclidean Voronoi."""
    if np.all(valid_mask) or not np.any(valid_mask):
        return arr
    out = arr.copy()
    indices = ndimage.distance_transform_edt(~valid_mask, return_distances=False, return_indices=True)
    missing = ~valid_mask
    out[missing] = arr[indices[0][missing], indices[1][missing]]
    return out


def _clean_depth_patch(depth_patch_u8: np.ndarray, fg: np.ndarray) -> tuple[np.ndarray, float]:
    """Erode AI outline fringe by 2 px, Voronoi-fill full rect, and smooth lightly."""
    ai_fg = depth_patch_u8 >= 18
    iou = float((fg & ai_fg).sum()) / float(max((fg | ai_fg).sum(), 1))

    erode_k = np.ones((5, 5), dtype=np.uint8)
    eroded = (cv2.erode(ai_fg.astype(np.uint8), erode_k, iterations=1) > 0) & fg
    if not np.any(eroded):
        eroded = fg

    filled = _voronoi_fill_array(depth_patch_u8.astype(np.float32), eroded)
    smoothed = cv2.GaussianBlur(filled, (5, 5), 1.0)
    return smoothed, iou


EAR_HEAD_KEYS: frozenset[str] = frozenset({"head_side_r", "head_side_l", "head_back_r", "head_back_l"})


def _detect_ear_mask(head_key: str, is_skin: np.ndarray) -> np.ndarray:
    """Detect exposed ear / isolated side-skin islands in profile and 3/4-back views."""
    h, w = is_skin.shape
    if head_key not in EAR_HEAD_KEYS or not np.any(is_skin):
        return np.zeros((h, w), dtype=bool)
    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(is_skin.astype(np.uint8), connectivity=8)
    ear = np.zeros((h, w), dtype=bool)
    for cc in range(1, n_cc):
        area = int(stats[cc, cv2.CC_STAT_AREA])
        top_y = int(stats[cc, cv2.CC_STAT_TOP])
        if 300 <= area <= 2200 and top_y >= 128:
            ear |= (lbl == cc)
    return ear


def _extract_almond_eye_socket(
    col_bgr: np.ndarray,
    is_skin: np.ndarray,
    is_iris: np.ndarray,
    is_eyelid: np.ndarray,
) -> np.ndarray:
    """Extract full almond eye opening (sclera + iris + pupil) bounded by dark lash ink."""
    h, w = is_skin.shape
    seed = is_iris | is_eyelid
    if not np.any(seed):
        return np.zeros((h, w), dtype=bool)

    ys, xs = np.where(seed)
    y0 = max(0, int(ys.min()) - 10)
    y1 = min(h, int(ys.max()) + 10)
    x0 = max(0, int(xs.min()) - 12)
    x1 = min(w, int(xs.max()) + 12)

    patch = col_bgr[y0:y1, x0:x1, :3].astype(np.float32)
    b, g, r = patch[:, :, 0], patch[:, :, 1], patch[:, :, 2]
    luma = 0.114 * b + 0.587 * g + 0.299 * r
    warmth = r - b

    skin_box = is_skin[y0:y1, x0:x1]
    iris_box = is_iris[y0:y1, x0:x1]
    non_skin = skin_box & (luma >= 72.0) & (warmth < 24.0)

    n_cc, lbl, stats, _ = cv2.connectedComponentsWithStats(non_skin.astype(np.uint8), connectivity=4)
    # Expand iris seed slightly so dark iris ring does not trap connected components away from sclera
    iris_expanded = cv2.dilate(iris_box.astype(np.uint8), np.ones((7, 7), dtype=np.uint8)) > 0
    sclera_bridge = iris_expanded & (luma >= 160.0) & non_skin
    seed_ref = (iris_box | sclera_bridge) if np.any(iris_box) else seed[y0:y1, x0:x1]

    socket_box = np.zeros_like(non_skin)
    for cc in range(1, n_cc):
        if int(stats[cc, cv2.CC_STAT_AREA]) < 8:
            continue
        if np.any((lbl == cc) & seed_ref):
            socket_box |= (lbl == cc)

    # Include iris/pupil seed directly and bridge 1-2px dark iris outline & pupil slit via closing
    socket_merged = socket_box | iris_box
    close_k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    socket_closed = cv2.morphologyEx(socket_merged.astype(np.uint8), cv2.MORPH_CLOSE, close_k) > 0
    socket_box = ndimage.binary_fill_holes(socket_closed) & skin_box

    # Keep only the single largest merged almond eye opening component
    n_m, lbl_m, st_m, _ = cv2.connectedComponentsWithStats(socket_box.astype(np.uint8), connectivity=8)
    if n_m > 2:
        best_m = max(range(1, n_m), key=lambda k: int(st_m[k, cv2.CC_STAT_AREA]))
        socket_box = (lbl_m == best_m)

    out = np.zeros((h, w), dtype=bool)
    out[y0:y1, x0:x1] = socket_box
    return out


def _build_face_live_mask(
    col_bgr: np.ndarray,
    cls_idx: np.ndarray,
    fg: np.ndarray,
    is_neck: np.ndarray,
    is_skin: np.ndarray,
) -> np.ndarray:
    """Compile RGBA face_live_mask: R=lid zone, G=almond eye socket, B=eyebrows, A=mouth + neck weld."""
    h, w = fg.shape
    is_eyelid = (cls_idx == KEY_TO_IDX["eyelid"]) & is_skin
    is_iris = (cls_idx == KEY_TO_IDX["iris_pupil"]) & is_skin
    is_eyebrow = (cls_idx == KEY_TO_IDX["eyebrow"]) & is_skin
    is_mouth = (cls_idx == KEY_TO_IDX["mouth"]) & is_skin

    k3 = np.ones((3, 3), dtype=np.uint8)
    k5 = np.ones((5, 5), dtype=np.uint8)

    eye_socket = _extract_almond_eye_socket(col_bgr, is_skin, is_iris, is_eyelid)
    if not np.any(eye_socket):
        eye_socket = is_iris

    # R: full eye socket + upper eyelid arch for clean blink wipe
    r_raw = np.zeros((h, w), dtype=np.float32)
    lid_union = eye_socket | is_eyelid
    if np.any(lid_union):
        lid_guard = (cv2.dilate(lid_union.astype(np.uint8), k5) > 0) & is_skin
        r_blur = cv2.GaussianBlur(lid_union.astype(np.float32), (3, 3), 0.85)
        r_raw = np.where(lid_guard, r_blur, 0.0)

    # G: crisp almond eye opening (sclera + iris + pupil) tight to lash outline
    g_raw = np.zeros((h, w), dtype=np.float32)
    if np.any(eye_socket):
        socket_guard = (cv2.dilate(eye_socket.astype(np.uint8), k3) > 0) & is_skin
        g_blur = cv2.GaussianBlur(eye_socket.astype(np.float32), (3, 3), 0.55)
        g_raw = np.where(socket_guard, g_blur, 0.0)

    # B: eyebrows
    b_raw = np.zeros((h, w), dtype=np.float32)
    if np.any(is_eyebrow):
        brow_guard = (cv2.dilate(is_eyebrow.astype(np.uint8), k5) > 0) & is_skin
        b_blur = cv2.GaussianBlur(is_eyebrow.astype(np.float32), (5, 5), 1.0)
        b_raw = np.where(brow_guard, b_blur, 0.0)

    # A: mouth (on face skin) + vertical cervical weld gradient (0 jaw -> 1 neck base)
    a_raw = np.zeros((h, w), dtype=np.float32)
    if np.any(is_mouth):
        mouth_guard = (cv2.dilate(is_mouth.astype(np.uint8), k5) > 0) & is_skin
        m_blur = cv2.GaussianBlur(is_mouth.astype(np.float32), (3, 3), 0.9)
        a_raw = np.where(mouth_guard, m_blur, a_raw)

    if np.any(is_neck):
        ny, _ = np.where(is_neck)
        ny0, ny1 = float(ny.min()), float(ny.max())
        yy = np.broadcast_to(np.arange(h, dtype=np.float32)[:, None], (h, w))
        t_neck = (yy - ny0) / max(ny1 - ny0, 1.0)
        weld_val = _smoothstep01((t_neck - 0.12) / 0.80)
        # Bleed cervical weld 3 px outside neck edge onto transparent margin to avoid bilinear drops
        neck_bleed = (cv2.dilate(is_neck.astype(np.uint8), np.ones((7, 7), dtype=np.uint8)) > 0) & (~is_skin)
        a_raw = np.where(neck_bleed, weld_val, a_raw)

    # OpenCV BGRA -> PNG RGBA
    bgra = np.zeros((h, w, 4), dtype=np.uint8)
    bgra[:, :, 2] = np.clip(np.round(r_raw * 255.0), 0, 255).astype(np.uint8)  # R
    bgra[:, :, 1] = np.clip(np.round(g_raw * 255.0), 0, 255).astype(np.uint8)  # G
    bgra[:, :, 0] = np.clip(np.round(b_raw * 255.0), 0, 255).astype(np.uint8)  # B
    bgra[:, :, 3] = np.clip(np.round(a_raw * 255.0), 0, 255).astype(np.uint8)  # A
    return bgra


def _build_hair_jiggle_3zone(
    head_key: str,
    cls_idx: np.ndarray,
    fg: np.ndarray,
    is_hair: np.ndarray,
    is_skin: np.ndarray,
) -> np.ndarray:
    """Compile 3-channel RGB hair mask with Voronoi outer-outline bleed and ear/face guards."""
    h, w = fg.shape
    is_crown = (cls_idx == KEY_TO_IDX["hair_crown"]) & is_hair
    if np.any(is_crown):
        dist_from_crown = cv2.distanceTransform((~is_crown).astype(np.uint8), cv2.DIST_L2, 5)
        pin = _smoothstep01(dist_from_crown / 34.0)
    else:
        ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
        pin = _smoothstep01((ys - 0.16) / 0.38)

    non_hair_fg = fg & (~is_hair)
    dist_from_non_hair = cv2.distanceTransform((~non_hair_fg).astype(np.uint8), cv2.DIST_L2, 5)
    face_guard_r = _smoothstep01((dist_from_non_hair - 0.5) / 3.0)
    face_guard_gb = _smoothstep01((dist_from_non_hair - 0.5) / 3.5)

    ear_mask = _detect_ear_mask(head_key, is_skin)
    if np.any(ear_mask):
        dist_from_ear = cv2.distanceTransform((~ear_mask).astype(np.uint8), cv2.DIST_L2, 5)
        ear_guard = _smoothstep01((dist_from_ear - 1.5) / 5.5)
    else:
        ear_guard = np.ones((h, w), dtype=np.float32)

    hair_den = cv2.GaussianBlur(is_hair.astype(np.float32), (11, 11), 3.0)
    hair_den = np.maximum(hair_den, 1e-4)

    fg_weights = np.zeros((h, w, 3), dtype=np.float32)
    zone_specs = (
        ("hair_bangs", 2, face_guard_r),
        ("hair_sides", 1, face_guard_gb * ear_guard),
        ("hair_back", 0, face_guard_gb * ear_guard),
    )
    for zone_key, ch_idx, guard in zone_specs:
        zone = (cls_idx == KEY_TO_IDX[zone_key]) & is_hair
        if np.any(zone):
            w_num = cv2.GaussianBlur(zone.astype(np.float32), (11, 11), 3.0)
            w_norm = np.where(is_hair, np.clip(w_num / hair_den, 0.0, 1.0), 0.0)
            fg_weights[:, :, ch_idx] = np.where(is_hair, np.clip(w_norm * pin * guard, 0.0, 1.0), 0.0)

    # Propagate exact edge hair weights outward into transparent outline margin (~fg),
    # while non-hair fg (face/ears/neck) keeps 0.0 so chin/ear/neck borders never move.
    bleed_weights = _voronoi_fill_array(fg_weights, fg)
    dist_out = cv2.distanceTransform((~fg).astype(np.uint8), cv2.DIST_L2, 5)
    out_falloff = 1.0 - _smoothstep01((dist_out - 12.0) / 8.0)
    final_f = np.where(fg[:, :, None], fg_weights, bleed_weights * out_falloff[:, :, None])
    return np.clip(np.round(final_f * 255.0), 0, 255).astype(np.uint8)


def _build_normal_depth_25d(
    head_key: str,
    depth_smooth: np.ndarray,
    cls_idx: np.ndarray,
    col_alpha: np.ndarray,
    fg: np.ndarray,
    is_neck: np.ndarray,
    is_monocle: np.ndarray,
    is_skin: np.ndarray,
) -> np.ndarray:
    """Compile RGBA normal_depth: 70% cranial dome + 30% Sobel relief, A=normalized depth [80..245]."""
    fg_vals = depth_smooth[fg]
    d_lo = float(np.percentile(fg_vals, 2.0))
    d_hi = max(float(np.percentile(fg_vals, 98.5)), d_lo + 1.0)
    depth_norm = 80.0 + np.clip((depth_smooth - d_lo) / (d_hi - d_lo), 0.0, 1.0) * (245.0 - 80.0)

    is_bangs = (cls_idx == KEY_TO_IDX["hair_bangs"]) & fg
    depth_norm = np.where(is_neck, np.clip(depth_norm, 80.0, 135.0), depth_norm)
    depth_norm = np.where(is_bangs, np.maximum(depth_norm, 215.0), depth_norm)
    depth_norm = np.where(is_monocle, np.maximum(depth_norm, 235.0), depth_norm)

    ear_mask = _detect_ear_mask(head_key, is_skin)
    if np.any(ear_mask):
        dist_ear = cv2.distanceTransform((~ear_mask).astype(np.uint8), cv2.DIST_L2, 5)
        ring = (dist_ear >= 5.0) & (dist_ear <= 14.0) & fg & (~is_neck)
        temple_depth = float(np.median(depth_norm[ring])) if np.any(ring) else 185.0
        depth_norm = np.where(ear_mask, 0.30 * depth_norm + 0.70 * temple_depth, depth_norm)
        ear_blurred = cv2.GaussianBlur(depth_norm.astype(np.float32), (9, 9), 2.5)
        ear_blend = (1.0 - _smoothstep01((dist_ear - 2.0) / 8.0)) * fg.astype(np.float32)
        depth_norm = depth_norm * (1.0 - ear_blend) + ear_blurred * ear_blend

    # Smooth transitions gently inside fg and Voronoi-fill transparent border
    depth_clean = cv2.GaussianBlur(depth_norm.astype(np.float32), (3, 3), 0.8)
    depth_vor = _voronoi_fill_array(depth_clean, fg)

    # Base smooth cranial normals (70%) + Sobel depth gradient normals (30%)
    dome_bgra = _build_clean_head_normal_depth(col_alpha)
    dome_x = (dome_bgra[:, :, 2].astype(np.float32) / 255.0) * 2.0 - 1.0
    dome_y = (dome_bgra[:, :, 1].astype(np.float32) / 255.0) * 2.0 - 1.0
    dome_z = (dome_bgra[:, :, 0].astype(np.float32) / 255.0) * 2.0 - 1.0

    d_unit = cv2.GaussianBlur(depth_vor / 255.0, (5, 5), 1.1)
    gx = cv2.Sobel(d_unit, cv2.CV_32F, 1, 0, ksize=3) / 8.0
    gy = cv2.Sobel(d_unit, cv2.CV_32F, 0, 1, ksize=3) / 8.0
    relief_gain = 3.2
    sx = -gx * relief_gain
    sy = -gy * relief_gain
    sz = np.ones_like(sx, dtype=np.float32)
    s_len = np.sqrt(sx * sx + sy * sy + sz * sz)
    sx /= np.maximum(s_len, 1e-5)
    sy /= np.maximum(s_len, 1e-5)
    sz /= np.maximum(s_len, 1e-5)

    nx = 0.70 * dome_x + 0.30 * sx
    ny = 0.70 * dome_y + 0.30 * sy
    nz = 0.70 * dome_z + 0.30 * sz
    n_len = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= np.maximum(n_len, 1e-5)
    ny /= np.maximum(n_len, 1e-5)
    nz /= np.maximum(n_len, 1e-5)

    h, w = fg.shape
    nd_bgra = np.zeros((h, w, 4), dtype=np.uint8)
    nd_bgra[:, :, 2] = np.clip(np.round((nx * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    nd_bgra[:, :, 1] = np.clip(np.round((ny * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    nd_bgra[:, :, 0] = np.clip(np.round((nz * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    nd_bgra[:, :, 3] = np.clip(np.round(depth_vor), 0, 255).astype(np.uint8)
    return _voronoi_fill_array(nd_bgra, fg)


def _render_face_audit_panel(face_bgra: np.ndarray, fg: np.ndarray) -> np.ndarray:
    """Create bright high-contrast BGR visualization of face_live_mask R/G/B/A channels."""
    h, w = fg.shape
    vis = np.zeros((h, w, 3), dtype=np.uint8)
    vis[fg] = (46, 48, 60)

    r_f = face_bgra[:, :, 2].astype(np.float32) / 255.0  # eyelid -> yellow
    g_f = face_bgra[:, :, 1].astype(np.float32) / 255.0  # iris -> cyan
    b_f = face_bgra[:, :, 0].astype(np.float32) / 255.0  # eyebrow -> orange
    a_f = face_bgra[:, :, 3].astype(np.float32) / 255.0  # mouth/neck -> magenta/blue

    yy = np.broadcast_to(np.arange(h, dtype=np.float32)[:, None], (h, w))
    is_lower_neck = yy > (h * 0.60)
    vis_f = vis.astype(np.float32)
    vis_f += r_f[:, :, None] * np.array([60.0, 240.0, 255.0])
    vis_f += g_f[:, :, None] * np.array([255.0, 255.0, 0.0])
    vis_f += b_f[:, :, None] * np.array([0.0, 120.0, 255.0])
    mouth_col = np.where(is_lower_neck[:, :, None], np.array([255.0, 110.0, 30.0]), np.array([120.0, 0.0, 255.0]))
    vis_f += a_f[:, :, None] * mouth_col
    return np.clip(np.round(vis_f), 0, 255).astype(np.uint8)


def _build_compiled_audit_sheet(audit_rows: list[tuple[str, list[np.ndarray]]]) -> np.ndarray:
    """Assemble 8x4 inspection sheet: face_live, hair_jiggle RGB, normals RGB, depth A."""
    cell_w, cell_h = 340, 290
    pad_x, pad_y = 20, 16
    top_header = 44
    cols = 4
    w_tot = pad_x * 2 + cols * cell_w
    h_tot = top_header + pad_y + len(audit_rows) * cell_h
    canvas = np.full((h_tot, w_tot, 3), (20, 22, 28), dtype=np.uint8)

    col_titles = ("1. Face Live (R/G/B/Weld)", "2. Hair 3-Zone (R/G/B)", "3. Normals 2.5D (RGB)", "4. Depth 2.5D (Alpha)")
    for c, title in enumerate(col_titles):
        cv2.putText(
            canvas,
            title,
            (pad_x + c * cell_w + 10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.66,
            (230, 236, 250),
            1,
            cv2.LINE_AA,
        )

    for r, (hk, panels) in enumerate(audit_rows):
        y0 = top_header + r * cell_h
        for c, panel in enumerate(panels):
            x0 = pad_x + c * cell_w
            ph, pw = panel.shape[:2]
            scale = min((cell_w - 24) / float(pw), (cell_h - 36) / float(ph))
            nw, nh = max(1, int(round(pw * scale))), max(1, int(round(ph * scale)))
            rs = cv2.resize(panel, (nw, nh), interpolation=cv2.INTER_AREA)
            dx = x0 + (cell_w - nw) // 2
            dy = y0 + 24 + (cell_h - 24 - nh) // 2
            canvas[dy : dy + nh, dx : dx + nw] = rs
            cv2.rectangle(canvas, (x0 + 2, y0 + 2), (x0 + cell_w - 3, y0 + cell_h - 3), (58, 64, 82), 1)
        cv2.putText(canvas, hk, (pad_x + 10, y0 + 22), cv2.FONT_HERSHEY_SIMPLEX, 0.54, (205, 220, 255), 1, cv2.LINE_AA)
    return canvas


def ingest_all(assets_dir: Path, source_dir: Path, depth_sheet_path: Path) -> None:
    """Compile all live-head runtime masks and depth/normal maps for Valentina v2."""
    work_dir = source_dir / WORK_SUBDIR
    man_path = work_dir / "head_live_sheet_manifest.json"
    sem_path = work_dir / "outputs" / "heads_8dir_live_mask_16x9.png"
    for req in (man_path, sem_path, depth_sheet_path):
        if not req.exists():
            raise FileNotFoundError(f"Missing required input file: {req}")

    man = json.loads(man_path.read_text(encoding="utf-8"))
    sem_sheet = cv2.imread(str(sem_path))
    depth_sheet = cv2.imread(str(depth_sheet_path), cv2.IMREAD_GRAYSCALE)
    if sem_sheet is None or depth_sheet is None:
        raise RuntimeError("Failed to decode semantic or depth sheet.")

    heads_dir = assets_dir / "heads"
    out_depth_16x9 = np.zeros((SHEET_H, SHEET_W), dtype=np.uint8)
    audit_depth_16x9 = np.zeros((SHEET_H, SHEET_W, 3), dtype=np.uint8)
    audit_rows: list[tuple[str, list[np.ndarray]]] = []

    for slot in man["slots"]:
        hk = str(slot["head_key"])
        dx, dy, nw, nh = [int(v) for v in slot["piece_rect"]]
        sx, sy, sw, sh = [int(v) for v in slot["slot_rect"]]
        iw, ih = [int(v) for v in slot["orig_size"]]

        col = cv2.imread(str(heads_dir / f"{hk}.png"), cv2.IMREAD_UNCHANGED)
        idm = cv2.imread(str(heads_dir / f"{hk}_id_mask.png"), cv2.IMREAD_UNCHANGED)
        if col is None or idm is None:
            raise FileNotFoundError(f"Missing canonical texture for {hk}")

        fg = col[:, :, 3] >= 24
        is_neck = (idm[:, :, 0] > 128) & (idm[:, :, 2] < 100) & fg
        is_monocle = (idm[:, :, 2] > 128) & (idm[:, :, 0] < 100) & fg
        is_hair = (idm[:, :, 3] > 128) & fg & (~is_neck) & (~is_monocle)
        is_skin = fg & (~is_hair) & (~is_neck) & (~is_monocle)

        sem_patch = _extract_slot_patch(sem_sheet, slot["piece_rect"], slot["orig_size"])
        cls_idx = _classify_all_palette(sem_patch)

        # Extract and clean 2.5D depth patch
        dh_s, dw_s = depth_sheet.shape[:2]
        x0 = max(0, int(round(dx * dw_s / float(SHEET_W))))
        y0 = max(0, int(round(dy * dh_s / float(SHEET_H))))
        x1 = min(dw_s, int(round((dx + nw) * dw_s / float(SHEET_W))))
        y1 = min(dh_s, int(round((dy + nh) * dh_s / float(SHEET_H))))
        d_raw = cv2.resize(depth_sheet[y0:y1, x0:x1], (iw, ih), interpolation=cv2.INTER_CUBIC)
        depth_smooth, d_iou = _clean_depth_patch(d_raw, fg)

        d_clean_fg = np.where(fg, np.clip(np.round(depth_smooth), 0, 255), 0).astype(np.uint8)
        d_scaled = cv2.resize(d_clean_fg, (nw, nh), interpolation=cv2.INTER_CUBIC)
        out_depth_16x9[dy : dy + nh, dx : dx + nw] = d_scaled
        audit_depth_16x9[dy : dy + nh, dx : dx + nw] = cv2.cvtColor(d_scaled, cv2.COLOR_GRAY2BGR)
        cv2.rectangle(audit_depth_16x9, (sx + 3, sy + 3), (sx + sw - 4, sy + sh - 4), (92, 102, 128), 2)
        cv2.putText(
            audit_depth_16x9,
            f"{hk} raw_IoU={d_iou:.4f}",
            (sx + 16, sy + 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.58,
            (226, 232, 248),
            1,
            cv2.LINE_AA,
        )

        # Compile runtime assets
        face_mask = _build_face_live_mask(col, cls_idx, fg, is_neck, is_skin)
        hair_jiggle = _build_hair_jiggle_3zone(hk, cls_idx, fg, is_hair, is_skin)
        normal_depth = _build_normal_depth_25d(hk, depth_smooth, cls_idx, col[:, :, 3], fg, is_neck, is_monocle, is_skin)

        cv2.imwrite(str(heads_dir / f"{hk}_face_live_mask.png"), face_mask)
        cv2.imwrite(str(heads_dir / f"{hk}_hair_jiggle_mask.png"), hair_jiggle)
        cv2.imwrite(str(heads_dir / f"{hk}_normal_depth.png"), normal_depth)

        if hk == "head_side_r":
            for suffix in ("_face_live_mask.png", "_hair_jiggle_mask.png", "_normal_depth.png"):
                shutil.copy2(heads_dir / f"{hk}{suffix}", heads_dir / f"head_side{suffix}")

        d_vis = np.where(fg, normal_depth[:, :, 3], 0).astype(np.uint8)
        n_vis = np.where(fg[:, :, None], normal_depth[:, :, :3], 18)
        audit_rows.append((
            hk,
            [
                _render_face_audit_panel(face_mask, fg),
                hair_jiggle,
                n_vis,
                cv2.cvtColor(d_vis, cv2.COLOR_GRAY2BGR),
            ],
        ))
        a_fg = normal_depth[:, :, 3][fg]
        print(
            f"[INGEST] {hk:14s} raw_depth_IoU={d_iou:.4f} depth_A=[{int(a_fg.min())},{int(a_fg.max())}] "
            f"face_R_max={int(face_mask[:,:,2].max())} G_max={int(face_mask[:,:,1].max())} "
            f"B_max={int(face_mask[:,:,0].max())} A_max={int(face_mask[:,:,3].max())}"
        )

    out_depth_path = work_dir / "outputs" / "heads_8dir_depth_16x9.png"
    audit_depth_path = work_dir / "guides" / "audit_02_heads_depth_16x9.png"
    audit_compiled_path = work_dir / "guides" / "audit_03_compiled_head_rig_channels.png"
    cv2.imwrite(str(out_depth_path), out_depth_16x9)
    cv2.imwrite(str(audit_depth_path), audit_depth_16x9)
    cv2.imwrite(str(audit_compiled_path), _build_compiled_audit_sheet(audit_rows))

    print(f"\n[OK] 16:9 depth written to: {out_depth_path}")
    print(f"[OK] Audit 02 written to:   {audit_depth_path}")
    print(f"[OK] Audit 03 written to:   {audit_compiled_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Compile runtime head live masks and 2.5D normal/depth maps.")
    parser.add_argument("--assets-dir", type=Path, default=REPO_ROOT / DEFAULT_OUT_DIR)
    parser.add_argument("--source-dir", type=Path, default=REPO_ROOT / DEFAULT_SOURCE_DIR)
    parser.add_argument("--depth-sheet", type=Path, default=DEFAULT_DEPTH_SHEET)
    args = parser.parse_args()
    ingest_all(args.assets_dir, args.source_dir, args.depth_sheet)


if __name__ == "__main__":
    main()
