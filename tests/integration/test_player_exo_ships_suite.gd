extends Node

func _ready() -> void:
	print("--- TEST PLAYER EXO SHIPS SUITE START ---")
	var roster := CharacterData.load_roster()
	assert(not roster.is_empty(), "Roster is empty!")
	
	for char_id in roster.keys():
		var char_data: CharacterData = roster[char_id]
		var tex: Texture2D = char_data.get_ship_texture()
		assert(tex != null, "Ship texture is null for %s!" % str(char_id))
		print("Pilot: %s | Tex: %s | Size: %s" % [char_data.display_name, tex.resource_path, tex.get_size()])
		assert(tex.get_size() == Vector2(256, 256), "Texture size mismatch for %s!" % str(char_id))
		
	print("--- TEST PLAYER EXO SHIPS SUITE PASSED SUCCESSFULLY ---")
	get_tree().quit(0)
