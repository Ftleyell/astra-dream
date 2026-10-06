"""
Procesa las grillas 4x4 de preprocess/ (Fases 2-4: Tomos, Items, Arcanas).
Reutiliza el keying magenta de process_pilot_skill_grids.py.

Uso:
    python tools/process_icon_grids.py            # procesa todas las grillas presentes
    python tools/process_icon_grids.py --grid 3A  # una sola
"""

import os
import argparse
from PIL import Image
from process_pilot_skill_grids import remove_magenta_chroma

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREPROCESS_DIR = os.path.join(BASE_DIR, "preprocess")
ICONS_DIR = os.path.join(BASE_DIR, "assets", "icons")

# Orden fila a fila (izq->der, arriba->abajo). Prefijo "misc:" = comodín.
GRIDS: dict[str, tuple[str, list[str]]] = {
    "2A": ("tomes", [
        "tome_base_damage", "tome_attack_speed", "tome_crit_chance", "tome_crit_damage",
        "tome_weapon_size", "tome_projectile_speed", "tome_projectile_count", "tome_move_speed",
        "tome_cooldown_reduction", "misc:chrono_matrix", "misc:singularity_core", "misc:plasma_crucible",
        "misc:hyper_voltage_coil", "misc:superconductive_node", "misc:tachyon_catalyst", "misc:anti_entropy_valve",
    ]),
    "2B": ("tomes", [
        "tome_armor", "tome_max_health", "tome_health_regen", "tome_pickup_radius",
        "tome_luck", "tome_biomass_multiplier", "tome_credits_multiplier", "tome_exp_multiplier",
        "tome_curse", "misc:aegis_node", "misc:quantum_battery", "misc:bio_synthesizer",
        "misc:astral_beacon", "misc:dark_matter_inverter", "misc:midas_transmuter", "misc:genesis_spark",
    ]),
    "3A": ("items", [
        "tachyon_piercer", "collimator_lens", "photonic_prism", "pyroclastic_battery",
        "antimatter_core", "tesla_coil", "split_salvo", "kinetic_converter",
        "bifocal_lens", "photonic_transducer", "alchemical_converter", "abyssal_contract",
        "entropy_catalyst", "retaliation_swarm", "static_cell", "blood_capacitor",
    ]),
    "3B": ("items", [
        "kinetic_plating", "nanotitanium_plating", "heavy_condenser", "phase_inverter",
        "cryo_condenser", "glass_reactor", "dense_turbine", "overdrain_module",
        "hemodynamic_cell", "fusion_reactor", "gravitational_resonator", "orbital_relay",
        "escudo", "misc:nanite_infuser", "misc:reactive_bulwark", "misc:thermal_sink",
    ]),
    "3C": ("items", [
        "afterburn_thruster", "phase_thruster", "inertial_thruster", "quantum_key",
        "quantum_recompiler", "chronos_bank", "credit_card_green", "credit_card_red",
        "heavy_salvager", "stellar_scrap", "chip_telemetria", "rapid_injector",
        "capsula_biomasa", "trebol", "iman", "reloj_cuantico",
    ]),
    "4A": ("arcanas", [
        "agonic_fury", "blood_pact", "shield_sacrifice", "last_breath",
        "vampiric_drain", "core_thirst", "colossal_projectile", "heavy_ballistics",
        "shrapnel_rain", "unstable_fission", "voracious_harvest", "danmaku_mirror",
        "misc:the_eclipse", "misc:blade_of_the_abyss", "misc:crimson_rebirth", "misc:judgment_ray",
    ]),
    "4B": ("arcanas", [
        "dimensional_leap", "phase_flicker", "time_dilation", "gravitational_vortex",
        "warp_engine", "quantum_ricochet", "extraction_aura", "magnet_overload",
        "midas_alchemy", "high_risk_investment", "black_market", "phantom_evasion",
        "misc:wheel_of_stars", "misc:void_weaver", "misc:chronos_eternity", "misc:ouroboros_nebula",
    ]),
}


def _find_input(grid_id: str) -> str | None:
    for ext in (".jpg", ".jpeg", ".png", ".webp"):
        p = os.path.join(PREPROCESS_DIR, grid_id + ext)
        if os.path.exists(p):
            return p
    return None


def _normalize(cell: Image.Image, size: int) -> Image.Image:
    cleaned = remove_magenta_chroma(cell)
    bbox = cleaned.getbbox()
    if bbox:
        cleaned = cleaned.crop(bbox)
    cw, ch = cleaned.size
    dim = max(cw, ch)
    padded = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
    padded.paste(cleaned, ((dim - cw) // 2, (dim - ch) // 2))
    return padded.resize((size, size), Image.Resampling.LANCZOS)


def process_grid(grid_id: str, size: int) -> int:
    path = _find_input(grid_id)
    if not path:
        print(f"[SKIP] {grid_id}: no encontrado en preprocess/")
        return 0
    category, names = GRIDS[grid_id]
    img = Image.open(path).convert("RGBA")
    cw, ch = img.size[0] / 4.0, img.size[1] / 4.0
    count = 0
    for idx, name in enumerate(names):
        row, col = divmod(idx, 4)
        box = (int(col * cw), int(row * ch), int((col + 1) * cw), int((row + 1) * ch))
        icon = _normalize(img.crop(box), size)
        if name.startswith("misc:"):
            out_dir = os.path.join(ICONS_DIR, category, "misc")
            fname = f"icon_{name[5:]}.png"
        else:
            out_dir = os.path.join(ICONS_DIR, category)
            fname = f"icon_{name}.png"
        os.makedirs(out_dir, exist_ok=True)
        icon.save(os.path.join(out_dir, fname), "PNG")
        count += 1
    print(f"[OK] {grid_id} -> assets/icons/{category}/ ({count} iconos)")
    return count


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--grid", type=str, choices=list(GRIDS.keys()))
    parser.add_argument("--size", type=int, default=256)
    args = parser.parse_args()
    targets = [args.grid] if args.grid else list(GRIDS.keys())
    total = sum(process_grid(g, args.size) for g in targets)
    print(f"Total exportados: {total}")
