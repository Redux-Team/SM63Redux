@tool
extends State


func _on_physics_tick(delta: float) -> void:
	if abs(player.move_dir) == 0 and not player.is_diving:
		var friction: FrictionComponent = player.get_component(FrictionComponent)
		friction.apply(0.4)
	
	player.is_falling = player.velocity.y > 0
	_update_jump_chain(delta)
	_handle_ground_pound()


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
	if not player.is_on_floor() and player.is_input_ground_pound:
		state_machine.change_state(&"GroundPoundStart")
