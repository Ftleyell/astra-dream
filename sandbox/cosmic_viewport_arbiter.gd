class_name CosmicViewportArbiter
extends RefCounted

## cosmic_viewport_arbiter.gd
## Árbitro estricto de visibilidad anti-duplicados por frustum de viewport.
## Garantiza que dentro del área de pantalla de la cámara (con margen de seguridad del +20%)
## no coexistan más de:
## - 1 Galaxia simultánea.
## - 1 Singularidad (Agujero Negro / Púlsar) simultánea.
## - 1 Planeta de la misma variante visual simultánea.

var margin_factor: float = 1.20
var max_galaxies: int = 1
var max_singularities: int = 1
var max_same_variant_planets: int = 1

var _visible_galaxies: int = 0
var _visible_singularities: int = 0
var _visible_planet_variants: Dictionary = {}


func _init(config: SpaceEnvironmentConfig = null) -> void:
	if config != null:
		margin_factor = config.viewport_margin_factor
		max_galaxies = config.max_visible_galaxies
		max_singularities = config.max_visible_singularities
		max_same_variant_planets = config.max_visible_same_variant_planets


## Reinicia el tracking para el cuadro o ciclo de evaluación actual.
func reset_frame() -> void:
	_visible_galaxies = 0
	_visible_singularities = 0
	_visible_planet_variants.clear()


## Determina si una posición de renderizado cae dentro del frustum con margen de seguridad.
func is_in_viewport(
	render_pos: Vector2,
	camera_pos: Vector2,
	viewport_size: Vector2,
	zoom: Vector2 = Vector2.ONE
) -> bool:
	var safe_zoom: Vector2 = Vector2(
		maxf(absf(zoom.x), 0.001),
		maxf(absf(zoom.y), 0.001)
	)
	var half_visible: Vector2 = (viewport_size / safe_zoom) * 0.5 * margin_factor
	var offset: Vector2 = render_pos - camera_pos
	return absf(offset.x) <= half_visible.x and absf(offset.y) <= half_visible.y


## Evalúa si un cuerpo celeste puede ser visible según las reglas anti-duplicado.
## Retorna true si es admisible, o false si viola la cuota de unicidad visual en pantalla.
func evaluate_item(
	type: String,
	variant: int,
	render_pos: Vector2,
	camera_pos: Vector2,
	viewport_size: Vector2,
	zoom: Vector2 = Vector2.ONE
) -> bool:
	var inside: bool = is_in_viewport(render_pos, camera_pos, viewport_size, zoom)
	if not inside:
		# Fuera del viewport no compite por las cuotas de pantalla
		return true

	match type:
		"galaxy":
			if _visible_galaxies >= max_galaxies:
				return false
			_visible_galaxies += 1
			return true

		"black_hole", "pulsar":
			if _visible_singularities >= max_singularities:
				return false
			_visible_singularities += 1
			return true

		"planet":
			var cur_count: int = _visible_planet_variants.get(variant, 0)
			if cur_count >= max_same_variant_planets:
				return false
			_visible_planet_variants[variant] = cur_count + 1
			return true

		"sun", "station":
			# Los soles y estaciones tácticas no tienen cuota restrictiva única
			return true

		_:
			return true


func get_visible_galaxies_count() -> int:
	return _visible_galaxies


func get_visible_singularities_count() -> int:
	return _visible_singularities


func get_visible_planet_variant_count(variant: int) -> int:
	return _visible_planet_variants.get(variant, 0)
