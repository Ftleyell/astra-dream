class_name CombatPlayerFeedbackCoordinator
extends RefCounted

## Coordinador desacoplado de reacciones sensoriales y feedback del jugador.
## Gestiona trauma de cámara (screen shake) por daño/bombas y enrutamiento
## de eventos de muerte y estado hacia el controlador de fin de partida.

var main_game: MainGame = null
var camera: Camera2D = null
var end_run_controller: RefCounted = null
var _last_player_hp: float = 0.0

func setup(p_main_game: MainGame, p_camera: Camera2D, p_end_run: RefCounted) -> void:
	main_game = p_main_game
	camera = p_camera
	end_run_controller = p_end_run

	if is_instance_valid(main_game) and is_instance_valid(main_game.player):
		_last_player_hp = main_game.player.current_health
		_connect_player_signals(main_game.player)

func _connect_player_signals(player: Player) -> void:
	if not player.bomb_used.is_connected(on_player_bomb_used):
		player.bomb_used.connect(on_player_bomb_used)
	if not player.health_changed.is_connected(on_player_health_changed):
		player.health_changed.connect(on_player_health_changed)
	if not player.player_died.is_connected(on_player_died):
		player.player_died.connect(on_player_died)

func on_player_bomb_used(_remaining: int) -> void:
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.6)

func on_player_health_changed(current: float, _max_val: float) -> void:
	if current < _last_player_hp:
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(0.4)
	_last_player_hp = current

func on_player_died() -> void:
	if end_run_controller and end_run_controller.has_method("on_player_died"):
		end_run_controller.on_player_died()
