class_name SpatialChest
extends Area2D

## SpatialChest.gd
## Entidad física e interactuable de cofre en el espacio exterior de Astra Dream.
## Gestiona la interacción con el piloto, cálculo de costes y tiradas estocásticas.

signal chest_opened(item: ItemData, was_free: bool, cost: int)
signal player_proximity_changed(is_inside: bool, chest: SpatialChest)

enum ChestType {
	SALVAGE_CAPSULE,
	REGULAR,
	GOLDEN
}

const TEXTURE_SALVAGE := "res://assets/sprites/interactables/spatial_chest_salvage.png"
const TEXTURE_REGULAR := "res://assets/sprites/interactables/spatial_chest_regular.png"
const TEXTURE_GOLDEN := "res://assets/sprites/interactables/spatial_chest_golden.png"

@export var chest_type: ChestType = ChestType.REGULAR
@export var economy_config: ChestEconomyConfig
@export var activation_radius: float = 120.0
@export var float_speed: float = 2.0
@export var float_amplitude: float = 5.0

var current_cost: int = 0
var is_opened: bool = false
var player_inside: bool = false
var _cached_player: Player = null
var _time_alive: float = 0.0

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var price_label: Label = $PriceLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var radius_visual: Line2D = $RadiusVisual

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("spatial_chests")

	if not economy_config:
		var default_res = load("res://data/balance/default_chest_economy.tres")
		if default_res is ChestEconomyConfig:
			economy_config = default_res as ChestEconomyConfig

	_apply_visual_skin()
	_draw_perimeter_circle()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if is_opened:
		return
	_time_alive += delta
	# Flotación sutil en gravedad cero
	if visual_root:
		visual_root.position.y = sin(_time_alive * float_speed) * float_amplitude

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_opened or not is_instance_valid(_cached_player):
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_pressed() and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		try_open(_cached_player, null)
		get_viewport().set_input_as_handled()

func _apply_visual_skin() -> void:
	if not sprite:
		return
	var tex_path: String = TEXTURE_REGULAR
	match chest_type:
		ChestType.SALVAGE_CAPSULE:
			tex_path = TEXTURE_SALVAGE
		ChestType.REGULAR:
			tex_path = TEXTURE_REGULAR
		ChestType.GOLDEN:
			tex_path = TEXTURE_GOLDEN

	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path) as Texture2D
		sprite.scale = Vector2(0.18, 0.18) # Escala óptima para 1024x1024 a ~180px de juego

func _draw_perimeter_circle() -> void:
	if not radius_visual:
		return
	radius_visual.clear_points()
	var points: int = 32
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		radius_visual.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)

	match chest_type:
		ChestType.SALVAGE_CAPSULE:
			radius_visual.default_color = Color(0.8, 0.6, 0.3, 0.35)
		ChestType.REGULAR:
			radius_visual.default_color = Color(0.0, 0.9, 1.0, 0.4)
		ChestType.GOLDEN:
			radius_visual.default_color = Color(1.0, 0.85, 0.2, 0.5)

## Actualiza el coste mostrado en pantalla según compras pagadas y tarjetas
func update_price_display(paid_chests: int, green_cards: int = 0) -> void:
	if not economy_config:
		return

	match chest_type:
		ChestType.SALVAGE_CAPSULE:
			current_cost = economy_config.salvage_capsule_cost
			if price_label:
				price_label.text = "GRATIS"
				price_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		ChestType.REGULAR:
			current_cost = economy_config.calculate_regular_chest_cost(paid_chests, green_cards)
			if price_label:
				price_label.text = "%dc" % current_cost
				price_label.modulate = Color(0.2, 0.8, 1.0, 1.0)
		ChestType.GOLDEN:
			current_cost = economy_config.golden_chest_base_cost
			if price_label:
				price_label.text = "%dc" % current_cost
				price_label.modulate = Color(1.0, 0.85, 0.2, 1.0)

## Intenta abrir el cofre consumiendo créditos y otorgando el ítem resultante
func try_open(player: Player, item_pool: ItemPoolManager) -> bool:
	if is_opened or not is_instance_valid(player):
		return false

	var keys: int = player.inventory.get_item_count(&"quantum_key") if player.inventory else 0
	var key_free_chance: float = economy_config.calculate_key_free_chance(keys) if economy_config else 0.0
	var was_free: bool = (chest_type == ChestType.SALVAGE_CAPSULE) or (chest_type != ChestType.GOLDEN and randf() < key_free_chance)

	if not was_free:
		if player.run_credits < current_cost:
			_flash_insufficient_credits()
			return false
		player.run_credits -= current_cost
		if player.hud and is_instance_valid(player.hud):
			player.hud.update_credits(player.run_credits)

	is_opened = true

	# Tirada de ítem por Suerte
	var luck: float = player.character_stats.luck if (player.character_stats and "luck" in player.character_stats) else 1.0
	var weights: Dictionary = economy_config.golden_base_rarity_weights if chest_type == ChestType.GOLDEN else economy_config.regular_base_rarity_weights
	var chosen_item: ItemData = null

	if item_pool:
		chosen_item = item_pool.roll_item_by_weights(weights, luck)
	elif player.item_pool_manager:
		chosen_item = player.item_pool_manager.roll_item_by_weights(weights, luck)

	if chosen_item and player.inventory:
		player.inventory.add_item(chosen_item)
		player.inventory.process_chest_opened_procs(player)

	chest_opened.emit(chosen_item, was_free, 0 if was_free else current_cost)
	_play_open_and_vanish_fx()
	return true

func _flash_insufficient_credits() -> void:
	if not price_label:
		return
	var orig_text := price_label.text
	var orig_col := price_label.modulate
	price_label.text = "¡FALTAN CRÉDITOS!"
	price_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func():
		if is_instance_valid(price_label):
			price_label.text = orig_text
			price_label.modulate = orig_col
	)

func _play_open_and_vanish_fx() -> void:
	var tw := create_tween()
	tw.parallel().tween_property(visual_root, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual_root, "modulate:a", 0.0, 0.3)
	if radius_visual:
		tw.parallel().tween_property(radius_visual, "default_color:a", 0.0, 0.3)
	if price_label:
		tw.parallel().tween_property(price_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if is_opened:
		return
	if body is Player:
		player_inside = true
		_cached_player = body as Player
		player_proximity_changed.emit(true, self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false
		_cached_player = null
		player_proximity_changed.emit(false, self)
