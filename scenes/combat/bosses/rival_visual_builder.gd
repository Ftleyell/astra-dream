class_name RivalVisualBuilder
extends RefCounted

## RivalVisualBuilder.gd
## Ensamblador procedural de componentes visuales para el jefe RivalPilotBoss:
## - Instancia y parametriza el shader de vuelo exo-pilot con sus máscaras y paletas.
## - Configura CollisionShape2D, WarningLabel y CombatDangerRing.

static func setup_ship_sprite(
	parent: Node2D,
	character_data: CharacterData,
	pilot_id: StringName,
	pilot_theme_colors: Dictionary
) -> Sprite2D:
	var ship_sprite := parent.get_node_or_null("ShipSprite") as Sprite2D
	if not ship_sprite:
		ship_sprite = Sprite2D.new()
		ship_sprite.name = "ShipSprite"
		ship_sprite.scale = Vector2(0.42, 0.42)
		ship_sprite.z_index = 2
		parent.add_child(ship_sprite)

	var tex: Texture2D = character_data.get_ship_texture() if character_data else null
	if not tex:
		var fb_path := "res://assets/characters/ships/ship_nova.png"
		if ResourceLoader.exists(fb_path):
			tex = load(fb_path) as Texture2D
	ship_sprite.texture = tex

	var flight_mat := ShaderMaterial.new()
	flight_mat.shader = preload("res://shaders/exo_pilot_flight.gdshader")
	var theme_col: Color = pilot_theme_colors.get(pilot_id, Color(0.0, 0.9, 1.0))
	var sec_col: Color = Color.from_hsv(wrapf(theme_col.h + 0.15, 0.0, 1.0), 0.7, 1.1)
	flight_mat.set_shader_parameter("primary_color", theme_col)
	flight_mat.set_shader_parameter("secondary_color", sec_col)
	flight_mat.set_shader_parameter("thrust_intensity", 0.5)

	var noise_res: Resource = preload("res://shaders/flame_noise.tres")
	if noise_res:
		flight_mat.set_shader_parameter("noise_texture", noise_res)

	var mask_tex: Texture2D = character_data.get_ship_mask() if character_data and character_data.has_method("get_ship_mask") else null
	if not mask_tex:
		var mask_path := "res://assets/characters/ships/ship_%s_mask.png" % str(pilot_id).to_lower()
		if ResourceLoader.exists(mask_path):
			mask_tex = load(mask_path) as Texture2D

	if mask_tex:
		flight_mat.set_shader_parameter("has_mask", true)
		flight_mat.set_shader_parameter("mask_texture", mask_tex)
		if character_data:
			flight_mat.set_shader_parameter("hair_dir", character_data.hair_direction)
			flight_mat.set_shader_parameter("wave_freq", character_data.hair_wave_frequency)
			flight_mat.set_shader_parameter("hair_amp", character_data.hair_amplitude)
		flight_mat.set_shader_parameter("enable_thrusters", true)
	else:
		flight_mat.set_shader_parameter("has_mask", false)
		flight_mat.set_shader_parameter("enable_thrusters", false)
	ship_sprite.material = flight_mat
	return ship_sprite


static func setup_collision_shape(parent: Node2D) -> void:
	var existing_col := parent.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if existing_col and existing_col.shape is CircleShape2D:
		(existing_col.shape as CircleShape2D).radius = 18.0
	elif not existing_col:
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0
		col.shape = circle
		parent.add_child(col)


static func setup_warning_label(parent: Node2D) -> Label:
	var warning_label := parent.get_node_or_null("WarningLabel") as Label
	if not warning_label:
		warning_label = Label.new()
		warning_label.name = "WarningLabel"
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		warning_label.position = Vector2(-200, -85)
		warning_label.size = Vector2(400, 30)
		warning_label.z_index = 3
		warning_label.add_theme_font_size_override("font_size", 13)
		parent.add_child(warning_label)
	return warning_label


static func setup_danger_ring(parent: Node2D, combat_trigger_radius: float) -> Sprite2D:
	var ring := parent.get_node_or_null("CombatDangerRing") as Sprite2D
	if not ring:
		ring = Sprite2D.new()
		ring.name = "CombatDangerRing"
		var ring_path := "res://assets/sprites/effects/rival_danger_projection.png"
		var ring_tex: Texture2D = null
		if ResourceLoader.exists(ring_path):
			ring_tex = load(ring_path) as Texture2D
		if not ring_tex:
			var global_path := ProjectSettings.globalize_path(ring_path)
			if FileAccess.file_exists(global_path):
				var img := Image.new()
				if img.load(global_path) == OK:
					ring_tex = ImageTexture.create_from_image(img)
		ring.texture = ring_tex
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ring.material = mat
		var sx: float = parent.scale.x if parent.scale.x > 0.0 else 1.0
		var target_scale: float = (combat_trigger_radius * 2.0) / (906.0 * sx)
		ring.scale = Vector2(target_scale, target_scale)
		ring.modulate = Color(1.0, 0.25, 0.3, 0.65)
		ring.z_index = -2
		parent.add_child(ring)
	return ring
