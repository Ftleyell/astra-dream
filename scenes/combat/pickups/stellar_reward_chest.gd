class_name StellarRewardChest
extends Area2D

## StellarRewardChest.gd
## Cofre Estelar de Recompensa de Piloto Rival.
## Drop especial de meta-progresión liberado al abatir al rival del sector.
## Otorga BioMasa, Materia Oscura y Antimateria a SaveManager y al Player.

signal collected(biomass: int, dark_matter: int, antimatter: int)

@export_group("Rewards")
@export var reward_biomass: int = 150
@export var reward_dark_matter: int = 50
@export var reward_antimatter: int = 10

@export_group("Pickup Mechanics")
@export var pickup_radius: float = 260.0
@export var collect_radius: float = 34.0
@export var magnet_accel: float = 1800.0
@export var max_magnet_speed: float = 900.0
@export var pulse_speed: float = 4.0

var player: Node2D = null
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var magnet_speed: float = 0.0
var lifetime: float = 0.0

@onready var visual_root: Node2D = get_node_or_null("VisualRoot")
@onready var aura_hexagon: Polygon2D = get_node_or_null("VisualRoot/AuraHexagon")
@onready var orbit_ring: Line2D = get_node_or_null("VisualRoot/OrbitRing")
@onready var core_gem: Polygon2D = get_node_or_null("VisualRoot/CoreGem")
@onready var label_name: Label = get_node_or_null("LabelName")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("pickups")
	add_to_group("stellar_chests")

	# Impulso inicial radial para separación con otros drops simultáneos
	var angle := randf_range(-PI, PI)
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(50.0, 110.0)

	_sync_metadata()

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(p_pos: Vector2, p_biomass: int = 150, p_dark_matter: int = 50, p_antimatter: int = 10) -> void:
	global_position = p_pos
	reward_biomass = max(0, p_biomass)
	reward_dark_matter = max(0, p_dark_matter)
	reward_antimatter = max(0, p_antimatter)
	_sync_metadata()


func setup_from_sector(p_sector: Resource) -> void:
	if not p_sector:
		return
	if "reward_biomass" in p_sector:
		reward_biomass = max(0, int(p_sector.reward_biomass))
	if "reward_dark_matter" in p_sector:
		reward_dark_matter = max(0, int(p_sector.reward_dark_matter))
	if "reward_antimatter" in p_sector:
		reward_antimatter = max(0, int(p_sector.reward_antimatter))
	_sync_metadata()


func _sync_metadata() -> void:
	set_meta("reward_biomass", reward_biomass)
	set_meta("reward_dark_matter", reward_dark_matter)
	set_meta("reward_antimatter", reward_antimatter)


func _process(delta: float) -> void:
	if is_collected:
		return

	lifetime += delta
	var t := lifetime * pulse_speed
	var s := 1.0 + sin(t) * 0.16

	if orbit_ring:
		orbit_ring.rotation += delta * 2.5
	if aura_hexagon:
		aura_hexagon.scale = Vector2(s, s)
		aura_hexagon.rotation -= delta * 1.2
	if core_gem:
		core_gem.rotation += delta * 3.0
	if visual_root:
		visual_root.position.y = sin(lifetime * 3.6) * 3.0


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	# Fricción del impulso inicial
	if velocity.length_squared() > 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, 130.0 * delta)
		global_position += velocity * delta

	# Localización del jugador
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if not player:
			return

	# B2.4 Permadeath Precedence: Jugador muerto no puede recolectar
	if _is_player_dead():
		return

	# Magnetismo de proximidad
	var effective_radius := pickup_radius
	if is_instance_valid(player) and "stats" in player and player.stats:
		effective_radius = maxf(pickup_radius, player.stats.get_stat(&"pickup_radius"))

	var dist := global_position.distance_to(player.global_position)
	if dist <= effective_radius:
		magnet_speed = move_toward(magnet_speed, max_magnet_speed, magnet_accel * delta)
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

		if dist <= collect_radius:
			_collect()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		_collect()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if not is_instance_valid(player):
			player = area
		_collect()
	elif area.owner and area.owner.is_in_group("player"):
		if not is_instance_valid(player) and area.owner is Node2D:
			player = area.owner as Node2D
		_collect()


func _is_player_dead() -> bool:
	var target_player := player
	if not is_instance_valid(target_player) and is_inside_tree():
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(target_player):
			player = target_player

	if not is_instance_valid(target_player):
		return false
	if "is_dead" in target_player and target_player.is_dead:
		return true
	if "current_health" in target_player and target_player.current_health <= 0.0:
		return true
	return false


func _collect() -> void:
	# B2.5 Rapid Double-Collection Prevention / Debounce
	if is_collected:
		return
	is_collected = true

	# B2.4 Precedencia de muerte
	if _is_player_dead():
		is_collected = false
		return

	set_physics_process(false)
	set_process(false)

	# 1. Dispensación de BioMasa
	if is_instance_valid(player) and player.has_method("add_biomass"):
		player.add_biomass(reward_biomass)
	else:
		SaveManager.add_biomass(reward_biomass)

	# 2. Dispensación de Materia Oscura
	if is_instance_valid(player) and player.has_method("add_dark_matter"):
		player.add_dark_matter(reward_dark_matter)
	else:
		SaveManager.add_dark_matter(reward_dark_matter)

	# 3. Dispensación de Antimateria
	if is_instance_valid(player) and player.has_method("add_antimatter"):
		player.add_antimatter(reward_antimatter)
	else:
		SaveManager.add_antimatter(reward_antimatter)

	# Emitir señal
	collected.emit(reward_biomass, reward_dark_matter, reward_antimatter)

	# SFX
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("heal", 1.35)

	# Feedback visual / flotante
	_spawn_feedback()

	# Animación de implosión / pop y queue_free
	var tw := create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(self, "scale", scale * 1.6, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()


func _spawn_feedback() -> void:
	var parent_node := get_parent()
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene
	if not parent_node:
		return

	var floating_text_script = load("res://scenes/ui/floating_text.gd")
	if floating_text_script and floating_text_script.has_method("spawn"):
		floating_text_script.spawn(parent_node, global_position + Vector2(0, -22), "+%d BIOMASA" % reward_biomass, Color(0.2, 1.0, 0.6))
		floating_text_script.spawn(parent_node, global_position + Vector2(0, -42), "+%d MATERIA OSCURA" % reward_dark_matter, Color(0.85, 0.25, 1.0))
		floating_text_script.spawn(parent_node, global_position + Vector2(0, -62), "+%d ANTIMATERIA" % reward_antimatter, Color(0.2, 0.9, 1.0))
