"""Compile 512x512 pet albedos, inflated cel normal maps, and seamless bubble textures."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
PILOT_TOOLS_DIR = REPO_ROOT / "sandbox" / "pilot_rig_lab" / "tools"
MODELS_CACHE = PILOT_TOOLS_DIR / "models"
os.environ.setdefault("HF_HOME", str(MODELS_CACHE))
os.environ.setdefault("U2NET_HOME", str(MODELS_CACHE / "u2net"))

if str(PILOT_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(PILOT_TOOLS_DIR))

import cv2
import numpy as np
from PIL import Image, ImageDraw
from rembg import new_session, remove

from polish_outlines import alpha_bleed_and_defringe

UPSCAYL_BIN = Path(r"C:\Program Files\Upscayl\resources\bin\upscayl-bin.exe")
UPSCAYL_MODELS = Path(r"C:\Program Files\Upscayl\resources\models")

OUT_SIZE = 512
SPRITE_MAX_DIM = 400
CELL_INSET_PX = 18

SHEET_SPECS: list[dict[str, Any]] = [
    {
        "raw": "raw_gen_3x2_mochi_kuro_luna.jpg",
        "upscaled": "upscaled_3x2_mochi_kuro_luna.png",
        "cols": 3,
        "pets": ["mochi", "kuro", "luna"],
    },
    {
        "raw": "raw_gen_2x2_pip_cosmo.jpg",
        "upscaled": "upscaled_2x2_pip_cosmo.png",
        "cols": 2,
        "pets": ["pip", "cosmo"],
    },
]


def run_upscayl_4x(src_path: Path, dst_path: Path, model: str = "digital-art-4x") -> Path:
    """Upscale a generated sprite/tile sheet 4x with Upscayl CLI."""
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    if dst_path.exists() and dst_path.stat().st_mtime >= src_path.stat().st_mtime:
        return dst_path
    if not UPSCAYL_BIN.exists():
        raise FileNotFoundError(f"Upscayl CLI not found at {UPSCAYL_BIN}")
    cmd = [
        str(UPSCAYL_BIN),
        "-i",
        str(src_path),
        "-o",
        str(dst_path),
        "-m",
        str(UPSCAYL_MODELS),
        "-n",
        model,
        "-z",
        "4",
        "-s",
        "4",
        "-f",
        "png",
    ]
    subprocess.run(cmd, check=True)
    return dst_path


def crop_cell(img_bgr: np.ndarray, row: int, col: int, rows: int, cols: int, inset: int) -> np.ndarray:
    """Crop one grid cell with an inset margin to avoid divider lines."""
    h, w = img_bgr.shape[:2]
    x0 = round(col * w / cols) + inset
    x1 = round((col + 1) * w / cols) - inset
    y0 = round(row * h / rows) + inset
    y1 = round((row + 1) * h / rows) - inset
    return img_bgr[max(0, y0) : min(h, y1), max(0, x0) : min(w, x1)].copy()


def predict_isnet_alpha(cell_bgr: np.ndarray, session: Any) -> np.ndarray:
    """Run IS-Net Anime on a square-padded cell to preserve aspect ratio."""
    h, w = cell_bgr.shape[:2]
    side = max(h, w)
    pad_y = (side - h) // 2
    pad_x = (side - w) // 2
    sq_rgb = np.full((side, side, 3), 128, dtype=np.uint8)
    sq_rgb[pad_y : pad_y + h, pad_x : pad_x + w] = cv2.cvtColor(cell_bgr, cv2.COLOR_BGR2RGB)
    out = np.array(remove(Image.fromarray(sq_rgb), session=session))
    return out[pad_y : pad_y + h, pad_x : pad_x + w, 3]


def _bbox_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    """Shortest Euclidean distance between two xywh axis-aligned boxes."""
    ax0, ay0, aw, ah = a
    bx0, by0, bw, bh = b
    dx = max(0, max(ax0 - (bx0 + bw), bx0 - (ax0 + aw)))
    dy = max(0, max(ay0 - (by0 + bh), by0 - (ay0 + ah)))
    return float(np.hypot(dx, dy))


def extract_clean_pet_rgba(cell_bgr: np.ndarray, session: Any) -> np.ndarray:
    """Extract clean pet RGBA with IS-Net Anime, connected-component filtering, and defringing."""
    h, w = cell_bgr.shape[:2]
    isnet_a = predict_isnet_alpha(cell_bgr, session)
    fg_raw = isnet_a >= 120

    # Fill tiny pinholes inside the character silhouette
    inv = (~fg_raw).astype(np.uint8)
    n_holes, h_lbl, h_stats, _ = cv2.connectedComponentsWithStats(inv)
    for hid in range(1, n_holes):
        area = int(h_stats[hid, cv2.CC_STAT_AREA])
        x, y, bw, bh, _ = [int(v) for v in h_stats[hid]]
        touches_border = x == 0 or y == 0 or (x + bw) >= w or (y + bh) >= h
        if not touches_border and area < 1800:
            fg_raw[h_lbl == hid] = True

    n_cc, lbl, stats, centroids = cv2.connectedComponentsWithStats(fg_raw.astype(np.uint8))
    if n_cc <= 1:
        raise RuntimeError("IS-Net found no foreground pixels in pet cell.")

    cx, cy = w * 0.5, h * 0.52
    best_cid = 1
    best_score = -1e18
    for cid in range(1, n_cc):
        area = float(stats[cid, cv2.CC_STAT_AREA])
        dist = float(np.hypot(centroids[cid][0] - cx, centroids[cid][1] - cy))
        score = area - dist * 180.0
        if score > best_score:
            best_score = score
            best_cid = cid

    main_area = int(stats[best_cid, cv2.CC_STAT_AREA])
    main_box = (
        int(stats[best_cid, cv2.CC_STAT_LEFT]),
        int(stats[best_cid, cv2.CC_STAT_TOP]),
        int(stats[best_cid, cv2.CC_STAT_WIDTH]),
        int(stats[best_cid, cv2.CC_STAT_HEIGHT]),
    )

    fg = lbl == best_cid
    min_sub_area = max(160, int(main_area * 0.0035))
    for cid in range(1, n_cc):
        if cid == best_cid:
            continue
        area = int(stats[cid, cv2.CC_STAT_AREA])
        if area < min_sub_area:
            continue
        sub_box = (
            int(stats[cid, cv2.CC_STAT_LEFT]),
            int(stats[cid, cv2.CC_STAT_TOP]),
            int(stats[cid, cv2.CC_STAT_WIDTH]),
            int(stats[cid, cv2.CC_STAT_HEIGHT]),
        )
        if _bbox_distance(main_box, sub_box) <= 45.0:
            fg |= lbl == cid

    k3 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    fg_u8 = fg.astype(np.uint8) * 255
    fg_inner = cv2.erode(fg_u8, k3, iterations=1) > 0
    fg_blur = cv2.GaussianBlur(fg.astype(np.float32) * 255.0, (3, 3), 0.72)
    alpha = np.where(fg, np.clip(fg_blur, 96.0, 255.0), 0.0)
    alpha[fg_inner] = 255.0
    alpha_u8 = np.clip(np.round(alpha), 0, 255).astype(np.uint8)

    bgra = np.zeros((h, w, 4), dtype=np.uint8)
    bgra[:, :, :3] = cell_bgr
    bgra[:, :, 3] = alpha_u8
    bgra_clean = alpha_bleed_and_defringe(bgra)
    return bgra_clean


def normalize_pet_canvas(bgra: np.ndarray, out_size: int = OUT_SIZE, max_dim: int = SPRITE_MAX_DIM) -> np.ndarray:
    """Crop to foreground bbox and center uniformly into an out_size x out_size RGBA canvas."""
    ys, xs = np.where(bgra[:, :, 3] > 24)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    cropped = bgra[y0:y1, x0:x1]

    ch, cw = cropped.shape[:2]
    scale = max_dim / float(max(ch, cw))
    nw = max(1, round(cw * scale))
    nh = max(1, round(ch * scale))
    resized = cv2.resize(cropped, (nw, nh), interpolation=cv2.INTER_AREA)

    canvas = np.zeros((out_size, out_size, 4), dtype=np.uint8)
    ox = (out_size - nw) // 2
    oy = (out_size - nh) // 2
    canvas[oy : oy + nh, ox : ox + nw] = resized
    return canvas


def build_inflated_normal_map(bgra_512: np.ndarray) -> np.ndarray:
    """Generate a smooth anime cel-inflated normal map (+X right, +Y up, +Z toward camera)."""
    alpha = bgra_512[:, :, 3]
    fg = alpha > 127
    fg_u8 = fg.astype(np.uint8)

    dist = cv2.distanceTransform(fg_u8, cv2.DIST_L2, 5).astype(np.float32)
    max_d = max(float(dist.max()), 1.0)
    d_norm = np.clip(dist / (max_d * 0.74), 0.0, 1.0)
    h_edge = np.sqrt(np.clip(1.0 - (1.0 - d_norm) ** 2, 0.0, 1.0))

    ys, xs = np.where(fg)
    cy = float(ys.mean())
    cx = float(xs.mean())
    rad = max(float(max(ys.max() - ys.min(), xs.max() - xs.min())) * 0.56, 1.0)
    yy, xx = np.mgrid[0:OUT_SIZE, 0:OUT_SIZE].astype(np.float32)
    r_norm = np.clip(np.hypot(xx - cx, yy - cy) / rad, 0.0, 1.0)
    h_dome = np.sqrt(np.clip(1.0 - r_norm ** 2, 0.0, 1.0))

    bgr_f = bgra_512[:, :, :3].astype(np.float32) / 255.0
    luma = 0.114 * bgr_f[:, :, 0] + 0.587 * bgr_f[:, :, 1] + 0.299 * bgr_f[:, :, 2]
    luma_smooth = cv2.GaussianBlur(luma, (0, 0), 2.2)

    height = (0.70 * h_edge + 0.30 * h_dome) * fg.astype(np.float32)
    height = 0.65 * cv2.GaussianBlur(height, (0, 0), 10.0) + 0.35 * cv2.GaussianBlur(height, (0, 0), 3.5)
    height = height + 0.08 * luma_smooth * fg.astype(np.float32)

    gx = cv2.Sobel(height, cv2.CV_32F, 1, 0, ksize=5) / 16.0
    gy = cv2.Sobel(height, cv2.CV_32F, 0, 1, ksize=5) / 16.0

    # Convention: +X right, +Y up (negate downward image derivative), +Z toward camera
    strength = 2.6
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx, dtype=np.float32)
    inv_len = 1.0 / np.maximum(np.sqrt(nx * nx + ny * ny + nz * nz), 1e-6)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len

    # Neutral camera-facing normal (0, 0, 1) outside silhouette
    nx = np.where(fg, nx, 0.0)
    ny = np.where(fg, ny, 0.0)
    nz = np.where(fg, nz, 1.0)

    normal_rgb = np.zeros((OUT_SIZE, OUT_SIZE, 3), dtype=np.uint8)
    normal_rgb[:, :, 0] = np.clip(np.round((nx * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    normal_rgb[:, :, 1] = np.clip(np.round((ny * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    normal_rgb[:, :, 2] = np.clip(np.round((nz * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    return normal_rgb


def build_seamless_bubble_texture(cell_bgr: np.ndarray, out_size: int = OUT_SIZE) -> np.ndarray:
    """Square-crop and seamless-wrap-blend a bubble texture to 512x512 RGB."""
    h, w = cell_bgr.shape[:2]
    side = min(h, w)
    y0 = (h - side) // 2
    x0 = (w - side) // 2
    sq_bgr = cell_bgr[y0 : y0 + side, x0 : x0 + side]
    sq_rgb = cv2.cvtColor(cv2.resize(sq_bgr, (out_size, out_size), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2RGB)
    base = sq_rgb.astype(np.float32)

    half = out_size // 2
    shifted = np.roll(np.roll(base, half, axis=0), half, axis=1)

    u = (np.arange(out_size, dtype=np.float32) + 0.5) / float(out_size)
    v = (np.arange(out_size, dtype=np.float32) + 0.5) / float(out_size)
    wy = np.sin(np.pi * v)[:, None]
    wx = np.sin(np.pi * u)[None, :]
    w_center = (wx * wy) ** 1.4
    w_shift = ((1.0 - wx) * (1.0 - wy)) ** 1.4
    w_sum = np.maximum(w_center + w_shift, 1e-5)
    alpha_blend = (w_center / w_sum)[:, :, None]

    blended = base * alpha_blend + shifted * (1.0 - alpha_blend)
    return np.clip(np.round(blended), 0, 255).astype(np.uint8)


def make_checkerboard(size: int, tile: int = 24) -> np.ndarray:
    """Create a subtle dark checkerboard background for alpha inspection."""
    yy, xx = np.mgrid[0:size, 0:size]
    pat = ((xx // tile) + (yy // tile)) % 2
    bg = np.where(pat[:, :, None] == 0, 48, 68).astype(np.uint8)
    return np.repeat(bg, 3, axis=2)


def build_audit_sheet(assets_root: Path, pet_ids: list[str], out_path: Path) -> None:
    """Create a 5x3 audit grid: [Albedo on Checker, Normal Map, 2x2 Tiled Bubble Tex]."""
    thumb = 256
    pad = 12
    cols = 3
    rows = len(pet_ids)
    w = cols * thumb + (cols + 1) * pad
    h = rows * thumb + (rows + 1) * pad
    sheet = Image.new("RGB", (w, h), (22, 24, 32))
    checker = make_checkerboard(thumb, tile=16)

    for r_idx, pid in enumerate(pet_ids):
        pdir = assets_root / pid
        albedo = np.array(Image.open(pdir / f"pet_{pid}_albedo.png").convert("RGBA").resize((thumb, thumb), Image.Resampling.LANCZOS))
        normal = Image.open(pdir / f"pet_{pid}_normal.png").convert("RGB").resize((thumb, thumb), Image.Resampling.LANCZOS)
        btex = Image.open(pdir / f"pet_{pid}_bubble_tex.png").convert("RGB").resize((thumb // 2, thumb // 2), Image.Resampling.LANCZOS)

        a_f = albedo[:, :, 3:4].astype(np.float32) / 255.0
        comp = np.clip(albedo[:, :, :3].astype(np.float32) * a_f + checker.astype(np.float32) * (1.0 - a_f), 0, 255).astype(np.uint8)
        albedo_img = Image.fromarray(comp)

        tiled = Image.new("RGB", (thumb, thumb))
        for ty in (0, thumb // 2):
            for tx in (0, thumb // 2):
                tiled.paste(btex, (tx, ty))

        y = pad + r_idx * (thumb + pad)
        sheet.paste(albedo_img, (pad + 0 * (thumb + pad), y))
        sheet.paste(normal, (pad + 1 * (thumb + pad), y))
        sheet.paste(tiled, (pad + 2 * (thumb + pad), y))

    draw = ImageDraw.Draw(sheet)
    for r_idx, pid in enumerate(pet_ids):
        y = pad + r_idx * (thumb + pad) + 6
        draw.text((pad + 8, y), pid.upper(), fill=(255, 230, 140))

    sheet.save(out_path, format="PNG")


def main() -> None:
    lab_root = REPO_ROOT / "sandbox" / "pet_bubble_lab"
    refs_dir = lab_root / "source_refs"
    assets_root = lab_root / "assets"
    assets_root.mkdir(parents=True, exist_ok=True)

    print("Loading IS-Net Anime session...")
    session = new_session("isnet-anime")

    all_pets: list[str] = []
    for spec in SHEET_SPECS:
        raw_path = refs_dir / spec["raw"]
        up_path = refs_dir / spec["upscaled"]
        print(f"Upscaling 4x: {raw_path.name} -> {up_path.name}")
        run_upscayl_4x(raw_path, up_path)

        sheet_bgr = cv2.imread(str(up_path), cv2.IMREAD_COLOR)
        if sheet_bgr is None:
            raise RuntimeError(f"Failed to read upscaled image: {up_path}")

        cols = int(spec["cols"])
        for col_idx, pet_id in enumerate(spec["pets"]):
            all_pets.append(pet_id)
            pet_dir = assets_root / pet_id
            pet_dir.mkdir(parents=True, exist_ok=True)

            top_bgr = crop_cell(sheet_bgr, row=0, col=col_idx, rows=2, cols=cols, inset=CELL_INSET_PX)
            bot_bgr = crop_cell(sheet_bgr, row=1, col=col_idx, rows=2, cols=cols, inset=CELL_INSET_PX)

            clean_bgra = extract_clean_pet_rgba(top_bgr, session)
            albedo_512 = normalize_pet_canvas(clean_bgra, out_size=OUT_SIZE, max_dim=SPRITE_MAX_DIM)
            normal_512 = build_inflated_normal_map(albedo_512)
            bubble_512 = build_seamless_bubble_texture(bot_bgr, out_size=OUT_SIZE)

            albedo_rgba = cv2.cvtColor(albedo_512, cv2.COLOR_BGRA2RGBA)
            Image.fromarray(albedo_rgba).save(pet_dir / f"pet_{pet_id}_albedo.png", format="PNG")
            Image.fromarray(normal_512).save(pet_dir / f"pet_{pet_id}_normal.png", format="PNG")
            Image.fromarray(bubble_512).save(pet_dir / f"pet_{pet_id}_bubble_tex.png", format="PNG")
            print(f"Compiled {pet_id}: albedo + normal + bubble_tex (512x512)")

    audit_path = refs_dir / "audit_compiled_pets.png"
    build_audit_sheet(assets_root, all_pets, audit_path)
    print(f"Saved audit sheet: {audit_path}")


if __name__ == "__main__":
    main()
