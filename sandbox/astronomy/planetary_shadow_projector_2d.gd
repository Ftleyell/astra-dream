class_name PlanetaryShadowProjector2D
extends Node2D

## Componente modular responsable de proyectar sombras cónicas y gestionar oclusiones/eclipses interplanetarios.
## Administra el CanvasGroup unificado para prevenir Double-Darkening y actualiza los parámetros del shader de sombra.

const PLANETARY_SHADOW_CONE_SHADER: Shader = preload("res://sandbox/shaders/planetary_shadow_cone.gdshader")
const COSMIC_SHADOW_GROUP_SHADER: Shader = preload("res://sandbox/shaders/cosmic_shadow_group.gdshader")

var shadow_config: ShadowSystemConfig = null
var shadows_enabled: bool = true
var shadow_opacity: float = 0.75
var shadow_penumbra_ratio: float = 0.45
var shadow_expansion_factor: float = 1.85
var shadow_heliopause_fade: float = 0.22
var shadow_tint: Color = Color(0.18, 0.18, 0.24, 1.0)

var _shadow_group: CanvasGroup = null
var _shadow_group_mat: ShaderMaterial = null
var _registered_bodies: Array[OrbitalBody2D] = []
var _planet_pivots: Dictionary = {} # OrbitalBody2D -> Node2D
var _planet_sprites: Dictionary = {} # OrbitalBody2D -> Sprite2D
var _light_quad_texture: ImageTexture = null

func _init(quad_tex: ImageTexture = null) -> void:
	name = "PlanetaryShadowProjector2D"
	_light_quad_texture = quad_tex

func setup_config(cfg: ShadowSystemConfig) -> void:
	shadow_config = cfg
	if shadow_config != null:
		shadows_enabled = shadow_config.enable_planetary_shadows
		shadow_opacity = shadow_config.shadow_intensity
		shadow_penumbra_ratio = shadow_config.shadow_penumbra_ratio
		shadow_expansion_factor = shadow_config.shadow_expansion_factor
		shadow_heliopause_fade = shadow_config.shadow_heliopause_fade
		shadow_tint = shadow_config.shadow_tint
	_setup_canvas_group()

func _setup_canvas_group() -> void:
	if _shadow_group != null:
		return
	_shadow_group = CanvasGroup.new()
	_shadow_group.name = "CosmicShadowsGroup"
	_shadow_group.z_index = -1
	if COSMIC_SHADOW_GROUP_SHADER != null:
		_shadow_group_mat = ShaderMaterial.new()
		_shadow_group_mat.shader = COSMIC_SHADOW_GROUP_SHADER
		_shadow_group_mat.set_shader_parameter("shadow_tint", shadow_tint)
		_shadow_group_mat.set_shader_parameter("shadow_opacity", shadow_opacity)
		_shadow_group.material = _shadow_group_mat
	var parent_node: Node = get_parent() if get_parent() != null else self
	parent_node.add_child(_shadow_group)

func get_shadow_group() -> CanvasGroup:
	return _shadow_group

func clear_projector() -> void:
	for pivot: Node2D in _planet_pivots.values():
		if is_instance_valid(pivot):
			pivot.queue_free()
	_planet_pivots.clear()
	_planet_sprites.clear()
	_registered_bodies.clear()
	if is_instance_valid(_shadow_group):
		_shadow_group.queue_free()
	_shadow_group = null
	_shadow_group_mat = null

func has_registered_body(body: OrbitalBody2D) -> bool:
	return _planet_pivots.has(body)

func register_body(body: OrbitalBody2D, identifier: String) -> void:
	if not shadows_enabled or PLANETARY_SHADOW_CONE_SHADER == null or body == null:
		return

	var shadow_pivot: Node2D = Node2D.new()
	shadow_pivot.name = "ShadowPivot_" + identifier

	var shadow_sprite: Sprite2D = Sprite2D.new()
	shadow_sprite.name = "ShadowConeVisual"
	shadow_sprite.centered = false
	shadow_sprite.texture = _light_quad_texture

	var s_mat: ShaderMaterial = ShaderMaterial.new()
	s_mat.shader = PLANETARY_SHADOW_CONE_SHADER
	shadow_sprite.material = s_mat

	shadow_pivot.add_child(shadow_sprite)
	if _shadow_group != null:
		_shadow_group.add_child(shadow_pivot)
	else:
		body.add_child(shadow_pivot)

	_planet_pivots[body] = shadow_pivot
	_planet_sprites[body] = shadow_sprite
	if not _registered_bodies.has(body):
		_registered_bodies.append(body)

func register_planet(planet_body: OrbitalBody2D, index: int) -> void:
	register_body(planet_body, str(index))

func update_projections(planets: Array[OrbitalBody2D], light_field_radius: float) -> void:
	if not shadows_enabled:
		for pivot: Node2D in _planet_pivots.values():
			if is_instance_valid(pivot):
				pivot.visible = false
		return

	for body: OrbitalBody2D in _registered_bodies:
		if not is_instance_valid(body):
			continue
		var b_pos: Vector2 = body.position
		if body.get_parent() is OrbitalBody2D:
			b_pos += (body.get_parent() as OrbitalBody2D).position
		var b_dist: float = b_pos.length()
		var outward_dir: Vector2 = b_pos.normalized() if b_dist > 1.0 else Vector2(1.0, 0.0)
		var b_radius: float = float(body.get_meta(&"visual_radius", 130.0))

		var pivot: Node2D = _planet_pivots.get(body, null)
		var sprite: Sprite2D = _planet_sprites.get(body, null)
		if is_instance_valid(pivot) and is_instance_valid(sprite):
			pivot.visible = true
			pivot.position = b_pos
			pivot.rotation = outward_dir.angle()

			var dist_to_heliopause: float = maxf(light_field_radius - b_dist, 50.0)
			var cone_length: float = dist_to_heliopause + 250.0
			var base_radius: float = b_radius
			var end_radius: float = base_radius * shadow_expansion_factor
			var quad_height: float = maxf(end_radius * 2.5, 200.0)

			sprite.position = Vector2(0.0, -quad_height * 0.5)
			sprite.scale = Vector2(cone_length * 0.5, quad_height * 0.5)

			if sprite.material is ShaderMaterial:
				var s_mat: ShaderMaterial = sprite.material as ShaderMaterial
				s_mat.set_shader_parameter("base_radius", base_radius)
				s_mat.set_shader_parameter("expansion_factor", shadow_expansion_factor)
				s_mat.set_shader_parameter("penumbra_ratio", shadow_penumbra_ratio)
				s_mat.set_shader_parameter("planet_sun_dist", b_dist)
				s_mat.set_shader_parameter("heliopause_radius", light_field_radius)
				s_mat.set_shader_parameter("heliosphere_edge_feather", shadow_heliopause_fade)
				s_mat.set_shader_parameter("cone_length", cone_length)
				s_mat.set_shader_parameter("quad_height", quad_height)

func evaluate_eclipses(planets: Array[OrbitalBody2D], light_field_radius: float) -> void:
	for planet_body: OrbitalBody2D in planets:
		if not is_instance_valid(planet_body):
			continue
		var p_pos: Vector2 = planet_body.position
		var p_radius: float = float(planet_body.get_meta(&"visual_radius", 130.0))
		var inter_eclipse: float = 0.0

		for other_planet: OrbitalBody2D in planets:
			if not is_instance_valid(other_planet) or other_planet == planet_body:
				continue
			var other_pos: Vector2 = other_planet.position
			var other_radius: float = float(other_planet.get_meta(&"visual_radius", 100.0))
			var curr_e: float = KeplerOrbitMath.calculate_interplanetary_eclipse(
				p_pos, p_radius,
				other_pos, other_radius,
				shadow_expansion_factor, shadow_penumbra_ratio, light_field_radius
			)
			inter_eclipse = maxf(inter_eclipse, curr_e)

		var p_sprite: Sprite2D = planet_body.get_sprite()
		if p_sprite != null and p_sprite.material is ShaderMaterial:
			(p_sprite.material as ShaderMaterial).set_shader_parameter("eclipse_shadow", inter_eclipse)

func set_shadows_enabled(p_enabled: bool) -> void:
	shadows_enabled = p_enabled
	if _shadow_group != null:
		_shadow_group.visible = p_enabled

func set_shadow_opacity(p_opacity: float) -> void:
	shadow_opacity = p_opacity
	if _shadow_group_mat != null:
		_shadow_group_mat.set_shader_parameter("shadow_opacity", shadow_opacity)

func set_shadow_penumbra_ratio(p_ratio: float) -> void:
	shadow_penumbra_ratio = p_ratio

func set_shadow_expansion_factor(p_factor: float) -> void:
	shadow_expansion_factor = p_factor

func set_shadow_heliopause_fade(p_fade: float) -> void:
	shadow_heliopause_fade = p_fade
