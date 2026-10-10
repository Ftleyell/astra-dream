class_name SlotMachineConfig
extends Resource
## Recurso de configuración y balance data-driven para SlotMachineBeacon (Godot 4.7+).

@export_group("Bumper & Physics")
@export var bumper_radius: float = 46.0
@export var bumper_kickback_force: float = 540.0
@export var bumper_nudge_distance: float = 14.0
@export var bump_cooldown: float = 0.28

@export_group("Economy & Uses")
@export var base_spin_cost: int = 50
@export var cost_increment: int = 25
@export var min_uses: int = 3
@export var max_uses: int = 5

@export_group("Slot Reels & Probabilities")
@export var symbols: Array[String] = ["💰", "💣", "🧲", "💖", "⭐"]
@export var jackpot_chance: float = 0.18
@export var pair_chance: float = 0.65
