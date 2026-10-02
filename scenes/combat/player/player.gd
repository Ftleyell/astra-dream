class_name Player
extends CharacterBody2D

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SandevistanFlightVFX = preload("res://scenes/combat/player/sandevistan_flight_vfx.gd")
const PlayerDashController = preload("res://scenes/combat/player/player_dash_controller.gd")

@export var character_data: CharacterData
@export var bullet_server: BulletServer

var stats: CharacterStats = CharacterStats.new()
var inventory: InventoryComponent = InventoryComponent.new()
var _static_charge: float = 0.0

# Dash Controller Component & Mobility State
var dash_controller: PlayerDashController = PlayerDashController.new()

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

# Combat VFX Scenes
var bomb_shockwave_scene: PackedScene = preload("res://scenes/combat/player/bomb_shockwave_vfx.tscn")
var explosion_vfx_scene: PackedScene = preload("res://scenes/combat/player/player_explosion_vfx.tscn")

var is_dead: bool = false

var bomb_count: int = 2
var run_credits: int = 40
var run_biomass: int = 0
var _menu_close_suppress_timer: float = 0.0
var _was_bomb_pressed_during_menu: bool = false
var is_movement_suppressed: bool = false

# EXP & Leveling
var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next: float = 40.0
var chosen_stat_cards: Array[StatCardData] = []
var active_arcanas: Array[ArcanaData] = []
var run_dark_matter: int = 0

# Kinematics & Flight Shader State
var current_facing_angle: float = -PI / 2.0 # Inicialmente mirando hacia arriba
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

var current_health: float = 100.0

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
	inventory.item_added.connect(func(_it: ItemData, _cnt: int) -> void: _update_conversion_core_stats())
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
		ship_spr.z_index = 1
		add_child(ship_spr)
		move_child(ship_spr, 0)
	elif ship_spr:
		ship_spr.z_index = 1

	# Aplicar Shader Maestro de vuelo de exo-piloto
	var flight_shader := preload("res://shaders/exo_pilot_flight.gdshader")
	var flight_mat := ShaderMaterial.new()
	flight_mat.shader = flight_shader
	var p_color: Color = character_data.color if character_data else Color(0.2, 0.75, 1.0, 1.0)
	var sec_color := Color(1.0, 0.85, 0.4, 1.0)
	if p_color.h < 0.5:
		sec_color = Color.from_hsv(wrapf(p_color.h + 0.15, 0.0, 1.0), 0.7, 1.1)
	else:
		sec_color = Color.from_hsv(wrapf(p_color.h - 0.15, 0.0, 1.0), 0.7, 1.1)

	var noise_res := preload("res://shaders/flame_noise.tres")
	if noise_res:
		flight_mat.set_shader_parameter("noise_texture", noise_res)

	flight_mat.set_shader_parameter("primary_color", p_color)
	flight_mat.set_shader_parameter("secondary_color", sec_color)
	flight_mat.set_shader_parameter("thrust_intensity", 0.35)
	flight_mat.set_shader_parameter("speed_ratio", 0.0)
	flight_mat.set_shader_parameter("bank_tilt", 0.0)
	flight_mat.set_shader_parameter("chromatic_offset", 0.004)
	flight_mat.set_shader_parameter("hit_flash", 0.0)
	flight_mat.set_shader_parameter("core_gem_glow", 1.2)
	flight_mat.set_shader_parameter("flame_direction", Vector2(0.0, 1.0))

	# Componente de imágenes residuales Sandevistan
	var vfx_comp := get_node_or_null("SandevistanFlightVFX") as SandevistanFlightVFX
	if not vfx_comp and ship_spr:
		vfx_comp = SandevistanFlightVFX.new()
		vfx_comp.name = "SandevistanFlightVFX"
		vfx_comp.source_sprite = ship_spr
		add_child(vfx_comp)
	if vfx_comp:
		vfx_comp.configure_colors(p_color, sec_color)

	# Aplicar skin cosmética a la nave si está equipada
	var char_id_str := String(character_data.character_id) if character_data else "survivor_default"
	var equipped_ship_skin: String = SaveManager.get_equipped_skin("ship:" + char_id_str)
	if not equipped_ship_skin.is_empty() and ship_spr:
		var skin_data := CosmeticsManager.get_skin(equipped_ship_skin)
		var custom_tex := CosmeticsManager.get_skin_texture(skin_data)
		if custom_tex:
			ship_spr.texture = custom_tex
		var glow_hex: String = skin_data.get("glow_hex", "")
		if not glow_hex.is_empty():
			var skin_primary := Color.from_string(glow_hex, p_color)
			flight_mat.set_shader_parameter("primary_color", skin_primary)
			if vfx_comp:
				vfx_comp.configure_colors(skin_primary, sec_color)
		ship_spr.material = flight_mat
		ship_spr.visible = true
		ship_spr.scale = Vector2(0.42, 0.42)
		if placeholder:
			placeholder.visible = false
	elif ship_spr:
		if ship_tex:
			ship_spr.texture = ship_tex
			ship_spr.material = flight_mat
			ship_spr.visible = true
			ship_spr.scale = Vector2(0.42, 0.42)
			if placeholder:
				placeholder.visible = false
		else:
			ship_spr.visible = false
			ship_spr.material = null
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

	# Configurar sprite del arma rotatoria en WeaponController montado directamente sobre el chasis del jugador
	var w_ctrl := get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		w_ctrl.z_index = 20
		w_ctrl.z_as_relative = false
		move_child(w_ctrl, get_child_count() - 1)
		var w_tex: Texture2D = character_data.get_weapon_texture() if character_data.has_method("get_weapon_texture") else null
		var w_spr := w_ctrl.get_node_or_null("WeaponSprite") as Sprite2D
		var w_poly := w_ctrl.get_node_or_null("WeaponVisual") as Polygon2D
		if not w_spr and (w_tex or not SaveManager.get_equipped_skin("weapon:" + char_id_str).is_empty()):
			w_spr = Sprite2D.new()
			w_spr.name = "WeaponSprite"
			w_ctrl.add_child(w_spr)
		if w_spr:
			w_spr.z_as_relative = false
			w_spr.z_index = 20
			w_spr.move_to_front()
			var equipped_w_skin: String = SaveManager.get_equipped_skin("weapon:" + char_id_str)
			if not equipped_w_skin.is_empty():
				var w_stars: int = SaveManager.get_skin_stars(equipped_w_skin)
				CosmeticsManager.apply_skin_to_canvas_item(w_spr, equipped_w_skin, w_stars)
				w_spr.position = Vector2.ZERO
				w_spr.visible = true
				if w_poly:
					w_poly.visible = false
			elif w_tex:
				w_spr.texture = w_tex
				w_spr.material = null
				w_spr.position = Vector2.ZERO
				w_spr.visible = true
				if w_poly:
					w_poly.visible = false
			else:
				w_spr.visible = false
				w_spr.material = null
				if w_poly:
					w_poly.z_as_relative = false
					w_poly.z_index = 20
					w_poly.position = Vector2.ZERO
					w_poly.visible = true

			# Escalar para montarse sobre el chasis de la nave (aprox. 45% del tamaño de la nave)
			if w_spr.visible:
				var char_visual_size: float = 108.0
				if ship_spr and ship_spr.texture:
					char_visual_size = maxf(float(ship_spr.texture.get_width()) * ship_spr.scale.x, float(ship_spr.texture.get_height()) * ship_spr.scale.y)
				var target_weapon_pixel_size: float = char_visual_size * 0.45
				var tex_dim: float = 128.0
				if w_spr.texture:
					tex_dim = maxf(float(w_spr.texture.get_width()), float(w_spr.texture.get_height()))
				var target_scale: float = target_weapon_pixel_size / maxf(tex_dim, 1.0)
				w_spr.scale = Vector2(target_scale, target_scale)


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

	# Cinemática de Vuelo 360° orientada hacia el vector de movimiento
	idle_bob_timer += delta
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	var is_moving: bool = velocity.length_squared() > 10.0
	if is_moving and inventory and inventory.get_item_count(&"static_cell") > 0:
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

		# Offset de PI/2 porque los sprites base de las chicas están dibujados hacia ARRIBA (-Y)
		var visual_rotation := current_facing_angle + PI / 2.0
		var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
		if ship_spr and ship_spr.visible:
			ship_spr.rotation = visual_rotation
			# Micro-flotación orgánica (idle bobbing) cuando la piloto está en reposo
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

	# Actualizar uniforms del shader de vuelo de la piloto
	_update_pilot_shader(delta, is_moving)

	if bullet_server:
		bullet_server.player_pos = global_position
		bullet_server.player_invulnerable = is_dashing

func _update_pilot_shader(_delta: float, is_moving: bool) -> void:
	var ship_spr := get_node_or_null("ShipSprite") as Sprite2D
	if not ship_spr or not (ship_spr.material is ShaderMaterial):
		return

	var mat := ship_spr.material as ShaderMaterial
	var max_spd: float = maxf(1.0, stats.get_stat(&"move_speed"))
	var spd_ratio: float = clampf(velocity.length() / max_spd, 0.0, 1.0)

	var target_thrust: float = 0.25
	if is_dashing:
		target_thrust = 2.4 # Estado 3: Sobrecarga hiperbólica en Dash
	elif is_moving:
		target_thrust = lerpf(0.65, 1.25, spd_ratio) # Estado 2: Vuelo reactivo a la velocidad
	else:
		target_thrust = 0.25 + 0.08 * sin(idle_bob_timer * 6.0) # Estado 1: Llama piloto parpadeante en reposo

	mat.set_shader_parameter("thrust_intensity", target_thrust)
	mat.set_shader_parameter("speed_ratio", spd_ratio)
	mat.set_shader_parameter("bank_tilt", current_bank_tilt)
	mat.set_shader_parameter("hit_flash", 1.0 if hit_flash_timer > 0.0 else 0.0)

	# Brillo del reactor / HitboxCore (intensificado al esquivar o recibir daño)
	var gem_glow: float = 1.2
	if is_dashing:
		gem_glow = 2.2
	elif hit_flash_timer > 0.0:
		gem_glow = 2.8
	mat.set_shader_parameter("core_gem_glow", gem_glow)

	# Dirección del flameo opuesta al arrastre cinemático en coordenadas locales del sprite
	var visual_rot := current_facing_angle + PI / 2.0
	var local_burn := Vector2(0.0, 1.0)
	if is_moving and velocity.length_squared() > 100.0:
		var local_vel := velocity.rotated(-visual_rot)
		var dir := -local_vel.normalized()
		if not dir.is_zero_approx():
			local_burn = dir
	mat.set_shader_parameter("flame_direction", local_burn)

	# Actualizar estela cinemática de afterimages Sandevistan
	var vfx_comp := get_node_or_null("SandevistanFlightVFX") as SandevistanFlightVFX
	if vfx_comp:
		vfx_comp.update_flight(_delta, velocity, is_dashing)

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

## Sincroniza la rotación visual de la nave, armadura y cañón con el rayo láser en tiempo real
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
	_update_conversion_core_stats()

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
	if inventory and inventory.get_item_count(&"alchemical_converter") > 0:
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
	if is_dead or is_dashing:
		return
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_hp_active") and debug_mgr.is_infinite_hp_active():
		return
	if has_meta("caelia_shield_hook"):
		remove_meta("caelia_shield_hook")
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.0, 0.8, 0.2, 1.0), 0.1)
		tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click", 0.0, 1.8)
		return
	if has_meta("phase_inverter_shield"):
		remove_meta("phase_inverter_shield")
		var tw := create_tween()
		if tw:
			tw.tween_property(self, "modulate", Color(0.3, 1.5, 2.0, 1.0), 0.1)
			tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click", 0.0, 2.2)
		return
	var armor_val: float = stats.get_stat(&"armor") if stats else 0.0
	var mitigated_dmg: float = amount
	if armor_val >= 0.0:
		mitigated_dmg = maxf(1.0, amount * (100.0 / (100.0 + armor_val)))
	else:
		mitigated_dmg = amount * (2.0 - (100.0 / (100.0 - armor_val)))

	current_health -= mitigated_dmg
	hit_flash_timer = 0.22
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("player_hit")
	health_changed.emit(current_health, stats.get_stat(&"max_health"))
	_update_conversion_core_stats()

	if inventory:
		inventory.process_take_damage_procs(mitigated_dmg, self)

	if current_health <= 0.0 and not is_dead:
		if inventory and inventory.get_item_count(&"stellar_scrap") > 0 and not has_meta("stellar_scrap_used") and run_credits >= 100:
			set_meta("stellar_scrap_used", true)
			run_credits -= 100
			credits_changed.emit(run_credits)
			var max_hp: float = stats.get_stat(&"max_health") if stats else 100.0
			current_health = max_hp * 0.3
			health_changed.emit(current_health, max_hp)
			_update_conversion_core_stats()
			var tw := create_tween()
			if tw:
				tw.tween_property(self, "modulate", Color(2.5, 2.0, 0.5, 1.0), 0.15)
				tw.tween_property(self, "modulate", Color.WHITE, 0.3)
			var audio_mgr2 := get_node_or_null("/root/AudioManager")
			if audio_mgr2 and audio_mgr2.has_method("play_sfx"):
				audio_mgr2.play_sfx("upgrade_obtained", 1.5, 1.5)
			return
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
	if inventory and inventory.get_item_count(&"overdrain_module") > 0:
		return
	var max_hp := stats.get_stat(&"max_health")
	if current_health < max_hp and current_health > 0.0:
		var regen := stats.get_stat(&"health_regen")
		if regen > 0.0:
			var old_val := current_health
			current_health = minf(max_hp, current_health + regen * delta)
			if int(old_val * 2.0) != int(current_health * 2.0) or current_health >= max_hp:
				health_changed.emit(current_health, max_hp)

func _update_conversion_core_stats() -> void:
	if not stats or not inventory:
		return

	# Célula Hemodinámica
	if inventory.get_item_count(&"hemodynamic_cell") > 0:
		var max_hp: float = maxf(1.0, stats.get_stat(&"max_health"))
		var missing_pct: float = clampf(1.0 - (current_health / max_hp), 0.0, 1.0)
		var missing_tens: float = floorf(missing_pct * 10.0)
		var dmg_bonus: float = minf(0.25, missing_tens * 0.03)
		var atk_spd_bonus: float = minf(0.25, missing_tens * 0.02)
		stats.set_or_replace_modifier(&"base_damage", CharacterStats.StatModifier.new(&"hemodynamic_dmg", dmg_bonus, true, &"hemodynamic_cell"))
		stats.set_or_replace_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"hemodynamic_spd", atk_spd_bonus, true, &"hemodynamic_cell"))
	else:
		stats.remove_modifier(&"base_damage", &"hemodynamic_dmg")
		stats.remove_modifier(&"attack_speed", &"hemodynamic_spd")

	# Conversor Cinético
	if inventory.get_item_count(&"kinetic_converter") > 0:
		var p_speed: float = stats.get_stat(&"projectile_speed")
		var p_bonus: float = maxf(0.0, p_speed - 1.0)
		var dmg_bonus: float = p_bonus * 0.25
		stats.set_or_replace_modifier(&"base_damage", CharacterStats.StatModifier.new(&"kinetic_converter_dmg", dmg_bonus, true, &"kinetic_converter"))
	else:
		stats.remove_modifier(&"base_damage", &"kinetic_converter_dmg")

	# Resonador Gravitatorio
	if inventory.get_item_count(&"gravitational_resonator") > 0:
		var radius: float = stats.get_stat(&"pickup_radius")
		var armor_bonus: float = floorf(radius / 25.0)
		stats.set_or_replace_modifier(&"armor", CharacterStats.StatModifier.new(&"gravitational_resonator_armor", armor_bonus, false, &"gravitational_resonator"))
	else:
		stats.remove_modifier(&"armor", &"gravitational_resonator_armor")

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
