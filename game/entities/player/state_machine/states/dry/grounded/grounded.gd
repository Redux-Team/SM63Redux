## Dry
extends State


func _physics_process(_delta: float) -> void:
	if abs(player.move_dir) > 0 and not (player.is_crouching and player.velocity.x == 0):
		speed_up(player.move_dir)


func speed_up(move_dir: float) -> void:
	var target_speed: float = player.run_max_speed * move_dir
	var accel: float = player.walk_acceleration
	var friction: float = player.get_effective_friction()
	
	if player.is_on_floor():
		if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
			var turn_factor: float = lerpf(1.0, player.turn_speed, clamp(friction, 0.0, 1.0))
			accel *= turn_factor
		
		player.velocity.x = move_toward(player.velocity.x, target_speed, accel)
		
		var floor_normal: Vector2 = player.get_floor_normal()
		if floor_normal.y < 0.999 and player.velocity.y >= 0: # on slope, not moving up
			player.velocity.y = max(player.velocity.y, 5.0)
