class_name DialogueBackdropLayer
extends CanvasLayer

## Capa Cinematográfica de Fondo y Efectos para Diálogos (Dialogic 2)
## Oscurece el juego de fondo (~72%), atenúa el HUD principal, destaca al orador
## activo con escala/brillo y anima a las mascotas con un balanceo Tilt & Wiggle (-4° a +4°).

@onready var backdrop_rect: ColorRect = $BackdropRect

var _fade_tween: Tween = null
var _hud_layer: CanvasLayer = null
var _active_pet_node: Node = null
var _is_dialogue_active: bool = false
var _pet_wiggle_active: bool = false
var _wiggle_time: float = 0.0
var hold_dimmer: bool = false:
	set(val):
		hold_dimmer = val
		if not hold_dimmer and not _is_dialogue_active:
			fade_out(0.2)

const SHOWCASE_SHADER := preload("res://shaders/pilot_showcase_hologram.gdshader")

const PET_IDS: Array[String] = ["mochi", "kuro", "luna", "pip", "cosmo"]
const WIGGLE_ANGLE_MAX: float = 4.0
const WIGGLE_SPEED: float = 12.0

const PILOT_CONFIGS: Dictionary = {
	"nova": { "color": Color(1.00, 0.40, 0.05), "bottom_fade_start": 0.90 },
	"echo": { "color": Color(0.12, 0.85, 0.95), "bottom_fade_start": 0.90 },
	"kira": { "color": Color(0.95, 0.78, 0.12), "bottom_fade_start": 0.90 },
	"nyx": { "color": Color(0.60, 0.20, 0.88), "bottom_fade_start": 0.90 },
	"roxy": { "color": Color(0.90, 0.14, 0.22), "bottom_fade_start": 0.90 },
	"selene": { "color": Color(0.35, 0.25, 0.75), "bottom_fade_start": 0.90 },
	"valentina": { "color": Color(0.18, 0.45, 0.90), "bottom_fade_start": 0.78 },
}

static var _shared_glow_texture: Texture2D = null
static var _shared_add_material: CanvasItemMaterial = null

static func _get_shared_backlight_texture() -> Texture2D:
	if _shared_glow_texture == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0.85))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = grad
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.45)
		grad_tex.fill_to = Vector2(0.5, 0.0)
		grad_tex.width = 512
		grad_tex.height = 768
		_shared_glow_texture = grad_tex
	return _shared_glow_texture

static func _get_shared_add_material() -> CanvasItemMaterial:
	if _shared_add_material == null:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_add_material = mat
	return _shared_add_material

func _ready() -> void:
	layer = 15 # Situado entre el HUD (5) y Dialogic (20)
	process_mode = Node.PROCESS_MODE_ALWAYS

	if backdrop_rect:
		backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop_rect.modulate.a = 0.0
		backdrop_rect.visible = false

	_connect_dialogic_signals()

func _process(delta: float) -> void:
	if _pet_wiggle_active and is_instance_valid(_active_pet_node):
		_wiggle_time += delta * WIGGLE_SPEED
		var angle: float = sin(_wiggle_time) * WIGGLE_ANGLE_MAX
		if "rotation_degrees" in _active_pet_node:
			_active_pet_node.rotation_degrees = angle

	# Failsafe: Si no hay diálogo activo ni hold_dimmer pero el fondo sigue visible, desvanecer
	if not hold_dimmer and backdrop_rect and backdrop_rect.visible:
		var dialogic: Node = get_node_or_null("/root/Dialogic")
		var is_dlg_running: bool = false
		if dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null:
			is_dlg_running = true
		if not is_dlg_running and not _is_dialogue_active:
			if _fade_tween == null or not _fade_tween.is_running():
				fade_out(0.18)

func _connect_dialogic_signals() -> void:
	var dialogic: Node = get_node_or_null("/root/Dialogic")
	if not dialogic:
		return

	if dialogic.has_signal("timeline_started"):
		dialogic.timeline_started.connect(_on_timeline_started)
	if dialogic.has_signal("timeline_ended"):
		dialogic.timeline_ended.connect(_on_timeline_ended)

	if dialogic.has_method("get_subsystem"):
		var text_subsystem: Variant = dialogic.call("get_subsystem", "Text")
		if text_subsystem and text_subsystem.has_signal("speaker_updated"):
			text_subsystem.speaker_updated.connect(_on_speaker_updated)

		var portraits_sub: Variant = dialogic.call("get_subsystem", "Portraits")
		if portraits_sub:
			if portraits_sub.has_signal("character_joined"):
				portraits_sub.character_joined.connect(_on_character_portrait_event)
			if portraits_sub.has_signal("character_portrait_changed"):
				portraits_sub.character_portrait_changed.connect(_on_character_portrait_event)

func _on_character_portrait_event(_info: Dictionary) -> void:
	if _is_dialogue_active:
		call_deferred("_refresh_portraits_visual_polish")

func set_hud_reference(hud_node: CanvasLayer) -> void:
	_hud_layer = hud_node

func _acquire_hud() -> void:
	if not is_instance_valid(_hud_layer):
		_hud_layer = get_tree().get_first_node_in_group("hud") as CanvasLayer
		if not _hud_layer:
			var main_g: Node = get_tree().current_scene
			if main_g and "hud" in main_g and is_instance_valid(main_g.hud):
				_hud_layer = main_g.hud as CanvasLayer

func _elevate_dialogic_layout() -> void:
	var dialogic: Node = get_node_or_null("/root/Dialogic")
	if dialogic and dialogic.has_method("has_subsystem") and dialogic.call("has_subsystem", "Styles"):
		var styles_sub: Variant = dialogic.call("get_subsystem", "Styles")
		if styles_sub and styles_sub.has_method("get_layout_node"):
			var layout: Node = styles_sub.call("get_layout_node")
			if layout and is_instance_valid(layout):
				if "canvas_layer" in layout:
					layout.canvas_layer = 50
				if "layer" in layout:
					layout.layer = 50

func _on_timeline_started() -> void:
	_is_dialogue_active = true
	_acquire_hud()
	_elevate_dialogic_layout()
	fade_in()
	call_deferred("_on_speaker_updated", null)

func _on_timeline_ended() -> void:
	_is_dialogue_active = false
	_stop_pet_wiggle()
	_fade_out_all_glows()
	if not hold_dimmer:
		fade_out()

func fade_in(duration: float = 0.22) -> void:
	if not backdrop_rect:
		return
	_acquire_hud()
	if is_instance_valid(_hud_layer):
		if _hud_layer.has_method("set_hud_visible"):
			_hud_layer.call("set_hud_visible", false)
		else:
			_hud_layer.visible = false

	backdrop_rect.visible = true
	if backdrop_rect.modulate.a >= 0.99:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if duration <= 0.01:
		backdrop_rect.modulate.a = 1.0
		return

	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(backdrop_rect, "modulate:a", 1.0, duration)

func fade_out(duration: float = 0.22) -> void:
	if not backdrop_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if duration <= 0.01:
		backdrop_rect.modulate.a = 0.0
		backdrop_rect.visible = false
		if is_instance_valid(_hud_layer):
			if _hud_layer.has_method("set_hud_visible"):
				_hud_layer.call("set_hud_visible", true)
			else:
				_hud_layer.visible = true
		return

	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(backdrop_rect, "modulate:a", 0.0, duration)
	_fade_tween.chain().tween_callback(func() -> void:
		if backdrop_rect:
			backdrop_rect.visible = false
		if is_instance_valid(_hud_layer):
			if _hud_layer.has_method("set_hud_visible"):
				_hud_layer.call("set_hud_visible", true)
			else:
				_hud_layer.visible = true
	)

func _on_speaker_updated(character: Variant) -> void:
	if not _is_dialogue_active:
		return

	var active_speaker_id: String = ""
	if character and character.has_method("get_identifier"):
		active_speaker_id = String(character.get_identifier()).to_lower()
	elif character and "display_name" in character:
		active_speaker_id = String(character.display_name).to_lower()

	var dialogic: Node = get_node_or_null("/root/Dialogic")
	if not dialogic or not dialogic.has_method("get_subsystem"):
		return

	var portraits_sub: Variant = dialogic.call("get_subsystem", "Portraits")
	if not portraits_sub or not "character_nodes" in portraits_sub:
		return

	var char_nodes: Dictionary = portraits_sub.character_nodes
	var is_pet_speaking: bool = false

	for char_key in char_nodes.keys():
		var raw_node: Variant = char_nodes[char_key]
		if not is_instance_valid(raw_node):
			continue
		var node: Node = raw_node as Node
		if not node:
			continue

		var c_id: String = String(char_key).to_lower()
		var is_current_speaker: bool = (c_id == active_speaker_id) or (active_speaker_id.is_empty() and false)

		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if is_current_speaker:
			# Orador Activo: Escala 1.05x, Brillo pleno, prioridad visual
			t.tween_property(node, "scale", Vector2(1.05, 1.05), 0.18)
			t.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
			if "z_index" in node:
				node.z_index = 10

			if PET_IDS.has(c_id):
				_start_pet_wiggle(node)
				is_pet_speaking = true
		else:
			# Oyente Pasivo: Escala 0.95x, Atenuado 60%
			t.tween_property(node, "scale", Vector2(0.95, 0.95), 0.20)
			t.tween_property(node, "modulate", Color(0.55, 0.55, 0.65, 0.60), 0.20)
			if "z_index" in node:
				node.z_index = 0

		if PILOT_CONFIGS.has(c_id):
			_apply_pilot_visual_polish(c_id, node, is_current_speaker)

	if not is_pet_speaking:
		_stop_pet_wiggle()

func _start_pet_wiggle(node: Node) -> void:
	_active_pet_node = node
	_pet_wiggle_active = true
	_wiggle_time = 0.0

func _stop_pet_wiggle() -> void:
	_pet_wiggle_active = false
	if is_instance_valid(_active_pet_node) and "rotation_degrees" in _active_pet_node:
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_active_pet_node, "rotation_degrees", 0.0, 0.12)
	_active_pet_node = null

func _refresh_portraits_visual_polish() -> void:
	if not _is_dialogue_active:
		return
	var dialogic: Node = get_node_or_null("/root/Dialogic")
	var active_speaker: Variant = null
	if dialogic and dialogic.has_method("get_subsystem"):
		var text_sub: Variant = dialogic.call("get_subsystem", "Text")
		if text_sub and "speaker_identifier" in text_sub:
			active_speaker = text_sub.speaker_identifier
	_on_speaker_updated(active_speaker)

func _find_portrait_sprite(character_node: Node) -> Sprite2D:
	if not is_instance_valid(character_node):
		return null
	var s: Sprite2D = character_node.find_child("Portrait", true, false) as Sprite2D
	if is_instance_valid(s) and s.texture != null:
		return s
	for child in character_node.get_children():
		if child is Sprite2D and child.texture != null:
			return child as Sprite2D
		for grand_child in child.get_children():
			if grand_child is Sprite2D and grand_child.texture != null:
				return grand_child as Sprite2D
	return null

func _apply_pilot_visual_polish(char_id: String, character_node: Node, is_current_speaker: bool) -> void:
	var config: Dictionary = PILOT_CONFIGS.get(char_id, {})
	if config.is_empty():
		return

	var sprite: Sprite2D = _find_portrait_sprite(character_node)
	if not is_instance_valid(sprite) or sprite.texture == null:
		return

	var pilot_color: Color = config.get("color", Color(0.2, 0.9, 1.0))
	var fade_start: float = config.get("bottom_fade_start", 0.90)

	# 1. Backlight Glow (Contraluz subyacente detrás del retrato)
	var parent_node: Node = sprite.get_parent()
	if not is_instance_valid(parent_node):
		return

	var glow: Sprite2D = parent_node.get_node_or_null("BacklightGlow") as Sprite2D
	if not is_instance_valid(glow):
		glow = Sprite2D.new()
		glow.name = "BacklightGlow"
		glow.texture = _get_shared_backlight_texture()
		glow.material = _get_shared_add_material()
		glow.centered = true
		glow.z_index = -1
		glow.modulate = Color(pilot_color.r, pilot_color.g, pilot_color.b, 0.0)
		parent_node.add_child(glow)
		if parent_node.has_method("move_child"):
			parent_node.move_child(glow, 0)

	var tex_size: Vector2 = sprite.texture.get_size()
	var center_offset: Vector2 = tex_size * 0.5 if not sprite.centered else Vector2.ZERO
	glow.position = sprite.position + center_offset
	glow.scale = Vector2((tex_size.x / 512.0) * 1.15, (tex_size.y / 768.0) * 1.15)
	glow.modulate.r = pilot_color.r
	glow.modulate.g = pilot_color.g
	glow.modulate.b = pilot_color.b

	var target_glow_alpha: float = 0.50 if is_current_speaker else 0.18
	var glow_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(glow, "modulate:a", target_glow_alpha, 0.18)

	# 2. Material Shader (pilot_showcase_hologram.gdshader)
	var target_rim_intensity: float = 1.30 if is_current_speaker else 0.70
	if sprite.material == null:
		var mat := ShaderMaterial.new()
		mat.shader = SHOWCASE_SHADER
		mat.set_shader_parameter("rim_color", pilot_color)
		mat.set_shader_parameter("rim_thickness", 2.2)
		mat.set_shader_parameter("rim_intensity", target_rim_intensity)
		mat.set_shader_parameter("alpha_cutoff", 0.04)
		mat.set_shader_parameter("bottom_fade_start", fade_start)
		mat.set_shader_parameter("bottom_fade_power", 1.8)
		sprite.material = mat
	elif sprite.material is ShaderMaterial:
		var curr_mat := sprite.material as ShaderMaterial
		if curr_mat.shader == SHOWCASE_SHADER:
			curr_mat.set_shader_parameter("rim_color", pilot_color)
			curr_mat.set_shader_parameter("rim_intensity", target_rim_intensity)
			curr_mat.set_shader_parameter("bottom_fade_start", fade_start)

func _fade_out_all_glows() -> void:
	var dialogic: Node = get_node_or_null("/root/Dialogic")
	if not dialogic or not dialogic.has_method("get_subsystem"):
		return
	var portraits_sub: Variant = dialogic.call("get_subsystem", "Portraits")
	if not portraits_sub or not "character_nodes" in portraits_sub:
		return
	var char_nodes: Dictionary = portraits_sub.character_nodes
	for char_key in char_nodes.keys():
		var raw_node: Variant = char_nodes[char_key]
		if not is_instance_valid(raw_node):
			continue
		var node: Node = raw_node as Node
		if not node:
			continue
		var sprite: Sprite2D = _find_portrait_sprite(node)
		if is_instance_valid(sprite) and is_instance_valid(sprite.get_parent()):
			var glow: Sprite2D = sprite.get_parent().get_node_or_null("BacklightGlow") as Sprite2D
			if is_instance_valid(glow):
				var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(glow, "modulate:a", 0.0, 0.18)
