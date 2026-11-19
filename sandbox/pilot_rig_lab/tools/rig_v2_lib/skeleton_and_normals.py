"""Skeleton bone derivation, 3D relief/normal+depth synthesis, and geodesic anim weight baking."""

from __future__ import annotations

import cv2
import numpy as np
import scipy.ndimage as ndimage
import scipy.sparse as sp
import scipy.sparse.linalg as spla

from process_masked_5parts import TEX_SCALE

from .constants import BONE_PARENTS, LIMB_PARTS, PX_H, PX_W


def _row_center(mask: np.ndarray, y: int) -> float | None:
    if y < 0 or y >= mask.shape[0]:
        return None
    xs = np.where(mask[y])[0]
    return float(xs.mean()) if len(xs) > 0 else None


def _seam_centroid(seg_a: np.ndarray, seg_b: np.ndarray, fallback_pt: tuple[float, float]) -> tuple[float, float]:
    """Find joint center where segment A meets segment B inside a limb."""
    if not np.any(seg_a) or not np.any(seg_b):
        return fallback_pt
    dil_a = cv2.dilate(seg_a.astype(np.uint8), np.ones((19, 19), np.uint8)) > 0
    dil_b = cv2.dilate(seg_b.astype(np.uint8), np.ones((19, 19), np.uint8)) > 0
    seam = dil_a & dil_b
    if not np.any(seam):
        ys_a, xs_a = np.where(seg_a)
        ys_b, xs_b = np.where(seg_b)
        return (0.5 * (float(xs_a.mean()) + float(xs_b.mean())), 0.5 * (float(ys_a.max()) + float(ys_b.min())))
    ys, xs = np.where(seam)
    return float(xs.mean()), float(ys.mean())


def _derive_view_bones(
    view: str,
    part_masks: dict[str, np.ndarray],
    limb_segments: np.ndarray,
    neck_disp: tuple[float, float],
    limb_seg_overrides: dict[str, np.ndarray] | None = None,
) -> list[dict[str, object]]:
    """Compute all 16 canonical bone coordinates directly from cleaned masks."""
    bc = part_masks["body_core"]
    ys_bc, xs_bc = np.where(bc)
    top_y = int(ys_bc.min())
    bot_y = int(ys_bc.max())

    # Narrowest torso waist row inside mid-torso
    w_y0 = top_y + int((bot_y - top_y) * 0.25)
    w_y1 = top_y + int((bot_y - top_y) * 0.62)
    waist_y = (w_y0 + w_y1) // 2
    min_w = 10**6
    for y in range(w_y0, max(w_y0 + 1, w_y1)):
        xs = np.where(bc[y])[0]
        if len(xs) > 20 and (xs.max() - xs.min()) < min_w:
            min_w = int(xs.max() - xs.min())
            waist_y = y
    waist_cx = _row_center(bc, waist_y) or (neck_disp[0] * float(TEX_SCALE))

    chest_y = int(round(top_y + (waist_y - top_y) * 0.45))
    chest_cx = _row_center(bc, chest_y) or waist_cx
    pelvis_y = int(round(waist_y + (bot_y - waist_y) * 0.52))
    pelvis_cx = _row_center(bc, pelvis_y) or waist_cx

    def _to_disp(pt_px: tuple[float, float]) -> list[float]:
        return [round(pt_px[0] / float(TEX_SCALE), 1), round(pt_px[1] / float(TEX_SCALE), 1)]

    limb_pts: dict[str, tuple[list[float], list[float], list[float]]] = {}
    for pname in LIMB_PARTS:
        pm = part_masks[pname]
        if int(pm.sum()) < 250:
            continue
        seg_src = limb_seg_overrides[pname] if (limb_seg_overrides is not None and pname in limb_seg_overrides) else limb_segments
        is_upper = (seg_src[:, :, 2] > 128) & (seg_src[:, :, 1] < 90) & (seg_src[:, :, 0] < 90)
        is_lower = (seg_src[:, :, 1] > 128) & (seg_src[:, :, 2] < 90) & (seg_src[:, :, 0] < 90)
        is_ext = (seg_src[:, :, 0] > 128) & (seg_src[:, :, 2] < 90) & (seg_src[:, :, 1] < 90)

        ys_p, xs_p = np.where(pm)
        py0, py1 = int(ys_p.min()), int(ys_p.max())
        u_m = pm & is_upper
        l_m = pm & is_lower
        e_m = pm & is_ext

        u_ys, u_xs = np.where(u_m) if np.any(u_m) else (ys_p, xs_p)
        if pname.startswith("arm"):
            top_band = u_m & (np.arange(PX_H)[:, None] <= (int(u_ys.min()) + 28))
            bys, bxs = np.where(top_band) if np.any(top_band) else (u_ys, u_xs)
            sx = float(bxs.mean())
            # Pull shoulder slightly inward toward chest socket center
            sx = sx + (chest_cx - sx) * 0.22
            sy = float(bys.min()) + 14.0
        else:
            hip_y = float(pelvis_y) + 26.0 * float(TEX_SCALE)
            if np.any(u_m) and int(u_ys.min()) <= int(round(hip_y + 10.0)):
                top_band = u_m & (np.arange(PX_H)[:, None] <= (int(u_ys.min()) + 32))
                bys, bxs = np.where(top_band) if np.any(top_band) else (u_ys, u_xs)
                sx = float(bxs.mean())
                sy = max(float(pelvis_y) + 28.0, float(bys.min()) + 10.0)
            else:
                # When limb_segments starts at stocking cuff below the bare hip/glute, anchor Thigh at hip socket
                hip_band = pm & (np.abs(np.arange(PX_H)[:, None] - hip_y) <= 18.0)
                bys, bxs = np.where(hip_band) if np.any(hip_band) else (ys_p, xs_p)
                sx = float(bxs.mean())
                sy = hip_y

        mid_fb = (float(xs_p.mean()), float(py0 + (py1 - py0) * 0.45))
        ext_fb = (float(xs_p.mean()), float(py0 + (py1 - py0) * 0.85))
        mid_pt = _seam_centroid(u_m, l_m, mid_fb)
        end_pt = _seam_centroid(l_m, e_m, ext_fb)
        limb_pts[pname] = (_to_disp((sx, sy)), _to_disp(mid_pt), _to_disp(end_pt))

    # Fill occluded side in pure profile views E / W from visible profile side
    pairs = [("arm_r", "arm_l"), ("leg_r", "leg_l")]
    for a, b in pairs:
        if a in limb_pts and b not in limb_pts:
            limb_pts[b] = limb_pts[a]
        elif b in limb_pts and a not in limb_pts:
            limb_pts[a] = limb_pts[b]

    coords: dict[str, list[float]] = {
        "Pelvis": [round(pelvis_cx / float(TEX_SCALE), 1), round(pelvis_y / float(TEX_SCALE), 1)],
        "Waist": [round(waist_cx / float(TEX_SCALE), 1), round(waist_y / float(TEX_SCALE), 1)],
        "Chest": [round(chest_cx / float(TEX_SCALE), 1), round(chest_y / float(TEX_SCALE), 1)],
        "Neck": [round(neck_disp[0], 1), round(neck_disp[1], 1)],
        "Shoulder_R": limb_pts["arm_r"][0],
        "Elbow_R": limb_pts["arm_r"][1],
        "Wrist_R": limb_pts["arm_r"][2],
        "Shoulder_L": limb_pts["arm_l"][0],
        "Elbow_L": limb_pts["arm_l"][1],
        "Wrist_L": limb_pts["arm_l"][2],
        "Thigh_R": limb_pts["leg_r"][0],
        "Knee_R": limb_pts["leg_r"][1],
        "Ankle_R": limb_pts["leg_r"][2],
        "Thigh_L": limb_pts["leg_l"][0],
        "Knee_L": limb_pts["leg_l"][1],
        "Ankle_L": limb_pts["leg_l"][2],
        "Pauldron_R": limb_pts["arm_r"][0],
        "Pauldron_L": limb_pts["arm_l"][0],
    }
    return [{"name": bname, "parent": parent, "pos": coords[bname]} for bname, parent in BONE_PARENTS]


def _hermite_c2(t: np.ndarray) -> np.ndarray:
    """Polinomio Hermite quíntico C2: 6t^5 - 15t^4 + 10t^3."""
    x = np.clip(t, 0.0, 1.0)
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


def _build_part_bone_chain_3d(
    pname: str,
    meta_bones_dict: dict,
    x0: int,
    y0: int,
    ph: int,
    pw: int,
) -> tuple[list[tuple[float, float]], list[float]]:
    """Retorna cadena ósea 2D local al patch (px TEX_SCALE) y profundidades Z globales."""
    bones_list = meta_bones_dict.get("bones", [])
    bmap: dict[str, tuple[float, float]] = {
        str(b["name"]): (
            float(b["pos"][0]) * float(TEX_SCALE) - float(x0),
            float(b["pos"][1]) * float(TEX_SCALE) - float(y0),
        )
        for b in bones_list
    }
    z_orders = meta_bones_dict.get("z_orders", {})
    bc_z_ord = float(z_orders.get("body_core", 4))
    p_z_ord = float(z_orders.get(pname, bc_z_ord))
    z_layer = (p_z_ord - bc_z_ord) * 16.0
    view = str(meta_bones_dict.get("view", "s"))

    def _pt(name: str, fallback: tuple[float, float]) -> tuple[float, float]:
        return bmap.get(name, fallback)

    if pname == "body_core":
        pelvis = _pt("Pelvis", (pw * 0.5, ph * 0.85))
        waist = _pt("Waist", (pw * 0.5, ph * 0.62))
        chest = _pt("Chest", (pw * 0.5, ph * 0.35))
        neck = _pt("Neck", (pw * 0.5, ph * 0.12))
        chest_z = 10.0 if view in ("s", "se", "sw", "n", "ne", "nw") else 6.0
        return [pelvis, waist, chest, neck], [0.0, 4.0, chest_z, 2.0]

    if pname in ("arm_r", "arm_l"):
        side = "R" if pname.endswith("_r") else "L"
        sh = _pt(f"Shoulder_{side}", (pw * 0.5, ph * 0.15))
        el = _pt(f"Elbow_{side}", (pw * 0.5, ph * 0.52))
        wr = _pt(f"Wrist_{side}", (pw * 0.5, ph * 0.88))
        z_sh = 4.0
        return [sh, el, wr], [z_sh, z_sh + z_layer * 0.75, z_sh + z_layer]

    if pname in ("leg_r", "leg_l"):
        side = "R" if pname.endswith("_r") else "L"
        th = _pt(f"Thigh_{side}", (pw * 0.5, ph * 0.12))
        kn = _pt(f"Knee_{side}", (pw * 0.5, ph * 0.52))
        an = _pt(f"Ankle_{side}", (pw * 0.5, ph * 0.88))
        z_th = 0.0
        return [th, kn, an], [z_th, z_th + z_layer * 0.75, z_th + z_layer]

    if pname in ("pauldron_r", "pauldron_l"):
        side = "R" if pname.endswith("_r") else "L"
        sh = _pt(f"Shoulder_{side}", (pw * 0.5, ph * 0.6))
        pa = _pt(f"Pauldron_{side}", (pw * 0.5, ph * 0.35))
        if np.hypot(pa[0] - sh[0], pa[1] - sh[1]) < 4.0:
            pa = (sh[0], sh[1] - 18.0)
        return [sh, pa], [14.0, 18.0]

    return [(pw * 0.5, ph * 0.15), (pw * 0.5, ph * 0.85)], [z_layer, z_layer]


def _build_torso_relief_height(ph: int, pw: int, meta_bones_dict: dict, x0: int, y0: int) -> np.ndarray:
    """Campo suave de bajorrelieve estructural para RNM en body_core (pecho, clavícula, cintura)."""
    bones_map = {str(b["name"]): b["pos"] for b in meta_bones_dict.get("bones", [])}
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float32)
    relief = np.zeros((ph, pw), dtype=np.float32)
    if "Chest" in bones_map:
        cx = float(bones_map["Chest"][0]) * float(TEX_SCALE) - float(x0)
        cy = float(bones_map["Chest"][1]) * float(TEX_SCALE) - float(y0)
        relief += 3.2 * np.exp(-(((xx - cx) / 28.0) ** 2 + ((yy - cy) / 20.0) ** 2))
    if "Waist" in bones_map:
        wx = float(bones_map["Waist"][0]) * float(TEX_SCALE) - float(x0)
        wy = float(bones_map["Waist"][1]) * float(TEX_SCALE) - float(y0)
        relief -= 1.4 * np.exp(-(((xx - wx) / 24.0) ** 2 + ((yy - wy) / 18.0) ** 2))
    if "Neck" in bones_map:
        nx_b = float(bones_map["Neck"][0]) * float(TEX_SCALE) - float(x0)
        ny_b = float(bones_map["Neck"][1]) * float(TEX_SCALE) - float(y0) + 14.0
        relief += 1.6 * np.exp(-(((xx - nx_b) / 34.0) ** 2 + ((yy - ny_b) / 10.0) ** 2))
    return relief


def _synthesize_skeleton_normal_and_depth(
    mask: np.ndarray,
    bone_chain_xy: list[tuple[float, float]],
    bone_chain_z: list[float],
    z_global_range: tuple[float, float] = (-110.0, 110.0),
    cap_open_mask: np.ndarray | None = None,
    torso_relief_height: np.ndarray | None = None,
    nz_min_byte: int = 202,
) -> np.ndarray:
    """Genera _normal_depth.png en orden BGRA (B=nz 202..254, G=ny, R=nx, A=depth 80..239)."""
    h, w = mask.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    valid = mask > 0

    edt_domain = valid if cap_open_mask is None else (valid | (cap_open_mask > 0))
    edt = ndimage.distance_transform_edt(edt_domain).astype(np.float32)

    w_sum = np.zeros((h, w), dtype=np.float32)
    tx_acc = np.zeros((h, w), dtype=np.float32)
    ty_acc = np.zeros((h, w), dtype=np.float32)
    dx_acc = np.zeros((h, w), dtype=np.float32)
    dy_acc = np.zeros((h, w), dtype=np.float32)
    z_axial = np.zeros((h, w), dtype=np.float32)
    tilt_acc = np.zeros((h, w), dtype=np.float32)

    for k in range(len(bone_chain_xy) - 1):
        a = np.array(bone_chain_xy[k], dtype=np.float32)
        b = np.array(bone_chain_xy[k + 1], dtype=np.float32)
        za, zb = float(bone_chain_z[k]), float(bone_chain_z[k + 1])
        ba = b - a
        l_seg = max(float(np.linalg.norm(ba)), 1e-4)
        t_vec = ba / l_seg
        pa_x = xx - a[0]
        pa_y = yy - a[1]
        h_proj = np.clip((pa_x * ba[0] + pa_y * ba[1]) / (l_seg * l_seg), 0.0, 1.0)
        dx = pa_x - ba[0] * h_proj
        dy = pa_y - ba[1] * h_proj
        dist_sq = dx * dx + dy * dy
        w_k = 1.0 / (dist_sq + 16.0)
        w_sum += w_k
        tx_acc += w_k * t_vec[0]
        ty_acc += w_k * t_vec[1]
        dx_acc += w_k * dx
        dy_acc += w_k * dy
        z_axial += w_k * ((1.0 - h_proj) * za + h_proj * zb)
        tilt_acc += w_k * float(np.clip((zb - za) / l_seg, -0.35, 0.35))

    inv_w = 1.0 / np.maximum(w_sum, 1e-6)
    tx = tx_acc * inv_w
    ty = ty_acc * inv_w
    t_norm = np.maximum(np.hypot(tx, ty), 1e-6)
    tx /= t_norm
    ty /= t_norm
    bx, by = -ty, tx

    dx_blend = dx_acc * inv_w
    dy_blend = dy_acc * inv_w
    z_axial *= inv_w
    n_long = tilt_acc * inv_w

    u_lat = dx_blend * bx + dy_blend * by
    r_local = np.abs(u_lat) + edt + 1e-4
    xi = np.clip(u_lat / r_local, -1.0, 1.0)

    nz_min = max((float(nz_min_byte) - 128.0) / 127.0, 0.20)
    sin_max = float(np.sqrt(max(1.0 - nz_min * nz_min - 0.04, 0.1)))
    n_lat = xi * sin_max

    nx = n_lat * bx + n_long * tx
    ny = n_lat * by + n_long * ty
    nz = np.sqrt(np.maximum(1.0 - nx * nx - ny * ny, nz_min * nz_min))

    if torso_relief_height is not None:
        gy, gx = np.gradient(torso_relief_height.astype(np.float32))
        dn_norm = np.sqrt(gx * gx + gy * gy + 1.0)
        dnx, dny, dnz = -gx / dn_norm, -gy / dn_norm, 1.0 / dn_norm
        tz = nz + 1.0
        dot_tu = nx * (-dnx) + ny * (-dny) + tz * dnz
        nx = nx * (dot_tu / tz) + dnx
        ny = ny * (dot_tu / tz) + dny
        nz = tz * (dot_tu / tz) - dnz
        n_len = np.maximum(np.sqrt(nx * nx + ny * ny + nz * nz), 1e-6)
        nx, ny, nz = nx / n_len, ny / n_len, np.maximum(nz / n_len, nz_min)

    z_thickness = 0.65 * np.minimum(r_local, 55.0) * np.sqrt(np.maximum(1.0 - xi * xi, 0.0))
    z_total = z_axial + z_thickness
    z_min, z_max = z_global_range
    z_norm = np.clip((z_total - z_min) / max(z_max - z_min, 1e-4), 0.0, 1.0)

    out_bgra = np.zeros((h, w, 4), dtype=np.uint8)
    out_bgra[:, :, 0] = 254  # B = nz
    out_bgra[:, :, 1] = 128  # G = ny
    out_bgra[:, :, 2] = 128  # R = nx
    out_bgra[:, :, 3] = 80   # A = depth
    if np.any(valid):
        out_bgra[valid, 2] = np.clip(np.round(128.0 + 127.0 * nx[valid]), 1, 254).astype(np.uint8)
        out_bgra[valid, 1] = np.clip(np.round(128.0 + 127.0 * ny[valid]), 1, 254).astype(np.uint8)
        out_bgra[valid, 0] = np.clip(np.round(128.0 + 126.0 * nz[valid]), nz_min_byte, 254).astype(np.uint8)
        out_bgra[valid, 3] = np.clip(np.round(80.0 + 159.0 * z_norm[valid]), 80, 239).astype(np.uint8)
    return out_bgra


def _bake_geodesic_anim_mask_with_crease_cut(
    mask: np.ndarray,
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    seam_pivot: tuple[float, float],
    seam_fade_radius: float = 42.0,
) -> np.ndarray:
    """Hornea _anim_mask.png en BGRA (R=proximal, G=bisagra, B=distal, A=seam_fade) con Corte de Pliegue."""
    h, w = mask.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    p0_v = np.array(p0, dtype=np.float32)
    p1_v = np.array(p1, dtype=np.float32)
    p2_v = np.array(p2, dtype=np.float32)

    def _sd_segment(a: np.ndarray, b: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        pa_x, pa_y = xx - a[0], yy - a[1]
        ba = b - a
        h_p = np.clip((pa_x * ba[0] + pa_y * ba[1]) / max(float(np.dot(ba, ba)), 1e-6), 0.0, 1.0)
        return np.hypot(pa_x - ba[0] * h_p, pa_y - ba[1] * h_p), h_p

    dist1, h1 = _sd_segment(p0_v, p1_v)
    dist2, h2 = _sd_segment(p1_v, p2_v)

    u1 = (p0_v - p1_v) / max(float(np.linalg.norm(p0_v - p1_v)), 1e-6)
    u2 = (p2_v - p1_v) / max(float(np.linalg.norm(p2_v - p1_v)), 1e-6)
    bisector = u1 + u2
    b_norm = float(np.linalg.norm(bisector))
    has_crease = (b_norm > 1e-3) and (float(np.dot(u1, u2)) > -0.35)
    if has_crease:
        bisector /= b_norm
    else:
        bisector = np.array([-u1[1], u1[0]], dtype=np.float32)

    valid_y, valid_x = np.nonzero(mask > 0)
    n_px = len(valid_y)
    out_bgra = np.zeros((h, w, 4), dtype=np.uint8)
    if n_px == 0:
        out_bgra[:, :, 2] = 255
        out_bgra[:, :, 3] = 255
        return out_bgra

    idx_map = np.full((h, w), -1, dtype=np.int32)
    idx_map[valid_y, valid_x] = np.arange(n_px, dtype=np.int32)

    px = valid_x.astype(np.float32) - p1_v[0]
    py = valid_y.astype(np.float32) - p1_v[1]
    proj_crease = px * bisector[0] + py * bisector[1]
    perp_crease = px * (-bisector[1]) + py * bisector[0]

    rows: list[np.ndarray] = []
    cols: list[np.ndarray] = []
    vals: list[np.ndarray] = []
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        ny_i, nx_i = valid_y + dy, valid_x + dx
        in_b = (ny_i >= 0) & (ny_i < h) & (nx_i >= 0) & (nx_i < w)
        nb = np.full(n_px, -1, dtype=np.int32)
        nb[in_b] = idx_map[ny_i[in_b], nx_i[in_b]]
        ok = nb >= 0
        src = np.nonzero(ok)[0]
        dst = nb[ok]
        if has_crease and len(src) > 0:
            crosses = (proj_crease[src] > 0.0) & (
                (perp_crease[src] * perp_crease[dst] <= 0.0)
                & (np.abs(perp_crease[src] - perp_crease[dst]) < 3.0)
            )
            keep = ~crosses
            src, dst = src[keep], dst[keep]
        rows.append(src)
        cols.append(dst)
        vals.append(np.full(len(src), -1.0, dtype=np.float64))

    a_off = sp.csr_matrix(
        (np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))),
        shape=(n_px, n_px),
    )
    deg = np.array(-a_off.sum(axis=1)).ravel()
    lap = a_off + sp.diags(deg)

    on_b1 = (dist1[valid_y, valid_x] <= 2.0) & (
        (perp_crease <= 0.0) if has_crease else (dist1[valid_y, valid_x] <= dist2[valid_y, valid_x])
    )
    on_b2 = (dist2[valid_y, valid_x] <= 2.0) & (
        (perp_crease > 0.0) if has_crease else (dist2[valid_y, valid_x] < dist1[valid_y, valid_x])
    )
    if not np.any(on_b1):
        on_b1 = dist1[valid_y, valid_x] <= float(dist1[valid_y, valid_x].min() + 2.0)
    if not np.any(on_b2):
        on_b2 = dist2[valid_y, valid_x] <= float(dist2[valid_y, valid_x].min() + 2.0)

    w_dir = np.zeros(n_px, dtype=np.float64)
    rhs = np.zeros(n_px, dtype=np.float64)
    tau_b1 = 0.5 * h1[valid_y, valid_x]
    tau_b2 = 0.5 + 0.5 * h2[valid_y, valid_x]
    w_dir[on_b1] = 50.0
    rhs[on_b1] = 50.0 * tau_b1[on_b1]
    w_dir[on_b2] = 50.0
    rhs[on_b2] = 50.0 * tau_b2[on_b2]

    tau_sol = np.clip(spla.spsolve(lap + sp.diags(w_dir + 1e-6), rhs), 0.0, 1.0)

    w_r = 1.0 - _hermite_c2((tau_sol - 0.08) / (0.55 - 0.08))
    w_b = _hermite_c2((tau_sol - 0.45) / (0.92 - 0.45))
    w_g = np.clip(1.0 - w_r - w_b, 0.0, 1.0)
    w_sum = np.maximum(w_r + w_g + w_b, 1e-6)
    w_r, w_g, w_b = w_r / w_sum, w_g / w_sum, w_b / w_sum

    d_seam = np.hypot(valid_x.astype(np.float32) - seam_pivot[0], valid_y.astype(np.float32) - seam_pivot[1])
    seam_fade = _hermite_c2(d_seam / max(seam_fade_radius, 1.0))

    # BGRA para cv2.imwrite: B=w_B, G=w_G, R=w_R, A=seam_fade
    out_bgra[valid_y, valid_x, 2] = np.clip(np.round(w_r * 255.0), 0, 255).astype(np.uint8)
    out_bgra[valid_y, valid_x, 1] = np.clip(np.round(w_g * 255.0), 0, 255).astype(np.uint8)
    out_bgra[valid_y, valid_x, 0] = np.clip(np.round(w_b * 255.0), 0, 255).astype(np.uint8)
    out_bgra[valid_y, valid_x, 3] = np.clip(np.round(seam_fade * 255.0), 0, 255).astype(np.uint8)
    return out_bgra


def _synthesize_rear_arm_maps(
    arm_rgba: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Build (mask, id_bgra, own limb_seg) for an external rear arm sprite in 1560x1680."""
    raw_mask = arm_rgba[:, :, 3] > 20
    n_cc, lbl, st, _ = cv2.connectedComponentsWithStats(raw_mask.astype(np.uint8))
    if n_cc > 2:
        main_cc = max(range(1, n_cc), key=lambda i: int(st[i, cv2.CC_STAT_AREA]))
        mask = lbl == main_cc
    else:
        mask = raw_mask

    id_bgra = np.zeros((PX_H, PX_W, 4), dtype=np.uint8)
    b, g, r = arm_rgba[:, :, 0].astype(np.int16), arm_rgba[:, :, 1].astype(np.int16), arm_rgba[:, :, 2].astype(np.int16)
    is_accent = mask & (r > b + 16) & (r > g + 14) & (r > 55)
    is_suit = mask & (~is_accent)
    id_bgra[is_suit, 0] = 255
    id_bgra[is_accent, 2] = 255

    ys_m = np.where(mask)[0]
    py0, py1 = (int(ys_m.min()), int(ys_m.max())) if len(ys_m) > 0 else (620, 1040)
    span_y = max(float(py1 - py0), 30.0)
    # Anatomical seams derived from arm silhouette itself: elbow sleeve cuff (~0.28) & wrist sphere (~0.69)
    elbow_y = float(py0) + span_y * 0.28
    wrist_y = float(py0) + span_y * 0.69
    yy = np.arange(PX_H, dtype=np.float32)[:, None]
    limb_seg = np.zeros((PX_H, PX_W, 3), dtype=np.uint8)
    limb_seg[mask & (yy <= elbow_y)] = (0, 0, 255)
    limb_seg[mask & (yy > elbow_y) & (yy <= wrist_y)] = (0, 255, 0)
    limb_seg[mask & (yy > wrist_y)] = (255, 0, 0)
    return mask, id_bgra, limb_seg
