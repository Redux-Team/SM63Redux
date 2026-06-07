extends Entity

const FLUDD_PICKUP_COLLECT: AudioStream = preload("uid://skajv0eggseb")

@export var grant_nozzle: PlayerFluddHandler.FluddNozzle


func _ready() -> void:
	assert(grant_nozzle)


func _on_entity_check_area_player_entered(player: Player) -> void:
	player.get_fludd_handler().held_nozzles.set(grant_nozzle, true)
	player.get_fludd_handler().switch_nozzle_to(grant_nozzle)
	player.get_fludd_handler().fludd_fuel = 100
	SFX.build(FLUDD_PICKUP_COLLECT).set_db(-10).play()
	queue_free()
