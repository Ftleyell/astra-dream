import os
import math
from PIL import Image, ImageDraw, ImageFilter

INPUT_DIR = r"C:\Users\Frani\.gemini\antigravity\brain\1f8d9939-8c9e-40c8-8722-3b68b1b59aff"
OUTPUT_DIR = r"C:\Users\Frani\.gemini\antigravity\scratch\astra_dream\assets\pets"

PET_FILES = {
    "mochi": "pet_mochi_raw_1790406283889.jpg",
    "kuro": "pet_kuro_raw_1790406349905.jpg",
    "luna": "pet_luna_raw_1790406372485.jpg",
    "pip": "pet_pip_raw_1790406400689.jpg",
    "cosmo": "pet_cosmo_raw_1790406435650.jpg",
}

TARGET_SIZE = 512

def process_pet(pet_name, filename):
    in_path = os.path.join(INPUT_DIR, filename)
    out_path = os.path.join(OUTPUT_DIR, f"pet_{pet_name}.png")

    img = Image.open(in_path).convert("RGBA")
    w, h = img.size

    # Convert to grayscale to find bounding box of the glowing sphere
    gray = img.convert("L")
    thresh = gray.point(lambda p: 255 if p > 22 else 0)
    bbox = thresh.getbbox() # (min_x, min_y, max_x, max_y)

    min_x, min_y, max_x, max_y = bbox
    cx = (min_x + max_x) / 2.0
    cy = (min_y + max_y) / 2.0
    # Radius covers the entire sphere rim
    rx = (max_x - min_x) / 2.0
    ry = (max_y - min_y) / 2.0
    radius = max(rx, ry) + 1.0

    print(f"Processing {pet_name}: center=({cx:.1f}, {cy:.1f}), radius={radius:.1f}")

    # Create high-resolution supersampled mask for ultra-smooth anti-aliasing
    # Using 4x supersampling for the circle mask
    mask_scale = 4
    mask_w = w * mask_scale
    mask_h = h * mask_scale
    mask = Image.new("L", (mask_w, mask_h), 0)
    draw = ImageDraw.Draw(mask)

    mcx = cx * mask_scale
    mcy = cy * mask_scale
    mrad = radius * mask_scale

    draw.ellipse([mcx - mrad, mcy - mrad, mcx + mrad, mcy - mrad + 2 * mrad], fill=255)
    
    # Soften outer edge with a small blur at high res, then downsample back to (w, h)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=2.0 * mask_scale))
    mask = mask.resize((w, h), Image.Resampling.LANCZOS)

    # Apply mask as alpha channel
    r, g, b, _ = img.split()
    masked_img = Image.merge("RGBA", (r, g, b, mask))

    # Crop neatly centered around the bubble with a tiny margin (5px)
    crop_size = int(radius * 2 + 10)
    crop_box = (
        int(cx - crop_size / 2.0),
        int(cy - crop_size / 2.0),
        int(cx + crop_size / 2.0),
        int(cy + crop_size / 2.0)
    )

    cropped = Image.new("RGBA", (crop_size, crop_size), (0, 0, 0, 0))
    # Paste masked image with offset
    cropped.paste(masked_img, (-crop_box[0], -crop_box[1]))

    # Resize to target size 512x512
    final_img = cropped.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)

    final_img.save(out_path, "PNG", optimize=True)
    print(f"Saved: {out_path} ({TARGET_SIZE}x{TARGET_SIZE})")

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for pet_name, filename in PET_FILES.items():
        process_pet(pet_name, filename)
    print("All pets processed successfully!")

if __name__ == "__main__":
    main()
