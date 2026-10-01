import math
from PIL import Image, ImageDraw, ImageFilter

def create_vortex_accretion_disk(filepath: str):
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    center = size / 2.0
    
    max_r = 120.0
    horizon_r = 22.0
    arms = 3
    
    pixels = img.load()
    for y in range(size):
        dy = y - center
        for x in range(size):
            dx = x - center
            r = math.sqrt(dx*dx + dy*dy)
            if r < horizon_r - 2.0 or r > max_r:
                continue
                
            angle = math.atan2(dy, dx)
            spiral_phase = angle * arms + (r * 0.14)
            spiral_intensity = (math.cos(spiral_phase) + 1.0) * 0.5
            
            sin_val = max(0.0, math.sin((r - horizon_r) / (max_r - horizon_r) * math.pi))
            env = sin_val ** 0.85
            # Inner ring glow
            inner_glow = math.exp(-((r - 28.0) ** 2) / (2.0 * 6.0 * 6.0)) * 1.5
            
            bright = (env * (0.35 + 0.65 * (spiral_intensity ** 1.5))) + inner_glow
            bright = max(0.0, min(1.8, float(bright)))
            
            t = (r - horizon_r) / (max_r - horizon_r)
            t = max(0.0, min(1.0, t))
            
            red = (1.0 - t) * 235 + t * 140
            green = (1.0 - t) * 245 + t * 40
            blue = (1.0 - t) * 255 + t * 255
            
            alpha = bright * 255.0
            if r < horizon_r + 3.0:
                alpha *= (r - (horizon_r - 2.0)) / 5.0
            alpha = max(0, min(255, int(alpha)))
            
            r_val = max(0, min(255, int(red * (bright / 1.2))))
            g_val = max(0, min(255, int(green * (bright / 1.2))))
            b_val = max(0, min(255, int(blue * (bright / 1.2))))
            
            pixels[x, y] = (r_val, g_val, b_val, alpha)
            
    img = img.filter(ImageFilter.GaussianBlur(radius=0.75))
    img.save(filepath, "PNG")
    print(f"Saved vortex accretion disk to {filepath}")


def create_orbital_drone(filepath: str):
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2.0, size / 2.0
    
    # Body points facing +X
    body_pts = [
        (cx + 24, cy),
        (cx + 10, cy - 8),
        (cx - 8, cy - 18),
        (cx - 16, cy - 14),
        (cx - 12, cy - 6),
        (cx - 18, cy - 4),
        (cx - 18, cy + 4),
        (cx - 12, cy + 6),
        (cx - 16, cy + 14),
        (cx - 8, cy + 18),
        (cx + 10, cy + 8),
    ]
    draw.polygon(body_pts, fill=(35, 42, 55, 255), outline=(90, 115, 145, 255))
    
    # Wing armor plates
    upper_wing = [(cx + 6, cy - 6), (cx - 7, cy - 16), (cx - 13, cy - 13), (cx - 4, cy - 5)]
    lower_wing = [(cx + 6, cy + 6), (cx - 7, cy + 16), (cx - 13, cy + 13), (cx - 4, cy + 5)]
    draw.polygon(upper_wing, fill=(65, 80, 105, 255))
    draw.polygon(lower_wing, fill=(65, 80, 105, 255))
    
    # Gold accents
    draw.line([(cx + 12, cy - 5), (cx + 2, cy - 2)], fill=(255, 200, 60, 255), width=2)
    draw.line([(cx + 12, cy + 5), (cx + 2, cy + 2)], fill=(255, 200, 60, 255), width=2)
    
    # Central optical eye
    eye_x, eye_y = cx + 6, cy
    draw.ellipse([eye_x - 4, eye_y - 4, eye_x + 4, eye_y + 4], fill=(255, 240, 150, 255), outline=(255, 180, 40, 255))
    draw.ellipse([eye_x - 2, eye_y - 2, eye_x + 2, eye_y + 2], fill=(255, 255, 255, 255))
    
    # Twin thrusters
    draw.ellipse([cx - 20, cy - 4, cx - 14, cy - 1], fill=(80, 220, 255, 220))
    draw.ellipse([cx - 20, cy + 1, cx - 14, cy + 4], fill=(80, 220, 255, 220))
    
    glow = img.filter(ImageFilter.GaussianBlur(radius=1.0))
    final = Image.alpha_composite(glow, img)
    final.save(filepath, "PNG")
    print(f"Saved orbital drone to {filepath}")


def create_cluster_canister(filepath: str):
    size = 48
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2.0, size / 2.0
    
    # Fins
    draw.polygon([(cx - 12, cy - 7), (cx - 18, cy - 12), (cx - 15, cy - 7)], fill=(50, 55, 65, 255))
    draw.polygon([(cx - 12, cy + 7), (cx - 18, cy + 12), (cx - 15, cy + 7)], fill=(50, 55, 65, 255))
    
    # Cylinder body
    draw.rectangle([cx - 14, cy - 7, cx + 10, cy + 7], fill=(45, 50, 60, 255), outline=(75, 85, 100, 255))
    
    # Hazard band
    draw.rectangle([cx - 4, cy - 7, cx + 2, cy + 7], fill=(255, 120, 20, 255))
    draw.line([(cx - 2, cy - 7), (cx, cy + 7)], fill=(20, 20, 20, 255), width=1)
    
    # Nose cone
    nose_pts = [(cx + 10, cy - 7), (cx + 18, cy), (cx + 10, cy + 7)]
    draw.polygon(nose_pts, fill=(70, 78, 92, 255), outline=(90, 100, 115, 255))
    
    # Beacon
    draw.ellipse([cx + 13, cy - 2, cx + 17, cy + 2], fill=(255, 50, 30, 255))
    draw.ellipse([cx + 14, cy - 1, cx + 16, cy + 1], fill=(255, 220, 200, 255))
    
    # Exhaust
    draw.rectangle([cx - 17, cy - 3, cx - 14, cy + 3], fill=(30, 30, 35, 255))
    draw.ellipse([cx - 19, cy - 2, cx - 15, cy + 2], fill=(255, 160, 40, 220))
    
    glow = img.filter(ImageFilter.GaussianBlur(radius=0.8))
    final = Image.alpha_composite(glow, img)
    final.save(filepath, "PNG")
    print(f"Saved cluster canister to {filepath}")


def create_lightning_bolt_core(filepath: str):
    w, h = 128, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cy = h / 2.0
    core_w = 4.0
    outer_w = 14.0
    
    pixels = img.load()
    for y in range(h):
        dy = abs(y - cy)
        core_mask = math.exp(-(dy**2) / (2.0 * core_w * core_w))
        outer_mask = math.exp(-(dy**2) / (2.0 * outer_w * outer_w)) * 0.65
        t = max(0.0, min(1.0, dy / outer_w))
        red = max(0, min(255, int((1.0 - t) * 255 + t * 40)))
        green = max(0, min(255, int((1.0 - t) * 255 + t * 210)))
        blue = 255
        
        for x in range(w):
            x_mod = 0.85 + 0.15 * math.sin(x * 0.4)
            intensity = (core_mask + outer_mask) * x_mod
            alpha = max(0, min(255, int(intensity * 255.0)))
            pixels[x, y] = (red, green, blue, alpha)
            
    img.save(filepath, "PNG")
    print(f"Saved lightning bolt core to {filepath}")


if __name__ == "__main__":
    create_vortex_accretion_disk("assets/sprites/weapons/vortex_accretion_disk.png")
    create_orbital_drone("assets/sprites/weapons/orbital_drone.png")
    create_cluster_canister("assets/sprites/weapons/cluster_canister.png")
    create_lightning_bolt_core("assets/sprites/effects/lightning_bolt_core.png")
