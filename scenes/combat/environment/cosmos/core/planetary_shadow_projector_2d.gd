class_name CosmosPlanetaryShadowProjector2D
extends Node2D

## Componente modular responsable de proyectar sombras cónicas y gestionar oclusiones/eclipses interplanetarios.
## Administra el CanvasGroup unificado para prevenir Double-Darkening y actualiza los parámetros del shader de sombra.

const PLANETARY_SHADOW_CONE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/planetary_shadow_cone.gdshader")
const COSMIC_SHADOW_GROUP_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/cosmic_shadow_group.gdshader")
const PLANETARY_CREPUSCULAR_SHAFT_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/planetary_crepuscular_shaft.gdshader")

var shadow_config: CosmosShadowSystemConfig = null
var shadows_enabled: bool = true
var shadow_opacity: float = 0.75
var shadow_penumbra_ratio: float = 0.45
var shadow_expansion_factor: float = 1.85
var shadow_heliopause_fade: float = 0.22
var shadow_tint: Color = Color(0.18, 0.18, 0.24, 1.0)
var umbra_convergence: float = 0.42
var shadow_dust_noise_strength: float = 0.24
var atmospheric_refraction_strength: float = 0.55
var crepuscular_rim_strength: float = 0.45

var _star_radius: float = 220.0
var _star_color: Color = Color(1.0, 0.88, 0.65, 1.0)
var _crepuscular_enabled: bool = true

var _shadow_group: CanvasGroup = null
var _shadow_group_mat: ShaderMaterial = null
var _shafts_root: Node2D = null
var _registered_bodies: Array[CosmosOrbitalBody2D] = []
var _planet_pivots: Dictionary = {} # CosmosOrbitalBody2D -> Node2D
var _planet_sprites: Dictionary = {} # CosmosOrbitalBody2D -> Sprite2D
var _shaft_pivots: Dictionary = {} # CosmosOrbitalBody2D -> Node2D
var _shaft_sprites: Dictionary = {} # CosmosOrbitalBody2D -> Sprite2D
var _light_quad_texture: ImageTexture = null

func _init(quad_tex: ImageTexture = null) -> void:
	name = "CosmosPlanetaryShadowProjector2D"
	_light_quad_texture = quad_tex

func setup_config(cfg: CosmosShadowSystemConfig) -> void:
	shadow_config = cfg
	if shadow_config != null:
		shadows_enabled = shadow_config.enable_planetary_shadows
		shadow_opacity = shadow_config.shadow_intensity
		shadow_penumbra_ratio = shadow_config.shadow_penumbra_ratio
		shadow_expansion_factor = shadow_config.shadow_expansion_factor
		shadow_heliopause_fade = shadow_config.shadow_heliopause_fade
		shadow_tint = shadow_config.shadow_tint
		umbra_convergence = shadow_config.umbra_convergence
		shadow_dust_noise_strength = shadow_config.shadow_dust_noise_strength
		atmospheric_refraction_strength = shadow_config.atmospheric_refraction_strength
		crepuscular_rim_strength = shadow_config.crepuscular_rim_strength
	_setup_canvas_group()

func set_star_visual_context(star_col: Color, p_star_radius: float) -> void:
	_star_color = star_col
	_star_radius = maxf(p_star_radius, 40.0)
	if _shadow_group_mat != null:
		var pen_col: Color = Color(
			clampf(shadow_tint.r * 1.85 + star_col.r * 0.10, 0.16, 0.68),
			clampf(shadow_tint.g * 1.85 + star_col.g * 0.10, 0.16, 0.68),
			clampf(shadow_tint.b * 1.65 + star_col.b * 0.14, 0.20, 0.76),
			1.0
		)
		var twi_col: Color = Color(0.86, 0.45, 0.34, 1.0).lerp(star_col, 0.35)
		_shadow_group_mat.set_shader_parameter("penumbra_tint", pen_col)
		_shadow_group_mat.set_shader_parameter("twilight_tint", twi_col)

func set_crepuscular_enabled(p_enabled: bool) -> void:
	_crepuscular_enabled = p_enabled
	if is_instance_valid(_shafts_root):
		_shafts_root.visible = shadows_enabled and _crepuscular_enabled

func _setup_canvas_group() -> void:
	var parent_node: Node = get_parent() if get_parent() != null else self
	if _shadow_group == null:
		_shadow_group = CanvasGroup.new()
		_shadow_group.name = "CosmicShadowsGroup"
		_shadow_group.z_index = -2
		if COSMIC_SHADOW_GROUP_SHADER != null:
			_shadow_group_mat = ShaderMaterial.new()
			_shadow_group_mat.shader = COSMIC_SHADOW_GROUP_SHADER
			_shadow_group_mat.set_shader_parameter("shadow_tint", shadow_tint)
			_shadow_group_mat.set_shader_parameter("shadow_opacity", shadow_opacity)
			_shadow_group.material = _shadow_group_mat
		parent_node.add_child(_shadow_group)
	if _shafts_root == null:
		_shafts_root = Node2D.new()
		_shafts_root.name = "CosmicCrepuscularShafts"
		_shafts_root.z_index = -2
		_shafts_root.visible = shadows_enabled and _crepuscular_enabled
		parent_node.add_child(_shafts_root)

func get_shadow_group() -> CanvasGroup:
	return _shadow_group

func clear_projector() -> void:
	for pivot: Node2D in _planet_pivots.values():
		if is_instance_valid(pivot):
			pivot.queue_free()
	for spivot: Node2D in _shaft_pivots.values():
		if is_instance_valid(spivot):
			spivot.queue_free()
	_planet_pivots.clear()
	_planet_sprites.clear()
	_shaft_pivots.clear()
	_shaft_sprites.clear()
	_registered_bodies.clear()
	if is_instance_valid(_shadow_group):
		_shadow_group.queue_free()
	if is_instance_valid(_shafts_root):
		_shafts_root.queue_free()
	_shadow_group = null
	_shadow_group_mat = null
	_shafts_root = null

func has_registered_body(body: CosmosOrbitalBody2D) -> bool:
	return _planet_pivots.has(body)

func register_body(body: CosmosOrbitalBody2D, identifier: String) -> void:
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

	if not identifier.contains("Moon") and PLANETARY_CREPUSCULAR_SHAFT_SHADER != null:
		var shaft_pivot: Node2D = Node2D.new()
		shaft_pivot.name = "ShaftPivot_" + identifier
		var shaft_sprite: Sprite2D = Sprite2D.new()
		shaft_sprite.name = "ShadowShaftVisual"
		shaft_sprite.centered = false
		shaft_sprite.texture = _light_quad_texture
		var sh_mat: ShaderMaterial = ShaderMaterial.new()
		sh_mat.shader = PLANETARY_CREPUSCULAR_SHAFT_SHADER
		shaft_sprite.material = sh_mat
		shaft_pivot.add_child(shaft_sprite)
		if _shafts_root != null:
			_shafts_root.add_child(shaft_pivot)
		else:
			body.add_child(shaft_pivot)
		_shaft_pivots[body] = shaft_pivot
		_shaft_sprites[body] = shaft_sprite

	if not _registered_bodies.has(body):
		_registered_bodies.append(body)

func register_planet(planet_body: CosmosOrbitalBody2D, index: int) -> void:
	register_body(planet_body, str(index))

func update_projections(
	planets: Array[CosmosOrbitalBody2D],
	light_field_radius: float,
	p_star_radius: float = -1.0,
	p_global_time: float = 0.0
) -> void:
	if p_star_radius > 0.0:
		_star_radius = p_star_radius
	if not shadows_enabled:
		for pivot: Node2D in _planet_pivots.values():
			if is_instance_valid(pivot):
				pivot.visible = false
		for spivot: Node2D in _shaft_pivots.values():
			if is_instance_valid(spivot):
				spivot.visible = false
		return

	if is_instance_valid(_shafts_root):
		_shafts_root.visible = _crepuscular_enabled

	for body: CosmosOrbitalBody2D in _registered_bodies:
		if not is_instance_valid(body):
			continue
		var b_pos: Vector2 = body.position
		var live_scale: float = body.scale.x
		if body.get_parent() is CosmosOrbitalBody2D:
			var host_body: CosmosOrbitalBody2D = body.get_parent() as CosmosOrbitalBody2D
			b_pos = host_body.position + (body.position * host_body.scale)
			live_scale *= host_body.scale.x
		var b_dist: float = b_pos.length()
		var outward_dir: Vector2 = b_pos.normalized() if b_dist > 1.0 else Vector2(1.0, 0.0)
		var b_radius: float = float(body.get_meta(&"visual_radius", 130.0)) * live_scale

		var pivot: Node2D = _planet_pivots.get(body, null)
		var sprite: Sprite2D = _planet_sprites.get(body, null)
		var dist_to_heliopause: float = maxf(light_field_radius - b_dist, 50.0)
		var cone_length: float = dist_to_heliopause + 250.0
		var base_radius: float = b_radius
		var end_radius: float = base_radius * shadow_expansion_factor
		var quad_height: float = maxf(end_radius * 3.1, 260.0)

		if is_instance_valid(pivot) and is_instance_valid(sprite):
			pivot.visible = true
			pivot.position = b_pos
			pivot.rotation = outward_dir.angle()

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
				s_mat.set_shader_parameter("star_radius", _star_radius)
				s_mat.set_shader_parameter("umbra_convergence", umbra_convergence)
				s_mat.set_shader_parameter("dust_noise_strength", shadow_dust_noise_strength)
				s_mat.set_shader_parameter("atmo_refraction_strength", atmospheric_refraction_strength)
				s_mat.set_shader_parameter("global_time", p_global_time)

		var spivot: Node2D = _shaft_pivots.get(body, null)
		var ssprite: Sprite2D = _shaft_sprites.get(body, null)
		if is_instance_valid(spivot) and is_instance_valid(ssprite):
			spivot.visible = _crepuscular_enabled and crepuscular_rim_strength > 0.005
			if spivot.visible:
				spivot.position = b_pos
				spivot.rotation = outward_dir.angle()
				ssprite.position = Vector2(0.0, -quad_height * 0.5)
				ssprite.scale = Vector2(cone_length * 0.5, quad_height * 0.5)
				if ssprite.material is ShaderMaterial:
					var sh_mat: ShaderMaterial = ssprite.material as ShaderMaterial
					sh_mat.set_shader_parameter("base_radius", base_radius)
					sh_mat.set_shader_parameter("expansion_factor", shadow_expansion_factor)
					sh_mat.set_shader_parameter("penumbra_ratio", shadow_penumbra_ratio)
					sh_mat.set_shader_parameter("planet_sun_dist", b_dist)
					sh_mat.set_shader_parameter("heliopause_radius", light_field_radius)
					sh_mat.set_shader_parameter("heliosphere_edge_feather", shadow_heliopause_fade)
					sh_mat.set_shader_parameter("cone_length", cone_length)
					sh_mat.set_shader_parameter("quad_height", quad_height)
					var atmo_col: Color = body.get_meta(&"atmosphere_color", _star_color) as Color
					sh_mat.set_shader_parameter("shaft_color", _star_color.lerp(atmo_col, 0.25))
					sh_mat.set_shader_parameter("shaft_strength", crepuscular_rim_strength)
					sh_mat.set_shader_parameter("global_time", p_global_time)

func evaluate_eclipses(planets: Array[CosmosOrbitalBody2D], light_field_radius: float) -> void:
	for planet_body: CosmosOrbitalBody2D in planets:
		if not is_instance_valid(planet_body):
			continue
		var p_pos: Vector2 = planet_body.position
		var p_radius: float = float(planet_body.get_meta(&"visual_radius", 130.0)) * planet_body.scale.x
		var inter_eclipse: float = 0.0

		for other_planet: CosmosOrbitalBody2D in planets:
			if not is_instance_valid(other_planet) or other_planet == planet_body:
				continue
			var other_pos: Vector2 = other_planet.position
			var other_radius: float = float(other_planet.get_meta(&"visual_radius", 100.0)) * other_planet.scale.x
			var curr_e: float = CosmosKeplerOrbitMath.calculate_interplanetary_eclipse(
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
	if _shafts_root != null:
		_shafts_root.visible = p_enabled and _crepuscular_enabled

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
