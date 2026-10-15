class_name ForkChoiceCard
extends PanelContainer

## ForkChoiceCard.gd
## Componente visual que representa una tarjeta de bifurcación táctica en una esquina del HUD.
## Admite escalado elástico, modulación de opacidad según vector de timón y animaciones de confirmación.

@onready var title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/TextContainer/TitleLabel") as Label
@onready var rarity_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/TextContainer/RarityLabel") as Label
@onready var icon_rect: TextureRect = get_node_or_null("MarginContainer/VBoxContainer/Header/IconRect") as TextureRect
@onready var desc_label: Label = get_node_or_null("MarginContainer/VBoxContainer/DescLabel") as Label
@onready var progress_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/ProgressBar") as ProgressBar

var option_data: RunForkOptionData = null
var current_ratio: float = 0.0
var _active_tween: Tween = null

const RARITY_COLORS: Dictionary = {
	RunForkOptionData.Rarity.COMMON: Color(0.75, 0.85, 0.95, 1.0),
	RunForkOptionData.Rarity.RARE: Color(0.25, 0.70, 1.0, 1.0),
	RunForkOptionData.Rarity.EPIC: Color(0.80, 0.35, 1.0, 1.0),
	RunForkOptionData.Rarity.LEGENDARY: Color(1.0, 0.80, 0.20, 1.0),
}

const RARITY_NAMES: Dictionary = {
	RunForkOptionData.Rarity.COMMON: "COMÚN",
	RunForkOptionData.Rarity.RARE: "RARA",
	RunForkOptionData.Rarity.EPIC: "ÉPICA",
	RunForkOptionData.Rarity.LEGENDARY: "LEGENDARIA",
}


func _ready() -> void:
	custom_minimum_size = Vector2(260.0, 120.0)
	pivot_offset = custom_minimum_size * 0.5


func setup_data(data: RunForkOptionData) -> void:
	option_data = data
	_ensure_node_references()

	if not is_instance_valid(data):
		return

	if title_label:
		title_label.text = data.title

	if desc_label:
		desc_label.text = data.description

	var r_color: Color = RARITY_COLORS.get(data.rarity, Color.WHITE)
	if rarity_label:
		rarity_label.text = RARITY_NAMES.get(data.rarity, "COMÚN")
		rarity_label.add_theme_color_override("font_color", r_color)

	if icon_rect:
		if data.icon != null:
			icon_rect.texture = data.icon
			icon_rect.modulate = Color.WHITE
		else:
			icon_rect.modulate = r_color

	if progress_bar:
		progress_bar.value = 0.0

	# Estilo visual de borde según rareza
	_apply_rarity_style(r_color)


func set_focus_ratio(ratio: float) -> void:
	current_ratio = clampf(ratio, -1.0, 1.0)
	_ensure_node_references()

	var target_scale: Vector2
	var target_alpha: float = 1.0

	if current_ratio >= 0.0:
		# Enfoque progresivo hacia 1.25x
		var t: float = current_ratio
		var s: float = lerpf(1.0, 1.25, t)
		target_scale = Vector2(s, s)
		target_alpha = 1.0
		if progress_bar:
			progress_bar.value = t * 100.0
	else:
		# Desvanecimiento progresivo hacia 0.7x y opacidad 0.4
		var t: float = -current_ratio
		var s: float = lerpf(1.0, 0.70, t)
		target_scale = Vector2(s, s)
		target_alpha = lerpf(1.0, 0.40, t)
		if progress_bar:
			progress_bar.value = 0.0

	scale = target_scale
	modulate.a = target_alpha


func play_confirm_animation() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	if not _active_tween:
		scale = Vector2(1.30, 1.30)
		return

	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.15)
	_active_tween.chain().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)


func play_dismiss_animation() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	if not _active_tween:
		modulate.a = 0.0
		return

	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "scale", Vector2(0.60, 0.60), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.30)


func _ensure_node_references() -> void:
	if not title_label:
		title_label = get_node_or_null("MarginContainer/VBoxContainer/Header/TextContainer/TitleLabel") as Label
	if not rarity_label:
		rarity_label = get_node_or_null("MarginContainer/VBoxContainer/Header/TextContainer/RarityLabel") as Label
	if not icon_rect:
		icon_rect = get_node_or_null("MarginContainer/VBoxContainer/Header/IconRect") as TextureRect
	if not desc_label:
		desc_label = get_node_or_null("MarginContainer/VBoxContainer/DescLabel") as Label
	if not progress_bar:
		progress_bar = get_node_or_null("MarginContainer/VBoxContainer/ProgressBar") as ProgressBar
	if pivot_offset == Vector2.ZERO and size != Vector2.ZERO:
		pivot_offset = size * 0.5


func _apply_rarity_style(border_color: Color) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.06, 0.08, 0.14, 0.88)
	style_box.border_color = border_color
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style_box)
