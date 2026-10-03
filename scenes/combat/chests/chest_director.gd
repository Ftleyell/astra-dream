class_name ChestDirector
extends Node

## ChestDirector.gd
## Sub-director encargado de la generación, poblamiento y administración del ciclo de vida
## de los cofres espaciales interactuables en cada oleada y sector de Astra Dream.

signal chest_opened(item: ItemData, was_free: bool, cost: int)

@export var config: ChestEconomyConfig = null
@export var chest_scene: PackedScene = preload("res://scenes/combat/chests/spatial_chest.tscn")

var paid_chests_count: int = 0
var active_chests: Array[SpatialChest] = []

func initialize(economy_cfg: ChestEconomyConfig, starting_paid_chests: int = 0) -> void:
	config = economy_cfg
	paid_chests_count = starting_paid_chests
	active_chests.clear()

## Genera el lote de cofres correspondiente a una nueva oleada dentro del radio del jugador
func spawn_wave_chests(player_pos: Vector2, parent_container: Node2D, _wave_num: int = 1, green_card_stacks: int = 0) -> void:
	if not config or not is_instance_valid(parent_container):
		return

	var salvage_count := randi_range(config.salvage_capsules_per_wave.x, config.salvage_capsules_per_wave.y)
	var regular_count := randi_range(config.regular_chests_per_wave.x, config.regular_chests_per_wave.y)
	var spawn_golden := randf() < config.golden_chest_chance_per_wave

	# 1. Cápsulas de chatarra (0 créditos)
	for i in range(salvage_count):
		_spawn_single_chest(SpatialChest.ChestType.SALVAGE_CAPSULE, player_pos, parent_container, green_card_stacks)

	# 2. Cofres regulares
	for i in range(regular_count):
		_spawn_single_chest(SpatialChest.ChestType.REGULAR, player_pos, parent_container, green_card_stacks)

	# 3. Cofre dorado (si aplica)
	if spawn_golden:
		_spawn_single_chest(SpatialChest.ChestType.GOLDEN, player_pos, parent_container, green_card_stacks)

func _spawn_single_chest(type: SpatialChest.ChestType, center_pos: Vector2, parent: Node2D, green_card_stacks: int) -> void:
	if not chest_scene:
		return

	var chest := chest_scene.instantiate() as SpatialChest
	chest.chest_type = type
	chest.economy_config = config

	# Cálculo de posición dispersa en corona circular
	var angle := randf() * TAU
	var dist := randf_range(config.min_spawn_radius, config.max_spawn_radius)
	var spawn_pos := center_pos + Vector2(cos(angle), sin(angle)) * dist

	# Prevenir solapamiento con cofres existentes
	for existing in active_chests:
		if is_instance_valid(existing):
			if spawn_pos.distance_squared_to(existing.global_position) < (180.0 * 180.0):
				spawn_pos += Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 150.0))

	chest.global_position = spawn_pos
	parent.add_child(chest)
	chest.update_price_display(paid_chests_count, green_card_stacks)

	chest.chest_opened.connect(func(item: ItemData, was_free: bool, cost: int):
		_on_chest_opened(item, was_free, cost, chest, green_card_stacks)
	)

	active_chests.append(chest)

func _on_chest_opened(item: ItemData, was_free: bool, cost: int, chest: SpatialChest, green_card_stacks: int) -> void:
	if not was_free:
		paid_chests_count += 1
		# La inflación acumulativa incrementa el coste de los cofres restantes en tiempo real
		refresh_all_chest_prices(green_card_stacks)

	active_chests.erase(chest)
	chest_opened.emit(item, was_free, cost)

## Refresca las etiquetas de precio de todos los cofres activos en el espacio
func refresh_all_chest_prices(green_card_stacks: int = 0) -> void:
	var cleaned_list: Array[SpatialChest] = []
	for c in active_chests:
		if is_instance_valid(c) and not c.is_opened:
			c.update_price_display(paid_chests_count, green_card_stacks)
			cleaned_list.append(c)
	active_chests = cleaned_list

## Limpia todos los cofres del sector actual
func cleanup_all_chests() -> void:
	for c in active_chests:
		if is_instance_valid(c):
			c.queue_free()
	active_chests.clear()
