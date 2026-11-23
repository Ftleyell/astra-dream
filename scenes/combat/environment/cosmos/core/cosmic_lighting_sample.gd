class_name CosmicLightingSample
extends RefCounted

## Value Object puro (sin punteros a SceneTree/nodos) con la muestra analítica de iluminación cósmica.
## Captura dirección solar 2D/3D, tintes estelares, sombras de bioma, oclusión por eclipse y realce emisivo.

var light_dir_2d: Vector2 = Vector2(-0.58, -0.81).normalized()
var light_dir_3d: Vector3 = Vector3(-0.50, 0.70, 0.50).normalized()
var key_light_tint: Color = Color(1.04, 1.02, 0.97, 1.0)
var rim_key_color: Color = Color(0.87, 0.95, 1.0, 1.0)
var shadow_tint: Color = Color(0.145, 0.145, 0.335, 1.0)
var ao_tint: Color = Color(0.078, 0.064, 0.175, 1.0)

var eclipse_factor: float = 0.0
var star_proximity: float = 0.0
var star_tint_weight: float = 0.0
var rim_tint_weight: float = 0.0
var biome_shadow_weight: float = 0.0
var visibility_floor: float = 0.58
var emissive_boost_mult: float = 1.0

var has_active_star: bool = false
var dominant_star_name: StringName = &""
var dominant_star_distance: float = INF


func reset_defaults(fallback_dir_2d: Vector2 = Vector2(-0.58, -0.81), light_z_3d: float = 0.55) -> void:
	var n2d: Vector2 = fallback_dir_2d.normalized() if fallback_dir_2d.length_squared() > 0.0001 else Vector2(-0.58, -0.81).normalized()
	light_dir_2d = n2d
	light_dir_3d = Vector3(n2d.x, -n2d.y, light_z_3d).normalized()
	key_light_tint = Color(1.04, 1.02, 0.97, 1.0)
	rim_key_color = Color(0.87, 0.95, 1.0, 1.0)
	shadow_tint = Color(0.145, 0.145, 0.335, 1.0)
	ao_tint = Color(0.078, 0.064, 0.175, 1.0)
	eclipse_factor = 0.0
	star_proximity = 0.0
	star_tint_weight = 0.0
	rim_tint_weight = 0.0
	biome_shadow_weight = 0.0
	visibility_floor = 0.58
	emissive_boost_mult = 1.0
	has_active_star = false
	dominant_star_name = &""
	dominant_star_distance = INF


func copy_from(other: CosmicLightingSample) -> void:
	if other == null:
		return
	light_dir_2d = other.light_dir_2d
	light_dir_3d = other.light_dir_3d
	key_light_tint = other.key_light_tint
	rim_key_color = other.rim_key_color
	shadow_tint = other.shadow_tint
	ao_tint = other.ao_tint
	eclipse_factor = other.eclipse_factor
	star_proximity = other.star_proximity
	star_tint_weight = other.star_tint_weight
	rim_tint_weight = other.rim_tint_weight
	biome_shadow_weight = other.biome_shadow_weight
	visibility_floor = other.visibility_floor
	emissive_boost_mult = other.emissive_boost_mult
	has_active_star = other.has_active_star
	dominant_star_name = other.dominant_star_name
	dominant_star_distance = other.dominant_star_distance


func smooth_toward(target: CosmicLightingSample, dir_t: float, color_t: float) -> void:
	if target == null:
		return
	var dt: float = clampf(dir_t, 0.0, 1.0)
	var ct: float = clampf(color_t, 0.0, 1.0)

	var cur_2d: Vector2 = light_dir_2d.normalized() if light_dir_2d.length_squared() > 0.0001 else Vector2.UP
	var tgt_2d: Vector2 = target.light_dir_2d.normalized() if target.light_dir_2d.length_squared() > 0.0001 else Vector2.UP
	if cur_2d.dot(tgt_2d) < -0.99:
		cur_2d = cur_2d.rotated(0.12)
	var blended_2d: Vector2 = cur_2d.lerp(tgt_2d, dt)
	light_dir_2d = blended_2d.normalized() if blended_2d.length_squared() > 0.0001 else tgt_2d

	var cur_3d: Vector3 = light_dir_3d.normalized() if light_dir_3d.length_squared() > 0.0001 else Vector3.UP
	var tgt_3d: Vector3 = target.light_dir_3d.normalized() if target.light_dir_3d.length_squared() > 0.0001 else Vector3.UP
	if cur_3d.dot(tgt_3d) < -0.99:
		cur_3d = Vector3(cur_3d.x + 0.1, cur_3d.y, cur_3d.z).normalized()
	var blended_3d: Vector3 = cur_3d.lerp(tgt_3d, dt)
	light_dir_3d = blended_3d.normalized() if blended_3d.length_squared() > 0.0001 else tgt_3d

	key_light_tint = key_light_tint.lerp(target.key_light_tint, ct)
	rim_key_color = rim_key_color.lerp(target.rim_key_color, ct)
	shadow_tint = shadow_tint.lerp(target.shadow_tint, ct)
	ao_tint = ao_tint.lerp(target.ao_tint, ct)

	eclipse_factor = lerpf(eclipse_factor, target.eclipse_factor, ct)
	star_proximity = lerpf(star_proximity, target.star_proximity, ct)
	star_tint_weight = lerpf(star_tint_weight, target.star_tint_weight, ct)
	rim_tint_weight = lerpf(rim_tint_weight, target.rim_tint_weight, ct)
	biome_shadow_weight = lerpf(biome_shadow_weight, target.biome_shadow_weight, ct)
	visibility_floor = lerpf(visibility_floor, target.visibility_floor, ct)
	emissive_boost_mult = lerpf(emissive_boost_mult, target.emissive_boost_mult, ct)

	has_active_star = target.has_active_star
	dominant_star_name = target.dominant_star_name
	dominant_star_distance = target.dominant_star_distance
