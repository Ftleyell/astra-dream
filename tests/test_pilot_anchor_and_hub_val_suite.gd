extends Node

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Testing Valentina Hub Fullbody & Character Select Bottom Anchor...")
	print("==========================================")

	# 1. Verificar carga de fullbody de Valentina
	var cd: CharacterData = CharacterData.load_roster().get(&"valentina")
	assert(cd != null, "CharacterData de Valentina no encontrado")
	var fb: Texture2D = cd.get_fullbody_texture(false)
	assert(fb != null, "Fullbody de Valentina debe cargarse sin ser nulo")
	assert(fb.get_width() == 1200 and fb.get_height() == 1600, "Dimensiones de Valentina fullbody deben ser 1200x1600")
	print("  ✓ Fullbody de Valentina restaurado y verificado (1200x1600)")

	# 2. Instanciar CharacterSelectUI y verificar jerarquía y anclaje
	var cs_scene: PackedScene = load("res://scenes/ui/character_select/character_select.tscn")
	assert(cs_scene != null, "character_select.tscn debe cargar")
	var cs_ui: CharacterSelectUI = cs_scene.instantiate()
	add_child(cs_ui)

	var right_panel = cs_ui.get_node_or_null("MarginContainer/RootVBox/MainColumns/RightPanel")
	assert(right_panel is AspectRatioContainer, "RightPanel debe ser AspectRatioContainer")
	var arc: AspectRatioContainer = right_panel as AspectRatioContainer
	assert(is_equal_approx(arc.ratio, 0.75), "AspectRatioContainer debe tener ratio 0.75")
	assert(arc.alignment_vertical == AspectRatioContainer.ALIGNMENT_END, "AspectRatioContainer debe estar alineado al final verticalmente (ALIGNMENT_END)")

	var fullbody_tex: Texture2D = cs_ui.fullbody_texture.texture
	assert(fullbody_tex != null, "FullbodyTexture debe tener textura asignada")
	print("  ✓ RightPanel AspectRatioContainer alineado al fondo (ratio 0.75, ALIGNMENT_END)")

	# 3. Probar selección de Valentina en la UI
	cs_ui._select_character(&"valentina")
	assert(cs_ui.current_character_id == &"valentina", "Valentina debe estar seleccionada")
	assert(cs_ui.fullbody_texture.texture != null, "Textura de selección de Valentina debe estar presente")

	# 4. Probar hover tween y pivot_offset
	cs_ui._on_pilot_mouse_entered()
	assert(cs_ui.fullbody_texture.pivot_offset.y == cs_ui.fullbody_texture.size.y, "pivot_offset.y debe anclarse a la base inferior")
	print("  ✓ Hover y Click configurados con pivote de escala anclado en la base inferior")

	cs_ui.queue_free()
	print("\n==========================================")
	print("[PASS] VALENTINA HUB FULLBODY & SELECTION ANCHOR VERIFIED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
