extends State


func _physics_process(delta: float) -> void:
	if abs(player.move_dir) > 0 and not player.is_diving:
		speed_up(player.move_dir)


func speed_up(move_dir: float) -> void:
	var target_speed = player.run_max_speed * move_dir * 0.75
	var accel = player.walk_acceleration
	var friction = player.get_effective_friction()

	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
		var turn_factor = lerpf(1.0, player.midair_turn_speed, clamp(friction, 0.0, 1.0))
		accel *= turn_factor

	player.velocity.x = move_toward(player.velocity.x, target_speed, accel)
