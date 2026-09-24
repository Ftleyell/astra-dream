class_name AimModeIndicator
extends Node2D

## AimModeIndicator.gd
## Indicador visual posicionado debajo de la nave que muestra el estado de Autoaim (ON / OFF).

@export var weapon_controller: WeaponController

@onready var label: Label = get_node_or_null("PanelContainer/Label")
@onready var panel: PanelContainer = get_node_or_null("PanelContainer")

var pulse_tween: Tween

func _ready() -> void:
	z_index = 20
	if not weapon_controller and get_parent():
		weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController

	if weapon_controller:
		if weapon_controller.has_signal("aim_mode_changed"):
			weapon_controller.aim_mode_changed.connect(_on_aim_mode_changed)
		_update_indicator(weapon_controller.is_manual_aim)
	else:
		_update_indicator(false)

func _on_aim_mode_changed(is_manual: bool) -> void:
	_update_indicator(is_manual)
	_animate_toggle()

func _update_indicator(is_manual: bool) -> void:
	if not label:
		label = get_node_or_null("PanelContainer/Label") as Label
	if not label:
		return

	if is_manual:
		label.text = "AUTOAIM: OFF"
		label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15, 0.95))
	else:
		label.text = "AUTOAIM: ON"
		label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 0.95))

func _animate_toggle() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	scale = Vector2(1.22, 1.22)
	pulse_tween = create_tween()
	pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
