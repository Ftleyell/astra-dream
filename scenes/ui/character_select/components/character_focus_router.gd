class_name CharacterFocusRouter
extends RefCounted

## CharacterFocusRouter.gd
## Enrutador desacoplado de navegación y malla de foco UI para CharacterSelectUI.
## Establece los vecinos de foco (gamepad / teclado) y restaura el foco tras el cierre de modales.

var _last_focused_control: Control = null


func save_focus(viewport: Viewport) -> void:
	if viewport:
		_last_focused_control = viewport.gui_get_focus_owner()


func set_last_focused(control: Control) -> void:
	_last_focused_control = control


func get_last_focused() -> Control:
	return _last_focused_control


func has_valid_saved_focus() -> bool:
	return _last_focused_control != null and is_instance_valid(_last_focused_control) and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree()


func get_saved_focus() -> Control:
	return _last_focused_control


func restore_focus(pilot_button: Button, orbital_terminal: Control) -> void:
	if _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control != pilot_button and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		_last_focused_control.grab_focus()
	elif orbital_terminal and orbital_terminal.is_visible_in_tree():
		orbital_terminal.grab_focus()


func restore_companion_modal_focus(companion_button: Button, orbital_terminal: Control) -> void:
	var target_focus: Control = null
	if is_instance_valid(companion_button) and companion_button.is_visible_in_tree():
		target_focus = companion_button
	elif _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		target_focus = _last_focused_control
	elif orbital_terminal and orbital_terminal.is_visible_in_tree():
		target_focus = orbital_terminal

	if target_focus:
		target_focus.call_deferred("grab_focus")


func setup_focus_mesh(
	back_button: Button,
	ship_button: Button,
	weapon_button: Button,
	pet_button: Button,
	navigator_button: Button,
	expand_talents_btn: Button,
	arsenal_banlist_btn: Button,
	tomes_pool_btn: Button,
	loadout_button: Button,
	speed_1x_btn: Button,
	speed_2x_btn: Button,
	speed_4x_btn: Button,
	pilot_skin_btn: Button,
	orbital_terminal: Control
) -> void:
	# 1. Back button
	if back_button:
		back_button.focus_neighbor_top = orbital_terminal.get_path() if orbital_terminal else NodePath()
		back_button.focus_neighbor_bottom = ship_button.get_path() if ship_button else NodePath()
		back_button.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()

	# 2. Equipment row (Ship & Weapon)
	if ship_button:
		ship_button.focus_neighbor_top = back_button.get_path() if back_button else NodePath()
		ship_button.focus_neighbor_right = weapon_button.get_path() if weapon_button else NodePath()
		ship_button.focus_neighbor_bottom = pet_button.get_path() if pet_button else NodePath()

	if weapon_button:
		weapon_button.focus_neighbor_top = back_button.get_path() if back_button else NodePath()
		weapon_button.focus_neighbor_left = ship_button.get_path() if ship_button else NodePath()
		weapon_button.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		weapon_button.focus_neighbor_bottom = pet_button.get_path() if pet_button else NodePath()

	# 3. Companions (Pet & Navigator)
	if pet_button:
		pet_button.focus_neighbor_top = ship_button.get_path() if ship_button else NodePath()
		pet_button.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		pet_button.focus_neighbor_bottom = navigator_button.get_path() if navigator_button else NodePath()

	if navigator_button:
		navigator_button.focus_neighbor_top = pet_button.get_path() if pet_button else NodePath()
		navigator_button.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		navigator_button.focus_neighbor_bottom = expand_talents_btn.get_path() if expand_talents_btn else NodePath()

	# 4. Talents and Tomes / Arsenal
	var eff_pool_btn: Control = arsenal_banlist_btn if (arsenal_banlist_btn and arsenal_banlist_btn.is_visible_in_tree()) else tomes_pool_btn
	var eff_pool_path: NodePath = eff_pool_btn.get_path() if eff_pool_btn else NodePath()

	if expand_talents_btn:
		expand_talents_btn.focus_neighbor_top = navigator_button.get_path() if navigator_button else NodePath()
		expand_talents_btn.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		expand_talents_btn.focus_neighbor_bottom = eff_pool_path

	if arsenal_banlist_btn:
		arsenal_banlist_btn.focus_neighbor_top = expand_talents_btn.get_path() if expand_talents_btn else NodePath()
		arsenal_banlist_btn.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		arsenal_banlist_btn.focus_neighbor_bottom = speed_1x_btn.get_path() if speed_1x_btn else NodePath()

	if tomes_pool_btn:
		tomes_pool_btn.focus_neighbor_top = expand_talents_btn.get_path() if expand_talents_btn else NodePath()
		tomes_pool_btn.focus_neighbor_right = loadout_button.get_path() if loadout_button else (pilot_skin_btn.get_path() if pilot_skin_btn else NodePath())
		tomes_pool_btn.focus_neighbor_bottom = speed_1x_btn.get_path() if speed_1x_btn else NodePath()

	if loadout_button:
		loadout_button.focus_neighbor_top = expand_talents_btn.get_path() if expand_talents_btn else NodePath()
		loadout_button.focus_neighbor_left = tomes_pool_btn.get_path() if tomes_pool_btn else NodePath()
		loadout_button.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		loadout_button.focus_neighbor_bottom = speed_1x_btn.get_path() if speed_1x_btn else NodePath()

	# 5. Speed Buttons (1x, 2x, 4x)
	var eff_launch: Control = orbital_terminal if (orbital_terminal and orbital_terminal.is_visible_in_tree()) else null
	var eff_launch_path: NodePath = eff_launch.get_path() if eff_launch else NodePath()

	if speed_1x_btn:
		speed_1x_btn.focus_neighbor_top = eff_pool_path
		speed_1x_btn.focus_neighbor_right = speed_2x_btn.get_path() if speed_2x_btn else NodePath()
		speed_1x_btn.focus_neighbor_bottom = eff_launch_path

	if speed_2x_btn:
		speed_2x_btn.focus_neighbor_top = eff_pool_path
		speed_2x_btn.focus_neighbor_left = speed_1x_btn.get_path() if speed_1x_btn else NodePath()
		speed_2x_btn.focus_neighbor_right = speed_4x_btn.get_path() if speed_4x_btn else NodePath()
		speed_2x_btn.focus_neighbor_bottom = eff_launch_path

	if speed_4x_btn:
		speed_4x_btn.focus_neighbor_top = eff_pool_path
		speed_4x_btn.focus_neighbor_left = speed_2x_btn.get_path() if speed_2x_btn else NodePath()
		speed_4x_btn.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		speed_4x_btn.focus_neighbor_bottom = eff_launch_path

	# 6. Launch Button (Orbital Terminal)
	if eff_launch:
		eff_launch.focus_neighbor_top = speed_1x_btn.get_path() if speed_1x_btn else NodePath()
		eff_launch.focus_neighbor_right = pilot_skin_btn.get_path() if pilot_skin_btn else NodePath()
		eff_launch.focus_neighbor_bottom = back_button.get_path() if back_button else NodePath()
