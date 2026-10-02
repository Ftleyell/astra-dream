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
var hold_dimmer: bool = false

const PET_IDS: Array[String] = ["mochi", "kuro", "luna", "pip", "cosmo"]
const WIGGLE_ANGLE_MAX: float = 4.0
const WIGGLE_SPEED: float = 12.0

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
	_fade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(backdrop_rect, "modulate:a", 1.0, duration)

func fade_out(duration: float = 0.22) -> void:
	if not backdrop_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
		var node: Node = char_nodes[char_key] as Node
		if not is_instance_valid(node):
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
