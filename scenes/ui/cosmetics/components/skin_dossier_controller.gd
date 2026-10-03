class_name SkinDossierController
extends RefCounted

## SkinDossierController.gd
## Controlador del dossier inferior y botones de acción (Equipar, Color Original, Gacha)
## para SkinSelectionModal.

var skin_name_label: Label = null
var palette_label: Label = null
var status_badge: Label = null
var desc_label: Label = null

var equip_btn: Button = null
var default_btn: Button = null
var gacha_btn: Button = null


func setup(
	p_name: Label,
	p_palette: Label,
	p_status: Label,
	p_desc: Label,
	p_equip: Button,
	p_default: Button,
	p_gacha: Button,
	p_on_equip: Callable,
	p_on_default: Callable,
	p_on_gacha: Callable
) -> void:
	skin_name_label = p_name
	palette_label = p_palette
	status_badge = p_status
	desc_label = p_desc
	equip_btn = p_equip
	default_btn = p_default
	gacha_btn = p_gacha

	if equip_btn:
		UIFocusHelper.apply_cyber_focus(equip_btn)
		equip_btn.pressed.connect(p_on_equip)
	if default_btn:
		UIFocusHelper.apply_cyber_focus(default_btn)
		default_btn.pressed.connect(p_on_default)
	if gacha_btn:
		UIFocusHelper.apply_cyber_focus(gacha_btn)
		gacha_btn.pressed.connect(p_on_gacha)


func update_dossier(
	cur_skin: Dictionary,
	is_unlocked: bool,
	is_equipped: bool,
	has_any_equipped: bool
) -> void:
	var sname: String = cur_skin.get("skin_name", "Aspecto")
	var pal_name: String = cur_skin.get("palette_id", "").replace("_", " ").capitalize()
	var desc: String = cur_skin.get("description", "")
	var rarity: String = cur_skin.get("rarity", "common").to_upper()

	if skin_name_label:
		skin_name_label.text = sname
	if palette_label:
		palette_label.text = "[Paleta: %s | Rareza: %s]" % [pal_name, rarity]
	if desc_label:
		desc_label.text = desc

	if not status_badge or not equip_btn:
		return

	if is_equipped:
		status_badge.text = "✓ EQUIPADO"
		status_badge.modulate = Color(0.2, 1.0, 0.4)
		equip_btn.text = "✓ EQUIPADO (CLIC PARA DESEQUIPAR)"
		equip_btn.disabled = false
		equip_btn.modulate = Color(0.3, 1.0, 0.5)
	elif is_unlocked:
		status_badge.text = "DESBLOQUEADO"
		status_badge.modulate = Color(0.2, 0.9, 1.0)
		equip_btn.text = "★ EQUIPAR ASPECTO"
		equip_btn.disabled = false
		equip_btn.modulate = Color(1.0, 1.0, 1.0)
	else:
		status_badge.text = "🔒 BLOQUEADO"
		status_badge.modulate = Color(1.0, 0.4, 0.4)
		equip_btn.text = "🔒 BLOQUEADO EN GACHA"
		equip_btn.disabled = true
		equip_btn.modulate = Color(0.6, 0.6, 0.6)

	if default_btn:
		default_btn.disabled = not has_any_equipped


func show_empty_state() -> void:
	if skin_name_label:
		skin_name_label.text = "SIN ASPECTOS"
	if palette_label:
		palette_label.text = ""
	if desc_label:
		desc_label.text = "No hay aspectos disponibles para esta categoría."
	if equip_btn:
		equip_btn.disabled = true
	if default_btn:
		default_btn.disabled = true
