class_name RunForkOverlay
extends CanvasLayer

## RunForkOverlay.gd
## Capa de interfaz de usuario para la selección táctica de bifurcaciones de run.
## Proyecta 4 tarjetas en las 4 esquinas del HUD y modula su escala y opacidad
## según el vector de desplazamiento del jugador relativo al punto de ancla.

const ForkChoiceCardClass = preload("res://scenes/combat/ui/components/fork_choice_card.gd")
const ForkChoiceCardScene = preload("res://scenes/combat/ui/components/fork_choice_card.tscn")

@export var prompt_label_text: String = "MANIOBRA LA NAVE HACIA UN CUADRANTE"

@onready var root_control: Control = $Control
@onready var prompt_label: Label = $Control/PromptLabel

@onready var card_top_right: ForkChoiceCard = $Control/TopRight/ForkChoiceCard
@onready var card_top_left: ForkChoiceCard = $Control/TopLeft/ForkChoiceCard
@onready var card_bottom_left: ForkChoiceCard = $Control/BottomLeft/ForkChoiceCard
@onready var card_bottom_right: ForkChoiceCard = $Control/BottomRight/ForkChoiceCard

var cards: Array[ForkChoiceCard] = []
var _is_presenting: bool = false
var _overlay_tween: Tween = null

const QUADRANT_DIRECTIONS: Array[Vector2] = [
	Vector2(0.707107, -0.707107),  # Cuadrante 0: Superior Derecho (x > 0, y < 0)
	Vector2(-0.707107, -0.707107), # Cuadrante 1: Superior Izquierdo (x < 0, y < 0)
	Vector2(-0.707107, 0.707107),  # Cuadrante 2: Inferior Izquierdo (x < 0, y > 0)
	Vector2(0.707107, 0.707107),   # Cuadrante 3: Inferior Derecho (x > 0, y > 0)
]


func _ready() -> void:
	_gather_cards()
	visible = false
	if prompt_label:
		prompt_label.text = prompt_label_text


func _gather_cards() -> void:
	cards.clear()
	if not card_top_right:
		card_top_right = get_node_or_null("Control/TopRight/ForkChoiceCard") as ForkChoiceCard
	if not card_top_left:
		card_top_left = get_node_or_null("Control/TopLeft/ForkChoiceCard") as ForkChoiceCard
	if not card_bottom_left:
		card_bottom_left = get_node_or_null("Control/BottomLeft/ForkChoiceCard") as ForkChoiceCard
	if not card_bottom_right:
		card_bottom_right = get_node_or_null("Control/BottomRight/ForkChoiceCard") as ForkChoiceCard

	if card_top_right: cards.append(card_top_right)
	if card_top_left: cards.append(card_top_left)
	if card_bottom_left: cards.append(card_bottom_left)
	if card_bottom_right: cards.append(card_bottom_right)


func present_choices(choices: Array[RunForkOptionData]) -> void:
	_gather_cards()
	_is_presenting = true
	visible = true

	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()

	if root_control:
		root_control.modulate.a = 0.0
		_overlay_tween = create_tween()
		if _overlay_tween:
			_overlay_tween.tween_property(root_control, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)

	for i in range(cards.size()):
		var card: ForkChoiceCard = cards[i]
		if not is_instance_valid(card):
			continue
		if i < choices.size():
			card.visible = true
			card.setup_data(choices[i])
			card.set_focus_ratio(0.0)
		else:
			card.visible = false


func update_displacement(delta_vector: Vector2, threshold_distance: float) -> void:
	if not _is_presenting or threshold_distance <= 0.0:
		return

	var dist: float = delta_vector.length()
	var progress: float = clampf(dist / threshold_distance, 0.0, 1.0)

	if dist < 12.0:
		for card: ForkChoiceCard in cards:
			if is_instance_valid(card):
				card.set_focus_ratio(0.0)
		return

	var dir: Vector2 = delta_vector.normalized()

	for i in range(mini(cards.size(), QUADRANT_DIRECTIONS.size())):
		var card: ForkChoiceCard = cards[i]
		if not is_instance_valid(card):
			continue
		var dot: float = dir.dot(QUADRANT_DIRECTIONS[i])
		var ratio: float = dot * progress
		card.set_focus_ratio(ratio)


func play_confirm_sequence(selected_idx: int) -> void:
	_is_presenting = false
	for i in range(cards.size()):
		var card: ForkChoiceCard = cards[i]
		if not is_instance_valid(card):
			continue
		if i == selected_idx:
			card.play_confirm_animation()
		else:
			card.play_dismiss_animation()


func hide_overlay() -> void:
	_is_presenting = false
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()

	_overlay_tween = create_tween()
	if _overlay_tween and root_control:
		_overlay_tween.tween_property(root_control, "modulate:a", 0.0, 0.25)
		_overlay_tween.tween_callback(func() -> void:
			visible = false
		)
	else:
		visible = false


static func get_quadrant_index_for_vector(delta_vec: Vector2) -> int:
	if delta_vec.x >= 0.0 and delta_vec.y < 0.0:
		return 0 # Cuadrante 0: Superior Derecho
	elif delta_vec.x < 0.0 and delta_vec.y < 0.0:
		return 1 # Cuadrante 1: Superior Izquierdo
	elif delta_vec.x < 0.0 and delta_vec.y >= 0.0:
		return 2 # Cuadrante 2: Inferior Izquierdo
	else:
		return 3 # Cuadrante 3: Inferior Derecho
