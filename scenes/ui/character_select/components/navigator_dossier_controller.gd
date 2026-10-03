class_name NavigatorDossierController
extends RefCounted

## NavigatorDossierController.gd
## Controlador modular del dossier de información táctica para NavigatorSelectionModal.
## Gestiona nombres, títulos, estado de enlace, frecuencias de radio, descripción de radar,
const NavigatorDataScript = preload("res://data/navigators/navigator_data.gd")

var index_badge: Label = null
var name_label: Label = null
var status_badge: Label = null
var title_label: Label = null
var radio_dialogue: Label = null
var radar_desc: Label = null
var buff_card: PanelContainer = null
var buff_name_label: Label = null
var buff_desc_label: Label = null
var select_btn: Button = null


func setup(
	p_index_badge: Label,
	p_name_lbl: Label,
	p_status_badge: Label,
	p_title_lbl: Label,
	p_radio_lbl: Label,
	p_radar_lbl: Label,
	p_buff_card: PanelContainer,
	p_buff_name: Label,
	p_buff_desc: Label,
	p_select_btn: Button
) -> void:
	index_badge = p_index_badge
	name_label = p_name_lbl
	status_badge = p_status_badge
	title_label = p_title_lbl
	radio_dialogue = p_radio_lbl
	radar_desc = p_radar_lbl
	buff_card = p_buff_card
	buff_name_label = p_buff_name
	buff_desc_label = p_buff_desc
	select_btn = p_select_btn


func display_navigator(
	nav_data: NavigatorDataScript,
	is_unlocked: bool,
	is_selected: bool,
	current_index: int,
	total_count: int
) -> void:
	if not nav_data:
		return

	if index_badge:
		index_badge.text = "[ %02d / %02d ]" % [current_index + 1, total_count]

	if name_label:
		name_label.text = nav_data.display_name.to_upper()
		name_label.add_theme_color_override("font_color", nav_data.theme_color if is_unlocked else Color(0.6, 0.65, 0.75))

	if title_label:
		title_label.text = "— " + nav_data.title.to_upper()

	if status_badge:
		if is_selected:
			status_badge.text = "[✓ ENLACE ACTIVO]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_badge.text = "[DISPONIBLE]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			status_badge.text = "[🔒 BLOQUEADA]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if radio_dialogue:
		if not nav_data.dialogue_callouts.is_empty():
			radio_dialogue.text = "\"%s\"" % nav_data.dialogue_callouts[0]
		else:
			radio_dialogue.text = "\"Frecuencia de telemetría a la espera...\""

	if radar_desc:
		radar_desc.text = nav_data.specialty_desc if is_unlocked else "Algoritmo de telemetría clasificado."

	if buff_name_label:
		buff_name_label.text = nav_data.buff_name.to_upper() if is_unlocked else "ENLACE TÁCTICO BLOQUEADO"

	if buff_desc_label:
		buff_desc_label.text = nav_data.buff_desc if is_unlocked else "Enlace táctico bloqueado."

	if select_btn:
		select_btn.disabled = not is_unlocked
		if is_selected:
			select_btn.text = "✓ ENLACE ACTIVO (SELECCIONADA)"
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			select_btn.text = "⚡ ENLAZAR A %s [ESPACIO]" % nav_data.display_name.to_upper()
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		else:
			select_btn.text = "🔒 NAVEGANTE BLOQUEADA"
			select_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))


func display_skin(
	cur_skin: Dictionary,
	is_unlocked: bool,
	is_equipped: bool,
	stars: int,
	current_index: int,
	total_count: int
) -> void:
	if cur_skin.is_empty():
		return

	var sname: String = cur_skin.get("skin_name", "Aspecto")
	var pal_name: String = cur_skin.get("palette_id", "").replace("_", " ").capitalize()
	var desc: String = cur_skin.get("description", "")

	if index_badge:
		index_badge.text = "[ ASPECTO: %02d / %02d ]" % [current_index + 1, total_count]

	if name_label:
		name_label.text = sname.to_upper()
		name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2) if is_unlocked else Color(0.6, 0.65, 0.75))

	if title_label:
		var star_str := ""
		for s in range(stars):
			star_str += "★"
		title_label.text = "[%s %d★ | Paleta: %s]" % [star_str, stars, pal_name]

	if status_badge:
		if is_equipped:
			status_badge.text = "[✓ EQUIPADO]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_badge.text = "[DESBLOQUEADO]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			status_badge.text = "[🔒 GACHA]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if radio_dialogue:
		radio_dialogue.text = desc

	if radar_desc:
		radar_desc.text = "Personalización de telemetría y comunicaciones tácticas."

	if buff_desc_label:
		buff_desc_label.text = "Aura holográfica y destellos estelares para la navegante."

	if select_btn:
		select_btn.disabled = not is_unlocked
		if is_equipped:
			select_btn.text = "✓ DESEQUIPAR ASPECTO"
			select_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		elif is_unlocked:
			select_btn.text = "★ EQUIPAR ESTE ASPECTO"
			select_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		else:
			select_btn.text = "🔒 BLOQUEADO EN GACHA"
			select_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
