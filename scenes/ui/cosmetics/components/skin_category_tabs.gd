class_name SkinCategoryTabs
extends RefCounted

## SkinCategoryTabs.gd
## Controlador de pestañas de categorías para SkinSelectionModal.
## Gestiona las pestañas (Piloto, Nave, Arma, Mascota, Navegadora), navegación Q/E y estilos.

var tabs_container: HBoxContainer = null
var tab_buttons: Dictionary = {} # String: Button
var current_category: String = "pilot"
var on_category_switched: Callable = Callable()


func setup(container: HBoxContainer, on_switched: Callable) -> void:
	tabs_container = container
	on_category_switched = on_switched
	tab_buttons.clear()

	var tabs: Array[Dictionary] = [
		{ "cat": "pilot", "label": "👤 PILOTO" },
		{ "cat": "ship", "label": "🚀 NAVE" },
		{ "cat": "weapon", "label": "🔫 ARMA" },
		{ "cat": "pet", "label": "🐱 MASCOTA" },
		{ "cat": "navigator", "label": "📡 NAVEGADORA" }
	]

	for t in tabs:
		var btn := Button.new()
		btn.text = t["label"]
		btn.custom_minimum_size = Vector2(105, 34)
		var cat_name: String = t["cat"]
		btn.pressed.connect(func(): switch_category(cat_name))
		UIFocusHelper.apply_cyber_focus(btn)
		tabs_container.add_child(btn)
		tab_buttons[cat_name] = btn


func switch_category(new_cat: String) -> void:
	if current_category == new_cat:
		return
	current_category = new_cat
	if on_category_switched.is_valid():
		on_category_switched.call(new_cat)


func cycle_tabs(dir: int) -> void:
	var tabs: Array[String] = ["pilot", "ship", "weapon"]
	if not (current_category in tabs):
		return
	var cur: int = tabs.find(current_category)
	var next_idx: int = (cur + dir) % tabs.size()
	if next_idx < 0:
		next_idx += tabs.size()
	switch_category(tabs[next_idx])


func configure_tab_visibility(category: String) -> void:
	current_category = category
	var is_character_system: bool = (category in ["pilot", "ship", "weapon"])
	for cat in tab_buttons.keys():
		var btn: Button = tab_buttons[cat]
		if is_character_system:
			btn.visible = (cat in ["pilot", "ship", "weapon"])
		else:
			btn.visible = (cat == category)


func update_styles(active_cat: String) -> void:
	current_category = active_cat
	for cat in tab_buttons.keys():
		var btn: Button = tab_buttons[cat]
		if cat == active_cat:
			btn.modulate = Color(0.2, 1.0, 0.85, 1.0)
		else:
			btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
