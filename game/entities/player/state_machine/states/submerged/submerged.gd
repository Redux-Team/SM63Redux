extends State

func _physics_process(_delta: float) -> void:
	if abs(player.move_dir) == 0:
		player.apply_friction(0.4, true)
	
	if abs(player.move_dir) > 0 and not player.is_crouching:
		speed_up(player.move_dir)
	
	
	if Input.is_action_pressed("swim_down"):
		player.velocity.y = lerpf(player.velocity.y, 140, 0.2)
	else:
		player.velocity.y = min(player.velocity.y, 35)
	
	_handle_ground_pound()
	_handle_spin()


func speed_up(move_dir: float) -> void:
	var resistance: float = clamp(player.water_resistance, 0.0, 1.0)
	
	var target_speed: float = player.run_max_speed * move_dir * resistance
	var accel: float = player.walk_acceleration * resistance
	var friction: float = player.get_effective_friction() * resistance
	
	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
		var turn_factor: float = lerpf(1.0, player.turn_speed, clamp(friction, 0.0, 1.0))
		accel *= turn_factor
	
	player.velocity.x = move_toward(player.velocity.x, target_speed, accel)
	
	var floor_normal: Vector2 = player.get_floor_normal()
	if floor_normal.y < 0.999 and player.velocity.y >= 0.0:
		player.velocity.y = max(player.velocity.y, 5.0 * resistance)


func _handle_spin() -> void:
	pass


func _handle_ground_pound() -> void:
	if not player.is_on_floor() and player.is_input_ground_pound:
		state_machine.change_state(&"GroundPoundStart")
