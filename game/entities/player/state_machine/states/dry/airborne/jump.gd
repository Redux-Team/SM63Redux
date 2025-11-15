extends State


func _on_enter(_from: StringName) -> void:
	if player.is_on_floor():
		player.velocity.y = -player.jump_strength
		player.jump_chain_timer = player.jump_chain_time
		await get_tree().physics_frame
		player.current_jump += 1
