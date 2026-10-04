class_name TransmutationRewardChest
extends Area2D

## TransmutationRewardChest.gd
## Cápsula / cofre orbital generado tras culminar la forja molecular en la TransmutationStation.
## Permite al jugador aceptar el ítem forjado o rechazarlo a cambio de créditos estelares.

signal reward_resolved(accepted: bool, item: ItemData)

@export var item: ItemData = null
@export var station: TransmutationStation = null

var is_resolved: bool = false
var _cached_player: Player = null
var _time_alive: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var label: Label = $Label
@onready var aura: Line2D = $VisualRoot/AuraRing

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("transmutation_chests")
	collision_layer = 0
	collision_mask = 3

	_setup_visuals()
	body_entered.connect(_on_body_entered)

func setup(p_item: ItemData, p_station: TransmutationStation) -> void:
	item = p_item
	station = p_station
	_setup_visuals()

func _setup_visuals() -> void:
	if not is_inside_tree():
		return
	if label and item:
		label.text = "[ %s ]\n(BUMPEAR: ACEPTAR/RECHAZAR)" % item.item_name
		label.modulate = _get_rarity_color(item.rarity)

func _process(delta: float) -> void:
	if is_resolved:
		return
	_time_alive += delta
	if visual_root:
		visual_root.position.y = sin(_time_alive * 3.5) * 4.0

	# Fallback de bumpeo por distancia directa con el jugador
	if not _cached_player or not is_instance_valid(_cached_player):
		var p_nodes := get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			_cached_player = p_nodes[0] as Player

	if _cached_player and is_instance_valid(_cached_player):
		if global_position.distance_to(_cached_player.global_position) <= 60.0:
			trigger_choice(_cached_player)

func _on_body_entered(body: Node2D) -> void:
	if is_resolved:
		return
	if body is Player or (body != null and body.is_in_group("player")):
		trigger_choice(body as Player)

func trigger_choice(player: Player) -> void:
	if is_resolved or not is_instance_valid(player) or not item:
		return

	is_resolved = true
	var tree := get_tree()
	var modal: TransmutationModal = tree.get_first_node_in_group("transmutation_modal") if tree else null

	if modal and is_instance_valid(modal) and modal.has_method("open_choice"):
		modal.open_choice(item, func(accepted: bool) -> void:
			_apply_resolution(player, accepted)
		)
	else:
		# Fallback directo en caso de no encontrar el modal
		_apply_resolution(player, true)

func _apply_resolution(player: Player, accepted: bool) -> void:
	if is_instance_valid(player):
		if accepted:
			if player.inventory:
				player.inventory.add_item(item, 1)
			if player.has_method("show_tactical_alert"):
				player.show_tactical_alert("FORJA COMPLETADA", "Obtenido: %s" % item.item_name, Color(0.8, 0.4, 1.0))
		else:
			var refund := get_refund_credits_for_rarity(item.rarity)
			player.run_credits += refund
			if player.has_signal("credits_changed"):
				player.credits_changed.emit(player.run_credits)
			var hud_node: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
			if hud_node and hud_node.has_method("show_tactical_alert"):
				hud_node.show_tactical_alert("ÍTEM RECICLADO", "+%d créditos recuperados" % refund, Color(0.3, 0.9, 1.0))

	if is_instance_valid(station):
		station.consume_use()

	reward_resolved.emit(accepted, item)
	queue_free()

static func get_refund_credits_for_rarity(rarity: Enums.Rarity) -> int:
	match rarity:
		Enums.Rarity.COMMON: return 25
		Enums.Rarity.UNCOMMON: return 50
		Enums.Rarity.RARE: return 80
		Enums.Rarity.EPIC: return 120
		Enums.Rarity.LEGENDARY: return 180
		_: return 30

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON: return Color(0.6, 0.9, 0.6)
		Enums.Rarity.UNCOMMON: return Color(0.3, 0.7, 1.0)
		Enums.Rarity.RARE: return Color(0.8, 0.4, 1.0)
		Enums.Rarity.EPIC: return Color(1.0, 0.3, 0.8)
		Enums.Rarity.LEGENDARY: return Color(1.0, 0.85, 0.2)
		_: return Color.WHITE
