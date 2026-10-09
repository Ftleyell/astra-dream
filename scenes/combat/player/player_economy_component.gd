class_name PlayerEconomyComponent
extends Node

## PlayerEconomyComponent.gd
## Componente de gestión de experiencia, subidas de nivel y economía activa/persistente:
## - Créditos de la run (con modificadores de botín y maldición).
## - Biomasa de la run y persistencia en SaveManager.
## - Materia Oscura de la run y persistencia en SaveManager.
## - Experiencia acumulada, curva de progresión por nivel y conversión alquímica.

signal credits_changed(amount: int)
signal biomass_changed(amount: int, total_persistent: int)
signal dark_matter_changed(amount: int, total_persistent: int)
signal exp_changed(current: float, max_val: float, level: int)
signal level_up_requested(level: int)

var run_credits: int = 40
var run_biomass: int = 0
var run_dark_matter: int = 0

var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next: float = 40.0


func initialize_economy() -> void:
	credits_changed.emit(run_credits)
	var persistent_bio: int = SaveManager.get_biomass() if SaveManager else 0
	biomass_changed.emit(run_biomass, persistent_bio)
	var persistent_dm: int = SaveManager.get_dark_matter() if SaveManager else 0
	dark_matter_changed.emit(run_dark_matter, persistent_dm)
	exp_changed.emit(current_exp, exp_to_next, current_level)


func add_credits(amount: int, stats: CharacterStats) -> void:
	if amount <= 0:
		return
	var mult: float = stats.get_stat(&"credits_multiplier") if stats else 1.0
	var curse: float = stats.get_stat(&"curse") if stats else 0.0
	var curse_bonus: float = maxf(0.0, 1.0 + (curse * 0.01))
	var effective: int = int(round(float(amount) * maxf(0.1, mult) * curse_bonus))
	run_credits += effective
	credits_changed.emit(run_credits)


func add_biomass(amount: int, stats: CharacterStats) -> void:
	if amount <= 0:
		return
	var mult: float = stats.get_stat(&"biomass_multiplier") if stats else 1.0
	var effective: int = int(round(float(amount) * maxf(0.1, mult)))
	run_biomass += effective
	var total_persistent: int = SaveManager.add_biomass(effective) if SaveManager else 0
	biomass_changed.emit(run_biomass, total_persistent)


func add_dark_matter(amount: int) -> void:
	if amount <= 0:
		return
	run_dark_matter += amount
	var total_persistent: int = SaveManager.add_dark_matter(amount) if SaveManager else 0
	dark_matter_changed.emit(run_dark_matter, total_persistent)


func add_exp(amount: float, stats: CharacterStats, inventory: InventoryComponent) -> void:
	var exp_mult: float = stats.get_stat(&"exp_multiplier") if stats else 1.0
	var effective_amount: float = amount * maxf(0.1, exp_mult)
	if inventory and inventory.has_method("get_item_count") and inventory.get_item_count(&"alchemical_converter") > 0:
		var cred_gain: int = maxi(1, int(round(effective_amount * 0.15)))
		add_credits(cred_gain, stats)
	current_exp += effective_amount
	while current_exp >= exp_to_next:
		current_exp -= exp_to_next
		current_level += 1
		exp_to_next *= 1.35
		level_up_requested.emit(current_level)
	exp_changed.emit(current_exp, exp_to_next, current_level)
