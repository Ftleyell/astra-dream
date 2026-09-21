class_name WeaponData
extends Resource

@export_group("Identity")
@export var weapon_id: StringName = &"weapon_default"
@export var weapon_name: String = "Arma Base"
@export var icon: Texture2D
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var tags: Array[StringName] = []

@export_group("Base Combat Stats")
@export var base_damage: float = 20.0
@export var base_cooldown: float = 0.5
@export var proc_coefficient: float = 1.0

@export_group("Active Layer (Manual Aim / Mouse Click)")
@export var active_projectile_scene: PackedScene
@export var active_burst_count: int = 1
@export var active_spread_deg: float = 12.0

@export_group("Passive Layer (Autonomous Auto-Fire)")
@export var passive_interval: float = 2.0
@export var passive_search_radius: float = 300.0
@export var passive_target_mode: Enums.TargetMode = Enums.TargetMode.NEAREST
@export var passive_sub_attack_scene: PackedScene

@export_group("Projectile Scaling")
@export var scales_with_projectile_count: bool = true
@export var active_scales_with_projectiles: bool = true
@export var passive_scales_with_projectiles: bool = true
