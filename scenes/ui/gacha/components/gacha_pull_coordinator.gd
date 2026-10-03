class_name GachaPullCoordinator
extends RefCounted

## GachaPullCoordinator.gd
## Controlador dedicado a la lógica matemática y de transacciones del Gacha:
## - Comprobación de saldo de tokens y gasto atómico en SaveManager.
## - Seguimiento y reinicio de Pity por banner.
## - Invocación a CosmeticsManager y resolución de mejoras de estrellas.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")

func execute_pulls(count: int, banner_id: String) -> Array[Dictionary]:
	var current_tokens: int = SaveManager.get_gacha_tokens()
	if current_tokens < count:
		return []

	# Descontar tokens
	SaveManager.spend_gacha_tokens(count)

	var pulled_results: Array[Dictionary] = []
	for i: int in range(count):
		# Comprobar si esta tirada activa el Pity (10 tiradas acumuladas)
		var current_pity: int = SaveManager.get_banner_pity(banner_id)
		var is_pity: bool = (current_pity + 1 >= 10)

		var raw_skin: Dictionary = CosmeticsManager.roll_banner_skin(banner_id, is_pity)
		if raw_skin.is_empty():
			continue

		var skin_id: String = raw_skin.get("id", "")
		var upgrade_res: Dictionary = SaveManager.unlock_or_upgrade_skin(skin_id)

		# Actualizar o reiniciar contador de pity del banner
		if is_pity or str(raw_skin.get("rarity", "")) == "epic":
			SaveManager.reset_banner_pity(banner_id)
		else:
			SaveManager.increment_banner_pity(banner_id, 1)

		pulled_results.append({
			"skin_data": raw_skin,
			"upgrade_data": upgrade_res
		})

	return pulled_results
