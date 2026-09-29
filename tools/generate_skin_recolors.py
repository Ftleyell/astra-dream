import os
import json
import shutil
from PIL import Image, ImageOps, ImageChops, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
RECOLORS_DIR = os.path.join(ASSETS_DIR, "recolors")
DATA_DIR = os.path.join(BASE_DIR, "data", "cosmetics")
CATEGORIES_DIR = os.path.join(DATA_DIR, "categories")

PALETTES = {
    "crimson_void": {
        "name": "Carmesí del Vacío",
        "description": "Fusión de plasma carmesí y energía del vacío.",
        "tint_rgb": (255, 42, 85),
        "glow_hex": "#FF6B8B",
        "accent_hex": "#FFA8B8",
        "secondary_rgb": (138, 0, 34),
        "rarity": "rare"
    },
    "cyber_neon": {
        "name": "Ciberneón",
        "description": "Luminiscencia cian eléctrica y pulsos cyberpunk.",
        "tint_rgb": (0, 240, 255),
        "glow_hex": "#70FFFF",
        "accent_hex": "#FF007F",
        "secondary_rgb": (0, 85, 170),
        "rarity": "rare"
    },
    "solar_gold": {
        "name": "Oro Solar",
        "description": "Blindaje forjado con radiación y oro estelar.",
        "tint_rgb": (255, 215, 0),
        "glow_hex": "#FFF275",
        "accent_hex": "#FF9900",
        "secondary_rgb": (204, 136, 0),
        "rarity": "epic"
    },
    "glacial_frost": {
        "name": "Glaciar Ártico",
        "description": "Cristales de hielo cósmico a cero absoluto.",
        "tint_rgb": (165, 243, 252),
        "glow_hex": "#E0F2FE",
        "accent_hex": "#38BDF8",
        "secondary_rgb": (2, 132, 199),
        "rarity": "common"
    },
    "royal_amethyst": {
        "name": "Amatista Real",
        "description": "Resonancia mística de cuarzo púrpura profundo.",
        "tint_rgb": (192, 132, 252),
        "glow_hex": "#F3E8FF",
        "accent_hex": "#E879F9",
        "secondary_rgb": (107, 33, 168),
        "rarity": "epic"
    },
    "emerald_matrix": {
        "name": "Matriz Esmeralda",
        "description": "Nanomáquinas bio-sintéticas de flujo esmeralda.",
        "tint_rgb": (52, 211, 153),
        "glow_hex": "#A7F3D0",
        "accent_hex": "#10B981",
        "secondary_rgb": (6, 95, 70),
        "rarity": "common"
    }
}

PILOTS = ["nova", "valentina", "kira", "selene", "roxy", "echo", "nyx"]
PETS = ["mochi", "kuro", "luna", "pip", "cosmo"]
NAVIGATORS = ["lyra", "vespera", "caelia", "zephyr", "iris"]

PILOT_DISPLAY_NAMES = {
    "nova": "Nova", "valentina": "Valentina", "kira": "Kira",
    "selene": "Selene", "roxy": "Roxy", "echo": "Echo", "nyx": "Nyx"
}
PET_DISPLAY_NAMES = {
    "mochi": "Mochi", "kuro": "Kuro", "luna": "Luna", "pip": "Pip", "cosmo": "Cosmo"
}
NAV_DISPLAY_NAMES = {
    "lyra": "Lyra", "vespera": "Vespera", "caelia": "Caelia", "zephyr": "Zephyr", "iris": "Iris"
}

def recolor_image(src_path, dst_path, tint_rgb, blend_factor=0.65, preserve_skin=False):
    """Applies color tint with optional facial and skin tone preservation."""
    if not os.path.exists(src_path):
        print(f"Warning: Source not found: {src_path}")
        return False
    
    img = Image.open(src_path).convert("RGBA")
    r, g, b, a = img.split()
    img_rgb = img.convert("RGB")
    
    gray = ImageOps.grayscale(img)
    tinted = ImageOps.colorize(
        gray,
        black=(0, 0, 0),
        white=tint_rgb,
        mid=(int(tint_rgb[0] * 0.6), int(tint_rgb[1] * 0.6), int(tint_rgb[2] * 0.6))
    )
    
    if not preserve_skin:
        blended = Image.blend(img_rgb, tinted, blend_factor)
        final_img = Image.merge("RGBA", (*blended.split(), a))
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        final_img.save(dst_path, "PNG")
        return True

    # Máscara C-acelerada en espacio HSV para detección de tonos de piel/rostro
    h, s, v = img_rgb.convert("HSV").split()
    lut_h = [255 if (x <= 32 or x >= 245) else 0 for x in range(256)]
    lut_s = [255 if (28 <= x <= 185) else 0 for x in range(256)]
    lut_v = [255 if (x >= 55) else 0 for x in range(256)]

    mask_h = h.point(lut_h)
    mask_s = s.point(lut_s)
    mask_v = v.point(lut_v)
    mask = ImageChops.multiply(mask_h, ImageChops.multiply(mask_s, mask_v))
    mask = mask.filter(ImageFilter.BoxBlur(1))

    # Composición: tinte pleno en ropa/tecnología y atenuado en piel/ojos
    blended_outfit = Image.blend(img_rgb, tinted, blend_factor)
    blended_skin = Image.blend(img_rgb, tinted, blend_factor * 0.12)
    final_rgb = Image.composite(blended_skin, blended_outfit, mask)
    final_img = Image.merge("RGBA", (*final_rgb.split(), a))

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    final_img.save(dst_path, "PNG")
    return True

def generate_all():
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(CATEGORIES_DIR, exist_ok=True)
    os.makedirs(os.path.join(RECOLORS_DIR, "ships"), exist_ok=True)
    os.makedirs(os.path.join(RECOLORS_DIR, "weapons"), exist_ok=True)
    os.makedirs(os.path.join(RECOLORS_DIR, "pilots"), exist_ok=True)
    os.makedirs(os.path.join(RECOLORS_DIR, "pets"), exist_ok=True)
    os.makedirs(os.path.join(RECOLORS_DIR, "navigators"), exist_ok=True)
    
    skin_database = {
        "version": "1.0",
        "palettes": PALETTES,
        "skins": {}
    }
    
    cat_ships = {"category": "ship", "skins": {}}
    cat_weapons = {"category": "weapon", "skins": {}}
    cat_pilots = {"category": "pilot", "skins": {}}
    cat_pets = {"category": "pet", "skins": {}}
    cat_navigators = {"category": "navigator", "skins": {}}

    total_generated = 0
    
    # 1. SHIPS (Exotrajes 256x256 con protección de rostro)
    print("--- Generando Skins de Naves (Exotrajes) ---")
    for pilot in PILOTS:
        src_ship = os.path.join(ASSETS_DIR, "characters", "ships", f"ship_{pilot}.png")
        for pal_id, pal in PALETTES.items():
            skin_id = f"ship_{pilot}_{pal_id}"
            dst_ship = os.path.join(RECOLORS_DIR, "ships", f"ship_{pilot}_{pal_id}.png")
            rel_path = f"res://assets/recolors/ships/ship_{pilot}_{pal_id}.png"
            
            # Recolor preservando el rostro y tiñendo el exotraje/blindaje
            if recolor_image(src_ship, dst_ship, pal["tint_rgb"], blend_factor=0.68, preserve_skin=True):
                total_generated += 1
            
            skin_entry = {
                "id": skin_id,
                "category": "ship",
                "target_id": pilot,
                "target_name": f"Nave de {PILOT_DISPLAY_NAMES.get(pilot, pilot.capitalize())}",
                "palette_id": pal_id,
                "skin_name": f"{pal['name']} - Nave {PILOT_DISPLAY_NAMES.get(pilot, pilot.capitalize())}",
                "description": pal["description"],
                "rarity": pal["rarity"],
                "glow_hex": pal["glow_hex"],
                "accent_hex": pal["accent_hex"],
                "texture_path": rel_path
            }
            skin_database["skins"][skin_id] = skin_entry
            cat_ships["skins"][skin_id] = skin_entry

    # 2. WEAPONS (Armas 128x128 y HD 1024x1024)
    print("--- Generando Skins de Armas ---")
    for pilot in PILOTS:
        src_weapon = os.path.join(ASSETS_DIR, "characters", "weapons", f"weapon_{pilot}.png")
        src_weapon_hd = os.path.join(ASSETS_DIR, "characters", "weapons", f"weapon_{pilot}_hd.png")
        
        for pal_id, pal in PALETTES.items():
            skin_id = f"weapon_{pilot}_{pal_id}"
            dst_weapon = os.path.join(RECOLORS_DIR, "weapons", f"weapon_{pilot}_{pal_id}.png")
            rel_path = f"res://assets/recolors/weapons/weapon_{pilot}_{pal_id}.png"
            
            if recolor_image(src_weapon, dst_weapon, pal["tint_rgb"], blend_factor=0.72, preserve_skin=False):
                total_generated += 1

            if os.path.exists(src_weapon_hd):
                dst_weapon_hd = os.path.join(RECOLORS_DIR, "weapons", f"weapon_{pilot}_{pal_id}_hd.png")
                recolor_image(src_weapon_hd, dst_weapon_hd, pal["tint_rgb"], blend_factor=0.72, preserve_skin=False)

            skin_entry = {
                "id": skin_id,
                "category": "weapon",
                "target_id": pilot,
                "target_name": f"Arma de {PILOT_DISPLAY_NAMES.get(pilot, pilot.capitalize())}",
                "palette_id": pal_id,
                "skin_name": f"{pal['name']} - Fuego de {PILOT_DISPLAY_NAMES.get(pilot, pilot.capitalize())}",
                "description": f"Modifica el chasis, proyectiles y partículas del arma a {pal['name']}.",
                "rarity": pal["rarity"],
                "glow_hex": pal["glow_hex"],
                "accent_hex": pal["accent_hex"],
                "tint_rgb": pal["tint_rgb"],
                "texture_path": rel_path
            }
            skin_database["skins"][skin_id] = skin_entry
            cat_weapons["skins"][skin_id] = skin_entry

    # 3. PILOTS (Fullbody y Retratos con protección de rostro)
    print("--- Generando Skins de Pilotos Fullbody ---")
    for pilot in PILOTS:
        src_fullbody = os.path.join(ASSETS_DIR, "characters", "fullbody", f"fullbody_{pilot}.png")
        for pal_id, pal in PALETTES.items():
            skin_id = f"pilot_{pilot}_{pal_id}"
            dst_fullbody = os.path.join(RECOLORS_DIR, "pilots", f"fullbody_{pilot}_{pal_id}.png")
            rel_path = f"res://assets/recolors/pilots/fullbody_{pilot}_{pal_id}.png"
            
            if recolor_image(src_fullbody, dst_fullbody, pal["tint_rgb"], blend_factor=0.48, preserve_skin=True):
                total_generated += 1
                dst_selection = os.path.join(RECOLORS_DIR, "pilots", f"selection_{pilot}_{pal_id}.png")
                shutil.copy2(dst_fullbody, dst_selection)
            
            src_flipped = os.path.join(ASSETS_DIR, "characters", "fullbody", f"fullbody_{pilot}_flipped.png")
            rel_flipped = ""
            if os.path.exists(src_flipped):
                dst_flipped = os.path.join(RECOLORS_DIR, "pilots", f"fullbody_{pilot}_{pal_id}_flipped.png")
                if recolor_image(src_flipped, dst_flipped, pal["tint_rgb"], blend_factor=0.48, preserve_skin=True):
                    total_generated += 1
                    rel_flipped = f"res://assets/recolors/pilots/fullbody_{pilot}_{pal_id}_flipped.png"
                    dst_selection_flipped = os.path.join(RECOLORS_DIR, "pilots", f"selection_{pilot}_{pal_id}_flipped.png")
                    shutil.copy2(dst_flipped, dst_selection_flipped)
            
            src_portrait = os.path.join(ASSETS_DIR, "characters", "portraits", f"portrait_{pilot}.png")
            if not os.path.exists(src_portrait):
                src_portrait = os.path.join(ASSETS_DIR, "portraits", f"portrait_{pilot}.png")
            
            src_portrait_flipped = os.path.join(ASSETS_DIR, "characters", "portraits", f"portrait_{pilot}_flipped.png")
            if not os.path.exists(src_portrait_flipped):
                src_portrait_flipped = os.path.join(ASSETS_DIR, "portraits", f"portrait_{pilot}_flipped.png")

            rel_portrait = ""
            if os.path.exists(src_portrait):
                dst_portrait = os.path.join(RECOLORS_DIR, "pilots", f"portrait_{pilot}_{pal_id}.png")
                if recolor_image(src_portrait, dst_portrait, pal["tint_rgb"], blend_factor=0.45, preserve_skin=True):
                    total_generated += 1
                    rel_portrait = f"res://assets/recolors/pilots/portrait_{pilot}_{pal_id}.png"

            rel_portrait_flipped = ""
            if os.path.exists(src_portrait_flipped):
                dst_portrait_flipped = os.path.join(RECOLORS_DIR, "pilots", f"portrait_{pilot}_{pal_id}_flipped.png")
                if recolor_image(src_portrait_flipped, dst_portrait_flipped, pal["tint_rgb"], blend_factor=0.45, preserve_skin=True):
                    total_generated += 1
                    rel_portrait_flipped = f"res://assets/recolors/pilots/portrait_{pilot}_{pal_id}_flipped.png"
            
            skin_entry = {
                "id": skin_id,
                "category": "pilot",
                "target_id": pilot,
                "target_name": PILOT_DISPLAY_NAMES.get(pilot, pilot.capitalize()),
                "palette_id": pal_id,
                "skin_name": f"{pal['name']} - {PILOT_DISPLAY_NAMES.get(pilot, pilot.capitalize())}",
                "description": pal["description"],
                "rarity": pal["rarity"],
                "glow_hex": pal["glow_hex"],
                "accent_hex": pal["accent_hex"],
                "texture_path": rel_path,
                "flipped_texture_path": rel_flipped,
                "selection_texture_path": f"res://assets/recolors/pilots/selection_{pilot}_{pal_id}.png",
                "selection_flipped_texture_path": f"res://assets/recolors/pilots/selection_{pilot}_{pal_id}_flipped.png" if rel_flipped else "",
                "portrait_texture_path": rel_portrait,
                "portrait_flipped_texture_path": rel_portrait_flipped
            }
            skin_database["skins"][skin_id] = skin_entry
            cat_pilots["skins"][skin_id] = skin_entry

    # 4. PETS
    print("--- Generando Skins de Pets ---")
    for pet in PETS:
        src_pet = os.path.join(ASSETS_DIR, "pets", f"pet_{pet}.png")
        for pal_id, pal in PALETTES.items():
            skin_id = f"pet_{pet}_{pal_id}"
            dst_pet = os.path.join(RECOLORS_DIR, "pets", f"pet_{pet}_{pal_id}.png")
            rel_path = f"res://assets/recolors/pets/pet_{pet}_{pal_id}.png"
            
            if recolor_image(src_pet, dst_pet, pal["tint_rgb"], blend_factor=0.55):
                total_generated += 1
                
            skin_entry = {
                "id": skin_id,
                "category": "pet",
                "target_id": pet,
                "target_name": PET_DISPLAY_NAMES.get(pet, pet.capitalize()),
                "palette_id": pal_id,
                "skin_name": f"{pal['name']} - {PET_DISPLAY_NAMES.get(pet, pet.capitalize())}",
                "description": pal["description"],
                "rarity": pal["rarity"],
                "glow_hex": pal["glow_hex"],
                "accent_hex": pal["accent_hex"],
                "texture_path": rel_path,
                "portrait_texture_path": rel_path
            }
            skin_database["skins"][skin_id] = skin_entry
            cat_pets["skins"][skin_id] = skin_entry

    # 5. NAVIGATORS
    print("--- Generando Skins de Navegadoras ---")
    for nav in NAVIGATORS:
        src_nav = os.path.join(ASSETS_DIR, "characters", "navigators", "portraits", f"portrait_{nav}.png")
        for pal_id, pal in PALETTES.items():
            skin_id = f"navigator_{nav}_{pal_id}"
            dst_nav = os.path.join(RECOLORS_DIR, "navigators", f"portrait_{nav}_{pal_id}.png")
            rel_path = f"res://assets/recolors/navigators/portrait_{nav}_{pal_id}.png"
            
            if recolor_image(src_nav, dst_nav, pal["tint_rgb"], blend_factor=0.45, preserve_skin=True):
                total_generated += 1
                
            skin_entry = {
                "id": skin_id,
                "category": "navigator",
                "target_id": nav,
                "target_name": NAV_DISPLAY_NAMES.get(nav, nav.capitalize()),
                "palette_id": pal_id,
                "skin_name": f"{pal['name']} - {NAV_DISPLAY_NAMES.get(nav, nav.capitalize())}",
                "description": pal["description"],
                "rarity": pal["rarity"],
                "glow_hex": pal["glow_hex"],
                "accent_hex": pal["accent_hex"],
                "texture_path": rel_path
            }
            skin_database["skins"][skin_id] = skin_entry
            cat_navigators["skins"][skin_id] = skin_entry

    # Write databases (both monolithic and modular category JSONs)
    json_path = os.path.join(DATA_DIR, "skin_database.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(skin_database, f, indent=2, ensure_ascii=False)
        
    with open(os.path.join(CATEGORIES_DIR, "skins_ships.json"), "w", encoding="utf-8") as f:
        json.dump(cat_ships, f, indent=2, ensure_ascii=False)

    with open(os.path.join(CATEGORIES_DIR, "skins_weapons.json"), "w", encoding="utf-8") as f:
        json.dump(cat_weapons, f, indent=2, ensure_ascii=False)

    with open(os.path.join(CATEGORIES_DIR, "skins_pilots.json"), "w", encoding="utf-8") as f:
        json.dump(cat_pilots, f, indent=2, ensure_ascii=False)

    with open(os.path.join(CATEGORIES_DIR, "skins_pets.json"), "w", encoding="utf-8") as f:
        json.dump(cat_pets, f, indent=2, ensure_ascii=False)

    with open(os.path.join(CATEGORIES_DIR, "skins_navigators.json"), "w", encoding="utf-8") as f:
        json.dump(cat_navigators, f, indent=2, ensure_ascii=False)
    
    print(f"\n[OK] Total de skins generadas e indexadas: {len(skin_database['skins'])}")
    print(f"[OK] Archivos PNG creados en disco: {total_generated}")
    print(f"[OK] Base de datos global guardada en: {json_path}")
    print(f"[OK] Archivos modulares guardados en: {CATEGORIES_DIR}")

if __name__ == "__main__":
    generate_all()
