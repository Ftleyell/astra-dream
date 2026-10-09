class_name CombatLootCoordinator
extends "res://scenes/combat/systems/combat_subsystem.gd"

## Coordinador desacoplado del sistema de botín y recompensas in-run.
## Administra la aparición de máquinas tragamonedas (bumper arcade),
## cofres de recompensa (SlotMachineChest), y sus modales correspondientes.

signal slot_machine_spawned(beacon: Node2D)
signal slot_machine_exploded(chest: Node2D)

const InRunSlotMachineModalScript := preload("res://scenes/ui/modals/in_run_slot_machine_modal.gd")
const SlotMachineRewardModalScript := preload("res://scenes/ui/modals/slot_machine_reward_modal.gd")
const SlotMachineBeaconScript := preload("res://scenes/combat/satellite/slot_machine_beacon.gd")
const SlotMachineChestScript := preload("res://scenes/combat/satellite/slot_machine_chest.gd")

var current_slot_machine: Node2D = null
var slot_machine_modal: CanvasLayer = null
var slot_machine_reward_modal: CanvasLayer = null

var pity_chance: float = 0.25
var combat_root: Node2D = null
var player_ref: Node2D = null
var camera_ref: GameCamera2D = null

func setup_subsystem(p_context: CombatContextScript) -> void:
	super.setup_subsystem(p_context)
	if context:
		var cam_2d: GameCamera2D = context.camera as GameCamera2D if context.camera is GameCamera2D else null
		initialize(context.main_game as Node2D, context.player, cam_2d)

func initialize(combat_main: Node2D, player_node: Node2D, cam: GameCamera2D) -> void:
	combat_root = combat_main
	player_ref = player_node
	camera_ref = cam

	if not slot_machine_modal:
		slot_machine_modal = InRunSlotMachineModalScript.new()
		combat_root.add_child(slot_machine_modal)

	if not slot_machine_reward_modal:
		slot_machine_reward_modal = SlotMachineRewardModalScript.new()
		combat_root.add_child(slot_machine_reward_modal)

func evaluate_slot_machine_spawn(can_spawn: bool) -> bool:
	if not can_spawn:
		return false

	var roll: float = randf()
	if roll < pity_chance:
		pity_chance = 0.20
		spawn_slot_machine()
		return true
	else:
		pity_chance = minf(1.0, pity_chance + 0.25)
		return false

func spawn_slot_machine(spawn_pos: Vector2 = Vector2.INF) -> Node2D:
	if current_slot_machine != null and is_instance_valid(current_slot_machine):
		return current_slot_machine
	if not is_instance_valid(player_ref) or not combat_root:
		return null

	if spawn_pos == Vector2.INF:
		var move_dir: Vector2 = player_ref.velocity.normalized() if player_ref.velocity.length_squared() > 10.0 else Vector2.UP.rotated(randf_range(-PI, PI))
		spawn_pos = player_ref.global_position + move_dir * 750.0

	var beacon = SlotMachineBeaconScript.new()
	beacon.global_position = spawn_pos
	beacon.interacted.connect(_on_slot_machine_interacted)
	beacon.exploded.connect(_on_slot_machine_exploded)
	current_slot_machine = beacon
	combat_root.add_child(beacon)
	slot_machine_spawned.emit(beacon)
	return beacon

func _on_slot_machine_interacted(_beacon: Node2D) -> void:
	# La máquina tragamonedas in-run es un bumper arcade 100% in-game:
	# Rebota al jugador físicamente, gira los rodillos sobre la máquina y entrega
	# premios en tiempo real sin pausar la partida ni abrir ventanas modales.
	pass

func _on_slot_machine_exploded(pos: Vector2) -> void:
	if camera_ref and is_instance_valid(camera_ref):
		camera_ref.add_trauma(0.65)
	current_slot_machine = null

	var chest = SlotMachineChestScript.new()
	chest.global_position = pos
	chest.chest_opened.connect(_on_slot_machine_chest_opened)
	if combat_root:
		combat_root.add_child(chest)
	slot_machine_exploded.emit(chest)

func _on_slot_machine_chest_opened(chest: Node2D) -> void:
	if slot_machine_reward_modal and is_instance_valid(player_ref):
		slot_machine_reward_modal.show_reward(chest, player_ref)

func spawn_slot_chest(pos: Vector2 = Vector2.INF) -> Node2D:
	if not combat_root:
		return null
	if pos == Vector2.INF:
		var move_dir: Vector2 = player_ref.velocity.normalized() if (is_instance_valid(player_ref) and player_ref.velocity.length_squared() > 10.0) else Vector2.UP
		pos = (player_ref.global_position if is_instance_valid(player_ref) else Vector2.ZERO) + move_dir * 300.0
	var chest = SlotMachineChestScript.new()
	chest.global_position = pos
	chest.chest_opened.connect(_on_slot_machine_chest_opened)
	combat_root.add_child(chest)
	return chest

func cleanup() -> void:
	if is_instance_valid(current_slot_machine):
		current_slot_machine.queue_free()
		current_slot_machine = null
