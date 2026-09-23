class_name TrophyDetailsModal
extends CanvasLayer


## TrophyDetailsModal.gd
## Modal de inspección y mejora de Trofeos en la Sala de Trofeos del Hub 2.5D.
## Permite gastar Materia Oscura para elevar el nivel de maestría del logro
## e incrementar sus bonificaciones pasivas globales permanentes.

signal trophy_upgraded(trophy_id: StringName, new_level: int)
signal modal_closed()

const COLOR_HOT_PINK := Color("#FF1493")
const COLOR_DEEP_BLACK := Color("#0A0A0E")
const COLOR_PURE_WHITE := Color("#FFFFFF")
const COLOR_NEON_CYAN := Color("#00F0FF")
const COLOR_DARK_MATTER := Color("#BF00FF")

@onready var backdrop: ColorRect = $Backdrop
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var trophy_title: Label = find_child("TrophyTitle", true, false) as Label
@onready var trophy_lore: Label = find_child("TrophyLore", true, false) as Label
@onready var mastery_badge: Label = find_child("MasteryBadge", true, false) as Label
@onready var bonus_label: Label = find_child("BonusLabel", true, false) as Label
@onready var btn_upgrade: Button = find_child("UpgradeButton", true, false) as Button
@onready var btn_close: Button = find_child("CloseButton", true, false) as Button
@onready var cost_label: Label = find_child("CostLabel", true, false) as Label

var current_trophy_id: StringName = &"trophy_boss_aegis"
var is_active: bool = false

const TROPHY_METADATA = {
	&"trophy_boss_aegis": {
		"title": "CORAZÓN DE NODRIZA AEGIS",
		"lore": "Reactor de aniquilación cuántica recuperado tras abatir al dreadnought estelar.",
		"bonus_fmt": "+%d%% Daño permanente a todas las heroínas (+5%% por maestría)",
		"base_val": 10,
		"step_val": 5
	},
	&"trophy_biosphere_core": {
		"title": "NÚCLEO BIO-PLANETA",
		"lore": "Matriz biológica viva cosechada de las capas geológicas del planeta verde.",
		"bonus_fmt": "+%d HP Máximo global para todas las partidas (+5 HP por maestría)",
		"base_val": 15,
		"step_val": 5
	},
	&"trophy_cryo_core": {
		"title": "NÚCLEO CRIOGÉNICO",
		"lore": "Cero absoluto estabilizado en un prisma hiperconductor superconductor.",
		"bonus_fmt": "+%d%% Vel. Proyectil y +%d%% Reducción de enfriamiento",
		"base_val": 5,
		"step_val": 2
	},
	&"trophy_volcanic_core": {
		"title": "NÚCLEO VOLCÁNICO",
		"lore": "Geoda magmática ígnea de combustión infinita extraída del manto de lava.",
		"bonus_fmt": "+%d%% Probabilidad crítica y +%.2fx Daño crítico",
		"base_val": 5,
		"step_val": 2
	},
	&"trophy_monolith_master": {
		"title": "RELIQUIA DEL MONOLITO",
		"lore": "Estructura rúnica taumatúrgica capaz de canalizar el poder del orbe arcano.",
		"bonus_fmt": "+%d%% Radio magnético de recogida de orbes (+5%% por maestría)",
		"base_val": 15,
		"step_val": 5
	}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if btn_close:
		btn_close.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(btn_close)

	if btn_upgrade:
		btn_upgrade.pressed.connect(_on_upgrade_pressed)
		UIFocusHelper.apply_cyber_focus(btn_upgrade)

	_apply_styles()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close_modal()
		get_viewport().set_input_as_handled()


func open_trophy(trophy_id: StringName) -> void:
	current_trophy_id = trophy_id
	is_active = true
	visible = true
	_refresh_display()
	if btn_upgrade and btn_upgrade.is_inside_tree() and not btn_upgrade.disabled:
		btn_upgrade.grab_focus()
	elif btn_close and btn_close.is_inside_tree():
		btn_close.grab_focus()


func close_modal() -> void:
	is_active = false
	visible = false
	modal_closed.emit()


func _refresh_display() -> void:
	var meta: Dictionary = TROPHY_METADATA.get(current_trophy_id, {
		"title": "TROFEO DESCONOCIDO",
		"lore": "Reliquia no identificada en los sensores del hangar.",
		"bonus_fmt": "Bono pasivo activo",
		"base_val": 5,
		"step_val": 2
	})

	if trophy_title:
		trophy_title.text = meta["title"]

	if trophy_lore:
		trophy_lore.text = meta["lore"]

	var mastery := SaveManager.get_trophy_mastery(current_trophy_id)
	var is_unlocked := mastery > 0

	if mastery_badge:
		if is_unlocked:
			mastery_badge.text = "★ DESBLOQUEADO - MAESTRÍA NIVEL %d" % mastery
			mastery_badge.add_theme_color_override("font_color", COLOR_DARK_MATTER)
		else:
			mastery_badge.text = "🔒 BLOQUEADO (Vence al jefe o destruye el núcleo en combate)"
			mastery_badge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))

	if bonus_label:
		if is_unlocked:
			var val: int = int(meta["base_val"]) + (mastery - 1) * int(meta["step_val"])
			if current_trophy_id == &"trophy_cryo_core":
				bonus_label.text = meta["bonus_fmt"] % [val, val]
			elif current_trophy_id == &"trophy_volcanic_core":
				var crit_dmg: float = 0.20 + float(mastery - 1) * 0.05
				bonus_label.text = meta["bonus_fmt"] % [val, crit_dmg]
			else:
				bonus_label.text = meta["bonus_fmt"] % val
			bonus_label.add_theme_color_override("font_color", COLOR_NEON_CYAN)
		else:
			bonus_label.text = "Bonificación inactiva hasta desbloquear el trofeo."
			bonus_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	# Costo de mejora = 10 * maestría actual
	var cost := 10 * maxi(1, mastery)
	var dm := SaveManager.get_dark_matter()

	if cost_label:
		cost_label.text = "Materia Oscura disponible: %d  |  Costo de mejora: %d" % [dm, cost]

	if btn_upgrade:
		btn_upgrade.disabled = (not is_unlocked) or (dm < cost)
		btn_upgrade.text = "MEJORAR MAESTRÍA A NIVEL %d" % (mastery + 1)


func _on_upgrade_pressed() -> void:
	var mastery := SaveManager.get_trophy_mastery(current_trophy_id)
	var cost := 10 * maxi(1, mastery)
	if SaveManager.upgrade_trophy_with_dark_matter(current_trophy_id, cost):
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("level_up", 1.3)
		trophy_upgraded.emit(current_trophy_id, mastery + 1)
		_refresh_display()


func _apply_styles() -> void:
	if backdrop:
		backdrop.color = Color(0.02, 0.02, 0.05, 0.85)

	if main_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_DEEP_BLACK
		sb.border_color = COLOR_DARK_MATTER
		sb.set_border_width_all(2)
		sb.border_width_top = 4
		sb.set_corner_radius_all(0)
		sb.shadow_color = Color(0.75, 0.0, 1.0, 0.25)
		sb.shadow_size = 16
		main_panel.add_theme_stylebox_override("panel", sb)
