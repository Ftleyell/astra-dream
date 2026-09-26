import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
RAW_DIR = REPO_ROOT / "assets" / "characters" / "navigators" / "raw"
FULL_DIR = REPO_ROOT / "assets" / "characters" / "navigators" / "full"
OUTPUT_DIR = REPO_ROOT / "assets" / "characters" / "navigators" / "portraits"
TARGET_SIZE = 512

def process_bubble_image(in_path, out_path):
    """Processes an image that already has a circular glowing bubble on dark background."""
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    gray = img.convert("L")
    thresh = gray.point(lambda p: 255 if p > 25 else 0)
    bbox = thresh.getbbox()
    min_x, min_y, max_x, max_y = bbox
    cx = (min_x + max_x) / 2.0
    cy = (min_y + max_y) / 2.0
    radius = max((max_x - min_x) / 2.0, (max_y - min_y) / 2.0) + 1.0

    mask_scale = 4
    mask = Image.new("L", (w * mask_scale, h * mask_scale), 0)
    draw = ImageDraw.Draw(mask)
    mcx, mcy, mrad = cx * mask_scale, cy * mask_scale, radius * mask_scale
    draw.ellipse([mcx - mrad, mcy - mrad, mcx + mrad, mcy + mrad], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=2.0 * mask_scale))
    mask = mask.resize((w, h), Image.Resampling.LANCZOS)

    r, g, b, _ = img.split()
    masked = Image.merge("RGBA", (r, g, b, mask))
    crop_size = int(radius * 2 + 10)
    crop_box = (
        int(cx - crop_size / 2.0),
        int(cy - crop_size / 2.0),
        int(cx + crop_size / 2.0),
        int(cy + crop_size / 2.0)
    )
    cropped = Image.new("RGBA", (crop_size, crop_size), (0, 0, 0, 0))
    cropped.paste(masked, (-crop_box[0], -crop_box[1]))
    final = cropped.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
    final.save(out_path, "PNG", optimize=True)
    print(f"Processed bubble portrait: {out_path}")

def process_tight_crop_bubble(in_path, center_x, center_y, crop_radius, theme_color_rgb, out_path):
    """Crops face tightly from full illustration and builds the matching circular bubble with glowing neon ring."""
    img = Image.open(in_path).convert("RGBA")
    
    x0 = int(center_x - crop_radius)
    y0 = int(center_y - crop_radius)
    x1 = int(center_x + crop_radius)
    y1 = int(center_y + crop_radius)
    
    cropped = img.crop((x0, y0, x1, y1))
    cropped = cropped.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
    
    scale = 4
    sw = TARGET_SIZE * scale
    sh = TARGET_SIZE * scale
    
    mask = Image.new("L", (sw, sh), 0)
    draw_m = ImageDraw.Draw(mask)
    margin = 8 * scale
    r_circle = (sw / 2.0) - margin
    center = sw / 2.0
    
    draw_m.ellipse([center - r_circle, center - r_circle, center + r_circle, center + r_circle], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=1.5 * scale))
    mask = mask.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
    
    r, g, b, _ = cropped.split()
    char_masked = Image.merge("RGBA", (r, g, b, mask))
    
    neon_layer = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw_n = ImageDraw.Draw(neon_layer)
    cr, cg, cb = theme_color_rgb
    
    # Outer glow gradient rings
    for glow_width, alpha in [(24 * scale, 40), (16 * scale, 75), (10 * scale, 140), (5 * scale, 220), (2 * scale, 255)]:
        draw_n.ellipse([
            center - r_circle - glow_width / 2,
            center - r_circle - glow_width / 2,
            center + r_circle + glow_width / 2,
            center + r_circle + glow_width / 2
        ], outline=(cr, cg, cb, alpha), width=max(1, int(glow_width / 2)))
    
    # Inner bright crisp rim
    draw_n.ellipse([
        center - r_circle + 2 * scale,
        center - r_circle + 2 * scale,
        center + r_circle - 2 * scale,
        center + r_circle - 2 * scale
    ], outline=(255, 255, 255, 200), width=int(2.5 * scale))

    # Glass highlight crescent (top-left)
    arc_rect = [
        center - r_circle + 8 * scale,
        center - r_circle + 8 * scale,
        center + r_circle - 8 * scale,
        center + r_circle - 8 * scale
    ]
    draw_n.arc(arc_rect, start=195, end=275, fill=(255, 255, 255, 175), width=int(3.5 * scale))
    
    neon_layer = neon_layer.filter(ImageFilter.GaussianBlur(radius=1.0 * scale))
    neon_layer = neon_layer.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
    
    final = Image.alpha_composite(char_masked, neon_layer)
    final.save(out_path, "PNG", optimize=True)
    print(f"Processed tight crop bubble portrait: {out_path}")

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # 1. Lyra
    process_bubble_image(
        RAW_DIR / "nav_portrait_lyra_raw.jpg",
        OUTPUT_DIR / "portrait_lyra.png"
    )
    
    # 2. Vespera
    process_bubble_image(
        RAW_DIR / "nav_portrait_vespera_raw.jpg",
        OUTPUT_DIR / "portrait_vespera.png"
    )
    
    # 3. Caelia
    process_tight_crop_bubble(
        FULL_DIR / "navigator_caelia.png",
        center_x=380, center_y=280, crop_radius=160,
        theme_color_rgb=(255, 184, 51),
        out_path=OUTPUT_DIR / "portrait_caelia.png"
    )
    
    # 4. Zephyr
    process_tight_crop_bubble(
        FULL_DIR / "navigator_zephyr.png",
        center_x=425, center_y=260, crop_radius=160,
        theme_color_rgb=(26, 217, 255),
        out_path=OUTPUT_DIR / "portrait_zephyr.png"
    )
    
    # 5. Iris
    process_tight_crop_bubble(
        FULL_DIR / "navigator_iris.png",
        center_x=415, center_y=285, crop_radius=165,
        theme_color_rgb=(225, 210, 255),
        out_path=OUTPUT_DIR / "portrait_iris.png"
    )
    
    print("All 5 navigator circular portraits generated successfully!")

if __name__ == "__main__":
    main()
