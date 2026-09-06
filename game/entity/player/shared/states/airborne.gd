extends PlayerState


func _tick(_delta: float) -> void:
	if player.is_diving:
		return
	
	if absf(player.move_input) > 0.0:
		_air_move(player.move_input)
	else:
		_air_drag()


func _air_move(move_input: float) -> void:
	var acceleration: float = player.air_acceleration
	var max_speed: float = player.effective_midair_max_speed
	var is_spinning: bool = machine.get_state_name() == &"Spin"
	var acceleration_multiplier: float = player.air_control_spin if is_spinning and not player.is_on_floor() else player.air_control_normal
	
	if sign(player.velocity.x) != sign(move_input) and abs(player.velocity.x) > player.air_turn_speed_threshold:
		acceleration_multiplier = player.air_turn_boost_spin if is_spinning else player.air_turn_boost
	
	var speed_x: float = player.velocity.x
	
	if absf(speed_x) < max_speed or signf(speed_x) != signf(move_input):
		speed_x = move_toward(speed_x, max_speed * move_input, acceleration * acceleration_multiplier)
	elif not player.get_fludd_handler().is_spraying():
		speed_x = move_toward(speed_x, player.air_momentum_max_speed * signf(speed_x), player.air_momentum_gain)
	
	player.velocity.x = speed_x


func _air_drag() -> void:
	var over_speed: bool = absf(player.velocity.x) > player.effective_midair_max_speed
	var drag: float = player.air_drag_over_speed if over_speed else player.air_drag
	player.velocity.x = move_toward(player.velocity.x, 0.0, drag)
