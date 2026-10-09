class_name HubPilotShowcaseController
extends Node

## Controlador de pedestales 3D, VFX de selección, sprites billboarding y personalización de skins para los pilotos del Hangar.

const PedestalVisualPresenterClass = preload("res://scenes/ui/hub/components/pedestal_visual_presenter.gd")

var hub: Node3D = null
var current_pilot_index: int = 0
var sprite_nodes: Array[Sprite3D] = []
var pilot_vfx_data: Array[Dictionary] = []
var interactable_nodes: Array[HubInteractable3D] = []
var _pilot_tweens: Array[Tween] = []

func setup(p_hub: Node3D) -> void:
	hub = p_hub

func build_pilot_pedestals_and_vfx(roster: Array[Dictionary]) -> void:
	pilot_vfx_data = PedestalVisualPresenterClass.build_pedestals(hub, roster)

func collect_and_verify_sprites(roster: Array[Dictionary]) -> void:
	if not is_instance_valid(hub):
		return
	sprite_nodes.clear()
	var roster_group := hub.get_node_or_null("RosterCutouts")
	if not roster_group:
		roster_group = Node3D.new()
		roster_group.name = "RosterCutouts"
		hub.add_child(roster_group)

	for i in range(roster.size()):
		var char_data: Dictionary = roster[i]
		var char_id: String = String(char_data["id"])
		var sprite_name := "Cutout_" + char_id.capitalize()
		var sprite: Sprite3D = roster_group.get_node_or_null(sprite_name)
		if not sprite:
			sprite = Sprite3D.new()
			sprite.name = sprite_name
			roster_group.add_child(sprite)

		var old_shadow := roster_group.get_node_or_null("Shadow_" + char_id.capitalize())
		if old_shadow:
			old_shadow.queue_free()

		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		sprite.position = char_data["pedestal_pos"]

		var is_right_side: bool = char_data["pedestal_pos"].x > 0.0
		var fullbody_tex := ("res://assets/characters/fullbody/fullbody_%s_flipped.png" % char_id) if is_right_side else ("res://assets/characters/fullbody/fullbody_%s.png" % char_id)
		if ResourceLoader.exists(fullbody_tex):
			sprite.texture = load(fullbody_tex)
			sprite.pixel_size = 0.0013
			sprite.offset = Vector2(0, 800)
		else:
			var portrait_tex := "res://assets/portraits/portrait_%s.png" % char_id
			if ResourceLoader.exists(portrait_tex):
				sprite.texture = load(portrait_tex)
				sprite.pixel_size = 0.005
				sprite.offset = Vector2(0, 256)

		var is_unlocked := SaveManager.is_character_unlocked(char_data["id"])
		sprite.visible = is_unlocked
		if is_unlocked:
			PedestalVisualPresenterClass.apply_skin_to_sprite(sprite, char_id, is_right_side)

		var platform_ped: Node3D = hub.get_node_or_null("PilotPedestals/Pedestal_" + char_id.capitalize())
		if platform_ped:
			platform_ped.visible = is_unlocked
		var old_ped: Node3D = hub.get_node_or_null("Pedestals/Pedestal_" + char_id.capitalize())
		if old_ped:
			old_ped.visible = is_unlocked

		sprite_nodes.append(sprite)

func setup_interactables(roster: Array[Dictionary], callback: Callable) -> void:
	if not is_instance_valid(hub):
		return
	var roster_group := hub.get_node_or_null("RosterCutouts")
	if not roster_group:
		return

	interactable_nodes.clear()

	for i in range(roster.size()):
		var char_data: Dictionary = roster[i]
		var cid: StringName = char_data["id"]
		var is_unlocked := SaveManager.is_character_unlocked(cid)
		var interact_name := "Interactable_" + String(cid).capitalize()
		var inter: Area3D = roster_group.get_node_or_null(interact_name)
		if not inter:
			var inter_script = load("res://scenes/ui/hub/hub_interactable_3d.gd")
			inter = inter_script.new()
			inter.name = interact_name
			inter.set("target_character_id", cid)
			inter.set("interaction_title", "Árbol de Habilidades")
			inter.position = char_data["pedestal_pos"]
			roster_group.add_child(inter)

		inter.visible = is_unlocked
		inter.monitoring = is_unlocked
		inter.monitorable = is_unlocked

		if inter is HubInteractable3D:
			interactable_nodes.append(inter as HubInteractable3D)

		if inter and not inter.interacted.is_connected(callback):
			inter.interacted.connect(callback)

func update_interactable_prompts(roster: Array[Dictionary], active_index: int) -> void:
	current_pilot_index = active_index
	for i in range(interactable_nodes.size()):
		var inter: HubInteractable3D = interactable_nodes[i]
		if not is_instance_valid(inter) or not is_instance_valid(inter.label_3d):
			continue
		var char_data: Dictionary = roster[i]
		var cname: String = String(char_data["name"]).capitalize()
		if i == current_pilot_index:
			inter.label_3d.text = "[E] Árbol de Habilidades: %s [ACTIVA]" % cname
			inter.label_3d.modulate = char_data["color"]
		else:
			inter.label_3d.text = "[E] Seleccionar a %s" % cname
			inter.label_3d.modulate = Color(0.85, 0.88, 0.95, 0.9)

func refresh_pedestal_skins(roster: Array[Dictionary]) -> void:
	for i in range(min(roster.size(), sprite_nodes.size())):
		var char_data: Dictionary = roster[i]
		var cid: String = String(char_data["id"])
		var sprite := sprite_nodes[i]
		if not is_instance_valid(sprite):
			continue
		var is_unlocked := SaveManager.is_character_unlocked(char_data["id"])
		sprite.visible = is_unlocked
		if not is_unlocked:
			continue
		var is_right_side: bool = char_data.get("pedestal_pos", Vector3.ZERO).x > 0.0
		PedestalVisualPresenterClass.apply_skin_to_sprite(sprite, cid, is_right_side)

func select_pilot_visuals(index: int, roster: Array[Dictionary]) -> void:
	current_pilot_index = index
	clean_tweens()

	for i in range(sprite_nodes.size()):
		var sp := sprite_nodes[i]
		if not is_instance_valid(sp):
			continue
		var tw := hub.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pilot_tweens.append(tw)
		if i == index:
			tw.tween_property(sp, "scale", Vector3(1.2, 1.2, 1.2), 0.35)
			sp.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			tw.tween_property(sp, "scale", Vector3.ONE, 0.25)
			sp.modulate = Color(0.75, 0.75, 0.85, 0.85)

	# Actualizar VFX de pedestales 3D
	for i in range(pilot_vfx_data.size()):
		var vfx: Dictionary = pilot_vfx_data[i]
		var beam: MeshInstance3D = vfx.get("holo_beam")
		var rim_mat: StandardMaterial3D = vfx.get("rim_mat")
		var rot_ring: MeshInstance3D = vfx.get("rotator_ring")
		var light: OmniLight3D = vfx.get("omni_light")
		var badge: Label3D = vfx.get("floating_badge")

		if i == index:
			if beam and is_instance_valid(beam):
				beam.visible = true
				beam.scale = Vector3(1.0, 0.0, 1.0)
				var tw_beam := hub.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_beam.tween_property(beam, "scale:y", 1.0, 0.35)
				_pilot_tweens.append(tw_beam)

			if rim_mat:
				var tw_rim := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_rim.tween_property(rim_mat, "emission_energy_multiplier", 3.2, 0.35)
				_pilot_tweens.append(tw_rim)

			if light and is_instance_valid(light):
				light.visible = true
				var tw_light := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_light.tween_property(light, "light_energy", 2.6, 0.35)
				_pilot_tweens.append(tw_light)

			if rot_ring and is_instance_valid(rot_ring):
				rot_ring.visible = true

			if badge and is_instance_valid(badge):
				badge.visible = true
				badge.scale = Vector3(0.2, 0.2, 0.2)
				var tw_badge := hub.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_badge.tween_property(badge, "scale", Vector3.ONE, 0.3)
				_pilot_tweens.append(tw_badge)
		else:
			if beam and is_instance_valid(beam) and beam.visible:
				var tw_beam_off := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_beam_off.tween_property(beam, "scale:y", 0.0, 0.2)
				tw_beam_off.tween_callback(func(): if is_instance_valid(beam): beam.visible = false)
				_pilot_tweens.append(tw_beam_off)

			if rim_mat:
				var tw_rim_off := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_rim_off.tween_property(rim_mat, "emission_energy_multiplier", 0.4, 0.25)
				_pilot_tweens.append(tw_rim_off)

			if light and is_instance_valid(light) and light.visible:
				var tw_light_off := hub.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw_light_off.tween_property(light, "light_energy", 0.0, 0.25)
				tw_light_off.tween_callback(func(): if is_instance_valid(light): light.visible = false)
				_pilot_tweens.append(tw_light_off)

			if rot_ring and is_instance_valid(rot_ring):
				rot_ring.visible = false

			if badge and is_instance_valid(badge):
				badge.visible = false

	update_interactable_prompts(roster, index)

func process_vfx(delta: float, idle_time: float) -> void:
	if current_pilot_index >= 0 and current_pilot_index < pilot_vfx_data.size():
		var active_vfx: Dictionary = pilot_vfx_data[current_pilot_index]
		var rot_ring: MeshInstance3D = active_vfx.get("rotator_ring")
		if rot_ring and is_instance_valid(rot_ring) and rot_ring.visible:
			rot_ring.rotation.y += delta * 2.2
		var beam: MeshInstance3D = active_vfx.get("holo_beam")
		if beam and is_instance_valid(beam) and beam.visible:
			var pulse: float = 1.0 + sin(idle_time * 3.5) * 0.04
			beam.scale.x = pulse
			beam.scale.z = pulse
		var badge: Label3D = active_vfx.get("floating_badge")
		if badge and is_instance_valid(badge) and badge.visible:
			badge.position.y = 2.8 + sin(idle_time * 2.8) * 0.06

func clean_tweens() -> void:
	for tw in _pilot_tweens:
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
	_pilot_tweens.clear()

func build_pilot_selector_buttons(container: HBoxContainer, roster: Array[Dictionary], select_callback: Callable, card: PanelContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
	for i in range(roster.size()):
		var data: Dictionary = roster[i]
		if not SaveManager.is_character_unlocked(data["id"]):
			continue
		var btn := Button.new()
		btn.text = String(data["name"]).substr(0, 3).to_upper()
		btn.custom_minimum_size = Vector2(52, 34)
		btn.add_theme_font_size_override("font_size", 11)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#0A0A0E")
		sb.border_width_left = 3
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(data["color"])
		sb.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", sb)
		btn.pressed.connect(func():
			select_callback.call(i, true)
			if card:
				card.visible = true
		)
		container.add_child(btn)

