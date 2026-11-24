class_name WorkbenchHub
extends Control
## Hub de acceso rápido para Workbenches de producción, Combat Gym y Pilot Rig Labs (Cast v2).

const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")

const WORKBENCH_SCENES: Dictionary = {
	"combat_gym": "res://sandbox/combat_gym/combat_gym.tscn",
	"hud": "res://sandbox/workbenches/hud_workbench/hud_workbench.tscn",
	"dialogue": "res://sandbox/workbenches/dialogue_workbench/dialogue_workbench.tscn",
	"char_select": "res://sandbox/workbenches/character_select_workbench/character_select_workbench.tscn",
	"hub_art_lab": "res://sandbox/hub_art_lab/hub_art_lab.tscn",
}

const PILOT_RIG_LAB_SCENES: Dictionary = {
	"proto": "res://sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn",
	"anim_test": "res://sandbox/pilot_rig_lab/proto/planar_anim_test.tscn",
	"face_lab": "res://sandbox/pilot_rig_lab/face_lab/valentina_face_lab.tscn",
	"shader_lab": "res://sandbox/pilot_rig_lab/shader_lab/planar_shader_lab.tscn",
	"vfx_lab": "res://sandbox/pilot_rig_lab/vfx_lab/valentina_vfx_lab.tscn",
	"guns_lab": "res://sandbox/pilot_rig_lab/guns_lab/valentina_guns_lab.tscn",
	"3d_lab": "res://sandbox/pilot_rig_lab/3d_lab/valentina_3d_lab.tscn",
	"banner_lab": "res://sandbox/pilot_rig_lab/banner_lab/valentina_banner_lab.tscn",
	"dialogue_lab": "res://sandbox/pilot_rig_lab/dialogue_lab/pilot_dialogue_lab.tscn",
	"cosmos_lab": "res://sandbox/pilot_rig_lab/cosmos_lighting_lab/valentina_cosmos_lab.tscn",
	"calibrator": "res://sandbox/pilot_rig_lab/calibrator/rig_calibrator.tscn",
}

const PILOT_LAB_SPECS: Array[Dictionary] = [
	{"key": "proto", "title": "Proto Rig 8-Dir", "desc": "Arena general & órbita"},
	{"key": "anim_test", "title": "Anim Lab (6 Tabs)", "desc": "Pose, Idle, Vuelo, Kiting, Giros, Jiggle"},
	{"key": "face_lab", "title": "Face Lab", "desc": "Ojos Live2D, cabello & expresiones"},
	{"key": "shader_lab", "title": "Shader Lab A/B", "desc": "Cel 2.5D, skins, estilos & normal"},
	{"key": "vfx_lab", "title": "VFX Lab", "desc": "Alas 2D base + estela Sandevistan"},
	{"key": "guns_lab", "title": "Guns Lab", "desc": "Anillo orbital 2.5D & Rail-Lance"},
	{"key": "3d_lab", "title": "3D Wings Lab", "desc": "Alas Astral Seraph 3D cel-shaded"},
	{"key": "banner_lab", "title": "Banner Lab 2.5D", "desc": "Live Splash Art + Lock-In"},
	{"key": "dialogue_lab", "title": "Dialogue Lab 2.5D", "desc": "Close-ups vivos, poses & teatro"},
	{"key": "cosmos_lab", "title": "Cosmos Lighting", "desc": "Sol, bioma y eclipses sobre rig"},
	{"key": "calibrator", "title": "Rig Calibrator", "desc": "Anclas, huesos, Z-order & simetría"},
]

const CARD_SPECS: Array[Dictionary] = [
	{
		"key": "combat_gym",
		"shortcut": "[1]",
		"title": "Combat Gym (Arena In-Game)",
		"accent": Color(0.28, 0.92, 1.0, 1.0),
		"desc": "Player Valentina v2 real, OverheadHealthBar, Anillo Orbital 1–4 armas, HUD completo, Cosmos y Dummies.",
	},
	{
		"key": "hud",
		"shortcut": "[2]",
		"title": "HUD Workbench",
		"accent": Color(0.32, 1.0, 0.65, 1.0),
		"desc": "Calibra GameHUD real (0–4 armas, vida, escudo, boss bar, alertas) con grilla, bounds y cotas de equidistancia.",
	},
	{
		"key": "dialogue",
		"shortcut": "[3]",
		"title": "Dialogue Workbench",
		"accent": Color(1.0, 0.55, 0.72, 1.0),
		"desc": "Prueba todos los escenarios de CombatNarrativeDirector y retratos .dch de Valentina y rivales en 1 clic.",
	},
	{
		"key": "char_select",
		"shortcut": "[4]",
		"title": "Character Select Workbench",
		"accent": Color(1.0, 0.82, 0.30, 1.0),
		"desc": "Itera CharacterSelectUI, HeroPickerModal y skins shader sin modificar tu perfil real (respaldo automático).",
	},
	{
		"key": "hub_art_lab",
		"shortcut": "[5]",
		"title": "Hub Art Lab 3D (Estación Astral v2)",
		"accent": Color(0.95, 0.25, 0.48, 1.0),
		"desc": "Vertical Slice del Hub 3D: piso/muros Ink SDF 2x, props ArcSys procedurales, Cápsula Central y Ventanal Cosmos vivo.",
	},
]

const RIG_LAB_NOTES: String = "Playbook Multi-Piloto: docs/PILOT_CREATION_PIPELINE.md · Scaffold: sandbox/pilot_rig_lab/tools/scaffold_new_pilot.py"

var _pilot_entries: Array[Dictionary] = []
var _pilot_opt: OptionButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pilot_entries = PilotLabSelectorScript.scan_profile_entries()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	match key_ev.keycode:
		KEY_1:
			launch_workbench("combat_gym")
		KEY_2:
			launch_workbench("hud")
		KEY_3:
			launch_workbench("dialogue")
		KEY_4:
			launch_workbench("char_select")
		KEY_5:
			launch_workbench("hub_art_lab")


func launch_workbench(key: String) -> void:
	var target_path: String = str(WORKBENCH_SCENES.get(key, ""))
	if target_path.is_empty():
		return
	get_tree().change_scene_to_file(target_path)


func launch_pilot_rig_lab(key: String) -> void:
	var target_path: String = str(PILOT_RIG_LAB_SCENES.get(key, ""))
	if target_path.is_empty():
		return
	get_tree().change_scene_to_file(target_path)


func _on_pilot_selected(idx: int) -> void:
	if idx < 0 or idx >= _pilot_entries.size():
		return
	var p_path: String = str(_pilot_entries[idx].get("profile_path", ""))
	PilotLabSelectorScript.set_selected_profile_path(p_path)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.025, 0.035, 0.065, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_row)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 4)
	header_row.add_child(title_vbox)

	var title := Label.new()
	title.text = "ASTRA DREAM — WORKBENCH HUB"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.28, 0.94, 1.0, 1.0))
	title_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Entornos rápidos (F6) sobre escenas de producción y Pilot Rig Labs (Cast v2). Presioná [1..5] o elegí un entorno."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.9))
	title_vbox.add_child(subtitle)

	var pilot_box := HBoxContainer.new()
	pilot_box.add_theme_constant_override("separation", 8)
	pilot_box.alignment = BoxContainer.ALIGNMENT_END
	header_row.add_child(pilot_box)

	var pilot_lbl := Label.new()
	pilot_lbl.text = "Piloto Activo (Cast v2):"
	pilot_lbl.add_theme_font_size_override("font_size", 13)
	pilot_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.78, 1.0))
	pilot_box.add_child(pilot_lbl)

	_pilot_opt = OptionButton.new()
	_pilot_opt.custom_minimum_size = Vector2(230.0, 36.0)
	_pilot_opt.focus_mode = Control.FOCUS_NONE
	var active_path: String = PilotLabSelectorScript.get_selected_profile_path()
	var selected_idx: int = 0
	for i: int in range(_pilot_entries.size()):
		var entry: Dictionary = _pilot_entries[i]
		_pilot_opt.add_item("%s (%s)" % [str(entry.get("display_name", "")), str(entry.get("pilot_id", ""))])
		if str(entry.get("profile_path", "")) == active_path:
			selected_idx = i
	if _pilot_entries.size() > 0:
		_pilot_opt.select(selected_idx)
		PilotLabSelectorScript.set_selected_profile_path(str(_pilot_entries[selected_idx].get("profile_path", "")))
	_pilot_opt.item_selected.connect(_on_pilot_selected)
	pilot_box.add_child(_pilot_opt)

	var grid := GridContainer.new()
	grid.columns = 3 if CARD_SPECS.size() > 4 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	root_vbox.add_child(grid)

	for spec: Dictionary in CARD_SPECS:
		grid.add_child(_make_card(spec))

	var labs_header := Label.new()
	labs_header.text = "PILOT RIG LABS (CAST V2 — USAN EL PILOTO ACTIVO SELECCIONADO ARRIBA)"
	labs_header.add_theme_font_size_override("font_size", 14)
	labs_header.add_theme_color_override("font_color", Color(1.0, 0.55, 0.75, 1.0))
	root_vbox.add_child(labs_header)

	var labs_grid := GridContainer.new()
	labs_grid.columns = 5
	labs_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labs_grid.add_theme_constant_override("h_separation", 10)
	labs_grid.add_theme_constant_override("v_separation", 10)
	root_vbox.add_child(labs_grid)

	for lab_spec: Dictionary in PILOT_LAB_SPECS:
		labs_grid.add_child(_make_lab_button(lab_spec))

	var footer := Label.new()
	footer.text = RIG_LAB_NOTES
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.62, 0.72, 0.84, 0.82))
	root_vbox.add_child(footer)


func _make_lab_button(spec: Dictionary) -> Button:
	var key: String = str(spec.get("key", ""))
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0.0, 56.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "%s\n%s" % [str(spec.get("title", key)), str(spec.get("desc", ""))]
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void:
		launch_pilot_rig_lab(key)
	)
	return btn


func _make_card(spec: Dictionary) -> PanelContainer:
	var accent: Color = spec.get("accent", Color.CYAN) as Color
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "%s %s" % [str(spec.get("shortcut", "")), str(spec.get("title", ""))]
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", accent)
	vbox.add_child(header)

	var desc := Label.new()
	desc.text = str(spec.get("desc", ""))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 0.92))
	vbox.add_child(desc)

	var key: String = str(spec.get("key", ""))
	var path_lbl := Label.new()
	path_lbl.text = str(WORKBENCH_SCENES.get(key, ""))
	path_lbl.add_theme_font_size_override("font_size", 11)
	path_lbl.add_theme_color_override("font_color", Color(0.55, 0.68, 0.80, 0.8))
	vbox.add_child(path_lbl)

	var btn := Button.new()
	btn.text = "Abrir %s" % str(spec.get("title", "Workbench"))
	btn.custom_minimum_size = Vector2(0.0, 42.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func() -> void:
		launch_workbench(key)
	)
	vbox.add_child(btn)
	return card
