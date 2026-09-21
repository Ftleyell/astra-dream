class_name HubInteractable3D
extends Area3D

## HubInteractable3D.gd
## Componente modular 3D para puntos de interacción en el Hub.
## Permite añadir fácilmente nuevos personajes, terminales de armas, forjas de antimateria
## o cualquier otro elemento interactuable arrastrando el nodo a la escena.

signal interacted(interactable: HubInteractable3D, player_node: Node3D)

@export var target_character_id: StringName = &"nova"
@export var interaction_title: String = "Árbol de Habilidades"
@export var prompt_action_text: String = "[E]"
@export var interaction_radius: float = 2.4
@export var prompt_offset_y: float = 1.8

var is_player_in_range: bool = false
var player_ref: Node3D = null

var label_3d: Label3D = null
var collision_shape: CollisionShape3D = null


func _ready() -> void:
	add_to_group("hub_interactables")
	collision_layer = 0
	collision_mask = 2 # Capa del jugador en el Hub

	_setup_collision()
	_setup_label_3d()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _setup_collision() -> void:
	collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = interaction_radius
		collision_shape.shape = sphere
		add_child(collision_shape)
	elif collision_shape.shape is SphereShape3D:
		(collision_shape.shape as SphereShape3D).radius = interaction_radius


func _setup_label_3d() -> void:
	label_3d = get_node_or_null("PromptLabel3D")
	if not label_3d:
		label_3d = Label3D.new()
		label_3d.name = "PromptLabel3D"
		add_child(label_3d)

	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.shaded = false
	label_3d.font_size = 28
	label_3d.outline_size = 8
	label_3d.outline_modulate = Color("#0A0A0E") # Deep Black
	label_3d.modulate = Color("#FF1493") # Hot Pink
	label_3d.position = Vector3(0, prompt_offset_y, 0)
	label_3d.text = "%s %s: %s" % [prompt_action_text, interaction_title, String(target_character_id).capitalize()]
	label_3d.visible = false


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		is_player_in_range = true
		player_ref = body
		if label_3d:
			label_3d.visible = true
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			label_3d.scale = Vector3(0.5, 0.5, 0.5)
			tw.tween_property(label_3d, "scale", Vector3.ONE, 0.2)


func _on_body_exited(body: Node3D) -> void:
	if body == player_ref:
		is_player_in_range = false
		player_ref = null
		if label_3d:
			label_3d.visible = false


func trigger_interaction() -> void:
	interacted.emit(self, player_ref)
