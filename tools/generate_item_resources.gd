extends SceneTree

func _init() -> void:
	print("==================================================")
	print("🛠️ Astra Dream — Generador de Recursos .tres de Ítems")
	print("==================================================")

	var dir_path := "res://data/items/roster"
	var da := DirAccess.open("res://data/items")
	if da:
		if not da.dir_exists("roster"):
			da.make_dir("roster")
			print("  ✓ Directorio data/items/roster creado.")

	# Obtener todos los ítems canónicos y satelitales
	var canonical := ItemPoolManager.create_canonical_stat_items()
	var satellite := ItemPoolManager.create_satellite_shop_items()

	var all_items: Dictionary = {}
	for it in canonical:
		all_items[it.item_id] = it
	for it in satellite:
		if not all_items.has(it.item_id):
			all_items[it.item_id] = it

	print("  Total ítems únicos a materializar en .tres: %d" % all_items.size())

	var saved_count := 0
	for item_id in all_items.keys():
		var it: ItemData = all_items[item_id]
		var file_path := "%s/%s.tres" % [dir_path, str(item_id)]
		var err := ResourceSaver.save(it, file_path)
		if err == OK:
			saved_count += 1
		else:
			printerr("  ✗ Error al guardar %s: %d" % [file_path, err])

	print("==================================================")
	print("  ✓ %d archivos .tres creados exitosamente en data/items/roster/" % saved_count)
	print("==================================================")
	quit(0)
