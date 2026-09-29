class_name AimModeIndicator
extends Node2D

## AimModeIndicator.gd
## Sigilo / glifo holográfico de auto-apuntado y radar integrado en el interior del anillo de vida.
## Centrado debajo de la nave, ajustado al diámetro interior del halo de salud.

@export var weapon_controller: WeaponController

const BASE_GLYPH_SCALE: float = 0.38

var glyph_sprite: Sprite2D = null
var pulse_tween: Tween
var is_manual_mode: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	z_index = -1
	if get_parent() is Player:
		position = Vector2.ZERO
	else:
		position = Vector2.ZERO

	_hide_legacy_panel()
	_setup_glyph()

	if not weapon_controller and get_parent():
		weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController

	if weapon_controller:
		if weapon_controller.has_signal("aim_mode_changed"):
			weapon_controller.aim_mode_changed.connect(_on_aim_mode_changed)
		_update_indicator(weapon_controller.is_manual_aim)
	else:
		_update_indicator(false)

func _hide_legacy_panel() -> void:
	var legacy_panel := get_node_or_null("PanelContainer")
	if legacy_panel:
		legacy_panel.visible = false

func _setup_glyph() -> void:
	if not glyph_sprite:
		glyph_sprite = Sprite2D.new()
		glyph_sprite.name = "GlyphSprite"
		var tex_path := "res://assets/sprites/ui/aim_mode_glyph.png"
		var tex: Texture2D = null
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		if not tex:
			var global_path := ProjectSettings.globalize_path(tex_path)
			if FileAccess.file_exists(global_path):
				var img := Image.new()
				if img.load(global_path) == OK:
					tex = ImageTexture.create_from_image(img)
		glyph_sprite.texture = tex
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glyph_sprite.material = mat
		glyph_sprite.scale = Vector2(BASE_GLYPH_SCALE, BASE_GLYPH_SCALE)
		add_child(glyph_sprite)

func _process(delta: float) -> void:
	if not glyph_sprite:
		return
	elapsed += delta
	if not is_manual_mode:
		# Modo Auto: rotación lenta cibernética y suave pulso de respiración
		glyph_sprite.rotation += delta * 0.4
		var p := BASE_GLYPH_SCALE * (1.0 + sin(elapsed * 3.5) * 0.035)
		glyph_sprite.scale = Vector2(p, p)
	else:
		# Modo Manual: estático y tenue
		glyph_sprite.rotation = 0.0
		glyph_sprite.scale = Vector2(BASE_GLYPH_SCALE * 0.92, BASE_GLYPH_SCALE * 0.92)

func _on_aim_mode_changed(is_manual: bool) -> void:
	_update_indicator(is_manual)
	_animate_toggle()

func _update_indicator(is_manual: bool) -> void:
	is_manual_mode = is_manual
	if not glyph_sprite:
		return

	if is_manual:
		# Modo Manual: ámbar tenue y sutil
		glyph_sprite.modulate = Color(0.85, 0.45, 0.15, 0.38)
	else:
		# Modo Auto: cian neón eléctrico brillante
		glyph_sprite.modulate = Color(0.2, 0.95, 1.0, 0.78)

func _animate_toggle() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	if glyph_sprite:
		glyph_sprite.scale = Vector2(BASE_GLYPH_SCALE * 1.3, BASE_GLYPH_SCALE * 1.3)
		pulse_tween = create_tween()
		var target_s: float = BASE_GLYPH_SCALE * (0.92 if is_manual_mode else 1.0)
		pulse_tween.tween_property(glyph_sprite, "scale", Vector2(target_s, target_s), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
