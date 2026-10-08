extends SceneTree

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	
	var files: Array[String] = []
	var collect: bool = false
	for arg: String in args:
		if arg == "--":
			collect = true
			continue
		if collect or arg.ends_with(".gd"):
			if not arg.begins_with("-") and not arg.contains("validate_gdscript.gd"):
				files.append(arg)
	
	if files.is_empty():
		print("[VALIDATOR] Ningun archivo especificado.")
		quit(0)
		return
	
	var had_error: bool = false
	for file_path: String in files:
		var norm_path: String = file_path.replace("\\", "/")
		if not norm_path.begins_with("res://"):
			# Si es ruta relativa o absoluta local, normalizar a res://
			var clean_path: String = norm_path
			if clean_path.contains("astra_dream/"):
				clean_path = clean_path.substr(clean_path.find("astra_dream/") + 12)
			norm_path = "res://" + clean_path.trim_prefix("/")
		
		var script: Resource = load(norm_path)
		if script == null:
			printerr("✗ [COMPILE ERROR] %s" % norm_path)
			had_error = true
		else:
			print("✓ [OK] %s" % norm_path)
	
	quit(1 if had_error else 0)
