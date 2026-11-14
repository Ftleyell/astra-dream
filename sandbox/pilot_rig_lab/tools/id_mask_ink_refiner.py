"""Ink-locked SLIC superpixel + CIELAB graph propagation refiner for Valentina 1:1 ID masks.

Replaces naive RGB bare-skin overrides and 5x5-eroded OpenCV watershed with:
1. Thin ink-barrier extraction (pitch-black lineart + morphological blackhat panel seams).
2. Fine CIELAB SLIC superpixels strictly constrained inside non-ink foreground regions.
3. Eroded semantic seed voting per superpixel + Dijkstra propagation on the superpixel
   adjacency graph weighted by perceptual Delta-E and heavy ink-wall crossing penalties.
4. Island cleanup + Voronoi fill across ink lines and outer alpha fringes.
"""

from __future__ import annotations

import heapq
from collections import defaultdict

import cv2
import numpy as np
from skimage.color import rgb2lab
from skimage.segmentation import slic

INK_LUMA_HARD_THRESH: float = 18.0
INK_BLACKHAT_THRESH: float = 12.0
INK_CROSS_PENALTY: float = 85.0
SAME_REGION_SCALE: float = 0.65
MAX_SEED_DOMINANCE_RATIO: float = 1.8


def extract_ink_barrier(bgra: np.ndarray, fg: np.ndarray) -> np.ndarray:
    """Detects dark lineart and thin panel contour seams inside foreground."""
    b = bgra[:, :, 0].astype(np.float32)
    g = bgra[:, :, 1].astype(np.float32)
    r = bgra[:, :, 2].astype(np.float32)
    luma = 0.114 * b + 0.587 * g + 0.299 * r
    luma_u8 = np.clip(luma, 0.0, 255.0).astype(np.uint8)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    blackhat = cv2.morphologyEx(luma_u8, cv2.MORPH_BLACKHAT, kernel)
    return fg & ((luma < INK_LUMA_HARD_THRESH) | (blackhat > INK_BLACKHAT_THRESH))


def voronoi_fill_labels(
    values: np.ndarray,
    valid_mask: np.ndarray,
    target_mask: np.ndarray,
    max_dist_px: float = -1.0,
) -> np.ndarray:
    """Fills pixels in target_mask from nearest True pixel in valid_mask."""
    out = values.copy()
    missing = target_mask & (~valid_mask)
    if not np.any(missing) or not np.any(valid_mask):
        return out
    dist, labels = cv2.distanceTransformWithLabels(
        (~valid_mask).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    if max_dist_px > 0.0:
        missing = missing & (dist <= max_dist_px)
        if not np.any(missing):
            return out
    vy, vx = np.where(valid_mask)
    my, mx = np.where(missing)
    src_idx = labels[my, mx] - 1
    out[my, mx] = values[vy[src_idx], vx[src_idx]]
    return out


def compute_ink_constrained_superpixels(
    bgra: np.ndarray,
    non_ink: np.ndarray,
    px_per_segment: int = 50,
    compactness: float = 14.0,
) -> tuple[np.ndarray, np.ndarray]:
    """Segments non_ink foreground into fine CIELAB SLIC superpixels (labels >= 1)."""
    rgb = cv2.cvtColor(bgra[:, :, :3], cv2.COLOR_BGR2RGB)
    lab = rgb2lab(rgb).astype(np.float32)
    area = max(int(np.sum(non_ink)), 1)
    n_seg = max(80, area // max(px_per_segment, 20))
    sp = slic(
        lab,
        mask=non_ink,
        n_segments=n_seg,
        compactness=compactness,
        slic_zero=True,
        start_label=1,
    ).astype(np.int32)
    # Fill any tiny isolated non_ink pixel dropped by SLIC connectivity pruning
    valid_sp = (sp > 0) & non_ink
    if np.any(non_ink & (~valid_sp)) and np.any(valid_sp):
        sp = voronoi_fill_labels(sp, valid_sp, non_ink)
    return sp, lab


def _erode_seed_prior(
    prior_cls: np.ndarray,
    non_ink: np.ndarray,
    allowed_classes: tuple[int, ...],
    erode_px: int = 3,
) -> np.ndarray:
    """Erodes each component of a semantic class while preserving thin strokes & small enclosed islands."""
    safe = np.zeros_like(prior_cls, dtype=np.uint8)
    if erode_px <= 1:
        for cid in allowed_classes:
            safe[(prior_cls == cid) & non_ink] = cid
        return safe
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (erode_px, erode_px))
    for cid in allowed_classes:
        m = ((prior_cls == cid) & non_ink).astype(np.uint8)
        if not np.any(m):
            continue
        er = (cv2.erode(m, k) > 0) & non_ink
        safe[er] = cid
        # Preserve any connected component (e.g. eye sclera or thin accent) that eroded away completely
        n_cc, cc_lbl, _, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
        for ci in range(1, n_cc):
            comp_m = cc_lbl == ci
            if not np.any(er & comp_m):
                safe[comp_m] = cid
    return safe


def _build_superpixel_graph(
    sp: np.ndarray,
    non_ink: np.ndarray,
    ink_wall: np.ndarray,
    sp_lab: np.ndarray,
) -> dict[int, list[tuple[int, float]]]:
    """Builds weighted superpixel adjacency graph (direct touches + 2-3px across-ink bridges)."""
    edges: dict[tuple[int, int], bool] = {}  # True if direct non-ink touch

    def _add_pairs(a: np.ndarray, b: np.ndarray, direct: bool) -> None:
        mask = (a > 0) & (b > 0) & (a != b)
        if not np.any(mask):
            return
        pairs = np.stack([a[mask], b[mask]], axis=1)
        lo = np.minimum(pairs[:, 0], pairs[:, 1])
        hi = np.maximum(pairs[:, 0], pairs[:, 1])
        uniq = np.unique(np.stack([lo, hi], axis=1), axis=0)
        for u, v in uniq:
            key = (int(u), int(v))
            if direct or key not in edges:
                edges[key] = direct

    # Direct 4-connected neighbors inside non_ink
    _add_pairs(sp[:, :-1], sp[:, 1:], True)
    _add_pairs(sp[:-1, :], sp[1:, :], True)

    # Bridges across thin ink barriers (offsets 2..4 px where middle hits ink_wall)
    for step in (2, 3, 4):
        if sp.shape[1] > step:
            mid_h = ink_wall[:, step // 2 : sp.shape[1] - (step - step // 2)]
            _add_pairs(
                np.where(mid_h, sp[:, :-step], 0),
                np.where(mid_h, sp[:, step:], 0),
                False,
            )
        if sp.shape[0] > step:
            mid_v = ink_wall[step // 2 : sp.shape[0] - (step - step // 2), :]
            _add_pairs(
                np.where(mid_v, sp[:-step, :], 0),
                np.where(mid_v, sp[step:, :], 0),
                False,
            )

    adj: dict[int, list[tuple[int, float]]] = defaultdict(list)
    for (u, v), direct in edges.items():
        de = float(np.linalg.norm(sp_lab[u] - sp_lab[v]))
        w = (de * SAME_REGION_SCALE) if direct else (de + INK_CROSS_PENALTY)
        adj[u].append((v, max(w, 0.05)))
        adj[v].append((u, max(w, 0.05)))
    return adj


def remove_small_islands(
    cls_map: np.ndarray,
    fg_mask: np.ndarray,
    allowed_classes: tuple[int, ...],
    min_area: int = 35,
) -> np.ndarray:
    """Replaces isolated islands smaller than min_area with nearest valid neighbor class."""
    out = cls_map.copy()
    valid_keep = np.zeros_like(fg_mask, dtype=bool)
    for cid in allowed_classes:
        m = ((out == cid) & fg_mask).astype(np.uint8)
        if not np.any(m):
            continue
        n, labels, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
        for comp_id in range(1, n):
            if int(stats[comp_id, cv2.CC_STAT_AREA]) > min_area:
                valid_keep[labels == comp_id] = True
    if np.any(valid_keep) and np.any(fg_mask & (~valid_keep)):
        out = voronoi_fill_labels(out, valid_keep, fg_mask)
    return out


def refine_mask_ink_locked(
    bgra: np.ndarray,
    prior_cls: np.ndarray,
    allowed_classes: tuple[int, ...],
    allow_zero_class: bool = False,
    zero_seed_code: int = 5,
    erode_px: int = 3,
    px_per_segment: int = 48,
    min_island_area: int = 35,
) -> np.ndarray:
    """Refines a noisy semantic class map onto exact ink lines & CIELAB color regions.

    When allow_zero_class is True (e.g., bare skin on torso/heads), zero_seed_code
    is propagated inside non_ink alongside allowed_classes and mapped back to 0 at end.
    """
    fg = bgra[:, :, 3] > 16
    alpha_any = bgra[:, :, 3] > 0
    if not np.any(fg):
        return np.zeros(bgra.shape[:2], dtype=np.uint8)

    ink_wall = extract_ink_barrier(bgra, fg)
    non_ink = fg & (~ink_wall)
    if not np.any(non_ink):
        non_ink = fg

    sp, lab = compute_ink_constrained_superpixels(bgra, non_ink, px_per_segment=px_per_segment)
    max_sp = int(sp.max())

    # Mean Lab per superpixel
    sp_lab = np.zeros((max_sp + 1, 3), dtype=np.float32)
    counts = np.bincount(sp[non_ink], minlength=max_sp + 1).astype(np.float32)
    for ch in range(3):
        sums = np.bincount(sp[non_ink], weights=lab[:, :, ch][non_ink], minlength=max_sp + 1)
        sp_lab[:, ch] = np.divide(sums, np.maximum(counts, 1.0))

    seed_classes = allowed_classes + ((zero_seed_code,) if allow_zero_class else ())
    safe_prior = _erode_seed_prior(prior_cls, non_ink, seed_classes, erode_px=erode_px)

    # Seed confidence per superpixel using safe_prior first, raw prior only if superpixel entirely untouched
    sp_label = np.zeros(max_sp + 1, dtype=np.int32)
    seed_cost = np.full(max_sp + 1, np.inf, dtype=np.float32)

    valid_seed_mask = non_ink & np.isin(safe_prior, seed_classes)
    if np.any(valid_seed_mask):
        # Count class occurrences per superpixel cleanly via vectorized grouping
        sids = sp[valid_seed_mask]
        cids = safe_prior[valid_seed_mask]
        cls_votes: dict[int, dict[int, int]] = defaultdict(dict)
        for cid in seed_classes:
            cm = cids == cid
            if not np.any(cm):
                continue
            uniq_s, cnt_s = np.unique(sids[cm], return_counts=True)
            for u, c in zip(uniq_s, cnt_s):
                cls_votes[int(u)][cid] = int(c)
        for sid, vdict in cls_votes.items():
            ranked = sorted(vdict.items(), key=lambda kv: kv[1], reverse=True)
            top_c, top_n = ranked[0]
            runner_n = ranked[1][1] if len(ranked) > 1 else 0
            total_sp_px = float(counts[sid])
            min_frac = 0.20 if runner_n == 0 else 0.35
            if (top_n / max(total_sp_px, 1.0)) >= min_frac and (
                runner_n == 0 or (top_n / max(runner_n, 1)) >= MAX_SEED_DOMINANCE_RATIO
            ):
                sp_label[sid] = top_c
                seed_cost[sid] = 0.0

    # Dijkstra graph propagation across adjacent superpixels
    adj = _build_superpixel_graph(sp, non_ink, ink_wall, sp_lab)
    pq: list[tuple[float, int]] = []
    for sid in range(1, max_sp + 1):
        if sp_label[sid] > 0:
            heapq.heappush(pq, (0.0, sid))

    while pq:
        d, u = heapq.heappop(pq)
        if d > seed_cost[u]:
            continue
        lbl = sp_label[u]
        for v, w in adj.get(u, ()):
            nd = d + w
            if nd < seed_cost[v]:
                seed_cost[v] = nd
                sp_label[v] = lbl
                heapq.heappush(pq, (nd, v))

    # Map superpixel labels back to pixels
    refined_non_ink = np.where(non_ink, sp_label[sp], 0).astype(np.uint8)
    valid_out = non_ink & np.isin(refined_non_ink, seed_classes)

    # Fallback if an isolated component wasn't reached by graph edges
    if np.any(valid_out) and np.any(non_ink & (~valid_out)):
        refined_non_ink = voronoi_fill_labels(refined_non_ink, valid_out, non_ink)
        valid_out = non_ink & np.isin(refined_non_ink, seed_classes)

    # Clean tiny stray islands inside non_ink before filling ink lines
    refined = remove_small_islands(refined_non_ink, non_ink, seed_classes, min_area=min_island_area)
    # Propagate labels cleanly through ink lines and outer 1-2px AA fringes
    refined = voronoi_fill_labels(refined, non_ink & np.isin(refined, seed_classes), alpha_any)
    refined[~alpha_any] = 0

    if allow_zero_class:
        refined[refined == zero_seed_code] = 0
    return refined
