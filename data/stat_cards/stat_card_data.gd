class_name StatCardData
extends Resource

@export var card_id: StringName = &"card_default"
@export var title: String = "+10% Daño"
@export var icon: Texture2D
@export var tier: Enums.Tier = Enums.Tier.TIER_1
@export var target_stat: StringName = &"base_damage"
@export var modifier_value: float = 0.10
@export var is_percentage: bool = true
@export var base_weight: float = 100.0
@export var tags: Array[StringName] = [&"damage", &"offense"]
