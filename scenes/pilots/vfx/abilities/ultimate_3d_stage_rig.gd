class_name Ultimate3DStageRig
extends SubViewport
## Escenario 3D Cel-Shaded HDR (TONE_MAPPER_AGX + Bloom) para Actos 2 y 3 de la Ultimate [Q].
## Pre-aloca en _ready() con arquitectura Zero-Allocation:
##   - 3 anillos giroscópicos de radar 3D en ejes ortogonales
##   - Túnel reticular espacial de 8 aros octogonales con Camera3D FOV punch (42° -> 68° -> 26°)
##   - 12 cuchillas 3D reales vía AstralWings3DMeshBuilder + astral_wing_toon_3d + astral_wing_outline_3d
##   - Pool de púas radiales 3D Sakuga (hasta 48, 24 activas por defecto) para Beats 1 y 2
##   - Pool de esquirlas 3D de cristal obsidiana (hasta 48, 28 activas por defecto) para Beat 3

const Wings3DBuilderScript = preload("res://scenes/pilots/vfx/astral_wings_3d_mesh_builder.gd")
const WingToonShader: Shader = preload("res://scenes/pilots/shaders/astral_wing_toon_3d.gdshader")
const WingOutlineShader: Shader = preload("res://scenes/pilots/shaders/astral_wing_outline_3d.gdshader")

const VIEWPORT_RES: Vector2i = Vector2i(1280, 720)
const GYRO_RING_COUNT: int = 3
const TUNNEL_RING_COUNT: int = 8
const WING_BLADE_COUNT: int = 12
const MAX_SAKUGA_SPIKES: int = 48
const MAX_SHATTER_SHARDS: int = 48

enum StageMode {
	HIDDEN = 0,
	ACT2_CUTIN_STAGE = 1,
	ACT3_BEAT1_SPIKES = 2,
	ACT3_BEAT2_CONTRAST = 3,
	ACT3_BEAT3_SHATTER = 4,
}

var _stage_mode: int = StageMode.HIDDEN
var _stage_root: Node3D = null
var _world_env: WorldEnvironment = null
var _camera: Camera3D = null
var _key_light: OmniLight3D = null
var _contrast_light: OmniLight3D = null

var _act2_group: Node3D = null
var _bg_quad: MeshInstance3D = null
var _bg_mat: StandardMaterial3D = null

var _gyro_rings: Array[Node3D] = []
var _gyro_mats: Array[StandardMaterial3D] = []

var _tunnel_rings: Array[MeshInstance3D] = []
var _tunnel_mat: StandardMaterial3D = null

var _wing_blades: Array[MeshInstance3D] = []
var _wing_armor_mat: ShaderMaterial = null
var _wing_chassis_mat: ShaderMaterial = null
var _wing_crystal_mat: ShaderMaterial = null
var _wing_outline_mat: ShaderMaterial = null
var _wing_base_angles: PackedFloat32Array = PackedFloat32Array()
var _wing_side_signs: PackedFloat32Array = PackedFloat32Array()
var _wing_tier_scales: PackedFloat32Array = PackedFloat32Array()

var _spikes_group: Node3D = null
var _sakuga_spikes: Array[MeshInstance3D] = []
var _spike_mat_light: StandardMaterial3D = null
var _spike_mat_dark: StandardMaterial3D = null
var _spike_mat_contrast: StandardMaterial3D = null
var _spike_angles: PackedFloat32Array = PackedFloat32Array()
var _spike_radii: PackedFloat32Array = PackedFloat32Array()
var _spike_z_offsets: PackedFloat32Array = PackedFloat32Array()

var _shards_group: Node3D = null
var _shatter_shards: Array[MeshInstance3D] = []
var _shard_mat_obsidian: StandardMaterial3D = null
var _shard_mat_accent: StandardMaterial3D = null
var _shard_dir_x: PackedFloat32Array = PackedFloat32Array()
var _shard_dir_y: PackedFloat32Array = PackedFloat32Array()
var _shard_dir_z: PackedFloat32Array = PackedFloat32Array()
var _shard_rot_spd: PackedFloat32Array = PackedFloat32Array()
var _shard_scales: PackedFloat32Array = PackedFloat32Array()

# Parámetros data-driven desde PilotUltimateConfig
var _fov_start: float = 42.0
var _fov_peak: float = 68.0
var _fov_snap: float = 26.0
var _gyro_speed: float = 3.2
var _active_spike_count: int = 24
var _active_shard_count: int = 28

# Paleta cromática derivada por PilotSkinPaletteResolver
var _accent_color: Color = Color(0.98, 0.14, 0.34, 1.0)
var _contrast_color: Color = Color(0.08, 0.96, 0.88, 1.0)
var _stage_bg_color: Color = Color(0.03, 0.02, 0.06, 1.0)
var _panel_color: Color = Color(0.84, 0.88, 0.96, 1.0)
var _suit_dark_color: Color = Color(0.06, 0.04, 0.11, 1.0)


func _ready() -> void:
	name = "Ultimate3DStageRig"
	size = VIEWPORT_RES
	transparent_bg = true
	use_hdr_2d = true
	own_world_3d = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_build_3d_scene()
	set_stage_state(StageMode.HIDDEN, 0.0, 0.0)


func _build_3d_scene() -> void:
	_stage_root = Node3D.new()
	_stage_root.name = "StageRoot3D"
	add_child(_stage_root)

	# 1. WorldEnvironment HDR (AgX + Bloom calibrado como Gacha/3D Wings Lab)
	_world_env = WorldEnvironment.new()
	_world_env.name = "StageEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.30, 0.46, 1.0)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.05
	env.glow_bloom = 0.24
	env.glow_intensity = 0.85
	_world_env.environment = env
	_stage_root.add_child(_world_env)

	# 2. Luces tintadas por skin + Cámara dinámica con FOV punch
	_key_light = OmniLight3D.new()
	_key_light.name = "AccentOmniLight"
	_key_light.position = Vector3(-4.0, 3.2, 4.5)
	_key_light.light_color = _accent_color
	_key_light.light_energy = 2.6
	_key_light.omni_range = 28.0
	_stage_root.add_child(_key_light)

	_contrast_light = OmniLight3D.new()
	_contrast_light.name = "ContrastOmniLight"
	_contrast_light.position = Vector3(4.2, -2.0, 3.5)
	_contrast_light.light_color = _contrast_color
	_contrast_light.light_energy = 2.2
	_contrast_light.omni_range = 28.0
	_stage_root.add_child(_contrast_light)

	_camera = Camera3D.new()
	_camera.name = "StageCamera3D"
	_camera.position = Vector3(0.0, 0.0, 5.4)
	_camera.fov = _fov_start
	_camera.near = 0.1
	_camera.far = 90.0
	_camera.current = true
	_stage_root.add_child(_camera)

	# 3. Grupo Acto 2 (Fondo + 3 Anillos Giroscópicos + Túnel Reticular + 12 Cuchillas 3D)
	_act2_group = Node3D.new()
	_act2_group.name = "Act2StageGroup"
	_stage_root.add_child(_act2_group)

	_build_backdrop_plane()
	_build_gyro_rings()
	_build_warp_tunnel()
	_build_wing_blades_3d()

	# 4. Grupo Acto 3 Beats 1 y 2 (Pool de 48 Púas Radiales 3D Sakuga)
	_build_sakuga_spikes_pool()

	# 5. Grupo Acto 3 Beat 3 (Pool de 48 Esquirlas 3D de Cristal Obsidiana)
	_build_shatter_shards_pool()


func _build_backdrop_plane() -> void:
	_bg_quad = MeshInstance3D.new()
	_bg_quad.name = "StageBgPlane"
	var qm := QuadMesh.new()
	qm.size = Vector2(96.0, 56.0)
	_bg_quad.mesh = qm
	_bg_quad.position = Vector3(0.0, 0.0, -32.0)

	_bg_mat = StandardMaterial3D.new()
	_bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bg_mat.albedo_color = _stage_bg_color
	_bg_quad.material_override = _bg_mat
	_act2_group.add_child(_bg_quad)


func _build_gyro_rings() -> void:
	var radii: Array[float] = [2.45, 3.45, 4.55]
	var thicknesses: Array[float] = [0.055, 0.048, 0.064]
	var tick_mesh := BoxMesh.new()
	tick_mesh.size = Vector3(0.08, 0.34, 0.08)

	for i: int in range(GYRO_RING_COUNT):
		var ring_pivot := Node3D.new()
		ring_pivot.name = "GyroRadarRing_%d" % i
		ring_pivot.position = Vector3(0.0, 0.0, -3.4 - float(i) * 0.9)
		_act2_group.add_child(ring_pivot)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 1.9
		var col: Color = _accent_color if (i == 1) else _contrast_color
		mat.albedo_color = col
		mat.emission = col
		_gyro_mats.append(mat)

		var torus := TorusMesh.new()
		torus.inner_radius = radii[i] - thicknesses[i]
		torus.outer_radius = radii[i] + thicknesses[i]
		torus.rings = 48
		torus.ring_segments = 12
		var ring_mi := MeshInstance3D.new()
		ring_mi.name = "Torus"
		ring_mi.mesh = torus
		ring_mi.rotation_degrees.x = 90.0
		ring_mi.material_override = mat
		ring_pivot.add_child(ring_mi)

		# 12 ticks radiales sobre cada anillo giroscópico
		for k: int in range(12):
			var ang: float = float(k) * (TAU / 12.0)
			var tick := MeshInstance3D.new()
			tick.mesh = tick_mesh
			tick.material_override = mat
			tick.position = Vector3(cos(ang) * radii[i], sin(ang) * radii[i], 0.0)
			tick.rotation.z = ang - PI * 0.5
			ring_pivot.add_child(tick)

		_gyro_rings.append(ring_pivot)


func _build_warp_tunnel() -> void:
	_tunnel_mat = StandardMaterial3D.new()
	_tunnel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tunnel_mat.emission_enabled = true
	_tunnel_mat.emission_energy_multiplier = 1.35
	_tunnel_mat.albedo_color = _accent_color.lerp(_contrast_color, 0.35)
	_tunnel_mat.emission = _tunnel_mat.albedo_color

	var oct_torus := TorusMesh.new()
	oct_torus.inner_radius = 6.8
	oct_torus.outer_radius = 6.96
	oct_torus.rings = 8
	oct_torus.ring_segments = 4

	for i: int in range(TUNNEL_RING_COUNT):
		var mi := MeshInstance3D.new()
		mi.name = "WarpTunnelRing_%02d" % i
		mi.mesh = oct_torus
		mi.rotation_degrees = Vector3(90.0, 0.0, float(i) * 22.5)
		mi.position = Vector3(0.0, 0.0, -3.0 - float(i) * 3.5)
		mi.material_override = _tunnel_mat
		_act2_group.add_child(mi)
		_tunnel_rings.append(mi)


func _build_wing_blades_3d() -> void:
	_wing_outline_mat = ShaderMaterial.new()
	_wing_outline_mat.shader = WingOutlineShader
	_wing_outline_mat.set_shader_parameter("outline_width", 0.022)

	_wing_armor_mat = ShaderMaterial.new()
	_wing_armor_mat.shader = WingToonShader
	_wing_armor_mat.set_shader_parameter("material_kind", 0)
	_wing_armor_mat.next_pass = _wing_outline_mat

	_wing_chassis_mat = ShaderMaterial.new()
	_wing_chassis_mat.shader = WingToonShader
	_wing_chassis_mat.set_shader_parameter("material_kind", 1)
	_wing_chassis_mat.next_pass = _wing_outline_mat

	_wing_crystal_mat = ShaderMaterial.new()
	_wing_crystal_mat.shader = WingToonShader
	_wing_crystal_mat.set_shader_parameter("material_kind", 2)
	_wing_crystal_mat.set_shader_parameter("emissive_boost", 1.85)
	_wing_crystal_mat.set_shader_parameter("channel_glow_strength", 1.95)
	_wing_crystal_mat.next_pass = _wing_outline_mat

	_wing_base_angles.resize(WING_BLADE_COUNT)
	_wing_side_signs.resize(WING_BLADE_COUNT)
	_wing_tier_scales.resize(WING_BLADE_COUNT)

	for i: int in range(WING_BLADE_COUNT):
		var is_right: bool = i >= 6
		var side_sign: float = 1.0 if is_right else -1.0
		var local_idx: int = (i - 6) if is_right else i
		var tier: int = AstralWings3DMeshBuilder.TIER_PRIMARY if local_idx == 0 else (AstralWings3DMeshBuilder.TIER_MID if local_idx <= 2 else AstralWings3DMeshBuilder.TIER_LOWER)

		var blade_mesh: ArrayMesh = Wings3DBuilderScript.build_wing_blade_mesh(tier)
		var mi := MeshInstance3D.new()
		mi.name = "WingBlade3D_%02d" % i
		mi.mesh = blade_mesh
		mi.set_surface_override_material(AstralWings3DMeshBuilder.SURFACE_ARMOR, _wing_armor_mat)
		mi.set_surface_override_material(AstralWings3DMeshBuilder.SURFACE_CHASSIS, _wing_chassis_mat)
		mi.set_surface_override_material(AstralWings3DMeshBuilder.SURFACE_CRYSTAL, _wing_crystal_mat)

		var fan_ang_deg: float = lerpf(42.0, -48.0, float(local_idx) / 5.0)
		_wing_base_angles[i] = deg_to_rad(fan_ang_deg)
		_wing_side_signs[i] = side_sign
		_wing_tier_scales[i] = 1.48 if local_idx == 0 else (1.32 if local_idx <= 2 else 1.18)

		_act2_group.add_child(mi)
		_wing_blades.append(mi)


func _build_sakuga_spikes_pool() -> void:
	_spikes_group = Node3D.new()
	_spikes_group.name = "SakugaSpikes3DGroup"
	_stage_root.add_child(_spikes_group)

	_spike_mat_light = StandardMaterial3D.new()
	_spike_mat_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spike_mat_light.albedo_color = Color(2.1, 2.1, 2.2, 1.0)

	_spike_mat_dark = StandardMaterial3D.new()
	_spike_mat_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spike_mat_dark.albedo_color = Color(0.01, 0.01, 0.02, 1.0)

	_spike_mat_contrast = StandardMaterial3D.new()
	_spike_mat_contrast.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spike_mat_contrast.emission_enabled = true
	_spike_mat_contrast.emission_energy_multiplier = 2.2
	_spike_mat_contrast.albedo_color = _contrast_color
	_spike_mat_contrast.emission = _contrast_color

	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.005
	spike_mesh.bottom_radius = 0.14
	spike_mesh.height = 4.6
	spike_mesh.radial_segments = 4

	_spike_angles.resize(MAX_SAKUGA_SPIKES)
	_spike_radii.resize(MAX_SAKUGA_SPIKES)
	_spike_z_offsets.resize(MAX_SAKUGA_SPIKES)

	for i: int in range(MAX_SAKUGA_SPIKES):
		var ang: float = (float(i) / float(MAX_SAKUGA_SPIKES)) * TAU + fmod(float(i) * 0.37, 0.14)
		_spike_angles[i] = ang
		_spike_radii[i] = 3.2 + fmod(float(i) * 0.71, 1.65)
		_spike_z_offsets[i] = -1.8 + fmod(float(i) * 0.53, 2.8)

		var mi := MeshInstance3D.new()
		mi.name = "SakugaSpike3D_%02d" % i
		mi.mesh = spike_mesh
		mi.material_override = _spike_mat_light if (i % 2 == 0) else _spike_mat_dark
		_spikes_group.add_child(mi)
		_sakuga_spikes.append(mi)


func _build_obsidian_shard_mesh() -> ArrayMesh:
	# Cristal triangular facetado de 6 caras (bipirámide asimétrica)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v_tip := Vector3(0.0, 0.55, 0.0)
	var v_bot := Vector3(0.0, -0.45, 0.0)
	var v0 := Vector3(0.32, 0.05, 0.08)
	var v1 := Vector3(-0.24, 0.08, 0.22)
	var v2 := Vector3(-0.08, -0.04, -0.26)

	var faces: Array[Array] = [
		[v_tip, v0, v1], [v_tip, v1, v2], [v_tip, v2, v0],
		[v_bot, v1, v0], [v_bot, v2, v1], [v_bot, v0, v2],
	]
	for f: Array in faces:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		st.set_normal(n)
		st.add_vertex(a)
		st.set_normal(n)
		st.add_vertex(b)
		st.set_normal(n)
		st.add_vertex(c)
	return st.commit()


func _build_shatter_shards_pool() -> void:
	_shards_group = Node3D.new()
	_shards_group.name = "ObsidianShards3DGroup"
	_stage_root.add_child(_shards_group)

	_shard_mat_obsidian = StandardMaterial3D.new()
	_shard_mat_obsidian.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_shard_mat_obsidian.albedo_color = Color(0.02, 0.015, 0.04, 1.0)
	_shard_mat_obsidian.metallic = 0.65
	_shard_mat_obsidian.roughness = 0.14
	_shard_mat_obsidian.emission_enabled = true
	_shard_mat_obsidian.emission = _accent_color
	_shard_mat_obsidian.emission_energy_multiplier = 0.65

	_shard_mat_accent = StandardMaterial3D.new()
	_shard_mat_accent.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shard_mat_accent.emission_enabled = true
	_shard_mat_accent.emission_energy_multiplier = 2.1
	_shard_mat_accent.albedo_color = _contrast_color
	_shard_mat_accent.emission = _contrast_color

	var shard_mesh: ArrayMesh = _build_obsidian_shard_mesh()
	_shard_dir_x.resize(MAX_SHATTER_SHARDS)
	_shard_dir_y.resize(MAX_SHATTER_SHARDS)
	_shard_dir_z.resize(MAX_SHATTER_SHARDS)
	_shard_rot_spd.resize(MAX_SHATTER_SHARDS)
	_shard_scales.resize(MAX_SHATTER_SHARDS)

	for i: int in range(MAX_SHATTER_SHARDS):
		var ang: float = (float(i) / float(MAX_SHATTER_SHARDS)) * TAU + fmod(float(i) * 1.13, 0.45)
		var spread: float = 0.55 + fmod(float(i) * 0.43, 1.25)
		_shard_dir_x[i] = cos(ang) * spread
		_shard_dir_y[i] = sin(ang) * spread * 0.72
		_shard_dir_z[i] = 1.6 + fmod(float(i) * 0.67, 2.4)
		_shard_rot_spd[i] = 5.5 + fmod(float(i) * 1.37, 8.5)
		_shard_scales[i] = 0.68 + fmod(float(i) * 0.29, 0.95)

		var mi := MeshInstance3D.new()
		mi.name = "ObsidianShard3D_%02d" % i
		mi.mesh = shard_mesh
		mi.material_override = _shard_mat_accent if (i % 5 == 0) else _shard_mat_obsidian
		_shards_group.add_child(mi)
		_shatter_shards.append(mi)


func configure_from_ult(cfg: PilotUltimateConfig) -> void:
	if cfg == null:
		return
	cfg.ensure_defaults()
	_fov_start = cfg.stage_3d_fov_start
	_fov_peak = cfg.stage_3d_fov_peak
	_fov_snap = cfg.stage_3d_fov_snap
	_gyro_speed = cfg.stage_3d_gyro_speed
	_active_spike_count = clampi(cfg.sakuga_3d_spike_count, 4, MAX_SAKUGA_SPIKES)
	_active_shard_count = clampi(cfg.shatter_3d_shard_count, 4, MAX_SHATTER_SHARDS)


func apply_palette(palette: Dictionary, suit_dark: Color = Color(0.06, 0.04, 0.11, 1.0)) -> void:
	if palette.has("accent"):
		_accent_color = palette["accent"] as Color
	if palette.has("contrast_crosshair"):
		_contrast_color = palette["contrast_crosshair"] as Color
	if palette.has("stage_bg"):
		_stage_bg_color = palette["stage_bg"] as Color
	if palette.has("panel"):
		_panel_color = palette["panel"] as Color
	_suit_dark_color = suit_dark

	if _bg_mat != null:
		_bg_mat.albedo_color = _stage_bg_color
	if _key_light != null:
		_key_light.light_color = _accent_color
	if _contrast_light != null:
		_contrast_light.light_color = _contrast_color
	for i: int in range(_gyro_mats.size()):
		var col: Color = _accent_color if (i == 1) else _contrast_color
		_gyro_mats[i].albedo_color = col
		_gyro_mats[i].emission = col
	if _tunnel_mat != null:
		var tcol: Color = _accent_color.lerp(_contrast_color, 0.35)
		_tunnel_mat.albedo_color = tcol
		_tunnel_mat.emission = tcol
	if _wing_armor_mat != null:
		_wing_armor_mat.set_shader_parameter("base_color", _panel_color.lerp(Color.WHITE, 0.35))
		_wing_armor_mat.set_shader_parameter("fire_glow_color", _accent_color)
	if _wing_chassis_mat != null:
		_wing_chassis_mat.set_shader_parameter("base_color", _suit_dark_color)
		_wing_chassis_mat.set_shader_parameter("fire_glow_color", _accent_color)
	if _wing_crystal_mat != null:
		_wing_crystal_mat.set_shader_parameter("base_color", _accent_color)
		_wing_crystal_mat.set_shader_parameter("fire_glow_color", _accent_color)
	if _spike_mat_contrast != null:
		_spike_mat_contrast.albedo_color = _contrast_color
		_spike_mat_contrast.emission = _contrast_color
	if _shard_mat_obsidian != null:
		_shard_mat_obsidian.albedo_color = _stage_bg_color.darkened(0.45)
		_shard_mat_obsidian.emission = _accent_color
	if _shard_mat_accent != null:
		_shard_mat_accent.albedo_color = _contrast_color
		_shard_mat_accent.emission = _contrast_color


func set_stage_state(mode: int, phase_t: float, total_elapsed: float) -> void:
	_stage_mode = mode
	var t: float = clampf(phase_t, 0.0, 1.0)
	var is_active: bool = mode != StageMode.HIDDEN
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED

	if _act2_group != null:
		_act2_group.visible = (mode == StageMode.ACT2_CUTIN_STAGE)
	if _spikes_group != null:
		_spikes_group.visible = (mode == StageMode.ACT3_BEAT1_SPIKES or mode == StageMode.ACT3_BEAT2_CONTRAST)
	if _shards_group != null:
		_shards_group.visible = (mode == StageMode.ACT3_BEAT3_SHATTER)

	if not is_active:
		return

	if mode == StageMode.ACT2_CUTIN_STAGE:
		_eval_act2_stage(t, total_elapsed)
	elif mode == StageMode.ACT3_BEAT1_SPIKES or mode == StageMode.ACT3_BEAT2_CONTRAST:
		_eval_act3_spikes(mode == StageMode.ACT3_BEAT2_CONTRAST, t, total_elapsed)
	elif mode == StageMode.ACT3_BEAT3_SHATTER:
		_eval_act3_shatter(t, total_elapsed)


func _eval_act2_stage(t: float, elapsed: float) -> void:
	# Camera FOV punch: 42° -> 68° durante el despliegue de alas 3D
	var fov_eased: float = ease(t, 0.35)
	_camera.fov = lerpf(_fov_start, _fov_peak, fov_eased)
	var cam_orbit_x: float = sin(elapsed * 1.8) * 0.42
	var cam_orbit_y: float = cos(elapsed * 1.4) * 0.22
	_camera.position = Vector3(cam_orbit_x, cam_orbit_y, lerpf(5.6, 4.4, fov_eased))
	_camera.look_at(Vector3(0.0, 0.0, -3.5), Vector3.UP)

	# 3 Anillos giroscópicos de radar 3D en ejes ortogonales
	var sp: float = _gyro_speed
	if _gyro_rings.size() >= 3:
		_gyro_rings[0].rotation = Vector3(elapsed * sp * 0.85, elapsed * sp * 0.45, elapsed * sp * 1.2)
		_gyro_rings[1].rotation = Vector3(-elapsed * sp * 0.60, elapsed * sp * 1.15, -elapsed * sp * 0.55)
		_gyro_rings[2].rotation = Vector3(elapsed * sp * 0.40, -elapsed * sp * 0.80, elapsed * sp * 0.95)

	# Túnel reticular viajando hacia la cámara
	var tunnel_span: float = float(TUNNEL_RING_COUNT) * 3.5
	for i: int in range(_tunnel_rings.size()):
		var base_z: float = float(i) * 3.5
		var z_scroll: float = fposmod(base_z - elapsed * 18.0, tunnel_span)
		_tunnel_rings[i].position.z = -3.0 - z_scroll
		_tunnel_rings[i].rotation.z = elapsed * 0.9 + float(i) * 0.4

	# 12 Cuchillas 3D Cel-Shaded abriéndose en abanico y apuntando hacia cámara
	if _wing_crystal_mat != null:
		_wing_crystal_mat.set_shader_parameter("energy_flow_time", elapsed * 2.4)
		_wing_crystal_mat.set_shader_parameter("fire_flash", clampf(t * 1.25, 0.0, 1.5))

	var deploy: float = ease(clampf(t * 1.45, 0.0, 1.0), 0.25)
	for i: int in range(_wing_blades.size()):
		var mi: MeshInstance3D = _wing_blades[i]
		var side: float = _wing_side_signs[i]
		var local_idx: int = (i - 6) if side > 0.0 else i
		var base_ang: float = _wing_base_angles[i]
		var s: float = _wing_tier_scales[i] * lerpf(0.65, 1.0, deploy)

		var x_off: float = side * lerpf(0.55, 1.65 + float(local_idx) * 0.32, deploy)
		var y_off: float = lerpf(-0.15, 1.15 - float(local_idx) * 0.48, deploy) + sin(elapsed * 4.0 + float(i)) * 0.08
		var z_off: float = -2.2 - float(local_idx) * 0.28 + deploy * 1.45

		mi.position = Vector3(x_off, y_off, z_off)
		mi.scale = Vector3(s * side, s, s)
		# Apuntar las puntas rubí hacia la cámara al avanzar Acto 2
		var yaw_toward_cam: float = -side * lerpf(0.20, 0.92, deploy)
		var roll_z: float = side * base_ang * deploy
		mi.rotation = Vector3(sin(elapsed * 3.0 + float(i)) * 0.12, yaw_toward_cam, roll_z)


func _eval_act3_spikes(is_beat2_contrast: bool, t: float, elapsed: float) -> void:
	# Camera FOV snap dramático a 26° + micro shake 3D
	_camera.fov = _fov_snap
	var shake: float = 0.22 if is_beat2_contrast else 0.14
	_camera.position = Vector3(sin(elapsed * 85.0) * shake, cos(elapsed * 73.0) * shake, 4.8)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	for i: int in range(MAX_SAKUGA_SPIKES):
		var mi: MeshInstance3D = _sakuga_spikes[i]
		var active: bool = i < _active_spike_count
		mi.visible = active
		if not active:
			continue
		var ang: float = _spike_angles[i] + (0.28 if is_beat2_contrast else 0.0)
		var rad: float = _spike_radii[i] * lerpf(1.25, 0.72, t)
		mi.position = Vector3(cos(ang) * rad, sin(ang) * rad * 0.65, _spike_z_offsets[i])
		mi.rotation = Vector3(0.0, 0.0, ang + PI * 0.5)
		var len_s: float = lerpf(0.85, 1.45, t)
		mi.scale = Vector3(1.0, len_s, 1.0)
		if is_beat2_contrast:
			mi.material_override = _spike_mat_contrast if (i % 3 == 0) else (_spike_mat_dark if (i % 2 == 0) else _spike_mat_light)
		else:
			mi.material_override = _spike_mat_light if (i % 2 == 0) else _spike_mat_dark


func _eval_act3_shatter(t: float, elapsed: float) -> void:
	_camera.fov = lerpf(_fov_snap, _fov_start * 1.15, t)
	var shake: float = (1.0 - t) * 0.28
	_camera.position = Vector3(cos(elapsed * 95.0) * shake, sin(elapsed * 88.0) * shake, 5.2)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	var blast: float = ease(t, 0.42)
	for i: int in range(MAX_SHATTER_SHARDS):
		var mi: MeshInstance3D = _shatter_shards[i]
		var active: bool = i < _active_shard_count
		mi.visible = active
		if not active:
			continue
		var dist_xy: float = lerpf(0.35, 5.8, blast)
		var z_fly: float = lerpf(-2.4, 3.8, blast) * (_shard_dir_z[i] * 0.45)
		mi.position = Vector3(_shard_dir_x[i] * dist_xy, _shard_dir_y[i] * dist_xy, z_fly)
		var rspd: float = _shard_rot_spd[i]
		mi.rotation = Vector3(elapsed * rspd, elapsed * rspd * 0.75 + float(i), elapsed * rspd * 1.2)
		var sc: float = _shard_scales[i] * lerpf(0.65, 1.35, blast)
		mi.scale = Vector3(sc, sc, sc)


func get_gyro_ring_count() -> int:
	return _gyro_rings.size()


func get_tunnel_ring_count() -> int:
	return _tunnel_rings.size()


func get_wing_blade_count() -> int:
	return _wing_blades.size()


func get_active_sakuga_spike_count() -> int:
	return _active_spike_count


func get_active_shatter_shard_count() -> int:
	return _active_shard_count


func get_camera_fov() -> float:
	return _camera.fov if _camera != null else _fov_start


func get_stage_mode() -> int:
	return _stage_mode
