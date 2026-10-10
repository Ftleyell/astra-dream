class_name PlayerVessel
extends CharacterBody2D

## Nave de exploración libre para validación interactiva de Cosmos Engine.
## Proporciona propulsión inercial espacial realista con aceleración, frenado, giro suave
## y visuales reactivos completos del personaje seleccionado (ShipSprite con exo_pilot_flight shader,
## estela de plasma Sandevistan y selector dinámico de heroína en tiempo real).

const BASE_SHADER: Shader = preload("res://shaders/exo_pilot_flight.gdshader")
const FLAME_NOISE: Resource = preload("res://shaders/flame_noise.tres")

const AVAILABLE_CHARACTERS: Array[StringName] = [
	&"nova",
	&"valentina",
	&"kira",
	&"selene",
	&"roxy",
	&"echo",
	&"nyx"
]

@export var character_data: CharacterData
@export var max_speed: float = 2500.0
@export var acceleration: float = 1400.0
@export var friction: float = 400.0
@export var rotation_speed: float = 6.0
@export var boost_multiplier: float = 2.5

@onready var ship_sprite: Sprite2D = $ShipSprite
@onready var vessel_visual: Polygon2D = $VesselVisual
@onready var thruster_visual: Polygon2D = $ThrusterVisual
@onready var sandevistan_vfx: SandevistanFlightVFX = $SandevistanFlightVFX

var _current_input_dir: Vector2 = Vector2.ZERO
var _char_index: int = 0
var _flight_material: ShaderMaterial = null

func _ready() -> void:
	_init_character()

func _init_character() -> void:
	if character_data == null:
		var nova_res: Resource = load("res://data/characters/roster/nova.tres")
		if nova_res is CharacterData:
			character_data = nova_res as CharacterData

	_apply_character_visuals()

func _apply_character_visuals() -> void:
	if character_data == null:
		return

	# Color temático principal y secundario
	var p_color: Color = character_data.color
	var sec_color: Color = Color(1.0, 0.85, 0.4, 1.0)
	if p_color.h < 0.5:
		sec_color = Color.from_hsv(wrapf(p_color.h + 0.15, 0.0, 1.0), 0.7, 1.1)
	else:
		sec_color = Color.from_hsv(wrapf(p_color.h - 0.15, 0.0, 1.0), 0.7, 1.1)

	# Preparar ShaderMaterial
	if _flight_material == null:
		_flight_material = ShaderMaterial.new()
		_flight_material.shader = BASE_SHADER

	if FLAME_NOISE != null:
		_flight_material.set_shader_parameter("noise_texture", FLAME_NOISE)

	_flight_material.set_shader_parameter("primary_color", p_color)
	_flight_material.set_shader_parameter("secondary_color", sec_color)
	_flight_material.set_shader_parameter("thrust_intensity", 0.8)
	_flight_material.set_shader_parameter("speed_ratio", 0.0)
	_flight_material.set_shader_parameter("bank_tilt", 0.0)
	_flight_material.set_shader_parameter("chromatic_offset", 0.004)
	_flight_material.set_shader_parameter("core_gem_glow", 1.4)
	_flight_material.set_shader_parameter("flame_direction", Vector2(0.0, 1.0))

	var mask_tex: Texture2D = character_data.get_ship_mask()
	if mask_tex != null:
		_flight_material.set_shader_parameter("mask_texture", mask_tex)
		_flight_material.set_shader_parameter("has_mask", true)
		_flight_material.set_shader_parameter("hair_dir", character_data.hair_direction)
		_flight_material.set_shader_parameter("wave_freq", character_data.hair_wave_frequency)
		_flight_material.set_shader_parameter("hair_amp", character_data.hair_amplitude)
		_flight_material.set_shader_parameter("enable_thrusters", true)
	else:
		_flight_material.set_shader_parameter("has_mask", false)
		_flight_material.set_shader_parameter("enable_thrusters", false)

	# Asignar textura de nave de la heroína
	var ship_tex: Texture2D = character_data.get_ship_texture()
	if ship_sprite != null:
		if ship_tex != null:
			ship_sprite.texture = ship_tex
			ship_sprite.material = _flight_material
			ship_sprite.scale = Vector2(0.42, 0.42)
			ship_sprite.visible = true
			if vessel_visual != null:
				vessel_visual.visible = false
			if thruster_visual != null:
				thruster_visual.visible = false
		else:
			ship_sprite.visible = false
			if vessel_visual != null:
				vessel_visual.visible = true
				vessel_visual.color = p_color
			if thruster_visual != null:
				thruster_visual.visible = true

	# Configurar componente Sandevistan
	if sandevistan_vfx != null:
		sandevistan_vfx.configure_colors(p_color, sec_color)
		if ship_sprite != null and ship_sprite.visible:
			sandevistan_vfx.source_sprite = ship_sprite

func switch_to_next_character() -> void:
	_char_index = (_char_index + 1) % AVAILABLE_CHARACTERS.size()
	_load_character_by_name(AVAILABLE_CHARACTERS[_char_index])

func switch_to_previous_character() -> void:
	_char_index = (_char_index - 1 + AVAILABLE_CHARACTERS.size()) % AVAILABLE_CHARACTERS.size()
	_load_character_by_name(AVAILABLE_CHARACTERS[_char_index])

func _load_character_by_name(char_name: StringName) -> void:
	var path: String = "res://data/characters/roster/%s.tres" % String(char_name)
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is CharacterData:
			character_data = res as CharacterData
			_apply_character_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_E:
			switch_to_next_character()
		elif event.keycode == KEY_Q:
			switch_to_previous_character()

func _physics_process(delta: float) -> void:
	_handle_input()
	_apply_movement(delta)

func _process(delta: float) -> void:
	_update_visual_dynamics(delta)

func _handle_input() -> void:
	_current_input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		_current_input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		_current_input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		_current_input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		_current_input_dir.x += 1.0

	_current_input_dir = _current_input_dir.normalized()

func _apply_movement(delta: float) -> void:
	var is_boosting: bool = Input.is_key_pressed(KEY_SHIFT)
	var accel: float = acceleration
	var target_max_speed: float = max_speed

	if is_boosting:
		accel *= boost_multiplier
		target_max_speed *= boost_multiplier

	if _current_input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(_current_input_dir * target_max_speed, accel * delta)
		var target_angle: float = _current_input_dir.angle() + PI * 0.5
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

func _update_visual_dynamics(delta: float) -> void:
	var current_spd: float = velocity.length()
	var is_boosting: bool = Input.is_key_pressed(KEY_SHIFT) and current_spd > 200.0
	var speed_ratio: float = clampf(current_spd / (max_speed * boost_multiplier), 0.0, 1.0)

	if _flight_material != null:
		var target_thrust: float = 2.5 if is_boosting else (1.2 if current_spd > 50.0 else 0.4)
		_flight_material.set_shader_parameter("speed_ratio", speed_ratio)
		_flight_material.set_shader_parameter("thrust_intensity", target_thrust)

	if sandevistan_vfx != null and is_instance_valid(sandevistan_vfx):
		sandevistan_vfx.update_flight(delta, velocity, is_boosting)

## Devuelve la velocidad escalar instantánea actual.
func get_current_speed() -> float:
	return velocity.length()

## Devuelve el nombre del personaje activo para la telemetría.
func get_character_display_name() -> String:
	return character_data.display_name if character_data != null else "Piloto Estándar"

## Responde a recentrados del sistema de Origen Flotante para compensar efectos espaciales desacoplados.
func on_origin_shifted(shift: Vector2) -> void:
	if sandevistan_vfx != null and is_instance_valid(sandevistan_vfx):
		sandevistan_vfx.on_origin_shifted(shift)

