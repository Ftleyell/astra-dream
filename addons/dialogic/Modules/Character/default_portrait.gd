@tool
extends DialogicPortrait

## Default portrait scene.
## The parent class has a character and portrait variable.

@export_group('Main')
@export_file var image := ""


## Load anything related to the given character and portrait
func _update_portrait(passed_character:DialogicCharacter, passed_portrait:String) -> void:
	apply_character_and_portrait(passed_character, passed_portrait)

	apply_texture($Portrait, image)

	if not Engine.is_editor_hint():
		var cm = load("res://core/systems/cosmetics_manager.gd")
		if cm and cm.has_method("apply_skin_to_dialogue_portrait"):
			cm.apply_skin_to_dialogue_portrait($Portrait, passed_character.get_identifier(), passed_portrait)


func _set_mirror(mirror: bool) -> void:
	super._set_mirror(mirror)
	if not Engine.is_editor_hint() and character:
		var cm = load("res://core/systems/cosmetics_manager.gd")
		if cm and cm.has_method("apply_skin_to_dialogue_portrait"):
			cm.apply_skin_to_dialogue_portrait($Portrait, character.get_identifier(), portrait if not mirror else "Flipped")
