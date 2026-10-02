class_name CinematicDeathSequence
extends Node2D

## Orquestador desacoplado de la secuencia de muerte cinematográfica estilo Mega Man / Supernova.
## Congela el combate nativamente (get_tree().paused = true) y reproduce las 4 fases de catarsis:
## 1. Stun & Fractura (0.45s)
## 2. Aceleración Crítica (1.9s)
## 3. Implosión / El Vacío (0.12s)
## 4. Supernova & Flash (0.95s)

signal sequence_completed

@onready var shockwave_rect: ColorRect = $OverlayLayer/ShockwaveRect
@onready var flash_rect: ColorRect = $OverlayLayer/FlashRect

var target_boss: Node2D = null
var target_sprite: CanvasItem = null
var original_material: Material = null
var death_shader_mat: ShaderMaterial = null
var camera: GameCamera2D = null
var original_camera_zoom: Vector2 = Vector2.ONE
var boss_origin: Vector2 = Vector2.ZERO
var boss_bounds: Rect2 = Rect2(-50.0, -50.0, 100.0, 100.0)
var boss_energy_color: Color = Color(0.2, 0.95, 1.0, 1.0)
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_player_index: int = 0

const CinematicMicroExplosionScript = preload("res://scenes/combat/bosses/cinematic_micro_explosion.gd")
const CinematicResidualDebrisScript = preload("res://scenes/combat/bosses/cinematic_residual_debris.gd")

## Método estático para disparar la secuencia cinemática sobre cualquier jefe de manera desacoplada
static func play_for_boss(boss: Node2D, on_completed: Callable, instant: bool = false) -> void:
	if not is_instance_valid(boss):
		if on_completed.is_valid():
			on_completed.call()
		return

	# Si se ejecuta en modo headless o se solicita explícitamente instantáneo, completar de inmediato
	if instant or DisplayServer.get_name() == "headless":
		var bullet_server := boss.get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and boss.get_parent():
			bullet_server = boss.get_parent().get_node_or_null("BulletServer") as BulletServer
		if bullet_server:
			bullet_server.bomb_clear_all()
		if on_completed.is_valid():
			on_completed.call()
		return

	var seq_scene := load("res://scenes/combat/bosses/cinematic_death_sequence.tscn") as PackedScene
	if seq_scene:
		var seq := seq_scene.instantiate() as CinematicDeathSequence
		if seq:
			var parent_node: Node = boss.get_parent() if boss.get_parent() else boss.get_tree().current_scene
			parent_node.add_child(seq)
			if on_completed.is_valid():
				seq.sequence_completed.connect(on_completed)
			seq.start_sequence(boss)
			return

	if on_completed.is_valid():
		on_completed.call()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pool dedicado de 4 reproductores de audio para micro-explosiones (evita throttle de AudioManager)
	var exp_stream := load("res://assets/audio/sfx/explosion.wav") as AudioStream
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.stream = exp_stream
		add_child(p)
		_sfx_players.append(p)

## Inicia la secuencia completa sobre la entidad del jefe
func start_sequence(boss: Node2D) -> void:
	target_boss = boss
	if not is_instance_valid(target_boss):
		_finish_sequence()
		return

	boss_origin = target_boss.global_position

	# 1. Congelar escena de combate
	get_tree().paused = true

	# 2. Configurar cámara y zoom
	camera = get_viewport().get_camera_2d() as GameCamera2D
	if not camera:
		camera = get_tree().get_first_node_in_group("camera") as GameCamera2D
	if is_instance_valid(camera):
		camera.process_mode = Node.PROCESS_MODE_ALWAYS
		camera.focus_override = target_boss
		original_camera_zoom = camera.zoom

	# 3. Localizar sprite o componente visual y asignar shader de fractura
	_setup_visual_shader()

	# 4. Configurar centro normalizado del shockwave en pantalla
	_setup_shockwave_center()

	# 5. Ejecutar la coreografía de las 4 fases
	_run_choreography()

func _setup_visual_shader() -> void:
	if not is_instance_valid(target_boss):
		return

	# Buscar Sprite2D o CanvasItem principal del jefe/piloto
	if target_boss.has_node("HullSprite"):
		target_sprite = target_boss.get_node("HullSprite") as CanvasItem
	elif target_boss.get("hull_sprite") != null and target_boss.get("hull_sprite") is CanvasItem:
		target_sprite = target_boss.get("hull_sprite") as CanvasItem
	elif target_boss.has_node("ShipSprite"):
		target_sprite = target_boss.get_node("ShipSprite") as CanvasItem
	elif target_boss.get("ship_sprite") != null and target_boss.get("ship_sprite") is CanvasItem:
		target_sprite = target_boss.get("ship_sprite") as CanvasItem
	elif target_boss.has_node("VortexHull"):
		target_sprite = target_boss.get_node("VortexHull") as CanvasItem
	elif target_boss.has_node("GearSprite"):
		target_sprite = target_boss.get_node("GearSprite") as CanvasItem
	elif target_boss.has_node("MirrorHull"):
		target_sprite = target_boss.get_node("MirrorHull") as CanvasItem
	elif target_boss.has_node("Sprite2D"):
		target_sprite = target_boss.get_node("Sprite2D") as CanvasItem
	elif target_boss.get("sprite") != null and target_boss.get("sprite") is CanvasItem:
		target_sprite = target_boss.get("sprite") as CanvasItem
	else:
		# Primero buscar si tiene algún Sprite2D entre sus hijos
		for child in target_boss.get_children():
			if child is Sprite2D:
				target_sprite = child as CanvasItem
				break
		# Solo si no tiene Sprite2D, buscar Polygon2D
		if not target_sprite:
			for child in target_boss.get_children():
				if child is Polygon2D:
					target_sprite = child as CanvasItem
					break

	if is_instance_valid(target_sprite):
		original_material = target_sprite.material
		
		# Calcular límites para micro-explosiones
		if target_sprite is Sprite2D:
			var s2d := target_sprite as Sprite2D
			if s2d.texture:
				var g_scale: Vector2 = s2d.global_scale.abs()
				var sz: Vector2 = s2d.texture.get_size() * g_scale
				sz.x = maxf(sz.x, 180.0)
				sz.y = maxf(sz.y, 180.0)
				boss_bounds = Rect2(-sz.x * 0.45, -sz.y * 0.45, sz.x * 0.9, sz.y * 0.9)
		elif target_sprite is Polygon2D:
			var p2d := target_sprite as Polygon2D
			var poly := p2d.polygon
			if poly.size() > 0:
				var min_p := poly[0]
				var max_p := poly[0]
				for pt in poly:
					min_p = min_p.min(pt)
					max_p = max_p.max(pt)
				var g_scale: Vector2 = p2d.global_scale.abs()
				var sz: Vector2 = (max_p - min_p) * g_scale
				sz.x = maxf(sz.x, 180.0)
				sz.y = maxf(sz.y, 180.0)
				boss_bounds = Rect2(-sz.x * 0.45, -sz.y * 0.45, sz.x * 0.9, sz.y * 0.9)

		# Asignar shader de muerte
		var shader_res := load("res://shaders/boss_energy_death.gdshader") as Shader
		var noise_res := load("res://shaders/death_noise.tres") as Texture2D
		if shader_res:
			death_shader_mat = ShaderMaterial.new()
			death_shader_mat.shader = shader_res
			if noise_res:
				death_shader_mat.set_shader_parameter("noise_tex", noise_res)

			boss_energy_color = Color(0.2, 0.95, 1.0, 1.0)
			if target_boss.get("character_data") != null and target_boss.character_data.get("theme_color") != null:
				boss_energy_color = target_boss.character_data.theme_color
			elif target_boss.get("theme_color") != null and target_boss.get("theme_color") is Color:
				boss_energy_color = target_boss.theme_color
			elif target_boss.get("boss_id") != null and target_boss.boss_id == "boss_hermit_void":
				boss_energy_color = Color(0.65, 0.2, 1.0, 1.0)
			elif target_boss.get("boss_id") != null and target_boss.boss_id == "boss_ash_clock":
				boss_energy_color = Color(1.0, 0.65, 0.1, 1.0)
			elif target_boss.get("boss_id") != null and target_boss.boss_id == "boss_broken_mirror":
				boss_energy_color = Color(0.1, 0.9, 0.85, 1.0)
			elif target_boss.get("boss_id") != null and target_boss.boss_id == "boss_overflow_vortex":
				boss_energy_color = Color(0.95, 0.1, 0.3, 1.0)

			death_shader_mat.set_shader_parameter("energy_color", boss_energy_color)
			death_shader_mat.set_shader_parameter("energy_intensity", 3.2)
			death_shader_mat.set_shader_parameter("u_whiteness", 0.0)
			death_shader_mat.set_shader_parameter("u_fracture_progress", 0.0)
			death_shader_mat.set_shader_parameter("u_jitter_amount", 0.0)
			target_sprite.material = death_shader_mat

func _setup_shockwave_center() -> void:
	if not is_instance_valid(target_boss):
		return
	var screen_pos: Vector2 = target_boss.get_global_transform_with_canvas().origin
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		var norm_center := Vector2(screen_pos.x / vp_size.x, screen_pos.y / vp_size.y)
		if shockwave_rect and shockwave_rect.material is ShaderMaterial:
			var sm := shockwave_rect.material as ShaderMaterial
			sm.set_shader_parameter("center", norm_center)
			sm.set_shader_parameter("screen_aspect", vp_size.x / vp_size.y)
			sm.set_shader_parameter("size", 0.0)

func _run_choreography() -> void:
	# =========================================================================
	# FASE 1: Stun & Fractura (0.45s)
	# =========================================================================
	if AudioManager:
		AudioManager.play_sfx("player_hit", 0.55, 2.0)

	var tw_phase1 := create_tween()
	tw_phase1.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_phase1.set_parallel(true)

	if death_shader_mat:
		tw_phase1.tween_method(
			func(val: float): death_shader_mat.set_shader_parameter("u_fracture_progress", val),
			0.0, 0.45, 0.45
		)
		tw_phase1.tween_method(
			func(val: float): death_shader_mat.set_shader_parameter("u_whiteness", val),
			0.0, 0.35, 0.45
		)
		tw_phase1.tween_method(
			func(val: float): death_shader_mat.set_shader_parameter("u_jitter_amount", val),
			0.0, 3.5, 0.45
		)

	print("[CinematicDeathSequence] Iniciando Fase 1: Stun & Fractura...")
	await tw_phase1.finished
	print("[CinematicDeathSequence] Fase 1 completada. Iniciando Fase 2: Aceleración Crítica...")

	# =========================================================================
	# FASE 2: Aceleración Crítica (1.9s)
	# =========================================================================
	var tw_phase2 := create_tween()
	tw_phase2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_phase2.set_parallel(true)

	if death_shader_mat:
		tw_phase2.tween_method(
			func(val: float): death_shader_mat.set_shader_parameter("u_fracture_progress", val),
			0.45, 1.0, 1.9
		)
		tw_phase2.tween_method(
			func(val: float): death_shader_mat.set_shader_parameter("u_whiteness", val),
			0.35, 1.0, 1.9
		)
		tw_phase2.tween_method(
			func(val: float): death_shader_mat.set_shader_parameter("u_jitter_amount", val),
			3.5, 18.0, 1.9
		)

	if is_instance_valid(camera):
		tw_phase2.tween_property(camera, "zoom", original_camera_zoom * 1.15, 1.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Bucle asíncrono exponencial de micro-explosiones
	var elapsed: float = 0.0
	var delay: float = 0.28
	var pitch: float = 0.85
	var count: int = 0

	while elapsed < 1.9:
		count += 1
		_spawn_micro_explosion()
		if not _sfx_players.is_empty():
			var p := _sfx_players[_sfx_player_index]
			_sfx_player_index = (_sfx_player_index + 1) % _sfx_players.size()
			p.pitch_scale = clampf(pitch * randf_range(0.96, 1.04), 0.7, 1.5)
			p.volume_db = randf_range(1.5, 3.5)
			p.play()
		if is_instance_valid(camera):
			camera.add_trauma(0.18)

		pitch = minf(1.30, pitch + 0.035)
		var step_wait := create_tween()
		step_wait.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		step_wait.tween_interval(delay)
		await step_wait.finished

		elapsed += delay
		delay = maxf(0.045, delay * 0.83)

	print("[CinematicDeathSequence] Fin bucle micro-explosiones (total: %d)" % count)
	if tw_phase2 and tw_phase2.is_running():
		await tw_phase2.finished
	print("[CinematicDeathSequence] Fase 2 completada.")

	# =========================================================================
	# FASE 3: Implosión (El Vacío) (0.12s)
	# =========================================================================
	# Corte seco de audio absoluto (100ms)
	AudioServer.set_bus_mute(0, true)

	if death_shader_mat:
		death_shader_mat.set_shader_parameter("u_jitter_amount", 0.0)

	var orig_scale: Vector2 = target_boss.scale if is_instance_valid(target_boss) else Vector2.ONE
	var tw_implosion := create_tween()
	tw_implosion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if is_instance_valid(target_boss):
		tw_implosion.tween_property(target_boss, "scale", orig_scale * 0.65, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	else:
		tw_implosion.tween_interval(0.12)

	await tw_implosion.finished

	# Restaurar audio tras el vacío
	AudioServer.set_bus_mute(0, false)

	# =========================================================================
	# FASE 4: Supernova & Flash (0.95s)
	# =========================================================================
	# 1. Screen-Wipe de proyectiles masivos
	var bullet_server := get_node_or_null("/root/BulletServer") as BulletServer
	if not bullet_server and get_parent():
		bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer
	if bullet_server:
		bullet_server.bomb_clear_all()

	# 2. Audio de detonación catártica
	if AudioManager:
		AudioManager.play_sfx("bomb", 0.85, 6.0)
		AudioManager.play_sfx("explosion", 0.60, 4.0)

	# 3. Sacudida máxima de cámara
	if is_instance_valid(camera):
		camera.add_trauma(1.0)

	# 4. Destello blanco cegador (FlashRect)
	flash_rect.color = Color(1.0, 1.0, 1.0, 1.0)

	# 5. Desvanecer jefe y spawn de materia residual
	if is_instance_valid(target_boss):
		target_boss.visible = false
	_spawn_residual_debris()

	# 6. Tweens paralelos de Shockwave, Flash y Retorno de Cámara
	var tw_supernova := create_tween()
	tw_supernova.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_supernova.set_parallel(true)

	tw_supernova.tween_property(flash_rect, "color:a", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if shockwave_rect and shockwave_rect.material is ShaderMaterial:
		var sm := shockwave_rect.material as ShaderMaterial
		tw_supernova.tween_method(
			func(val: float): sm.set_shader_parameter("size", val),
			0.0, 1.45, 0.85
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if is_instance_valid(camera):
		tw_supernova.tween_property(camera, "zoom", original_camera_zoom, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tw_supernova.finished

	_finish_sequence()

func _spawn_micro_explosion() -> void:
	var offset := Vector2(
		randf_range(boss_bounds.position.x, boss_bounds.end.x),
		randf_range(boss_bounds.position.y, boss_bounds.end.y)
	)
	var spawn_pos := boss_origin + offset
	var micro = CinematicMicroExplosionScript.new()
	add_child(micro)
	micro.setup(spawn_pos, randf_range(65.0, 115.0), boss_energy_color)

func _spawn_residual_debris() -> void:
	var debris = CinematicResidualDebrisScript.new()
	debris.setup(boss_origin, 28, boss_energy_color)
	var parent_node: Node = get_parent() if get_parent() else self
	parent_node.add_child(debris)

func _finish_sequence() -> void:
	# Asegurar que el audio esté desmuteado pase lo que pase
	AudioServer.set_bus_mute(0, false)

	if is_instance_valid(camera):
		camera.focus_override = null
		camera.zoom = original_camera_zoom

	get_tree().paused = false
	sequence_completed.emit()
	queue_free()
