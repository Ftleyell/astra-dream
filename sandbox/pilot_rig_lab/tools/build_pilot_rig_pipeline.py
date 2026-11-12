"""
Astra Dream — Pipeline Unificado Multi-Piloto (Rigging 2D, Upscayl 4x y Máscaras Clown-Pass)
Ubicación: sandbox/pilot_rig_lab/tools/build_pilot_rig_pipeline.py

Uso:
    # Reconstruir a Valentina (piloto base -> sandbox/pilot_rig_lab/assets/):
    python sandbox/pilot_rig_lab/tools/build_pilot_rig_pipeline.py --pilot valentina

    # Construir una nueva piloto (ej: 'kaelen' -> sandbox/pilot_rig_lab/pilots/kaelen/):
    python sandbox/pilot_rig_lab/tools/build_pilot_rig_pipeline.py --pilot kaelen

Entradas esperadas en sandbox/pilot_rig_lab/source_refs/:
  1. <pilot>_step1_master_9x16.(jpg|png)     (Concepto Maestro Vertical 9:16)
  2. <pilot>_step2_parts_16x9.(jpg|png)      (Hoja 3-Zonas 16:9 de 6 Piezas sobre Chroma Verde)
  3. <pilot>_step3_clown_pass_16x9.(jpg|png) (Mapa Semántico Plano de 6 Colores / Clown Pass)

Salidas en la carpeta de assets del piloto:
  - <part>.png         : Texturas 2.4x supersampled desde Upscayl 4x (digital-art-4x),
                         extracción EDT (0px verdes residuales, borde #080812).
  - <part>_id_mask.png : Máscara RGBA de 4 canales (R=Acentos/Visor, G=Armadura,
                         B=Traje/Capa, A=Pelo en head / Medias en hips_legs, 0=Piel y Tinta).
  - reference_full.png : Calco Fantasma 9:16 a escala de rig.
  - auto_matches.json  : Posiciones y tamaños calibrados de las 8 capas del rig.
"""
import os
import sys
import glob
import json
import argparse
import subprocess
import tempfile
import numpy as np
import cv2
from PIL import Image, ImageFilter

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
LAB_DIR = os.path.join(REPO_ROOT, "sandbox", "pilot_rig_lab")
REFS_DIR = os.path.join(LAB_DIR, "source_refs")

UPSCAYL_BIN = r"C:\Program Files\Upscayl\resources\bin\upscayl-bin.exe"
UPSCAYL_MODELS = r"C:\Program Files\Upscayl\resources\models"

VALENTINA_RAW_COMPS = {
    "head":              (110, 31, 157, 167),
    "torso":             (112, 223, 154, 281),
    "hips_legs":         (382, 66, 265, 499),
    "arm_right_bent":    (693, 35, 155, 182),
    "arm_left_straight": (860, 33, 118, 265),
    "cape":              (706, 274, 224, 288),
}

VALENTINA_CLOWN_COMPS = {
    "head":              (110, 28,  161, 170),
    "torso":             (112, 222, 158, 286),
    "hips_legs":         (385, 64,  269, 507),
    "arm_right_bent":    (699, 32,  158, 186),
    "arm_left_straight": (868, 30,  120, 269),
    "cape":              (712, 274, 228, 294),
}

VALENTINA_CALIBRATED = {
    "head":              {"scale": 1.13, "rx": 197, "ry": 21,  "rot_deg": 0.0},
    "torso":             {"scale": 1.12, "sx": 1.16, "sy": 1.13, "rx": 210, "ry": 161, "rot_deg": 0.0},
    "hips_legs":         {"scale": 1.25, "rx": 119, "ry": 352, "rot_deg": 0.0},
    "arm_right_bent":    {"scale": 1.24, "rx": 108, "ry": 170, "rot_deg": 0.0},
    "arm_left_straight": {"scale": 1.25, "sx": 1.23, "sy": 1.32, "rx": 312, "ry": 184, "rot_deg": 0.0},
    "cape":              {"scale": 1.40, "rx": 48,  "ry": 210, "rot_deg": 8.0},
}

DEFAULT_SEARCH_WINDOWS = {
    "head":              (120, 460, 10,  310),
    "torso":             (120, 460, 150, 580),
    "hips_legs":         (90,  500, 310, 1015),
    "arm_right_bent":    (60,  380, 150, 520),
    "arm_left_straight": (250, 540, 150, 640),
    "cape":              (20,  480, 150, 820),
}


def resolve_ref_image(pilot_id: str, suffix: str) -> str:
    pattern = os.path.join(REFS_DIR, f"{pilot_id}_{suffix}.*")
    matches = sorted(glob.glob(pattern))
    if not matches:
        raise FileNotFoundError(f"No se encontró referencia '{pattern}'")
    return matches[0]


def detect_6_zone_components(img_bgr: np.ndarray, is_white_bg: bool = False) -> dict:
    """
    Detecta automáticamente los 6 componentes de la hoja 3-Zonas 16:9 por su posición espacial:
      - Columna izquierda (x < 0.34*W): arriba=head, abajo=torso
      - Columna central (0.34*W <= x <= 0.67*W): hips_legs (componente mayor)
      - Columna derecha (x > 0.67*W): arriba-izq=arm_right_bent, arriba-der=arm_left_straight, abajo=cape
    """
    ph, pw = img_bgr.shape[:2]
    if is_white_bg:
        fg = (img_bgr.min(axis=2) < 236).astype(np.uint8)
    else:
        hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
        bg = (hsv[:, :, 0] >= 35) & (hsv[:, :, 0] <= 85) & (hsv[:, :, 1] >= 60) & (hsv[:, :, 2] >= 60)
        fg = (~bg).astype(np.uint8)

    num, _, stats, centroids = cv2.connectedComponentsWithStats(fg)
    comps = []
    for i in range(1, num):
        x, y, w, h, area = stats[i]
        if area > 1200:
            comps.append((int(x), int(y), int(w), int(h), int(area), float(centroids[i][0]), float(centroids[i][1])))

    left = sorted([c for c in comps if c[5] < pw * 0.35], key=lambda c: c[6])
    mid = sorted([c for c in comps if pw * 0.35 <= c[5] <= pw * 0.67], key=lambda c: -c[4])
    right = [c for c in comps if c[5] > pw * 0.67]

    out = {}
    if len(left) >= 2:
        out["head"] = left[0][:4]
        out["torso"] = left[-1][:4]
    if mid:
        out["hips_legs"] = mid[0][:4]
    if len(right) >= 2:
        right_by_y = sorted(right, key=lambda c: -c[6])
        out["cape"] = right_by_y[0][:4]
        arms = sorted(right_by_y[1:], key=lambda c: c[5])
        if len(arms) >= 2:
            out["arm_right_bent"] = arms[0][:4]
            out["arm_left_straight"] = arms[-1][:4]
        elif len(arms) == 1:
            out["arm_right_bent"] = arms[0][:4]
            out["arm_left_straight"] = arms[0][:4]
    return out


def find_exact_transform_on_ref(ref_bgr: np.ndarray, part_bgr: np.ndarray, part_name: str) -> dict:
    rh, rw = ref_bgr.shape[:2]
    sx_w = rw / 571.0
    sy_h = rh / 1024.0
    bx0, bx1, by0, by1 = DEFAULT_SEARCH_WINDOWS[part_name]
    x0, x1 = max(0, int(bx0 * sx_w)), min(rw, int(bx1 * sx_w))
    y0, y1 = max(0, int(by0 * sy_h)), min(rh, int(by1 * sy_h))

    roi_bgr = ref_bgr[y0:y1, x0:x1].astype(np.float32)
    hsv_p = cv2.cvtColor(part_bgr, cv2.COLOR_BGR2HSV)
    part_fg = (~((hsv_p[:, :, 0] >= 35) & (hsv_p[:, :, 0] <= 85) & (hsv_p[:, :, 1] >= 65) & (hsv_p[:, :, 2] >= 65))).astype(np.float32)
    part_fg_eroded = cv2.erode(part_fg, np.ones((3, 3), np.uint8), iterations=1)

    ph, pw = part_bgr.shape[:2]
    best_loss = 1e9
    best_match = (1.15, x0, y0)
    for s in np.linspace(0.80, 1.45, 28):
        nw, nh = int(round(pw * s)), int(round(ph * s))
        if nw >= (x1 - x0) or nh >= (y1 - y0):
            continue
        rp_bgr = cv2.resize(part_bgr, (nw, nh), interpolation=cv2.INTER_AREA).astype(np.float32)
        rp_mask = cv2.resize(part_fg_eroded, (nw, nh), interpolation=cv2.INTER_NEAREST)
        if rp_mask.sum() < 100:
            continue
        res = np.nan_to_num(cv2.matchTemplate(roi_bgr, rp_bgr, cv2.TM_SQDIFF_NORMED, mask=rp_mask), nan=1e9, posinf=1e9, neginf=1e9)
        min_val, _, min_loc, _ = cv2.minMaxLoc(res)
        if min_val < best_loss:
            best_loss = min_val
            best_match = (float(s), int(x0 + min_loc[0]), int(y0 + min_loc[1]))
    return {"scale": best_match[0], "rx": best_match[1], "ry": best_match[2], "rot_deg": 0.0}


def smooth_antialiased_chroma_key(pil_img: Image.Image) -> Image.Image:
    rgba = np.array(pil_img.convert("RGBA"), dtype=np.float32)
    r, g, b = rgba[:, :, 0], rgba[:, :, 1], rgba[:, :, 2]

    max_rb = np.maximum(r, b)
    green_excess = g - max_rb
    green_ratio = g / (r + b + 1.0)

    is_bg_or_halo = (green_excess > 8.0) & (green_ratio > 0.62)
    fg_raw = (~is_bg_or_halo).astype(np.uint8)

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(fg_raw)
    clean_fg = np.zeros_like(fg_raw)
    if num_labels > 1:
        largest_idx = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        clean_fg[labels == largest_idx] = 1

    inv_fg = 1 - clean_fg
    n_bg, l_bg, s_bg, _ = cv2.connectedComponentsWithStats(inv_fg)
    for i in range(1, n_bg):
        if s_bg[i, cv2.CC_STAT_AREA] < 200:
            clean_fg[l_bg == i] = 1

    dist_inside = cv2.distanceTransform(clean_fg, cv2.DIST_L2, 5)
    dist_smooth = cv2.GaussianBlur(dist_inside, (5, 5), 1.1)
    final_alpha = np.clip((dist_smooth - 2.2) / 1.6, 0.0, 1.0)

    g_clean = np.minimum(g, max_rb)
    ink_rim_t = np.clip((dist_smooth - 2.0) / 5.5, 0.0, 1.0)
    r_clean = 8.0 * (1.0 - ink_rim_t) + r * ink_rim_t
    g_final = 8.0 * (1.0 - ink_rim_t) + g_clean * ink_rim_t
    b_clean = 18.0 * (1.0 - ink_rim_t) + b * ink_rim_t

    out = np.zeros_like(rgba, dtype=np.uint8)
    out[:, :, 0] = np.clip(r_clean, 0, 255).astype(np.uint8)
    out[:, :, 1] = np.clip(g_final, 0, 255).astype(np.uint8)
    out[:, :, 2] = np.clip(b_clean, 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(final_alpha * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(out, mode="RGBA")


def trim_lower_neck_on_head(head_rgba: Image.Image) -> Image.Image:
    arr = np.array(head_rgba, dtype=np.float32)
    h, _ = arr.shape[:2]
    yy, _ = np.mgrid[0:h, 0:arr.shape[1]]
    yn = yy / float(h)
    collar_fade = np.clip((0.91 - yn) / 0.09, 0.0, 1.0)
    arr[:, :, 3] = arr[:, :, 3] * collar_fade
    return Image.fromarray(arr.astype(np.uint8), mode="RGBA")


def align_clown_crop_to_part(part_rgba: np.ndarray, clown_bgr: np.ndarray) -> tuple:
    th, tw = part_rgba.shape[:2]
    c_min_raw = clown_bgr.min(axis=2)
    fg_raw = (c_min_raw < 238).astype(np.uint8)
    num_l, labels, stats, _ = cv2.connectedComponentsWithStats(fg_raw)
    if num_l > 1:
        largest_l = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        clown_bgr = clown_bgr.copy()
        clown_bgr[labels != largest_l] = (255, 255, 255)

    clown_resized = cv2.resize(clown_bgr, (tw, th), interpolation=cv2.INTER_LINEAR)
    part_fg = (part_rgba[:, :, 3] > 64).astype(np.float32)
    c_min = clown_resized.min(axis=2)
    clown_fg = (c_min < 235).astype(np.float32)

    best_dx, best_dy = 0, 0
    best_iou = -1.0
    for dy in range(-14, 15, 1):
        for dx in range(-14, 15, 1):
            M = np.float32([[1, 0, dx], [0, 1, dy]])
            shifted = cv2.warpAffine(clown_fg, M, (tw, th), flags=cv2.INTER_NEAREST)
            inter = (part_fg * shifted).sum()
            union = np.maximum(part_fg, shifted).sum() + 1e-5
            iou = inter / union
            if iou > best_iou:
                best_iou = iou
                best_dx, best_dy = dx, dy

    M_final = np.float32([[1, 0, best_dx], [0, 1, best_dy]])
    clown_aligned = cv2.warpAffine(
        clown_resized, M_final, (tw, th),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255)
    )
    return clown_aligned, (best_dx, best_dy), best_iou


def classify_clown_pixels(clown_bgr: np.ndarray, part_rgba: np.ndarray, part_name: str) -> Image.Image:
    cr = clown_bgr[:, :, 2].astype(np.float32) / 255.0
    cg = clown_bgr[:, :, 1].astype(np.float32) / 255.0
    cb = clown_bgr[:, :, 0].astype(np.float32) / 255.0

    or_r = part_rgba[:, :, 0].astype(np.float32) / 255.0
    or_g = part_rgba[:, :, 1].astype(np.float32) / 255.0
    or_b = part_rgba[:, :, 2].astype(np.float32) / 255.0
    or_a = part_rgba[:, :, 3].astype(np.float32) / 255.0
    orig_luma = 0.299 * or_r + 0.587 * or_g + 0.114 * or_b
    c_max = np.maximum(np.maximum(cr, cg), cb)

    is_yellow_skin = (cr > 0.62) & (cg > 0.62) & (cb < 0.40) & ((cr - cb) > 0.35)
    is_green_stocking = (cg > 0.52) & (cr < 0.44) & (cb < 0.44) & ((cg - np.maximum(cr, cb)) > 0.22)

    if part_name == "head":
        is_cyan_hair = (cb > 0.48) & (cg > 0.42) & (cr < 0.38) & ((cb - cr) > 0.25)
        is_blue_armor = np.zeros_like(is_cyan_hair)
    else:
        is_cyan_hair = np.zeros_like(is_yellow_skin)
        is_blue_armor = (cb > 0.48) & (cr < 0.38) & (cg < 0.62) & ((cb - cr) > 0.26)

    is_red_accent = (cr > 0.50) & (cg < 0.36) & (cb < 0.38) & ((cr - np.maximum(cg, cb)) > 0.24)
    is_bright_magenta = (cr > 0.48) & (cb > 0.48) & (cg < 0.42) & ((np.minimum(cr, cb) - cg) > 0.18)
    is_dark_plum_suit = (
        (c_max < 0.55) & (c_max > 0.11) &
        (~is_yellow_skin) & (~is_green_stocking) & (~is_cyan_hair) & (~is_red_accent) & (~is_blue_armor) &
        (orig_luma > 0.13)
    )
    is_suit = is_bright_magenta | is_dark_plum_suit

    if part_name == "cape":
        is_suit = (or_a > 0.1) & (orig_luma > 0.12)
        is_red_accent = np.zeros_like(is_suit)
        is_blue_armor = np.zeros_like(is_suit)

    k5 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    k7 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))

    skin_dil = cv2.dilate(is_yellow_skin.astype(np.float32), k7, iterations=1)
    stocking_dil = cv2.dilate(is_green_stocking.astype(np.float32), k5, iterations=1) * (1.0 - skin_dil)
    hair_dil = cv2.dilate(is_cyan_hair.astype(np.float32), k5, iterations=1) * (1.0 - skin_dil)
    red_dil = cv2.dilate(is_red_accent.astype(np.float32), k5, iterations=1) * (1.0 - skin_dil)
    blue_dil = cv2.dilate(is_blue_armor.astype(np.float32), k5, iterations=1) * (1.0 - skin_dil) * (1.0 - red_dil)
    suit_dil = cv2.dilate(is_suit.astype(np.float32), k5, iterations=1) * (1.0 - skin_dil) * (1.0 - red_dil) * (1.0 - blue_dil) * (1.0 - stocking_dil) * (1.0 - hair_dil)

    assigned = skin_dil + stocking_dil + hair_dil + red_dil + blue_dil + suit_dil
    unassigned_fg = np.clip(1.0 - assigned, 0.0, 1.0) * (or_a > 0.1).astype(np.float32) * (orig_luma > 0.14).astype(np.float32)
    if part_name == "head":
        h_img, _ = or_r.shape
        yy, _ = np.mgrid[0:h_img, 0:or_r.shape[1]]
        yn = yy / float(h_img)
        hair_dil = np.clip(hair_dil + unassigned_fg * (yn < 0.72).astype(np.float32), 0.0, 1.0)
        suit_dil = np.clip(suit_dil + unassigned_fg * (yn >= 0.72).astype(np.float32), 0.0, 1.0)
    elif part_name != "hips_legs":
        suit_dil = np.clip(suit_dil + unassigned_fg, 0.0, 1.0)

    ink_weight = np.clip((0.145 - orig_luma) / 0.055, 0.0, 1.0)
    valid_fg = (1.0 - ink_weight) * np.clip((or_a - 0.10) / 0.40, 0.0, 1.0) * (1.0 - skin_dil)

    w_red = red_dil * valid_fg
    w_panel = blue_dil * valid_fg
    w_suit = suit_dil * valid_fg
    if part_name == "head":
        w_alpha = hair_dil * valid_fg
    elif part_name == "hips_legs":
        w_alpha = stocking_dil * valid_fg
    else:
        w_alpha = np.zeros_like(w_red)

    hard_lock = (1.0 - (skin_dil > 0.2).astype(np.float32)) * (1.0 - ink_weight * 0.90) * (or_a > 0.05).astype(np.float32)

    def smooth_ch(ch: np.ndarray) -> np.ndarray:
        im = Image.fromarray((ch * 255.0).clip(0, 255).astype(np.uint8), mode="L")
        sm = np.array(im.filter(ImageFilter.GaussianBlur(radius=0.95)), dtype=np.float32) / 255.0
        return np.clip(sm * hard_lock * 255.0, 0, 255).astype(np.uint8)

    mask_rgba = np.zeros_like(part_rgba, dtype=np.uint8)
    mask_rgba[:, :, 0] = smooth_ch(w_red)
    mask_rgba[:, :, 1] = smooth_ch(w_panel)
    mask_rgba[:, :, 2] = smooth_ch(w_suit)
    mask_rgba[:, :, 3] = smooth_ch(w_alpha)
    return Image.fromarray(mask_rgba, mode="RGBA")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Astra Dream 2D rigged pilot assets & Clown-Pass ID masks.")
    parser.add_argument("--pilot", default="valentina", help="ID del piloto (ej: valentina, kaelen, nyx)")
    args = parser.parse_args()

    pilot_id = args.pilot.strip().lower()
    if pilot_id == "valentina":
        out_dir = os.path.join(LAB_DIR, "assets")
        raw_comps = VALENTINA_RAW_COMPS
        clown_comps = VALENTINA_CLOWN_COMPS
        calibrated = VALENTINA_CALIBRATED
    else:
        out_dir = os.path.join(LAB_DIR, "pilots", pilot_id)
        raw_comps = None
        clown_comps = None
        calibrated = None

    os.makedirs(out_dir, exist_ok=True)
    master_ref_path = resolve_ref_image(pilot_id, "step1_master_9x16")
    parts_sheet_path = resolve_ref_image(pilot_id, "step2_parts_16x9")
    clown_pass_path = resolve_ref_image(pilot_id, "step3_clown_pass_16x9")

    ref_bgr = cv2.imread(master_ref_path)
    sheet_bgr = cv2.imread(parts_sheet_path)
    clown_sheet_bgr = cv2.imread(clown_pass_path)
    ref_h, ref_w = ref_bgr.shape[:2]
    ph_sheet, pw_sheet = sheet_bgr.shape[:2]
    ph_clown, pw_clown = clown_sheet_bgr.shape[:2]

    if raw_comps is None:
        raw_comps = detect_6_zone_components(sheet_bgr, is_white_bg=False)
    if clown_comps is None:
        clown_comps = detect_6_zone_components(clown_sheet_bgr, is_white_bg=True)

    PAD = 12
    DISPLAY_SCALE = 552.0 / float(ref_h)
    TEX_SUPERSAMPLE = 2.4

    with tempfile.TemporaryDirectory() as tmp_dir:
        crops_in = os.path.join(tmp_dir, "crops_in")
        crops_up = os.path.join(tmp_dir, "crops_up")
        os.makedirs(crops_in, exist_ok=True)
        os.makedirs(crops_up, exist_ok=True)

        if calibrated is None:
            calibrated = {}
            for name, (x, y, w, h) in raw_comps.items():
                x0, y0 = max(0, x - PAD), max(0, y - PAD)
                x1, y1 = min(pw_sheet, x + w + PAD), min(ph_sheet, y + h + PAD)
                calibrated[name] = find_exact_transform_on_ref(ref_bgr, sheet_bgr[y0:y1, x0:x1], name)

        for name, (x, y, w, h) in raw_comps.items():
            x0, y0 = max(0, x - PAD), max(0, y - PAD)
            x1, y1 = min(pw_sheet, x + w + PAD), min(ph_sheet, y + h + PAD)
            cv2.imwrite(os.path.join(crops_in, f"{name}.png"), sheet_bgr[y0:y1, x0:x1])
        cv2.imwrite(os.path.join(crops_in, "full_reference.png"), ref_bgr)

        subprocess.run([
            UPSCAYL_BIN, "-i", crops_in, "-o", crops_up,
            "-m", UPSCAYL_MODELS, "-n", "digital-art-4x", "-s", "4", "-f", "png"
        ], check=True)

        up_ref_pil = Image.open(os.path.join(crops_up, "full_reference.png"))
        ref_clean_4x = smooth_antialiased_chroma_key(up_ref_pil)
        ref_disp_w = int(round(ref_w * DISPLAY_SCALE))
        ref_disp_h = int(round(ref_h * DISPLAY_SCALE))
        ref_disp_img = ref_clean_4x.resize((ref_disp_w, ref_disp_h), Image.Resampling.LANCZOS)
        ref_disp_img.save(os.path.join(out_dir, "reference_full.png"))
        ref_disp_img.save(os.path.join(out_dir, "full_reference.png"))

        auto_matches = {}
        for name, (x, y, w, h) in raw_comps.items():
            x0, y0 = max(0, x - PAD), max(0, y - PAD)
            x1, y1 = min(pw_sheet, x + w + PAD), min(ph_sheet, y + h + PAD)
            cw, ch = x1 - x0, y1 - y0
            cal = calibrated[name]
            s_ref = cal["scale"]
            sx_ref = cal.get("sx", s_ref)
            sy_ref = cal.get("sy", s_ref)

            up_part_pil = Image.open(os.path.join(crops_up, f"{name}.png"))
            part_clean_4x = smooth_antialiased_chroma_key(up_part_pil)
            if abs(cal["rot_deg"]) > 0.1:
                part_clean_4x = part_clean_4x.rotate(cal["rot_deg"], resample=Image.Resampling.BICUBIC, expand=False)
            if name == "head":
                part_clean_4x = trim_lower_neck_on_head(part_clean_4x)

            disp_w = int(round(cw * sx_ref * DISPLAY_SCALE))
            disp_h = int(round(ch * sy_ref * DISPLAY_SCALE))
            tex_w = int(round(disp_w * TEX_SUPERSAMPLE))
            tex_h = int(round(disp_h * TEX_SUPERSAMPLE))

            part_final = part_clean_4x.resize((tex_w, tex_h), Image.Resampling.LANCZOS)
            r_c, g_c, b_c, a_c = part_final.split()
            rgb_sharp = Image.merge("RGB", (r_c, g_c, b_c)).filter(
                ImageFilter.UnsharpMask(radius=1.0, percent=40, threshold=3)
            )
            arr_f = np.array(rgb_sharp, dtype=np.float32)
            arr_a = np.array(a_c, dtype=np.float32) / 255.0

            fg_bin = (arr_a > 0.05).astype(np.uint8)
            dist_post = cv2.distanceTransform(fg_bin, cv2.DIST_L2, 5)
            rim_t = np.clip((dist_post - 1.0) / 2.8, 0.0, 1.0)[..., None]
            ink_rgb = np.array([8.0, 8.0, 18.0], dtype=np.float32).reshape(1, 1, 3)
            arr_f = ink_rgb * (1.0 - rim_t) + arr_f * rim_t
            arr_f[:, :, 1] = np.minimum(arr_f[:, :, 1], np.maximum(arr_f[:, :, 0], arr_f[:, :, 2]))

            out_rgba = np.zeros((tex_h, tex_w, 4), dtype=np.uint8)
            out_rgba[:, :, :3] = np.clip(arr_f, 0, 255).astype(np.uint8)
            out_rgba[:, :, 3] = np.clip(arr_a * 255.0, 0, 255).astype(np.uint8)
            part_final = Image.fromarray(out_rgba, mode="RGBA")
            part_final.save(os.path.join(out_dir, f"{name}.png"))

            cx, cy, cw_c, ch_c = clown_comps[name]
            cx0, cy0 = max(0, cx - PAD), max(0, cy - PAD)
            cx1, cy1 = min(pw_clown, cx + cw_c + PAD), min(ph_clown, cy + ch_c + PAD)
            clown_crop = clown_sheet_bgr[cy0:cy1, cx0:cx1]
            if abs(cal["rot_deg"]) > 0.1:
                c_pil = Image.fromarray(cv2.cvtColor(clown_crop, cv2.COLOR_BGR2RGB))
                c_pil = c_pil.rotate(cal["rot_deg"], resample=Image.Resampling.BILINEAR, expand=False, fillcolor=(255, 255, 255))
                clown_crop = cv2.cvtColor(np.array(c_pil), cv2.COLOR_RGB2BGR)

            clown_aligned, _, iou = align_clown_crop_to_part(out_rgba, clown_crop)
            id_mask = classify_clown_pixels(clown_aligned, out_rgba, name)
            id_mask.save(os.path.join(out_dir, f"{name}_id_mask.png"))
            print(f"[{pilot_id} | {name:17s}] IoU={iou:.3f} -> {name}.png & {name}_id_mask.png")

            disp_x = int(round(cal["rx"] * DISPLAY_SCALE))
            disp_y = int(round(cal["ry"] * DISPLAY_SCALE))
            auto_matches[name] = [0.99, disp_x, disp_y, disp_w, disp_h]

        empty_img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for unused in ["bust", "wings"]:
            empty_img.save(os.path.join(out_dir, f"{unused}.png"))
            empty_img.save(os.path.join(out_dir, f"{unused}_id_mask.png"))
            auto_matches[unused] = [1.0, 0, 0, 4, 4]

        with open(os.path.join(out_dir, "auto_matches.json"), "w", encoding="utf-8") as f:
            json.dump(auto_matches, f, indent=2)
        print(f"Pipeline multi-piloto '{pilot_id}' finalizado en: {out_dir}")


if __name__ == "__main__":
    main()
