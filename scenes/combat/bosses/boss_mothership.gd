class_name BossMothership
extends CharacterBody2D


signal health_changed(current: float, max_val: float)
signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String)

@export var boss_id: String = "boss_aegis"
@export var boss_name: String = "NODRIZA ORBITAL AEGIS"
@export var max_health: float = 1200.0

var current_health: float = 1200.0
var current_phase: int = 1
var is_dying: bool = false
var player: Player = null
var bullet_server: BulletServer = null

# Timers de patrones Danmaku
var radial_timer: float = 0.0
var aimed_timer: float = 0.0
var spiral_timer: float = 0.0
var spiral_tick: int = 0
var nova_timer: float = 0.0

# Nodos visuales
var sprite: Sprite2D = null
var core_poly: Polygon2D = null
var shield_ring: Node2D = null
var hit_flash_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("bosses")

	current_health = max_health
	_acquire_references()
	_setup_visuals()

	# Emitir estado inicial de salud
	health_changed.emit(current_health, max_health)

func _acquire_references() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
	if not bullet_server:
		bullet_server = get_node_or_null("/root/BulletServer") as BulletServer
		if not bullet_server and get_parent():
			bullet_server = get_parent().get_node_or_null("BulletServer") as BulletServer

func _setup_visuals() -> void:
	# 1. Contenedor de placas orbitales de energía
	shield_ring = Node2D.new()
	shield_ring.name = "ShieldRing"
	add_child(shield_ring)

	var plate_tex_path := "res://assets/enemies/shield_plate.png"
	var plate_tex: Texture2D = null
	if ResourceLoader.exists(plate_tex_path):
		plate_tex = load(plate_tex_path) as Texture2D

	for i in range(4):
		var angle := (TAU / 4.0) * float(i)
		var plate_pos := Vector2(cos(angle), sin(angle)) * 64.0
		if plate_tex:
			var p_spr := Sprite2D.new()
			p_spr.texture = plate_tex
			p_spr.position = plate_pos
			p_spr.rotation = angle + PI / 2.0
			p_spr.scale = Vector2(0.6, 0.6)
			shield_ring.add_child(p_spr)
		else:
			var poly := Polygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(-12, -6), Vector2(12, -6), Vector2(8, 6), Vector2(-8, 6)])
			poly.position = plate_pos
			poly.rotation = angle + PI / 2.0
			poly.color = Color(0.2, 0.8, 1.0, 0.8)
			shield_ring.add_child(poly)

	# 2. Sprite principal de la nodriza (dreadnought)
	var tank_tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tank_tex_path):
		var tex := load(tank_tex_path) as Texture2D
		if tex:
			sprite = Sprite2D.new()
			sprite.name = "HullSprite"
			sprite.texture = tex
			sprite.scale = Vector2(1.7, 1.7)
			add_child(sprite)

	# 3. Núcleo de energía reactivo en el centro
	core_poly = Polygon2D.new()
	core_poly.name = "ReactorCore"
	var core_pts := PackedVector2Array()
	for i in range(8):
		var a := (TAU / 8.0) * float(i)
		core_pts.append(Vector2(cos(a), sin(a)) * 22.0)
	core_poly.polygon = core_pts
	core_poly.color = Color(0.15, 0.85, 1.0, 0.95)
	add_child(core_poly)

	# 4. Colisionador circular robusto
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 58.0
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	if is_dying:
		return

	if not is_instance_valid(player):
		_acquire_references()

	# Rotación lenta de la nodriza y rotación opuesta del anillo de escudos
	var rot_speed := 0.4 if current_phase == 1 else 0.9
	rotation += delta * rot_speed
	if shield_ring:
		shield_ring.rotation -= delta * (rot_speed * 1.5)

	# Pulso del reactor central
	if core_poly:
		var time := Time.get_ticks_msec() * 0.005
		var scale_factor := 1.0 + sin(time) * 0.12
		core_poly.scale = Vector2(scale_factor, scale_factor)

	# Procesamiento Danmaku según fase
	if bullet_server:
		if current_phase == 1:
			_process_phase_1(delta)
		else:
			_process_phase_2(delta)

func _process_phase_1(delta: float) -> void:
	radial_timer += delta
	aimed_timer += delta

	# Anillos radiales con ventanas geométricas cada 1.8 segundos
	if radial_timer >= 1.8:
		radial_timer = 0.0
		bullet_server.fire_radial_ring(global_position, 20, 145.0, rotation, 0)
		_play_boss_sfx("laser", 0.8)

	# Salvas dirigidas de 5 proyectiles en abanico cada 1.3 segundos
	if aimed_timer >= 1.3:
		aimed_timer = 0.0
		if is_instance_valid(player):
			bullet_server.fire_aimed_spread(global_position, player.global_position, 5, 40.0, 215.0, 2)
			_play_boss_sfx("missile", 1.1)

func _process_phase_2(delta: float) -> void:
	spiral_timer += delta
	radial_timer += delta
	aimed_timer += delta

	# Espiral Dorada de Fermat continua y densa
	if spiral_timer >= 0.038:
		spiral_timer = 0.0
		spiral_tick += 1
		bullet_server.fire_fermat_spiral_tick(global_position, spiral_tick, 175.0, rotation, 1)

	# Pulsos Nova radiales acelerados cada 1.2 segundos
	if radial_timer >= 1.2:
		radial_timer = 0.0
		bullet_server.fire_radial_ring(global_position, 24, 165.0, rotation + PI / 12.0, 0)
		_play_boss_sfx("laser", 0.9)

	# Ráfagas dirigidas más rápidas e intensas
	if aimed_timer >= 1.5:
		aimed_timer = 0.0
		if is_instance_valid(player):
			bullet_server.fire_aimed_spread(global_position, player.global_position, 7, 48.0, 240.0, 2)
			_play_boss_sfx("missile", 1.2)

func take_damage(arg) -> void:
	if is_dying:
		return

	var dmg: float = 0.0
	var is_crit: bool = false
	if arg is HitContext:
		dmg = arg.final_damage
		is_crit = arg.is_crit
	elif arg is float or arg is int:
		dmg = float(arg)
	else:
		return

	current_health -= dmg
	health_changed.emit(maxf(0.0, current_health), max_health)

	var dmg_acc := get_node_or_null("DamageAccumulator") as DamageAccumulator
	if dmg_acc:
		dmg_acc.register_hit(dmg, is_crit)

	# Feedback visual de impacto (Hit-Flash)
	_apply_hit_flash()

	# Comprobar transición a Fase 2 (al 50% de HP)
	if current_phase == 1 and current_health <= max_health * 0.5:
		_transition_to_phase_2()

	# Muerte del jefe
	if current_health <= 0.0:
		_die()

func _apply_hit_flash() -> void:
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()

	modulate = Color(2.4, 2.4, 2.4, 1.0)
	hit_flash_tween = create_tween()
	var normal_color := Color(1.0, 0.7, 0.7, 1.0) if current_phase == 2 else Color.WHITE
	hit_flash_tween.tween_property(self, "modulate", normal_color, 0.12)

func _transition_to_phase_2() -> void:
	current_phase = 2
	phase_changed.emit(2)

	# Cambio cromático a modo sobrecarga (rojo / naranja térmico)
	if core_poly:
		core_poly.color = Color(1.0, 0.25, 0.15, 1.0)
	if sprite:
		sprite.modulate = Color(1.0, 0.65, 0.65, 1.0)

	# Sacudida visual de alerta de sobrecarga
	var cam := get_viewport().get_camera_2d() as GameCamera2D
	if cam:
		cam.add_trauma(0.5)

	_play_boss_sfx("explosion", 1.4)

func _die() -> void:
	is_dying = true

	# 1. Limpieza total de balas en pantalla (Screen Wipe)
	if bullet_server:
		bullet_server.bomb_clear_all()

	# 2. Sacudida cinematográfica de cámara
	var cam := get_viewport().get_camera_2d() as GameCamera2D
	if cam:
		cam.add_trauma(0.85)

	# 3. Efectos de sonido de destrucción
	_play_boss_sfx("bomb", 1.0)

	# 4. Otorgar recompensas: +100 Créditos al jugador
	_acquire_references()
	if is_instance_valid(player):
		player.add_credits(100)

	# 5. Generar Orbe Colosal de EXP (+150 EXP) en la posición de muerte
	var blob_scene: PackedScene = load("res://scenes/combat/pickups/exp_blob.tscn")
	if blob_scene:
		var blob := blob_scene.instantiate() as Node2D
		if blob.has_method("setup"):
			blob.setup(150.0, global_position)
		var spawn_parent: Node = get_parent() if get_parent() else get_tree().current_scene
		if spawn_parent:
			spawn_parent.call_deferred("add_child", blob)

	# 5b. Alta probabilidad (60%) de soltar consumible de campo (Bomba, Imán o Heal)
	if randf() <= 0.60:
		var consumable_scene := load("res://scenes/combat/pickups/field_consumable.tscn") as PackedScene
		if consumable_scene:
			var consumable := consumable_scene.instantiate() as Area2D
			if consumable:
				var consumable_script = load("res://scenes/combat/pickups/field_consumable.gd")
				var roll := randf()
				var c_type: int = consumable_script.ConsumableType.BOMB if roll < 0.50 else consumable_script.ConsumableType.HEAL
				var spawn_parent: Node = get_parent() if get_parent() else get_tree().current_scene
				if spawn_parent:
					spawn_parent.call_deferred("add_child", consumable)
					consumable.call_deferred("setup", c_type, global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35)))

	# 6. Activar Imán Global (Magnet): succiona toda la exp del mapa hacia el jugador
	ExpBlob.trigger_global_magnet(get_tree())

	# 7. Notificar derrota a los sistemas
	
	# Desbloqueo de Trofeo de Nodriza y dropeo de Materia Oscura (Fase 3)
	SaveManager.unlock_or_upgrade_trophy(&"trophy_boss_aegis", 1)
	var dm_scene: PackedScene = load("res://scenes/combat/pickups/dark_matter_orb.tscn")
	if dm_scene:
		var dm_orb = dm_scene.instantiate()
		if dm_orb:
			if dm_orb.has_method("setup"):
				dm_orb.setup(15, global_position)
			var spawn_target: Node = get_parent() if get_parent() else get_tree().current_scene
			if spawn_target:
				spawn_target.call_deferred("add_child", dm_orb)

	boss_defeated.emit(boss_id)
	var bus := get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("boss_defeated"):
		bus.boss_defeated.emit(boss_id)

	# 8. Secuencia visual de desintegración
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.4, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.38)
	tw.chain().tween_callback(queue_free)

func _play_boss_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name, pitch)
