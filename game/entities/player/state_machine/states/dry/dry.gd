extends State


func _physics_process(delta: float) -> void:
	if abs(player.move_dir) == 0 and not player.is_diving:
		player.apply_friction()
	
	player.is_falling = player.velocity.y > 0
	_handle_triple_jump(delta)
	_handle_ground_pound()


func _handle_triple_jump(delta: float) -> void:
	if player.jump_buffer_timer > 0.0:
		player.jump_buffer_timer = max(0, player.jump_buffer_timer - delta)
	
	
	if not player.is_on_floor():
		return
	
	if player.jump_chain_timer > 0.0:
		player.jump_chain_timer = max(0, player.jump_chain_timer - delta)
	else:
		player.current_jump = 0


func _handle_ground_pound() -> void:
	if not player.is_on_floor() and player.is_input_ground_pound:
		state_machine.change_state(&"GroundPoundStart")
