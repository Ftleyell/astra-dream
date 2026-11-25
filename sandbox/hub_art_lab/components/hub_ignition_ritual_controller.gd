class_name HubIgnitionRitualController
extends Node

## Controlador cinematográfico del Ritual de Ignición Orbital Norte (1.65 s).
## Coreografía de 3 tiempos:
## - Fase A (0.00-0.50 s): Centrado Zero-G mirando al Cosmos, carga del anillo + columna energética + 16 chispas ascendentes + levitación.
## - Fase B (0.50-1.05 s): Despliegue SERAPH_BLOOM (Alas 3D + Anillo Orbital 3D centrado) + bloom swell + shake.
## - Fase C (1.05-1.65 s): Ascenso e impulso hacia el Cosmos + push-in de cámara + flash hiperespacial suave.

signal ritual_started(focus_pos: Vector3)
signal ritual_progress(charge: float, push_in_t: float)
signal bloom_swell_requested(bloom_val: float)
signal camera_shake_requested(amount: float)
signal warp_retune_requested()
signal ritual_completed(request: RunLaunchRequestScript, launched_combat: bool)
signal active_run_prompt_opened()
signal active_run_prompt_closed()

const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const PlayerScript = preload("res://scenes/ui/hub/astral_station/components/hub_art_lab_player.gd")
const AstralWings3DScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const LaunchCtrlScript = preload("res://scenes/ui/character_select/components/character_select_launch_controller.gd")
const BeamShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_ignition_beam_3d.gdshader")
const SparkBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_gacha_summoner_mesh_builder.gd")
const PropShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_arcsys_prop_3d.gdshader")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const COLOR_BG := Color(0.035, 0.048, 0.102, 0.94)
const COLOR_GOLD := Color(0.95, 0.80, 0.34, 1.0)
const COLOR_CYAN := Color(0.05, 0.94, 1.0, 1.0)
const SPARK_COUNT: int = 16

@export var dry_run_sandbox_launch: bool = true

var _config: ConfigScript = null
var _player: PlayerScript = null
var _ring_mat: ShaderMaterial = null
var _is_ritual_active: bool = false
var _ritual_timer: float = 0.0
var _bloom_triggered: bool = false
var _warp_triggered: bool = false
var _pending_request: RunLaunchRequestScript = null
var _pending_resume: bool = false

var _vfx_root: Node3D = null
var _beam_mesh: MeshInstance3D = null
var _beam_mat: ShaderMaterial = null
var _spark_nodes: Array[MeshInstance3D] = []
var _spark_mat: ShaderMaterial = null
var _spark_angles: PackedFloat32Array = PackedFloat32Array()
var _spark_phases: PackedFloat32Array = PackedFloat32Array()
var _spark_radii: PackedFloat32Array = PackedFloat32Array()

var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_fade_out: bool = false
var _flash_alpha: float = 0.0

var _prompt_layer: CanvasLayer = null
var _prompt_panel: PanelContainer = null
var _prompt_desc_label: Label = null


func setup(p_config: ConfigScript, p_player: PlayerScript, p_ring_mat: ShaderMaterial = null) -> void:
	_config = p_config
	_player = p_player
	_ring_mat = p_ring_mat
	_ensure_prompt_ui()
	_ensure_vfx_nodes()


func set_ring_material(p_ring_mat: ShaderMaterial) -> void:
	_ring_mat = p_ring_mat


func is_ritual_active() -> bool:
	return _is_ritual_active


func is_active_run_prompt_open() -> bool:
	return _prompt_layer != null and _prompt_layer.visible


func request_ignition(active_request: RunLaunchRequestScript, force_direct_preview: bool = false) -> void:
	if _is_ritual_active:
		return
	var req: RunLaunchRequestScript = active_request.duplicate_request() if active_request != null else RunLaunchRequestScript.create_random_auto()
	if not force_direct_preview and SaveManagerScript.has_active_run():
		_pending_request = req
		_open_active_run_prompt()
		return
	start_ritual(req, false)


func cancel_active_run_prompt() -> void:
	if _prompt_layer != null and _prompt_layer.visible:
		_prompt_layer.visible = false
		active_run_prompt_closed.emit()


func start_ritual(request: RunLaunchRequestScript, is_resuming: bool = false) -> void:
	if _is_ritual_active or _config == null:
		return
	cancel_active_run_prompt()
	_ensure_vfx_nodes()
	_pending_request = request.duplicate_request() if request != null else RunLaunchRequestScript.create_random_auto()
	_pending_resume = is_resuming
	_is_ritual_active = true
	_ritual_timer = 0.0
	_bloom_triggered = false
	_warp_triggered = false
	_flash_fade_out = false
	_flash_alpha = 0.0

	if _vfx_root != null:
		_vfx_root.position = Vector3(_config.ignition_ring_pos.x, 0.05, _config.ignition_ring_pos.z)
		_vfx_root.visible = true
	if _beam_mat != null:
		_beam_mat.set_shader_parameter("beam_color", _config.pilot_accent_color)
		_beam_mat.set_shader_parameter("intensity", 0.0)
	if _spark_mat != null:
		_spark_mat.set_shader_parameter("pilot_accent_color", _config.pilot_accent_color)
		_spark_mat.set_shader_parameter("base_color", _config.pilot_accent_color)

	if _player != null:
		_player.is_movement_locked = true
		_player.is_pose_override_active = true
		_player.global_position = Vector3(_config.ignition_ring_pos.x, 0.065, _config.ignition_ring_pos.z)
		_player.set_pose_override(Vector2.UP, 0.20, Vector2.UP, true)
		if _player.rig_avatar != null:
			_player.rig_avatar.set_showcase_lift_offset(0.0)
			_player.rig_avatar.set_launch_scale_multiplier(1.0)
			_player.rig_avatar.set_loadout_showcase_enabled(true, true, AstralWings3DScript.AnimState.IDLE_ZERO_G)

	ritual_started.emit(_config.ignition_ring_pos)


func _process(delta: float) -> void:
	if _flash_fade_out and _flash_rect != null:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 3.2)
		_flash_rect.color.a = _flash_alpha
		if _flash_alpha <= 0.005:
			_flash_fade_out = false
			if _flash_layer != null:
				_flash_layer.visible = false

	if not _is_ritual_active or _config == null:
		return

	_ritual_timer += delta
	var dur: float = maxf(_config.ignition_preview_duration, 0.25)
	var t_norm: float = clampf(_ritual_timer / dur, 0.0, 1.0)

	# Fase A (0.00 - 0.32): carga anular + columna alta difuminada + pre-impulso Zero-G
	var charge_phase: float = clampf(t_norm / 0.34, 0.0, 1.0)
	var beam_int: float = sin(clampf(t_norm / 0.92, 0.0, 1.0) * PI) * 1.45

	if _ring_mat != null:
		_ring_mat.set_shader_parameter("ignition_charge", clampf(t_norm * 1.25, 0.0, 1.0))
	if _beam_mat != null:
		_beam_mat.set_shader_parameter("intensity", beam_int)

	_update_ascending_sparks(t_norm)

	# Fase B (t >= 0.32): despliegue SERAPH_BLOOM + pose de propulsión Turbo + bloom swell + shake
	if not _bloom_triggered and t_norm >= 0.32:
		_bloom_triggered = true
		if _player != null:
			_player.set_pose_override(Vector2.UP, 1.22, Vector2.UP, false)
			if _player.rig_avatar != null:
				var rig: PlanarCombatRig = _player.rig_avatar.get_rig()
				if rig != null:
					rig.set_turbo_active(true)
					rig.set_3d_wings_anim_state(AstralWings3DScript.AnimState.SERAPH_BLOOM, false)
					rig.trigger_3d_wings_pulse()
		bloom_swell_requested.emit(maxf(_config.bloom_intensity * 1.65, 1.25))
		camera_shake_requested.emit(0.055)

	# Levitación controlada (0..0.32 -> 0.26m) -> despegue CRUISE_BOOST hacia el Ventanal Cosmos (0.66..1.00)
	var hover_lift: float = smoothstep(0.0, 0.32, t_norm) * 0.28 + smoothstep(0.32, 0.66, t_norm) * 0.32
	var launch_t: float = clampf((t_norm - 0.66) / 0.34, 0.0, 1.0)
	var launch_ease: float = launch_t * launch_t * launch_t

	if _player != null:
		_player.global_position = Vector3(
			_config.ignition_ring_pos.x,
			0.065,
			lerpf(_config.ignition_ring_pos.z, _config.ignition_ring_pos.z - 2.65, launch_ease)
		)
		if _player.rig_avatar != null:
			_player.rig_avatar.set_showcase_lift_offset(hover_lift + launch_ease * 2.95)
			_player.rig_avatar.set_launch_scale_multiplier(lerpf(1.0, 0.70, launch_ease))
			if t_norm >= 0.68:
				var rig_c: PlanarCombatRig = _player.rig_avatar.get_rig()
				if rig_c != null:
					rig_c.set_3d_wings_anim_state(AstralWings3DScript.AnimState.CRUISE_BOOST, false)

	if not _warp_triggered and t_norm >= 0.72:
		_warp_triggered = true
		warp_retune_requested.emit()
		camera_shake_requested.emit(0.075)

	# Flash hiperespacial en el cierre (t >= 0.80)
	if t_norm >= 0.80 and _flash_rect != null and _flash_layer != null:
		_flash_layer.visible = true
		_flash_alpha = clampf((t_norm - 0.80) / 0.18, 0.0, 1.0) * 0.88
		_flash_rect.color.a = _flash_alpha

	var push_in_t: float = clampf((t_norm - 0.48) / 0.52, 0.0, 1.0)
	push_in_t = push_in_t * push_in_t * (3.0 - 2.0 * push_in_t)
	ritual_progress.emit(charge_phase, push_in_t)

	if t_norm >= 1.0:
		_complete_ritual()


func _update_ascending_sparks(t_norm: float) -> void:
	for i: int in range(_spark_nodes.size()):
		var sp: MeshInstance3D = _spark_nodes[i]
		if sp == null:
			continue
		var cyc: float = fposmod(_spark_phases[i] + t_norm * (1.8 + t_norm * 2.2), 1.0)
		var ang: float = _spark_angles[i] + t_norm * 5.2
		var rad: float = _spark_radii[i] * (1.0 - cyc * 0.42)
		sp.position = Vector3(cos(ang) * rad, cyc * 3.8, sin(ang) * rad)
		var s: float = (1.0 - cyc * 0.55) * (0.7 + t_norm * 0.6)
		sp.scale = Vector3(s, s * 1.6, s)


func _complete_ritual() -> void:
	_is_ritual_active = false
	if _ring_mat != null:
		_ring_mat.set_shader_parameter("ignition_charge", 0.0)
	if _beam_mat != null:
		_beam_mat.set_shader_parameter("intensity", 0.0)
	if _vfx_root != null:
		_vfx_root.visible = false

	var req: RunLaunchRequestScript = _pending_request if _pending_request != null else RunLaunchRequestScript.create_random_auto()
	var launched_combat: bool = false

	if not dry_run_sandbox_launch and get_tree() != null:
		if _pending_resume:
			SaveManagerScript.is_resuming_run = true
			var tree: SceneTree = get_tree()
			var st: Node = tree.root.get_node_or_null("SceneTransition") if tree.root != null else null
			if st != null and st.has_method("change_scene_to_file"):
				st.call("change_scene_to_file", "res://scenes/combat/main_game.tscn")
			else:
				tree.call_deferred("change_scene_to_file", "res://scenes/combat/main_game.tscn")
		else:
			SaveManagerScript.clear_active_run()
			SaveManagerScript.is_resuming_run = false
			var char_id: StringName = SaveManagerScript.get_selected_character()
			var launch_ctrl := LaunchCtrlScript.new()
			launch_ctrl.commit_launch(char_id, get_tree(), req)
		launched_combat = true
	else:
		RunLaunchRequestScript.set_pending(req)
		RunLaunchRequestScript.consume_pending()

	if not launched_combat and _player != null:
		_player.is_movement_locked = false
		_player.is_pose_override_active = false
		_player.global_position = Vector3(_config.ignition_ring_pos.x, 0.065, _config.ignition_ring_pos.z)
		_player.face_front_idle(true)
		if _player.rig_avatar != null:
			var rig_done: PlanarCombatRig = _player.rig_avatar.get_rig()
			if rig_done != null:
				rig_done.set_turbo_active(false)
			_player.rig_avatar.set_showcase_lift_offset(0.0)
			_player.rig_avatar.set_launch_scale_multiplier(1.0)
			_player.rig_avatar.set_loadout_showcase_enabled(false, false)
		if _flash_alpha > 0.01:
			_flash_fade_out = true

	if _config != null:
		bloom_swell_requested.emit(_config.bloom_intensity)

	ritual_completed.emit(req, launched_combat)


func _ensure_vfx_nodes() -> void:
	if _vfx_root != null:
		return
	_vfx_root = Node3D.new()
	_vfx_root.name = "IgnitionVFXRoot"
	_vfx_root.visible = false
	add_child(_vfx_root)

	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BeamShader
	_beam_mat.set_shader_parameter("intensity", 0.0)

	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.95
	cyl.bottom_radius = 1.35
	cyl.height = 14.0
	cyl.radial_segments = 32
	cyl.cap_top = false
	cyl.cap_bottom = false

	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "IgnitionEnergyColumn"
	_beam_mesh.mesh = cyl
	_beam_mesh.position = Vector3(0.0, 6.9, 0.0)
	_beam_mesh.material_override = _beam_mat
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vfx_root.add_child(_beam_mesh)

	_spark_mat = ShaderMaterial.new()
	_spark_mat.shader = PropShader
	_spark_mat.set_shader_parameter("material_kind", 2)
	_spark_mat.set_shader_parameter("emissive_boost", 2.2)

	var spark_mesh: ArrayMesh = SparkBuilder.build_spark_shard_mesh()
	_spark_nodes.clear()
	_spark_angles.resize(SPARK_COUNT)
	_spark_phases.resize(SPARK_COUNT)
	_spark_radii.resize(SPARK_COUNT)
	for i: int in range(SPARK_COUNT):
		_spark_angles[i] = TAU * float(i) / float(SPARK_COUNT)
		_spark_phases[i] = float(i) / float(SPARK_COUNT)
		_spark_radii[i] = 1.05 + 0.55 * float(i % 3) * 0.5
		var sm := MeshInstance3D.new()
		sm.name = "IgnitionSpark_%d" % i
		sm.mesh = spark_mesh
		sm.material_override = _spark_mat
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vfx_root.add_child(sm)
		_spark_nodes.append(sm)

	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "IgnitionWarpFlashLayer"
	_flash_layer.layer = 70
	_flash_layer.visible = false
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.96, 0.92, 0.80, 0.0)
	_flash_layer.add_child(_flash_rect)


func _open_active_run_prompt() -> void:
	_ensure_prompt_ui()
	var active_data: Dictionary = SaveManagerScript.load_active_run()
	var wave_num: int = int(active_data.get("current_wave", 1))
	if _prompt_desc_label != null:
		_prompt_desc_label.text = "Hay una incursión guardada en curso (Oleada %d).\n¿Deseas continuar o iniciar un nuevo salto con coordenada %s?" % [
			wave_num,
			_pending_request.coordinate_code if _pending_request != null else "AUTO"
		]
	if _prompt_layer != null:
		_prompt_layer.visible = true
	active_run_prompt_opened.emit()


func _ensure_prompt_ui() -> void:
	if _prompt_layer != null:
		return

	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "IgnitionActiveRunPromptLayer"
	_prompt_layer.layer = 60
	_prompt_layer.visible = false
	add_child(_prompt_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.025, 0.06, 0.72)
	_prompt_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt_layer.add_child(center)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.custom_minimum_size = Vector2(460.0, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_CYAN
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_content_margin_all(18.0)
	_prompt_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_prompt_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_prompt_panel.add_child(vbox)

	var title := Label.new()
	title.text = "ANILLO DE IGNICIÓN NORTE // INCURSIÓN ACTIVA"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	_prompt_desc_label = Label.new()
	_prompt_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_desc_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_prompt_desc_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	for spec: Array in [
		["Continuar Run", func() -> void: start_ritual(_pending_request, true)],
		["Nueva Run", func() -> void: start_ritual(_pending_request, false)],
		["Cancelar", cancel_active_run_prompt],
	]:
		var btn := Button.new()
		btn.text = str(spec[0])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(spec[1] as Callable)
		btn_row.add_child(btn)
