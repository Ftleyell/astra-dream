#!/usr/bin/env python3
"""Generate the reusable 4x2 (8-angle) head turnaround guide template
with fixed cranium scale and neck anchor across all 8 cells.
Also exports Valentina's clean front portrait on solid white as Reference Image 1.
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw


CELL = 512
COLS = 4
ROWS = 2

# (yaw_deg: 0=front, +left/+CCW viewer-left, -right, 180=back)
ANGLES = [
    ("0_front", 0.0),
    ("45_front_l", -45.0),
    ("45_front_r", 45.0),
    ("90_side_l", -90.0),
    ("90_side_r", 90.0),
    ("135_back_l", -135.0),
    ("135_back_r", 135.0),
    ("180_back", 180.0),
]


def _draw_mannequin_head(draw: ImageDraw.ImageDraw, cx: int, cy: int, yaw_deg: float) -> None:
    r = 128
    # Neck cylinder anchored identically in every cell
    neck_top_y = cy + r - 18
    neck_bot_y = cy + r + 84
    neck_w = 52
    draw.rectangle(
        [cx - neck_w, neck_top_y, cx + neck_w, neck_bot_y],
        fill=(228, 232, 240),
        outline=(110, 120, 140),
        width=4,
    )
    # Cranium sphere
    draw.ellipse(
        [cx - r, cy - r, cx + r, cy + r],
        fill=(242, 244, 248),
        outline=(90, 100, 120),
        width=5,
    )
    # Horizontal eye-line equator
    draw.line([(cx - r + 6, cy - 6), (cx + r - 6, cy - 6)], fill=(140, 155, 180), width=4)

    rad = math.radians(yaw_deg)
    sin_y = math.sin(rad)
    cos_y = math.cos(rad)

    # Front face meridian (solid cyan-blue when facing camera, dashed gray when on back)
    x_shift = sin_y * (r * 0.92)
    face_pts = []
    for step in range(-10, 11):
        lat = (step / 10.0) * (math.pi * 0.46)
        px = cx + x_shift * math.cos(lat)
        py = cy + math.sin(lat) * r
        face_pts.append((px, py))

    is_front_half = cos_y >= -0.05
    meridian_col = (0, 150, 230) if is_front_half else (180, 185, 195)
    draw.line(face_pts, fill=meridian_col, width=6 if is_front_half else 3)

    # Nose/gaze direction arrow on front + pure profiles (cos_y >= -0.05)
    if cos_y >= -0.05:
        nose_x = cx + sin_y * (r * 0.94)
        nose_y = cy + 18
        tip_x = nose_x + sin_y * 34
        draw.line([(nose_x, nose_y), (tip_x, nose_y + 4)], fill=(230, 50, 90), width=7)
        draw.ellipse([tip_x - 6, nose_y - 2, tip_x + 6, nose_y + 10], fill=(230, 50, 90))
        # Eye markers (blue = natural eye on her right, red = monocle on her left)
        for eye_side in (-1.0, 1.0):
            ex = cx + math.sin(rad + eye_side * 0.42) * (r * 0.88)
            if math.cos(rad + eye_side * 0.42) > 0.05:
                ey = cy - 8
                col = (220, 35, 65) if eye_side > 0 else (40, 110, 210)
                draw.ellipse([ex - 11, ey - 8, ex + 11, ey + 8], fill=col)
    else:
        # Back center line (purple) so 135 vs 180 is unmistakable
        back_x = -sin_y * (r * 0.92)
        back_pts = []
        for step in range(-10, 11):
            lat = (step / 10.0) * (math.pi * 0.46)
            back_pts.append((cx + back_x * math.cos(lat), cy + math.sin(lat) * r))
        draw.line(back_pts, fill=(130, 80, 200), width=6)


def main() -> None:
    out_dir = Path("sandbox/pilot_rig_lab/source_refs")
    out_dir.mkdir(parents=True, exist_ok=True)

    guide = Image.new("RGB", (CELL * COLS, CELL * ROWS), (255, 255, 255))
    draw = ImageDraw.Draw(guide)

    # Subtle light-gray cell dividers
    for c in range(1, COLS):
        draw.line([(c * CELL, 0), (c * CELL, CELL * ROWS)], fill=(232, 234, 238), width=2)
    draw.line([(0, CELL), (CELL * COLS, CELL)], fill=(232, 234, 238), width=2)

    for idx, (_name, yaw) in enumerate(ANGLES):
        col = idx % COLS
        row = idx // COLS
        cx = col * CELL + CELL // 2
        cy = row * CELL + int(CELL * 0.44)
        _draw_mannequin_head(draw, cx, cy, yaw)

    guide_path = out_dir / "head_8dir_guide.png"
    guide.save(guide_path)
    print("Saved guide:", guide_path, guide.size)

    # Export Valentina front reference on pure white 512x512
    front_src = Path("sandbox/pilot_rig_lab/combat_assets/valentina_planar/heads/head_front.png")
    if front_src.exists():
        im = Image.open(front_src).convert("RGBA")
        scale = 340.0 / max(im.width, im.height)
        im_res = im.resize((int(round(im.width * scale)), int(round(im.height * scale))), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 255))
        canvas.alpha_composite(im_res, ((CELL - im_res.width) // 2, (CELL - im_res.height) // 2))
        ref_path = out_dir / "valentina_head_front_ref.png"
        canvas.convert("RGB").save(ref_path)
        print("Saved ref:", ref_path, canvas.size)


if __name__ == "__main__":
    main()
