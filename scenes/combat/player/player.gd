class_name Player
extends CharacterBody2D

@export var character_data: CharacterData
@export var bullet_server: BulletServer

var stats: CharacterStats = CharacterStats.new()
var inventory: InventoryComponent = InventoryComponent.new()

# Dash & Mobility State (Unique per Character)
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var dash_charges: int = 1
var max_dash_charges: int = 1
var dash_recharge_timer: float = 0.0
var dash_recharge_max: float = 1.6
var dash_internal_cd: float = 0.2
var _internal_cd_timer: float = 0.0

# Valentina: Sobre-Enfoque (Bullet-Time Focus & Guaranteed Crit)
var is_focus_active: bool = false
var focus_timer: float = 0.0
var has_guaranteed_crit: bool = false

# Roxy: Embestida Sísmica (Contact Damage flag)
var roxy_ram_hit_enemies: Array[Node2D] = []

# Dash VFX Scenes
var fire_trail_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/fire_trail_hazard.tscn")
var decoy_mine_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/decoy_drone_mine.tscn")
var vacuum_pulse_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/vacuum_phase_pulse.tscn")
var chain_scene: PackedScene = preload("res://scenes/combat/weapons/chain_lightning_effect.tscn")
var bomb_shockwave_scene: PackedScene = preload("res://scenes/combat/player/bomb_shockwave_vfx.tscn")

# Bombs & Economy
var bomb_count: int = 2
var run_credits: int = 120
var run_biomass: int = 0
var _menu_close_suppress_timer: float = 0.0
var _was_bomb_pressed_during_menu: bool = false

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
signal dash_updated(current_charges: int, max_charges: int, recharge_ratio: float, is_focus: bool)
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
	_setup_character_dash()
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

	# Aplicar trampas y modificadores de stats del Modo Debug si está activo
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("apply_to_player"):
		debug_mgr.apply_to_player(self)


func _apply_visual_theme() -> void:
	if not character_data:
		return

	var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
	var ship_tex: Texture2D = character_data.get_ship_texture() if character_data.has_method("get_ship_texture") else null

	var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
	if not ship_spr and ship_tex:
		ship_spr = Sprite2D.new()
		ship_spr.name = "ShipSprite"
		add_child(ship_spr)
		move_child(ship_spr, 0)

	if ship_spr:
		if ship_tex:
			ship_spr.texture = ship_tex
			ship_spr.visible = true
			ship_spr.scale = Vector2(0.42, 0.42)
			if placeholder:
				placeholder.visible = false
		else:
			ship_spr.visible = false
			if placeholder:
				placeholder.visible = true

	if placeholder and (not ship_spr or not ship_spr.visible):
		placeholder.color = character_data.color
		placeholder.visible = true
		if character_data.pts.size() >= 3:
			var scaled_pts := PackedVector2Array()
			for pt in character_data.pts:
				scaled_pts.append(pt * 0.35)
			placeholder.polygon = scaled_pts

	# Configurar sprite del arma rotatoria en WeaponController
	var w_ctrl := get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		var w_tex: Texture2D = character_data.get_weapon_texture() if character_data.has_method("get_weapon_texture") else null
		var w_spr := w_ctrl.get_node_or_null("WeaponSprite") as Sprite2D
		var w_poly := w_ctrl.get_node_or_null("WeaponVisual") as Polygon2D
		if not w_spr and w_tex:
			w_spr = Sprite2D.new()
			w_spr.name = "WeaponSprite"
			w_ctrl.add_child(w_spr)
		if w_spr:
			if w_tex:
				w_spr.texture = w_tex
				w_spr.position = Vector2(16, 0)
				w_spr.scale = Vector2(0.35, 0.35)
				w_spr.visible = true
				if w_poly:
					w_poly.visible = false
			else:
				w_spr.visible = false
				if w_poly:
					w_poly.visible = true

func _physics_process(delta: float) -> void:
	if _menu_close_suppress_timer > 0.0:
		_menu_close_suppress_timer = maxf(0.0, _menu_close_suppress_timer - delta)

	if is_any_menu_or_modal_active():
		if Input.is_action_pressed("bomb"):
			_was_bomb_pressed_during_menu = true
	elif _was_bomb_pressed_during_menu:
		if not Input.is_action_pressed("bomb"):
			_was_bomb_pressed_during_menu = false

	_handle_dash(delta)
	_handle_movement(delta)
	_handle_actions()
	_handle_health_regen(delta)

	# Orientación 360° de la nave hacia el apuntado (offset de PI/2 por estar dibujada hacia ARRIBA)
	var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
	if ship_spr and ship_spr.visible:
		ship_spr.rotation = (get_global_mouse_position() - global_position).angle() + PI / 2.0
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

func _setup_character_dash() -> void:
	var cid := String(character_data.character_id) if character_data else "nova"
	match cid:
		"nova":
			max_dash_charges = 2
			dash_charges = 2
			dash_recharge_max = 1.0
			dash_internal_cd = 0.15
		"valentina":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.8
			dash_internal_cd = 0.25
		"kira":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.4
			dash_internal_cd = 0.2
		"selene":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.6
			dash_internal_cd = 0.2
		"roxy":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.8
			dash_internal_cd = 0.25
		"echo":
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.2
			dash_internal_cd = 0.2
		_:
			max_dash_charges = 1
			dash_charges = 1
			dash_recharge_max = 1.6
			dash_internal_cd = 0.2
	dash_recharge_timer = 0.0

func _handle_dash(delta: float) -> void:
	# Ajuste de delta cuando está activo el Bullet-Time de Valentina
	var unscaled_delta: float = delta / maxf(0.1, Engine.time_scale)

	# 1. Temporizador de enfriamiento interno entre cargas consecutivas
	if _internal_cd_timer > 0.0:
		_internal_cd_timer -= unscaled_delta

	# 2. Recarga pasiva de cargas de dash
	if dash_charges < max_dash_charges:
		dash_recharge_timer += unscaled_delta
		if dash_recharge_timer >= dash_recharge_max:
			dash_recharge_timer = 0.0
			dash_charges = mini(max_dash_charges, dash_charges + 1)
			dash_updated.emit(dash_charges, max_dash_charges, 1.0, is_focus_active)
		else:
			dash_updated.emit(dash_charges, max_dash_charges, dash_recharge_timer / dash_recharge_max, is_focus_active)
	else:
		dash_recharge_timer = 0.0

	# 3. Temporizador de Sobre-Enfoque (Valentina)
	if is_focus_active:
		focus_timer -= unscaled_delta
		if focus_timer <= 0.0:
			is_focus_active = false
			Engine.time_scale = 1.0
			dash_updated.emit(dash_charges, max_dash_charges, 1.0 if dash_charges >= max_dash_charges else (dash_recharge_timer / dash_recharge_max), false)

	# 4. Estado activo de Dash e invulnerabilidad
	if is_dashing:
		dash_timer -= delta
		if character_data and character_data.character_id == &"roxy":
			_process_roxy_ram_collision()

		if dash_timer <= 0.0:
			is_dashing = false

	# 5. Entrada del jugador para ejecutar Dash
	if Input.is_action_just_pressed("dash") and not is_dashing and _internal_cd_timer <= 0.0 and dash_charges > 0:
		dash_charges -= 1
		_internal_cd_timer = dash_internal_cd
		_execute_character_dash()
		dash_updated.emit(dash_charges, max_dash_charges, dash_recharge_timer / dash_recharge_max, is_focus_active)

func _execute_character_dash() -> void:
	var cid := String(character_data.character_id) if character_data else "nova"
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	dash_direction = aim_dir

	match cid:
		"nova":
			_execute_nova_dash()
		"valentina":
			_execute_valentina_dash()
		"kira":
			_execute_kira_dash()
		"selene":
			_execute_selene_dash()
		"roxy":
			_execute_roxy_dash()
		"echo":
			_execute_echo_dash()
		_:
			_execute_nova_dash()

func _execute_nova_dash() -> void:
	is_dashing = true
	dash_timer = 0.25
	var hazard := fire_trail_scene.instantiate()
	if hazard and hazard.has_method("setup"):
		hazard.setup(global_position, dash_direction, self)
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child(hazard)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.2, 0.0)

func _execute_valentina_dash() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	dash_direction = -aim_dir
	is_dashing = true
	dash_timer = 0.22
	is_focus_active = true
	focus_timer = 1.5
	has_guaranteed_crit = true
	Engine.time_scale = 0.55

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.6, 2.0)

func _execute_kira_dash() -> void:
	is_dashing = true
	dash_timer = 0.25
	var mine := decoy_mine_scene.instantiate()
	if mine and mine.has_method("setup"):
		mine.setup(global_position, self)
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child(mine)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.4, -2.0)

func _execute_selene_dash() -> void:
	is_dashing = true
	dash_timer = 0.15
	var teleport_dist := 240.0
	global_position += dash_direction * teleport_dist

	var pulse := vacuum_pulse_scene.instantiate()
	if pulse and pulse.has_method("setup"):
		pulse.setup(global_position, self)
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child(pulse)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 0.7, 1.0)

func _execute_roxy_dash() -> void:
	is_dashing = true
	dash_timer = 0.32
	roxy_ram_hit_enemies.clear()

	if bullet_server and bullet_server.has_method("clear_bullets_in_arc"):
		bullet_server.clear_bullets_in_arc(global_position, dash_direction, 120.0, 180.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 1.6, 2.0)

func _process_roxy_ram_collision() -> void:
	var tree := get_tree()
	if not tree:
		return
	var ram_radius_sq := 48.0 * 48.0
	for enemy in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is Node2D and not roxy_ram_hit_enemies.has(enemy):
			if global_position.distance_squared_to(enemy.global_position) <= ram_radius_sq:
				roxy_ram_hit_enemies.append(enemy)
				if enemy.has_method("take_damage"):
					var ctx := HitContext.new()
					ctx.attacker = self
					ctx.raw_damage = 35.0
					ctx.final_damage = 35.0
					ctx.hit_position = global_position
					enemy.take_damage(ctx)
				if "velocity" in enemy:
					enemy.velocity += dash_direction * 300.0

func _execute_echo_dash() -> void:
	is_dashing = true
	dash_timer = 0.15
	var teleport_dist := 200.0
	global_position += dash_direction * teleport_dist

	var nearest_enemy: Node2D = null
	var min_d_sq := 400.0 * 400.0
	var tree := get_tree()
	if tree:
		for enemy in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is Node2D:
				var d_sq := global_position.distance_squared_to(enemy.global_position)
				if d_sq < min_d_sq:
					min_d_sq = d_sq
					nearest_enemy = enemy

	if nearest_enemy:
		var chain := chain_scene.instantiate()
		if chain and chain.has_method("setup"):
			var ctx := HitContext.new()
			ctx.attacker = self
			ctx.raw_damage = 40.0
			ctx.final_damage = 40.0
			ctx.hit_position = global_position
			chain.setup(global_position, nearest_enemy.global_position, ctx, 5)
			var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
			if spawn_parent:
				spawn_parent.add_child(chain)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.8, 1.0)

func consume_guaranteed_crit() -> bool:
	if has_guaranteed_crit:
		has_guaranteed_crit = false
		return true
	return false


func suppress_bomb_input(duration: float = 0.35) -> void:
	_menu_close_suppress_timer = maxf(_menu_close_suppress_timer, duration)
	_was_bomb_pressed_during_menu = true

func is_any_menu_or_modal_active() -> bool:
	if not is_inside_tree():
		return false
	var parent_node := get_parent()
	if parent_node:
		if parent_node.has_method("is_any_combat_modal_active") and parent_node.is_any_combat_modal_active():
			return true
		if parent_node.has_method("is_pause_menu_active") and parent_node.is_pause_menu_active():
			return true
		if parent_node.has_method("is_level_up_modal_active") and parent_node.is_level_up_modal_active():
			return true
		if parent_node.has_method("is_satellite_shop_active") and parent_node.is_satellite_shop_active():
			return true
		if parent_node.has_method("is_character_stats_active") and parent_node.is_character_stats_active():
			return true
		if parent_node.has_method("is_dialogue_active") and parent_node.is_dialogue_active():
			return true

	var dialogic = get_node_or_null("/root/Dialogic")
	if dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null:
		return true

	var vp := get_viewport()
	if vp:
		var focused := vp.gui_get_focus_owner()
		if focused and focused.is_visible_in_tree():
			return true

	return false

func _can_trigger_bomb() -> bool:
	var debug_mgr = get_node_or_null("/root/DebugManager")
	var inf_consumables: bool = debug_mgr and debug_mgr.has_method("is_infinite_consumables_active") and debug_mgr.is_infinite_consumables_active()
	if bomb_count <= 0 and not inf_consumables:
		return false
	if get_tree() and get_tree().paused:
		return false
	if _menu_close_suppress_timer > 0.0:
		return false
	if _was_bomb_pressed_during_menu:
		return false
	if is_any_menu_or_modal_active():
		return false
	return true

func _execute_bomb() -> void:
	if not _can_trigger_bomb():
		return
	var debug_mgr = get_node_or_null("/root/DebugManager")
	var inf_consumables: bool = debug_mgr and debug_mgr.has_method("is_infinite_consumables_active") and debug_mgr.is_infinite_consumables_active()
	if not inf_consumables:
		bomb_count -= 1
	bomb_used.emit(bomb_count)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("bomb")
	if bullet_server:
		bullet_server.bomb_clear_all()
	_spawn_bomb_vfx()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bomb") and not event.is_echo():
		if _can_trigger_bomb():
			_execute_bomb()
			get_viewport().set_input_as_handled()

func _handle_actions() -> void:
	# Las bombas ahora se procesan de forma segura a través de _unhandled_input(event)
	# para garantizar que la barra espaciadora en menús, tiendas y diálogos nunca consuma bombas.
	pass

func add_bombs(amount: int = 1) -> bool:
	const MAX_BOMBS: int = 5
	if bomb_count < MAX_BOMBS:
		bomb_count = mini(MAX_BOMBS, bomb_count + amount)
		bomb_used.emit(bomb_count)
		return true
	else:
		# Límite alcanzado: detonación táctica inmediata
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("bomb")
		if bullet_server:
			bullet_server.bomb_clear_all()
		_spawn_bomb_vfx()
		return false

func _spawn_bomb_vfx(at_position: Vector2 = global_position) -> void:
	if not bomb_shockwave_scene:
		return
	var vfx := bomb_shockwave_scene.instantiate()
	if vfx:
		if vfx.has_method("setup"):
			vfx.setup(at_position)
		else:
			vfx.global_position = at_position
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child(vfx)

func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	var max_hp: float = stats.get_stat(&"max_health") if stats else 100.0
	current_health = minf(max_hp, current_health + amount)
	health_changed.emit(current_health, max_hp)

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
	var exp_mult: float = stats.get_stat(&"exp_multiplier") if stats else 1.0
	var effective_amount: float = amount * maxf(0.1, exp_mult)
	current_exp += effective_amount
	if current_exp >= exp_to_next:
		current_exp -= exp_to_next
		current_level += 1
		exp_to_next *= 1.35
		level_up_requested.emit(current_level)
	exp_changed.emit(current_exp, exp_to_next, current_level)

func take_damage(amount: float) -> void:
	if is_dashing:
		return
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_hp_active") and debug_mgr.is_infinite_hp_active():
		return
	var armor_val: float = stats.get_stat(&"armor") if stats else 0.0
	var mitigated_dmg: float = amount
	if armor_val >= 0.0:
		mitigated_dmg = maxf(1.0, amount * (100.0 / (100.0 + armor_val)))
	else:
		mitigated_dmg = amount * (2.0 - (100.0 / (100.0 - armor_val)))

	current_health -= mitigated_dmg
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("player_hit")
	health_changed.emit(current_health, stats.get_stat(&"max_health"))
	if current_health <= 0.0:
		player_died.emit()

func _handle_health_regen(delta: float) -> void:
	if not stats:
		return
	var max_hp := stats.get_stat(&"max_health")
	if current_health < max_hp and current_health > 0.0:
		var regen := stats.get_stat(&"health_regen")
		if regen > 0.0:
			var old_val := current_health
			current_health = minf(max_hp, current_health + regen * delta)
			if int(old_val * 2.0) != int(current_health * 2.0) or current_health >= max_hp:
				health_changed.emit(current_health, max_hp)

func _on_bullet_hit() -> void:
	take_damage(10.0)

func _on_bullet_grazed(bullet_pos: Vector2) -> void:
	add_exp(2.0) # Cada roce con balas suma experiencia y escala con exp_multiplier
