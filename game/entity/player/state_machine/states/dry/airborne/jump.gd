extends State


func _on_enter(_from: StringName) -> void:
	if player.is_on_floor():
		player.velocity.y = -player.jump_strength
		player.jump_chain_timer = player.jump_chain_time
		player.can_jump = false
		await get_tree().physics_frame
		player.current_jump += 1


func _on_exit(_to: StringName) -> void:
	player.can_jump = true
