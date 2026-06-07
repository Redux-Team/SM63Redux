extends LevelObjectSprite

@export var pickup_sfx: AudioStream
@export var water_amount: int = 50


func _on_entity_check_area_player_entered(player: Player) -> void:
	SFX.build(pickup_sfx).set_db(-5).play()
	# TODO water particles
	player.get_fludd_handler().fludd_fuel += water_amount
	queue_free()
