class_name SlotMachineBeacon
extends Node2D

## Máquina Tragamonedas In-Run tipo Bumper Arcade 100% In-Game.
## El jugador la choca físicamente ("bump"), rebota suavemente hacia atrás,
## descuenta los créditos y hace girar los 3 rodillos sobre la propia máquina
## en tiempo real sin abrir ventanas modales ni pausar la partida.

signal interacted(beacon: SlotMachineBeacon)
signal exploded(pos: Vector2)
signal spin_started()
signal spin_resolved(outcome: Dictionary)

const DefaultConfig = preload("res://data/interactables/default_slot_machine_config.tres")
const SlotMachineMarqueeDisplayClass = preload("res://scenes/combat/satellite/components/slot_machine_marquee_display.gd")
const SlotMachinePayoutEngineClass = preload("res://scenes/combat/satellite/components/slot_machine_payout_engine.gd")

@export var config: Resource = DefaultConfig
@export var bumper_radius: float = 46.0

var remaining_uses: int = 3
var current_spin_cost: int = 50
var cost_increment: int = 25

var is_rolling: bool = false
var is_exploded: bool = false
var _is_tearing_down: bool = false
var _bump_cooldown: float = 0.0

var symbols: Array[String] = ["💰", "💣", "🧲", "💖", "⭐"]

# Nodos visuales in-game
var _visual_core: CanvasItem
var _radius_visual: Line2D
var _area: Area2D
var _marquee: Node2D

func _ready() -> void:
	add_to_group("slot_machine_beacon")
	scale = Vector2(2.0, 2.0)
	if config:
		bumper_radius = config.bumper_radius
		current_spin_cost = config.base_spin_cost
		cost_increment = config.cost_increment
		symbols = config.symbols.duplicate()
		if remaining_uses <= 0:
			remaining_uses = randi_range(config.min_uses, config.max_uses)
	elif remaining_uses <= 0:
		remaining_uses = randi_range(3, 5)

	_setup_visuals()
	_marquee = SlotMachineMarqueeDisplayClass.new()
	add_child(_marquee)
	_marquee.setup_display(self)
	_marquee.update_info_display(current_spin_cost, remaining_uses)
	_setup_area()

func _setup_visuals() -> void:
	var sprite := Sprite2D.new()
	var tex: Texture2D = load("res://assets/sprites/interactables/slot_machine_beacon.png") as Texture2D
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.24, 0.24)
	_visual_core = sprite
	add_child(_visual_core)

	_radius_visual = Line2D.new()
	_radius_visual.width = 2.5
	_radius_visual.default_color = Color(1.0, 0.85, 0.2, 0.7)
	var points: int = 32
	for i: int in range(points + 1):
		var angle: float = float(i) * TAU / float(points)
		_radius_visual.add_point(Vector2(cos(angle), sin(angle)) * bumper_radius)
	add_child(_radius_visual)

func _setup_area() -> void:
	_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = bumper_radius
	col.shape = shape
	_area.add_child(col)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)

func _exit_tree() -> void:
	_is_tearing_down = true
	if is_instance_valid(_area) and _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.disconnect(_on_body_entered)

func _process(delta: float) -> void:
	if is_exploded or _is_tearing_down:
		return

	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	var bob: float = sin(Time.get_ticks_msec() * 0.003) * 0.35 * delta * 60.0
	position.y += bob

	if _visual_core:
		var pulse: float = 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
		_visual_core.modulate = Color(1.0 * pulse, 0.82 * pulse, 0.15, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if _is_tearing_down or is_exploded or not is_inside_tree() or is_queued_for_deletion():
		return
	if body != null and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	if body is Player or body.is_in_group("player"):
		handle_player_bump(body as Player)

func handle_player_bump(player: Player) -> void:
	if _bump_cooldown > 0.0 or is_exploded:
		return
	_bump_cooldown = 0.28

	var diff: Vector2 = player.global_position - global_position
	var bump_dir: Vector2 = diff.normalized() if diff.length_squared() > 1.0 else Vector2.UP

	if "velocity" in player:
		player.velocity = bump_dir * 540.0
	player.global_position += bump_dir * 14.0

	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2(2.56, 1.52)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.24)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click")

	if is_rolling:
		_marquee.show_flash_msg("🎰 ¡RODILLOS GIRANDO!", Color(0.2, 0.95, 1.0))
		return

	if remaining_uses <= 0:
		return

	if player.run_credits < current_spin_cost:
		_marquee.show_flash_msg("❌ ¡FALTAN CRÉDITOS! (%d CR)" % current_spin_cost, Color(1.0, 0.35, 0.35))
		_marquee.spawn_floating_text(self, "¡Créditos insuficientes! (%d CR)" % current_spin_cost, Color(1.0, 0.35, 0.35))
		return

	player.run_credits -= current_spin_cost
	var main_scene: Node = get_tree().current_scene
	if main_scene and "hud" in main_scene and main_scene.hud:
		main_scene.hud.update_credits(player.run_credits)

	interacted.emit(self)
	_start_in_game_spin(player)

func _start_in_game_spin(player: Player) -> void:
	is_rolling = true
	spin_started.emit()
	_marquee.show_flash_msg("🎰 ¡GIRANDO...!", Color(1.0, 0.85, 0.2))

	var spin_cost: int = current_spin_cost
	var jackpot_chance: float = config.jackpot_chance if config else 0.18
	var pair_chance: float = config.pair_chance if config else 0.65
	var final_symbols: Array[String] = SlotMachinePayoutEngineClass.roll_symbols(symbols, jackpot_chance, pair_chance)

	await _marquee.animate_spin(symbols, final_symbols, get_tree())

	if not is_inside_tree() or is_exploded or _is_tearing_down:
		return

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click")

	var payout: Dictionary = SlotMachinePayoutEngineClass.evaluate_payout(final_symbols, spin_cost)
	if is_instance_valid(player):
		SlotMachinePayoutEngineClass.apply_payout(payout, player, get_tree(), self, _marquee, current_spin_cost)

	consume_spin()
	_marquee.update_info_display(current_spin_cost, remaining_uses)
	spin_resolved.emit(payout)
	is_rolling = false

	if remaining_uses <= 0:
		_marquee.show_flash_msg("⚠️ ¡DETONACIÓN INMINENTE! ⚠️", Color(1.0, 0.25, 0.25))
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(0.65, false, false, true).timeout
		if is_inside_tree() and not is_exploded:
			trigger_explosion()

func get_current_cost() -> int:
	return current_spin_cost

func has_uses_remaining() -> bool:
	return remaining_uses > 0

func record_use() -> void:
	consume_spin()

func consume_spin() -> void:
	remaining_uses -= 1
	current_spin_cost += cost_increment

func trigger_explosion() -> void:
	if is_exploded:
		return
	is_exploded = true
	var exp_pos: Vector2 = position if position != Vector2.ZERO else global_position
	exploded.emit(exp_pos)
	queue_free()

static func evaluate_payout(symbols: Array, spin_cost: int = 50) -> Dictionary:
	return SlotMachinePayoutEngineClass.evaluate_payout(symbols, spin_cost)
