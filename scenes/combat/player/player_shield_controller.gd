class_name PlayerShieldController
extends RefCounted

## PlayerShieldController.gd
## Controlador modular de combate, escudos, mitigación de armadura, curación y secuencia de muerte.
## Gestiona capas defensivas (Caelia, Phase Inverter), daño mitigado por armadura,
## resucitación por chatarra estelar, regeneración de salud y conversión de núcleos de stats.

var explosion_vfx_scene: PackedScene = preload("res://scenes/combat/player/player_explosion_vfx.tscn")
var current_shield: float = 0.0
var max_shield: float = 0.0


func take_damage(
	player: CharacterBody2D,
	amount: float,
	stats: CharacterStats,
	inventory: Node
) -> void:
	if not player or player.is_dead or player.is_dashing or player.get("is_invulnerable") == true:
		return

	var debug_mgr: Node = player.get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_hp_active") and debug_mgr.is_infinite_hp_active():
		return

	# Capa de Escudo Gravitacional de Caelia
	if player.has_meta("caelia_shield_hook"):
		player.remove_meta("caelia_shield_hook")
		var tw := player.create_tween()
		if tw:
			tw.tween_property(player, "modulate", Color(1.0, 0.8, 0.2, 1.0), 0.1)
			tw.tween_property(player, "modulate", Color.WHITE, 0.2)
		var audio_mgr := player.get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click", 0.0, 1.8)
		return

	# Capa de Escudo Inversor de Fase
	if player.has_meta("phase_inverter_shield"):
		player.remove_meta("phase_inverter_shield")
		var tw := player.create_tween()
		if tw:
			tw.tween_property(player, "modulate", Color(0.3, 1.5, 2.0, 1.0), 0.1)
			tw.tween_property(player, "modulate", Color.WHITE, 0.2)
		var audio_mgr := player.get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click", 0.0, 2.2)
		return

	# Mitigación por Armadura
	var armor_val: float = stats.get_stat(&"armor") if stats else 0.0
	var mitigated_dmg: float = amount
	if armor_val >= 0.0:
		mitigated_dmg = maxf(1.0, amount * (100.0 / (100.0 + armor_val)))
	else:
		mitigated_dmg = amount * (2.0 - (100.0 / (100.0 - armor_val)))

	var remaining_dmg: float = mitigated_dmg
	if current_shield > 0.0:
		if current_shield >= remaining_dmg:
			current_shield -= remaining_dmg
			remaining_dmg = 0.0
		else:
			remaining_dmg -= current_shield
			current_shield = 0.0

	player.current_health -= remaining_dmg
	player.hit_flash_timer = 0.22

	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("player_hit")

	var max_hp: float = stats.get_stat(&"max_health") if stats else 100.0
	player.health_changed.emit(player.current_health, max_hp)
	update_conversion_core_stats(player, stats, inventory)

	if inventory and inventory.has_method("process_take_damage_procs"):
		inventory.process_take_damage_procs(mitigated_dmg, player)

	# Lógica Letal y Resucitación por Chatarra Estelar
	if player.has_meta(&"osp_active_frame"):
		player.current_health = maxf(1.0, player.current_health)
		return

	if player.current_health <= 0.0 and not player.is_dead:
		if inventory and inventory.has_method("get_item_count") and inventory.get_item_count(&"stellar_scrap") > 0 and not player.has_meta("stellar_scrap_used") and player.run_credits >= 100:
			player.set_meta("stellar_scrap_used", true)
			player.run_credits -= 100
			player.credits_changed.emit(player.run_credits)
			player.current_health = max_hp * 0.3
			player.health_changed.emit(player.current_health, max_hp)
			update_conversion_core_stats(player, stats, inventory)

			var tw := player.create_tween()
			if tw:
				tw.tween_property(player, "modulate", Color(2.5, 2.0, 0.5, 1.0), 0.15)
				tw.tween_property(player, "modulate", Color.WHITE, 0.3)
			var audio_mgr2 := player.get_node_or_null("/root/AudioManager")
			if audio_mgr2 and audio_mgr2.has_method("play_sfx"):
				audio_mgr2.play_sfx("upgrade_obtained", 1.5, 1.5)
			return

		trigger_death_sequence(player)


func trigger_death_sequence(player: CharacterBody2D) -> void:
	if not player or player.is_dead:
		return
	player.is_dead = true
	player.current_health = 0.0
	player.velocity = Vector2.ZERO

	# Ocultar todos los elementos visuales de la nave
	var ship_spr := player.get_node_or_null("ShipSprite") as Sprite2D
	if ship_spr:
		ship_spr.hide()
	var exo_spr := player.get_node_or_null("ExoArmorSprite") as Sprite2D
	if exo_spr:
		exo_spr.hide()
	var placeholder := player.get_node_or_null("VisualPlaceholder") as Polygon2D
	if placeholder:
		placeholder.hide()
	if player.hitbox_core:
		player.hitbox_core.hide()
	if player.weapon_controller:
		player.weapon_controller.hide()
	var aim_ind := player.get_node_or_null("AimModeIndicator")
	if aim_ind:
		aim_ind.hide()
	var ohb := player.get_node_or_null("OverheadHealthBar")
	if ohb:
		ohb.hide()
	var lcb := player.get_node_or_null("LaserChargeBar")
	if lcb:
		lcb.hide()

	# Desactivar colisiones
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)

	# Instanciar efecto VFX de explosión de la nave
	spawn_player_explosion_vfx(player)

	# SFX de explosión masiva
	var audio_mgr := player.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("explosion", 0.9, 2.5)

	player.player_died.emit()


func spawn_player_explosion_vfx(player: CharacterBody2D) -> void:
	if not player or not explosion_vfx_scene:
		return
	var vfx := explosion_vfx_scene.instantiate()
	if vfx:
		var p_color: Color = player.character_data.color if player.character_data else Color(0.2, 0.85, 1.0)
		if vfx.has_method("setup"):
			vfx.setup(player.global_position, p_color)
		else:
			vfx.global_position = player.global_position
		var tree := player.get_tree()
		var spawn_parent: Node = tree.current_scene if tree and tree.current_scene else player.get_parent()
		if spawn_parent:
			spawn_parent.add_child(vfx)


func handle_health_regen(
	player: CharacterBody2D,
	delta: float,
	stats: CharacterStats,
	inventory: Node
) -> void:
	if not player or not stats:
		return
	if inventory and inventory.has_method("get_item_count") and inventory.get_item_count(&"overdrain_module") > 0:
		return
	var max_hp: float = stats.get_stat(&"max_health")
	if player.current_health < max_hp and player.current_health > 0.0:
		var regen: float = stats.get_stat(&"health_regen")
		if regen > 0.0:
			var old_val: float = player.current_health
			player.current_health = minf(max_hp, player.current_health + regen * delta)
			if int(old_val * 2.0) != int(player.current_health * 2.0) or player.current_health >= max_hp:
				player.health_changed.emit(player.current_health, max_hp)


func update_conversion_core_stats(
	player: CharacterBody2D,
	stats: CharacterStats,
	inventory: Node
) -> void:
	if not player or not stats or not inventory:
		return

	# Célula Hemodinámica
	if inventory.has_method("get_item_count") and inventory.get_item_count(&"hemodynamic_cell") > 0:
		var max_hp: float = maxf(1.0, stats.get_stat(&"max_health"))
		var missing_pct: float = clampf(1.0 - (player.current_health / max_hp), 0.0, 1.0)
		var missing_tens: float = floorf(missing_pct * 10.0)
		var dmg_bonus: float = minf(0.25, missing_tens * 0.03)
		var atk_spd_bonus: float = minf(0.25, missing_tens * 0.02)
		stats.set_or_replace_modifier(&"base_damage", CharacterStats.StatModifier.new(&"hemodynamic_dmg", dmg_bonus, true, &"hemodynamic_cell"))
		stats.set_or_replace_modifier(&"attack_speed", CharacterStats.StatModifier.new(&"hemodynamic_spd", atk_spd_bonus, true, &"hemodynamic_cell"))
	else:
		stats.remove_modifier(&"base_damage", &"hemodynamic_dmg")
		stats.remove_modifier(&"attack_speed", &"hemodynamic_spd")

	# Conversor Cinético
	if inventory.has_method("get_item_count") and inventory.get_item_count(&"kinetic_converter") > 0:
		var p_speed: float = stats.get_stat(&"projectile_speed")
		var p_bonus: float = maxf(0.0, p_speed - 1.0)
		var dmg_bonus: float = p_bonus * 0.25
		stats.set_or_replace_modifier(&"base_damage", CharacterStats.StatModifier.new(&"kinetic_converter_dmg", dmg_bonus, true, &"kinetic_converter"))
	else:
		stats.remove_modifier(&"base_damage", &"kinetic_converter_dmg")

	# Resonador Gravitatorio
	if inventory.has_method("get_item_count") and inventory.get_item_count(&"gravitational_resonator") > 0:
		var radius: float = stats.get_stat(&"pickup_radius")
		var armor_bonus: float = floorf(radius / 25.0)
		stats.set_or_replace_modifier(&"armor", CharacterStats.StatModifier.new(&"gravitational_resonator_armor", armor_bonus, false, &"gravitational_resonator"))
	else:
		stats.remove_modifier(&"armor", &"gravitational_resonator_armor")
