#!/usr/bin/env python3
"""
Astra Dream — Mass Skin Chroma Generator
Genera variantes de color (chromas / skins) a partir de una única ilustración base,
protegiendo automáticamente tonos de piel, ojos y neutrales faciales.
"""

import os
import sys
import argparse
import colorsys
from PIL import Image

# Presets de variantes de estilo y paleta
CHROMA_PALETTES = {
    "void": {
        "hue_target": 0.77,       # Púrpura / Amatista cósmico
        "sat_mult": 1.15,
        "val_mult": 0.90,
        "desc": "Armadura oscura abisal con acentos violeta brillante"
    },
    "neon": {
        "hue_target": 0.50,       # Cian / Turquesa Cyberpunk
        "sat_mult": 1.35,
        "val_mult": 1.05,
        "desc": "Acentos de neón brillante sobre gris grafito"
    },
    "solar": {
        "hue_target": 0.11,       # Dorado / Ámbar solar
        "sat_mult": 1.20,
        "val_mult": 1.10,
        "desc": "Placas de oro resplandeciente con núcleos de fusión ámbar"
    },
    "crimson": {
        "hue_target": 0.98,       # Rojo carmesí / Rubí intenso
        "sat_mult": 1.30,
        "val_mult": 0.95,
        "desc": "Carrocería carmesí de combate con remates en ónix"
    },
    "emerald": {
        "hue_target": 0.38,       # Verde esmeralda / Jade cuántico
        "sat_mult": 1.15,
        "val_mult": 1.00,
        "desc": "Blindaje de jade refinado y líneas de poder esmeralda"
    },
    "amethyst": {
        "hue_target": 0.83,       # Magenta / Orquídea eléctrica
        "sat_mult": 1.25,
        "val_mult": 1.05,
        "desc": "Superficies iridiscentes en tono magenta de alta frecuencia"
    }
}

def is_skin_or_eye_pixel(h: float, s: float, v: float) -> bool:
    """
    Detecta si un píxel pertenece a tonos de piel humana / anime o partes neutras de los ojos.
    """
    # 1. Piel cálida estándar (Tono naranja-melocotón a dorado suave)
    # Hue ~ 10° a 45° (0.027 a 0.125 en float)
    if 0.025 <= h <= 0.13:
        if 0.12 <= s <= 0.68 and v >= 0.35:
            return True

    # 2. Blancos de ojos y brillos reflejados (Casi acromáticos muy luminosos)
    if s < 0.08 and v > 0.88:
        return True

    # 3. Pupilas / Sombras neutras profundas del iris (Negros puros)
    if v < 0.12:
        return True

    return False

def generate_chroma_image(
    base_img: Image.Image,
    palette_info: dict,
    preserve_skin: bool = True
) -> Image.Image:
    """
    Aplica una modulación de color a las partes no protegidas del sprite.
    """
    img = base_img.convert("RGBA")
    pixels = img.load()
    width, height = img.size

    target_hue = palette_info["hue_target"]
    sat_mult = palette_info.get("sat_mult", 1.0)
    val_mult = palette_info.get("val_mult", 1.0)

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h, s, v = colorsys.rgb_to_hsv(rf, gf, bf)

            # Si es piel u ojos y la protección está activa, preservar intacto
            if preserve_skin and is_skin_or_eye_pixel(h, s, v):
                continue

            # Para partes metálicas, ropa, armadura, alas y efectos:
            # Reasignar el tono manteniendo la textura luminosa original
            new_h = target_hue
            new_s = max(0.0, min(1.0, s * sat_mult))
            new_v = max(0.0, min(1.0, v * val_mult))

            # Si el píxel original era casi gris neutro (armadura blanca/negra),
            # otorgarle un tinte sutil de la nueva paleta
            if s < 0.10 and v > 0.20:
                new_s = min(0.35, new_s + 0.18)

            nr, ng, nb = colorsys.hsv_to_rgb(new_h, new_s, new_v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

    return img

def main():
    parser = argparse.ArgumentParser(description="Genera en lote variantes de color (chromas) de un sprite preservando piel y ojos.")
    parser.add_argument("--input", "-i", required=True, help="Ruta de la imagen base transparente (PNG).")
    parser.add_argument("--output_dir", "-o", default="output_chromas", help="Directorio destino para guardar los chromas.")
    parser.add_argument("--no_skin_mask", action="store_true", help="Desactiva la máscara de protección de piel.")
    parser.add_argument("--palettes", "-p", nargs="*", default=list(CHROMA_PALETTES.keys()),
                        help=f"Paletas a generar. Opciones: {list(CHROMA_PALETTES.keys())}")

    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Error: Archivo no encontrado: {args.input}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.output_dir, exist_ok=True)
    base_name = os.path.splitext(os.path.basename(args.input))[0]
    base_img = Image.open(args.input)

    print(f"Generando variantes para: {args.input}")
    print(f"Máscara de protección de piel y ojos: {'DESACTIVADA' if args.no_skin_mask else 'ACTIVA'}")

    for pal_name in args.palettes:
        if pal_name not in CHROMA_PALETTES:
            print(f"Aviso: Paleta '{pal_name}' desconocida, omitiendo.")
            continue

        pal = CHROMA_PALETTES[pal_name]
        chroma_img = generate_chroma_image(base_img, pal, preserve_skin=not args.no_skin_mask)
        out_filename = f"{base_name}_{pal_name}.png"
        out_path = os.path.join(args.output_dir, out_filename)
        chroma_img.save(out_path, "PNG")
        print(f"  ✓ [{pal_name.upper()}]: {out_path} ({pal['desc']})")

    print("\n¡Generación en lote completada con éxito!")

if __name__ == "__main__":
    main()
