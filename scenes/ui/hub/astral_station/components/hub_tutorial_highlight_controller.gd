class_name HubTutorialHighlightController
extends Node

## Controlador minimalista del glow titilante directo por shader sobre estaciones 3D
## durante el debrief/tutorial guiado por mascota en el Hub 3D.

var _active_bundle: Dictionary = {}
var _active_color: Color = Color(0.28, 0.94, 1.0, 1.0)
var _pulse_hz: float = 2.6
var _intensity: float = 1.25
var _time_acc: float = 0.0
var _is_active: bool = false


func activate_target(bundle: Dictionary, color: Color, pulse_hz: float = 2.6, intensity: float = 1.25) -> void:
	clear_highlight()
	if bundle.is_empty():
		return
	_active_bundle = bundle
	_active_color = color
	_pulse_hz = maxf(pulse_hz, 0.25)
	_intensity = maxf(intensity, 0.0)
	_time_acc = 0.0
	_is_active = true
	_apply_pulse(_intensity * 0.65)


func clear_highlight() -> void:
	_is_active = false
	_apply_pulse(0.0)
	_active_bundle = {}


func is_highlight_active() -> bool:
	return _is_active


func get_current_pulse_value() -> float:
	if not _is_active:
		return 0.0
	return _intensity * (0.28 + 0.72 * (0.5 + 0.5 * sin(_time_acc * TAU * _pulse_hz)))


func _process(delta: float) -> void:
	if not _is_active:
		return
	_time_acc += delta
	_apply_pulse(get_current_pulse_value())


func _apply_pulse(val: float) -> void:
	if _active_bundle.is_empty():
		return
	var prop_mats: Array = _active_bundle.get("prop_mats", [])
	for m_v: Variant in prop_mats:
		var mat: ShaderMaterial = m_v as ShaderMaterial
		if mat != null and is_instance_valid(mat):
			mat.set_shader_parameter("tutorial_highlight_pulse", val)
			mat.set_shader_parameter("tutorial_highlight_color", _active_color)

	var outline_mats: Array = _active_bundle.get("outline_mats", [])
	for o_v: Variant in outline_mats:
		var omat: ShaderMaterial = o_v as ShaderMaterial
		if omat != null and is_instance_valid(omat):
			omat.set_shader_parameter("tutorial_highlight_pulse", val)
			omat.set_shader_parameter("tutorial_highlight_color", _active_color)

	var dais_mats: Array = _active_bundle.get("dais_mats", [])
	for d_v: Variant in dais_mats:
		var dmat: ShaderMaterial = d_v as ShaderMaterial
		if dmat != null and is_instance_valid(dmat):
			dmat.set_shader_parameter("tutorial_highlight_pulse", val)
			dmat.set_shader_parameter("tutorial_highlight_color", _active_color)

	var bridge_mats: Array = _active_bundle.get("bridge_mats", [])
	for b_v: Variant in bridge_mats:
		var bmat: ShaderMaterial = b_v as ShaderMaterial
		if bmat != null and is_instance_valid(bmat):
			bmat.set_shader_parameter("tutorial_highlight_pulse", val)
			bmat.set_shader_parameter("tutorial_highlight_color", _active_color)

	var holo_mats: Array = _active_bundle.get("holo_mats", [])
	for h_v: Variant in holo_mats:
		var hmat: ShaderMaterial = h_v as ShaderMaterial
		if hmat != null and is_instance_valid(hmat):
			hmat.set_shader_parameter("pulse_boost", clampf(val * 0.85, 0.0, 1.8))


func _exit_tree() -> void:
	clear_highlight()
