extends Node

func _ready() -> void:
	print("--- TEST DROPS SUITE START ---")
	var scene := preload("res://scenes/combat/pickups/field_consumable.tscn")
	
	# Test HEAL
	var heal_node := scene.instantiate() as FieldConsumable
	add_child(heal_node)
	heal_node.setup(FieldConsumable.ConsumableType.HEAL, Vector2(100, 100))
	var heal_sprite := heal_node.get_node("VisualRoot/IconSprite") as Sprite2D
	var heal_glow := heal_node.get_node("VisualRoot/GlowPolygon") as Polygon2D
	print("HEAL texture: ", heal_sprite.texture.resource_path)
	print("HEAL scale: ", heal_sprite.scale)
	print("HEAL modulate: ", heal_sprite.modulate)
	print("HEAL glow: ", heal_glow.color)
	assert(heal_sprite.texture.resource_path == "res://assets/sprites/pickups/drop_heal.png", "Heal texture mismatch")
	assert(heal_sprite.scale == Vector2(0.18, 0.18), "Heal scale mismatch")
	assert(heal_sprite.modulate == Color.WHITE, "Heal modulate mismatch")
	
	# Test MAGNET
	var magnet_node := scene.instantiate() as FieldConsumable
	add_child(magnet_node)
	magnet_node.setup(FieldConsumable.ConsumableType.MAGNET, Vector2(200, 200))
	var magnet_sprite := magnet_node.get_node("VisualRoot/IconSprite") as Sprite2D
	var magnet_glow := magnet_node.get_node("VisualRoot/GlowPolygon") as Polygon2D
	print("MAGNET texture: ", magnet_sprite.texture.resource_path)
	print("MAGNET scale: ", magnet_sprite.scale)
	print("MAGNET modulate: ", magnet_sprite.modulate)
	print("MAGNET glow: ", magnet_glow.color)
	assert(magnet_sprite.texture.resource_path == "res://assets/sprites/pickups/drop_magnet.png", "Magnet texture mismatch")
	assert(magnet_sprite.scale == Vector2(0.18, 0.18), "Magnet scale mismatch")
	assert(magnet_sprite.modulate == Color.WHITE, "Magnet modulate mismatch")
	
	# Test BOMB
	var bomb_node := scene.instantiate() as FieldConsumable
	add_child(bomb_node)
	bomb_node.setup(FieldConsumable.ConsumableType.BOMB, Vector2(300, 300))
	var bomb_sprite := bomb_node.get_node("VisualRoot/IconSprite") as Sprite2D
	var bomb_glow := bomb_node.get_node("VisualRoot/GlowPolygon") as Polygon2D
	print("BOMB texture: ", bomb_sprite.texture.resource_path)
	print("BOMB scale: ", bomb_sprite.scale)
	print("BOMB modulate: ", bomb_sprite.modulate)
	print("BOMB glow: ", bomb_glow.color)
	assert(bomb_sprite.texture.resource_path == "res://assets/sprites/pickups/drop_bomb.png", "Bomb texture mismatch")
	assert(bomb_sprite.scale == Vector2(0.18, 0.18), "Bomb scale mismatch")
	assert(bomb_sprite.modulate == Color.WHITE, "Bomb modulate mismatch")
	
	print("--- TEST DROPS SUITE COMPLETED SUCCESSFULLY ---")
	get_tree().quit(0)
