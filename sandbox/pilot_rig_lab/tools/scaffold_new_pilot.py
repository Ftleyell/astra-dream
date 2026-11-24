#!/usr/bin/env python3
"""Scaffold de un nuevo piloto v2 (8-Dir Nativo) clonando la plantilla de Valentina v2.

Genera el bundle completo de recursos .tres en data/pilots/<pilot_id>/ (17 raíz + skins/),
la estructura de directorios de assets en assets/pilots/<pilot_id>/ y la zona de fuentes crudas
en sandbox/pilot_rig_lab/source_refs/<pilot_id>/00_raw/ con .gdignore.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT: Path = Path(__file__).resolve().parents[3]
TEMPLATE_DATA_DIR: Path = REPO_ROOT / "data" / "pilots" / "valentina_v2"

ASSET_SUBDIRS: tuple[str, ...] = (
    "planar/heads",
    "planar/wings",
    "planar/weapons",
    "planar/s/parts_5",
    "planar/se/parts_5",
    "planar/e/parts_5",
    "planar/ne/parts_5",
    "planar/n/parts_5",
    "planar/nw/parts_5",
    "planar/w/parts_5",
    "planar/sw/parts_5",
    "banner",
    "dialogue",
)


def parse_hex_color(hex_str: str) -> tuple[float, float, float]:
    cleaned: str = hex_str.strip().lstrip("#")
    if len(cleaned) != 6 or not re.fullmatch(r"[0-9a-fA-F]{6}", cleaned):
        raise ValueError(f"Color hexadecimal inválido '{hex_str}'. Usa formato #RRGGBB.")
    r: float = round(int(cleaned[0:2], 16) / 255.0, 4)
    g: float = round(int(cleaned[2:4], 16) / 255.0, 4)
    b: float = round(int(cleaned[4:6], 16) / 255.0, 4)
    return (r, g, b)


def _format_color(rgb: tuple[float, float, float]) -> str:
    return f"Color({rgb[0]:g}, {rgb[1]:g}, {rgb[2]:g}, 1)"


def _derive_char_title(display_name: str, char_id: str) -> str:
    stripped: str = re.sub(r"\s*v2.*$", "", display_name, flags=re.IGNORECASE).strip()
    if stripped:
        return stripped
    return char_id.replace("_", " ").title()


def _transform_tres_content(
    rel_name: str,
    raw_text: str,
    pilot_id: str,
    char_id: str,
    display_name: str,
    char_title: str,
    color_literal: str,
) -> str:
    text: str = raw_text

    # 1. Reemplazos de rutas y prefijos propios del piloto (preservando data/pilots/styles/*)
    text = text.replace("res://data/pilots/valentina_v2/valentina_v2_", f"res://data/pilots/{pilot_id}/{pilot_id}_")
    text = text.replace("res://data/pilots/valentina_v2/skins/", f"res://data/pilots/{pilot_id}/skins/")
    text = text.replace("res://data/pilots/valentina_v2/", f"res://data/pilots/{pilot_id}/")
    text = text.replace("res://assets/pilots/valentina_v2/", f"res://assets/pilots/{pilot_id}/")
    text = text.replace("valentina_v2_", f"{pilot_id}_")
    text = text.replace("valentina_mecha_ring_packed.png", f"{char_id}_mecha_ring_packed.png")

    # 2. Ajustes específicos por archivo
    if rel_name == "valentina_v2_profile.tres":
        text = re.sub(r'pilot_id = "[^"]*"', f'pilot_id = "{pilot_id}"', text)
        text = re.sub(r'display_name = "[^"]*"', f'display_name = "{display_name}"', text)
        text = re.sub(r"default_accent_color = Color\([^\)]*\)", f"default_accent_color = {color_literal}", text)
    elif rel_name == "valentina_v2_skin_catalog.tres":
        text = text.replace('pilot_id = &"valentina"', f'pilot_id = &"{char_id}"')
        text = text.replace('target_id = &"valentina"', f'target_id = &"{char_id}"')
        text = text.replace('"pilot_valentina_', f'"pilot_{char_id}_')
        text = text.replace('"wings_valentina_', f'"wings_{char_id}_')
        text = text.replace('"weapon_valentina_', f'"weapon_{char_id}_')
        text = text.replace('display_name = "Valentina"', f'display_name = "{char_title}"')
        text = text.replace('target_name = "Valentina"', f'target_name = "{char_title}"')
        text = text.replace('target_name = "Alas de Valentina"', f'target_name = "Alas de {char_title}"')
        text = text.replace('target_name = "Rail-Lance de Valentina"', f'target_name = "Rail-Lance de {char_title}"')
    elif rel_name == "skins/00_base.tres":
        if "accent_color =" in text:
            text = re.sub(r"accent_color = Color\([^\)]*\)", f"accent_color = {color_literal}", text)
        else:
            text = text.rstrip() + f"\naccent_color = {color_literal}\n"
    elif "Valentina" in text:
        text = text.replace("Valentina v2", display_name)
        text = text.replace("Valentina", char_title)

    # 3. Reemplazo final del identificador maestro si quedó suelto en propiedades
    text = text.replace('"valentina_v2"', f'"{pilot_id}"')
    return text


def scaffold_pilot(
    pilot_id: str,
    display_name: str,
    char_id: str,
    accent_hex: str,
    out_root: Path,
    dry_run: bool,
    overwrite: bool,
) -> list[Path]:
    if not re.fullmatch(r"[a-z0-9_]+", pilot_id):
        raise ValueError(f"--pilot-id inválido '{pilot_id}': usar solo [a-z0-9_].")
    if not re.fullmatch(r"[a-z0-9_]+", char_id):
        raise ValueError(f"--char-id inválido '{char_id}': usar solo [a-z0-9_].")
    if not TEMPLATE_DATA_DIR.is_dir():
        raise FileNotFoundError(f"No existe la plantilla base en {TEMPLATE_DATA_DIR}")

    rgb: tuple[float, float, float] = parse_hex_color(accent_hex)
    color_literal: str = _format_color(rgb)
    char_title: str = _derive_char_title(display_name, char_id)

    target_data_dir: Path = out_root / "data" / "pilots" / pilot_id
    target_assets_dir: Path = out_root / "assets" / "pilots" / pilot_id
    target_source_dir: Path = out_root / "sandbox" / "pilot_rig_lab" / "source_refs" / pilot_id / "00_raw"

    if target_data_dir.exists() and not overwrite:
        raise FileExistsError(
            f"El directorio destino ya existe: {target_data_dir}. Usa --overwrite para regenerarlo."
        )

    planned_files: list[tuple[Path, str]] = []
    for src_file in sorted(TEMPLATE_DATA_DIR.rglob("*.tres")):
        rel_path: Path = src_file.relative_to(TEMPLATE_DATA_DIR)
        rel_posix: str = rel_path.as_posix()
        dest_name: str = rel_path.name.replace("valentina_v2_", f"{pilot_id}_")
        dest_file: Path = target_data_dir / rel_path.parent / dest_name
        raw_text: str = src_file.read_text(encoding="utf-8")
        transformed: str = _transform_tres_content(
            rel_posix,
            raw_text,
            pilot_id,
            char_id,
            display_name,
            char_title,
            color_literal,
        )
        planned_files.append((dest_file, transformed))

    planned_dirs: list[Path] = [target_data_dir / "skins", target_source_dir]
    for sub in ASSET_SUBDIRS:
        planned_dirs.append(target_assets_dir / sub)

    gdignore_path: Path = target_source_dir.parent / ".gdignore"
    created_paths: list[Path] = []

    if dry_run:
        print(f"[DRY-RUN] Pilot ID={pilot_id} | Char ID={char_id} | Display='{display_name}' | Accent={color_literal}")
        for d in planned_dirs:
            print(f"  [DIR ] {d}")
        for dest_file, _content in planned_files:
            print(f"  [FILE] {dest_file}")
            created_paths.append(dest_file)
        print(f"  [FILE] {gdignore_path}")
        return created_paths

    for d in planned_dirs:
        d.mkdir(parents=True, exist_ok=True)
    for dest_file, content in planned_files:
        dest_file.parent.mkdir(parents=True, exist_ok=True)
        dest_file.write_text(content, encoding="utf-8")
        created_paths.append(dest_file)
    gdignore_path.write_text("", encoding="utf-8")
    created_paths.append(gdignore_path)
    return created_paths


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Scaffold completo de nuevo piloto v2 desde plantilla Valentina v2.")
    parser.add_argument("--pilot-id", required=True, help="ID del rig/carpeta (ej. nova_v2)")
    parser.add_argument("--display-name", required=True, help='Nombre visible en labs (ej. "Nova v2 (8-Dir)")')
    parser.add_argument("--char-id", default="", help="ID de CharacterData (por defecto --pilot-id sin _v2)")
    parser.add_argument("--accent-hex", default="#33CCFF", help="Color acento base en hex #RRGGBB")
    parser.add_argument("--out-root", default=str(REPO_ROOT), help="Raíz destino (default: raíz del proyecto)")
    parser.add_argument("--dry-run", action="store_true", help="Mostrar archivos a crear sin escribir en disco")
    parser.add_argument("--overwrite", action="store_true", help="Sobrescribir bundle destino si ya existe")

    args = parser.parse_args(argv)
    pilot_id: str = args.pilot_id.strip().lower()
    char_id: str = args.char_id.strip().lower() if args.char_id.strip() else re.sub(r"_v\d+$", "", pilot_id)
    out_root: Path = Path(args.out_root).resolve()

    try:
        created: list[Path] = scaffold_pilot(
            pilot_id=pilot_id,
            display_name=args.display_name.strip(),
            char_id=char_id,
            accent_hex=args.accent_hex,
            out_root=out_root,
            dry_run=args.dry_run,
            overwrite=args.overwrite,
        )
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    if not args.dry_run:
        print(f"[OK] Scaffold generado para '{pilot_id}' ({len(created)} archivos).")
        print(f"  - Recursos .tres: {out_root / 'data' / 'pilots' / pilot_id}")
        print(f"  - Assets target:  {out_root / 'assets' / 'pilots' / pilot_id}")
        print(f"  - Raw sources:    {out_root / 'sandbox' / 'pilot_rig_lab' / 'source_refs' / pilot_id / '00_raw'}")
        print("Siguiente paso: generar arte base en 00_raw/ y seguir docs/PILOT_CREATION_PIPELINE.md (Etapas 1..9).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
