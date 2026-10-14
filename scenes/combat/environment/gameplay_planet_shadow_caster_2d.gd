class_name GameplayPlanetShadowCaster2D
extends Node2D

## GameplayPlanetShadowCaster2D.gd
## Componente modular responsable de proyectar el cono de sombra analítico (umbra y penumbra)
## de un planeta interactuable de combate respecto a la estrella central de su sistema solar en Cosmos Engine.
##
## Diseñado para:
## 1. Zero-Allocation en runtime: actualiza parámetros uniformes en ShaderMaterial sin instanciaciones dinámicas.
## 2. Compatibilidad con el shader planetary_shadow_cone.gdshader.
## 3. Fade out fluido y sincronizado al desintegrarse el planeta.

const GAMEPLAY_SHADOW_CONE_SHADER: Shader = preload("res://scenes/combat/environment/gameplay_planet_shadow_cone.gdshader")
const CosmosOrbitSlotScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const CosmosOrbitalSlotTrackerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")
const DEFAULT_SHADOW_CONFIG: CosmosShadowSystemConfig = preload("res://scenes/combat/environment/cosmos/resources/data/default_shadow_system.tres")

@export var shadow_config: CosmosShadowSystemConfig = null
@export var shadows_enabled: bool = true
@export var shadow_opacity: float = 0.75
@export var shadow_penumbra_ratio: float = 0.45
@export var shadow_expansion_factor: float = 1.85
@export var shadow_heliopause_fade: float = 0.22
@export var shadow_tint: Color = Color(0.18, 0.18, 0.24, 1.0)

var slot: CosmosOrbitSlotScript = null
var base_radius: float = 300.0
var star_world_pos: Vector2 = Vector2.ZERO

var _shadow_sprite: Sprite2D = null
var _material: ShaderMaterial = null
var _camera_ref: Camera2D = null
var _cosmos_root: CosmosRootNode = null
var _is_fading: bool = false

static var _quad_texture: ImageTexture = null

static func _get_quad_texture() -> ImageTexture:
	if _quad_texture == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_quad_texture = ImageTexture.create_from_image(img)
	return _quad_texture

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	name = "GameplayPlanetShadowCaster2D"
	z_index = -1
	_build_shadow_visual()
	_find_references()
	sync_shadow_config()

func _find_references() -> void:
	if not is_inside_tree():
		return

	if _camera_ref == null:
		_camera_ref = get_viewport().get_camera_2d()

	if _cosmos_root == null:
		var root_node: Node = get_tree().get_first_node_in_group("cosmos_root")
		if root_node is CosmosRootNode:
			_cosmos_root = root_node as CosmosRootNode
		else:
			var bg: Node = get_tree().root.find_child("SpaceBackground", true, false)
			if bg != null and bg.has_method("get_cosmos_root"):
				_cosmos_root = bg.call("get_cosmos_root") as CosmosRootNode

func _build_shadow_visual() -> void:
	if _shadow_sprite != null:
		return

	_shadow_sprite = Sprite2D.new()
	_shadow_sprite.name = "ShadowConeVisual"
	_shadow_sprite.centered = false
	_shadow_sprite.texture = _get_quad_texture()
	_shadow_sprite.modulate = Color.WHITE

	if GAMEPLAY_SHADOW_CONE_SHADER != null:
		_material = ShaderMaterial.new()
		_material.shader = GAMEPLAY_SHADOW_CONE_SHADER
		_shadow_sprite.material = _material

	add_child(_shadow_sprite)

func apply_shadow_config(cfg: CosmosShadowSystemConfig) -> void:
	if cfg == null:
		return
	shadow_config = cfg
	shadows_enabled = cfg.enable_planetary_shadows
	shadow_opacity = cfg.shadow_intensity
	shadow_penumbra_ratio = cfg.shadow_penumbra_ratio
	shadow_expansion_factor = cfg.shadow_expansion_factor
	shadow_heliopause_fade = cfg.shadow_heliopause_fade
	shadow_tint = cfg.shadow_tint

func sync_shadow_config() -> void:
	if shadow_config != null:
		apply_shadow_config(shadow_config)
		return

	var active_cfg: CosmosShadowSystemConfig = null
	if _cosmos_root != null:
		if _cosmos_root.solar_streamer != null and _cosmos_root.solar_streamer.system_profile != null:
			active_cfg = _cosmos_root.solar_streamer.system_profile.get_effective_shadow_config()
		elif _cosmos_root.environment_profile != null and _cosmos_root.environment_profile.solar_profile != null:
			active_cfg = _cosmos_root.environment_profile.solar_profile.get_effective_shadow_config()

	if active_cfg == null and slot != null and is_instance_valid(slot.body_reference):
		var parent_sys: Node = slot.body_reference.get_parent()
		if parent_sys is CosmosSolarSystem2D and (parent_sys as CosmosSolarSystem2D).system_profile != null:
			active_cfg = (parent_sys as CosmosSolarSystem2D).system_profile.get_effective_shadow_config()

	if active_cfg == null:
		active_cfg = DEFAULT_SHADOW_CONFIG

	if active_cfg != null:
		apply_shadow_config(active_cfg)

func setup_shadow_binding(p_slot: CosmosOrbitSlotScript, p_radius: float = 300.0, p_camera: Camera2D = null, p_cosmos_root: CosmosRootNode = null, p_shadow_config: CosmosShadowSystemConfig = null) -> void:
	slot = p_slot
	base_radius = p_radius
	if p_camera != null:
		_camera_ref = p_camera
	if p_cosmos_root != null:
		_cosmos_root = p_cosmos_root

	if p_shadow_config != null:
		apply_shadow_config(p_shadow_config)
	else:
		sync_shadow_config()

	_update_shadow_cone()

func _exit_tree() -> void:
	if _shadow_sprite != null and is_instance_valid(_shadow_sprite):
		if _shadow_sprite.get_parent() != self:
			_shadow_sprite.queue_free()

func get_star_world_pos() -> Vector2:
	if slot != null:
		var cam_pos: Vector2 = _camera_ref.global_position if (_camera_ref != null and is_instance_valid(_camera_ref)) else Vector2.ZERO
		var s_scale: Vector2 = slot.layer_scroll_scale
		var star_layer_pos: Vector2 = slot.center_layer_position
		return (cam_pos * (Vector2.ONE - s_scale)) + star_layer_pos
	return star_world_pos

func _process(_delta: float) -> void:
	if not shadows_enabled or _is_fading:
		return
	_update_shadow_cone()

func _update_shadow_cone() -> void:
	if _shadow_sprite == null or not is_instance_valid(_shadow_sprite):
		return

	if not shadows_enabled:
		_shadow_sprite.visible = false
		return

	_shadow_sprite.visible = true

	var parent_2d: Node2D = get_parent() as Node2D
	var planet_pos: Vector2 = parent_2d.global_position if parent_2d != null else global_position

	if _camera_ref == null or not is_instance_valid(_camera_ref):
		_camera_ref = get_viewport().get_camera_2d() if is_inside_tree() else null

	var current_star_pos: Vector2 = star_world_pos
	var heliopause_radius: float = 4500.0

	if slot != null:
		var cam_pos: Vector2 = _camera_ref.global_position if (_camera_ref != null and is_instance_valid(_camera_ref)) else Vector2.ZERO
		var s_scale: Vector2 = slot.layer_scroll_scale
		var star_layer_pos: Vector2 = slot.center_layer_position
		current_star_pos = (cam_pos * (Vector2.ONE - s_scale)) + star_layer_pos
		heliopause_radius = maxf(slot.orbit_radius * 1.5, 4500.0)

	var to_planet: Vector2 = planet_pos - current_star_pos
	var planet_sun_dist: float = to_planet.length()
	var outward_dir: Vector2 = to_planet.normalized() if planet_sun_dist > 1.0 else Vector2(1.0, 0.0)

	var dist_to_heliopause: float = maxf(heliopause_radius - planet_sun_dist, 50.0)
	var cone_length: float = dist_to_heliopause + 1200.0
	var end_radius: float = base_radius * shadow_expansion_factor
	var quad_height: float = maxf(end_radius * 2.5, 200.0)

	global_rotation = outward_dir.angle()
	_shadow_sprite.position = Vector2(0.0, -quad_height * 0.5)
	_shadow_sprite.rotation = 0.0
	_shadow_sprite.offset = Vector2.ZERO
	_shadow_sprite.scale = Vector2(cone_length * 0.5, quad_height * 0.5)

	if _material != null:
		_material.set_shader_parameter("base_radius", base_radius)
		_material.set_shader_parameter("expansion_factor", shadow_expansion_factor)
		_material.set_shader_parameter("penumbra_ratio", shadow_penumbra_ratio)
		_material.set_shader_parameter("planet_sun_dist", planet_sun_dist)
		_material.set_shader_parameter("heliopause_radius", heliopause_radius)
		_material.set_shader_parameter("heliosphere_edge_feather", shadow_heliopause_fade)
		_material.set_shader_parameter("cone_length", cone_length)
		_material.set_shader_parameter("quad_height", quad_height)
		_material.set_shader_parameter("shadow_tint", shadow_tint)
		_material.set_shader_parameter("shadow_opacity", shadow_opacity)

func fade_and_destroy(duration: float = 0.35) -> void:
	_is_fading = true
	if not is_inside_tree() or _shadow_sprite == null:
		queue_free()
		return

	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tw.tween_property(_shadow_sprite, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _material != null:
		tw.tween_property(_material, "shader_parameter/shadow_opacity", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if _shadow_sprite != null and is_instance_valid(_shadow_sprite) and _shadow_sprite.get_parent() != self:
			_shadow_sprite.queue_free()
		queue_free()
	)
