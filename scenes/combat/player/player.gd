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

# Nova: Omega Spin (Láser giratorio 360° continuo en dash)
var is_omega_spinning: bool = false
var omega_spin_angle: float = 0.0

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
var nova_spin_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/nova_spin_360_laser.tscn")
var bomb_shockwave_scene: PackedScene = preload("res://scenes/combat/player/bomb_shockwave_vfx.tscn")
var explosion_vfx_scene: PackedScene = preload("res://scenes/combat/player/player_explosion_vfx.tscn")
var cut_line_scene: PackedScene = preload("res://scenes/combat/player/dash_effects/dimensional_cut_line.tscn")

var is_dead: bool = false

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
var active_arcanas: Array[ArcanaData] = []
var run_dark_matter: int = 0

# Core Hitbox Node
@onready var hitbox_core: Node2D = $HitboxCore
@onready var weapon_controller: Node2D = $WeaponController

signal health_changed(current: float, max_val: float)
signal bomb_used(remaining: int)
signal credits_changed(amount: int)
signal biomass_changed(amount: int, total_persistent: int)
signal dark_matter_changed(amount: int, total_persistent: int)
signal arcana_applied(arcana: ArcanaData)
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
		if character_data.character_id == &"nyx":
			var nyx_speed: int = 0
			var nyx_dmg: int = 0
			var nyx_hp: int = 0
			var nyx_crit: int = 0
			var has_speed_3: bool = false
			var has_dmg_3: bool = false
			var has_hp_3: bool = false
			var has_crit_3: bool = false

			for nid in unlocked_nodes:
				var s := String(nid)
				if s.begins_with("nyx_speed_") or s.begins_with("speed_"):
					nyx_speed += 1
					if s == "nyx_speed_3": has_speed_3 = true
				elif s.begins_with("nyx_dmg_") or s.begins_with("damage_"):
					nyx_dmg += 1
					if s == "nyx_dmg_3": has_dmg_3 = true
				elif s.begins_with("nyx_hp_") or s.begins_with("hp_"):
					nyx_hp += 1
					if s == "nyx_hp_3": has_hp_3 = true
				elif s.begins_with("nyx_crit_") or s.begins_with("crit_"):
					nyx_crit += 1
					if s == "nyx_crit_3": has_crit_3 = true

			if nyx_speed > 0:
				stats.add_modifier(&"move_speed", CharacterStats.StatModifier.new(&"skill_tree_speed", float(nyx_speed) * 0.18, true, self))
			if has_speed_3:
				dash_recharge_max *= 0.85
			if nyx_dmg > 0:
				stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"skill_tree_damage", float(nyx_dmg) * 0.18, true, self))
			if has_dmg_3:
				stats.add_modifier(&"weapon_size", CharacterStats.StatModifier.new(&"nyx_weapon_size", 0.15, true, self))
			if nyx_hp > 0:
				stats.add_modifier(&"max_health", CharacterStats.StatModifier.new(&"skill_tree_hp", float(nyx_hp) * 30.0, false, self))
			if has_hp_3:
				stats.add_modifier(&"health_regen", CharacterStats.StatModifier.new(&"nyx_regen", 1.0, false, self))
			if nyx_crit > 0:
				stats.add_modifier(&"crit_chance", CharacterStats.StatModifier.new(&"skill_tree_crit", float(nyx_crit) * 0.06, false, self))
				stats.add_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"skill_tree_atk_speed", float(nyx_crit) * 0.06, true, self))
			if has_crit_3:
				stats.add_modifier(&"crit_damage", CharacterStats.StatModifier.new(&"nyx_crit_dmg", 0.20, false, self))
		else:
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

		# Aplicar bonos permanentes globales de la Sala de Trofeos (Fase 3)
	var trophy_bonuses := SaveManager.get_trophy_passive_bonuses()
	if trophy_bonuses.get("base_damage_pct", 0.0) > 0.0:
		stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"trophy_damage", trophy_bonuses["base_damage_pct"], true, "trophy"))
	if trophy_bonuses.get("max_health", 0.0) > 0.0:
		stats.add_modifier(&"max_health", CharacterStats.StatModifier.new(&"trophy_hp", trophy_bonuses["max_health"], false, "trophy"))
	if trophy_bonuses.get("projectile_speed_pct", 0.0) > 0.0:
		stats.add_modifier(&"projectile_speed", CharacterStats.StatModifier.new(&"trophy_proj_speed", trophy_bonuses["projectile_speed_pct"], true, "trophy"))
	if trophy_bonuses.get("cooldown_reduction", 0.0) > 0.0:
		stats.add_modifier(&"cooldown_reduction", CharacterStats.StatModifier.new(&"trophy_cdr", trophy_bonuses["cooldown_reduction"], false, "trophy"))
	if trophy_bonuses.get("crit_chance", 0.0) > 0.0:
		stats.add_modifier(&"crit_chance", CharacterStats.StatModifier.new(&"trophy_crit", trophy_bonuses["crit_chance"], false, "trophy"))
	if trophy_bonuses.get("crit_damage", 0.0) > 0.0:
		stats.add_modifier(&"crit_damage", CharacterStats.StatModifier.new(&"trophy_crit_dmg", trophy_bonuses["crit_damage"], false, "trophy"))
	if trophy_bonuses.get("pickup_radius_pct", 0.0) > 0.0:
		stats.add_modifier(&"pickup_radius", CharacterStats.StatModifier.new(&"trophy_magnet", trophy_bonuses["pickup_radius_pct"], true, "trophy"))

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

	# Indicador de Autoaim debajo de la nave (y = 26px)
	if not get_node_or_null("AimModeIndicator"):
		var aim_ind_scene := preload("res://scenes/combat/player/aim_mode_indicator.tscn")
		if aim_ind_scene:
			var ind: Node2D = aim_ind_scene.instantiate() as Node2D
			ind.name = "AimModeIndicator"
			ind.position = Vector2(0, 26)
			add_child(ind)



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
	if is_dead:
		velocity = Vector2.ZERO
		return

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
	# Durante el Omega Spin, la rotación la conduce sincronizadamente el rayo láser
	if not is_omega_spinning:
		var aim_angle := (get_global_mouse_position() - global_position).angle()
		var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
		if ship_spr and ship_spr.visible:
			ship_spr.rotation = aim_angle + PI / 2.0
		var exo_spr := get_node_or_null("ExoArmorSprite") as Sprite2D
		if exo_spr:
			exo_spr.rotation = aim_angle + PI / 2.0
		var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
		if placeholder and placeholder.visible:
			placeholder.rotation = aim_angle


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
		"nyx":
			max_dash_charges = 2
			dash_charges = 2
			dash_recharge_max = 1.3
			dash_internal_cd = 0.15
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
			Engine.time_scale = SaveManager.get_game_speed() if SaveManager else 1.0
			dash_updated.emit(dash_charges, max_dash_charges, 1.0 if dash_charges >= max_dash_charges else (dash_recharge_timer / dash_recharge_max), false)

	# 4. Estado activo de Dash e invulnerabilidad
	if is_dashing:
		dash_timer -= delta
		if character_data and character_data.character_id == &"roxy":
			_process_roxy_ram_collision()

		if dash_timer <= 0.0:
			is_dashing = false
			is_omega_spinning = false

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
		"nyx":
			_execute_nyx_dash()
		_:
			_execute_nova_dash()

func _execute_nova_dash() -> void:
	# ── Omega Spin: se activa cuando el láser está a carga máxima ──
	# Usamos get_node_or_null en lugar del @onready para que funcione
	# tanto en instancias de escena como en Player.new() de los tests.
	var wc := get_node_or_null("WeaponController") as WeaponController
	if wc and wc.is_laser_fully_charged():
		_execute_nova_omega_spin(wc)
		return

	# ── Dash normal: rastro de fuego ──
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

## Omega Spin: dash + giro 360° + láser en todas direcciones.
## Se activa solo cuando el láser de Nova tiene carga máxima.
func _execute_nova_omega_spin(wc: WeaponController) -> void:
	# 1. Dash estándar (0.35s para que la vuelta 360° sea completa)
	is_dashing = true
	dash_timer = 0.35
	is_omega_spinning = true
	omega_spin_angle = dash_direction.angle()
	update_omega_spin_rotation(omega_spin_angle)

	# 2. Consumir la carga del láser antes de disparar
	wc.consume_laser_charge()

	# 3. Construir HitContext a partir de las stats actuales del jugador
	var base_dmg := stats.get_stat(&"base_damage")
	var crit_chance: float = stats.get_stat(&"crit_chance")
	var is_crit := randf() <= crit_chance
	var crit_mult: float = stats.get_stat(&"crit_damage")
	var final_dmg := base_dmg * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = self
	ctx.raw_damage = base_dmg
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = 0.35
	ctx.hit_position = global_position

	# 4. Instanciar y lanzar NovaSpin360Laser (el haz barre desde la dirección del dash)
	var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
	if spawn_parent and nova_spin_scene:
		var spin: Node2D = nova_spin_scene.instantiate() as Node2D
		if spin:
			spawn_parent.add_child(spin)
			if spin.has_method("setup"):
				# Pasar: jugador (para seguir su posición y sincronizar giro), ctx de daño, ángulo inicial = dirección del dash
				spin.call("setup", self, ctx, dash_direction.angle())

	# 5. SFX especial (pitch alto para comunicar la potencia)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 1.6, 2.0)
		audio_mgr.play_sfx("dash", 1.4, 3.0)

## Sincroniza la rotación visual de la nave, armadura y cañón con el rayo láser en tiempo real
func update_omega_spin_rotation(angle: float) -> void:
	omega_spin_angle = angle
	var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
	if ship_spr and ship_spr.visible:
		ship_spr.rotation = angle + PI / 2.0
	var exo_spr := get_node_or_null("ExoArmorSprite") as Sprite2D
	if exo_spr:
		exo_spr.rotation = angle + PI / 2.0
	var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
	if placeholder and placeholder.visible:
		placeholder.rotation = angle
	var w_ctrl := get_node_or_null("WeaponController") as Node2D
	if w_ctrl:
		w_ctrl.rotation = angle




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
	var base_spd: float = SaveManager.get_game_speed() if SaveManager else 1.0
	Engine.time_scale = base_spd * 0.55

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

func _execute_nyx_dash() -> void:
	is_dashing = true
	dash_timer = 0.18
	var start_pos := global_position
	var teleport_dist := 260.0
	var target_pos := start_pos + dash_direction * teleport_dist
	global_position = target_pos

	var base_dmg := stats.get_stat(&"base_damage") if stats else 48.0
	var crit_chance: float = stats.get_stat(&"crit_chance") if stats else 0.15
	var is_crit := (randf() <= crit_chance) or consume_guaranteed_crit()
	var crit_mult: float = stats.get_stat(&"crit_damage") if stats else 1.8
	var final_dmg := base_dmg * 1.5 * (crit_mult if is_crit else 1.0)

	var ctx := HitContext.new()
	ctx.attacker = self
	ctx.raw_damage = base_dmg * 1.5
	ctx.final_damage = final_dmg
	ctx.is_crit = is_crit
	ctx.proc_coefficient = 1.0
	ctx.hit_position = (start_pos + target_pos) * 0.5

	if cut_line_scene:
		var cut: Node2D = cut_line_scene.instantiate() as Node2D
		if cut and cut.has_method("setup"):
			var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
			if spawn_parent:
				spawn_parent.add_child(cut)
			cut.setup(start_pos, target_pos, self, ctx)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("dash", 1.8, 1.5)

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
	if is_dead:
		return
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
	var mult: float = stats.get_stat(&"credits_multiplier") if stats else 1.0
	var effective := int(round(float(amount) * maxf(0.1, mult)))
	run_credits += effective
	credits_changed.emit(run_credits)

func add_biomass(amount: int) -> void:
	if amount <= 0:
		return
	var mult: float = stats.get_stat(&"biomass_multiplier") if stats else 1.0
	var effective := int(round(float(amount) * maxf(0.1, mult)))
	run_biomass += effective
	var total_persistent := SaveManager.add_biomass(effective)
	biomass_changed.emit(run_biomass, total_persistent)

func add_exp(amount: float) -> void:
	var exp_mult: float = stats.get_stat(&"exp_multiplier") if stats else 1.0
	var effective_amount: float = amount * maxf(0.1, exp_mult)
	current_exp += effective_amount
	while current_exp >= exp_to_next:
		current_exp -= exp_to_next
		current_level += 1
		exp_to_next *= 1.35
		level_up_requested.emit(current_level)
	exp_changed.emit(current_exp, exp_to_next, current_level)

func take_damage(amount: float) -> void:
	if is_dead or is_dashing:
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
	if current_health <= 0.0 and not is_dead:
		_trigger_death_sequence()

func _trigger_death_sequence() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	velocity = Vector2.ZERO

	# Ocultar todos los elementos visuales de la nave
	var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
	if ship_spr:
		ship_spr.hide()
	var exo_spr := get_node_or_null("ExoArmorSprite") as Sprite2D
	if exo_spr:
		exo_spr.hide()
	var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
	if placeholder:
		placeholder.hide()
	if hitbox_core:
		hitbox_core.hide()
	if weapon_controller:
		weapon_controller.hide()
	var aim_ind := get_node_or_null("AimModeIndicator")
	if aim_ind:
		aim_ind.hide()
	var ohb := get_node_or_null("OverheadHealthBar")
	if ohb:
		ohb.hide()
	var lcb := get_node_or_null("LaserChargeBar")
	if lcb:
		lcb.hide()

	# Desactivar colisiones
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)

	# Instanciar efecto VFX de explosión de la nave
	_spawn_player_explosion_vfx()

	# SFX de explosión masiva
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 0.9, 2.5)

	player_died.emit()

func _spawn_player_explosion_vfx() -> void:
	if not explosion_vfx_scene:
		return
	var vfx := explosion_vfx_scene.instantiate()
	if vfx:
		var p_color: Color = character_data.color if character_data else Color(0.2, 0.85, 1.0)
		if vfx.has_method("setup"):
			vfx.setup(global_position, p_color)
		else:
			vfx.global_position = global_position
		var spawn_parent: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if spawn_parent:
			spawn_parent.add_child(vfx)


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

func _on_bullet_grazed(_bullet_pos: Vector2) -> void:
	add_exp(2.0) # Cada roce con balas suma experiencia y escala con exp_multiplier

func get_arcana_ids() -> Array[String]:
	var ids: Array[String] = []
	for arc in active_arcanas:
		if arc:
			ids.append(arc.id)
	return ids

func apply_arcana(arcana: ArcanaData) -> void:
	if not arcana or active_arcanas.has(arcana):
		return
	active_arcanas.append(arcana)

	for key in arcana.stat_modifiers.keys():
		var val: float = float(arcana.stat_modifiers[key])
		var s_key := String(key)
		var stat_name := StringName(s_key.trim_suffix("_pct"))
		var is_pct := s_key.ends_with("_pct")

		var mod_id := StringName("arcana_" + arcana.id + "_" + s_key)
		stats.add_modifier(stat_name, CharacterStats.StatModifier.new(mod_id, val, is_pct, arcana))

	var max_hp := stats.get_stat(&"max_health")
	if current_health > max_hp:
		current_health = max_hp
		health_changed.emit(current_health, max_hp)

	arcana_applied.emit(arcana)

func add_dark_matter(amount: int) -> void:
	if amount <= 0:
		return
	run_dark_matter += amount
	var total_persistent := SaveManager.add_dark_matter(amount)
	dark_matter_changed.emit(run_dark_matter, total_persistent)
