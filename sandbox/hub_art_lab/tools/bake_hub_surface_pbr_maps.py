"""Hornea mapas físicos Normal (Tangent-Space) y ORM (Roughness/AO/Metallic) a 2x/native
para las superficies del Hub 3D (hub_floor_astral y hub_wall_astral) usando PIL + NumPy.
"""

from pathlib import Path
import numpy as np
from PIL import Image


SURFACE_DIR = Path(__file__).resolve().parent.parent / "assets" / "surfaces"
BASES = ["hub_floor_astral", "hub_wall_astral"]


def box_blur_2d(arr: np.ndarray, radius: int, passes: int = 2) -> np.ndarray:
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


def bake_surface(base_name: str) -> None:
    alb_path = SURFACE_DIR / f"{base_name}.png"
    id_path = SURFACE_DIR / f"{base_name}_id_mask.png"
    ilm_path = SURFACE_DIR / f"{base_name}_ilm_mask.png"
    sdf_path = SURFACE_DIR / f"{base_name}_ink_sdf.png"

    alb_img = Image.open(alb_path).convert("RGB")
    w, h = alb_img.size

    id_img = Image.open(id_path).convert("RGB").resize((w, h), Image.NEAREST)
    ilm_img = Image.open(ilm_path).convert("RGBA").resize((w, h), Image.BILINEAR)
    sdf_img = Image.open(sdf_path).convert("L").resize((w, h), Image.BILINEAR)

    alb = np.asarray(alb_img, dtype=np.float32) / 255.0
    id_m = np.asarray(id_img, dtype=np.float32) / 255.0
    ilm = np.asarray(ilm_img, dtype=np.float32) / 255.0
    sdf = np.asarray(sdf_img, dtype=np.float32) / 255.0

    luma = 0.299 * alb[:, :, 0] + 0.587 * alb[:, :, 1] + 0.114 * alb[:, :, 2]

    # Mapa de alturas físico multicapa:
    # - Placas blindadas (id.g) elevadas (+0.78) con chaflanes suaves derivados del SDF
    # - Chasis oscuro (id.b) hundido (+0.24)
    # - Conductos emisivos (id.r) acanalados (+0.12)
    plate_w = id_m[:, :, 1]
    chassis_w = id_m[:, :, 2]
    conduit_w = id_m[:, :, 0]

    # El SDF >= 0.5 indica interior lejos de la junta Ink; creamos bisel físico suave en [0.44 .. 0.64]
    bevel = np.clip((sdf - 0.43) / 0.22, 0.0, 1.0)
    bevel_smooth = bevel * bevel * (3.0 - 2.0 * bevel)

    # Micro-relieve mecánico y grano metálico direccional sutil
    yy, xx = np.mgrid[0:h, 0:w]
    aniso_grain = np.sin(yy * 0.85) * 0.014 + np.sin((xx + yy) * 0.35) * 0.008

    raw_height = (
        plate_w * (0.48 + 0.36 * bevel_smooth + 0.14 * luma)
        + chassis_w * (0.16 + 0.18 * bevel_smooth + 0.08 * luma)
        + conduit_w * (0.08 + 0.10 * ilm[:, :, 3])
        + ilm[:, :, 1] * 0.12
    )
    height = box_blur_2d(raw_height, radius=2, passes=2) + aniso_grain * plate_w

    # Sobel / diferencias finitas periódicas (tileable!) para Normal Map Tangent-Space
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    # Escala amplia adicional para que los biseles se lean bien a distancia diorama
    h_wide = box_blur_2d(raw_height, radius=5, passes=2)
    dx_w = (np.roll(h_wide, -2, axis=1) - np.roll(h_wide, 2, axis=1)) * 0.25
    dy_w = (np.roll(h_wide, -2, axis=0) - np.roll(h_wide, 2, axis=0)) * 0.25

    strength = 4.6
    nx = -(dx * 0.65 + dx_w * 0.85) * strength
    ny = -(dy * 0.65 + dy_w * 0.85) * strength
    nz = np.ones_like(height, dtype=np.float32)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len

    normal_rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
    normal_u8 = np.clip(normal_rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    normal_out = SURFACE_DIR / f"{base_name}_normal.png"
    Image.fromarray(normal_u8, mode="RGB").save(normal_out)

    # Packed ORM Map:
    # R = Roughness: placas metálicas semi-pulidas (0.24..0.38), chasis y zanjas mate (0.76..0.88)
    # G = Cavity AO: oclusión ambiental física en zanjas, biseles y bordes Ink
    # B = Metallic: placas metálicas (0.58), chasis oscuro (0.10)
    seam_ao = np.clip((sdf - 0.36) / 0.28, 0.0, 1.0)
    macro_ao = np.clip(0.45 + 0.55 * box_blur_2d(bevel_smooth, radius=7, passes=2), 0.32, 1.0)
    cavity_ao = np.clip(ilm[:, :, 1] * 0.45 + seam_ao * 0.35 + macro_ao * 0.25, 0.22, 1.0)

    roughness = np.clip(
        plate_w * (0.28 - 0.08 * ilm[:, :, 0] + (1.0 - bevel_smooth) * 0.26)
        + chassis_w * (0.78 - 0.06 * luma)
        + conduit_w * 0.35,
        0.16,
        0.92,
    )
    metallic = np.clip(plate_w * 0.62 + chassis_w * 0.10 + conduit_w * 0.20, 0.0, 0.85)

    orm_rgb = np.stack([roughness, cavity_ao, metallic], axis=-1)
    orm_u8 = np.clip(orm_rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    orm_out = SURFACE_DIR / f"{base_name}_pbr_orm.png"
    Image.fromarray(orm_u8, mode="RGB").save(orm_out)
    print(f"Baked {normal_out.name} & {orm_out.name} ({w}x{h})")


if __name__ == "__main__":
    for b in BASES:
        bake_surface(b)
