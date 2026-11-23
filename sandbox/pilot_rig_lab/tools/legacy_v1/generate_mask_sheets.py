"""
Astra Dream — Generador e Importador de Hojas Agrupadas de Máscaras (Cabezas + Cuerpos)
Ubicación: sandbox/pilot_rig_lab/tools/generate_mask_sheets.py

Uso:
  1. Exportar las 2 hojas de referencia para enviar a la IA:
     python sandbox/pilot_rig_lab/tools/generate_mask_sheets.py --export
  2. Importar las hojas pintadas por la IA y hornear las máscaras finales:
     python sandbox/pilot_rig_lab/tools/generate_mask_sheets.py --import-heads <ruta_heads_mask.png>
     python sandbox/pilot_rig_lab/tools/generate_mask_sheets.py --import-bodies <ruta_bodies_mask.png>
"""
import argparse
import json
import os
from typing import Dict, List, Tuple

import cv2
import numpy as np
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS_DIR = os.path.join(BASE_DIR, "combat_assets", "valentina_planar")
SHEETS_OUT_DIR = os.path.join(BASE_DIR, "source_refs", "mask_sheets")

HEAD_ORDER: List[str] = [
    "head_front",
    "head_side_l",
    "head_side_r",
    "head_back",
    "head_back_l",
    "head_back_r",
]


def _composite_rgba_on_gray(rgba: Image.Image, target_w: int, target_h: int) -> Image.Image:
    bg = Image.new("RGBA", (target_w, target_h), (128, 128, 128, 255))
    bg.alpha_composite(rgba)
    return bg


def export_sheets() -> None:
    os.makedirs(SHEETS_OUT_DIR, exist_ok=True)
    layout: Dict = {"heads": {}, "bodies": {}}

    # 1. Hoja de Cabezas (3x2 = 1536 x 1024)
    cell_w, cell_h = 512, 512
    heads_canvas = Image.new("RGBA", (cell_w * 3, cell_h * 2), (128, 128, 128, 255))
    heads_dir = os.path.join(ASSETS_DIR, "heads")

    for idx, hname in enumerate(HEAD_ORDER):
        path = os.path.join(heads_dir, f"{hname}.png")
        if not os.path.isfile(path):
            continue
        im = Image.open(path).convert("RGBA")
        scale = min((cell_w - 64) / im.width, (cell_h - 64) / im.height)
        nw, nh = max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale)))
        im_res = im.resize((nw, nh), Image.Resampling.LANCZOS)
        col = idx % 3
        row = idx // 3
        ox = col * cell_w + (cell_w - nw) // 2
        oy = row * cell_h + (cell_h - nh) // 2
        heads_canvas.alpha_composite(im_res, (ox, oy))
        layout["heads"][hname] = {
            "box": [ox, oy, nw, nh],
            "orig_size": [im.width, im.height],
        }

    heads_out = os.path.join(SHEETS_OUT_DIR, "mask_sheet_heads_ref.png")
    heads_canvas.convert("RGB").save(heads_out)

    # 2. Hoja de Cuerpos S y N (2x1 = 1536 x 1024)
    half_w, full_h = 768, 1024
    bodies_canvas = Image.new("RGBA", (half_w * 2, full_h), (128, 128, 128, 255))

    for v_idx, vkey in enumerate(["s", "n"]):
        vdir = os.path.join(ASSETS_DIR, vkey)
        with open(os.path.join(vdir, "auto_matches.json"), "r", encoding="utf-8") as f:
            matches = json.load(f)
        with open(os.path.join(vdir, "rig_skeleton_config.json"), "r", encoding="utf-8") as f:
            skel_cfg = json.load(f)

        z_orders = skel_cfg.get("z_orders", {})
        parts = ["hips_legs", "torso", "arm_r", "arm_l"]
        parts.sort(key=lambda p: int(z_orders.get(p, 0)))

        # Calcular bounds del cuerpo completo en coords rig (px base 550)
        min_x, min_y = 1e9, 1e9
        max_x, max_y = -1e9, -1e9
        for p in parts:
            if p not in matches:
                continue
            _, px, py, pw, ph = matches[p]
            min_x = min(min_x, px)
            min_y = min(min_y, py)
            max_x = max(max_x, px + pw)
            max_y = max(max_y, py + ph)

        bw = max(1.0, max_x - min_x)
        bh = max(1.0, max_y - min_y)
        scale = min((half_w - 80) / bw, (full_h - 80) / bh)
        base_ox = v_idx * half_w + (half_w - bw * scale) * 0.5
        base_oy = (full_h - bh * scale) * 0.5

        layout["bodies"][vkey] = {"parts": {}}
        for p in parts:
            p_path = os.path.join(vdir, f"{p}.png")
            if not os.path.isfile(p_path) or p not in matches:
                continue
            _, px, py, pw, ph = matches[p]
            pim = Image.open(p_path).convert("RGBA")
            dx = int(round(base_ox + (px - min_x) * scale))
            dy = int(round(base_oy + (py - min_y) * scale))
            dw = max(1, int(round(pw * scale)))
            dh = max(1, int(round(ph * scale)))
            pim_res = pim.resize((dw, dh), Image.Resampling.LANCZOS)
            bodies_canvas.alpha_composite(pim_res, (dx, dy))
            layout["bodies"][vkey]["parts"][p] = {
                "box": [dx, dy, dw, dh],
                "orig_size": [pim.width, pim.height],
            }

    bodies_out = os.path.join(SHEETS_OUT_DIR, "mask_sheet_bodies_ref.png")
    bodies_canvas.convert("RGB").save(bodies_out)

    layout_path = os.path.join(SHEETS_OUT_DIR, "mask_sheet_layout.json")
    with open(layout_path, "w", encoding="utf-8") as f:
        json.dump(layout, f, indent=2)

    print(f"[OK] Hojas exportadas:\n  - {heads_out}\n  - {bodies_out}")


def _snap_to_palette(crop_rgb: np.ndarray, palette_rgb: np.ndarray) -> np.ndarray:
    """Asigna cada píxel al índice más cercano de la paleta RGB (distancia euclidiana)."""
    flat = crop_rgb.reshape(-1, 3).astype(np.float32)
    dists = np.linalg.norm(flat[:, None, :] - palette_rgb[None, :, :], axis=2)
    return np.argmin(dists, axis=1).reshape(crop_rgb.shape[:2])


def _fill_unlabeled_in_alpha(cls_map: np.ndarray, alpha: np.ndarray, valid_classes: Tuple[int, ...]) -> np.ndarray:
    """Rellena píxeles dentro de `alpha` que cayeron en fondo/otra clase usando el píxel válido más cercano."""
    valid_mask = np.isin(cls_map, valid_classes) & alpha
    if not np.any(valid_mask):
        return cls_map
    invalid_in_alpha = alpha & (~valid_mask)
    if not np.any(invalid_in_alpha):
        return cls_map
    # distanceTransformWithLabels asigna a cada píxel 0 el índice del píxel != 0 más cercano
    # Para ello pasamos 0 en válidos y 255 en inválidos
    src = np.where(valid_mask, 0, 255).astype(np.uint8)
    _, labels = cv2.distanceTransformWithLabels(src, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    vy, vx = np.where(valid_mask)
    # labels es 1-indexado sobre los píxeles cero en orden row-major
    flat_cls = cls_map[vy, vx]
    out = cls_map.copy()
    iy, ix = np.where(invalid_in_alpha)
    lbl_idx = np.clip(labels[iy, ix] - 1, 0, len(flat_cls) - 1)
    out[iy, ix] = flat_cls[lbl_idx]
    return out


def import_heads(mask_img_path: str) -> None:
    with open(os.path.join(SHEETS_OUT_DIR, "mask_sheet_layout.json"), "r", encoding="utf-8") as f:
        layout = json.load(f)

    sheet = cv2.imread(mask_img_path)
    if sheet is None:
        raise FileNotFoundError(mask_img_path)
    sheet_rgb = cv2.cvtColor(sheet, cv2.COLOR_BGR2RGB)
    # Redimensionar si la IA devolvió otra resolución manteniendo 3:2
    if sheet_rgb.shape[1] != 1536 or sheet_rgb.shape[0] != 1024:
        sheet_rgb = cv2.resize(sheet_rgb, (1536, 1024), interpolation=cv2.INTER_LINEAR)

    # Paleta: 0=Blue(Hair), 1=Green(Face/Skin), 2=Red(Neck/Collar), 3=Yellow(Visor/Accent), 4=Gray(Bg)
    palette = np.array([
        [0, 0, 255],
        [0, 255, 0],
        [255, 0, 0],
        [255, 255, 0],
        [128, 128, 128],
    ], dtype=np.float32)

    heads_dir = os.path.join(ASSETS_DIR, "heads")
    for hname, info in layout["heads"].items():
        ox, oy, nw, nh = info["box"]
        ow, oh = info["orig_size"]
        crop = sheet_rgb[oy:oy + nh, ox:ox + nw]
        crop_orig = cv2.resize(crop, (ow, oh), interpolation=cv2.INTER_NEAREST)

        fg_img = cv2.imread(os.path.join(heads_dir, f"{hname}.png"), cv2.IMREAD_UNCHANGED)
        alpha = fg_img[:, :, 3] > 60
        cls_map = _snap_to_palette(crop_orig, palette)
        cls_map = _fill_unlabeled_in_alpha(cls_map, alpha, (0, 1, 2, 3))

        # Actualizar id_mask.png preservando estructura compatible con pilot_rig_stylizer.gdshader
        id_path = os.path.join(heads_dir, f"{hname}_id_mask.png")
        id_bgra = cv2.imread(id_path, cv2.IMREAD_UNCHANGED)
        # Canales OpenCV BGRA: 0=B(suit), 1=G(armor), 2=R(accent), 3=A(hair)
        hair_m = ((cls_map == 0) & alpha).astype(np.uint8) * 255
        skin_m = (cls_map == 1) & alpha
        neck_m = (cls_map == 2) & alpha
        visor_m = (cls_map == 3) & alpha

        # Suavizado ligero en bordes de cabello
        hair_blur = cv2.GaussianBlur(hair_m, (3, 3), 0.7)
        id_bgra[:, :, 3] = np.where(alpha, hair_blur, 0)
        # Piel limpia (0 en R/G/B)
        id_bgra[skin_m, 0] = 0
        id_bgra[skin_m, 1] = 0
        id_bgra[skin_m, 2] = 0
        # Visor rojo en canal R (255)
        id_bgra[visor_m, 2] = 255
        id_bgra[visor_m, 0] = 0
        id_bgra[visor_m, 1] = 0
        # Cuello/collar oscuro en canal B (si no tenía ya panel G)
        neck_empty = neck_m & (id_bgra[:, :, 1] < 40) & (id_bgra[:, :, 2] < 40)
        id_bgra[neck_empty, 0] = 255

        cv2.imwrite(id_path, id_bgra)
        print(f"[OK] Máscara cabeza actualizada: {hname}_id_mask.png")


def import_bodies(mask_img_path: str) -> None:
    with open(os.path.join(SHEETS_OUT_DIR, "mask_sheet_layout.json"), "r", encoding="utf-8") as f:
        layout = json.load(f)

    sheet = cv2.imread(mask_img_path)
    if sheet is None:
        raise FileNotFoundError(mask_img_path)
    sheet_rgb = cv2.cvtColor(sheet, cv2.COLOR_BGR2RGB)
    if sheet_rgb.shape[1] != 1536 or sheet_rgb.shape[0] != 1024:
        sheet_rgb = cv2.resize(sheet_rgb, (1536, 1024), interpolation=cv2.INTER_LINEAR)

    # Paleta: 0=Red(RightLeg), 1=Blue(LeftLeg), 2=Green(Pelvis/Torso), 3=Yellow(Arms), 4=Gray(Bg)
    palette = np.array([
        [255, 0, 0],
        [0, 0, 255],
        [0, 255, 0],
        [255, 255, 0],
        [128, 128, 128],
    ], dtype=np.float32)

    for vkey, vinfo in layout["bodies"].items():
        if "hips_legs" not in vinfo["parts"]:
            continue
        pinfo = vinfo["parts"]["hips_legs"]
        ox, oy, nw, nh = pinfo["box"]
        ow, oh = pinfo["orig_size"]
        crop = sheet_rgb[oy:oy + nh, ox:ox + nw]
        crop_orig = cv2.resize(crop, (ow, oh), interpolation=cv2.INTER_NEAREST)
        cls_map = _snap_to_palette(crop_orig, palette)

        vdir = os.path.join(ASSETS_DIR, vkey)
        fg_img = cv2.imread(os.path.join(vdir, "hips_legs.png"), cv2.IMREAD_UNCHANGED)
        alpha = fg_img[:, :, 3] > 40
        cls_map = _fill_unlabeled_in_alpha(cls_map, alpha, (0, 1, 2))

        # Hornear hips_legs_anim_mask.png: R=RightLeg(hueso Thigh_R), G=Pelvis, B=LeftLeg(hueso Thigh_L)
        # En vista trasera (n), la pierna anatómica derecha está a la derecha de pantalla, pero rig_skeleton_config.json nombra Thigh_R a la izquierda de pantalla -> intercambiar R/B en n.
        r_raw = ((cls_map == 0) & alpha).astype(np.float32) * 255.0
        b_raw = ((cls_map == 1) & alpha).astype(np.float32) * 255.0
        if vkey == "n":
            r_raw, b_raw = b_raw, r_raw
        # R y B usan blur moderado (15x15) para separación limpia sin cruce; G (Pelvis) usa blur amplio (55x55) para transición suave de cadera
        r_ch = cv2.GaussianBlur(r_raw, (15, 15), 4.0)
        b_ch = cv2.GaussianBlur(b_raw, (15, 15), 4.0)
        g_ch = cv2.GaussianBlur(((cls_map == 2) & alpha).astype(np.float32) * 255.0, (55, 55), 16.0)
        anim_rgb = np.stack([b_ch, g_ch, r_ch], axis=-1)
        anim_rgb[~alpha] = 0.0
        out_path = os.path.join(vdir, "hips_legs_anim_mask.png")
        cv2.imwrite(out_path, np.clip(anim_rgb, 0, 255).astype(np.uint8))
        print(f"[OK] Máscara animación piernas horneada: {vkey}/hips_legs_anim_mask.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", action="store_true")
    parser.add_argument("--import-heads", default="")
    parser.add_argument("--import-bodies", default="")
    args = parser.parse_args()

    if args.export:
        export_sheets()
    if args.import_heads:
        import_heads(args.import_heads)
    if args.import_bodies:
        import_bodies(args.import_bodies)


if __name__ == "__main__":
    main()
