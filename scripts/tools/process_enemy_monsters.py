"""
process_enemy_monsters.py
Pipeline de procesamiento chromakey para los monstruos Lovecraftianos de Astra Dream.
Convierte las imágenes crudas generadas con Gemini a sprites PNG transparentes de alta resolución (1024px)
centrados en un lienzo transparente con margen de seguridad (72px) para que los shaders de silueta
y las partículas de combate nunca generen artefactos de recorte ni bandas en los bordes.
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

# Agregar directorio actual al sys.path para importar chromakey_extractor
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from chromakey_extractor import process_chromakey, parse_hex_color

PROJECT_ROOT = SCRIPT_DIR.parent.parent
RAW_DIR = PROJECT_ROOT / "assets" / "enemies" / "raw"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "sprites" / "enemies"

MONSTER_CONFIGS = [
    {
        "id": "enemy_shooter",
        "raw_file": "raw_enemy_shooter.jpg",
        "out_file": "enemy_shooter.png",
        "color": "#DE02DE",  # Magenta chromakey
        "tolerance": 65.0,
        "softness": 25.0,
        "feather": 1.0,
        "brightness": 1.15,
        "contrast": 1.08,
    },
    {
        "id": "enemy_kamikaze",
        "raw_file": "raw_enemy_kamikaze.jpg",
        "out_file": "enemy_kamikaze.png",
        "color": "#07F907",  # Neon green chromakey
        "tolerance": 65.0,
        "softness": 25.0,
        "feather": 1.0,
        "brightness": 1.25,
        "contrast": 1.10,
    },
    {
        "id": "enemy_tank",
        "raw_file": "raw_enemy_tank.jpg",
        "out_file": "enemy_tank.png",
        "color": "#06F804",  # Neon green chromakey
        "tolerance": 65.0,
        "softness": 25.0,
        "feather": 1.0,
        "brightness": 1.30,
        "contrast": 1.12,
    },
    {
        "id": "enemy_rainbow",
        "raw_file": "raw_enemy_rainbow.jpg",
        "out_file": "enemy_rainbow.png",
        "color": "#08F405",  # Neon green chromakey
        "tolerance": 65.0,
        "softness": 25.0,
        "feather": 1.0,
        "brightness": 1.20,
        "contrast": 1.08,
    },
]


def post_process_canvas(png_path: str, brightness: float = 1.15, contrast: float = 1.08) -> None:
    """Asegura un lienzo 1024x1024 con margen transparente limpio de 72px y brillo óptimo para espacio."""
    img = Image.open(png_path).convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        cropped = img.crop(bbox)
    else:
        cropped = img

    # Escalar para que quepa cómodamente en 880x880 dejando 72px de margen perimetral
    target_dim = 880
    cw, ch = cropped.size
    scale = target_dim / max(cw, ch)
    new_w = int(cw * scale)
    new_h = int(ch * scale)
    scaled = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Mejorar brillo y contraste para visibilidad contra el fondo espacial oscuro
    r, g, b, a = scaled.split()
    rgb_img = Image.merge("RGB", (r, g, b))
    if brightness != 1.0:
        enh_b = ImageEnhance.Brightness(rgb_img)
        rgb_img = enh_b.enhance(brightness)
    if contrast != 1.0:
        enh_c = ImageEnhance.Contrast(rgb_img)
        rgb_img = enh_c.enhance(contrast)

    er, eg, eb = rgb_img.split()
    enhanced = Image.merge("RGBA", (er, eg, eb, a))

    # Pegar centrado en lienzo 1024x1024 completamente transparente
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    paste_x = (1024 - new_w) // 2
    paste_y = (1024 - new_h) // 2
    canvas.paste(enhanced, (paste_x, paste_y), enhanced)

    # Limpiar cualquier pixel con alpha == 0 a (0, 0, 0, 0) absoluto
    c_pixels = canvas.load()
    for y in range(1024):
        for x in range(1024):
            pr, pg, pb, pa = c_pixels[x, y]
            if pa == 0:
                c_pixels[x, y] = (0, 0, 0, 0)

    canvas.save(png_path, "PNG", optimize=True)
    print(f"  -> Post-procesado final en lienzo 1024x1024 con margen limpio: {png_path}")


def main() -> None:
    print("=== Iniciando pipeline de extracción chromakey de monstruos ===")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    all_success = True

    for cfg in MONSTER_CONFIGS:
        in_path = RAW_DIR / cfg["raw_file"]
        out_path = OUTPUT_DIR / cfg["out_file"]

        if not in_path.exists():
            print(f"[ERROR] Archivo fuente no encontrado: {in_path}")
            all_success = False
            continue

        print(f"\nProcesando {cfg['id']} desde {cfg['raw_file']}...")
        rgb_color = parse_hex_color(cfg["color"])
        ok = process_chromakey(
            input_path=str(in_path),
            output_path=str(out_path),
            key_color_rgb=rgb_color,
            tolerance=cfg["tolerance"],
            softness=cfg["softness"],
            feather_radius=cfg["feather"],
            despill=True,
            trim=True,
            target_max_size=1024,
        )
        if not ok:
            all_success = False
            continue

        # Post-procesar con margen y luminosidad
        post_process_canvas(
            str(out_path),
            brightness=cfg.get("brightness", 1.15),
            contrast=cfg.get("contrast", 1.08),
        )

    if all_success:
        print("\n[ÉXITO] Los 4 monstruos fueron procesados y guardados en assets/sprites/enemies/")
    else:
        print("\n[ADVERTENCIA] Algunos monstruos presentaron errores durante el procesamiento.")
        sys.exit(1)


if __name__ == "__main__":
    main()
