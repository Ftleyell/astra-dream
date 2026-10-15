class_name RunForkOptionData
extends Resource

## RunForkOptionData.gd
## Definición de recurso para cartas de opción de bifurcación de run (In-Run Decisions).

enum Rarity {
	COMMON = 0,
	RARE = 1,
	EPIC = 2,
	LEGENDARY = 3,
}

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var rarity: Rarity = Rarity.COMMON
@export var weight: float = 100.0
@export var min_wave: int = 1
@export var max_wave: int = 999
@export var effects: Array[RunEffect] = []
