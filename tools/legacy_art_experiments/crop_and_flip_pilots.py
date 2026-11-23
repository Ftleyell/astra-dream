import os
from PIL import Image, ImageOps

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
SELECTION_DIR = os.path.join(ASSETS_DIR, "characters", "selection")
FULLBODY_DIR = os.path.join(ASSETS_DIR, "characters", "fullbody")
PORTRAITS_CHAR_DIR = os.path.join(ASSETS_DIR, "characters", "portraits")
PORTRAITS_ROOT_DIR = os.path.join(ASSETS_DIR, "portraits")

PILOTS = ["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"]
RAW_FACES_RIGHT = {"valentina"}

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

    # 4. Asegurar que portrait (Normal) mire hacia la DERECHA para el lado IZQUIERDO de la conversación
    if pilot in RAW_FACES_RIGHT:
        facing_right = img
    else:
        facing_right = ImageOps.mirror(img)

    # 5. Encuadre cuadrado 1080x1080 pegado al borde (x=0) para disimular recortes
    S = 1080
    top_slice = facing_right.crop((0, 0, w, min(h, S)))
    alpha = top_slice.split()[-1]
    bbox = alpha.getbbox()
    x_back = bbox[0] if bbox else 0

    # Crear lienzo cuadrado transparente
    portrait_left = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # Pegar alineando la espalda del personaje en x=0 (pegado al borde izquierdo de la pantalla)
    portrait_left.paste(facing_right, (-x_back, 0))

    # 6. portrait_flipped mira hacia la IZQUIERDA y su espalda toca x=S (borde derecho de la pantalla)
    portrait_right = ImageOps.mirror(portrait_left)

    # 7. Guardar en ambas ubicaciones
    char_port_path = os.path.join(PORTRAITS_CHAR_DIR, f"portrait_{pilot}.png")
    char_port_flip_path = os.path.join(PORTRAITS_CHAR_DIR, f"portrait_{pilot}_flipped.png")
    root_port_path = os.path.join(PORTRAITS_ROOT_DIR, f"portrait_{pilot}.png")
    root_port_flip_path = os.path.join(PORTRAITS_ROOT_DIR, f"portrait_{pilot}_flipped.png")

    portrait_left.save(char_port_path, "PNG")
    portrait_left.save(root_port_path, "PNG")
    portrait_right.save(char_port_flip_path, "PNG")
    portrait_right.save(root_port_flip_path, "PNG")

    print(f"    -> Portrait {portrait_left.size} pegado a bordes y orientado hacia adentro.")
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
