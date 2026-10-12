class_name CosmosDebrisLayoutGenerator
extends RefCounted

## Generador matemático puro y determinista para la distribución de escombros espaciales.
## Desacoplado de la escena y de la GPU para facilitar tests unitarios, ajuste de balance
## y mantenimiento sin efectos colaterales.

class DebrisInstanceData:
	var position: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var scale: Vector2 = Vector2.ONE
	var color: Color = Color.WHITE
	var uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var spin_speed: float = 0.0

## Genera el layout determinista de instancias para una celda espacial dada.
static func generate_cell_layout(
	cell: Vector2i,
	cell_size: float,
	count: int,
	run_seed: int,
	is_scrap: bool,
	profile: CosmosDebrisLayerProfile,
	macro_grid: CosmosMacroGrid,
	micro_items: Array[Dictionary],
	medium_items: Array[Dictionary],
	macro_items: Array[Dictionary],
	has_star: bool,
	star_offset: Vector2,
	kuiper_inner_radius: float
) -> Array[DebrisInstanceData]:
	var result: Array[DebrisInstanceData] = []
	if count <= 0 or macro_grid == null:
		return result

	var max_rot: float = profile.max_initial_rotation if profile != null else TAU
	var base_color: Color = profile.alpha_modulation if profile != null else Color(0.85, 0.9, 0.95, 0.75)

	var micro_ratio: float = profile.micro_ratio if profile != null else 0.70
	var medium_ratio: float = profile.medium_ratio if profile != null else 0.25

	var micro_scale_range: Vector2 = profile.micro_scale_range if profile != null else Vector2(0.20, 0.45)
	var medium_scale_range: Vector2 = profile.medium_scale_range if profile != null else Vector2(0.55, 1.10)
	var macro_scale_range: Vector2 = profile.macro_scale_range if profile != null else Vector2(1.25, 2.10)

	var micro_alpha_mult: float = profile.micro_alpha_multiplier if profile != null else 0.60
	var medium_alpha_mult: float = profile.medium_alpha_multiplier if profile != null else 0.90
	var macro_alpha_mult: float = profile.macro_alpha_multiplier if profile != null else 1.00

	var kuiper_ratio: float = profile.kuiper_belt_ratio if profile != null else 0.50
	var border_ratio: float = profile.border_corridor_ratio if profile != null else 0.40
	var kuiper_w: float = profile.kuiper_belt_width if profile != null else 700.0
	var border_w: float = profile.border_corridor_width if profile != null else 900.0

	var atlas_seed_offset: int = 19349663 if is_scrap else 0

	# Partición analítica de slots por patrón
	var n_kuiper: int = 0
	var n_border: int = 0
	var n_ambient: int = 0

	if has_star:
		n_kuiper = int(round(float(count) * kuiper_ratio))
		n_border = int(round(float(count) * border_ratio))
		n_ambient = maxi(0, count - n_kuiper - n_border)
	else:
		n_kuiper = 0
		n_border = int(round(float(count) * 0.75))
		n_ambient = maxi(0, count - n_border)

	var sub_grid_dim: int = maxi(1, int(ceil(sqrt(float(maxi(1, n_ambient))))))
	var sub_cell_size: float = cell_size / float(sub_grid_dim)

	for i: int in range(count):
		var cell_hash_seed: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (i * 83492791) ^ run_seed ^ atlas_seed_offset
		var r_rot: float = CosmosHasher.hash_2d_float(cell.x + 3 * i, cell.y + 5 * i, cell_hash_seed + 554401)
		var r_tier: float = CosmosHasher.hash_2d_float(cell.x + 7 * i, cell.y - 11 * i, cell_hash_seed + 333111)
		var r_scale: float = CosmosHasher.hash_2d_float(cell.x - 7 * i, cell.y + 2 * i, cell_hash_seed + 992811)
		var r_piece: int = int(abs(CosmosHasher.hash_2d(cell.x + 13 * i, cell.y + 17 * i, cell_hash_seed + 771123)))
		var r_lum: float = CosmosHasher.hash_2d_float(cell.x + 11 * i, cell.y - 13 * i, cell_hash_seed + 12345)
		var r_spin: float = CosmosHasher.hash_2d_float(cell.x - 17 * i, cell.y + 19 * i, cell_hash_seed + 4419)

		var pos_local: Vector2 = Vector2.ZERO

		if i < n_kuiper:
			# Patrón 1: Cinturón de Kuiper
			var slot_idx: int = i
			var slot_w: float = TAU / float(maxi(1, n_kuiper))
			var r_th: float = CosmosHasher.hash_2d_float(cell.x + slot_idx, cell.y - slot_idx, cell_hash_seed + 101)
			var r_rad: float = CosmosHasher.hash_2d_float(cell.x - slot_idx, cell.y + slot_idx, cell_hash_seed + 202)
			var theta: float = (float(slot_idx) + (r_th - 0.5) * 0.70) * slot_w
			var radius: float = kuiper_inner_radius + (r_rad * kuiper_w)
			pos_local = star_offset + Vector2(cos(theta) * radius, sin(theta) * radius)
		elif i < (n_kuiper + n_border):
			# Patrón 2: Franjas perimetrales de frontera entre celdas
			var b_idx: int = i - n_kuiper
			var side: int = b_idx % 4
			var slot_in_side: int = b_idx / 4
			var slots_per_side: int = maxi(1, int(ceil(float(n_border) / 4.0)))
			var slot_len: float = cell_size / float(slots_per_side)

			var r_lin: float = CosmosHasher.hash_2d_float(cell.x + b_idx, cell.y - b_idx, cell_hash_seed + 303)
			var r_lat: float = CosmosHasher.hash_2d_float(cell.x - b_idx, cell.y + b_idx, cell_hash_seed + 404)
			var linear_pos: float = - (cell_size * 0.5) + (float(slot_in_side) + r_lin * 0.70) * slot_len
			var lateral_offset: float = r_lat * border_w

			match side:
				0: # Borde Superior (-Y)
					pos_local = Vector2(linear_pos, -(cell_size * 0.5) + lateral_offset)
				1: # Borde Inferior (+Y)
					pos_local = Vector2(linear_pos, (cell_size * 0.5) - lateral_offset)
				2: # Borde Izquierdo (-X)
					pos_local = Vector2(-(cell_size * 0.5) + lateral_offset, linear_pos)
				3: # Borde Derecho (+X)
					pos_local = Vector2((cell_size * 0.5) - lateral_offset, linear_pos)
		else:
			# Patrón 3: Espacio abierto (sub-rejilla uniforme con jitter acotado)
			var a_idx: int = i - n_kuiper - n_border
			var gx: int = a_idx % sub_grid_dim
			var gy: int = (a_idx / sub_grid_dim) % sub_grid_dim
			var r_jx: float = CosmosHasher.hash_2d_float(cell.x + a_idx, cell.y - a_idx, cell_hash_seed + 505)
			var r_jy: float = CosmosHasher.hash_2d_float(cell.x - a_idx, cell.y + a_idx, cell_hash_seed + 606)
			var sub_x: float = -(cell_size * 0.5) + (float(gx) + 0.15 + r_jx * 0.70) * sub_cell_size
			var sub_y: float = -(cell_size * 0.5) + (float(gy) + 0.15 + r_jy * 0.70) * sub_cell_size
			pos_local = Vector2(sub_x, sub_y)

		var rotation_angle: float = r_rot * max_rot

		var piece: Dictionary
		var scale_val: float = 1.0
		var alpha_mult: float = 1.0

		if r_tier < micro_ratio:
			piece = micro_items[r_piece % micro_items.size()]
			scale_val = lerpf(micro_scale_range.x, micro_scale_range.y, r_scale)
			alpha_mult = micro_alpha_mult
		elif r_tier < (micro_ratio + medium_ratio):
			piece = medium_items[r_piece % medium_items.size()]
			scale_val = lerpf(medium_scale_range.x, medium_scale_range.y, r_scale)
			alpha_mult = medium_alpha_mult
		else:
			piece = macro_items[r_piece % macro_items.size()]
			scale_val = lerpf(macro_scale_range.x, macro_scale_range.y, r_scale)
			alpha_mult = macro_alpha_mult

		var pixel_size: Vector2 = piece.get("pixel_size", Vector2(32.0, 32.0))
		var scale_x: float = maxf(pixel_size.x * scale_val, 1.0)
		var scale_y: float = maxf(pixel_size.y * scale_val, 1.0)

		var lum_mult: float = lerpf(0.75, 1.25, r_lum)
		var inst_color: Color = Color(
			base_color.r * lum_mult,
			base_color.g * lum_mult,
			base_color.b * lum_mult,
			base_color.a * alpha_mult * lerpf(0.7, 1.0, r_lum)
		)

		var data: DebrisInstanceData = DebrisInstanceData.new()
		data.position = pos_local
		data.rotation = rotation_angle
		data.scale = Vector2(scale_x, scale_y)
		data.color = inst_color
		data.uv_rect = piece.get("uv_rect", Rect2(0.0, 0.0, 1.0, 1.0))
		data.spin_speed = (r_spin - 0.5) * 2.0 # Velocidad y sentido de rotación en GPU (-1.0 a 1.0)

		result.append(data)

	return result
