extends State


func _on_enter(_from: StringName) -> void:
	print(player.double_jump_strength)
	player.velocity.y = -player.double_jump_strength
	player.jump_chain_timer = player.jump_chain_time
	
	await get_tree().physics_frame
	player.current_jump += 1
