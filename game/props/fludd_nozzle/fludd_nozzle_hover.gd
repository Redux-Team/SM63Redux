extends Entity

const FLUDD_PICKUP_COLLECT: AudioStream = preload("uid://skajv0eggseb")
const PICKUP_SFX_DB: float = -10.0

@export var grant_nozzle: PlayerFludd.Nozzle = PlayerFludd.Nozzle.HOVER


func _on_entity_check_area_player_entered(player: Player) -> void:
	var fludd: PlayerFludd = player.fludd
	fludd.held_nozzles[grant_nozzle] = true
	fludd.equipped_nozzle = grant_nozzle
	fludd.fuel = PlayerFludd.FUEL_MAX
	SFX.build(FLUDD_PICKUP_COLLECT).set_db(PICKUP_SFX_DB).play()
	queue_free()
