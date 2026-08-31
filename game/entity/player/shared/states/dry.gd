extends PlayerState


func _tick(delta: float) -> void:
	if is_zero_approx(player.move_dir) and not player.is_diving:
		var friction: FrictionComponent = player.get_component(FrictionComponent)
		friction.apply(player.dry_friction)
	
	player.is_falling = player.velocity.y > 0
	_update_jump_chain(delta)
	_handle_ground_pound()


func _next() -> StringName:
	return &"SwimIdle" if player.is_in_water() else &""


func _update_jump_chain(delta: float) -> void:
	if not player.is_on_floor() or not player.can_jump:
		return
	if player.jump_chain_timer > 0.0:
		player.jump_chain_timer = max(player.jump_chain_timer - delta, 0.0)
		if player.jump_chain_timer == 0.0:
			player.current_jump = 0
	elif player.current_jump >= 3:
		player.current_jump = 0


func _handle_ground_pound() -> void:
	if not player.is_on_floor() and player.is_input_ground_pound and player.can_ground_pound:
		machine.change_state(&"GroundPoundStart")
