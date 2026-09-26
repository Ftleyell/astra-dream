class_name WeaponData
extends Resource

const STYLIZED_WEAPON_NAMES: Dictionary = {
	"crescent_blade": "Sable Astral 'Crescent Slash'",
	"crescent_slash": "Sable Astral 'Crescent Slash'",
	"crescent_cyclone": "Sable Astral 'Crescent Slash'",
	"rail_launcher": "Cañón de Riel 'Vanguard Mk.I'",
	"hive_cannon": "Cañón de Enjambre 'Colmena-9'",
	"singularity_pulsar": "Púlsar Gravitatorio 'Singularity'",
	"sniper_rifle": "Fusil de Iones 'Ojo de Águila'",
	"tesla_arc": "Proyector Tesla 'Descarga Sonora'",
	"titan_shotgun": "Escopeta Sísmica 'Ruptura Titán'",
	"cluster_submunition": "Lanzador de Racimo 'Clúster'",
	"dimensional_blade": "Cuchilla Dimensional Astra",
	"nova_flak": "Batería Antiaérea 'Nova-Flak'",
	"solar_beam": "Haz Solar Orbital 'Helios'"
}

static func get_stylized_name_for_id(id_or_name: String) -> String:
	var clean := id_or_name.to_lower().strip_edges()
	if STYLIZED_WEAPON_NAMES.has(clean):
		return STYLIZED_WEAPON_NAMES[clean]
	if clean.contains(" ") and not clean.contains("_"):
		return id_or_name
	return id_or_name.replace("_", " ").capitalize()

func get_display_name() -> String:
	var s_id := String(weapon_id).to_lower().strip_edges()
	if STYLIZED_WEAPON_NAMES.has(s_id):
		return STYLIZED_WEAPON_NAMES[s_id]
	if not weapon_name.is_empty() and weapon_name != "Arma Base":
		return weapon_name
	return get_stylized_name_for_id(s_id)

var name: String:
	get:
		return get_display_name()

@export_group("Identity")
@export var weapon_id: StringName = &"weapon_default"
@export var weapon_name: String = "Arma Base"
@export_multiline var description: String = "Descripción del arma."
@export var icon: Texture2D
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var tags: Array[StringName] = []
@export var cost: int = 50

@export_group("Base Combat Stats")
@export var base_damage: float = 20.0
@export var base_cooldown: float = 0.5
@export var proc_coefficient: float = 1.0

@export_group("Upgrade Progression (Per Level)")
@export var damage_growth_per_level: float = 0.25 # +25% de daño por nivel
@export var cooldown_reduction_per_level: float = 0.08 # -8% de cooldown por nivel
@export var passive_interval_reduction_per_level: float = 0.08 # -8% de intervalo pasivo por nivel

@export_group("Active Layer (Manual Aim / Mouse Click)")
@export var active_projectile_scene: PackedScene
@export var active_burst_count: int = 1
@export var active_spread_deg: float = 12.0
@export var active_behavior_type: StringName = &"laser" # "laser", "projectile", "shotgun", "singularity", "chain", "cluster"

@export_group("Passive Layer (Autonomous Auto-Fire)")
@export var passive_interval: float = 2.0
@export var passive_search_radius: float = 520.0
@export var passive_target_mode: Enums.TargetMode = Enums.TargetMode.NEAREST
@export var passive_sub_attack_scene: PackedScene
@export var passive_behavior_type: StringName = &"missile" # "missile", "orbital", "shockwave", "chain_pulse", "mortar", "boomerang"

@export_group("Projectile Scaling")
@export var scales_with_projectile_count: bool = true
@export var active_scales_with_projectiles: bool = true
@export var passive_scales_with_projectiles: bool = true
