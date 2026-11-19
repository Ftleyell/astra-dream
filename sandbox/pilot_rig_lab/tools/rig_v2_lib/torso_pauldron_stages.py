"""Canonical HD torso & pauldron extraction and body metrics for Valentina v2."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from polish_outlines import _voronoi_fill
from process_masked_5parts import TEX_SCALE

from .constants import (
    CANONICAL_H,
    CANONICAL_W,
    DIRECTIONS,
    HEAD_SCALE_FACTOR,
    PAULDRON_SOCKET_SHIFT_DU,
    PX_H,
    PX_W,
)


def _shift_integer_px(arr: np.ndarray, dx_px: int, dy_px: int) -> np.ndarray:
    """Shift an image on the 1560x1680 canvas by exact integer pixels with zero resampling."""
    if dx_px == 0 and dy_px == 0:
        return arr
    out = np.zeros_like(arr)
    sx0 = max(0, -dx_px)
    sy0 = max(0, -dy_px)
    dx0 = max(0, dx_px)
    dy0 = max(0, dy_px)
    cw = min(PX_W - sx0, PX_W - dx0)
    ch = min(PX_H - sy0, PX_H - dy0)
    if cw > 0 and ch > 0:
        out[dy0 : dy0 + ch, dx0 : dx0 + cw] = arr[sy0 : sy0 + ch, sx0 : sx0 + cw]
    return out


def inject_hd_torso_and_pauldrons(
    view: str,
    part_masks: dict[str, np.ndarray],
    custom_part_src: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]],
    limb_seg_overrides: dict[str, np.ndarray],
    capped_parts: set[str],
    bones_list: list[dict],
    bones_by_name: dict[str, list[float]],
    neck_disp: tuple[float, float],
    neck_by_view: dict[str, tuple[float, float]],
    ref_rgba: np.ndarray,
    id_bgra: np.ndarray,
    limb_seg: np.ndarray,
    ws_dir: Path,
    out_dir: Path,
) -> tuple[bool, tuple[float, float], dict[str, tuple[float, float]]]:
    yy_full, xx_full = np.mgrid[:PX_H, :PX_W].astype(np.float32)
    torso_dir = ws_dir / "manual_fix_overlays" / "06_torso_and_leg_e_16x9" / "ingested_1560x1680"
    torso_path = torso_dir / f"{view}_body_core.png"
    hd_torso_path = out_dir / "hd_torsos" / f"{view}_body_core_hd.png"
    using_hd_torso = hd_torso_path.exists()
    active_torso_path = hd_torso_path if using_hd_torso else torso_path
    pauldron_shift_du_by_part: dict[str, tuple[float, float]] = {}

    if not active_torso_path.exists():
        return False, neck_disp, pauldron_shift_du_by_part

    t_rgba = cv2.imread(str(active_torso_path), cv2.IMREAD_UNCHANGED)
    t_legacy_rgba = cv2.imread(str(torso_path), cv2.IMREAD_UNCHANGED) if torso_path.exists() else t_rgba
    if t_rgba is None or t_rgba.shape[:2] != (PX_H, PX_W):
        return False, neck_disp, pauldron_shift_du_by_part

    if using_hd_torso:
        hd_shift_by_view = {"s": (2, 0), "sw": (5, 6), "n": (4, 0)}
        if view in hd_shift_by_view:
            sdx, sdy = hd_shift_by_view[view]
            t_rgba = _shift_integer_px(t_rgba, sdx, sdy)

    t_mask = t_rgba[:, :, 3] >= 64
    if int(t_mask.sum()) < 500:
        return False, neck_disp, pauldron_shift_du_by_part

    base_bc = part_masks["body_core"]
    _, src_id, src_seg = custom_part_src.get("body_core", (ref_rgba, id_bgra, limb_seg))
    bc_id = src_id.copy()
    bc_seg = src_seg.copy()
    new_px = t_mask & (~base_bc)
    if np.any(new_px) and np.any(base_bc):
        non_red_seeds = base_bc & (src_id[:, :, 2] <= 128)
        bc_id[:, :, :3] = _voronoi_fill(src_id[:, :, :3], non_red_seeds if np.any(non_red_seeds) else base_bc)
        b_t = t_rgba[:, :, 0].astype(np.float32)
        g_t = t_rgba[:, :, 1].astype(np.float32)
        r_t = t_rgba[:, :, 2].astype(np.float32)
        l_t = (0.114 * b_t + 0.587 * g_t + 0.299 * r_t) / 255.0
        warm_t_skin = new_px & (r_t > b_t + 12.0) & (l_t > 0.36)
        dark_t_suit = new_px & (~warm_t_skin)
        bc_id[warm_t_skin, :3] = 0
        bc_id[dark_t_suit, 0] = 255
        bc_id[dark_t_suit, 1] = 0
        bc_id[dark_t_suit, 2] = 0
        bc_id[:, :, 3] = 0
        bc_seg = _voronoi_fill(src_seg, base_bc)

    part_masks["body_core"] = t_mask
    custom_part_src["body_core"] = (t_rgba, bc_id, bc_seg)
    limb_seg_overrides["body_core"] = bc_seg
    capped_parts.add("body_core")

    shr_px = np.array(bones_by_name["Shoulder_R"], dtype=np.float32) * float(TEX_SCALE)
    shl_px = np.array(bones_by_name["Shoulder_L"], dtype=np.float32) * float(TEX_SCALE)
    pauldron_union = np.zeros_like(t_mask)

    pm_path = torso_dir / f"{view}_pauldron_mask.png"
    if pm_path.exists():
        pm_full = cv2.imread(str(pm_path), cv2.IMREAD_GRAYSCALE)
        if pm_full is not None and pm_full.shape[:2] == (PX_H, PX_W):
            pm_ref_mask = (t_legacy_rgba[:, :, 3] >= 64) if t_legacy_rgba is not None else t_mask
            pm_bin = (pm_full >= 128) & pm_ref_mask
            p_r_mask = np.zeros_like(pm_bin)
            p_l_mask = np.zeros_like(pm_bin)
            num_c, lbl_c, st_c, cents = cv2.connectedComponentsWithStats(pm_bin.astype(np.uint8), connectivity=8)
            if view in ("e", "w"):
                best_cid = 0
                best_area = -1
                for cid in range(1, num_c):
                    area_c = int(st_c[cid, cv2.CC_STAT_AREA])
                    if area_c >= 25 and area_c > best_area:
                        best_area = area_c
                        best_cid = cid
                if best_cid > 0:
                    if view == "e":
                        p_r_mask |= lbl_c == best_cid
                    else:
                        p_l_mask |= lbl_c == best_cid
            else:
                for cid in range(1, num_c):
                    c_mask = lbl_c == cid
                    if int(c_mask.sum()) < 25:
                        continue
                    cpt = np.array([cents[cid][0], cents[cid][1]], dtype=np.float32)
                    if np.linalg.norm(cpt - shr_px) <= np.linalg.norm(cpt - shl_px):
                        p_r_mask |= c_mask
                    else:
                        p_l_mask |= c_mask

            pau_shifts = PAULDRON_SOCKET_SHIFT_DU.get(view, {})
            hd_dir = torso_dir.parent / "hd_pauldrons"
            hd_man_p = hd_dir / "hd_pauldrons_manifest.json"
            hd_man = json.loads(hd_man_p.read_text(encoding="utf-8")) if hd_man_p.exists() else {}

            fitted_pauldron_rects = {
                ("s", "pauldron_r"): (619, 542, 119, 126),
                ("s", "pauldron_l"): (822, 542, 119, 126),
                ("se", "pauldron_r"): (622, 540, 118, 124),
                ("se", "pauldron_l"): (818, 536, 104, 116),
                ("sw", "pauldron_r"): (638, 536, 104, 116),
                ("sw", "pauldron_l"): (820, 540, 118, 124),
                ("e", "pauldron_r"): (702, 549, 112, 120),
                ("w", "pauldron_l"): (762, 549, 112, 120),
                ("n", "pauldron_r"): (832, 539, 118, 124),
                ("n", "pauldron_l"): (610, 539, 118, 124),
            }

            for p_side, b_name, sh_key, p_m in (
                ("pauldron_r", "Pauldron_R", "Shoulder_R", p_r_mask),
                ("pauldron_l", "Pauldron_L", "Shoulder_L", p_l_mask),
            ):
                if int(p_m.sum()) >= 25:
                    p_rgba = (t_legacy_rgba if t_legacy_rgba is not None else t_rgba).copy()
                    p_rgba[~p_m, 3] = 0
                    p_id_src = bc_id

                    hd_match = None
                    for fn, entries in hd_man.items():
                        for ev, eside, eflip in entries:
                            if ev == view and eside == p_side:
                                hd_match = (hd_dir / fn, bool(eflip))
                                break
                        if hd_match is not None:
                            break
                    if hd_match is not None and hd_match[0].exists():
                        hd_rgba = cv2.imread(str(hd_match[0]), cv2.IMREAD_UNCHANGED)
                        if hd_rgba is not None and hd_rgba.shape[2] == 4:
                            if hd_match[1]:
                                hd_rgba = cv2.flip(hd_rgba, 1)
                            # Preserve 100% of anti-aliased edge pixels (alpha >= 1)
                            hys, hxs = np.where(hd_rgba[:, :, 3] >= 1)
                            tys, txs = np.where(p_m)
                            if len(hys) > 0 and len(tys) > 0:
                                hd_crop = hd_rgba[int(hys.min()) : int(hys.max()) + 1, int(hxs.min()) : int(hxs.max()) + 1]
                                if (view, p_side) in fitted_pauldron_rects:
                                    dx0_hd, dy0_hd, tw, th = fitted_pauldron_rects[(view, p_side)]
                                else:
                                    raw_tw = int(txs.max()) - int(txs.min()) + 1
                                    raw_th = int(tys.max()) - int(tys.min()) + 1
                                    scale_pw, scale_ph = (1.00, 1.00) if view in ("e", "w") else (1.01, 1.00)
                                    tw = max(8, int(round(raw_tw * scale_pw)))
                                    th = max(8, int(round(raw_th * scale_ph)))
                                    chest_cx_p = float(bones_by_name["Chest"][0]) * float(TEX_SCALE)
                                    is_left_of_chest = (0.5 * (float(txs.min()) + float(txs.max()))) < chest_cx_p
                                    dx0_hd = (int(txs.max()) + 1 - tw) if is_left_of_chest else int(txs.min())
                                    dy0_hd = int(tys.max()) + 1 - th
                                dx0_hd = max(0, min(PX_W - tw, dx0_hd))
                                dy0_hd = max(0, min(PX_H - th, dy0_hd))
                                interp = cv2.INTER_AREA if (hd_crop.shape[1] >= tw and hd_crop.shape[0] >= th) else cv2.INTER_CUBIC
                                hd_res = cv2.resize(hd_crop, (tw, th), interpolation=interp)
                                p_rgba = np.zeros_like(t_rgba)
                                p_rgba[dy0_hd : dy0_hd + th, dx0_hd : dx0_hd + tw] = hd_res
                                p_m = p_rgba[:, :, 3] >= 64
                                p_id_src = np.zeros_like(bc_id)
                                p_id_src[p_m, 1] = 255

                    pdx_du, pdy_du = pau_shifts.get(p_side, (0.0, 0.0))
                    if abs(pdx_du) > 1e-4 or abs(pdy_du) > 1e-4:
                        pauldron_shift_du_by_part[p_side] = (float(pdx_du), float(pdy_du))

                    # Mask for body_core_pauldron_mask in canonical torso space
                    pdx_px = int(round(float(pdx_du) * float(TEX_SCALE)))
                    pdy_px = int(round(float(pdy_du) * float(TEX_SCALE)))
                    pauldron_union |= _shift_integer_px(p_m.astype(np.uint8) * 255, pdx_px, pdy_px) >= 128

                    part_masks[p_side] = p_m
                    custom_part_src[p_side] = (p_rgba, p_id_src, bc_seg)
                    capped_parts.add(p_side)

                    pys, pxs = np.where(p_m)
                    chest_x = float(bones_by_name["Chest"][0]) * float(TEX_SCALE)
                    sh_x = float(bones_by_name[sh_key][0]) * float(TEX_SCALE)
                    sh_y = float(bones_by_name[sh_key][1]) * float(TEX_SCALE)
                    dists = np.abs(pxs.astype(np.float32) - chest_x)
                    inner = dists <= float(np.percentile(dists, 35.0))
                    w_in_x, w_in_y = (0.38, 0.35) if view in ("e", "w") else ((0.48, 0.44) if view in ("ne", "nw") else (0.62, 0.58))
                    hx = (w_in_x * float(np.median(pxs[inner])) + (1.0 - w_in_x) * sh_x) / float(TEX_SCALE) + float(pdx_du)
                    hy = (w_in_y * float(np.percentile(pys[inner], 36.0)) + (1.0 - w_in_y) * sh_y) / float(TEX_SCALE) + float(pdy_du)
                    hpos = [round(hx, 2), round(hy, 2)]
                else:
                    hpos = list(bones_by_name[sh_key])
                bones_by_name[b_name] = hpos
                for b_entry in bones_list:
                    if b_entry["name"] == b_name:
                        b_entry["pos"] = hpos
                        break

    # Clean ID mask on body_core without modifying t_rgba borders
    d_sh_r = np.hypot(xx_full - shr_px[0], yy_full - shr_px[1])
    d_sh_l = np.hypot(xx_full - shl_px[0], yy_full - shl_px[1])
    d_sh_min = np.minimum(d_sh_r, d_sh_l)
    pm_dil = cv2.dilate(pauldron_union.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0

    vis_bc_now = t_rgba[:, :, 3] >= 64
    b_c = t_rgba[:, :, 0].astype(np.float32)
    g_c = t_rgba[:, :, 1].astype(np.float32)
    r_c = t_rgba[:, :, 2].astype(np.float32)
    l_c = (0.114 * b_c + 0.587 * g_c + 0.299 * r_c) / 255.0
    actual_warm_skin = vis_bc_now & (r_c > b_c + 12.0) & (l_c > 0.34)
    actual_maroon_strap = vis_bc_now & (r_c > b_c + 14.0) & (r_c > g_c + 12.0) & (l_c <= 0.33)
    spurious_red = vis_bc_now & (bc_id[:, :, 2] > 128) & (~actual_maroon_strap)
    bc_id[spurious_red & actual_warm_skin, :3] = 0
    bc_id[spurious_red & (~actual_warm_skin), 0] = 255
    bc_id[spurious_red & (~actual_warm_skin), 1] = 0
    bc_id[spurious_red & (~actual_warm_skin), 2] = 0
    id_sum = bc_id[:, :, 0].astype(np.int32) + bc_id[:, :, 1].astype(np.int32) + bc_id[:, :, 2].astype(np.int32)
    fake_skin_on_dark = vis_bc_now & (l_c < 0.34) & (id_sum < 100)
    bc_id[fake_skin_on_dark & actual_maroon_strap, 0] = 0
    bc_id[fake_skin_on_dark & actual_maroon_strap, 1] = 0
    bc_id[fake_skin_on_dark & actual_maroon_strap, 2] = 255
    bc_id[fake_skin_on_dark & (~actual_maroon_strap), 0] = 255
    bc_id[fake_skin_on_dark & (~actual_maroon_strap), 1] = 0
    bc_id[fake_skin_on_dark & (~actual_maroon_strap), 2] = 0
    socket_id_zone = vis_bc_now & ((d_sh_min <= 24.0 * float(TEX_SCALE)) | pm_dil) & (~actual_warm_skin) & (~actual_maroon_strap)
    bc_id[socket_id_zone, 0] = 255
    bc_id[socket_id_zone, 1] = 0
    bc_id[socket_id_zone, 2] = 0
    bc_id[socket_id_zone, 3] = 0

    part_masks["body_core"] = vis_bc_now
    custom_part_src["body_core"] = (t_rgba, bc_id, bc_seg)

    if using_hd_torso and np.any(vis_bc_now):
        hd_ys, _ = np.where(vis_bc_now)
        hd_top_y = int(hd_ys.min())
        ring_ys: list[int] = []
        ring_cxs: list[float] = []
        min_rw = 14 if view in ("e", "w") else 46
        max_rw = 88
        scan_start = 4 if view in ("s", "se", "sw") else 2
        scan_lim = 20 if view in ("s", "se", "sw") else (26 if view in ("e", "w") else 32)
        for ry_s in range(hd_top_y + scan_start, min(PX_H, hd_top_y + scan_lim)):
            rxs = np.where(vis_bc_now[ry_s])[0]
            if len(rxs) > 0 and min_rw <= int(rxs.max() - rxs.min()) <= max_rw:
                ring_ys.append(ry_s)
                ring_cxs.append(0.5 * (float(rxs.min()) + float(rxs.max())))
                if len(ring_ys) >= 12:
                    break
        if ring_ys:
            hd_neck_cx = float(np.mean(ring_cxs))
            hd_neck_cy = float(np.mean(ring_ys))
        else:
            sample_y = min(PX_H - 1, hd_top_y + 14)
            row_xs = np.where(vis_bc_now[sample_y])[0]
            hd_neck_cx = 0.5 * (float(row_xs.min()) + float(row_xs.max())) if len(row_xs) > 0 else float(neck_disp[0]) * float(TEX_SCALE)
            hd_neck_cy = float(hd_top_y) + 12.0
        if view in ("e", "w"):
            hd_neck_cy += 1.5 * float(TEX_SCALE)
        elif view == "s":
            hd_neck_cy += 5.0 * float(TEX_SCALE)
        elif view in ("se", "sw"):
            hd_neck_cy += 5.2 * float(TEX_SCALE)
        hd_neck_pos = [
            round(hd_neck_cx / float(TEX_SCALE), 1),
            round(hd_neck_cy / float(TEX_SCALE), 1),
        ]
        bones_by_name["Neck"] = hd_neck_pos
        for b_entry in bones_list:
            if b_entry["name"] == "Neck":
                b_entry["pos"] = hd_neck_pos
                break
        neck_disp = (hd_neck_pos[0], hd_neck_pos[1])
        neck_by_view[view] = neck_disp

    return using_hd_torso, neck_disp, pauldron_shift_du_by_part


def compute_and_write_body_metrics(out_dir: Path, heads_meta: dict) -> None:
    s_meta = json.loads((out_dir / "s" / "parts_5" / "parts_5_meta.json").read_text(encoding="utf-8"))
    s_bones = {b["name"]: b["pos"] for b in s_meta["bones"]}
    hf_img = cv2.imread(str(out_dir / "heads" / "head_front.png"), cv2.IMREAD_UNCHANGED)
    hf_id = cv2.imread(str(out_dir / "heads" / "head_front_id_mask.png"), cv2.IMREAD_UNCHANGED)
    hf_info = heads_meta["head_front"]
    hf_dh = float(hf_info["disp_size"][1])
    hf_fg = hf_img[:, :, 3] > 20
    hf_ys = np.where(hf_fg)[0]
    hf_blue = hf_fg & (hf_id[:, :, 0] > 128) & (hf_id[:, :, 1] < 90) & (hf_id[:, :, 2] < 90)
    hf_hair = hf_fg & (hf_id[:, :, 3] > 128)
    hf_skin = hf_fg & (~hf_blue) & (~hf_hair) & (hf_id[:, :, 2] < 90)
    H_px, W_px = hf_img.shape[:2]
    skin_ys = np.where(hf_skin[:, int(W_px * 0.30) : int(W_px * 0.70)])[0]
    chin_px = int(skin_ys.max()) if len(skin_ys) else int(np.where(hf_blue)[0].min())
    c2chin_du = round((chin_px - int(hf_ys.min()) + 1) / float(H_px) * hf_dh, 2)
    vis_h_du = round((int(hf_ys.max()) - int(hf_ys.min()) + 1) / float(H_px) * hf_dh, 2)
    head_top_du = float(s_bones["Neck"][1]) + float(hf_info["sprite_offset"][1]) - 0.5 * hf_dh + (int(hf_ys.min()) / float(H_px)) * hf_dh
    leg_bot_du = max(
        float(s_meta["rects"]["leg_r"][1]) + float(s_meta["rects"]["leg_r"][3]),
        float(s_meta["rects"]["leg_l"][1]) + float(s_meta["rects"]["leg_l"][3]),
    )
    mounted_total_h = round(leg_bot_du - head_top_du, 2)
    prop_ratio = round(mounted_total_h / max(c2chin_du, 1.0), 2)

    body_metrics = {
        "canonical_canvas": [CANONICAL_W, CANONICAL_H],
        "tex_scale": TEX_SCALE,
        "directions": list(DIRECTIONS),
        "head_scale_factor": HEAD_SCALE_FACTOR,
        "head_target_disp_h": vis_h_du,
        "head_crown_to_chin_du": c2chin_du,
        "mounted_total_h_du": mounted_total_h,
        "head_to_body_proportion": prop_ratio,
    }
    (out_dir / "body_metrics.json").write_text(json.dumps(body_metrics, indent=2) + "\n", encoding="utf-8")
    print(f"[METRICS] head_vis_h={vis_h_du} du, crown_to_chin={c2chin_du} du, mounted_h={mounted_total_h} du, ratio={prop_ratio}x")
