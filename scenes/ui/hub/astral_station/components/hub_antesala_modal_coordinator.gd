class_name HubAntesalaModalCoordinator
extends Node

## Coordinador modular de paneles diegéticos Astral Pop-Ink y modales reales de producción:
## - Paneles integrados al lateral derecho (dejan a la piloto/consola limpia en el tercio izquierdo)
## - Holograma 3D de Navegante con shader circular limpio (oculto automáticamente en CALIBRATING)
## - Modales de producción: CosmeticCarouselModal, CharacterSkillTreeModal, PetSelectionModal,
##   NavigatorSelectionModal, ArsenalBanlistModal, TomeSelectionModal, HighscoresModal, TrophyDetailsModal

signal modal_opened(camera_mode: int, focus_pos: Vector3)
signal modal_closed()
signal pilot_changed(char_id: StringName, accent_color: Color)
signal skins_showcase_toggled(enabled: bool)
signal companions_updated()
signal trophy_upgraded_live(trophy_id: StringName, new_level: int)
signal tactical_seed_changed(request: RunLaunchRequestScript, trigger_flash: bool)

const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const CameraRigScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_camera_rig.gd")
const EvaluatorScript = preload("res://scenes/ui/hub/components/hub_progression_evaluator.gd")
const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const AstralWings3DScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")
const NavHoloShader = preload("res://scenes/ui/hub/astral_station/shaders/hub_nav_hologram_3d.gdshader")
const CharacterDataScript = preload("res://data/characters/character_data.gd")
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const SkillTreeModalScene: PackedScene = preload("res://scenes/ui/hub/character_skill_tree_modal.tscn")
const CosmeticCarouselScene: PackedScene = preload("res://scenes/ui/cosmetics/cosmetic_carousel_modal.tscn")
const PetModalScene: PackedScene = preload("res://scenes/ui/character_select/pet_selection_modal.tscn")
const NavigatorModalScene: PackedScene = preload("res://scenes/ui/character_select/navigator_selection_modal.tscn")
const BanlistModalScene: PackedScene = preload("res://scenes/ui/character_select/arsenal_banlist_modal.tscn")
const TomeModalScene: PackedScene = preload("res://scenes/ui/character_select/tome_selection_modal.tscn")
const HighscoresModalScene: PackedScene = preload("res://scenes/ui/highscores/highscores_modal.tscn")
const TrophyModalScene: PackedScene = preload("res://scenes/ui/hub/trophy_details_modal.tscn")

const COLOR_BG := Color(0.038, 0.052, 0.112, 0.94)
const COLOR_BTN_BG := Color(0.085, 0.115, 0.22, 0.96)
const COLOR_BTN_HOVER := Color(0.14, 0.19, 0.34, 0.98)
const COLOR_GOLD := Color(0.95, 0.80, 0.34, 1.0)
const COLOR_CYAN := Color(0.05, 0.94, 1.0, 1.0)
const COLOR_PINK := Color(1.0, 0.16, 0.62, 1.0)

var _evaluator: EvaluatorScript = null
var _avatar: HubRigAvatar3DScript = null
var _player_rig_v2: Node = null
var _active_request: RunLaunchRequestScript = null
var _active_panel_key: StringName = &""
var _active_submodal: Node = null
var _is_skins_showcase_active: bool = false

var _ui_layer: CanvasLayer = null
var _pilot_panel: PanelContainer = null
var _pilot_list_vbox: VBoxContainer = null
var _skins_panel: PanelContainer = null
var _companions_panel: PanelContainer = null
var _tactical_panel: PanelContainer = null

var _banlist_btn: Button = null
var _banlist_hint: Label = null
var _tomes_btn: Button = null
var _tomes_hint: Label = null
var _speed_buttons: Dictionary = {}
var _speed_hint: Label = null
var _seed_mode_btn: Button = null
var _seed_input: LineEdit = null
var _seed_apply_btn: Button = null
var _seed_rand_btn: Button = null
var _seed_repeat_btn: Button = null
var _seed_badge_lbl: Label = null
var _seed_hint: Label = null

var _skill_modal: CharacterSkillTreeModal = null
var _cosmetic_modal: CosmeticCarouselModal = null
var _pet_modal: PetSelectionModal = null
var _nav_modal: NavigatorSelectionModal = null
var _banlist_modal: ArsenalBanlistModal = null
var _tome_modal: TomeSelectionModal = null
var _highscores_modal: HighscoresModal = null
var _trophy_modal: TrophyDetailsModal = null

var _nav_holo_mesh: MeshInstance3D = null
var _nav_holo_mat: ShaderMaterial = null


func setup(
	p_evaluator: EvaluatorScript,
	p_avatar: HubRigAvatar3DScript,
	p_initial_request: RunLaunchRequestScript
) -> void:
	_evaluator = p_evaluator
	_avatar = p_avatar
	_active_request = p_initial_request.duplicate_request() if p_initial_request != null else RunLaunchRequestScript.create_random_auto()
	_ensure_ui_layer()


func set_evaluator(p_evaluator: EvaluatorScript) -> void:
	_evaluator = p_evaluator
	if _active_panel_key == &"tactical_console":
		_refresh_tactical_panel()


func set_avatar(p_avatar: HubRigAvatar3DScript) -> void:
	_avatar = p_avatar


func set_player_rig_v2(p_rig_ctrl: Node) -> void:
	_player_rig_v2 = p_rig_ctrl


func set_active_request(req: RunLaunchRequestScript) -> void:
	if req != null:
		_active_request = req.duplicate_request()
		_refresh_tactical_panel()


func get_active_request() -> RunLaunchRequestScript:
	return _active_request


func is_any_modal_open() -> bool:
	if not _active_panel_key.is_empty():
		return true
	if _is_node_visible(_active_submodal):
		return true
	return false


func close_active_modal() -> void:
	if _is_node_visible(_active_submodal):
		_close_submodal_instance(_active_submodal)
		_active_submodal = null
		if _active_panel_key == &"skins_mirror" or _active_panel_key == &"companions_projector" or _active_panel_key == &"tactical_console":
			return

	_hide_all_side_panels()
	_active_panel_key = &""
	if _is_skins_showcase_active:
		_is_skins_showcase_active = false
		if _avatar != null:
			_avatar.set_loadout_showcase_enabled(false, false)
		if _player_rig_v2 != null and is_instance_valid(_player_rig_v2) and _player_rig_v2.has_method("set_hub_loadout_showcase"):
			_player_rig_v2.call("set_hub_loadout_showcase", false)
		skins_showcase_toggled.emit(false)
	modal_closed.emit()


func open_pilot_capsule(focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"pilot_capsule"
	_rebuild_pilot_list()
	if _pilot_panel != null:
		_pilot_panel.visible = true
	modal_opened.emit(CameraRigScript.Mode.CAPSULE_PILOT_FOCUS, focus_pos)


func open_skins_mirror(focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"skins_mirror"
	_is_skins_showcase_active = true
	if _avatar != null:
		sync_avatar_cosmetics(_avatar, SaveManagerScript.get_selected_character())
		_avatar.set_loadout_showcase_enabled(true, true, AstralWings3DScript.AnimState.IDLE_ZERO_G)
	if _player_rig_v2 != null and is_instance_valid(_player_rig_v2):
		if _player_rig_v2.has_method("refresh_equipped_skins"):
			_player_rig_v2.call("refresh_equipped_skins")
		if _player_rig_v2.has_method("set_hub_loadout_showcase"):
			_player_rig_v2.call("set_hub_loadout_showcase", true)
	skins_showcase_toggled.emit(true)
	if _skins_panel != null:
		_skins_panel.visible = true
	modal_opened.emit(CameraRigScript.Mode.SKINS_MIRROR_FOCUS, focus_pos)


func open_talents_nexus(focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"talents_nexus"
	modal_opened.emit(CameraRigScript.Mode.STATION_FOCUS, focus_pos)
	var modal: CharacterSkillTreeModal = _ensure_skill_modal()
	if modal != null:
		_active_submodal = modal
		var cid: StringName = SaveManagerScript.get_selected_character()
		modal.open_for_character(cid)


func open_companions_projector(focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"companions_projector"
	if _companions_panel != null:
		_companions_panel.visible = true
	modal_opened.emit(CameraRigScript.Mode.STATION_FOCUS, focus_pos)


func open_tactical_console(focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"tactical_console"
	_refresh_tactical_panel()
	if _tactical_panel != null:
		_tactical_panel.visible = true
	modal_opened.emit(CameraRigScript.Mode.STATION_FOCUS, focus_pos)


func open_telemetry_totem(focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"telemetry_totem"
	modal_opened.emit(CameraRigScript.Mode.STATION_FOCUS, focus_pos)
	var modal: HighscoresModal = _ensure_highscores_modal()
	if modal != null:
		_active_submodal = modal
		modal.open_highscores()


func open_trophy_details(trophy_id: StringName, focus_pos: Vector3) -> void:
	_hide_all_side_panels()
	_active_panel_key = &"trophy_focus"
	modal_opened.emit(CameraRigScript.Mode.TROPHY_FOCUS, focus_pos)
	var modal: TrophyDetailsModal = _ensure_trophy_modal()
	if modal != null:
		_active_submodal = modal
		modal.open_trophy(trophy_id)


func sync_avatar_cosmetics(avatar: HubRigAvatar3DScript, char_id: StringName) -> void:
	if avatar == null:
		return
	var pilot_preset: PilotSkinPreset = CosmeticsManagerScript.resolve_pilot_skin_preset(char_id, "pilot")
	var pilot_stars: int = CosmeticsManagerScript.resolve_equipped_skin_stars("pilot", char_id)
	if pilot_preset != null:
		avatar.apply_skin_preset(pilot_preset, pilot_stars)

	var wings_preset: PilotSkinPreset = CosmeticsManagerScript.resolve_pilot_skin_preset(char_id, "wings")
	var wings_stars: int = CosmeticsManagerScript.resolve_equipped_skin_stars("wings", char_id)
	if wings_preset != null:
		avatar.apply_wings_skin_preset(wings_preset, wings_stars)

	var weapon_preset: PilotSkinPreset = CosmeticsManagerScript.resolve_pilot_skin_preset(char_id, "weapon")
	var weapon_stars: int = CosmeticsManagerScript.resolve_equipped_skin_stars("weapon", char_id)
	if weapon_preset != null:
		avatar.apply_weapon_skin_preset(weapon_preset, weapon_stars)


func refresh_navigator_hologram(projector_station: Node3D, is_online: bool = true) -> void:
	if projector_station == null or not is_instance_valid(projector_station):
		return
	if _nav_holo_mesh == null or not is_instance_valid(_nav_holo_mesh):
		_nav_holo_mat = ShaderMaterial.new()
		_nav_holo_mat.shader = NavHoloShader
		_nav_holo_mat.set_shader_parameter("holo_tint", COLOR_CYAN)
		_nav_holo_mat.set_shader_parameter("ring_color", COLOR_GOLD)

		var quad := QuadMesh.new()
		quad.size = Vector2(0.58, 0.58)
		_nav_holo_mesh = MeshInstance3D.new()
		_nav_holo_mesh.name = "NavigatorHoloMesh3D"
		_nav_holo_mesh.mesh = quad
		_nav_holo_mesh.position = Vector3(0.0, 2.38, 0.04)
		_nav_holo_mesh.material_override = _nav_holo_mat
		_nav_holo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		projector_station.add_child(_nav_holo_mesh)

	_nav_holo_mesh.visible = is_online
	if not is_online:
		return

	var nav_id: StringName = SaveManagerScript.get_selected_navigator()
	var nav_data: NavigatorData = NavigatorDataScript.get_navigator(nav_id)
	if nav_data != null and _nav_holo_mat != null:
		var tex: Texture2D = nav_data.get_portrait_texture()
		if tex != null:
			_nav_holo_mat.set_shader_parameter("portrait_tex", tex)
		_nav_holo_mat.set_shader_parameter("holo_tint", nav_data.theme_color)


func apply_custom_seed_code(raw_code: String) -> bool:
	var req: RunLaunchRequestScript = RunLaunchRequestScript.create_from_code(raw_code, RunLaunchRequestScript.SeedMode.CUSTOM)
	if req == null:
		return false
	_active_request = req
	_refresh_tactical_panel()
	tactical_seed_changed.emit(_active_request, true)
	return true


func apply_random_auto_seed() -> RunLaunchRequestScript:
	_active_request = RunLaunchRequestScript.create_random_auto()
	_refresh_tactical_panel()
	tactical_seed_changed.emit(_active_request, true)
	return _active_request


func repeat_last_coordinate() -> bool:
	var last_req: RunLaunchRequestScript = RunLaunchRequestScript.get_last_launched()
	if last_req == null:
		return false
	_active_request = RunLaunchRequestScript.create(last_req.master_seed, RunLaunchRequestScript.SeedMode.CUSTOM)
	_refresh_tactical_panel()
	tactical_seed_changed.emit(_active_request, true)
	return true


func set_seed_mode_custom(is_custom: bool) -> void:
	var seed_val: int = _active_request.master_seed if _active_request != null else 428175
	var mode: int = RunLaunchRequestScript.SeedMode.CUSTOM if is_custom else RunLaunchRequestScript.SeedMode.AUTO
	_active_request = RunLaunchRequestScript.create(seed_val, mode)
	_refresh_tactical_panel()
	tactical_seed_changed.emit(_active_request, false)


func _ensure_ui_layer() -> void:
	if _ui_layer != null:
		return
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "HubAntesalaPanelsLayer"
	_ui_layer.layer = 45
	add_child(_ui_layer)

	_build_pilot_panel()
	_build_skins_panel()
	_build_companions_panel()
	_build_tactical_panel()
	_hide_all_side_panels()


func _hide_all_side_panels() -> void:
	for p: PanelContainer in [_pilot_panel, _skins_panel, _companions_panel, _tactical_panel]:
		if p != null:
			p.visible = false


func _build_pilot_panel() -> void:
	_pilot_panel = _create_right_side_panel("PilotCapsulePanel", 380.0, COLOR_GOLD)
	_ui_layer.add_child(_pilot_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_pilot_panel.add_child(vbox)

	_add_header(vbox, "CÁPSULA DE PILOTO", COLOR_GOLD)
	var sub := Label.new()
	sub.text = "Sincronización de avatar en Estación Astral:"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 1.0))
	vbox.add_child(sub)

	_pilot_list_vbox = VBoxContainer.new()
	_pilot_list_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_pilot_list_vbox)

	var close_btn: Button = _make_styled_button("Cerrar Cápsula [ESC]", Color(0.75, 0.82, 0.94, 1.0))
	close_btn.pressed.connect(close_active_modal)
	vbox.add_child(close_btn)


func _rebuild_pilot_list() -> void:
	if _pilot_list_vbox == null:
		return
	for ch: Node in _pilot_list_vbox.get_children():
		ch.queue_free()

	var current_id: StringName = SaveManagerScript.get_selected_character()
	var roster: Array[CharacterData] = CharacterDataScript.load_roster_ordered()
	for cd: CharacterData in roster:
		if cd == null:
			continue
		var is_ready: bool = cd.is_playable_rework_ready
		var is_unlocked: bool = SaveManagerScript.is_character_unlocked(cd.character_id)
		var btn: Button = _make_styled_button("", cd.color if (is_ready and is_unlocked) else Color(0.45, 0.48, 0.58, 1.0))
		if is_ready and is_unlocked:
			var mark: String = " ★ ACTIVA" if cd.character_id == current_id else ""
			btn.text = "%s — %s%s" % [cd.display_name, cd.title, mark]
			var target_cid: StringName = cd.character_id
			var target_col: Color = cd.color
			btn.pressed.connect(func() -> void:
				SaveManagerScript.set_selected_character(target_cid)
				if _avatar != null:
					sync_avatar_cosmetics(_avatar, target_cid)
				pilot_changed.emit(target_cid, target_col)
				_rebuild_pilot_list()
			)
		elif not is_ready:
			btn.text = "%s — En sincronización (Rework)" % cd.display_name
			btn.disabled = true
		else:
			btn.text = "%s — Bloqueada" % cd.display_name
			btn.disabled = true
		_pilot_list_vbox.add_child(btn)


func _build_skins_panel() -> void:
	_skins_panel = _create_right_side_panel("SkinsMirrorPanel", 370.0, COLOR_PINK)
	_ui_layer.add_child(_skins_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_skins_panel.add_child(vbox)

	_add_header(vbox, "ESPEJO DE SKINS // PREVIEW 3D", COLOR_PINK)
	var info := Label.new()
	info.text = "Alas 3D y Arma Orbital activas en vivo sobre la piloto:"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 1.0))
	vbox.add_child(info)

	for spec: Array in [
		["Traje de Piloto (pilot)", "pilot", COLOR_PINK],
		["Alas Astrales (wings)", "wings", COLOR_CYAN],
		["Arma Orbital (weapon)", "weapon", COLOR_GOLD],
	]:
		var b: Button = _make_styled_button(str(spec[0]), spec[2] as Color)
		var cat: String = str(spec[1])
		b.pressed.connect(func() -> void: _open_cosmetic_slot(cat))
		vbox.add_child(b)

	var close_btn: Button = _make_styled_button("Cerrar Espejo [ESC]", Color(0.75, 0.82, 0.94, 1.0))
	close_btn.pressed.connect(close_active_modal)
	vbox.add_child(close_btn)


func _open_cosmetic_slot(category: String) -> void:
	_play_preview_for_category(category)
	var modal: CosmeticCarouselModal = _ensure_cosmetic_modal()
	if modal == null:
		return
	var cid: StringName = SaveManagerScript.get_selected_character()
	var roster: Dictionary = CharacterDataScript.load_roster()
	var cdata: CharacterData = roster.get(cid, null) as CharacterData
	_active_submodal = modal
	modal.open_modal(category, cid, cdata)


func _play_preview_for_category(category: String) -> void:
	if _avatar == null:
		return
	match category:
		"pilot":
			_avatar.play_pilot_skin_turnaround()
		"wings", "ship":
			_avatar.play_wings_skin_flourish()
		"weapon":
			_avatar.play_weapon_skin_inspect()


func _build_companions_panel() -> void:
	_companions_panel = _create_right_side_panel("CompanionsProjectorPanel", 370.0, COLOR_CYAN)
	_ui_layer.add_child(_companions_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_companions_panel.add_child(vbox)

	_add_header(vbox, "PROYECTOR DE COMPAÑÍA", COLOR_CYAN)
	var pet_btn: Button = _make_styled_button("Mascota (Lounge / Seguidor)", COLOR_CYAN)
	pet_btn.pressed.connect(func() -> void:
		var m: PetSelectionModal = _ensure_pet_modal()
		if m != null:
			_active_submodal = m
			m.open_modal()
	)
	vbox.add_child(pet_btn)

	var nav_btn: Button = _make_styled_button("Navegante Táctica (Holograma)", COLOR_GOLD)
	nav_btn.pressed.connect(func() -> void:
		var m: NavigatorSelectionModal = _ensure_navigator_modal()
		if m != null:
			_active_submodal = m
			m.open_modal()
	)
	vbox.add_child(nav_btn)

	var close_btn: Button = _make_styled_button("Cerrar Proyector [ESC]", Color(0.75, 0.82, 0.94, 1.0))
	close_btn.pressed.connect(close_active_modal)
	vbox.add_child(close_btn)


func _build_tactical_panel() -> void:
	_tactical_panel = _create_right_side_panel("TacticalConsolePanel", 400.0, COLOR_GOLD)
	_ui_layer.add_child(_tactical_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	_tactical_panel.add_child(vbox)

	_add_header(vbox, "CONSOLA TÁCTICA DE RUN", COLOR_GOLD)

	_banlist_btn = _make_styled_button("Banlist de Arsenal & Ítems", COLOR_GOLD)
	_banlist_btn.pressed.connect(func() -> void:
		var m: ArsenalBanlistModal = _ensure_banlist_modal()
		if m != null:
			_active_submodal = m
			m.open_modal(SaveManagerScript.get_selected_character(), 0)
	)
	vbox.add_child(_banlist_btn)
	_banlist_hint = _make_hint_label()
	vbox.add_child(_banlist_hint)

	_tomes_btn = _make_styled_button("Pool de Tomos Iniciales", COLOR_PINK)
	_tomes_btn.pressed.connect(func() -> void:
		var m: TomeSelectionModal = _ensure_tome_modal()
		if m != null:
			_active_submodal = m
			m.open_modal(SaveManagerScript.get_selected_character())
	)
	vbox.add_child(_tomes_btn)
	_tomes_hint = _make_hint_label()
	vbox.add_child(_tomes_hint)

	_add_header(vbox, "Overclock de Velocidad", COLOR_CYAN)
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 6)
	vbox.add_child(spd_row)
	for spd: float in [1.0, 1.25, 1.5]:
		var label_txt: String = "%.2fx" % spd if not is_equal_approx(spd, 1.0) else "1.0x"
		var sb: Button = _make_styled_button(label_txt, COLOR_CYAN)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spd_val: float = spd
		sb.pressed.connect(func() -> void:
			SaveManagerScript.set_game_speed(spd_val)
			_refresh_tactical_panel()
		)
		spd_row.add_child(sb)
		_speed_buttons[spd] = sb
	_speed_hint = _make_hint_label()
	vbox.add_child(_speed_hint)

	_add_header(vbox, "Coordenadas / Seed de Salto", COLOR_CYAN)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mode_row)
	_seed_mode_btn = _make_styled_button("Modo: AUTO", COLOR_CYAN)
	_seed_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_mode_btn.pressed.connect(func() -> void:
		var is_cur_custom: bool = _active_request != null and _active_request.is_custom_seeded()
		set_seed_mode_custom(not is_cur_custom)
	)
	mode_row.add_child(_seed_mode_btn)

	_seed_badge_lbl = Label.new()
	_seed_badge_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	mode_row.add_child(_seed_badge_lbl)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 6)
	vbox.add_child(code_row)
	_seed_input = LineEdit.new()
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.placeholder_text = "ASTR-XXXXXX o entero"
	code_row.add_child(_seed_input)

	_seed_apply_btn = _make_styled_button("Aplicar", COLOR_GOLD)
	_seed_apply_btn.pressed.connect(func() -> void:
		if _seed_input != null:
			apply_custom_seed_code(_seed_input.text)
			_seed_input.release_focus()
	)
	code_row.add_child(_seed_apply_btn)

	var seed_act_row := HBoxContainer.new()
	seed_act_row.add_theme_constant_override("separation", 6)
	vbox.add_child(seed_act_row)
	_seed_rand_btn = _make_styled_button("Aleatoria (AUTO)", COLOR_CYAN)
	_seed_rand_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_rand_btn.pressed.connect(func() -> void: apply_random_auto_seed())
	seed_act_row.add_child(_seed_rand_btn)

	_seed_repeat_btn = _make_styled_button("Repetir última", COLOR_GOLD)
	_seed_repeat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_repeat_btn.pressed.connect(func() -> void: repeat_last_coordinate())
	seed_act_row.add_child(_seed_repeat_btn)

	_seed_hint = _make_hint_label()
	vbox.add_child(_seed_hint)

	var close_btn: Button = _make_styled_button("Cerrar Consola [ESC]", Color(0.75, 0.82, 0.94, 1.0))
	close_btn.pressed.connect(close_active_modal)
	vbox.add_child(close_btn)


func _refresh_tactical_panel() -> void:
	if _tactical_panel == null:
		return
	var ban_ok: bool = _evaluator == null or _evaluator.is_module_unlocked(&"tactical_banlist")
	var tomes_ok: bool = _evaluator == null or _evaluator.is_module_unlocked(&"tactical_tomes")
	var speed_ok: bool = _evaluator == null or _evaluator.is_module_unlocked(&"tactical_speed")
	var seed_ok: bool = _evaluator == null or _evaluator.is_module_unlocked(&"tactical_seed")

	if _banlist_btn != null:
		_banlist_btn.disabled = not ban_ok
	if _banlist_hint != null:
		_banlist_hint.visible = not ban_ok
		_banlist_hint.text = "🔒 " + (_evaluator.get_locked_hint(&"tactical_banlist") if _evaluator != null else "")

	if _tomes_btn != null:
		_tomes_btn.disabled = not tomes_ok
	if _tomes_hint != null:
		_tomes_hint.visible = not tomes_ok
		_tomes_hint.text = "🔒 " + (_evaluator.get_locked_hint(&"tactical_tomes") if _evaluator != null else "")

	var cur_speed: float = SaveManagerScript.get_game_speed()
	for spd_var: Variant in _speed_buttons.keys():
		var spd: float = float(spd_var)
		var btn: Button = _speed_buttons[spd_var] as Button
		if btn != null:
			btn.disabled = (not speed_ok) and (not is_equal_approx(spd, 1.0))
			btn.modulate = COLOR_GOLD if is_equal_approx(cur_speed, spd) else Color.WHITE
	if _speed_hint != null:
		_speed_hint.visible = not speed_ok
		_speed_hint.text = "🔒 " + (_evaluator.get_locked_hint(&"tactical_speed") if _evaluator != null else "")

	for c: Control in [_seed_mode_btn, _seed_input, _seed_apply_btn, _seed_rand_btn, _seed_repeat_btn]:
		if c != null:
			if c is Button:
				(c as Button).disabled = not seed_ok
			elif c is LineEdit:
				(c as LineEdit).editable = seed_ok
	if _seed_repeat_btn != null and seed_ok:
		_seed_repeat_btn.disabled = (RunLaunchRequestScript.get_last_launched() == null)
	if _seed_hint != null:
		_seed_hint.visible = not seed_ok
		_seed_hint.text = "🔒 " + (_evaluator.get_locked_hint(&"tactical_seed") if _evaluator != null else "")

	if _active_request != null:
		if _seed_mode_btn != null:
			_seed_mode_btn.text = "Modo: CUSTOM" if _active_request.is_custom_seeded() else "Modo: AUTO"
		if _seed_badge_lbl != null:
			_seed_badge_lbl.text = _active_request.get_seed_badge_text()
		if _seed_input != null and not _seed_input.has_focus():
			_seed_input.text = _active_request.coordinate_code


func _ensure_skill_modal() -> CharacterSkillTreeModal:
	if _skill_modal == null:
		_skill_modal = SkillTreeModalScene.instantiate() as CharacterSkillTreeModal
		if _skill_modal != null:
			var backdrop: ColorRect = _skill_modal.get_node_or_null("Backdrop") as ColorRect
			if backdrop != null:
				if backdrop.material is ShaderMaterial:
					var bd_mat := (backdrop.material as ShaderMaterial).duplicate() as ShaderMaterial
					bd_mat.set_shader_parameter("blur_amount", 1.8)
					bd_mat.set_shader_parameter("tint_color", Color(0.02, 0.025, 0.06, 0.44))
					backdrop.material = bd_mat
				backdrop.color = Color(0.025, 0.035, 0.055, 0.48)
			if _ui_layer != null:
				_ui_layer.add_child(_skill_modal)
			else:
				add_child(_skill_modal)
			_skill_modal.modal_closed.connect(_on_submodal_closed_return_to_roam)
	return _skill_modal


func _ensure_cosmetic_modal() -> CosmeticCarouselModal:
	if _cosmetic_modal == null:
		_cosmetic_modal = CosmeticCarouselScene.instantiate() as CosmeticCarouselModal
		if _cosmetic_modal != null:
			add_child(_cosmetic_modal)
			_cosmetic_modal.skin_selected.connect(func(slot_key: String, _skin_id: String) -> void:
				if _avatar != null:
					sync_avatar_cosmetics(_avatar, SaveManagerScript.get_selected_character())
					_play_preview_for_category(slot_key)
				if _player_rig_v2 != null and is_instance_valid(_player_rig_v2) and _player_rig_v2.has_method("refresh_equipped_skins"):
					_player_rig_v2.call("refresh_equipped_skins")
			)
			_cosmetic_modal.skin_modal_closed.connect(func(_cat: String, _tid: StringName, _sid: String) -> void:
				_active_submodal = null
				if _avatar != null:
					sync_avatar_cosmetics(_avatar, SaveManagerScript.get_selected_character())
				if _player_rig_v2 != null and is_instance_valid(_player_rig_v2) and _player_rig_v2.has_method("refresh_equipped_skins"):
					_player_rig_v2.call("refresh_equipped_skins")
			)
	return _cosmetic_modal


func _ensure_pet_modal() -> PetSelectionModal:
	if _pet_modal == null:
		_pet_modal = PetModalScene.instantiate() as PetSelectionModal
		if _pet_modal != null:
			add_child(_pet_modal)
			_pet_modal.pet_selected.connect(func(_pid: StringName) -> void: companions_updated.emit())
			_pet_modal.skin_equipped.connect(func(_sk: String, _sid: String) -> void: companions_updated.emit())
			_pet_modal.closed.connect(func() -> void: _active_submodal = null)
	return _pet_modal


func _ensure_navigator_modal() -> NavigatorSelectionModal:
	if _nav_modal == null:
		_nav_modal = NavigatorModalScene.instantiate() as NavigatorSelectionModal
		if _nav_modal != null:
			add_child(_nav_modal)
			_nav_modal.navigator_selected.connect(func(_nid: StringName) -> void: companions_updated.emit())
			_nav_modal.skin_equipped.connect(func(_sk: String, _sid: String) -> void: companions_updated.emit())
			_nav_modal.closed.connect(func() -> void: _active_submodal = null)
	return _nav_modal


func _ensure_banlist_modal() -> ArsenalBanlistModal:
	if _banlist_modal == null:
		_banlist_modal = BanlistModalScene.instantiate() as ArsenalBanlistModal
		if _banlist_modal != null:
			add_child(_banlist_modal)
			_banlist_modal.closed.connect(func() -> void: _active_submodal = null)
	return _banlist_modal


func _ensure_tome_modal() -> TomeSelectionModal:
	if _tome_modal == null:
		_tome_modal = TomeModalScene.instantiate() as TomeSelectionModal
		if _tome_modal != null:
			add_child(_tome_modal)
			_tome_modal.closed.connect(func() -> void: _active_submodal = null)
	return _tome_modal


func _ensure_highscores_modal() -> HighscoresModal:
	if _highscores_modal == null:
		_highscores_modal = HighscoresModalScene.instantiate() as HighscoresModal
		if _highscores_modal != null:
			add_child(_highscores_modal)
			_highscores_modal.closed.connect(_on_submodal_closed_return_to_roam)
	return _highscores_modal


func _ensure_trophy_modal() -> TrophyDetailsModal:
	if _trophy_modal == null:
		_trophy_modal = TrophyModalScene.instantiate() as TrophyDetailsModal
		if _trophy_modal != null:
			add_child(_trophy_modal)
			_trophy_modal.trophy_upgraded.connect(func(tid: StringName, lvl: int) -> void:
				trophy_upgraded_live.emit(tid, lvl)
			)
			_trophy_modal.modal_closed.connect(_on_submodal_closed_return_to_roam)
	return _trophy_modal


func _on_submodal_closed_return_to_roam() -> void:
	_active_submodal = null
	_active_panel_key = &""
	modal_closed.emit()


func _is_node_visible(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is CanvasLayer:
		return (n as CanvasLayer).visible
	if n is CanvasItem:
		return (n as CanvasItem).visible
	return false


func _close_submodal_instance(m: Node) -> void:
	if m.has_method("close_modal"):
		m.call("close_modal")
	elif m.has_method("close_highscores"):
		m.call("close_highscores")
	elif m is CanvasLayer:
		(m as CanvasLayer).visible = false
	elif m is CanvasItem:
		(m as CanvasItem).visible = false


func _create_right_side_panel(panel_name: String, width_px: float, border_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = panel_name
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.offset_left = -(width_px + 22.0)
	p.offset_right = -22.0
	p.offset_top = 84.0
	p.custom_minimum_size = Vector2(width_px, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_content_margin_all(14.0)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_styled_button(text_str: String, accent_col: Color) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(0.0, 34.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = COLOR_BTN_BG
	sb_norm.border_color = accent_col.lerp(Color.WHITE, 0.15)
	sb_norm.set_border_width_all(1)
	sb_norm.border_width_left = 3
	sb_norm.set_content_margin_all(8.0)

	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	sb_hover.bg_color = COLOR_BTN_HOVER
	sb_hover.border_color = accent_col

	var sb_dis := sb_norm.duplicate() as StyleBoxFlat
	sb_dis.bg_color = Color(0.05, 0.06, 0.10, 0.72)
	sb_dis.border_color = Color(0.28, 0.30, 0.38, 0.65)

	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("disabled", sb_dis)
	return btn


func _add_header(parent: VBoxContainer, title_text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)


func _make_hint_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.28, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.visible = false
	return lbl
