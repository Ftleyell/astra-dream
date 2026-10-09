class_name BaseSpaceStation
extends Node2D

## BaseSpaceStation.gd
## Contrato e interfaz base para entidades y estaciones espaciales interactuables
## (Balizas de radar, Forjas cuánticas, Terminales, etc.).

signal station_activated
signal station_depleted

@export var activation_radius: float = 180.0
@export var core_bump_radius: float = 60.0

var player_inside: bool = false


func is_station_busy() -> bool:
	return false


func is_station_charging() -> bool:
	return false


func is_station_ready() -> bool:
	return false


func can_be_replaced() -> bool:
	return true
