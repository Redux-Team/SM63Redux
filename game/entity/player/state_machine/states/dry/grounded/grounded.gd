extends State


func _physics_process(_delta: float) -> void:
	if player._movement_locked:
		return
	
	if abs(player.move_dir) > 0.0 and not state_machine.current_state.name == "Crouch":
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
	
	if player.get_floor_normal().y < 0.999 and player.velocity.y >= 0.0:
		player.velocity.y = 0.5
 
 
func _apply_friction() -> void:
	var speed: float = abs(player.velocity.x)
	speed = max(0.0, speed - 0.3)
	speed /= 1.15
	player.velocity.x = speed * sign(player.velocity.x)
