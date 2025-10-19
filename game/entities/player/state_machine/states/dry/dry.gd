extends State


func _physics_process(delta: float) -> void:
	if abs(player.move_dir) == 0 or (player.is_diving and player.is_on_floor()):
		player.apply_friction()
	
	player.is_falling = player.velocity.y > 0
	_handle_triple_jump(delta)


func _handle_triple_jump(delta: float) -> void:
	if not player.is_on_floor():
		return
	
	if player.jump_chain_timer > 0.0:
		player.jump_chain_timer = max(0, player.jump_chain_timer - delta)
	else:
		player.current_jump = 0
