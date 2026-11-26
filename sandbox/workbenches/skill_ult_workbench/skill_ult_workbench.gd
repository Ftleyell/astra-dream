class_name SkillUltWorkbench
extends Node2D
## Workbench oficial sobre producción real para calibrar Skill [R] (Hold-to-Aim Sniper),
## Ultimate [Q] (Cut-In animado, Impact Frames Sakuga B/N + Fractura Obsidiana, 12 cuchillas ida/vuelta),
## sincronización con PauseArbitrator, Cosmos Engine, Skins Shader y preview de HUD sin mutar SaveManager.

const CosmosEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const HUDScene: PackedScene = preload("res://scenes/ui/hud/hud.tscn")
const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const OrbitalRingScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const CutInTheaterScript = preload("res://scenes/pilots/vfx/abilities/pilot_cutin_theater.gd")
const SniperVFXScript = preload("res://scenes/pilots/vfx/abilities/sniper_weakpoint_rail_vfx.gd")
const WingBarrageScript = preload("res://scenes/pilots/vfx/abilities/ultimate_wing_barrage_controller.gd")
const HUDClusterScript = preload("res://scenes/ui/hud/components/hud_ability_cluster_preview.gd")
const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")
const AlignmentOverlayScript = preload("res://sandbox/workbenches/shared/workbench_alignment_overlay.gd")
const SaveSandboxScript = preload("res://sandbox/workbenches/shared/workbench_save_sandbox.gd")
const PanelScript = preload("res://sandbox/workbenches/skill_ult_workbench/skill_ult_workbench_panel.gd")

const DEFAULT_PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const DEFAULT_SKILL_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_skill.tres"
const DEFAULT_ULT_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_ultimate.tres"
const DEFAULT_ORBITAL_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"
const SKILL_ULT_STUDIO_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/valentina_skill_ult_studio.tscn"

const PAUSE_TOKEN_SKILL: StringName = &"workbench_skill_cutin"
const PAUSE_TOKEN_ULT: StringName = &"workbench_ultimate_cutin"
const DANMAKU_COUNT: int = 36


class _WorkbenchDummy extends Node2D:
	var dummy_name: String = "Dummy"
	var max_hp: float = 400.0
	var hp: float = 400.0
	var radius_px: float = 24.0
	var is_boss: bool = false
	var is_selected: bool = false
	var hit_flash: float = 0.0
	var base_pos: Vector2 = Vector2.ZERO
	var phase_seed: float = 0.0

	func _ready() -> void:
		# Pausable para validar visualmente el Time-Stop real de PauseArbitrator
		process_mode = Node.PROCESS_MODE_PAUSABLE

	func apply_hit(dmg: float) -> void:
		hp = maxf(0.0, hp - dmg)
		hit_flash = 1.0
		if hp <= 0.0:
			hp = max_hp
		queue_redraw()

	func _process(delta: float) -> void:
		if hit_flash > 0.0:
			hit_flash = maxf(0.0, hit_flash - delta * 4.5)
			queue_redraw()

	func _draw() -> void:
		var fill: Color = Color(0.95, 0.25, 0.38, 0.92) if is_boss else Color(0.24, 0.65, 0.92, 0.88)
		fill = fill.lerp(Color(1.9, 1.8, 2.0, 1.0), hit_flash)
		var pts := PackedVector2Array()
		var sides: int = 6 if is_boss else 4
		for i: int in range(sides):
			var a: float = float(i) * (TAU / float(sides)) - PI * 0.5
			pts.append(Vector2(cos(a), sin(a)) * radius_px)
		draw_colored_polygon(pts, fill)
		if is_selected:
			draw_arc(Vector2.ZERO, radius_px + 10.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.25, 0.95), 2.5, true)
		var hp_ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		draw_rect(Rect2(-radius_px, -radius_px - 12.0, radius_px * 2.0, 5.0), Color(0.06, 0.06, 0.12, 0.85))
		draw_rect(Rect2(-radius_px, -radius_px - 12.0, radius_px * 2.0 * hp_ratio, 5.0), Color(0.98, 0.22, 0.42, 0.95))


var theater: PilotCutInTheater = null
var sniper_vfx: SniperWeakpointRailVFX = null
var wing_barrage: UltimateWingBarrageController = null
var hud_cluster: HUDAbilityClusterPreview = null
var alignment_overlay: AlignmentOverlayScript = null
var real_hud: GameHUD = null

var _save_sandbox: SaveSandboxScript = SaveSandboxScript.new()
var _panel_refs: Dictionary = {}
var _cosmos_env: CosmosCombatEnvironment = null
var _backdrop_layer: CanvasLayer = null
var _camera: Camera2D = null
var _pausable_world: Node2D = null
var _rig: PlanarCombatRig = null
var _ring_ctrl: OrbitalWeaponRingController = null
var _dummies_root: Node2D = null
var _danmaku_layer: Node2D = null
var _hud_preview_layer: CanvasLayer = null

var _profile_path: String = DEFAULT_PROFILE_PATH
var _skill_cfg_path: String = DEFAULT_SKILL_CFG_PATH
var _ult_cfg_path: String = DEFAULT_ULT_CFG_PATH
var _profile: PilotRigProfile = null
var _skill_cfg: PilotSkillConfig = null
var _ult_cfg: PilotUltimateConfig = null
var _skins: Array[PilotSkinPreset] = []
var _active_accent: Color = Color(0.98, 0.14, 0.34, 1.0)

var _dummies: Array[_WorkbenchDummy] = []
var _selected_dummy: _WorkbenchDummy = null
var _danmaku_orbs: Array[Dictionary] = []
var _orb_respawn_timer: float = 0.0

var _use_pause_arbitrator: bool = true
var _playback_speed: float = 1.0
var _is_frozen: bool = false
var _holding_skill_aim: bool = false
var _sim_skill_cd: float = 0.0
var _sim_ult_energy: float = 100.0
var _sim_time: float = 0.0
var _target_zoom: float = 1.05
var _pending_skill_target: _WorkbenchDummy = null
var _pending_skill_pos: Vector2 = Vector2.ZERO
var _ignore_scrubber_cb: bool = false


func _enter_tree() -> void:
	_save_sandbox.backup()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_pilot_paths()
	_load_configs()
	_build_stage()
	spawn_scenario(0)
	_build_danmaku_orbs()
	alignment_overlay = AlignmentOverlayScript.attach_to(self, 75) as AlignmentOverlayScript
	_register_alignment_targets()
	_panel_refs = PanelScript.build(self, self)
	_refresh_metrics_label()


func _exit_tree() -> void:
	_release_all_cutin_pauses()
	_cleanup_real_hud()
	_save_sandbox.restore()


func _resolve_pilot_paths() -> void:
	var sel_prof: String = PilotLabSelectorScript.get_selected_profile_path()
	if not sel_prof.is_empty() and ResourceLoader.exists(sel_prof):
		_profile_path = sel_prof
	else:
		_profile_path = DEFAULT_PROFILE_PATH
	_skill_cfg_path = PilotLabSelectorScript.resolve_sibling_config_path(_profile_path, "skill", DEFAULT_SKILL_CFG_PATH)
	_ult_cfg_path = PilotLabSelectorScript.resolve_sibling_config_path(_profile_path, "ultimate", DEFAULT_ULT_CFG_PATH)


func _load_configs() -> void:
	if ResourceLoader.exists(_profile_path):
		_profile = ResourceLoader.load(_profile_path) as PilotRigProfile
	if ResourceLoader.exists(_skill_cfg_path):
		var s: Resource = ResourceLoader.load(_skill_cfg_path)
		if s is PilotSkillConfig:
			_skill_cfg = (s as PilotSkillConfig).duplicate(true) as PilotSkillConfig
	if _skill_cfg == null:
		_skill_cfg = PilotSkillConfig.new()
	_skill_cfg.ensure_defaults()

	if ResourceLoader.exists(_ult_cfg_path):
		var u: Resource = ResourceLoader.load(_ult_cfg_path)
		if u is PilotUltimateConfig:
			_ult_cfg = (u as PilotUltimateConfig).duplicate(true) as PilotUltimateConfig
	if _ult_cfg == null:
		_ult_cfg = PilotUltimateConfig.new()
	_ult_cfg.ensure_defaults()

	_skins.clear()
	if _profile != null:
		for sk: PilotSkinPreset in _profile.skins:
			if sk != null:
				_skins.append(sk)


func _build_stage() -> void:
	_backdrop_layer = CanvasLayer.new()
	_backdrop_layer.name = "FlatBackdropLayer"
	_backdrop_layer.layer = -120
	add_child(_backdrop_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.025, 0.03, 0.07, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_layer.add_child(bg)

	_camera = Camera2D.new()
	_camera.name = "WorkbenchCamera"
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	_camera.enabled = true
	add_child(_camera)

	# Contenedor pausable real para demostrar el congelamiento via PauseArbitrator
	_pausable_world = Node2D.new()
	_pausable_world.name = "PausableCombatWorld"
	_pausable_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_pausable_world)

	_dummies_root = Node2D.new()
	_dummies_root.name = "DummiesRoot"
	_dummies_root.z_index = 12
	_pausable_world.add_child(_dummies_root)

	_danmaku_layer = Node2D.new()
	_danmaku_layer.name = "DanmakuLayer"
	_danmaku_layer.z_index = 18
	_pausable_world.add_child(_danmaku_layer)

	_rig = PlanarRigScript.new()
	_rig.name = "ValentinaWorkbenchRig"
	_rig.pilot_profile = _profile
	_rig.enable_live_animations = true
	_rig.enable_face_live = true
	_rig.enable_3d_wings = false
	_rig.enable_base_propulsion_wings = true
	_rig.position = Vector2(-140.0, 20.0)
	_rig.z_index = 15
	_pausable_world.add_child(_rig)

	_ring_ctrl = OrbitalRingScript.new()
	_ring_ctrl.name = "OrbitalRing"
	if ResourceLoader.exists(DEFAULT_ORBITAL_CFG_PATH):
		var ocfg: Resource = ResourceLoader.load(DEFAULT_ORBITAL_CFG_PATH)
		if ocfg is PilotOrbitalWeaponConfig:
			var dup: PilotOrbitalWeaponConfig = (ocfg as PilotOrbitalWeaponConfig).duplicate(true) as PilotOrbitalWeaponConfig
			dup.ensure_defaults()
			_ring_ctrl.set_config(dup)
	_ring_ctrl.set_weapon_count(2)
	_rig.add_child(_ring_ctrl)

	sniper_vfx = SniperVFXScript.new()
	sniper_vfx.name = "SniperWeakpointRailVFX"
	sniper_vfx.shot_impacted.connect(_on_sniper_impacted)
	add_child(sniper_vfx)

	wing_barrage = WingBarrageScript.new()
	wing_barrage.name = "UltimateWingBarrageController"
	wing_barrage.blade_impacted.connect(_on_blade_impacted)
	wing_barrage.finisher_detonated.connect(_on_finisher_detonated)
	add_child(wing_barrage)

	theater = CutInTheaterScript.new()
	theater.name = "PilotCutInTheater"
	theater.cutin_release_reached.connect(_on_cutin_release)
	theater.cutin_finished.connect(_on_cutin_finished)
	add_child(theater)

	_hud_preview_layer = CanvasLayer.new()
	_hud_preview_layer.name = "HUDAbilityPreviewLayer"
	_hud_preview_layer.layer = 22
	_hud_preview_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_preview_layer)

	hud_cluster = HUDClusterScript.new()
	hud_cluster.name = "HUDAbilityClusterPreview"
	_hud_preview_layer.add_child(hud_cluster)


func _register_alignment_targets() -> void:
	if alignment_overlay == null:
		return
	alignment_overlay.clear_targets()
	if is_instance_valid(hud_cluster):
		alignment_overlay.register_control("HUDAbilityCluster", hud_cluster)
	if is_instance_valid(_rig):
		alignment_overlay.set_world_target(_rig)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.keycode == KEY_R and not kev.echo:
			if kev.pressed:
				begin_skill_hold_aim()
			elif _holding_skill_aim:
				release_skill_hold_aim()
			get_viewport().set_input_as_handled()
			return
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_Q:
				trigger_ultimate_demo()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_P:
				toggle_freeze()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_G:
				toggle_guides()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_H:
				var panel: Control = _panel_refs.get("panel") as Control
				if is_instance_valid(panel):
					panel.visible = not panel.visible
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_LEFT:
				_try_pick_dummy_at(get_global_mouse_position())
			elif mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.12, 0.55, 2.4)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.12, 0.55, 2.4)


func spawn_scenario(idx: int) -> void:
	for d: _WorkbenchDummy in _dummies:
		if is_instance_valid(d):
			d.queue_free()
	_dummies.clear()
	_selected_dummy = null

	var center := Vector2(110.0, 0.0)
	if idx == 0:
		for i: int in range(12):
			var ang: float = float(i) * (TAU / 12.0)
			var r: float = 200.0 if (i % 2 == 0) else 310.0
			_add_dummy("Enemigo #%02d" % (i + 1), center + Vector2(cos(ang) * r * 1.2, sin(ang) * r * 0.85), 280.0, 20.0, false, float(i))
	elif idx == 1:
		var offsets: Array[Vector2] = [Vector2(150, -155), Vector2(280, -35), Vector2(230, 145), Vector2(60, 165)]
		for i: int in range(offsets.size()):
			_add_dummy("Élite #%d" % (i + 1), offsets[i], 650.0, 28.0, false, float(i) * 1.6)
	else:
		_add_dummy("JEFE ORBITAL", Vector2(220.0, 0.0), 2500.0, 48.0, true, 0.0)

	if not _dummies.is_empty():
		_select_dummy(_dummies[0])
	_set_status("Escenario actualizado (%d objetivos)" % _dummies.size())


func _add_dummy(d_name: String, pos: Vector2, max_hp: float, rad: float, boss: bool, seed_val: float) -> void:
	var d := _WorkbenchDummy.new()
	d.dummy_name = d_name
	d.max_hp = max_hp
	d.hp = max_hp
	d.radius_px = rad
	d.is_boss = boss
	d.base_pos = pos
	d.position = pos
	d.phase_seed = seed_val
	_dummies_root.add_child(d)
	_dummies.append(d)


func _select_dummy(d: _WorkbenchDummy) -> void:
	for item: _WorkbenchDummy in _dummies:
		if is_instance_valid(item):
			item.is_selected = (item == d)
			item.queue_redraw()
	_selected_dummy = d


func _try_pick_dummy_at(world_pos: Vector2) -> void:
	var best: _WorkbenchDummy = null
	var best_d: float = 140.0
	for d: _WorkbenchDummy in _dummies:
		if is_instance_valid(d):
			var dist: float = d.global_position.distance_to(world_pos)
			if dist < best_d:
				best_d = dist
				best = d
	if best != null:
		_select_dummy(best)


func _build_danmaku_orbs() -> void:
	_danmaku_orbs.clear()
	for i: int in range(DANMAKU_COUNT):
		var ang: float = float(i) * (TAU / float(DANMAKU_COUNT))
		var r: float = 150.0 + float(i % 4) * 72.0
		_danmaku_orbs.append({
			"angle": ang,
			"radius": r,
			"speed": 0.45 + float(i % 3) * 0.22,
			"alive": true,
			"pos": Vector2(100.0, 0.0) + Vector2(cos(ang), sin(ang)) * r,
		})


func begin_skill_hold_aim() -> void:
	if theater != null and theater.is_playing():
		return
	_holding_skill_aim = true
	_update_hold_aim_target()


func release_skill_hold_aim() -> void:
	_holding_skill_aim = false
	if sniper_vfx != null:
		sniper_vfx.stop_hold_aim()
	trigger_skill_demo()


func _update_hold_aim_target() -> void:
	if not _holding_skill_aim or _rig == null or sniper_vfx == null:
		return
	var cursor_w: Vector2 = get_global_mouse_position()
	var best: _WorkbenchDummy = null
	var best_d: float = _skill_cfg.cursor_snap_radius_px if _skill_cfg != null else 240.0
	for d: _WorkbenchDummy in _dummies:
		if is_instance_valid(d):
			var dist: float = d.global_position.distance_to(cursor_w)
			if dist < best_d:
				best_d = dist
				best = d
	if best != null:
		_select_dummy(best)
	var active_tgt: _WorkbenchDummy = best if best != null else (_selected_dummy if is_instance_valid(_selected_dummy) else null)
	sniper_vfx.update_hold_aim(_rig.global_position, active_tgt, cursor_w)


func trigger_skill_demo() -> void:
	if _rig == null or theater == null:
		return
	_holding_skill_aim = false
	_release_all_cutin_pauses()
	_sim_skill_cd = _skill_cfg.cooldown_sec
	_sim_ult_energy = minf(_ult_cfg.max_energy, _sim_ult_energy + _ult_cfg.energy_on_skill_cast)

	var target: _WorkbenchDummy = _selected_dummy if is_instance_valid(_selected_dummy) else (_dummies[0] if not _dummies.is_empty() else null)
	_pending_skill_target = target
	_pending_skill_pos = target.global_position if is_instance_valid(target) else (_rig.global_position + Vector2(360.0, 0.0))

	if _use_pause_arbitrator:
		PauseArbitrator.acquire(PAUSE_TOKEN_SKILL)
	sniper_vfx.begin_weakpoint_lock(_rig.global_position, target, _pending_skill_pos, _skill_cfg.reticle_lead_sec)
	theater.play_skill_cutin(_skill_cfg, _world_to_screen_uv(_rig.global_position))
	_set_status("Skill [R] disparada (Time-Stop %.2fs)" % _skill_cfg.time_stop_sec)


func trigger_ultimate_demo() -> void:
	if _rig == null or theater == null:
		return
	_holding_skill_aim = false
	_release_all_cutin_pauses()
	_sim_ult_energy = 0.0
	if _use_pause_arbitrator:
		PauseArbitrator.acquire(PAUSE_TOKEN_ULT)
	theater.play_ultimate_cutin(_ult_cfg, _world_to_screen_uv(_rig.global_position))
	_set_status("Ultimate [Q] disparada (Time-Stop %.2fs)" % _ult_cfg.total_timestop_sec)


func stop_active_cutin() -> void:
	if theater != null:
		theater.stop_and_hide()
	_release_all_cutin_pauses()


func _release_all_cutin_pauses() -> void:
	PauseArbitrator.release(PAUSE_TOKEN_SKILL)
	PauseArbitrator.release(PAUSE_TOKEN_ULT)


func _on_cutin_release(mode_name: StringName) -> void:
	_release_all_cutin_pauses()
	if mode_name == &"skill":
		sniper_vfx.fire_sniper_beam(_rig.global_position, _pending_skill_target, _pending_skill_pos, _skill_cfg)
		if _skill_cfg.clear_corridor_bullets:
			_clear_orbs_along_corridor(_rig.global_position, _pending_skill_pos, _skill_cfg.bullet_clear_half_width_px)
	elif mode_name == &"ultimate":
		var targets: Array[Node2D] = []
		for d: _WorkbenchDummy in _dummies:
			if is_instance_valid(d):
				targets.append(d)
		if _ult_cfg.purge_all_bullets:
			for orb: Dictionary in _danmaku_orbs:
				orb["alive"] = false
			_orb_respawn_timer = 1.6
		wing_barrage.launch_barrage(_rig.global_position, targets, _ult_cfg, _rig)


func _on_cutin_finished(_mode_name: StringName) -> void:
	_release_all_cutin_pauses()


func _on_sniper_impacted(target: Node2D, _hit_pos: Vector2, _beam_end: Vector2) -> void:
	if target is _WorkbenchDummy:
		(target as _WorkbenchDummy).apply_hit(180.0 * _skill_cfg.damage_multiplier * 0.25)


func _on_blade_impacted(target: Node2D, _world_pos: Vector2, _blade_idx: int) -> void:
	if target is _WorkbenchDummy:
		(target as _WorkbenchDummy).apply_hit(65.0 * _ult_cfg.blade_damage_mult * 0.35)


func _on_finisher_detonated(targets: Array[Node2D]) -> void:
	for t: Node2D in targets:
		if t is _WorkbenchDummy:
			(t as _WorkbenchDummy).apply_hit(120.0 * _ult_cfg.shatter_finisher_mult * 0.35)


func _clear_orbs_along_corridor(a: Vector2, b: Vector2, half_w: float) -> void:
	var ab: Vector2 = b - a
	var len_sq: float = maxf(ab.length_squared(), 1.0)
	for orb: Dictionary in _danmaku_orbs:
		if not bool(orb["alive"]):
			continue
		var p: Vector2 = orb["pos"]
		var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
		if p.distance_to(a + ab * t) <= half_w:
			orb["alive"] = false
	_orb_respawn_timer = 1.6


func toggle_guides() -> void:
	if alignment_overlay != null:
		alignment_overlay.show_guides = not alignment_overlay.show_guides
		_set_status("Guías: %s" % ("ON" if alignment_overlay.show_guides else "OFF"))


func toggle_cosmos_background() -> void:
	if is_instance_valid(_cosmos_env):
		_cosmos_env.queue_free()
		_cosmos_env = null
		_set_status("Fondo: Oscuro plano")
		return
	if CosmosEnvScene != null:
		_cosmos_env = CosmosEnvScene.instantiate() as CosmosCombatEnvironment
		_cosmos_env.name = "CosmosPreview"
		add_child(_cosmos_env)
		_cosmos_env.set_camera_reference(_camera)
		_set_status("Fondo: Cosmos Engine vivo")


func toggle_real_game_hud() -> void:
	if is_instance_valid(real_hud):
		_cleanup_real_hud()
		_set_status("GameHUD real oculto")
		return
	if HUDScene != null:
		real_hud = HUDScene.instantiate() as GameHUD
		real_hud.name = "ProductionGameHUDPreview"
		add_child(real_hud)
		_set_status("GameHUD de producción montado")


func _cleanup_real_hud() -> void:
	if is_instance_valid(real_hud):
		if is_instance_valid(real_hud.target_reticle):
			real_hud.target_reticle.queue_free()
		real_hud.queue_free()
		real_hud = null


func toggle_freeze() -> void:
	_is_frozen = not _is_frozen
	if theater != null:
		theater.set_frozen(_is_frozen)
	_set_status("Congelado: %s" % ("ON" if _is_frozen else "OFF"))


func set_playback_speed(spd: float) -> void:
	_playback_speed = clampf(spd, 0.05, 2.0)
	if theater != null:
		theater.set_time_scale(_playback_speed)
	if sniper_vfx != null:
		sniper_vfx.set_time_scale(_playback_speed)
	if wing_barrage != null:
		wing_barrage.set_time_scale(_playback_speed)
	_set_status("Velocidad: %.1fx" % _playback_speed)


func set_use_pause_arbitrator(enabled: bool) -> void:
	_use_pause_arbitrator = enabled
	if not enabled:
		_release_all_cutin_pauses()


func scrub_timeline(val: float) -> void:
	if _ignore_scrubber_cb or theater == null:
		return
	if not theater.is_playing():
		_is_frozen = true
		theater.set_frozen(true)
		theater.play_ultimate_cutin(_ult_cfg, _world_to_screen_uv(_rig.global_position))
	theater.scrub_to_normalized(val)


func refill_energy() -> void:
	_sim_ult_energy = _ult_cfg.max_energy
	_sim_skill_cd = 0.0
	_set_status("Energía Ultimate al 100% y Skill lista")


func set_hud_preview_style(style_idx: int) -> void:
	if hud_cluster != null:
		hud_cluster.set_hud_style(style_idx)
	_set_status("HUD Preview: Estilo #%d" % (style_idx + 1))


func apply_skin_by_index(idx: int) -> void:
	if _skins.is_empty():
		return
	var sk: PilotSkinPreset = _skins[clampi(idx, 0, _skins.size() - 1)]
	_active_accent = Color(0.98, 0.14, 0.34, 1.0) if (sk == null or sk.is_base_skin) else sk.accent_color
	if _rig != null and sk != null:
		_rig.apply_skin_preset(sk, 3)
	if theater != null:
		theater.set_skin_presets(sk, 3, sk, 3)
	if sniper_vfx != null:
		sniper_vfx.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if wing_barrage != null:
		wing_barrage.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if hud_cluster != null:
		hud_cluster.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	_set_status("Skin aplicada: %s" % (sk.label if sk != null else "Base"))


func notify_config_changed() -> void:
	if theater != null:
		theater.refresh_live_config()
	if sniper_vfx != null:
		sniper_vfx.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if wing_barrage != null:
		wing_barrage.set_palette(_active_accent, _ult_cfg.secondary_crack_color)


func save_configs_to_disk() -> void:
	_skill_cfg.ensure_defaults()
	_ult_cfg.ensure_defaults()
	var e1: Error = ResourceSaver.save(_skill_cfg, _skill_cfg_path)
	var e2: Error = ResourceSaver.save(_ult_cfg, _ult_cfg_path)
	if e1 == OK and e2 == OK:
		_set_status("Guardado OK en .tres de producción")
	else:
		_set_status("Error guardando .tres (%d / %d)" % [e1, e2])


func reload_configs_from_disk() -> void:
	_load_configs()
	notify_config_changed()
	_set_status("Recargado desde disco")


func apply_window_preset(preset_str: String) -> void:
	var parts: PackedStringArray = preset_str.split("x")
	if parts.size() == 2:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		_set_status("Ventana ajustada a %s" % preset_str)


func return_to_hub() -> void:
	_release_all_cutin_pauses()
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)


func open_skill_ult_studio() -> void:
	_release_all_cutin_pauses()
	get_tree().change_scene_to_file(SKILL_ULT_STUDIO_PATH)


func get_skill_config() -> PilotSkillConfig:
	return _skill_cfg


func get_ultimate_config() -> PilotUltimateConfig:
	return _ult_cfg


func get_skin_labels() -> Array[String]:
	var out: Array[String] = []
	for sk: PilotSkinPreset in _skins:
		out.append(sk.label if (sk != null and not sk.label.is_empty()) else "Base")
	return out


func _set_status(msg: String) -> void:
	var lbl: Label = _panel_refs.get("status_label") as Label
	if is_instance_valid(lbl):
		lbl.text = msg


func _world_to_screen_uv(world_pos: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2(0.5, 0.5)
	var sz: Vector2 = vp.get_visible_rect().size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return Vector2(0.5, 0.5)
	var sp: Vector2 = vp.get_canvas_transform() * world_pos
	return (sp / sz).clamp(Vector2.ZERO, Vector2.ONE)


func _process(delta: float) -> void:
	var world_paused: bool = _is_frozen or PauseArbitrator.is_system_paused() or (theater != null and theater.is_playing())
	var hold_mult: float = (_skill_cfg.hold_aim_time_scale if (_holding_skill_aim and _skill_cfg != null) else 1.0)
	var dt: float = 0.0 if world_paused else (clampf(delta, 0.0, 0.05) * _playback_speed * hold_mult)
	_sim_time += dt

	if _holding_skill_aim:
		_update_hold_aim_target()

	if dt > 0.0 and _rig != null:
		var mv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
		if mv.length_squared() > 0.01:
			_rig.position += mv.normalized() * 280.0 * dt
		var aim_tgt: Vector2 = _selected_dummy.global_position if is_instance_valid(_selected_dummy) else get_global_mouse_position()
		var aim_dir: Vector2 = (aim_tgt - _rig.global_position).normalized()
		_rig.set_locomotion_state(mv if mv.length_squared() > 0.01 else aim_dir, 0.85 if mv.length_squared() > 0.01 else 0.0, aim_dir, false)
		if _ring_ctrl != null:
			_ring_ctrl.set_mouse_target_local(_ring_ctrl.to_local(aim_tgt))
			_ring_ctrl.step(dt)

		for d: _WorkbenchDummy in _dummies:
			if is_instance_valid(d):
				d.position = d.base_pos + Vector2(sin(_sim_time * 1.4 + d.phase_seed) * 14.0, cos(_sim_time * 1.8 + d.phase_seed) * 10.0)

		if _orb_respawn_timer > 0.0:
			_orb_respawn_timer -= dt
			if _orb_respawn_timer <= 0.0:
				for orb: Dictionary in _danmaku_orbs:
					orb["alive"] = true
		for orb: Dictionary in _danmaku_orbs:
			orb["angle"] = float(orb["angle"]) + float(orb["speed"]) * dt
			var a: float = float(orb["angle"])
			var r: float = float(orb["radius"])
			orb["pos"] = Vector2(100.0, 0.0) + Vector2(cos(a) * r * 1.2, sin(a) * r * 0.85)

		_sim_skill_cd = maxf(0.0, _sim_skill_cd - clampf(delta, 0.0, 0.05))
		_sim_ult_energy = minf(_ult_cfg.max_energy, _sim_ult_energy + clampf(delta, 0.0, 0.05) * 9.5)

	if hud_cluster != null:
		hud_cluster.set_state(_sim_skill_cd, _skill_cfg.cooldown_sec, _holding_skill_aim, _sim_ult_energy, _ult_cfg.max_energy)

	if _camera != null:
		var z: float = lerpf(_camera.zoom.x, _target_zoom, clampf(delta * 8.0, 0.0, 1.0))
		_camera.zoom = Vector2(z, z)

	var scrub: HSlider = _panel_refs.get("scrubber") as HSlider
	if is_instance_valid(scrub) and theater != null and theater.is_playing() and not _is_frozen:
		_ignore_scrubber_cb = true
		scrub.value = theater.get_normalized_progress()
		_ignore_scrubber_cb = false

	_refresh_metrics_label()
	queue_redraw()


func _refresh_metrics_label() -> void:
	var lbl: Label = _panel_refs.get("metrics_label") as Label
	if not is_instance_valid(lbl):
		return
	var phase_s: String = theater.get_current_phase_name() if theater != null else "IDLE"
	var pa_s: String = "PAUSED" if PauseArbitrator.is_system_paused() else "FREE"
	var tgt_s: String = _selected_dummy.dummy_name if is_instance_valid(_selected_dummy) else "Cursor"
	lbl.text = "Fase: %s | Pause: %s\nBlanco: %s | Ult: %d%%" % [phase_s, pa_s, tgt_s, int(roundf(_sim_ult_energy))]


func _draw() -> void:
	for orb: Dictionary in _danmaku_orbs:
		if not bool(orb["alive"]):
			continue
		var p: Vector2 = orb["pos"]
		draw_circle(p, 7.5, Color(0.65, 0.25, 1.0, 0.85))
		draw_circle(p, 3.8, Color(1.6, 1.5, 1.9, 0.95))
