class_name CosmeticCarouselLayoutBuilder
extends RefCounted

## CosmeticCarouselLayoutBuilder.gd
## Constructor desacoplado de vista, maquetación y estilos para CosmeticCarouselModal.
## Gestiona el renderizado de tarjetas, shaders de holograma, puntos del carrusel y estilos visuales.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")
const HOLOGRAM_SHADER := preload("res://shaders/pilot_showcase_hologram.gdshader")


func load_available_skins(category: String, target_id: StringName, char_data: CharacterData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tid_str: String = String(target_id).to_lower()

	# Skin Base
	var base_tex: Texture2D = get_base_texture(category, char_data)
	var base_skin: Dictionary = {
		"id": "base",
		"skin_name": "%s Base" % (char_data.display_name if char_data else "Original"),
		"description": "Aspecto operativo estándar de despliegue estelar.",
		"rarity": "common",
		"is_base": true,
		"is_unlocked": true,
		"unlocked_stars": 3,
		"stars": 1,
		"texture": base_tex,
		"glow_color": char_data.color if char_data else Color(0.2, 0.85, 1.0)
	}
	result.append(base_skin)

	# Skins alternativas desde CosmeticsManager
	var catalog_skins: Array[Dictionary] = CosmeticsManager.get_skins_for_target(category, tid_str)
	for s in catalog_skins:
		var sid: String = s.get("id", "")
		var is_unl: bool = SaveManagerScript.is_skin_unlocked(sid)
		var stars: int = SaveManagerScript.get_skin_stars(sid) if is_unl else 1
		var tex: Texture2D = get_skin_texture(category, s, char_data)
		var glow_hex: String = s.get("glow_hex", "#00f0ff")
		var glow_col := Color(glow_hex)

		var entry: Dictionary = {
			"id": sid,
			"skin_name": s.get("skin_name", sid),
			"description": s.get("description", "Aspecto cromático del arsenal cuántico."),
			"rarity": s.get("rarity", "rare"),
			"is_base": false,
			"is_unlocked": is_unl,
			"unlocked_stars": stars if is_unl else 0,
			"stars": clampi(stars, 1, 3),
			"texture": tex,
			"glow_color": glow_col,
			"raw_data": s
		}
		result.append(entry)

	return result


func get_base_texture(category: String, char_data: CharacterData) -> Texture2D:
	if not char_data:
		return null
	match category:
		"pilot":
			return char_data.get_selection_texture(false)
		"ship":
			return char_data.get_ship_texture()
		"weapon":
			return char_data.get_weapon_texture()
	return null


func get_skin_texture(category: String, s_data: Dictionary, char_data: CharacterData) -> Texture2D:
	match category:
		"pilot":
			var sel_path: String = s_data.get("selection_texture_path", "")
			if not sel_path.is_empty() and ResourceLoader.exists(sel_path):
				return load(sel_path) as Texture2D
			var fb_path: String = s_data.get("texture_path", "")
			if not fb_path.is_empty() and ResourceLoader.exists(fb_path):
				return load(fb_path) as Texture2D
		"ship":
			var s_path: String = s_data.get("texture_path", "")
			if not s_path.is_empty() and ResourceLoader.exists(s_path):
				return load(s_path) as Texture2D
		"weapon":
			var w_path: String = s_data.get("texture_path", "")
			if not w_path.is_empty() and ResourceLoader.exists(w_path):
				return load(w_path) as Texture2D
	return get_base_texture(category, char_data)


func setup_frame_dimensions(
	category: String,
	carousel_panel: PanelContainer,
	center_slot: Control,
	artwork_frame: PanelContainer,
	category_label: Label,
	hint_footer_label: Label,
	artwork_texture: TextureRect,
	silhouette_overlay: TextureRect
) -> void:
	if not carousel_panel:
		return
	carousel_panel.custom_minimum_size = Vector2(580, 640)
	match category:
		"pilot":
			center_slot.custom_minimum_size = Vector2(360, 500)
			artwork_frame.custom_minimum_size = Vector2(360, 500)
			category_label.text = "HEROÍNA // PILOTO ESTELAR"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2.ZERO, Vector2.ONE)
		"ship":
			center_slot.custom_minimum_size = Vector2(320, 320)
			artwork_frame.custom_minimum_size = Vector2(320, 320)
			category_label.text = "EXO-TRAJE // AERONAVE DE COMBATE"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2.ZERO, Vector2.ONE)
		"weapon":
			center_slot.custom_minimum_size = Vector2(320, 320)
			artwork_frame.custom_minimum_size = Vector2(320, 320)
			category_label.text = "ARMAMENTO // SISTEMA BALÍSTICO"
			hint_footer_label.text = "✦ [A / D] ASPECTOS  ✦  [W / S] ESTRELLAS  ✦  [ESPACIO] EQUIPAR  ✦  [ESC] SALIR"
			apply_artwork_transform(artwork_texture, silhouette_overlay, Vector2(-38.0, 0.0), Vector2(1.15, 1.15))


func apply_artwork_transform(
	artwork_texture: TextureRect,
	silhouette_overlay: TextureRect,
	offset_pos: Vector2,
	target_scale: Vector2
) -> void:
	if artwork_texture:
		artwork_texture.pivot_offset = artwork_texture.size * 0.5
		artwork_texture.position = offset_pos
		artwork_texture.scale = target_scale
	if silhouette_overlay:
		silhouette_overlay.pivot_offset = silhouette_overlay.size * 0.5
		silhouette_overlay.position = offset_pos
		silhouette_overlay.scale = target_scale


func refresh_display(
	modal: CosmeticCarouselModal,
	available_skins: Array[Dictionary],
	skin_index: int,
	star_level: int,
	category: String,
	target_id: StringName,
	silhouette_material: ShaderMaterial
) -> void:
	if available_skins.is_empty() or not modal:
		return

	var cur: Dictionary = available_skins[skin_index]
	var total: int = available_skins.size()
	var is_unlocked: bool = cur.get("is_unlocked", false)
	var unl_stars: int = cur.get("unlocked_stars", 1)
	var is_star_unlocked: bool = is_unlocked and (star_level <= unl_stars)

	var slot_key: String = "%s:%s" % [category, String(target_id).to_lower()]
	var equipped_now: String = SaveManager.get_equipped_skin(slot_key)
	var is_equipped: bool = is_star_unlocked and (equipped_now == cur.get("id", ""))
	var theme_col: Color = cur.get("glow_color", Color(0.2, 0.85, 1.0))

	# Dossier Header
	modal.index_badge.text = "[ %02d / %02d ]" % [skin_index + 1, total]

	if not is_unlocked:
		modal.name_label.text = "[ BLOQUEADO ]"
		modal.name_label.modulate = Color(0.6, 0.65, 0.75, 0.7)
		modal.status_badge.text = "[ BLOQUEADO // GACHA ]"
		modal.status_badge.modulate = Color(1.0, 0.35, 0.45)
	elif not is_star_unlocked:
		modal.name_label.text = str(cur.get("skin_name", "")).to_upper()
		modal.name_label.modulate = theme_col
		modal.status_badge.text = "[ NIVEL %d★ BLOQUEADO ]" % star_level
		modal.status_badge.modulate = Color(1.0, 0.6, 0.3)
	elif is_equipped:
		modal.name_label.text = str(cur.get("skin_name", "")).to_upper()
		modal.name_label.modulate = theme_col
		modal.status_badge.text = "[✓ EQUIPADA]"
		modal.status_badge.modulate = Color(0.2, 1.0, 0.6)
	else:
		modal.name_label.text = str(cur.get("skin_name", "")).to_upper()
		modal.name_label.modulate = theme_col
		modal.status_badge.text = "[ DISPONIBLE ]"
		modal.status_badge.modulate = Color(0.4, 0.8, 1.0)

	# Stars Badge
	match star_level:
		1: modal.stars_badge.text = "★☆☆  [NIVEL 1 - BASE]"
		2: modal.stars_badge.text = "★★☆  [NIVEL 2 - HALO DE ENERGÍA]"
		3: modal.stars_badge.text = "★★★  [NIVEL 3 - SOBRECARGA RADIANTE]"
	modal.stars_badge.modulate = Color(1.0, 0.85, 0.25) if is_star_unlocked else Color(0.5, 0.55, 0.6)

	# Lore / Info
	if not is_unlocked:
		modal.desc_label.text = "Aspecto estelar clasificado. Desbloquéalo participando en la Gacha Cuántica del Hangar."
	else:
		modal.desc_label.text = str(cur.get("description", ""))

	# Artwork Texture & Shader
	var tex: Texture2D = cur.get("texture", null)
	modal.artwork_texture.texture = tex

	if not is_unlocked or not is_star_unlocked:
		modal.artwork_texture.material = silhouette_material
		modal.locked_overlay.visible = true
		modal.lock_title.text = "ASPECTO BLOQUEADO" if not is_unlocked else "NIVEL %d★ BLOQUEADO" % star_level
		modal.lock_desc.text = "Obtén duplicados o cápsulas cuánticas para desbloquear este nivel de resonancia."
		if modal.circular_glow:
			modal.circular_glow.modulate = Color(0.1, 0.15, 0.25, 0.3)
	else:
		modal.locked_overlay.visible = false
		if category == "pilot":
			var mat := ShaderMaterial.new()
			mat.shader = HOLOGRAM_SHADER
			mat.set_shader_parameter("rim_color", theme_col)
			var is_valentina: bool = (String(target_id).to_lower() == "valentina")
			mat.set_shader_parameter("bottom_fade_start", 0.78 if is_valentina else 0.88)
			modal.artwork_texture.material = mat
		elif cur.get("is_base", false):
			modal.artwork_texture.material = null
		else:
			CosmeticsManager.apply_skin_to_canvas_item(modal.artwork_texture, cur.get("id", ""), star_level, false)

		if modal.circular_glow:
			modal.circular_glow.modulate = Color(theme_col.r, theme_col.g, theme_col.b, 0.85)

	# Tarjetas Adyacentes (Horizontales)
	var left_idx := (skin_index - 1 + total) % total
	var right_idx := (skin_index + 1) % total
	modal.left_texture.texture = available_skins[left_idx].get("texture", null)
	modal.right_texture.texture = available_skins[right_idx].get("texture", null)

	# Tarjetas de Estrellas (Verticales)
	if modal.top_card and modal.bottom_card:
		modal.top_texture.texture = tex
		modal.bottom_texture.texture = tex
		modal.top_card.modulate.a = 0.6 if star_level > 1 else 0.2
		modal.bottom_card.modulate.a = 0.6 if star_level < 3 else 0.2


func build_dots(dots_container: HBoxContainer, available_skins: Array[Dictionary], current_index: int) -> void:
	if not dots_container:
		return
	for child in dots_container.get_children():
		child.queue_free()

	for i in range(available_skins.size()):
		var dot := Panel.new()
		var is_active := (i == current_index)
		dot.custom_minimum_size = Vector2(20 if is_active else 8, 8)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		if is_active:
			var cur_col: Color = available_skins[i].get("glow_color", Color(0, 0.95, 1.0))
			sb.bg_color = cur_col
			sb.shadow_color = cur_col
			sb.shadow_size = 4
		else:
			sb.bg_color = Color(0.25, 0.35, 0.45, 0.5)
		dot.add_theme_stylebox_override("panel", sb)
		dots_container.add_child(dot)
