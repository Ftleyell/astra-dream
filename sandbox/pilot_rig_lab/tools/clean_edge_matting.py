"""Limpia halos/matting blanco en bordes semitransparentes de PNGs de color (parts_5 y heads)."""
from __future__ import annotations

import os
import sys
import numpy as np
from PIL import Image, ImageFilter


INK_RGB = np.array([10, 10, 20], dtype=np.uint8)


def clean_png_edges(path: str) -> tuple[int, int]:
	img = Image.open(path).convert("RGBA")
	arr = np.array(img, dtype=np.uint8)
	rgb = arr[:, :, :3].astype(np.float32)
	a = arr[:, :, 3]

	# 1. Eliminar polvo sub-umbral exterior + 1px de borde claro tocando alpha == 0
	dust_mask = (a > 0) & (a < 28)
	dust_count = int(np.sum(dust_mask))
	a[dust_mask] = 0

	luma = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
	padded_a0 = np.pad(a, 1, mode="constant", constant_values=0)
	min_nb_a0 = np.minimum.reduce([
		padded_a0[0:-2, 0:-2], padded_a0[0:-2, 1:-1], padded_a0[0:-2, 2:],
		padded_a0[1:-1, 0:-2],                        padded_a0[1:-1, 2:],
		padded_a0[2:,   0:-2], padded_a0[2:,   1:-1], padded_a0[2:,   2:],
	])
	erode_light = (a > 0) & (min_nb_a0 == 0) & (luma > 42.0)
	dust_count += int(np.sum(erode_light))
	a[erode_light] = 0

	# 2. De-matting de píxeles semitransparentes claros en el borde (28 <= a < 250)
	semi_bright = (a >= 28) & (a < 250) & (luma > 55.0)

	# Verificar si tiene algún vecino transparente (es decir, es borde exterior real)
	padded_a = np.pad(a, 1, mode="constant", constant_values=0)
	min_neighbor_a = np.minimum.reduce([
		padded_a[0:-2, 0:-2], padded_a[0:-2, 1:-1], padded_a[0:-2, 2:],
		padded_a[1:-1, 0:-2],                       padded_a[1:-1, 2:],
		padded_a[2:,   0:-2], padded_a[2:,   1:-1], padded_a[2:,   2:],
	])
	outer_fringe = semi_bright & (min_neighbor_a < 225)
	fringe_count = int(np.sum(outer_fringe))

	if fringe_count > 0:
		# Mezcla proporcional hacia tinta oscura según qué tan claro/exterior sea
		t = np.clip((luma[outer_fringe] - 68.0) / 80.0, 0.45, 1.0)[:, None]
		rgb[outer_fringe] = rgb[outer_fringe] * (1.0 - t) + INK_RGB.astype(np.float32) * t

	# 3. Bleeding de color hacia píxeles alpha == 0 desde vecinos opacos (3 pasadas para parallax y bilineal)
	arr[:, :, :3] = np.clip(rgb, 0.0, 255.0).astype(np.uint8)
	arr[:, :, 3] = a

	bleed_a = a.copy()
	for _pass in range(3):
		zero_a = bleed_a == 0
		if not np.any(zero_a):
			break
		padded_rgb = np.pad(arr[:, :, :3], ((1, 1), (1, 1), (0, 0)), mode="constant", constant_values=0)
		padded_ba = np.pad(bleed_a, 1, mode="constant", constant_values=0)
		best_rgb = np.zeros_like(arr[:, :, :3])
		best_a = np.zeros_like(bleed_a)
		for dy in (-1, 0, 1):
			for dx in (-1, 0, 1):
				if dy == 0 and dx == 0:
					continue
				nb_a = padded_ba[1 + dy:1 + dy + a.shape[0], 1 + dx:1 + dx + a.shape[1]]
				nb_rgb = padded_rgb[1 + dy:1 + dy + a.shape[0], 1 + dx:1 + dx + a.shape[1]]
				better = zero_a & (nb_a > best_a)
				best_rgb[better] = nb_rgb[better]
				best_a[better] = nb_a[better]
		fill_mask = zero_a & (best_a > 0)
		arr[fill_mask, :3] = best_rgb[fill_mask]
		bleed_a[fill_mask] = best_a[fill_mask]

	still_zero = bleed_a == 0
	arr[still_zero, :3] = INK_RGB

	# 4. Re-antialiasing SDF suave + dilatación uniforme de ~0.45px en tinta para eliminar dientes de sierra
	a_img = Image.fromarray(a, "L")
	blur_a = np.array(a_img.filter(ImageFilter.GaussianBlur(radius=1.10)), dtype=np.float32) / 255.0
	t_aa = np.clip((blur_a - 0.28) / 0.36, 0.0, 1.0)
	smooth_a = t_aa * t_aa * (3.0 - 2.0 * t_aa)
	new_a = np.clip(np.round(smooth_a * 255.0), 0.0, 255.0).astype(np.uint8)

	# Asegurar que el borde expandido/suavizado sea tinta oscura (excepto el tope superior de piernas bajo body_core y la ventana del cuello)
	new_edge = (new_a > 0) & (a < 210)
	if os.path.basename(path) in ("leg_l.png", "leg_r.png"):
		new_edge[:10, :] = False
	elif os.path.basename(path) == "body_core.png":
		h, w = new_edge.shape
		yy, xx = np.mgrid[:h, :w]
		neck_win = (yy < int(h * 0.075)) & (np.abs(xx - w * 0.42) < (w * 0.15))
		new_edge[neck_win] = False
	arr[new_edge, :3] = INK_RGB
	arr[:, :, 3] = new_a

	Image.fromarray(arr, "RGBA").save(path, optimize=False)
	return dust_count, fringe_count


def main() -> int:
	root = sys.argv[1] if len(sys.argv) > 1 else "sandbox/pilot_rig_lab/combat_assets/valentina_planar"
	if not os.path.isdir(root):
		print(f"Directory not found: {root}")
		return 1

	total_files = 0
	total_dust = 0
	total_fringe = 0
	for dp, _, fs in os.walk(root):
		for f in sorted(fs):
			if not f.endswith(".png"):
				continue
			if any(tag in f for tag in ("_mask", "_normal_depth", "_sdf")):
				continue
			full_path = os.path.join(dp, f)
			dust, fringe = clean_png_edges(full_path)
			total_files += 1
			total_dust += dust
			total_fringe += fringe
			print(f"{os.path.relpath(full_path, root)}: dust_zeroed={dust}, fringe_darkened={fringe}")

	print(f"Done: {total_files} PNGs cleaned (dust_zeroed={total_dust}, fringe_darkened={total_fringe}).")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
