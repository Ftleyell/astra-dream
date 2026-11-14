#!/usr/bin/env python3
"""Slice and align the side-by-side S+N limb semantic mask sheet into smooth
3-channel bone-weight masks (<part>_anim_mask.png) for parts_5 limbs:
  R = Upper segment (Shoulder_* / Thigh_*)
  G = Lower segment (Elbow_* / Knee_*)
  B = Extremity (Wrist_* / Ankle_*)
"""

import json
from pathlib import Path
import cv2
import numpy as np

from process_masked_5parts import _align_mask_to_ref, _place_on_canvas

LIMB_PARTS = ("arm_r", "arm_l", "leg_r", "leg_l")
MASK_SCALE = 2  # 2x canonical rect resolution for smooth joint transitions


def _classify_rgb_half(half_bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (sil_fg, class_rgb_u8) from one half of the semantic mask sheet."""
    rgb = cv2.cvtColor(half_bgr, cv2.COLOR_BGR2RGB)
    max_c = rgb.max(axis=2)
    sil_fg = max_c > 60
    dom = np.argmax(rgb, axis=2)  # 0=R, 1=G, 2=B

    cls_rgb = np.zeros_like(rgb, dtype=np.uint8)
    cls_rgb[sil_fg & (dom == 0)] = (255, 0, 0)
    cls_rgb[sil_fg & (dom == 1)] = (0, 255, 0)
    cls_rgb[sil_fg & (dom == 2)] = (0, 0, 255)
    return sil_fg, cls_rgb


def _fill_nearest_rgb(patch_rgb: np.ndarray, valid_mask: np.ndarray) -> np.ndarray:
    """Fill unlabeled pixels in patch_rgb from nearest valid_mask pixel."""
    if np.all(valid_mask) or not np.any(valid_mask):
        return patch_rgb
    _, labels = cv2.distanceTransformWithLabels(
        (~valid_mask).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    vy, vx = np.where(valid_mask)
    uy, ux = np.where(~valid_mask)
    out = patch_rgb.copy()
    out[uy, ux] = patch_rgb[vy[labels[uy, ux] - 1], vx[labels[uy, ux] - 1]]
    return out


def process_view_limbs(view: str, half_bgr: np.ndarray, audit_dir: Path | None = None) -> None:
    vdir = Path(f"sandbox/pilot_rig_lab/combat_assets/valentina_planar/{view}")
    parts_dir = vdir / "parts_5"
    meta = json.loads((parts_dir / "parts_5_meta.json").read_text(encoding="utf-8"))
    skel = json.loads((vdir / "rig_skeleton_config.json").read_text(encoding="utf-8"))

    # Match exact 1x reference placement used by process_masked_5parts.py
    W1, H1 = 520, 560
    ref_raw = cv2.imread(str(vdir / "body_unified.png"), cv2.IMREAD_UNCHANGED)
    bones_by_name = {b["name"]: b["pos"] for b in skel["bones"]}
    neck_x, neck_y = bones_by_name["Neck"][0], bones_by_name["Neck"][1]
    rh1, rw1 = ref_raw.shape[:2]
    ref_scale = 430.0 / float(rh1)
    rw_1x, rh_1x = int(round(rw1 * ref_scale)), int(round(rh1 * ref_scale))
    ox_1x = int(round(neck_x - rw_1x * 0.50))
    oy_1x = int(round(neck_y - rh_1x * 0.04))
    ref_canvas = _place_on_canvas(ref_raw, rw_1x, rh_1x, ox_1x, oy_1x, W1, H1, cv2.INTER_AREA)
    ref_alpha_1x = ref_canvas[:, :, 3] > 28

    sil_fg, cls_rgb = _classify_rgb_half(half_bgr)
    ox, oy, scale = _align_mask_to_ref(sil_fg, ref_alpha_1x)
    print(f"[{view}] aligned limb mask: ox={ox}, oy={oy}, scale={scale:.4f}")

    ys, xs = np.where(sil_fg)
    my0, my1 = int(ys.min()), int(ys.max()) + 1
    mx0, mx1 = int(xs.min()), int(xs.max()) + 1
    crop_cls = cls_rgb[my0:my1, mx0:mx1]

    W2, H2 = W1 * MASK_SCALE, H1 * MASK_SCALE
    nw2 = max(4, int(round((mx1 - mx0) * scale * MASK_SCALE)))
    nh2 = max(4, int(round((my1 - my0) * scale * MASK_SCALE)))
    canvas_cls = _place_on_canvas(
        crop_cls, nw2, nh2, ox * MASK_SCALE, oy * MASK_SCALE, W2, H2, cv2.INTER_NEAREST
    )

    rects = meta["rects"]
    audit_overlay = cv2.resize(ref_canvas[:, :, :3], (W2, H2), interpolation=cv2.INTER_LINEAR).copy()
    for part in LIMB_PARTS:
        rx, ry, rw, rh = rects[part]
        x0 = max(0, int(round(rx * MASK_SCALE)))
        y0 = max(0, int(round(ry * MASK_SCALE)))
        pw = max(4, int(round(rw * MASK_SCALE)))
        ph = max(4, int(round(rh * MASK_SCALE)))
        x1 = min(W2, x0 + pw)
        y1 = min(H2, y0 + ph)

        patch = canvas_cls[y0:y1, x0:x1]
        valid = patch.max(axis=2) > 128
        filled = _fill_nearest_rgb(patch, valid)

        # Smooth joint transitions while keeping weights normalized (R+G+B = 1.0)
        blurred = cv2.GaussianBlur(filled.astype(np.float32), (13, 13), 3.6)
        s_rgb = np.maximum(blurred.sum(axis=2, keepdims=True), 1e-5)
        norm_rgb = np.clip((blurred / s_rgb) * 255.0, 0, 255).astype(np.uint8)

        out_bgr = cv2.cvtColor(norm_rgb, cv2.COLOR_RGB2BGR)
        cv2.imwrite(str(parts_dir / f"{part}_anim_mask.png"), out_bgr)

        # Blend into audit preview
        p_img = cv2.imread(str(parts_dir / f"{part}.png"), cv2.IMREAD_UNCHANGED)
        p_a = cv2.resize(p_img[:, :, 3], (x1 - x0, y1 - y0), interpolation=cv2.INTER_AREA) > 40
        roi = audit_overlay[y0:y1, x0:x1]
        roi[p_a] = cv2.addWeighted(roi, 0.45, out_bgr, 0.55, 0.0)[p_a]

    if audit_dir is not None:
        audit_dir.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(audit_dir / f"audit_limb_mask_{view}.png"), audit_overlay)


def main() -> None:
    sheet_path = Path("sandbox/pilot_rig_lab/source_refs/valentina_limb_mask_sheet.jpg")
    sheet = cv2.imread(str(sheet_path), cv2.IMREAD_COLOR)
    h, w = sheet.shape[:2]
    audit_dir = Path("C:/Users/Frani/.gemini/antigravity/brain/bb755c55-c3f7-48df-b5ee-a7bbab5da010/scratch")
    process_view_limbs("s", sheet[:, : w // 2], audit_dir)
    process_view_limbs("n", sheet[:, w // 2 :], audit_dir)


if __name__ == "__main__":
    main()
