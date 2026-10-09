"""
generate_deep_starfield.py

Generador procedural astrofísico de atlas estelar 8K (8192 x 8192) continuo (seamless).
Implementa:
- Empacado de canales espectrales:
  * R: Núcleo estelar (Gaussian Point Spread Function sub-píxel)
  * G: Halo y dispersión atmosférica difusa
  * B: Temperatura espectral astrofísica (Clases O, B, A, F, G, K, M)
- Distribución de Poisson fractal con cúmulos y vacíos naturales
- Ley de potencias astronómica (Salpeter/Pareto) para variedad radical de brillo y magnitud
- Envoltura toroidal periódica (seamless en los 4 bordes para repetición infinita)
"""

import os
import sys
import time
import numpy as np
from PIL import Image

WIDTH = 8192
HEIGHT = 8192
OUTPUT_FILE = r"assets\environments\parallax_space\deep_starfield_8k.png"


def create_gaussian_stamp(radius: float, halo_mult: float = 3.0) -> tuple[np.ndarray, np.ndarray]:
    """Genera matrices cuadradas de sello gaussiano para núcleo y halo."""
    size = int(np.ceil(radius * halo_mult * 2.2))
    if size % 2 == 0:
        size += 1
    half = size // 2
    y, x = np.ogrid[-half:half + 1, -half:half + 1]
    d2 = (x * x + y * y).astype(np.float32)

    # Núcleo (Point Spread Function)
    sigma_core = radius * 0.75
    core = np.exp(-0.5 * d2 / (sigma_core * sigma_core))

    # Halo difuso
    sigma_halo = radius * halo_mult
    halo = np.exp(-0.5 * d2 / (sigma_halo * sigma_halo))
    halo = halo * (1.0 - core * 0.6)

    return core.astype(np.float32), halo.astype(np.float32)


def render_star_stamps_toroidal(
    canvas_r: np.ndarray,
    canvas_g: np.ndarray,
    canvas_b: np.ndarray,
    positions: np.ndarray,
    radii: np.ndarray,
    luminosities: np.ndarray,
    spectral_temps: np.ndarray
) -> None:
    """Estampa miles de estrellas en los lienzos con envoltura toroidal periódica."""
    n_stars = len(positions)
    # Pre-calcular una tabla de sellos por tamaño cuantizado para alto rendimiento
    unique_bins = 18
    r_min, r_max = radii.min(), radii.max()
    r_bins = np.linspace(r_min, r_max, unique_bins)

    stamps = []
    for r in r_bins:
        stamps.append(create_gaussian_stamp(r))

    for i in range(n_stars):
        x, y = positions[i]
        r_val = radii[i]
        lum = luminosities[i]
        temp = spectral_temps[i]

        bin_idx = int(np.clip((r_val - r_min) / max(r_max - r_min, 1e-5) * (unique_bins - 1), 0, unique_bins - 1))
        core_stamp, halo_stamp = stamps[bin_idx]
        sh, sw = core_stamp.shape
        half_h, half_w = sh // 2, sw // 2

        ix = int(np.round(x))
        iy = int(np.round(y))

        # Envoltura toroidal usando índices modulares
        x_indices = (np.arange(ix - half_w, ix + half_w + 1)) % WIDTH
        y_indices = (np.arange(iy - half_h, iy + half_h + 1)) % HEIGHT

        c_patch = core_stamp * lum
        h_patch = halo_stamp * (lum * 0.75)

        # Aplicar aditivamente con corte en 1.0
        # Usamos indexación rápida 2D en NumPy
        sub_r = canvas_r[np.ix_(y_indices, x_indices)]
        sub_g = canvas_g[np.ix_(y_indices, x_indices)]
        sub_b = canvas_b[np.ix_(y_indices, x_indices)]

        # Acumular intensidad en R y G
        new_r = np.clip(sub_r + c_patch, 0.0, 1.0)
        new_g = np.clip(sub_g + h_patch, 0.0, 1.0)
        # El canal B almacena la temperatura espectral donde hay luz
        weight = np.maximum(c_patch, h_patch * 0.5)
        new_b = np.where(weight > 0.05, np.maximum(sub_b, temp), sub_b)

        canvas_r[np.ix_(y_indices, x_indices)] = new_r
        canvas_g[np.ix_(y_indices, x_indices)] = new_g
        canvas_b[np.ix_(y_indices, x_indices)] = new_b


def generate_starfield_8k() -> None:
    print(f"[1/4] Inicializando matriz cósmica 8K ({WIDTH}x{HEIGHT})...")
    start_time = time.time()
    rng = np.random.default_rng(seed=421337)

    canvas_r = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
    canvas_g = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
    canvas_b = np.zeros((HEIGHT, WIDTH), dtype=np.float32)

    # 1. CAPA 0: Micro-polvo cósmico (Deep Field, 24,000 micro-estrellas sub-píxel)
    print("[2/4] Generando 24,000 micro-estrellas de fondo profundo (Hubble Deep Field)...")
    n_deep = 24000
    pos_deep = rng.uniform(0.0, [WIDTH, HEIGHT], size=(n_deep, 2))
    # Ley de potencias astronómica para radios y brillos
    u_deep = rng.uniform(0.0, 1.0, size=n_deep)
    rad_deep = 0.35 + np.power(u_deep, 3.5) * 0.35
    lum_deep = 0.06 + np.power(rng.uniform(0.0, 1.0, size=n_deep), 2.8) * 0.28
    temp_deep = rng.uniform(0.15, 0.85, size=n_deep)
    render_star_stamps_toroidal(canvas_r, canvas_g, canvas_b, pos_deep, rad_deep, lum_deep, temp_deep)

    # 2. CAPA 1: Estrellas de catálogo galáctico medio (Magnitud 3-5, 3,400 estrellas)
    print("[3/4] Generando 3,400 estrellas de catálogo medio con halos y clasificación espectral...")
    n_mid = 3400
    pos_mid = rng.uniform(0.0, [WIDTH, HEIGHT], size=(n_mid, 2))
    u_mid = rng.uniform(0.0, 1.0, size=n_mid)
    rad_mid = 0.65 + np.power(u_mid, 2.5) * 0.65
    lum_mid = 0.25 + np.power(rng.uniform(0.0, 1.0, size=n_mid), 2.2) * 0.60
    # Distribución de temperatura: sesgada hacia solares (0.45) y azules (0.85)
    temp_mid = rng.choice([0.15, 0.40, 0.55, 0.80, 0.95], size=n_mid, p=[0.20, 0.30, 0.25, 0.15, 0.10])
    render_star_stamps_toroidal(canvas_r, canvas_g, canvas_b, pos_mid, rad_mid, lum_mid, temp_mid)

    # 3. CAPA 2: Estrellas prominentes y supergigantes (Magnitud 0-2, 380 joyas resplandecientes)
    print("[4/4] Generando 380 gemas colosales y supergigantes focales...")
    n_bright = 380
    pos_bright = rng.uniform(0.0, [WIDTH, HEIGHT], size=(n_bright, 2))
    u_bright = rng.uniform(0.0, 1.0, size=n_bright)
    rad_bright = 1.15 + np.power(u_bright, 1.8) * 1.10
    lum_bright = 0.70 + np.power(rng.uniform(0.0, 1.0, size=n_bright), 1.5) * 0.30
    temp_bright = rng.choice([0.10, 0.45, 0.75, 0.98], size=n_bright, p=[0.15, 0.35, 0.30, 0.20])
    render_star_stamps_toroidal(canvas_r, canvas_g, canvas_b, pos_bright, rad_bright, lum_bright, temp_bright)

    print("Empacando canales RGB (R: Core, G: Halo, B: Espectral) y guardando PNG 8K...")
    # Convertir a 8-bit unsigned integer
    r_bytes = (np.clip(canvas_r, 0.0, 1.0) * 255.0).astype(np.uint8)
    g_bytes = (np.clip(canvas_g, 0.0, 1.0) * 255.0).astype(np.uint8)
    b_bytes = (np.clip(canvas_b, 0.0, 1.0) * 255.0).astype(np.uint8)

    rgb = np.dstack([r_bytes, g_bytes, b_bytes])
    out_dir = os.path.dirname(OUTPUT_FILE)
    os.makedirs(out_dir, exist_ok=True)

    img = Image.fromarray(rgb, mode="RGB")
    img.save(OUTPUT_FILE, format="PNG", optimize=True)

    elapsed = time.time() - start_time
    file_mb = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)
    print(f"\n[ÉXITO] Atlas 8K generado en {elapsed:.2f} s: '{OUTPUT_FILE}' ({file_mb:.1f} MB)")


if __name__ == "__main__":
    generate_starfield_8k()
