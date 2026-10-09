class_name CharacterSelectTabController
extends RefCounted

## CharacterSelectTabController.gd
## Orquestador desacoplado de pestañas para CharacterSelectUI.
## Gestiona: registro de botones de tab, visibilidad de vistas y estilos activo/inactivo.
## Responsabilidad única: determinar qué vista es visible según el tab activo.

# ── Vistas contenedoras ──────────────────────────────────────────────────────
var _loadout_view: Control = null
var _abilities_view: Control = null

# ── Botones de pestaña ───────────────────────────────────────────────────────
var _tab_loadout_btn: Button = null
var _tab_abilities_btn: Button = null

# ── Estado ───────────────────────────────────────────────────────────────────
var current_tab_index: int = 0

# ── Estilos ──────────────────────────────────────────────────────────────────
var _style_active: StyleBoxFlat = null
var _style_inactive: StyleBoxFlat = null


func setup(
	tab_loadout_btn: Button,
	tab_abilities_btn: Button,
	loadout_view: Control,
	abilities_view: Control
) -> void:
	_tab_loadout_btn = tab_loadout_btn
	_tab_abilities_btn = tab_abilities_btn
	_loadout_view = loadout_view
	_abilities_view = abilities_view

	_build_styles()
	_connect_buttons()


func _build_styles() -> void:
	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color(0.05, 0.12, 0.22, 0.95)
	_style_active.border_width_bottom = 2
	_style_active.border_color = Color(0.0, 0.85, 1.0, 0.9)
	_style_active.set_corner_radius_all(4)

	_style_inactive = StyleBoxFlat.new()
	_style_inactive.bg_color = Color(0.02, 0.05, 0.10, 0.7)
	_style_inactive.border_width_bottom = 1
	_style_inactive.border_color = Color(0.3, 0.4, 0.5, 0.5)
	_style_inactive.set_corner_radius_all(4)


func _connect_buttons() -> void:
	if _tab_loadout_btn:
		_tab_loadout_btn.pressed.connect(func() -> void: switch_tab(0))
	if _tab_abilities_btn:
		_tab_abilities_btn.pressed.connect(func() -> void: switch_tab(1))


## Cambia al tab indicado por índice.
## 0 = Loadout / Equipamiento, 1 = Habilidades / Stats.
func switch_tab(index: int) -> void:
	current_tab_index = index
	_apply_tab_visibility()
	_apply_tab_styles()


## Aplica visibilidad: en modo sin botones, ambas vistas son visibles (status quo).
func _apply_tab_visibility() -> void:
	var has_real_tabs: bool = (_tab_loadout_btn != null or _tab_abilities_btn != null)

	if not has_real_tabs:
		# Sin botones de tab en escena: mantener ambas vistas visibles.
		if _loadout_view:
			_loadout_view.visible = true
		if _abilities_view:
			_abilities_view.visible = true
		return

	match current_tab_index:
		0:
			if _loadout_view:
				_loadout_view.visible = true
			if _abilities_view:
				_abilities_view.visible = false
		1:
			if _loadout_view:
				_loadout_view.visible = false
			if _abilities_view:
				_abilities_view.visible = true
		_:
			if _loadout_view:
				_loadout_view.visible = true
			if _abilities_view:
				_abilities_view.visible = true


func _apply_tab_styles() -> void:
	if _tab_loadout_btn:
		_tab_loadout_btn.add_theme_stylebox_override(
			"normal",
			_style_active if current_tab_index == 0 else _style_inactive
		)
	if _tab_abilities_btn:
		_tab_abilities_btn.add_theme_stylebox_override(
			"normal",
			_style_active if current_tab_index == 1 else _style_inactive
		)


## Devuelve true si la vista de loadout es la activa.
func is_loadout_tab_active() -> bool:
	return current_tab_index == 0


## Devuelve true si la vista de habilidades es la activa.
func is_abilities_tab_active() -> bool:
	return current_tab_index == 1


## Registra externamente los botones de tab si se crean de forma diferida.
func set_tab_buttons(loadout_btn: Button, abilities_btn: Button) -> void:
	_tab_loadout_btn = loadout_btn
	_tab_abilities_btn = abilities_btn
	_connect_buttons()
	switch_tab(current_tab_index)
