class_name PetDossierController
extends RefCounted

## PetDossierController.gd
## Controlador modular del dossier de información de compañeros astrales para PetSelectionModal.
## Gestiona nombres, títulos, estado de sintonización/equipamiento, biografía, poderes pasivos
## y el botón de selección/equipamiento tanto para mascotas como para sus skins.

const PetDataScript = preload("res://data/pets/pet_data.gd")

var index_badge: Label = null
var name_label: Label = null
var title_label: Label = null
var status_badge: Label = null
var bio_desc: Label = null
var power_card: PanelContainer = null
var power_desc: Label = null
var select_btn: Button = null


func setup(
	p_index_badge: Label,
	p_name_lbl: Label,
	p_title_lbl: Label,
	p_status_badge: Label,
	p_bio_desc: Label,
	p_power_card: PanelContainer,
	p_power_desc: Label,
	p_select_btn: Button
) -> void:
	index_badge = p_index_badge
	name_label = p_name_lbl
	title_label = p_title_lbl
	status_badge = p_status_badge
	bio_desc = p_bio_desc
	power_card = p_power_card
	power_desc = p_power_desc
	select_btn = p_select_btn


func display_pet(
	pet_data: PetDataScript,
	is_unlocked: bool,
	is_selected: bool,
	current_index: int,
	total_count: int
) -> void:
	if not pet_data:
		return

	if index_badge:
		index_badge.text = "[ %02d / %02d ]" % [current_index + 1, total_count]

	if name_label:
		name_label.text = pet_data.display_name.to_upper()
		name_label.add_theme_color_override("font_color", pet_data.theme_color if is_unlocked else Color(0.6, 0.65, 0.75))

	if title_label:
		title_label.text = "— " + pet_data.title.to_upper()

	if status_badge:
		if is_selected:
			status_badge.text = "[✓ EQUIPADO]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_badge.text = "[DISPONIBLE]"
			status_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
		else:
			status_badge.text = "[🔒 BLOQUEADO (10 MIN)]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if bio_desc:
		bio_desc.text = pet_data.description if is_unlocked else "Mascota astral bloqueada. Requiere sintonización."
	if power_desc:
		power_desc.text = pet_data.power_description if is_unlocked else "Sobrevive 10 minutos para desbloquear."

	if select_btn:
		select_btn.disabled = not is_unlocked
		if is_selected:
			select_btn.text = "✓ EQUIPADO (SELECCIONADA)"
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		elif is_unlocked:
			select_btn.text = "⚡ EQUIPAR MASCOTA [ESPACIO]"
			select_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.85))
		else:
			select_btn.text = "🔒 MASCOTA BLOQUEADA"
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

	if bio_desc:
		bio_desc.text = desc
	if power_desc:
		power_desc.text = "Personalización cosmética. Al subir de nivel en el Gacha desbloquea auras de plasma y destellos estelares."

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
