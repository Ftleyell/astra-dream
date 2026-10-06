extends BaseTestSuite

## TestCharacterSelectReworkSuite
## Suite de pruebas exhaustiva para la nueva interfaz de Selección de Personajes:
## 1. Existencia y resolución 256x256 de los 7 avatares recortados.
## 2. CharacterData.get_avatar_texture().
## 3. Instanciación de CharacterSelectUI con 4 Tech-Tabs y alternancia de vistas.
## 4. Dock inferior con 7 tarjetas de heroínas y avatares.
## 5. Persistencia de loadouts independientes por piloto en SaveManager.
## 6. Shader holográfico con rim-light aplicado en el escaparate de la heroína.
## 7. F1 Debug deshabilitado de forma visual y condicionado a debug builds.
## 8. Apertura del Árbol de Talentos para la piloto seleccionada.

const PilotAvatars := ["nova", "valentina", "roxy", "selene", "nyx", "echo", "kira"]


func _ready() -> void:
	print("\n=======================================================")
	print("[TEST] Testing Character Select UI Cyberpunk Rework...")
	print("=======================================================\n")

	_test_avatar_assets_exist_and_dimensions()
	_test_character_data_avatar_integration()
	_test_per_pilot_loadout_persistence()
	_test_ui_instantiation_and_tabs()
	_test_heroine_shader_and_visuals()
	await _test_talent_tree_modal_integration()

	pass_suite("Todas las pruebas del rework de Selección de Personaje pasaron con éxito.")


func _test_avatar_assets_exist_and_dimensions() -> void:
	print("[1/6] Verifying 256x256 cropped face avatars on disk...")
	for pilot in PilotAvatars:
		var path := "res://assets/portraits/avatars/avatar_%s.png" % pilot
		assert_true(ResourceLoader.exists(path), "El avatar de %s debe existir en %s" % [pilot, path])
		var tex := load(path) as Texture2D
		assert_true(tex != null, "La textura del avatar de %s debe cargar" % pilot)
		assert_true(tex.get_width() == 256 and tex.get_height() == 256, "El avatar debe ser exactamente 256x256 (medido: %dx%d)" % [tex.get_width(), tex.get_height()])
	print("  ✓ 7 Avatares 256x256 verificados correctamente.")


func _test_character_data_avatar_integration() -> void:
	print("[2/6] Verifying CharacterData.get_avatar_texture()...")
	var roster := CharacterData.load_roster()
	for pilot in PilotAvatars:
		var c_data: CharacterData = roster.get(StringName(pilot), null)
		assert_true(c_data != null, "CharacterData para %s debe existir" % pilot)
		var av_tex := c_data.get_avatar_texture()
		assert_true(av_tex != null, "get_avatar_texture() debe retornar textura válida para %s" % pilot)
	print("  ✓ Integración de get_avatar_texture() en CharacterData verificada.")


func _test_per_pilot_loadout_persistence() -> void:
	print("[3/6] Verifying per-pilot loadout persistence in SaveManager...")
	var test_loadout_nova := {
		"selected_pet": "kuro",
		"selected_navigator": "vespera",
		"equipped_pet_skin": "kuro_void",
		"equipped_navigator_skin": "vespera_alt",
		"equipped_ship_skin": "exo_nova_neon",
		"equipped_weapon_skin": "weapon_nova_gold"
	}
	var test_loadout_valentina := {
		"selected_pet": "luna",
		"selected_navigator": "caelia",
		"equipped_pet_skin": "luna_frost",
		"equipped_navigator_skin": "caelia_solar",
		"equipped_ship_skin": "exo_val_crimson",
		"equipped_weapon_skin": "weapon_val_void"
	}

	SaveManager.set_character_loadout(&"nova", test_loadout_nova)
	SaveManager.set_character_loadout(&"valentina", test_loadout_valentina)

	var loaded_nova := SaveManager.get_character_loadout(&"nova")
	var loaded_val := SaveManager.get_character_loadout(&"valentina")

	assert_true(String(loaded_nova.get("selected_pet")) == "kuro", "Nova debe retener su mascota kuro")
	assert_true(String(loaded_nova.get("selected_navigator")) == "vespera", "Nova debe retener su navegadora vespera")
	assert_true(String(loaded_val.get("selected_pet")) == "luna", "Valentina debe retener su mascota luna")
	assert_true(String(loaded_val.get("selected_navigator")) == "caelia", "Valentina debe retener su navegadora caelia")
	print("  ✓ Persistencia independiente de loadouts por heroína verificada.")


func _test_ui_instantiation_and_tabs() -> void:
	print("[4/6] Verifying CharacterSelectUI Unified 2-Column Dashboard & Bottom Dock...")
	var scene_res := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	assert_true(scene_res != null, "character_select.tscn debe cargar")

	SaveManager.unlock_character(&"nyx")
	var ui: CharacterSelectUI = scene_res.instantiate()
	add_child(ui)

	# Confirmar heroína para salir del HeroPickerModal inicial y desplegar el dashboard
	if ui.hero_picker_modal and ui.hero_picker_modal.is_open:
		ui._on_hero_confirmed(&"nyx")

	# Verificar las 2 columnas del dashboard unificado visibles simultáneamente
	assert_true(ui.loadout_view != null, "loadout_view debe existir")
	assert_true(ui.abilities_view != null, "abilities_view debe existir")
	assert_true(ui.loadout_view.visible, "Columna 1 (Loadout) debe estar visible en el dashboard")
	assert_true(ui.abilities_view.visible, "Columna 2 (Habilidades) debe estar visible en el dashboard")

	# Verificar bloques técnicos de habilidades e iconos
	assert_true(ui.weapon_block_title != null, "weapon_block_title debe existir")
	assert_true(ui.tactical_block_title != null, "tactical_block_title debe existir")
	assert_true(ui.dash_block_title != null, "dash_block_title debe existir")
	assert_true(ui.passive_block_title != null, "passive_block_title debe existir")
	assert_true(ui.weapon_block_icon != null, "weapon_block_icon debe existir")
	assert_true(ui.tactical_block_icon != null, "tactical_block_icon debe existir")
	assert_true(ui.dash_block_icon != null, "dash_block_icon debe existir")
	assert_true(ui.passive_block_icon != null, "passive_block_icon debe existir")

	# Verificar hotkeys dinámicas en etiquetas de habilidades
	assert_true(ui.tactical_block_tag.text.contains("CLIC DER"), "tactical_block_tag debe contener [CLIC DER] de fire_active")
	assert_true(ui.dash_block_tag.text.contains("SHIFT"), "dash_block_tag debe contener [SHIFT] de dash")
	assert_true(ui.weapon_block_tag.text.contains("AUTO / PASIVO"), "weapon_block_tag debe indicar [AUTO / PASIVO]")
	assert_true(ui.passive_block_tag.text.contains("INNATA"), "passive_block_tag debe indicar [INNATA]")

	# Verificar tarjetas individuales de Loadout (Compañeros y Utilidad)
	assert_true(ui.pet_card != null, "pet_card debe existir como panel individual")
	assert_true(ui.navigator_card != null, "navigator_card debe existir como panel individual")
	assert_true(ui.expand_talents_btn != null, "expand_talents_btn debe existir en TalentsCard")
	assert_true(ui.tomes_pool_btn != null, "tomes_pool_btn debe existir en TomesCard")
	assert_true(ui.loadout_button != null, "loadout_button (Banlist) debe existir en TomesCard")
	assert_true(ui.speed_1x_btn != null, "speed_1x_btn debe existir en SpeedCard")

	# Verificar Formato Gigante de iconos y autowrap multilínea
	assert_true(ui.ship_icon.custom_minimum_size in [Vector2(112, 112), Vector2(120, 120)], "ship_icon debe medir formato gigante (112x112 o 120x120)")
	assert_true(ui.weapon_icon.custom_minimum_size in [Vector2(112, 112), Vector2(120, 120)], "weapon_icon debe medir formato gigante (112x112 o 120x120)")
	assert_true(ui.pet_icon.custom_minimum_size == Vector2(88, 88), "pet_icon debe medir 88x88 en formato gigante")
	assert_true(ui.navigator_icon.custom_minimum_size == Vector2(88, 88), "navigator_icon debe medir 88x88 en formato gigante")
	assert_true(ui.pet_desc.autowrap_mode != TextServer.AUTOWRAP_OFF, "pet_desc debe tener autowrap activo para no recortar texto")
	assert_true(ui.navigator_desc.autowrap_mode != TextServer.AUTOWRAP_OFF, "navigator_desc debe tener autowrap activo para no recortar texto")

	# Dock inferior: 7 tarjetas cuadradas de heroínas perfectamente alineadas
	assert_true(ui.char_list_container.get_child_count() == 7, "El dock debe contener 7 tarjetas de heroínas")
	for child in ui.char_list_container.get_children():
		var btn := child as Button
		assert_true(btn != null, "Cada elemento del dock debe ser un Button")
		assert_true(btn.custom_minimum_size == Vector2(76, 76), "Cada tarjeta del dock debe medir 76x76")

	# Verificar que el click en el botón de la piloto no genera recursión infinita / underflow
	ui._on_pilot_button_pressed()

	ui.queue_free()
	print("  ✓ Dashboard unificado de 2 Columnas, Formato Gigante y Dock alineado verificados.")


func _test_heroine_shader_and_visuals() -> void:
	print("[5/6] Verifying Heroine Showcase shader & defringing rim-light...")
	var scene_res := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	var ui: CharacterSelectUI = scene_res.instantiate()
	add_child(ui)

	ui._select_character(&"valentina")
	assert_true(ui.fullbody_texture.texture != null, "Textura de Valentina debe cargarse")
	assert_true(ui.fullbody_texture.material != null, "Debe aplicarse ShaderMaterial al escaparate")
	assert_true(ui.fullbody_texture.material is ShaderMaterial, "Material debe ser ShaderMaterial")

	var sm := ui.fullbody_texture.material as ShaderMaterial
	assert_true(sm.shader != null, "Shader de rim-light debe estar asignado")

	# Verificar selector de aspecto
	assert_true(ui.pilot_skin_btn != null, "Botón de aspecto de piloto debe estar presente")

	ui.queue_free()
	print("  ✓ Shader holográfico de rim-light y escaparate visual verificados.")


func _test_talent_tree_modal_integration() -> void:
	print("[6/6] Verifying CharacterSkillTreeModal integration...")
	var scene_res := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	var ui: CharacterSelectUI = scene_res.instantiate()
	add_child(ui)

	assert_true(ui.character_skill_tree_modal != null, "CharacterSkillTreeModal debe estar instanciado en la escena")

	# Abrir modal de talentos para la piloto seleccionada
	ui._select_character(&"nova")
	ui._on_expand_talents_pressed()
	assert_true(ui.character_skill_tree_modal.visible, "El modal del árbol de talentos debe abrirse")
	assert_true(ui.character_skill_tree_modal.current_character_id == &"nova", "El árbol debe configurarse para Nova")

	# Cerrar modal
	ui.character_skill_tree_modal.close_modal()
	await get_tree().create_timer(0.25).timeout
	assert_true(not ui.character_skill_tree_modal.visible, "El modal de talentos debe cerrarse")

	ui.queue_free()
	print("  ✓ Integración del Árbol de Talentos verificada exitosamente.")
