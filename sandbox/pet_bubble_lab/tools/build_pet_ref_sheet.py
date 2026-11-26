"""Build clean #808080 reference sheets for pet sprite generation."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageDraw, ImageFont


CANVAS_SIZE: tuple[int, int] = (1920, 1080)
CANVAS_SIZE_2X2: tuple[int, int] = (1280, 1280)
BG_COLOR: tuple[int, int, int] = (128, 128, 128)
LABEL_COLOR: tuple[int, int, int] = (74, 74, 74)
DIVIDER_COLOR: tuple[int, int, int] = (56, 56, 56)
DIVIDER_WIDTH: int = 4
SLOT_BOX_SIZE: int = 460
SLOT_BOX_SIZE_3X2: int = 380
SLOT_BOX_SIZE_2X2: int = 420
SLOT_CENTER_Y: int = 565
LABEL_Y: int = 140
FONT_SIZE: int = 32

SHEETS: dict[int, tuple[str, list[str]]] = {
    1: ("pet_ref_sample_3x1_mochi_kuro_luna.png", ["mochi", "kuro", "luna"]),
    2: ("pet_ref_sample_2x1_pip_cosmo.png", ["pip", "cosmo"]),
}

SHEETS_3X2: dict[int, tuple[str, list[str]]] = {
    1: ("pet_ref_3x2_mochi_kuro_luna.png", ["mochi", "kuro", "luna"]),
    2: ("pet_ref_3x2_pip_cosmo.png", ["pip", "cosmo"]),
}

SHEETS_2X2: dict[int, tuple[str, list[str]]] = {
    2: ("pet_ref_2x2_pip_cosmo.png", ["pip", "cosmo"]),
}


def load_label_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Load a crisp sans-serif system font or fall back to Pillow default."""
    for font_name in ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(font_name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def fit_rgba_sprite(path: Path, max_size: int) -> Image.Image:
    """Load an RGBA sprite and scale it proportionally inside max_size."""
    sprite = Image.open(path).convert("RGBA")
    scale = min(max_size / sprite.width, max_size / sprite.height)
    new_size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    return sprite.resize(new_size, Image.Resampling.LANCZOS)


def compose_sheet(
    pets: Sequence[str],
    assets_dir: Path,
    out_path: Path,
) -> Path:
    """Compose pets evenly across a 1920x1080 #808080 reference canvas."""
    canvas = Image.new("RGB", CANVAS_SIZE, BG_COLOR)
    draw = ImageDraw.Draw(canvas)
    font = load_label_font(FONT_SIZE)

    count = len(pets)
    slot_width = CANVAS_SIZE[0] / count

    for idx, pet_id in enumerate(pets, start=1):
        src_path = assets_dir / f"pet_{pet_id}.png"
        if not src_path.exists():
            raise FileNotFoundError(f"Missing pet asset: {src_path}")

        sprite = fit_rgba_sprite(src_path, SLOT_BOX_SIZE)
        center_x = round((idx - 0.5) * slot_width)
        paste_x = center_x - sprite.width // 2
        paste_y = SLOT_CENTER_Y - sprite.height // 2
        canvas.paste(sprite, (paste_x, paste_y), sprite)

        label = f"[{idx}] {pet_id.upper()}"
        draw.text((center_x, LABEL_Y), label, fill=LABEL_COLOR, font=font, anchor="mm")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, format="PNG")
    return out_path


def compose_sheet_grid(
    pets: Sequence[str],
    assets_dir: Path,
    out_path: Path,
    canvas_size: tuple[int, int],
    cols: int,
    slot_box_size: int,
) -> Path:
    """Compose a cols x 2 reference grid with each pet duplicated in both rows."""
    canvas = Image.new("RGB", canvas_size, BG_COLOR)
    draw = ImageDraw.Draw(canvas)

    rows = 2
    cell_w = canvas_size[0] // cols
    cell_h = canvas_size[1] // rows

    for col_idx, pet_id in enumerate(pets[:cols]):
        src_path = assets_dir / f"pet_{pet_id}.png"
        if not src_path.exists():
            raise FileNotFoundError(f"Missing pet asset: {src_path}")

        sprite = fit_rgba_sprite(src_path, slot_box_size)
        center_x = col_idx * cell_w + cell_w // 2
        for row_idx in range(rows):
            center_y = row_idx * cell_h + cell_h // 2
            paste_x = center_x - sprite.width // 2
            paste_y = center_y - sprite.height // 2
            canvas.paste(sprite, (paste_x, paste_y), sprite)

    for col_idx in range(1, cols):
        col_div = cell_w * col_idx
        draw.line([(col_div, 0), (col_div, canvas_size[1])], fill=DIVIDER_COLOR, width=DIVIDER_WIDTH)
    draw.line([(0, cell_h), (canvas_size[0], cell_h)], fill=DIVIDER_COLOR, width=DIVIDER_WIDTH)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, format="PNG")
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate pet reference sheets on #808080.")
    parser.add_argument(
        "--layout",
        choices=("strip", "3x2", "2x2"),
        default="strip",
        help="Layout mode: strip (1 row), 3x2 (3 cols x 2 rows), or 2x2 (2 cols x 2 rows).",
    )
    parser.add_argument(
        "--sheet",
        type=int,
        choices=sorted(SHEETS.keys()),
        default=1,
        help="Sheet index: 1=(mochi,kuro,luna), 2=(pip,cosmo).",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[3]
    assets_dir = repo_root / "assets" / "pets"
    out_dir = repo_root / "sandbox" / "pet_bubble_lab" / "source_refs"

    if args.layout == "3x2":
        filename, pets = SHEETS_3X2[args.sheet]
        target_size = CANVAS_SIZE
        out_path = compose_sheet_grid(pets, assets_dir, out_dir / filename, target_size, 3, SLOT_BOX_SIZE_3X2)
    elif args.layout == "2x2":
        if args.sheet not in SHEETS_2X2:
            raise ValueError(f"Sheet {args.sheet} is not defined for layout 2x2.")
        filename, pets = SHEETS_2X2[args.sheet]
        target_size = CANVAS_SIZE_2X2
        out_path = compose_sheet_grid(pets, assets_dir, out_dir / filename, target_size, 2, SLOT_BOX_SIZE_2X2)
    else:
        filename, pets = SHEETS[args.sheet]
        target_size = CANVAS_SIZE
        out_path = compose_sheet(pets, assets_dir, out_dir / filename)
    print(f"Generated: {out_path} ({target_size[0]}x{target_size[1]})")


if __name__ == "__main__":
    main()
