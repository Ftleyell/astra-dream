class_name ProfileRosterData
extends RefCounted

## Schema DTO tipado para pilotos, acompañantes, cosméticos y equipamiento del perfil.

const DEFAULT_ITEMS: Array[StringName] = [
	&"botas", &"espada", &"escudo", &"corazon", &"manzana",
	&"iman", &"gafas", &"lupa", &"guante", &"trebol", &"carcaj",
	&"telemetry_chip", &"quantum_thruster", &"expansion_lens",
	&"quantum_chronometer", &"quantum_coin", &"biomass_capsule",
	&"cursed_relic", &"reactor_cristal", &"heavy_condenser",
	&"tachyon_piercer", &"quantum_key", &"green_card", &"red_card",
	&"fusion_reactor", &"dense_turbine", &"collimating_lens",
	&"split_salvo", &"rapid_injector", &"nanotitanium_plating",
	&"afterburner", &"tachyon_prism",
	&"tesla_coil", &"kinetic_armor", &"phase_thruster",
	&"retaliation_swarm", &"entropy_catalyst", &"phase_inverter",
	&"pyroclastic_battery", &"cryogenic_capacitor",
	&"alchemical_converter", &"hemodynamic_cell", &"kinetic_converter",
	&"gravitational_resonator", &"photonic_transducer", &"overdrain_module",
	&"static_charge_battery", &"stellar_scrap",
	&"abyssal_contract", &"antimatter_core", &"blood_capacitor",
	&"entropy_engine", &"bifocal_lens", &"inertial_thruster",
	&"chain_battery", &"photonic_prism", &"orbital_relay",
	&"quantum_recompiler", &"heavy_salvager", &"chronos_bank"
]

const DEFAULT_CHARACTERS: Array[StringName] = [
	&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"
]

const DEFAULT_PETS: Array[StringName] = [
	&"mochi", &"kuro", &"luna", &"pip"
]

const DEFAULT_NAVIGATORS: Array[StringName] = [
	&"lyra", &"vespera", &"caelia", &"zephyr"
]

const ROSTER_PILOTS: Array[StringName] = [
	&"nova", &"echo", &"valentina", &"roxy", &"kira", &"selene", &"nyx"
]

var unlocked_items: Array[StringName] = []
var unlocked_characters: Array[StringName] = []
var character_banlists: Dictionary = {}
var character_skills: Dictionary = {}
var selected_character: StringName = &"nova"
var selected_pet: StringName = &"mochi"
var unlocked_pets: Array[StringName] = []
var selected_navigator: StringName = &"lyra"
var unlocked_navigators: Array[StringName] = []
var unlocked_endings: Array[String] = []
var unlocked_skins: Dictionary = {}
var equipped_skins: Dictionary = {}
var character_active_tomes: Dictionary = {}
var character_active_weapons: Dictionary = {}
var character_loadouts: Dictionary = {}

static func create_default() -> RefCounted:
	var roster: RefCounted = (load("res://core/systems/persistence/schemas/profile_roster_data.gd") as GDScript).new()
	roster.unlocked_items = DEFAULT_ITEMS.duplicate()
	roster.unlocked_characters = DEFAULT_CHARACTERS.duplicate()
	roster.character_banlists = {
		&"nova": [&"escudo"] as Array[StringName],
		&"valentina": [&"manzana"] as Array[StringName]
	}
	roster.character_skills = {}
	roster.selected_character = &"nova"
	roster.selected_pet = &"mochi"
	roster.unlocked_pets = DEFAULT_PETS.duplicate()
	roster.selected_navigator = &"lyra"
	roster.unlocked_navigators = DEFAULT_NAVIGATORS.duplicate()
	roster.unlocked_endings = []
	roster.unlocked_skins = {}
	roster.equipped_skins = {}
	roster.character_active_tomes = {}
	roster.character_active_weapons = {}
	roster.character_loadouts = roster._generate_default_loadouts()
	return roster

func _generate_default_loadouts() -> Dictionary:
	var loadouts: Dictionary = {}
	for c_name in ROSTER_PILOTS:
		loadouts[String(c_name)] = {
			"selected_pet": &"mochi",
			"selected_navigator": &"lyra",
			"equipped_pet_skin": "",
			"equipped_navigator_skin": "",
			"equipped_ship_skin": "base",
			"equipped_weapon_skin": "base",
			"equipped_pilot_skin": "base"
		}
	return loadouts

func populate_from_dict(raw: Dictionary) -> void:
	selected_character = StringName(str(raw.get("selected_character", "nova")))
	if selected_character == &"":
		selected_character = &"nova"

	selected_pet = StringName(str(raw.get("selected_pet", "mochi")))
	if selected_pet == &"":
		selected_pet = &"mochi"

	selected_navigator = StringName(str(raw.get("selected_navigator", "lyra")))
	if selected_navigator == &"":
		selected_navigator = &"lyra"

	# Unlocked items
	unlocked_items = []
	if raw.has("unlocked_items") and raw["unlocked_items"] is Array:
		for item in raw["unlocked_items"]:
			unlocked_items.append(StringName(str(item)))
	else:
		unlocked_items = DEFAULT_ITEMS.duplicate()

	# Unlocked characters
	unlocked_characters = []
	if raw.has("unlocked_characters") and raw["unlocked_characters"] is Array:
		for ch in raw["unlocked_characters"]:
			unlocked_characters.append(StringName(str(ch)))
	else:
		unlocked_characters = DEFAULT_CHARACTERS.duplicate()

	# Unlocked pets
	unlocked_pets = []
	if raw.has("unlocked_pets") and raw["unlocked_pets"] is Array and not raw["unlocked_pets"].is_empty():
		for p in raw["unlocked_pets"]:
			unlocked_pets.append(StringName(str(p)))
	else:
		unlocked_pets = DEFAULT_PETS.duplicate()
	for default_pid in DEFAULT_PETS:
		if not unlocked_pets.has(default_pid):
			unlocked_pets.append(default_pid)

	# Unlocked navigators
	unlocked_navigators = []
	if raw.has("unlocked_navigators") and raw["unlocked_navigators"] is Array and not raw["unlocked_navigators"].is_empty():
		for n in raw["unlocked_navigators"]:
			unlocked_navigators.append(StringName(str(n)))
	else:
		unlocked_navigators = DEFAULT_NAVIGATORS.duplicate()
	for default_nid in DEFAULT_NAVIGATORS:
		if not unlocked_navigators.has(default_nid):
			unlocked_navigators.append(default_nid)

	# Unlocked endings
	unlocked_endings = []
	if raw.has("unlocked_endings") and raw["unlocked_endings"] is Array:
		for e in raw["unlocked_endings"]:
			unlocked_endings.append(String(e))

	# Banlists
	character_banlists = {}
	if raw.has("character_banlists") and raw["character_banlists"] is Dictionary:
		var raw_bans: Dictionary = raw["character_banlists"]
		for char_id in raw_bans.keys():
			var bans: Array[StringName] = []
			if raw_bans[char_id] is Array:
				for b in raw_bans[char_id]:
					bans.append(StringName(str(b)))
			character_banlists[StringName(str(char_id))] = bans

	# Skills
	character_skills = {}
	if raw.has("character_skills") and raw["character_skills"] is Dictionary:
		var raw_skills: Dictionary = raw["character_skills"]
		for cid in raw_skills.keys():
			var arr: Array[StringName] = []
			if raw_skills[cid] is Array:
				for n in raw_skills[cid]:
					arr.append(StringName(str(n)))
			character_skills[StringName(str(cid))] = arr

	# Skins
	unlocked_skins = raw.get("unlocked_skins", {}).duplicate() if raw.get("unlocked_skins") is Dictionary else {}
	equipped_skins = raw.get("equipped_skins", {}).duplicate() if raw.get("equipped_skins") is Dictionary else {}

	# Active tomes & weapons
	character_active_tomes = raw.get("character_active_tomes", {}).duplicate() if raw.get("character_active_tomes") is Dictionary else {}
	character_active_weapons = raw.get("character_active_weapons", {}).duplicate() if raw.get("character_active_weapons") is Dictionary else {}

	# Character loadouts
	var raw_loadouts: Dictionary = raw.get("character_loadouts", {}) if raw.get("character_loadouts") is Dictionary else {}
	var clean_loadouts: Dictionary = {}
	for c_name in ROSTER_PILOTS:
		var c_str := String(c_name)
		var c_loadout: Dictionary = raw_loadouts.get(c_str, {}).duplicate() if raw_loadouts.has(c_str) else {}
		if not c_loadout.has("selected_pet") or str(c_loadout["selected_pet"]).is_empty():
			c_loadout["selected_pet"] = &"mochi"
		if not c_loadout.has("selected_navigator") or str(c_loadout["selected_navigator"]).is_empty():
			c_loadout["selected_navigator"] = &"lyra"
		if not c_loadout.has("equipped_pet_skin"):
			c_loadout["equipped_pet_skin"] = ""
		if not c_loadout.has("equipped_navigator_skin"):
			c_loadout["equipped_navigator_skin"] = ""
		if not c_loadout.has("equipped_ship_skin") or str(c_loadout["equipped_ship_skin"]).is_empty():
			c_loadout["equipped_ship_skin"] = "base"
		if not c_loadout.has("equipped_weapon_skin") or str(c_loadout["equipped_weapon_skin"]).is_empty():
			c_loadout["equipped_weapon_skin"] = "base"
		if not c_loadout.has("equipped_pilot_skin") or str(c_loadout["equipped_pilot_skin"]).is_empty():
			c_loadout["equipped_pilot_skin"] = "base"
		clean_loadouts[c_str] = c_loadout
	character_loadouts = clean_loadouts

func to_dict() -> Dictionary:
	var bans_serializable: Dictionary = {}
	for char_id in character_banlists.keys():
		var bans: Array = character_banlists[char_id]
		var str_list: Array[String] = []
		for item_id in bans:
			str_list.append(String(item_id))
		bans_serializable[String(char_id)] = str_list

	var str_unlocked_items: Array[String] = []
	for item_id in unlocked_items:
		str_unlocked_items.append(String(item_id))

	var str_unlocked_chars: Array[String] = []
	for char_id in unlocked_characters:
		str_unlocked_chars.append(String(char_id))

	var skills_serializable: Dictionary = {}
	for cid in character_skills.keys():
		var arr: Array = character_skills[cid]
		var str_arr: Array[String] = []
		for n in arr:
			str_arr.append(str(n))
		skills_serializable[String(cid)] = str_arr

	var str_unlocked_pets: Array[String] = []
	for p in unlocked_pets:
		str_unlocked_pets.append(String(p))

	var str_unlocked_navs: Array[String] = []
	for n in unlocked_navigators:
		str_unlocked_navs.append(String(n))

	var str_unlocked_endings: Array[String] = []
	for e in unlocked_endings:
		str_unlocked_endings.append(String(e))

	return {
		"unlocked_items": str_unlocked_items,
		"unlocked_characters": str_unlocked_chars,
		"character_banlists": bans_serializable,
		"character_skills": skills_serializable,
		"selected_character": String(selected_character),
		"selected_pet": String(selected_pet),
		"unlocked_pets": str_unlocked_pets,
		"selected_navigator": String(selected_navigator),
		"unlocked_navigators": str_unlocked_navs,
		"unlocked_endings": str_unlocked_endings,
		"unlocked_skins": unlocked_skins.duplicate(),
		"equipped_skins": equipped_skins.duplicate(),
		"character_active_tomes": character_active_tomes.duplicate(),
		"character_active_weapons": character_active_weapons.duplicate(),
		"character_loadouts": character_loadouts.duplicate()
	}
