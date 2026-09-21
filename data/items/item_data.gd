class_name ItemData
extends Resource

@export_group("Identity")
@export var item_id: StringName = &"item_default"
@export var item_name: String = "Item Base"
@export_multiline var description: String = "Descripción del ítem."
@export var icon: Texture2D
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var tags: Array[StringName] = []
@export var cost: int = 35

@export_group("Stat Scaling")
@export var stat_name: StringName = &""
@export var stat_value: float = 0.0
@export var is_percentage: bool = false

@export_group("Stacking")
@export var max_stacks: int = 99
@export var stack_type: Enums.StackType = Enums.StackType.LINEAR
@export var hyperbolic_factor: float = 0.15

@export_group("Behaviors")
@export var effects: Array[ItemEffect] = []
