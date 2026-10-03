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
@export var activation_radius: float = 55.0
@export var float_speed: float = 2.0
@export var float_amplitude: float = 3.5
@export var item_pool: ItemPoolManager = null

var _fallback_pool: ItemPoolManager = null

var current_cost: int = 24
var is_opened: bool = false
var player_inside: bool = false
var _cached_player: Player = null
var _time_alive: float = 0.0
var _insufficient_cooldown: float = 0.0
var _flash_tween: Tween = null

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

	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = activation_radius

	_apply_visual_skin()
	_draw_perimeter_circle()
	update_price_display(1, 0, 0)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if is_opened:
		return
	_time_alive += delta
	if _insufficient_cooldown > 0.0:
		_insufficient_cooldown -= delta

	# Flotación sutil en gravedad cero
	if visual_root:
		visual_root.position.y = sin(_time_alive * float_speed) * float_amplitude

	# Fallback de proximidad por distancia euclidiana directa con el jugador
	if not _cached_player or not is_instance_valid(_cached_player):
		var p_nodes := get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			_cached_player = p_nodes[0] as Player

	if _cached_player and is_instance_valid(_cached_player):
		var dist := global_position.distance_to(_cached_player.global_position)
		if dist <= activation_radius:
			if not player_inside:
				player_inside = true
				player_proximity_changed.emit(true, self)
			# Apertura automática al contacto
			if _can_afford_or_free(_cached_player):
				try_open(_cached_player, item_pool)
			elif _insufficient_cooldown <= 0.0:
				_flash_insufficient_credits()
				_insufficient_cooldown = 1.0
		elif dist > activation_radius + 15.0 and player_inside:
			player_inside = false
			player_proximity_changed.emit(false, self)

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_opened or not is_instance_valid(_cached_player):
		return
	var is_interact_action: bool = InputMap.has_action("interact") and event.is_action_pressed("interact")
	var is_accept_action: bool = event.is_action_pressed("ui_accept")
	var is_key: bool = event is InputEventKey and event.is_pressed() and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_F or event.keycode == KEY_ENTER)
	if is_interact_action or is_accept_action or is_key:
		try_open(_cached_player, item_pool)
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
		sprite.scale = Vector2(0.06, 0.06) # Tamaño táctico ~60px acorde a la nave del jugador

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

func _get_player_ref() -> Player:
	if _cached_player and is_instance_valid(_cached_player) and not _cached_player.is_queued_for_deletion():
		return _cached_player
	if is_inside_tree():
		var p_nodes := get_tree().get_nodes_in_group("player")
		for node in p_nodes:
			if node is Player and is_instance_valid(node) and not node.is_queued_for_deletion():
				_cached_player = node as Player
				return _cached_player
	return null

## Actualiza el coste mostrado en pantalla según la fórmula híbrida de oleada y llaves
func update_price_display(wave: int = 1, local_chests_in_wave: int = 0, green_card_stacks: int = 0) -> void:
	if not economy_config:
		return

	var p: Player = _get_player_ref()
	var keys: int = p.inventory.get_item_count(&"quantum_key") if (p and is_instance_valid(p) and p.inventory) else 0
	var effective_green_cards: int = green_card_stacks
	if effective_green_cards <= 0 and p and is_instance_valid(p) and p.inventory:
		effective_green_cards = p.inventory.get_item_count(&"credit_card_green")

	match chest_type:
		ChestType.SALVAGE_CAPSULE:
			current_cost = 0
			if price_label:
				price_label.text = "GRATIS"
				price_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		ChestType.REGULAR:
			current_cost = economy_config.calculate_regular_chest_cost(wave, local_chests_in_wave, effective_green_cards, keys > 0)
			if price_label:
				price_label.text = "%dc" % current_cost
				price_label.modulate = Color(0.2, 0.8, 1.0, 1.0)
		ChestType.GOLDEN:
			current_cost = economy_config.golden_chest_base_cost
			if price_label:
				price_label.text = "%dc" % current_cost
				price_label.modulate = Color(1.0, 0.85, 0.2, 1.0)

func _can_afford_or_free(player: Player) -> bool:
	if not is_instance_valid(player):
		return false
	if chest_type == ChestType.SALVAGE_CAPSULE:
		return true
	var keys: int = player.inventory.get_item_count(&"quantum_key") if player.inventory else 0
	if keys > 0 and chest_type != ChestType.GOLDEN:
		return true
	return player.run_credits >= current_cost

## Intenta abrir el cofre consumiendo llaves o créditos y otorgando el ítem resultante
func try_open(player: Player, pool: ItemPoolManager = null) -> bool:
	if is_opened or not is_instance_valid(player):
		return false

	_cached_player = player
	var keys: int = player.inventory.get_item_count(&"quantum_key") if player.inventory else 0
	var was_free: bool = false

	if chest_type == ChestType.SALVAGE_CAPSULE:
		was_free = true
	elif keys > 0 and chest_type != ChestType.GOLDEN:
		# Consumo activo de 1 llave: abre gratis y no incrementa el contador k local
		was_free = true
		player.inventory.remove_item_stacks(&"quantum_key", 1)
	else:
		# Pago con créditos
		was_free = false
		if player.run_credits < current_cost:
			_flash_insufficient_credits()
			return false
		player.run_credits -= current_cost
		if player.has_signal("credits_changed"):
			player.credits_changed.emit(player.run_credits)

	is_opened = true

	# Tirada de ítem por Suerte
	var luck: float = 1.0
	if player.stats:
		luck = player.stats.get_stat(&"luck")
	elif player.character_stats and "luck" in player.character_stats:
		luck = float(player.character_stats.luck)

	var weights: Dictionary = economy_config.golden_base_rarity_weights if chest_type == ChestType.GOLDEN else economy_config.regular_base_rarity_weights
	var active_pool: ItemPoolManager = pool if pool != null else item_pool
	if not active_pool:
		if not is_instance_valid(_fallback_pool):
			_fallback_pool = ItemPoolManager.new()
		active_pool = _fallback_pool

	var draft_items: Array[ItemData] = []
	if active_pool:
		draft_items = active_pool.roll_chest_draft(chest_type, weights, luck, 3)

	var modal: ChestRewardModal = null
	var tree := get_tree()
	if tree:
		modal = tree.get_first_node_in_group("chest_reward_modal") as ChestRewardModal

	if modal and is_instance_valid(modal) and modal.is_inside_tree() and not draft_items.is_empty():
		modal.open_draft(draft_items, was_free, player, func(chosen_item: ItemData) -> void:
			chest_opened.emit(chosen_item, was_free, 0 if was_free else current_cost)
			_play_open_and_vanish_fx()
		)
	else:
		var chosen_item: ItemData = draft_items[0] if not draft_items.is_empty() else null
		if chosen_item and player.inventory:
			player.inventory.add_item(chosen_item)
			player.inventory.process_chest_opened_procs(player)
		chest_opened.emit(chosen_item, was_free, 0 if was_free else current_cost)
		_play_open_and_vanish_fx()

	return true

func _flash_insufficient_credits() -> void:
	if not price_label:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	price_label.text = "¡FALTAN CRÉDITOS!"
	price_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.8)
	_flash_tween.tween_callback(func():
		if is_instance_valid(price_label):
			if chest_type == ChestType.SALVAGE_CAPSULE:
				price_label.text = "GRATIS"
				price_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
			elif chest_type == ChestType.GOLDEN:
				price_label.text = "%dc" % current_cost
				price_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
			else:
				price_label.text = "%dc" % current_cost
				price_label.modulate = Color(0.2, 0.8, 1.0, 1.0)
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
