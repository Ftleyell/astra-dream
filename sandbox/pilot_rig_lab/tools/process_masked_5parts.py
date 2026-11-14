#!/usr/bin/env python3
"""Slice Upscayl-4x body_unified.png into 5 crisp high-res parts (body_core, arm_r, arm_l, leg_r, leg_l)
using 5-color semantic segmentation masks.
Outputs 3x-resolution textures + id_mask + normal_depth while keeping canonical 520x560 rects in parts_5_meta.json.
"""

import json
import shutil
import subprocess
from pathlib import Path
import cv2
import numpy as np

UPSCAYL_BIN = Path(r"C:\Program Files\Upscayl\resources\bin\upscayl-bin.exe")
UPSCAYL_MODELS = Path(r"C:\Program Files\Upscayl\resources\models")
TEX_SCALE = 3  # 3x canonical (1560x1680 canvas) for crisp in-game lineart

COLOR_PALETTE = {
    "body_core": np.array([0, 255, 0], dtype=np.float32),      # Green
    "arm_left_img": np.array([255, 0, 0], dtype=np.float32),   # Red
    "arm_right_img": np.array([0, 0, 255], dtype=np.float32),  # Blue
    "leg_r": np.array([255, 255, 0], dtype=np.float32),        # Yellow (viewer-left)
    "leg_l": np.array([255, 0, 255], dtype=np.float32),        # Magenta (viewer-right)
}

Z_ORDERS = {
    "s": {"arm_l": 0, "leg_l": 1, "leg_r": 2, "arm_r": 3, "body_core": 4},
    "n": {"arm_r": 0, "leg_r": 1, "leg_l": 2, "body_core": 3, "arm_l": 4},
}


def make_id_mask_and_normal_depth(bgra: np.ndarray, part_name: str) -> tuple[np.ndarray, np.ndarray]:
    b = bgra[:, :, 0].astype(np.float32) / 255.0
    g = bgra[:, :, 1].astype(np.float32) / 255.0
    r = bgra[:, :, 2].astype(np.float32) / 255.0
    a = bgra[:, :, 3]

    luma = 0.299 * r + 0.587 * g + 0.114 * b
    is_crimson = (r - g > 0.10) & (r - b > 0.08) & (r < 0.72)
    is_skin = (r > 0.68) & (g > 0.50) & (b > 0.42) & ((r - b) > 0.06)
    is_metal = (~is_skin) & (~is_crimson) & (luma > 0.34) & (np.abs(r - b) < 0.08)
    is_stocking = (part_name in ("leg_r", "leg_l")) & (~is_skin) & (~is_crimson) & (~is_metal) & (luma > 0.20) & (luma < 0.42) & ((r - b) > 0.015)

    ch_suit = np.where((~is_crimson) & (~is_metal) & (~is_skin) & (~is_stocking) & (a > 16), 255, 0).astype(np.uint8)
    ch_panel = np.where(is_metal & (a > 16), 255, 0).astype(np.uint8)
    ch_accent = np.where(is_crimson & (a > 16), 255, 0).astype(np.uint8)
    ch_stock = np.where(is_stocking & (a > 16), 255, 0).astype(np.uint8)
    id_mask = np.stack([ch_suit, ch_panel, ch_accent, ch_stock], axis=-1)

    fg = (a > 16).astype(np.uint8)
    dist = cv2.distanceTransform(fg, cv2.DIST_L2, 5)
    max_d = max(float(dist.max()), 1.0)
    depth = np.sqrt(np.clip(dist / max_d, 0.0, 1.0))

    gx = cv2.Sobel(depth, cv2.CV_32F, 1, 0, ksize=5)
    gy = cv2.Sobel(depth, cv2.CV_32F, 0, 1, ksize=5)
    nz = np.ones_like(depth) * 0.65
    n_len = np.sqrt(gx * gx + gy * gy + nz * nz) + 1e-6
    nx = np.clip((-gx / n_len) * 0.5 + 0.5, 0.0, 1.0)
    ny = np.clip((-gy / n_len) * 0.5 + 0.5, 0.0, 1.0)
    nz_n = np.clip((nz / n_len) * 0.5 + 0.5, 0.0, 1.0)
    nd_a = np.where(a > 16, np.clip(depth * 255.0, 40, 255).astype(np.uint8), 0)
    nd_bgra = np.stack([
        np.clip(nz_n * 255.0, 0, 255).astype(np.uint8),
        np.clip(ny * 255.0, 0, 255).astype(np.uint8),
        np.clip(nx * 255.0, 0, 255).astype(np.uint8),
        nd_a,
    ], axis=-1)
    return id_mask, nd_bgra


def upscale_with_upscayl(src_png: Path, dst_png: Path, model: str = "digital-art-4x") -> Path:
    """Run Upscayl CLI on src_png -> dst_png if upscayl-bin.exe is available."""
    if not UPSCAYL_BIN.exists():
        print(f"[WARN] Upscayl not found at {UPSCAYL_BIN}, using {src_png} directly.")
        return src_png
    dst_png.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(UPSCAYL_BIN),
        "-i", str(src_png),
        "-o", str(dst_png),
        "-m", str(UPSCAYL_MODELS),
        "-n", model,
        "-f", "png",
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return dst_png


def _classify_mask_pixels(mask_rgb: np.ndarray) -> dict[str, np.ndarray]:
    """Classify every non-black pixel to nearest semantic region, keeping largest CC per region."""
    is_fg = mask_rgb.max(axis=2) > 120
    flat = mask_rgb.astype(np.float32)

    names = list(COLOR_PALETTE.keys())
    dists = [np.linalg.norm(flat - COLOR_PALETTE[k][None, None, :], axis=2) for k in names]
    best_idx = np.argmin(np.stack(dists, axis=0), axis=0)

    masks: dict[str, np.ndarray] = {}
    for idx, k in enumerate(names):
        m = (is_fg & (best_idx == idx)).astype(np.uint8)
        num_cc, cc_lbl, stats, _ = cv2.connectedComponentsWithStats(m)
        if num_cc > 1:
            best_cc = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
            masks[k] = cc_lbl == best_cc
        else:
            masks[k] = m > 0
    return masks


def _align_mask_to_ref(mask_fg: np.ndarray, ref_alpha: np.ndarray) -> tuple[int, int, float]:
    """Find (ox, oy, scale) that aligns cropped mask_fg to 1x ref_alpha with maximum IoU."""
    ys, xs = np.where(mask_fg)
    my0, my1 = int(ys.min()), int(ys.max()) + 1
    mx0, mx1 = int(xs.min()), int(xs.max()) + 1
    crop_fg = mask_fg[my0:my1, mx0:mx1].astype(np.uint8) * 255

    rys, rxs = np.where(ref_alpha)
    ry0, ry1 = int(rys.min()), int(rys.max()) + 1
    rx0, rx1 = int(rxs.min()), int(rxs.max()) + 1
    rh_box = ry1 - ry0

    ch, cw = crop_fg.shape[:2]
    base_scale = float(rh_box) / float(ch)
    H, W = ref_alpha.shape[:2]
    ref_b = ref_alpha > 0

    best = (rx0, ry0, base_scale, -1.0)
    for s_mul in np.linspace(0.94, 1.06, 13):
        s = base_scale * s_mul
        nw, nh = max(4, int(round(cw * s))), max(4, int(round(ch * s)))
        res = cv2.resize(crop_fg, (nw, nh), interpolation=cv2.INTER_NEAREST) > 127
        for dy in range(-10, 11, 2):
            for dx in range(-10, 11, 2):
                ox = rx0 + int(round((rx1 - rx0 - nw) * 0.5)) + dx
                oy = ry0 + int(round((ry1 - ry0 - nh) * 0.5)) + dy
                px0, py0 = max(0, ox), max(0, oy)
                px1, py1 = min(W, ox + nw), min(H, oy + nh)
                if px1 <= px0 or py1 <= py0:
                    continue
                m_sub = res[py0 - oy:py1 - oy, px0 - ox:px1 - ox]
                r_sub = ref_b[py0:py1, px0:px1]
                inter = int((m_sub & r_sub).sum())
                union = int(res.sum() + ref_b.sum() - inter)
                iou = float(inter) / max(1.0, float(union))
                if iou > best[3]:
                    best = (ox, oy, s, iou)
    return best[0], best[1], best[2]


def _place_on_canvas(src_img: np.ndarray, rw_ref: int, rh_ref: int, ox_ref: int, oy_ref: int, W: int, H: int, interp: int) -> np.ndarray:
    scaled = cv2.resize(src_img, (rw_ref, rh_ref), interpolation=interp)
    out = np.zeros((H, W, src_img.shape[2]), dtype=np.uint8)
    cx0, cy0 = max(0, ox_ref), max(0, oy_ref)
    cx1, cy1 = min(W, ox_ref + rw_ref), min(H, oy_ref + rh_ref)
    out[cy0:cy1, cx0:cx1] = scaled[cy0 - oy_ref:cy1 - oy_ref, cx0 - ox_ref:cx1 - ox_ref]
    return out


def process_view_masked(view: str, mask_path: Path, audit_out: Path, upscayl_cache_dir: Path) -> None:
    vdir = Path(f"sandbox/pilot_rig_lab/combat_assets/valentina_planar/{view}")
    out_dir = vdir / "parts_5"
    out_dir.mkdir(parents=True, exist_ok=True)

    ref_1x_path = vdir / "body_unified.png"
    ref_4x_path = upscale_with_upscayl(ref_1x_path, upscayl_cache_dir / f"{view}_body_4x.png")
    ref_raw = cv2.imread(str(ref_4x_path), cv2.IMREAD_UNCHANGED)
    ml_id_raw = cv2.imread(str(vdir / "body_unified_id_mask.png"), cv2.IMREAD_UNCHANGED)
    ml_nd_raw = cv2.imread(str(vdir / "body_unified_normal_depth.png"), cv2.IMREAD_UNCHANGED)

    skel = json.loads((vdir / "rig_skeleton_config.json").read_text(encoding="utf-8"))
    bones_by_name = {b["name"]: b["pos"] for b in skel["bones"]}

    # Place Upscayl-4x body_unified onto TEX_SCALE (3x) canonical canvas: 1560 x 1680
    W1, H1 = 520, 560
    W, H = W1 * TEX_SCALE, H1 * TEX_SCALE
    neck_x, neck_y = bones_by_name["Neck"][0] * TEX_SCALE, bones_by_name["Neck"][1] * TEX_SCALE
    ref_h, ref_w = ref_raw.shape[:2]
    ref_scale = (430.0 * TEX_SCALE) / float(ref_h)
    rw_ref, rh_ref = int(round(ref_w * ref_scale)), int(round(ref_h * ref_scale))
    ref_scaled = cv2.resize(ref_raw, (rw_ref, rh_ref), interpolation=cv2.INTER_AREA)

    # Clean semi-transparent Upscayl outer alpha fringe and solidify thin interior tips (e.g. fingertips)
    a_ch = ref_scaled[:, :, 3]
    fg_closed = cv2.morphologyEx((a_ch >= 48).astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    ref_scaled[:, :, 3] = np.where(fg_closed > 0, 255, np.where(a_ch < 28, 0, a_ch))

    ox_ref = int(round(neck_x - rw_ref * 0.50))
    oy_ref = int(round(neck_y - rh_ref * 0.04))

    ref = np.zeros((H, W, 4), dtype=np.uint8)
    cx0, cy0 = max(0, ox_ref), max(0, oy_ref)
    cx1, cy1 = min(W, ox_ref + rw_ref), min(H, oy_ref + rh_ref)
    ref[cy0:cy1, cx0:cx1] = ref_scaled[cy0 - oy_ref:cy1 - oy_ref, cx0 - ox_ref:cx1 - ox_ref]
    ref_alpha = ref[:, :, 3] > 28

    ml_id_canvas = _place_on_canvas(ml_id_raw, rw_ref, rh_ref, ox_ref, oy_ref, W, H, cv2.INTER_NEAREST) if ml_id_raw is not None else None
    ml_nd_canvas = _place_on_canvas(ml_nd_raw, rw_ref, rh_ref, ox_ref, oy_ref, W, H, cv2.INTER_LINEAR) if ml_nd_raw is not None else None

    # Align mask at 1x for fast IoU search, then project at TEX_SCALE
    ref_alpha_1x = cv2.resize(ref_alpha.astype(np.uint8), (W1, H1), interpolation=cv2.INTER_NEAREST) > 0

    mask_bgr = cv2.imread(str(mask_path), cv2.IMREAD_COLOR)
    mask_rgb = cv2.cvtColor(mask_bgr, cv2.COLOR_BGR2RGB)
    raw_regions = _classify_mask_pixels(mask_rgb)

    arm_a, arm_b = raw_regions["arm_left_img"], raw_regions["arm_right_img"]
    if float(np.where(arm_a)[1].mean()) < float(np.where(arm_b)[1].mean()):
        raw_regions["arm_r"], raw_regions["arm_l"] = arm_a, arm_b
    else:
        raw_regions["arm_r"], raw_regions["arm_l"] = arm_b, arm_a
    del raw_regions["arm_left_img"], raw_regions["arm_right_img"]

    part_names = ["body_core", "arm_r", "arm_l", "leg_r", "leg_l"]
    proj_masks: dict[str, np.ndarray] = {}
    if mask_rgb.shape[:2] == (H, W):
        for k in part_names:
            proj_masks[k] = raw_regions[k]
    else:
        mask_fg = np.zeros(mask_rgb.shape[:2], dtype=bool)
        for m in raw_regions.values():
            mask_fg |= m
        ys, xs = np.where(mask_fg)
        my0, my1 = int(ys.min()), int(ys.max()) + 1
        mx0, mx1 = int(xs.min()), int(xs.max()) + 1

        ox1, oy1, m_scale1 = _align_mask_to_ref(mask_fg, ref_alpha_1x)
        ox, oy, m_scale = ox1 * TEX_SCALE, oy1 * TEX_SCALE, m_scale1 * TEX_SCALE
        nw = max(4, int(round((mx1 - mx0) * m_scale)))
        nh = max(4, int(round((my1 - my0) * m_scale)))

        for k in part_names:
            crop_m = raw_regions[k][my0:my1, mx0:mx1].astype(np.uint8) * 255
            res_m = cv2.resize(crop_m, (nw, nh), interpolation=cv2.INTER_NEAREST) > 127
            full_m = np.zeros((H, W), dtype=bool)
            px0, py0 = max(0, ox), max(0, oy)
            px1, py1 = min(W, ox + nw), min(H, oy + nh)
            full_m[py0:py1, px0:px1] = res_m[py0 - oy:py1 - oy, px0 - ox:px1 - ox]
            proj_masks[k] = full_m

    dist_stack = [cv2.distanceTransform((~proj_masks[k]).astype(np.uint8), cv2.DIST_L2, 5) for k in part_names]
    best_region = np.argmin(np.stack(dist_stack, axis=0), axis=0)
    snapped = {k: (ref_alpha & (best_region == idx)) for idx, k in enumerate(part_names)}

    rects: dict[str, list[float]] = {}
    islands: dict[str, np.ndarray] = {}
    z_order = Z_ORDERS[view]

    for k in part_names:
        m = snapped[k]
        is_arm = k in ("arm_r", "arm_l")
        underlap_k = (9 * TEX_SCALE + 1) if is_arm else (4 * TEX_SCALE + 1)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (underlap_k, underlap_k))
        dil = cv2.dilate(m.astype(np.uint8), kernel, iterations=1) > 0
        allowed = m.copy()
        ext_zone = np.zeros_like(m)
        if is_arm and z_order[k] < z_order["body_core"]:
            # Radial geodesic dilation around Shoulder + along upper-arm/torso seam down to Elbow
            sh_name = "Shoulder_R" if k == "arm_r" else "Shoulder_L"
            el_name = "Elbow_R" if k == "arm_r" else "Elbow_L"
            sh_x = bones_by_name[sh_name][0] * TEX_SCALE
            sh_y = bones_by_name[sh_name][1] * TEX_SCALE
            el_y = bones_by_name[el_name][1] * TEX_SCALE
            yy, xx = np.ogrid[:H, :W]
            radial_mask = (((xx - sh_x) ** 2 + (yy - sh_y) ** 2) <= ((28.0 * TEX_SCALE) ** 2)) | (yy <= el_y)
            k3 = np.ones((3, 3), dtype=np.uint8)
            geo = m.astype(np.uint8)
            step_lim = 12 * TEX_SCALE
            seam_mask = (m | (snapped["body_core"] & radial_mask)).astype(np.uint8)
            for _ in range(step_lim):
                geo = cv2.dilate(geo, k3, iterations=1) & seam_mask
            ext_zone = (geo > 0) & (~m) & snapped["body_core"] & radial_mask
            allowed |= ext_zone
        else:
            for other_k in part_names:
                if other_k != k and z_order[other_k] > z_order[k]:
                    allowed |= (dil & snapped[other_k])

        part_img = ref.copy()
        part_img[~allowed, 3] = 0
        pys, pxs = np.where(allowed)
        pad = 2 * TEX_SCALE
        x0, y0 = max(0, int(pxs.min()) - pad), max(0, int(pys.min()) - pad)
        x1, y1 = min(W, int(pxs.max()) + pad + 1), min(H, int(pys.max()) + pad + 1)

        crop_bgra = part_img[y0:y1, x0:x1].copy()
        id_src = ml_id_canvas[y0:y1, x0:x1].copy() if ml_id_canvas is not None else None
        nd_src = ml_nd_canvas[y0:y1, x0:x1].copy() if ml_nd_canvas is not None else None

        if is_arm and np.any(ext_zone[y0:y1, x0:x1]):
            ref_sub = ref[y0:y1, x0:x1]
            m_sub = m[y0:y1, x0:x1]
            ext_sub = ext_zone[y0:y1, x0:x1]
            ref_luma = (
                0.114 * ref_sub[:, :, 0].astype(np.float32)
                + 0.587 * ref_sub[:, :, 1].astype(np.float32)
                + 0.299 * ref_sub[:, :, 2].astype(np.float32)
            ) / 255.0
            seed_sub = m_sub & (ref_luma > 0.14)
            if not np.any(seed_sub):
                seed_sub = m_sub
            dist_m, labels = cv2.distanceTransformWithLabels(
                (~seed_sub).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
            )
            my_idx, mx_idx = np.where(seed_sub)
            ey, ex = np.where(ext_sub)
            src_idx = labels[ey, ex] - 1
            sy, sx = my_idx[src_idx], mx_idx[src_idx]
            ao = np.clip(1.0 - (dist_m[ey, ex] / (12.0 * TEX_SCALE)) * 0.22, 0.78, 1.0)[:, None]
            ext_rgb = np.clip(ref_sub[sy, sx, :3].astype(np.float32) * ao, 0, 255).astype(np.uint8)
            crop_bgra[ey, ex, :3] = ext_rgb
            crop_bgra[ey, ex, 3] = 255
            if id_src is not None:
                id_src[ey, ex] = id_src[sy, sx]
            if nd_src is not None:
                nd_src[ey, ex] = nd_src[sy, sx]

        islands[k] = crop_bgra
        # Store canonical 1x rects in parts_5_meta.json while textures are 3x Upscayl-crisp!
        rects[k] = [
            round(float(x0) / TEX_SCALE, 2),
            round(float(y0) / TEX_SCALE, 2),
            round(float(x1 - x0) / TEX_SCALE, 2),
            round(float(y1 - y0) / TEX_SCALE, 2),
        ]

        cv2.imwrite(str(out_dir / f"{k}.png"), crop_bgra)
        if id_src is not None and nd_src is not None:
            id_m, nd_m = id_src, nd_src
        else:
            id_m, nd_m = make_id_mask_and_normal_depth(crop_bgra, k)
        cv2.imwrite(str(out_dir / f"{k}_id_mask.png"), id_m)
        cv2.imwrite(str(out_dir / f"{k}_normal_depth.png"), nd_m)

    meta_path = out_dir / "parts_5_meta.json"
    existing_meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    meta = {
        "view": view,
        "tex_scale": TEX_SCALE,
        "rig_origin": existing_meta.get("rig_origin", skel["rig_origin"]),
        "neck_anchor": existing_meta.get("neck_anchor", skel["neck_anchor"]),
        "z_orders": z_order,
        "rects": rects,
        "bones": existing_meta.get("bones", skel["bones"]),
    }
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    # Audit composite at 2x for sharp inspection
    assembled = np.zeros((H, W, 4), dtype=np.uint8)
    for k in sorted(part_names, key=lambda p: (z_order[p], p)):
        x0 = int(round(rects[k][0] * TEX_SCALE))
        y0 = int(round(rects[k][1] * TEX_SCALE))
        patch = islands[k]
        ph, pw = patch.shape[:2]
        a = patch[:, :, 3:4].astype(np.float32) / 255.0
        dst = assembled[y0:y0 + ph, x0:x0 + pw].astype(np.float32)
        assembled[y0:y0 + ph, x0:x0 + pw, :3] = np.clip(patch[:, :, :3] * a + dst[:, :, :3] * (1.0 - a), 0, 255).astype(np.uint8)
        assembled[y0:y0 + ph, x0:x0 + pw, 3:4] = np.clip(np.maximum(dst[:, :, 3:4], patch[:, :, 3:4]), 0, 255).astype(np.uint8)

    y_a, y_b = 80 * TEX_SCALE, 540 * TEX_SCALE
    x_a, x_b = 120 * TEX_SCALE, 400 * TEX_SCALE
    comp = np.hstack([ref[y_a:y_b, x_a:x_b], assembled[y_a:y_b, x_a:x_b]])
    bg = np.full((comp.shape[0], comp.shape[1], 3), 245, dtype=np.uint8)
    a = comp[:, :, 3:4].astype(np.float32) / 255.0
    vis = np.clip(comp[:, :, :3].astype(np.float32) * a + bg.astype(np.float32) * (1.0 - a), 0, 255).astype(np.uint8)
    audit_out.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(audit_out), vis)
    print(f"Processed Upscayl 3x masked 5 parts for '{view}' -> {out_dir} (body_core={islands['body_core'].shape[:2]})")


if __name__ == "__main__":
    sr = Path("sandbox/pilot_rig_lab/source_refs")
    scratch = Path("C:/Users/Frani/.gemini/antigravity/brain/7a3a228c-eb42-4859-8dfd-b49e7048ca8f/scratch")
    cache = scratch / "upscayl_out"
    process_view_masked("s", sr / "valentina_planar_s_mask5.jpg", scratch / "audit_masked_5_upscayl_s.png", cache)
    process_view_masked("n", sr / "valentina_planar_n_mask5.jpg", scratch / "audit_masked_5_upscayl_n.png", cache)
