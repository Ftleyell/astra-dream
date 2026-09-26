class_name AlliedWingman
extends Node2D

## Escolta Aliada de la Flota de la Esperanza (Ruta Pacifista)
## Nave de una piloto perdonada que salta al combate para escoltar al jugador en la Oleada 11.
## Orbita alrededor del jugador y concentra fuego de apoyo sobre Astra Prime.

@export var pilot_id: StringName = &"nova"
@export var orbit_radius: float = 230.0
@export var orbit_speed: float = 1.2
@export var fire_rate: float = 1.2

var orbit_angle: float = 0.0
var player: Player = null
var target_boss: Node2D = null
var fire_timer: float = 0.0
var ship_sprite: Sprite2D = null
var shield_ring: Line2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("allies")
	_setup_visuals()
	_warp_in_effect()

func setup(p_pilot_id: StringName, p_angle: float) -> void:
	pilot_id = p_pilot_id
	orbit_angle = p_angle
	_setup_visuals()

func _setup_visuals() -> void:
	if not ship_sprite:
		ship_sprite = Sprite2D.new()
		ship_sprite.name = "ShipSprite"
		ship_sprite.scale = Vector2(0.42, 0.42)
		add_child(ship_sprite)

	var roster := CharacterData.load_roster()
	if roster.has(pilot_id):
		var cd: CharacterData = roster[pilot_id]
		var tex := cd.get_ship_texture()
		if tex:
			ship_sprite.texture = tex

	if not shield_ring:
		shield_ring = Line2D.new()
		shield_ring.name = "ShieldAura"
		shield_ring.width = 2.0
		shield_ring.default_color = Color(0.2, 0.9, 1.0, 0.6)
		var pts := PackedVector2Array()
		for i in range(17):
			var a := (TAU / 16.0) * float(i)
			pts.append(Vector2(cos(a), sin(a)) * 20.0)
		shield_ring.points = pts
		add_child(shield_ring)

func _warp_in_effect() -> void:
	scale = Vector2(0.1, 1.2)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	# Movimiento orbital suave alrededor del jugador
	orbit_angle += orbit_speed * delta
	var target_pos := player.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	global_position = global_position.lerp(target_pos, 10.0 * delta)

	# Buscar a Astra Prime o jefe activo
	if not is_instance_valid(target_boss):
		target_boss = get_tree().get_first_node_in_group("bosses") as Node2D

	if is_instance_valid(target_boss):
		var to_target := (target_boss.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, to_target.angle() + PI / 2.0, 8.0 * delta)
	else:
		rotation = orbit_angle + PI / 2.0

	# Disparo de apoyo
	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_fire_support_volley()

func _fire_support_volley() -> void:
	if not is_instance_valid(target_boss):
		return

	# Efecto visual de rayo láser hacia el jefe
	var laser := Line2D.new()
	laser.width = 4.0
	laser.default_color = Color(0.2, 1.0, 0.8, 1.0)
	laser.points = PackedVector2Array([global_position, target_boss.global_position])
	get_parent().add_child(laser)

	var tw := laser.create_tween()
	tw.tween_property(laser, "width", 0.0, 0.18)
	tw.chain().tween_callback(laser.queue_free)

	# Impacto en el jefe
	if target_boss.has_method("take_damage"):
		target_boss.take_damage(65.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("laser", 1.3, 1.3)
