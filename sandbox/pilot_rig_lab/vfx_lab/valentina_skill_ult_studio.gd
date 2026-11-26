extends Node2D
## Studio interactivo aislado de Skill [R] y Ultimate [Q] — Valentina v2.
## Consume directamente los controladores y .tres de producción (Single Source of Truth):
## - PilotCutInTheater (LIVE_BANNER_25D vs RIG_BATTLE_POSE + Impact Frames + Fractura Obsidiana)
## - SniperWeakpointRailVFX (Retícula de Punto Débil + Disparo Sniper Lineal)
## - UltimateWingBarrageController (Pool zero-allocation de 12 cuchillas reales)

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const OrbitalRingScript = preload("res://scenes/pilots/weapons/orbital_weapon_ring_controller.gd")
const CutInTheaterScript = preload("res://scenes/pilots/vfx/abilities/pilot_cutin_theater.gd")
const SniperVFXScript = preload("res://scenes/pilots/vfx/abilities/sniper_weakpoint_rail_vfx.gd")
const WingBarrageScript = preload("res://scenes/pilots/vfx/abilities/ultimate_wing_barrage_controller.gd")
const BackdropScript = preload("res://sandbox/pilot_rig_lab/shader_lab/shader_lab_backdrop.gd")
const StudioHUDScript = preload("res://sandbox/pilot_rig_lab/vfx_lab/valentina_skill_ult_studio_hud.gd")
const HUDClusterScript = preload("res://scenes/ui/hud/components/hud_ability_cluster_preview.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const SKILL_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_skill.tres"
const ULT_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_ultimate.tres"
const ORBITAL_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_orbital_weapon.tres"
const VFX_LAB_SCENE_PATH: String = "res://sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn"

const DANMAKU_COUNT: int = 36

class _StudioDummy extends Node2D:
	var dummy_name: String = "Dummy"
	var max_hp: float = 400.0
	var hp: float = 400.0
	var radius_px: float = 24.0
	var is_boss: bool = false
	var is_selected: bool = false
	var hit_flash: float = 0.0
	var base_pos: Vector2 = Vector2.ZERO
	var phase_seed: float = 0.0

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


var _profile: PilotRigProfile = null
var _skill_cfg: PilotSkillConfig = null
var _ult_cfg: PilotUltimateConfig = null
var _skins: Array[PilotSkinPreset] = []
var _active_skin_idx: int = 0
var _active_accent: Color = Color(0.98, 0.14, 0.34, 1.0)

var _backdrop: Node2D = null
var _camera: Camera2D = null
var _rig: PlanarCombatRig = null
var _ring_ctrl: OrbitalWeaponRingController = null
var _theater: PilotCutInTheater = null
var _sniper_vfx: SniperWeakpointRailVFX = null
var _wing_barrage: UltimateWingBarrageController = null
var _dummies_root: Node2D = null
var _danmaku_root: Node2D = null

var _dummies: Array[_StudioDummy] = []
var _selected_dummy: _StudioDummy = null
var _danmaku_orbs: Array[Dictionary] = []
var _show_danmaku: bool = true
var _orb_respawn_timer: float = 0.0

var _hud_refs: Dictionary = {}
var _hud_preview_layer: CanvasLayer = null
var _hud_cluster: HUDAbilityClusterPreview = null
var _sim_skill_cd: float = 0.0
var _sim_ult_energy: float = 100.0
var _holding_skill_aim: bool = false
var _studio_time_scale: float = 1.0
var _is_frozen: bool = false
var _sim_time: float = 0.0
var _target_zoom: float = 1.05
var _pending_skill_target: _StudioDummy = null
var _pending_skill_pos: Vector2 = Vector2.ZERO
var _ignore_scrubber_cb: bool = false


func _ready() -> void:
	_load_configs()
	_build_world()
	_spawn_scenario(0)
	_build_danmaku_orbs()

	var skin_names: Array[String] = []
	for sk: PilotSkinPreset in _skins:
		skin_names.append(sk.label if (sk != null and not sk.label.is_empty()) else "Base")

	_hud_refs = StudioHUDScript.build_hud(self, _skill_cfg, _ult_cfg, skin_names, {
		"on_trigger_skill": Callable(self, "trigger_skill_demo"),
		"on_trigger_ultimate": Callable(self, "trigger_ultimate_demo"),
		"on_freeze_toggled": Callable(self, "_on_freeze_toggled"),
		"on_speed_changed": Callable(self, "_on_speed_changed"),
		"on_scenario_changed": Callable(self, "_spawn_scenario"),
		"on_timeline_scrub": Callable(self, "_on_timeline_scrub"),
		"on_config_changed": Callable(self, "_on_config_changed"),
		"on_skin_selected": Callable(self, "apply_skin_by_index"),
		"on_hud_style_selected": Callable(self, "set_hud_preview_style"),
		"on_refill_energy": Callable(self, "_on_refill_energy"),
		"on_orbs_toggled": Callable(self, "_on_orbs_toggled"),
		"on_save_configs": Callable(self, "save_configs_to_disk"),
		"on_reload_configs": Callable(self, "_reload_configs_from_disk"),
		"on_open_workbench": Callable(self, "_on_open_workbench"),
		"on_back_to_vfx_lab": Callable(self, "_on_back_to_vfx_lab"),
	})


func _load_configs() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if ResourceLoader.exists(SKILL_CFG_PATH):
		var s: Resource = ResourceLoader.load(SKILL_CFG_PATH)
		if s is PilotSkillConfig:
			_skill_cfg = (s as PilotSkillConfig).duplicate(true) as PilotSkillConfig
	if _skill_cfg == null:
		_skill_cfg = PilotSkillConfig.new()
	_skill_cfg.ensure_defaults()

	if ResourceLoader.exists(ULT_CFG_PATH):
		var u: Resource = ResourceLoader.load(ULT_CFG_PATH)
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


func _build_world() -> void:
	_backdrop = BackdropScript.new()
	_backdrop.name = "StudioBackdrop"
	add_child(_backdrop)

	_camera = Camera2D.new()
	_camera.name = "StudioCamera"
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	_camera.enabled = true
	add_child(_camera)

	_dummies_root = Node2D.new()
	_dummies_root.name = "DummiesRoot"
	_dummies_root.z_index = 12
	add_child(_dummies_root)

	_danmaku_root = Node2D.new()
	_danmaku_root.name = "DanmakuOrbsLayer"
	_danmaku_root.z_index = 20
	add_child(_danmaku_root)

	_rig = PlanarRigScript.new()
	_rig.name = "ValentinaStudioRig"
	_rig.pilot_profile = _profile
	_rig.enable_live_animations = true
	_rig.enable_face_live = true
	_rig.enable_3d_wings = false
	_rig.enable_base_propulsion_wings = true
	_rig.position = Vector2(-120.0, 40.0)
	_rig.z_index = 15
	add_child(_rig)

	_ring_ctrl = OrbitalRingScript.new()
	_ring_ctrl.name = "OrbitalRing"
	if ResourceLoader.exists(ORBITAL_CFG_PATH):
		var ocfg: Resource = ResourceLoader.load(ORBITAL_CFG_PATH)
		if ocfg is PilotOrbitalWeaponConfig:
			var dup: PilotOrbitalWeaponConfig = (ocfg as PilotOrbitalWeaponConfig).duplicate(true) as PilotOrbitalWeaponConfig
			dup.ensure_defaults()
			_ring_ctrl.set_config(dup)
	_ring_ctrl.set_weapon_count(2)
	_rig.add_child(_ring_ctrl)

	_sniper_vfx = SniperVFXScript.new()
	_sniper_vfx.name = "SniperWeakpointRailVFX"
	_sniper_vfx.shot_impacted.connect(_on_sniper_impacted)
	add_child(_sniper_vfx)

	_wing_barrage = WingBarrageScript.new()
	_wing_barrage.name = "UltimateWingBarrageController"
	_wing_barrage.blade_impacted.connect(_on_blade_impacted)
	_wing_barrage.finisher_detonated.connect(_on_finisher_detonated)
	add_child(_wing_barrage)

	_theater = CutInTheaterScript.new()
	_theater.name = "PilotCutInTheater"
	_theater.cutin_release_reached.connect(_on_cutin_release)
	_theater.cutin_finished.connect(_on_cutin_finished)
	add_child(_theater)

	_hud_preview_layer = CanvasLayer.new()
	_hud_preview_layer.name = "HUDPreviewLayer"
	_hud_preview_layer.layer = 22
	_hud_preview_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_preview_layer)

	_hud_cluster = HUDClusterScript.new()
	_hud_cluster.name = "HUDAbilityClusterPreview"
	_hud_preview_layer.add_child(_hud_cluster)


func _spawn_scenario(idx: int) -> void:
	for d: _StudioDummy in _dummies:
		if is_instance_valid(d):
			d.queue_free()
	_dummies.clear()
	_selected_dummy = null

	var center := Vector2(140.0, 0.0)
	if idx == 0:
		# Enjambre de 12 objetivos
		for i: int in range(12):
			var ang: float = float(i) * (TAU / 12.0)
			var ring_r: float = 210.0 if (i % 2 == 0) else 320.0
			var pos: Vector2 = center + Vector2(cos(ang) * ring_r * 1.25, sin(ang) * ring_r * 0.85)
			_add_dummy("Enemigo #%02d" % (i + 1), pos, 260.0, 20.0, false, float(i))
	elif idx == 1:
		# Escuadrón de 4 élites
		var offsets: Array[Vector2] = [Vector2(180, -160), Vector2(310, -40), Vector2(260, 150), Vector2(90, 175)]
		for i: int in range(offsets.size()):
			_add_dummy("Élite #%d" % (i + 1), offsets[i], 650.0, 28.0, false, float(i) * 1.7)
	else:
		# Jefe único para probar convergencia de las 12 alas
		_add_dummy("JEFE ORBITAL", Vector2(260.0, 0.0), 2500.0, 48.0, true, 0.0)

	if not _dummies.is_empty():
		_select_dummy(_dummies[0])


func _add_dummy(d_name: String, pos: Vector2, max_hp: float, rad: float, boss: bool, seed_val: float) -> void:
	var d := _StudioDummy.new()
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


func _select_dummy(d: _StudioDummy) -> void:
	for item: _StudioDummy in _dummies:
		if is_instance_valid(item):
			item.is_selected = (item == d)
			item.queue_redraw()
	_selected_dummy = d


func _build_danmaku_orbs() -> void:
	_danmaku_orbs.clear()
	for i: int in range(DANMAKU_COUNT):
		var ang: float = float(i) * (TAU / float(DANMAKU_COUNT))
		var r: float = 150.0 + float(i % 4) * 75.0
		_danmaku_orbs.append({
			"angle": ang,
			"radius": r,
			"speed": 0.45 + float(i % 3) * 0.22,
			"alive": true,
			"pos": Vector2(cos(ang), sin(ang)) * r,
		})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.keycode == KEY_R and not kev.echo:
			if kev.pressed:
				_begin_skill_hold_aim()
			elif _holding_skill_aim:
				_release_skill_hold_aim()
			return
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_Q:
				trigger_ultimate_demo()
			elif kev.keycode == KEY_P:
				var fb: Button = _hud_refs.get("freeze_button") as Button
				if fb != null:
					fb.button_pressed = not fb.button_pressed
				else:
					_on_freeze_toggled(not _is_frozen)
			elif kev.keycode == KEY_TAB:
				var pnl: Control = _hud_refs.get("panel") as Control
				if pnl != null:
					pnl.visible = not pnl.visible
			elif kev.keycode == KEY_1:
				_spawn_scenario(0)
			elif kev.keycode == KEY_2:
				_spawn_scenario(1)
			elif kev.keycode == KEY_3:
				_spawn_scenario(2)
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_LEFT:
				_try_pick_dummy_at(get_global_mouse_position())
			elif mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.12, 0.55, 2.4)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.12, 0.55, 2.4)


func _try_pick_dummy_at(world_pos: Vector2) -> void:
	var best: _StudioDummy = null
	var best_d: float = 140.0
	for d: _StudioDummy in _dummies:
		if not is_instance_valid(d):
			continue
		var dist: float = d.global_position.distance_to(world_pos)
		if dist < best_d:
			best_d = dist
			best = d
	if best != null:
		_select_dummy(best)


func _begin_skill_hold_aim() -> void:
	if _theater != null and _theater.is_playing():
		return
	_holding_skill_aim = true
	_update_hold_aim_target()


func _release_skill_hold_aim() -> void:
	_holding_skill_aim = false
	if _sniper_vfx != null:
		_sniper_vfx.stop_hold_aim()
	trigger_skill_demo()


func _update_hold_aim_target() -> void:
	if not _holding_skill_aim or _rig == null or _sniper_vfx == null:
		return
	var cursor_w: Vector2 = get_global_mouse_position()
	var best: _StudioDummy = null
	var best_d: float = _skill_cfg.cursor_snap_radius_px if _skill_cfg != null else 240.0
	for d: _StudioDummy in _dummies:
		if not is_instance_valid(d):
			continue
		var dist: float = d.global_position.distance_to(cursor_w)
		if dist < best_d:
			best_d = dist
			best = d
	if best != null:
		_select_dummy(best)
	var active_tgt: _StudioDummy = best if best != null else (_selected_dummy if is_instance_valid(_selected_dummy) else null)
	_sniper_vfx.update_hold_aim(_rig.global_position, active_tgt, cursor_w)


func trigger_skill_demo() -> void:
	if _rig == null or _theater == null:
		return
	_holding_skill_aim = false
	_sim_skill_cd = _skill_cfg.cooldown_sec if _skill_cfg != null else 8.0
	_sim_ult_energy = minf(_ult_cfg.max_energy, _sim_ult_energy + (_ult_cfg.energy_on_skill_cast if _ult_cfg != null else 14.0))
	var target: _StudioDummy = _selected_dummy if is_instance_valid(_selected_dummy) else (_dummies[0] if not _dummies.is_empty() else null)
	_pending_skill_target = target
	_pending_skill_pos = target.global_position if is_instance_valid(target) else (_rig.global_position + Vector2(360.0, 0.0))

	_sniper_vfx.begin_weakpoint_lock(_rig.global_position, target, _pending_skill_pos, _skill_cfg.reticle_lead_sec)
	var center_uv: Vector2 = _world_to_screen_uv(_rig.global_position)
	_theater.play_skill_cutin(_skill_cfg, center_uv)


func trigger_ultimate_demo() -> void:
	if _rig == null or _theater == null:
		return
	_holding_skill_aim = false
	_sim_ult_energy = 0.0
	var center_uv: Vector2 = _world_to_screen_uv(_rig.global_position)
	_theater.play_ultimate_cutin(_ult_cfg, center_uv)


func set_hud_preview_style(style_idx: int) -> void:
	if _hud_cluster != null:
		_hud_cluster.set_hud_style(style_idx)


func _on_refill_energy() -> void:
	_sim_ult_energy = _ult_cfg.max_energy if _ult_cfg != null else 100.0
	_sim_skill_cd = 0.0


func _on_cutin_release(mode_name: StringName) -> void:
	if mode_name == &"skill":
		_sniper_vfx.fire_sniper_beam(_rig.global_position, _pending_skill_target, _pending_skill_pos, _skill_cfg)
		if _skill_cfg.clear_corridor_bullets:
			_clear_orbs_along_corridor(_rig.global_position, _pending_skill_pos, _skill_cfg.bullet_clear_half_width_px)
	elif mode_name == &"ultimate":
		var targets: Array[Node2D] = []
		for d: _StudioDummy in _dummies:
			if is_instance_valid(d):
				targets.append(d)
		if _ult_cfg.purge_all_bullets:
			for orb: Dictionary in _danmaku_orbs:
				orb["alive"] = false
			_orb_respawn_timer = 1.6
		_wing_barrage.launch_barrage(_rig.global_position, targets, _ult_cfg, _rig)


func _on_cutin_finished(_mode_name: StringName) -> void:
	pass


func _on_sniper_impacted(target: Node2D, _hit_pos: Vector2, _beam_end: Vector2) -> void:
	if target is _StudioDummy:
		(target as _StudioDummy).apply_hit(180.0 * _skill_cfg.damage_multiplier * 0.25)


func _on_blade_impacted(target: Node2D, _world_pos: Vector2, _blade_idx: int) -> void:
	if target is _StudioDummy:
		(target as _StudioDummy).apply_hit(65.0 * _ult_cfg.blade_damage_mult * 0.35)


func _on_finisher_detonated(targets: Array[Node2D]) -> void:
	for t: Node2D in targets:
		if t is _StudioDummy:
			(t as _StudioDummy).apply_hit(120.0 * _ult_cfg.shatter_finisher_mult * 0.35)


func _clear_orbs_along_corridor(a: Vector2, b: Vector2, half_w: float) -> void:
	var ab: Vector2 = b - a
	var len_sq: float = maxf(ab.length_squared(), 1.0)
	for orb: Dictionary in _danmaku_orbs:
		if not bool(orb["alive"]):
			continue
		var p: Vector2 = orb["pos"]
		var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
		var closest: Vector2 = a + ab * t
		if p.distance_to(closest) <= half_w:
			orb["alive"] = false
	_orb_respawn_timer = 1.6


func apply_skin_by_index(idx: int) -> void:
	if _skins.is_empty():
		return
	_active_skin_idx = clampi(idx, 0, _skins.size() - 1)
	var sk: PilotSkinPreset = _skins[_active_skin_idx]
	_active_accent = Color(0.98, 0.14, 0.34, 1.0) if (sk == null or sk.is_base_skin) else sk.accent_color
	if _rig != null and sk != null:
		_rig.apply_skin_preset(sk, 3)
	if _theater != null:
		_theater.set_skin_presets(sk, 3, sk, 3)
	if _sniper_vfx != null:
		_sniper_vfx.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if _wing_barrage != null:
		_wing_barrage.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if _hud_cluster != null:
		_hud_cluster.set_palette(_active_accent, _ult_cfg.secondary_crack_color)


func save_configs_to_disk() -> void:
	_skill_cfg.ensure_defaults()
	_ult_cfg.ensure_defaults()
	var err_s: Error = ResourceSaver.save(_skill_cfg, SKILL_CFG_PATH)
	var err_u: Error = ResourceSaver.save(_ult_cfg, ULT_CFG_PATH)
	var lbl: Label = _hud_refs.get("save_status") as Label
	if lbl != null:
		if err_s == OK and err_u == OK:
			lbl.text = "Guardado OK: valentina_v2_skill.tres y valentina_v2_ultimate.tres"
		else:
			lbl.text = "Error al guardar (.tres): skill=%d ult=%d" % [err_s, err_u]


func _reload_configs_from_disk() -> void:
	_load_configs()
	_on_config_changed()
	var lbl: Label = _hud_refs.get("save_status") as Label
	if lbl != null:
		lbl.text = "Recargado desde disco."


func _on_freeze_toggled(frozen: bool) -> void:
	_is_frozen = frozen
	if _theater != null:
		_theater.set_frozen(frozen)


func _on_speed_changed(spd: float) -> void:
	_studio_time_scale = spd
	if _theater != null:
		_theater.set_time_scale(spd)
	if _sniper_vfx != null:
		_sniper_vfx.set_time_scale(spd)
	if _wing_barrage != null:
		_wing_barrage.set_time_scale(spd)


func _on_timeline_scrub(val: float) -> void:
	if _ignore_scrubber_cb or _theater == null:
		return
	if not _theater.is_playing():
		_theater.set_frozen(true)
		_theater.play_ultimate_cutin(_ult_cfg, _world_to_screen_uv(_rig.global_position))
	_theater.scrub_to_normalized(val)


func _on_config_changed() -> void:
	if _theater != null:
		_theater.refresh_live_config()
	if _sniper_vfx != null:
		_sniper_vfx.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if _wing_barrage != null:
		_wing_barrage.set_palette(_active_accent, _ult_cfg.secondary_crack_color)
	if _hud_cluster != null:
		_hud_cluster.set_palette(_active_accent, _ult_cfg.secondary_crack_color)


func _on_orbs_toggled(enabled: bool) -> void:
	_show_danmaku = enabled
	queue_redraw()


func _on_open_workbench() -> void:
	const WB_PATH: String = "res://sandbox/workbenches/skill_ult_workbench/skill_ult_workbench.tscn"
	if ResourceLoader.exists(WB_PATH):
		get_tree().change_scene_to_file(WB_PATH)


func _on_back_to_vfx_lab() -> void:
	if ResourceLoader.exists(VFX_LAB_SCENE_PATH):
		get_tree().change_scene_to_file(VFX_LAB_SCENE_PATH)


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
	var world_paused: bool = _is_frozen or (_theater != null and _theater.is_playing())
	var hold_mult: float = (_skill_cfg.hold_aim_time_scale if (_holding_skill_aim and _skill_cfg != null) else 1.0)
	var dt: float = 0.0 if world_paused else (clampf(delta, 0.0, 0.05) * _studio_time_scale * hold_mult)
	_sim_time += dt

	if _holding_skill_aim:
		_update_hold_aim_target()

	if not world_paused:
		_sim_skill_cd = maxf(0.0, _sim_skill_cd - clampf(delta, 0.0, 0.05))
		_sim_ult_energy = minf(_ult_cfg.max_energy, _sim_ult_energy + clampf(delta, 0.0, 0.05) * 9.5)
	if _hud_cluster != null:
		_hud_cluster.set_state(_sim_skill_cd, _skill_cfg.cooldown_sec, _holding_skill_aim, _sim_ult_energy, _ult_cfg.max_energy)

	# Movimiento suave WASD de Valentina + apuntado al blanco seleccionado
	if dt > 0.0 and _rig != null:
		var mv := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		if mv.length_squared() > 0.01:
			mv = mv.normalized()
			_rig.position += mv * 280.0 * dt
		var aim_target: Vector2 = _selected_dummy.global_position if is_instance_valid(_selected_dummy) else get_global_mouse_position()
		var aim_dir: Vector2 = (aim_target - _rig.global_position).normalized()
		_rig.set_locomotion_state(mv if mv.length_squared() > 0.01 else aim_dir, 0.85 if mv.length_squared() > 0.01 else 0.0, aim_dir, false)
		if _ring_ctrl != null:
			_ring_ctrl.set_mouse_target_local(_ring_ctrl.to_local(aim_target))
			_ring_ctrl.step(dt)

		# Flotación sutil de dummies
		for d: _StudioDummy in _dummies:
			if is_instance_valid(d):
				d.position = d.base_pos + Vector2(sin(_sim_time * 1.4 + d.phase_seed) * 14.0, cos(_sim_time * 1.8 + d.phase_seed) * 10.0)

		# Orbes danmaku simulados
		if _orb_respawn_timer > 0.0:
			_orb_respawn_timer -= dt
			if _orb_respawn_timer <= 0.0:
				for orb: Dictionary in _danmaku_orbs:
					orb["alive"] = true
		for orb: Dictionary in _danmaku_orbs:
			orb["angle"] = float(orb["angle"]) + float(orb["speed"]) * dt
			var a: float = float(orb["angle"])
			var r: float = float(orb["radius"])
			orb["pos"] = Vector2(120.0, 0.0) + Vector2(cos(a) * r * 1.25, sin(a) * r * 0.85)

	if _camera != null:
		var z: float = lerpf(_camera.zoom.x, _target_zoom, clampf(delta * 8.0, 0.0, 1.0))
		_camera.zoom = Vector2(z, z)

	# Actualizar telemetría y scrubber
	var phase_lbl: Label = _hud_refs.get("phase_label") as Label
	if phase_lbl != null and _theater != null:
		var tgt_str: String = _selected_dummy.dummy_name if is_instance_valid(_selected_dummy) else "Cursor"
		phase_lbl.text = "Fase: %s | Blanco: %s | [Tab] Ocultar" % [_theater.get_current_phase_name(), tgt_str]

	var scrub: HSlider = _hud_refs.get("scrubber") as HSlider
	if scrub != null and _theater != null and _theater.is_playing() and not _is_frozen:
		_ignore_scrubber_cb = true
		scrub.value = _theater.get_normalized_progress()
		_ignore_scrubber_cb = false

	queue_redraw()


func _draw() -> void:
	if not _show_danmaku:
		return
	for orb: Dictionary in _danmaku_orbs:
		if not bool(orb["alive"]):
			continue
		var p: Vector2 = orb["pos"]
		draw_circle(p, 7.5, Color(0.65, 0.25, 1.0, 0.85))
		draw_circle(p, 3.8, Color(1.6, 1.5, 1.9, 0.95))


func get_theater() -> PilotCutInTheater:
	return _theater


func get_sniper_vfx() -> SniperWeakpointRailVFX:
	return _sniper_vfx


func get_wing_barrage() -> UltimateWingBarrageController:
	return _wing_barrage


func get_skill_config() -> PilotSkillConfig:
	return _skill_cfg


func get_ultimate_config() -> PilotUltimateConfig:
	return _ult_cfg
