class_name OrbitalWeapon3DRenderer
extends SubViewport
## Renderizador SubViewport 3D transparente por slot para el Rail-Lance Autónomo.
## Renderiza la malla 3D facetada con cel-shading ArcSys y contorno inverted-hull
## permitiendo rotación orbital 360° real sin pop de flip ni efecto acordeón.

const ToonShader = preload("res://sandbox/pilot_rig_lab/guns_lab/rail_lance_toon_3d.gdshader")
const OutlineShader = preload("res://sandbox/pilot_rig_lab/guns_lab/rail_lance_outline_3d.gdshader")
const MeshBuilderScript = preload("res://sandbox/pilot_rig_lab/guns_lab/rail_lance_3d_mesh_builder.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")

const VIEWPORT_PX: int = 256
const CAMERA_FOV_DEG: float = 30.0
const CAMERA_DIST_Z: float = 9.8

const BASE_ARMOR_COLOR := Color(0.88, 0.92, 0.97, 1.0)
const BASE_CHASSIS_COLOR := Color(0.12, 0.16, 0.25, 1.0)
const BASE_CRYSTAL_COLOR := Color(0.92, 0.14, 0.32, 1.0)
const BASE_SHADOW_TINT := Color(0.52, 0.55, 0.72, 1.0)
const BASE_KEY_LIGHT_DIR := Vector3(-0.48, 0.68, 0.55)

var _camera: Camera3D = null
var _weapon_pivot: Node3D = null
var _weapon_body: Node3D = null
var _mesh_instance: MeshInstance3D = null
var _mats: Array[ShaderMaterial] = []
var _outline_mat: ShaderMaterial = null


func _ready() -> void:
	size = Vector2i(VIEWPORT_PX, VIEWPORT_PX)
	transparent_bg = true
	own_world_3d = true
	use_hdr_2d = true
	msaa_3d = SubViewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_camera = Camera3D.new()
	_camera.name = "WeaponCam3D"
	_camera.fov = CAMERA_FOV_DEG
	_camera.near = 0.1
	_camera.far = 30.0
	_camera.position = Vector3(0.0, 0.0, CAMERA_DIST_Z)
	add_child(_camera)

	_weapon_pivot = Node3D.new()
	_weapon_pivot.name = "WeaponPivot3D"
	add_child(_weapon_pivot)

	_weapon_body = Node3D.new()
	_weapon_body.name = "WeaponBody3D"
	_weapon_pivot.add_child(_weapon_body)

	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OutlineShader

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RailLanceMesh3D"
	_mesh_instance.mesh = MeshBuilderScript.build_rail_lance_mesh()

	var kinds: Array[int] = [0, 1, 2]
	var defaults: Array[Color] = [BASE_ARMOR_COLOR, BASE_CHASSIS_COLOR, BASE_CRYSTAL_COLOR]
	_mats.clear()
	for i: int in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = ToonShader
		mat.set_shader_parameter("material_kind", kinds[i])
		mat.set_shader_parameter("base_color", defaults[i])
		mat.next_pass = _outline_mat
		_mesh_instance.set_surface_override_material(i, mat)
		_mats.append(mat)

	_weapon_body.add_child(_mesh_instance)


func update_pose(
	aim_dir_3d: Vector3,
	up_dir_3d: Vector3,
	recoil: float,
	recoil_pitch_rad: float,
	orbit_depth: float,
	depth_back_dim: float,
	depth_back_tint: Color,
	rim_strength: float,
	rim_color: Color,
	spec_strength: float,
	fire_flash: float,
	fire_glow_color: Color
) -> void:
	if _weapon_pivot != null and aim_dir_3d.length_squared() > 0.0001:
		var fwd: Vector3 = aim_dir_3d.normalized()
		var safe_up: Vector3 = up_dir_3d.normalized() if up_dir_3d.length_squared() > 0.0001 else Vector3.UP
		if absf(fwd.dot(safe_up)) > 0.96:
			safe_up = Vector3.BACK if absf(fwd.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
		_weapon_pivot.basis = Basis.looking_at(fwd, safe_up)

	if _weapon_body != null:
		_weapon_body.position = Vector3(0.0, 0.0, recoil * 0.38)
		_weapon_body.rotation = Vector3(recoil_pitch_rad, 0.0, 0.0)

	for mat: ShaderMaterial in _mats:
		if mat == null:
			continue
		mat.set_shader_parameter("orbit_depth", orbit_depth)
		mat.set_shader_parameter("depth_back_dim", depth_back_dim)
		mat.set_shader_parameter("depth_back_tint", depth_back_tint)
		mat.set_shader_parameter("rim_strength", rim_strength)
		mat.set_shader_parameter("rim_color", rim_color)
		mat.set_shader_parameter("specular_sweep_strength", spec_strength)
		mat.set_shader_parameter("fire_flash", fire_flash)
		mat.set_shader_parameter("fire_glow_color", fire_glow_color)

	if _outline_mat != null:
		_outline_mat.set_shader_parameter("orbit_depth", orbit_depth)
		_outline_mat.set_shader_parameter("depth_back_dim", depth_back_dim)


func apply_skin_palette(
	recolor_enabled: bool,
	accent_col: Color,
	panel_col: Color,
	dark_col: Color
) -> void:
	if _mats.size() < 3:
		return
	if not recolor_enabled:
		_mats[0].set_shader_parameter("base_color", BASE_ARMOR_COLOR)
		_mats[1].set_shader_parameter("base_color", BASE_CHASSIS_COLOR)
		_mats[2].set_shader_parameter("base_color", BASE_CRYSTAL_COLOR)
		return

	_mats[0].set_shader_parameter("base_color", panel_col.lerp(Color(0.92, 0.94, 0.98), 0.25))
	_mats[1].set_shader_parameter("base_color", dark_col)
	_mats[2].set_shader_parameter("base_color", accent_col)


func apply_cosmic_lighting(sample: CosmicLightingSampleScript) -> void:
	if _mats.is_empty():
		return
	if sample == null:
		var def_dir: Vector3 = BASE_KEY_LIGHT_DIR.normalized()
		for mat: ShaderMaterial in _mats:
			if mat == null:
				continue
			mat.set_shader_parameter("key_light_dir", def_dir)
			mat.set_shader_parameter("key_light_tint", Color.WHITE)
			mat.set_shader_parameter("key_light_boost", 1.0)
			mat.set_shader_parameter("shadow_tint", BASE_SHADOW_TINT)
			mat.set_shader_parameter("emissive_boost", 1.0)
		return

	var l_dir_3d: Vector3 = sample.light_dir_3d.normalized() if sample.light_dir_3d.length_squared() > 0.0001 else BASE_KEY_LIGHT_DIR.normalized()
	var eff_key_tint: Color = Color.WHITE.lerp(sample.key_light_tint, clampf(sample.star_tint_weight, 0.0, 1.0))
	var eclipse: float = clampf(sample.eclipse_factor, 0.0, 1.0)
	var floor_v: float = clampf(sample.visibility_floor, 0.25, 1.0)
	var eff_key_boost: float = maxf(
		(1.0 + clampf(sample.star_proximity, 0.0, 1.0) * 0.12) * lerpf(1.0, floor_v, eclipse),
		floor_v
	)
	var biome_3d_shadow: Color = BASE_SHADOW_TINT.lerp(sample.shadow_tint.lightened(0.32), clampf(sample.biome_shadow_weight, 0.0, 1.0))
	var eff_emissive: float = maxf(sample.emissive_boost_mult, 1.0)

	for mat: ShaderMaterial in _mats:
		if mat == null:
			continue
		mat.set_shader_parameter("key_light_dir", l_dir_3d)
		mat.set_shader_parameter("key_light_tint", eff_key_tint)
		mat.set_shader_parameter("key_light_boost", eff_key_boost)
		mat.set_shader_parameter("shadow_tint", biome_3d_shadow)
		mat.set_shader_parameter("emissive_boost", eff_emissive)


func get_muzzle_uv_offset() -> Vector2:
	if not is_inside_tree() or _camera == null or _weapon_body == null:
		return Vector2.ZERO
	var world_muzzle: Vector3 = _weapon_body.to_global(MeshBuilderScript.MUZZLE_LOCAL_POS)
	var screen_pos: Vector2 = _camera.unproject_position(world_muzzle)
	return screen_pos - Vector2(size) * 0.5
