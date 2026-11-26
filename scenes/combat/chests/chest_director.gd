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
var is_hub_suppressed: bool = false


func set_hub_suppressed(suppressed: bool) -> void:
	is_hub_suppressed = suppressed
	if suppressed:
		cleanup_all_chests()
		continuous_spawn_timer = 0.0


func _is_blocked_by_hub(container: Node = null) -> bool:
	if is_hub_suppressed:
		return true
	var check_node: Node = container if container != null else get_parent()
	if check_node != null and check_node.has_method("is_hub_mode_active") and bool(check_node.call("is_hub_mode_active")):
		return true
	return false

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
	if _is_blocked_by_hub(parent_container):
		return
	# Limpieza de referencias inválidas
	var valid_chests: Array[SpatialChest] = []
	for c in active_chests:
		if is_instance_valid(c) and not c.is_opened:
			valid_chests.append(c)
	active_chests = valid_chests

	_relocate_distant_chests(player_pos, parent_container)

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
	if _is_blocked_by_hub(parent_container) or not config or not is_instance_valid(parent_container):
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
	if _is_blocked_by_hub(parent) or not chest_scene:
		return

	var chest := chest_scene.instantiate() as SpatialChest
	chest.chest_type = type
	chest.economy_config = config
	chest.item_pool = item_pool_manager

	chest.global_position = _resolve_valid_chest_position(center_pos, parent)
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

const CHEST_MAX_DISTANCE: float = 1800.0
const CHEST_RELOCATION_MIN_DIST: float = 1150.0
const CHEST_RELOCATION_MAX_DIST: float = 1450.0

func _has_chest_overlap(pos: Vector2) -> bool:
	for existing in active_chests:
		if is_instance_valid(existing):
			if pos.distance_squared_to(existing.global_position) < (180.0 * 180.0):
				return true
	return false


func _resolve_valid_chest_position(center_pos: Vector2, parent: Node2D) -> Vector2:
	var launch_dir: Vector2 = Vector2.ZERO
	var cone_half: float = deg_to_rad(65.0)
	if is_instance_valid(parent):
		if parent.has_method("get_hub_launch_departure_direction"):
			launch_dir = parent.call("get_hub_launch_departure_direction")
		if parent.has_method("get_hub_launch_forward_cone_half_angle_rad"):
			cone_half = float(parent.call("get_hub_launch_forward_cone_half_angle_rad"))

	var has_filter: bool = is_instance_valid(parent) and parent.has_method("is_position_allowed_for_combat_spawn")
	for _attempt: int in range(16):
		var angle: float = (launch_dir.angle() + randf_range(-cone_half, cone_half)) if launch_dir.length_squared() > 0.001 else (randf() * TAU)
		var dist: float = randf_range(config.min_spawn_radius, config.max_spawn_radius)
		var cand: Vector2 = center_pos + Vector2(cos(angle), sin(angle)) * dist
		if has_filter and not bool(parent.call("is_position_allowed_for_combat_spawn", cand, center_pos, 90.0, true)):
			continue
		if not _has_chest_overlap(cand):
			return cand

	var fallback_dir: Vector2 = launch_dir if launch_dir.length_squared() > 0.001 else Vector2.UP.rotated(randf_range(-PI, PI))
	var fallback_pos: Vector2 = center_pos + fallback_dir.normalized() * config.max_spawn_radius
	if is_instance_valid(parent) and parent.has_method("push_position_outside_hub_exclusion"):
		fallback_pos = parent.call("push_position_outside_hub_exclusion", fallback_pos, fallback_dir, 90.0)
	if _has_chest_overlap(fallback_pos):
		var perp: Vector2 = Vector2(-fallback_dir.y, fallback_dir.x).normalized()
		fallback_pos += perp * 200.0 * (1.0 if (active_chests.size() % 2 == 0) else -1.0)
	return fallback_pos


## Reubicación cuántica silenciosa de cofres desatendidos lejanos hacia adelante del jugador
func _relocate_distant_chests(player_pos: Vector2, parent_container: Node2D) -> void:
	var forward_dir: Vector2 = Vector2.ZERO
	if is_instance_valid(parent_container):
		var player_node: Node2D = parent_container.get("player") as Node2D
		if is_instance_valid(player_node) and "velocity" in player_node:
			var vel: Vector2 = player_node.get("velocity")
			if vel.length_squared() > 100.0:
				forward_dir = vel.normalized()

	for chest: SpatialChest in active_chests:
		if not is_instance_valid(chest) or chest.is_opened:
			continue
		var dist: float = chest.global_position.distance_to(player_pos)
		if dist > CHEST_MAX_DISTANCE:
			var spawn_angle: float
			if forward_dir.length_squared() > 0.001:
				spawn_angle = forward_dir.angle() + randf_range(-PI * 0.25, PI * 0.25)
			else:
				spawn_angle = randf_range(0.0, TAU)
			var offset_dist: float = randf_range(CHEST_RELOCATION_MIN_DIST, CHEST_RELOCATION_MAX_DIST)
			var candidate: Vector2 = player_pos + Vector2.from_angle(spawn_angle) * offset_dist
			if is_instance_valid(parent_container) and parent_container.has_method("is_position_in_hub_exclusion_zone") and bool(parent_container.call("is_position_in_hub_exclusion_zone", candidate, 90.0)):
				candidate = parent_container.call("push_position_outside_hub_exclusion", candidate, forward_dir, 90.0)
			chest.global_position = candidate

