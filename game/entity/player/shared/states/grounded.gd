extends PlayerState


func _tick(_delta: float) -> void:
	if absf(player.move_input) > 0.0 and not machine.get_state_name() == &"Crouch":
		_speed_up(player.move_input)
	else:
		_apply_friction()
	
	player.velocity.y = 0.0


func _speed_up(move_input: float) -> void:
	var target_speed: float = player.run_max_speed * move_input
	var acceleration: float = player.walk_acceleration
	
	if sign(player.velocity.x) != sign(move_input) and abs(player.velocity.x) > 0.0:
		acceleration *= player.turn_acceleration_multiplier
	
	player.velocity.x = move_toward(player.velocity.x, target_speed, acceleration)
	
	if player.get_local_floor_normal().y < player.slope_normal_threshold and player.velocity.y >= 0.0:
		player.velocity.y = player.slope_stick_speed


func _apply_friction() -> void:
	var speed: float = abs(player.velocity.x)
	speed = max(0.0, speed - player.ground_friction_flat)
	speed /= player.ground_friction_divisor
	player.velocity.x = speed * sign(player.velocity.x)
