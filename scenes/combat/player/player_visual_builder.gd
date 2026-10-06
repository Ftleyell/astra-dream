class_name PlayerVisualBuilder
extends RefCounted

## PlayerVisualBuilder.gd
## Controlador de renderizado visual, shaders dinámicos de vuelo y personalización cosmética del jugador:
## - Aplica skins de nave y texturas sobre ShipSprite o polygon fallback.
## - Configura el material de shader maestro (exo_pilot_flight.gdshader) con estela y parámetros térmicos.
## - Vincula y actualiza el componente de imágenes residuales Sandevistan (SandevistanFlightVFX).
## - Ajusta el sprite y posición del arma primaria en WeaponController.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")
const SandevistanFlightVFXClass = preload("res://scenes/combat/player/sandevistan_flight_vfx.gd")

func apply_visual_theme(player: CharacterBody2D, character_data: CharacterData) -> void:
	if not character_data:
		return

	var placeholder: Polygon2D = player.get_node_or_null("VisualPlaceholder") as Polygon2D
	var ship_tex: Texture2D = character_data.get_ship_texture() if character_data.has_method("get_ship_texture") else null

	var ship_spr: Sprite2D = player.get_node_or_null("ShipSprite") as Sprite2D
	if not ship_spr and ship_tex:
		ship_spr = Sprite2D.new()
		ship_spr.name = "ShipSprite"
		ship_spr.z_index = 1
		player.add_child(ship_spr)
		player.move_child(ship_spr, 0)
	elif ship_spr:
		ship_spr.z_index = 1

	# Aplicar Shader Maestro de vuelo de exo-piloto
	var flight_shader: Shader = preload("res://shaders/exo_pilot_flight.gdshader")
	var flight_mat := ShaderMaterial.new()
	flight_mat.shader = flight_shader
	var p_color: Color = character_data.color if character_data else Color(0.2, 0.75, 1.0, 1.0)
	var sec_color: Color = Color(1.0, 0.85, 0.4, 1.0)
	if p_color.h < 0.5:
		sec_color = Color.from_hsv(wrapf(p_color.h + 0.15, 0.0, 1.0), 0.7, 1.1)
	else:
		sec_color = Color.from_hsv(wrapf(p_color.h - 0.15, 0.0, 1.0), 0.7, 1.1)

	var noise_res: Resource = preload("res://shaders/flame_noise.tres")
	if noise_res:
		flight_mat.set_shader_parameter("noise_texture", noise_res)

	flight_mat.set_shader_parameter("primary_color", p_color)
	flight_mat.set_shader_parameter("secondary_color", sec_color)
	flight_mat.set_shader_parameter("thrust_intensity", 0.35)
	flight_mat.set_shader_parameter("speed_ratio", 0.0)
	flight_mat.set_shader_parameter("bank_tilt", 0.0)
	flight_mat.set_shader_parameter("chromatic_offset", 0.004)
	flight_mat.set_shader_parameter("hit_flash", 0.0)
	flight_mat.set_shader_parameter("core_gem_glow", 1.2)
	flight_mat.set_shader_parameter("flame_direction", Vector2(0.0, 1.0))

	# Configuración de máscara procedimental y peinado
	var mask_tex: Texture2D = character_data.get_ship_mask() if character_data.has_method("get_ship_mask") else null
	if mask_tex:
		flight_mat.set_shader_parameter("has_mask", true)
		flight_mat.set_shader_parameter("mask_texture", mask_tex)
		flight_mat.set_shader_parameter("hair_dir", character_data.hair_direction)
		flight_mat.set_shader_parameter("wave_freq", character_data.hair_wave_frequency)
		flight_mat.set_shader_parameter("hair_amp", character_data.hair_amplitude)
		flight_mat.set_shader_parameter("enable_thrusters", true)
	else:
		flight_mat.set_shader_parameter("has_mask", false)
		flight_mat.set_shader_parameter("enable_thrusters", false)

	# Componente de imágenes residuales Sandevistan
	var vfx_comp: SandevistanFlightVFX = player.get_node_or_null("SandevistanFlightVFX") as SandevistanFlightVFX
	if not vfx_comp and ship_spr:
		vfx_comp = SandevistanFlightVFXClass.new()
		vfx_comp.name = "SandevistanFlightVFX"
		vfx_comp.source_sprite = ship_spr
		player.add_child(vfx_comp)
	if vfx_comp:
		vfx_comp.configure_colors(p_color, sec_color)

	# Aplicar skin cosmética a la nave si está equipada
	var char_id_str: String = String(character_data.character_id) if character_data else "survivor_default"
	var equipped_ship_skin: String = SaveManager.get_equipped_skin("ship:" + char_id_str)
	var custom_tex: Texture2D = null
	var skin_data: Dictionary = {}
	if not equipped_ship_skin.is_empty() and equipped_ship_skin != "base" and equipped_ship_skin != "default":
		skin_data = CosmeticsManager.get_skin(equipped_ship_skin)
		custom_tex = CosmeticsManager.get_skin_texture(skin_data)

	if ship_spr:
		var final_ship_tex: Texture2D = custom_tex if custom_tex else ship_tex
		if final_ship_tex:
			ship_spr.texture = final_ship_tex
			var glow_hex: String = skin_data.get("glow_hex", "")
			if not glow_hex.is_empty():
				var skin_primary: Color = Color.from_string(glow_hex, p_color)
				flight_mat.set_shader_parameter("primary_color", skin_primary)
				if vfx_comp:
					vfx_comp.configure_colors(skin_primary, sec_color)
			ship_spr.material = flight_mat
			ship_spr.visible = true
			ship_spr.scale = Vector2(0.42, 0.42)
			if placeholder:
				placeholder.visible = false
		else:
			ship_spr.visible = false
			ship_spr.material = null
			if placeholder:
				placeholder.visible = true

	if placeholder and (not ship_spr or not ship_spr.visible):
		placeholder.color = character_data.color
		placeholder.visible = true
		if character_data.pts.size() >= 3:
			var scaled_pts := PackedVector2Array()
			for pt: Vector2 in character_data.pts:
				scaled_pts.append(pt * 0.35)
			placeholder.polygon = scaled_pts

	# Configurar sprite del arma rotatoria en WeaponController
	var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl:
		w_ctrl.z_index = 20
		w_ctrl.z_as_relative = false
		player.move_child(w_ctrl, player.get_child_count() - 1)
		var w_tex: Texture2D = character_data.get_weapon_texture() if character_data.has_method("get_weapon_texture") else null
		var w_spr: Sprite2D = w_ctrl.get_node_or_null("WeaponSprite") as Sprite2D
		var w_poly: Polygon2D = w_ctrl.get_node_or_null("WeaponVisual") as Polygon2D
		if not w_spr and (w_tex or not SaveManager.get_equipped_skin("weapon:" + char_id_str).is_empty()):
			w_spr = Sprite2D.new()
			w_spr.name = "WeaponSprite"
			w_ctrl.add_child(w_spr)
		if w_spr:
			w_spr.z_as_relative = false
			w_spr.z_index = 20
			w_spr.move_to_front()
			var equipped_w_skin: String = SaveManager.get_equipped_skin("weapon:" + char_id_str)
			var w_applied := false
			if not equipped_w_skin.is_empty() and equipped_w_skin != "base" and equipped_w_skin != "default":
				var w_stars: int = SaveManager.get_skin_stars(equipped_w_skin)
				CosmeticsManager.apply_skin_to_canvas_item(w_spr, equipped_w_skin, w_stars)
				if w_spr.texture:
					w_spr.position = Vector2.ZERO
					w_spr.visible = true
					w_applied = true
					if w_poly:
						w_poly.visible = false
			if not w_applied:
				if w_tex:
					w_spr.texture = w_tex
					w_spr.material = null
					w_spr.position = Vector2.ZERO
					w_spr.visible = true
					if w_poly:
						w_poly.visible = false
				else:
					w_spr.visible = false
					w_spr.material = null
					if w_poly:
						w_poly.z_as_relative = false
						w_poly.z_index = 20
						w_poly.position = Vector2.ZERO
						w_poly.visible = true

			if w_spr.visible:
				var char_visual_size: float = 108.0
				if ship_spr and ship_spr.texture:
					char_visual_size = maxf(float(ship_spr.texture.get_width()) * ship_spr.scale.x, float(ship_spr.texture.get_height()) * ship_spr.scale.y)
				var target_weapon_pixel_size: float = char_visual_size * 0.45
				var tex_dim: float = 128.0
				if w_spr.texture:
					tex_dim = maxf(float(w_spr.texture.get_width()), float(w_spr.texture.get_height()))
				var target_scale: float = target_weapon_pixel_size / maxf(tex_dim, 1.0)
				w_spr.scale = Vector2(target_scale, target_scale)

func update_pilot_shader(player: CharacterBody2D, delta: float, is_moving: bool) -> void:
	var ship_spr: Sprite2D = player.get_node_or_null("ShipSprite") as Sprite2D
	if not ship_spr or not (ship_spr.material is ShaderMaterial):
		return

	var mat: ShaderMaterial = ship_spr.material as ShaderMaterial
	var max_spd: float = maxf(1.0, player.stats.get_stat(&"move_speed") if ("stats" in player and player.stats) else 200.0)
	var spd_ratio: float = clampf(player.velocity.length() / max_spd, 0.0, 1.0)

	var is_dashing: bool = (player.get("is_dashing") if "is_dashing" in player else false) or bool(player.get_meta("is_dashing", false))
	var idle_bob_timer: float = (player.get("idle_bob_timer") if "idle_bob_timer" in player else 0.0) if not player.has_meta("idle_bob_timer") else float(player.get_meta("idle_bob_timer", 0.0))
	var current_bank_tilt: float = (player.get("current_bank_tilt") if "current_bank_tilt" in player else 0.0) if not player.has_meta("current_bank_tilt") else float(player.get_meta("current_bank_tilt", 0.0))
	var hit_flash_timer: float = (player.get("hit_flash_timer") if "hit_flash_timer" in player else 0.0) if not player.has_meta("hit_flash_timer") else float(player.get_meta("hit_flash_timer", 0.0))
	var current_facing_angle: float = (player.get("current_facing_angle") if "current_facing_angle" in player else 0.0) if not player.has_meta("current_facing_angle") else float(player.get_meta("current_facing_angle", 0.0))

	var target_thrust: float = 0.25
	if is_dashing:
		target_thrust = 2.4
	elif is_moving:
		target_thrust = lerpf(0.65, 1.25, spd_ratio)
	else:
		target_thrust = 0.25 + 0.08 * sin(idle_bob_timer * 6.0)

	mat.set_shader_parameter("thrust_intensity", target_thrust)
	mat.set_shader_parameter("speed_ratio", spd_ratio)
	mat.set_shader_parameter("bank_tilt", current_bank_tilt)
	mat.set_shader_parameter("hit_flash", 1.0 if hit_flash_timer > 0.0 else 0.0)

	# Inercia de piernas y modulación de soplete
	var leg_bend_val: float = clampf(-current_bank_tilt * 0.22, -0.22, 0.22)
	mat.set_shader_parameter("leg_bend", leg_bend_val)

	if is_dashing:
		mat.set_shader_parameter("thruster_length", 0.75)
		mat.set_shader_parameter("thruster_speed", 90.0)
		mat.set_shader_parameter("thruster_width", 0.075)
	elif is_moving:
		mat.set_shader_parameter("thruster_length", lerpf(0.38, 0.52, spd_ratio))
		mat.set_shader_parameter("thruster_speed", lerpf(45.0, 70.0, spd_ratio))
		mat.set_shader_parameter("thruster_width", lerpf(0.04, 0.055, spd_ratio))
	else:
		mat.set_shader_parameter("thruster_length", 0.32 + 0.04 * sin(idle_bob_timer * 4.0))
		mat.set_shader_parameter("thruster_speed", 40.0)
		mat.set_shader_parameter("thruster_width", 0.038)

	var gem_glow: float = 1.2
	if is_dashing:
		gem_glow = 2.2
	elif hit_flash_timer > 0.0:
		gem_glow = 2.8
	mat.set_shader_parameter("core_gem_glow", gem_glow)

	var visual_rot: float = current_facing_angle + PI / 2.0
	var local_burn := Vector2(0.0, 1.0)
	if is_moving and player.velocity.length_squared() > 100.0:
		var local_vel: Vector2 = player.velocity.rotated(-visual_rot)
		var dir: Vector2 = -local_vel.normalized()
		if not dir.is_zero_approx():
			local_burn = dir
	mat.set_shader_parameter("flame_direction", local_burn)

	var vfx_comp: SandevistanFlightVFX = player.get_node_or_null("SandevistanFlightVFX") as SandevistanFlightVFX
	if vfx_comp:
		vfx_comp.update_flight(delta, player.velocity, is_dashing)
