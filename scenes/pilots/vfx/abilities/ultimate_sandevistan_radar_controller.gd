class_name UltimateSandevistanRadarController
extends Node2D
## Acto 1 de la Ultimate [Q]: Vuelta orbital ultrarrápida con estela Sandevistan (recoloreada por skin)
## y Radar Ocular 360° que clava Crosshairs contrastantes (LOCK #01..N) sobre todos los enemigos congelados.
## Corre en PROCESS_MODE_ALWAYS mientras PauseArbitrator mantiene el mundo detenido y garantiza
## la restauración exacta de rig.global_position al concluir el barrido.

signal target_locked(target: Node2D, lock_index: int)
signal radar_sweep_completed(marked_targets: Array[Node2D])

const SandevistanCtrlScript = preload("res://scenes/pilots/vfx/sandevistan_trail_controller.gd")
const DEFAULT_PROPULSION_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_propulsion_vfx.tres"

var _sandevistan: SandevistanTrailController = null
var _propulsion_cfg: PilotPropulsionVFXConfig = null

var _rig: Node2D = null
var _rig_saved_pos: Vector2 = Vector2.ZERO
var _has_saved_rig_pos: bool = false
var _orbit_center: Vector2 = Vector2.ZERO
var _orbit_radius_x: float = 195.0
var _orbit_radius_y: float = 135.0
var _orbit_turns: float = 1.0
var _radar_origin: Vector2 = Vector2.ZERO
var _radar_max_radius: float = 920.0
var _crosshair_scale: float = 1.0

var _sweep_duration: float = 0.46
var _elapsed: float = 0.0
var _radar_radius: float = 0.0
var _radar_angle: float = 0.0
var _is_sweeping: bool = false
var _is_frozen: bool = false
var _time_scale: float = 1.0
var _completed_emitted: bool = false

var _accent_color: Color = Color(0.98, 0.14, 0.34, 1.0)
var _contrast_color: Color = Color(0.08, 0.96, 0.88, 1.0)
var _stage_bg_color: Color = Color(0.03, 0.02, 0.06, 1.0)

var _pending_targets: Array[Node2D] = []
var _marked_entries: Array[Dictionary] = [] # {target: Node2D, pos: Vector2, lock_idx: int, age: float, consumed: bool}
var _anim_clock: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_sandevistan()


func _ensure_sandevistan() -> void:
	if _sandevistan != null and is_instance_valid(_sandevistan):
		return
	if ResourceLoader.exists(DEFAULT_PROPULSION_CFG_PATH):
		var raw_cfg: Resource = ResourceLoader.load(DEFAULT_PROPULSION_CFG_PATH)
		if raw_cfg is PilotPropulsionVFXConfig:
			_propulsion_cfg = (raw_cfg as PilotPropulsionVFXConfig).duplicate(true) as PilotPropulsionVFXConfig
	if _propulsion_cfg == null:
		_propulsion_cfg = PilotPropulsionVFXConfig.new()
	_propulsion_cfg.ensure_defaults()
	# Calibrado para arco cerrado de alta velocidad (~10-14 afterimages por vuelta)
	_propulsion_cfg.burst_spawn_distance_px = 38.0
	_propulsion_cfg.burst_max_ghosts = 14
	_propulsion_cfg.burst_lifetime_sec = 0.65

	_sandevistan = SandevistanCtrlScript.new()
	_sandevistan.name = "UltimateSandevistanTrail"
	_sandevistan.process_mode = Node.PROCESS_MODE_ALWAYS
	_sandevistan.z_index = -1
	_sandevistan.set_config(_propulsion_cfg)
	add_child(_sandevistan)


func set_palette(palette: Dictionary) -> void:
	_ensure_sandevistan()
	if palette.has("accent"):
		_accent_color = palette["accent"] as Color
	if palette.has("contrast_crosshair"):
		_contrast_color = palette["contrast_crosshair"] as Color
	if palette.has("stage_bg"):
		_stage_bg_color = palette["stage_bg"] as Color
	if palette.has("sandevistan_gradient") and palette["sandevistan_gradient"] is Gradient and _propulsion_cfg != null:
		_propulsion_cfg.sequence_gradient = (palette["sandevistan_gradient"] as Gradient).duplicate() as Gradient
		if _sandevistan != null:
			_sandevistan.set_config(_propulsion_cfg)
	queue_redraw()


func set_time_scale(scale_val: float) -> void:
	_time_scale = clampf(scale_val, 0.05, 2.0)


func set_frozen(frozen: bool) -> void:
	_is_frozen = frozen


func is_sweeping() -> bool:
	return _is_sweeping


func get_normalized_progress() -> float:
	if _sweep_duration <= 0.001:
		return 1.0 if _completed_emitted else 0.0
	return clampf(_elapsed / _sweep_duration, 0.0, 1.0)


func get_marked_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for entry: Dictionary in _marked_entries:
		var t_node: Node2D = entry.get("target", null) as Node2D
		if is_instance_valid(t_node):
			result.append(t_node)
	return result


func get_marked_count() -> int:
	return _marked_entries.size()


func get_active_ghost_count() -> int:
	if _sandevistan == null:
		return 0
	return _sandevistan.get_active_ghost_count()


func get_total_ghosts_spawned() -> int:
	if _sandevistan == null:
		return 0
	return _sandevistan.get_total_spawned_count()


func start_sweep(
	rig: Node2D,
	origin_pos: Vector2,
	targets: Array[Node2D],
	ult_cfg: PilotUltimateConfig,
	palette: Dictionary
) -> void:
	_ensure_sandevistan()
	_restore_rig_position()
	_sandevistan.clear_all_ghosts()
	set_palette(palette)

	var cfg: PilotUltimateConfig = ult_cfg if ult_cfg != null else PilotUltimateConfig.new()
	cfg.ensure_defaults()

	_rig = rig
	_rig_saved_pos = rig.global_position if is_instance_valid(rig) else origin_pos
	_has_saved_rig_pos = is_instance_valid(rig)
	_radar_origin = _rig_saved_pos + Vector2(0.0, -44.0)

	_sweep_duration = maxf(0.12, cfg.sandevistan_sweep_sec)
	_orbit_radius_x = clampf(cfg.sandevistan_orbit_radius_px, 40.0, 600.0)
	_orbit_radius_y = _orbit_radius_x * 0.68
	_orbit_turns = clampf(cfg.sandevistan_turns, 0.25, 3.0)
	_radar_max_radius = maxf(240.0, cfg.radar_ring_max_radius_px)
	_crosshair_scale = clampf(cfg.crosshair_scale, 0.4, 2.5)

	# Orientar el centro orbital hacia el centroide de los enemigos (si existen) para barrer el campo
	var dir_to_arena: Vector2 = Vector2.RIGHT
	_pending_targets.clear()
	_marked_entries.clear()
	var sum_pos: Vector2 = Vector2.ZERO
	var valid_count: int = 0
	for t_node: Node2D in targets:
		if is_instance_valid(t_node):
			_pending_targets.append(t_node)
			sum_pos += t_node.global_position
			valid_count += 1
	if valid_count > 0:
		var centroid: Vector2 = sum_pos / float(valid_count)
		var delta_c: Vector2 = centroid - _rig_saved_pos
		if delta_c.length_squared() > 16.0:
			dir_to_arena = delta_c.normalized()
	_orbit_center = _rig_saved_pos + dir_to_arena * _orbit_radius_x

	_elapsed = 0.0
	_radar_radius = 0.0
	_radar_angle = 0.0
	_is_sweeping = true
	_completed_emitted = false

	if is_instance_valid(_rig):
		_sandevistan.trigger_burst_impulse(_rig)
	_evaluate_sweep_at(0.0, 0.016)
	queue_redraw()


func scrub_sweep(t_norm: float) -> void:
	var clamped: float = clampf(t_norm, 0.0, 1.0)
	_elapsed = clamped * _sweep_duration
	_evaluate_sweep_at(clamped, 0.016)
	if clamped >= 1.0:
		_restore_rig_position()
	queue_redraw()


func clear_crosshair_for_target(target: Node2D) -> void:
	if target == null:
		return
	for entry: Dictionary in _marked_entries:
		if entry.get("target", null) == target:
			entry["consumed"] = true
	queue_redraw()


func clear_all_marks() -> void:
	_marked_entries.clear()
	_pending_targets.clear()
	queue_redraw()


func clear_marks_and_stop(restore_rig: bool = true) -> void:
	_is_sweeping = false
	_completed_emitted = false
	_elapsed = 0.0
	_radar_radius = 0.0
	if restore_rig:
		_restore_rig_position()
	if _sandevistan != null:
		_sandevistan.clear_all_ghosts()
	_pending_targets.clear()
	_marked_entries.clear()
	queue_redraw()


func _restore_rig_position() -> void:
	if _has_saved_rig_pos and is_instance_valid(_rig):
		_rig.global_position = _rig_saved_pos
	_has_saved_rig_pos = false


func _process(delta: float) -> void:
	var dt: float = 0.0 if _is_frozen else (clampf(delta, 0.0, 0.05) * _time_scale)
	_anim_clock += dt

	if not _is_sweeping and _marked_entries.is_empty():
		if _sandevistan != null and _sandevistan.get_active_ghost_count() > 0 and is_instance_valid(_rig):
			_sandevistan.step(dt, _rig, Vector2.ZERO, false)
		return

	for entry: Dictionary in _marked_entries:
		entry["age"] = float(entry["age"]) + dt
		var t_node: Node2D = entry.get("target", null) as Node2D
		if is_instance_valid(t_node):
			entry["pos"] = t_node.global_position

	if _is_sweeping:
		_elapsed += dt
		var t_norm: float = clampf(_elapsed / maxf(0.001, _sweep_duration), 0.0, 1.0)
		_evaluate_sweep_at(t_norm, dt)

		if not _is_frozen and _elapsed >= _sweep_duration:
			_finish_sweep()
	elif _sandevistan != null and _sandevistan.get_active_ghost_count() > 0 and is_instance_valid(_rig):
		_sandevistan.step(dt, _rig, Vector2.ZERO, false)

	queue_redraw()


func _evaluate_sweep_at(t_norm: float, dt: float) -> void:
	# 1. Posición orbital ultrarrápida cerrando exactamente en _rig_saved_pos
	var start_ang: float = (_rig_saved_pos - _orbit_center).angle()
	var t_eased: float = ease(t_norm, -1.35)
	var theta: float = start_ang + t_eased * TAU * _orbit_turns
	var orbit_pos: Vector2 = _orbit_center + Vector2(cos(theta) * _orbit_radius_x, sin(theta) * _orbit_radius_y)

	# Para vueltas no enteras, suavizar el regreso exacto al origen en el último 12%
	if t_norm >= 0.88:
		var ret_w: float = clampf((t_norm - 0.88) / 0.12, 0.0, 1.0)
		orbit_pos = orbit_pos.lerp(_rig_saved_pos, ret_w * ret_w)
	if t_norm >= 0.999:
		orbit_pos = _rig_saved_pos

	if is_instance_valid(_rig):
		var prev_pos: Vector2 = _rig.global_position
		_rig.global_position = orbit_pos
		var step_dt: float = maxf(dt, 0.008)
		var vel: Vector2 = (orbit_pos - prev_pos) / step_dt
		if vel.length_squared() < 1600.0 and t_norm > 0.0 and t_norm < 0.999:
			var tang := Vector2(-sin(theta), cos(theta))
			vel = tang * 2200.0
		if _sandevistan != null:
			_sandevistan.step(step_dt, _rig, vel, true)

	# 2. Expansión del Radar Ocular 360° y marcado de Crosshairs contrastantes
	_radar_radius = lerpf(28.0, _radar_max_radius, ease(t_norm, 0.45))
	_radar_angle = t_norm * TAU * 1.5
	_radar_origin = (_rig.global_position if is_instance_valid(_rig) else _rig_saved_pos) + Vector2(0.0, -44.0)

	var lock_all_now: bool = t_norm >= 0.92
	for t_node: Node2D in _pending_targets:
		if not is_instance_valid(t_node):
			continue
		if _is_target_marked(t_node):
			continue
		var dist_from_origin: float = _rig_saved_pos.distance_to(t_node.global_position)
		if lock_all_now or dist_from_origin <= _radar_radius + 40.0:
			var lock_idx: int = _marked_entries.size() + 1
			_marked_entries.append({
				"target": t_node,
				"pos": t_node.global_position,
				"lock_idx": lock_idx,
				"age": 0.0,
				"consumed": false,
			})
			target_locked.emit(t_node, lock_idx)


func _is_target_marked(target: Node2D) -> bool:
	for entry: Dictionary in _marked_entries:
		if entry.get("target", null) == target:
			return true
	return false


func _finish_sweep() -> void:
	# Asegurar que ningún enemigo válido quede sin marcar al terminar el barrido
	for t_node: Node2D in _pending_targets:
		if is_instance_valid(t_node) and not _is_target_marked(t_node):
			var lock_idx: int = _marked_entries.size() + 1
			_marked_entries.append({
				"target": t_node,
				"pos": t_node.global_position,
				"lock_idx": lock_idx,
				"age": 0.0,
				"consumed": false,
			})
			target_locked.emit(t_node, lock_idx)

	_is_sweeping = false
	_restore_rig_position()
	if not _completed_emitted:
		_completed_emitted = true
		radar_sweep_completed.emit(get_marked_targets())


func _draw() -> void:
	# 1. Radar Ocular 360° activo durante Acto 1
	if _is_sweeping:
		var t_norm: float = get_normalized_progress()
		var alpha_env: float = clampf(sin(t_norm * PI) * 1.4, 0.25, 1.0)
		var c_hdr := Color(_contrast_color.r * 1.75, _contrast_color.g * 1.75, _contrast_color.b * 1.75, 0.92 * alpha_env)
		var c_soft := Color(_contrast_color.r, _contrast_color.g, _contrast_color.b, 0.26 * alpha_env)
		var a_soft := Color(_accent_color.r * 1.4, _accent_color.g * 1.4, _accent_color.b * 1.4, 0.42 * alpha_env)

		# Onda expansiva principal + eco secundario
		draw_arc(_rig_saved_pos, _radar_radius, 0.0, TAU, 72, c_hdr, 3.8, true)
		draw_arc(_rig_saved_pos, _radar_radius * 0.66, 0.0, TAU, 56, c_soft, 1.8, true)
		draw_arc(_rig_saved_pos, _radar_radius * 0.34, 0.0, TAU, 40, a_soft, 1.5, true)

		# Barrido polar giratorio desde el ojo/monóculo
		var sweep_dir := Vector2(cos(_radar_angle), sin(_radar_angle))
		draw_line(_radar_origin, _radar_origin + sweep_dir * _radar_radius, c_hdr, 2.4, true)
		var wedge_pts := PackedVector2Array([_radar_origin])
		for s: int in range(9):
			var wa: float = _radar_angle - float(s) * 0.065
			wedge_pts.append(_radar_origin + Vector2(cos(wa), sin(wa)) * _radar_radius)
		draw_colored_polygon(wedge_pts, Color(_contrast_color.r, _contrast_color.g, _contrast_color.b, 0.10 * alpha_env))

		# Ticks radiales tácticos cada 30°
		for k: int in range(12):
			var ka: float = float(k) * (TAU / 12.0) + _radar_angle * 0.25
			var kd := Vector2(cos(ka), sin(ka))
			draw_line(_rig_saved_pos + kd * (_radar_radius - 16.0), _rig_saved_pos + kd * (_radar_radius + 10.0), c_hdr, 2.0, true)

		# Destello en el ojo de Valentina
		draw_circle(_radar_origin, 7.0 + sin(t_norm * PI * 4.0) * 2.5, c_hdr)

	# 2. Crosshairs contrastantes clavados en cada enemigo marcado
	var font: Font = ThemeDB.fallback_font
	for entry: Dictionary in _marked_entries:
		if bool(entry.get("consumed", false)):
			continue
		var pos: Vector2 = entry["pos"] as Vector2
		var age: float = float(entry["age"])
		var lock_idx: int = int(entry["lock_idx"])
		var snap_t: float = clampf(age / 0.14, 0.0, 1.0)
		var lock_r: float = lerpf(62.0, 30.0, ease(snap_t, 0.28)) * _crosshair_scale
		var rot: float = _anim_clock * 2.6 + float(lock_idx) * 0.55

		var ch_hdr := Color(_contrast_color.r * 1.85, _contrast_color.g * 1.85, _contrast_color.b * 1.85, 0.96)
		var ch_core := Color(1.95, 1.98, 2.05, 0.95)
		var ch_sub := Color(_accent_color.r * 1.5, _accent_color.g * 1.5, _accent_color.b * 1.5, 0.72)

		# Anillo segmentado giratorio (4 arcos de 55°)
		for q: int in range(4):
			var a0: float = rot + float(q) * (PI * 0.5) + 0.18
			var a1: float = a0 + 0.95
			draw_arc(pos, lock_r, a0, a1, 12, ch_hdr, 2.8 * _crosshair_scale, true)
		draw_arc(pos, lock_r * 0.62, -rot * 1.4, -rot * 1.4 + TAU * 0.72, 18, ch_sub, 1.6 * _crosshair_scale, true)

		# 4 brackets convergentes + miras en cruz
		var br_len: float = 11.0 * _crosshair_scale
		for q: int in range(4):
			var ba: float = float(q) * (PI * 0.5) + PI * 0.25
			var bd := Vector2(cos(ba), sin(ba))
			var bp := Vector2(-bd.y, bd.x)
			var corner: Vector2 = pos + bd * (lock_r * 1.18)
			draw_line(corner, corner - bd * br_len + bp * (br_len * 0.42), ch_core, 2.2 * _crosshair_scale, true)
			draw_line(corner, corner - bd * br_len - bp * (br_len * 0.42), ch_core, 2.2 * _crosshair_scale, true)

		# Líneas cardinales cortas + rombo central
		var c_in: float = lock_r * 0.26
		var c_out: float = lock_r * 0.54
		draw_line(pos + Vector2(-c_out, 0.0), pos + Vector2(-c_in, 0.0), ch_core, 1.8, true)
		draw_line(pos + Vector2(c_in, 0.0), pos + Vector2(c_out, 0.0), ch_core, 1.8, true)
		draw_line(pos + Vector2(0.0, -c_out), pos + Vector2(0.0, -c_in), ch_core, 1.8, true)
		draw_line(pos + Vector2(0.0, c_in), pos + Vector2(0.0, c_out), ch_core, 1.8, true)

		# Pulso flash inicial al fijar objetivo
		if snap_t < 1.0:
			var pulse_r: float = lerpf(16.0, lock_r * 1.7, snap_t)
			draw_arc(pos, pulse_r, 0.0, TAU, 24, Color(ch_hdr.r, ch_hdr.g, ch_hdr.b, (1.0 - snap_t) * 0.85), 3.0 * (1.0 - snap_t), true)

		# Etiqueta LOCK #01..N
		if font != null:
			var label_txt: String = "LOCK #%02d" % lock_idx
			var label_pos: Vector2 = pos + Vector2(lock_r * 0.78, -lock_r * 0.78)
			draw_string(font, label_pos + Vector2(1.0, 1.0), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * _crosshair_scale)), Color(0.0, 0.0, 0.0, 0.92))
			draw_string(font, label_pos, label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12.0 * _crosshair_scale)), ch_hdr)
