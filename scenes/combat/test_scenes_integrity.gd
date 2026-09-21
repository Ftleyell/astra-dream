extends SceneTree

func _init() -> void:
	create_timer(4.0).timeout.connect(func():
		printerr("[TIMEOUT] Test de escenas excedió el tiempo.")
		quit(1)
	)
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	print("--- VERIFICANDO INSTANCIACIÓN DE ESCENAS PRINCIPALES ---")

	var scenes := [
		"res://scenes/ui/main_menu/main_menu.tscn",
		"res://scenes/ui/character_select/character_select.tscn",
		"res://scenes/ui/hub/hub_world.tscn",
		"res://scenes/combat/main_game.tscn"
	]

	for path in scenes:
		var res: PackedScene = load(path)
		if not res:
			printerr("[ERROR] Falló al cargar: ", path)
			quit(1)
			return
		var inst = res.instantiate()
		if not inst:
			printerr("[ERROR] Falló al instanciar: ", path)
			quit(1)
			return
		root.add_child(inst)
		print("[OK] Escena instanciada correctamente: ", path)
		inst.queue_free()

	print("--- TODAS LAS ESCENAS PRINCIPALES CARGAN E INSTANCIAN CON ÉXITO ---")
	quit(0)
