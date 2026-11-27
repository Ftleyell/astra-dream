class_name EnemyArchetypeVisualEntry
extends Resource

## Data-driven visual configuration for a production enemy archetype placeholder
## sharing the Void Scarab 2.5D/3D procedural rig.

@export var enemy_id: StringName = &""
@export var display_label: String = ""
@export_range(0.35, 2.5) var size_multiplier: float = 1.0
@export var use_variant_recolor: bool = false
@export var armor_tint: Color = Color(0.22, 0.22, 0.36, 1.0)
@export var accent_tint: Color = Color(0.68, 0.24, 0.96, 1.0)
@export var energy_tint: Color = Color(0.22, 1.0, 0.56, 1.0)
@export var enable_rainbow_cycle: bool = false
@export var enable_flight_ribbons: bool = false
