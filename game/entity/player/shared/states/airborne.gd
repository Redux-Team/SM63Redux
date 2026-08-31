extends PlayerState


func _tick(_delta: float) -> void:
	if absf(player.move_dir) > 0.0 and not player.is_diving:
		air_move(player.move_dir)
	
	player.velocity.y = min(player.velocity.y, player.terminal_velocity_y)


func air_move(move_dir: float) -> void:
	var accel: float = player.midair_turn_speed
	var max_speed: float = player.effective_midair_max_speed
	var is_spinning: bool = machine.get_state_name() == &"Spin"
	var accel_mult: float = player.air_control_spin if is_spinning and not player.is_on_floor() else player.air_control_normal
	
	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > player.air_turn_speed_threshold:
		accel_mult = player.air_turn_boost_spin if is_spinning else player.air_turn_boost
	
	var vx: float = player.velocity.x
	
	if abs(vx) < max_speed or sign(vx) != sign(move_dir):
		vx = move_toward(vx, max_speed * move_dir, accel * accel_mult)
	elif abs(vx) > max_speed and not player.get_fludd_handler().is_hover_active():
		vx = move_toward(vx, max_speed * sign(vx), accel * accel_mult * player.air_over_speed_decel)
	
	player.velocity.x = vx
