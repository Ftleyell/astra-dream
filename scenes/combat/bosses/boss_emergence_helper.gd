class_name BossEmergenceHelper
extends RefCounted

## Administrador desacoplado de aparición e interpolación cinemática para Jefes Titanes.
## Evita pre-renderizados accidentales o disparos prematuros ocultando el coloso hasta
## que la ruptura espaciotemporal se estabilice y la mascota emita la alerta de radar.

static func prepare_boss(boss: Node2D, target_pos: Vector2) -> void:
	if not is_instance_valid(boss):
		return

	boss.global_position = target_pos
	boss.process_mode = Node.PROCESS_MODE_ALWAYS
	boss.scale = Vector2(0.01, 0.01)
	boss.modulate = Color(2.5, 2.5, 3.5, 0.0)

	# Preservar capas de colisión y suspenderlas durante el spawn cinemático
	if boss is CollisionObject2D:
		var c_obj := boss as CollisionObject2D
		c_obj.set_meta("_cinematic_saved_layer", c_obj.collision_layer)
		c_obj.set_meta("_cinematic_saved_mask", c_obj.collision_mask)
		c_obj.collision_layer = 0
		c_obj.collision_mask = 0


static func emerge_boss(boss: Node2D, tear: Node2D = null, callback: Callable = Callable()) -> void:
	if not is_instance_valid(boss):
		if callback.is_valid():
			callback.call()
		return

	boss.process_mode = Node.PROCESS_MODE_ALWAYS

	# Sonido colosal de manifestación titánica
	var audio_mgr := boss.get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("bomb_explode", -1.0, 0.8)

	var cam := boss.get_tree().get_first_node_in_group("camera") as Camera2D
	if cam and cam.has_method("add_trauma"):
		cam.call("add_trauma", 0.55)

	var tw := boss.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Expansión majestuosa con elasticidad e iluminación estelar
	tw.tween_property(boss, "scale", Vector2(2.0, 2.0), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(boss):
			if callback.is_valid():
				callback.call()
			return

		# Restaurar capas de colisión del jefe
		if boss is CollisionObject2D and boss.has_meta("_cinematic_saved_layer"):
			var c_obj := boss as CollisionObject2D
			c_obj.collision_layer = int(boss.get_meta("_cinematic_saved_layer", 2))
			c_obj.collision_mask = int(boss.get_meta("_cinematic_saved_mask", 1))

		boss.process_mode = Node.PROCESS_MODE_PAUSABLE

		if is_instance_valid(tear) and tear.has_method("start_collapse"):
			tear.start_collapse()

		if callback.is_valid():
			callback.call()
	)
