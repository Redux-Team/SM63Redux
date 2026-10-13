extends Node2D

@export var player: Player
@export var player_old: PlayerOld


func _ready() -> void:
	AudioServer.set_bus_volume_db(0, -80)
	get_tree().debug_collisions_hint = true
	
	for nozzle: PlayerFludd.Nozzle in PlayerFludd.Nozzle.values():
		player.fludd.held_nozzles.set(nozzle, true)
