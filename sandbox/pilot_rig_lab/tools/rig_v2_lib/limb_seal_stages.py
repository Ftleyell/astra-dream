"""Post-assembly micro-speck pruning without morphological border alteration."""

from __future__ import annotations

import cv2
import numpy as np


def prune_tiny_specks(
    part_masks: dict[str, np.ndarray],
    custom_part_src: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]],
    min_area_px: int = 64,
) -> None:
    """Drop tiny disconnected alpha specks (< min_area_px) without altering piece borders."""
    for pk in list(part_masks.keys()):
        pm = part_masks[pk]
        if int(pm.sum()) < 250:
            continue
        if pk in custom_part_src:
            p_rgba_c, p_id_c, p_seg_c = custom_part_src[pk]
            fg_cc = (p_rgba_c[:, :, 3] >= 16).astype(np.uint8)
        else:
            p_rgba_c, p_id_c, p_seg_c = None, None, None
            fg_cc = pm.astype(np.uint8)

        n_cc, lbl_cc, st_cc, _ = cv2.connectedComponentsWithStats(fg_cc, connectivity=8)
        if n_cc <= 2:
            continue
        drop_mask = np.zeros_like(pm, dtype=bool)
        for cc_id in range(1, n_cc):
            if int(st_cc[cc_id, cv2.CC_STAT_AREA]) < min_area_px:
                drop_mask |= (lbl_cc == cc_id)
        if not np.any(drop_mask):
            continue
        part_masks[pk] = pm & (~drop_mask)
        if p_rgba_c is not None and p_id_c is not None and p_seg_c is not None:
            p_rgba_out = p_rgba_c.copy()
            p_rgba_out[drop_mask] = 0
            custom_part_src[pk] = (p_rgba_out, p_id_c, p_seg_c)
