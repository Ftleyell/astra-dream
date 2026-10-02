import os
from PIL import Image

brain_dir = r"C:\Users\neldo\.gemini\antigravity\brain\4bd13dfc-4d1a-4da4-bc9a-bccb2fec8918"
out_bullets = r"C:\Users\neldo\Drive Nel2\astra-dream\assets\sprites\bullets"
out_telegraphs = r"C:\Users\neldo\Drive Nel2\astra-dream\assets\sprites\telegraphs"

os.makedirs(out_bullets, exist_ok=True)
os.makedirs(out_telegraphs, exist_ok=True)

def process_chromakey(input_path, output_path, target_size=256, is_bullet=True):
    print(f"Processing: {os.path.basename(input_path)} -> {os.path.basename(output_path)}")
    im = Image.open(input_path).convert("RGBA")
    w, h = im.size
    pix = im.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            # Keying pure green
            max_other = max(r, b)
            excess = g - max_other

            if excess > 20 and g > 80:
                # Strong green background or green fringe
                if excess > 50:
                    alpha = 0
                else:
                    # Soft edge transition
                    alpha = int(255 * (1.0 - (excess - 20) / 30.0))
                # Despill: neutralize green tint on edges
                g_despilled = min(g, max_other)
                pix[x, y] = (r, g_despilled, b, min(a, alpha))
            elif g > 150 and g > r * 1.2 and g > b * 1.2:
                pix[x, y] = (0, 0, 0, 0)

    # Autocrop to non-zero alpha bounding box
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
        # Make square with padding
        bw = bbox[2] - bbox[0]
        bh = bbox[3] - bbox[1]
        dim = max(bw, bh)
        padded = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
        offset_x = (dim - bw) // 2
        offset_y = (dim - bh) // 2
        padded.paste(im, (offset_x, offset_y))
        im = padded.resize((target_size, target_size), Image.Resampling.LANCZOS)
    else:
        im = im.resize((target_size, target_size), Image.Resampling.LANCZOS)

    im.save(output_path, "PNG")
    print(f"Saved: {output_path} ({target_size}x{target_size})")

items = [
    (os.path.join(brain_dir, "bullet_cone_amber_1790899010816.jpg"), os.path.join(out_bullets, "bullet_alien_amber_cone.png"), 128, True),
    (os.path.join(brain_dir, "bullet_ring_cobalt_1790899027308.jpg"), os.path.join(out_bullets, "bullet_alien_cobalt_ring.png"), 128, True),
    (os.path.join(brain_dir, "bullet_wave_purple_1790899053544.jpg"), os.path.join(out_bullets, "bullet_alien_purple_wave.png"), 128, True),
    (os.path.join(brain_dir, "telegraph_cone_sector_1790899189105.jpg"), os.path.join(out_telegraphs, "telegraph_cone.png"), 256, False),
    (os.path.join(brain_dir, "telegraph_ring_1790899108945.jpg"), os.path.join(out_telegraphs, "telegraph_ring.png"), 256, False),
    (os.path.join(brain_dir, "telegraph_wave_1790899155006.jpg"), os.path.join(out_telegraphs, "telegraph_wave.png"), 256, False),
]

for in_p, out_p, sz, is_b in items:
    if os.path.exists(in_p):
        process_chromakey(in_p, out_p, sz, is_b)
    else:
        print(f"WARNING: File not found: {in_p}")
