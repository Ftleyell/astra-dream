class_name HubGachaSummoner3D
extends Node3D

## Nodo 3D reutilizable del Invocador Giroscópico Astral (Fase 2 — Hub Art Lab).
## Construye la base octogonal Psycho-Pop, 3 anillos mecha concéntricos, núcleo divisible + cápsula,
## aura de piso, 18 chispas zero-allocation y máquina de estados exacta de 5 fases (0.00s -> 1.95s+).

enum SequencePhase {
	IDLE = 0,
	FRAMING = 1,
	CHARGING = 2,
	TENSION = 3,
	BLOOM_BURST = 4,
	REVEAL = 5,
}

signal phase_changed(new_phase: int)
signal fakeout_triggered()
signal burst_triggered(is_epic: bool)
signal reveal_ready(batch: Dictionary)
signal camera_shake_requested(amount: float)
signal bloom_boost_requested(bloom_val: float)

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_gacha_3d_config.gd")
const DEFAULT_CONFIG: ConfigScript = preload("res://data/hub/default_hub_gacha_3d_config.tres")
const MeshBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_gacha_summoner_mesh_builder.gd")
const TextureLoader = preload("res://scenes/ui/hub/astral_station/components/hub_texture_loader.gd")
const PropShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_prop_3d.gdshader")
const OutlineShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_outline_3d.gdshader")
const IgnitionRingShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_ignition_ring_3d.gdshader")
const GachaBannerEngineScript = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")

const SPARK_COUNT: int = 18
const STEP_SLICE_MAX: float = 0.025

@export var config: ConfigScript = DEFAULT_CONFIG

var _is_built: bool = false
var _phase: SequencePhase = SequencePhase.IDLE
var _active_banner_id: String = "general"
var _banner_color: Color = Color(0.0, 0.94, 1.0, 1.0)
var _charge_color: Color = Color(0.0, 0.94, 1.0, 1.0)
var _target_final_color: Color = Color(0.0, 0.94, 1.0, 1.0)
var _current_energy_color: Color = Color(0.0, 0.94, 1.0, 1.0)
var _current_emissive: float = 1.55
var _current_charge_ratio: float = 0.0

var _active_batch: Dictionary = {}
var _has_epic: bool = false
var _is_fakeout: bool = false
var _fakeout_broken: bool = false
var _burst_emitted: bool = false
var _reveal_emitted: bool = false

var _time_acc: float = 0.0
var _sequence_elapsed: float = 0.0
var _phase_elapsed: float = 0.0
var _core_separation: float = 0.0

var _pedestal_mesh: MeshInstance3D = null
var _floor_aura_mesh: MeshInstance3D = null
var _gyro_pivot: Node3D = null
var _outer_ring_pivot: Node3D = null
var _mid_ring_pivot: Node3D = null
var _inner_ring_pivot: Node3D = null
var _core_pivot: Node3D = null
var _core_upper_mesh: MeshInstance3D = null
var _core_lower_mesh: MeshInstance3D = null
var _reward_capsule_mesh: MeshInstance3D = null
var _core_light: OmniLight3D = null

var _outline_mat: ShaderMaterial = null
var _body_mats: Array[ShaderMaterial] = []
var _core_crystal_mat: ShaderMaterial = null
var _spark_mat: ShaderMaterial = null
var _floor_aura_mat: ShaderMaterial = null

var _spark_root: Node3D = null
var _spark_nodes: Array[MeshInstance3D] = []
var _spark_angles: PackedFloat32Array = PackedFloat32Array()
var _spark_elevs: PackedFloat32Array = PackedFloat32Array()
var _spark_speeds: PackedFloat32Array = PackedFloat32Array()
var _spark_radii: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_ensure_nodes()


func setup(p_config: ConfigScript) -> void:
	if p_config != null:
		config = p_config
	_ensure_nodes()
	set_banner(_active_banner_id)
	_apply_visual_state(0.0)


func _resolve_config() -> ConfigScript:
	if config != null:
		return config
	return DEFAULT_CONFIG


func _ensure_nodes() -> void:
	if _is_built:
		return
	var cfg: ConfigScript = _resolve_config()

	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OutlineShader
	_outline_mat.set_shader_parameter("outline_width", cfg.outline_width)
	_outline_mat.set_shader_parameter("reference_distance", cfg.outline_ref_distance)

	_body_mats.clear()
	var base_colors: Array[Color] = [cfg.armor_color, cfg.chassis_color, _banner_color]
	for surf_idx: int in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = PropShader
		mat.next_pass = _outline_mat
		mat.set_shader_parameter("material_kind", surf_idx)
		mat.set_shader_parameter("base_color", base_colors[surf_idx])
		mat.set_shader_parameter("pilot_accent_color", _banner_color)
		mat.set_shader_parameter("crease_ink_strength", cfg.crease_ink_strength)
		mat.set_shader_parameter("emissive_boost", cfg.emissive_idle)
		mat.set_shader_parameter("ambient_fill", 0.28)
		_body_mats.append(mat)

	_core_crystal_mat = ShaderMaterial.new()
	_core_crystal_mat.shader = PropShader
	_core_crystal_mat.next_pass = _outline_mat
	_core_crystal_mat.set_shader_parameter("material_kind", 2)
	_core_crystal_mat.set_shader_parameter("base_color", _banner_color)
	_core_crystal_mat.set_shader_parameter("pilot_accent_color", _banner_color)
	_core_crystal_mat.set_shader_parameter("crease_ink_strength", cfg.crease_ink_strength)
	_core_crystal_mat.set_shader_parameter("emissive_boost", cfg.emissive_idle * 1.15)
	_core_crystal_mat.set_shader_parameter("energy_flow_speed", 3.2)

	_spark_mat = ShaderMaterial.new()
	_spark_mat.shader = PropShader
	_spark_mat.set_shader_parameter("material_kind", 2)
	_spark_mat.set_shader_parameter("base_color", _banner_color)
	_spark_mat.set_shader_parameter("pilot_accent_color", _banner_color)
	_spark_mat.set_shader_parameter("emissive_boost", cfg.emissive_idle * 1.45)

	_pedestal_mesh = MeshInstance3D.new()
	_pedestal_mesh.name = "PedestalBaseMesh"
	_pedestal_mesh.mesh = MeshBuilder.build_pedestal_base_mesh()
	_pedestal_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_three_surface_mats(_pedestal_mesh, false)
	add_child(_pedestal_mesh)

	_floor_aura_mat = ShaderMaterial.new()
	_floor_aura_mat.shader = IgnitionRingShader
	var ring_tex: Texture2D = TextureLoader.load_texture_2d(cfg.ring_tex_path, true)
	if ring_tex != null:
		_floor_aura_mat.set_shader_parameter("ring_packed_tex", ring_tex)
	_floor_aura_mat.set_shader_parameter("ring_primary_color", Color(0.86, 0.90, 1.0, 0.92))
	_floor_aura_mat.set_shader_parameter("ring_accent_color", _banner_color)
	_floor_aura_mat.set_shader_parameter("energy_hdr_boost", cfg.emissive_idle * 1.15)
	_floor_aura_mat.set_shader_parameter("ignition_charge", 0.0)

	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(3.85, 3.85)
	_floor_aura_mesh = MeshInstance3D.new()
	_floor_aura_mesh.name = "FloorAuraMesh"
	_floor_aura_mesh.mesh = floor_plane
	_floor_aura_mesh.position = Vector3(0.0, 0.025, 0.0)
	_floor_aura_mesh.material_override = _floor_aura_mat
	_floor_aura_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor_aura_mesh)

	_gyro_pivot = Node3D.new()
	_gyro_pivot.name = "GyroPivot"
	_gyro_pivot.position = Vector3(0.0, cfg.gyro_center_y, 0.0)
	add_child(_gyro_pivot)

	_outer_ring_pivot = Node3D.new()
	_outer_ring_pivot.name = "OuterRingPivot"
	_gyro_pivot.add_child(_outer_ring_pivot)
	var outer_mesh := MeshInstance3D.new()
	outer_mesh.name = "OuterRingMesh"
	outer_mesh.mesh = MeshBuilder.build_outer_ring_mesh()
	outer_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_three_surface_mats(outer_mesh, false)
	_outer_ring_pivot.add_child(outer_mesh)

	_mid_ring_pivot = Node3D.new()
	_mid_ring_pivot.name = "MidRingPivot"
	_mid_ring_pivot.rotation_degrees = Vector3(45.0, 35.0, 0.0)
	_gyro_pivot.add_child(_mid_ring_pivot)
	var mid_mesh := MeshInstance3D.new()
	mid_mesh.name = "MidRingMesh"
	mid_mesh.mesh = MeshBuilder.build_mid_ring_mesh()
	mid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_three_surface_mats(mid_mesh, false)
	_mid_ring_pivot.add_child(mid_mesh)

	_inner_ring_pivot = Node3D.new()
	_inner_ring_pivot.name = "InnerRingPivot"
	_inner_ring_pivot.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	_gyro_pivot.add_child(_inner_ring_pivot)
	var inner_mesh := MeshInstance3D.new()
	inner_mesh.name = "InnerRingMesh"
	inner_mesh.mesh = MeshBuilder.build_inner_ring_mesh()
	inner_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_three_surface_mats(inner_mesh, false)
	_inner_ring_pivot.add_child(inner_mesh)

	_core_pivot = Node3D.new()
	_core_pivot.name = "CorePivot"
	_gyro_pivot.add_child(_core_pivot)

	_core_upper_mesh = MeshInstance3D.new()
	_core_upper_mesh.name = "CoreUpperHalfMesh"
	_core_upper_mesh.mesh = MeshBuilder.build_core_upper_half_mesh()
	_core_upper_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_three_surface_mats(_core_upper_mesh, true)
	_core_pivot.add_child(_core_upper_mesh)

	_core_lower_mesh = MeshInstance3D.new()
	_core_lower_mesh.name = "CoreLowerHalfMesh"
	_core_lower_mesh.mesh = MeshBuilder.build_core_lower_half_mesh()
	_core_lower_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_three_surface_mats(_core_lower_mesh, true)
	_core_pivot.add_child(_core_lower_mesh)

	_reward_capsule_mesh = MeshInstance3D.new()
	_reward_capsule_mesh.name = "RewardCapsuleMesh"
	_reward_capsule_mesh.mesh = MeshBuilder.build_reward_capsule_mesh()
	_reward_capsule_mesh.visible = false
	_reward_capsule_mesh.scale = Vector3(0.01, 0.01, 0.01)
	_reward_capsule_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_three_surface_mats(_reward_capsule_mesh, true)
	_core_pivot.add_child(_reward_capsule_mesh)

	_build_spark_pool()

	_core_light = OmniLight3D.new()
	_core_light.name = "CoreOmniLight"
	_core_light.position = Vector3(0.0, cfg.gyro_center_y, 0.45)
	_core_light.light_color = _banner_color
	_core_light.light_energy = 0.62
	_core_light.omni_range = 6.0
	add_child(_core_light)

	_is_built = true
	set_banner(_active_banner_id)


func _build_spark_pool() -> void:
	_spark_root = Node3D.new()
	_spark_root.name = "SparkPoolRoot"
	_gyro_pivot.add_child(_spark_root)

	_spark_nodes.clear()
	_spark_angles.resize(SPARK_COUNT)
	_spark_elevs.resize(SPARK_COUNT)
	_spark_speeds.resize(SPARK_COUNT)
	_spark_radii.resize(SPARK_COUNT)

	var spark_mesh: ArrayMesh = MeshBuilder.build_spark_shard_mesh()
	for i: int in range(SPARK_COUNT):
		var s_mi := MeshInstance3D.new()
		s_mi.name = "SparkShard_%02d" % i
		s_mi.mesh = spark_mesh
		s_mi.material_override = _spark_mat
		s_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spark_root.add_child(s_mi)
		_spark_nodes.append(s_mi)

		var ratio: float = float(i) / float(SPARK_COUNT)
		_spark_angles[i] = ratio * TAU
		_spark_elevs[i] = sin(ratio * TAU * 3.0) * 0.72
		_spark_speeds[i] = 0.85 + float(i % 4) * 0.35
		_spark_radii[i] = 1.75 + float(i % 3) * 0.28


func _apply_three_surface_mats(mi: MeshInstance3D, use_core_crystal: bool) -> void:
	mi.set_surface_override_material(0, _body_mats[0])
	mi.set_surface_override_material(1, _body_mats[1])
	mi.set_surface_override_material(2, _core_crystal_mat if use_core_crystal else _body_mats[2])


func set_banner(banner_id: String) -> void:
	_ensure_nodes()
	_active_banner_id = banner_id if GachaBannerEngineScript.BANNERS_CONFIG.has(banner_id) else "general"
	var cfg_dict: Dictionary = GachaBannerEngineScript.get_banner_config(_active_banner_id)
	_banner_color = cfg_dict.get("color", Color(0.0, 0.94, 1.0, 1.0)) as Color
	if _phase == SequencePhase.IDLE:
		_current_energy_color = _banner_color
		_apply_shader_uniforms()


func start_sequence(batch: Dictionary) -> void:
	_ensure_nodes()
	var cfg: ConfigScript = _resolve_config()
	_active_batch = batch.duplicate(true)
	var b_id: String = str(batch.get("banner_id", _active_banner_id))
	set_banner(b_id)

	var highest: String = str(batch.get("highest_rarity", "common"))
	_has_epic = bool(batch.get("has_epic", highest == "epic"))
	_is_fakeout = bool(batch.get("is_fakeout", false)) and _has_epic
	_fakeout_broken = false
	_burst_emitted = false
	_reveal_emitted = false

	if _has_epic or highest == "epic":
		_target_final_color = cfg.epic_energy_color
	elif highest == "rare":
		_target_final_color = cfg.rare_energy_color
	else:
		_target_final_color = cfg.common_energy_color

	_charge_color = cfg.common_energy_color if _is_fakeout else _target_final_color
	_current_energy_color = _banner_color
	_current_emissive = cfg.emissive_idle
	_current_charge_ratio = 0.0
	_sequence_elapsed = 0.0
	_phase_elapsed = 0.0
	_core_separation = 0.0

	if _reward_capsule_mesh != null:
		_reward_capsule_mesh.visible = false
		_reward_capsule_mesh.scale = Vector3(0.01, 0.01, 0.01)

	for i: int in range(SPARK_COUNT):
		_spark_radii[i] = 2.45 + float(i % 3) * 0.25

	_set_phase(SequencePhase.FRAMING)
	_apply_visual_state(0.0)


func reset_to_idle() -> void:
	_ensure_nodes()
	var cfg: ConfigScript = _resolve_config()
	_active_batch.clear()
	_has_epic = false
	_is_fakeout = false
	_fakeout_broken = false
	_burst_emitted = false
	_reveal_emitted = false
	_sequence_elapsed = 0.0
	_phase_elapsed = 0.0
	_core_separation = 0.0
	_current_charge_ratio = 0.0
	_current_emissive = cfg.emissive_idle
	_current_energy_color = _banner_color

	if _reward_capsule_mesh != null:
		_reward_capsule_mesh.visible = false
		_reward_capsule_mesh.scale = Vector3(0.01, 0.01, 0.01)
	if _outer_ring_pivot != null:
		_outer_ring_pivot.scale = Vector3.ONE
		_outer_ring_pivot.rotation = Vector3.ZERO
	if _mid_ring_pivot != null:
		_mid_ring_pivot.scale = Vector3.ONE
		_mid_ring_pivot.rotation_degrees = Vector3(45.0, 35.0, 0.0)
	if _inner_ring_pivot != null:
		_inner_ring_pivot.scale = Vector3.ONE
		_inner_ring_pivot.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	for i: int in range(SPARK_COUNT):
		_spark_radii[i] = 1.75 + float(i % 3) * 0.28

	_set_phase(SequencePhase.IDLE)
	_apply_visual_state(0.0)


func can_skip() -> bool:
	var cfg: ConfigScript = _resolve_config()
	if _phase in [SequencePhase.FRAMING, SequencePhase.CHARGING, SequencePhase.TENSION, SequencePhase.BLOOM_BURST]:
		return _sequence_elapsed >= cfg.skip_unlock_delay
	return false


func skip_to_reveal() -> bool:
	if _phase == SequencePhase.IDLE or _phase == SequencePhase.REVEAL:
		return false
	var cfg: ConfigScript = _resolve_config()
	if _is_fakeout and not _fakeout_broken:
		_fakeout_broken = true
		_current_energy_color = _target_final_color
		fakeout_triggered.emit()

	if not _burst_emitted:
		_burst_emitted = true
		burst_triggered.emit(_has_epic)
		bloom_boost_requested.emit(cfg.bloom_burst_peak)
		camera_shake_requested.emit(cfg.shake_burst_impulse)

	_current_energy_color = _target_final_color
	_current_emissive = cfg.emissive_burst_epic if _has_epic else cfg.emissive_burst_common
	_current_charge_ratio = 1.0
	_core_separation = cfg.core_split_distance
	_apply_bloom_open_pose(1.0)
	_set_phase(SequencePhase.REVEAL)
	if not _reveal_emitted:
		_reveal_emitted = true
		reveal_ready.emit(_active_batch)
	_apply_visual_state(0.0)
	return true


func _process(delta: float) -> void:
	step_sequence(delta)


func step_sequence(delta: float) -> void:
	_ensure_nodes()
	if delta <= 0.0:
		return
	var remaining: float = delta
	while remaining > 0.00001:
		var slice: float = minf(remaining, STEP_SLICE_MAX)
		_step_slice(slice)
		remaining -= slice


func _step_slice(dt: float) -> void:
	_time_acc += dt
	var cfg: ConfigScript = _resolve_config()

	match _phase:
		SequencePhase.IDLE:
			_current_energy_color = _banner_color
			_current_emissive = cfg.emissive_idle
			_current_charge_ratio = 0.0
			_apply_visual_state(dt)
		SequencePhase.FRAMING:
			_sequence_elapsed += dt
			_phase_elapsed += dt
			var p: float = clampf(_phase_elapsed / maxf(cfg.phase_frame_duration, 0.01), 0.0, 1.0)
			_current_energy_color = _banner_color.lerp(_charge_color, p * 0.35)
			_current_emissive = lerpf(cfg.emissive_idle, cfg.emissive_idle * 1.25, p)
			_current_charge_ratio = p * 0.15
			_apply_visual_state(dt)
			if _phase_elapsed >= cfg.phase_frame_duration:
				_set_phase(SequencePhase.CHARGING)
		SequencePhase.CHARGING:
			_sequence_elapsed += dt
			_phase_elapsed += dt
			var p: float = clampf(_phase_elapsed / maxf(cfg.phase_charge_duration, 0.01), 0.0, 1.0)
			_current_energy_color = _banner_color.lerp(_charge_color, clampf(0.35 + p * 0.65, 0.0, 1.0))
			_current_emissive = lerpf(cfg.emissive_idle * 1.25, cfg.emissive_charge_peak, p * p)
			_current_charge_ratio = 0.15 + p * 0.70
			if p > 0.25:
				camera_shake_requested.emit(cfg.shake_max_charge * pow(p, 2.0))
			_apply_visual_state(dt)
			if _phase_elapsed >= cfg.phase_charge_duration:
				_set_phase(SequencePhase.TENSION)
		SequencePhase.TENSION:
			_sequence_elapsed += dt
			_phase_elapsed += dt
			var p: float = clampf(_phase_elapsed / maxf(cfg.phase_tension_duration, 0.01), 0.0, 1.0)
			if _is_fakeout and not _fakeout_broken and p >= cfg.fakeout_break_ratio:
				_fakeout_broken = true
				_current_energy_color = _target_final_color
				_current_emissive = cfg.emissive_burst_epic
				fakeout_triggered.emit()
				camera_shake_requested.emit(cfg.shake_fakeout_impulse)
				_play_sfx("bomb", 1.18, -3.0)
			elif _fakeout_broken:
				var pulse_t: float = 0.5 + 0.5 * sin(_time_acc * 26.0)
				_current_energy_color = cfg.epic_energy_color.lerp(cfg.epic_secondary_color, pulse_t * 0.55)
				_current_emissive = cfg.emissive_burst_epic
			else:
				_current_energy_color = _charge_color
				_current_emissive = cfg.emissive_charge_peak * (1.0 + p * 0.25)
			_current_charge_ratio = 0.85 + p * 0.15
			_apply_visual_state(dt)
			if _phase_elapsed >= cfg.phase_tension_duration:
				_enter_bloom_burst()
		SequencePhase.BLOOM_BURST:
			_sequence_elapsed += dt
			_phase_elapsed += dt
			var p: float = clampf(_phase_elapsed / maxf(cfg.phase_bloom_duration, 0.01), 0.0, 1.0)
			_current_energy_color = _target_final_color
			var peak_e: float = cfg.emissive_burst_epic if _has_epic else cfg.emissive_burst_common
			_current_emissive = lerpf(peak_e * 1.15, peak_e * 0.88, p)
			_current_charge_ratio = 1.0 - p * 0.55
			_apply_bloom_open_pose(p)
			_apply_visual_state(dt)
			if _phase_elapsed >= cfg.phase_bloom_duration:
				_set_phase(SequencePhase.REVEAL)
				if not _reveal_emitted:
					_reveal_emitted = true
					reveal_ready.emit(_active_batch)
		SequencePhase.REVEAL:
			_sequence_elapsed += dt
			_phase_elapsed += dt
			_current_energy_color = _target_final_color
			var reveal_e: float = cfg.emissive_burst_epic if _has_epic else cfg.emissive_burst_common
			_current_emissive = reveal_e * (0.84 + 0.12 * sin(_time_acc * 3.4))
			_current_charge_ratio = 0.35
			_apply_visual_state(dt)


func _enter_bloom_burst() -> void:
	var cfg: ConfigScript = _resolve_config()
	if _is_fakeout and not _fakeout_broken:
		_fakeout_broken = true
		fakeout_triggered.emit()
	_current_energy_color = _target_final_color
	_set_phase(SequencePhase.BLOOM_BURST)
	if not _burst_emitted:
		_burst_emitted = true
		burst_triggered.emit(_has_epic)
		bloom_boost_requested.emit(cfg.bloom_burst_peak)
		camera_shake_requested.emit(cfg.shake_burst_impulse)
		_play_sfx("bomb" if _has_epic else "magnet", 1.08, -2.0)


func _set_phase(new_phase: SequencePhase) -> void:
	if _phase == new_phase:
		return
	_phase = new_phase
	_phase_elapsed = 0.0
	phase_changed.emit(int(_phase))


func _apply_bloom_open_pose(bloom_p: float) -> void:
	var cfg: ConfigScript = _resolve_config()
	var ease_out: float = 1.0 - pow(1.0 - clampf(bloom_p, 0.0, 1.0), 3.0)
	_core_separation = lerpf(0.0, cfg.core_split_distance, ease_out)

	var ring_s: float = lerpf(1.0, cfg.rings_bloom_open_scale, ease_out)
	var tilt_rad: float = deg_to_rad(cfg.rings_bloom_tilt_deg * ease_out)
	if _outer_ring_pivot != null:
		_outer_ring_pivot.scale = Vector3.ONE * ring_s
		_outer_ring_pivot.rotation.x = lerpf(_outer_ring_pivot.rotation.x, tilt_rad, 0.35)
	if _mid_ring_pivot != null:
		_mid_ring_pivot.scale = Vector3.ONE * lerpf(1.0, ring_s * 0.96, ease_out)
		_mid_ring_pivot.rotation.x = lerpf(_mid_ring_pivot.rotation.x, -tilt_rad, 0.35)
	if _inner_ring_pivot != null:
		_inner_ring_pivot.scale = Vector3.ONE * lerpf(1.0, ring_s * 0.92, ease_out)
		_inner_ring_pivot.rotation.y = lerpf(_inner_ring_pivot.rotation.y, tilt_rad * 1.2, 0.35)

	if _reward_capsule_mesh != null:
		_reward_capsule_mesh.visible = true
		var pop_s: float = ease_out + sin(clampf(bloom_p, 0.0, 1.0) * PI) * 0.22
		_reward_capsule_mesh.scale = Vector3.ONE * maxf(pop_s, 0.05)


func _apply_visual_state(dt: float) -> void:
	var cfg: ConfigScript = _resolve_config()

	# 1. Cinemática de los 3 anillos según fase
	match _phase:
		SequencePhase.IDLE:
			_outer_ring_pivot.rotation.z += dt * cfg.outer_ring_idle_speed
			_outer_ring_pivot.rotation.x = lerpf(_outer_ring_pivot.rotation.x, sin(_time_acc * 0.55) * 0.14, 0.12)
			_mid_ring_pivot.rotation.z += dt * cfg.mid_ring_idle_speed
			_mid_ring_pivot.rotation.x = lerpf(_mid_ring_pivot.rotation.x, deg_to_rad(45.0), 0.12)
			_mid_ring_pivot.rotation.y = lerpf(_mid_ring_pivot.rotation.y, deg_to_rad(35.0), 0.12)
			_inner_ring_pivot.rotation.z += dt * cfg.inner_ring_idle_speed
			_inner_ring_pivot.rotation.x = lerpf(_inner_ring_pivot.rotation.x, deg_to_rad(-45.0), 0.12)
			_inner_ring_pivot.rotation.y = lerpf(_inner_ring_pivot.rotation.y, deg_to_rad(-25.0), 0.12)
		SequencePhase.FRAMING, SequencePhase.CHARGING:
			var charge_t: float = 0.0
			if _phase == SequencePhase.CHARGING:
				charge_t = clampf(_phase_elapsed / maxf(cfg.phase_charge_duration, 0.01), 0.0, 1.0)
			var accel: float = 1.0 + pow(charge_t, 2.2)
			_outer_ring_pivot.rotation.z += dt * cfg.outer_ring_idle_speed * lerpf(1.6, cfg.outer_ring_charge_mult, charge_t) * accel
			_mid_ring_pivot.rotation.z += dt * cfg.mid_ring_idle_speed * lerpf(1.6, cfg.mid_ring_charge_mult, charge_t) * accel
			_inner_ring_pivot.rotation.z += dt * cfg.inner_ring_idle_speed * lerpf(1.6, cfg.inner_ring_charge_mult, charge_t) * accel
			# Convergencia hacia plano ecuatorial común
			var align_w: float = clampf(dt * (3.5 + charge_t * 6.0), 0.0, 1.0)
			_outer_ring_pivot.rotation.x = lerpf(_outer_ring_pivot.rotation.x, 0.0, align_w)
			_mid_ring_pivot.rotation.x = lerpf(_mid_ring_pivot.rotation.x, 0.0, align_w)
			_mid_ring_pivot.rotation.y = lerpf(_mid_ring_pivot.rotation.y, 0.0, align_w)
			_inner_ring_pivot.rotation.x = lerpf(_inner_ring_pivot.rotation.x, 0.0, align_w)
			_inner_ring_pivot.rotation.y = lerpf(_inner_ring_pivot.rotation.y, 0.0, align_w)
		SequencePhase.TENSION:
			_outer_ring_pivot.rotation.z += dt * cfg.outer_ring_idle_speed * cfg.outer_ring_charge_mult * 2.2
			_mid_ring_pivot.rotation.z += dt * cfg.mid_ring_idle_speed * cfg.mid_ring_charge_mult * 2.2
			_inner_ring_pivot.rotation.z += dt * cfg.inner_ring_idle_speed * cfg.inner_ring_charge_mult * 2.2
			var squeeze: float = 0.94 + 0.04 * sin(_time_acc * 36.0)
			_outer_ring_pivot.scale = Vector3.ONE * squeeze
			_mid_ring_pivot.scale = Vector3.ONE * squeeze
			_inner_ring_pivot.scale = Vector3.ONE * squeeze
		SequencePhase.BLOOM_BURST, SequencePhase.REVEAL:
			_outer_ring_pivot.rotation.z += dt * cfg.outer_ring_idle_speed * 0.45
			_mid_ring_pivot.rotation.z += dt * cfg.mid_ring_idle_speed * 0.45
			_inner_ring_pivot.rotation.z += dt * cfg.inner_ring_idle_speed * 0.55

	# 2. Núcleo y cápsula
	if _core_pivot != null:
		var bob_y: float = sin(_time_acc * TAU * cfg.core_idle_bob_hz) * cfg.core_idle_bob_amp
		if _phase == SequencePhase.TENSION:
			_core_pivot.position = Vector3(sin(_time_acc * 58.0) * 0.025, cos(_time_acc * 64.0) * 0.025, 0.0)
			_core_pivot.scale = Vector3.ONE * (0.92 + 0.06 * sin(_time_acc * 42.0))
		else:
			_core_pivot.position = Vector3(0.0, bob_y, 0.0)
			_core_pivot.scale = Vector3.ONE
		_core_pivot.rotation.y += dt * (2.6 if _phase == SequencePhase.CHARGING else 0.72)

	if _core_upper_mesh != null:
		_core_upper_mesh.position.y = _core_separation
	if _core_lower_mesh != null:
		_core_lower_mesh.position.y = -_core_separation
	if _reward_capsule_mesh != null and _reward_capsule_mesh.visible:
		_reward_capsule_mesh.rotation.y += dt * 1.45

	# 3. Chispas zero-allocation
	_update_sparks(dt)

	# 4. Luz y uniforms de shader
	_apply_shader_uniforms()


func _update_sparks(dt: float) -> void:
	for i: int in range(SPARK_COUNT):
		var s_mi: MeshInstance3D = _spark_nodes[i]
		var spd: float = _spark_speeds[i]
		var r: float = _spark_radii[i]
		match _phase:
			SequencePhase.IDLE:
				_spark_angles[i] += dt * spd * 0.65
				r = lerpf(r, 1.75 + float(i % 3) * 0.25, clampf(dt * 4.0, 0.0, 1.0))
				s_mi.scale = Vector3.ONE * 0.65
			SequencePhase.FRAMING, SequencePhase.CHARGING:
				_spark_angles[i] += dt * spd * (2.6 + _current_charge_ratio * 6.5)
				r = maxf(0.14, r - dt * (1.2 + _current_charge_ratio * 2.2))
				if r <= 0.16:
					r = 2.55
				s_mi.scale = Vector3.ONE * (0.75 + _current_charge_ratio * 0.75)
			SequencePhase.TENSION:
				_spark_angles[i] += dt * spd * 9.5
				r = 0.28 + 0.12 * sin(_time_acc * 18.0 + float(i))
				s_mi.scale = Vector3.ONE * 1.35
			SequencePhase.BLOOM_BURST:
				_spark_angles[i] += dt * spd * 1.8
				r += dt * 4.8
				s_mi.scale = Vector3.ONE * maxf(0.25, 1.65 - _phase_elapsed * 2.8)
			SequencePhase.REVEAL:
				_spark_angles[i] += dt * spd * 0.9
				r = lerpf(r, 1.65 + float(i % 3) * 0.30, clampf(dt * 3.0, 0.0, 1.0))
				s_mi.scale = Vector3.ONE * 0.82
		_spark_radii[i] = r
		var ang: float = _spark_angles[i]
		var elev: float = _spark_elevs[i] * (0.35 if _phase == SequencePhase.CHARGING else 1.0)
		s_mi.position = Vector3(cos(ang) * r, elev + sin(_time_acc * 2.5 + float(i)) * 0.12, sin(ang) * r * 0.65)
		s_mi.rotation.z = ang + PI * 0.5


func _apply_shader_uniforms() -> void:
	var cfg: ConfigScript = _resolve_config()
	for i: int in range(_body_mats.size()):
		var mat: ShaderMaterial = _body_mats[i]
		mat.set_shader_parameter("pilot_accent_color", _current_energy_color)
		mat.set_shader_parameter("emissive_boost", _current_emissive)
		mat.set_shader_parameter("crease_ink_strength", cfg.crease_ink_strength)
		if i == 2:
			mat.set_shader_parameter("base_color", _current_energy_color)
	if _core_crystal_mat != null:
		_core_crystal_mat.set_shader_parameter("pilot_accent_color", _current_energy_color)
		_core_crystal_mat.set_shader_parameter("base_color", _current_energy_color)
		_core_crystal_mat.set_shader_parameter("emissive_boost", _current_emissive * 1.25)
	if _spark_mat != null:
		_spark_mat.set_shader_parameter("pilot_accent_color", _current_energy_color)
		_spark_mat.set_shader_parameter("base_color", _current_energy_color)
		_spark_mat.set_shader_parameter("emissive_boost", _current_emissive * 1.45)
	if _floor_aura_mat != null:
		_floor_aura_mat.set_shader_parameter("ring_accent_color", _current_energy_color)
		_floor_aura_mat.set_shader_parameter("energy_hdr_boost", maxf(_current_emissive, 1.25))
		_floor_aura_mat.set_shader_parameter("ignition_charge", _current_charge_ratio)
	if _core_light != null:
		_core_light.light_color = _current_energy_color
		_core_light.light_energy = 1.0 + _current_emissive * 0.85


func _play_sfx(sfx_name: String, pitch_scale: float, volume_db: float) -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var audio_mgr: Node = tree.root.get_node_or_null("AudioManager")
	if audio_mgr != null and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch_scale, volume_db)


func get_phase() -> SequencePhase:
	return _phase


func get_sequence_elapsed() -> float:
	return _sequence_elapsed


func get_active_banner_id() -> String:
	return _active_banner_id


func get_active_energy_color() -> Color:
	return _current_energy_color


func get_core_separation() -> float:
	return _core_separation


func get_ring_nodes() -> Array[Node3D]:
	_ensure_nodes()
	return [_outer_ring_pivot, _mid_ring_pivot, _inner_ring_pivot]


func was_fakeout_triggered() -> bool:
	return _fakeout_broken


func get_tutorial_highlight_materials() -> Dictionary:
	var p_mats: Array[ShaderMaterial] = []
	for mat: ShaderMaterial in _body_mats:
		if mat != null and not p_mats.has(mat):
			p_mats.append(mat)
	if _core_crystal_mat != null and not p_mats.has(_core_crystal_mat):
		p_mats.append(_core_crystal_mat)
	var o_mats: Array[ShaderMaterial] = []
	if _outline_mat != null:
		o_mats.append(_outline_mat)
	return {
		"prop_mats": p_mats,
		"outline_mats": o_mats,
	}
