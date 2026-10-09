class_name CharacterSelectDisplayManager
extends RefCounted

## Administrador desacoplado para la presentación visual, telemetría y textos tácticos en CharacterSelect.

var name_label: Label = null
var title_label: Label = null
var biomass_label: Label = null
var antimatter_label: Label = null
var dark_matter_label: Label = null
var expand_talents_btn: Button = null
var talents_metrics_label: Label = null
var loadout_button: Button = null
var orbital_terminal: OrbitalIgnitionTerminal = null

var weapon_block_icon: TextureRect = null
var weapon_block_tag: Label = null
var weapon_block_title: Label = null
var weapon_block_desc: Label = null

var tactical_block_icon: TextureRect = null
var tactical_block_tag: Label = null
var tactical_block_title: Label = null
var tactical_block_desc: Label = null

var dash_block_icon: TextureRect = null
var dash_block_tag: Label = null
var dash_block_title: Label = null
var dash_block_desc: Label = null

var passive_block_icon: TextureRect = null
var passive_block_tag: Label = null
var passive_block_title: Label = null
var passive_block_desc: Label = null
var favored_tome_desc: Label = null


func setup_identity_and_telemetry(
	p_name_lbl: Label,
	p_title_lbl: Label,
	p_bio_lbl: Label,
	p_anti_lbl: Label,
	p_dark_lbl: Label,
	p_expand_btn: Button,
	p_talents_metrics: Label,
	p_loadout_btn: Button,
	p_terminal: OrbitalIgnitionTerminal
) -> void:
	name_label = p_name_lbl
	title_label = p_title_lbl
	biomass_label = p_bio_lbl
	antimatter_label = p_anti_lbl
	dark_matter_label = p_dark_lbl
	expand_talents_btn = p_expand_btn
	talents_metrics_label = p_talents_metrics
	loadout_button = p_loadout_btn
	orbital_terminal = p_terminal


func setup_abilities_blocks(
	w_icon: TextureRect, w_tag: Label, w_title: Label, w_desc: Label,
	t_icon: TextureRect, t_tag: Label, t_title: Label, t_desc: Label,
	d_icon: TextureRect, d_tag: Label, d_title: Label, d_desc: Label,
	p_icon: TextureRect, p_tag: Label, p_title: Label, p_desc: Label,
	f_desc: Label = null
) -> void:
	weapon_block_icon = w_icon
	weapon_block_tag = w_tag
	weapon_block_title = w_title
	weapon_block_desc = w_desc

	tactical_block_icon = t_icon
	tactical_block_tag = t_tag
	tactical_block_title = t_title
	tactical_block_desc = t_desc

	dash_block_icon = d_icon
	dash_block_tag = d_tag
	dash_block_title = d_title
	dash_block_desc = d_desc

	passive_block_icon = p_icon
	passive_block_tag = p_tag
	passive_block_title = p_title
	passive_block_desc = p_desc
	favored_tome_desc = f_desc


func get_action_key_text(act: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(act)
	for ev: InputEvent in events:
		if ev is InputEventKey:
			var txt: String = ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
			return txt.to_upper()
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "CLIC IZQ"
				MOUSE_BUTTON_RIGHT: return "CLIC DER"
				MOUSE_BUTTON_MIDDLE: return "CLIC CEN"
				_: return "RATÓN %d" % ev.button_index
	return "N/A"


func update_ability_tags() -> void:
	if weapon_block_tag:
		weapon_block_tag.text = "[AUTO / PASIVO] // ARMA PRINCIPAL"
	if tactical_block_tag:
		tactical_block_tag.text = "[%s] // HABILIDAD TÁCTICA" % get_action_key_text(&"fire_active")
	if dash_block_tag:
		dash_block_tag.text = "[%s] // PROPULSIÓN EVASIVA" % get_action_key_text(&"dash")
	if passive_block_tag:
		passive_block_tag.text = "[INNATA] // AFINIDAD DE TOMO"


func refresh_telemetry_ui() -> void:
	if biomass_label:
		biomass_label.text = "BIOMASA: %s" % String.num_int64(SaveManager.get_biomass())
	if antimatter_label:
		antimatter_label.text = "ANTIMATERIA: %s" % String.num_int64(SaveManager.get_antimatter())
	if dark_matter_label:
		dark_matter_label.text = "MATERIA OSCURA: %s" % String.num_int64(SaveManager.get_dark_matter())


func refresh_talents_summary(char_id: StringName) -> void:
	var unlocked_nodes: Array = SaveManager.get_character_unlocked_nodes(char_id)
	if expand_talents_btn:
		expand_talents_btn.text = "[ÁRBOL DE TALENTOS] (%d/24)" % unlocked_nodes.size()
	if talents_metrics_label:
		talents_metrics_label.text = "NODOS ACTIVOS: %d / 24 | BIOMASA DISPONIBLE: %s" % [
			unlocked_nodes.size(),
			String.num_int64(SaveManager.get_biomass())
		]


func update_character_identity(data: CharacterData) -> void:
	if not data:
		return
	if name_label:
		name_label.text = data.display_name.to_upper()
		name_label.modulate = data.color
	if title_label:
		title_label.text = data.title


func update_character_abilities(data: CharacterData) -> void:
	if not data:
		return
	var kit: Dictionary = data.get_kit_dossier() if data.has_method("get_kit_dossier") else {}
	if not kit.is_empty():
		if weapon_block_title:
			weapon_block_title.text = kit.get("weapon_name", "")
		if weapon_block_desc:
			weapon_block_desc.text = kit.get("weapon_desc", "")
		if tactical_block_title:
			tactical_block_title.text = kit.get("tactical_name", "")
		if tactical_block_desc:
			tactical_block_desc.text = kit.get("tactical_desc", "")
		if dash_block_title:
			dash_block_title.text = kit.get("dash_name", "")
		if dash_block_desc:
			dash_block_desc.text = kit.get("dash_desc", "")
		if passive_block_title:
			passive_block_title.text = kit.get("passive_name", "")
		if passive_block_desc:
			passive_block_desc.text = kit.get("passive_desc", "")
		if favored_tome_desc:
			var f_tome: StringName = kit.get("favored_tome", &"")
			var p_desc: String = kit.get("passive_desc", "")
			favored_tome_desc.text = "%s — Sinergia: %s" % [String(f_tome), p_desc]

	if weapon_block_icon:
		weapon_block_icon.texture = data.get_weapon_skill_texture()
	if tactical_block_icon:
		tactical_block_icon.texture = data.get_tactical_texture()
	if dash_block_icon:
		dash_block_icon.texture = data.get_dash_texture()
	if passive_block_icon:
		passive_block_icon.texture = data.get_passive_texture()


func update_terminal_lock_state(is_unlocked: bool) -> void:
	if not is_unlocked:
		if orbital_terminal:
			orbital_terminal.focus_mode = Control.FOCUS_NONE
			orbital_terminal.active_telemetry_text = "/// PILOTO BLOQUEADA // REQUIERE AUTORIZACIÓN DE FLOTA /// PROTOCOLO RESTRINGIDO /// "
			orbital_terminal._update_telemetry_metrics()
		if loadout_button:
			loadout_button.disabled = true
	else:
		if orbital_terminal:
			orbital_terminal.focus_mode = Control.FOCUS_ALL
			orbital_terminal.active_telemetry_text = OrbitalIgnitionTerminal.BASE_TELEMETRY
			orbital_terminal._update_telemetry_metrics()
		if loadout_button:
			loadout_button.disabled = false


func update_dock_highlights(
	current_char_id: StringName,
	dock_card_buttons: Dictionary[StringName, Button],
	roster_dict: Dictionary[StringName, CharacterData]
) -> void:
	for cid: StringName in dock_card_buttons.keys():
		var btn: Button = dock_card_buttons[cid]
		if not is_instance_valid(btn):
			continue
		var is_current: bool = (cid == current_char_id)
		var c_data: CharacterData = roster_dict.get(cid, null)
		var c_unlocked: bool = SaveManager.is_character_unlocked(cid)
		var sb: StyleBox = btn.get_theme_stylebox("normal")
		if sb is StyleBoxFlat:
			var dup: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
			dup.border_width_left = 2
			dup.border_width_top = 2
			dup.border_width_right = 2
			dup.border_width_bottom = 2
			if is_current:
				dup.border_color = c_data.color if c_data else Color(0, 1, 0.85, 1)
				dup.bg_color = Color(0.04, 0.08, 0.12, 0.96)
				dup.shadow_color = (c_data.color * Color(1, 1, 1, 0.4)) if c_data else Color(0, 0.8, 1, 0.3)
				dup.shadow_size = 6
			else:
				dup.border_color = (c_data.color * Color(1, 1, 1, 0.4) if c_unlocked else Color(0.2, 0.25, 0.3, 0.5)) if c_data else Color(0.2, 0.4, 0.6, 0.5)
				dup.bg_color = Color(0.025, 0.04, 0.07, 0.92)
				dup.shadow_size = 0
			btn.add_theme_stylebox_override("normal", dup)
			var hover_dup: StyleBoxFlat = dup.duplicate() as StyleBoxFlat
			if not is_current and c_data:
				hover_dup.border_color = c_data.color * Color(1, 1, 1, 0.85)
				hover_dup.bg_color = Color(0.035, 0.065, 0.1, 0.95)
			btn.add_theme_stylebox_override("hover", hover_dup)
			btn.add_theme_stylebox_override("pressed", dup)
