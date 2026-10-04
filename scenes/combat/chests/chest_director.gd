class_name ChestDirector
extends Node

## ChestDirector.gd
## Sub-director encargado de la generación, poblamiento y administración del ciclo de vida
## de los cofres espaciales interactuables en cada oleada y sector de Astra Dream.

signal chest_opened(item: ItemData, was_free: bool, cost: int)

@export var config: ChestEconomyConfig = null
@export var chest_scene: PackedScene = preload("res://scenes/combat/chests/spatial_chest.tscn")

var paid_chests_count: int = 0
var current_wave: int = 1
var local_chests_opened_this_wave: int = 0
var active_chests: Array[SpatialChest] = []
var continuous_spawn_timer: float = 0.0
const CONTINUOUS_SPAWN_INTERVAL: float = 18.0
const MAX_ACTIVE_CHESTS: int = 5
var item_pool_manager: ItemPoolManager = null

func initialize(economy_cfg: ChestEconomyConfig, starting_paid_chests: int = 0) -> void:
	config = economy_cfg
	paid_chests_count = starting_paid_chests
	current_wave = 1
	local_chests_opened_this_wave = 0
	active_chests.clear()
	continuous_spawn_timer = 0.0
	if not item_pool_manager:
		item_pool_manager = ItemPoolManager.new()
		item_pool_manager.name = "ChestItemPoolManager"
		add_child(item_pool_manager)
	else:
		item_pool_manager.reset_pity_counters()

## Notificación de inicio de nueva oleada para reiniciar inflación local
func on_new_wave(new_wave: int, green_card_stacks: int = 0) -> void:
	current_wave = new_wave
	local_chests_opened_this_wave = 0
	refresh_all_chest_prices(green_card_stacks)

## Chequeo continuo para invocar 1 cofre adicional cada 18s si no se alcanza el tope
func update_continuous_spawner(delta: float, player_pos: Vector2, parent_container: Node2D, green_card_stacks: int = 0) -> void:
	# Limpieza de referencias inválidas
	var valid_chests: Array[SpatialChest] = []
	for c in active_chests:
		if is_instance_valid(c) and not c.is_opened:
			valid_chests.append(c)
	active_chests = valid_chests

	continuous_spawn_timer += delta
	if continuous_spawn_timer >= CONTINUOUS_SPAWN_INTERVAL:
		continuous_spawn_timer = 0.0
		if active_chests.size() < MAX_ACTIVE_CHESTS:
			var roll := randf()
			var type := SpatialChest.ChestType.REGULAR
			if roll < 0.25:
				type = SpatialChest.ChestType.SALVAGE_CAPSULE
			elif roll > 0.85 and config and randf() < config.golden_chest_chance_per_wave:
				type = SpatialChest.ChestType.GOLDEN
			_spawn_single_chest(type, player_pos, parent_container, green_card_stacks)

## Genera el lote de cofres correspondiente a una nueva oleada dentro del radio del jugador
func spawn_wave_chests(player_pos: Vector2, parent_container: Node2D, wave_num: int = 1, green_card_stacks: int = 0) -> void:
	if not config or not is_instance_valid(parent_container):
		return

	current_wave = wave_num

	# Si ya hay varios cofres en el campo, no sobrecargar
	if active_chests.size() >= MAX_ACTIVE_CHESTS:
		return

	if wave_num == 1:
		# En el segundo 0: 1 cápsula gratuita y 1 cofre regular para arrancar
		_spawn_single_chest(SpatialChest.ChestType.SALVAGE_CAPSULE, player_pos, parent_container, green_card_stacks)
		_spawn_single_chest(SpatialChest.ChestType.REGULAR, player_pos, parent_container, green_card_stacks)
		return

	var salvage_count := randi_range(config.salvage_capsules_per_wave.x, config.salvage_capsules_per_wave.y)
	var regular_count := randi_range(config.regular_chests_per_wave.x, config.regular_chests_per_wave.y)
	var spawn_golden := randf() < config.golden_chest_chance_per_wave

	# 1. Cápsulas de chatarra (0 créditos)
	for i in range(salvage_count):
		if active_chests.size() < MAX_ACTIVE_CHESTS:
			_spawn_single_chest(SpatialChest.ChestType.SALVAGE_CAPSULE, player_pos, parent_container, green_card_stacks)

	# 2. Cofres regulares
	for i in range(regular_count):
		if active_chests.size() < MAX_ACTIVE_CHESTS:
			_spawn_single_chest(SpatialChest.ChestType.REGULAR, player_pos, parent_container, green_card_stacks)

	# 3. Cofre dorado (si aplica)
	if spawn_golden and active_chests.size() < MAX_ACTIVE_CHESTS:
		_spawn_single_chest(SpatialChest.ChestType.GOLDEN, player_pos, parent_container, green_card_stacks)

func _spawn_single_chest(type: SpatialChest.ChestType, center_pos: Vector2, parent: Node2D, green_card_stacks: int) -> void:
	if not chest_scene:
		return

	var chest := chest_scene.instantiate() as SpatialChest
	chest.chest_type = type
	chest.economy_config = config
	chest.item_pool = item_pool_manager

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
	chest.update_price_display(current_wave, local_chests_opened_this_wave, green_card_stacks)

	chest.chest_opened.connect(func(item: ItemData, was_free: bool, cost: int):
		var live_cards: int = green_card_stacks
		if is_inside_tree():
			var p_nodes := get_tree().get_nodes_in_group("player")
			for p in p_nodes:
				if p is Player and is_instance_valid(p) and not p.is_queued_for_deletion() and p.inventory:
					live_cards = p.inventory.get_item_count(&"credit_card_green")
					break
		_on_chest_opened(item, was_free, cost, chest, live_cards)
	)

	active_chests.append(chest)

func _on_chest_opened(item: ItemData, was_free: bool, cost: int, chest: SpatialChest, green_card_stacks: int) -> void:
	if not was_free:
		local_chests_opened_this_wave += 1
		paid_chests_count += 1

	# Refrescar los precios de los cofres restantes (por inflación o consumo de llaves)
	refresh_all_chest_prices(green_card_stacks)

	active_chests.erase(chest)
	chest_opened.emit(item, was_free, cost)

## Refresca las etiquetas de precio de todos los cofres activos en el espacio
func refresh_all_chest_prices(green_card_stacks: int = 0) -> void:
	var cleaned_list: Array[SpatialChest] = []
	for c in active_chests:
		if is_instance_valid(c) and not c.is_opened:
			c.update_price_display(current_wave, local_chests_opened_this_wave, green_card_stacks)
			cleaned_list.append(c)
	active_chests = cleaned_list

## Limpia todos los cofres del sector actual
func cleanup_all_chests() -> void:
	for c in active_chests:
		if is_instance_valid(c):
			c.queue_free()
	active_chests.clear()
