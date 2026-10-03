class_name Player
extends CharacterBody2D

## Player.gd
## Controlador principal del jugador y nave de combate en Astra Dream.
## Coordina cinemática de vuelo 360°, entradas de movimiento, experiencia/niveles y economía de la run.
## Delega responsabilidades especializadas a subcontroladores desacoplados:
## - PlayerDashController: Físicas de dashes, esquivas tácticas y cargas.
## - PlayerBombController: Bombas tácticas, supresión durante menús y shockwave.
## - PlayerShieldController: Capas defensivas, mitigación por armadura, regeneración y muerte.
## - PlayerProgressionApplier: Bonificaciones permanentes de Árbol de Talentos y Sala de Trofeos.
## - PlayerVisualBuilder: Shaders de vuelo de la piloto y tematización cromática.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SandevistanFlightVFX = preload("res://scenes/combat/player/sandevistan_flight_vfx.gd")
const PlayerDashController = preload("res://scenes/combat/player/player_dash_controller.gd")
const PlayerVisualBuilderClass = preload("res://scenes/combat/player/player_visual_builder.gd")
const PlayerBombControllerClass = preload("res://scenes/combat/player/player_bomb_controller.gd")
const PlayerShieldControllerClass = preload("res://scenes/combat/player/player_shield_controller.gd")
const PlayerProgressionApplierClass = preload("res://scenes/combat/player/player_progression_applier.gd")

@export var character_data: CharacterData
@export var bullet_server: BulletServer

var stats: CharacterStats = CharacterStats.new()
var character_stats: CharacterStats:
	get: return stats
	set(val): stats = val
var inventory: InventoryComponent = InventoryComponent.new()
var _static_charge: float = 0.0

# Subcontroladores Modulares
var visual_builder: RefCounted = PlayerVisualBuilderClass.new()
var bomb_controller: RefCounted = PlayerBombControllerClass.new()
var shield_controller: RefCounted = PlayerShieldControllerClass.new()
var progression_applier: RefCounted = PlayerProgressionApplierClass.new()
var dash_controller: PlayerDashController = PlayerDashController.new()

# Propiedades delegadas de Movilidad y Dash (PlayerDashController)
var is_dashing: bool:
	get: return dash_controller.is_dashing if dash_controller else false
	set(val):
		if dash_controller: dash_controller.is_dashing = val

var dash_direction: Vector2:
	get: return dash_controller.dash_direction if dash_controller else Vector2.RIGHT
	set(val):
		if dash_controller: dash_controller.dash_direction = val

var dash_charges: int:
	get: return dash_controller.dash_charges if dash_controller else 1
	set(val):
		if dash_controller: dash_controller.dash_charges = val

var max_dash_charges: int:
	get: return dash_controller.max_dash_charges if dash_controller else 1
	set(val):
		if dash_controller: dash_controller.max_dash_charges = val

var dash_recharge_max: float:
	get: return dash_controller.dash_recharge_max if dash_controller else 1.6
	set(val):
		if dash_controller: dash_controller.dash_recharge_max = val

var dash_internal_cd: float:
	get: return dash_controller.dash_internal_cd if dash_controller else 0.2
	set(val):
		if dash_controller: dash_controller.dash_internal_cd = val

var is_omega_spinning: bool:
	get: return dash_controller.is_omega_spinning if dash_controller else false
	set(val):
		if dash_controller: dash_controller.is_omega_spinning = val

var omega_spin_angle: float:
	get: return dash_controller.omega_spin_angle if dash_controller else 0.0
	set(val):
		if dash_controller: dash_controller.omega_spin_angle = val

var is_focus_active: bool:
	get: return dash_controller.is_focus_active if dash_controller else false
	set(val):
		if dash_controller: dash_controller.is_focus_active = val

var has_guaranteed_crit: bool:
	get: return dash_controller.has_guaranteed_crit if dash_controller else false
	set(val):
		if dash_controller: dash_controller.has_guaranteed_crit = val

var dash_timer: float:
	get: return dash_controller.dash_timer if dash_controller else 0.0
	set(val):
		if dash_controller: dash_controller.dash_timer = val

var roxy_ram_hit_enemies: Array[Node2D]:
	get: return dash_controller.roxy_ram_hit_enemies if dash_controller else []
	set(val):
		if dash_controller: dash_controller.roxy_ram_hit_enemies = val

# Propiedades delegadas de Bombas (PlayerBombController)
var bomb_count: int:
	get:
		return bomb_controller.bomb_count if bomb_controller else 2
	set(val):
		if bomb_controller:
			bomb_controller.bomb_count = val

var _menu_close_suppress_timer: float:
	get:
		return bomb_controller.menu_close_suppress_timer if bomb_controller else 0.0
	set(val):
		if bomb_controller:
			bomb_controller.menu_close_suppress_timer = val

var _was_bomb_pressed_during_menu: bool:
	get:
		return bomb_controller.was_bomb_pressed_during_menu if bomb_controller else false
	set(val):
		if bomb_controller:
			bomb_controller.was_bomb_pressed_during_menu = val

# Escenas VFX de Combate
var bomb_shockwave_scene: PackedScene = preload("res://scenes/combat/player/bomb_shockwave_vfx.tscn")
var explosion_vfx_scene: PackedScene = preload("res://scenes/combat/player/player_explosion_vfx.tscn")

var is_dead: bool = false
var current_health: float = 100.0

# Economía de la Run
var run_credits: int = 40
var run_biomass: int = 0
var run_dark_matter: int = 0
var is_movement_suppressed: bool = false
var is_invulnerable: bool = false

# Experiencia y Progresión en Run
var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next: float = 40.0
var chosen_stat_cards: Array[StatCardData] = []
var active_arcanas: Array[ArcanaData] = []

# Cinemática de Vuelo y Shaders
var current_facing_angle: float = -PI / 2.0
var last_facing_direction: Vector2 = Vector2.UP
var current_bank_tilt: float = 0.0
var idle_bob_timer: float = 0.0
var hit_flash_timer: float = 0.0
const ROTATION_SMOOTH_SPEED: float = 14.0
const BANK_SMOOTH_SPEED: float = 8.0

@onready var hitbox_core: Node2D = get_node_or_null("HitboxCore")
@onready var weapon_controller: Node2D = get_node_or_null("WeaponController")

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	z_index = 5
	scale = Vector2(1.2, 1.2)
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
	if not dash_controller.is_inside_tree():
		add_child(dash_controller)
	if not dash_controller.dash_updated.is_connected(_on_dash_controller_updated):
		dash_controller.dash_updated.connect(_on_dash_controller_updated)
	if bomb_controller and not bomb_controller.bomb_used.is_connected(func(c: int) -> void: bomb_used.emit(c)):
		bomb_controller.bomb_used.connect(func(c: int) -> void: bomb_used.emit(c))
	_setup_character_dash()
	stats.initialize(character_data)

	if progression_applier:
		progression_applier.apply_skill_tree_bonuses(self, stats, character_data)
		progression_applier.apply_trophy_bonuses(stats)

	current_health = stats.get_stat(&"max_health")
	health_changed.emit(current_health, current_health)
	credits_changed.emit(run_credits)
	var persistent_bio := SaveManager.get_biomass()
	biomass_changed.emit(run_biomass, persistent_bio)
	var persistent_dm := SaveManager.get_dark_matter()
	dark_matter_changed.emit(run_dark_matter, persistent_dm)
	exp_changed.emit(current_exp, exp_to_next, current_level)
	if not inventory.is_inside_tree():
		add_child(inventory)
	if not inventory.item_added.is_connected(_on_inventory_item_added):
		inventory.item_added.connect(_on_inventory_item_added)

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
	if visual_builder:
		visual_builder.apply_visual_theme(self, character_data)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if bomb_controller:
		bomb_controller.update_suppression(delta)
		if is_any_menu_or_modal_active():
			if Input.is_action_pressed("bomb"):
				bomb_controller.was_bomb_pressed_during_menu = true
		elif bomb_controller.was_bomb_pressed_during_menu:
			if not Input.is_action_pressed("bomb"):
				bomb_controller.was_bomb_pressed_during_menu = false

	_handle_dash(delta)
	_handle_movement(delta)
	_handle_actions()
	_handle_health_regen(delta)

	# Cinemática de Vuelo 360° orientada hacia el vector de movimiento
	idle_bob_timer += delta
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	var is_moving: bool = velocity.length_squared() > 10.0
	if is_moving and inventory and inventory.has_method("get_item_count") and inventory.get_item_count(&"static_cell") > 0:
		_static_charge += velocity.length() * delta * 0.25
		if _static_charge >= 100.0:
			_static_charge = 0.0
			has_guaranteed_crit = true
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("laser", 1.8, 2.5)
	var target_bank: float = 0.0

	# Durante el Omega Spin de Nova, la rotación la conduce sincronizadamente el rayo láser
	if not is_omega_spinning:
		if is_moving:
			var move_angle := velocity.angle()
			last_facing_direction = velocity.normalized()
			var angle_diff := wrapf(move_angle - current_facing_angle, -PI, PI)
			current_facing_angle = lerp_angle(current_facing_angle, move_angle, ROTATION_SMOOTH_SPEED * delta)
			target_bank = clampf(angle_diff * 1.8, -1.0, 1.0)
		else:
			target_bank = 0.0

		current_bank_tilt = move_toward(current_bank_tilt, target_bank, BANK_SMOOTH_SPEED * delta)

		var visual_rotation := current_facing_angle + PI / 2.0
		var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
		if ship_spr and ship_spr.visible:
			ship_spr.rotation = visual_rotation
			if not is_moving and not is_dashing:
				ship_spr.position.y = sin(idle_bob_timer * 3.5) * 1.5
			else:
				ship_spr.position.y = move_toward(ship_spr.position.y, 0.0, 8.0 * delta)

		var exo_spr := get_node_or_null("ExoArmorSprite") as Sprite2D
		if exo_spr:
			exo_spr.rotation = visual_rotation

		var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
		if placeholder and placeholder.visible:
			placeholder.rotation = current_facing_angle

	_update_pilot_shader(delta, is_moving)

	if bullet_server:
		bullet_server.player_pos = global_position
		bullet_server.player_invulnerable = is_dashing or is_invulnerable


func _update_pilot_shader(delta: float, is_moving: bool) -> void:
	if visual_builder:
		visual_builder.update_pilot_shader(self, delta, is_moving)


func _handle_movement(delta: float) -> void:
	if is_movement_suppressed:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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


func set_cinematic_duel_facing() -> void:
	is_movement_suppressed = true
	velocity = Vector2.ZERO
	current_facing_angle = 0.0
	var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
	if ship_spr:
		ship_spr.rotation = PI / 2.0
	var exo_spr := get_node_or_null("ExoArmorSprite") as Sprite2D
	if exo_spr:
		exo_spr.rotation = PI / 2.0
	var placeholder := get_node_or_null("VisualPlaceholder") as Polygon2D
	if placeholder:
		placeholder.rotation = 0.0


func resume_movement_control() -> void:
	is_movement_suppressed = false


func _on_dash_controller_updated(c: int, m: int, p: float, f: bool) -> void:
	dash_updated.emit(c, m, p, f)


func _setup_character_dash() -> void:
	if not dash_controller:
		dash_controller = PlayerDashController.new()
	var cid: StringName = character_data.character_id if character_data else &"nova"
	dash_controller.setup_for_character(self, cid)


func _handle_dash(delta: float) -> void:
	if dash_controller:
		dash_controller.handle_dash_process(delta)


func _execute_character_dash() -> void:
	if dash_controller:
		dash_controller.execute_character_dash()


func update_omega_spin_rotation(angle: float) -> void:
	if dash_controller:
		dash_controller.omega_spin_angle = angle
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


func consume_guaranteed_crit() -> bool:
	if dash_controller:
		return dash_controller.consume_guaranteed_crit()
	return false


func _execute_roxy_dash() -> void:
	if dash_controller:
		dash_controller._execute_roxy_dash()


func _process_roxy_ram_collision() -> void:
	if dash_controller:
		dash_controller._process_roxy_ram_collision()


func suppress_bomb_input(duration: float = 0.35) -> void:
	if bomb_controller:
		bomb_controller.suppress_bomb_input(duration)


func is_any_menu_or_modal_active() -> bool:
	return bomb_controller.is_any_menu_or_modal_active(self) if bomb_controller else false


func _can_trigger_bomb() -> bool:
	return bomb_controller.can_trigger_bomb(self) if bomb_controller else false


func _execute_bomb() -> void:
	if bomb_controller:
		bomb_controller.execute_bomb(self, bullet_server)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("bomb") and not event.is_echo():
		if _can_trigger_bomb():
			_execute_bomb()
			get_viewport().set_input_as_handled()


func _handle_actions() -> void:
	pass


func add_bombs(amount: int = 1) -> bool:
	return bomb_controller.add_bombs(self, bullet_server, amount) if bomb_controller else false


func _spawn_bomb_vfx(at_position: Vector2 = global_position) -> void:
	if bomb_controller:
		bomb_controller.spawn_bomb_vfx(get_tree(), at_position)


func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	var max_hp: float = stats.get_stat(&"max_health") if stats else 100.0
	current_health = minf(max_hp, current_health + amount)
	health_changed.emit(current_health, max_hp)
	_update_conversion_core_stats()


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	var mult: float = stats.get_stat(&"credits_multiplier") if stats else 1.0
	var curse: float = stats.get_stat(&"curse") if stats else 0.0
	var curse_bonus: float = maxf(0.0, 1.0 + (curse * 0.01))
	var effective := int(round(float(amount) * maxf(0.1, mult) * curse_bonus))
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
	if inventory and inventory.has_method("get_item_count") and inventory.get_item_count(&"alchemical_converter") > 0:
		var cred_gain: int = maxi(1, int(round(effective_amount * 0.15)))
		add_credits(cred_gain)
	current_exp += effective_amount
	while current_exp >= exp_to_next:
		current_exp -= exp_to_next
		current_level += 1
		exp_to_next *= 1.35
		level_up_requested.emit(current_level)
	exp_changed.emit(current_exp, exp_to_next, current_level)


func take_damage(amount: float) -> void:
	if is_invulnerable:
		return
	if shield_controller:
		shield_controller.take_damage(self, amount, stats, inventory)


func _trigger_death_sequence() -> void:
	if shield_controller:
		shield_controller.trigger_death_sequence(self)


func _spawn_player_explosion_vfx() -> void:
	if shield_controller:
		shield_controller.spawn_player_explosion_vfx(self)


func _handle_health_regen(delta: float) -> void:
	if shield_controller:
		shield_controller.handle_health_regen(self, delta, stats, inventory)


func _update_conversion_core_stats() -> void:
	if shield_controller:
		shield_controller.update_conversion_core_stats(self, stats, inventory)


func _on_bullet_hit() -> void:
	take_damage(10.0)


func _on_bullet_grazed(_bullet_pos: Vector2) -> void:
	add_exp(2.0)


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

	var max_hp := maxf(1.0, stats.get_stat(&"max_health"))
	current_health = clampf(current_health, 1.0, max_hp)
	health_changed.emit(current_health, max_hp)

	arcana_applied.emit(arcana)


func add_dark_matter(amount: int) -> void:
	if amount <= 0:
		return
	run_dark_matter += amount
	var total_persistent := SaveManager.add_dark_matter(amount)
	dark_matter_changed.emit(run_dark_matter, total_persistent)

func _on_inventory_item_added(_it: ItemData, _cnt: int) -> void:
	_update_conversion_core_stats()
