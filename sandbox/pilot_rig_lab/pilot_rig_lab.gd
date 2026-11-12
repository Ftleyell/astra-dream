extends Control

const ASSETS_DIR: String = "res://sandbox/pilot_rig_lab/assets"
const PILOTS_ROOT_DIR: String = "res://sandbox/pilot_rig_lab/pilots"
const PRESET_SAVE_PATH: String = "res://sandbox/pilot_rig_lab/rig_offsets_saved.json"
const PROFILES_SAVE_PATH: String = "res://sandbox/pilot_rig_lab/saved_style_profiles.json"
const SHADER_PATH: String = "res://sandbox/pilot_rig_lab/pilot_rig_stylizer.gdshader"

const LAYER_ORDER: Array[String] = [
	"wings",
	"cape",
	"hips_legs",
	"arm_left_straight",
	"torso",
	"bust",
	"head",
	"arm_right_bent"
]

const PIVOT_RATIOS: Dictionary = {
	"wings": Vector2(0.50, 0.45),
	"cape": Vector2(0.45, 0.08),
	"hips_legs": Vector2(0.50, 0.14),
	"arm_left_straight": Vector2(0.20, 0.10),
	"torso": Vector2(0.50, 0.84),
	"bust": Vector2(0.50, 0.25),
	"head": Vector2(0.50, 0.88),
	"arm_right_bent": Vector2(0.68, 0.15)
}

const PIPELINE_NAMES: Array[String] = [
	"Perfil 0: Original Upscayl 4x (Referencia Pura)",
	"Perfil 1: Studio Trigger Clean Cel (Sin Trama)",
	"Perfil 2: Skullgirls Screentone (Semitono en Sombras)",
	"Perfil 3: Guilty Gear / Hades (Rim-Light + Cel Duro)",
	"Perfil 4: Spider-Verse / Hi-Fi Rush (Doble Trama Luz/Sombra)",
	"Perfil 5: Persona 5 / Gurren Lagann (Graphic Noir Ink)",
	"Perfil 6: Cyberpunk Edgerunners (Doble Rim Cian + Acento)",
	"Perfil 7: Kill la Kill / Promare (Rayado Manga Diagonal)",
	"Perfil 8: Arcane / Nikke (Especular Metálico + Subsurface)"
]

# Valores de fábrica (Factory Defaults) de cada uno de los 9 Perfiles de Identidad Visual
const FACTORY_PROFILES: Array[Dictionary] = [
	{ # 0: Original Upscayl 4x
		"pipeline_mode": 0, "enable_halftone": false, "halftone_pattern_type": 0, "halftone_zone_mode": 0,
		"halftone_scale": 165.0, "halftone_strength": 0.0, "halftone_angle_deg": 45.0, "halftone_threshold": 0.38,
		"ink_boost": 0.10, "cel_step_strength": 0.0, "noir_shadow_crush": 0.0, "noir_shadow_threshold": 0.24,
		"metal_sheen_strength": 0.0, "rim_light_strength": 0.12, "rim_width_px": 4.5, "dual_rim_strength": 0.0, "glow_intensity": 1.05
	},
	{ # 1: Studio Trigger Clean Cel
		"pipeline_mode": 1, "enable_halftone": false, "halftone_pattern_type": 0, "halftone_zone_mode": 0,
		"halftone_scale": 165.0, "halftone_strength": 0.0, "halftone_angle_deg": 45.0, "halftone_threshold": 0.38,
		"ink_boost": 0.25, "cel_step_strength": 0.35, "noir_shadow_crush": 0.0, "noir_shadow_threshold": 0.24,
		"metal_sheen_strength": 0.0, "rim_light_strength": 0.32, "rim_width_px": 5.0, "dual_rim_strength": 0.0, "glow_intensity": 1.25
	},
	{ # 2: Skullgirls Screentone
		"pipeline_mode": 2, "enable_halftone": true, "halftone_pattern_type": 0, "halftone_zone_mode": 0,
		"halftone_scale": 165.0, "halftone_strength": 0.42, "halftone_angle_deg": 45.0, "halftone_threshold": 0.38,
		"ink_boost": 0.38, "cel_step_strength": 0.15, "noir_shadow_crush": 0.0, "noir_shadow_threshold": 0.24,
		"metal_sheen_strength": 0.0, "rim_light_strength": 0.30, "rim_width_px": 5.0, "dual_rim_strength": 0.0, "glow_intensity": 1.25
	},
	{ # 3: Guilty Gear / Hades Rim-Lit
		"pipeline_mode": 3, "enable_halftone": false, "halftone_pattern_type": 0, "halftone_zone_mode": 0,
		"halftone_scale": 165.0, "halftone_strength": 0.25, "halftone_angle_deg": 45.0, "halftone_threshold": 0.38,
		"ink_boost": 0.32, "cel_step_strength": 0.72, "noir_shadow_crush": 0.15, "noir_shadow_threshold": 0.22,
		"metal_sheen_strength": 0.20, "rim_light_strength": 0.78, "rim_width_px": 5.5, "dual_rim_strength": 0.0, "glow_intensity": 1.35
	},
	{ # 4: Spider-Verse / Hi-Fi Rush Dual-Tone
		"pipeline_mode": 4, "enable_halftone": true, "halftone_pattern_type": 0, "halftone_zone_mode": 3,
		"halftone_scale": 155.0, "halftone_strength": 0.46, "halftone_angle_deg": 45.0, "halftone_threshold": 0.38,
		"ink_boost": 0.42, "cel_step_strength": 0.30, "noir_shadow_crush": 0.0, "noir_shadow_threshold": 0.24,
		"metal_sheen_strength": 0.0, "rim_light_strength": 0.42, "rim_width_px": 5.0, "dual_rim_strength": 0.25, "glow_intensity": 1.35
	},
	{ # 5: Persona 5 / Gurren Lagann Graphic Noir
		"pipeline_mode": 5, "enable_halftone": false, "halftone_pattern_type": 1, "halftone_zone_mode": 0,
		"halftone_scale": 170.0, "halftone_strength": 0.30, "halftone_angle_deg": 35.0, "halftone_threshold": 0.36,
		"ink_boost": 0.52, "cel_step_strength": 0.50, "noir_shadow_crush": 0.88, "noir_shadow_threshold": 0.24,
		"metal_sheen_strength": 0.0, "rim_light_strength": 0.45, "rim_width_px": 5.5, "dual_rim_strength": 0.0, "glow_intensity": 1.70
	},
	{ # 6: Cyberpunk Edgerunners Dual-Rim
		"pipeline_mode": 6, "enable_halftone": false, "halftone_pattern_type": 5, "halftone_zone_mode": 0,
		"halftone_scale": 190.0, "halftone_strength": 0.22, "halftone_angle_deg": 0.0, "halftone_threshold": 0.38,
		"ink_boost": 0.28, "cel_step_strength": 0.25, "noir_shadow_crush": 0.12, "noir_shadow_threshold": 0.22,
		"metal_sheen_strength": 0.35, "rim_light_strength": 0.88, "rim_width_px": 6.0, "dual_rim_strength": 0.85, "glow_intensity": 1.75
	},
	{ # 7: Kill la Kill / Promare Manga Hatch
		"pipeline_mode": 7, "enable_halftone": true, "halftone_pattern_type": 1, "halftone_zone_mode": 0,
		"halftone_scale": 175.0, "halftone_strength": 0.48, "halftone_angle_deg": 40.0, "halftone_threshold": 0.40,
		"ink_boost": 0.45, "cel_step_strength": 0.68, "noir_shadow_crush": 0.22, "noir_shadow_threshold": 0.22,
		"metal_sheen_strength": 0.0, "rim_light_strength": 0.40, "rim_width_px": 5.0, "dual_rim_strength": 0.0, "glow_intensity": 1.40
	},
	{ # 8: Arcane / Nikke Specular Metal
		"pipeline_mode": 8, "enable_halftone": false, "halftone_pattern_type": 3, "halftone_zone_mode": 0,
		"halftone_scale": 210.0, "halftone_strength": 0.18, "halftone_angle_deg": 45.0, "halftone_threshold": 0.36,
		"ink_boost": 0.22, "cel_step_strength": 0.0, "noir_shadow_crush": 0.0, "noir_shadow_threshold": 0.24,
		"metal_sheen_strength": 0.92, "rim_light_strength": 0.38, "rim_width_px": 4.5, "dual_rim_strength": 0.18, "glow_intensity": 1.35
	}
]

const RECOLOR_METHOD_NAMES: Array[String] = [
	"Método 0: Multiplicativo Clásico (Proporcional)",
	"Método 1: Gradiente 3-Tonos (Skullgirls: Sombra Fría -> Brillo Cálido)",
	"Método 2: Remapeo Perceptual HSL (Contraste Exacto)",
	"Método 3: Fusión Overlay / Hard-Light (Clip Studio)",
	"Método 4: Cel-Ramp Indexado 3-Bandas (Guilty Gear)"
]

const HAIR_STYLE_NAMES: Array[String] = [
	"Pelo 0: Sólido Cel-Shaded (Natural 2-Tonos)",
	"Pelo 1: Bicolor Trigger / Edgerunners (Sombra Teñida)",
	"Pelo 2: Puntas Teñidas / Dip-Dye (Degradado a Puntas)",
	"Pelo 3: Halo Especular Anime ('Angel Ring' + Sombra)"
]

const SKIN_ORDER: Array[String] = [
	"base",
	"crimson_nebula",
	"cyber_emerald",
	"solar_valkyrie",
	"void_amethyst",
	"arctic_phantom",
	"blood_eclipse",
	"eva_unit_01",
	"2b_yorha",
	"edgerunner_lucy"
]

const SKIN_PRESETS: Dictionary = {
	"base": {
		"label": "Skin 0: Base Original (Carmesí + Acero)",
		"accent": Color(0.86, 0.18, 0.32, 1.0),
		"panel": Color(0.36, 0.38, 0.44, 1.0),
		"suit_dark": Color(0.16, 0.15, 0.20, 1.0),
		"hair": Color(0.86, 0.88, 0.94, 1.0)
	},
	"crimson_nebula": {
		"label": "Skin 1: Nebulosa Carmesí (Rojo Láser + Obsidiana)",
		"accent": Color(1.0, 0.10, 0.32, 1.0),
		"panel": Color(0.28, 0.32, 0.42, 1.0),
		"suit_dark": Color(0.08, 0.08, 0.13, 1.0),
		"hair": Color(0.92, 0.94, 1.0, 1.0)
	},
	"cyber_emerald": {
		"label": "Skin 2: Esmeralda Ciber (Verde Neón + Titanio)",
		"accent": Color(0.0, 0.96, 0.58, 1.0),
		"panel": Color(0.20, 0.38, 0.36, 1.0),
		"suit_dark": Color(0.07, 0.14, 0.15, 1.0),
		"hair": Color(0.80, 0.98, 0.90, 1.0)
	},
	"solar_valkyrie": {
		"label": "Skin 3: Valquiria Solar (Oro + Marfil Real)",
		"accent": Color(1.0, 0.68, 0.08, 1.0),
		"panel": Color(0.76, 0.72, 0.64, 1.0),
		"suit_dark": Color(0.22, 0.15, 0.12, 1.0),
		"hair": Color(1.0, 0.92, 0.74, 1.0)
	},
	"void_amethyst": {
		"label": "Skin 4: Amatista del Vacío (Magenta + Índigo)",
		"accent": Color(0.88, 0.18, 1.0, 1.0),
		"panel": Color(0.36, 0.26, 0.52, 1.0),
		"suit_dark": Color(0.11, 0.07, 0.19, 1.0),
		"hair": Color(0.92, 0.80, 1.0, 1.0)
	},
	"arctic_phantom": {
		"label": "Skin 5: Fantasma Ártico (Cian + Blanco Crio)",
		"accent": Color(0.0, 0.90, 1.0, 1.0),
		"panel": Color(0.68, 0.78, 0.88, 1.0),
		"suit_dark": Color(0.10, 0.16, 0.24, 1.0),
		"hair": Color(0.86, 0.96, 1.0, 1.0)
	},
	"blood_eclipse": {
		"label": "Skin 6: Eclipse de Sangre (Armadura Negra + Rubí)",
		"accent": Color(1.0, 0.05, 0.18, 1.0),
		"panel": Color(0.17, 0.16, 0.20, 1.0),
		"suit_dark": Color(0.06, 0.05, 0.08, 1.0),
		"hair": Color(0.96, 0.82, 0.86, 1.0)
	},
	"eva_unit_01": {
		"label": "Skin 7: Mecha Unidad-01 (Violeta + Verde Ácido)",
		"accent": Color(0.22, 1.0, 0.12, 1.0),
		"panel": Color(0.44, 0.20, 0.68, 1.0),
		"suit_dark": Color(0.12, 0.08, 0.20, 1.0),
		"hair": Color(0.90, 0.86, 0.98, 1.0)
	},
	"2b_yorha": {
		"label": "Skin 8: Gótico Androide (Terciopelo Negro + Plata)",
		"accent": Color(0.90, 0.92, 0.96, 1.0),
		"panel": Color(0.24, 0.25, 0.29, 1.0),
		"suit_dark": Color(0.07, 0.07, 0.09, 1.0),
		"hair": Color(0.94, 0.95, 0.98, 1.0)
	},
	"edgerunner_lucy": {
		"label": "Skin 9: Night City Netrunner (Amarillo + Cian)",
		"accent": Color(1.0, 0.92, 0.05, 1.0),
		"panel": Color(0.16, 0.64, 0.78, 1.0),
		"suit_dark": Color(0.09, 0.11, 0.18, 1.0),
		"hair": Color(0.94, 0.90, 0.98, 1.0)
	}
}

const HAIR_PRESETS: Array[Dictionary] = [
	{"label": "Color Pelo 0: Original Plata Valentina", "override": false, "col": Color(0.86, 0.88, 0.94), "sec": Color(0.86, 0.18, 0.32)},
	{"label": "Color Pelo 1: Seguir Skin del Traje", "override": false, "col": Color(0.86, 0.88, 0.94), "sec": Color(0.86, 0.18, 0.32)},
	{"label": "Color Pelo 2: Blanco Platino Nier (2B)", "override": true, "col": Color(0.95, 0.96, 1.0), "sec": Color(0.20, 0.85, 1.0)},
	{"label": "Color Pelo 3: Rubio Dorado Valquiria", "override": true, "col": Color(1.0, 0.84, 0.32), "sec": Color(1.0, 0.28, 0.12)},
	{"label": "Color Pelo 4: Rosa Pastel Cyberpunk (Lucy)", "override": true, "col": Color(1.0, 0.48, 0.76), "sec": Color(0.0, 0.94, 1.0)},
	{"label": "Color Pelo 5: Rojo Escarlata Intenso", "override": true, "col": Color(0.95, 0.14, 0.26), "sec": Color(0.12, 0.08, 0.18)},
	{"label": "Color Pelo 6: Cian Eléctrico Holográfico", "override": true, "col": Color(0.12, 0.92, 1.0), "sec": Color(0.95, 0.14, 0.88)},
	{"label": "Color Pelo 7: Violeta Nebulosa Profundo", "override": true, "col": Color(0.64, 0.32, 0.98), "sec": Color(0.0, 0.96, 0.68)},
	{"label": "Color Pelo 8: Negro Azabache con Reflejo Azul", "override": true, "col": Color(0.18, 0.22, 0.34), "sec": Color(0.0, 0.84, 1.0)},
	{"label": "Color Pelo 9: Verde Esmeralda Tóxico", "override": true, "col": Color(0.18, 0.96, 0.52), "sec": Color(0.10, 0.22, 0.38)}
]

var rig_root: Node2D = null
var rig_clone_root: Node2D = null
var clone_part_sprites: Dictionary = {}
var clone_part_materials: Dictionary = {}

var ingame_pip_panel: PanelContainer = null
var ingame_pip_rig: Node2D = null
var ingame_bullets_node: Node2D = null
var pip_part_sprites: Dictionary = {}
var pip_part_materials: Dictionary = {}

var ghost_ref_sprite: Sprite2D = null
var bg_rect: ColorRect = null
var bg_canvas_node: Node2D = null
var current_bg_mode: int = 4 # Arranca en Blanco Puro (#FFFFFF) o seleccionable con 1 click
var custom_bg_color: Color = Color("#FFFFFF")

var part_sprites: Dictionary = {}
var part_materials: Dictionary = {}
var base_positions: Dictionary = {}
var user_offsets: Dictionary = {}
var wings_bloom_sprite: Sprite2D = null

var time_accum: float = 0.0
var anim_enabled: bool = true
var idle_preset_mode: int = 0
var breath_speed: float = 2.15
var breath_amp: float = 1.0
var hip_sway_amp: float = 1.0
var jiggle_gain: float = 1.25
var cape_wind_strength: float = 1.0
var use_seamless_elastic_bust: bool = true

var _prev_torso_y: float = 0.0
var _bust_disp: Vector2 = Vector2.ZERO
var _bust_vel: Vector2 = Vector2.ZERO

# Estado Activo del Perfil y Filtros
var current_profile_index: int = 2
var current_pipeline_mode: int = 2
var current_recolor_method: int = 1
var current_skin_id: String = "base"
var current_hair_preset_idx: int = 0
var current_hair_style_mode: int = 0
var debug_view_mode: int = 0

var active_accent_col: Color = Color(0.86, 0.18, 0.32, 1.0)
var active_panel_col: Color = Color(0.36, 0.38, 0.44, 1.0)
var active_suit_col: Color = Color(0.16, 0.15, 0.20, 1.0)
var active_hair_col: Color = Color(0.86, 0.88, 0.94, 1.0)
var active_hair_sec_col: Color = Color(0.86, 0.18, 0.32, 1.0)
var custom_colors_dirty: bool = false
var hair_override_active: bool = false

var lock_accent: bool = false
var lock_panel: bool = false
var lock_suit: bool = false
var lock_hair: bool = false
var harmony_mode: int = 0

# Parámetros Finos de Sección 1 (Filtro / Trama / Tinta / Rim)
var enable_halftone: bool = true
var halftone_pattern_type: int = 0
var halftone_zone_mode: int = 0
var halftone_scale: float = 165.0
var halftone_strength: float = 0.42
var halftone_angle_deg: float = 45.0
var halftone_threshold: float = 0.38

var ink_boost: float = 0.38
var cel_step_strength: float = 0.15
var noir_shadow_crush: float = 0.0
var noir_shadow_threshold: float = 0.24
var metal_sheen_strength: float = 0.0
var rim_light_strength: float = 0.30
var rim_width_px: float = 5.0
var dual_rim_strength: float = 0.0
var glow_intensity: float = 1.25

# Parámetros Finos de Sección 2 (Algoritmo de Recoloreo)
var recolor_contrast: float = 1.0
var recolor_highlight: float = 1.0
var recolor_saturation: float = 1.0
var stocking_tint_strength: float = 0.28

# Parámetros Finos de Sección 4 (Pelo)
var hair_effect_strength: float = 0.90
var hair_cut_height: float = 0.42
var hair_cut_softness: float = 0.14

# Perfiles Guardados y Comparador A/B
var custom_profiles: Array[Dictionary] = []
var snapshot_style_a: Dictionary = {}
var snapshot_style_b_temp: Dictionary = {}
var viewing_snapshot_a: bool = false
var split_compare_active: bool = false
var ingame_pip_active: bool = false

var edit_mode_enabled: bool = false
var selected_part_name: String = "torso"
var _dragging_part: bool = false
var _status_label: Label = null
var _compare_label_a: Label = null
var _compare_label_b: Label = null

# Referencias a controles UI para sincronizar al cargar un perfil o hacer Reset
var available_pilots: Array[Dictionary] = []
var current_pilot_id: String = "valentina"
var current_pilot_dir: String = ASSETS_DIR
var _pilot_opt: OptionButton = null

var _profile_opt: OptionButton = null
var _profile_name_edit: LineEdit = null
var _method_opt: OptionButton = null
var _skin_opt: OptionButton = null
var _hair_opt: OptionButton = null
var _hair_style_opt: OptionButton = null
var _ht_chk: CheckBox = null
var _pat_opt: OptionButton = null
var _zone_opt: OptionButton = null
var _ui_sliders: Dictionary = {}

var _picker_accent: ColorPickerButton = null
var _picker_panel: ColorPickerButton = null
var _picker_suit: ColorPickerButton = null
var _picker_hair: ColorPickerButton = null
var _picker_hair_sec: ColorPickerButton = null
var _picker_bg: ColorPickerButton = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_discover_available_pilots()
	_load_custom_profiles_from_disk()
	_sync_colors_from_preset(current_skin_id)
	_build_background_and_stage()
	_load_rig_parts()
	_build_ab_clone_rig()
	_build_ingame_pip_preview()
	_build_control_panel_ui()
	_build_top_art_director_bar()
	_load_profile_by_index(2)
	snapshot_style_a = _export_current_state_dict()
	_apply_Snapshot_to_clone_rig(snapshot_style_a)

func _discover_available_pilots() -> void:
	available_pilots.clear()
	available_pilots.append({"id": "valentina", "label": "Piloto: Valentina (Base R&D)", "dir": ASSETS_DIR})
	var abs_pilots: String = ProjectSettings.globalize_path(PILOTS_ROOT_DIR)
	if DirAccess.dir_exists_absolute(abs_pilots):
		var d: DirAccess = DirAccess.open(abs_pilots)
		if d:
			d.list_dir_begin()
			var fname: String = d.get_next()
			while fname != "":
				if d.current_is_dir() and not fname.begins_with("."):
					var sub_res: String = "%s/%s" % [PILOTS_ROOT_DIR, fname]
					if FileAccess.file_exists(ProjectSettings.globalize_path(sub_res + "/auto_matches.json")):
						available_pilots.append({
							"id": fname,
							"label": "Piloto: %s (sandbox/pilots)" % fname.capitalize(),
							"dir": sub_res
						})
				fname = d.get_next()
			d.list_dir_end()
	current_pilot_id = "valentina"
	current_pilot_dir = ASSETS_DIR

func _get_active_offsets_save_path() -> String:
	if current_pilot_id == "valentina":
		return PRESET_SAVE_PATH
	return "%s/rig_offsets_saved.json" % current_pilot_dir

func _switch_active_pilot(idx: int) -> void:
	if idx < 0 or idx >= available_pilots.size():
		return
	var entry: Dictionary = available_pilots[idx]
	current_pilot_id = String(entry["id"])
	current_pilot_dir = String(entry["dir"])
	_reload_rig_assets_in_place()
	_apply_pipeline_and_skin()
	if _status_label:
		_status_label.text = "✅ Piloto cambiada a '%s' (%s)." % [current_pilot_id, current_pilot_dir]

func _reload_rig_assets_in_place() -> void:
	var matches_path: String = ProjectSettings.globalize_path(current_pilot_dir + "/auto_matches.json")
	var matches_data: Dictionary = _parse_json_dict(matches_path)
	var saved_offsets_data: Dictionary = _parse_json_dict(ProjectSettings.globalize_path(_get_active_offsets_save_path()))

	if ghost_ref_sprite:
		var g_tex: Texture2D = _load_texture_direct(current_pilot_dir + "/reference_full.png")
		if not g_tex:
			g_tex = _load_texture_direct(current_pilot_dir + "/full_reference.png")
		ghost_ref_sprite.texture = g_tex

	for p_name: String in LAYER_ORDER:
		if not part_sprites.has(p_name):
			continue
		var spr: Sprite2D = part_sprites[p_name] as Sprite2D
		var tex: Texture2D = _load_texture_direct("%s/%s.png" % [current_pilot_dir, p_name])
		var mask_tex: Texture2D = _load_texture_direct("%s/%s_id_mask.png" % [current_pilot_dir, p_name])
		spr.texture = tex

		var ms_pos: Array = _extract_match_rect(matches_data, p_name)
		var m_pos: Vector2 = ms_pos[0] as Vector2
		var m_size: Vector2 = ms_pos[1] as Vector2
		spr.set_meta("matched_size", m_size)
		var pivot_ratio: Vector2 = PIVOT_RATIOS.get(p_name, Vector2(0.5, 0.5)) as Vector2
		if tex:
			spr.offset = -Vector2(float(tex.get_width()) * pivot_ratio.x, float(tex.get_height()) * pivot_ratio.y)
		var anchor_pos: Vector2 = m_pos + Vector2(m_size.x * pivot_ratio.x, m_size.y * pivot_ratio.y)
		spr.position = anchor_pos
		base_positions[p_name] = anchor_pos

		if saved_offsets_data.has(p_name):
			var u_arr: Array = saved_offsets_data[p_name] as Array
			user_offsets[p_name] = Vector2(float(u_arr[0]), float(u_arr[1]))
		else:
			user_offsets[p_name] = Vector2.ZERO

		var mat: ShaderMaterial = part_materials.get(p_name, null) as ShaderMaterial
		if mat and mask_tex:
			mat.set_shader_parameter("id_mask_tex", mask_tex)

		if clone_part_sprites.has(p_name):
			var cspr: Sprite2D = clone_part_sprites[p_name] as Sprite2D
			cspr.texture = tex
			cspr.set_meta("matched_size", m_size)
			var cmat: ShaderMaterial = clone_part_materials.get(p_name, null) as ShaderMaterial
			if cmat and mask_tex:
				cmat.set_shader_parameter("id_mask_tex", mask_tex)
		if pip_part_sprites.has(p_name):
			var pspr: Sprite2D = pip_part_sprites[p_name] as Sprite2D
			pspr.texture = tex
			pspr.set_meta("matched_size", m_size)

func _parse_json_dict(abs_path: String) -> Dictionary:
	if FileAccess.file_exists(abs_path):
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				return parsed as Dictionary
	return {}

func _extract_match_rect(matches_data: Dictionary, p_name: String) -> Array:
	var m_pos := Vector2(180.0, 180.0)
	var m_size := Vector2(100.0, 100.0)
	if matches_data.has(p_name):
		var entry: Variant = matches_data[p_name]
		if entry is Array:
			var arr: Array = entry as Array
			if arr.size() >= 5:
				m_pos = Vector2(float(arr[1]), float(arr[2]))
				m_size = Vector2(float(arr[3]), float(arr[4]))
		elif entry is Dictionary:
			var info: Dictionary = entry as Dictionary
			var mp: Array = info.get("match_pos", [180, 180]) as Array
			var ms: Array = info.get("matched_size", [100, 100]) as Array
			m_pos = Vector2(float(mp[0]), float(mp[1]))
			m_size = Vector2(float(ms[0]), float(ms[1]))
	return [m_pos, m_size]

func _load_custom_profiles_from_disk() -> void:
	custom_profiles.clear()
	var abs_p: String = ProjectSettings.globalize_path(PROFILES_SAVE_PATH)
	if FileAccess.file_exists(abs_p):
		var f := FileAccess.open(abs_p, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Array:
				for item: Variant in parsed:
					if item is Dictionary:
						custom_profiles.append(item as Dictionary)
			f.close()

func _save_custom_profiles_to_disk() -> void:
	var abs_p: String = ProjectSettings.globalize_path(PROFILES_SAVE_PATH)
	var f := FileAccess.open(abs_p, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(custom_profiles, "\t"))
		f.close()

func _get_total_profile_count() -> int:
	return FACTORY_PROFILES.size() + custom_profiles.size()

func _rebuild_profile_option_items() -> void:
	if not _profile_opt:
		return
	_profile_opt.clear()
	for i: int in range(PIPELINE_NAMES.size()):
		_profile_opt.add_item(PIPELINE_NAMES[i], i)
	for j: int in range(custom_profiles.size()):
		var cp: Dictionary = custom_profiles[j]
		var cname: String = String(cp.get("name", "Custom %d" % (j + 1)))
		_profile_opt.add_item("★ [Guardado] " + cname, FACTORY_PROFILES.size() + j)
	_profile_opt.selected = clampi(current_profile_index, 0, _get_total_profile_count() - 1)

func _load_profile_by_index(idx: int) -> void:
	current_profile_index = clampi(idx, 0, _get_total_profile_count() - 1)
	if current_profile_index < FACTORY_PROFILES.size():
		var fp: Dictionary = FACTORY_PROFILES[current_profile_index]
		_apply_filter_dict(fp)
	else:
		var c_idx: int = current_profile_index - FACTORY_PROFILES.size()
		var cp: Dictionary = custom_profiles[c_idx]
		_import_full_state_dict(cp)
	_sync_all_ui_controls()
	_apply_pipeline_and_skin()

func _reset_current_profile_to_default() -> void:
	var base_idx: int = current_pipeline_mode
	if current_profile_index < FACTORY_PROFILES.size():
		base_idx = current_profile_index
	var fp: Dictionary = FACTORY_PROFILES[clampi(base_idx, 0, FACTORY_PROFILES.size() - 1)]
	_apply_filter_dict(fp)
	_reset_recolor_section()
	_sync_all_ui_controls()
	_apply_pipeline_and_skin()
	if _status_label:
		_status_label.text = "↺ Perfil restaurado a sus valores de fábrica."

func _apply_filter_dict(d: Dictionary) -> void:
	current_pipeline_mode = int(d.get("pipeline_mode", current_pipeline_mode))
	enable_halftone = bool(d.get("enable_halftone", true))
	halftone_pattern_type = int(d.get("halftone_pattern_type", 0))
	halftone_zone_mode = int(d.get("halftone_zone_mode", 0))
	halftone_scale = float(d.get("halftone_scale", 165.0))
	halftone_strength = float(d.get("halftone_strength", 0.38))
	halftone_angle_deg = float(d.get("halftone_angle_deg", 45.0))
	halftone_threshold = float(d.get("halftone_threshold", 0.38))
	ink_boost = float(d.get("ink_boost", 0.28))
	cel_step_strength = float(d.get("cel_step_strength", 0.0))
	noir_shadow_crush = float(d.get("noir_shadow_crush", 0.0))
	noir_shadow_threshold = float(d.get("noir_shadow_threshold", 0.24))
	metal_sheen_strength = float(d.get("metal_sheen_strength", 0.0))
	rim_light_strength = float(d.get("rim_light_strength", 0.30))
	rim_width_px = float(d.get("rim_width_px", 5.0))
	dual_rim_strength = float(d.get("dual_rim_strength", 0.0))
	glow_intensity = float(d.get("glow_intensity", 1.25))

func _export_current_state_dict(custom_name: String = "") -> Dictionary:
	return {
		"name": custom_name,
		"pipeline_mode": current_pipeline_mode,
		"recolor_method": current_recolor_method,
		"skin_id": current_skin_id,
		"hair_preset_idx": current_hair_preset_idx,
		"hair_style_mode": current_hair_style_mode,
		"custom_colors_dirty": custom_colors_dirty,
		"hair_override_active": hair_override_active,
		"accent_col": active_accent_col.to_html(false),
		"panel_col": active_panel_col.to_html(false),
		"suit_col": active_suit_col.to_html(false),
		"hair_col": active_hair_col.to_html(false),
		"hair_sec_col": active_hair_sec_col.to_html(false),
		"enable_halftone": enable_halftone,
		"halftone_pattern_type": halftone_pattern_type,
		"halftone_zone_mode": halftone_zone_mode,
		"halftone_scale": halftone_scale,
		"halftone_strength": halftone_strength,
		"halftone_angle_deg": halftone_angle_deg,
		"halftone_threshold": halftone_threshold,
		"ink_boost": ink_boost,
		"cel_step_strength": cel_step_strength,
		"noir_shadow_crush": noir_shadow_crush,
		"noir_shadow_threshold": noir_shadow_threshold,
		"metal_sheen_strength": metal_sheen_strength,
		"rim_light_strength": rim_light_strength,
		"rim_width_px": rim_width_px,
		"dual_rim_strength": dual_rim_strength,
		"glow_intensity": glow_intensity,
		"recolor_contrast": recolor_contrast,
		"recolor_highlight": recolor_highlight,
		"recolor_saturation": recolor_saturation,
		"stocking_tint_strength": stocking_tint_strength,
		"hair_effect_strength": hair_effect_strength,
		"hair_cut_height": hair_cut_height,
		"hair_cut_softness": hair_cut_softness
	}

func _import_full_state_dict(d: Dictionary) -> void:
	_apply_filter_dict(d)
	current_recolor_method = int(d.get("recolor_method", 1))
	current_skin_id = String(d.get("skin_id", "base"))
	current_hair_preset_idx = int(d.get("hair_preset_idx", 0))
	current_hair_style_mode = int(d.get("hair_style_mode", 0))
	custom_colors_dirty = bool(d.get("custom_colors_dirty", false))
	hair_override_active = bool(d.get("hair_override_active", false))
	if d.has("accent_col"):
		active_accent_col = Color(String(d["accent_col"]))
	if d.has("panel_col"):
		active_panel_col = Color(String(d["panel_col"]))
	if d.has("suit_col"):
		active_suit_col = Color(String(d["suit_col"]))
	if d.has("hair_col"):
		active_hair_col = Color(String(d["hair_col"]))
	if d.has("hair_sec_col"):
		active_hair_sec_col = Color(String(d["hair_sec_col"]))
	recolor_contrast = float(d.get("recolor_contrast", 1.0))
	recolor_highlight = float(d.get("recolor_highlight", 1.0))
	recolor_saturation = float(d.get("recolor_saturation", 1.0))
	stocking_tint_strength = float(d.get("stocking_tint_strength", 0.28))
	hair_effect_strength = float(d.get("hair_effect_strength", 0.90))
	hair_cut_height = float(d.get("hair_cut_height", 0.42))
	hair_cut_softness = float(d.get("hair_cut_softness", 0.14))

func _reset_recolor_section() -> void:
	recolor_contrast = 1.0
	recolor_highlight = 1.0
	recolor_saturation = 1.0
	stocking_tint_strength = 0.28
	_sync_all_ui_controls()
	_apply_pipeline_and_skin()

func _reset_hair_section() -> void:
	hair_effect_strength = 0.90
	hair_cut_height = 0.42
	hair_cut_softness = 0.14
	_apply_hair_preset(0)
	_sync_all_ui_controls()

func _sync_colors_from_preset(skin_id: String) -> void:
	var cfg: Dictionary = SKIN_PRESETS.get(skin_id, SKIN_PRESETS["base"]) as Dictionary
	active_accent_col = cfg["accent"] as Color
	active_panel_col = cfg["panel"] as Color
	active_suit_col = cfg["suit_dark"] as Color
	if not hair_override_active:
		active_hair_col = cfg["hair"] as Color
		active_hair_sec_col = active_accent_col
	custom_colors_dirty = false
	_refresh_picker_buttons()

func _apply_hair_preset(idx: int) -> void:
	current_hair_preset_idx = idx
	var hp: Dictionary = HAIR_PRESETS[idx]
	hair_override_active = bool(hp["override"])
	if hair_override_active:
		active_hair_col = hp["col"] as Color
		active_hair_sec_col = hp["sec"] as Color
	else:
		var cfg: Dictionary = SKIN_PRESETS.get(current_skin_id, SKIN_PRESETS["base"]) as Dictionary
		active_hair_col = cfg["hair"] as Color
		active_hair_sec_col = active_accent_col
	_refresh_picker_buttons()
	_apply_pipeline_and_skin()

func _mutate_color_harmony() -> void:
	var base_h: float = randf()
	var h_panel: float = fmod(base_h + 0.08, 1.0)
	var h_suit: float = fmod(base_h + 0.52, 1.0)
	var h_hair: float = fmod(base_h + 0.33, 1.0)
	var h_hair_sec: float = base_h

	if harmony_mode == 1: # Tríada Armónica (120°)
		h_panel = fmod(base_h + 0.333, 1.0)
		h_suit = fmod(base_h + 0.666, 1.0)
	elif harmony_mode == 2: # Complementaria Dividida
		h_panel = fmod(base_h + 0.45, 1.0)
		h_suit = fmod(base_h + 0.55, 1.0)
	elif harmony_mode == 3: # Análoga
		h_panel = fmod(base_h + 0.07, 1.0)
		h_suit = fmod(base_h + 0.93, 1.0)

	if not lock_accent:
		active_accent_col = Color.from_hsv(base_h, randf_range(0.78, 1.0), randf_range(0.88, 1.0))
	if not lock_panel:
		active_panel_col = Color.from_hsv(h_panel, randf_range(0.22, 0.58), randf_range(0.32, 0.68))
	if not lock_suit:
		active_suit_col = Color.from_hsv(h_suit, randf_range(0.28, 0.55), randf_range(0.08, 0.22))
	if not lock_hair:
		active_hair_col = Color.from_hsv(h_hair, randf_range(0.15, 0.72), randf_range(0.75, 0.98))
		active_hair_sec_col = Color.from_hsv(h_hair_sec, randf_range(0.75, 0.98), randf_range(0.85, 1.0))
		hair_override_active = true

	custom_colors_dirty = true
	_refresh_picker_buttons()
	_apply_pipeline_and_skin()
	if _status_label:
		_status_label.text = "🎲 Armonía cromática generada (respetando canales con 🔒)."

func _refresh_picker_buttons() -> void:
	if _picker_accent:
		_picker_accent.color = active_accent_col
	if _picker_panel:
		_picker_panel.color = active_panel_col
	if _picker_suit:
		_picker_suit.color = active_suit_col
	if _picker_hair:
		_picker_hair.color = active_hair_col
	if _picker_hair_sec:
		_picker_hair_sec.color = active_hair_sec_col
	if _picker_bg:
		_picker_bg.color = custom_bg_color

func _sync_all_ui_controls() -> void:
	if _profile_opt:
		_profile_opt.selected = clampi(current_profile_index, 0, _get_total_profile_count() - 1)
	if _method_opt:
		_method_opt.selected = current_recolor_method
	if _skin_opt:
		var s_idx: int = SKIN_ORDER.find(current_skin_id)
		if s_idx >= 0:
			_skin_opt.selected = s_idx
	if _hair_opt:
		_hair_opt.selected = current_hair_preset_idx
	if _hair_style_opt:
		_hair_style_opt.selected = current_hair_style_mode
	if _ht_chk:
		_ht_chk.set_pressed_no_signal(enable_halftone)
	if _pat_opt:
		_pat_opt.selected = halftone_pattern_type
	if _zone_opt:
		_zone_opt.selected = halftone_zone_mode

	_set_slider_val("halftone_scale", halftone_scale)
	_set_slider_val("halftone_strength", halftone_strength)
	_set_slider_val("halftone_angle_deg", halftone_angle_deg)
	_set_slider_val("halftone_threshold", halftone_threshold)
	_set_slider_val("ink_boost", ink_boost)
	_set_slider_val("cel_step_strength", cel_step_strength)
	_set_slider_val("noir_shadow_crush", noir_shadow_crush)
	_set_slider_val("noir_shadow_threshold", noir_shadow_threshold)
	_set_slider_val("metal_sheen_strength", metal_sheen_strength)
	_set_slider_val("rim_light_strength", rim_light_strength)
	_set_slider_val("rim_width_px", rim_width_px)
	_set_slider_val("dual_rim_strength", dual_rim_strength)
	_set_slider_val("glow_intensity", glow_intensity)

	_set_slider_val("recolor_contrast", recolor_contrast)
	_set_slider_val("recolor_highlight", recolor_highlight)
	_set_slider_val("recolor_saturation", recolor_saturation)
	_set_slider_val("stocking_tint_strength", stocking_tint_strength)

	_set_slider_val("hair_effect_strength", hair_effect_strength)
	_set_slider_val("hair_cut_height", hair_cut_height)
	_set_slider_val("hair_cut_softness", hair_cut_softness)
	_refresh_picker_buttons()

func _set_slider_val(key: String, val: float) -> void:
	if not _ui_sliders.has(key):
		return
	var info: Dictionary = _ui_sliders[key] as Dictionary
	var sl: HSlider = info["slider"] as HSlider
	var lbl: Label = info["label"] as Label
	var title: String = String(info["title"])
	sl.set_value_no_signal(val)
	lbl.text = "%s: %.2f" % [title, val]

func _load_texture_direct(res_path: String) -> Texture2D:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		var tex: Texture2D = load(res_path) as Texture2D
		if tex:
			return tex
	return null

func _build_background_and_stage() -> void:
	bg_rect = ColorRect.new()
	bg_rect.name = "AbyssalBackground"
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	bg_canvas_node = Node2D.new()
	bg_canvas_node.name = "ContextBackdropNode"
	bg_canvas_node.draw.connect(_on_draw_context_backdrop)
	add_child(bg_canvas_node)

	rig_root = Node2D.new()
	rig_root.name = "ValentinaRigRoot"
	rig_root.position = Vector2(650.0, 96.0)
	rig_root.scale = Vector2(1.55, 1.55)
	add_child(rig_root)

	_set_backdrop_mode(current_bg_mode)

func _set_backdrop_mode(mode: int) -> void:
	current_bg_mode = mode
	if bg_rect:
		if mode == 4:
			custom_bg_color = Color("#FFFFFF")
			bg_rect.color = custom_bg_color
		elif mode == 5:
			custom_bg_color = Color("#D6DAE2")
			bg_rect.color = custom_bg_color
		elif mode == 6:
			bg_rect.color = custom_bg_color
		else:
			custom_bg_color = Color("#080812")
			bg_rect.color = custom_bg_color
	_refresh_picker_buttons()
	if bg_canvas_node:
		bg_canvas_node.queue_redraw()

func _on_draw_context_backdrop() -> void:
	if not bg_canvas_node:
		return
	var center := Vector2(885.0, 540.0)
	if current_bg_mode == 1:
		var grid_col := Color(0.0, 0.94, 1.0, 0.14)
		for i: int in range(-6, 7):
			var x_top: float = center.x + float(i) * 55.0
			var x_bot: float = center.x + float(i) * 145.0
			bg_canvas_node.draw_line(Vector2(x_top, 780.0), Vector2(x_bot, 1060.0), grid_col, 1.5)
		for j: int in range(0, 6):
			var y_line: float = 780.0 + float(j) * 52.0
			bg_canvas_node.draw_line(Vector2(450.0, y_line), Vector2(1420.0, y_line), grid_col, 1.5)
		bg_canvas_node.draw_arc(Vector2(center.x, 955.0), 175.0, 0.0, TAU, 64, Color(active_accent_col.r, active_accent_col.g, active_accent_col.b, 0.38), 3.0)
	elif current_bg_mode == 2:
		bg_canvas_node.draw_circle(Vector2(center.x, 460.0), 340.0, Color(0.08, 0.05, 0.16, 0.45))
		bg_canvas_node.draw_circle(Vector2(center.x - 90.0, 380.0), 210.0, Color(0.04, 0.11, 0.20, 0.35))
	elif current_bg_mode == 3:
		var poly := PackedVector2Array([
			Vector2(690.0, 65.0),
			Vector2(1140.0, 110.0),
			Vector2(1040.0, 995.0),
			Vector2(620.0, 960.0)
		])
		var panel_fill := Color(active_accent_col.r * 0.28, active_accent_col.g * 0.28, active_accent_col.b * 0.28, 0.85)
		bg_canvas_node.draw_colored_polygon(poly, panel_fill)
		var closed_poly := poly.duplicate()
		closed_poly.append(poly[0])
		bg_canvas_node.draw_polyline(closed_poly, active_accent_col, 4.0)

func _load_rig_parts() -> void:
	var matches_path: String = ProjectSettings.globalize_path(ASSETS_DIR + "/auto_matches.json")
	var matches_data: Dictionary = {}
	if FileAccess.file_exists(matches_path):
		var f := FileAccess.open(matches_path, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				matches_data = parsed
			f.close()

	var saved_offsets_path: String = ProjectSettings.globalize_path(PRESET_SAVE_PATH)
	var saved_offsets_data: Dictionary = {}
	if FileAccess.file_exists(saved_offsets_path):
		var fs := FileAccess.open(saved_offsets_path, FileAccess.READ)
		if fs:
			var p_off: Variant = JSON.parse_string(fs.get_as_text())
			if p_off is Dictionary:
				saved_offsets_data = p_off
			fs.close()

	ghost_ref_sprite = Sprite2D.new()
	ghost_ref_sprite.name = "GhostReferenceCol1"
	ghost_ref_sprite.centered = false
	var g_tex: Texture2D = _load_texture_direct(ASSETS_DIR + "/reference_full.png")
	if not g_tex:
		g_tex = _load_texture_direct(ASSETS_DIR + "/full_reference.png")
	ghost_ref_sprite.texture = g_tex
	ghost_ref_sprite.z_index = 25 # Proyectado POR ENCIMA de todas las piezas para calzar uniones
	ghost_ref_sprite.modulate = Color(0.20, 0.92, 1.0, 0.48)
	ghost_ref_sprite.visible = false
	rig_root.add_child(ghost_ref_sprite)

	var shader_res: Shader = load(SHADER_PATH) as Shader

	for i: int in range(LAYER_ORDER.size()):
		var p_name: String = LAYER_ORDER[i]
		var spr := Sprite2D.new()
		spr.name = "Part_" + p_name
		spr.centered = false
		spr.z_index = i
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

		var tex: Texture2D = _load_texture_direct("%s/%s.png" % [ASSETS_DIR, p_name])
		var mask_tex: Texture2D = _load_texture_direct("%s/%s_id_mask.png" % [ASSETS_DIR, p_name])
		spr.texture = tex

		var m_pos := Vector2(180.0, 180.0)
		var m_size := Vector2(100.0, 100.0)
		if matches_data.has(p_name):
			var entry: Variant = matches_data[p_name]
			if entry is Array:
				var arr: Array = entry as Array
				if arr.size() >= 5:
					m_pos = Vector2(float(arr[1]), float(arr[2]))
					m_size = Vector2(float(arr[3]), float(arr[4]))
			elif entry is Dictionary:
				var info: Dictionary = entry as Dictionary
				var mp: Array = info.get("match_pos", [180, 180]) as Array
				var ms: Array = info.get("matched_size", [100, 100]) as Array
				m_pos = Vector2(float(mp[0]), float(mp[1]))
				m_size = Vector2(float(ms[0]), float(ms[1]))

		spr.set_meta("matched_size", m_size)
		var pivot_ratio: Vector2 = PIVOT_RATIOS.get(p_name, Vector2(0.5, 0.5)) as Vector2
		if tex:
			spr.offset = -Vector2(float(tex.get_width()) * pivot_ratio.x, float(tex.get_height()) * pivot_ratio.y)

		var anchor_pos: Vector2 = m_pos + Vector2(m_size.x * pivot_ratio.x, m_size.y * pivot_ratio.y)
		spr.position = anchor_pos
		base_positions[p_name] = anchor_pos

		if saved_offsets_data.has(p_name):
			var u_arr: Array = saved_offsets_data[p_name] as Array
			user_offsets[p_name] = Vector2(float(u_arr[0]), float(u_arr[1]))
		else:
			user_offsets[p_name] = Vector2.ZERO

		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		if mask_tex:
			mat.set_shader_parameter("id_mask_tex", mask_tex)
		mat.set_shader_parameter("is_head_part", p_name == "head")
		mat.set_shader_parameter("is_cape_part", p_name == "cape")
		mat.set_shader_parameter("is_hips_legs_part", p_name == "hips_legs")
		mat.set_shader_parameter("is_torso_elastic_bust", p_name == "torso" and use_seamless_elastic_bust)
		spr.material = mat

		if p_name == "bust":
			spr.visible = not use_seamless_elastic_bust
		elif p_name == "wings":
			spr.visible = false

		rig_root.add_child(spr)
		part_sprites[p_name] = spr
		part_materials[p_name] = mat

		if p_name == "wings":
			wings_bloom_sprite = Sprite2D.new()
			wings_bloom_sprite.name = "WingsHologramBloom"
			wings_bloom_sprite.centered = false
			wings_bloom_sprite.texture = tex
			wings_bloom_sprite.offset = spr.offset
			wings_bloom_sprite.position = anchor_pos
			wings_bloom_sprite.z_index = -1
			var add_mat := CanvasItemMaterial.new()
			add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			wings_bloom_sprite.material = add_mat
			wings_bloom_sprite.modulate = Color(1.0, 0.12, 0.35, 0.38)
			wings_bloom_sprite.visible = false
			rig_root.add_child(wings_bloom_sprite)

func _build_ab_clone_rig() -> void:
	rig_clone_root = Node2D.new()
	rig_clone_root.name = "ValentinaCloneRigA"
	rig_clone_root.position = Vector2(980.0, 120.0)
	rig_clone_root.scale = Vector2(1.38, 1.38)
	rig_clone_root.visible = false
	add_child(rig_clone_root)

	var shader_res: Shader = load(SHADER_PATH) as Shader
	for i: int in range(LAYER_ORDER.size()):
		var p_name: String = LAYER_ORDER[i]
		var orig_spr: Sprite2D = part_sprites[p_name] as Sprite2D
		var spr := Sprite2D.new()
		spr.centered = false
		spr.z_index = i
		spr.texture = orig_spr.texture
		spr.offset = orig_spr.offset
		spr.position = orig_spr.position
		spr.set_meta("matched_size", orig_spr.get_meta("matched_size"))
		spr.visible = orig_spr.visible

		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		var orig_mat: ShaderMaterial = part_materials[p_name] as ShaderMaterial
		mat.set_shader_parameter("id_mask_tex", orig_mat.get_shader_parameter("id_mask_tex"))
		mat.set_shader_parameter("is_head_part", p_name == "head")
		mat.set_shader_parameter("is_cape_part", p_name == "cape")
		mat.set_shader_parameter("is_hips_legs_part", p_name == "hips_legs")
		mat.set_shader_parameter("is_torso_elastic_bust", p_name == "torso" and use_seamless_elastic_bust)
		spr.material = mat

		rig_clone_root.add_child(spr)
		clone_part_sprites[p_name] = spr
		clone_part_materials[p_name] = mat

	_compare_label_a = Label.new()
	_compare_label_a.text = "📌 ESTILO A (Referencia Fijada)"
	_compare_label_a.position = Vector2(1070.0, 90.0)
	_compare_label_a.add_theme_color_override("font_color", Color("#00F0FF"))
	_compare_label_a.add_theme_font_size_override("font_size", 14)
	_compare_label_a.visible = false
	add_child(_compare_label_a)

	_compare_label_b = Label.new()
	_compare_label_b.text = "✏️ ESTILO B (Editando en Vivo)"
	_compare_label_b.position = Vector2(610.0, 90.0)
	_compare_label_b.add_theme_color_override("font_color", Color("#FF1E56"))
	_compare_label_b.add_theme_font_size_override("font_size", 14)
	_compare_label_b.visible = false
	add_child(_compare_label_b)

func _build_ingame_pip_preview() -> void:
	ingame_pip_panel = PanelContainer.new()
	ingame_pip_panel.name = "InGameScalePip"
	ingame_pip_panel.position = Vector2(1490.0, 620.0)
	ingame_pip_panel.custom_minimum_size = Vector2(380.0, 380.0)
	ingame_pip_panel.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.03, 0.07, 0.96)
	st.border_color = Color("#00F0FF")
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	ingame_pip_panel.add_theme_stylebox_override("panel", st)
	add_child(ingame_pip_panel)

	var clip := Control.new()
	clip.clip_contents = true
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ingame_pip_panel.add_child(clip)

	var pip_title := Label.new()
	pip_title.text = "🎮 PREVIEW ESCALA IN-GAME (0.34x) + BALAS DANMAKU"
	pip_title.position = Vector2(12.0, 8.0)
	pip_title.add_theme_color_override("font_color", Color("#00F0FF"))
	pip_title.add_theme_font_size_override("font_size", 11)
	clip.add_child(pip_title)

	ingame_pip_rig = Node2D.new()
	ingame_pip_rig.position = Vector2(125.0, 85.0)
	ingame_pip_rig.scale = Vector2(0.42, 0.42)
	clip.add_child(ingame_pip_rig)

	for i: int in range(LAYER_ORDER.size()):
		var p_name: String = LAYER_ORDER[i]
		var orig_spr: Sprite2D = part_sprites[p_name] as Sprite2D
		var spr := Sprite2D.new()
		spr.centered = false
		spr.z_index = i
		spr.texture = orig_spr.texture
		spr.offset = orig_spr.offset
		spr.position = orig_spr.position
		spr.set_meta("matched_size", orig_spr.get_meta("matched_size"))
		spr.visible = orig_spr.visible
		spr.material = part_materials[p_name] # Comparte el ShaderMaterial en vivo
		ingame_pip_rig.add_child(spr)
		pip_part_sprites[p_name] = spr

	ingame_bullets_node = Node2D.new()
	ingame_bullets_node.draw.connect(_on_draw_pip_danmaku)
	clip.add_child(ingame_bullets_node)

func _on_draw_pip_danmaku() -> void:
	if not ingame_bullets_node or not ingame_pip_active:
		return
	var center := Vector2(190.0, 210.0)
	for i: int in range(14):
		var ang: float = time_accum * 1.8 + float(i) * (TAU / 14.0)
		var rad: float = 95.0 + 28.0 * sin(time_accum * 2.5 + float(i))
		var bpos: Vector2 = center + Vector2(cos(ang), sin(ang)) * rad
		var bcol: Color = Color(1.0, 0.15, 0.42, 0.95) if (i % 2 == 0) else Color(0.0, 0.95, 1.0, 0.95)
		ingame_bullets_node.draw_circle(bpos, 8.5, Color(bcol.r, bcol.g, bcol.b, 0.32))
		ingame_bullets_node.draw_circle(bpos, 5.2, bcol)
		ingame_bullets_node.draw_circle(bpos, 2.6, Color.WHITE)

func _process(delta: float) -> void:
	if not anim_enabled:
		_reset_to_rest_pose()
		return

	time_accum += delta * breath_speed
	var breath_wave: float = sin(time_accum)
	var half_time: float = time_accum * 0.55
	var sway_wave: float = sin(half_time)
	var sec_wave: float = cos(time_accum - 0.55)

	var leg_shift: float = sway_wave * clampf(hip_sway_amp, 0.0, 2.0)
	if part_materials.has("hips_legs"):
		var hips_mat: ShaderMaterial = part_materials["hips_legs"] as ShaderMaterial
		hips_mat.set_shader_parameter("leg_weight_shift", leg_shift)
	if clone_part_materials.has("hips_legs"):
		var chips_mat: ShaderMaterial = clone_part_materials["hips_legs"] as ShaderMaterial
		chips_mat.set_shader_parameter("leg_weight_shift", leg_shift)

	# Exact match with hips_legs shader waist UV shift (0.026 * 195px = 5.07px) so waist seam never separates
	var hip_shift_x: float = leg_shift * 5.05
	var hip_drop_y: float = absf(leg_shift) * 0.85
	var torso_sway_x: float = hip_shift_x
	var torso_breath_y: float = -breath_wave * 0.90 * breath_amp + hip_drop_y
	var torso_pos_offset := Vector2(torso_sway_x, torso_breath_y)
	var torso_rot: float = deg_to_rad(sway_wave * 1.15 * hip_sway_amp)
	var torso_sc := Vector2(1.0 + breath_wave * 0.012 * breath_amp, 1.0 + breath_wave * 0.016 * breath_amp)

	_apply_part_transform("hips_legs", Vector2.ZERO, 0.0, Vector2.ONE)
	_apply_part_transform("torso", torso_pos_offset, torso_rot, torso_sc)

	var torso_vel_y: float = (torso_breath_y - _prev_torso_y) / maxf(delta, 0.001)
	_prev_torso_y = torso_breath_y
	var impulse := Vector2(-sway_wave * 18.0 * hip_sway_amp, -torso_vel_y * 0.35)
	var spring_k: float = 135.0
	var damping: float = 7.8
	var accel: Vector2 = -spring_k * _bust_disp - damping * _bust_vel + impulse
	_bust_vel += accel * delta
	_bust_disp += _bust_vel * delta

	var phase_l: float = sin(time_accum - 0.42)
	var phase_r: float = sin(time_accum - 0.68)
	var uv_l := Vector2(
		clampf((_bust_disp.x * 0.0005 + sway_wave * 0.004 * hip_sway_amp) * jiggle_gain, -0.028, 0.028),
		clampf((_bust_disp.y * 0.0014 - phase_l * 0.011 * breath_amp) * jiggle_gain, -0.038, 0.038)
	)
	var uv_r := Vector2(
		clampf((_bust_disp.x * 0.0005 + sway_wave * 0.004 * hip_sway_amp) * jiggle_gain, -0.028, 0.028),
		clampf((_bust_disp.y * 0.0015 - phase_r * 0.012 * breath_amp) * jiggle_gain, -0.038, 0.038)
	)
	if part_materials.has("torso"):
		var torso_mat: ShaderMaterial = part_materials["torso"] as ShaderMaterial
		torso_mat.set_shader_parameter("bust_uv_disp_l", uv_l if use_seamless_elastic_bust else Vector2.ZERO)
		torso_mat.set_shader_parameter("bust_uv_disp_r", uv_r if use_seamless_elastic_bust else Vector2.ZERO)
	if clone_part_materials.has("torso"):
		var ctorso_mat: ShaderMaterial = clone_part_materials["torso"] as ShaderMaterial
		ctorso_mat.set_shader_parameter("bust_uv_disp_l", uv_l if use_seamless_elastic_bust else Vector2.ZERO)
		ctorso_mat.set_shader_parameter("bust_uv_disp_r", uv_r if use_seamless_elastic_bust else Vector2.ZERO)

	_apply_attached_to_torso("head", torso_pos_offset, torso_rot, torso_sc, Vector2(0.0, -sec_wave * 1.2 * breath_amp), deg_to_rad(-sway_wave * 1.15 * hip_sway_amp), Vector2.ONE)
	_apply_attached_to_torso("arm_right_bent", torso_pos_offset, torso_rot, torso_sc, Vector2(-breath_wave * 0.8 * breath_amp, -breath_wave * 0.6 * breath_amp), deg_to_rad(-breath_wave * 0.65 * breath_amp), Vector2.ONE)
	_apply_attached_to_torso("arm_left_straight", torso_pos_offset, torso_rot, torso_sc, Vector2(0.0, -sec_wave * 1.2 * breath_amp), deg_to_rad(sec_wave * 1.6 * breath_amp + sway_wave * 0.8 * hip_sway_amp), Vector2.ONE)
	_apply_attached_to_torso("cape", torso_pos_offset, torso_rot, torso_sc, Vector2.ZERO, deg_to_rad(sin(time_accum * 0.85) * 1.4 * cape_wind_strength), Vector2(1.0 + sin(time_accum * 1.3) * 0.018 * cape_wind_strength, 1.0))

	if ingame_pip_active and ingame_bullets_node:
		ingame_bullets_node.queue_redraw()

func _apply_attached_to_torso(p_name: String, torso_offset: Vector2, torso_rot: float, torso_sc: Vector2, local_offset: Vector2, local_rot: float, local_sc: Vector2) -> void:
	if not part_sprites.has(p_name) or not part_sprites.has("torso"):
		return
	var t_base: Vector2 = base_positions.get("torso", Vector2.ZERO) as Vector2
	var t_uoff: Vector2 = user_offsets.get("torso", Vector2.ZERO) as Vector2
	var torso_pivot_world: Vector2 = t_base + t_uoff + torso_offset

	var p_base: Vector2 = base_positions.get(p_name, Vector2.ZERO) as Vector2
	var p_uoff: Vector2 = user_offsets.get(p_name, Vector2.ZERO) as Vector2
	var rel_from_torso: Vector2 = (p_base + p_uoff) - (t_base + t_uoff)
	var rotated_rel: Vector2 = (rel_from_torso * torso_sc).rotated(torso_rot)
	var final_anchor: Vector2 = torso_pivot_world + rotated_rel + local_offset.rotated(torso_rot)
	var anim_offset: Vector2 = final_anchor - (p_base + p_uoff)
	var final_rot: float = torso_rot + local_rot
	var final_sc := Vector2(torso_sc.x * local_sc.x, torso_sc.y * local_sc.y)
	_apply_part_transform(p_name, anim_offset, final_rot, final_sc)

func _apply_part_transform(p_name: String, anim_offset: Vector2, rot_rad: float, sc: Vector2) -> void:
	if not part_sprites.has(p_name):
		return
	var spr: Sprite2D = part_sprites[p_name] as Sprite2D
	var b_pos: Vector2 = base_positions.get(p_name, Vector2.ZERO) as Vector2
	var u_off: Vector2 = user_offsets.get(p_name, Vector2.ZERO) as Vector2
	var tex_ratio := Vector2.ONE
	if spr.texture and spr.has_meta("matched_size"):
		var ms: Vector2 = spr.get_meta("matched_size") as Vector2
		var tw: float = maxf(1.0, float(spr.texture.get_width()))
		var th: float = maxf(1.0, float(spr.texture.get_height()))
		tex_ratio = Vector2(ms.x / tw, ms.y / th)
		var pr: Vector2 = PIVOT_RATIOS.get(p_name, Vector2(0.5, 0.5)) as Vector2
		spr.offset = -Vector2(tw * pr.x, th * pr.y)
	spr.position = b_pos + u_off + anim_offset
	spr.rotation = rot_rad
	spr.scale = Vector2(sc.x * tex_ratio.x, sc.y * tex_ratio.y)

	if clone_part_sprites.has(p_name):
		var cspr: Sprite2D = clone_part_sprites[p_name] as Sprite2D
		cspr.offset = spr.offset
		cspr.position = spr.position
		cspr.rotation = spr.rotation
		cspr.scale = spr.scale
	if pip_part_sprites.has(p_name):
		var pspr: Sprite2D = pip_part_sprites[p_name] as Sprite2D
		pspr.offset = spr.offset
		pspr.position = spr.position
		pspr.rotation = spr.rotation
		pspr.scale = spr.scale

func _reset_to_rest_pose() -> void:
	for p_name: String in LAYER_ORDER:
		_apply_part_transform(p_name, Vector2.ZERO, 0.0, Vector2.ONE)
	if part_materials.has("torso"):
		var t_mat: ShaderMaterial = part_materials["torso"] as ShaderMaterial
		t_mat.set_shader_parameter("bust_uv_disp_l", Vector2.ZERO)
		t_mat.set_shader_parameter("bust_uv_disp_r", Vector2.ZERO)
	if part_materials.has("hips_legs"):
		var h_mat: ShaderMaterial = part_materials["hips_legs"] as ShaderMaterial
		h_mat.set_shader_parameter("leg_weight_shift", 0.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var me: InputEventMouse = event as InputEventMouse
		if me.position.x < 495.0 or me.position.y < 110.0:
			return
	if not edit_mode_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_part = event.pressed
	elif event is InputEventMouseMotion and _dragging_part:
		var delta_local: Vector2 = event.relative / rig_root.scale.x
		var curr: Vector2 = user_offsets.get(selected_part_name, Vector2.ZERO) as Vector2
		user_offsets[selected_part_name] = curr + delta_local
		if _status_label:
			var u: Vector2 = user_offsets[selected_part_name] as Vector2
			_status_label.text = "Pieza [%s] offset: (%.1f, %.1f)" % [selected_part_name, u.x, u.y]

func _apply_idle_preset(preset_idx: int) -> void:
	idle_preset_mode = preset_idx
	if preset_idx == 0:
		anim_enabled = true
		breath_speed = 2.15
		breath_amp = 1.0
		hip_sway_amp = 1.0
		jiggle_gain = 1.25
		cape_wind_strength = 1.0
	elif preset_idx == 1:
		anim_enabled = true
		breath_speed = 1.55
		breath_amp = 0.65
		hip_sway_amp = 0.55
		jiggle_gain = 0.75
		cape_wind_strength = 0.55
	elif preset_idx == 2:
		anim_enabled = true
		breath_speed = 2.65
		breath_amp = 1.25
		hip_sway_amp = 1.20
		jiggle_gain = 1.45
		cape_wind_strength = 1.85
	else:
		anim_enabled = false
		cape_wind_strength = 0.0
	_apply_pipeline_and_skin()

func _apply_pipeline_and_skin() -> void:
	var state_d: Dictionary = _export_current_state_dict()
	_apply_state_dict_to_materials(part_materials, state_d)
	if wings_bloom_sprite:
		wings_bloom_sprite.modulate = Color(active_accent_col.r, active_accent_col.g, active_accent_col.b, clampf(glow_intensity * 0.30, 0.0, 0.85))
	if bg_canvas_node:
		bg_canvas_node.queue_redraw()

func _apply_Snapshot_to_clone_rig(snap_d: Dictionary) -> void:
	_apply_state_dict_to_materials(clone_part_materials, snap_d)

func _apply_state_dict_to_materials(mat_dict: Dictionary, d: Dictionary) -> void:
	var s_id: String = String(d.get("skin_id", "base"))
	var c_dirty: bool = bool(d.get("custom_colors_dirty", false))
	var h_over: bool = bool(d.get("hair_override_active", false))
	var use_recolor: bool = (s_id != "base") or c_dirty

	var acc_c := Color(String(d.get("accent_col", active_accent_col.to_html(false))))
	var pan_c := Color(String(d.get("panel_col", active_panel_col.to_html(false))))
	var suit_c := Color(String(d.get("suit_col", active_suit_col.to_html(false))))
	var hair_c := Color(String(d.get("hair_col", active_hair_col.to_html(false))))
	var hsec_c := Color(String(d.get("hair_sec_col", active_hair_sec_col.to_html(false))))

	for p_name: String in LAYER_ORDER:
		if not mat_dict.has(p_name):
			continue
		var mat: ShaderMaterial = mat_dict[p_name] as ShaderMaterial
		if not mat:
			continue

		mat.set_shader_parameter("pipeline_style_mode", int(d.get("pipeline_mode", 2)))
		mat.set_shader_parameter("recolor_method", int(d.get("recolor_method", 1)))
		mat.set_shader_parameter("hair_style_mode", int(d.get("hair_style_mode", 0)))
		mat.set_shader_parameter("enable_shader_recolor", use_recolor)
		mat.set_shader_parameter("enable_hair_recolor", h_over or use_recolor)
		mat.set_shader_parameter("debug_view_mode", debug_view_mode)

		mat.set_shader_parameter("accent_color", acc_c)
		mat.set_shader_parameter("panel_color", pan_c)
		mat.set_shader_parameter("suit_dark_color", suit_c)
		mat.set_shader_parameter("hair_color", hair_c)
		mat.set_shader_parameter("hair_secondary_color", hsec_c)

		mat.set_shader_parameter("enable_halftone", bool(d.get("enable_halftone", true)))
		mat.set_shader_parameter("halftone_pattern_type", int(d.get("halftone_pattern_type", 0)))
		mat.set_shader_parameter("halftone_zone_mode", int(d.get("halftone_zone_mode", 0)))
		mat.set_shader_parameter("halftone_scale", float(d.get("halftone_scale", 165.0)))
		mat.set_shader_parameter("halftone_strength", float(d.get("halftone_strength", 0.38)))
		mat.set_shader_parameter("halftone_angle_deg", float(d.get("halftone_angle_deg", 45.0)))
		mat.set_shader_parameter("halftone_threshold", float(d.get("halftone_threshold", 0.38)))

		mat.set_shader_parameter("ink_boost", float(d.get("ink_boost", 0.28)))
		mat.set_shader_parameter("cel_step_strength", float(d.get("cel_step_strength", 0.0)))
		mat.set_shader_parameter("noir_shadow_crush", float(d.get("noir_shadow_crush", 0.0)))
		mat.set_shader_parameter("noir_shadow_threshold", float(d.get("noir_shadow_threshold", 0.24)))
		mat.set_shader_parameter("metal_sheen_strength", float(d.get("metal_sheen_strength", 0.0)))
		mat.set_shader_parameter("rim_light_strength", float(d.get("rim_light_strength", 0.30)))
		mat.set_shader_parameter("rim_width_px", float(d.get("rim_width_px", 5.0)))
		mat.set_shader_parameter("dual_rim_strength", float(d.get("dual_rim_strength", 0.0)))
		mat.set_shader_parameter("glow_intensity", float(d.get("glow_intensity", 1.25)))

		mat.set_shader_parameter("recolor_contrast", float(d.get("recolor_contrast", 1.0)))
		mat.set_shader_parameter("recolor_highlight", float(d.get("recolor_highlight", 1.0)))
		mat.set_shader_parameter("recolor_saturation", float(d.get("recolor_saturation", 1.0)))
		mat.set_shader_parameter("stocking_tint_strength", float(d.get("stocking_tint_strength", 0.28)))

		mat.set_shader_parameter("hair_effect_strength", float(d.get("hair_effect_strength", 0.90)))
		mat.set_shader_parameter("hair_cut_height", float(d.get("hair_cut_height", 0.42)))
		mat.set_shader_parameter("hair_cut_softness", float(d.get("hair_cut_softness", 0.14)))
		mat.set_shader_parameter("cape_wind_strength", cape_wind_strength if anim_enabled else 0.0)

func _save_offsets_to_disk() -> void:
	var out: Dictionary = {}
	for k: String in user_offsets.keys():
		var v: Vector2 = user_offsets[k] as Vector2
		out[k] = [snappedf(v.x, 0.1), snappedf(v.y, 0.1)]
	var save_res: String = _get_active_offsets_save_path()
	var abs_save: String = ProjectSettings.globalize_path(save_res)
	var f := FileAccess.open(abs_save, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
		if _status_label:
			_status_label.text = "✅ Offsets guardados en %s" % save_res.get_file()

func _build_top_art_director_bar() -> void:
	var top_panel := PanelContainer.new()
	top_panel.name = "ArtDirectorTopBar"
	top_panel.position = Vector2(500.0, 12.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.94)
	style.border_color = Color("#00F0FF")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	top_panel.add_theme_stylebox_override("panel", style)
	add_child(top_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(vbox)

	# FILA 1: FONDOS 1-CLICK + COLOR PICKER LIBRE
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	var bg_lbl := Label.new()
	bg_lbl.text = "FONDO:"
	bg_lbl.add_theme_color_override("font_color", Color("#00F0FF"))
	bg_lbl.add_theme_font_size_override("font_size", 11)
	row1.add_child(bg_lbl)

	_add_quick_btn(row1, "⬜ Blanco Puro", func() -> void: _set_backdrop_mode(4))
	_add_quick_btn(row1, "🩶 Gris Estudio", func() -> void: _set_backdrop_mode(5))
	_add_quick_btn(row1, "⬛ Abismo #080812", func() -> void: _set_backdrop_mode(0))
	_add_quick_btn(row1, "🌌 Hangar", func() -> void: _set_backdrop_mode(1))
	_add_quick_btn(row1, "📐 Panel Manga", func() -> void: _set_backdrop_mode(3))

	var cp_lbl := Label.new()
	cp_lbl.text = "Libre:"
	cp_lbl.add_theme_font_size_override("font_size", 11)
	row1.add_child(cp_lbl)

	_picker_bg = ColorPickerButton.new()
	_picker_bg.custom_minimum_size = Vector2(36.0, 24.0)
	_picker_bg.color = custom_bg_color
	_picker_bg.edit_alpha = false
	_picker_bg.color_changed.connect(func(c: Color) -> void:
		custom_bg_color = c
		_set_backdrop_mode(6)
	)
	row1.add_child(_picker_bg)

	# FILA 2: COMPARADOR A/B + PREVIEW IN-GAME + INSPECTOR RAYOS-X
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)

	var ab_lbl := Label.new()
	ab_lbl.text = "LAB TOOLS:"
	ab_lbl.add_theme_color_override("font_color", Color("#FF1E56"))
	ab_lbl.add_theme_font_size_override("font_size", 11)
	row2.add_child(ab_lbl)

	_add_quick_btn(row2, "📌 Fijar Estilo A", func() -> void:
		snapshot_style_a = _export_current_state_dict("Snapshot A")
		_apply_Snapshot_to_clone_rig(snapshot_style_a)
		if _status_label:
			_status_label.text = "📌 Estilo actual fijado como Referencia A para comparar."
	)

	var toggle_ab_btn := Button.new()
	toggle_ab_btn.text = "🔀 Ver A / B"
	toggle_ab_btn.pressed.connect(func() -> void:
		if snapshot_style_a.is_empty():
			return
		if not viewing_snapshot_a:
			snapshot_style_b_temp = _export_current_state_dict()
			viewing_snapshot_a = true
			_import_full_state_dict(snapshot_style_a)
			toggle_ab_btn.text = "🔀 Viendo A (Click -> B)"
		else:
			viewing_snapshot_a = false
			_import_full_state_dict(snapshot_style_b_temp)
			toggle_ab_btn.text = "🔀 Ver A / B"
		_sync_all_ui_controls()
		_apply_pipeline_and_skin()
	)
	row2.add_child(toggle_ab_btn)

	var split_chk := Button.new()
	split_chk.text = "👥 Lado a Lado (A vs B)"
	split_chk.toggle_mode = true
	split_chk.toggled.connect(func(on: bool) -> void:
		split_compare_active = on
		if on:
			rig_root.position = Vector2(465.0, 120.0)
			rig_root.scale = Vector2(1.38, 1.38)
			rig_clone_root.visible = true
			_compare_label_a.visible = true
			_compare_label_b.visible = true
			_apply_Snapshot_to_clone_rig(snapshot_style_a)
		else:
			rig_root.position = Vector2(650.0, 96.0)
			rig_root.scale = Vector2(1.55, 1.55)
			rig_clone_root.visible = false
			_compare_label_a.visible = false
			_compare_label_b.visible = false
	)
	row2.add_child(split_chk)

	var pip_chk := Button.new()
	pip_chk.text = "🎮 Escala In-Game + Balas"
	pip_chk.toggle_mode = true
	pip_chk.toggled.connect(func(on: bool) -> void:
		ingame_pip_active = on
		if ingame_pip_panel:
			ingame_pip_panel.visible = on
	)
	row2.add_child(pip_chk)

	var ghost_top_btn := Button.new()
	ghost_top_btn.text = "👻 Calco 9:16"
	ghost_top_btn.toggle_mode = true
	ghost_top_btn.tooltip_text = "Proyectar imagen maestra 9:16 semitransparente SOBRE el personaje"
	ghost_top_btn.toggled.connect(func(on: bool) -> void:
		if ghost_ref_sprite:
			ghost_ref_sprite.visible = on
	)
	row2.add_child(ghost_top_btn)

	var xray_opt := OptionButton.new()
	xray_opt.add_item("🔬 Vista: Render Final", 0)
	xray_opt.add_item("🔬 Rayos-X: Clown-Pass ID", 1)
	xray_opt.add_item("🔬 Rayos-X: Luminancia", 2)
	xray_opt.add_item("🔬 Rayos-X: Solo Tinta", 3)
	xray_opt.selected = 0
	xray_opt.item_selected.connect(func(idx: int) -> void:
		debug_view_mode = idx
		_apply_pipeline_and_skin()
	)
	row2.add_child(xray_opt)

func _add_quick_btn(parent: HBoxContainer, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_control_panel_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "LabControlPanel"
	panel.position = Vector2(14.0, 12.0)
	panel.custom_minimum_size = Vector2(472.0, 980.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.95)
	style.border_color = Color("#FF1E56")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var main_scroll := ScrollContainer.new()
	main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(main_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	main_scroll.add_child(vbox)

	var title := Label.new()
	title.text = "ASTRA DREAM — VISUAL IDENTITY STUDIO v6"
	title.add_theme_color_override("font_color", Color("#FF1E56"))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "✅ Abrí el menú ⚙️ de cada filtro para ajustar sus patrones y guardar perfiles."
	_status_label.add_theme_color_override("font_color", Color("#00FF9D"))
	_status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_status_label)

	# =========================================================================
	# 0. SELECTOR MULTI-PILOTO (valentina base + sandbox/pilot_rig_lab/pilots/*)
	# =========================================================================
	_add_section_header(vbox, "0. Piloto Activa (Multi-Rig Studio):")
	_pilot_opt = OptionButton.new()
	_pilot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(available_pilots.size()):
		var pe: Dictionary = available_pilots[i]
		_pilot_opt.add_item(String(pe["label"]), i)
	_pilot_opt.selected = 0
	_pilot_opt.item_selected.connect(func(idx: int) -> void:
		_switch_active_pilot(idx)
	)
	_add_prev_next_dynamic_row(vbox, _pilot_opt, func() -> int: return available_pilots.size(), func(idx: int) -> void:
		_switch_active_pilot(idx)
	)

	# =========================================================================
	# 1. PERFIL DE IDENTIDAD VISUAL / FILTRO + GUARDADO Y AJUSTE CONTEXTUAL
	# =========================================================================
	_add_section_header(vbox, "1. Perfil de Identidad Visual / Filtro:")
	_profile_opt = OptionButton.new()
	_profile_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rebuild_profile_option_items()
	_profile_opt.item_selected.connect(func(idx: int) -> void:
		_load_profile_by_index(idx)
	)
	_add_prev_next_dynamic_row(vbox, _profile_opt, func() -> int: return _get_total_profile_count(), func(idx: int) -> void:
		_load_profile_by_index(idx)
	)

	# Barra de Gestión de Perfiles (Reset Default / Guardar como Nuevo / Sobrescribir)
	var prof_bar := HBoxContainer.new()
	prof_bar.add_theme_constant_override("separation", 5)
	vbox.add_child(prof_bar)

	var reset_prof_btn := Button.new()
	reset_prof_btn.text = "↺ Default"
	reset_prof_btn.tooltip_text = "Restaurar el perfil activo a sus valores de fábrica"
	reset_prof_btn.pressed.connect(_reset_current_profile_to_default)
	prof_bar.add_child(reset_prof_btn)

	_profile_name_edit = LineEdit.new()
	_profile_name_edit.placeholder_text = "Nombre para guardar perfil..."
	_profile_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_name_edit.add_theme_font_size_override("font_size", 11)
	prof_bar.add_child(_profile_name_edit)

	var save_new_btn := Button.new()
	save_new_btn.text = "➕ Guardar Nuevo"
	save_new_btn.pressed.connect(func() -> void:
		var cname: String = _profile_name_edit.text.strip_edges()
		if cname.is_empty():
			cname = "Mi Estilo %d" % (custom_profiles.size() + 1)
		var new_prof: Dictionary = _export_current_state_dict(cname)
		custom_profiles.append(new_prof)
		_save_custom_profiles_to_disk()
		current_profile_index = FACTORY_PROFILES.size() + custom_profiles.size() - 1
		_rebuild_profile_option_items()
		_profile_name_edit.text = ""
		if _status_label:
			_status_label.text = "💾 Guardado nuevo perfil '%s' en disco." % cname
	)
	prof_bar.add_child(save_new_btn)

	var overwrite_btn := Button.new()
	overwrite_btn.text = "💾"
	overwrite_btn.tooltip_text = "Sobrescribir perfil personalizado actual (o crear copia si es de fábrica)"
	overwrite_btn.pressed.connect(func() -> void:
		if current_profile_index >= FACTORY_PROFILES.size():
			var c_idx: int = current_profile_index - FACTORY_PROFILES.size()
			var old_name: String = String(custom_profiles[c_idx].get("name", "Custom"))
			custom_profiles[c_idx] = _export_current_state_dict(old_name)
			_save_custom_profiles_to_disk()
			if _status_label:
				_status_label.text = "💾 Perfil '%s' actualizado en disco." % old_name
		else:
			var auto_name: String = "Editado P%d (%d)" % [current_pipeline_mode, custom_profiles.size() + 1]
			custom_profiles.append(_export_current_state_dict(auto_name))
			_save_custom_profiles_to_disk()
			current_profile_index = FACTORY_PROFILES.size() + custom_profiles.size() - 1
			_rebuild_profile_option_items()
			if _status_label:
				_status_label.text = "💾 Creado perfil '%s' para preservar el default de fábrica." % auto_name
	)
	prof_bar.add_child(overwrite_btn)

	# ACORDEÓN DESPLEGABLE DE LA SECCIÓN 1 (PATRONES, TRAMA, TINTA Y RIM-LIGHT)
	var sec1_box: VBoxContainer = _create_contextual_accordion(vbox, "⚙️ Ajustar Patrones, Trama, Sombra y Rim de este Filtro")

	_ht_chk = CheckBox.new()
	_ht_chk.text = "Activar Patrón de Trama / Semitono en este Filtro"
	_ht_chk.button_pressed = enable_halftone
	_ht_chk.toggled.connect(func(v: bool) -> void:
		enable_halftone = v
		_apply_pipeline_and_skin()
	)
	sec1_box.add_child(_ht_chk)

	var ht_hb := HBoxContainer.new()
	sec1_box.add_child(ht_hb)
	_pat_opt = OptionButton.new()
	_pat_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pat_opt.add_item("Patrón 0: Puntos CMYK", 0)
	_pat_opt.add_item("Patrón 1: Líneas Manga", 1)
	_pat_opt.add_item("Patrón 2: Trama Cruzada", 2)
	_pat_opt.add_item("Patrón 3: Micro-Punto", 3)
	_pat_opt.add_item("Patrón 4: Hexágonos Sci-Fi", 4)
	_pat_opt.add_item("Patrón 5: Scanlines CRT", 5)
	_pat_opt.selected = halftone_pattern_type
	_pat_opt.item_selected.connect(func(idx: int) -> void:
		halftone_pattern_type = idx
		_apply_pipeline_and_skin()
	)
	ht_hb.add_child(_pat_opt)

	_zone_opt = OptionButton.new()
	_zone_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_opt.add_item("Zona: Sombras Traje", 0)
	_zone_opt.add_item("Zona: Todo el Traje", 1)
	_zone_opt.add_item("Zona: Global (Sin Piel)", 2)
	_zone_opt.add_item("Zona: Sombra + Luz Pop-Art", 3)
	_zone_opt.selected = halftone_zone_mode
	_zone_opt.item_selected.connect(func(idx: int) -> void:
		halftone_zone_mode = idx
		_apply_pipeline_and_skin()
	)
	ht_hb.add_child(_zone_opt)

	_add_bound_slider(sec1_box, "halftone_scale", "Densidad de Patrón", 40.0, 300.0, halftone_scale, func(v: float) -> void:
		halftone_scale = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "halftone_strength", "Opacidad de Trama", 0.0, 0.95, halftone_strength, func(v: float) -> void:
		halftone_strength = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "halftone_angle_deg", "Ángulo del Patrón (°)", 0.0, 180.0, halftone_angle_deg, func(v: float) -> void:
		halftone_angle_deg = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "halftone_threshold", "Umbral Luma de Trama", 0.18, 0.78, halftone_threshold, func(v: float) -> void:
		halftone_threshold = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "ink_boost", "Refuerzo Tinta (#080812)", 0.0, 0.90, ink_boost, func(v: float) -> void:
		ink_boost = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "cel_step_strength", "Bandas Duras Cel-Step", 0.0, 1.0, cel_step_strength, func(v: float) -> void:
		cel_step_strength = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "noir_shadow_crush", "Sombra Negra Noir (P5)", 0.0, 1.0, noir_shadow_crush, func(v: float) -> void:
		noir_shadow_crush = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "noir_shadow_threshold", "Corte Sombra Noir", 0.12, 0.42, noir_shadow_threshold, func(v: float) -> void:
		noir_shadow_threshold = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "metal_sheen_strength", "Especular Metálico", 0.0, 1.4, metal_sheen_strength, func(v: float) -> void:
		metal_sheen_strength = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "rim_light_strength", "Fuerza Rim-Light Izq.", 0.0, 1.4, rim_light_strength, func(v: float) -> void:
		rim_light_strength = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "rim_width_px", "Grosor Rim-Light (px)", 1.0, 12.0, rim_width_px, func(v: float) -> void:
		rim_width_px = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "dual_rim_strength", "Rim Secundario Cian Der.", 0.0, 1.4, dual_rim_strength, func(v: float) -> void:
		dual_rim_strength = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec1_box, "glow_intensity", "Brillo Acentos / Monóculo", 0.0, 2.6, glow_intensity, func(v: float) -> void:
		glow_intensity = v
		_apply_pipeline_and_skin()
	)

	var reset_s1 := Button.new()
	reset_s1.text = "↺ Restaurar Patrones y Sombreado de este Filtro"
	reset_s1.pressed.connect(func() -> void:
		var fp: Dictionary = FACTORY_PROFILES[clampi(current_pipeline_mode, 0, FACTORY_PROFILES.size() - 1)]
		_apply_filter_dict(fp)
		_sync_all_ui_controls()
		_apply_pipeline_and_skin()
	)
	sec1_box.add_child(reset_s1)

	# =========================================================================
	# 2. ALGORITMO MATEMÁTICO DE RECOLOREO + ACORDEÓN DE CURVA
	# =========================================================================
	_add_section_header(vbox, "2. Algoritmo Matemático de Recoloreo:")
	_method_opt = OptionButton.new()
	_method_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(RECOLOR_METHOD_NAMES.size()):
		_method_opt.add_item(RECOLOR_METHOD_NAMES[i], i)
	_method_opt.selected = current_recolor_method
	_method_opt.item_selected.connect(func(idx: int) -> void:
		current_recolor_method = idx
		_apply_pipeline_and_skin()
	)
	_add_prev_next_row(vbox, _method_opt, RECOLOR_METHOD_NAMES.size(), func(idx: int) -> void:
		current_recolor_method = idx
		_apply_pipeline_and_skin()
	)

	var sec2_box: VBoxContainer = _create_contextual_accordion(vbox, "⚙️ Ajustar Contraste, Brillo y Medias de este Método")
	_add_bound_slider(sec2_box, "recolor_contrast", "Contraste Sombras/Luz", 0.45, 2.0, recolor_contrast, func(v: float) -> void:
		recolor_contrast = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec2_box, "recolor_highlight", "Realce Especular (Luces)", 0.0, 1.8, recolor_highlight, func(v: float) -> void:
		recolor_highlight = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec2_box, "recolor_saturation", "Saturación de Color", 0.1, 1.8, recolor_saturation, func(v: float) -> void:
		recolor_saturation = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec2_box, "stocking_tint_strength", "Tinte Nylon en Medias", 0.0, 0.95, stocking_tint_strength, func(v: float) -> void:
		stocking_tint_strength = v
		_apply_pipeline_and_skin()
	)
	var reset_s2 := Button.new()
	reset_s2.text = "↺ Restaurar Curva de Recoloreo por Defecto"
	reset_s2.pressed.connect(_reset_recolor_section)
	sec2_box.add_child(reset_s2)

	# =========================================================================
	# 3. SKIN / PALETA DEL TRAJE + MUTADOR DE ARMONÍA + ACORDEÓN RGB
	# =========================================================================
	_add_section_header(vbox, "3. Skin / Paleta de Traje y Armadura:")
	_skin_opt = OptionButton.new()
	_skin_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(SKIN_ORDER.size()):
		var s_id: String = SKIN_ORDER[i]
		var s_cfg: Dictionary = SKIN_PRESETS[s_id] as Dictionary
		_skin_opt.add_item(String(s_cfg["label"]), i)
	_skin_opt.item_selected.connect(func(idx: int) -> void:
		current_skin_id = SKIN_ORDER[idx]
		_sync_colors_from_preset(current_skin_id)
		_apply_pipeline_and_skin()
	)
	_add_prev_next_row(vbox, _skin_opt, SKIN_ORDER.size(), func(idx: int) -> void:
		current_skin_id = SKIN_ORDER[idx]
		_sync_colors_from_preset(current_skin_id)
		_apply_pipeline_and_skin()
	)

	var sec3_box: VBoxContainer = _create_contextual_accordion(vbox, "🎨 Editar Colores RGB y Generador de Armonías")
	var harm_row := HBoxContainer.new()
	sec3_box.add_child(harm_row)
	var harm_opt := OptionButton.new()
	harm_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harm_opt.add_item("Armonía: Cyberpunk Alto Contraste", 0)
	harm_opt.add_item("Armonía: Tríada Equilátera (120°)", 1)
	harm_opt.add_item("Armonía: Complementaria Dividida", 2)
	harm_opt.add_item("Armonía: Análoga Suave", 3)
	harm_opt.item_selected.connect(func(idx: int) -> void: harmony_mode = idx)
	harm_row.add_child(harm_opt)

	var mut_btn := Button.new()
	mut_btn.text = "🎲 Sugerir Armonía"
	mut_btn.pressed.connect(_mutate_color_harmony)
	harm_row.add_child(mut_btn)

	var pickers_hb := HBoxContainer.new()
	pickers_hb.add_theme_constant_override("separation", 6)
	sec3_box.add_child(pickers_hb)
	_picker_accent = _add_lockable_color_chip(pickers_hb, "Acento", active_accent_col, func(c: Color) -> void:
		active_accent_col = c
		custom_colors_dirty = true
		_apply_pipeline_and_skin()
	, func(lk: bool) -> void: lock_accent = lk)
	_picker_panel = _add_lockable_color_chip(pickers_hb, "Paneles", active_panel_col, func(c: Color) -> void:
		active_panel_col = c
		custom_colors_dirty = true
		_apply_pipeline_and_skin()
	, func(lk: bool) -> void: lock_panel = lk)
	_picker_suit = _add_lockable_color_chip(pickers_hb, "Traje", active_suit_col, func(c: Color) -> void:
		active_suit_col = c
		custom_colors_dirty = true
		_apply_pipeline_and_skin()
	, func(lk: bool) -> void: lock_suit = lk)

	var reset_s3 := Button.new()
	reset_s3.text = "↺ Restaurar Colores Originales de esta Skin"
	reset_s3.pressed.connect(func() -> void:
		_sync_colors_from_preset(current_skin_id)
		_apply_pipeline_and_skin()
	)
	sec3_box.add_child(reset_s3)

	# =========================================================================
	# 4. CABELLO INDEPENDIENTE (COLOR + TÉCNICA) + ACORDEÓN DE PELO
	# =========================================================================
	_add_section_header(vbox, "4. Color y Técnica de Cabello Independiente:")
	_hair_opt = OptionButton.new()
	_hair_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(HAIR_PRESETS.size()):
		var hp: Dictionary = HAIR_PRESETS[i]
		_hair_opt.add_item(String(hp["label"]), i)
	_hair_opt.selected = current_hair_preset_idx
	_hair_opt.item_selected.connect(func(idx: int) -> void: _apply_hair_preset(idx))
	_add_prev_next_row(vbox, _hair_opt, HAIR_PRESETS.size(), func(idx: int) -> void: _apply_hair_preset(idx))

	_hair_style_opt = OptionButton.new()
	_hair_style_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(HAIR_STYLE_NAMES.size()):
		_hair_style_opt.add_item(HAIR_STYLE_NAMES[i], i)
	_hair_style_opt.selected = current_hair_style_mode
	_hair_style_opt.item_selected.connect(func(idx: int) -> void:
		current_hair_style_mode = idx
		_apply_pipeline_and_skin()
	)
	_add_prev_next_row(vbox, _hair_style_opt, HAIR_STYLE_NAMES.size(), func(idx: int) -> void:
		current_hair_style_mode = idx
		_apply_pipeline_and_skin()
	)

	var sec4_box: VBoxContainer = _create_contextual_accordion(vbox, "⚙️ Ajustar Corte, Halo y RGB del Cabello")
	var hpick_hb := HBoxContainer.new()
	sec4_box.add_child(hpick_hb)
	_picker_hair = _add_lockable_color_chip(hpick_hb, "Pelo Base", active_hair_col, func(c: Color) -> void:
		active_hair_col = c
		hair_override_active = true
		_apply_pipeline_and_skin()
	, func(lk: bool) -> void: lock_hair = lk)
	_picker_hair_sec = _add_lockable_color_chip(hpick_hb, "Pelo 2 / Halo", active_hair_sec_col, func(c: Color) -> void:
		active_hair_sec_col = c
		hair_override_active = true
		_apply_pipeline_and_skin()
	, func(_lk: bool) -> void: pass)

	_add_bound_slider(sec4_box, "hair_effect_strength", "Intensidad Efecto Pelo", 0.0, 1.0, hair_effect_strength, func(v: float) -> void:
		hair_effect_strength = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec4_box, "hair_cut_height", "Altura Corte / Halo", 0.08, 0.82, hair_cut_height, func(v: float) -> void:
		hair_cut_height = v
		_apply_pipeline_and_skin()
	)
	_add_bound_slider(sec4_box, "hair_cut_softness", "Suavidad de Transición", 0.02, 0.35, hair_cut_softness, func(v: float) -> void:
		hair_cut_softness = v
		_apply_pipeline_and_skin()
	)
	var reset_s4 := Button.new()
	reset_s4.text = "↺ Restaurar Cabello por Defecto"
	reset_s4.pressed.connect(_reset_hair_section)
	sec4_box.add_child(reset_s4)

	# =========================================================================
	# 5. ANIMACIÓN IDLE AUTÓNOMA Y CALIBRACIÓN DE PIEZAS
	# =========================================================================
	_add_section_header(vbox, "5. Animación Idle Autónoma y Calibración:")
	var idle_opt := OptionButton.new()
	idle_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idle_opt.add_item("Idle 0: Presencia Dominante (Ciclo Completo)", 0)
	idle_opt.add_item("Idle 1: Calma Calculadora (Sutil y Fría)", 1)
	idle_opt.add_item("Idle 2: Vendaval en Cubierta (Viento Intenso)", 2)
	idle_opt.add_item("Idle 3: Estática de Estudio (0% Movimiento)", 3)
	idle_opt.selected = idle_preset_mode
	idle_opt.item_selected.connect(func(idx: int) -> void: _apply_idle_preset(idx))
	_add_prev_next_row(vbox, idle_opt, 4, func(idx: int) -> void: _apply_idle_preset(idx))

	var sec5_box: VBoxContainer = _create_contextual_accordion(vbox, "⚙️ Ajustar Física Idle y Posición de Piezas")
	_add_bound_slider(sec5_box, "breath_speed", "Velocidad Respiratoria", 0.5, 4.5, breath_speed, func(v: float) -> void: breath_speed = v)
	_add_bound_slider(sec5_box, "hip_sway_amp", "Swing de Piernas", 0.0, 2.2, hip_sway_amp, func(v: float) -> void: hip_sway_amp = v)
	_add_bound_slider(sec5_box, "jiggle_gain", "Elasticidad Pecho UV", 0.0, 2.5, jiggle_gain, func(v: float) -> void: jiggle_gain = v)
	_add_bound_slider(sec5_box, "cape_wind_strength", "Viento en Capa UV", 0.0, 2.0, cape_wind_strength, func(v: float) -> void:
		cape_wind_strength = v
		_apply_pipeline_and_skin()
	)

	var ghost_chk := CheckBox.new()
	ghost_chk.text = "👻 Proyectar Calco Fantasma 9:16 SOBRE el Personaje"
	ghost_chk.toggled.connect(func(v: bool) -> void:
		if ghost_ref_sprite:
			ghost_ref_sprite.visible = v
	)
	sec5_box.add_child(ghost_chk)

	_add_bound_slider(sec5_box, "ghost_alpha", "Opacidad Calco Fantasma", 0.10, 0.95, 0.48, func(v: float) -> void:
		if ghost_ref_sprite:
			ghost_ref_sprite.modulate = Color(0.20, 0.92, 1.0, v)
	)

	var edit_chk := CheckBox.new()
	edit_chk.text = "Habilitar Arrastre Manual de Pieza con Mouse"
	edit_chk.toggled.connect(func(v: bool) -> void: edit_mode_enabled = v)
	sec5_box.add_child(edit_chk)

	var part_opt := OptionButton.new()
	for i: int in range(LAYER_ORDER.size()):
		part_opt.add_item("Pieza: " + LAYER_ORDER[i], i)
	part_opt.selected = 4
	part_opt.item_selected.connect(func(idx: int) -> void: selected_part_name = LAYER_ORDER[idx])
	sec5_box.add_child(part_opt)

	var btn_hb := HBoxContainer.new()
	sec5_box.add_child(btn_hb)
	var save_btn := Button.new()
	save_btn.text = "💾 Guardar Offsets"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_offsets_to_disk)
	btn_hb.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Offsets"
	reset_btn.pressed.connect(func() -> void:
		for k: String in user_offsets.keys():
			user_offsets[k] = Vector2.ZERO
	)
	btn_hb.add_child(reset_btn)

func _create_contextual_accordion(parent: VBoxContainer, btn_label: String) -> VBoxContainer:
	var btn := Button.new()
	btn.text = btn_label + " ▼"
	btn.toggle_mode = true
	btn.button_pressed = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 11)
	parent.add_child(btn)

	var panel := PanelContainer.new()
	panel.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.11, 0.18, 0.95)
	st.border_color = Color(0.0, 0.94, 1.0, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", st)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)

	btn.toggled.connect(func(open: bool) -> void:
		panel.visible = open
		btn.text = (btn_label + " ▲") if open else (btn_label + " ▼")
	)
	return vb

func _add_prev_next_row(parent: VBoxContainer, opt: OptionButton, count: int, on_change: Callable) -> void:
	_add_prev_next_dynamic_row(parent, opt, func() -> int: return count, on_change)

func _add_prev_next_dynamic_row(parent: VBoxContainer, opt: OptionButton, count_fn: Callable, on_change: Callable) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	var prev_b := Button.new()
	prev_b.text = "◀"
	prev_b.custom_minimum_size = Vector2(32.0, 0.0)
	prev_b.pressed.connect(func() -> void:
		var c: int = max(1, int(count_fn.call()))
		var next_idx: int = (opt.selected - 1 + c) % c
		opt.selected = next_idx
		on_change.call(next_idx)
	)
	hb.add_child(prev_b)
	hb.add_child(opt)
	var next_b := Button.new()
	next_b.text = "▶"
	next_b.custom_minimum_size = Vector2(32.0, 0.0)
	next_b.pressed.connect(func() -> void:
		var c: int = max(1, int(count_fn.call()))
		var next_idx: int = (opt.selected + 1) % c
		opt.selected = next_idx
		on_change.call(next_idx)
	)
	hb.add_child(next_b)
	parent.add_child(hb)

func _add_section_header(parent: VBoxContainer, txt: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", Color("#00F0FF"))
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)

func _add_lockable_color_chip(parent: HBoxContainer, label_txt: String, init_col: Color, cb: Callable, lock_cb: Callable) -> ColorPickerButton:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top_hb := HBoxContainer.new()
	vb.add_child(top_hb)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 10)
	top_hb.add_child(lbl)
	var lk := CheckBox.new()
	lk.text = "🔒"
	lk.tooltip_text = "Bloquear este canal al usar '🎲 Sugerir Armonía'"
	lk.add_theme_font_size_override("font_size", 9)
	lk.toggled.connect(lock_cb)
	top_hb.add_child(lk)

	var cpb := ColorPickerButton.new()
	cpb.custom_minimum_size = Vector2(0.0, 24.0)
	cpb.color = init_col
	cpb.edit_alpha = false
	cpb.color_changed.connect(cb)
	vb.add_child(cpb)
	parent.add_child(vb)
	return cpb

func _add_bound_slider(parent: VBoxContainer, key: String, label_text: String, min_v: float, max_v: float, init_v: float, callback: Callable) -> void:
	var hb := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "%s: %.2f" % [label_text, init_v]
	lbl.custom_minimum_size = Vector2(205.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	hb.add_child(lbl)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = 0.01
	sl.value = init_v
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v: float) -> void:
		lbl.text = "%s: %.2f" % [label_text, v]
		callback.call(v)
	)
	hb.add_child(sl)
	parent.add_child(hb)
	_ui_sliders[key] = {"slider": sl, "label": lbl, "title": label_text}
