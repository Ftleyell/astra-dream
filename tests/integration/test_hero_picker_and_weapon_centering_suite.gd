class_name TestHeroPickerAndWeaponCenteringSuite
extends BaseTestSuite

## TestHeroPickerAndWeaponCenteringSuite
## Suite automatizada para validar:
## 1. Centrado óptico compensado de armas (-38px, escala 1.15x) en CosmeticCarouselModal.
## 2. Flujo de HeroPickerModal (apertura con blur, preview central, ciclo de heroínas).
## 3. Confirmación con salto de foco al Exotraje (ship_button).
## 4. Preservación del estilo de fondo en hover/pressed en las tarjetas del dock.

const CosmeticCarouselModalScene = preload("res://scenes/ui/cosmetics/cosmetic_carousel_modal.tscn")
const HeroPickerModalScene = preload("res://scenes/ui/character_select/hero_picker_modal.tscn")
const CharacterSelectScene = preload("res://scenes/ui/character_select/character_select.tscn")


func _ready() -> void:
	super._ready()
	_run_all_tests()


func _run_all_tests() -> void:
	print("--- INICIANDO TEST SUITE: HERO PICKER & WEAPON CENTERING ---")
	_test_weapon_optical_centering()
	await _test_hero_picker_modal_initial_flow()
	await _test_dock_hover_and_focus_flow()

	await get_tree().process_frame
	await get_tree().process_frame
	print("--- TODAS LAS PRUEBAS DE HERO PICKER Y CENTRADO DE ARMAS SUPERADAS ---")
	pass_suite("Pruebas de centrado de armas, hero picker, escape al hub y salto de foco superadas.")


func _test_weapon_optical_centering() -> void:
	var modal: CanvasLayer = CosmeticCarouselModalScene.instantiate() as CanvasLayer
	add_child(modal)

	var char_data := CharacterData.new()
	char_data.character_id = &"nova"
	char_data.display_name = "Nova"

	# 1. Categoría Arma -> debe aplicar offset óptico -38px y escala 1.15x
	modal.open_modal("weapon", &"nova", char_data)
	var art_tex: TextureRect = modal.get_node_or_null("DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport/ArtworkTexture") as TextureRect
	assert_true(art_tex != null, "ArtworkTexture debe existir en CosmeticCarouselModal.")
	assert_true(is_equal_approx(art_tex.position.x, -38.0), "Armas deben tener offset.x = -38.0 para centrado óptico.")
	assert_true(is_equal_approx(art_tex.scale.x, 1.15), "Armas deben tener escala 1.15x para presencia visual.")

	# 2. Categoría Piloto -> debe restablecerse a posición y escala neutrales
	modal.open_modal("pilot", &"nova", char_data)
	assert_true(is_equal_approx(art_tex.position.x, 0.0), "Pilotos deben tener posición neutral X = 0.0.")
	assert_true(is_equal_approx(art_tex.scale.x, 1.0), "Pilotos deben tener escala neutral 1.0.")

	modal.queue_free()
	print("✓ Test 1: Centrado óptico compensado de armas verificado.")


func _test_hero_picker_modal_initial_flow() -> void:
	var picker: CanvasLayer = HeroPickerModalScene.instantiate() as CanvasLayer
	add_child(picker)

	var roster_dict := CharacterData.load_roster()
	var roster_arr: Array[CharacterData] = []
	for k in roster_dict.keys():
		roster_arr.append(roster_dict[k])

	picker.open_picker(roster_arr, &"nova", true)
	assert_true(picker.is_open, "HeroPickerModal debe quedar abierto tras open_picker.")
	assert_true(picker.is_initial_entry, "Debe registrarse como entrada inicial.")

	# Comprobar blur en DimOverlay
	var dim: ColorRect = picker.get_node_or_null("DimOverlay") as ColorRect
	assert_true(dim != null and dim.material is ShaderMaterial, "DimOverlay debe poseer ShaderMaterial con blur.")

	# Comprobar preview central
	var preview_tex: TextureRect = picker.get_node_or_null("DimOverlay/CenterContainer/CenterVBox/PreviewHolder/HeroPreview") as TextureRect
	assert_true(preview_tex != null and preview_tex.texture != null, "HeroPreview debe mostrar textura de la heroína.")

	# Comprobar LeftDossierPanel (Sistemas de Combate)
	var dossier_panel: PanelContainer = picker.get_node_or_null("DimOverlay/LeftDossierPanel") as PanelContainer
	assert_true(dossier_panel != null, "DimOverlay debe poseer LeftDossierPanel con Sistemas de Combate.")
	assert_true(picker.weapon_block_title != null and not picker.weapon_block_title.text.is_empty(), "Dossier debe mostrar arma de la heroína.")
	assert_true(picker.tactical_block_title != null and not picker.tactical_block_title.text.is_empty(), "Dossier debe mostrar habilidad táctica de la heroína.")

	# Simular confirmación
	var confirmed_id: Array[StringName] = [&""]
	picker.hero_confirmed.connect(func(cid: StringName) -> void:
		confirmed_id[0] = cid
	)

	picker._cycle_hero(1)
	picker._confirm_selection()
	await get_tree().process_frame

	assert_true(not picker.is_open, "HeroPickerModal debe cerrarse al confirmar.")
	assert_true(not confirmed_id[0].is_empty(), "hero_confirmed debe emitir el ID de la heroína.")

	picker.queue_free()
	print("✓ Test 2: Flujo HeroPickerModal (apertura con blur, preview central, dossier lateral y confirmación) verificado.")


func _test_dock_hover_and_focus_flow() -> void:
	var ui: CharacterSelectUI = CharacterSelectScene.instantiate() as CharacterSelectUI
	add_child(ui)

	# Esperar 2 frames para inicialización
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.dock_unified_button != null, "DockContainer debe poseer nodo DockUnifiedButton unificado.")

	# Verificar que los botones individuales del dock tienen hover stylebox definido (evitando pérdida de fondo)
	var dock_buttons: Dictionary = ui._dock_card_buttons
	assert_true(not dock_buttons.is_empty(), "Dock debe contener botones de heroínas.")
	for cid in dock_buttons.keys():
		var btn: Button = dock_buttons[cid]
		var norm_sb := btn.get_theme_stylebox("normal")
		var hov_sb := btn.get_theme_stylebox("hover")
		var press_sb := btn.get_theme_stylebox("pressed")
		assert_true(norm_sb != null, "Botón de %s debe tener normal StyleBox." % cid)
		assert_true(hov_sb != null, "Botón de %s debe tener hover StyleBox para no perder fondo." % cid)
		assert_true(press_sb != null, "Botón de %s debe tener pressed StyleBox." % cid)

	# Simular confirmación en hero_picker_modal -> foco debe ir a ship_button (Exotraje)
	if ui.hero_picker_modal and ui.hero_picker_modal.is_open:
		assert_true(ui.main_margin_container != null and not ui.main_margin_container.visible, "main_margin_container debe estar oculto mientras el picker de heroína está activo.")
		ui._on_hero_confirmed(&"nova")
		await get_tree().process_frame
		assert_true(ui.main_margin_container.visible, "main_margin_container debe revelarse tras confirmar heroína.")
		assert_true(ui.abilities_view.visible, "AbilitiesView debe revelarse tras confirmar heroína.")
		assert_true(ui.weapon_block_title != null and not ui.weapon_block_title.text.is_empty(), "weapon_block_title en AbilitiesView debe estar cargado correctamente.")
		assert_true(ui.dock_container != null and ui.dock_container.visible, "dock_container debe estar visible en la pantalla de loadout.")
		assert_true(ui.orbital_terminal != null and ui.orbital_terminal.visible, "El botón de lanzamiento (orbital_terminal) debe estar visible para iniciar la partida.")
		assert_true(ui.dock_margin != null and not ui.dock_margin.visible, "dock_margin (avatares colapsados) debe quedar oculto en la pantalla de loadout.")
		assert_true(ui.back_button != null and ui.back_button.text == "← [ESC] HUB", "back_button debe indicar '← [ESC] HUB'.")
		assert_true(ui.ship_button != null, "ship_button debe ser accesible para focus.")
		var current_focus := get_viewport().gui_get_focus_owner()
		assert_true(current_focus == ui.ship_button, "El foco debe saltar directamente al Exotraje tras confirmar heroína.")

		# Probar centrado simétrico del arma al equipar skin de piloto y de arma
		assert_true(ui.weapon_icon.texture is AtlasTexture, "weapon_icon debe usar un AtlasTexture centrado.")
		var initial_region: Rect2 = (ui.weapon_icon.texture as AtlasTexture).region
		assert_true(is_equal_approx(initial_region.size.x, initial_region.size.y), "La región recortada del arma debe ser perfectamente cuadrada para no descentrarse.")

		# Cambiar skin de piloto
		ui._on_skin_selected("pilot:nova", "pilot_nova_cyber_mecha")
		await get_tree().process_frame
		var after_pilot_skin_region: Rect2 = (ui.weapon_icon.texture as AtlasTexture).region
		assert_true(is_equal_approx(after_pilot_skin_region.size.x, after_pilot_skin_region.size.y), "Tras cambiar skin de piloto, la región del arma debe mantenerse cuadrada y centrada.")

		# Cambiar skin de arma
		ui._on_skin_selected("weapon:nova", "weapon_nova_cyber_mecha")
		await get_tree().process_frame
		var after_weapon_skin_region: Rect2 = (ui.weapon_icon.texture as AtlasTexture).region
		assert_true(is_equal_approx(after_weapon_skin_region.size.x, after_weapon_skin_region.size.y), "Tras cambiar skin de arma, la región del arma debe ser cuadrada y simétrica.")

		# Probar que al presionar ESC (ui_cancel), _input lo maneja llamando a _on_back_pressed
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.keycode = KEY_ESCAPE
		ui._input(ev)
		assert_true(get_viewport().is_input_handled(), "ESC sin modales abiertos debe ser consumido por CharacterSelectUI para volver al HUB.")

	ui.queue_free()
	print("✓ Test 3: Unificación del dock, retorno al HUB con ESC y centrado simétrico del arma verificados.")
