extends Prop

@export var pickup_sfx: AudioStream
@export var water_amount: int = 50


func _on_entity_check_area_player_entered(player: Player) -> void:
	SFX.build(pickup_sfx).set_db(-5).play()
	player.fludd.fuel = minf(player.fludd.fuel + water_amount, PlayerFludd.FUEL_MAX)
	queue_free()
