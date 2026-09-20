class_name CharacterData
extends Resource

@export_group("Identity")
@export var character_id: StringName = &"survivor_default"
@export var display_name: String = "Heroína Base"
@export_multiline var description: String = "Descripción del personaje."
@export var portrait_icon: Texture2D

@export_group("Base Attributes")
@export var max_health: float = 100.0
@export var health_regen: float = 0.5
@export var move_speed: float = 320.0
@export var armor: float = 0.0
@export var base_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var crit_chance: float = 0.05
@export var crit_damage: float = 1.5
@export var luck: float = 1.0
@export var pickup_radius: float = 100.0

@export_group("Loadout")
@export var starting_weapon: WeaponData

@export_group("Megabonk Banlist Constraints")
@export var banned_tags: Array[StringName] = []
@export var inherent_item_banlist: Array[StringName] = []
