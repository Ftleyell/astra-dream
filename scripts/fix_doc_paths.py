#!/usr/bin/env python3
"""
Repara 75 paths rotos en 9 documentos de orientación.
Migración: C:/Users/Aimol/OneDrive/Escritorio/Astra/ → workspace actual
"""
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REPLACEMENTS = [
    (
        "file:///c:/Users/Aimol/OneDrive/Escritorio/Astra/",
        "file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/"
    ),
    (
        "file:///C:/Users/Aimol/OneDrive/Escritorio/Astra/",
        "file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/"
    ),
]

DOCS = [
    "docs/DOMAIN_MAP.md",
    "docs/architecture/autoload_and_signal_bus_map.md",
    "docs/architecture/combat_progression_and_ui_systems.md",
    "docs/architecture/zero_context_architecture_and_file_tree.md",
    "docs/architecture/persistence_and_save_schema.md",
    "EXTENDING_THE_GAME.md",
    "docs/art/asset_generation_and_chromas.md",
    "docs/balance/QUICK_BALANCE_GUIDE.md",
    "docs/art/BotonTest.md",
]

fixed_total = 0
for doc in DOCS:
    path = os.path.join(BASE, doc)
    if not os.path.exists(path):
        print(f"[WARN] No encontrado: {doc}")
        continue
    with open(path, 'r', encoding='utf-8') as f:
        original = f.read()
    content = original
    for old, new in REPLACEMENTS:
        content = content.replace(old, new)
    count = original.count(REPLACEMENTS[0][0]) + original.count(REPLACEMENTS[1][0])
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[OK] {doc:60s} ({count} paths reparados)")
        fixed_total += count
    else:
        print(f"[-]  {doc:60s} (sin cambios)")

print(f"\nTotal reparados: {fixed_total} paths")
