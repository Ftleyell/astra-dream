extends Node

func _ready() -> void:
	print("--- TEST EXP CRYSTALS SUITE START ---")
	var scene := preload("res://scenes/combat/pickups/exp_blob.tscn")
	
	var test_cases := [
		{ "exp": 15.0, "expected_tex": "res://assets/sprites/pickups/exp_crystal_tier1.png", "tier": 1, "scale": Vector2(2.0, 2.0) },
		{ "exp": 75.0, "expected_tex": "res://assets/sprites/pickups/exp_crystal_tier2.png", "tier": 2, "scale": Vector2(2.7, 2.7) },
		{ "exp": 250.0, "expected_tex": "res://assets/sprites/pickups/exp_crystal_tier3.png", "tier": 3, "scale": Vector2(3.5, 3.5) },
		{ "exp": 600.0, "expected_tex": "res://assets/sprites/pickups/exp_crystal_tier4.png", "tier": 4, "scale": Vector2(4.5, 4.5) },
	]
	
	for tc in test_cases:
		var blob := scene.instantiate() as ExpBlob
		add_child(blob)
		blob.setup(tc["exp"], Vector2.ZERO)
		
		var sprite: Sprite2D = blob.get_node("CrystalVisual/CrystalSprite")
		assert(sprite != null, "CrystalSprite node not found!")
		assert(sprite.texture != null, "Texture is null for Tier %d!" % tc["tier"])
		print("Tier %d (EXP %.1f): Tex = %s | Scale = %s" % [tc["tier"], tc["exp"], sprite.texture.resource_path, blob.scale])
		assert(sprite.texture.resource_path == tc["expected_tex"], "Texture mismatch for Tier %d" % tc["tier"])
		assert(blob.scale == tc["scale"], "Blob scale mismatch for Tier %d" % tc["tier"])
		blob.queue_free()
		
	print("--- TEST EXP CRYSTALS SUITE PASSED SUCCESSFULLY ---")
	get_tree().quit(0)
