class_name Player
extends CharacterBody2D

## ─── TABLE OF CONTENTS ──────────────────────────────────────────────────────
## VARIABLES & @ONREADY NODES     → L.25  - L.201
## LIFECYCLE: _ready              → L.202 - L.275
## THEME & HITBOX VISUALS         → L.276 - L.312  [delegado a PlayerVisualBuilder]
## PROCESS: hitbox visibility     → L.313 - L.348
## PHYSICS: _physics_process      → L.349 - L.420
## PILOT SHADER update            → L.421 - L.425  [delegado a PlayerVisualBuilder]
## MOVEMENT: _handle_movement     → L.426 - L.451
## CINEMATIC DUEL: facing         → L.452 - L.474
## DASH SETUP & EXECUTE           → L.475 - L.524
## BOMB: suppress / can_trigger   → L.525 - L.547
## INPUT: _unhandled_input        → L.548 - L.556
## ACTIONS: _handle_actions       → L.557 - L.569
## ECONOMY: heal/credits/biomass  → L.570 - L.599
## EXP: add_exp                   → L.600 - L.614
## DAMAGE: take_damage / death    → L.615 - L.635  [delegado a PlayerShieldController]
## HEALTH REGEN                   → L.636 - L.652  [delegado a PlayerShieldController]
## ARCANAS: apply_arcana          → L.653 - L.681
## DARK MATTER                    → L.682 - L.691
## ─────────────────────────────────────────────────────────────────────────────


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
const TomeControllerClass = preload("res://scenes/combat/player/tome_controller.gd")
const PlayerLocomotionControllerClass = preload("res://scenes/combat/player/player_locomotion_controller.gd")
const PlayerEconomyComponentClass = preload("res://scenes/combat/player/player_economy_component.gd")
const PlayerDamageProcessorClass = preload("res://scenes/combat/player/player_damage_processor.gd")
const PlayerArcanaInventoryClass = preload("res://scenes/combat/player/player_arcana_inventory.gd")

@export var character_data: CharacterData
@export var bullet_server: BulletServer

var character_id: StringName:
	get:
		return character_data.character_id if character_data else &"nova"

var stats: CharacterStats = CharacterStats.new()
var character_stats: CharacterStats:
	get: return stats
	set(val): stats = val
var inventory: InventoryComponent = InventoryComponent.new()
var tome_controller: Node = TomeControllerClass.new()
var _static_charge: float = 0.0

# Subcontroladores Modulares
var visual_builder: RefCounted = PlayerVisualBuilderClass.new()
var bomb_controller: RefCounted = PlayerBombControllerClass.new()
var shield_controller: RefCounted = PlayerShieldControllerClass.new()
var progression_applier: RefCounted = PlayerProgressionApplierClass.new()
var dash_controller: PlayerDashController = PlayerDashController.new()
var locomotion_controller: RefCounted = PlayerLocomotionControllerClass.new()
var economy_component: Node = PlayerEconomyComponentClass.new()
var damage_processor: RefCounted = PlayerDamageProcessorClass.new()
var arcana_inventory: Node = PlayerArcanaInventoryClass.new()

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

# Economía de la Run delegada a PlayerEconomyComponent
var run_credits: int:
	get: return economy_component.run_credits if economy_component else 40
	set(val):
		if economy_component: economy_component.run_credits = val

var run_biomass: int:
	get: return economy_component.run_biomass if economy_component else 0
	set(val):
		if economy_component: economy_component.run_biomass = val

var run_dark_matter: int:
	get: return economy_component.run_dark_matter if economy_component else 0
	set(val):
		if economy_component: economy_component.run_dark_matter = val

var is_movement_suppressed: bool:
	get: return locomotion_controller.is_movement_suppressed if locomotion_controller else false
	set(val):
		if locomotion_controller: locomotion_controller.is_movement_suppressed = val

var is_invulnerable: bool = false

# Experiencia y Progresión en Run delegada a PlayerEconomyComponent
var current_level: int:
	get: return economy_component.current_level if economy_component else 1
	set(val):
		if economy_component: economy_component.current_level = val

var current_exp: float:
	get: return economy_component.current_exp if economy_component else 0.0
	set(val):
		if economy_component: economy_component.current_exp = val

var exp_to_next: float:
	get: return economy_component.exp_to_next if economy_component else 40.0
	set(val):
		if economy_component: economy_component.exp_to_next = val

var chosen_stat_cards: Array[StatCardData] = []
var active_arcanas: Array[ArcanaData]:
	get: return arcana_inventory.active_arcanas if arcana_inventory else []
	set(val):
		if arcana_inventory: arcana_inventory.active_arcanas = val

# Cinemática de Vuelo y Shaders delegados a PlayerLocomotionController
var current_facing_angle: float:
	get: return locomotion_controller.current_facing_angle if locomotion_controller else -PI / 2.0
	set(val):
		if locomotion_controller: locomotion_controller.current_facing_angle = val

var last_facing_direction: Vector2:
	get: return locomotion_controller.last_facing_direction if locomotion_controller else Vector2.UP
	set(val):
		if locomotion_controller: locomotion_controller.last_facing_direction = val

var current_bank_tilt: float:
	get: return locomotion_controller.current_bank_tilt if locomotion_controller else 0.0
	set(val):
		if locomotion_controller: locomotion_controller.current_bank_tilt = val

var idle_bob_timer: float:
	get: return locomotion_controller.idle_bob_timer if locomotion_controller else 0.0
	set(val):
		if locomotion_controller: locomotion_controller.idle_bob_timer = val

var hit_flash_timer: float = 0.0
const ROTATION_SMOOTH_SPEED: float = 14.0
const BANK_SMOOTH_SPEED: float = 8.0
const TACTICAL_FOCUS_SPEED: float = 280.0

var is_tactical_focus_active: bool:
	get: return locomotion_controller.is_tactical_focus_active if locomotion_controller else false
	set(val):
		if locomotion_controller: locomotion_controller.is_tactical_focus_active = val

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
signal osp_triggered(remaining_hp: float)


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

	if not economy_component.is_inside_tree():
		add_child(economy_component)
	economy_component.credits_changed.connect(func(amt: int) -> void: credits_changed.emit(amt))
	economy_component.biomass_changed.connect(func(amt: int, tot: int) -> void: biomass_changed.emit(amt, tot))
	economy_component.dark_matter_changed.connect(func(amt: int, tot: int) -> void: dark_matter_changed.emit(amt, tot))
	economy_component.exp_changed.connect(func(c: float, m: float, lvl: int) -> void: exp_changed.emit(c, m, lvl))
	economy_component.level_up_requested.connect(func(lvl: int) -> void: level_up_requested.emit(lvl))

	if not arcana_inventory.is_inside_tree():
		add_child(arcana_inventory)
	if not arcana_inventory.arcana_applied.is_connected(func(a: ArcanaData) -> void: arcana_applied.emit(a)):
		arcana_inventory.arcana_applied.connect(func(a: ArcanaData) -> void: arcana_applied.emit(a))

	current_health = stats.get_stat(&"max_health")
	health_changed.emit(current_health, current_health)
	economy_component.initialize_economy()
	if not inventory.is_inside_tree():
		add_child(inventory)
	inventory.character_stats = stats
	if not inventory.item_added.is_connected(_on_inventory_item_added):
		inventory.item_added.connect(_on_inventory_item_added)

	if not tome_controller.is_inside_tree():
		add_child(tome_controller)
	tome_controller.setup(self)

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

	_setup_hitbox_core_visuals()


func _apply_visual_theme() -> void:
	if visual_builder:
		visual_builder.apply_visual_theme(self, character_data)

func _setup_hitbox_core_visuals() -> void:
	if visual_builder:
		visual_builder.setup_hitbox_core_visuals(hitbox_core)


func _process(delta: float) -> void:
	if locomotion_controller:
		locomotion_controller.update_hitbox_core_visibility(self, hitbox_core, delta)


func _check_hostile_threat() -> bool:
	return locomotion_controller._check_hostile_threat(self) if locomotion_controller else false


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

	if locomotion_controller:
		locomotion_controller.update_flight_kinematics(self, is_omega_spinning, is_dashing, delta)

	_update_pilot_shader(delta, is_moving)

	if bullet_server:
		bullet_server.player_pos = global_position
		bullet_server.player_invulnerable = is_dashing or is_invulnerable


func _update_pilot_shader(delta: float, is_moving: bool) -> void:
	if visual_builder:
		visual_builder.update_pilot_shader(self, delta, is_moving)


func _handle_movement(delta: float) -> void:
	if locomotion_controller:
		locomotion_controller.handle_movement(self, stats, is_dashing, dash_direction, delta)


func set_cinematic_duel_facing() -> void:
	if locomotion_controller:
		locomotion_controller.set_cinematic_duel_facing(self)


func resume_movement_control() -> void:
	if locomotion_controller:
		locomotion_controller.resume_movement_control()


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
	if visual_builder:
		visual_builder.update_omega_spin_rotation(self, angle)



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


func clear_bomb_suppression(grace_period: float = 0.35) -> void:
	if bomb_controller:
		bomb_controller.clear_suppression_lock(grace_period)


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
	if economy_component:
		economy_component.add_credits(amount, stats)


func add_biomass(amount: int) -> void:
	if economy_component:
		economy_component.add_biomass(amount, stats)


func add_exp(amount: float) -> void:
	if economy_component:
		economy_component.add_exp(amount, stats, inventory)


func take_damage(arg: Variant) -> void:
	if damage_processor:
		damage_processor.process_incoming_damage(self, arg, shield_controller, stats, inventory)


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
	return arcana_inventory.get_arcana_ids() if arcana_inventory else []


func apply_arcana(arcana: ArcanaData) -> void:
	if arcana_inventory:
		arcana_inventory.apply_arcana(arcana, self, stats)


func add_dark_matter(amount: int) -> void:
	if economy_component:
		economy_component.add_dark_matter(amount)

func _on_inventory_item_added(_it: ItemData, _cnt: int) -> void:
	_update_conversion_core_stats()
