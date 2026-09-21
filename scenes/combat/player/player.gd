class_name Player
extends CharacterBody2D

@export var character_data: CharacterData
@export var bullet_server: BulletServer

var stats: CharacterStats = CharacterStats.new()
var inventory: InventoryComponent = InventoryComponent.new()

# Dash state
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
const DASH_DURATION: float = 0.25
const DASH_COOLDOWN: float = 1.0
var dash_direction: Vector2 = Vector2.RIGHT

# Bombs & Economy
var bomb_count: int = 2
var run_credits: int = 120
var run_biomass: int = 0

# EXP & Leveling
var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next: float = 40.0
var chosen_stat_cards: Array[StatCardData] = []

# Core Hitbox Node
@onready var hitbox_core: Node2D = $HitboxCore
@onready var weapon_controller: Node2D = $WeaponController

signal health_changed(current: float, max_val: float)
signal bomb_used(remaining: int)
signal credits_changed(amount: int)
signal biomass_changed(amount: int, total_persistent: int)
signal exp_changed(current: float, max_val: float, level: int)
signal level_up_requested(level: int)
signal player_died()

var current_health: float = 100.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	if not character_data or character_data.character_id == &"survivor_default":
		var sel_id := SaveManager.get_selected_character()
		var roster := CharacterData.load_roster()
		if roster.has(sel_id):
			character_data = roster[sel_id]
		elif not roster.is_empty():
			character_data = roster.values()[0]
		else:
			character_data = CharacterData.new()

	_apply_visual_theme()
	stats.initialize(character_data)

	# Aplicar bonos permanentes del Árbol de Habilidades cibernético (4 ramas)
	if character_data and character_data.character_id:
		var unlocked_nodes := SaveManager.get_character_unlocked_nodes(character_data.character_id)
		var speed_count: int = 0
		var damage_count: int = 0
		var hp_count: int = 0
		var crit_count: int = 0

		for nid in unlocked_nodes:
			var s := String(nid)
			if s.begins_with("speed_") or s in ["0", "1", "2", "3", "4"]:
				speed_count += 1
			elif s.begins_with("damage_"):
				damage_count += 1
			elif s.begins_with("hp_") or s.begins_with("hull_"):
				hp_count += 1
			elif s.begins_with("crit_") or s.begins_with("overclock_") or s.begins_with("focus_"):
				crit_count += 1

		if speed_count > 0:
			stats.add_modifier(&"move_speed", CharacterStats.StatModifier.new(&"skill_tree_speed", float(speed_count) * 0.20, true, self))
		if damage_count > 0:
			stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"skill_tree_damage", float(damage_count) * 0.15, true, self))
		if hp_count > 0:
			stats.add_modifier(&"max_health", CharacterStats.StatModifier.new(&"skill_tree_hp", float(hp_count) * 25.0, false, self))
		if crit_count > 0:
			stats.add_modifier(&"crit_chance", CharacterStats.StatModifier.new(&"skill_tree_crit", float(crit_count) * 0.05, false, self))
			stats.add_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"skill_tree_atk_speed", float(crit_count) * 0.05, true, self))

	current_health = stats.get_stat(&"max_health")
	stats.stat_changed.connect(func(stat_name: StringName, new_val: float):
		if stat_name == &"max_health":
			current_health = minf(current_health + 20.0, new_val)
			health_changed.emit(current_health, new_val)
	)

	inventory.character_stats = stats
	add_child(inventory)

	if bullet_server:
		bullet_server.player_hit.connect(_on_bullet_hit)
		bullet_server.player_grazed.connect(_on_bullet_grazed)

	# Equipar arma inicial del personaje en el WeaponController
	var w_ctrl := get_node_or_null("WeaponController") as WeaponController
	if w_ctrl and character_data and character_data.starting_weapon:
		w_ctrl.equipped_weapons.clear()
		w_ctrl.add_weapon(character_data.starting_weapon)


func _apply_visual_theme() -> void:
	if not character_data:
		return
	var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
	if placeholder:
		placeholder.color = character_data.color
		placeholder.visible = true
		if character_data.pts.size() >= 3:
			var scaled_pts := PackedVector2Array()
			for pt in character_data.pts:
				scaled_pts.append(pt * 0.35)
			placeholder.polygon = scaled_pts

func _physics_process(delta: float) -> void:
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_actions()

	# Orientación 360° del exotraje hacia el apuntado
	var exo_spr := get_node_or_null("ExoArmorSprite") as Sprite2D
	if exo_spr:
		exo_spr.rotation = (get_global_mouse_position() - global_position).angle() + PI / 2.0

	if bullet_server:
		bullet_server.player_pos = global_position
		bullet_server.player_invulnerable = is_dashing

func _handle_movement(delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * (stats.get_stat(&"move_speed") * 2.5)
		move_and_slide()
		return

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	var speed: float = stats.get_stat(&"move_speed")
	velocity = velocity.move_toward(input_vector * speed, speed * 8.0 * delta)
	move_and_slide()

func _handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_direction = velocity.normalized() if velocity.length_squared() > 0.1 else (get_global_mouse_position() - global_position).normalized()
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("dash")

func _handle_actions() -> void:
	if Input.is_action_just_pressed("bomb") and bomb_count > 0:
		bomb_count -= 1
		bomb_used.emit(bomb_count)
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("bomb")
		if bullet_server:
			bullet_server.bomb_clear_all()

func add_credits(amount: int) -> void:
	run_credits += amount
	credits_changed.emit(run_credits)

func add_biomass(amount: int) -> void:
	if amount <= 0:
		return
	run_biomass += amount
	var total_persistent := SaveManager.add_biomass(amount)
	biomass_changed.emit(run_biomass, total_persistent)

func add_exp(amount: float) -> void:
	current_exp += amount
	if current_exp >= exp_to_next:
		current_exp -= exp_to_next
		current_level += 1
		exp_to_next *= 1.35
		level_up_requested.emit(current_level)
	exp_changed.emit(current_exp, exp_to_next, current_level)

func take_damage(amount: float) -> void:
	if is_dashing:
		return
	current_health -= amount
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("player_hit")
	health_changed.emit(current_health, stats.get_stat(&"max_health"))
	if current_health <= 0.0:
		player_died.emit()

func _on_bullet_hit() -> void:
	take_damage(10.0)

func _on_bullet_grazed(bullet_pos: Vector2) -> void:
	add_exp(2.0) # Cada roce con balas suma experiencia
