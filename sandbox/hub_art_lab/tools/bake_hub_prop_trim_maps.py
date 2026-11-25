"""Hornea un Trim-Sheet PBR completo (Albedo, Normal, ORM, ID Mask, ILM Mask e Ink SDF 2x)
para los modelos 3D ArcSys elevados del Hub (islas flotantes, quillas, puentes y props)
usando únicamente PIL + NumPy.

Salidas en sandbox/hub_art_lab/assets/trims/:
- hub_arcsys_trim.png          (1024x1024 RGB  - albedo base neutro/estilizado)
- hub_arcsys_trim_id_mask.png  (1024x1024 RGB  - R=acento/energía, G=placa, B=chasis)
- hub_arcsys_trim_ilm_mask.png (1024x1024 RGBA - R=spec, G=AO, B=oro/metal, A=emisión)
- hub_arcsys_trim_normal.png   (1024x1024 RGB  - Tangent-Space Normal Map multi-escala)
- hub_arcsys_trim_pbr_orm.png  (1024x1024 RGB  - R=Roughness, G=Cavity AO, B=Metallic)
- hub_arcsys_trim_ink_sdf.png  (2048x2048 L    - Signed Distance Field 2x, rango +-8 texels)
- hub_arcsys_trim_meta.json    (metadatos de bandas y esquema v1)
"""

import json
from pathlib import Path
import numpy as np
from PIL import Image


OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "trims"
PREFIX = "hub_arcsys_trim"
BASE_SIZE = 1024
SDF_SIZE = BASE_SIZE * 2
SDF_RANGE_TEXELS = 8.0


def _box_blur_2d(arr: np.ndarray, radius: int, passes: int = 2) -> np.ndarray:
    out = arr.astype(np.float32, copy=True)
    if radius <= 0:
        return out
    k = 2 * radius + 1
    for _ in range(passes):
        pad_h = np.pad(out, ((0, 0), (radius, radius)), mode="wrap")
        csum = np.cumsum(pad_h, axis=1, dtype=np.float64)
        csum = np.pad(csum, ((0, 0), (1, 0)), mode="constant")
        out = ((csum[:, k:] - csum[:, :-k]) / k).astype(np.float32)

        pad_v = np.pad(out, ((radius, radius), (0, 0)), mode="wrap")
        csum_v = np.cumsum(pad_v, axis=0, dtype=np.float64)
        csum_v = np.pad(csum_v, ((1, 0), (0, 0)), mode="constant")
        out = ((csum_v[k:, :] - csum_v[:-k, :]) / k).astype(np.float32)
    return out


def _bounded_edt_2d(inside_mask: np.ndarray, max_dist: float = 12.0, iters: int = 12) -> np.ndarray:
    """Calcula distancia euclidiana aproximada (8-vecinos) acotada a max_dist en O(iters)."""
    dist = np.where(inside_mask, max_dist, 0.0).astype(np.float32)
    diag = np.float32(1.41421356)
    one = np.float32(1.0)
    for _ in range(iters):
        up = np.roll(dist, 1, axis=0)
        dn = np.roll(dist, -1, axis=0)
        lf = np.roll(dist, 1, axis=1)
        rt = np.roll(dist, -1, axis=1)
        ul = np.roll(up, 1, axis=1)
        ur = np.roll(up, -1, axis=1)
        dl = np.roll(dn, 1, axis=1)
        dr = np.roll(dn, -1, axis=1)

        c4 = np.minimum(np.minimum(up, dn), np.minimum(lf, rt)) + one
        d4 = np.minimum(np.minimum(ul, ur), np.minimum(dl, dr)) + diag
        dist = np.minimum(dist, np.minimum(c4, d4))
    return dist


def _signed_distance_field(seam_mask: np.ndarray) -> np.ndarray:
    """Devuelve SDF normalizado en [0..1]: <0.5 dentro del trazo de tinta, >0.5 fuera."""
    dist_outside = _bounded_edt_2d(~seam_mask, max_dist=SDF_RANGE_TEXELS + 2.0, iters=12)
    dist_inside = _bounded_edt_2d(seam_mask, max_dist=SDF_RANGE_TEXELS + 2.0, iters=12)
    signed_dist = dist_outside - dist_inside
    norm = np.clip(0.5 + signed_dist / (2.0 * SDF_RANGE_TEXELS), 0.0, 1.0)
    return norm


def _build_trim_masks(size: int) -> dict[str, np.ndarray]:
    """Construye geometría vectorial analítica del trim-sheet a resolución `size`."""
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx.astype(np.float32) / float(size)
    v = yy.astype(np.float32) / float(size)

    # Bandas verticales:
    # B0 [0.00..0.40]: Placas blindadas de cubierta con chaflanes octogonales y remaches
    # B1 [0.40..0.70]: Costillas estructurales de quilla + rejillas/ventilas empotradas
    # B2 [0.70..0.85]: Molduras metálicas / Oro Astral y filetes de bisel
    # B3 [0.85..1.00]: Conductos energéticos rebajados + facetas cristalinas
    seam = np.zeros((size, size), dtype=bool)
    plate = np.zeros((size, size), dtype=np.float32)
    chassis = np.zeros((size, size), dtype=np.float32)
    conduit = np.zeros((size, size), dtype=np.float32)
    gold_trim = np.zeros((size, size), dtype=np.float32)
    height_raw = np.zeros((size, size), dtype=np.float32)

    px_unit = 1.0 / float(size)
    seam_w = 2.6 * px_unit

    # Separadores horizontales entre bandas
    for y_b in (0.0, 0.40, 0.70, 0.85):
        dy = np.minimum(np.abs(v - y_b), 1.0 - np.abs(v - y_b))
        seam |= dy < seam_w * 1.1

    # --- Banda 0: Placas blindadas (2 filas x 4 columnas con cortes diagonales) ---
    in_b0 = v < 0.40
    tile_u0 = (u * 4.0) % 1.0
    tile_v0 = (v / 0.40 * 2.0) % 1.0
    edge0 = np.minimum(np.minimum(tile_u0, 1.0 - tile_u0), np.minimum(tile_v0, 1.0 - tile_v0))
    # Chaflán diagonal en esquina superior derecha de cada placa
    diag_dist0 = np.abs((tile_u0 + tile_v0) - 1.62) * 0.7071
    plate[in_b0] = 1.0
    height_raw[in_b0] = 0.78

    # Juntas de placas y cortes diagonales
    seam |= in_b0 & ((edge0 < 0.022) | (diag_dist0 < 0.016))
    # Pequeñas ranuras de remache / anclaje
    rivet_d = np.sqrt((tile_u0 - 0.14) ** 2 + (tile_v0 - 0.16) ** 2)
    rivet_d2 = np.sqrt((tile_u0 - 0.86) ** 2 + (tile_v0 - 0.84) ** 2)
    recess_b0 = in_b0 & ((rivet_d < 0.045) | (rivet_d2 < 0.045) | (diag_dist0 < 0.032))
    plate[recess_b0] = 0.2
    chassis[recess_b0] = 0.8
    height_raw[recess_b0] = 0.42
    seam |= in_b0 & ((np.abs(rivet_d - 0.045) < 0.011) | (np.abs(rivet_d2 - 0.045) < 0.011))

    # --- Banda 1: Costillas estructurales y ventilas empotradas ---
    in_b1 = (v >= 0.40) & (v < 0.70)
    bv1 = (v - 0.40) / 0.30
    bu1 = (u * 6.0) % 1.0
    # Rejillas horizontales en el centro de cada celda
    in_vent = in_b1 & (bu1 > 0.16) & (bu1 < 0.84) & (bv1 > 0.18) & (bv1 < 0.82)
    louver = np.sin(bv1 * np.pi * 14.0)
    chassis[in_b1] = 0.85
    plate[in_b1] = 0.15
    height_raw[in_b1] = 0.45

    rib_mask = in_b1 & (~in_vent)
    plate[rib_mask] = 0.85
    chassis[rib_mask] = 0.15
    height_raw[rib_mask] = 0.76

    vent_slat = in_vent & (louver > 0.0)
    vent_hole = in_vent & (louver <= 0.0)
    plate[vent_slat] = 0.55
    chassis[vent_slat] = 0.45
    height_raw[vent_slat] = 0.52
    chassis[vent_hole] = 1.0
    plate[vent_hole] = 0.0
    height_raw[vent_hole] = 0.12

    seam |= in_b1 & ((np.abs(bu1 - 0.16) < 0.018) | (np.abs(bu1 - 0.84) < 0.018))
    seam |= in_b1 & ((np.abs(bv1 - 0.18) < 0.016) | (np.abs(bv1 - 0.82) < 0.016))
    seam |= in_vent & (np.abs(louver) < 0.14)

    # --- Banda 2: Molduras Oro Astral / Biseles Metálicos ---
    in_b2 = (v >= 0.70) & (v < 0.85)
    bv2 = (v - 0.70) / 0.15
    bu2 = (u * 8.0) % 1.0
    gold_trim[in_b2] = 1.0
    plate[in_b2] = 1.0
    height_raw[in_b2] = (0.86 - 0.24 * np.abs(bv2 - 0.5) * 2.0)[in_b2]
    notch_b2 = in_b2 & (np.abs(bu2 - 0.5) < 0.06) & ((bv2 < 0.25) | (bv2 > 0.75))
    chassis[notch_b2] = 0.9
    plate[notch_b2] = 0.1
    height_raw[notch_b2] = 0.34
    seam |= in_b2 & (np.abs(bv2 - 0.5) < 0.028)
    seam |= in_b2 & (np.abs(bu2 - 0.5) < 0.018) & ((bv2 < 0.28) | (bv2 > 0.72))

    # --- Banda 3: Conductos Energéticos + Facetas Cristalinas ---
    in_b3 = v >= 0.85
    bv3 = (v - 0.85) / 0.15
    bu3 = (u * 4.0) % 1.0
    core_line = in_b3 & (np.abs(bv3 - 0.5) < 0.22)
    bevel_edge = in_b3 & (np.abs(bv3 - 0.5) >= 0.22) & (np.abs(bv3 - 0.5) < 0.36)
    chassis[in_b3] = 1.0
    height_raw[in_b3] = 0.32
    chassis[bevel_edge] = 0.6
    plate[bevel_edge] = 0.4
    height_raw[bevel_edge] = 0.56
    conduit[core_line] = 1.0
    chassis[core_line] = 0.0
    height_raw[core_line] = 0.16
    # Segmentación diagonal cristalina dentro del conducto
    crystal_cut = in_b3 & (np.abs(((bu3 * 2.0) % 1.0) - bv3) < 0.04)
    seam |= in_b3 & ((np.abs(np.abs(bv3 - 0.5) - 0.22) < 0.025) | crystal_cut)

    # Micro-grano metálico anisotrópico sutil en placas
    aniso = (np.sin(yy * 0.95) * 0.012 + np.sin((xx + yy) * 0.42) * 0.007) * plate
    height_raw = np.clip(height_raw + aniso, 0.0, 1.0)

    return {
        "seam": seam,
        "plate": np.clip(plate, 0.0, 1.0),
        "chassis": np.clip(chassis, 0.0, 1.0),
        "conduit": np.clip(conduit, 0.0, 1.0),
        "gold_trim": np.clip(gold_trim, 0.0, 1.0),
        "height_raw": height_raw,
    }


def _save_rgb(arr: np.ndarray, path: Path) -> None:
    u8 = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(u8, mode="RGB").save(path)


def _save_rgba(arr: np.ndarray, path: Path) -> None:
    u8 = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(u8, mode="RGBA").save(path)


def bake_trim_sheet() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Ink SDF a resolución 2x (2048x2048) sin compresión de detalle
    hi_masks = _build_trim_masks(SDF_SIZE)
    sdf_2x = _signed_distance_field(hi_masks["seam"])
    sdf_u8 = np.clip(sdf_2x * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(sdf_u8, mode="L").save(OUT_DIR / f"{PREFIX}_ink_sdf.png")

    # 2. Mapas físicos 1x (1024x1024)
    m = _build_trim_masks(BASE_SIZE)
    sdf_1x = np.asarray(
        Image.fromarray(sdf_u8, mode="L").resize((BASE_SIZE, BASE_SIZE), Image.BILINEAR),
        dtype=np.float32,
    ) / 255.0

    plate_w = m["plate"]
    chassis_w = m["chassis"]
    conduit_w = m["conduit"]
    gold_w = m["gold_trim"]
    height_raw = m["height_raw"]

    bevel = np.clip((sdf_1x - 0.42) / 0.24, 0.0, 1.0)
    bevel_smooth = bevel * bevel * (3.0 - 2.0 * bevel)

    # Albedo estilizado (neutro-frío listo para tintado por shader)
    col_plate = np.array([0.44, 0.50, 0.64], dtype=np.float32)
    col_chassis = np.array([0.11, 0.13, 0.22], dtype=np.float32)
    col_gold = np.array([0.92, 0.78, 0.44], dtype=np.float32)
    col_conduit = np.array([0.95, 0.24, 0.44], dtype=np.float32)
    w_tot = np.maximum(plate_w + chassis_w + conduit_w, 1e-4)
    albedo = (
        plate_w[:, :, None] * np.where(gold_w[:, :, None] > 0.5, col_gold, col_plate)
        + chassis_w[:, :, None] * col_chassis
        + conduit_w[:, :, None] * col_conduit
    ) / w_tot[:, :, None]
    albedo *= (0.78 + 0.28 * bevel_smooth[:, :, None])
    _save_rgb(albedo, OUT_DIR / f"{PREFIX}.png")

    # ID Mask (R=acento/energía, G=placa armadura, B=chasis oscuro)
    id_mask = np.stack([conduit_w, plate_w, chassis_w], axis=-1)
    _save_rgb(id_mask, OUT_DIR / f"{PREFIX}_id_mask.png")

    # Normal Map Tangent-Space multi-escala (tileable)
    h_combined = np.clip(height_raw * 0.72 + bevel_smooth * 0.28, 0.0, 1.0)
    h_fine = _box_blur_2d(h_combined, radius=2, passes=2)
    h_wide = _box_blur_2d(h_combined, radius=5, passes=2)
    dx = (np.roll(h_fine, -1, axis=1) - np.roll(h_fine, 1, axis=1)) * 0.5
    dy = (np.roll(h_fine, -1, axis=0) - np.roll(h_fine, 1, axis=0)) * 0.5
    dx_w = (np.roll(h_wide, -2, axis=1) - np.roll(h_wide, 2, axis=1)) * 0.25
    dy_w = (np.roll(h_wide, -2, axis=0) - np.roll(h_wide, 2, axis=0)) * 0.25

    strength = 4.4
    nx = -(dx * 0.68 + dx_w * 0.82) * strength
    ny = -(dy * 0.68 + dy_w * 0.82) * strength
    nz = np.ones_like(h_fine, dtype=np.float32)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    normal_rgb = np.stack([nx * inv_len * 0.5 + 0.5, ny * inv_len * 0.5 + 0.5, nz * inv_len * 0.5 + 0.5], axis=-1)
    _save_rgb(normal_rgb, OUT_DIR / f"{PREFIX}_normal.png")

    # ORM (R=Roughness, G=Cavity AO, B=Metallic)
    seam_ao = np.clip((sdf_1x - 0.34) / 0.30, 0.0, 1.0)
    macro_ao = np.clip(0.46 + 0.54 * _box_blur_2d(bevel_smooth, radius=6, passes=2), 0.28, 1.0)
    cavity_ao = np.clip(seam_ao * 0.45 + macro_ao * 0.55, 0.22, 1.0)
    roughness = np.clip(
        plate_w * (0.28 - 0.10 * gold_w + (1.0 - bevel_smooth) * 0.22)
        + chassis_w * 0.78
        + conduit_w * 0.24,
        0.14,
        0.92,
    )
    metallic = np.clip(plate_w * (0.56 + 0.32 * gold_w) + chassis_w * 0.12 + conduit_w * 0.20, 0.0, 0.92)
    orm_rgb = np.stack([roughness, cavity_ao, metallic], axis=-1)
    _save_rgb(orm_rgb, OUT_DIR / f"{PREFIX}_pbr_orm.png")

    # ILM Mask (R=Spec, G=AO, B=Gold/Trim, A=Emissive)
    spec_v = np.clip(1.0 - roughness, 0.08, 0.95)
    ilm_rgba = np.stack([spec_v, cavity_ao, gold_w, conduit_w], axis=-1)
    _save_rgba(ilm_rgba, OUT_DIR / f"{PREFIX}_ilm_mask.png")

    meta = {
        "schema_version": 1,
        "prefix": PREFIX,
        "base_size": BASE_SIZE,
        "ink_sdf_size": SDF_SIZE,
        "sdf_range_texels": SDF_RANGE_TEXELS,
        "bands_v": {
            "armor_plates": [0.0, 0.40],
            "keel_ribs_and_vents": [0.40, 0.70],
            "astral_gold_trim": [0.70, 0.85],
            "energy_conduits": [0.85, 1.00],
        },
    }
    (OUT_DIR / f"{PREFIX}_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"Baked trim-sheet bundle in {OUT_DIR} ({BASE_SIZE}x{BASE_SIZE}, ink_sdf {SDF_SIZE}x{SDF_SIZE})")


if __name__ == "__main__":
    bake_trim_sheet()
