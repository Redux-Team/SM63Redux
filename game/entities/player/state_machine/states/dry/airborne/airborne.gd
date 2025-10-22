## airborne.gd
extends State

func _physics_process(delta: float) -> void:
	if abs(player.move_dir) > 0 and not player.is_diving:
		air_move(player.move_dir)


func air_move(move_dir: float) -> void:
	var accel: float = player.walk_acceleration
	var max_speed: float = player.run_max_speed
	var accel_mult: float = 0.85
	
	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
		accel_mult = 2.8
	
	var vx: float = player.velocity.x
	
	if abs(vx) < max_speed or sign(vx) != sign(move_dir):
		vx = move_toward(vx, max_speed * move_dir, accel * accel_mult)
	else:
		pass
	
	player.velocity.x = vx
