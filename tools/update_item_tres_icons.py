#!/usr/bin/env python3
"""Updates the icon path in all data/items/roster/*.tres files to point to their generated PNGs."""
import os
import re

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
roster_dir = os.path.join(base_dir, "data", "items", "roster")
icon_dir = os.path.join(base_dir, "assets", "icons", "items")

total_updated = 0
already_ok = 0
not_found = []

for fname in sorted(os.listdir(roster_dir)):
    if not fname.endswith(".tres"):
        continue
    stem = fname[:-5]
    icon_filename = f"icon_{stem}.png"
    icon_disk_path = os.path.join(icon_dir, icon_filename)
    
    if not os.path.exists(icon_disk_path):
        not_found.append(stem)
        continue

    new_res_path = f"res://assets/icons/items/{icon_filename}"
    fpath = os.path.join(roster_dir, fname)
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()

    if f'path="{new_res_path}"' in content:
        already_ok += 1
        continue

    # Find Texture2D ExtResource linked to `icon`
    matches = re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', content)
    replaced = False
    for old_path, res_id in matches:
        if f'icon = ExtResource("{res_id}")' in content:
            content = content.replace(f'path="{old_path}"', f'path="{new_res_path}"')
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"OK: {fname} -> {new_res_path}")
            total_updated += 1
            replaced = True
            break

    if not replaced:
        print(f"WARN: Could not link Texture2D in {fname}")

print(f"\n--- RESUMEN ---")
print(f"Archivos .tres actualizados: {total_updated}")
print(f"Archivos ya actualizados: {already_ok}")
print(f"Archivos sin icono PNG ({len(not_found)}): {', '.join(not_found)}")
