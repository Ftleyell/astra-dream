class_name CosmosAtmosphereLayersController
extends Node

## Controlador modular sin asignaciones por frame para capas atmosféricas v2:
## - ParallaxDustMid (cortinas de polvo con paralaje ~0.38 detrás del plano de combate)
## - VolumetricHazeSprite (neblina volumétrica intermedia ~0.72 cortada por sombras)
## - CosmosForegroundAtmosphere (motas rápidas, velo solar y destello anamórfico delante a paralaje ~1.12)

@export var dust_mid_rect: CanvasItem
@export var foreground_rect: ColorRect
@export var post_grade_rect: ColorRect
@export var volumetric_haze_sprite: Sprite2D

var _dust_mat: ShaderMaterial = null
var _fg_mat: ShaderMaterial = null
var _post_grade_mat: ShaderMaterial = null
var _haze_mat: ShaderMaterial = null
var _quality_level: int = 2
var _fallback_quad_tex: ImageTexture = null


func _ready() -> void:
	_ensure_haze_texture()
	_cache_materials()
	apply_graphics_quality(_quality_level)


func _ensure_haze_texture() -> void:
	var needs_haze_tex: bool = volumetric_haze_sprite != null and volumetric_haze_sprite.texture == null
	var needs_dust_tex: bool = dust_mid_rect is Sprite2D and (dust_mid_rect as Sprite2D).texture == null
	if not needs_haze_tex and not needs_dust_tex:
		return
	if _fallback_quad_tex == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_fallback_quad_tex = ImageTexture.create_from_image(img)
	if needs_haze_tex:
		volumetric_haze_sprite.texture = _fallback_quad_tex
	if needs_dust_tex:
		(dust_mid_rect as Sprite2D).texture = _fallback_quad_tex


func _cache_materials() -> void:
	if dust_mid_rect != null and dust_mid_rect.material is ShaderMaterial:
		_dust_mat = dust_mid_rect.material as ShaderMaterial
	if foreground_rect != null and foreground_rect.material is ShaderMaterial:
		_fg_mat = foreground_rect.material as ShaderMaterial
	if post_grade_rect != null and post_grade_rect.material is ShaderMaterial:
		_post_grade_mat = post_grade_rect.material as ShaderMaterial
	if volumetric_haze_sprite != null and volumetric_haze_sprite.material is ShaderMaterial:
		_haze_mat = volumetric_haze_sprite.material as ShaderMaterial


## Escala activación de capas según calidad gráfica (0=Bajo, 1=Medio, 2=Alto).
func apply_graphics_quality(quality_level: int) -> void:
	_quality_level = clampi(quality_level, 0, 2)
	_cache_materials()
	var enable_dust: bool = (_quality_level >= 1)
	var enable_fg: bool = (_quality_level >= 1)
	var enable_veil: bool = (_quality_level >= 2)

	if dust_mid_rect != null and is_instance_valid(dust_mid_rect):
		dust_mid_rect.visible = enable_dust
		var dust_layer: CanvasLayer = dust_mid_rect.get_parent() as CanvasLayer
		if dust_layer != null:
			dust_layer.visible = enable_dust

	if foreground_rect != null and is_instance_valid(foreground_rect):
		foreground_rect.visible = enable_fg
		var fg_layer: CanvasLayer = foreground_rect.get_parent() as CanvasLayer
		if fg_layer != null:
			fg_layer.visible = enable_fg

	if post_grade_rect != null and is_instance_valid(post_grade_rect):
		post_grade_rect.visible = enable_fg

	if volumetric_haze_sprite != null and is_instance_valid(volumetric_haze_sprite):
		volumetric_haze_sprite.visible = enable_veil

	if _fg_mat != null:
		_fg_mat.set_shader_parameter("enable_solar_veil", enable_veil)
		_fg_mat.set_shader_parameter("enable_anamorphic_glare", enable_veil)
	if _post_grade_mat != null:
		_post_grade_mat.set_shader_parameter("enable_optical_wash", enable_veil)


## Sincroniza cámara, tiempo cósmico, bioma activo y luz de estrella dominante sin allocs.
func update_view_and_lighting(
	world_pos: Vector2,
	global_time: float,
	biome_primary: Color,
	biome_secondary: Color,
	star_screen_pos: Vector2,
	star_color: Color,
	star_influence: float,
	viewport_size: Vector2,
	camera_zoom: float = 1.0,
	star_screen_uv: Vector2 = Vector2(0.5, 0.5),
	star_visibility: float = 1.0,
	is_black_hole: bool = false,
	planet_occluders: Array[Vector4] = [],
	occluder_count: int = 0,
	player_screen_uv: Vector2 = Vector2(0.5, 0.5),
	player_eclipse: float = 0.0,
	player_vel_norm: Vector2 = Vector2.ZERO,
	domain_entry_pulse: float = 0.0,
	player_aura_color: Color = Color(0.98, 0.16, 0.34, 1.0),
	player_aura_radius_v: float = 0.20,
	player_aura_energy: float = 1.0,
	player_wing_axis: Vector2 = Vector2(1.0, 0.0),
	star_heliopause_uv_r: float = 1.2
) -> void:
	if _dust_mat == null and _fg_mat == null and _post_grade_mat == null and _haze_mat == null:
		_cache_materials()

	if _dust_mat != null and dust_mid_rect != null and dust_mid_rect.visible:
		var dust_eff_zoom: float = maxf(camera_zoom, 0.05)
		if dust_mid_rect is Sprite2D:
			var dust_spr: Sprite2D = dust_mid_rect as Sprite2D
			dust_spr.global_position = world_pos
			dust_spr.scale = (viewport_size / dust_eff_zoom) * 0.70
		_dust_mat.set_shader_parameter("camera_world_position", world_pos)
		_dust_mat.set_shader_parameter("viewport_resolution", viewport_size)
		_dust_mat.set_shader_parameter("camera_zoom", dust_eff_zoom)
		_dust_mat.set_shader_parameter("global_time", global_time)
		_dust_mat.set_shader_parameter("biome_primary", biome_primary)
		_dust_mat.set_shader_parameter("biome_secondary", biome_secondary)
		_dust_mat.set_shader_parameter("star_screen_pos", star_screen_pos)
		_dust_mat.set_shader_parameter("star_color", star_color)
		_dust_mat.set_shader_parameter("star_influence", star_influence)

	if _haze_mat != null and volumetric_haze_sprite != null and volumetric_haze_sprite.visible:
		var eff_zoom: float = maxf(camera_zoom, 0.05)
		volumetric_haze_sprite.global_position = world_pos
		volumetric_haze_sprite.scale = (viewport_size / eff_zoom) * 0.70
		var vp_aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
		_haze_mat.set_shader_parameter("camera_world_position", world_pos)
		_haze_mat.set_shader_parameter("viewport_resolution", viewport_size)
		_haze_mat.set_shader_parameter("camera_zoom", eff_zoom)
		_haze_mat.set_shader_parameter("global_time", global_time)
		_haze_mat.set_shader_parameter("biome_primary", biome_primary)
		_haze_mat.set_shader_parameter("biome_secondary", biome_secondary)
		_haze_mat.set_shader_parameter("star_screen_uv", star_screen_uv)
		_haze_mat.set_shader_parameter("star_color", star_color)
		_haze_mat.set_shader_parameter("star_influence", star_influence)
		_haze_mat.set_shader_parameter("star_heliopause_uv_r", star_heliopause_uv_r)
		_haze_mat.set_shader_parameter("viewport_aspect", vp_aspect)
		_haze_mat.set_shader_parameter("planet_occluder_count", mini(occluder_count, planet_occluders.size()))
		if not planet_occluders.is_empty():
			_haze_mat.set_shader_parameter("planet_occluders", planet_occluders)
		_haze_mat.set_shader_parameter("player_screen_uv", player_screen_uv)
		_haze_mat.set_shader_parameter("player_aura_color", player_aura_color)
		_haze_mat.set_shader_parameter("player_aura_radius_v", player_aura_radius_v)
		_haze_mat.set_shader_parameter("player_aura_energy", player_aura_energy)
		_haze_mat.set_shader_parameter("player_wing_axis", player_wing_axis)
		_haze_mat.set_shader_parameter("player_eclipse_factor", player_eclipse)

	if _fg_mat != null and foreground_rect != null and foreground_rect.visible:
		_fg_mat.set_shader_parameter("camera_world_position", world_pos)
		_fg_mat.set_shader_parameter("viewport_resolution", viewport_size)
		_fg_mat.set_shader_parameter("global_time", global_time)
		_fg_mat.set_shader_parameter("biome_secondary", biome_secondary)
		_fg_mat.set_shader_parameter("star_screen_pos", star_screen_pos)
		_fg_mat.set_shader_parameter("star_color", star_color)
		_fg_mat.set_shader_parameter("star_influence", star_influence)
		_fg_mat.set_shader_parameter("star_screen_visibility", star_visibility)
		_fg_mat.set_shader_parameter("is_black_hole_star", is_black_hole)
		_fg_mat.set_shader_parameter("player_velocity_screen", player_vel_norm)
		_fg_mat.set_shader_parameter("domain_entry_pulse", domain_entry_pulse)

	if _post_grade_mat != null and post_grade_rect != null and post_grade_rect.visible:
		_post_grade_mat.set_shader_parameter("viewport_resolution", viewport_size)
		_post_grade_mat.set_shader_parameter("global_time", global_time)
		_post_grade_mat.set_shader_parameter("biome_primary", biome_primary)
		_post_grade_mat.set_shader_parameter("biome_secondary", biome_secondary)
		_post_grade_mat.set_shader_parameter("star_screen_pos", star_screen_pos)
		_post_grade_mat.set_shader_parameter("star_color", star_color)
		_post_grade_mat.set_shader_parameter("star_influence", star_influence)
		_post_grade_mat.set_shader_parameter("domain_entry_pulse", domain_entry_pulse)
