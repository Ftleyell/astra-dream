class_name PetBubbleUIPreview
extends Control

## Widget Control liviano para renderizar una pet en burbuja 3D viva dentro de
## modales de UI (PetSelectionModal, GachaWardrobeController, GachaRevealTheater).

const RigScene: PackedScene = preload("res://scenes/pets/rig/pet_bubble_rig_25d.tscn")

var _rig: PetBubbleRig25D = null
var _fill_ratio: float = 0.88
var _paused: bool = false
var _last_pet_id: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_rig()
	resized.connect(_update_rig_layout)
	_update_rig_layout()


func _ensure_rig() -> void:
	if _rig == null:
		_rig = RigScene.instantiate() as PetBubbleRig25D
		add_child(_rig)
		_rig.set_sun_direction(Vector3(-0.48, 0.68, 0.58))
		_rig.set_orbit_depth(1.0)
		_rig.set_process(not _paused)


func _update_rig_layout() -> void:
	if _rig == null:
		return
	var target_size: Vector2 = size if size.x > 4.0 and size.y > 4.0 else custom_minimum_size
	if target_size.x <= 4.0 or target_size.y <= 4.0:
		target_size = Vector2(140.0, 140.0)
	_rig.position = target_size * 0.5
	var diam: float = clampf(minf(target_size.x, target_size.y) * _fill_ratio, 36.0, 340.0)
	_rig.set_bubble_diameter_px(diam)


func configure(
	pet_id: StringName,
	skin_id: String = "",
	stars: int = 1,
	is_locked: bool = false,
	fill_ratio: float = 0.88
) -> void:
	_fill_ratio = clampf(fill_ratio, 0.4, 1.15)
	_ensure_rig()
	var cfg: PetBubbleVisualConfig = PetBubbleRegistry.get_config(pet_id)
	if cfg != null and (_last_pet_id != pet_id or _rig.config != cfg):
		_rig.apply_config(cfg)
		_last_pet_id = pet_id
	_rig.apply_skin_by_id(skin_id, stars, is_locked)
	_update_rig_layout()


func trigger_emote(kind: StringName = &"hop") -> void:
	if _rig != null:
		_rig.trigger_emote(kind)


func set_preview_paused(paused: bool) -> void:
	_paused = paused
	if _rig != null:
		_rig.set_process(not paused)
		if _rig.inner_particles != null:
			_rig.inner_particles.emitting = not paused


func get_rig() -> PetBubbleRig25D:
	return _rig


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _rig != null:
			_rig.trigger_emote(&"hop")
