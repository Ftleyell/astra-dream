#!/usr/bin/env python3
"""Herramienta CLI para empaquetar retratos de a 3 en trípticos 16:9 (1920x1080)
y desempaquetar / alinear / sanitizar las Motion Masks generadas por AI.

Uso:
  python motion_mask_triptych_tool.py pack --pilot-id valentina_v2
  python motion_mask_triptych_tool.py unpack --pilot-id valentina_v2
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from build_pilot_dialogue_portraits import _render_audit_sheet  # noqa: E402

PILOT_RIG_LAB_DIR = TOOLS_DIR.parent
REPO_ROOT = PILOT_RIG_LAB_DIR.parent.parent

CANVAS_W = 1920
CANVAS_H = 1080
CROP_X0 = 152
CROP_X1 = 872  # 720px ancho (contiene el 100% de los bboxes 176..848)
CROP_W = CROP_X1 - CROP_X0  # 720
CROP_H = 1024

SLOT_W = 620
SLOT_H = 882  # Escala uniforme 720x1024 -> 620x882
SLOT_XS = (10, 650, 1290)
SLOT_Y0 = 99
DIVIDER_XS = (640, 1280)
DIVIDER_COLOR = (56, 56, 56)


def _paths_for(pilot_id: str) -> dict[str, Path]:
    src_root = PILOT_RIG_LAB_DIR / "source_refs" / f"{pilot_id}_dialogue"
    ai_root = src_root / "04_motion_masks_ai"
    return {
        "source_root": src_root,
        "assets_dir": REPO_ROOT / "assets" / "pilots" / pilot_id / "dialogue",
        "audit_sheet": src_root / "audit_dialogue_sheet.png",
        "ai_root": ai_root,
        "inputs_dir": ai_root / "triptych_inputs",
        "outputs_dir": ai_root / "triptych_outputs",
        "extracted_dir": ai_root / "extracted",
        "manifest": ai_root / "triptych_inputs" / "triptych_manifest.json",
        "overlay_audit": ai_root / "audit_motion_overlay.png",
    }


def _load_manifest(assets_dir: Path, pilot_id: str) -> dict:
    mf_path = assets_dir / f"{pilot_id}_dialogue_manifest.json"
    if not mf_path.is_file():
        raise FileNotFoundError(f"No se encontró el manifiesto compilado: {mf_path}")
    return json.loads(mf_path.read_text(encoding="utf-8"))


def _composite_over_black(rgba: np.ndarray) -> np.ndarray:
    alpha = rgba[:, :, 3:4].astype(np.float32) / 255.0
    rgb = rgba[:, :, :3].astype(np.float32)
    return np.clip(rgb * alpha, 0, 255).astype(np.uint8)


def _build_triptych_groups(emotions: list[str]) -> list[list[dict]]:
    groups: list[list[dict]] = []
    anchors = [em for em in ("neutral", "warm", "thinking") if em in emotions]
    if not anchors:
        anchors = emotions[:2]

    for start in range(0, len(emotions), 3):
        chunk = emotions[start : start + 3]
        slots: list[dict] = []
        for idx, em in enumerate(chunk):
            slots.append({"slot": idx, "emotion": em, "extract": True})
        anchor_i = 0
        while len(slots) < 3:
            candidate = anchors[anchor_i % len(anchors)]
            if candidate in [s["emotion"] for s in slots] and len(emotions) >= 3:
                for fallback_em in emotions:
                    if fallback_em not in [s["emotion"] for s in slots]:
                        candidate = fallback_em
                        break
            slots.append({"slot": len(slots), "emotion": candidate, "extract": False})
            anchor_i += 1
        groups.append(slots)
    return groups


def cmd_pack(pilot_id: str) -> int:
    paths = _paths_for(pilot_id)
    assets_dir = paths["assets_dir"]
    dlg_mf = _load_manifest(assets_dir, pilot_id)
    entries_by_em = {str(e["emotion"]): e for e in dlg_mf.get("entries", [])}
    emotions = [str(em) for em in dlg_mf.get("emotions", []) if str(em) in entries_by_em]
    if not emotions:
        print(f"[ERROR] Sin emociones válidas en {assets_dir}")
        return 1

    paths["inputs_dir"].mkdir(parents=True, exist_ok=True)
    paths["outputs_dir"].mkdir(parents=True, exist_ok=True)
    paths["extracted_dir"].mkdir(parents=True, exist_ok=True)

    groups = _build_triptych_groups(emotions)
    triptych_records: list[dict] = []

    for g_idx, slots in enumerate(groups, start=1):
        canvas = np.zeros((CANVAS_H, CANVAS_W, 3), dtype=np.uint8)
        for div_x in DIVIDER_XS:
            canvas[:, div_x - 1 : div_x + 1] = DIVIDER_COLOR

        for s in slots:
            em = s["emotion"]
            albedo_path = assets_dir / entries_by_em[em]["albedo"]
            rgba = np.array(Image.open(albedo_path).convert("RGBA"), dtype=np.uint8)
            rgb_black = _composite_over_black(rgba)
            cropped = rgb_black[:, CROP_X0:CROP_X1]
            resized = cv2.resize(cropped, (SLOT_W, SLOT_H), interpolation=cv2.INTER_AREA)
            x0 = SLOT_XS[s["slot"]]
            canvas[SLOT_Y0 : SLOT_Y0 + SLOT_H, x0 : x0 + SLOT_W] = resized

        in_name = f"triptych_{g_idx:02d}.png"
        out_expected = f"triptych_{g_idx:02d}_motion_mask.png"
        out_img_path = paths["inputs_dir"] / in_name
        Image.fromarray(canvas, mode="RGB").save(out_img_path)
        triptych_records.append({
            "index": g_idx,
            "input_file": in_name,
            "output_file": out_expected,
            "slots": slots,
        })
        slot_desc = ", ".join([f"{s['emotion']}{'*' if s['extract'] else '(ref)'}" for s in slots])
        print(f"[PACK] {in_name} -> {slot_desc}")

    manifest = {
        "pilot_id": pilot_id,
        "canvas": [CANVAS_W, CANVAS_H],
        "crop_x": [CROP_X0, CROP_X1],
        "slot_size": [SLOT_W, SLOT_H],
        "slot_xs": list(SLOT_XS),
        "slot_y0": SLOT_Y0,
        "triptychs": triptych_records,
    }
    paths["manifest"].write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"[OK] Empaquetado listo en {paths['inputs_dir']}")
    return 0


def _shift_image(img: np.ndarray, dx: int, dy: int) -> np.ndarray:
    m = np.float32([[1.0, 0.0, float(dx)], [0.0, 1.0, float(dy)]])
    return cv2.warpAffine(img, m, (img.shape[1], img.shape[0]), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def _slice_overlap_score(
    rgb: np.ndarray,
    sil_f: np.ndarray,
    bg_f: np.ndarray,
    hair_f: np.ndarray,
    torso_f: np.ndarray,
    eye_f: np.ndarray,
    dx: int,
    dy: int,
) -> float:
    h, w = sil_f.shape
    sx0, sx1 = max(0, -dx), min(w, w - dx)
    sy0, sy1 = max(0, -dy), min(h, h - dy)
    tx0, tx1 = max(0, dx), min(w, w + dx)
    ty0, ty1 = max(0, dy), min(h, h + dy)
    if sx1 <= sx0 or sy1 <= sy0:
        return -1e9
    s = rgb[sy0:sy1, sx0:sx1]
    s_any = np.max(s, axis=2)
    fg_hit = float(np.sum(s_any * sil_f[ty0:ty1, tx0:tx1]))
    bg_pen = float(np.sum(s_any * bg_f[ty0:ty1, tx0:tx1])) * 1.45
    hair_hit = float(np.sum(s[:, :, 1] * hair_f[ty0:ty1, tx0:tx1])) * 1.35
    torso_hit = float(np.sum(s[:, :, 0] * torso_f[ty0:ty1, tx0:tx1])) * 1.10
    eye_hit = float(np.sum(s[:, :, 2] * eye_f[ty0:ty1, tx0:tx1])) * 1.60
    return fg_hit + hair_hit + torso_hit + eye_hit - bg_pen


def _align_to_silhouette(
    raw_rgb_f: np.ndarray,
    in_sil: np.ndarray,
    hair_core: np.ndarray,
    torso_core: np.ndarray,
    eye_band: np.ndarray,
) -> tuple[np.ndarray, tuple[int, int], float]:
    """Busca (dx, dy) en +-28px con pirámide 256px + refinamiento 1px a 1024px."""
    if not np.any(raw_rgb_f > 0.05):
        return raw_rgb_f, (0, 0), 0.0
    bg_f = (~in_sil).astype(np.float32)
    sil_f = in_sil.astype(np.float32)
    hair_f = hair_core.astype(np.float32)
    torso_f = torso_core.astype(np.float32)
    eye_f = eye_band.astype(np.float32)

    # Búsqueda gruesa a 256x256 (1px = 4px en 1024)
    c_sz = (256, 256)
    c_rgb = cv2.resize(raw_rgb_f, c_sz, interpolation=cv2.INTER_AREA)
    c_sil = cv2.resize(sil_f, c_sz, interpolation=cv2.INTER_AREA)
    c_bg = cv2.resize(bg_f, c_sz, interpolation=cv2.INTER_AREA)
    c_hair = cv2.resize(hair_f, c_sz, interpolation=cv2.INTER_AREA)
    c_torso = cv2.resize(torso_f, c_sz, interpolation=cv2.INTER_AREA)
    c_eye = cv2.resize(eye_f, c_sz, interpolation=cv2.INTER_AREA)

    best_c_sc = -1e12
    cdx, cdy = 0, 0
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            sc = _slice_overlap_score(c_rgb, c_sil, c_bg, c_hair, c_torso, c_eye, dx, dy)
            if sc > best_c_sc:
                best_c_sc = sc
                cdx, cdy = dx, dy

    # Refinamiento exacto 1px en 1024x1024 alrededor del óptimo grueso
    cx0, cy0 = cdx * 4, cdy * 4
    best_score = -1e12
    best_dx, best_dy = cx0, cy0
    for dy in range(cy0 - 4, cy0 + 5):
        for dx in range(cx0 - 4, cx0 + 5):
            if abs(dx) > 28 or abs(dy) > 28:
                continue
            sc = _slice_overlap_score(raw_rgb_f, sil_f, bg_f, hair_f, torso_f, eye_f, dx, dy)
            if sc > best_score:
                best_score = sc
                best_dx, best_dy = dx, dy

    return _shift_image(raw_rgb_f, best_dx, best_dy), (best_dx, best_dy), best_score


def _sanitize_motion_channels(
    aligned_rgb_f: np.ndarray,
    rgba: np.ndarray,
    id_mask: np.ndarray,
    ilm_map: np.ndarray,
    bbox: list[int],
) -> np.ndarray:
    h, w = rgba.shape[:2]
    alpha = rgba[:, :, 3]
    in_sil = alpha > 48
    in_sil_soft = alpha > 20
    bx, by, bw, bh = bbox

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    y_norm = yy / float(h)
    x_norm = xx / float(w)
    face_cx = (bx + bw * 0.50) / float(w)
    face_cy = (by + bh * 0.225) / float(h)

    ai_r = aligned_rgb_f[:, :, 0]
    ai_g = aligned_rgb_f[:, :, 1]
    ai_b = aligned_rgb_f[:, :, 2]

    hair_mask = ilm_map[:, :, 2].astype(np.float32) / 255.0
    crimson_mask = id_mask[:, :, 0].astype(np.float32) / 255.0

    # --- Canal R: Respiración en pecho superior ---
    r_pure = np.clip(ai_r - 0.55 * np.maximum(ai_g, ai_b), 0.0, 1.0)
    r_pure *= np.where(in_sil, 1.0, 0.0)
    r_pure *= np.clip(1.0 - hair_mask * 1.4, 0.0, 1.0)
    head_suppress = np.clip((y_norm - (by + bh * 0.34) / float(h)) / 0.055, 0.0, 1.0)
    waist_fade = np.clip(1.0 - (y_norm - (by + bh * 0.68) / float(h)) / 0.14, 0.0, 1.0)
    r_clean = cv2.GaussianBlur((r_pure * head_suppress * waist_fade).astype(np.float32), (15, 15), 0)
    r_clean *= cv2.GaussianBlur(in_sil_soft.astype(np.float32), (9, 9), 0)
    if float(np.max(r_clean)) > 0.08:
        r_clean = np.clip(r_clean / max(float(np.percentile(r_clean[r_clean > 0.05], 98)), 0.35), 0.0, 1.0)

    # --- Canal G: Solo mechones / puntas sueltas de cabello (raíces fijas en 0) ---
    g_pure = np.clip(ai_g - 0.55 * np.maximum(ai_r, ai_b), 0.0, 1.0)
    hair_bin = (hair_mask > 0.30).astype(np.uint8)
    k_dil = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    hair_dilated = cv2.dilate(hair_bin, k_dil, iterations=2).astype(np.float32)  # ~8px
    face_oval = ((x_norm - face_cx) / 0.088) ** 2 + ((y_norm - face_cy) / 0.100) ** 2
    protect_face = np.clip((face_oval - 0.70) / 0.50, 0.0, 1.0).astype(np.float32)
    g_clean = cv2.GaussianBlur((g_pure * hair_dilated * protect_face).astype(np.float32), (9, 9), 0)
    if float(np.max(g_clean)) > 0.08:
        g_clean = np.clip(g_clean / max(float(np.percentile(g_clean[g_clean > 0.05], 98)), 0.35), 0.0, 1.0)

    # --- Canal B: Solo ojo abierto + lente del monóculo ---
    b_pure = np.clip(ai_b - 0.55 * np.maximum(ai_r, ai_g), 0.0, 1.0)
    in_face_band = (
        in_sil_soft
        & (y_norm < (by + bh * 0.305) / float(h))
        & (y_norm > (by + bh * 0.14) / float(h))
        & (np.abs(x_norm - face_cx) < 0.11)
    )
    b_band = np.where(in_face_band, b_pure, 0.0)
    # Conservar componentes conectados válidos (>=35 px), descartando motas aisladas
    b_bin = (b_band > 0.18).astype(np.uint8)
    num_l, labels, stats, _ = cv2.connectedComponentsWithStats(b_bin, connectivity=8)
    b_keep = np.zeros_like(b_band, dtype=np.float32)
    for idx in range(1, num_l):
        if int(stats[idx, cv2.CC_STAT_AREA]) >= 35:
            b_keep[labels == idx] = b_band[labels == idx]
    # Asegurar cobertura limpia del lente rojo del monóculo dentro de la cara
    monocle_core = (crimson_mask > 0.5) & in_face_band
    if np.any(monocle_core):
        b_keep = np.maximum(b_keep, monocle_core.astype(np.float32) * 1.0)
    b_clean = cv2.GaussianBlur(b_keep, (5, 5), 0)
    b_clean = np.clip(b_clean * 1.15, 0.0, 1.0)

    return np.dstack([
        np.clip(r_clean * 255.0, 0, 255).astype(np.uint8),
        np.clip(g_clean * 255.0, 0, 255).astype(np.uint8),
        np.clip(b_clean * 255.0, 0, 255).astype(np.uint8),
    ])


def _render_motion_overlay_audit(items: list[dict], out_path: Path) -> None:
    if not items:
        return
    tile = 320
    n = len(items)
    pad = 12
    w = n * tile + (n + 1) * pad
    h = 2 * tile + 3 * pad + 26
    canvas = np.full((h, w, 3), 12, dtype=np.uint8)
    bg_rgb = np.full((tile, tile, 3), np.array([14, 18, 30], dtype=np.uint8))

    for col, rec in enumerate(items):
        x = pad + col * (tile + pad)
        cv2.putText(canvas, rec["emotion"].upper(), (x + 6, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (235, 242, 255), 2, cv2.LINE_AA)

        rgba_s = cv2.resize(rec["rgba"], (tile, tile), interpolation=cv2.INTER_AREA)
        mot_s = cv2.resize(rec["motion_mask"], (tile, tile), interpolation=cv2.INTER_AREA)
        a = rgba_s[:, :, 3:4].astype(np.float32) / 255.0
        base = rgba_s[:, :, :3].astype(np.float32) * a + bg_rgb.astype(np.float32) * (1.0 - a)
        overlay = np.clip(base * 0.62 + mot_s.astype(np.float32) * 0.72, 0, 255).astype(np.uint8)

        y_top = pad + 24
        y_bot = y_top + tile + pad
        canvas[y_top : y_top + tile, x : x + tile] = overlay
        canvas[y_bot : y_bot + tile, x : x + tile] = mot_s
        if col == 0:
            cv2.putText(canvas, "OVERLAY ALBEDO+MOTION", (x + 6, y_top + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 235, 140), 1, cv2.LINE_AA)
            cv2.putText(canvas, "MOTION MASK (RGB)", (x + 6, y_bot + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 235, 140), 1, cv2.LINE_AA)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, mode="RGB").save(out_path)
    print(f"[AUDIT] Guardado overlay motion mask: {out_path}")


def cmd_unpack(pilot_id: str) -> int:
    paths = _paths_for(pilot_id)
    if not paths["manifest"].is_file():
        print(f"[ERROR] Falta {paths['manifest']}. Ejecuta 'pack' primero.")
        return 1

    triptych_mf = json.loads(paths["manifest"].read_text(encoding="utf-8"))
    assets_dir = paths["assets_dir"]
    dlg_mf = _load_manifest(assets_dir, pilot_id)
    entries_by_em = {str(e["emotion"]): e for e in dlg_mf.get("entries", [])}

    paths["extracted_dir"].mkdir(parents=True, exist_ok=True)
    updated_emotions: set[str] = set()

    for trip in triptych_mf.get("triptychs", []):
        out_name = str(trip["output_file"])
        out_img_path = paths["outputs_dir"] / out_name
        if not out_img_path.is_file():
            print(f"[WARN] Aún no existe salida AI: {out_img_path} (se omite)")
            continue

        ai_full = np.array(Image.open(out_img_path).convert("RGB"), dtype=np.uint8)
        if ai_full.shape[1] != CANVAS_W or ai_full.shape[0] != CANVAS_H:
            ai_full = cv2.resize(ai_full, (CANVAS_W, CANVAS_H), interpolation=cv2.INTER_LINEAR)

        for slot in trip.get("slots", []):
            if not bool(slot.get("extract", False)):
                continue
            em = str(slot["emotion"])
            entry = entries_by_em.get(em)
            if entry is None:
                continue

            x0 = SLOT_XS[int(slot["slot"])]
            patch = ai_full[SLOT_Y0 : SLOT_Y0 + SLOT_H, x0 : x0 + SLOT_W]
            patch_1024 = cv2.resize(patch, (CROP_W, CROP_H), interpolation=cv2.INTER_LINEAR)

            raw_1024 = np.zeros((1024, 1024, 3), dtype=np.float32)
            raw_1024[:, CROP_X0:CROP_X1] = patch_1024.astype(np.float32) / 255.0

            rgba = np.array(Image.open(assets_dir / entry["albedo"]).convert("RGBA"), dtype=np.uint8)
            id_mask = np.array(Image.open(assets_dir / entry["id_mask"]).convert("RGB"), dtype=np.uint8)
            ilm_map = np.array(Image.open(assets_dir / entry["ilm_map"]).convert("RGB"), dtype=np.uint8)
            bbox = [int(v) for v in entry["bbox"]]
            bx, by, bw, bh = bbox

            yy, xx = np.mgrid[0:1024, 0:1024].astype(np.float32)
            y_norm = yy / 1024.0
            x_norm = xx / 1024.0
            face_cx = (bx + bw * 0.50) / 1024.0

            in_sil = rgba[:, :, 3] > 48
            hair_core = (ilm_map[:, :, 2] > 128) & in_sil
            torso_core = in_sil & (~hair_core) & (y_norm >= (by + bh * 0.34) / 1024.0) & (y_norm <= (by + bh * 0.68) / 1024.0)
            eye_band = in_sil & (y_norm >= (by + bh * 0.16) / 1024.0) & (y_norm <= (by + bh * 0.35) / 1024.0) & (np.abs(x_norm - face_cx) < 0.12)

            aligned_f, shift_xy, corr_sc = _align_to_silhouette(raw_1024, in_sil, hair_core, torso_core, eye_band)
            sanitized = _sanitize_motion_channels(aligned_f, rgba, id_mask, ilm_map, bbox)

            mot_name = str(entry["motion_mask"])
            Image.fromarray(sanitized, mode="RGB").save(paths["extracted_dir"] / mot_name)
            Image.fromarray(sanitized, mode="RGB").save(assets_dir / mot_name)
            updated_emotions.add(em)
            print(f"[UNPACK] {em}: shift={shift_xy} corr={corr_sc:.1f} -> {mot_name}")

    if not updated_emotions:
        print("[ERROR] No se desempaquetó ninguna motion mask.")
        return 1

    # Reconstruir hoja overlay + audit_dialogue_sheet.png completa desde los assets compilados
    items: list[dict] = []
    for em in dlg_mf.get("emotions", []):
        entry = entries_by_em.get(str(em))
        if entry is None:
            continue
        items.append({
            "emotion": str(em),
            "rgba": np.array(Image.open(assets_dir / entry["albedo"]).convert("RGBA"), dtype=np.uint8),
            "normal": np.array(Image.open(assets_dir / entry["normal_map"]).convert("RGB"), dtype=np.uint8),
            "depth_rgb": np.array(Image.open(assets_dir / entry["depth_map"]).convert("RGB"), dtype=np.uint8),
            "id_mask": np.array(Image.open(assets_dir / entry["id_mask"]).convert("RGB"), dtype=np.uint8),
            "ilm_map": np.array(Image.open(assets_dir / entry["ilm_map"]).convert("RGB"), dtype=np.uint8),
            "motion_mask": np.array(Image.open(assets_dir / entry["motion_mask"]).convert("RGB"), dtype=np.uint8),
        })
    _render_motion_overlay_audit(items, paths["overlay_audit"])
    _render_audit_sheet(items, paths["audit_sheet"])
    print(f"[OK] Inyectadas {len(updated_emotions)} motion masks AI sanitizadas en {assets_dir}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Trípticos 16:9 para Motion Masks AI limpias.")
    parser.add_argument("action", choices=["pack", "unpack"])
    parser.add_argument("--pilot-id", default="valentina_v2")
    args = parser.parse_args()
    if args.action == "pack":
        return cmd_pack(args.pilot_id.strip())
    return cmd_unpack(args.pilot_id.strip())


if __name__ == "__main__":
    raise SystemExit(main())
