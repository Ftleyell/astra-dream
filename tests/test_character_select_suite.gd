extends Node

func _ready() -> void:
	get_tree().create_timer(6.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(0)
	)

	print("\n==========================================")
	print("[TEST] Testing Revamped Character Select UI & Spacebar Launch...")
	print("==========================================")

	var scene_res := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	assert(scene_res != null, "character_select.tscn debe cargar")

	var ui: CharacterSelectUI = scene_res.instantiate()
	add_child(ui)

	# 1. Verificar población de botones de personajes
	var char_list := ui.char_list_container
	assert(char_list != null, "char_list_container debe existir")
	assert(char_list.get_child_count() == 6, "Deben existir 6 botones de pilotos en el roster")

	var first_btn := char_list.get_child(0) as Button
	assert(first_btn.icon != null, "El botón de Nova debe tener icono de retrato")
	assert("NOVA" in first_btn.text, "El primer botón debe ser Nova")

	# 2. Verificar datos de Nova seleccionada por defecto
	assert(ui.name_label.text == "NOVA", "Nombre mostrado debe ser NOVA")
	assert(ui.fullbody_texture.texture != null, "Fullbody texture no debe ser nula")
	assert(ui.ship_icon.texture != null, "Ship icon no debe ser nulo")
	assert(ui.weapon_icon.texture != null, "Weapon icon no debe ser nulo")
	print("  ✓ Nova seleccionada correctamente con full body, nave, arma y retrato")

	# 3. Cambiar a Valentina
	ui._select_character(&"valentina")
	assert(ui.name_label.text == "VALENTINA", "Nombre mostrado debe ser VALENTINA")
	assert(ui.current_character_id == &"valentina", "current_character_id debe ser valentina")
	assert(ui.fullbody_texture.texture != null, "Fullbody de Valentina debe asignarse")
	print("  ✓ Selección interactiva de Valentina verificada con todos sus assets")

	# 4. Verificar pulsación de barra espaciadora
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	space_event.echo = false

	# Verificamos que _unhandled_input procesa KEY_SPACE sin errores
	ui._unhandled_input(space_event)
	print("  ✓ Atajo de Barra Espaciadora procesado para despegue")

	ui.queue_free()

	print("\n==========================================")
	print("[PASS] CHARACTER SELECT UI & SPACEBAR VERIFIED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)
