## airborne.gd
extends State

func _physics_process(delta: float) -> void:
	if abs(player.move_dir) > 0 and not player.is_diving:
		air_move(player.move_dir)


func air_move(move_dir: float) -> void:
	var accel: float = player.walk_acceleration
	var target_speed: float = player.run_max_speed * move_dir
	var accel_mult: float = 0.85
	
	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
		accel_mult = 1.2
	
	player.velocity.x = move_toward(player.velocity.x, target_speed, accel * accel_mult)
