class_name TelegraphIndicator
extends Node2D

## Componente modular de telegrafiado visual de ataques para enemigos y élites.
## Muestra una sombra o guía translúcida de advertencia (Cono, Anillo o Carril de Ondas)
## antes de que los proyectiles sean disparados, otorgando al jugador una lectura justa
## y tiempo de reacción al estilo de Enter the Gungeon.

enum TelegraphType {
	CONE,
	RING,
	WAVE
}

signal telegraph_completed()

@export var indicator_scale: Vector2 = Vector2(1.0, 1.0)

var _sprite: Sprite2D = null
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

func _process(_delta: float) -> void:
	if is_instance_valid(_sprite) and _sprite.visible:
		_sprite.global_position = global_position

func _load_textures() -> void:
	var c_path := "res://assets/sprites/telegraphs/telegraph_cone.png"
	var r_path := "res://assets/sprites/telegraphs/telegraph_ring.png"
	var w_path := "res://assets/sprites/telegraphs/telegraph_wave.png"

	if ResourceLoader.exists(c_path):
		_cone_tex = load(c_path) as Texture2D
	if ResourceLoader.exists(r_path):
		_ring_tex = load(r_path) as Texture2D
	if ResourceLoader.exists(w_path):
		_wave_tex = load(w_path) as Texture2D

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

	_sprite.visible = true
	_tween = create_tween()
	_tween.set_parallel(true)

	# Fade in elástico de advertencia suave (alfa 0.35 - 0.45 para no cegar al jugador)
	var target_alpha: float = 0.38
	var target_color: Color = _sprite.modulate
	target_color.a = target_alpha

	_tween.tween_property(_sprite, "modulate", target_color, p_duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", _sprite.scale * 1.08, p_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Callback al completar el telegrafiado
	_tween.set_parallel(false)
	_tween.tween_callback(self._on_duration_completed)

func _on_duration_completed() -> void:
	telegraph_completed.emit()
	dismiss()

func dismiss() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if not is_instance_valid(_sprite):
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
