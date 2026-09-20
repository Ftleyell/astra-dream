"""
Procedural Sci-Fi Asset Generator for Astra Dream
Generates high-definition, transparent PNG assets for UI, Portraits, Characters, and Enemies.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

def create_gradient_radial(draw, center, radius, inner_color, outer_color):
    cx, cy = center
    r_in, g_in, b_in, a_in = inner_color
    r_out, g_out, b_out, a_out = outer_color
    for r in range(radius, 0, -1):
        t = r / radius
        col = (
            int(r_in * (1 - t) + r_out * t),
            int(g_in * (1 - t) + g_out * t),
            int(b_in * (1 - t) + b_out * t),
            int(a_in * (1 - t) + a_out * t),
        )
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

def generate_portrait(filename, name, primary_color, secondary_color, eye_color, hair_color, detail_type):
    size = 512
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # 1. Background Tech Ring / Halo
    cx, cy = size // 2, size // 2 - 20
    for r in range(190, 205):
        alpha = int(120 * (1.0 - abs(r - 197) / 8.0))
        col = (*secondary_color[:3], alpha)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=2)
    
    # Tech tick marks on the ring
    for angle_deg in range(0, 360, 15):
        rad = math.radians(angle_deg)
        x1 = cx + math.cos(rad) * 180
        y1 = cy + math.sin(rad) * 180
        x2 = cx + math.cos(rad) * (205 if angle_deg % 45 == 0 else 195)
        y2 = cy + math.sin(rad) * (205 if angle_deg % 45 == 0 else 195)
        draw.line([(x1, y1), (x2, y2)], fill=(*primary_color[:3], 180), width=2 if angle_deg % 45 == 0 else 1)

    # 2. Heroine Silhouette & Suit (Cutout Bust)
    # Shoulders & Torso armor
    shoulder_poly = [
        (cx - 180, size),
        (cx - 140, cy + 180),
        (cx - 90, cy + 140),
        (cx - 40, cy + 120),
        (cx + 40, cy + 120),
        (cx + 90, cy + 140),
        (cx + 140, cy + 180),
        (cx + 180, size),
    ]
    # Suit base
    draw.polygon(shoulder_poly, fill=(20, 24, 38, 255), outline=(*primary_color[:3], 240))

    # Armor Pauldrons / Plates
    left_pauldron = [
        (cx - 170, size),
        (cx - 135, cy + 175),
        (cx - 85, cy + 145),
        (cx - 110, cy + 220),
        (cx - 160, size)
    ]
    draw.polygon(left_pauldron, fill=(35, 42, 60, 255), outline=(*secondary_color[:3], 255))
    
    right_pauldron = [
        (cx + 170, size),
        (cx + 135, cy + 175),
        (cx + 85, cy + 145),
        (cx + 110, cy + 220),
        (cx + 160, size)
    ]
    draw.polygon(right_pauldron, fill=(35, 42, 60, 255), outline=(*secondary_color[:3], 255))

    # Chest Armor & Power Core Collar
    chest_plate = [
        (cx - 65, cy + 130),
        (cx + 65, cy + 130),
        (cx + 50, cy + 230),
        (cx, cy + 250),
        (cx - 50, cy + 230),
    ]
    draw.polygon(chest_plate, fill=(15, 18, 30, 255), outline=(*primary_color[:3], 255))

    # Glowing Chest Reactor Core
    for r in range(24, 0, -1):
        alpha = int(255 * (1.0 - r / 24.0))
        draw.ellipse([cx - r, cy + 185 - r, cx + r, cy + 185 + r], fill=(*primary_color[:3], alpha))
    draw.ellipse([cx - 6, cy + 185 - 6, cx + 6, cy + 185 + 6], fill=(255, 255, 255, 255))

    # Neck
    neck_poly = [(cx - 24, cy + 85), (cx + 24, cy + 85), (cx + 28, cy + 130), (cx - 28, cy + 130)]
    draw.polygon(neck_poly, fill=(245, 215, 200, 255))
    # Neck tech choker
    draw.rectangle([cx - 27, cy + 110, cx + 27, cy + 124], fill=(25, 30, 45, 255), outline=(*secondary_color[:3], 240))
    draw.ellipse([cx - 4, cy + 117 - 4, cx + 4, cy + 117 + 4], fill=(*primary_color[:3], 255))

    # Head (Anime Style Face)
    chin_point = (cx, cy + 105)
    left_jaw = (cx - 52, cy + 55)
    right_jaw = (cx + 52, cy + 55)
    left_temple = (cx - 56, cy + 15)
    right_temple = (cx + 56, cy + 15)
    face_poly = [left_temple, right_temple, right_jaw, chin_point, left_jaw]
    draw.polygon(face_poly, fill=(255, 228, 215, 255))

    # Blush
    draw.ellipse([cx - 44, cy + 55, cx - 22, cy + 65], fill=(255, 180, 190, 100))
    draw.ellipse([cx + 22, cy + 55, cx + 44, cy + 65], fill=(255, 180, 190, 100))

    # Nose & Mouth
    draw.line([(cx, cy + 68), (cx + 2, cy + 72)], fill=(200, 160, 150, 200), width=2)
    draw.line([(cx - 8, cy + 84), (cx + 8, cy + 84)], fill=(210, 120, 130, 240), width=2)

    # Anime Eyes
    for eye_x, is_right in [(cx - 28, False), (cx + 28, True)]:
        # Upper eyelid (sharp stylish wing)
        draw.arc([eye_x - 18, cy + 28, eye_x + 18, cy + 50], 190, 350, fill=(30, 30, 45, 255), width=4)
        if is_right:
            draw.line([(eye_x + 16, cy + 39), (eye_x + 22, cy + 36)], fill=(30, 30, 45, 255), width=3)
        else:
            draw.line([(eye_x - 16, cy + 39), (eye_x - 22, cy + 36)], fill=(30, 30, 45, 255), width=3)

        # Iris
        draw.ellipse([eye_x - 11, cy + 36, eye_x + 11, cy + 56], fill=(*eye_color[:3], 255))
        # Pupil
        draw.ellipse([eye_x - 5, cy + 42, eye_x + 5, cy + 52], fill=(15, 15, 25, 255))
        # Highlights
        draw.ellipse([eye_x - 6, cy + 38, eye_x - 1, cy + 43], fill=(255, 255, 255, 255))
        draw.ellipse([eye_x + 2, cy + 48, eye_x + 6, cy + 52], fill=(255, 255, 255, 200))

    # Hair Back
    hair_back = [
        (cx - 75, cy + 10),
        (cx - 95, cy + 90),
        (cx - 80, cy + 180),
        (cx + 80, cy + 180),
        (cx + 95, cy + 90),
        (cx + 75, cy + 10),
        (cx, cy - 30)
    ]
    # Hair Bangs & Front
    hair_poly = [
        (cx - 62, cy + 20),
        (cx - 50, cy - 35),
        (cx - 20, cy - 50),
        (cx + 20, cy - 50),
        (cx + 50, cy - 35),
        (cx + 62, cy + 20),
        (cx + 45, cy + 28),
        (cx + 30, cy + 15),
        (cx + 15, cy + 36),
        (cx, cy + 18),
        (cx - 15, cy + 38),
        (cx - 32, cy + 16),
        (cx - 48, cy + 28),
    ]
    draw.polygon(hair_poly, fill=(*hair_color[:3], 255), outline=(*secondary_color[:3], 180))

    # Tactical Gear by Character Type
    if detail_type == "visor":
        # Cyber Visor / Headset over ear
        draw.polygon([(cx + 48, cy + 15), (cx + 68, cy + 20), (cx + 65, cy + 50), (cx + 46, cy + 45)], fill=(20, 25, 40, 255), outline=(*primary_color[:3], 255))
        draw.line([(cx + 55, cy + 35), (cx + 10, cy + 48)], fill=(*primary_color[:3], 220), width=3) # Visor beam
        draw.ellipse([cx + 52, cy + 30, cx + 62, cy + 40], fill=(*primary_color[:3], 255))
    elif detail_type == "monocle":
        # Targeting lens over left eye
        draw.ellipse([cx - 36, cy + 30, cx - 12, cy + 58], outline=(*primary_color[:3], 255), width=2)
        draw.line([(cx - 36, cy + 44), (cx - 48, cy + 44)], fill=(*primary_color[:3], 255), width=2)
    elif detail_type == "goggles":
        # Goggles rested on forehead
        draw.rectangle([cx - 45, cy - 30, cx + 45, cy - 10], fill=(25, 28, 38, 255), outline=(*primary_color[:3], 255), width=2)
        draw.ellipse([cx - 38, cy - 28, cx - 12, cy - 12], fill=(*secondary_color[:3], 200))
        draw.ellipse([cx + 12, cy - 28, cx + 38, cy - 12], fill=(*secondary_color[:3], 200))
    elif detail_type == "halo":
        # Gravity Halo floating
        draw.arc([cx - 70, cy - 80, cx + 70, cy - 30], 0, 360, fill=(*primary_color[:3], 255), width=4)
        draw.ellipse([cx - 6, cy - 58, cx + 6, cy - 52], fill=(255, 255, 255, 255))
    elif detail_type == "antenna":
        # Dual swarm antennas
        draw.line([(cx - 50, cy - 25), (cx - 75, cy - 65)], fill=(*primary_color[:3], 255), width=3)
        draw.ellipse([cx - 80, cy - 70, cx - 70, cy - 60], fill=(*primary_color[:3], 255))
        draw.line([(cx + 50, cy - 25), (cx + 75, cy - 65)], fill=(*primary_color[:3], 255), width=3)
        draw.ellipse([cx + 70, cy - 70, cx + 80, cy - 60], fill=(*primary_color[:3], 255))
    elif detail_type == "android":
        # Facial cyber seams & cryo crystals
        draw.line([(cx - 38, cy + 56), (cx - 44, cy + 80)], fill=(*primary_color[:3], 220), width=2)
        draw.line([(cx + 38, cy + 56), (cx + 44, cy + 80)], fill=(*primary_color[:3], 220), width=2)
        # Holographic HUD shard
        draw.polygon([(cx + 60, cy + 10), (cx + 90, cy + 0), (cx + 95, cy + 40), (cx + 65, cy + 45)], fill=(*primary_color[:3], 60), outline=(*primary_color[:3], 220))

    # Name tag at bottom
    draw.rectangle([cx - 100, size - 36, cx + 100, size - 8], fill=(10, 14, 25, 220), outline=(*primary_color[:3], 255), width=2)
    # Beveled corners on nameplate
    draw.line([(cx - 100, size - 36), (cx - 90, size - 36)], fill=(255, 255, 255, 255), width=2)

    im.save(filename, "PNG")
    print(f"Generated {filename}")

def generate_player_exo_sprite(filename):
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = size // 2, size // 2

    # Thruster Plumes (Behind)
    for r in range(16, 0, -1):
        alpha = int(240 * (1 - r / 16))
        draw.polygon([
            (cx - 14, cy + 30),
            (cx - 24, cy + 45 + r * 1.2),
            (cx - 4, cy + 30)
        ], fill=(0, 200, 255, alpha))
        draw.polygon([
            (cx + 4, cy + 30),
            (cx + 24, cy + 45 + r * 1.2),
            (cx + 14, cy + 30)
        ], fill=(0, 200, 255, alpha))

    # Swept Mecha Wings / Flight Frame
    left_wing = [
        (cx - 12, cy - 10),
        (cx - 52, cy + 18),
        (cx - 46, cy + 32),
        (cx - 18, cy + 16),
        (cx - 8, cy + 24)
    ]
    draw.polygon(left_wing, fill=(28, 35, 52, 255), outline=(0, 240, 255, 255))
    
    right_wing = [
        (cx + 12, cy - 10),
        (cx + 52, cy + 18),
        (cx + 46, cy + 32),
        (cx + 18, cy + 16),
        (cx + 8, cy + 24)
    ]
    draw.polygon(right_wing, fill=(28, 35, 52, 255), outline=(0, 240, 255, 255))

    # Torso & Armored Chassis
    torso_poly = [
        (cx, cy - 38),       # Nose / Helmet tip
        (cx + 16, cy - 16),
        (cx + 18, cy + 18),
        (cx + 10, cy + 32),
        (cx - 10, cy + 32),
        (cx - 18, cy + 18),
        (cx - 16, cy - 16)
    ]
    draw.polygon(torso_poly, fill=(22, 26, 40, 255), outline=(230, 240, 255, 255))

    # Shoulder Cannons
    draw.rectangle([cx - 19, cy - 20, cx - 13, cy + 5], fill=(45, 55, 75, 255), outline=(0, 220, 255, 255))
    draw.rectangle([cx + 13, cy - 20, cx + 19, cy + 5], fill=(45, 55, 75, 255), outline=(0, 220, 255, 255))

    # Visor Glow
    draw.polygon([(cx - 7, cy - 26), (cx + 7, cy - 26), (cx + 4, cy - 20), (cx - 4, cy - 20)], fill=(0, 255, 255, 255))

    # --- HITBOX CORE (CRITICAL DANMAKU RULE) ---
    # Radius: 6px (Diameter 12px) centered at (cx, cy)
    for r in range(14, 0, -1):
        alpha = int(220 * (1 - r / 14))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 255, 255, alpha))
    draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(0, 255, 255, 255), outline=(255, 255, 255, 255), width=1)
    draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255, 255))

    im.save(filename, "PNG")
    print(f"Generated {filename}")

def generate_enemy_sprites():
    # 1. Drone
    size = 96
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = size // 2, size // 2

    # 4 Quad rotor/propulsion pods
    for dx, dy in [(-26, -26), (26, -26), (-26, 26), (26, 26)]:
        draw.ellipse([cx + dx - 10, cy + dy - 10, cx + dx + 10, cy + dy + 10], fill=(20, 20, 30, 255), outline=(255, 60, 60, 255))
        draw.ellipse([cx + dx - 5, cy + dy - 5, cx + dx + 5, cy + dy + 5], fill=(255, 100, 100, 220))
        draw.line([(cx, cy), (cx + dx, cy + dy)], fill=(50, 50, 70, 255), width=3)

    # Central fuselage
    hull = [
        (cx, cy - 22),
        (cx + 20, cy),
        (cx, cy + 22),
        (cx - 20, cy)
    ]
    draw.polygon(hull, fill=(35, 30, 42, 255), outline=(255, 70, 70, 255), width=2)
    # Red Ominous Eye Sensor
    draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 30, 30, 255), outline=(255, 200, 200, 255))
    draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255, 255))
    im.save("assets/enemies/enemy_drone.png", "PNG")

    # 2. Kamikaze (Void Leech)
    size = 80
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = size // 2, size // 2

    # Organic chitin spires
    spikes = [
        (cx, cy - 36),
        (cx + 18, cy - 14),
        (cx + 34, cy + 18),
        (cx + 12, cy + 30),
        (cx, cy + 22),
        (cx - 12, cy + 30),
        (cx - 34, cy + 18),
        (cx - 18, cy - 14)
    ]
    draw.polygon(spikes, fill=(50, 15, 25, 255), outline=(255, 100, 30, 255), width=2)
    # Volatile pulsing bio-reactor
    for r in range(16, 0, -1):
        alpha = int(255 * (1 - r / 16))
        draw.ellipse([cx - r, cy - r + 4, cx + r, cy + r + 4], fill=(255, 120, 0, alpha))
    draw.ellipse([cx - 6, cy - 2, cx + 6, cy + 10], fill=(255, 240, 100, 255))
    im.save("assets/enemies/enemy_kamikaze.png", "PNG")

    # 3. Tank Cruiser (Nebula Cruiser)
    size = 160
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = size // 2, size // 2

    # Heavy warship chassis
    hull = [
        (cx, cy - 65),       # Armored Ramming prow
        (cx + 38, cy - 35),
        (cx + 55, cy + 10),
        (cx + 60, cy + 50),
        (cx + 25, cy + 62),
        (cx - 25, cy + 62),
        (cx - 60, cy + 50),
        (cx - 55, cy + 10),
        (cx - 38, cy - 35)
    ]
    draw.polygon(hull, fill=(24, 28, 42, 255), outline=(130, 160, 210, 255), width=3)
    
    # Armored plates detailing
    draw.polygon([(cx - 30, cy - 20), (cx + 30, cy - 20), (cx + 35, cy + 30), (cx - 35, cy + 30)], fill=(38, 45, 65, 255), outline=(90, 120, 170, 255))
    # Heavy Torpedo Launch Tubes
    draw.rectangle([cx - 48, cy - 10, cx - 36, cy + 25], fill=(15, 18, 25, 255), outline=(255, 160, 40, 255), width=2)
    draw.rectangle([cx + 36, cy - 10, cx + 48, cy + 25], fill=(15, 18, 25, 255), outline=(255, 160, 40, 255), width=2)
    
    # Bridge / Reactor
    draw.ellipse([cx - 18, cy + 5, cx + 18, cy + 41], fill=(40, 180, 255, 200), outline=(255, 255, 255, 255), width=2)
    draw.ellipse([cx - 8, cy + 15, cx + 8, cy + 31], fill=(255, 255, 255, 255))
    im.save("assets/enemies/enemy_tank.png", "PNG")

    # 4. Shield Plate (Orbital Shield)
    im_shield = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    draw_s = ImageDraw.Draw(im_shield)
    # Curved hexagonal shield plate
    poly = [(6, 26), (20, 6), (44, 6), (58, 26), (42, 20), (22, 20)]
    draw_s.polygon(poly, fill=(0, 220, 255, 160), outline=(150, 255, 255, 255), width=2)
    im_shield.save("assets/enemies/shield_plate.png", "PNG")
    print("Generated enemy sprites")

def generate_ui_assets():
    # 1. Sci-Fi 9-patch Panel (128x128)
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    m = 12
    # Semi-transparent dark glass body
    draw.rectangle([m, m, size - m, size - m], fill=(12, 16, 28, 225))
    # Border
    draw.rectangle([m, m, size - m, size - m], outline=(0, 200, 255, 160), width=2)
    # Corner cyber brackets
    c_len = 16
    # Top-Left
    draw.line([(m - 4, m), (m + c_len, m)], fill=(0, 255, 255, 255), width=3)
    draw.line([(m, m - 4), (m, m + c_len)], fill=(0, 255, 255, 255), width=3)
    # Top-Right
    draw.line([(size - m - c_len, m), (size - m + 4, m)], fill=(0, 255, 255, 255), width=3)
    draw.line([(size - m, m - 4), (size - m, m + c_len)], fill=(0, 255, 255, 255), width=3)
    # Bottom-Left
    draw.line([(m - 4, size - m), (m + c_len, size - m)], fill=(0, 255, 255, 255), width=3)
    draw.line([(m, size - m - c_len), (m, size - m + 4)], fill=(0, 255, 255, 255), width=3)
    # Bottom-Right
    draw.line([(size - m - c_len, size - m), (size - m + 4, size - m)], fill=(0, 255, 255, 255), width=3)
    draw.line([(size - m, size - m - c_len), (size - m, size - m + 4)], fill=(0, 255, 255, 255), width=3)
    im.save("assets/ui/panel_scifi.png", "PNG")

    # 2. Sci-Fi Button 9-patch (128x48)
    im_btn = Image.new("RGBA", (128, 48), (0, 0, 0, 0))
    draw_b = ImageDraw.Draw(im_btn)
    # Angled button background
    draw_b.polygon([(6, 42), (6, 12), (18, 6), (122, 6), (122, 36), (110, 42)], fill=(20, 28, 48, 235), outline=(0, 220, 255, 220), width=2)
    draw_b.line([(20, 40), (108, 40)], fill=(0, 255, 255, 255), width=2)
    im_btn.save("assets/ui/button_scifi.png", "PNG")

    # 3. Portrait Frame (512x512)
    im_frame = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw_f = ImageDraw.Draw(im_frame)
    # Hexagonal / chamfered outer frame
    m = 24
    w, h = 512, 512
    outer_poly = [
        (m + 40, m),
        (w - m - 40, m),
        (w - m, m + 40),
        (w - m, h - m - 40),
        (w - m - 40, h - m),
        (m + 40, h - m),
        (m, h - m - 40),
        (m, m + 40)
    ]
    draw_f.polygon(outer_poly, outline=(0, 220, 255, 220), width=3)
    # Corner tech ticks
    for pt in [(m, m+40), (w-m, m+40), (w-m, h-m-40), (m, h-m-40)]:
        draw_f.ellipse([pt[0]-4, pt[1]-4, pt[0]+4, pt[1]+4], fill=(0, 255, 255, 255))
    im_frame.save("assets/ui/portrait_frame.png", "PNG")

    # 4. Weapon & Action Icons (64x64)
    # Laser Icon
    im_laser = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_l = ImageDraw.Draw(im_laser)
    draw_l.ellipse([6, 6, 58, 58], fill=(12, 20, 36, 240), outline=(0, 230, 255, 255), width=2)
    draw_l.line([(12, 52), (52, 12)], fill=(0, 255, 255, 255), width=5)
    draw_l.line([(12, 52), (52, 12)], fill=(255, 255, 255, 255), width=2)
    draw_l.ellipse([28, 28, 36, 36], fill=(255, 255, 255, 255))
    im_laser.save("assets/icons/icon_laser.png", "PNG")

    # Missile Icon
    im_mis = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_m = ImageDraw.Draw(im_mis)
    draw_m.ellipse([6, 6, 58, 58], fill=(12, 20, 36, 240), outline=(255, 170, 30, 255), width=2)
    # Micro missile angled
    draw_m.polygon([(46, 18), (34, 30), (22, 42), (28, 48), (40, 36), (52, 24)], fill=(230, 230, 245, 255), outline=(255, 140, 0, 255))
    draw_m.polygon([(16, 48), (24, 40), (20, 52)], fill=(255, 80, 0, 255))
    im_mis.save("assets/icons/icon_missile.png", "PNG")

    # Bomb Icon
    im_bomb = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_b = ImageDraw.Draw(im_bomb)
    draw_b.ellipse([6, 6, 58, 58], fill=(12, 20, 36, 240), outline=(255, 60, 90, 255), width=2)
    draw_b.ellipse([20, 20, 44, 44], fill=(255, 40, 70, 255), outline=(255, 255, 255, 255), width=2)
    draw_b.ellipse([26, 26, 38, 38], fill=(255, 255, 255, 255))
    im_bomb.save("assets/icons/icon_bomb.png", "PNG")

    # Credit Icon
    im_cred = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_c = ImageDraw.Draw(im_cred)
    draw_c.ellipse([6, 6, 58, 58], fill=(12, 20, 36, 240), outline=(255, 215, 0, 255), width=2)
    # Hex coin
    hex_pts = [(32, 16), (46, 24), (46, 40), (32, 48), (18, 40), (18, 24)]
    draw_c.polygon(hex_pts, fill=(255, 215, 0, 220), outline=(255, 255, 255, 255), width=2)
    draw_c.line([(32, 22), (32, 42)], fill=(40, 30, 0, 255), width=3)
    im_cred.save("assets/icons/icon_credit.png", "PNG")
    print("Generated UI assets")

if __name__ == "__main__":
    # Portraits: Nova, Valentina, Kira, Selene, Roxy, Echo
    generate_portrait(
        "assets/portraits/portrait_nova.png", "NOVA",
        (0, 240, 255, 255), (0, 160, 220, 255), (0, 220, 255, 255), (25, 35, 65, 255), "visor"
    )
    generate_portrait(
        "assets/portraits/portrait_valentina.png", "VALENTINA",
        (255, 65, 85, 255), (255, 180, 50, 255), (255, 80, 80, 255), (145, 45, 30, 255), "monocle"
    )
    generate_portrait(
        "assets/portraits/portrait_kira.png", "KIRA",
        (255, 190, 0, 255), (255, 120, 0, 255), (255, 180, 20, 255), (240, 175, 40, 255), "goggles"
    )
    generate_portrait(
        "assets/portraits/portrait_selene.png", "SELENE",
        (185, 90, 255, 255), (120, 40, 220, 255), (200, 130, 255, 255), (210, 205, 230, 255), "halo"
    )
    generate_portrait(
        "assets/portraits/portrait_roxy.png", "ROXY",
        (50, 240, 120, 255), (20, 180, 90, 255), (80, 255, 140, 255), (40, 130, 75, 255), "antenna"
    )
    generate_portrait(
        "assets/portraits/portrait_echo.png", "ECHO",
        (130, 215, 255, 255), (180, 235, 255, 255), (150, 230, 255, 255), (240, 248, 255, 255), "android"
    )

    generate_player_exo_sprite("assets/characters/player_exo_vanguard.png")
    generate_enemy_sprites()
    generate_ui_assets()
    print("ALL ASSETS GENERATED SUCCESSFULLY!")
