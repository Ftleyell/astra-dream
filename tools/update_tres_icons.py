import os
import re

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

targets = [
    (os.path.join(base_dir, "data", "tomes"), os.path.join(base_dir, "assets", "icons", "tomes"), "res://assets/icons/tomes/icon_{id}.png"),
    (os.path.join(base_dir, "data", "items"), os.path.join(base_dir, "assets", "icons", "items"), "res://assets/icons/items/icon_{id}.png"),
    (os.path.join(base_dir, "data", "arcanas", "roster"), os.path.join(base_dir, "assets", "icons", "arcanas"), "res://assets/icons/arcanas/icon_{id}.png"),
]

total_updated = 0
not_found = []

for data_dir, icon_dir, res_tpl in targets:
    if not os.path.exists(data_dir):
        continue
    for fname in os.listdir(data_dir):
        if not fname.endswith(".tres"):
            continue
        stem = fname[:-5]
        icon_file = os.path.join(icon_dir, f"icon_{stem}.png")
        if not os.path.exists(icon_file):
            not_found.append((stem, data_dir))
            continue
        
        fpath = os.path.join(data_dir, fname)
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()

        new_res = res_tpl.format(id=stem)
        
        # Regex to find any Texture2D ExtResource linked to `icon`
        # Pattern matches:
        # [ext_resource type="Texture2D" path="..." id="1_xxx"]
        matches = re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', content)
        replaced = False
        for old_path, res_id in matches:
            if f'icon = ExtResource("{res_id}")' in content:
                content = content.replace(f'path="{old_path}"', f'path="{new_res}"')
                with open(fpath, "w", encoding="utf-8") as f:
                    f.write(content)
                total_updated += 1
                replaced = True
                break
        
        if not replaced:
            print(f"[WARN] No se pudo vincular Texture2D en {fname}")

print(f"Total .tres actualizados con nuevos PNG: {total_updated}")
if not_found:
    print(f"Archivos .tres sin icono generado ({len(not_found)}):")
    for s, d in not_found:
        print(f"  - {s} en {os.path.basename(d)}")
