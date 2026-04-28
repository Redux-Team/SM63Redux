extends State


func _physics_process(_delta: float) -> void:
	if player._movement_locked:
		return
	
	if abs(player.move_dir) > 0 and not player.is_diving:
		air_move(player.move_dir)
	
	player.velocity.y = min(player.velocity.y, player.terminal_velocity_y)


func air_move(move_dir: float) -> void:
	var accel: float = player.walk_acceleration
	var max_speed: float = player.run_max_speed
	var is_spinning: bool = state_machine.current_state.name == "Spin"
	var accel_mult: float = 0.35 if is_spinning and not player.is_on_floor() else 0.85
	
	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
		accel_mult = 1.4 if is_spinning else 2.8
	
	var vx: float = player.velocity.x
	
	if abs(vx) < max_speed or sign(vx) != sign(move_dir):
		vx = move_toward(vx, max_speed * move_dir, accel * accel_mult)
	
	player.velocity.x = vx
