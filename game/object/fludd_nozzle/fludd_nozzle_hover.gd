extends Entity

const FLUDD_PICKUP_COLLECT: AudioStream = preload("uid://skajv0eggseb")
const PICKUP_SFX_DB: float = -10.0

@export var grant_nozzle: PlayerFluddHandler.FluddNozzle


func _ready() -> void:
	assert(grant_nozzle)


func _on_entity_check_area_player_entered(player: Player) -> void:
	var fludd: PlayerFluddHandler = player.get_fludd_handler()
	fludd.held_nozzles.set(grant_nozzle, true)
	fludd.switch_nozzle_to(grant_nozzle)
	fludd.fludd_fuel = PlayerFluddHandler.FLUDD_FUEL_MAX
	
	SFX.build(FLUDD_PICKUP_COLLECT).set_db(PICKUP_SFX_DB).play()
	queue_free()
