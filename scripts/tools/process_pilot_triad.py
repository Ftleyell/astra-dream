#!/usr/bin/env python3
"""
Astra Dream — Process Pilot 1:1 Triad
Pipeline de producción oficial para procesar las 3 imágenes 1:1 de un piloto:
- Módulo A: Hub 3D Duo (Frente & Espalda 50/50) -> fullbody_*.png (1200x1600)
- Módulo B: Heroic Selection Splash -> selection_*.png (1200x1600) + portrait_*.png (1080x1080)
- Módulo C: Flight Combat Sprite -> ship_*.png (256x256)
"""

import os
import sys
import argparse
import colorsys
from PIL import Image

def remove_magenta_chroma(img: Image.Image, target_hue: float = 0.894) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    pixels = img.load()
    clean = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cp = clean.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h_val, s_val, v_val = colorsys.rgb_to_hsv(rf, gf, bf)
            diff = abs(h_val - target_hue)
            if diff > 0.5:
                diff = 1.0 - diff

            if diff < 0.08 and s_val >= 0.35 and v_val >= 0.25:
                cp[x, y] = (0, 0, 0, 0)
            elif diff < 0.12 and s_val >= 0.25:
                factor = (diff - 0.08) / 0.04
                alpha = int(255 * max(0.0, min(1.0, factor)))
                neutral = (gf + bf) * 0.5
                rf = min(rf, neutral)
                bf = min(bf, neutral * 1.1)
                cp[x, y] = (int(rf * 255), int(gf * 255), int(bf * 255), alpha)
            else:
                cp[x, y] = (r, g, b, 255)
    return clean

def process_pilot_triad(
    pilot_id: str,
    hub_duo_path: str = None,
    hero_path: str = None,
    flight_path: str = None,
    output_dir: str = "assets/characters"
) -> None:
    print(f"=== Procesando Triada 1:1 para Piloto: '{pilot_id}' ===")

    # 1. Módulo A (Hub Duo: Frente y Espalda)
    if hub_duo_path and os.path.exists(hub_duo_path):
        print(f"-> Procesando Hub Duo: {hub_duo_path}")
        hub_img = remove_magenta_chroma(Image.open(hub_duo_path))
        w, h = hub_img.size
        front_crop = hub_img.crop((0, 0, w // 2, h))
        back_crop = hub_img.crop((w // 2, 0, w, h))

        for prefix, crop in [("fullbody", front_crop), ("fullbody_back", back_crop)]:
            bbox = crop.getbbox()
            if not bbox:
                continue
            fig = crop.crop(bbox)
            scale = min((1200 * 0.88) / fig.width, (1600 * 0.88) / fig.height)
            nw, nh = int(fig.width * scale), int(fig.height * scale)
            res = fig.resize((nw, nh), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (1200, 1600), (0, 0, 0, 0))
            canvas.paste(res, ((1200 - nw) // 2, int(1600 * 0.94 - nh)), res)

            dest_file = f"{output_dir}/fullbody/{prefix}_{pilot_id}.png"
            os.makedirs(os.path.dirname(dest_file), exist_ok=True)
            canvas.save(dest_file)
            flipped_file = f"{output_dir}/fullbody/{prefix}_{pilot_id}_flipped.png"
            canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(flipped_file)
            print(f"   [OK] {dest_file}")
            print(f"   [OK] {flipped_file}")

    # 2. Módulo B (Heroic Selection Splash Art & Portrait)
    if hero_path and os.path.exists(hero_path):
        print(f"-> Procesando Heroic Splash: {hero_path}")
        hero_img = remove_magenta_chroma(Image.open(hero_path))
        bbox = hero_img.getbbox()
        if bbox:
            fig = hero_img.crop(bbox)
            scale = min((1200 * 0.90) / fig.width, (1600 * 0.90) / fig.height)
            nw, nh = int(fig.width * scale), int(fig.height * scale)
            res = fig.resize((nw, nh), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (1200, 1600), (0, 0, 0, 0))
            canvas.paste(res, ((1200 - nw) // 2, int(1600 * 0.94 - nh)), res)

            dest_file = f"{output_dir}/selection/selection_{pilot_id}.png"
            os.makedirs(os.path.dirname(dest_file), exist_ok=True)
            canvas.save(dest_file)
            flipped_file = f"{output_dir}/selection/selection_{pilot_id}_flipped.png"
            canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(flipped_file)
            print(f"   [OK] {dest_file}")
            print(f"   [OK] {flipped_file}")

            # Generar Portrait (busto superior 50%)
            head_crop = fig.crop((0, 0, fig.width, int(fig.height * 0.50)))
            head_bbox = head_crop.getbbox()
            if head_bbox:
                head_tight = head_crop.crop(head_bbox)
                pscale = min((1080 * 0.88) / head_tight.width, (1080 * 0.88) / head_tight.height)
                pnw, pnh = int(head_tight.width * pscale), int(head_tight.height * pscale)
                pres = head_tight.resize((pnw, pnh), Image.Resampling.LANCZOS)
                pcanvas = Image.new("RGBA", (1080, 1080), (0, 0, 0, 0))
                pcanvas.paste(pres, ((1080 - pnw) // 2, int(1080 * 0.92 - pnh)), pres)
                port_file = f"{output_dir}/portraits/portrait_{pilot_id}.png"
                pcanvas.save(port_file)
                pcanvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(f"{output_dir}/portraits/portrait_{pilot_id}_flipped.png")
                # Sincronizar también con assets/portraits
                os.makedirs("assets/portraits", exist_ok=True)
                pcanvas.save(f"assets/portraits/portrait_{pilot_id}.png")
                pcanvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(f"assets/portraits/portrait_{pilot_id}_flipped.png")
                print(f"   [OK] {port_file}")

    # 3. Módulo C (Flight Combat Sprite 256x256)
    if flight_path and os.path.exists(flight_path):
        print(f"-> Procesando Flight Combat Sprite: {flight_path}")
        flight_img = remove_magenta_chroma(Image.open(flight_path))
        bbox = flight_img.getbbox()
        if bbox:
            fig = flight_img.crop(bbox)
            scale = min((256 * 0.88) / fig.width, (256 * 0.88) / fig.height)
            nw, nh = int(fig.width * scale), int(fig.height * scale)
            res = fig.resize((nw, nh), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
            canvas.paste(res, ((256 - nw) // 2, (256 - nh) // 2), res)
            ship_file = f"{output_dir}/ships/ship_{pilot_id}.png"
            os.makedirs(os.path.dirname(ship_file), exist_ok=True)
            canvas.save(ship_file)
            print(f"   [OK] {ship_file}")

    print("=== Triada 1:1 procesada exitosamente ===")

def main():
    parser = argparse.ArgumentParser(description="Procesa la Triada Modular 1:1 para un piloto de Astra Dream.")
    parser.add_argument("--pilot", "-p", required=True, help="Identificador del piloto (ej. valentina, nova, roxy, kira)")
    parser.add_argument("--hub", help="Ruta de la imagen 1:1 del Hub Duo (Frente & Espalda)")
    parser.add_argument("--hero", help="Ruta de la imagen 1:1 del Heroic Selection Splash Art")
    parser.add_argument("--flight", help="Ruta de la imagen 1:1 del Sprite de Combate en Vuelo")
    parser.add_argument("--output", "-o", default="assets/characters", help="Directorio base de destino")
    args = parser.parse_args()

    process_pilot_triad(
        pilot_id=args.pilot.lower(),
        hub_duo_path=args.hub,
        hero_path=args.hero,
        flight_path=args.flight,
        output_dir=args.output
    )

if __name__ == "__main__":
    main()
