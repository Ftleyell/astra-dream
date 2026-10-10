class_name HighscoresModal
extends CanvasLayer

signal closed()

@onready var panel: Panel = $Panel
@onready var vbox_root: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/HeaderHBox/TitleLabel
@onready var table_header: HBoxContainer = $Panel/VBoxContainer/TableHeader
@onready var scroll_container: ScrollContainer = $Panel/VBoxContainer/ScrollContainer
@onready var list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ListContainer
@onready var close_button: Button = $Panel/VBoxContainer/BottomBar/CloseButton

var current_tab: int:
	get:
		return _tab_controller.current_tab if _tab_controller else 0
	set(val):
		if _tab_controller:
			_tab_controller.current_tab = val

var career_container: ScrollContainer = null
var tab_career_btn: Button = null
var tab_hof_btn: Button = null
var _tab_controller: HighscoresTabController = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	hide()
	_setup_tab_bar()
	_setup_career_container()
	_setup_controller()
	if close_button:
		UIFocusHelper.apply_cyber_focus(close_button)
		close_button.pressed.connect(close_highscores)

func _setup_tab_bar() -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBarHBox"
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 16)

	tab_career_btn = Button.new()
	tab_career_btn.text = "  [1] HOJA DE SERVICIO Y CARRERA  "
	tab_career_btn.custom_minimum_size = Vector2(280, 42)
	UIFocusHelper.apply_cyber_focus(tab_career_btn)

	tab_hof_btn = Button.new()
	tab_hof_btn.text = "  [2] SALÓN DE LA FAMA (TOP 10)  "
	tab_hof_btn.custom_minimum_size = Vector2(280, 42)
	UIFocusHelper.apply_cyber_focus(tab_hof_btn)

	tab_bar.add_child(tab_career_btn)
	tab_bar.add_child(tab_hof_btn)

	# Insertar la barra de tabs justo debajo del HeaderHBox (índice 1)
	if vbox_root:
		vbox_root.add_child(tab_bar)
		vbox_root.move_child(tab_bar, 1)

func _setup_career_container() -> void:
	career_container = ScrollContainer.new()
	career_container.name = "CareerScrollContainer"
	career_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	career_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if vbox_root:
		vbox_root.add_child(career_container)
		var target_idx: int = scroll_container.get_index() if scroll_container else 4
		vbox_root.move_child(career_container, target_idx)

func _setup_controller() -> void:
	_tab_controller = HighscoresTabController.new()
	_tab_controller.setup(
		title_label,
		table_header,
		scroll_container,
		career_container,
		list_container,
		tab_career_btn,
		tab_hof_btn
	)

func open_highscores() -> void:
	if _tab_controller:
		_tab_controller.switch_tab(_tab_controller.current_tab, false)
	show()
	if tab_career_btn and current_tab == 0:
		tab_career_btn.grab_focus()
	elif tab_hof_btn and current_tab == 1:
		tab_hof_btn.grab_focus()
	elif close_button:
		close_button.grab_focus()

func open_career() -> void:
	if _tab_controller:
		_tab_controller.current_tab = 0
	open_highscores()

func close_highscores() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close_highscores()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			if _tab_controller:
				_tab_controller.switch_tab(0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			if _tab_controller:
				_tab_controller.switch_tab(1)
			get_viewport().set_input_as_handled()
