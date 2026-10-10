class_name HighscoresTabController
extends RefCounted

## Responsable de la gestión de pestañas, estilos visuales y alternancia de vistas en HighscoresModal.

signal tab_switched(tab_idx: int)

var current_tab: int = 0
var title_label: Label = null
var table_header: HBoxContainer = null
var scroll_container: ScrollContainer = null
var career_container: ScrollContainer = null
var list_container: VBoxContainer = null
var tab_career_btn: Button = null
var tab_hof_btn: Button = null

func setup(
	p_title_label: Label,
	p_table_header: HBoxContainer,
	p_scroll_container: ScrollContainer,
	p_career_container: ScrollContainer,
	p_list_container: VBoxContainer,
	p_tab_career_btn: Button,
	p_tab_hof_btn: Button
) -> void:
	title_label = p_title_label
	table_header = p_table_header
	scroll_container = p_scroll_container
	career_container = p_career_container
	list_container = p_list_container
	tab_career_btn = p_tab_career_btn
	tab_hof_btn = p_tab_hof_btn

	if tab_career_btn:
		tab_career_btn.pressed.connect(func() -> void: switch_tab(0))
	if tab_hof_btn:
		tab_hof_btn.pressed.connect(func() -> void: switch_tab(1))

func switch_tab(tab_idx: int, play_sound: bool = true) -> void:
	current_tab = tab_idx
	if play_sound:
		var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")

	if tab_idx == 0:
		# Tab Carrera
		if title_label:
			title_label.text = "HOJA DE SERVICIO Y CARRERA ESPACIAL"
		if table_header:
			table_header.visible = false
		if scroll_container:
			scroll_container.visible = false
		if career_container:
			career_container.visible = true
		HighscoresTableBuilder.populate_career_view(career_container)
		_style_tab_buttons(true)
	else:
		# Tab Salón de la Fama
		if title_label:
			title_label.text = "SALÓN DE LA FAMA — TOP 10 RÉCORDS"
		if career_container:
			career_container.visible = false
		if table_header:
			table_header.visible = true
		if scroll_container:
			scroll_container.visible = true
		HighscoresTableBuilder.populate_table(list_container)
		_style_tab_buttons(false)

	tab_switched.emit(current_tab)

func style_buttons() -> void:
	_style_tab_buttons(current_tab == 0)

func _style_tab_buttons(is_career_active: bool) -> void:
	if tab_career_btn:
		tab_career_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_career_active else Color(0.65, 0.75, 0.85, 0.7)
	if tab_hof_btn:
		tab_hof_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if not is_career_active else Color(0.65, 0.75, 0.85, 0.7)
