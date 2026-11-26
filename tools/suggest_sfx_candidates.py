"""Analizador y sugeridor asistido de candidatos SFX y perfiles combinados.

Recorre recursivamente una o mas carpetas con packs descargados,
puntua cada archivo contra los 32 slots de Stela Galactica (keywords + duracion ideal),
genera Top 5 por slot y construye 4 perfiles combinados completos (1-clic) con
variantes reales y Capa 2. Tambien permite descomprimir archivos .zip de forma segura.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import wave
import zipfile
from pathlib import Path

SUPPORTED_EXTS: set[str] = {".wav", ".ogg", ".mp3", ".flac", ".aiff", ".aif", ".m4a", ".opus"}
IGNORED_DIRS: set[str] = {".git", ".godot", "__MACOSX", "node_modules"}
VARIANT_SUFFIX_RE = re.compile(r"^(.*?)(?:[_\-\s]*(?:0?\d+|v\d+))$", re.IGNORECASE)

# (slot_key, category, default_mono, is_ambience, keywords, min_ms, ideal_min_ms, ideal_max_ms, max_ms)
SLOT_RULES: list[tuple[str, str, bool, bool, list[str], float, float, float, float]] = [
    ("laser", "Combat", True, False, ["laser", "beam", "plasma", "shoot", "blaster", "pulse"], 30, 70, 320, 800),
    ("missile", "Combat", True, False, ["missile", "rocket", "launch", "whoosh", "thruster"], 60, 120, 600, 1400),
    ("explosion", "Combat", True, False, ["explosion", "boom", "blast", "destroy", "burst"], 80, 180, 750, 1800),
    ("bomb", "Combat", False, False, ["bomb", "nuke", "ult", "shockwave", "mega", "massive", "explosion"], 250, 500, 2400, 5000),
    ("player_hit", "Combat", True, False, ["hit", "damage", "shield", "hurt", "punch", "impact"], 40, 80, 350, 900),
    ("dash", "Combat", True, False, ["dash", "whoosh", "swoosh", "boost", "warp", "blink"], 50, 100, 420, 1000),
    ("exp", "Pickups", True, False, ["coin", "gem", "pickup", "chime", "blip", "crystal", "orb"], 20, 45, 220, 550),
    ("heal", "Pickups", False, False, ["heal", "powerup", "magic", "shimmer", "restore", "chime"], 150, 280, 1400, 3000),
    ("magnet", "Pickups", False, False, ["magnet", "charge", "warp", "suction", "arcane", "hum"], 120, 220, 1200, 2600),
    ("ui_click", "UI", False, False, ["click", "select", "confirm", "button", "ui", "tap"], 10, 20, 180, 450),
    ("hub_footstep", "Hub", True, False, ["footstep", "step", "metal", "tap", "walk", "boot"], 20, 40, 260, 600),
    ("ui_hover", "UI", False, False, ["hover", "tick", "rollover", "ui", "soft", "blip"], 8, 15, 130, 320),
    ("ui_error", "UI", False, False, ["error", "deny", "cancel", "buzz", "negative", "invalid"], 40, 80, 450, 1000),
    ("menu_open", "UI", False, False, ["open", "menu", "swoosh", "panel", "ui", "slide"], 60, 120, 550, 1200),
    ("level_up", "Pickups", False, False, ["level", "fanfare", "upgrade", "chime", "powerup", "victory"], 200, 400, 2200, 4500),
    ("upgrade_obtained", "Pickups", False, False, ["upgrade", "reward", "unlock", "victory", "gacha", "chime"], 180, 350, 2000, 4200),
    ("item_pickup", "Pickups", True, False, ["pickup", "item", "collect", "loot", "chime"], 30, 60, 380, 900),
    ("warning", "Combat", False, False, ["warning", "alarm", "alert", "siren", "boss", "danger"], 150, 300, 1800, 4000),
    ("laser_heavy", "Combat", False, False, ["heavy", "cannon", "railgun", "beam", "charge", "mega"], 150, 250, 1200, 2600),
    ("impact", "Combat", True, False, ["impact", "hit", "thud", "crash", "slam", "punch"], 40, 80, 500, 1200),
    ("hit_bullet", "Combat", True, False, ["hit", "ricochet", "spark", "metal", "tick", "bullet"], 15, 30, 220, 550),
    ("satellite_plant", "Hub", False, False, ["deploy", "plant", "lock", "mech", "activate", "latch"], 80, 160, 900, 2000),
    ("satellite_activate", "Hub", False, False, ["activate", "beacon", "portal", "power", "gacha", "arcane"], 150, 280, 1500, 3200),
    ("weapon_laser", "Weapons", True, False, ["laser", "pulse", "scifi", "blaster", "shoot", "beam"], 30, 70, 320, 750),
    ("weapon_railgun", "Weapons", True, False, ["railgun", "rail", "sniper", "cannon", "gauss", "rifle"], 80, 150, 650, 1400),
    ("weapon_shotgun", "Weapons", True, False, ["shotgun", "flak", "blast", "cannon", "heavy", "scatter"], 70, 140, 600, 1300),
    ("weapon_missile", "Weapons", True, False, ["missile", "rocket", "launch", "swarm", "whoosh"], 70, 130, 580, 1300),
    ("weapon_blade", "Weapons", True, False, ["blade", "sword", "slash", "swipe", "cut", "energy"], 50, 90, 420, 950),
    ("weapon_tesla", "Weapons", True, False, ["tesla", "electric", "zap", "arc", "spark", "lightning"], 40, 80, 450, 1000),
    ("weapon_void", "Weapons", False, False, ["void", "singularity", "gravity", "deep", "bass", "blackhole", "arcane"], 120, 220, 1200, 2600),
    ("ambience_cosmos", "Ambience", False, True, ["space", "cosmos", "ambience", "ambient", "drone", "nebula", "void", "pad"], 1800, 4000, 60000, 300000),
    ("ambience_hub", "Ambience", False, True, ["station", "hub", "ship", "bridge", "room", "hum", "ambience", "ambient", "tech"], 1800, 4000, 60000, 300000),
]

FALLBACK_CHAINS: dict[str, list[str]] = {
    "weapon_laser": ["laser"],
    "weapon_railgun": ["laser_heavy", "weapon_laser", "laser"],
    "weapon_shotgun": ["impact", "explosion", "laser_heavy"],
    "weapon_missile": ["missile", "dash"],
    "weapon_blade": ["dash", "weapon_laser"],
    "weapon_tesla": ["weapon_laser", "laser", "hit_bullet"],
    "weapon_void": ["magnet", "bomb", "laser_heavy"],
    "ui_hover": ["ui_click"],
    "ui_error": ["ui_click", "impact"],
    "menu_open": ["dash", "ui_click"],
    "level_up": ["upgrade_obtained", "heal"],
    "upgrade_obtained": ["level_up", "heal"],
    "item_pickup": ["exp", "heal"],
    "warning": ["bomb", "laser_heavy"],
    "laser_heavy": ["weapon_railgun", "laser"],
    "impact": ["player_hit", "explosion"],
    "hit_bullet": ["impact", "player_hit"],
    "satellite_plant": ["impact", "ui_click"],
    "satellite_activate": ["heal", "magnet"],
}

LAYER2_SLOTS_BY_PROFILE: dict[str, set[str]] = {
    "hibrido_stela": {"bomb", "level_up", "warning", "weapon_railgun", "weapon_void"},
    "anime_cristalino": {"bomb", "level_up"},
    "cinematografico": {"bomb", "explosion", "laser_heavy", "weapon_railgun", "weapon_shotgun", "weapon_void", "warning", "satellite_activate"},
    "arcade_punchy": {"bomb"},
}


def estimate_duration_ms(path: Path) -> float:
    """Estima duracion en ms rapidamente sin invocar subprocesos por archivo."""
    ext = path.suffix.lower()
    if ext == ".wav":
        try:
            with wave.open(str(path), "rb") as wf:
                rate = wf.getframerate()
                frames = wf.getnframes()
                if rate > 0:
                    return (frames / float(rate)) * 1000.0
        except Exception:
            pass
    try:
        size = path.stat().st_size
        kbps_bytes = 16000.0 if ext in {".ogg", ".mp3", ".opus", ".m4a"} else 88200.0
        return (size / kbps_bytes) * 1000.0
    except OSError:
        return 300.0


def variant_group_key(path: Path) -> str:
    stem = path.stem.lower()
    m = VARIANT_SUFFIX_RE.match(stem)
    base = m.group(1) if m else stem
    return f"{str(path.parent).lower()}/{base}"


def scan_audio_files(root_dirs: list[Path], max_files: int = 12000) -> list[dict[str, object]]:
    files: list[dict[str, object]] = []
    seen_abs: set[str] = set()
    for root_dir in root_dirs:
        if not root_dir.is_dir():
            continue
        for cur_root, dirnames, filenames in os.walk(root_dir):
            dirnames[:] = [d for d in sorted(dirnames) if d not in IGNORED_DIRS and not d.startswith(".")]
            for fname in sorted(filenames):
                if fname.startswith("._"):
                    continue
                p = Path(cur_root) / fname
                if p.suffix.lower() not in SUPPORTED_EXTS:
                    continue
                abs_str = str(p).replace("\\", "/")
                if abs_str in seen_abs:
                    continue
                seen_abs.add(abs_str)
                try:
                    rel_str = str(p.relative_to(root_dir)).replace("\\", "/")
                except ValueError:
                    rel_str = p.name
                dur_ms = estimate_duration_ms(p)
                files.append(
                    {
                        "abs_path": abs_str,
                        "rel_path": f"{root_dir.name}/{rel_str}",
                        "rel_lower": f"{root_dir.name}/{rel_str}".lower(),
                        "stem_lower": p.stem.lower(),
                        "duration_ms": round(dur_ms, 1),
                        "group_key": variant_group_key(p),
                    }
                )
                if len(files) >= max_files:
                    return files
    return files


def score_file_for_rule(
    entry: dict[str, object],
    keywords: list[str],
    min_ms: float,
    ideal_min: float,
    ideal_max: float,
    max_ms: float,
) -> float:
    rel_l = str(entry["rel_lower"])
    stem_l = str(entry["stem_lower"])
    dur = float(entry["duration_ms"])

    kw_score = 0.0
    for idx, kw in enumerate(keywords):
        weight = 24.0 if idx < 2 else 14.0
        if kw in stem_l:
            kw_score += weight * 1.4
        elif kw in rel_l:
            kw_score += weight

    if kw_score <= 0.0:
        return 0.0

    if ideal_min <= dur <= ideal_max:
        dur_score = 22.0
    elif min_ms <= dur <= max_ms:
        dur_score = 8.0
    else:
        dur_score = -18.0

    ext_bonus = 3.0 if rel_l.endswith(".wav") else 0.0
    return max(0.0, kw_score + dur_score + ext_bonus)


def _pick_profile_item(candidates: list[dict[str, object]], profile_id: str) -> dict[str, object] | None:
    if not candidates:
        return None
    if profile_id == "hibrido_stela":
        return candidates[0]
    if profile_id == "anime_cristalino":
        return min(candidates, key=lambda c: (float(c["duration_ms"]), -float(c["score"])))
    if profile_id == "cinematografico":
        return max(candidates, key=lambda c: (float(c["duration_ms"]) * 0.05 + float(c["score"])))
    if profile_id == "arcade_punchy":
        short_pool = [c for c in candidates if float(c["duration_ms"]) <= 260.0]
        pool = short_pool if short_pool else candidates
        return min(pool, key=lambda c: (float(c["duration_ms"]), -float(c["score"])))
    return candidates[0]


def _pick_layer2_candidate(
    primary_abs: str,
    candidates: list[dict[str, object]],
    fallback_pool: list[dict[str, object]],
) -> str:
    for item in candidates[1:]:
        p = str(item.get("abs_path", ""))
        if p and p != primary_abs:
            return p
    for item in fallback_pool:
        p = str(item.get("abs_path", ""))
        if p and p != primary_abs:
            return p
    return ""


def _build_combined_profiles(
    suggestions: dict[str, list[dict[str, object]]],
    entries: list[dict[str, object]],
) -> dict[str, dict[str, object]]:
    profiles_meta: dict[str, tuple[str, float, float, float]] = {
        "hibrido_stela": ("Híbrido Stela Galactica (Rec.)", 0.0, 1.0, 0.08),
        "anime_cristalino": ("Anime Sci-Fi Cristalino", -0.5, 1.04, 0.06),
        "cinematografico": ("Cinematográfico & Pesado", 0.5, 0.94, 0.07),
        "arcade_punchy": ("Arcade Bullet-Hell Punchy", 0.0, 1.06, 0.10),
    }

    any_short_fallback = [str(e["abs_path"]) for e in sorted(entries, key=lambda x: float(x["duration_ms"]))[:1]]
    heavy_pool = suggestions.get("bomb", []) + suggestions.get("explosion", []) + suggestions.get("impact", [])

    result: dict[str, dict[str, object]] = {}
    for prof_id, (label, gain_db, pitch_base, pitch_jitter) in profiles_meta.items():
        slots_out: dict[str, dict[str, object]] = {}
        layer2_targets = LAYER2_SLOTS_BY_PROFILE.get(prof_id, set())

        for slot_key, _cat, default_mono, is_amb, _kws, _min_m, _imin, _imax, _max_m in SLOT_RULES:
            pool = list(suggestions.get(slot_key, []))
            used_fallback = False
            if not pool:
                for fb_key in FALLBACK_CHAINS.get(slot_key, []):
                    fb_list = suggestions.get(fb_key, [])
                    if fb_list:
                        pool = list(fb_list)
                        used_fallback = True
                        break

            chosen = _pick_profile_item(pool, prof_id)
            cands: list[str] = []
            if chosen is not None:
                raw_vars = [str(v) for v in chosen.get("variants", []) if str(v)]
                if raw_vars:
                    cands = raw_vars[:3]
                else:
                    cands = [str(chosen["abs_path"])]
            elif not is_amb and any_short_fallback:
                cands = list(any_short_fallback)
                used_fallback = True

            l2_path = ""
            if cands and slot_key in layer2_targets:
                l2_path = _pick_layer2_candidate(cands[0], pool, heavy_pool)

            slots_out[slot_key] = {
                "candidates": cands,
                "layer2_candidate": l2_path,
                "gain_db": gain_db,
                "pitch_base": pitch_base,
                "pitch_jitter": pitch_jitter,
                "trim_silence": not is_amb,
                "mono": default_mono and not is_amb,
                "fallback": used_fallback,
            }

        result[prof_id] = {
            "label": label,
            "slots": slots_out,
        }
    return result


def build_suggestions(root_dirs: list[Path], top_n: int = 5) -> dict[str, object]:
    entries = scan_audio_files(root_dirs)
    groups: dict[str, list[str]] = {}
    for e in entries:
        gk = str(e["group_key"])
        groups.setdefault(gk, []).append(str(e["abs_path"]))

    suggestions: dict[str, list[dict[str, object]]] = {}
    for slot_key, _cat, _mono, _is_amb, keywords, min_ms, ideal_min, ideal_max, max_ms in SLOT_RULES:
        scored: list[tuple[float, dict[str, object]]] = []
        for e in entries:
            s = score_file_for_rule(e, keywords, min_ms, ideal_min, ideal_max, max_ms)
            if s > 0.0:
                scored.append((s, e))
        scored.sort(key=lambda item: (-item[0], str(item[1]["rel_path"])))

        seen_groups: set[str] = set()
        top_items: list[dict[str, object]] = []
        for s, e in scored:
            gk = str(e["group_key"])
            if gk in seen_groups and len(scored) > top_n:
                continue
            seen_groups.add(gk)
            variants = groups.get(gk, [str(e["abs_path"])])[:4]
            top_items.append(
                {
                    "abs_path": e["abs_path"],
                    "rel_path": e["rel_path"],
                    "score": round(s, 1),
                    "duration_ms": e["duration_ms"],
                    "variants": variants,
                }
            )
            if len(top_items) >= top_n:
                break
        suggestions[slot_key] = top_items

    profiles = _build_combined_profiles(suggestions, entries)
    return {
        "ok": True,
        "pack_root_dirs": [str(d).replace("\\", "/") for d in root_dirs],
        "total_files": len(entries),
        "suggestions": suggestions,
        "profiles": profiles,
    }


def unpack_zips(source_paths: list[Path], dest_root: Path) -> dict[str, object]:
    """Descomprime archivos .zip (de carpetas o rutas directas) sin zip-slip."""
    zip_targets: list[Path] = []
    for sp in source_paths:
        if sp.is_file() and sp.suffix.lower() == ".zip":
            zip_targets.append(sp)
        elif sp.is_dir():
            for p in sorted(sp.iterdir()):
                if p.is_file() and p.suffix.lower() == ".zip":
                    zip_targets.append(p)

    dest_root.mkdir(parents=True, exist_ok=True)
    unpacked_dirs: list[str] = []
    errors: list[str] = []

    for zp in zip_targets:
        target_dir = (dest_root / zp.stem).resolve()
        target_dir.mkdir(parents=True, exist_ok=True)
        try:
            with zipfile.ZipFile(zp, "r") as zf:
                for member in zf.infolist():
                    if member.is_dir():
                        continue
                    out_member = (target_dir / member.filename).resolve()
                    if not str(out_member).startswith(str(target_dir)):
                        continue
                    out_member.parent.mkdir(parents=True, exist_ok=True)
                    with zf.open(member, "r") as src, open(out_member, "wb") as dst:
                        dst.write(src.read())
            unpacked_dirs.append(str(target_dir).replace("\\", "/"))
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{zp.name}: {exc}")

    return {
        "ok": len(errors) == 0,
        "dest_dir": str(dest_root).replace("\\", "/"),
        "unpacked_dirs": unpacked_dirs,
        "errors": errors,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sugeridor de candidatos y perfiles SFX para Stela Galactica.")
    parser.add_argument("--packs-dir", action="append", default=[], help="Carpeta(s) raiz con packs de audio")
    parser.add_argument("--output", default="", help="Ruta JSON de salida")
    parser.add_argument("--top", type=int, default=5, help="Cantidad de sugerencias por slot")
    parser.add_argument("--unpack-zips-from", action="append", default=[], help="Archivo(s) .zip o carpeta(s) con .zip")
    parser.add_argument("--unpack-dest", default="", help="Carpeta destino para descompresion")
    args = parser.parse_args(argv)

    if args.unpack_zips_from:
        if not args.unpack_dest:
            print(json.dumps({"ok": False, "error": "Falta --unpack-dest"}, ensure_ascii=False))
            return 1
        src_list = [Path(p) for p in args.unpack_zips_from]
        res = unpack_zips(src_list, Path(args.unpack_dest))
        print(json.dumps(res, ensure_ascii=False))
        return 0 if res.get("ok") else 1

    if not args.packs_dir or not args.output:
        print(json.dumps({"ok": False, "error": "Se requieren --packs-dir y --output"}, ensure_ascii=False))
        return 1

    root_dirs = [Path(p) for p in args.packs_dir]
    valid_dirs = [d for d in root_dirs if d.is_dir()]
    if not valid_dirs:
        print(json.dumps({"ok": False, "error": f"Ninguna carpeta valida: {args.packs_dir}"}, ensure_ascii=False))
        return 1

    out_path = Path(args.output)
    payload = build_suggestions(valid_dirs, top_n=max(1, args.top))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"ok": True, "output": str(out_path), "total_files": payload["total_files"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
