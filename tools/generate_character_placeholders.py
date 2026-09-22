"""
Generador de Placeholders Técnicos de Personajes (Etapa 1 - 1 Frame)
Genera los 24 assets exactos según la guía en docs/art_pipeline_characters_stage1.md:
- 6 Naves (256x256, apuntando hacia ARRIBA, con Hitbox Core en 128,128)
- 6 Armas (128x128, apuntando a la DERECHA)
- 6 Retratos (512x512, cuadrados para UI y HUD)
- 6 Cuerpos Completos (1200x1600, 3:4 para selección y Dialogic 2)
"""

import os
from PIL import Image, ImageDraw, ImageFont

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

CHARACTERS = {
    "nova": {
        "name": "NOVA",
        "title": "Piloto de Vanguardia",
        "primary": (255, 122, 0, 255),       # Naranja neón
        "secondary": (0, 240, 255, 255),     # Cian energético
        "hull": (230, 240, 255, 255),        # Blanco ártico
        "dark": (28, 35, 52, 255),           # Azul espacial oscuro
        "core": (0, 240, 255, 255),          # Cian brillante
        "style": "delta"
    },
    "valentina": {
        "name": "VALENTINA",
        "title": "Francotiradora y Estratega",
        "primary": (0, 102, 255, 255),       # Azul eléctrico
        "secondary": (255, 42, 85, 255),     # Carmesí táctico
        "hull": (20, 22, 32, 255),           # Negro azabache
        "dark": (12, 14, 22, 255),           # Carbón profundo
        "core": (0, 180, 255, 255),          # Prisma azul gélido
        "style": "needle"
    },
    "kira": {
        "name": "KIRA",
        "title": "Ingeniera de Drones",
        "primary": (255, 184, 0, 255),       # Amarillo industrial
        "secondary": (255, 85, 0, 255),      # Naranja advertencia
        "hull": (56, 60, 69, 255),           # Gris grafito
        "dark": (32, 36, 42, 255),           # Gris oscuro
        "core": (255, 215, 0, 255),          # Ámbar brillante
        "style": "industrial"
    },
    "selene": {
        "name": "SELENE",
        "title": "Navegante del Vacío",
        "primary": (142, 60, 216, 255),      # Morado nebulosa
        "secondary": (230, 184, 0, 255),     # Oro estelar
        "hull": (50, 16, 80, 255),           # Púrpura profundo
        "dark": (16, 8, 28, 255),            # Vacío negro
        "core": (200, 120, 255, 255),        # Orbe morado estelar
        "style": "crescent"
    },
    "roxy": {
        "name": "ROXY",
        "title": "Especialista Pesada",
        "primary": (204, 17, 51, 255),       # Carmesí de choque
        "secondary": (168, 109, 50, 255),    # Bronce blindado
        "hull": (34, 38, 46, 255),           # Grafito blindado
        "dark": (18, 20, 26, 255),           # Acero oscuro
        "core": (255, 40, 80, 255),          # Rubí de impacto
        "style": "tank"
    },
    "echo": {
        "name": "ECHO",
        "title": "Androide de Telemetría",
        "primary": (0, 229, 255, 255),       # Cian ciberespacial
        "secondary": (0, 85, 170, 255),      # Azul de datos
        "hull": (245, 250, 255, 255),        # Cerámico blanco
        "dark": (30, 45, 65, 255),           # Sub-chasis
        "core": (0, 255, 255, 255),          # Núcleo cuántico
        "style": "cyber"
    }
}

def generate_ship(cid, cfg, out_path):
    size = 256
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = size // 2, size // 2

    # Motores y Toberas hacia ABAJO (Cy + offset)
    for r in range(18, 0, -2):
        alpha = int(220 * (1 - r / 18))
        glow_color = (cfg["primary"][0], cfg["primary"][1], cfg["primary"][2], alpha)
        draw.polygon([(cx - 24, cy + 50), (cx - 36, cy + 70 + r * 2), (cx - 12, cy + 50)], fill=glow_color)
        draw.polygon([(cx + 24, cy + 50), (cx + 36, cy + 70 + r * 2), (cx + 12, cy + 50)], fill=glow_color)

    # Silueta de Fuselaje según Estilo (apuntando hacia ARRIBA)
    style = cfg["style"]
    if style == "delta":
        # Nova: Interceptor Delta afilado
        wings = [(cx, cy - 90), (cx + 85, cy + 45), (cx + 65, cy + 70), (cx + 25, cy + 55), (cx, cy + 40),
                 (cx - 25, cy + 55), (cx - 65, cy + 70), (cx - 85, cy + 45)]
        draw.polygon(wings, fill=cfg["dark"], outline=cfg["secondary"], width=3)
        body = [(cx, cy - 80), (cx + 30, cy - 10), (cx + 26, cy + 48), (cx - 26, cy + 48), (cx - 30, cy - 10)]
        draw.polygon(body, fill=cfg["hull"], outline=cfg["primary"], width=2)
    elif style == "needle":
        # Valentina: Aguja larga y estilizada
        wings = [(cx, cy - 105), (cx + 70, cy + 30), (cx + 55, cy + 75), (cx + 15, cy + 50), (cx, cy + 40),
                 (cx - 15, cy + 50), (cx - 55, cy + 75), (cx - 70, cy + 30)]
        draw.polygon(wings, fill=cfg["dark"], outline=cfg["primary"], width=2)
        body = [(cx, cy - 100), (cx + 18, cy - 20), (cx + 16, cy + 50), (cx - 16, cy + 50), (cx - 18, cy - 20)]
        draw.polygon(body, fill=cfg["hull"], outline=cfg["secondary"], width=2)
    elif style == "industrial":
        # Kira: Angular asimétrica tipo fragata de drones
        wings = [(cx - 15, cy - 75), (cx + 75, cy - 35), (cx + 85, cy + 45), (cx + 35, cy + 65),
                 (cx - 45, cy + 65), (cx - 85, cy + 30), (cx - 65, cy - 45)]
        draw.polygon(wings, fill=cfg["dark"], outline=cfg["primary"], width=3)
        body = [(cx - 5, cy - 70), (cx + 35, cy - 20), (cx + 35, cy + 50), (cx - 35, cy + 50), (cx - 35, cy - 20)]
        draw.polygon(body, fill=cfg["hull"], outline=cfg["secondary"], width=2)
    elif style == "crescent":
        # Selene: Luna creciente envolvente
        wings = [(cx, cy - 90), (cx + 80, cy - 20), (cx + 70, cy + 60), (cx + 30, cy + 30), (cx, cy + 45),
                 (cx - 30, cy + 30), (cx - 70, cy + 60), (cx - 80, cy - 20)]
        draw.polygon(wings, fill=cfg["dark"], outline=cfg["secondary"], width=3)
        body = [(cx, cy - 75), (cx + 25, cy - 10), (cx + 20, cy + 45), (cx - 20, cy + 45), (cx - 25, cy - 10)]
        draw.polygon(body, fill=cfg["hull"], outline=cfg["primary"], width=2)
    elif style == "tank":
        # Roxy: Acorazado ariete blindado
        wings = [(cx, cy - 65), (cx + 75, cy - 30), (cx + 80, cy + 60), (cx + 35, cy + 65), (cx, cy + 50),
                 (cx - 35, cy + 65), (cx - 80, cy + 60), (cx - 75, cy - 30)]
        draw.polygon(wings, fill=cfg["dark"], outline=cfg["secondary"], width=4)
        body = [(cx, cy - 60), (cx + 45, cy - 15), (cx + 40, cy + 55), (cx - 40, cy + 55), (cx - 45, cy - 15)]
        draw.polygon(body, fill=cfg["hull"], outline=cfg["primary"], width=3)
    else:
        # Echo: Aguja cuántica minimalista
        wings = [(cx, cy - 95), (cx + 65, cy + 25), (cx + 50, cy + 65), (cx + 18, cy + 45), (cx, cy + 35),
                 (cx - 18, cy + 45), (cx - 50, cy + 65), (cx - 65, cy + 25)]
        draw.polygon(wings, fill=cfg["dark"], outline=cfg["primary"], width=2)
        body = [(cx, cy - 90), (cx + 20, cy - 15), (cx + 16, cy + 45), (cx - 16, cy + 45), (cx - 20, cy - 15)]
        draw.polygon(body, fill=cfg["hull"], outline=cfg["secondary"], width=2)

    # HITBOX CORE EN (128, 128) - SAGRADO PARA BULLET HELL
    for r in range(16, 0, -2):
        alpha = int(220 * (1 - r / 16))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(cfg["core"][0], cfg["core"][1], cfg["core"][2], alpha))
    draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(255, 255, 255, 255), outline=cfg["primary"], width=2)
    draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255, 255))

    # Indicador sutil de placeholder
    draw.text((12, 12), f"{cfg['name']} SHIP", fill=cfg["primary"])
    im.save(out_path, "PNG")
    print(f"Generated Ship: {out_path}")

def generate_weapon(cid, cfg, out_path):
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cy = size // 2

    # Arma apuntando a la DERECHA (+X). Montura/pivote en X=32, Cy=64
    # Soporte base de montura
    draw.polygon([(20, cy - 14), (40, cy - 10), (40, cy + 10), (20, cy + 14)], fill=cfg["dark"], outline=cfg["secondary"], width=2)
    # Cuerpo principal y cañón
    draw.polygon([(36, cy - 12), (105, cy - 6), (115, cy), (105, cy + 6), (36, cy + 12)], fill=cfg["hull"], outline=cfg["primary"], width=2)
    # Boca de fuego / Cañón
    draw.rectangle([102, cy - 4, 118, cy + 4], fill=cfg["primary"])
    # Celda de energía / Brillo
    for r in range(10, 0, -2):
        alpha = int(200 * (1 - r / 10))
        draw.ellipse([55 - r, cy - r, 55 + r, cy + r], fill=(cfg["core"][0], cfg["core"][1], cfg["core"][2], alpha))
    draw.ellipse([51, cy - 4, 59, cy + 4], fill=(255, 255, 255, 255))

    draw.text((8, 8), f"{cfg['name']} WPN", fill=cfg["primary"])
    im.save(out_path, "PNG")
    print(f"Generated Weapon: {out_path}")

def generate_portrait(cid, cfg, out_path):
    size = 512
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = size // 2, size // 2

    # Marco tecnológico Sci-Fi
    m = 24
    outer = [(m + 40, m), (size - m - 40, m), (size - m, m + 40), (size - m, size - m - 40),
             (size - m - 40, size - m), (m + 40, size - m), (m, size - m - 40), (m, m + 40)]
    draw.polygon(outer, fill=(12, 16, 26, 240), outline=cfg["primary"], width=4)
    draw.polygon([(p[0]+8 if p[0]<cx else p[0]-8, p[1]+8 if p[1]<cy else p[1]-8) for p in outer], outline=cfg["secondary"], width=1)

    # Silueta de Piloto estilizada (Busto)
    # Hombros
    draw.polygon([(cx - 140, size - m - 10), (cx - 70, cy + 90), (cx + 70, cy + 90), (cx + 140, size - m - 10)],
                 fill=cfg["dark"], outline=cfg["primary"], width=3)
    # Cuello / Traje
    draw.polygon([(cx - 35, cy + 95), (cx + 35, cy + 95), (cx + 25, cy + 40), (cx - 25, cy + 40)], fill=cfg["hull"])
    # Cabeza / Rostro
    draw.polygon([(cx, cy - 80), (cx + 55, cy - 35), (cx + 45, cy + 35), (cx, cy + 65), (cx - 45, cy + 35), (cx - 55, cy - 35)],
                 fill=(245, 225, 215, 255), outline=cfg["primary"], width=2)
    # Cabello característico
    draw.polygon([(cx, cy - 95), (cx + 70, cy - 50), (cx + 65, cy + 10), (cx + 40, cy - 30),
                  (cx, cy - 40), (cx - 40, cy - 30), (cx - 65, cy + 10), (cx - 70, cy - 50)],
                 fill=cfg["primary"], outline=cfg["secondary"], width=2)

    # Visor / Accesorio característico
    draw.polygon([(cx - 38, cy - 10), (cx + 38, cy - 10), (cx + 32, cy + 10), (cx - 32, cy + 10)],
                 fill=cfg["secondary"])

    # Rótulo de identidad
    draw.text((m + 30, size - m - 45), cfg["name"], fill=cfg["primary"])
    draw.text((m + 30, size - m - 28), cfg["title"].upper(), fill=(200, 210, 230, 220))

    im.save(out_path, "PNG")
    print(f"Generated Portrait: {out_path}")

def generate_fullbody(cid, cfg, out_path):
    w, h = 1200, 1600
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx, cy = w // 2, h // 2

    # Fondo tecnológico semitransparente para previsualización clara
    # Marco de coordenadas tácticas
    m = 40
    draw.rectangle([m, m, w - m, h - m], outline=(cfg["primary"][0], cfg["primary"][1], cfg["primary"][2], 120), width=3)
    # Marcas angulares cibernéticas
    for corner in [(m, m), (w - m, m), (w - m, h - m), (m, h - m)]:
        draw.rectangle([corner[0]-8, corner[1]-8, corner[0]+8, corner[1]+8], fill=cfg["primary"])

    # Silueta de Heroína de Cuerpo Entero estilizada (3/4 de pie)
    # Pies / Botas
    draw.polygon([(cx - 90, h - 180), (cx - 40, h - 120), (cx - 100, h - 110)], fill=cfg["dark"], outline=cfg["primary"], width=2)
    draw.polygon([(cx + 40, h - 180), (cx + 90, h - 120), (cx + 30, h - 110)], fill=cfg["dark"], outline=cfg["primary"], width=2)
    # Piernas
    draw.polygon([(cx - 85, cy + 220), (cx - 20, cy + 220), (cx - 35, h - 180), (cx - 80, h - 180)], fill=cfg["hull"], outline=cfg["secondary"], width=2)
    draw.polygon([(cx + 20, cy + 220), (cx + 85, cy + 220), (cx + 80, h - 180), (cx + 35, h - 180)], fill=cfg["hull"], outline=cfg["secondary"], width=2)
    # Caderas / Cinturón táctico
    draw.polygon([(cx - 110, cy + 180), (cx + 110, cy + 180), (cx + 90, cy + 240), (cx - 90, cy + 240)], fill=cfg["dark"], outline=cfg["primary"], width=3)
    # Torso / Pechera con Reactor Core
    draw.polygon([(cx - 120, cy - 80), (cx + 120, cy - 80), (cx + 100, cy + 180), (cx - 100, cy + 180)], fill=cfg["hull"], outline=cfg["primary"], width=4)
    # Core en el pecho de la chica
    for r in range(35, 0, -5):
        alpha = int(220 * (1 - r / 35))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(cfg["core"][0], cfg["core"][1], cfg["core"][2], alpha))
    draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(255, 255, 255, 255))

    # Brazos y hombreras
    draw.polygon([(cx - 170, cy - 70), (cx - 110, cy - 90), (cx - 100, cy + 90), (cx - 150, cy + 120)], fill=cfg["dark"], outline=cfg["secondary"], width=2)
    draw.polygon([(cx + 110, cy - 90), (cx + 170, cy - 70), (cx + 150, cy + 120), (cx + 100, cy + 90)], fill=cfg["dark"], outline=cfg["secondary"], width=2)

    # Cuello y Cabeza
    draw.rectangle([cx - 30, cy - 140, cx + 30, cy - 80], fill=(245, 225, 215, 255))
    draw.polygon([(cx, cy - 300), (cx + 90, cy - 220), (cx + 70, cy - 120), (cx, cy - 80), (cx - 70, cy - 120), (cx - 90, cy - 220)],
                 fill=(245, 225, 215, 255), outline=cfg["primary"], width=3)
    # Cabello y visor estilizados
    draw.polygon([(cx, cy - 330), (cx + 120, cy - 250), (cx + 100, cy - 100), (cx + 50, cy - 160),
                  (cx, cy - 180), (cx - 50, cy - 160), (cx - 100, cy - 100), (cx - 120, cy - 250)],
                 fill=cfg["primary"], outline=cfg["secondary"], width=3)
    draw.polygon([(cx - 60, cy - 200), (cx + 60, cy - 200), (cx + 50, cy - 150), (cx - 50, cy - 150)],
                 fill=cfg["secondary"])

    # Cartela de Especificación Técnica
    draw.text((m + 60, m + 60), f"PILOT DOSSIER: {cfg['name']}", fill=cfg["primary"])
    draw.text((m + 60, m + 90), f"CLASS: {cfg['title'].upper()}", fill=(220, 230, 245, 240))
    draw.text((m + 60, m + 120), "STATUS: 1-FRAME PLACEHOLDER [READY FOR ART OVERWRITE]", fill=(180, 200, 220, 180))

    im.save(out_path, "PNG")
    print(f"Generated Fullbody: {out_path}")

def main():
    base_ships = "assets/characters/ships"
    base_weapons = "assets/characters/weapons"
    base_portraits = "assets/characters/portraits"
    base_fullbody = "assets/characters/fullbody"

    for p in [base_ships, base_weapons, base_portraits, base_fullbody]:
        ensure_dir(p)

    for cid, cfg in CHARACTERS.items():
        generate_ship(cid, cfg, f"{base_ships}/ship_{cid}.png")
        generate_weapon(cid, cfg, f"{base_weapons}/weapon_{cid}.png")
        generate_portrait(cid, cfg, f"{base_portraits}/portrait_{cid}.png")
        generate_fullbody(cid, cfg, f"{base_fullbody}/fullbody_{cid}.png")

    print("\n✓ 24 CHARACTER PLACEHOLDERS GENERATED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
