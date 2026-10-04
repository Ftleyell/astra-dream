extends SceneTree

const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const EnumsScript = preload("res://core/types/enums.gd")

func _init() -> void:
	print("==================================================")
	print("📚 Astra Dream — Generador de Recursos .tres de Tomos")
	print("==================================================")

	var dir_path := "res://data/tomes"
	var da := DirAccess.open("res://data")
	if da:
		if not da.dir_exists("tomes"):
			da.make_dir("tomes")
			print("  ✓ Directorio data/tomes creado.")

	var defs: Array[Dictionary] = [
		{
			"id": &"tome_base_damage",
			"name": "Tomo de Poder",
			"desc": "Aumenta el daño base infligido por todas las armas y proyectiles.",
			"icon": "res://assets/icons/items/icon_sword.svg",
			"stat": &"base_damage",
			"val": 5.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"offense", &"damage"]
		},
		{
			"id": &"tome_attack_speed",
			"name": "Tomo de Cadencia",
			"desc": "Aumenta la velocidad de ataque y disparo de todas las armas.",
			"icon": "res://assets/icons/items/icon_gauntlet.svg",
			"stat": &"attack_speed",
			"val": 0.10,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"offense", &"speed"]
		},
		{
			"id": &"tome_crit_chance",
			"name": "Tomo de Precisión",
			"desc": "Aumenta la probabilidad de asestar impactos críticos.",
			"icon": "res://assets/icons/items/icon_glasses.svg",
			"stat": &"crit_chance",
			"val": 0.08,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"offense", &"crit"]
		},
		{
			"id": &"tome_crit_damage",
			"name": "Tomo de Devastación",
			"desc": "Aumenta el multiplicador de daño infligido al asestar golpes críticos.",
			"icon": "res://assets/icons/items/icon_lens.svg",
			"stat": &"crit_damage",
			"val": 0.25,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"offense", &"crit"]
		},
		{
			"id": &"tome_cooldown_reduction",
			"name": "Tomo de Celeridad",
			"desc": "Reduce el tiempo de recarga y enfriamiento de armas automáticas y habilidades.",
			"icon": "res://assets/icons/restart.svg",
			"stat": &"cooldown_reduction",
			"val": 0.08,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"utility", &"cooldown"]
		},
		{
			"id": &"tome_projectile_speed",
			"name": "Tomo Balístico",
			"desc": "Aumenta la velocidad de vuelo de todos los proyectiles disparados.",
			"icon": "res://assets/icons/rocket.svg",
			"stat": &"projectile_speed",
			"val": 0.15,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"offense", &"projectile"]
		},
		{
			"id": &"tome_weapon_size",
			"name": "Tomo de Amplitud",
			"desc": "Incrementa el tamaño y radio de impacto de proyectiles y explosiones.",
			"icon": "res://assets/icons/star.svg",
			"stat": &"weapon_size",
			"val": 0.15,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"offense", &"area"]
		},
		{
			"id": &"tome_projectile_count",
			"name": "Tomo Multidisparo",
			"desc": "Añade proyectiles adicionales a todas las salvas disparadas.",
			"icon": "res://assets/icons/items/icon_quiver.svg",
			"stat": &"projectile_count",
			"val": 1.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"offense", &"projectile"]
		},
		{
			"id": &"tome_move_speed",
			"name": "Tomo de Impulso",
			"desc": "Aumenta la velocidad de desplazamiento de la nave.",
			"icon": "res://assets/icons/items/icon_boots.svg",
			"stat": &"move_speed",
			"val": 20.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"mobility", &"speed"]
		},
		{
			"id": &"tome_max_health",
			"name": "Tomo de Blindaje",
			"desc": "Aumenta la integridad estructural máxima del casco de la nave.",
			"icon": "res://assets/icons/items/icon_heart.svg",
			"stat": &"max_health",
			"val": 25.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"defense", &"health"]
		},
		{
			"id": &"tome_health_regen",
			"name": "Tomo de Nanoreparación",
			"desc": "Regenera puntos de casco de forma sostenida cada segundo.",
			"icon": "res://assets/icons/items/icon_apple.svg",
			"stat": &"health_regen",
			"val": 0.8,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"defense", &"regen"]
		},
		{
			"id": &"tome_armor",
			"name": "Tomo de Mitigación",
			"desc": "Reduce el daño directo recibido ante cualquier impacto hostil.",
			"icon": "res://assets/icons/items/icon_shield.svg",
			"stat": &"armor",
			"val": 2.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"defense", &"armor"]
		},
		{
			"id": &"tome_pickup_radius",
			"name": "Tomo Gravitatorio",
			"desc": "Amplía el campo magnético para atraer telemetría y suministros.",
			"icon": "res://assets/icons/items/icon_magnet.svg",
			"stat": &"pickup_radius",
			"val": 30.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"utility", &"magnet"]
		},
		{
			"id": &"tome_luck",
			"name": "Tomo de Fortuna",
			"desc": "Mejora las probabilidades cuánticas en recompensas y cofres.",
			"icon": "res://assets/icons/items/icon_clover.svg",
			"stat": &"luck",
			"val": 0.15,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"utility", &"luck"]
		},
		{
			"id": &"tome_exp_multiplier",
			"name": "Tomo de Telemetría",
			"desc": "Incrementa la experiencia obtenida de todos los cristales en combate.",
			"icon": "res://assets/icons/package.svg",
			"stat": &"exp_multiplier",
			"val": 0.15,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"utility", &"exp"]
		},
		{
			"id": &"tome_credits_multiplier",
			"name": "Tomo de Extracción",
			"desc": "Multiplica la cantidad de créditos cósmicos extraídos en combate.",
			"icon": "res://assets/sprites/ui/credit_coin_icon.png",
			"stat": &"credits_multiplier",
			"val": 0.20,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"economy", &"utility"]
		},
		{
			"id": &"tome_biomass_multiplier",
			"name": "Tomo de Biocosecha",
			"desc": "Incrementa la biomasa orgánica recolectada de aberraciones eliminadas.",
			"icon": "res://assets/sprites/ui/biomass_dna_icon.png",
			"stat": &"biomass_multiplier",
			"val": 0.20,
			"pct": true,
			"mod": Enums.ModifierType.ADDITIVE_PERCENT,
			"tags": [&"economy", &"biomass"]
		},
		{
			"id": &"tome_curse",
			"name": "Tomo de Entropía",
			"desc": "Eleva la maldición cósmica, aumentando la densidad y desafío enemigo.",
			"icon": "res://assets/icons/icon_arcana_rune.svg",
			"stat": &"curse",
			"val": 10.0,
			"pct": false,
			"mod": Enums.ModifierType.FLAT,
			"tags": [&"curse", &"challenge"]
		}
	]

	var saved_count := 0
	for d in defs:
		var tome = TomeDataScript.new()
		tome.tome_id = d["id"]
		tome.display_name = d["name"]
		tome.description = d["desc"]
		if ResourceLoader.exists(d["icon"]):
			tome.icon = load(d["icon"]) as Texture2D
		tome.stat_name = d["stat"]
		tome.stat_value_per_level = d["val"]
		tome.is_percentage = d["pct"]
		tome.modifier_type = d["mod"]
		tome.max_level = 5
		tome.base_unlocked = true
		var t_tags: Array[StringName] = []
		for t in d["tags"]:
			t_tags.append(StringName(t))
		tome.tags = t_tags

		var file_path := "%s/%s.tres" % [dir_path, str(tome.tome_id)]
		var err := ResourceSaver.save(tome, file_path)
		if err == OK:
			saved_count += 1
		else:
			printerr("  ✗ Error al guardar %s: %d" % [file_path, err])

	print("==================================================")
	print("  ✓ %d archivos .tres creados exitosamente en data/tomes/" % saved_count)
	print("==================================================")
	quit(0)
