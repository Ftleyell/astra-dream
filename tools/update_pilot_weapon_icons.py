#!/usr/bin/env python3
"""Updates the icon path in the 7 pilot starting weapon .tres files."""
import re
from pathlib import Path

BASE = Path(__file__).parent.parent

MAPPING = {
    "crescent_blade.tres":   "res://assets/characters/skills/weapons/icon_weapon_nyx.png",
    "hive_cannon.tres":      "res://assets/characters/skills/weapons/icon_weapon_kira.png",
    "rail_launcher.tres":    "res://assets/characters/skills/weapons/icon_weapon_nova.png",
    "singularity_pulsar.tres": "res://assets/characters/skills/weapons/icon_weapon_selene.png",
    "sniper_rifle.tres":     "res://assets/characters/skills/weapons/icon_weapon_valentina.png",
    "tesla_arc.tres":        "res://assets/characters/skills/weapons/icon_weapon_echo.png",
    "titan_shotgun.tres":    "res://assets/characters/skills/weapons/icon_weapon_roxy.png",
}

PATTERN = re.compile(r'(\[ext_resource type="Texture2D" path=")([^"]+)(" id="2_ico"\])')

roster_dir = BASE / "data" / "weapons" / "roster"
for fname, new_path in MAPPING.items():
    fpath = roster_dir / fname
    text = fpath.read_text(encoding="utf-8")
    new_text, n = PATTERN.subn(lambda m: m.group(1) + new_path + m.group(3), text)
    if n == 1:
        fpath.write_text(new_text, encoding="utf-8")
        print(f"OK {fname}  ->  {new_path}")
    elif n == 0:
        print(f"WARN {fname}: no match found (already updated or different format?)")
    else:
        print(f"ERR {fname}: {n} matches (expected 1) -- skipped for safety")
