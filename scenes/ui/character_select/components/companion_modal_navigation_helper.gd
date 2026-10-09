class_name CompanionModalNavigationHelper
extends RefCounted

## CompanionModalNavigationHelper.gd
## Manejador de navegación de teclado, mando y ratón para modales de compañeros (Navegantes y Mascotas):
## - Procesa atajos de teclado (A/D/W/S, flechas, rueda de ratón, Escape, Espacio).
## - Verifica clics fuera de los límites de la ventana (dim overlay) para auto-confirmar o cerrar.
## - Configura trampas de foco en el panel del carrusel CoverFlow.

static func setup_carousel_focus(carousel_panel: PanelContainer) -> void:
	if not carousel_panel:
		return
	carousel_panel.focus_mode = Control.FOCUS_ALL
	carousel_panel.focus_neighbor_left = carousel_panel.get_path()
	carousel_panel.focus_neighbor_right = carousel_panel.get_path()
	carousel_panel.focus_neighbor_top = carousel_panel.get_path()
	carousel_panel.focus_neighbor_bottom = carousel_panel.get_path()
	carousel_panel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func is_click_outside(root_box: Control, event: InputEvent) -> bool:
	if not root_box or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return false
	var mouse_pos: Vector2 = root_box.get_local_mouse_position()
	var bounds: Rect2 = Rect2(Vector2.ZERO, root_box.size)
	return not bounds.has_point(mouse_pos)

static func handle_input(
	event: InputEvent,
	on_cycle_h: Callable,
	on_cycle_v: Callable,
	on_confirm: Callable,
	on_close: Callable
) -> bool:
	# 1. Cancelar / Salir
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		on_close.call()
		return true

	# 2. Confirmar / Seleccionar
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		on_confirm.call()
		return true

	# 3. Navegación Horizontal
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		on_cycle_h.call(-1)
		return true
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		on_cycle_h.call(1)
		return true

	# 4. Navegación Vertical
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		on_cycle_v.call(-1)
		return true
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		on_cycle_v.call(1)
		return true

	# 5. Rueda del ratón
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			on_cycle_v.call(-1)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			on_cycle_v.call(1)
			return true

	return false
