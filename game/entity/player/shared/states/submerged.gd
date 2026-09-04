extends PlayerState


func _tick(delta: float) -> void:
	player.swim_hold_timer = max(player.swim_hold_timer - delta, 0.0)
	
	if abs(player.move_input) == 0 or not player.can_walk:
		var friction_component: FrictionComponent = player.get_component(FrictionComponent)
		if friction_component:
			friction_component.apply(1.0, true)
	
	if abs(player.move_input) > 0 and not player.is_crouching and player.can_walk:
		_speed_up(player.move_input)
	
	if player.is_action_pressed("swim_down") and player.swim_hold_timer <= 0.0 and not player.get_fludd_handler().is_spraying():
		player.velocity.y = lerpf(player.velocity.y, player.swim_down_speed, player.swim_down_lerp)
	elif player.swim_hold_timer > 0.0:
		player.velocity.y = lerpf(player.velocity.y, 0.0, player.swim_hold_lerp)
	else:
		player.velocity.y = lerpf(player.velocity.y, player.swim_drift_speed, player.swim_drift_lerp)
	
	_handle_ground_pound()


func _next() -> StringName:
	if not player.is_in_water():
		return &"Fall" if player.velocity.y > 0.0 else &"IdleJump"
	return &"SwimIdle" if is_current() else &""


func _speed_up(move_input: float) -> void:
	var resistance: float = clamp(player.water_resistance, 0.0, 1.0)
	
	var target_speed: float = player.run_max_speed * move_input * resistance
	var acceleration: float = player.walk_acceleration * resistance
	var friction: float = player.get_effective_friction() * resistance
	
	if sign(player.velocity.x) != sign(move_input) and abs(player.velocity.x) > player.swim_turn_threshold:
		var turn_factor: float = lerpf(1.0, player.turn_acceleration_multiplier, clamp(friction, 0.0, 1.0))
		acceleration *= turn_factor
	
	player.velocity.x = move_toward(player.velocity.x, target_speed, acceleration)
	
	var floor_normal: Vector2 = player.get_floor_normal()
	if floor_normal.y < player.slope_normal_threshold and player.velocity.y >= 0.0:
		player.velocity.y = max(player.velocity.y, player.swim_slope_speed * resistance)


func _handle_ground_pound() -> void:
	if not player.is_on_floor() and player.is_input_ground_pound and player.can_ground_pound:
		machine.change_state(&"GroundPoundStart")


func _exit() -> void:
	# little boost for exiting the water
	if player.velocity.y < 0:
		player.velocity.y = max(player.velocity.y * player.swim_exit_boost, player.swim_exit_boost_cap)
