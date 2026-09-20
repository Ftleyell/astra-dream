class_name CombatDialogueBox
extends CanvasLayer

signal dialogue_finished()

@export var audio_duck_manager: AudioDuckManager

@onready var container: PanelContainer = $BannerContainer
@onready var speaker_label: Label = $BannerContainer/Margin/HBox/TextVBox/SpeakerLabel
@onready var text_label: Label = $BannerContainer/Margin/HBox/TextVBox/ContentLabel
@onready var skip_hint: Label = $BannerContainer/Margin/HBox/TextVBox/SkipHint
@onready var portrait_rect: ColorRect = $BannerContainer/Margin/HBox/PortraitRect

var is_active: bool = false
var auto_advance_timer: float = 0.0
var line_duration: float = 4.0

func _ready() -> void:
	hide()
	# mouse_filter IGNORE en toda la jerarquía para no bloquear el apuntado ni disparos
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_active:
		return

	auto_advance_timer -= delta
	if auto_advance_timer <= 0.0:
		close_dialogue()

	if Input.is_action_just_pressed("dialogue_skip"):
		close_dialogue()

func trigger_dialogue(speaker: String, text: String, color: Color = Color(1.0, 0.4, 0.4)) -> void:
	is_active = true
	speaker_label.text = speaker
	speaker_label.modulate = color
	text_label.text = text
	portrait_rect.color = color
	auto_advance_timer = line_duration

	if audio_duck_manager:
		audio_duck_manager.duck_music(true)

	show()

func close_dialogue() -> void:
	if not is_active:
		return
	is_active = false
	hide()

	if audio_duck_manager:
		audio_duck_manager.duck_music(false)

	dialogue_finished.emit()
