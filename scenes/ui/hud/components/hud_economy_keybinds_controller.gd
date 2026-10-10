class_name HUDEconomyKeybindsController
extends RefCounted

## HUDEconomyKeybindsController.gd
## Componente especializado para el control de economía (créditos, biomasa, llaves)
## y etiquetas de keybinds tácticos del GameHUD.

var credits_label: Label
var biomass_label: Label
var credit_icon: TextureRect
var key_label: Label
var dash_keybind_label: Label
var laser_keybind_label: Label
var bomb_keybind_label: Label

var current_credits: int = 120
var current_biomass: int = 0
var _credit_punch_tween: Tween = null

func setup(elements: Dictionary) -> void:
	credits_label = elements.get("credits_label") as Label
	biomass_label = elements.get("biomass_label") as Label
	credit_icon = elements.get("credit_icon") as TextureRect
	key_label = elements.get("key_label") as Label
	dash_keybind_label = elements.get("dash_keybind_label") as Label
	laser_keybind_label = elements.get("laser_keybind_label") as Label
	bomb_keybind_label = elements.get("bomb_keybind_label") as Label

func update_credits(amount: int, tree_ref: SceneTree = null) -> void:
	var diff: int = amount - current_credits
	current_credits = amount
	_refresh_economy_label()

	if diff > 0 and tree_ref and is_instance_valid(credit_icon) and credit_icon.is_inside_tree():
		if _credit_punch_tween and _credit_punch_tween.is_valid():
			_credit_punch_tween.kill()
		credit_icon.pivot_offset = credit_icon.size / 2.0
		_credit_punch_tween = tree_ref.create_tween()
		_credit_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_credit_punch_tween.tween_property(credit_icon, "scale", Vector2(1.35, 1.35), 0.1)
		_credit_punch_tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_credit_punch_tween.tween_property(credit_icon, "scale", Vector2(1.0, 1.0), 0.16)

func update_biomass(_run_amount: int, total_persistent: int) -> void:
	current_biomass = total_persistent
	_refresh_economy_label()

func _refresh_economy_label() -> void:
	if credits_label:
		credits_label.text = "%d C" % current_credits
	if biomass_label:
		biomass_label.text = "%d" % current_biomass

func update_quantum_keys(keys_count: int, hud_root: CanvasLayer) -> void:
	if not key_label:
		return
	if keys_count > 0:
		key_label.text = "x%d (-20%% Desc.)" % keys_count
		key_label.modulate = Color(0.35, 1.0, 0.65, 1.0)
		var badge := hud_root.find_child("KeyBadge", true, false) as Control if hud_root else null
		if badge and hud_root:
			badge.pivot_offset = badge.size * 0.5
			var tw := hud_root.create_tween()
			tw.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	else:
		key_label.text = "x0"
		key_label.modulate = Color(0.7, 0.88, 1.0, 0.85)

func update_keybind_labels() -> void:
	if dash_keybind_label:
		dash_keybind_label.text = "[%s] DASH" % _get_action_key_text(&"dash")
	if laser_keybind_label:
		laser_keybind_label.text = "[%s]" % _get_action_key_text(&"fire_active")
	if bomb_keybind_label:
		bomb_keybind_label.text = "[%s] BOMBA" % _get_action_key_text(&"bomb")

func _get_action_key_text(act: StringName) -> String:
	var events := InputMap.action_get_events(act)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "CLIC IZQ"
				MOUSE_BUTTON_RIGHT: return "CLIC DER"
				MOUSE_BUTTON_MIDDLE: return "CLIC CEN"
				_: return "RATÓN %d" % ev.button_index
	return "N/A"
