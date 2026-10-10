class_name SectorDossierPresenter
extends RefCounted

## SectorDossierPresenter.gd
## Presentador desacoplado para volcar los metadatos de SectorData
## en los paneles de dossier, modificadores, recompensa e inteligencia del rival.

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_CYAN := Color("#00F0FF")
const COLOR_EMERALD := Color("#00FF9D")
const COLOR_DARK_MATTER := Color("#BF00FF")
const COLOR_AMBER := Color("#FFB700")

static func update_dossier_identity(
	sector: SectorData,
	is_unlocked: bool,
	is_selected: bool,
	sector_name_label: Label,
	title_label: Label,
	status_badge: Label,
	desc_label: Label,
	animate: bool
) -> void:
	var theme_col: Color = sector.theme_color
	if sector_name_label:
		sector_name_label.text = sector.display_name.to_upper()
		sector_name_label.add_theme_color_override("font_color", theme_col if is_unlocked else Color(0.6, 0.65, 0.75))
		if animate:
			sector_name_label.pivot_offset = Vector2(0, sector_name_label.size.y * 0.5)
			var tw_name := sector_name_label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_name.tween_property(sector_name_label, "scale", Vector2(1.08, 1.08), 0.06)
			tw_name.tween_property(sector_name_label, "scale", Vector2.ONE, 0.12)

	if title_label:
		title_label.text = sector.title.to_upper()

	if status_badge:
		if is_selected:
			status_badge.text = "[✓ RUTA ACTIVA]"
			status_badge.add_theme_color_override("font_color", COLOR_EMERALD)
		elif is_unlocked:
			status_badge.text = "[DISPONIBLE]"
			status_badge.add_theme_color_override("font_color", COLOR_CYAN)
		else:
			status_badge.text = "[🔒 BLOQUEADO]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if desc_label:
		desc_label.text = sector.description


static func update_modifiers_grid(
	sector: SectorData,
	density_val: Label,
	biomass_val: Label,
	dark_matter_val: Label,
	credits_val: Label,
	arcana_val: Label,
	hazard_val: Label,
	hazard_warning: Label
) -> void:
	if density_val:
		density_val.text = "x%.2f" % sector.enemy_density_mult
		density_val.add_theme_color_override("font_color", COLOR_HOT_PINK if sector.enemy_density_mult > 1.2 else COLOR_CYAN)
	if biomass_val:
		biomass_val.text = "+%.0f%%" % ((sector.biomass_mult - 1.0) * 100.0) if sector.biomass_mult != 1.0 else "Estándar (1.0x)"
		biomass_val.add_theme_color_override("font_color", COLOR_EMERALD)
	if dark_matter_val:
		dark_matter_val.text = "+%.0f%%" % ((sector.dark_matter_mult - 1.0) * 100.0) if sector.dark_matter_mult != 1.0 else "Estándar (1.0x)"
		dark_matter_val.add_theme_color_override("font_color", COLOR_DARK_MATTER)
	if credits_val:
		credits_val.text = "+%.0f%%" % ((sector.credits_mult - 1.0) * 100.0) if sector.credits_mult != 1.0 else "Estándar (1.0x)"
		credits_val.add_theme_color_override("font_color", COLOR_AMBER)
	if arcana_val:
		arcana_val.text = "+%.0f%%" % ((sector.arcana_chance_mult - 1.0) * 100.0) if sector.arcana_chance_mult != 1.0 else "Normal (1.0x)"
		arcana_val.add_theme_color_override("font_color", COLOR_CYAN)
	if hazard_val:
		hazard_val.text = "Alerta Rival Nv. %d" % sector.rival_encounter_wave
	if hazard_warning:
		hazard_warning.text = sector.rival_warning_subtitle


static func update_rival_and_rewards(
	sector: SectorData,
	rival_name: Label,
	rival_wave_alert: Label,
	rival_portrait: TextureRect,
	currencies_label: Label
) -> void:
	if rival_name:
		rival_name.text = String(sector.rival_pilot_id).to_upper()
	if rival_wave_alert:
		rival_wave_alert.text = "Intercepción programada: Oleada %d" % sector.rival_encounter_wave

	if rival_portrait:
		var roster := CharacterData.load_roster()
		var rival_char: CharacterData = roster.get(sector.rival_pilot_id, null)
		if rival_char and rival_char.has_method("get_portrait_texture"):
			rival_portrait.texture = rival_char.get_portrait_texture()
		elif rival_char and rival_char.portrait_texture:
			rival_portrait.texture = rival_char.portrait_texture

	if currencies_label:
		currencies_label.text = "+%d BioMasa | +%d Mat. Oscura | +%d Antimateria" % [
			sector.reward_biomass,
			sector.reward_dark_matter,
			sector.reward_antimatter
		]
