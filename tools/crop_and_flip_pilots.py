import os
from PIL import Image, ImageOps

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
SELECTION_DIR = os.path.join(ASSETS_DIR, "characters", "selection")
FULLBODY_DIR = os.path.join(ASSETS_DIR, "characters", "fullbody")
PORTRAITS_CHAR_DIR = os.path.join(ASSETS_DIR, "characters", "portraits")
PORTRAITS_ROOT_DIR = os.path.join(ASSETS_DIR, "portraits")

PILOTS = ["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"]

def ensure_dirs():
    os.makedirs(SELECTION_DIR, exist_ok=True)
    os.makedirs(FULLBODY_DIR, exist_ok=True)
    os.makedirs(PORTRAITS_CHAR_DIR, exist_ok=True)
    os.makedirs(PORTRAITS_ROOT_DIR, exist_ok=True)

def process_pilot(pilot: str):
    # 1. Localizar imagen fuente (preferencia selection, fallback fullbody)
    src_path = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
    if not os.path.exists(src_path):
        src_path = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}.png")
    
    if not os.path.exists(src_path):
        print(f"[-] No se encontró asset para {pilot} en {src_path}")
        return False

    print(f"[+] Procesando piloto: {pilot} desde {os.path.basename(src_path)}")
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size

    # 2. Sincronizar fullbody y selection
    fb_path = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}.png")
    sel_path = os.path.join(SELECTION_DIR, f"selection_{pilot}.png")
    img.save(fb_path, "PNG")
    if src_path != sel_path:
        img.save(sel_path, "PNG")

    # 3. Generar variantes Flipped de cuerpo completo
    img_flipped = ImageOps.mirror(img)
    fb_flip_path = os.path.join(FULLBODY_DIR, f"fullbody_{pilot}_flipped.png")
    sel_flip_path = os.path.join(SELECTION_DIR, f"selection_{pilot}_flipped.png")
    img_flipped.save(fb_flip_path, "PNG")
    img_flipped.save(sel_flip_path, "PNG")

    # 4. Calcular recorte cuadrado superior inteligente (1200x1200 o min(w, h))
    # Margen superior: detectamos bbox para no cortar pelo
    alpha = img.split()[-1]
    bbox = alpha.getbbox()
    top_y = bbox[1] if bbox else 0

    # Usar ancho completo como tamaño del cuadrado para no cortar poses laterales
    square_size = min(w, h)
    
    # y_start comienza con suficiente margen sobre el pelo
    y_start = 0
    if top_y > 30:
        y_start = 0 # Deja espacio natural arriba
    else:
        y_start = max(0, top_y - 20)
        
    y_end = min(h, y_start + square_size)
    if (y_end - y_start) < square_size:
        y_start = max(0, y_end - square_size)

    crop_box = (0, y_start, square_size, y_end)
    portrait = img.crop(crop_box)
    portrait_flipped = ImageOps.mirror(portrait)

    # 5. Guardar portraits en ambas ubicaciones (characters/portraits y portraits/)
    char_port_path = os.path.join(PORTRAITS_CHAR_DIR, f"portrait_{pilot}.png")
    char_port_flip_path = os.path.join(PORTRAITS_CHAR_DIR, f"portrait_{pilot}_flipped.png")
    root_port_path = os.path.join(PORTRAITS_ROOT_DIR, f"portrait_{pilot}.png")
    root_port_flip_path = os.path.join(PORTRAITS_ROOT_DIR, f"portrait_{pilot}_flipped.png")

    portrait.save(char_port_path, "PNG")
    portrait.save(root_port_path, "PNG")
    portrait_flipped.save(char_port_flip_path, "PNG")
    portrait_flipped.save(root_port_flip_path, "PNG")

    print(f"    -> Portrait {portrait.size} guardado y espejado en carpetas de portraits.")
    return True

def main():
    ensure_dirs()
    success_count = 0
    for pilot in PILOTS:
        if process_pilot(pilot):
            success_count += 1
    print(f"\n[DONE] Procesadas {success_count}/{len(PILOTS)} pilotos exitosamente.")

if __name__ == "__main__":
    main()
