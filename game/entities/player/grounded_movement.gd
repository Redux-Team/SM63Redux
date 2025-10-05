extends StateProcess


func _physics_process(delta: float) -> void:
	_falling_handler()


func _falling_handler() -> void:
	if player.velocity.y > 0 and not player.is_on_floor() and not player.is_spinning:
		state_machine.set_state(&"fall_start")
