#!/usr/bin/env python3
"""
tools/test_skin_methods.py
Banco de pruebas comparativo de técnicas avanzadas de recoloreo de skins para Astra Dream.
Procesa un sprite base y una máscara Color ID (Rojo=Ropa, Verde=Pelo, Azul=Ojos)
y genera una comparativa de los 4 métodos:
  1. Gradient Mapping (Anime Cel-Shading estilizado)
  2. Emisivo / Bloom Aditivo (Ojos incandescentes y traje táctico)
  3. Modo Oscuro / Platino (Blindaje fibra de carbono / titanio + pelo platino)
  4. Iridiscente / Prisma (Split-toning holográfico)
"""

import os
import sys
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELECTION_DIR = os.path.join(BASE_DIR, "assets", "characters", "selection")
DEFAULT_BASE = os.path.join(SELECTION_DIR, "selection_nova.png")
DEFAULT_MASK = os.path.join(SELECTION_DIR, "selection_nova_mask.png")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "recolors", "test_comparison")


def extract_masks(mask_img: Image.Image) -> tuple[Image.Image, Image.Image, Image.Image]:
    """
    Separa la máscara Color ID Map en 3 máscaras de 8-bit en escala de grises:
    Ropa (Rojo), Pelo (Verde) y Ojos (Azul), considerando el canal alfa si existe.
    """
    mask_rgba = mask_img.convert("RGBA")
    mr, mg, mb, ma = mask_rgba.split()

    # Rojo dominante = Ropa (R - (G + B))
    clothes = ImageChops.subtract(mr, ImageChops.add(mg, mb))
    # Verde dominante = Pelo (G - (R + B))
    hair = ImageChops.subtract(mg, ImageChops.add(mr, mb))
    # Azul dominante = Ojos (B - (R + G))
    eyes = ImageChops.subtract(mb, ImageChops.add(mr, mg))

    # Si hay canal alfa en la máscara, recortar por transparencia
    clothes = ImageChops.multiply(clothes, ma)
    hair = ImageChops.multiply(hair, ma)
    eyes = ImageChops.multiply(eyes, ma)

    # Suavizado sub-píxel para evitar bordes dentados
    clothes = clothes.filter(ImageFilter.GaussianBlur(0.8))
    hair = hair.filter(ImageFilter.GaussianBlur(0.8))
    eyes = eyes.filter(ImageFilter.GaussianBlur(0.5))

    return clothes, hair, eyes


def apply_gradient_mapping(
    base_rgb: Image.Image,
    mask: Image.Image,
    black_rgb: tuple[int, int, int],
    mid_rgb: tuple[int, int, int],
    white_rgb: tuple[int, int, int],
    blend_strength: float = 0.90
) -> Image.Image:
    """Aplica rampa de degradado de 3 puntos (sombras, medios, brillos)."""
    gray = ImageOps.grayscale(base_rgb)
    colored = ImageOps.colorize(gray, black=black_rgb, mid=mid_rgb, white=white_rgb)
    blended = Image.blend(base_rgb, colored, blend_strength)
    return Image.composite(blended, base_rgb, mask)


def apply_dark_mode(
    base_rgb: Image.Image,
    mask: Image.Image,
    tint_rgb: tuple[int, int, int] = (25, 30, 45),
    contrast_power: float = 1.6
) -> Image.Image:
    """Modo oscuro / titanio: preserva oclusión y brillos pero oscurece tonos medios."""
    gray = ImageOps.grayscale(base_rgb)
    # Tabla LUT que comprime tonos medios hacia carbón y mantiene brillos especulares
    lut = [int(pow(x / 255.0, contrast_power) * 160) for x in range(256)]
    dark_gray = gray.point(lut)
    tinted_dark = ImageOps.colorize(
        dark_gray,
        black=(5, 5, 8),
        mid=tint_rgb,
        white=(210, 220, 240)
    )
    return Image.composite(tinted_dark, base_rgb, mask)


def apply_platinum_hair(
    base_rgb: Image.Image,
    mask: Image.Image,
    shadow_rgb: tuple[int, int, int] = (160, 165, 195)
) -> Image.Image:
    """Convierte el cabello a platino anime con sombras violeta/grisáceas."""
    gray = ImageOps.grayscale(base_rgb)
    lut = [min(255, int(pow(x / 255.0, 0.7) * 220 + 35)) for x in range(256)]
    bright_gray = gray.point(lut)
    platinum = ImageOps.colorize(
        bright_gray,
        black=shadow_rgb,
        mid=(230, 235, 245),
        white=(255, 255, 255)
    )
    return Image.composite(platinum, base_rgb, mask)


def apply_emissive_bloom(
    base_rgb: Image.Image,
    mask: Image.Image,
    glow_rgb: tuple[int, int, int],
    blur_radius: float = 7.0,
    intensity: float = 1.4
) -> Image.Image:
    """Añade efecto de resplandor emisivo (bloom aditivo) en ojos o reactores."""
    w, h = base_rgb.size
    # Crear capa emisiva pura
    glow_solid = Image.new("RGB", (w, h), glow_rgb)
    glow_core = Image.composite(glow_solid, Image.new("RGB", (w, h), (0, 0, 0)), mask)

    # Multiplicar exposición del núcleo
    gray = ImageOps.grayscale(glow_core)
    boosted = gray.point(lambda p: min(255, int(p * intensity)))
    glow_core_boosted = ImageOps.colorize(boosted, black=(0, 0, 0), white=glow_rgb)

    # Difuminar para crear el aura de Bloom
    glow_blur = glow_core_boosted.filter(ImageFilter.GaussianBlur(blur_radius))

    # Fusión aditiva (Screen)
    with_core = Image.composite(glow_core_boosted, base_rgb, mask)
    final_rgb = ImageChops.screen(with_core, glow_blur)
    return final_rgb


def run_comparison(base_path: str = DEFAULT_BASE, mask_path: str = DEFAULT_MASK):
    if not os.path.exists(base_path):
        print(f"Error: No se encontró la imagen base: {base_path}")
        return False
    if not os.path.exists(mask_path):
        print(f"Esperando máscara... No encontrada aún en: {mask_path}")
        return False

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    base_img = Image.open(base_path).convert("RGBA")
    mask_img = Image.open(mask_path).convert("RGBA")

    # Validar dimensiones coincidentes
    if base_img.size != mask_img.size:
        print(f"Aviso: Redimensionando máscara {mask_img.size} a tamaño base {base_img.size}")
        mask_img = mask_img.resize(base_img.size, Image.Resampling.NEAREST)

    base_rgb = base_img.convert("RGB")
    alpha = base_img.split()[3]

    clothes_m, hair_m, eyes_m = extract_masks(mask_img)

    # -------------------------------------------------------------
    # Método 1: Gradient Mapping (Anime Cel-Shading)
    # Paleta: Cian Neón / Cyberpunk Estilizado
    # -------------------------------------------------------------
    m1 = base_rgb.copy()
    # Ropa: Azul noche profundo -> Cian eléctrico -> Blanco menta
    m1 = apply_gradient_mapping(
        m1, clothes_m,
        black_rgb=(10, 22, 45),
        mid_rgb=(0, 215, 245),
        white_rgb=(235, 255, 255),
        blend_strength=0.92
    )
    # Pelo: Violeta cósmico profundo -> Magenta neón -> Rosa pastel
    m1 = apply_gradient_mapping(
        m1, hair_m,
        black_rgb=(35, 10, 48),
        mid_rgb=(235, 45, 160),
        white_rgb=(255, 215, 240),
        blend_strength=0.88
    )
    # Ojos: Turquesa brillante
    m1 = apply_gradient_mapping(
        m1, eyes_m,
        black_rgb=(0, 40, 50),
        mid_rgb=(0, 255, 230),
        white_rgb=(255, 255, 255)
    )
    res_m1 = Image.merge("RGBA", (*m1.split(), alpha))
    res_m1.save(os.path.join(OUTPUT_DIR, "method1_gradient_mapping.png"))

    # -------------------------------------------------------------
    # Método 2: Emisivo & Bloom Aditivo (Mirada y Luces de Energía)
    # Paleta: Solar Gold / Fusión Radiante
    # -------------------------------------------------------------
    m2 = base_rgb.copy()
    # Ropa con rampa ámbar dorado
    m2 = apply_gradient_mapping(
        m2, clothes_m,
        black_rgb=(40, 25, 5),
        mid_rgb=(255, 180, 0),
        white_rgb=(255, 248, 220),
        blend_strength=0.85
    )
    # Pelo castaño oscuro con brillo ámbar
    m2 = apply_gradient_mapping(
        m2, hair_m,
        black_rgb=(20, 15, 10),
        mid_rgb=(110, 75, 45),
        white_rgb=(255, 220, 170),
        blend_strength=0.80
    )
    # Ojos con efecto Emisivo Bloom (resplandor de energía dorada incandescente)
    m2 = apply_emissive_bloom(
        m2, eyes_m,
        glow_rgb=(255, 220, 40),
        blur_radius=8.0,
        intensity=1.5
    )
    res_m2 = Image.merge("RGBA", (*m2.split(), alpha))
    res_m2.save(os.path.join(OUTPUT_DIR, "method2_emissive_bloom.png"))

    # -------------------------------------------------------------
    # Método 3: Modo Oscuro / Platino (Titanio / Fibra de Carbono)
    # Paleta: Stealth Ops / Void Elite
    # -------------------------------------------------------------
    m3 = base_rgb.copy()
    # Ropa en negro carbón / titanio mate
    m3 = apply_dark_mode(m3, clothes_m, tint_rgb=(22, 28, 42), contrast_power=1.7)
    # Pelo blanco platino anime
    m3 = apply_platinum_hair(m3, hair_m, shadow_rgb=(145, 150, 185))
    # Ojos carmesí brillante con halo
    m3 = apply_emissive_bloom(
        m3, eyes_m,
        glow_rgb=(255, 30, 80),
        blur_radius=6.0,
        intensity=1.6
    )
    res_m3 = Image.merge("RGBA", (*m3.split(), alpha))
    res_m3.save(os.path.join(OUTPUT_DIR, "method3_dark_mode_platinum.png"))

    # -------------------------------------------------------------
    # Método 4: Iridiscente / Prisma (Split-Toning Holográfico)
    # Paleta: Cuarzo Místico / Camaleón Cósmico
    # -------------------------------------------------------------
    m4 = base_rgb.copy()
    # Ropa: Sombras verde azulado profundo -> Medios amatista -> Brillos oro solar
    m4 = apply_gradient_mapping(
        m4, clothes_m,
        black_rgb=(10, 50, 60),      # Sombra esmeralda oscura
        mid_rgb=(185, 80, 240),      # Amatista vibrante
        white_rgb=(255, 235, 140),   # Brillo oro
        blend_strength=0.92
    )
    # Pelo iridiscente: Sombras violeta abisal -> Medios cian prisma -> Brillos lila
    m4 = apply_gradient_mapping(
        m4, hair_m,
        black_rgb=(45, 10, 75),
        mid_rgb=(40, 210, 220),
        white_rgb=(255, 195, 245),
        blend_strength=0.90
    )
    # Ojos esmeralda cuántico
    m4 = apply_emissive_bloom(
        m4, eyes_m,
        glow_rgb=(50, 255, 180),
        blur_radius=7.0,
        intensity=1.4
    )
    res_m4 = Image.merge("RGBA", (*m4.split(), alpha))
    res_m4.save(os.path.join(OUTPUT_DIR, "method4_iridescent_prism.png"))

    # -------------------------------------------------------------
    # Generar collage comparativo 2x2 para inspección rápida
    # -------------------------------------------------------------
    thumb_w, thumb_h = 450, 600
    grid = Image.new("RGBA", (thumb_w * 4, thumb_h), (20, 22, 28, 255))
    images = [
        ("1. Gradient Mapping", res_m1),
        ("2. Emissive Bloom", res_m2),
        ("3. Dark Ops Platino", res_m3),
        ("4. Iridiscente Prisma", res_m4)
    ]
    for idx, (label, img) in enumerate(images):
        thumb = img.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        grid.paste(thumb, (idx * thumb_w, 0), thumb)

    grid_path = os.path.join(OUTPUT_DIR, "comparison_grid.png")
    grid.save(grid_path)

    print("¡Comparativa generada con éxito!")
    print(f"Destino: {OUTPUT_DIR}")
    print(f"Collage: {grid_path}")
    return True


if __name__ == "__main__":
    base = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_BASE
    mask = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_MASK
    run_comparison(base, mask)
