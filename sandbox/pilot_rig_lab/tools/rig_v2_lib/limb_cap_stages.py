"""Clean canonical limb loading (capped limbs, HD profile legs, rear arms) and socket offsets."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from process_masked_5parts import TEX_SCALE

from polish_outlines import _voronoi_fill

from .constants import ARM_ARMHOLE_SHIFT_DU, PX_H, PX_W
from .skeleton_and_normals import _synthesize_rear_arm_maps


_CANONICAL_HD_LEG_POS_PX: dict[tuple[str, str], tuple[int, int]] = {
    ("e", "leg_r"): (678, 792),
    ("e", "leg_l"): (679, 792),
    ("w", "leg_r"): (661, 789),
    ("w", "leg_l"): (658, 789),
    ("ne", "leg_r"): (767, 905),
    ("ne", "leg_l"): (546, 892),
    ("n", "leg_r"): (777, 900),
    ("n", "leg_l"): (532, 901),
    ("nw", "leg_r"): (774, 895),
    ("nw", "leg_l"): (541, 905),
}


def inject_profile_rear_limbs(
    view: str,
    part_masks: dict[str, np.ndarray],
    custom_part_src: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]],
    limb_seg_overrides: dict[str, np.ndarray],
    rear_darken_parts: set[str],
    ws_dir: Path,
) -> None:
    if view not in ("e", "w"):
        return
    front_leg = "leg_r" if view == "e" else "leg_l"
    rear_leg = "leg_l" if view == "e" else "leg_r"
    if int(part_masks[rear_leg].sum()) < 250 and int(part_masks[front_leg].sum()) >= 250:
        part_masks[rear_leg] = part_masks[front_leg].copy()

    rear_arm = "arm_l" if view == "e" else "arm_r"
    rear_arm_path = ws_dir / "manual_fix_overlays" / "03_brazo_trasero_e_w" / f"{view}_arm_back_rgba_1560x1680.png"
    if rear_arm_path.exists():
        ra_rgba = cv2.imread(str(rear_arm_path), cv2.IMREAD_UNCHANGED)
        if ra_rgba is not None and ra_rgba.shape[:2] == (PX_H, PX_W):
            ra_mask, ra_id, ra_seg = _synthesize_rear_arm_maps(ra_rgba)
            part_masks[rear_arm] = ra_mask
            custom_part_src[rear_arm] = (ra_rgba, ra_id, ra_seg)
            limb_seg_overrides[rear_arm] = ra_seg
            rear_darken_parts.add(rear_arm)


def inject_hd_legs(
    view: str,
    part_masks: dict[str, np.ndarray],
    custom_part_src: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]],
    limb_seg_overrides: dict[str, np.ndarray],
    capped_parts: set[str],
    exact_crop_rects_px: dict[str, tuple[int, int, int, int]],
    ref_rgba: np.ndarray,
    id_bgra: np.ndarray,
    limb_seg: np.ndarray,
    out_dir: Path,
) -> None:
    """Place pre-cropped canonical HD legs onto 1560x1680 canvas without altering their pixels."""
    ov_rects: dict[str, list[float]] = {}
    ov_path = out_dir / "manual_calibration_overrides.json"
    if ov_path.exists():
        ov_data = json.loads(ov_path.read_text(encoding="utf-8"))
        ov_rects = ov_data.get("views", {}).get(view, {}).get("rects", {})

    for pname in ("leg_r", "leg_l"):
        hd_path = out_dir / "hd_legs" / f"{view}_{pname}_hd.png"
        if not hd_path.exists():
            continue
        hd_img = cv2.imread(str(hd_path), cv2.IMREAD_UNCHANGED)
        if hd_img is None or hd_img.ndim != 3 or hd_img.shape[2] != 4:
            continue
        hh, hw = hd_img.shape[:2]

        if pname in ov_rects and len(ov_rects[pname]) == 4:
            rx, ry, rw, rh = [float(v) for v in ov_rects[pname]]
            if abs(rw * TEX_SCALE - hw) <= 1.5 and abs(rh * TEX_SCALE - hh) <= 1.5:
                x0 = int(round(rx * float(TEX_SCALE)))
                y0 = int(round(ry * float(TEX_SCALE)))
            else:
                x0, y0 = _CANONICAL_HD_LEG_POS_PX.get((view, pname), (678, 792))
        else:
            x0, y0 = _CANONICAL_HD_LEG_POS_PX.get((view, pname), (678, 792))

        x0 = max(0, min(PX_W - hw, x0))
        y0 = max(0, min(PX_H - hh, y0))

        canvas_rgba = np.zeros((PX_H, PX_W, 4), dtype=np.uint8)
        canvas_rgba[y0 : y0 + hh, x0 : x0 + hw] = hd_img
        hd_mask = canvas_rgba[:, :, 3] >= 64
        if int(hd_mask.sum()) < 250:
            continue

        base_m = part_masks[pname]
        _, src_id, src_seg = custom_part_src.get(pname, (ref_rgba, id_bgra, limb_seg))
        cap_id = src_id.copy()
        cap_seg = src_seg.copy()
        new_px = hd_mask & (~base_m)
        if np.any(new_px) and np.any(base_m):
            skin_id_seeds = base_m & (src_id[:, :, 0] < 64) & (src_id[:, :, 1] < 64) & (src_id[:, :, 2] < 64)
            if np.any(skin_id_seeds):
                cap_id[:, :, :3] = _voronoi_fill(src_id[:, :, :3], skin_id_seeds)
            else:
                cap_id[new_px, :3] = 0
            cap_id[:, :, 3] = np.where(hd_mask & (~new_px), src_id[:, :, 3], 0).astype(np.uint8)
            cap_seg = _voronoi_fill(src_seg, base_m)

        part_masks[pname] = hd_mask
        custom_part_src[pname] = (canvas_rgba, cap_id, cap_seg)
        limb_seg_overrides[pname] = cap_seg
        capped_parts.add(pname)
        exact_crop_rects_px[pname] = (x0, y0, hw, hh)


def inject_capped_limbs(
    view: str,
    part_masks: dict[str, np.ndarray],
    custom_part_src: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]],
    limb_seg_overrides: dict[str, np.ndarray],
    capped_parts: set[str],
    exact_crop_rects_px: dict[str, tuple[int, int, int, int]],
    bones_list: list[dict],
    bones_by_name: dict[str, list[float]],
    ref_rgba: np.ndarray,
    id_bgra: np.ndarray,
    limb_seg: np.ndarray,
    ws_dir: Path,
    out_dir: Path,
) -> None:
    inject_hd_legs(
        view, part_masks, custom_part_src, limb_seg_overrides,
        capped_parts, exact_crop_rects_px, ref_rgba, id_bgra, limb_seg, out_dir,
    )

    cap_dir = ws_dir / "manual_fix_overlays" / "04_cap_sheets_16x9" / "capped_rgba_1560x1680"
    if cap_dir.exists():
        for pname in ("arm_r", "arm_l", "leg_r", "leg_l"):
            if pname in exact_crop_rects_px:
                continue
            cap_key = pname
            if view == "e" and pname == "leg_l":
                cap_key = "leg_r"
            elif view == "w" and pname == "leg_r":
                cap_key = "leg_l"
            cap_path = cap_dir / f"{view}_{cap_key}.png"
            if not cap_path.exists():
                continue
            cap_rgba = cv2.imread(str(cap_path), cv2.IMREAD_UNCHANGED)
            if cap_rgba is None or cap_rgba.shape[:2] != (PX_H, PX_W):
                continue
            cap_mask = cap_rgba[:, :, 3] >= 64
            if int(cap_mask.sum()) < 250:
                continue

            base_m = part_masks[pname]
            _, src_id, src_seg = custom_part_src.get(pname, (ref_rgba, id_bgra, limb_seg))
            cap_id = src_id.copy()
            cap_seg = src_seg.copy()
            new_cap_px = cap_mask & (~base_m)
            if np.any(new_cap_px) and np.any(base_m):
                if pname in ("leg_r", "leg_l"):
                    skin_id_seeds = base_m & (src_id[:, :, 0] < 64) & (src_id[:, :, 1] < 64) & (src_id[:, :, 2] < 64)
                    if np.any(skin_id_seeds):
                        cap_id[:, :, :3] = _voronoi_fill(src_id[:, :, :3], skin_id_seeds)
                    else:
                        cap_id[new_cap_px, :3] = 0
                else:
                    cap_id[:, :, :3] = _voronoi_fill(src_id[:, :, :3], base_m)
                cap_id[:, :, 3] = np.where(cap_mask & (~new_cap_px), src_id[:, :, 3], 0).astype(np.uint8)
                cap_seg = _voronoi_fill(src_seg, base_m)

            part_masks[pname] = cap_mask
            custom_part_src[pname] = (cap_rgba, cap_id, cap_seg)
            limb_seg_overrides[pname] = cap_seg
            capped_parts.add(pname)

    # Re-center Shoulder/Thigh bone pivot at the geometric dome center of each limb
    for pname in ("arm_r", "arm_l", "leg_r", "leg_l"):
        if pname not in part_masks or int(part_masks[pname].sum()) < 250:
            continue
        cap_mask = part_masks[pname]
        side_k = "R" if pname.endswith("_r") else "L"
        cys, _ = np.where(cap_mask)
        if len(cys) > 0:
            y_top = int(cys.min())
            probe_y = min(PX_H - 1, y_top + (26 if pname.startswith("arm") else 40))
            row_xs = np.where(cap_mask[probe_y])[0]
            if len(row_xs) >= 6:
                r_cap = float(row_xs.max() - row_xs.min()) * 0.5
                r_cap = float(np.clip(r_cap, 14.0 if pname.startswith("arm") else 24.0, 36.0 if pname.startswith("arm") else 56.0))
                cy_px = float(y_top) + r_cap
                if pname in ("leg_r", "leg_l") and view in ("ne", "n", "nw"):
                    pel_y_lim = (float(bones_by_name["Pelvis"][1]) + 4.0) * float(TEX_SCALE)
                    cy_px = min(cy_px, pel_y_lim)
                cy_i = min(PX_H - 1, int(round(cy_px)))
                c_xs = np.where(cap_mask[cy_i])[0]
                cx_px = float(c_xs.min() + c_xs.max()) * 0.5 if len(c_xs) > 0 else float(row_xs.min() + row_xs.max()) * 0.5
                b_key = f"Shoulder_{side_k}" if pname.startswith("arm") else f"Thigh_{side_k}"
                new_pos = [round(cx_px / float(TEX_SCALE), 2), round(cy_px / float(TEX_SCALE), 2)]
                bones_by_name[b_key] = new_pos
                for b_entry in bones_list:
                    if b_entry["name"] == b_key:
                        b_entry["pos"] = new_pos
                        break


def apply_armhole_shifts(
    view: str,
    part_masks: dict[str, np.ndarray],
    bones_list: list[dict],
    bones_by_name: dict[str, list[float]],
) -> dict[str, tuple[float, float]]:
    """Return display-unit socket shifts for arms and offset arm bones without resampling pixels."""
    arm_shifts = ARM_ARMHOLE_SHIFT_DU.get(view, {})
    arm_shift_du_by_part: dict[str, tuple[float, float]] = {}
    for arm_k, (adx_du, ady_du) in arm_shifts.items():
        if arm_k not in part_masks or int(part_masks[arm_k].sum()) < 250:
            continue
        arm_shift_du_by_part[arm_k] = (float(adx_du), float(ady_du))
        side_u = "R" if arm_k.endswith("_r") else "L"
        for bk_a in (f"Shoulder_{side_u}", f"Elbow_{side_u}", f"Wrist_{side_u}"):
            if bk_a in bones_by_name:
                new_bp = [
                    round(float(bones_by_name[bk_a][0]) + float(adx_du), 2),
                    round(float(bones_by_name[bk_a][1]) + float(ady_du), 2),
                ]
                bones_by_name[bk_a] = new_bp
                for b_e in bones_list:
                    if b_e["name"] == bk_a:
                        b_e["pos"] = new_bp
                        break
    return arm_shift_du_by_part
