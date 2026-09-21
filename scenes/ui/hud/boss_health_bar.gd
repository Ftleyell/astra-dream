class_name BossHealthBar
extends Control

@onready var boss_name_label: Label = $VBoxContainer/HeaderRow/BossNameLabel
@onready var phase_label: Label = $VBoxContainer/HeaderRow/PhaseLabel
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var hp_text_label: Label = $VBoxContainer/HPTextLabel

var target_health: float = 1200.0
var max_health_val: float = 1200.0
var bar_tween: Tween = null
var is_active: bool = false

func _ready() -> void:
	visible = false
	modulate.a = 0.0

func setup_boss(boss_name: String, max_hp: float) -> void:
	is_active = true
	max_health_val = max_hp
	target_health = max_hp

	if boss_name_label:
		boss_name_label.text = "⚠ ALERTA DE AMENAZA: %s ⚠" % boss_name
	if phase_label:
		phase_label.text = "[FASE 1]"
		phase_label.modulate = Color(0.2, 0.9, 1.0)
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = max_hp
	if hp_text_label:
		hp_text_label.text = "%d / %d HP" % [int(max_hp), int(max_hp)]

	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)

func update_health(current: float, max_val: float) -> void:
	if not is_active:
		return
	target_health = current
	max_health_val = max_val

	if hp_text_label:
		hp_text_label.text = "%d / %d HP" % [maxi(0, int(current)), int(max_val)]

	if health_bar:
		if bar_tween and bar_tween.is_valid():
			bar_tween.kill()
		bar_tween = create_tween()
		bar_tween.tween_property(health_bar, "value", current, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_phase(new_phase: int) -> void:
	if not phase_label:
		return
	phase_label.text = "[FASE %d - SOBRECARGA]" % new_phase if new_phase == 2 else "[FASE %d]" % new_phase
	if new_phase == 2:
		phase_label.modulate = Color(1.0, 0.35, 0.2)
		var fill_style := health_bar.get_theme_stylebox("fill")
		if fill_style is StyleBoxFlat:
			fill_style.bg_color = Color(0.95, 0.25, 0.15, 0.9)
		# Pulso de escala de advertencia
		var pulse := create_tween()
		pulse.tween_property(self, "scale", Vector2(1.04, 1.04), 0.1)
		pulse.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func hide_boss() -> void:
	is_active = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): visible = false)
