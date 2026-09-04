extends PlayerState


func _tick(_delta: float) -> void:
	if absf(player.move_input) > 0.0 and not player.is_diving:
		_air_move(player.move_input)
	
	player.velocity.y = min(player.velocity.y, player.terminal_velocity_y)


func _air_move(move_input: float) -> void:
	var acceleration: float = player.air_acceleration
	var max_speed: float = player.effective_midair_max_speed
	var is_spinning: bool = machine.get_state_name() == &"Spin"
	var acceleration_multiplier: float = player.air_control_spin if is_spinning and not player.is_on_floor() else player.air_control_normal
	
	if sign(player.velocity.x) != sign(move_input) and abs(player.velocity.x) > player.air_turn_speed_threshold:
		acceleration_multiplier = player.air_turn_boost_spin if is_spinning else player.air_turn_boost
	
	var speed_x: float = player.velocity.x
	
	if abs(speed_x) < max_speed or sign(speed_x) != sign(move_input):
		speed_x = move_toward(speed_x, max_speed * move_input, acceleration * acceleration_multiplier)
	elif abs(speed_x) > max_speed and not player.get_fludd_handler().is_spraying():
		speed_x = move_toward(speed_x, max_speed * sign(speed_x), acceleration * acceleration_multiplier * player.air_over_speed_decel)
	
	player.velocity.x = speed_x
