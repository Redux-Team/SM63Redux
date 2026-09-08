extends PlayerState


func _tick(_delta: float) -> void:
	if absf(player.move_input) > 0.0 and not machine.get_state_name() == &"Crouch":
		_speed_up(player.move_input)
	else:
		_apply_friction()
	
	player.velocity.y = 0.0


func _speed_up(move_input: float) -> void:
	var max_speed: float = player.effective_run_max_speed
	var speed_x: float = player.velocity.x
	var acceleration: float = player.walk_acceleration
	
	if sign(speed_x) != sign(move_input) and abs(speed_x) > 0.0:
		acceleration *= player.turn_acceleration_multiplier
	
	if absf(speed_x) < max_speed or signf(speed_x) != signf(move_input):
		player.velocity.x = move_toward(speed_x, max_speed * move_input, acceleration)
	
	if player.get_local_floor_normal().y < player.slope_normal_threshold and player.velocity.y >= 0.0:
		player.velocity.y = player.slope_stick_speed


func _apply_friction() -> void:
	var speed: float = abs(player.velocity.x)
	speed = max(0.0, speed - player.ground_friction_flat)
	speed /= player.ground_friction_divisor
	player.velocity.x = speed * sign(player.velocity.x)
