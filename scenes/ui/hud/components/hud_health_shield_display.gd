class_name HudHealthShieldDisplay
extends RefCounted

## HudHealthShieldDisplay.gd
## Controlador especializado para la visualización de salud, escudo y experiencia del jugador:
## - Interpolación y actualización de barra y etiqueta de salud / escudo.
## - Detección de umbral crítico de baja salud (<25%) con tintado de alerta.
## - Actualización de barra de progreso de EXP y etiqueta de nivel.
## - Efecto visual de destello de protección OSP (One-Shot Protection).

var health_bar: ProgressBar = null
var health_label: Label = null
var exp_bar: ProgressBar = null
var level_label: Label = null

var current_health: float = 100.0
var max_health: float = 100.0
var current_shield: float = 0.0
var max_shield: float = 0.0

var _health_tween: Tween = null
var _exp_tween: Tween = null

const LOW_HEALTH_THRESHOLD: float = 0.25

func setup_from_root(root: CanvasLayer) -> void:
	if not root:
		return
	setup({
		"health_bar": root.find_child("HealthBar", true, false),
		"health_label": root.find_child("HealthLabel", true, false),
		"exp_bar": root.find_child("ExpBar", true, false),
		"level_label": root.find_child("LevelLabel", true, false)
	})

func setup(elements: Dictionary) -> void:
	health_bar = elements.get("health_bar") as ProgressBar
	health_label = elements.get("health_label") as Label
	exp_bar = elements.get("exp_bar") as ProgressBar
	level_label = elements.get("level_label") as Label

func update_health(current: float, max_val: float, shield: float = 0.0, p_max_shield: float = 0.0, tree_ref: SceneTree = null) -> void:
	current_health = current
	max_health = max_val
	current_shield = shield
	max_shield = p_max_shield

	if is_instance_valid(health_bar):
		health_bar.max_value = max_val
		if tree_ref:
			if _health_tween and _health_tween.is_valid():
				_health_tween.kill()
			_health_tween = tree_ref.create_tween()
			_health_tween.tween_property(health_bar, "value", current, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			health_bar.value = current

	if is_instance_valid(health_label):
		if shield > 0.0:
			health_label.text = "%d (+%d) / %d" % [int(current), int(shield), int(max_val)]
		else:
			health_label.text = "%d / %d" % [int(current), int(max_val)]

		var ratio: float = current / maxf(1.0, max_val)
		if ratio <= LOW_HEALTH_THRESHOLD and current > 0.0:
			health_label.modulate = Color(1.0, 0.3, 0.35, 1.0)
		else:
			health_label.modulate = Color.WHITE

func update_exp(current: float, max_val: float, level: int, tree_ref: SceneTree = null) -> void:
	if is_instance_valid(exp_bar):
		exp_bar.max_value = max_val
		if tree_ref:
			if _exp_tween and _exp_tween.is_valid():
				_exp_tween.kill()
			_exp_tween = tree_ref.create_tween()
			_exp_tween.tween_property(exp_bar, "value", current, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			exp_bar.value = current

	if is_instance_valid(level_label):
		level_label.text = "NV. %d" % level

func trigger_osp_effect(parent_node: CanvasLayer) -> void:
	if not is_instance_valid(parent_node):
		return
	var flash := ColorRect.new()
	flash.name = "OSPFlashOverlay"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.2, 0.9, 1.0, 0.45)
	parent_node.add_child(flash)

	var tw: Tween = parent_node.create_tween()
	if tw:
		tw.tween_property(flash, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(flash.queue_free)
	else:
		flash.queue_free()
