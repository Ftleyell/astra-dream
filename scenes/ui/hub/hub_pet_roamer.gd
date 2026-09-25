class_name HubPetRoamer
extends Node3D

## HubPetRoamer.gd
## Mascota dron felina en 3D para el Hangar Espacial.
## Se desplaza de forma autónoma en el área central con saltitos y animación idle.

var pet_data: PetData = null
var sprite: Sprite3D = null
var shadow: MeshInstance3D = null

var _target_pos: Vector3 = Vector3.ZERO
var _move_speed: float = 2.0
var _is_waiting: bool = false
var _wait_timer: float = 0.0
var _anim_time: float = 0.0

const CENTER_MIN_X: float = -3.5
const CENTER_MAX_X: float = 3.5
const CENTER_MIN_Z: float = -1.5
const CENTER_MAX_Z: float = 7.5
const FLOOR_Y: float = 0.32

func setup(data: PetData, spawn_pos: Vector3) -> void:
	pet_data = data
	position = spawn_pos
	position.y = FLOOR_Y
	_target_pos = _pick_new_target()
	_move_speed = randf_range(1.8, 2.5)
	_wait_timer = randf_range(0.5, 2.0)
	_anim_time = randf_range(0.0, 5.0)

	# Sprite3D del gatito
	sprite = Sprite3D.new()
	sprite.name = "PetSprite"
	var tex: Texture2D = pet_data.get_icon_texture() if pet_data else null
	sprite.texture = tex
	sprite.pixel_size = 0.012
	sprite.offset = Vector2(0, 32)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.render_priority = 2
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)

	# Sombra suave bajo la mascota
	shadow = MeshInstance3D.new()
	shadow.name = "PetShadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.orientation = PlaneMesh.FACE_Y
	shadow.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.45)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.position.y = 0.02
	add_child(shadow)

func _process(delta: float) -> void:
	_anim_time += delta
	if _is_waiting:
		_wait_timer -= delta
		if sprite:
			sprite.position.y = sin(_anim_time * 3.5) * 0.02
		if _wait_timer <= 0.0:
			_is_waiting = false
			_target_pos = _pick_new_target()
	else:
		var current_xz := Vector2(position.x, position.z)
		var target_xz := Vector2(_target_pos.x, _target_pos.z)
		var diff := target_xz - current_xz
		var dist := diff.length()

		if dist < 0.2:
			_is_waiting = true
			_wait_timer = randf_range(1.8, 4.0)
			if sprite:
				sprite.position.y = 0.0
		else:
			var dir := diff.normalized()
			var move_step := dir * _move_speed * delta
			position.x += move_step.x
			position.z += move_step.y
			position.y = FLOOR_Y

			if sprite:
				if abs(dir.x) > 0.08:
					sprite.flip_h = (dir.x < 0)
				sprite.position.y = abs(sin(_anim_time * 9.5)) * 0.075

func _pick_new_target() -> Vector3:
	return Vector3(
		randf_range(CENTER_MIN_X, CENTER_MAX_X),
		FLOOR_Y,
		randf_range(CENTER_MIN_Z, CENTER_MAX_Z)
	)
