class_name TelegraphIndicator
extends Node2D

## Componente modular de telegrafiado visual de ataques para enemigos y élites.
## Muestra una sombra o guía translúcida de advertencia (Cono, Anillo o Carril de Ondas)
## antes de que los proyectiles sean disparados, otorgando al jugador una lectura justa
## y tiempo de reacción al estilo de Enter the Gungeon.

enum TelegraphType {
	CONE,
	RING,
	WAVE,
	CHARGE_LANE
}

signal telegraph_completed()

@export var indicator_scale: Vector2 = Vector2(1.0, 1.0)

var _sprite: Sprite2D = null
var _laser_line: Line2D = null
var _laser_glow: Line2D = null
var _laser_direction: Vector2 = Vector2.RIGHT
var _tween: Tween = null
var _active_type: TelegraphType = TelegraphType.CONE
var _cone_tex: Texture2D = null
var _ring_tex: Texture2D = null
var _wave_tex: Texture2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_sprite()
	_load_textures()

func _setup_sprite() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "TelegraphSprite"
		_sprite.visible = false
		_sprite.top_level = true
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		
		# Modo aditivo para brillo holográfico sci-fi
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_sprite.material = mat
		add_child(_sprite)

	if _laser_line == null:
		_laser_glow = Line2D.new()
		_laser_glow.name = "TelegraphLaserGlow"
		_laser_glow.visible = false
		_laser_glow.top_level = true
		_laser_glow.width = 9.0
		_laser_glow.default_color = Color(1.0, 0.15, 0.25, 0.35)
		var mat_glow := CanvasItemMaterial.new()
		mat_glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_laser_glow.material = mat_glow
		add_child(_laser_glow)

		_laser_line = Line2D.new()
		_laser_line.name = "TelegraphLaserCore"
		_laser_line.visible = false
		_laser_line.top_level = true
		_laser_line.width = 2.5
		_laser_line.default_color = Color(1.5, 0.85, 0.4, 0.95)
		var mat_core := CanvasItemMaterial.new()
		mat_core.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_laser_line.material = mat_core
		add_child(_laser_line)

func _process(_delta: float) -> void:
	if is_instance_valid(_sprite) and _sprite.visible:
		_sprite.global_position = global_position
	if is_instance_valid(_laser_line) and _laser_line.visible:
		var end_pt: Vector2 = global_position + _laser_direction * 2600.0
		var pts: PackedVector2Array = PackedVector2Array([global_position, end_pt])
		_laser_line.points = pts
		if is_instance_valid(_laser_glow):
			_laser_glow.points = pts

func _load_textures() -> void:
	if _cone_tex != null and _ring_tex != null and _wave_tex != null:
		return

	var c_path := "res://assets/sprites/telegraphs/telegraph_cone.png"
	var r_path := "res://assets/sprites/telegraphs/telegraph_ring.png"
	var w_path := "res://assets/sprites/telegraphs/telegraph_wave.png"

	if _cone_tex == null and ResourceLoader.exists(c_path):
		_cone_tex = load(c_path) as Texture2D
	if _ring_tex == null and ResourceLoader.exists(r_path):
		_ring_tex = load(r_path) as Texture2D
	if _wave_tex == null and ResourceLoader.exists(w_path):
		_wave_tex = load(w_path) as Texture2D

	if _cone_tex == null:
		_cone_tex = _create_fallback_texture(Color(1.0, 0.72, 0.1, 0.8))
	if _ring_tex == null:
		_ring_tex = _create_fallback_texture(Color(0.15, 0.65, 1.0, 0.8))
	if _wave_tex == null:
		_wave_tex = _create_fallback_texture(Color(0.85, 0.25, 1.0, 0.8))

func _create_fallback_texture(color: Color) -> Texture2D:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func start_telegraph(p_type: TelegraphType, p_duration: float, p_target_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_sprite):
		_setup_sprite()
	_load_textures()

	_active_type = p_type
	if _tween and _tween.is_valid():
		_tween.kill()

	_sprite.global_position = global_position

	# Configurar textura, orientación y anclaje según el tipo de ataque
	match p_type:
		TelegraphType.CONE:
			_sprite.texture = _cone_tex
			_sprite.offset = Vector2(0.0, -115.0) # Vértice en el centro del emisor
			_sprite.scale = indicator_scale * Vector2(1.2, 1.2)
			if p_target_dir.length_squared() > 0.001:
				_sprite.global_rotation = p_target_dir.angle() + (PI / 2.0)
			else:
				_sprite.global_rotation = 0.0
			_sprite.modulate = Color(1.0, 0.72, 0.1, 0.0) # Ámbar radiactivo

		TelegraphType.RING:
			_sprite.texture = _ring_tex
			_sprite.offset = Vector2.ZERO # Centrado en el enemigo
			_sprite.scale = indicator_scale * Vector2(1.1, 1.1)
			_sprite.global_rotation = 0.0
			_sprite.modulate = Color(0.15, 0.65, 1.0, 0.0) # Azul cobalto

		TelegraphType.WAVE:
			_sprite.texture = _wave_tex
			_sprite.offset = Vector2(0.0, -128.0) # Se extiende hacia el frente
			_sprite.scale = indicator_scale * Vector2(1.0, 1.3)
			if p_target_dir.length_squared() > 0.001:
				_sprite.global_rotation = p_target_dir.angle() + (PI / 2.0)
			else:
				_sprite.global_rotation = 0.0
			_sprite.modulate = Color(0.85, 0.25, 1.0, 0.0) # Púrpura abisal

		TelegraphType.CHARGE_LANE:
			_sprite.visible = false
			_laser_direction = p_target_dir.normalized() if p_target_dir.length_squared() > 0.001 else Vector2.RIGHT
			if is_instance_valid(_laser_line) and is_instance_valid(_laser_glow):
				var end_pt: Vector2 = global_position + _laser_direction * 2600.0
				var pts: PackedVector2Array = PackedVector2Array([global_position, end_pt])
				_laser_line.points = pts
				_laser_glow.points = pts
				_laser_line.visible = true
				_laser_glow.visible = true
				_laser_line.modulate = Color(1.0, 1.0, 1.0, 0.0)
				_laser_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)

	if p_type == TelegraphType.CHARGE_LANE:
		_tween = create_tween()
		_tween.set_parallel(true)
		if is_instance_valid(_laser_line):
			_tween.tween_property(_laser_line, "modulate:a", 1.0, p_duration * 0.35)
			_tween.tween_property(_laser_line, "width", 3.2, p_duration).from(1.5)
		if is_instance_valid(_laser_glow):
			_tween.tween_property(_laser_glow, "modulate:a", 1.0, p_duration * 0.35)
			_tween.tween_property(_laser_glow, "width", 11.0, p_duration).from(5.0)
		_tween.set_parallel(false)
		_tween.tween_callback(self._on_duration_completed)
		return

	_sprite.visible = true
	_tween = create_tween()
	_tween.set_parallel(true)

	# Fade in elástico de advertencia suave (alfa 0.35 - 0.45 para no cegar al jugador)
	var target_alpha: float = 0.38
	var target_color: Color = _sprite.modulate
	target_color.a = target_alpha

	_tween.tween_property(_sprite, "modulate", target_color, p_duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", _sprite.scale * 1.06, p_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Callback al completar el telegrafiado
	_tween.set_parallel(false)
	_tween.tween_callback(self._on_duration_completed)

func _on_duration_completed() -> void:
	telegraph_completed.emit()
	if _active_type != TelegraphType.CHARGE_LANE:
		dismiss()

func dismiss() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	if is_instance_valid(_laser_line) and _laser_line.visible:
		var line_tw := create_tween()
		line_tw.set_parallel(true)
		line_tw.tween_property(_laser_line, "modulate:a", 0.0, 0.08)
		if is_instance_valid(_laser_glow):
			line_tw.tween_property(_laser_glow, "modulate:a", 0.0, 0.08)
		line_tw.set_parallel(false)
		line_tw.tween_callback(func() -> void:
			if is_instance_valid(_laser_line): _laser_line.visible = false
			if is_instance_valid(_laser_glow): _laser_glow.visible = false
		)

	if not is_instance_valid(_sprite) or not _sprite.visible:
		return

	# Rápida contracción y desvanecimiento al momento del disparo
	var fade_tw := create_tween()
	fade_tw.set_parallel(true)
	var end_col: Color = _sprite.modulate
	end_col.a = 0.0
	fade_tw.tween_property(_sprite, "modulate", end_col, 0.08)
	fade_tw.tween_property(_sprite, "scale", _sprite.scale * 0.9, 0.08)
	fade_tw.set_parallel(false)
	fade_tw.tween_callback(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.visible = false
	)
