class_name TransmutationStation
extends Node2D

## TransmutationStation.gd
## Baliza satelital de Forja Cuántica (Microondas espacial).
## Permite al jugador clonar un ítem de su inventario sacrificando
## otro ítem aleatorio de la misma rareza (hasta 3 usos por estación).

signal station_activated(station: TransmutationStation)
signal station_depleted()

const TEXTURE_BEACON := "res://assets/sprites/interactables/transmutation_beacon.png"

@export var max_uses: int = 3
@export var activation_radius: float = 180.0
@export var core_bump_radius: float = 60.0
@export var rotation_speed: float = 0.35
@export var processing_duration: float = 9.0

var uses_remaining: int = 3
var is_active: bool = false
var player_inside: bool = false
var is_depleted: bool = false
var is_processing: bool = false
var processing_timer: float = 0.0
var current_target_item: ItemData = null
var current_processing_player: Node2D = null
var active_reward_chest: Node2D = null
var _recompiler_applied: bool = false
var _cached_player: Node2D = null
var _bump_cooldown: float = 0.0
var must_exit_before_rebump: bool = false
var _process_ring: Line2D = null

const TransmutationRewardChestClass = preload("res://scenes/combat/satellite/transmutation_reward_chest.gd")
var reward_chest_scene: PackedScene = preload("res://scenes/combat/satellite/transmutation_reward_chest.tscn")

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var area: Area2D = $PerimeterArea
@onready var radius_visual: Line2D = $RadiusVisual
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("transmutation_stations")
	check_quantum_recompiler()
	_apply_visual_skin()
	_draw_radius_circle()
	_setup_process_ring()
	_update_label()

	if is_instance_valid(area):
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _setup_process_ring() -> void:
	_process_ring = Line2D.new()
	_process_ring.width = 4.5
	_process_ring.default_color = Color(0.85, 0.25, 1.0, 0.95) # Violeta cuántico intenso
	add_child(_process_ring)

func check_quantum_recompiler(player_override: Node = null) -> void:
	var target_player: Node = player_override if player_override else (get_tree().get_first_node_in_group("player") if get_tree() else null)
	if target_player and "inventory" in target_player and target_player.inventory:
		var has_recompiler: bool = target_player.inventory.has_method("get_item_count") and target_player.inventory.get_item_count(&"quantum_recompiler") > 0
		if has_recompiler and not _recompiler_applied:
			_recompiler_applied = true
			max_uses = 4
			uses_remaining = mini(4, uses_remaining + 1)
			_update_label()
		elif not has_recompiler and _recompiler_applied:
			_recompiler_applied = false
			max_uses = 3
			uses_remaining = mini(3, uses_remaining)
			_update_label()

func _process(delta: float) -> void:
	if get_tree() and get_tree().paused:
		return

	var tree := get_tree()
	if tree:
		var mg := tree.get_first_node_in_group("main_game")
		if mg and mg.has_method("is_any_combat_modal_active") and mg.is_any_combat_modal_active():
			return

	if visual_root and not is_depleted:
		visual_root.rotation += rotation_speed * delta

	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	# Carga autónoma independiente (el jugador no necesita quedarse en el área)
	if is_processing:
		processing_timer += delta
		var prog := clampf(processing_timer / processing_duration, 0.0, 1.0)
		_update_process_ring(prog)
		var seconds_left := maxf(0.0, processing_duration - processing_timer)
		if status_label:
			status_label.text = "[FORJANDO %d%% (%.1fs)]" % [int(prog * 100.0), seconds_left]
			status_label.modulate = Color(0.95, 0.45, 1.0, 1.0)

		if processing_timer >= processing_duration:
			_complete_processing()
	else:
		# Detección de bumpeo físico del jugador contra la estación
		if not is_depleted and _bump_cooldown <= 0.0:
			_check_bump()

func _check_bump() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		var p_nodes := get_tree().get_nodes_in_group("player")
		if not p_nodes.is_empty():
			_cached_player = p_nodes[0] as Node2D

	if _cached_player and is_instance_valid(_cached_player):
		var effective_bump: float = core_bump_radius * scale.x
		var dist: float = global_position.distance_to(_cached_player.global_position)
		if dist > effective_bump + 35.0:
			must_exit_before_rebump = false
		elif dist <= effective_bump and not must_exit_before_rebump:
			_trigger_bump(_cached_player)

func _trigger_bump(player: Node2D) -> void:
	if _bump_cooldown > 0.0 or must_exit_before_rebump:
		return

	if is_depleted or uses_remaining <= 0:
		_bump_cooldown = 0.5
		var spawn_parent: Node = get_parent()
		if spawn_parent:
			FloatingText.spawn(spawn_parent, global_position + Vector2(0, -50), "¡FORJA AGOTADA!", Color(0.7, 0.7, 0.7))
		return

	if is_processing:
		_bump_cooldown = 0.5
		var spawn_parent: Node = get_parent()
		if spawn_parent:
			FloatingText.spawn(spawn_parent, global_position + Vector2(0, -50), "¡FORJANDO EN PROCESO!", Color(0.95, 0.45, 1.0))
		return

	if is_instance_valid(active_reward_chest):
		# No reabrir la forja hasta que el cofre actual sea resuelto (aceptado o reciclado)
		_bump_cooldown = 0.5
		if status_label:
			status_label.text = "[RECOGE LA CÁPSULA]"
			status_label.modulate = Color(1.0, 0.8, 0.2, 1.0)
		var spawn_parent: Node = get_parent()
		if spawn_parent:
			FloatingText.spawn(spawn_parent, global_position + Vector2(0, -50), "¡RECOGE LA CÁPSULA PRIMERO!", Color(1.0, 0.8, 0.2))
		return

	# 1. Impulso de repulsión física hacia afuera (Bumper Kickback)
	var diff: Vector2 = player.global_position - global_position
	var bump_dir: Vector2 = diff.normalized() if diff.length_squared() > 1.0 else Vector2.UP
	if "velocity" in player:
		player.set("velocity", bump_dir * 540.0)
	player.global_position += bump_dir * 18.0

	must_exit_before_rebump = true
	_bump_cooldown = 0.8

	# 2. Validar requisitos mínimos (créditos e ítems compatibles) antes de abrir UI
	var check := _can_player_transmute(player)
	if not check.can_open:
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click", 0.6, 2.0)
		var spawn_parent: Node = get_parent()
		if spawn_parent:
			FloatingText.spawn(spawn_parent, global_position + Vector2(0, -50), String(check.reason), Color(1.0, 0.35, 0.35))
		return

	check_quantum_recompiler(player)
	station_activated.emit(self)

func _can_player_transmute(p: Node2D) -> Dictionary:
	var credits: int = int(p.get("run_credits")) if "run_credits" in p else 0
	if credits < 50:
		return {"can_open": false, "reason": "¡CRÉDITOS INSUFICIENTES [50c]!"}
	if not ("inventory" in p and p.inventory):
		return {"can_open": false, "reason": "¡SIN INVENTARIO!"}
	var eligible_count: int = 0
	for entry in p.inventory.get_all_items():
		var it: ItemData = entry.get("data") as ItemData
		if it and TransmutationModal.is_item_eligible_for_transmutation(it):
			eligible_count += 1
	if eligible_count == 0:
		return {"can_open": false, "reason": "¡SIN ÍTEMS COMPATIBLES!"}
	return {"can_open": true, "reason": ""}

func _update_process_ring(progress: float) -> void:
	if not _process_ring:
		return
	_process_ring.clear_points()
	if progress <= 0.001:
		return
	var ring_radius: float = 65.0
	var total_points: int = 48
	var points_to_draw: int = int(float(total_points) * progress)
	points_to_draw = clampi(points_to_draw, 2, total_points + 1)
	for i in range(points_to_draw):
		var angle: float = -PI / 2.0 + (float(i) / float(total_points)) * TAU
		_process_ring.add_point(Vector2(cos(angle), sin(angle)) * ring_radius)
	# Modulación dinámica brillante violeta cuántico -> fucsia sobrecargado
	_process_ring.default_color = Color(0.85, 0.25, 1.0, 0.95).lerp(Color(1.0, 0.45, 1.2, 1.0), progress)
	_process_ring.width = lerpf(4.0, 6.5, progress)

func start_processing(target_item: ItemData, player: Node2D) -> void:
	current_target_item = target_item
	current_processing_player = player
	is_processing = true
	processing_timer = 0.0
	_update_process_ring(0.0)
	if status_label:
		status_label.text = "[FORJANDO 0%% (%.1fs)]" % processing_duration
		status_label.modulate = Color(0.95, 0.45, 1.0, 1.0)

func _complete_processing() -> void:
	is_processing = false
	_update_process_ring(0.0)

	# Instanciar el cofre / cápsula de recompensa que cae al lado de la forja
	if reward_chest_scene and current_target_item:
		var chest = reward_chest_scene.instantiate()
		chest.global_position = global_position + Vector2(75.0, 0.0)
		active_reward_chest = chest
		if chest.has_method("setup"):
			chest.setup(current_target_item, self)
		var parent_node := get_parent()
		if parent_node:
			parent_node.add_child(chest)
			# Animación pop de expulsión
			chest.scale = Vector2(0.2, 0.2)
			var tw := create_tween()
			tw.tween_property(chest, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if status_label:
		status_label.text = "[CÁPSULA LISTA: BUMPEAR]"
		status_label.modulate = Color(0.4, 1.0, 0.6, 1.0)

func _apply_visual_skin() -> void:
	if sprite and ResourceLoader.exists(TEXTURE_BEACON):
		sprite.texture = load(TEXTURE_BEACON) as Texture2D
		sprite.scale = Vector2(0.22, 0.22)

func _draw_radius_circle() -> void:
	if not radius_visual:
		return
	radius_visual.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		radius_visual.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)
	radius_visual.default_color = Color(0.8, 0.3, 1.0, 0.45)

func _on_body_entered(body: Node2D) -> void:
	if is_depleted or is_processing or is_instance_valid(active_reward_chest):
		return
	if body is Player or (body != null and body.is_in_group("player")):
		player_inside = true
		_cached_player = body
		_check_bump()

func _on_body_exited(body: Node2D) -> void:
	if body is Player or (body != null and body.is_in_group("player")):
		player_inside = false
		must_exit_before_rebump = false

func consume_use() -> bool:
	if uses_remaining <= 0 or is_depleted:
		return false
	active_reward_chest = null
	uses_remaining -= 1
	_update_label()
	if uses_remaining <= 0:
		deplete_station()
	return true

func _update_label() -> void:
	if status_label and not is_processing and not is_depleted:
		status_label.text = "FORJA: %d/%d (BUMPEAR)" % [uses_remaining, max_uses]
		status_label.modulate = Color(0.85, 0.5, 1.0, 1.0)

func deplete_station() -> void:
	is_depleted = true
	station_depleted.emit()
	if radius_visual:
		radius_visual.default_color = Color(0.4, 0.4, 0.4, 0.2)
	if status_label:
		status_label.text = "FORJA AGOTADA"
		status_label.modulate = Color(0.5, 0.5, 0.5, 0.8)

	var tw := create_tween()
	tw.tween_property(visual_root, "modulate", Color(0.5, 0.5, 0.6, 0.4), 0.8)

