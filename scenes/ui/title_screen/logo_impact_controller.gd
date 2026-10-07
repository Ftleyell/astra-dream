class_name LogoImpactController
extends Node

## LogoImpactController
## Controlador desacoplado para la secuencia de impacto cinético, VFX y reposo
## del logotipo estilo 32-bits (Mega Man X) en interfaces de Godot 4.

signal impact_landed
signal sequence_completed

const SHADER_RES: Shader = preload("res://shaders/ui/mega_man_logo_vfx.gdshader")

@export var config: TitleImpactConfig
@export var logo_target: Control
@export var vfx_anchor: Control
@export var ghost_container: Control
@export var secondary_panel: Control
@export var spark_particles: GPUParticles2D

var _shader_material: ShaderMaterial
var _trauma: float = 0.0
var _noise: FastNoiseLite
var _is_running: bool = false
var _origin_position_y: float = 0.0
var _idle_scale_tween: Tween
var _idle_float_tween: Tween


func _ready() -> void:
	if not config:
		config = preload("res://scenes/ui/title_screen/default_title_impact_config.tres")

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = config.noise_frequency
	_noise.seed = randi()

	_resolve_node_references()
	_setup_shader()


func _resolve_node_references() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return
	if not logo_target:
		logo_target = parent_node.find_child("LogoTexture", true, false) as Control
	if not vfx_anchor:
		vfx_anchor = parent_node.find_child("VFXAnchor", true, false) as Control
	if not ghost_container:
		ghost_container = parent_node.find_child("GhostContainer", true, false) as Control
	if not secondary_panel:
		secondary_panel = parent_node.find_child("PatchNotesPanel", true, false) as Control


func _setup_shader() -> void:
	if not logo_target:
		return

	if logo_target.material is ShaderMaterial and (logo_target.material as ShaderMaterial).shader == SHADER_RES:
		_shader_material = logo_target.material as ShaderMaterial
	else:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = SHADER_RES
		logo_target.material = _shader_material

	_shader_material.set_shader_parameter("flash_amount", 0.0)
	_shader_material.set_shader_parameter("flash_color", config.flash_color)
	_shader_material.set_shader_parameter("glitch_intensity", 0.0)
	_shader_material.set_shader_parameter("shine_active", false)


func _process(delta: float) -> void:
	if _trauma > 0.0 and vfx_anchor:
		_trauma = maxf(_trauma - config.trauma_decay * delta, 0.0)
		var strength: float = pow(_trauma, 2.0)
		var ticks: float = float(Time.get_ticks_msec()) * 0.1
		var ox: float = config.shake_offset_x * strength * _noise.get_noise_2d(ticks, 0.0)
		var oy: float = config.shake_offset_y * strength * _noise.get_noise_2d(0.0, ticks)
		vfx_anchor.position = Vector2(ox, oy)
	elif vfx_anchor and vfx_anchor.position != Vector2.ZERO:
		vfx_anchor.position = Vector2.ZERO


func play_sequence() -> void:
	if _is_running:
		return

	if not logo_target:
		_resolve_node_references()

	if not logo_target:
		sequence_completed.emit()
		return

	_is_running = true
	_setup_shader()

	if logo_target.size.x <= 1.0:
		await get_tree().process_frame

	# Configurar punto pivote centrado para escalados limpios de Control
	logo_target.pivot_offset = logo_target.size * 0.5
	_origin_position_y = logo_target.position.y

	# Ocultar panel secundario si está definido y visible
	if secondary_panel and secondary_panel.visible:
		secondary_panel.modulate.a = 0.0
		secondary_panel.scale = Vector2(0.96, 0.96)
		secondary_panel.pivot_offset = secondary_panel.size * 0.5

	# Estado inicial de caída
	logo_target.scale = config.start_scale
	logo_target.position.y = _origin_position_y - config.drop_height_offset
	logo_target.modulate.a = 0.0

	_execute_drop()


func _execute_drop() -> void:
	# Desencadenar afterimages durante el descenso en tarea asíncrona desacoplada
	if ghost_container and config.afterimage_count > 0:
		_spawn_ghost_cascade()

	var tw_drop: Tween = create_tween().set_parallel(true)
	tw_drop.tween_property(logo_target, "position:y", _origin_position_y, config.drop_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_drop.tween_property(logo_target, "scale", config.target_scale, config.drop_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_drop.tween_property(logo_target, "modulate:a", 1.0, config.drop_duration * 0.35)
	tw_drop.finished.connect(_on_impact)


func _spawn_ghost_cascade() -> void:
	var step_time: float = config.drop_duration / float(config.afterimage_count + 1)
	for i: int in range(config.afterimage_count):
		await get_tree().create_timer(step_time).timeout
		if not is_instance_valid(logo_target) or not _is_running:
			return
		_spawn_ghost_trail()


func _on_impact() -> void:
	impact_landed.emit()

	# 1. Partículas
	if spark_particles:
		spark_particles.restart()
		spark_particles.emitting = true

	# 2. Flash y Glitch en Shader
	if _shader_material:
		_shader_material.set_shader_parameter("flash_amount", 1.0)
		_shader_material.set_shader_parameter("glitch_intensity", 0.85)

	# 3. Hitstop
	if config.use_engine_time_scale:
		Engine.time_scale = 0.0
		await get_tree().create_timer(config.hitstop_duration, true, false, true).timeout
		Engine.time_scale = 1.0
	else:
		await get_tree().create_timer(config.hitstop_duration).timeout

	# 4. Inyección de trauma para sacudida local
	_trauma = 1.0

	# 5. Deformación Squash & Stretch
	var tw_settle: Tween = create_tween()
	tw_settle.tween_property(logo_target, "scale", config.squash_scale, config.squash_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_settle.tween_property(logo_target, "scale", config.stretch_scale, config.stretch_duration)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_settle.tween_property(logo_target, "scale", config.target_scale, config.bounce_duration)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# 6. Atenuación de flash y glitch
	if _shader_material:
		var tw_shader: Tween = create_tween().set_parallel(true)
		tw_shader.tween_property(_shader_material, "shader_parameter/flash_amount", 0.0, config.flash_duration)\
			.set_ease(Tween.EASE_OUT)
		tw_shader.tween_property(_shader_material, "shader_parameter/glitch_intensity", 0.0, config.glitch_duration)\
			.set_ease(Tween.EASE_OUT)

	# 7. Cascada del panel secundario (Patch Notes / Menú) si está visible
	if secondary_panel and secondary_panel.visible:
		var tw_panel: Tween = create_tween().set_parallel(true)
		tw_panel.chain().tween_interval(config.panel_reveal_delay)
		tw_panel.chain().tween_property(secondary_panel, "modulate:a", 1.0, config.panel_reveal_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_panel.tween_property(secondary_panel, "scale", Vector2.ONE, config.panel_reveal_duration)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw_settle.chain().tween_callback(_finalize_sequence)


func _finalize_sequence() -> void:
	# 8. Reposo activo
	if _shader_material:
		_shader_material.set_shader_parameter("shine_active", true)

	_start_idle_loops()
	_is_running = false
	sequence_completed.emit()


func _spawn_ghost_trail() -> void:
	if not ghost_container or not logo_target:
		return

	var ghost: Control
	if logo_target is TextureRect:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = (logo_target as TextureRect).texture
		tex_rect.expand_mode = (logo_target as TextureRect).expand_mode
		tex_rect.stretch_mode = (logo_target as TextureRect).stretch_mode
		tex_rect.size = logo_target.size
		tex_rect.pivot_offset = logo_target.pivot_offset
		ghost = tex_rect
	else:
		ghost = logo_target.duplicate() as Control

	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.global_position = logo_target.global_position
	ghost.scale = logo_target.scale
	ghost.modulate = config.afterimage_color
	ghost_container.add_child(ghost)

	var tw: Tween = ghost.create_tween().set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, config.afterimage_fade_time).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", ghost.scale * config.afterimage_scale_ratio, config.afterimage_fade_time)\
		.set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ghost.queue_free)


func _start_idle_loops() -> void:
	if not is_instance_valid(logo_target):
		return

	if _idle_scale_tween and _idle_scale_tween.is_valid():
		_idle_scale_tween.kill()
	if _idle_float_tween and _idle_float_tween.is_valid():
		_idle_float_tween.kill()

	# Respiración sinusoidal en escala
	_idle_scale_tween = logo_target.create_tween().set_loops()
	_idle_scale_tween.tween_property(logo_target, "scale", config.idle_scale_a, config.idle_scale_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_scale_tween.tween_property(logo_target, "scale", config.idle_scale_b, config.idle_scale_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Flotación vertical desfasada
	_idle_float_tween = logo_target.create_tween().set_loops()
	_idle_float_tween.tween_property(logo_target, "position:y", _origin_position_y - config.idle_float_offset, config.idle_float_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_float_tween.tween_property(logo_target, "position:y", _origin_position_y + config.idle_float_offset, config.idle_float_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
