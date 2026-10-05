class_name TomeData
extends Resource

@export_group("Identity")
@export var tome_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var tags: Array[StringName] = []

@export_group("Stats Scaling")
@export var stat_name: StringName = &""
@export var stat_value_per_level: float = 0.0
@export var is_percentage: bool = false
@export var modifier_type: Enums.ModifierType = Enums.ModifierType.FLAT
@export var max_level: int = 5
@export var base_unlocked: bool = true

func get_effective_modifier_type() -> Enums.ModifierType:
	if modifier_type == Enums.ModifierType.FLAT and is_percentage:
		return Enums.ModifierType.ADDITIVE_PERCENT
	return modifier_type

func get_bonus_description(level: int) -> String:
	var total_val: float = stat_value_per_level * float(level)
	var sign_str: String = "+" if total_val >= 0.0 else ""
	var val_str: String = "%.0f%%" % [total_val * 100.0] if is_percentage else "%.1f" % [total_val]
	if not is_percentage and is_equal_approx(total_val, roundf(total_val)):
		val_str = "%d" % [int(total_val)]
	return "%s%s" % [sign_str, val_str]
