extends PlayerState


func _tick(_delta: float) -> void:
	if absf(player.move_dir) > 0.0 and not machine.get_state_name() == &"Crouch":
		_speed_up(player.move_dir)
	else:
		_apply_friction()
	
	player.velocity.y = 0.0


func _speed_up(dir: float) -> void:
	var target: float = player.run_max_speed * dir
	var accel: float = player.walk_acceleration
	
	if sign(player.velocity.x) != sign(dir) and abs(player.velocity.x) > 0.0:
		accel *= player.turn_speed
	
	player.velocity.x = move_toward(player.velocity.x, target, accel)
	
	if player.get_local_floor_normal().y < player.slope_normal_threshold and player.velocity.y >= 0.0:
		player.velocity.y = player.slope_stick_speed


func _apply_friction() -> void:
	var speed: float = abs(player.velocity.x)
	speed = max(0.0, speed - player.ground_friction_flat)
	speed /= player.ground_friction_divisor
	player.velocity.x = speed * sign(player.velocity.x)
