class_name SatelliteShop
extends CanvasLayer

signal item_purchased(item: ItemData, cost: int)
signal shop_closed()

@export var available_items_pool: Array[ItemData] = []

var current_credits: int = 100
var reroll_cost: int = 15
var current_offered_items: Array[ItemData] = []

@onready var panel: Panel = $ShopPanel
@onready var items_container: HBoxContainer = $ShopPanel/VBoxContainer/ItemsContainer
@onready var credits_label: Label = $ShopPanel/VBoxContainer/TopBar/CreditsLabel
@onready var reroll_btn: Button = $ShopPanel/VBoxContainer/BottomBar/RerollButton
@onready var close_btn: Button = $ShopPanel/VBoxContainer/BottomBar/CloseButton

func _ready() -> void:
	hide()
	close_btn.pressed.connect(close_shop)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	if available_items_pool.is_empty():
		_generate_default_shop_items()

func _generate_default_shop_items() -> void:
	var item_defs = [
		{"id": &"plasma_coil", "name": "Bobina de Plasma", "desc": "15% prob. al golpear de electrocutar enemigos cercanos.", "cost": 40, "rarity": Enums.Rarity.COMMON},
		{"id": &"overcharged_core", "name": "Núcleo Sobrecargado", "desc": "+25% daño de disparos activos manuales.", "cost": 50, "rarity": Enums.Rarity.UNCOMMON},
		{"id": &"kinetic_booster", "name": "Propulsor Cinético", "desc": "El Dash viaja un 30% más lejos e inflige daño al cruzar balas.", "cost": 60, "rarity": Enums.Rarity.RARE},
		{"id": &"void_prism", "name": "Prisma del Vacío", "desc": "Los proyectiles críticos generan una micro-singularidad.", "cost": 85, "rarity": Enums.Rarity.EPIC}
	]
	for def in item_defs:
		var item := ItemData.new()
		item.item_id = def["id"]
		item.item_name = def["name"]
		item.description = def["desc"]
		item.rarity = def["rarity"]
		item.set_meta("cost", def["cost"])
		available_items_pool.append(item)

func open_shop(credits: int) -> void:
	current_credits = credits
	_update_credits_display()
	_roll_shop_items()
	show()

func close_shop() -> void:
	hide()
	shop_closed.emit()

func _update_credits_display() -> void:
	credits_label.text = "Créditos: %d" % current_credits
	reroll_btn.text = "Re-roll (%d C)" % reroll_cost

func _roll_shop_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	current_offered_items.clear()
	var pool_copy := available_items_pool.duplicate()
	pool_copy.shuffle()

	var count := mini(3, pool_copy.size())
	for i in range(count):
		var item: ItemData = pool_copy[i]
		current_offered_items.append(item)
		_create_item_card_ui(item)

func _create_item_card_ui(item: ItemData) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 260)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var cost: int = item.get_meta("cost", 30)
	var buy_btn := Button.new()
	buy_btn.text = "Comprar (%d C)" % cost

	buy_btn.pressed.connect(func():
		if current_credits >= cost:
			current_credits -= cost
			_update_credits_display()
			buy_btn.disabled = true
			buy_btn.text = "¡Adquirido!"
			item_purchased.emit(item, cost)
	)

	vbox.add_child(name_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(buy_btn)
	card.add_child(vbox)
	items_container.add_child(card)

func _on_reroll_pressed() -> void:
	if current_credits >= reroll_cost:
		current_credits -= reroll_cost
		reroll_cost += 10
		_update_credits_display()
		_roll_shop_items()
