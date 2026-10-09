class_name SectorManager
extends Node

## sector_manager.gd
## Administrador espacial de biomas con interpolación quíntica continua (Ken Perlin Smootherstep).
## Evalúa la posición de la nave y sincroniza suavemente los parámetros del shader cósmico.

class SpatialSector:
	var center: Vector2
	var radius: float
	var transition_width: float
	var data: BiomeData

	func _init(p_center: Vector2, p_radius: float, p_width: float, p_data: BiomeData) -> void:
		center = p_center
		radius = p_radius
		transition_width = p_width
		data = p_data

@export var ship_reference: Node2D
@export var cosmic_quad: ColorRect:
	set(value):
		cosmic_quad = value
		if is_instance_valid(cosmic_quad) and cosmic_quad.material is ShaderMaterial:
			_shader_material = cosmic_quad.material as ShaderMaterial
			_push_spatial_sectors_to_shader()
@export var neutral_biome: BiomeData
@export var blend_speed: float = 2.5

var _sectors: Array[SpatialSector] = []
var _shader_material: ShaderMaterial

# Estados interpolados en memoria
var _cur_space_color: Color = Color(0.01, 0.012, 0.025, 1.0)
var _cur_neb_primary: Color = Color(0.18, 0.05, 0.32, 1.0)
var _cur_neb_secondary: Color = Color(0.02, 0.22, 0.40, 1.0)
var _cur_density: float = 0.90
var _cur_scale: float = 0.00035
var _cur_star_density: float = 90.0
var _cur_star_cutoff: float = 0.965
var _cur_aberration: float = 0.0

var _forced_biome: BiomeData = null



func _ready() -> void:
	if is_instance_valid(cosmic_quad) and cosmic_quad.material is ShaderMaterial:
		_shader_material = cosmic_quad.material as ShaderMaterial

	_setup_neutral_baseline()
	_push_spatial_sectors_to_shader()


func register_sector(center: Vector2, radius: float, transition_width: float, biome: BiomeData) -> void:
	_sectors.append(SpatialSector.new(center, radius, transition_width, biome))
	_push_spatial_sectors_to_shader()


func _push_spatial_sectors_to_shader() -> void:
	if not is_instance_valid(_shader_material):
		if is_instance_valid(cosmic_quad) and cosmic_quad.material is ShaderMaterial:
			_shader_material = cosmic_quad.material as ShaderMaterial
		else:
			return

	var count: int = mini(_sectors.size(), 4)
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	var widths: Array[float] = []
	var colors_prim: Array[Color] = []
	var colors_sec: Array[Color] = []
	var densities: Array[float] = []

	for i: int in range(4):
		if i < count:
			var s: SpatialSector = _sectors[i]
			centers.append(s.center)
			radii.append(s.radius)
			widths.append(s.transition_width)
			colors_prim.append(s.data.nebula_primary if s.data else Color.MAGENTA)
			colors_sec.append(s.data.nebula_secondary if s.data else Color.CYAN)
			densities.append(s.data.nebula_density if s.data else 0.8)
		else:
			centers.append(Vector2.ZERO)
			radii.append(0.0)
			widths.append(1.0)
			colors_prim.append(Color.TRANSPARENT)
			colors_sec.append(Color.TRANSPARENT)
			densities.append(0.0)

	_shader_material.set_shader_parameter("sector_count", count)
	_shader_material.set_shader_parameter("sector_centers", centers)
	_shader_material.set_shader_parameter("sector_radii", radii)
	_shader_material.set_shader_parameter("sector_transition_widths", widths)
	_shader_material.set_shader_parameter("sector_colors_primary", colors_prim)
	_shader_material.set_shader_parameter("sector_colors_secondary", colors_sec)
	_shader_material.set_shader_parameter("sector_densities", densities)


func _setup_neutral_baseline() -> void:
	if not neutral_biome:
		neutral_biome = BiomeData.new()
	_cur_space_color = neutral_biome.space_color
	_cur_neb_primary = neutral_biome.nebula_primary
	_cur_neb_secondary = neutral_biome.nebula_secondary
	_cur_density = neutral_biome.nebula_density
	_cur_scale = neutral_biome.nebula_scale
	_cur_star_density = neutral_biome.star_density
	_cur_star_cutoff = neutral_biome.star_brightness_cutoff
	_cur_aberration = neutral_biome.chromatic_aberration


func force_biome(biome: BiomeData) -> void:
	_forced_biome = biome


func clear_forced_biome() -> void:
	_forced_biome = null


func get_active_biome_name() -> String:
	if _forced_biome != null:
		return _forced_biome.sector_name
	return "Modo Espacial Libre"


func _process(delta: float) -> void:
	if not is_instance_valid(_shader_material):
		if is_instance_valid(cosmic_quad) and cosmic_quad.material is ShaderMaterial:
			_shader_material = cosmic_quad.material as ShaderMaterial
		else:
			return

	var target: Dictionary
	if _forced_biome != null:
		target = {
			"space_color": _forced_biome.space_color,
			"nebula_primary": _forced_biome.nebula_primary,
			"nebula_secondary": _forced_biome.nebula_secondary,
			"nebula_density": _forced_biome.nebula_density,
			"nebula_scale": _forced_biome.nebula_scale,
			"star_density": _forced_biome.star_density,
			"star_cutoff": _forced_biome.star_brightness_cutoff,
			"chromatic_aberration": _forced_biome.chromatic_aberration
		}
	else:
		if not is_instance_valid(ship_reference):
			var vp: Viewport = get_viewport()
			if is_instance_valid(vp):
				var cam: Camera2D = vp.get_camera_2d()
				if is_instance_valid(cam):
					ship_reference = cam
			if not is_instance_valid(ship_reference):
				return

		target = _sample_spatial_biome(ship_reference.global_position)
	var t: float = clampf(delta * blend_speed, 0.0, 1.0)


	_cur_space_color = _cur_space_color.lerp(target.space_color as Color, t)
	_cur_neb_primary = _cur_neb_primary.lerp(target.nebula_primary as Color, t)
	_cur_neb_secondary = _cur_neb_secondary.lerp(target.nebula_secondary as Color, t)
	_cur_density = lerpf(_cur_density, target.nebula_density as float, t)
	_cur_scale = lerpf(_cur_scale, target.nebula_scale as float, t)
	_cur_star_density = lerpf(_cur_star_density, target.star_density as float, t)
	_cur_star_cutoff = lerpf(_cur_star_cutoff, target.star_cutoff as float, t)
	_cur_aberration = lerpf(_cur_aberration, target.chromatic_aberration as float, t)

	_shader_material.set_shader_parameter("base_space_color", _cur_space_color)
	_shader_material.set_shader_parameter("nebula_color_primary", _cur_neb_primary)
	_shader_material.set_shader_parameter("nebula_color_secondary", _cur_neb_secondary)
	_shader_material.set_shader_parameter("nebula_density", _cur_density)
	_shader_material.set_shader_parameter("nebula_scale", _cur_scale)
	_shader_material.set_shader_parameter("star_density", _cur_star_density)
	_shader_material.set_shader_parameter("star_brightness_cutoff", _cur_star_cutoff)
	_shader_material.set_shader_parameter("chromatic_aberration", _cur_aberration)


func get_current_nebula_primary() -> Color:
	return _cur_neb_primary


func get_current_space_color() -> Color:
	return _cur_space_color


func get_sector_influence_by_name(target_name: String) -> float:
	if _forced_biome != null:
		return 1.0 if _forced_biome.sector_name == target_name else 0.0
	if not is_instance_valid(ship_reference):
		return 0.0
	var ship_pos: Vector2 = ship_reference.global_position
	for sector: SpatialSector in _sectors:
		if sector.data and sector.data.sector_name == target_name:
			var dist: float = ship_pos.distance_to(sector.center)
			if dist < sector.radius:
				var inner_boundary: float = sector.radius - sector.transition_width
				if dist <= inner_boundary:
					return 1.0
				var factor: float = clampf((sector.radius - dist) / maxf(sector.transition_width, 1.0), 0.0, 1.0)
				# Curva quíntica C2 de Perlin
				return factor * factor * factor * (factor * (factor * 6.0 - 15.0) + 10.0)
	return 0.0



func get_graveyard_influence() -> float:
	return get_sector_influence_by_name("Cementerio Mecánico")


func _sample_spatial_biome(ship_pos: Vector2) -> Dictionary:
	var total_weight: float = 0.0
	var acc_space: Color = Color.BLACK
	var acc_prim: Color = Color.BLACK
	var acc_sec: Color = Color.BLACK
	var acc_density: float = 0.0
	var acc_scale: float = 0.0
	var acc_star_density: float = 0.0
	var acc_cutoff: float = 0.0
	var acc_aberration: float = 0.0

	for sector: SpatialSector in _sectors:
		var dist: float = ship_pos.distance_to(sector.center)
		var inner_boundary: float = sector.radius - sector.transition_width

		if dist < sector.radius:
			var w: float = 1.0
			if dist > inner_boundary:
				var factor: float = (sector.radius - dist) / maxf(sector.transition_width, 1.0)
				# Curva quíntica de Ken Perlin (Smootherstep: 6t^5 - 15t^4 + 10t^3)
				w = factor * factor * factor * (factor * (factor * 6.0 - 15.0) + 10.0)

			total_weight += w
			acc_space += sector.data.space_color * w
			acc_prim += sector.data.nebula_primary * w
			acc_sec += sector.data.nebula_secondary * w
			acc_density += sector.data.nebula_density * w
			acc_scale += sector.data.nebula_scale * w
			acc_star_density += sector.data.star_density * w
			acc_cutoff += sector.data.star_brightness_cutoff * w
			acc_aberration += sector.data.chromatic_aberration * w

	if total_weight < 1.0:
		var fill: float = 1.0 - total_weight
		acc_space += neutral_biome.space_color * fill
		acc_prim += neutral_biome.nebula_primary * fill
		acc_sec += neutral_biome.nebula_secondary * fill
		acc_density += neutral_biome.nebula_density * fill
		acc_scale += neutral_biome.nebula_scale * fill
		acc_star_density += neutral_biome.star_density * fill
		acc_cutoff += neutral_biome.star_brightness_cutoff * fill
		acc_aberration += neutral_biome.chromatic_aberration * fill
	else:
		acc_space /= total_weight
		acc_prim /= total_weight
		acc_sec /= total_weight
		acc_density /= total_weight
		acc_scale /= total_weight
		acc_star_density /= total_weight
		acc_cutoff /= total_weight
		acc_aberration /= total_weight

	return {
		"space_color": acc_space,
		"nebula_primary": acc_prim,
		"nebula_secondary": acc_sec,
		"nebula_density": acc_density,
		"nebula_scale": acc_scale,
		"star_density": acc_star_density,
		"star_cutoff": acc_cutoff,
		"chromatic_aberration": acc_aberration
	}
