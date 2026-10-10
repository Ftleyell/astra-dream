class_name PlayerDeathSequenceController
extends RefCounted

## PlayerDeathSequenceController.gd
## Controlador especializado para la secuencia de muerte y derrota del jugador.
## Oculta las partes de la nave, desactiva colisiones, reproduce efectos visuales y sonoros
## y emite player_died a los orquestadores superiores.

var explosion_vfx_scene: PackedScene = preload("res://scenes/combat/player/player_explosion_vfx.tscn")


func trigger_death_sequence(player: CharacterBody2D) -> void:
	if not is_instance_valid(player) or player.is_dead:
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
	if not is_instance_valid(player) or not explosion_vfx_scene:
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
